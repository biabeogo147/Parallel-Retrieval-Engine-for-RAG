cmake_minimum_required(VERSION 3.20)

if(NOT DEFINED REPO_ROOT)
    message(FATAL_ERROR "REPO_ROOT is required")
endif()

if(NOT DEFINED BUILD_DIR)
    message(FATAL_ERROR "BUILD_DIR is required")
endif()

if(NOT DEFINED GENERATE_VECTORS)
    message(FATAL_ERROR "GENERATE_VECTORS is required")
endif()

if(NOT DEFINED GENERATE_QUERIES)
    message(FATAL_ERROR "GENERATE_QUERIES is required")
endif()

if(NOT DEFINED WORK_DIR)
    message(FATAL_ERROR "WORK_DIR is required")
endif()

file(MAKE_DIRECTORY "${WORK_DIR}")
set(results_dir "${WORK_DIR}/results")
set(scratch_dir "${WORK_DIR}/scratch")
set(real_dir "${WORK_DIR}/squad_fixture")
file(MAKE_DIRECTORY "${real_dir}")

execute_process(
    COMMAND "${GENERATE_VECTORS}" "--N" "32" "--D" "8" "--output" "${real_dir}/vectors.bin" "--seed" "22222"
    RESULT_VARIABLE vectors_exit
    OUTPUT_VARIABLE vectors_stdout
    ERROR_VARIABLE vectors_stderr
)

if(NOT vectors_exit EQUAL 0)
    message(FATAL_ERROR "generate_vectors fixture failed:\n${vectors_stdout}\n${vectors_stderr}")
endif()

execute_process(
    COMMAND "${GENERATE_QUERIES}" "--Q" "4" "--D" "8" "--output" "${real_dir}/queries.bin" "--seed" "33333"
    RESULT_VARIABLE queries_exit
    OUTPUT_VARIABLE queries_stdout
    ERROR_VARIABLE queries_stderr
)

if(NOT queries_exit EQUAL 0)
    message(FATAL_ERROR "generate_queries fixture failed:\n${queries_stdout}\n${queries_stderr}")
endif()

file(WRITE "${real_dir}/metadata.tsv" "memory_id\tmemory_text\n0\tfixture memory 0\n")

execute_process(
    COMMAND
        "${CMAKE_COMMAND}" -E env
        "BENCH_BUILD_DIR=${BUILD_DIR}"
        "BENCH_RESULTS_DIR=${results_dir}"
        "BENCH_SCRATCH_DIR=${scratch_dir}"
        "BENCH_D=8"
        "BENCH_Q=5"
        "BENCH_TOPK=3"
        "BENCH_EPSILON=1e-5"
        "BENCH_N_CANDIDATES=64"
        "BENCH_P_SELECTED=4"
        "BENCH_P_LIST=2 4"
        "BENCH_SQUAD_OUTPUT_DIR=${real_dir}"
        bash
        "${REPO_ROOT}/scripts/run_faiss_comparison.sh"
    RESULT_VARIABLE run_exit
    OUTPUT_VARIABLE run_stdout
    ERROR_VARIABLE run_stderr
)

if(NOT run_exit EQUAL 0)
    message(FATAL_ERROR "run_faiss_comparison.sh failed:\n${run_stdout}\n${run_stderr}")
endif()

foreach(required_path
    "${results_dir}/faiss/synthetic_topk.csv"
    "${results_dir}/faiss/synthetic_run_metrics.csv"
    "${results_dir}/faiss/synthetic_correctness.csv"
    "${results_dir}/faiss/squad_topk.csv"
    "${results_dir}/faiss/squad_run_metrics.csv"
    "${results_dir}/faiss/squad_correctness.csv"
    "${results_dir}/faiss/comparison.csv")
    if(NOT EXISTS "${required_path}")
        message(FATAL_ERROR "expected Phase 8 artifact was not created: ${required_path}")
    endif()
endforeach()

file(STRINGS "${results_dir}/faiss/comparison.csv" comparison_lines)
list(LENGTH comparison_lines comparison_line_count)
if(NOT comparison_line_count EQUAL 3)
    message(FATAL_ERROR "expected 3 comparison CSV lines but found ${comparison_line_count}")
endif()
