#!/bin/sh

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
bash "$script_dir/benchmark_common.sh"

init_benchmark_env
ensure_benchmark_dirs

require_benchmark_binary generate_vectors
require_benchmark_binary generate_queries
require_benchmark_binary sequential_retriever
require_benchmark_binary parallel_retriever

n_runtime_path="$bench_results_dir/runtime_by_N.csv"
q_runtime_path="$bench_scratch_dir/calibration_runtime_by_Q.csv"
speedup_probe_path="$bench_scratch_dir/calibration_speedup_probes.csv"
context_env_path="$bench_scratch_dir/calibration_context.env"

base_query_path=$(query_dataset_path)
ensure_query_dataset "$base_query_path"

n_metric_files=""
n_max_feasible=""
for memory_n in $bench_n_candidates; do
    memory_path=$(memory_dataset_path "$memory_n")
    ensure_memory_dataset "$memory_n" "$memory_path"

    output_path="$bench_scratch_dir/calibration_parallel_topk_N${memory_n}.csv"
    metrics_path="$bench_scratch_dir/calibration_parallel_metrics_N${memory_n}.csv"
    run_metrics_path="$bench_scratch_dir/calibration_parallel_run_metrics_N${memory_n}.csv"

    set +e
    run_parallel_retriever \
        "$bench_p_selected" \
        "$memory_path" \
        "$base_query_path" \
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
    echo "Calibration failed: no successful N sweep rows were produced." >&2
    exit 1
fi

set -- $n_metric_files
"$bench_python_stdlib" "$script_dir/benchmark_csv.py" \
    merge-run-metrics \
    --output "$n_runtime_path" \
    "$@"

q_input_args=""
if ! "$bench_python_stdlib" "$script_dir/benchmark_csv.py" \
    row-in-target \
    --input "$n_runtime_path" \
    >/dev/null
then
    selected_memory_path=$(memory_dataset_path "$n_max_feasible")
    q_metric_files=""
    for query_q in $bench_q_candidates; do
        query_path=$(query_dataset_path_for_q "$query_q")
        ensure_query_dataset_for_q "$query_q" "$query_path"

        output_path="$bench_scratch_dir/calibration_parallel_topk_N${n_max_feasible}_Q${query_q}.csv"
        metrics_path="$bench_scratch_dir/calibration_parallel_metrics_N${n_max_feasible}_Q${query_q}.csv"
        run_metrics_path="$bench_scratch_dir/calibration_parallel_run_metrics_N${n_max_feasible}_Q${query_q}.csv"

        run_parallel_retriever \
            "$bench_p_selected" \
            "$selected_memory_path" \
            "$query_path" \
            "$bench_topk" \
            "$output_path" \
            "$metrics_path" \
            "$run_metrics_path"

        q_metric_files="$q_metric_files $run_metrics_path"
    done

    if [ -z "$q_metric_files" ]; then
        echo "Calibration failed: Q sweep was required but produced no successful rows." >&2
        exit 1
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
for speedup_n in $bench_speedup_n_candidates; do
    memory_path=$(memory_dataset_path "$speedup_n")
    ensure_memory_dataset "$speedup_n" "$memory_path"

    selected_probe_query_path=$(query_dataset_path_for_q "$Q_SELECTED")
    ensure_query_dataset_for_q "$Q_SELECTED" "$selected_probe_query_path"

    output_path="$bench_scratch_dir/calibration_speedup_topk_N${speedup_n}.csv"
    run_metrics_path="$bench_scratch_dir/calibration_speedup_run_metrics_N${speedup_n}.csv"

    set +e
    run_sequential_retriever \
        "$memory_path" \
        "$selected_probe_query_path" \
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
    echo "Calibration failed: no successful speedup baseline probes were produced." >&2
    exit 1
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
    --p-selected $bench_p_selected
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

echo "Wrote $n_runtime_path"
echo "Wrote $selection_env_path"
