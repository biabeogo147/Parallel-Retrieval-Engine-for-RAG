#!/bin/sh

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
bash "$script_dir/common.sh"

detect_physical_cores() {
    if command -v lscpu >/dev/null 2>&1; then
        count=$(lscpu -p=Core,Socket 2>/dev/null | grep -v '^#' | sort -u | wc -l | tr -d ' ')
        if [ -n "$count" ] && [ "$count" -ge 1 ] 2>/dev/null; then
            echo "$count"
            return 0
        fi
    fi

    count=$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)
    if [ -z "$count" ] || [ "$count" -lt 1 ] 2>/dev/null; then
        count=1
    fi
    echo "$count"
}

list_contains_value() {
    needle=$1
    shift
    for value in "$@"; do
        if [ "$value" = "$needle" ]; then
            return 0
        fi
    done
    return 1
}

generate_default_p_list() {
    physical_cores=$1
    result="1"
    current=2

    while [ "$current" -lt "$physical_cores" ]; do
        result="$result $current"
        current=$((current * 2))
    done

    set -- $result
    if ! list_contains_value "$physical_cores" "$@"; then
        result="$result $physical_cores"
    fi

    double_physical=$((physical_cores * 2))
    set -- $result
    if ! list_contains_value "$double_physical" "$@"; then
        result="$result $double_physical"
    fi

    echo "$result"
}

init_benchmark_env() {
    require_command python3
    require_command mpirun

    bench_storage_root=${BENCH_STORAGE_ROOT:-}
    if [ -n "$bench_storage_root" ]; then
        default_results_dir="${bench_storage_root}/results"
        default_scratch_dir="${bench_storage_root}/scratch"
        default_plot_venv_dir="${bench_storage_root}/.venv"
        default_squad_output_dir="${bench_storage_root}/real_corpora/squad_minilm"
    else
        default_results_dir="$repo_root/results"
        default_scratch_dir="$repo_root/.cache/benchmarks"
        default_plot_venv_dir="$repo_root/.venv"
        default_squad_output_dir="$repo_root/.cache/real_corpora/squad_minilm"
    fi

    bench_build_dir=${BENCH_BUILD_DIR:-"$repo_root/build/debug"}
    bench_results_dir=${BENCH_RESULTS_DIR:-"$default_results_dir"}
    bench_scratch_dir=${BENCH_SCRATCH_DIR:-"$default_scratch_dir"}
    bench_figures_dir="${bench_results_dir}/figures"
    bench_faiss_results_dir=${BENCH_FAISS_RESULTS_DIR:-"${bench_results_dir}/faiss"}
    bench_d=${BENCH_D:-384}
    bench_q=${BENCH_Q:-100}
    bench_q_candidates=${BENCH_Q_CANDIDATES:-"150 200 250 300 400 500 600"}
    bench_topk=${BENCH_TOPK:-10}
    bench_epsilon=${BENCH_EPSILON:-1e-5}
    bench_n_candidates=${BENCH_N_CANDIDATES:-"4000000 6000000 8000000 10000000"}
    bench_speedup_n_candidates=${BENCH_SPEEDUP_N_CANDIDATES:-"2000000 3000000 4000000 5000000"}
    bench_speedup_baseline_limit=${BENCH_SPEEDUP_BASELINE_LIMIT:-600}
    bench_p_selected=${BENCH_P_SELECTED:-$(detect_physical_cores)}
    bench_p_list=${BENCH_P_LIST:-$(generate_default_p_list "$bench_p_selected")}
    selection_env_path="${bench_results_dir}/benchmark_selection.env"
    bench_plot_venv_dir=${BENCH_PLOT_VENV_DIR:-"$default_plot_venv_dir"}
    bench_python_stdlib=${BENCH_PYTHON_STDLIB:-python3}
    bench_squad_input_dir=${BENCH_SQUAD_INPUT_DIR:-/mnt/e/data/squad/plain_text}
    bench_squad_output_dir=${BENCH_SQUAD_OUTPUT_DIR:-"$default_squad_output_dir"}
    bench_squad_model=${BENCH_SQUAD_MODEL:-sentence-transformers/all-MiniLM-L6-v2}
    bench_squad_queries_limit=${BENCH_SQUAD_QUERIES_LIMIT:-100}

    export bench_storage_root
    export bench_build_dir
    export bench_results_dir
    export bench_scratch_dir
    export bench_figures_dir
    export bench_faiss_results_dir
    export bench_d
    export bench_q
    export bench_q_candidates
    export bench_topk
    export bench_epsilon
    export bench_n_candidates
    export bench_speedup_n_candidates
    export bench_speedup_baseline_limit
    export bench_p_selected
    export bench_p_list
    export selection_env_path
    export bench_plot_venv_dir
    export bench_python_stdlib
    export bench_squad_input_dir
    export bench_squad_output_dir
    export bench_squad_model
    export bench_squad_queries_limit
}

