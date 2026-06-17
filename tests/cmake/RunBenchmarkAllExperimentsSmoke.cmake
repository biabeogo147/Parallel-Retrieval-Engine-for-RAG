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
        "BENCH_Q_CANDIDATES=150 200"
        "BENCH_SPEEDUP_N_CANDIDATES=64"
        "BENCH_P_SELECTED=4"
        "BENCH_P_LIST=2 4"
        bash
        "${REPO_ROOT}/scripts/run_all_experiments.sh"
    RESULT_VARIABLE run_exit
    OUTPUT_VARIABLE run_stdout
    ERROR_VARIABLE run_stderr
)

if(NOT run_exit EQUAL 0)
    message(FATAL_ERROR "run_all_experiments.sh failed:\n${run_stdout}\n${run_stderr}")
endif()

foreach(required_path
    "${results_dir}/runtime_by_N.csv"
    "${results_dir}/benchmark_selection.env"
    "${results_dir}/correctness.csv"
    "${results_dir}/granularity.csv"
    "${results_dir}/speedup.csv"
    "${results_dir}/figures/runtime_by_N.png"
    "${results_dir}/figures/granularity.png"
    "${results_dir}/figures/speedup_runtime.png"
    "${results_dir}/figures/speedup_curves.png")
    if(NOT EXISTS "${required_path}")
        message(FATAL_ERROR "expected benchmark artifact was not created: ${required_path}")
    endif()
endforeach()

file(READ "${results_dir}/benchmark_selection.env" selection_text)
foreach(required_entry "N_SPEEDUP=64" "CALIBRATION_MODE=N_PLUS_Q" "Q=200")
    string(FIND "${selection_text}" "${required_entry}" entry_index)
    if(entry_index EQUAL -1)
        message(FATAL_ERROR "missing calibrated selection entry ${required_entry} in:\n${selection_text}")
    endif()
endforeach()

file(STRINGS "${results_dir}/speedup.csv" speedup_lines)
list(GET speedup_lines 1 baseline_row)
string(REPLACE "," ";" baseline_fields "${baseline_row}")
list(GET baseline_fields 0 baseline_n)
if(NOT baseline_n STREQUAL "64")
    message(FATAL_ERROR "expected calibrated speedup baseline to use explicit N_SPEEDUP=64, got: ${baseline_row}")
endif()
