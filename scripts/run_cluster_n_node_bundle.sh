#!/bin/sh

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$script_dir/cluster_n_node_common.sh"

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

nnode_setup_bundle_env "$config_path" "$run_tag_override"

if [ "$dry_run" -eq 1 ] 2>/dev/null; then
    nnode_print_dry_run_plan
    exit 0
fi

nnode_validate_head_checkout
nnode_require_bundle_runtime

stage_selected_synthetic_run() {
    echo "Stage 1/4: selected synthetic correctness run"

    cp "$cluster_selection_env_source" "$selection_env_path"
    if ! selection_manifest_is_complete "$selection_env_path"; then
        nnode_die "Missing or incomplete selection manifest: $selection_env_path"
    fi
    load_selection_env

    if [ "$P_SELECTED" -gt "$cluster_p_total" ] 2>/dev/null; then
        nnode_die "P_SELECTED=$P_SELECTED exceeds cluster_p_total=$cluster_p_total"
    fi

    cp "$CLUSTER_HOSTFILE" "$bench_results_dir/hostfile.snapshot.txt"
    cat > "$bench_results_dir/run_notes.txt" <<EOF
cluster_date=$(date +%F)
run_tag=$cluster_run_tag
head_repo_root=$repo_root
hostfile=$CLUSTER_HOSTFILE
node_count=$cluster_node_count
cluster_p_total=$cluster_p_total
selected_p=$P_SELECTED
selected_memory_path=$cluster_selected_memory_path
selected_query_path=$cluster_selected_query_path
speedup_memory_path=$cluster_speedup_memory_path
speedup_query_path=$cluster_speedup_query_path
selected_n=$N_SELECTED
speedup_n=$N_SPEEDUP
selected_q=$Q
selected_d=$D
selected_k=$K
epsilon=$EPSILON
calibration_mode=$CALIBRATION_MODE
n_max_feasible=$N_MAX_FEASIBLE
EOF

    run_sequential_retriever \
        "$cluster_selected_memory_path" \
        "$cluster_selected_query_path" \
        "$K" \
        "$bench_results_dir/sequential_topk.csv" \
        "$bench_results_dir/sequential_run_metrics.csv"

    nnode_run_parallel_retriever \
        "$P_SELECTED" \
        "$cluster_selected_memory_path" \
        "$cluster_selected_query_path" \
        "$K" \
        "$bench_results_dir/parallel_topk.csv" \
        "$bench_results_dir/parallel_metrics.csv" \
        "$bench_results_dir/parallel_run_metrics.csv"

    "$bench_build_dir/verify_results" \
        --sequential "$bench_results_dir/sequential_topk.csv" \
        --parallel "$bench_results_dir/parallel_topk.csv" \
        --epsilon "$EPSILON" \
        --output "$bench_results_dir/correctness.csv"

    cp "$bench_results_dir/parallel_run_metrics.csv" "$bench_results_dir/runtime_by_N.csv"
}

stage_granularity() {
    echo "Stage 2/4: granularity summary"

    cp "$bench_results_dir/parallel_metrics.csv" "$bench_results_dir/granularity.csv"
    "$bench_python_stdlib" "$script_dir/benchmark_csv.py" \
        summarize-granularity \
        --input "$bench_results_dir/granularity.csv" \
        --output "$bench_results_dir/granularity_summary.txt" >/dev/null
}

stage_speedup() {
    echo "Stage 3/4: speedup sweep"

    load_selection_env

    baseline_output="$cluster_internal_dir/speedup_sequential_topk.csv"
    baseline_metrics="$cluster_internal_dir/speedup_sequential_run_metrics.csv"

    run_sequential_retriever \
        "$cluster_speedup_memory_path" \
        "$cluster_speedup_query_path" \
        "$K" \
        "$baseline_output" \
        "$baseline_metrics"

    parallel_metric_files=""
    for process_count in $BENCH_P_LIST; do
        if [ "$process_count" -eq 1 ] 2>/dev/null; then
            continue
        fi
        if [ "$process_count" -gt "$cluster_p_total" ] 2>/dev/null; then
            nnode_die "Requested BENCH_P_LIST entry $process_count exceeds cluster_p_total=$cluster_p_total"
        fi

        parallel_output="$cluster_probe_dir/speedup_parallel_topk_P${process_count}.csv"
        parallel_metrics="$cluster_probe_dir/speedup_parallel_metrics_P${process_count}.csv"
        parallel_run_metrics="$cluster_probe_dir/speedup_parallel_run_metrics_P${process_count}.csv"

        nnode_run_parallel_retriever \
            "$process_count" \
            "$cluster_speedup_memory_path" \
            "$cluster_speedup_query_path" \
            "$K" \
            "$parallel_output" \
            "$parallel_metrics" \
            "$parallel_run_metrics"

        parallel_metric_files="$parallel_metric_files $parallel_run_metrics"
    done

    if [ -z "$parallel_metric_files" ]; then
        nnode_die "BENCH_P_LIST did not produce any parallel speedup rows."
    fi

    set -- $parallel_metric_files
    "$bench_python_stdlib" "$script_dir/benchmark_csv.py" \
        build-speedup \
        --baseline "$baseline_metrics" \
        --output "$bench_results_dir/speedup.csv" \
        "$@"
}

stage_postprocess() {
    echo "Stage 4/4: postprocess"

    bash "$script_dir/run_cluster_postprocess.sh" \
        --results-dir "$bench_results_dir" \
        --docs-output "$CLUSTER_DOCS_OUTPUT"
}

stage_selected_synthetic_run
stage_granularity
stage_speedup
stage_postprocess

echo "Cluster n-node bundle completed at $bench_results_dir"