ensure_benchmark_dirs() {
    mkdir -p "$bench_results_dir" "$bench_scratch_dir" "$bench_figures_dir" "$bench_faiss_results_dir"
}

selection_manifest_is_complete() {
    manifest_path=${1:-"$selection_env_path"}
    if [ ! -f "$manifest_path" ]; then
        return 1
    fi

    for required_name in N_SELECTED N_SPEEDUP P_SELECTED D Q K EPSILON CALIBRATION_MODE N_MAX_FEASIBLE; do
        if ! grep -Eq "^${required_name}=.+" "$manifest_path"; then
            return 1
        fi
    done

    return 0
}

require_benchmark_binary() {
    binary_name=$1
    binary_path="$bench_build_dir/$binary_name"
    if [ ! -x "$binary_path" ]; then
        echo "Missing required benchmark binary: $binary_path" >&2
        exit 1
    fi
}

query_dataset_path() {
    query_dataset_path_for_q "$bench_q"
}

query_dataset_path_for_q() {
    query_q=$1
    echo "$bench_scratch_dir/query_vectors_Q${query_q}_D${bench_d}.bin"
}

memory_dataset_path() {
    memory_n=$1
    echo "$bench_scratch_dir/memory_vectors_N${memory_n}_D${bench_d}.bin"
}

ensure_query_dataset() {
    query_path=$1
    ensure_query_dataset_for_q "$bench_q" "$query_path"
}

ensure_query_dataset_for_q() {
    query_q=$1
    query_path=$2
    if [ ! -f "$query_path" ]; then
        "$bench_build_dir/generate_queries" \
            --Q "$query_q" \
            --D "$bench_d" \
            --output "$query_path"
    fi
}

ensure_memory_dataset() {
    memory_n=$1
    memory_path=$2
    if [ ! -f "$memory_path" ]; then
        "$bench_build_dir/generate_vectors" \
            --N "$memory_n" \
            --D "$bench_d" \
            --output "$memory_path"
    fi
}

run_mpirun() {
    np=$1
    shift

    if [ "$(id -u)" -eq 0 ]; then
        OMPI_ALLOW_RUN_AS_ROOT=1 \
        OMPI_ALLOW_RUN_AS_ROOT_CONFIRM=1 \
        mpirun --oversubscribe -np "$np" "$@"
    else
        mpirun --oversubscribe -np "$np" "$@"
    fi
}

run_sequential_retriever() {
    vectors_path=$1
    queries_path=$2
    topk_value=$3
    output_path=$4
    run_metrics_path=${5:-}

    if [ -n "$run_metrics_path" ]; then
        "$bench_build_dir/sequential_retriever" \
            --vectors "$vectors_path" \
            --queries "$queries_path" \
            --topk "$topk_value" \
            --output "$output_path" \
            --run-metrics "$run_metrics_path"
    else
        "$bench_build_dir/sequential_retriever" \
            --vectors "$vectors_path" \
            --queries "$queries_path" \
            --topk "$topk_value" \
            --output "$output_path"
    fi
}

