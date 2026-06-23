#!/bin/sh

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$script_dir/cluster_common.sh"

config_path=
run_tag_override=
dry_run=0

while [ "$#" -gt 0 ]; do
    case "$1" in
        --config)
            config_path=$2
            shift 2
            ;;
        --run-tag)
            run_tag_override=$2
            shift 2
            ;;
        --dry-run)
            dry_run=1
            shift
            ;;
        *)
            echo "Unknown argument: $1" >&2
            exit 1
            ;;
    esac
done

if [ -z "$config_path" ]; then
    echo "--config is required" >&2
    exit 1
fi

cluster_setup_bundle_env "$config_path" "$run_tag_override"

if [ "$dry_run" -eq 1 ] 2>/dev/null; then
    cluster_print_dry_run_plan
    exit 0
fi

cluster_validate_head_checkout
cluster_require_bundle_runtime

stage_runtime_calibration() {
    echo "Stage 1/6: runtime calibration"

    n_runtime_path="$bench_results_dir/runtime_by_N.csv"
    q_runtime_path="$cluster_internal_dir/calibration_runtime_by_Q.csv"
    speedup_probe_path="$cluster_internal_dir/calibration_speedup_probes.csv"
    context_env_path="$cluster_internal_dir/calibration_context.env"

    base_query_path=$(query_dataset_path_for_q "$bench_q")
    ensure_query_dataset_for_q "$bench_q" "$base_query_path"

    n_metric_files=""
    n_max_feasible=""
    for memory_n in $bench_n_candidates; do
        memory_path=$(memory_dataset_path "$memory_n")
        ensure_memory_dataset "$memory_n" "$memory_path"
        cluster_stage_synthetic_runtime "$memory_path" "$base_query_path"

        output_path="$cluster_probe_dir/calibration_parallel_topk_N${memory_n}.csv"
        metrics_path="$cluster_probe_dir/calibration_parallel_metrics_N${memory_n}.csv"
        run_metrics_path="$cluster_probe_dir/calibration_parallel_run_metrics_N${memory_n}.csv"

        set +e
        cluster_run_parallel_retriever \
            "$cluster_p_total" \
            "$cluster_synthetic_memory_runtime" \
            "$cluster_synthetic_query_runtime" \
            "$bench_topk" \
            "$output_path" \
            "$metrics_path" \
            "$run_metrics_path"
        run_exit=$?
        set -e

        if [ "$run_exit" -ne 0 ]; then
            break
        fi

        n_max_feasible=$memory_n
        n_metric_files="$n_metric_files $run_metrics_path"
    done

    if [ -z "$n_metric_files" ] || [ -z "$n_max_feasible" ]; then
        cluster_die "Cluster calibration failed: no successful N sweep rows were produced."
    fi

    set -- $n_metric_files
    "$bench_python_stdlib" "$script_dir/benchmark_csv.py" \
        merge-run-metrics \
        --output "$n_runtime_path" \
        "$@"

    q_input_args=""
    if ! "$bench_python_stdlib" "$script_dir/benchmark_csv.py" row-in-target --input "$n_runtime_path" >/dev/null; then
        selected_memory_path=$(memory_dataset_path "$n_max_feasible")
        cluster_stage_runtime_file "$selected_memory_path" "$cluster_synthetic_memory_runtime"
        q_metric_files=""
        for query_q in $bench_q_candidates; do
            query_path=$(query_dataset_path_for_q "$query_q")
            ensure_query_dataset_for_q "$query_q" "$query_path"
            cluster_stage_runtime_file "$query_path" "$cluster_synthetic_query_runtime"

            output_path="$cluster_probe_dir/calibration_parallel_topk_N${n_max_feasible}_Q${query_q}.csv"
            metrics_path="$cluster_probe_dir/calibration_parallel_metrics_N${n_max_feasible}_Q${query_q}.csv"
            run_metrics_path="$cluster_probe_dir/calibration_parallel_run_metrics_N${n_max_feasible}_Q${query_q}.csv"

            cluster_run_parallel_retriever \
                "$cluster_p_total" \
                "$cluster_synthetic_memory_runtime" \
                "$cluster_synthetic_query_runtime" \
                "$bench_topk" \
                "$output_path" \
                "$metrics_path" \
                "$run_metrics_path"

            q_metric_files="$q_metric_files $run_metrics_path"
        done

        if [ -z "$q_metric_files" ]; then
            cluster_die "Cluster calibration failed: Q sweep was required but produced no successful rows."
        fi

        set -- $q_metric_files
        "$bench_python_stdlib" "$script_dir/benchmark_csv.py" \
            merge-run-metrics \
            --output "$q_runtime_path" \
            "$@"
        q_input_args="--q-input $q_runtime_path"
    fi

    "$bench_python_stdlib" "$script_dir/benchmark_csv.py" \
        print-calibration-context \
        --n-input "$n_runtime_path" \
        $q_input_args \
        > "$context_env_path"

    # shellcheck disable=SC1090
    . "$context_env_path"

    speedup_metric_files=""
    selected_probe_query_path=$(query_dataset_path_for_q "$Q_SELECTED")
    ensure_query_dataset_for_q "$Q_SELECTED" "$selected_probe_query_path"
    cluster_stage_runtime_file "$selected_probe_query_path" "$cluster_synthetic_query_runtime"
    for speedup_n in $bench_speedup_n_candidates; do
        memory_path=$(memory_dataset_path "$speedup_n")
        ensure_memory_dataset "$speedup_n" "$memory_path"
        cluster_stage_runtime_file "$memory_path" "$cluster_synthetic_memory_runtime"

        output_path="$cluster_probe_dir/calibration_speedup_topk_N${speedup_n}.csv"
        run_metrics_path="$cluster_probe_dir/calibration_speedup_run_metrics_N${speedup_n}.csv"

        set +e
        run_sequential_retriever \
            "$cluster_synthetic_memory_runtime" \
            "$cluster_synthetic_query_runtime" \
            "$bench_topk" \
            "$output_path" \
            "$run_metrics_path"
        run_exit=$?
        set -e

        if [ "$run_exit" -ne 0 ]; then
            break
        fi

        speedup_metric_files="$speedup_metric_files $run_metrics_path"
    done

    if [ -z "$speedup_metric_files" ]; then
        cluster_die "Cluster calibration failed: no successful speedup baseline probes were produced."
    fi

    set -- $speedup_metric_files
    "$bench_python_stdlib" "$script_dir/benchmark_csv.py" \
        merge-run-metrics \
        --output "$speedup_probe_path" \
        "$@"

    write_manifest_args="
        --n-input $n_runtime_path
        --speedup-input $speedup_probe_path
        --output-env $selection_env_path
        --p-selected $cluster_p_total
        --epsilon $bench_epsilon
        --speedup-baseline-limit $bench_speedup_baseline_limit
    "

    if [ -n "$q_input_args" ]; then
        write_manifest_args="$write_manifest_args $q_input_args"
    fi

    # shellcheck disable=SC2086
    "$bench_python_stdlib" "$script_dir/benchmark_csv.py" \
        write-calibration-manifest \
        $write_manifest_args
}

