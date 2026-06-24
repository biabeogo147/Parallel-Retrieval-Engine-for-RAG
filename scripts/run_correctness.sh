#!/bin/sh

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
bash "$script_dir/benchmark_common.sh"

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
require_benchmark_binary verify_results

query_path=$(query_dataset_path)
ensure_query_dataset "$query_path"

memory_path=$(memory_dataset_path "$N_SELECTED")
ensure_memory_dataset "$N_SELECTED" "$memory_path"

sequential_output="$bench_results_dir/sequential_topk.csv"
parallel_output="$bench_results_dir/parallel_topk.csv"
parallel_metrics_path="$bench_scratch_dir/correctness_parallel_metrics.csv"
correctness_output="$bench_results_dir/correctness.csv"

run_sequential_retriever \
    "$memory_path" \
    "$query_path" \
    "$K" \
    "$sequential_output"

run_parallel_retriever \
    "$P_SELECTED" \
    "$memory_path" \
    "$query_path" \
    "$K" \
    "$parallel_output" \
    "$parallel_metrics_path"

"$bench_build_dir/verify_results" \
    --sequential "$sequential_output" \
    --parallel "$parallel_output" \
    --epsilon "$EPSILON" \
    --output "$correctness_output"

echo "Wrote $correctness_output"
