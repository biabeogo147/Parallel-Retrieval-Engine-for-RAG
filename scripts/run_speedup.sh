#!/bin/sh

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$script_dir/benchmark_common.sh"

init_benchmark_env
ensure_benchmark_dirs
if ! selection_manifest_is_complete "$selection_env_path"; then
    bash "$script_dir/run_calibrate_target.sh"
fi
load_selection_env

require_benchmark_binary generate_vectors
require_benchmark_binary generate_queries
require_benchmark_binary sequential_retriever
require_benchmark_binary parallel_retriever

query_path=$(query_dataset_path)
ensure_query_dataset "$query_path"

memory_path=$(memory_dataset_path "$N_SPEEDUP")
ensure_memory_dataset "$N_SPEEDUP" "$memory_path"

sequential_output="$bench_scratch_dir/speedup_sequential_topk.csv"
baseline_metrics="$bench_scratch_dir/speedup_sequential_run_metrics.csv"
run_sequential_retriever \
    "$memory_path" \
    "$query_path" \
    "$K" \
    "$sequential_output" \
    "$baseline_metrics"

parallel_metric_files=""
for process_count in $bench_p_list; do
    if [ "$process_count" -eq 1 ]; then
        continue
    fi

    parallel_output="$bench_scratch_dir/speedup_parallel_topk_P${process_count}.csv"
    parallel_metrics="$bench_scratch_dir/speedup_parallel_metrics_P${process_count}.csv"
    parallel_run_metrics="$bench_scratch_dir/speedup_parallel_run_metrics_P${process_count}.csv"

    run_parallel_retriever \
        "$process_count" \
        "$memory_path" \
        "$query_path" \
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

echo "Wrote $bench_results_dir/speedup.csv"
