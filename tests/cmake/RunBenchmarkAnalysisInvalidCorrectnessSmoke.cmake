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

file(WRITE "${results_dir}/runtime_by_N.csv" "N,D,Q,k,P,compute_time,communication_time,total_time\n64,8,5,3,4,0.40000000,0.05000000,0.50000000\n")
file(WRITE "${results_dir}/correctness.csv" "query_id,k,matched,matched_ids,max_score_diff,status\n0,3,false,2,0.01000000,FAIL\n")
file(WRITE "${results_dir}/granularity.csv" "rank,local_N,compute_time,communication_time,active_time,global_total_time,idle_time\n0,16,1.00000000,0.10000000,1.10000000,1.10200000,0.00200000\n1,16,1.01000000,0.09000000,1.10000000,1.10200000,0.00200000\n")
file(WRITE "${results_dir}/speedup.csv" "N,D,Q,k,P,compute_time,communication_time,total_time,compute_speedup,total_speedup,compute_efficiency,total_efficiency\n256,8,5,3,1,10.00000000,0.00000000,10.00000000,1.00000000,1.00000000,1.00000000,1.00000000\n256,8,5,3,2,5.10000000,0.10000000,5.20000000,1.96078431,1.92307692,0.98039216,0.96153846\n")
file(WRITE "${results_dir}/benchmark_selection.env" "N_SELECTED=64\nN_SPEEDUP=128\nP_SELECTED=4\nD=8\nQ=5\nK=3\nEPSILON=1e-5\n")
file(WRITE "${results_dir}/faiss/comparison.csv" "dataset_name,N,D,Q,k,parallel_workers,faiss_threads,parallel_compute_time,parallel_communication_time,parallel_total_time,faiss_build_time,faiss_compute_time,faiss_total_time,total_ratio,correctness_status,max_score_diff\nsynthetic,64,8,5,3,4,4,0.40000000,0.05000000,0.50000000,0.01000000,0.10000000,0.10000000,5.00000000,FAIL,0.01000000\nsquad_minilm,32,8,5,3,4,4,0.12000000,0.02000000,0.15000000,0.01000000,0.04000000,0.04000000,3.75000000,PASS,0.00000005\n")
file(WRITE "${results_dir}/faiss/synthetic_correctness.csv" "query_id,k,matched,matched_ids,max_score_diff,status\n0,3,false,2,0.01000000,FAIL\n")
file(WRITE "${results_dir}/faiss/squad_correctness.csv" "query_id,k,matched,matched_ids,max_score_diff,status\n0,3,true,3,0.00000005,PASS\n")

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

if(NOT run_exit EQUAL 0)
    message(FATAL_ERROR "analyze_benchmarks.py failed:\n${run_stdout}\n${run_stderr}")
endif()

file(READ "${output_dir}/benchmark_summary.json" summary_text)
if(NOT summary_text MATCHES "\"performance_conclusions_status\": \"INVALID_UNTIL_CORRECTNESS_FIXED\"")
    message(FATAL_ERROR "benchmark_summary.json does not mark performance conclusions as invalid when correctness fails:\n${summary_text}")
endif()

file(READ "${docs_output}" docs_output_text)
if(NOT docs_output_text MATCHES "INVALID_UNTIL_CORRECTNESS_FIXED")
    message(FATAL_ERROR "docs output does not mention INVALID_UNTIL_CORRECTNESS_FIXED when correctness fails:\n${docs_output_text}")
endif()
