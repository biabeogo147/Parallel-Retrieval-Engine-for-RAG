#!/bin/sh

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
bash "$script_dir/benchmark_common.sh"

results_dir=
docs_output="$repo_root/docs/analysis/latest-cluster-benchmark-review.md"
dry_run=0

while [ "$#" -gt 0 ]; do
    case "$1" in
        --results-dir)
            results_dir=$2
            shift 2
            ;;
        --docs-output)
            docs_output=$2
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

if [ -z "$results_dir" ]; then
    echo "--results-dir is required" >&2
    exit 1
fi

require_command python3

export BENCH_RESULTS_DIR="$results_dir"
init_benchmark_env
ensure_benchmark_dirs

if [ "$dry_run" -eq 1 ] 2>/dev/null; then
    echo "cluster_postprocess_results_dir=$results_dir"
    echo "cluster_postprocess_docs_output=$docs_output"
    echo "\"$script_dir/plot_results.py\" --results-dir \"$results_dir\""
    echo "\"$script_dir/analyze_benchmarks.py\" --results-dir \"$results_dir\" --output-dir \"$results_dir/analysis\" --docs-output \"$docs_output\""
    echo "dry-run: no postprocess commands executed"
    exit 0
fi

cluster_require_input() {
    path=$1
    if [ ! -f "$path" ]; then
        echo "Missing required cluster postprocess input: $path" >&2
        exit 1
    fi
}

cluster_require_input "$results_dir/runtime_by_N.csv"
cluster_require_input "$results_dir/correctness.csv"
cluster_require_input "$results_dir/granularity.csv"
cluster_require_input "$results_dir/speedup.csv"
cluster_require_input "$results_dir/benchmark_selection.env"

ensure_plot_python
"$BENCH_PLOT_PYTHON" "$script_dir/plot_results.py" --results-dir "$results_dir"

"$bench_python_stdlib" "$script_dir/analyze_benchmarks.py" \
    --results-dir "$results_dir" \
    --output-dir "$results_dir/analysis" \
    --docs-output "$docs_output"

echo "Wrote $results_dir/figures"
echo "Wrote $results_dir/analysis"
echo "Wrote $docs_output"