stage_selected_synthetic_run() {
    echo "Stage 2/6: selected synthetic correctness run"

    if ! selection_manifest_is_complete "$selection_env_path"; then
        cluster_die "Missing cluster selection manifest: $selection_env_path"
    fi
    load_selection_env

    query_path=$(query_dataset_path_for_q "$Q")
    ensure_query_dataset_for_q "$Q" "$query_path"
    memory_path=$(memory_dataset_path "$N_SELECTED")
    ensure_memory_dataset "$N_SELECTED" "$memory_path"
    cluster_stage_synthetic_runtime "$memory_path" "$query_path"

    cp "$CLUSTER_HOSTFILE" "$bench_results_dir/hostfile.snapshot.txt"
    cat > "$bench_results_dir/run_notes.txt" <<EOF
cluster_date=$(date +%F)
run_tag=$cluster_run_tag
head_repo_root=$repo_root
worker_repo_root=$CLUSTER_WORKER_REPO_ROOT
head_host=${cluster_head_mpi_host}
worker_host=${cluster_worker_mpi_host}
local_slots=${cluster_local_slots}
server_slots=${cluster_server_slots}
p_total=${cluster_p_total}
selected_n=${N_SELECTED}
selected_q=${Q}
selected_d=${D}
selected_k=${K}
faiss_threads=${cluster_faiss_threads}
mpi_lan_cidr=${CLUSTER_HEAD_LAN_CIDR}
EOF

    run_sequential_retriever \
        "$cluster_synthetic_memory_runtime" \
        "$cluster_synthetic_query_runtime" \
        "$K" \
        "$bench_results_dir/sequential_topk.csv" \
        "$bench_results_dir/sequential_run_metrics.csv"

    cluster_run_parallel_retriever \
        "$cluster_p_total" \
        "$cluster_synthetic_memory_runtime" \
        "$cluster_synthetic_query_runtime" \
        "$K" \
        "$bench_results_dir/parallel_topk.csv" \
        "$bench_results_dir/parallel_metrics.csv" \
        "$bench_results_dir/parallel_run_metrics.csv"

    "$bench_build_dir/verify_results" \
        --sequential "$bench_results_dir/sequential_topk.csv" \
        --parallel "$bench_results_dir/parallel_topk.csv" \
        --epsilon "$EPSILON" \
        --output "$bench_results_dir/correctness.csv"
}

