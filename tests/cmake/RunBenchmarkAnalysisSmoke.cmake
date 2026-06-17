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

file(WRITE "${results_dir}/runtime_by_N.csv" "N,D,Q,k,P,compute_time,communication_time,total_time\n64,8,5,3,4,0.40000000,0.05000000,0.50000000\n128,8,5,3,4,0.80000000,0.06000000,0.90000000\n")
file(WRITE "${results_dir}/correctness.csv" "query_id,k,matched,matched_ids,max_score_diff,status\n0,3,true,3,0.00000000,PASS\n1,3,true,3,0.00000000,PASS\n")
file(WRITE "${results_dir}/granularity.csv" "rank,local_N,compute_time,communication_time,active_time,global_total_time,idle_time\n0,16,1.00000000,0.10000000,1.10000000,1.10200000,0.00200000\n1,16,1.01000000,0.09000000,1.10000000,1.10200000,0.00200000\n2,16,1.00500000,0.09500000,1.10000000,1.10200000,0.00200000\n3,16,1.00800000,0.09100000,1.09900000,1.10200000,0.00300000\n")
file(WRITE "${results_dir}/speedup.csv" "N,D,Q,k,P,compute_time,communication_time,total_time,compute_speedup,total_speedup,compute_efficiency,total_efficiency\n256,8,5,3,1,10.00000000,0.00000000,10.00000000,1.00000000,1.00000000,1.00000000,1.00000000\n256,8,5,3,2,5.10000000,0.10000000,5.20000000,1.96078431,1.92307692,0.98039216,0.96153846\n256,8,5,3,4,2.60000000,0.20000000,2.90000000,3.84615385,3.44827586,0.96153846,0.86206897\n256,8,5,3,8,1.40000000,0.30000000,1.90000000,7.14285714,5.26315789,0.89285714,0.65789474\n256,8,5,3,10,1.20000000,0.35000000,1.70000000,8.33333333,5.88235294,0.83333333,0.58823529\n256,8,5,3,20,1.30000000,1.80000000,3.50000000,7.69230769,2.85714286,0.38461538,0.14285714\n")
file(WRITE "${results_dir}/benchmark_selection.env" "N_SELECTED=128\nN_SPEEDUP=256\nP_SELECTED=10\nD=8\nQ=5\nK=3\nEPSILON=1e-5\n")
file(WRITE "${results_dir}/faiss/comparison.csv" "dataset_name,N,D,Q,k,parallel_workers,faiss_threads,parallel_compute_time,parallel_communication_time,parallel_total_time,faiss_build_time,faiss_compute_time,faiss_total_time,total_ratio,correctness_status,max_score_diff\nsynthetic,128,8,5,3,10,10,0.80000000,0.10000000,0.90000000,0.05000000,0.30000000,0.30000000,3.00000000,PASS,0.00000010\nsquad_minilm,32,8,5,3,10,10,0.12000000,0.02000000,0.15000000,0.01000000,0.04000000,0.04000000,3.75000000,PASS,0.00000005\n")
file(WRITE "${results_dir}/faiss/synthetic_correctness.csv" "query_id,k,matched,matched_ids,max_score_diff,status\n0,3,true,3,0.00000010,PASS\n")
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

foreach(required_path
    "${output_dir}/runtime_analysis.csv"
    "${output_dir}/granularity_analysis.csv"
    "${output_dir}/speedup_analysis.csv"
    "${output_dir}/faiss_analysis.csv"
    "${output_dir}/benchmark_summary.json"
    "${output_dir}/final_conclusions.md"
    "${docs_output}")
    if(NOT EXISTS "${required_path}")
        message(FATAL_ERROR "expected analysis artifact was not created: ${required_path}")
    endif()
endforeach()

file(READ "${output_dir}/runtime_analysis.csv" runtime_analysis_text)
if(NOT runtime_analysis_text MATCHES "UNDER_TARGET")
    message(FATAL_ERROR "runtime_analysis.csv does not contain UNDER_TARGET classification:\n${runtime_analysis_text}")
endif()

file(READ "${output_dir}/granularity_analysis.csv" granularity_analysis_text)
if(NOT granularity_analysis_text MATCHES "BALANCED_BUT_IDLE_RATIO_SENSITIVE")
    message(FATAL_ERROR "granularity_analysis.csv does not contain BALANCED_BUT_IDLE_RATIO_SENSITIVE classification:\n${granularity_analysis_text}")
endif()

file(READ "${output_dir}/speedup_analysis.csv" speedup_analysis_text)
if(NOT speedup_analysis_text MATCHES "WEAK")
    message(FATAL_ERROR "speedup_analysis.csv does not contain expected efficiency band classification:\n${speedup_analysis_text}")
endif()

file(READ "${output_dir}/faiss_analysis.csv" faiss_analysis_text)
if(NOT faiss_analysis_text MATCHES "LARGE_GAP")
    message(FATAL_ERROR "faiss_analysis.csv does not contain LARGE_GAP classification:\n${faiss_analysis_text}")
endif()

file(READ "${output_dir}/benchmark_summary.json" summary_text)
if(NOT summary_text MATCHES "\"performance_conclusions_status\": \"VALID\"")
    message(FATAL_ERROR "benchmark_summary.json does not mark performance conclusions as VALID:\n${summary_text}")
endif()
if(NOT summary_text MATCHES "\"recommended_operating_p\": 4")
    message(FATAL_ERROR "benchmark_summary.json does not contain the expected recommended_operating_p:\n${summary_text}")
endif()
if(NOT summary_text MATCHES "\"speedup_regression_p\": 20")
    message(FATAL_ERROR "benchmark_summary.json does not contain the expected speedup_regression_p:\n${summary_text}")
endif()

file(READ "${docs_output}" docs_output_text)
foreach(required_heading
    "## 1. Benchmark Validity Check"
    "## 2. Runtime-by-N Findings"
    "## 3. Correctness Findings"
    "## 4. Granularity/Load-Balance Findings"
    "## 5. Speedup Findings"
    "## 6. FAISS Comparison Findings"
    "## 7. Final Conclusion"
    "## 8. Recommended Next Steps")
    if(NOT docs_output_text MATCHES "${required_heading}")
        message(FATAL_ERROR "docs output is missing required heading '${required_heading}':\n${docs_output_text}")
    endif()
endforeach()
