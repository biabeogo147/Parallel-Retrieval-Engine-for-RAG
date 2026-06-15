cmake_minimum_required(VERSION 3.20)

project(parallel_agent_memory_retriever LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

include(CTest)
find_package(MPI REQUIRED)

add_library(
    retriever_core
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
    config_logger_test
    tests/ConfigLoggerTest.cpp
)

target_link_libraries(config_logger_test PRIVATE retriever_core)

if(BUILD_TESTING)
    add_test(NAME config_logger_test COMMAND config_logger_test)
    add_test(NAME sequential_help COMMAND sequential_retriever --help)
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
endif()
