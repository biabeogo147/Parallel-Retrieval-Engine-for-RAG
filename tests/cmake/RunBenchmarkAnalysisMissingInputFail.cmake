cmake_minimum_required(VERSION 3.20)

if(NOT DEFINED REPO_ROOT)
    message(FATAL_ERROR "REPO_ROOT is required")
endif()

if(NOT DEFINED WORK_DIR)
    message(FATAL_ERROR "WORK_DIR is required")
endif()

file(MAKE_DIRECTORY "${WORK_DIR}")
set(results_dir "${WORK_DIR}/results")
set(output_dir "${results_dir}/analysis")
set(docs_dir "${WORK_DIR}/docs/analysis")
set(docs_output "${docs_dir}/latest-benchmark-review.md")

file(MAKE_DIRECTORY "${results_dir}" "${results_dir}/faiss" "${docs_dir}")

file(WRITE "${results_dir}/correctness.csv" "query_id,k,matched,matched_ids,max_score_diff,status\n0,3,true,3,0.00000000,PASS\n")
file(WRITE "${results_dir}/granularity.csv" "rank,local_N,compute_time,communication_time,active_time,global_total_time,idle_time\n0,16,1.00000000,0.10000000,1.10000000,1.10600000,0.00600000\n")
file(WRITE "${results_dir}/speedup.csv" "N,D,Q,k,P,compute_time,communication_time,total_time,compute_speedup,total_speedup,compute_efficiency,total_efficiency\n256,8,5,3,1,10.00000000,0.00000000,10.00000000,1.00000000,1.00000000,1.00000000,1.00000000\n")
file(WRITE "${results_dir}/benchmark_selection.env" "N_SELECTED=64\nN_SPEEDUP=128\nP_SELECTED=4\nD=8\nQ=5\nK=3\nEPSILON=1e-5\nCALIBRATION_MODE=N_ONLY\nN_MAX_FEASIBLE=64\n")
file(WRITE "${results_dir}/faiss/comparison.csv" "dataset_name,N,D,Q,k,parallel_workers,faiss_threads,parallel_compute_time,parallel_communication_time,parallel_total_time,faiss_build_time,faiss_compute_time,faiss_total_time,total_ratio,correctness_status,max_score_diff\nsynthetic,64,8,5,3,4,4,0.40000000,0.05000000,0.50000000,0.01000000,0.10000000,0.10000000,5.00000000,PASS,0.00000000\n")
file(WRITE "${results_dir}/faiss/synthetic_correctness.csv" "query_id,k,matched,matched_ids,max_score_diff,status\n0,3,true,3,0.00000000,PASS\n")
file(WRITE "${results_dir}/faiss/squad_correctness.csv" "query_id,k,matched,matched_ids,max_score_diff,status\n0,3,true,3,0.00000000,PASS\n")

execute_process(
    COMMAND
        python3
        "${REPO_ROOT}/scripts/analyze_benchmarks.py"
        --results-dir "${results_dir}"
        --output-dir "${output_dir}"
        --docs-output "${docs_output}"
    RESULT_VARIABLE run_exit
    OUTPUT_VARIABLE run_stdout
    ERROR_VARIABLE run_stderr
)

if(run_exit EQUAL 0)
    message(FATAL_ERROR "analyze_benchmarks.py unexpectedly succeeded without runtime_by_N.csv")
endif()

if(NOT run_stdout MATCHES "runtime_by_N.csv" AND NOT run_stderr MATCHES "runtime_by_N.csv")
    message(FATAL_ERROR "missing-input failure did not name runtime_by_N.csv:\nSTDOUT:\n${run_stdout}\nSTDERR:\n${run_stderr}")
endif()
