cmake_minimum_required(VERSION 3.20)

if(NOT DEFINED REPO_ROOT)
    message(FATAL_ERROR "REPO_ROOT is required")
endif()

if(NOT DEFINED WORK_DIR)
    message(FATAL_ERROR "WORK_DIR is required")
endif()

file(MAKE_DIRECTORY "${WORK_DIR}")
set(results_dir "${WORK_DIR}/results")
set(analysis_dir "${results_dir}/analysis")
set(docs_output "${WORK_DIR}/latest-benchmark-review.md")
file(MAKE_DIRECTORY "${results_dir}" "${results_dir}/faiss")

file(WRITE "${results_dir}/runtime_by_N.csv" "N,D,Q,k,P,compute_time,communication_time,total_time\n64,8,100,3,4,20.00000000,10.00000000,30.00000000\n128,8,100,3,4,30.00000000,10.00000000,40.00000000\n")
file(WRITE "${results_dir}/correctness.csv" "query_id,k,matched,matched_ids,max_score_diff,status\n0,3,true,3,0.00000000,PASS\n1,3,true,3,0.00000000,PASS\n")
file(WRITE "${results_dir}/granularity.csv" "rank,local_N,compute_time,communication_time,active_time,global_total_time,idle_time\n0,32,110.00000000,20.00000000,130.00000000,130.00000000,0.00000000\n1,32,110.00000000,20.00000000,130.00000000,130.00000000,0.00000000\n2,32,110.00000000,20.00000000,130.00000000,130.00000000,0.00000000\n3,32,110.00000000,20.00000000,130.00000000,130.00000000,0.00000000\n")
file(WRITE "${results_dir}/speedup.csv" "N,D,Q,k,P,compute_time,communication_time,total_time,compute_speedup,total_speedup,compute_efficiency,total_efficiency\n96,8,200,3,1,300.00000000,0.00000000,300.00000000,1.00000000,1.00000000,1.00000000,1.00000000\n96,8,200,3,4,90.00000000,15.00000000,105.00000000,3.33333333,2.85714286,0.83333333,0.71428572\n")
file(WRITE "${results_dir}/benchmark_selection.env" "N_SELECTED=128\nN_SPEEDUP=96\nP_SELECTED=4\nD=8\nQ=200\nK=3\nEPSILON=1e-5\nCALIBRATION_MODE=N_PLUS_Q\nN_MAX_FEASIBLE=128\n")
file(WRITE "${results_dir}/faiss/comparison.csv" "dataset_name,N,D,Q,k,parallel_workers,faiss_threads,parallel_compute_time,parallel_communication_time,parallel_total_time,faiss_build_time,faiss_compute_time,faiss_total_time,total_ratio,correctness_status,max_score_diff\nsynthetic,128,8,200,3,4,4,30.00000000,10.00000000,40.00000000,1.00000000,8.00000000,8.00000000,5.00000000,PASS,0.00000000\nsquad_minilm,64,8,100,3,4,4,3.00000000,1.00000000,4.00000000,0.10000000,1.00000000,1.00000000,4.00000000,PASS,0.00000000\n")
file(WRITE "${results_dir}/faiss/synthetic_correctness.csv" "query_id,k,matched,matched_ids,max_score_diff,status\n0,3,true,3,0.00000000,PASS\n")
file(WRITE "${results_dir}/faiss/squad_correctness.csv" "query_id,k,matched,matched_ids,max_score_diff,status\n0,3,true,3,0.00000000,PASS\n")

execute_process(
    COMMAND
        python3
        "${REPO_ROOT}/scripts/analyze_benchmarks.py"
        --results-dir "${results_dir}"
        --output-dir "${analysis_dir}"
        --docs-output "${docs_output}"
    RESULT_VARIABLE run_exit
    OUTPUT_VARIABLE run_stdout
    ERROR_VARIABLE run_stderr
)

if(NOT run_exit EQUAL 0)
    message(FATAL_ERROR "analyze_benchmarks.py failed:\n${run_stdout}\n${run_stderr}")
endif()

file(READ "${docs_output}" docs_text)
string(FIND "${docs_text}" "N-only calibration was infeasible on the current hardware" infeasible_index)
if(infeasible_index EQUAL -1)
    message(FATAL_ERROR "expected calibration-aware wording about N-only infeasibility in:\n${docs_text}")
endif()

string(FIND "${docs_text}" "Expand BENCH_N_CANDIDATES first" stale_index)
if(NOT stale_index EQUAL -1)
    message(FATAL_ERROR "analysis should not keep recommending N-only expansion after N_PLUS_Q fallback:\n${docs_text}")
endif()
