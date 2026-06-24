cmake_minimum_required(VERSION 3.20)

if(NOT DEFINED REPO_ROOT)
    message(FATAL_ERROR "REPO_ROOT is required")
endif()

if(NOT DEFINED BUILD_DIR)
    message(FATAL_ERROR "BUILD_DIR is required")
endif()

if(NOT DEFINED WORK_DIR)
    message(FATAL_ERROR "WORK_DIR is required")
endif()

file(MAKE_DIRECTORY "${WORK_DIR}")
set(config_path "${WORK_DIR}/n_node_bundle.env")
set(hostfile_path "${WORK_DIR}/hosts.cluster")
set(selection_env_path "${WORK_DIR}/benchmark_selection.env")
set(storage_root "${WORK_DIR}/external-storage")
set(bash_executable "bash")
set(selected_memory_path "${WORK_DIR}/selected_memory_vectors.bin")
set(selected_query_path "${WORK_DIR}/selected_query_vectors.bin")
set(speedup_memory_path "${WORK_DIR}/speedup_memory_vectors.bin")
set(speedup_query_path "${WORK_DIR}/speedup_query_vectors.bin")

if(EXISTS "C:/Program Files/Git/usr/bin/bash.exe")
    set(bash_executable "C:/Program Files/Git/usr/bin/bash.exe")
elseif(EXISTS "C:/Program Files/Git/bin/bash.exe")
    set(bash_executable "C:/Program Files/Git/bin/bash.exe")
endif()

file(WRITE "${hostfile_path}"
    "rag-head slots=4 max-slots=4\n"
    "rag-worker1 slots=4 max-slots=4\n"
    "rag-worker2 slots=4 max-slots=4\n")
file(WRITE "${selection_env_path}"
    "N_SELECTED=100000\n"
    "N_SPEEDUP=500000\n"
    "P_SELECTED=12\n"
    "D=384\n"
    "Q=100\n"
    "K=10\n"
    "EPSILON=1e-5\n"
    "CALIBRATION_MODE=PRESELECTED\n"
    "N_MAX_FEASIBLE=100000\n")
file(WRITE "${selected_memory_path}" "selected-memory\n")
file(WRITE "${selected_query_path}" "selected-query\n")
file(WRITE "${speedup_memory_path}" "speedup-memory\n")
file(WRITE "${speedup_query_path}" "speedup-query\n")
file(WRITE "${config_path}"
    "CLUSTER_HOSTFILE=${hostfile_path}\n"
    "CLUSTER_SELECTION_ENV=${selection_env_path}\n"
    "CLUSTER_SELECTED_MEMORY_PATH=${selected_memory_path}\n"
    "CLUSTER_SELECTED_QUERY_PATH=${selected_query_path}\n"
    "CLUSTER_SPEEDUP_MEMORY_PATH=${speedup_memory_path}\n"
    "CLUSTER_SPEEDUP_QUERY_PATH=${speedup_query_path}\n"
    "CLUSTER_HEAD_LAN_CIDR=192.168.1.0/24\n"
    "BENCH_BUILD_DIR=${BUILD_DIR}\n"
    "BENCH_STORAGE_ROOT=${storage_root}\n"
    "BENCH_PYTHON_STDLIB=python\n"
    "BENCH_P_LIST=\"2 4 8 12\"\n")

if(WIN32)
    execute_process(
        COMMAND
            "${bash_executable}"
            -lc
            "script_path=$(cygpath -u \"$1\"); config_path=$(cygpath -u \"$2\"); \"$script_path\" --config \"$config_path\" --run-tag \"smoke-n-node\" --dry-run"
            _
            "${REPO_ROOT}/scripts/run_cluster_n_node_bundle.sh"
            "${config_path}"
        RESULT_VARIABLE run_exit
        OUTPUT_VARIABLE run_stdout
        ERROR_VARIABLE run_stderr
    )
else()
    execute_process(
        COMMAND
            "${bash_executable}"
            "${REPO_ROOT}/scripts/run_cluster_n_node_bundle.sh"
            --config "${config_path}"
            --run-tag "smoke-n-node"
            --dry-run
        RESULT_VARIABLE run_exit
        OUTPUT_VARIABLE run_stdout
        ERROR_VARIABLE run_stderr
    )
endif()

if(NOT run_exit EQUAL 0)
    message(FATAL_ERROR "run_cluster_n_node_bundle.sh --dry-run failed:\n${run_stdout}\n${run_stderr}")
endif()

foreach(required_text
    "Stage 1/4: selected synthetic correctness run"
    "Stage 2/4: granularity summary"
    "Stage 3/4: speedup sweep"
    "Stage 4/4: postprocess"
    "run_tag=smoke-n-node"
    "cluster_node_count=3"
    "cluster_p_total=12"
    "cluster_results_dir="
    "external-storage/results/cluster/smoke-n-node"
    "external-storage/scratch/cluster_bundle/smoke-n-node"
    "selection_env_source="
    "dry-run: no cluster commands executed")
    if(NOT run_stdout MATCHES "${required_text}")
        message(FATAL_ERROR "missing expected dry-run text '${required_text}' in:\n${run_stdout}\n${run_stderr}")
    endif()
endforeach()
