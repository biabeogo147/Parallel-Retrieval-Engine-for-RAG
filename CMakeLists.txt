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
    src/Config.cpp
    src/Logger.cpp
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

if(BUILD_TESTING)
    add_test(NAME config_logger_test COMMAND config_logger_test)
    add_test(NAME binary_dataset_test COMMAND binary_dataset_test)
    add_test(NAME sequential_help COMMAND sequential_retriever --help)
    add_test(NAME generate_vectors_help COMMAND generate_vectors --help)
    add_test(NAME generate_queries_help COMMAND generate_queries --help)
    add_test(NAME inspect_dataset_help COMMAND inspect_dataset --help)
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
endif()
