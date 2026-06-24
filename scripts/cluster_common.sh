#!/bin/sh

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$script_dir/benchmark_common.sh"

cluster_die() {
    echo "$1" >&2
    exit 1
}

cluster_require_file() {
    path=$1
    if [ ! -f "$path" ]; then
        cluster_die "Missing required file: $path"
    fi
}

cluster_require_dir() {
    path=$1
    if [ ! -d "$path" ]; then
        cluster_die "Missing required directory: $path"
    fi
}

cluster_append_unique_value() {
    value=$1
    existing=${2:-}

    for item in $existing; do
        if [ "$item" = "$value" ]; then
            echo "$existing"
            return 0
        fi
    done

    if [ -n "$existing" ]; then
        echo "$existing $value"
    else
        echo "$value"
    fi
}

cluster_default_p_list() {
    local_slots=$1
    total_slots=$2
    values=""

    for candidate in 2 4 8 "$local_slots" $((local_slots + 2)) "$total_slots"; do
        if [ "$candidate" -ge 2 ] 2>/dev/null && [ "$candidate" -le "$total_slots" ] 2>/dev/null; then
            values=$(cluster_append_unique_value "$candidate" "$values")
        fi
    done

    echo "$values"
}

cluster_strip_user_from_host() {
    target=$1
    case "$target" in
        *@*)
            echo "${target#*@}"
            ;;
        *)
            echo "$target"
            ;;
    esac
}

