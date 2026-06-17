#!/bin/sh

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$script_dir/benchmark_common.sh"

init_benchmark_env
ensure_benchmark_dirs
if ! selection_manifest_is_complete "$selection_env_path"; then
    "$script_dir/run_calibrate_target.sh"
fi
load_selection_env

require_benchmark_binary generate_vectors
require_benchmark_binary generate_queries
require_benchmark_binary parallel_retriever

query_path=$(query_dataset_path)
ensure_query_dataset "$query_path"

memory_path=$(memory_dataset_path "$N_SELECTED")
ensure_memory_dataset "$N_SELECTED" "$memory_path"

parallel_output="$bench_scratch_dir/granularity_parallel_topk.csv"
granularity_output="$bench_results_dir/granularity.csv"
granularity_summary="$bench_results_dir/granularity_summary.txt"

run_parallel_retriever \
    "$P_SELECTED" \
    "$memory_path" \
    "$query_path" \
    "$K" \
    "$parallel_output" \
    "$granularity_output"

"$bench_python_stdlib" "$script_dir/benchmark_csv.py" \
    summarize-granularity \
    --input "$granularity_output" \
    --output "$granularity_summary"

cat "$granularity_summary"
