#!/bin/sh

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
bash "$script_dir/benchmark_common.sh"

init_benchmark_env
ensure_benchmark_dirs

bash "$script_dir/run_calibrate_target.sh"
bash "$script_dir/run_correctness.sh"
bash "$script_dir/run_granularity.sh"
bash "$script_dir/run_speedup.sh"

ensure_plot_python
"$BENCH_PLOT_PYTHON" "$script_dir/plot_results.py" --results-dir "$bench_results_dir"

echo "Benchmark automation completed."
