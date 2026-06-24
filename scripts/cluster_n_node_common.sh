#!/bin/sh

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$script_dir/benchmark_common.sh"

nnode_die() {
    echo "$1" >&2
    exit 1
}

nnode_require_file() {
    path=$1
    if [ ! -f "$path" ]; then
        nnode_die "Missing required file: $path"
    fi
}

nnode_append_unique_value() {
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

nnode_default_p_list() {
    echo "2 4 6 8 10 12 14 16 18 20 24 28 32"
}

nnode_is_mounted_repo() {
    case "$repo_root" in
        /mnt/*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

nnode_validate_head_checkout() {
    if nnode_is_mounted_repo; then
        nnode_die "Cluster execution requires a Linux-native head-node checkout, not a /mnt/... mounted repo: $repo_root"
    fi
}

nnode_parse_hostfile() {
    cluster_p_total=0
    cluster_node_count=0
    : > "$cluster_normalized_hostfile"

    while IFS= read -r raw_line || [ -n "$raw_line" ]; do
        line=${raw_line%%#*}
        set -- $line
        if [ "$#" -eq 0 ]; then
            continue
        fi

        host=$1
        shift
        slots=
        for token in "$@"; do
            case "$token" in
                slots=*)
                    slots=${token#slots=}
                    ;;
            esac
        done

        if [ -z "$slots" ]; then
            nnode_die "Hostfile entry is missing slots=: $raw_line"
        fi
        case "$slots" in
            ''|*[!0-9]*)
                nnode_die "Hostfile slots must be a positive integer: $raw_line"
                ;;
        esac
        if [ "$slots" -lt 1 ] 2>/dev/null; then
            nnode_die "Hostfile slots must be at least 1: $raw_line"
        fi

        printf '%s %s\n' "$host" "$slots" >> "$cluster_normalized_hostfile"
        cluster_p_total=$((cluster_p_total + slots))
        cluster_node_count=$((cluster_node_count + 1))
    done < "$CLUSTER_HOSTFILE"

    if [ "$cluster_node_count" -lt 1 ] 2>/dev/null; then
        nnode_die "Hostfile contains no usable host entries: $CLUSTER_HOSTFILE"
    fi
}

nnode_setup_bundle_env() {
    config_path=$1
    run_tag_override=${2:-}

    nnode_require_file "$config_path"

    # shellcheck disable=SC1090
    . "$config_path"

    : "${CLUSTER_HOSTFILE:?CLUSTER_HOSTFILE is required}"
    : "${CLUSTER_SELECTION_ENV:?CLUSTER_SELECTION_ENV is required}"
    : "${CLUSTER_SELECTED_MEMORY_PATH:?CLUSTER_SELECTED_MEMORY_PATH is required}"
    : "${CLUSTER_SELECTED_QUERY_PATH:?CLUSTER_SELECTED_QUERY_PATH is required}"
    : "${CLUSTER_SPEEDUP_MEMORY_PATH:?CLUSTER_SPEEDUP_MEMORY_PATH is required}"
    : "${CLUSTER_HEAD_LAN_CIDR:?CLUSTER_HEAD_LAN_CIDR is required}"

    CLUSTER_SPEEDUP_QUERY_PATH=${CLUSTER_SPEEDUP_QUERY_PATH:-"$CLUSTER_SELECTED_QUERY_PATH"}
    CLUSTER_RUNTIME_MAX_MEMORY_PATH=${CLUSTER_RUNTIME_MAX_MEMORY_PATH:-"$CLUSTER_SELECTED_MEMORY_PATH"}

    nnode_require_file "$CLUSTER_HOSTFILE"
    nnode_require_file "$CLUSTER_SELECTION_ENV"
    nnode_require_file "$CLUSTER_SELECTED_MEMORY_PATH"
    nnode_require_file "$CLUSTER_SELECTED_QUERY_PATH"
    nnode_require_file "$CLUSTER_SPEEDUP_MEMORY_PATH"
    nnode_require_file "$CLUSTER_SPEEDUP_QUERY_PATH"
    nnode_require_file "$CLUSTER_RUNTIME_MAX_MEMORY_PATH"

    if [ -z "${BENCH_P_LIST:-}" ]; then
        export BENCH_P_LIST="$(nnode_default_p_list)"
    fi

    cluster_run_tag_prefix=${CLUSTER_RUN_TAG_PREFIX:-n-node}
    if [ -n "$run_tag_override" ]; then
        cluster_run_tag=$run_tag_override
    else
        cluster_run_tag="$(date +%F)-${cluster_run_tag_prefix}-bundle"
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
    export CLUSTER_DOCS_OUTPUT="${CLUSTER_DOCS_OUTPUT:-"$repo_root/docs/analysis/latest-cluster-benchmark-review.md"}"

    init_benchmark_env
    ensure_benchmark_dirs

    cluster_hostfile_dir="${bench_scratch_dir}/hostfiles"
    cluster_probe_dir="${bench_scratch_dir}/probes"
    cluster_internal_dir="${bench_scratch_dir}/internal"
    cluster_analysis_dir="${bench_results_dir}/analysis"
    cluster_normalized_hostfile="${cluster_hostfile_dir}/normalized.hosts"
    cluster_selection_env_source=$CLUSTER_SELECTION_ENV
    cluster_selection_env_results=$selection_env_path
    cluster_selected_memory_path=$CLUSTER_SELECTED_MEMORY_PATH
    cluster_selected_query_path=$CLUSTER_SELECTED_QUERY_PATH
    cluster_speedup_memory_path=$CLUSTER_SPEEDUP_MEMORY_PATH
    cluster_speedup_query_path=$CLUSTER_SPEEDUP_QUERY_PATH
    cluster_runtime_max_memory_path=$CLUSTER_RUNTIME_MAX_MEMORY_PATH

    mkdir -p "$cluster_hostfile_dir" "$cluster_probe_dir" "$cluster_internal_dir" "$cluster_analysis_dir"
    nnode_parse_hostfile
    bench_p_list=$BENCH_P_LIST
    export bench_p_list

    export cluster_run_tag
    export cluster_results_root
    export cluster_scratch_root
    export cluster_hostfile_dir
    export cluster_probe_dir
    export cluster_internal_dir
    export cluster_analysis_dir
    export cluster_normalized_hostfile
    export cluster_selection_env_source
    export cluster_selection_env_results
    export cluster_selected_memory_path
    export cluster_selected_query_path
    export cluster_speedup_memory_path
    export cluster_speedup_query_path
    export cluster_runtime_max_memory_path
    export cluster_node_count
    export cluster_p_total
}

nnode_require_bundle_runtime() {
    require_command bash
    require_benchmark_binary sequential_retriever
    require_benchmark_binary parallel_retriever
    require_benchmark_binary verify_results
    require_benchmark_binary inspect_dataset
}

nnode_normalize_runtime_n_list() {
    raw_values=$1
    n_max_feasible=$2
    combined_values=""

    for candidate in $raw_values $n_max_feasible; do
        case "$candidate" in
            ''|*[!0-9]*)
                nnode_die "Runtime-by-N candidate must be a positive integer: $candidate"
                ;;
        esac
        if [ "$candidate" -lt 1 ] 2>/dev/null; then
            nnode_die "Runtime-by-N candidate must be positive: $candidate"
        fi
        if [ "$candidate" -le "$n_max_feasible" ] 2>/dev/null; then
            combined_values=$(nnode_append_unique_value "$candidate" "$combined_values")
        fi
    done

    if [ -z "$combined_values" ]; then
        nnode_die "Runtime-by-N sweep has no usable N values."
    fi

    printf '%s\n' $combined_values | sort -n | awk '!seen[$0]++ { values = values (values ? " " : "") $0 } END { print values }'
}

nnode_read_dataset_num_vectors() {
    dataset_path=$1
    num_vectors=$(
        "$bench_build_dir/inspect_dataset" --input "$dataset_path" |
            awk -F' = ' '/^num_vectors = / { print $2 }'
    )

    if [ -z "$num_vectors" ]; then
        nnode_die "Failed to read num_vectors from dataset: $dataset_path"
    fi

    echo "$num_vectors"
}

nnode_load_selection_context() {
    manifest_path=${1:-"$selection_env_path"}

    if ! selection_manifest_is_complete "$manifest_path"; then
        nnode_die "Missing or incomplete selection manifest: $manifest_path"
    fi

    selection_env_path=$manifest_path
    load_selection_env

    cluster_runtime_n_list=$(nnode_normalize_runtime_n_list "$bench_n_candidates" "$N_MAX_FEASIBLE")
    cluster_speedup_p_list=$BENCH_P_LIST
}

nnode_validate_runtime_inputs() {
    runtime_dataset_n=$(nnode_read_dataset_num_vectors "$cluster_runtime_max_memory_path")
    if [ "$runtime_dataset_n" -lt "$N_MAX_FEASIBLE" ] 2>/dev/null; then
        nnode_die \
            "CLUSTER_RUNTIME_MAX_MEMORY_PATH provides only $runtime_dataset_n vectors but N_MAX_FEASIBLE=$N_MAX_FEASIBLE"
    fi
}

nnode_compute_oversubscribe_p_list() {
    oversubscribe_values=""

    for process_count in $cluster_speedup_p_list; do
        if [ "$process_count" -gt "$cluster_p_total" ] 2>/dev/null; then
            oversubscribe_values=$(nnode_append_unique_value "$process_count" "$oversubscribe_values")
        fi
    done

    echo "$oversubscribe_values"
}

nnode_write_full_hostfile() {
    hostfile_output_path=$1

    mkdir -p "$(dirname "$hostfile_output_path")"
    : > "$hostfile_output_path"

    while IFS=' ' read -r host slots; do
        if [ -n "$host" ]; then
            printf '%s slots=%s max-slots=%s\n' "$host" "$slots" "$slots" >> "$hostfile_output_path"
        fi
    done < "$cluster_normalized_hostfile"
}

nnode_write_hostfile_for_p() {
    requested_process_count=$1
    hostfile_output_path=$2

    if [ "$requested_process_count" -lt 1 ] 2>/dev/null; then
        nnode_die "process_count must be positive"
    fi
    if [ "$requested_process_count" -gt "$cluster_p_total" ] 2>/dev/null; then
        nnode_die "process_count=$requested_process_count exceeds cluster_p_total=$cluster_p_total"
    fi

    remaining=$requested_process_count
    mkdir -p "$(dirname "$hostfile_output_path")"
    : > "$hostfile_output_path"

    while IFS=' ' read -r host slots; do
        if [ -z "$host" ]; then
            continue
        fi
        if [ "$remaining" -le 0 ] 2>/dev/null; then
            break
        fi

        allocated=$slots
        if [ "$allocated" -gt "$remaining" ] 2>/dev/null; then
            allocated=$remaining
        fi

        if [ "$allocated" -gt 0 ] 2>/dev/null; then
            printf '%s slots=%s max-slots=%s\n' "$host" "$allocated" "$allocated" >> "$hostfile_output_path"
            remaining=$((remaining - allocated))
        fi
    done < "$cluster_normalized_hostfile"

    if [ "$remaining" -ne 0 ] 2>/dev/null; then
        nnode_die "Failed to allocate $requested_process_count processes from hostfile $CLUSTER_HOSTFILE"
    fi
}

nnode_run_parallel_retriever() {
    process_count=$1
    vectors_path=$2
    queries_path=$3
    topk_value=$4
    output_path=$5
    metrics_path=$6
    run_metrics_path=${7:-}
    limit_n_value=${8:-}

    if [ "$process_count" -le "$cluster_p_total" ] 2>/dev/null; then
        hostfile_path="${cluster_hostfile_dir}/p${process_count}.hosts"
        nnode_write_hostfile_for_p "$process_count" "$hostfile_path"
    else
        hostfile_path="${cluster_hostfile_dir}/p${process_count}.oversubscribe.hosts"
        nnode_write_full_hostfile "$hostfile_path"
    fi

    if [ -n "$run_metrics_path" ]; then
        if [ -n "$limit_n_value" ]; then
            env HWLOC_COMPONENTS=-gl \
                mpirun \
                -x HWLOC_COMPONENTS \
                --mca oob_tcp_disable_ipv6_family 1 \
                --mca oob_tcp_if_include "$CLUSTER_HEAD_LAN_CIDR" \
                --mca btl self,tcp \
                --mca btl_tcp_if_include "$CLUSTER_HEAD_LAN_CIDR" \
                --oversubscribe \
                --hostfile "$hostfile_path" \
                --map-by slot \
                -np "$process_count" \
                "$bench_build_dir/parallel_retriever" \
                --vectors "$vectors_path" \
                --queries "$queries_path" \
                --topk "$topk_value" \
                --limit-n "$limit_n_value" \
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
                --oversubscribe \
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
        fi
    else
        if [ -n "$limit_n_value" ]; then
            env HWLOC_COMPONENTS=-gl \
                mpirun \
                -x HWLOC_COMPONENTS \
                --mca oob_tcp_disable_ipv6_family 1 \
                --mca oob_tcp_if_include "$CLUSTER_HEAD_LAN_CIDR" \
                --mca btl self,tcp \
                --mca btl_tcp_if_include "$CLUSTER_HEAD_LAN_CIDR" \
                --oversubscribe \
                --hostfile "$hostfile_path" \
                --map-by slot \
                -np "$process_count" \
                "$bench_build_dir/parallel_retriever" \
                --vectors "$vectors_path" \
                --queries "$queries_path" \
                --topk "$topk_value" \
                --limit-n "$limit_n_value" \
                --output "$output_path" \
                --metrics "$metrics_path"
        else
            env HWLOC_COMPONENTS=-gl \
                mpirun \
                -x HWLOC_COMPONENTS \
                --mca oob_tcp_disable_ipv6_family 1 \
                --mca oob_tcp_if_include "$CLUSTER_HEAD_LAN_CIDR" \
                --mca btl self,tcp \
                --mca btl_tcp_if_include "$CLUSTER_HEAD_LAN_CIDR" \
                --oversubscribe \
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
    fi
}

nnode_print_bundle_summary() {
    echo "run_tag=$cluster_run_tag"
    echo "cluster_results_dir=$bench_results_dir"
    echo "cluster_scratch_dir=$bench_scratch_dir"
    echo "cluster_node_count=$cluster_node_count"
    echo "cluster_p_total=$cluster_p_total"
    echo "cluster_hostfile=$CLUSTER_HOSTFILE"
    echo "selection_env_source=$cluster_selection_env_source"
    echo "selection_env_results=$cluster_selection_env_results"
    echo "cluster_selected_memory_path=$cluster_selected_memory_path"
    echo "cluster_selected_query_path=$cluster_selected_query_path"
    echo "cluster_speedup_memory_path=$cluster_speedup_memory_path"
    echo "cluster_speedup_query_path=$cluster_speedup_query_path"
    echo "cluster_runtime_max_memory_path=$cluster_runtime_max_memory_path"
    echo "runtime_n_list=$cluster_runtime_n_list"
    echo "speedup_p_list=$cluster_speedup_p_list"
    echo "oversubscribe_p_list=$cluster_oversubscribe_p_list"
    if [ -n "${bench_storage_root:-}" ]; then
        echo "bench_storage_root=$bench_storage_root"
    fi
}

nnode_print_dry_run_plan() {
    nnode_load_selection_context "$cluster_selection_env_source"
    cluster_oversubscribe_p_list=$(nnode_compute_oversubscribe_p_list)
    nnode_print_bundle_summary
    if nnode_is_mounted_repo; then
        echo "warning: current repo_root is mounted ($repo_root); real cluster execution should run from a Linux-native checkout."
    fi
    echo "Stage 1/5: runtime-by-N sweep"
    echo "Stage 2/5: selected synthetic correctness run"
    echo "Stage 3/5: granularity summary"
    echo "Stage 4/5: speedup sweep"
    echo "Stage 5/5: postprocess"
    echo "dry-run: no cluster commands executed"
}
