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
set(full_memory_path "${WORK_DIR}/memory_vectors_64.bin")
set(prefix_memory_path "${WORK_DIR}/memory_vectors_16.bin")
set(query_path "${WORK_DIR}/query_vectors.bin")
set(sequential_prefix_output "${WORK_DIR}/sequential_prefix_topk.csv")
set(parallel_output_path "${WORK_DIR}/parallel_limit_topk.csv")
set(metrics_path "${WORK_DIR}/parallel_limit_metrics.csv")
set(run_metrics_path "${WORK_DIR}/parallel_limit_run_metrics.csv")

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
        "--vectors" "${prefix_memory_path}"
        "--queries" "${query_path}"
        "--topk" "3"
        "--output" "${sequential_prefix_output}"
    RESULT_VARIABLE sequential_exit
    OUTPUT_VARIABLE sequential_stdout
    ERROR_VARIABLE sequential_stderr
)
if(NOT sequential_exit EQUAL 0)
    message(FATAL_ERROR "sequential prefix baseline failed:\n${sequential_stdout}\n${sequential_stderr}")
endif()

execute_process(
    COMMAND "${CMAKE_COMMAND}" -E env
            OMPI_ALLOW_RUN_AS_ROOT=1
            OMPI_ALLOW_RUN_AS_ROOT_CONFIRM=1
            "${MPIEXEC_EXECUTABLE}" "${MPIEXEC_NUMPROC_FLAG}" "4"
            "${PARALLEL}"
            "--vectors" "${full_memory_path}"
            "--queries" "${query_path}"
            "--topk" "3"
            "--limit-n" "16"
            "--output" "${parallel_output_path}"
            "--metrics" "${metrics_path}"
            "--run-metrics" "${run_metrics_path}"
    RESULT_VARIABLE parallel_exit
    OUTPUT_VARIABLE parallel_stdout
    ERROR_VARIABLE parallel_stderr
)
if(NOT parallel_exit EQUAL 0)
    message(FATAL_ERROR "parallel_retriever --limit-n failed:\n${parallel_stdout}\n${parallel_stderr}")
endif()

file(READ "${sequential_prefix_output}" sequential_text)
file(READ "${parallel_output_path}" parallel_text)
if(NOT sequential_text STREQUAL parallel_text)
    message(FATAL_ERROR "parallel --limit-n output did not match the explicit 16-row sequential prefix baseline")
endif()

file(STRINGS "${run_metrics_path}" run_metrics_lines)
list(GET run_metrics_lines 1 run_metrics_row)
string(REPLACE "," ";" run_metrics_fields "${run_metrics_row}")
list(GET run_metrics_fields 0 field_N)
if(NOT field_N STREQUAL "16")
    message(FATAL_ERROR "expected limited parallel run metrics to report N=16, got: ${run_metrics_row}")
endif()

file(STRINGS "${metrics_path}" metrics_lines)
list(GET metrics_lines 1 first_metric_row)
string(REPLACE "," ";" first_metric_fields "${first_metric_row}")
list(GET first_metric_fields 1 first_local_n)
if(NOT first_local_n STREQUAL "4")
    message(FATAL_ERROR "expected 16 vectors across 4 ranks to yield local_N=4 for rank 0, got: ${first_metric_row}")
endif()

execute_process(
    COMMAND "${CMAKE_COMMAND}" -E env
            OMPI_ALLOW_RUN_AS_ROOT=1
            OMPI_ALLOW_RUN_AS_ROOT_CONFIRM=1
            "${MPIEXEC_EXECUTABLE}" "${MPIEXEC_NUMPROC_FLAG}" "4"
            "${PARALLEL}"
            "--vectors" "${full_memory_path}"
            "--queries" "${query_path}"
            "--topk" "3"
            "--limit-n" "0"
            "--output" "${WORK_DIR}/parallel_invalid_zero.csv"
            "--metrics" "${WORK_DIR}/parallel_invalid_zero_metrics.csv"
    RESULT_VARIABLE invalid_zero_exit
    OUTPUT_VARIABLE invalid_zero_stdout
    ERROR_VARIABLE invalid_zero_stderr
)
if(invalid_zero_exit EQUAL 0)
    message(FATAL_ERROR "parallel_retriever unexpectedly accepted --limit-n 0")
endif()
if(NOT invalid_zero_stderr MATCHES "--limit-n")
    message(FATAL_ERROR "parallel invalid --limit-n 0 failure did not mention --limit-n:\n${invalid_zero_stdout}\n${invalid_zero_stderr}")
endif()

execute_process(
    COMMAND "${CMAKE_COMMAND}" -E env
            OMPI_ALLOW_RUN_AS_ROOT=1
            OMPI_ALLOW_RUN_AS_ROOT_CONFIRM=1
            "${MPIEXEC_EXECUTABLE}" "${MPIEXEC_NUMPROC_FLAG}" "4"
            "${PARALLEL}"
            "--vectors" "${full_memory_path}"
            "--queries" "${query_path}"
            "--topk" "3"
            "--limit-n" "65"
            "--output" "${WORK_DIR}/parallel_invalid_large.csv"
            "--metrics" "${WORK_DIR}/parallel_invalid_large_metrics.csv"
    RESULT_VARIABLE invalid_large_exit
    OUTPUT_VARIABLE invalid_large_stdout
    ERROR_VARIABLE invalid_large_stderr
)
if(invalid_large_exit EQUAL 0)
    message(FATAL_ERROR "parallel_retriever unexpectedly accepted a limit larger than the dataset")
endif()
if(NOT invalid_large_stderr MATCHES "limit")
    message(FATAL_ERROR "parallel large --limit-n failure did not mention limit:\n${invalid_large_stdout}\n${invalid_large_stderr}")
endif()
