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
    RESULT_VARIABLE run_exit
    OUTPUT_VARIABLE run_stdout
    ERROR_VARIABLE run_stderr
)

if(NOT run_exit EQUAL 0)
    message(FATAL_ERROR "run_select_N.sh failed:\n${run_stdout}\n${run_stderr}")
endif()

set(runtime_path "${results_dir}/runtime_by_N.csv")
set(selection_path "${results_dir}/benchmark_selection.env")

if(NOT EXISTS "${runtime_path}")
    message(FATAL_ERROR "expected runtime_by_N.csv was not created: ${runtime_path}")
endif()
if(NOT EXISTS "${selection_path}")
    message(FATAL_ERROR "expected benchmark_selection.env was not created: ${selection_path}")
endif()

file(STRINGS "${runtime_path}" runtime_lines)
list(LENGTH runtime_lines runtime_line_count)
if(NOT runtime_line_count EQUAL 3)
    message(FATAL_ERROR "expected 3 runtime CSV lines but found ${runtime_line_count}")
endif()

list(GET runtime_lines 0 runtime_header)
if(NOT runtime_header STREQUAL "N,D,Q,k,P,compute_time,communication_time,total_time")
    message(FATAL_ERROR "unexpected runtime CSV header: ${runtime_header}")
endif()

file(READ "${selection_path}" selection_text)
foreach(required_entry "N_SELECTED=" "N_SPEEDUP=64" "P_SELECTED=4" "D=8" "Q=5" "K=3" "EPSILON=1e-5" "CALIBRATION_MODE=" "N_MAX_FEASIBLE=")
    string(FIND "${selection_text}" "${required_entry}" entry_index)
    if(entry_index EQUAL -1)
        message(FATAL_ERROR "missing selection entry ${required_entry} in:\n${selection_text}")
    endif()
endforeach()
