if(NOT DEFINED GENERATOR)
    message(FATAL_ERROR "GENERATOR is required")
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

file(MAKE_DIRECTORY "${WORK_DIR}")
set(output_a "${WORK_DIR}/seed12345_a.bin")
set(output_b "${WORK_DIR}/seed12345_b.bin")
set(output_c "${WORK_DIR}/seed67890.bin")

foreach(run_spec
    "${output_a};12345"
    "${output_b};12345"
    "${output_c};67890"
)
    list(GET run_spec 0 output_path)
    list(GET run_spec 1 seed_value)

    execute_process(
        COMMAND "${GENERATOR}" "${COUNT_FLAG}" "${COUNT_VALUE}" "--D" "${DIMENSION}" "--output" "${output_path}" "--seed" "${seed_value}"
        RESULT_VARIABLE generate_exit
        OUTPUT_VARIABLE generate_stdout
        ERROR_VARIABLE generate_stderr
    )

    if(NOT generate_exit EQUAL 0)
        message(FATAL_ERROR "generator failed for ${output_path}:\n${generate_stdout}\n${generate_stderr}")
    endif()
endforeach()

file(SHA256 "${output_a}" hash_a)
file(SHA256 "${output_b}" hash_b)
file(SHA256 "${output_c}" hash_c)

if(NOT hash_a STREQUAL hash_b)
    message(FATAL_ERROR "same seed and args should produce identical output")
endif()

if(hash_a STREQUAL hash_c)
    message(FATAL_ERROR "different seeds should produce different output")
endif()
