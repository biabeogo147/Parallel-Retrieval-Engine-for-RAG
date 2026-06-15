cmake_minimum_required(VERSION 3.20)

if(NOT DEFINED GENERATE_VECTORS)
    message(FATAL_ERROR "GENERATE_VECTORS is required")
endif()

if(NOT DEFINED GENERATE_QUERIES)
    message(FATAL_ERROR "GENERATE_QUERIES is required")
endif()

if(NOT DEFINED SEQUENTIAL)
    message(FATAL_ERROR "SEQUENTIAL is required")
endif()

if(NOT DEFINED PARALLEL)
    message(FATAL_ERROR "PARALLEL is required")
endif()

if(NOT DEFINED VERIFY_RESULTS)
    message(FATAL_ERROR "VERIFY_RESULTS is required")
endif()

if(NOT DEFINED MPIEXEC_EXECUTABLE)
    message(FATAL_ERROR "MPIEXEC_EXECUTABLE is required")
endif()

if(NOT DEFINED MPIEXEC_NUMPROC_FLAG)
    message(FATAL_ERROR "MPIEXEC_NUMPROC_FLAG is required")
endif()

if(NOT DEFINED WORK_DIR)
    message(FATAL_ERROR "WORK_DIR is required")
endif()

file(MAKE_DIRECTORY "${WORK_DIR}")
set(memory_path "${WORK_DIR}/memory_vectors.bin")
set(query_path "${WORK_DIR}/query_vectors.bin")
set(sequential_output "${WORK_DIR}/sequential_topk.csv")
set(parallel_output "${WORK_DIR}/parallel_topk.csv")
set(metrics_output "${WORK_DIR}/parallel_metrics.csv")
set(correctness_output "${WORK_DIR}/correctness.csv")

execute_process(
    COMMAND "${GENERATE_VECTORS}" "--N" "64" "--D" "8" "--output" "${memory_path}" "--seed" "12345"
    RESULT_VARIABLE vectors_exit
    OUTPUT_VARIABLE vectors_stdout
    ERROR_VARIABLE vectors_stderr
)

if(NOT vectors_exit EQUAL 0)
    message(FATAL_ERROR "generate_vectors failed:\n${vectors_stdout}\n${vectors_stderr}")
endif()

execute_process(
    COMMAND "${GENERATE_QUERIES}" "--Q" "5" "--D" "8" "--output" "${query_path}" "--seed" "12345"
    RESULT_VARIABLE queries_exit
    OUTPUT_VARIABLE queries_stdout
    ERROR_VARIABLE queries_stderr
)

if(NOT queries_exit EQUAL 0)
    message(FATAL_ERROR "generate_queries failed:\n${queries_stdout}\n${queries_stderr}")
endif()

execute_process(
    COMMAND "${SEQUENTIAL}" "--vectors" "${memory_path}" "--queries" "${query_path}" "--topk" "3" "--output" "${sequential_output}"
    RESULT_VARIABLE sequential_exit
    OUTPUT_VARIABLE sequential_stdout
    ERROR_VARIABLE sequential_stderr
)

if(NOT sequential_exit EQUAL 0)
    message(FATAL_ERROR "sequential_retriever failed:\n${sequential_stdout}\n${sequential_stderr}")
endif()

execute_process(
    COMMAND "${CMAKE_COMMAND}" -E env
            OMPI_ALLOW_RUN_AS_ROOT=1
            OMPI_ALLOW_RUN_AS_ROOT_CONFIRM=1
            "${MPIEXEC_EXECUTABLE}" "${MPIEXEC_NUMPROC_FLAG}" "4"
            "${PARALLEL}"
            "--vectors" "${memory_path}"
            "--queries" "${query_path}"
            "--topk" "3"
            "--output" "${parallel_output}"
            "--metrics" "${metrics_output}"
    RESULT_VARIABLE parallel_exit
    OUTPUT_VARIABLE parallel_stdout
    ERROR_VARIABLE parallel_stderr
)

if(NOT parallel_exit EQUAL 0)
    message(FATAL_ERROR "parallel_retriever failed:\n${parallel_stdout}\n${parallel_stderr}")
endif()

execute_process(
    COMMAND "${VERIFY_RESULTS}"
            "--sequential" "${sequential_output}"
            "--parallel" "${parallel_output}"
            "--epsilon" "1e-5"
            "--output" "${correctness_output}"
    RESULT_VARIABLE verify_exit
    OUTPUT_VARIABLE verify_stdout
    ERROR_VARIABLE verify_stderr
)

if(NOT verify_exit EQUAL 0)
    message(FATAL_ERROR "verify_results should pass but failed:\n${verify_stdout}\n${verify_stderr}")
endif()

if(NOT EXISTS "${correctness_output}")
    message(FATAL_ERROR "expected correctness CSV output was not created: ${correctness_output}")
endif()

file(STRINGS "${correctness_output}" correctness_lines)
list(LENGTH correctness_lines correctness_line_count)
if(NOT correctness_line_count EQUAL 6)
    message(FATAL_ERROR "expected 6 correctness CSV lines but found ${correctness_line_count}")
endif()

list(GET correctness_lines 0 correctness_header)
if(NOT correctness_header STREQUAL "query_id,k,matched,matched_ids,max_score_diff,status")
    message(FATAL_ERROR "unexpected correctness CSV header: ${correctness_header}")
endif()

set(last_index 5)
foreach(line_index RANGE 1 ${last_index})
    list(GET correctness_lines ${line_index} row_text)
    string(FIND "${row_text}" ",true,3," matched_index)
    if(matched_index EQUAL -1)
        message(FATAL_ERROR "expected PASS row with matched_ids=3, got: ${row_text}")
    endif()
    string(FIND "${row_text}" ",PASS" status_index)
    if(status_index EQUAL -1)
        message(FATAL_ERROR "expected PASS status, got: ${row_text}")
    endif()
endforeach()

string(FIND "${verify_stdout}" "All queries PASS" summary_index)
if(summary_index EQUAL -1)
    message(FATAL_ERROR "expected success summary, got:\n${verify_stdout}\n${verify_stderr}")
endif()
