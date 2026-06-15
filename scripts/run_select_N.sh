#!/bin/sh

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$script_dir/benchmark_common.sh"

init_benchmark_env
ensure_benchmark_dirs

require_benchmark_binary generate_vectors
require_benchmark_binary generate_queries
require_benchmark_binary parallel_retriever

query_path=$(query_dataset_path)
ensure_query_dataset "$query_path"

run_metric_files=""
for memory_n in $bench_n_candidates; do
    memory_path=$(memory_dataset_path "$memory_n")
    ensure_memory_dataset "$memory_n" "$memory_path"

    output_path="$bench_scratch_dir/select_n_parallel_topk_N${memory_n}.csv"
    metrics_path="$bench_scratch_dir/select_n_parallel_metrics_N${memory_n}.csv"
    run_metrics_path="$bench_scratch_dir/select_n_parallel_run_metrics_N${memory_n}.csv"

    run_parallel_retriever \
        "$bench_p_selected" \
        "$memory_path" \
        "$query_path" \
        "$bench_topk" \
        "$output_path" \
        "$metrics_path" \
        "$run_metrics_path"

    run_metric_files="$run_metric_files $run_metrics_path"
done

set -- $run_metric_files
"$bench_python_stdlib" "$script_dir/benchmark_csv.py" \
    merge-run-metrics \
    --output "$bench_results_dir/runtime_by_N.csv" \
    "$@"

"$bench_python_stdlib" "$script_dir/benchmark_csv.py" \
    select-n \
    --input "$bench_results_dir/runtime_by_N.csv" \
    --output-env "$selection_env_path" \
    --p-selected "$bench_p_selected" \
    --epsilon "$bench_epsilon"

echo "Wrote $bench_results_dir/runtime_by_N.csv"
echo "Wrote $selection_env_path"
