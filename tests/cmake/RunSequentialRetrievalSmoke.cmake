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
set(memory_path "${WORK_DIR}/memory_vectors.bin")
set(query_path "${WORK_DIR}/query_vectors.bin")
set(output_path "${WORK_DIR}/sequential_topk.csv")

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
    COMMAND "${SEQUENTIAL}" "--vectors" "${memory_path}" "--queries" "${query_path}" "--topk" "3" "--output" "${output_path}"
    RESULT_VARIABLE sequential_exit
    OUTPUT_VARIABLE sequential_stdout
    ERROR_VARIABLE sequential_stderr
)

if(NOT sequential_exit EQUAL 0)
    message(FATAL_ERROR "sequential_retriever failed:\n${sequential_stdout}\n${sequential_stderr}")
endif()

if(NOT EXISTS "${output_path}")
    message(FATAL_ERROR "expected CSV output was not created: ${output_path}")
endif()

file(STRINGS "${output_path}" csv_lines)
list(LENGTH csv_lines csv_line_count)

if(NOT csv_line_count EQUAL 16)
    message(FATAL_ERROR "expected 16 CSV lines but found ${csv_line_count}")
endif()

list(GET csv_lines 0 csv_header)
if(NOT csv_header STREQUAL "query_id,rank_position,memory_id,score")
    message(FATAL_ERROR "unexpected CSV header: ${csv_header}")
endif()