stage_granularity() {
    echo "Stage 3/6: granularity summary"

    cp "$bench_results_dir/parallel_metrics.csv" "$bench_results_dir/granularity.csv"
    "$bench_python_stdlib" "$script_dir/benchmark_csv.py" \
        summarize-granularity \
        --input "$bench_results_dir/granularity.csv" \
        --output "$bench_results_dir/granularity_summary.txt" >/dev/null
}

stage_speedup() {
    echo "Stage 4/6: speedup sweep"

    load_selection_env

    query_path=$(query_dataset_path_for_q "$Q")
    ensure_query_dataset_for_q "$Q" "$query_path"
    memory_path=$(memory_dataset_path "$N_SPEEDUP")
    ensure_memory_dataset "$N_SPEEDUP" "$memory_path"
    cluster_stage_synthetic_runtime "$memory_path" "$query_path"

    baseline_output="$cluster_internal_dir/speedup_sequential_topk.csv"
    baseline_metrics="$cluster_internal_dir/speedup_sequential_run_metrics.csv"

    run_sequential_retriever \
        "$cluster_synthetic_memory_runtime" \
        "$cluster_synthetic_query_runtime" \
        "$K" \
        "$baseline_output" \
        "$baseline_metrics"

    parallel_metric_files=""
    for process_count in $BENCH_P_LIST; do
        if [ "$process_count" -eq 1 ] 2>/dev/null; then
            continue
        fi

        if [ "$process_count" -gt "$cluster_p_total" ] 2>/dev/null; then
            cluster_die "Requested BENCH_P_LIST entry $process_count exceeds cluster_p_total=$cluster_p_total"
        fi

        parallel_output="$cluster_probe_dir/speedup_parallel_topk_P${process_count}.csv"
        parallel_metrics="$cluster_probe_dir/speedup_parallel_metrics_P${process_count}.csv"
        parallel_run_metrics="$cluster_probe_dir/speedup_parallel_run_metrics_P${process_count}.csv"

        cluster_run_parallel_retriever \
            "$process_count" \
            "$cluster_synthetic_memory_runtime" \
            "$cluster_synthetic_query_runtime" \
            "$K" \
            "$parallel_output" \
            "$parallel_metrics" \
            "$parallel_run_metrics"

        parallel_metric_files="$parallel_metric_files $parallel_run_metrics"
    done

    set -- $parallel_metric_files
    "$bench_python_stdlib" "$script_dir/benchmark_csv.py" \
        build-speedup \
        --baseline "$baseline_metrics" \
        --output "$bench_results_dir/speedup.csv" \
        "$@"
}

