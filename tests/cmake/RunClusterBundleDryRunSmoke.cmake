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
set(config_path "${WORK_DIR}/two_node_bundle.env")
set(hostfile_path "${WORK_DIR}/hosts.local-plus-199")
set(storage_root "${WORK_DIR}/external-storage")

file(WRITE "${hostfile_path}" "rag-head slots=10 max-slots=10\nrag-worker1 slots=4 max-slots=4\n")
file(WRITE "${config_path}" "CLUSTER_HOSTFILE=${hostfile_path}\nCLUSTER_WORKER_HOST=rag-worker1\nCLUSTER_WORKER_REPO_ROOT=~/work/Parallel-Retrieval-Engine-for-RAG\nCLUSTER_SERVER_SLOTS=4\nCLUSTER_HEAD_LAN_CIDR=192.168.1.0/24\nCLUSTER_RUN_TAG_PREFIX=local-plus-199\nBENCH_BUILD_DIR=${BUILD_DIR}\nBENCH_STORAGE_ROOT=${storage_root}\nBENCH_D=8\nBENCH_Q=5\nBENCH_TOPK=3\nBENCH_EPSILON=1e-5\nBENCH_N_CANDIDATES=\"64 128\"\nBENCH_Q_CANDIDATES=\"5 10\"\nBENCH_SPEEDUP_N_CANDIDATES=\"64\"\nBENCH_SPEEDUP_BASELINE_LIMIT=600\nBENCH_P_LIST=\"2 4 8 10 12 14\"\n")

execute_process(
    COMMAND
        bash
        "${REPO_ROOT}/scripts/run_cluster_two_node_bundle.sh"
        --config "${config_path}"
        --run-tag "smoke-cluster-bundle"
        --dry-run
    RESULT_VARIABLE run_exit
    OUTPUT_VARIABLE run_stdout
    ERROR_VARIABLE run_stderr
)

if(NOT run_exit EQUAL 0)
    message(FATAL_ERROR "run_cluster_two_node_bundle.sh --dry-run failed:\n${run_stdout}\n${run_stderr}")
endif()

foreach(required_text
    "Stage 1/6: runtime calibration"
    "Stage 2/6: selected synthetic correctness run"
    "Stage 3/6: granularity summary"
    "Stage 4/6: speedup sweep"
    "Stage 5/6: FAISS comparisons"
    "Stage 6/6: postprocess"
    "run_tag=smoke-cluster-bundle"
    "cluster_p_total="
    "cluster_faiss_threads="
    "external-storage/results/cluster/smoke-cluster-bundle"
    "external-storage/scratch/cluster_bundle/smoke-cluster-bundle"
    "cluster_runtime_dir="
    "bench_storage_root="
    "dry-run: no cluster commands executed")
    if(NOT run_stdout MATCHES "${required_text}")
        message(FATAL_ERROR "missing expected dry-run text '${required_text}' in:\n${run_stdout}\n${run_stderr}")
    endif()
endforeach()
