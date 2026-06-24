cmake_minimum_required(VERSION 3.20)

project(parallel_agent_memory_retriever LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

include(CTest)
find_package(MPI REQUIRED)

add_library(
    retriever_core
    src/BinaryDataset.cpp
    src/BenchmarkMetrics.cpp
    src/Config.cpp
    src/CorrectnessChecker.cpp
    src/Logger.cpp
    src/ParallelRetriever.cpp
    src/SequentialRetriever.cpp
    src/TopKHeap.cpp
)

target_include_directories(retriever_core PUBLIC include)

add_executable(
    sequential_retriever
    src/main_sequential.cpp
)

target_link_libraries(sequential_retriever PRIVATE retriever_core)

add_executable(
    parallel_retriever
    src/main_parallel.cpp
    src/MpiUtils.cpp
    src/MpiSession.cpp
)

target_link_libraries(
    parallel_retriever
    PRIVATE
        retriever_core
        MPI::MPI_CXX
)

add_executable(
    generate_vectors
    tools/generate_vectors.cpp
)

target_include_directories(generate_vectors PRIVATE tools)
target_link_libraries(generate_vectors PRIVATE retriever_core)

add_executable(
    generate_queries
    tools/generate_queries.cpp
)

target_include_directories(generate_queries PRIVATE tools)
target_link_libraries(generate_queries PRIVATE retriever_core)

add_executable(
    inspect_dataset
    tools/inspect_dataset.cpp
)

target_link_libraries(inspect_dataset PRIVATE retriever_core)

add_executable(
    config_logger_test
    tests/ConfigLoggerTest.cpp
)

target_link_libraries(config_logger_test PRIVATE retriever_core)

add_executable(
    binary_dataset_test
    tests/BinaryDatasetTest.cpp
)

target_link_libraries(binary_dataset_test PRIVATE retriever_core)

add_executable(
    sequential_retriever_test
    tests/SequentialRetrieverTest.cpp
)

target_link_libraries(sequential_retriever_test PRIVATE retriever_core)

add_executable(
    parallel_retriever_test
    tests/ParallelRetrieverTest.cpp
)

target_link_libraries(parallel_retriever_test PRIVATE retriever_core)

add_executable(
    correctness_checker_test
    tests/CorrectnessCheckerTest.cpp
)

target_link_libraries(correctness_checker_test PRIVATE retriever_core)

add_executable(
    benchmark_metrics_test
    tests/BenchmarkMetricsTest.cpp
)

target_link_libraries(benchmark_metrics_test PRIVATE retriever_core)

add_executable(
    verify_results
    tools/verify_results.cpp
)

target_link_libraries(verify_results PRIVATE retriever_core)

if(BUILD_TESTING)
    add_test(NAME config_logger_test COMMAND config_logger_test)
    add_test(NAME binary_dataset_test COMMAND binary_dataset_test)
    add_test(NAME sequential_retriever_test COMMAND sequential_retriever_test)
    add_test(NAME parallel_retriever_test COMMAND parallel_retriever_test)
    add_test(NAME correctness_checker_test COMMAND correctness_checker_test)
    add_test(NAME benchmark_metrics_test COMMAND benchmark_metrics_test)
    add_test(NAME sequential_help COMMAND sequential_retriever --help)
    add_test(NAME generate_vectors_help COMMAND generate_vectors --help)
    add_test(NAME generate_queries_help COMMAND generate_queries --help)
    add_test(NAME inspect_dataset_help COMMAND inspect_dataset --help)
    add_test(NAME verify_results_help COMMAND verify_results --help)
    add_test(
        NAME sequential_unknown_flag
        COMMAND sequential_retriever --bogus
    )
    set_tests_properties(sequential_unknown_flag PROPERTIES WILL_FAIL TRUE)

    add_test(
        NAME sequential_missing_topk_value
        COMMAND sequential_retriever
                --vectors vectors.bin
                --queries queries.bin
                --output output.csv
                --topk
    )
    set_tests_properties(sequential_missing_topk_value PROPERTIES WILL_FAIL TRUE)

    add_test(
        NAME parallel_help
        COMMAND
            ${CMAKE_COMMAND} -E env
            OMPI_ALLOW_RUN_AS_ROOT=1
            OMPI_ALLOW_RUN_AS_ROOT_CONFIRM=1
            ${MPIEXEC_EXECUTABLE}
            ${MPIEXEC_NUMPROC_FLAG} 4
            $<TARGET_FILE:parallel_retriever>
            --help
    )
    add_test(
        NAME generate_vectors_and_inspect
        COMMAND
            ${CMAKE_COMMAND}
            -DGENERATOR=$<TARGET_FILE:generate_vectors>
            -DINSPECTOR=$<TARGET_FILE:inspect_dataset>
            -DCOUNT_FLAG=--N
            -DCOUNT_VALUE=8
            -DDIMENSION=4
            -DWORK_DIR=${CMAKE_CURRENT_BINARY_DIR}/phase2_vectors_smoke
            -DOUTPUT_NAME=memory_vectors.bin
            -P
            ${CMAKE_CURRENT_SOURCE_DIR}/tests/cmake/GenerateAndInspectDataset.cmake
    )
    add_test(
        NAME generate_queries_and_inspect
        COMMAND
            ${CMAKE_COMMAND}
            -DGENERATOR=$<TARGET_FILE:generate_queries>
            -DINSPECTOR=$<TARGET_FILE:inspect_dataset>
            -DCOUNT_FLAG=--Q
            -DCOUNT_VALUE=5
            -DDIMENSION=4
            -DWORK_DIR=${CMAKE_CURRENT_BINARY_DIR}/phase2_queries_smoke
            -DOUTPUT_NAME=query_vectors.bin
            -P
            ${CMAKE_CURRENT_SOURCE_DIR}/tests/cmake/GenerateAndInspectDataset.cmake
    )
    add_test(
        NAME generate_vectors_determinism
        COMMAND
            ${CMAKE_COMMAND}
            -DGENERATOR=$<TARGET_FILE:generate_vectors>
            -DCOUNT_FLAG=--N
            -DCOUNT_VALUE=6
            -DDIMENSION=3
            -DWORK_DIR=${CMAKE_CURRENT_BINARY_DIR}/phase2_determinism
            -P
            ${CMAKE_CURRENT_SOURCE_DIR}/tests/cmake/CheckGeneratorDeterminism.cmake
    )
    add_test(
        NAME sequential_retrieval_smoke
        COMMAND
            ${CMAKE_COMMAND}
            -DGENERATE_VECTORS=$<TARGET_FILE:generate_vectors>
            -DGENERATE_QUERIES=$<TARGET_FILE:generate_queries>
            -DSEQUENTIAL=$<TARGET_FILE:sequential_retriever>
            -DWORK_DIR=${CMAKE_CURRENT_BINARY_DIR}/phase3_sequential_smoke
            -P
            ${CMAKE_CURRENT_SOURCE_DIR}/tests/cmake/RunSequentialRetrievalSmoke.cmake
    )
    add_test(
        NAME sequential_dimension_mismatch_fails
        COMMAND
            ${CMAKE_COMMAND}
            -DGENERATE_VECTORS=$<TARGET_FILE:generate_vectors>
            -DGENERATE_QUERIES=$<TARGET_FILE:generate_queries>
            -DSEQUENTIAL=$<TARGET_FILE:sequential_retriever>
            -DWORK_DIR=${CMAKE_CURRENT_BINARY_DIR}/phase3_dimension_mismatch
            -P
            ${CMAKE_CURRENT_SOURCE_DIR}/tests/cmake/RunSequentialDimensionMismatchFail.cmake
    )
    add_test(
        NAME parallel_retrieval_smoke
        COMMAND
            ${CMAKE_COMMAND}
            -DGENERATE_VECTORS=$<TARGET_FILE:generate_vectors>
            -DGENERATE_QUERIES=$<TARGET_FILE:generate_queries>
            -DSEQUENTIAL=$<TARGET_FILE:sequential_retriever>
            -DPARALLEL=$<TARGET_FILE:parallel_retriever>
            -DMPIEXEC_EXECUTABLE=${MPIEXEC_EXECUTABLE}
            -DMPIEXEC_NUMPROC_FLAG=${MPIEXEC_NUMPROC_FLAG}
            -DWORK_DIR=${CMAKE_CURRENT_BINARY_DIR}/phase4_parallel_smoke
            -P
            ${CMAKE_CURRENT_SOURCE_DIR}/tests/cmake/RunParallelRetrievalSmoke.cmake
    )
    add_test(
        NAME parallel_world_size_gt_n_smoke
        COMMAND
            ${CMAKE_COMMAND}
            -DGENERATE_VECTORS=$<TARGET_FILE:generate_vectors>
            -DGENERATE_QUERIES=$<TARGET_FILE:generate_queries>
            -DPARALLEL=$<TARGET_FILE:parallel_retriever>
            -DMPIEXEC_EXECUTABLE=${MPIEXEC_EXECUTABLE}
            -DMPIEXEC_NUMPROC_FLAG=${MPIEXEC_NUMPROC_FLAG}
            -DWORK_DIR=${CMAKE_CURRENT_BINARY_DIR}/phase4_parallel_world_size_gt_n
            -P
            ${CMAKE_CURRENT_SOURCE_DIR}/tests/cmake/RunParallelWorldSizeGtNSmoke.cmake
    )
    add_test(
        NAME parallel_dimension_mismatch_fails
        COMMAND
            ${CMAKE_COMMAND}
            -DGENERATE_VECTORS=$<TARGET_FILE:generate_vectors>
            -DGENERATE_QUERIES=$<TARGET_FILE:generate_queries>
            -DPARALLEL=$<TARGET_FILE:parallel_retriever>
            -DMPIEXEC_EXECUTABLE=${MPIEXEC_EXECUTABLE}
            -DMPIEXEC_NUMPROC_FLAG=${MPIEXEC_NUMPROC_FLAG}
            -DWORK_DIR=${CMAKE_CURRENT_BINARY_DIR}/phase4_parallel_dimension_mismatch
            -P
            ${CMAKE_CURRENT_SOURCE_DIR}/tests/cmake/RunParallelDimensionMismatchFail.cmake
    )
    add_test(
        NAME verify_results_smoke
        COMMAND
            ${CMAKE_COMMAND}
            -DGENERATE_VECTORS=$<TARGET_FILE:generate_vectors>
            -DGENERATE_QUERIES=$<TARGET_FILE:generate_queries>
            -DSEQUENTIAL=$<TARGET_FILE:sequential_retriever>
            -DPARALLEL=$<TARGET_FILE:parallel_retriever>
            -DVERIFY_RESULTS=$<TARGET_FILE:verify_results>
            -DMPIEXEC_EXECUTABLE=${MPIEXEC_EXECUTABLE}
            -DMPIEXEC_NUMPROC_FLAG=${MPIEXEC_NUMPROC_FLAG}
            -DWORK_DIR=${CMAKE_CURRENT_BINARY_DIR}/phase5_verify_results_smoke
            -P
            ${CMAKE_CURRENT_SOURCE_DIR}/tests/cmake/RunVerifyResultsSmoke.cmake
    )
    add_test(
        NAME verify_results_mismatch_smoke
        COMMAND
            ${CMAKE_COMMAND}
            -DVERIFY_RESULTS=$<TARGET_FILE:verify_results>
            -DWORK_DIR=${CMAKE_CURRENT_BINARY_DIR}/phase5_verify_results_mismatch
            -P
            ${CMAKE_CURRENT_SOURCE_DIR}/tests/cmake/RunVerifyResultsMismatchSmoke.cmake
    )
    add_test(
        NAME verify_results_malformed_input_fails
        COMMAND
            ${CMAKE_COMMAND}
            -DVERIFY_RESULTS=$<TARGET_FILE:verify_results>
            -DWORK_DIR=${CMAKE_CURRENT_BINARY_DIR}/phase5_verify_results_malformed
            -P
            ${CMAKE_CURRENT_SOURCE_DIR}/tests/cmake/RunVerifyResultsMalformedFail.cmake
    )
    add_test(
        NAME sequential_run_metrics_smoke
        COMMAND
            ${CMAKE_COMMAND}
            -DGENERATE_VECTORS=$<TARGET_FILE:generate_vectors>
            -DGENERATE_QUERIES=$<TARGET_FILE:generate_queries>
            -DSEQUENTIAL=$<TARGET_FILE:sequential_retriever>
            -DWORK_DIR=${CMAKE_CURRENT_BINARY_DIR}/phase6_sequential_run_metrics
            -P
            ${CMAKE_CURRENT_SOURCE_DIR}/tests/cmake/RunSequentialRunMetricsSmoke.cmake
    )
    add_test(
        NAME parallel_run_metrics_smoke
        COMMAND
            ${CMAKE_COMMAND}
            -DGENERATE_VECTORS=$<TARGET_FILE:generate_vectors>
            -DGENERATE_QUERIES=$<TARGET_FILE:generate_queries>
            -DPARALLEL=$<TARGET_FILE:parallel_retriever>
            -DMPIEXEC_EXECUTABLE=${MPIEXEC_EXECUTABLE}
            -DMPIEXEC_NUMPROC_FLAG=${MPIEXEC_NUMPROC_FLAG}
            -DWORK_DIR=${CMAKE_CURRENT_BINARY_DIR}/phase6_parallel_run_metrics
            -P
            ${CMAKE_CURRENT_SOURCE_DIR}/tests/cmake/RunParallelRunMetricsSmoke.cmake
    )
    add_test(
        NAME benchmark_select_n_smoke
        COMMAND
            ${CMAKE_COMMAND}
            -DREPO_ROOT=${CMAKE_CURRENT_SOURCE_DIR}
            -DBUILD_DIR=${CMAKE_CURRENT_BINARY_DIR}
            -DWORK_DIR=${CMAKE_CURRENT_BINARY_DIR}/phase7_select_n_smoke
            -P
            ${CMAKE_CURRENT_SOURCE_DIR}/tests/cmake/RunBenchmarkSelectNSmoke.cmake
    )
    add_test(
        NAME benchmark_calibrate_target_n_only_smoke
        COMMAND
            ${CMAKE_COMMAND}
            -DREPO_ROOT=${CMAKE_CURRENT_SOURCE_DIR}
            -DWORK_DIR=${CMAKE_CURRENT_BINARY_DIR}/phase7_calibrate_n_only_smoke
            -P
            ${CMAKE_CURRENT_SOURCE_DIR}/tests/cmake/RunBenchmarkCalibrateTargetNOnlySmoke.cmake
    )
    add_test(
        NAME benchmark_calibrate_target_n_plus_q_smoke
        COMMAND
            ${CMAKE_COMMAND}
            -DREPO_ROOT=${CMAKE_CURRENT_SOURCE_DIR}
            -DWORK_DIR=${CMAKE_CURRENT_BINARY_DIR}/phase7_calibrate_n_plus_q_smoke
            -P
            ${CMAKE_CURRENT_SOURCE_DIR}/tests/cmake/RunBenchmarkCalibrateTargetNPlusQSmoke.cmake
    )
    add_test(
        NAME benchmark_correctness_script_smoke
        COMMAND
            ${CMAKE_COMMAND}
            -DREPO_ROOT=${CMAKE_CURRENT_SOURCE_DIR}
            -DBUILD_DIR=${CMAKE_CURRENT_BINARY_DIR}
            -DWORK_DIR=${CMAKE_CURRENT_BINARY_DIR}/phase7_correctness_smoke
            -P
            ${CMAKE_CURRENT_SOURCE_DIR}/tests/cmake/RunBenchmarkCorrectnessSmoke.cmake
    )
    add_test(
        NAME benchmark_granularity_script_smoke
        COMMAND
            ${CMAKE_COMMAND}
            -DREPO_ROOT=${CMAKE_CURRENT_SOURCE_DIR}
            -DBUILD_DIR=${CMAKE_CURRENT_BINARY_DIR}
            -DWORK_DIR=${CMAKE_CURRENT_BINARY_DIR}/phase7_granularity_smoke
            -P
            ${CMAKE_CURRENT_SOURCE_DIR}/tests/cmake/RunBenchmarkGranularitySmoke.cmake
    )
    add_test(
        NAME benchmark_speedup_script_smoke
        COMMAND
            ${CMAKE_COMMAND}
            -DREPO_ROOT=${CMAKE_CURRENT_SOURCE_DIR}
            -DBUILD_DIR=${CMAKE_CURRENT_BINARY_DIR}
            -DWORK_DIR=${CMAKE_CURRENT_BINARY_DIR}/phase7_speedup_smoke
            -P
            ${CMAKE_CURRENT_SOURCE_DIR}/tests/cmake/RunBenchmarkSpeedupSmoke.cmake
    )
    add_test(
        NAME benchmark_all_experiments_smoke
        COMMAND
            ${CMAKE_COMMAND}
            -DREPO_ROOT=${CMAKE_CURRENT_SOURCE_DIR}
            -DBUILD_DIR=${CMAKE_CURRENT_BINARY_DIR}
            -DWORK_DIR=${CMAKE_CURRENT_BINARY_DIR}/phase7_all_experiments_smoke
            -P
            ${CMAKE_CURRENT_SOURCE_DIR}/tests/cmake/RunBenchmarkAllExperimentsSmoke.cmake
    )
    add_test(
        NAME benchmark_faiss_comparison_table_smoke
        COMMAND
            ${CMAKE_COMMAND}
            -DREPO_ROOT=${CMAKE_CURRENT_SOURCE_DIR}
            -DWORK_DIR=${CMAKE_CURRENT_BINARY_DIR}/phase8_faiss_table_smoke
            -P
            ${CMAKE_CURRENT_SOURCE_DIR}/tests/cmake/RunFaissComparisonTableSmoke.cmake
    )
    add_test(
        NAME benchmark_faiss_comparison_workflow_smoke
        COMMAND
            ${CMAKE_COMMAND}
            -DREPO_ROOT=${CMAKE_CURRENT_SOURCE_DIR}
            -DBUILD_DIR=${CMAKE_CURRENT_BINARY_DIR}
            -DGENERATE_VECTORS=$<TARGET_FILE:generate_vectors>
            -DGENERATE_QUERIES=$<TARGET_FILE:generate_queries>
            -DWORK_DIR=${CMAKE_CURRENT_BINARY_DIR}/phase8_faiss_workflow_smoke
            -P
            ${CMAKE_CURRENT_SOURCE_DIR}/tests/cmake/RunFaissComparisonWorkflowSmoke.cmake
    )
    add_test(
        NAME benchmark_analysis_smoke
        COMMAND
            ${CMAKE_COMMAND}
            -DREPO_ROOT=${CMAKE_CURRENT_SOURCE_DIR}
            -DWORK_DIR=${CMAKE_CURRENT_BINARY_DIR}/analysis_smoke
            -P
            ${CMAKE_CURRENT_SOURCE_DIR}/tests/cmake/RunBenchmarkAnalysisSmoke.cmake
    )
    add_test(
        NAME benchmark_analysis_invalid_correctness_smoke
        COMMAND
            ${CMAKE_COMMAND}
            -DREPO_ROOT=${CMAKE_CURRENT_SOURCE_DIR}
            -DWORK_DIR=${CMAKE_CURRENT_BINARY_DIR}/analysis_invalid_correctness
            -P
            ${CMAKE_CURRENT_SOURCE_DIR}/tests/cmake/RunBenchmarkAnalysisInvalidCorrectnessSmoke.cmake
    )
    add_test(
        NAME benchmark_analysis_missing_input_fails
        COMMAND
            ${CMAKE_COMMAND}
            -DREPO_ROOT=${CMAKE_CURRENT_SOURCE_DIR}
            -DWORK_DIR=${CMAKE_CURRENT_BINARY_DIR}/analysis_missing_input
            -P
            ${CMAKE_CURRENT_SOURCE_DIR}/tests/cmake/RunBenchmarkAnalysisMissingInputFail.cmake
    )
    add_test(
        NAME benchmark_analysis_calibration_aware_smoke
        COMMAND
            ${CMAKE_COMMAND}
            -DREPO_ROOT=${CMAKE_CURRENT_SOURCE_DIR}
            -DWORK_DIR=${CMAKE_CURRENT_BINARY_DIR}/analysis_calibration_aware
            -P
            ${CMAKE_CURRENT_SOURCE_DIR}/tests/cmake/RunBenchmarkAnalysisCalibrationAwareSmoke.cmake
    )
    add_test(
        NAME cluster_postprocess_smoke
        COMMAND
            ${CMAKE_COMMAND}
            -DREPO_ROOT=${CMAKE_CURRENT_SOURCE_DIR}
            -DWORK_DIR=${CMAKE_CURRENT_BINARY_DIR}/cluster_postprocess_smoke
            -P
            ${CMAKE_CURRENT_SOURCE_DIR}/tests/cmake/RunClusterPostprocessSmoke.cmake
    )
    add_test(
        NAME cluster_postprocess_no_faiss_smoke
        COMMAND
            ${CMAKE_COMMAND}
            -DREPO_ROOT=${CMAKE_CURRENT_SOURCE_DIR}
            -DWORK_DIR=${CMAKE_CURRENT_BINARY_DIR}/cluster_postprocess_no_faiss_smoke
            -P
            ${CMAKE_CURRENT_SOURCE_DIR}/tests/cmake/RunClusterPostprocessNoFaissSmoke.cmake
    )
    add_test(
        NAME cluster_bundle_dry_run_smoke
        COMMAND
            ${CMAKE_COMMAND}
            -DREPO_ROOT=${CMAKE_CURRENT_SOURCE_DIR}
            -DBUILD_DIR=${CMAKE_CURRENT_BINARY_DIR}
            -DWORK_DIR=${CMAKE_CURRENT_BINARY_DIR}/cluster_bundle_dry_run
            -P
            ${CMAKE_CURRENT_SOURCE_DIR}/tests/cmake/RunClusterBundleDryRunSmoke.cmake
    )
    add_test(
        NAME cluster_n_node_bundle_dry_run_smoke
        COMMAND
            ${CMAKE_COMMAND}
            -DREPO_ROOT=${CMAKE_CURRENT_SOURCE_DIR}
            -DBUILD_DIR=${CMAKE_CURRENT_BINARY_DIR}
            -DWORK_DIR=${CMAKE_CURRENT_BINARY_DIR}/cluster_n_node_bundle_dry_run
            -P
            ${CMAKE_CURRENT_SOURCE_DIR}/tests/cmake/RunClusterNNodeBundleDryRunSmoke.cmake
    )
endif()
