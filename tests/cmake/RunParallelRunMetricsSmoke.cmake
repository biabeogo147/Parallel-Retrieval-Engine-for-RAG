cmake_minimum_required(VERSION 3.20)

if(NOT DEFINED GENERATE_VECTORS)
    message(FATAL_ERROR "GENERATE_VECTORS is required")
endif()

if(NOT DEFINED GENERATE_QUERIES)
    message(FATAL_ERROR "GENERATE_QUERIES is required")
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
set(output_path "${WORK_DIR}/parallel_topk.csv")
set(metrics_path "${WORK_DIR}/parallel_metrics.csv")
set(run_metrics_path "${WORK_DIR}/parallel_run_metrics.csv")

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
    COMMAND "${CMAKE_COMMAND}" -E env
            OMPI_ALLOW_RUN_AS_ROOT=1
            OMPI_ALLOW_RUN_AS_ROOT_CONFIRM=1
            "${MPIEXEC_EXECUTABLE}" "${MPIEXEC_NUMPROC_FLAG}" "4"
            "${PARALLEL}"
            "--vectors" "${memory_path}"
            "--queries" "${query_path}"
            "--topk" "3"
            "--output" "${output_path}"
            "--metrics" "${metrics_path}"
            "--run-metrics" "${run_metrics_path}"
    RESULT_VARIABLE parallel_exit
    OUTPUT_VARIABLE parallel_stdout
    ERROR_VARIABLE parallel_stderr
)

if(NOT parallel_exit EQUAL 0)
    message(FATAL_ERROR "parallel_retriever failed:\n${parallel_stdout}\n${parallel_stderr}")
endif()

if(NOT EXISTS "${run_metrics_path}")
    message(FATAL_ERROR "expected parallel run metrics CSV was not created: ${run_metrics_path}")
endif()

if(NOT EXISTS "${metrics_path}")
    message(FATAL_ERROR "expected parallel metrics CSV was not created: ${metrics_path}")
endif()

file(STRINGS "${run_metrics_path}" run_metrics_lines)
list(LENGTH run_metrics_lines run_metrics_line_count)
if(NOT run_metrics_line_count EQUAL 2)
    message(FATAL_ERROR "expected 2 run metrics CSV lines but found ${run_metrics_line_count}")
endif()

list(GET run_metrics_lines 0 run_metrics_header)
if(NOT run_metrics_header STREQUAL "N,D,Q,k,P,compute_time,communication_time,total_time")
    message(FATAL_ERROR "unexpected run metrics header: ${run_metrics_header}")
endif()

list(GET run_metrics_lines 1 run_metrics_row)
string(REPLACE "," ";" run_metrics_fields "${run_metrics_row}")
list(LENGTH run_metrics_fields run_metrics_field_count)
if(NOT run_metrics_field_count EQUAL 8)
    message(FATAL_ERROR "expected 8 fields in run metrics row but found ${run_metrics_field_count}: ${run_metrics_row}")
endif()

list(GET run_metrics_fields 0 field_N)
list(GET run_metrics_fields 1 field_D)
list(GET run_metrics_fields 2 field_Q)
list(GET run_metrics_fields 3 field_k)
list(GET run_metrics_fields 4 field_P)
list(GET run_metrics_fields 7 field_total)

if(NOT field_N STREQUAL "64")
    message(FATAL_ERROR "unexpected N in run metrics row: ${run_metrics_row}")
endif()
if(NOT field_D STREQUAL "8")
    message(FATAL_ERROR "unexpected D in run metrics row: ${run_metrics_row}")
endif()
if(NOT field_Q STREQUAL "5")
    message(FATAL_ERROR "unexpected Q in run metrics row: ${run_metrics_row}")
endif()
if(NOT field_k STREQUAL "3")
    message(FATAL_ERROR "unexpected k in run metrics row: ${run_metrics_row}")
endif()
if(NOT field_P STREQUAL "4")
    message(FATAL_ERROR "unexpected P in run metrics row: ${run_metrics_row}")
endif()

file(STRINGS "${metrics_path}" metrics_lines)
list(LENGTH metrics_lines metrics_line_count)
if(NOT metrics_line_count EQUAL 5)
    message(FATAL_ERROR "expected 5 metrics CSV lines but found ${metrics_line_count}")
endif()

list(GET metrics_lines 1 first_metric_row)
string(REPLACE "," ";" first_metric_fields "${first_metric_row}")
list(GET first_metric_fields 5 first_global_total)

if(NOT field_total STREQUAL first_global_total)
    message(FATAL_ERROR "run summary total_time should match global_total_time from per-rank metrics:\nrun=${run_metrics_row}\nmetric=${first_metric_row}")
endif()