stage_faiss() {
    echo "Stage 5/6: FAISS comparisons"

    load_selection_env
    ensure_phase8_python faiss

    synthetic_query_path=$(query_dataset_path_for_q "$Q")
    synthetic_memory_path=$(memory_dataset_path "$N_SELECTED")
    cluster_stage_synthetic_runtime "$synthetic_memory_path" "$synthetic_query_path"

    "$BENCH_PHASE8_PYTHON" "$script_dir/faiss_compare.py" \
        --dataset-name synthetic \
        --vectors "$cluster_synthetic_memory_runtime" \
        --queries "$cluster_synthetic_query_runtime" \
        --topk "$K" \
        --threads "$cluster_faiss_threads" \
        --output-topk "$bench_faiss_results_dir/synthetic_topk.csv" \
        --output-metrics "$bench_faiss_results_dir/synthetic_run_metrics.csv"

    "$bench_build_dir/verify_results" \
        --sequential "$bench_results_dir/sequential_topk.csv" \
        --parallel "$bench_faiss_results_dir/synthetic_topk.csv" \
        --epsilon "$EPSILON" \
        --output "$bench_faiss_results_dir/synthetic_correctness.csv"

    if [ ! -f "$bench_squad_output_dir/vectors.bin" ] || [ ! -f "$bench_squad_output_dir/queries.bin" ]; then
        ensure_phase8_python real
        "$BENCH_PHASE8_PYTHON" "$script_dir/prepare_squad_minilm.py" \
            --input-dir "$bench_squad_input_dir" \
            --output-dir "$bench_squad_output_dir" \
            --model "$bench_squad_model" \
            --queries-limit "$bench_squad_queries_limit"
    fi

    squad_metadata_path=
    if [ -f "$bench_squad_output_dir/metadata.tsv" ]; then
        squad_metadata_path="$bench_squad_output_dir/metadata.tsv"
    fi
    cluster_stage_squad_runtime \
        "$bench_squad_output_dir/vectors.bin" \
        "$bench_squad_output_dir/queries.bin" \
        "$squad_metadata_path"

    squad_sequential_output="$cluster_internal_dir/faiss_squad_sequential_topk.csv"
    squad_parallel_output="$cluster_internal_dir/faiss_squad_parallel_topk.csv"
    squad_parallel_metrics="$cluster_internal_dir/faiss_squad_parallel_metrics.csv"
    squad_parallel_run_metrics="$cluster_internal_dir/faiss_squad_parallel_run_metrics.csv"

    run_sequential_retriever \
        "$cluster_squad_vectors_runtime" \
        "$cluster_squad_queries_runtime" \
        "$K" \
        "$squad_sequential_output"

    cluster_run_parallel_retriever \
        "$cluster_p_total" \
        "$cluster_squad_vectors_runtime" \
        "$cluster_squad_queries_runtime" \
        "$K" \
        "$squad_parallel_output" \
        "$squad_parallel_metrics" \
        "$squad_parallel_run_metrics"

    "$BENCH_PHASE8_PYTHON" "$script_dir/faiss_compare.py" \
        --dataset-name squad_minilm \
        --vectors "$cluster_squad_vectors_runtime" \
        --queries "$cluster_squad_queries_runtime" \
        --topk "$K" \
        --threads "$cluster_faiss_threads" \
        --output-topk "$bench_faiss_results_dir/squad_topk.csv" \
        --output-metrics "$bench_faiss_results_dir/squad_run_metrics.csv"

    "$bench_build_dir/verify_results" \
        --sequential "$squad_sequential_output" \
        --parallel "$bench_faiss_results_dir/squad_topk.csv" \
        --epsilon "$EPSILON" \
        --output "$bench_faiss_results_dir/squad_correctness.csv"

    "$bench_python_stdlib" "$script_dir/benchmark_csv.py" \
        build-faiss-comparison \
        --output "$bench_faiss_results_dir/comparison.csv" \
        --parallel-metrics "$bench_results_dir/parallel_run_metrics.csv" \
        --faiss-metrics "$bench_faiss_results_dir/synthetic_run_metrics.csv" \
        --correctness "$bench_faiss_results_dir/synthetic_correctness.csv" \
        --parallel-metrics "$squad_parallel_run_metrics" \
        --faiss-metrics "$bench_faiss_results_dir/squad_run_metrics.csv" \
        --correctness "$bench_faiss_results_dir/squad_correctness.csv"
}

stage_postprocess() {
    echo "Stage 6/6: postprocess"

    bash "$script_dir/run_cluster_postprocess.sh" \
        --results-dir "$bench_results_dir" \
        --docs-output "$CLUSTER_DOCS_OUTPUT"
}

stage_runtime_calibration
stage_selected_synthetic_run
stage_granularity
stage_speedup
stage_faiss
stage_postprocess

echo "Cluster bundle completed at $bench_results_dir"
