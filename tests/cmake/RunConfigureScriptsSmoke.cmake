cmake_minimum_required(VERSION 3.20)

if(NOT DEFINED REPO_ROOT)
    message(FATAL_ERROR "REPO_ROOT is required")
endif()

set(bash_executable "bash")

if(EXISTS "C:/Program Files/Git/usr/bin/bash.exe")
    set(bash_executable "C:/Program Files/Git/usr/bin/bash.exe")
elseif(EXISTS "C:/Program Files/Git/bin/bash.exe")
    set(bash_executable "C:/Program Files/Git/bin/bash.exe")
endif()

foreach(script_name configure_debug.sh configure_release.sh)
    if(WIN32)
        execute_process(
            COMMAND
                "${bash_executable}"
                -lc
                "script_path=$(cygpath -u \"$1\"); \"$script_path\""
                _
                "${REPO_ROOT}/scripts/${script_name}"
            RESULT_VARIABLE run_exit
            OUTPUT_VARIABLE run_stdout
            ERROR_VARIABLE run_stderr
        )
    else()
        execute_process(
            COMMAND
                "${bash_executable}"
                "${REPO_ROOT}/scripts/${script_name}"
            RESULT_VARIABLE run_exit
            OUTPUT_VARIABLE run_stdout
            ERROR_VARIABLE run_stderr
        )
    endif()

    if(NOT run_exit EQUAL 0)
        message(FATAL_ERROR "${script_name} failed:\n${run_stdout}\n${run_stderr}")
    endif()
endforeach()
