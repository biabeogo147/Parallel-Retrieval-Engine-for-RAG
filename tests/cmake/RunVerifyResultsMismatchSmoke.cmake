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
    "0,2,12,0.80000000\n"
)

file(WRITE "${parallel_output}"
    "query_id,rank_position,memory_id,score\n"
    "0,1,10,0.90000000\n"
    "0,2,99,0.80000000\n"
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

if(NOT verify_exit EQUAL 1)
    message(FATAL_ERROR "verify_results should return 1 on mismatch, got ${verify_exit}:\n${verify_stdout}\n${verify_stderr}")
endif()

if(NOT EXISTS "${correctness_output}")
    message(FATAL_ERROR "expected correctness CSV output was not created: ${correctness_output}")
endif()

file(STRINGS "${correctness_output}" correctness_lines)
list(LENGTH correctness_lines correctness_line_count)
if(NOT correctness_line_count EQUAL 2)
    message(FATAL_ERROR "expected 2 correctness CSV lines but found ${correctness_line_count}")
endif()

list(GET correctness_lines 1 result_line)
string(FIND "${result_line}" "false,1," matched_index)
if(matched_index EQUAL -1)
    message(FATAL_ERROR "expected mismatch row with matched=false and matched_ids=1, got: ${result_line}")
endif()

string(FIND "${result_line}" ",FAIL" fail_index)
if(fail_index EQUAL -1)
    message(FATAL_ERROR "expected FAIL status, got: ${result_line}")
endif()

string(FIND "${verify_stdout}" "Correctness check FAILED: 0/1 queries passed" summary_index)
if(summary_index EQUAL -1)
    message(FATAL_ERROR "expected mismatch summary, got:\n${verify_stdout}\n${verify_stderr}")
endif()
