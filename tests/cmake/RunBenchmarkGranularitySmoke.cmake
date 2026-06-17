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
        "${REPO_ROOT}/scripts/run_granularity.sh"
    RESULT_VARIABLE run_exit
    OUTPUT_VARIABLE run_stdout
    ERROR_VARIABLE run_stderr
)

if(NOT run_exit EQUAL 0)
    message(FATAL_ERROR "run_granularity.sh failed:\n${run_stdout}\n${run_stderr}")
endif()

set(granularity_path "${results_dir}/granularity.csv")
set(summary_path "${results_dir}/granularity_summary.txt")
if(NOT EXISTS "${granularity_path}")
    message(FATAL_ERROR "expected granularity.csv was not created: ${granularity_path}")
endif()
if(NOT EXISTS "${summary_path}")
    message(FATAL_ERROR "expected granularity_summary.txt was not created: ${summary_path}")
endif()

file(STRINGS "${granularity_path}" granularity_lines)
list(LENGTH granularity_lines granularity_line_count)
if(NOT granularity_line_count EQUAL 5)
    message(FATAL_ERROR "expected 5 granularity CSV lines but found ${granularity_line_count}")
endif()

file(READ "${summary_path}" summary_text)
string(FIND "${summary_text}" "Load balancing verdict:" verdict_index)
if(verdict_index EQUAL -1)
    message(FATAL_ERROR "expected granularity summary verdict, got:\n${summary_text}")
endif()
