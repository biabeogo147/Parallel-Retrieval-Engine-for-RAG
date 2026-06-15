cmake_minimum_required(VERSION 3.20)

if(NOT DEFINED VERIFY_RESULTS)
    message(FATAL_ERROR "VERIFY_RESULTS is required")
endif()

if(NOT DEFINED WORK_DIR)
    message(FATAL_ERROR "WORK_DIR is required")
endif()

file(MAKE_DIRECTORY "${WORK_DIR}")
set(sequential_output "${WORK_DIR}/sequential_topk.csv")
set(parallel_output "${WORK_DIR}/parallel_topk.csv")
set(correctness_output "${WORK_DIR}/correctness.csv")

file(WRITE "${sequential_output}"
    "query_id,rank_position,memory_id,score\n"
    "0,1,10,0.90000000\n"
)

file(WRITE "${parallel_output}"
    "query_id,rank,memory_id,score\n"
    "0,1,10,0.90000000\n"
)

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

if(NOT verify_exit EQUAL 2)
    message(FATAL_ERROR "verify_results should return 2 on malformed input, got ${verify_exit}:\n${verify_stdout}\n${verify_stderr}")
endif()

set(combined_output "${verify_stdout}\n${verify_stderr}")
string(FIND "${combined_output}" "unexpected CSV header" header_index)
if(header_index EQUAL -1)
    message(FATAL_ERROR "expected malformed-header error, got:\n${combined_output}")
endif()
