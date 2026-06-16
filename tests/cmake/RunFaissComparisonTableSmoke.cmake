cmake_minimum_required(VERSION 3.20)

if(NOT DEFINED REPO_ROOT)
    message(FATAL_ERROR "REPO_ROOT is required")
endif()

if(NOT DEFINED WORK_DIR)
    message(FATAL_ERROR "WORK_DIR is required")
endif()

file(MAKE_DIRECTORY "${WORK_DIR}")

set(parallel_metrics_path "${WORK_DIR}/parallel_run_metrics.csv")
set(faiss_metrics_path "${WORK_DIR}/faiss_run_metrics.csv")
set(correctness_path "${WORK_DIR}/correctness.csv")
set(output_path "${WORK_DIR}/comparison.csv")

file(WRITE "${parallel_metrics_path}" "N,D,Q,k,P,compute_time,communication_time,total_time\n64,8,5,3,4,0.80000000,0.20000000,1.00000000\n")
file(WRITE "${faiss_metrics_path}" "dataset_name,N,D,Q,k,threads,build_time,compute_time,total_time\nsynthetic,64,8,5,3,4,0.01000000,0.25000000,0.25000000\n")
file(WRITE "${correctness_path}" "query_id,k,matched,matched_ids,max_score_diff,status\n0,3,true,3,0.00000012,PASS\n1,3,true,3,0.00000008,PASS\n")

execute_process(
    COMMAND
        python3
        "${REPO_ROOT}/scripts/benchmark_csv.py"
        build-faiss-comparison
        --output "${output_path}"
        --parallel-metrics "${parallel_metrics_path}"
        --faiss-metrics "${faiss_metrics_path}"
        --correctness "${correctness_path}"
    RESULT_VARIABLE run_exit
    OUTPUT_VARIABLE run_stdout
    ERROR_VARIABLE run_stderr
)

if(NOT run_exit EQUAL 0)
    message(FATAL_ERROR "build-faiss-comparison failed:\n${run_stdout}\n${run_stderr}")
endif()

if(NOT EXISTS "${output_path}")
    message(FATAL_ERROR "expected comparison.csv was not created: ${output_path}")
endif()

file(STRINGS "${output_path}" output_lines)
list(LENGTH output_lines output_line_count)
if(NOT output_line_count EQUAL 2)
    message(FATAL_ERROR "expected 2 comparison CSV lines but found ${output_line_count}")
endif()

list(GET output_lines 0 output_header)
if(NOT output_header STREQUAL "dataset_name,N,D,Q,k,parallel_workers,faiss_threads,parallel_compute_time,parallel_communication_time,parallel_total_time,faiss_build_time,faiss_compute_time,faiss_total_time,total_ratio,correctness_status,max_score_diff")
    message(FATAL_ERROR "unexpected comparison CSV header: ${output_header}")
endif()

list(GET output_lines 1 output_row)
string(REPLACE "," ";" output_fields "${output_row}")
list(GET output_fields 0 dataset_name)
list(GET output_fields 13 total_ratio)
list(GET output_fields 14 correctness_status)

if(NOT dataset_name STREQUAL "synthetic")
    message(FATAL_ERROR "unexpected dataset_name in comparison row: ${output_row}")
endif()

if(NOT correctness_status STREQUAL "PASS")
    message(FATAL_ERROR "expected correctness_status PASS, got: ${output_row}")
endif()

if(NOT total_ratio STREQUAL "4.00000000")
    message(FATAL_ERROR "expected total_ratio 4.00000000, got: ${output_row}")
endif()
