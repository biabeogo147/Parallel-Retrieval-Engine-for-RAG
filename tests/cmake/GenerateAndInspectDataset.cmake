if(NOT DEFINED GENERATOR)
    message(FATAL_ERROR "GENERATOR is required")
endif()

if(NOT DEFINED INSPECTOR)
    message(FATAL_ERROR "INSPECTOR is required")
endif()

if(NOT DEFINED COUNT_FLAG)
    message(FATAL_ERROR "COUNT_FLAG is required")
endif()

if(NOT DEFINED COUNT_VALUE)
    message(FATAL_ERROR "COUNT_VALUE is required")
endif()

if(NOT DEFINED DIMENSION)
    message(FATAL_ERROR "DIMENSION is required")
endif()

if(NOT DEFINED WORK_DIR)
    message(FATAL_ERROR "WORK_DIR is required")
endif()

if(NOT DEFINED OUTPUT_NAME)
    message(FATAL_ERROR "OUTPUT_NAME is required")
endif()

file(MAKE_DIRECTORY "${WORK_DIR}")
set(output_path "${WORK_DIR}/${OUTPUT_NAME}")

execute_process(
    COMMAND "${GENERATOR}" "${COUNT_FLAG}" "${COUNT_VALUE}" "--D" "${DIMENSION}" "--output" "${output_path}" "--seed" "12345"
    RESULT_VARIABLE generate_exit
    OUTPUT_VARIABLE generate_stdout
    ERROR_VARIABLE generate_stderr
)

if(NOT generate_exit EQUAL 0)
    message(FATAL_ERROR "generator failed:\n${generate_stdout}\n${generate_stderr}")
endif()

if(NOT EXISTS "${output_path}")
    message(FATAL_ERROR "expected output file was not created: ${output_path}")
endif()

execute_process(
    COMMAND "${INSPECTOR}" "--input" "${output_path}"
    RESULT_VARIABLE inspect_exit
    OUTPUT_VARIABLE inspect_stdout
    ERROR_VARIABLE inspect_stderr
)

if(NOT inspect_exit EQUAL 0)
    message(FATAL_ERROR "inspect_dataset failed:\n${inspect_stdout}\n${inspect_stderr}")
endif()

foreach(expected_line
    "magic = PMRAGV1"
    "version = 1"
    "flags = 3"
    "num_vectors = ${COUNT_VALUE}"
    "dimension = ${DIMENSION}"
)
    string(FIND "${inspect_stdout}" "${expected_line}" found_index)
    if(found_index EQUAL -1)
        message(FATAL_ERROR "inspect_dataset output did not contain: ${expected_line}\nActual output:\n${inspect_stdout}")
    endif()
endforeach()