run_parallel_retriever() {
    process_count=$1
    vectors_path=$2
    queries_path=$3
    topk_value=$4
    output_path=$5
    metrics_path=$6
    run_metrics_path=${7:-}

    if [ -n "$run_metrics_path" ]; then
        run_mpirun "$process_count" \
            "$bench_build_dir/parallel_retriever" \
            --vectors "$vectors_path" \
            --queries "$queries_path" \
            --topk "$topk_value" \
            --output "$output_path" \
            --metrics "$metrics_path" \
            --run-metrics "$run_metrics_path"
    else
        run_mpirun "$process_count" \
            "$bench_build_dir/parallel_retriever" \
            --vectors "$vectors_path" \
            --queries "$queries_path" \
            --topk "$topk_value" \
            --output "$output_path" \
            --metrics "$metrics_path"
    fi
}

load_selection_env() {
    if [ ! -f "$selection_env_path" ]; then
        echo "Missing benchmark selection manifest: $selection_env_path" >&2
        exit 1
    fi

    # shellcheck disable=SC1090
    . "$selection_env_path"

    for required_name in N_SELECTED N_SPEEDUP P_SELECTED D Q K EPSILON CALIBRATION_MODE N_MAX_FEASIBLE; do
        eval "required_value=\${${required_name}:-}"
        if [ -z "$required_value" ]; then
            echo "Missing required benchmark selection value: $required_name" >&2
            exit 1
        fi
    done

    if [ -n "${D:-}" ]; then
        bench_d=$D
    fi
    if [ -n "${Q:-}" ]; then
        bench_q=$Q
    fi
    if [ -n "${K:-}" ]; then
        bench_topk=$K
    fi
    if [ -n "${EPSILON:-}" ]; then
        bench_epsilon=$EPSILON
    fi
    if [ -n "${P_SELECTED:-}" ]; then
        bench_p_selected=$P_SELECTED
    fi

    export bench_d
    export bench_q
    export bench_topk
    export bench_epsilon
    export bench_p_selected
    export CALIBRATION_MODE
    export N_MAX_FEASIBLE
}

ensure_plot_python() {
    if [ ! -x "$bench_plot_venv_dir/bin/python" ]; then
        python3 -m venv "$bench_plot_venv_dir"
    fi

    if ! "$bench_plot_venv_dir/bin/python" -c "import matplotlib" >/dev/null 2>&1; then
        "$bench_plot_venv_dir/bin/python" -m pip install --upgrade pip >/dev/null
        "$bench_plot_venv_dir/bin/python" -m pip install -r "$script_dir/requirements-benchmark.txt" >/dev/null
    fi

    BENCH_PLOT_PYTHON="$bench_plot_venv_dir/bin/python"
    export BENCH_PLOT_PYTHON
}

ensure_phase8_python() {
    mode=${1:-faiss}

    if [ ! -x "$bench_plot_venv_dir/bin/python" ]; then
        python3 -m venv "$bench_plot_venv_dir"
    fi

    if [ "$mode" = "real" ]; then
        import_check="import faiss, numpy, pyarrow, sentence_transformers"
        requirements_file="$script_dir/requirements-phase8.txt"
    else
        import_check="import faiss, numpy"
        requirements_file="$script_dir/requirements-faiss.txt"
    fi

    if ! "$bench_plot_venv_dir/bin/python" -c "$import_check" >/dev/null 2>&1; then
        "$bench_plot_venv_dir/bin/python" -m pip install --upgrade pip >/dev/null
        "$bench_plot_venv_dir/bin/python" -m pip install -r "$requirements_file" >/dev/null
    fi

    BENCH_PHASE8_PYTHON="$bench_plot_venv_dir/bin/python"
    export BENCH_PHASE8_PYTHON
}
