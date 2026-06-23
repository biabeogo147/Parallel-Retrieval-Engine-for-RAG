cmake_minimum_required(VERSION 3.20)

if(NOT DEFINED REPO_ROOT)
    message(FATAL_ERROR "REPO_ROOT is required")
endif()

if(NOT DEFINED WORK_DIR)
    message(FATAL_ERROR "WORK_DIR is required")
endif()

file(MAKE_DIRECTORY "${WORK_DIR}")
set(results_dir "${WORK_DIR}/results/cluster/2026-06-23-local-plus-199-no-faiss")
set(analysis_dir "${results_dir}/analysis")
set(docs_output "${WORK_DIR}/docs/analysis/latest-cluster-benchmark-review.md")

file(MAKE_DIRECTORY "${results_dir}" "${WORK_DIR}/docs/analysis")

file(WRITE "${results_dir}/runtime_by_N.csv" "N,D,Q,k,P,compute_time,communication_time,total_time\n4000000,384,100,10,14,15.00000000,2.00000000,16.50000000\n10000000,384,100,10,14,34.69482769,4.43894768,36.62555562\n10000000,384,400,10,14,142.00000000,18.00000000,145.00000000\n")
file(WRITE "${results_dir}/correctness.csv" "query_id,k,matched,matched_ids,max_score_diff,status\n0,10,true,10,0.00000000,PASS\n1,10,true,10,0.00000000,PASS\n")
file(WRITE "${results_dir}/granularity.csv" "rank,local_N,compute_time,communication_time,active_time,global_total_time,idle_time\n0,714286,129.50000000,15.00000000,144.50000000,145.00000000,0.50000000\n1,714286,129.40000000,15.05000000,144.45000000,145.00000000,0.55000000\n2,714286,129.45000000,15.03000000,144.48000000,145.00000000,0.52000000\n3,714286,129.47000000,15.01000000,144.48000000,145.00000000,0.52000000\n")
file(WRITE "${results_dir}/speedup.csv" "N,D,Q,k,P,compute_time,communication_time,total_time,compute_speedup,total_speedup,compute_efficiency,total_efficiency\n5000000,384,400,10,1,900.00000000,0.00000000,905.00000000,1.00000000,1.00000000,1.00000000,1.00000000\n5000000,384,400,10,2,470.00000000,25.00000000,498.00000000,1.91489362,1.81726908,0.95744681,0.90863454\n5000000,384,400,10,4,245.00000000,32.00000000,280.00000000,3.67346939,3.23214286,0.91836735,0.80803571\n5000000,384,400,10,8,132.00000000,38.00000000,175.00000000,6.81818182,5.17142857,0.85227273,0.64642857\n5000000,384,400,10,14,86.00000000,45.00000000,140.00000000,10.46511628,6.46428571,0.74750831,0.46173469\n")
file(WRITE "${results_dir}/benchmark_selection.env" "N_SELECTED=10000000\nN_SPEEDUP=5000000\nP_SELECTED=14\nD=384\nQ=400\nK=10\nEPSILON=1e-5\nCALIBRATION_MODE=N_PLUS_Q\nN_MAX_FEASIBLE=10000000\n")

execute_process(
    COMMAND
        "${CMAKE_COMMAND}" -E env
        "BENCH_PLOT_VENV_DIR=${REPO_ROOT}/.venv"
        bash
        "${REPO_ROOT}/scripts/run_cluster_postprocess.sh"
        --results-dir "${results_dir}"
        --docs-output "${docs_output}"
    RESULT_VARIABLE run_exit
    OUTPUT_VARIABLE run_stdout
    ERROR_VARIABLE run_stderr
)

if(NOT run_exit EQUAL 0)
    message(FATAL_ERROR "run_cluster_postprocess.sh failed without FAISS inputs:\n${run_stdout}\n${run_stderr}")
endif()

foreach(required_path
    "${results_dir}/figures/runtime_by_N.png"
    "${results_dir}/figures/granularity.png"
    "${results_dir}/figures/speedup_runtime.png"
    "${results_dir}/figures/speedup_curves.png"
    "${analysis_dir}/runtime_analysis.csv"
    "${analysis_dir}/granularity_analysis.csv"
    "${analysis_dir}/speedup_analysis.csv"
    "${analysis_dir}/faiss_analysis.csv"
    "${analysis_dir}/benchmark_summary.json"
    "${analysis_dir}/final_conclusions.md"
    "${docs_output}")
    if(NOT EXISTS "${required_path}")
        message(FATAL_ERROR "expected no-FAISS cluster postprocess artifact was not created: ${required_path}")
    endif()
endforeach()

file(READ "${docs_output}" docs_text)
if(NOT docs_text MATCHES "FAISS comparison was skipped")
    message(FATAL_ERROR "cluster docs output must explain that FAISS was skipped for this run:\n${docs_text}")
endif()
