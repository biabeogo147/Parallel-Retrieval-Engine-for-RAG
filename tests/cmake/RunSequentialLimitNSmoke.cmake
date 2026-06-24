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

if(NOT DEFINED WORK_DIR)
    message(FATAL_ERROR "WORK_DIR is required")
endif()

file(MAKE_DIRECTORY "${WORK_DIR}")
set(full_memory_path "${WORK_DIR}/memory_vectors_64.bin")
set(prefix_memory_path "${WORK_DIR}/memory_vectors_16.bin")
set(query_path "${WORK_DIR}/query_vectors.bin")
set(limit_output_path "${WORK_DIR}/sequential_limit_topk.csv")
set(prefix_output_path "${WORK_DIR}/sequential_prefix_topk.csv")
set(run_metrics_path "${WORK_DIR}/sequential_limit_run_metrics.csv")

execute_process(
    COMMAND "${GENERATE_VECTORS}" "--N" "64" "--D" "8" "--output" "${full_memory_path}" "--seed" "12345"
    RESULT_VARIABLE vectors_full_exit
    OUTPUT_VARIABLE vectors_full_stdout
    ERROR_VARIABLE vectors_full_stderr
)
if(NOT vectors_full_exit EQUAL 0)
    message(FATAL_ERROR "generate_vectors (full) failed:\n${vectors_full_stdout}\n${vectors_full_stderr}")
endif()

execute_process(
    COMMAND "${GENERATE_VECTORS}" "--N" "16" "--D" "8" "--output" "${prefix_memory_path}" "--seed" "12345"
    RESULT_VARIABLE vectors_prefix_exit
    OUTPUT_VARIABLE vectors_prefix_stdout
    ERROR_VARIABLE vectors_prefix_stderr
)
if(NOT vectors_prefix_exit EQUAL 0)
    message(FATAL_ERROR "generate_vectors (prefix) failed:\n${vectors_prefix_stdout}\n${vectors_prefix_stderr}")
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
    COMMAND
        "${SEQUENTIAL}"
        "--vectors" "${full_memory_path}"
        "--queries" "${query_path}"
        "--topk" "3"
        "--limit-n" "16"
        "--output" "${limit_output_path}"
        "--run-metrics" "${run_metrics_path}"
    RESULT_VARIABLE limit_exit
    OUTPUT_VARIABLE limit_stdout
    ERROR_VARIABLE limit_stderr
)
if(NOT limit_exit EQUAL 0)
    message(FATAL_ERROR "sequential_retriever --limit-n failed:\n${limit_stdout}\n${limit_stderr}")
endif()

execute_process(
    COMMAND
        "${SEQUENTIAL}"
        "--vectors" "${prefix_memory_path}"
        "--queries" "${query_path}"
        "--topk" "3"
        "--output" "${prefix_output_path}"
    RESULT_VARIABLE prefix_exit
    OUTPUT_VARIABLE prefix_stdout
    ERROR_VARIABLE prefix_stderr
)
if(NOT prefix_exit EQUAL 0)
    message(FATAL_ERROR "sequential_retriever prefix baseline failed:\n${prefix_stdout}\n${prefix_stderr}")
endif()

file(READ "${limit_output_path}" limit_text)
file(READ "${prefix_output_path}" prefix_text)
if(NOT limit_text STREQUAL prefix_text)
    message(FATAL_ERROR "limit-n output did not match the explicit 16-row prefix dataset")
endif()

file(STRINGS "${run_metrics_path}" run_metrics_lines)
list(GET run_metrics_lines 1 run_metrics_row)
string(REPLACE "," ";" run_metrics_fields "${run_metrics_row}")
list(GET run_metrics_fields 0 field_N)
if(NOT field_N STREQUAL "16")
    message(FATAL_ERROR "expected limited sequential run metrics to report N=16, got: ${run_metrics_row}")
endif()

execute_process(
    COMMAND
        "${SEQUENTIAL}"
        "--vectors" "${full_memory_path}"
        "--queries" "${query_path}"
        "--topk" "3"
        "--limit-n" "0"
        "--output" "${WORK_DIR}/invalid_zero.csv"
    RESULT_VARIABLE invalid_zero_exit
    OUTPUT_VARIABLE invalid_zero_stdout
    ERROR_VARIABLE invalid_zero_stderr
)
if(invalid_zero_exit EQUAL 0)
    message(FATAL_ERROR "sequential_retriever unexpectedly accepted --limit-n 0")
endif()
if(NOT invalid_zero_stderr MATCHES "--limit-n")
    message(FATAL_ERROR "invalid --limit-n 0 failure did not mention --limit-n:\n${invalid_zero_stdout}\n${invalid_zero_stderr}")
endif()

execute_process(
    COMMAND
        "${SEQUENTIAL}"
        "--vectors" "${full_memory_path}"
        "--queries" "${query_path}"
        "--topk" "3"
        "--limit-n" "65"
        "--output" "${WORK_DIR}/invalid_large.csv"
    RESULT_VARIABLE invalid_large_exit
    OUTPUT_VARIABLE invalid_large_stdout
    ERROR_VARIABLE invalid_large_stderr
)
if(invalid_large_exit EQUAL 0)
    message(FATAL_ERROR "sequential_retriever unexpectedly accepted a limit larger than the dataset")
endif()
if(NOT invalid_large_stderr MATCHES "limit")
    message(FATAL_ERROR "large --limit-n failure did not mention limit:\n${invalid_large_stdout}\n${invalid_large_stderr}")
endif()
