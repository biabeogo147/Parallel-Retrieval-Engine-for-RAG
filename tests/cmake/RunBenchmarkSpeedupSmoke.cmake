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
        "BENCH_P_LIST=2 4"
        bash
        "${REPO_ROOT}/scripts/run_speedup.sh"
    RESULT_VARIABLE run_exit
    OUTPUT_VARIABLE run_stdout
    ERROR_VARIABLE run_stderr
)

if(NOT run_exit EQUAL 0)
    message(FATAL_ERROR "run_speedup.sh failed:\n${run_stdout}\n${run_stderr}")
endif()

set(speedup_path "${results_dir}/speedup.csv")
if(NOT EXISTS "${speedup_path}")
    message(FATAL_ERROR "expected speedup.csv was not created: ${speedup_path}")
endif()

file(STRINGS "${speedup_path}" speedup_lines)
list(LENGTH speedup_lines speedup_line_count)
if(NOT speedup_line_count EQUAL 4)
    message(FATAL_ERROR "expected 4 speedup CSV lines but found ${speedup_line_count}")
endif()

list(GET speedup_lines 0 speedup_header)
if(NOT speedup_header STREQUAL "N,D,Q,k,P,compute_time,communication_time,total_time,compute_speedup,total_speedup,compute_efficiency,total_efficiency")
    message(FATAL_ERROR "unexpected speedup CSV header: ${speedup_header}")
endif()

list(GET speedup_lines 1 baseline_row)
string(REPLACE "," ";" baseline_fields "${baseline_row}")
list(GET baseline_fields 4 baseline_p)
if(NOT baseline_p STREQUAL "1")
    message(FATAL_ERROR "expected baseline speedup row to use P=1, got: ${baseline_row}")
endif()
