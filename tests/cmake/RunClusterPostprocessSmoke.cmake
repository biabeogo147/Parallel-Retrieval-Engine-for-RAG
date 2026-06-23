cmake_minimum_required(VERSION 3.20)

if(NOT DEFINED REPO_ROOT)
    message(FATAL_ERROR "REPO_ROOT is required")
endif()

if(NOT DEFINED WORK_DIR)
    message(FATAL_ERROR "WORK_DIR is required")
endif()

file(MAKE_DIRECTORY "${WORK_DIR}")
set(results_dir "${WORK_DIR}/results/cluster/2026-06-23-local-plus-199-full-bundle")
set(analysis_dir "${results_dir}/analysis")
set(docs_output "${WORK_DIR}/docs/analysis/latest-cluster-benchmark-review.md")

file(MAKE_DIRECTORY "${results_dir}" "${results_dir}/faiss" "${WORK_DIR}/docs/analysis")

file(WRITE "${results_dir}/runtime_by_N.csv" "N,D,Q,k,P,compute_time,communication_time,total_time\n64,8,100,3,14,40.00000000,15.00000000,60.00000000\n128,8,100,3,14,70.00000000,20.00000000,95.00000000\n")
file(WRITE "${results_dir}/correctness.csv" "query_id,k,matched,matched_ids,max_score_diff,status\n0,3,true,3,0.00000000,PASS\n1,3,true,3,0.00000000,PASS\n")
file(WRITE "${results_dir}/granularity.csv" "rank,local_N,compute_time,communication_time,active_time,global_total_time,idle_time\n0,10,130.00000000,15.00000000,145.00000000,145.00300000,0.00300000\n1,10,129.90000000,15.10000000,145.00000000,145.00300000,0.00300000\n2,10,129.95000000,15.05000000,145.00000000,145.00300000,0.00300000\n3,10,129.98000000,15.02000000,145.00000000,145.00300000,0.00300000\n")
file(WRITE "${results_dir}/speedup.csv" "N,D,Q,k,P,compute_time,communication_time,total_time,compute_speedup,total_speedup,compute_efficiency,total_efficiency\n256,8,200,3,1,300.00000000,0.00000000,300.00000000,1.00000000,1.00000000,1.00000000,1.00000000\n256,8,200,3,10,60.00000000,20.00000000,80.00000000,5.00000000,3.75000000,0.50000000,0.37500000\n256,8,200,3,14,55.00000000,40.00000000,100.00000000,5.45454545,3.00000000,0.38961039,0.21428571\n")
file(WRITE "${results_dir}/benchmark_selection.env" "N_SELECTED=128\nN_SPEEDUP=256\nP_SELECTED=14\nD=8\nQ=200\nK=3\nEPSILON=1e-5\nCALIBRATION_MODE=N_PLUS_Q\nN_MAX_FEASIBLE=128\n")
file(WRITE "${results_dir}/faiss/comparison.csv" "dataset_name,N,D,Q,k,parallel_workers,faiss_threads,parallel_compute_time,parallel_communication_time,parallel_total_time,faiss_build_time,faiss_compute_time,faiss_total_time,total_ratio,correctness_status,max_score_diff\nsynthetic,128,8,200,3,14,10,55.00000000,40.00000000,100.00000000,0.10000000,10.00000000,10.00000000,10.00000000,PASS,0.00000000\nsquad_minilm,64,8,100,3,14,10,6.00000000,2.00000000,9.00000000,0.05000000,1.00000000,1.00000000,9.00000000,PASS,0.00000000\n")
file(WRITE "${results_dir}/faiss/synthetic_correctness.csv" "query_id,k,matched,matched_ids,max_score_diff,status\n0,3,true,3,0.00000000,PASS\n")
file(WRITE "${results_dir}/faiss/squad_correctness.csv" "query_id,k,matched,matched_ids,max_score_diff,status\n0,3,true,3,0.00000000,PASS\n")

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
    message(FATAL_ERROR "run_cluster_postprocess.sh failed:\n${run_stdout}\n${run_stderr}")
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
        message(FATAL_ERROR "expected cluster postprocess artifact was not created: ${required_path}")
    endif()
endforeach()

file(READ "${docs_output}" docs_text)
if(NOT docs_text MATCHES "single-node exact-flat baseline")
    message(FATAL_ERROR "cluster docs output must explain the single-node FAISS baseline fairness story:\n${docs_text}")
endif()
if(NOT docs_text MATCHES "distributed MPI run")
    message(FATAL_ERROR "cluster docs output must explain the distributed MPI comparison context:\n${docs_text}")
endif()
