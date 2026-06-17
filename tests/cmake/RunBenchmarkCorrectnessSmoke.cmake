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
set(results_dir "${WORK_DIR}/results")
set(scratch_dir "${WORK_DIR}/scratch")

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
        "BENCH_N_CANDIDATES=64 128"
        "BENCH_Q_CANDIDATES=5"
        "BENCH_SPEEDUP_N_CANDIDATES=64"
        "BENCH_P_SELECTED=4"
        bash
        "${REPO_ROOT}/scripts/run_select_N.sh"
    RESULT_VARIABLE select_exit
    OUTPUT_VARIABLE select_stdout
    ERROR_VARIABLE select_stderr
)

if(NOT select_exit EQUAL 0)
    message(FATAL_ERROR "run_select_N.sh failed:\n${select_stdout}\n${select_stderr}")
endif()

execute_process(
    COMMAND
        "${CMAKE_COMMAND}" -E env
        "BENCH_BUILD_DIR=${BUILD_DIR}"
        "BENCH_RESULTS_DIR=${results_dir}"
        "BENCH_SCRATCH_DIR=${scratch_dir}"
        bash
        "${REPO_ROOT}/scripts/run_correctness.sh"
    RESULT_VARIABLE run_exit
    OUTPUT_VARIABLE run_stdout
    ERROR_VARIABLE run_stderr
)

if(NOT run_exit EQUAL 0)
    message(FATAL_ERROR "run_correctness.sh failed:\n${run_stdout}\n${run_stderr}")
endif()

foreach(path_name
    "${results_dir}/sequential_topk.csv"
    "${results_dir}/parallel_topk.csv"
    "${results_dir}/correctness.csv")
    if(NOT EXISTS "${path_name}")
        message(FATAL_ERROR "expected correctness artifact was not created: ${path_name}")
    endif()
endforeach()

file(STRINGS "${results_dir}/correctness.csv" correctness_lines)
list(LENGTH correctness_lines correctness_line_count)
if(NOT correctness_line_count EQUAL 6)
    message(FATAL_ERROR "expected 6 correctness CSV lines but found ${correctness_line_count}")
endif()

list(GET correctness_lines 0 correctness_header)
if(NOT correctness_header STREQUAL "query_id,k,matched,matched_ids,max_score_diff,status")
    message(FATAL_ERROR "unexpected correctness CSV header: ${correctness_header}")
endif()
