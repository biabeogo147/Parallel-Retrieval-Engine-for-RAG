#!/bin/sh

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$script_dir/benchmark_common.sh"

init_benchmark_env
ensure_benchmark_dirs

require_benchmark_binary generate_vectors
require_benchmark_binary generate_queries
require_benchmark_binary sequential_retriever
require_benchmark_binary parallel_retriever
require_benchmark_binary verify_results

if ! selection_manifest_is_complete "$selection_env_path"; then
    bash "$script_dir/run_calibrate_target.sh"
fi
load_selection_env

ensure_phase8_python faiss

query_path=$(query_dataset_path)
ensure_query_dataset "$query_path"

synthetic_memory_path=$(memory_dataset_path "$N_SELECTED")
ensure_memory_dataset "$N_SELECTED" "$synthetic_memory_path"

synthetic_sequential_output="$bench_scratch_dir/faiss_synthetic_sequential_topk.csv"
synthetic_parallel_output="$bench_scratch_dir/faiss_synthetic_parallel_topk.csv"
synthetic_parallel_metrics="$bench_scratch_dir/faiss_synthetic_parallel_metrics.csv"
synthetic_parallel_run_metrics="$bench_scratch_dir/faiss_synthetic_parallel_run_metrics.csv"

run_sequential_retriever \
    "$synthetic_memory_path" \
    "$query_path" \
    "$bench_topk" \
    "$synthetic_sequential_output"

run_parallel_retriever \
    "$bench_p_selected" \
    "$synthetic_memory_path" \
    "$query_path" \
    "$bench_topk" \
    "$synthetic_parallel_output" \
    "$synthetic_parallel_metrics" \
    "$synthetic_parallel_run_metrics"

"$BENCH_PHASE8_PYTHON" "$script_dir/faiss_compare.py" \
    --dataset-name synthetic \
    --vectors "$synthetic_memory_path" \
    --queries "$query_path" \
    --topk "$bench_topk" \
    --threads "$bench_p_selected" \
    --output-topk "$bench_faiss_results_dir/synthetic_topk.csv" \
    --output-metrics "$bench_faiss_results_dir/synthetic_run_metrics.csv"

"$bench_build_dir/verify_results" \
    --sequential "$synthetic_sequential_output" \
    --parallel "$bench_faiss_results_dir/synthetic_topk.csv" \
    --epsilon "$bench_epsilon" \
    --output "$bench_faiss_results_dir/synthetic_correctness.csv"

if [ ! -f "$bench_squad_output_dir/vectors.bin" ] || [ ! -f "$bench_squad_output_dir/queries.bin" ]; then
    ensure_phase8_python real
    "$BENCH_PHASE8_PYTHON" "$script_dir/prepare_squad_minilm.py" \
        --input-dir "$bench_squad_input_dir" \
        --output-dir "$bench_squad_output_dir" \
        --model "$bench_squad_model" \
        --queries-limit "$bench_squad_queries_limit"
fi

squad_vectors_path="$bench_squad_output_dir/vectors.bin"
squad_queries_path="$bench_squad_output_dir/queries.bin"
squad_sequential_output="$bench_scratch_dir/faiss_squad_sequential_topk.csv"
squad_parallel_output="$bench_scratch_dir/faiss_squad_parallel_topk.csv"
squad_parallel_metrics="$bench_scratch_dir/faiss_squad_parallel_metrics.csv"
squad_parallel_run_metrics="$bench_scratch_dir/faiss_squad_parallel_run_metrics.csv"

run_sequential_retriever \
    "$squad_vectors_path" \
    "$squad_queries_path" \
    "$bench_topk" \
    "$squad_sequential_output"

run_parallel_retriever \
    "$bench_p_selected" \
    "$squad_vectors_path" \
    "$squad_queries_path" \
    "$bench_topk" \
    "$squad_parallel_output" \
    "$squad_parallel_metrics" \
    "$squad_parallel_run_metrics"

"$BENCH_PHASE8_PYTHON" "$script_dir/faiss_compare.py" \
    --dataset-name squad_minilm \
    --vectors "$squad_vectors_path" \
    --queries "$squad_queries_path" \
    --topk "$bench_topk" \
    --threads "$bench_p_selected" \
    --output-topk "$bench_faiss_results_dir/squad_topk.csv" \
    --output-metrics "$bench_faiss_results_dir/squad_run_metrics.csv"

"$bench_build_dir/verify_results" \
    --sequential "$squad_sequential_output" \
    --parallel "$bench_faiss_results_dir/squad_topk.csv" \
    --epsilon "$bench_epsilon" \
    --output "$bench_faiss_results_dir/squad_correctness.csv"

"$bench_python_stdlib" "$script_dir/benchmark_csv.py" \
    build-faiss-comparison \
    --output "$bench_faiss_results_dir/comparison.csv" \
    --parallel-metrics "$synthetic_parallel_run_metrics" \
    --faiss-metrics "$bench_faiss_results_dir/synthetic_run_metrics.csv" \
    --correctness "$bench_faiss_results_dir/synthetic_correctness.csv" \
    --parallel-metrics "$squad_parallel_run_metrics" \
    --faiss-metrics "$bench_faiss_results_dir/squad_run_metrics.csv" \
    --correctness "$bench_faiss_results_dir/squad_correctness.csv"

echo "Wrote $bench_faiss_results_dir/synthetic_topk.csv"
echo "Wrote $bench_faiss_results_dir/synthetic_run_metrics.csv"
echo "Wrote $bench_faiss_results_dir/synthetic_correctness.csv"
echo "Wrote $bench_faiss_results_dir/squad_topk.csv"
echo "Wrote $bench_faiss_results_dir/squad_run_metrics.csv"
echo "Wrote $bench_faiss_results_dir/squad_correctness.csv"
echo "Wrote $bench_faiss_results_dir/comparison.csv"