cluster_is_mounted_repo() {
    case "$repo_root" in
        /mnt/*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

cluster_validate_head_checkout() {
    if cluster_is_mounted_repo; then
        cluster_die "Cluster execution requires a WSL-native head-node checkout, not a /mnt/... mounted repo: $repo_root"
    fi
}

cluster_validate_runtime_root() {
    case "$cluster_runtime_root" in
        "$repo_root"/*)
            ;;
        *)
            cluster_die "CLUSTER_RUNTIME_ROOT must stay under the head-node repo checkout: $cluster_runtime_root"
            ;;
    esac
}

cluster_setup_bundle_env() {
    config_path=$1
    run_tag_override=${2:-}

    cluster_require_file "$config_path"

    # shellcheck disable=SC1090
    . "$config_path"

    : "${CLUSTER_HOSTFILE:?CLUSTER_HOSTFILE is required}"
    : "${CLUSTER_WORKER_HOST:?CLUSTER_WORKER_HOST is required}"
    : "${CLUSTER_WORKER_REPO_ROOT:?CLUSTER_WORKER_REPO_ROOT is required}"
    : "${CLUSTER_SERVER_SLOTS:?CLUSTER_SERVER_SLOTS is required}"
    : "${CLUSTER_HEAD_LAN_CIDR:?CLUSTER_HEAD_LAN_CIDR is required}"

    cluster_require_file "$CLUSTER_HOSTFILE"

    cluster_run_tag_prefix=${CLUSTER_RUN_TAG_PREFIX:-local-plus-199}
    if [ -n "$run_tag_override" ]; then
        cluster_run_tag=$run_tag_override
    else
        cluster_run_tag="$(date +%F)-${cluster_run_tag_prefix}-full-bundle"
    fi

    if [ -n "${CLUSTER_RESULTS_ROOT:-}" ]; then
        cluster_results_root=$CLUSTER_RESULTS_ROOT
    elif [ -n "${BENCH_RESULTS_DIR:-}" ]; then
        cluster_results_root=$BENCH_RESULTS_DIR
    elif [ -n "${BENCH_STORAGE_ROOT:-}" ]; then
        cluster_results_root="${BENCH_STORAGE_ROOT}/results"
    else
        cluster_results_root="$repo_root/results"
    fi
    case "$(basename "$cluster_results_root")" in
        cluster)
            export BENCH_RESULTS_DIR="${cluster_results_root}/${cluster_run_tag}"
            ;;
        *)
            export BENCH_RESULTS_DIR="${cluster_results_root}/cluster/${cluster_run_tag}"
            ;;
    esac

    if [ -n "${CLUSTER_SCRATCH_ROOT:-}" ]; then
        cluster_scratch_root=$CLUSTER_SCRATCH_ROOT
    elif [ -n "${BENCH_SCRATCH_DIR:-}" ]; then
        cluster_scratch_root=$BENCH_SCRATCH_DIR
    elif [ -n "${BENCH_STORAGE_ROOT:-}" ]; then
        cluster_scratch_root="${BENCH_STORAGE_ROOT}/scratch/cluster_bundle"
    else
        cluster_scratch_root="$repo_root/.cache/cluster_bundle"
    fi
    export BENCH_SCRATCH_DIR="${cluster_scratch_root}/${cluster_run_tag}"
    export BENCH_BUILD_DIR="${BENCH_BUILD_DIR:-"$repo_root/build/release"}"
    export BENCH_FAISS_RESULTS_DIR="${BENCH_RESULTS_DIR}/faiss"
    export CLUSTER_DOCS_OUTPUT="${CLUSTER_DOCS_OUTPUT:-"$repo_root/docs/analysis/latest-cluster-benchmark-review.md"}"
    if [ -n "${BENCH_STORAGE_ROOT:-}" ]; then
        export BENCH_PLOT_VENV_DIR="${BENCH_PLOT_VENV_DIR:-${BENCH_STORAGE_ROOT}/.venv}"
        export BENCH_SQUAD_OUTPUT_DIR="${BENCH_SQUAD_OUTPUT_DIR:-${BENCH_STORAGE_ROOT}/real_corpora/squad_minilm}"
    fi

    init_benchmark_env
    ensure_benchmark_dirs

    cluster_local_slots=$(detect_physical_cores)
    cluster_server_slots=$CLUSTER_SERVER_SLOTS
    cluster_p_total=$((cluster_local_slots + cluster_server_slots))
    cluster_faiss_threads=$cluster_local_slots
    cluster_head_mpi_host=${CLUSTER_HEAD_MPI_HOST:-rag-head}
    cluster_worker_mpi_host=${CLUSTER_WORKER_MPI_HOST:-$(cluster_strip_user_from_host "$CLUSTER_WORKER_HOST")}
    cluster_hostfile_dir="${bench_scratch_dir}/hostfiles"
    cluster_probe_dir="${bench_scratch_dir}/probes"
    cluster_internal_dir="${bench_scratch_dir}/internal"
    cluster_runtime_root=${CLUSTER_RUNTIME_ROOT:-"$repo_root/.cache/cluster_runtime"}
    cluster_validate_runtime_root
    cluster_runtime_dir="${cluster_runtime_root}/${cluster_run_tag}"
    cluster_data_dir="${cluster_runtime_dir}/datasets"
    cluster_synthetic_data_dir="${cluster_data_dir}/synthetic"
    cluster_squad_data_dir="${cluster_data_dir}/squad_minilm"
    cluster_synthetic_memory_runtime="${cluster_synthetic_data_dir}/memory_vectors.bin"
    cluster_synthetic_query_runtime="${cluster_synthetic_data_dir}/query_vectors.bin"
    cluster_squad_vectors_runtime="${cluster_squad_data_dir}/vectors.bin"
    cluster_squad_queries_runtime="${cluster_squad_data_dir}/queries.bin"
    cluster_squad_metadata_runtime="${cluster_squad_data_dir}/metadata.tsv"
    cluster_analysis_dir="${bench_results_dir}/analysis"

    mkdir -p "$cluster_hostfile_dir" "$cluster_probe_dir" "$cluster_internal_dir" "$cluster_synthetic_data_dir" "$cluster_squad_data_dir" "$cluster_analysis_dir"

    if [ -z "${BENCH_P_LIST:-}" ]; then
        export BENCH_P_LIST="$(cluster_default_p_list "$cluster_local_slots" "$cluster_p_total")"
    fi

    export BENCH_P_SELECTED="$cluster_p_total"
    bench_p_selected=$cluster_p_total
    export bench_p_selected
    export cluster_run_tag
    export cluster_results_root
    export cluster_scratch_root
    export cluster_local_slots
    export cluster_server_slots
    export cluster_p_total
    export cluster_faiss_threads
    export cluster_head_mpi_host
    export cluster_worker_mpi_host
    export cluster_hostfile_dir
    export cluster_probe_dir
    export cluster_internal_dir
    export cluster_runtime_root
    export cluster_runtime_dir
    export cluster_data_dir
    export cluster_synthetic_data_dir
    export cluster_squad_data_dir
    export cluster_synthetic_memory_runtime
    export cluster_synthetic_query_runtime
    export cluster_squad_vectors_runtime
    export cluster_squad_queries_runtime
    export cluster_squad_metadata_runtime
    export cluster_analysis_dir
}

cluster_require_bundle_runtime() {
    require_command bash
    require_command python3
    require_command ssh
    require_command rsync
    require_command mpirun

    require_benchmark_binary generate_vectors
    require_benchmark_binary generate_queries
    require_benchmark_binary sequential_retriever
    require_benchmark_binary parallel_retriever
    require_benchmark_binary verify_results
}

cluster_relative_repo_path() {
    absolute_path=$1
    case "$absolute_path" in
        "$repo_root"/*)
            echo "${absolute_path#$repo_root/}"
            ;;
        *)
            cluster_die "Expected repo-local path under $repo_root but got $absolute_path"
            ;;
    esac
}

cluster_sync_repo_path() {
    absolute_path=$1
    relative_path=$(cluster_relative_repo_path "$absolute_path")
    remote_path="${CLUSTER_WORKER_REPO_ROOT}/${relative_path}"
    remote_dir=$(dirname "$remote_path")

    ssh "$CLUSTER_WORKER_HOST" "mkdir -p '$remote_dir'"
    rsync -a "$absolute_path" "${CLUSTER_WORKER_HOST}:${remote_path}"
}

cluster_sync_repo_dir() {
    absolute_dir=$1
    relative_path=$(cluster_relative_repo_path "$absolute_dir")
    remote_dir="${CLUSTER_WORKER_REPO_ROOT}/${relative_path}"

    ssh "$CLUSTER_WORKER_HOST" "mkdir -p '$remote_dir'"
    rsync -a "${absolute_dir}/" "${CLUSTER_WORKER_HOST}:${remote_dir}/"
}

cluster_stage_runtime_file() {
    source_path=$1
    runtime_path=$2

    cluster_require_file "$source_path"

    runtime_relative_path=$(cluster_relative_repo_path "$runtime_path")
    remote_path="${CLUSTER_WORKER_REPO_ROOT}/${runtime_relative_path}"
    runtime_dir=$(dirname "$runtime_path")
    remote_dir=$(dirname "$remote_path")

    mkdir -p "$runtime_dir"
    rm -f "$runtime_path"
    ln -s "$source_path" "$runtime_path"

    ssh "$CLUSTER_WORKER_HOST" "mkdir -p '$remote_dir'"
    rsync -aL "$runtime_path" "${CLUSTER_WORKER_HOST}:${remote_path}"
}

cluster_stage_synthetic_runtime() {
    memory_source_path=$1
    query_source_path=$2

    cluster_stage_runtime_file "$memory_source_path" "$cluster_synthetic_memory_runtime"
    cluster_stage_runtime_file "$query_source_path" "$cluster_synthetic_query_runtime"
}

cluster_stage_squad_runtime() {
    vectors_source_path=$1
    queries_source_path=$2
    metadata_source_path=${3:-}

    cluster_stage_runtime_file "$vectors_source_path" "$cluster_squad_vectors_runtime"
    cluster_stage_runtime_file "$queries_source_path" "$cluster_squad_queries_runtime"

    if [ -n "$metadata_source_path" ] && [ -f "$metadata_source_path" ]; then
        cluster_stage_runtime_file "$metadata_source_path" "$cluster_squad_metadata_runtime"
    fi
}

cluster_write_hostfile_for_p() {
    requested_process_count=$1
    hostfile_output_path=$2

    if [ "$requested_process_count" -lt 1 ] 2>/dev/null; then
        cluster_die "process_count must be positive"
    fi
    if [ "$requested_process_count" -gt "$cluster_p_total" ] 2>/dev/null; then
        cluster_die "process_count=$requested_process_count exceeds cluster_p_total=$cluster_p_total"
    fi

    head_slots=$cluster_local_slots
    worker_slots=0

    if [ "$requested_process_count" -le "$cluster_local_slots" ] 2>/dev/null; then
        head_slots=$requested_process_count
    else
        worker_slots=$((requested_process_count - cluster_local_slots))
    fi

    mkdir -p "$(dirname "$hostfile_output_path")"
    {
        echo "${cluster_head_mpi_host} slots=${head_slots} max-slots=${head_slots}"
        if [ "$worker_slots" -gt 0 ] 2>/dev/null; then
            echo "${cluster_worker_mpi_host} slots=${worker_slots} max-slots=${worker_slots}"
        fi
    } > "$hostfile_output_path"
}

cluster_run_parallel_retriever() {
    process_count=$1
    vectors_path=$2
    queries_path=$3
    topk_value=$4
    output_path=$5
    metrics_path=$6
    run_metrics_path=${7:-}

    hostfile_path="${cluster_hostfile_dir}/p${process_count}.hosts"
    cluster_write_hostfile_for_p "$process_count" "$hostfile_path"

    if [ -n "$run_metrics_path" ]; then
        env HWLOC_COMPONENTS=-gl \
            mpirun \
            -x HWLOC_COMPONENTS \
            --mca oob_tcp_disable_ipv6_family 1 \
            --mca oob_tcp_if_include "$CLUSTER_HEAD_LAN_CIDR" \
            --mca btl self,tcp \
            --mca btl_tcp_if_include "$CLUSTER_HEAD_LAN_CIDR" \
            --hostfile "$hostfile_path" \
            --map-by slot \
            -np "$process_count" \
            "$bench_build_dir/parallel_retriever" \
            --vectors "$vectors_path" \
            --queries "$queries_path" \
            --topk "$topk_value" \
            --output "$output_path" \
            --metrics "$metrics_path" \
            --run-metrics "$run_metrics_path"
    else
        env HWLOC_COMPONENTS=-gl \
            mpirun \
            -x HWLOC_COMPONENTS \
            --mca oob_tcp_disable_ipv6_family 1 \
            --mca oob_tcp_if_include "$CLUSTER_HEAD_LAN_CIDR" \
            --mca btl self,tcp \
            --mca btl_tcp_if_include "$CLUSTER_HEAD_LAN_CIDR" \
            --hostfile "$hostfile_path" \
            --map-by slot \
            -np "$process_count" \
            "$bench_build_dir/parallel_retriever" \
            --vectors "$vectors_path" \
            --queries "$queries_path" \
            --topk "$topk_value" \
            --output "$output_path" \
            --metrics "$metrics_path"
    fi
}

cluster_print_bundle_summary() {
    echo "run_tag=$cluster_run_tag"
    echo "cluster_results_dir=$bench_results_dir"
    echo "cluster_scratch_dir=$bench_scratch_dir"
    echo "cluster_runtime_dir=$cluster_runtime_dir"
    echo "cluster_p_total=$cluster_p_total"
    echo "cluster_faiss_threads=$cluster_faiss_threads"
    echo "cluster_hostfile=$CLUSTER_HOSTFILE"
    if [ -n "${bench_storage_root:-}" ]; then
        echo "bench_storage_root=$bench_storage_root"
    fi
}

cluster_print_dry_run_plan() {
    cluster_print_bundle_summary
    if cluster_is_mounted_repo; then
        echo "warning: current repo_root is mounted ($repo_root); real cluster execution should run from a WSL-native checkout."
    fi
    echo "Stage 1/6: runtime calibration"
    echo "Stage 2/6: selected synthetic correctness run"
    echo "Stage 3/6: granularity summary"
    echo "Stage 4/6: speedup sweep"
    echo "Stage 5/6: FAISS comparisons"
    echo "Stage 6/6: postprocess"
    echo "dry-run: no cluster commands executed"
}
