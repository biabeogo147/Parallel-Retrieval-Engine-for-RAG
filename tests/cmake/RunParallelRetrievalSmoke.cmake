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
set(memory_path "${WORK_DIR}/memory_vectors.bin")
set(query_path "${WORK_DIR}/query_vectors.bin")
set(sequential_output "${WORK_DIR}/sequential_topk.csv")
set(parallel_output "${WORK_DIR}/parallel_topk.csv")
set(metrics_output "${WORK_DIR}/parallel_metrics.csv")

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

if(NOT EXISTS "${parallel_output}")
    message(FATAL_ERROR "expected parallel CSV output was not created: ${parallel_output}")
endif()

if(NOT EXISTS "${metrics_output}")
    message(FATAL_ERROR "expected metrics CSV output was not created: ${metrics_output}")
endif()

file(STRINGS "${parallel_output}" parallel_lines)
list(LENGTH parallel_lines parallel_line_count)
if(NOT parallel_line_count EQUAL 16)
    message(FATAL_ERROR "expected 16 parallel CSV lines but found ${parallel_line_count}")
endif()

list(GET parallel_lines 0 parallel_header)
if(NOT parallel_header STREQUAL "query_id,rank_position,memory_id,score")
    message(FATAL_ERROR "unexpected parallel CSV header: ${parallel_header}")
endif()

file(STRINGS "${metrics_output}" metrics_lines)
list(LENGTH metrics_lines metrics_line_count)
if(NOT metrics_line_count EQUAL 5)
    message(FATAL_ERROR "expected 5 metrics CSV lines but found ${metrics_line_count}")
endif()

list(GET metrics_lines 0 metrics_header)
if(NOT metrics_header STREQUAL "rank,local_N,compute_time,communication_time,active_time,global_total_time,idle_time")
    message(FATAL_ERROR "unexpected metrics CSV header: ${metrics_header}")
endif()

file(READ "${sequential_output}" sequential_text)
file(READ "${parallel_output}" parallel_text)
if(NOT sequential_text STREQUAL parallel_text)
    message(FATAL_ERROR "parallel top-k CSV did not match sequential output")
endif()
