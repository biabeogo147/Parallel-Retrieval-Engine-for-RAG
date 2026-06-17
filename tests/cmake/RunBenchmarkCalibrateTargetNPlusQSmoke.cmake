cmake_minimum_required(VERSION 3.20)

if(NOT DEFINED REPO_ROOT)
    message(FATAL_ERROR "REPO_ROOT is required")
endif()

if(NOT DEFINED WORK_DIR)
    message(FATAL_ERROR "WORK_DIR is required")
endif()

file(MAKE_DIRECTORY "${WORK_DIR}")
set(fake_build_dir "${WORK_DIR}/fake_build")
set(results_dir "${WORK_DIR}/results")
set(scratch_dir "${WORK_DIR}/scratch")
file(MAKE_DIRECTORY "${fake_build_dir}" "${results_dir}" "${scratch_dir}")

file(
    WRITE
    "${fake_build_dir}/generate_vectors"
    [=[
#!/bin/sh
set -eu
output=""
while [ "$#" -gt 0 ]; do
    if [ "$1" = "--output" ]; then
        output=$2
        shift 2
        continue
    fi
    shift
done
mkdir -p "$(dirname "$output")"
: > "$output"
]=]
)

file(
    WRITE
    "${fake_build_dir}/generate_queries"
    [=[
#!/bin/sh
set -eu
output=""
while [ "$#" -gt 0 ]; do
    if [ "$1" = "--output" ]; then
        output=$2
        shift 2
        continue
    fi
    shift
done
mkdir -p "$(dirname "$output")"
: > "$output"
]=]
)

file(
    WRITE
    "${fake_build_dir}/parallel_retriever"
    [=[
#!/bin/sh
set -eu
vectors=""
queries=""
output=""
metrics=""
run_metrics=""
topk=0
while [ "$#" -gt 0 ]; do
    case "$1" in
        --vectors) vectors=$2; shift 2 ;;
        --queries) queries=$2; shift 2 ;;
        --output) output=$2; shift 2 ;;
        --metrics) metrics=$2; shift 2 ;;
        --run-metrics) run_metrics=$2; shift 2 ;;
        --topk) topk=$2; shift 2 ;;
        *) shift ;;
    esac
done
N=$(printf '%s\n' "$vectors" | sed -n 's/.*memory_vectors_N\([0-9][0-9]*\)_D.*/\1/p')
Q=$(printf '%s\n' "$queries" | sed -n 's/.*query_vectors_Q\([0-9][0-9]*\)_D.*/\1/p')
if [ "$N" = "256" ]; then
    echo "simulated OOM at N=$N" >&2
    exit 99
fi
case "$N:$Q" in
    64:100) total=30 ;;
    128:100) total=40 ;;
    128:150) total=90 ;;
    128:200) total=130 ;;
    128:300) total=170 ;;
    *) echo "unexpected N:Q combination $N:$Q" >&2; exit 1 ;;
esac
compute=$((total - 10))
comm=10
mkdir -p "$(dirname "$output")"
{
    echo "query_id,rank_position,memory_id,score"
    echo "0,1,0,1.00000000"
} > "$output"
mkdir -p "$(dirname "$metrics")"
{
    echo "rank,local_N,compute_time,communication_time,active_time,global_total_time,idle_time"
    echo "0,$((N / 4)),$compute.00000000,$comm.00000000,$total.00000000,$total.00000000,0.00000000"
    echo "1,$((N / 4)),$compute.00000000,$comm.00000000,$total.00000000,$total.00000000,0.00000000"
    echo "2,$((N / 4)),$compute.00000000,$comm.00000000,$total.00000000,$total.00000000,0.00000000"
    echo "3,$((N / 4)),$compute.00000000,$comm.00000000,$total.00000000,$total.00000000,0.00000000"
} > "$metrics"
if [ -n "$run_metrics" ]; then
    mkdir -p "$(dirname "$run_metrics")"
    {
        echo "N,D,Q,k,P,compute_time,communication_time,total_time"
        echo "$N,8,$Q,$topk,4,$compute.00000000,$comm.00000000,$total.00000000"
    } > "$run_metrics"
fi
]=]
)

file(
    WRITE
    "${fake_build_dir}/sequential_retriever"
    [=[
#!/bin/sh
set -eu
vectors=""
queries=""
output=""
run_metrics=""
topk=0
while [ "$#" -gt 0 ]; do
    case "$1" in
        --vectors) vectors=$2; shift 2 ;;
        --queries) queries=$2; shift 2 ;;
        --output) output=$2; shift 2 ;;
        --run-metrics) run_metrics=$2; shift 2 ;;
        --topk) topk=$2; shift 2 ;;
        *) shift ;;
    esac
done
N=$(printf '%s\n' "$vectors" | sed -n 's/.*memory_vectors_N\([0-9][0-9]*\)_D.*/\1/p')
Q=$(printf '%s\n' "$queries" | sed -n 's/.*query_vectors_Q\([0-9][0-9]*\)_D.*/\1/p')
case "$N:$Q" in
    96:200) total=300 ;;
    160:200) total=700 ;;
    *) total=50 ;;
esac
mkdir -p "$(dirname "$output")"
{
    echo "query_id,rank_position,memory_id,score"
    echo "0,1,0,1.00000000"
} > "$output"
if [ -n "$run_metrics" ]; then
    mkdir -p "$(dirname "$run_metrics")"
    {
        echo "N,D,Q,k,P,compute_time,communication_time,total_time"
        echo "$N,8,$Q,$topk,1,$total.00000000,0.00000000,$total.00000000"
    } > "$run_metrics"
fi
]=]
)

foreach(tool_name generate_vectors generate_queries parallel_retriever sequential_retriever)
    execute_process(COMMAND chmod +x "${fake_build_dir}/${tool_name}")
endforeach()

execute_process(
    COMMAND
        "${CMAKE_COMMAND}" -E env
        "BENCH_BUILD_DIR=${fake_build_dir}"
        "BENCH_RESULTS_DIR=${results_dir}"
        "BENCH_SCRATCH_DIR=${scratch_dir}"
        "BENCH_D=8"
        "BENCH_Q=100"
        "BENCH_TOPK=3"
        "BENCH_EPSILON=1e-5"
        "BENCH_N_CANDIDATES=64 128 256"
        "BENCH_Q_CANDIDATES=150 200 300"
        "BENCH_SPEEDUP_N_CANDIDATES=96 160"
        "BENCH_SPEEDUP_BASELINE_LIMIT=600"
        "BENCH_P_SELECTED=4"
        bash
        "${REPO_ROOT}/scripts/run_calibrate_target.sh"
    RESULT_VARIABLE run_exit
    OUTPUT_VARIABLE run_stdout
    ERROR_VARIABLE run_stderr
)

if(NOT run_exit EQUAL 0)
    message(FATAL_ERROR "run_calibrate_target.sh failed:\n${run_stdout}\n${run_stderr}")
endif()

set(runtime_path "${results_dir}/runtime_by_N.csv")
set(selection_path "${results_dir}/benchmark_selection.env")

if(NOT EXISTS "${runtime_path}")
    message(FATAL_ERROR "expected runtime_by_N.csv was not created: ${runtime_path}")
endif()
if(NOT EXISTS "${selection_path}")
    message(FATAL_ERROR "expected benchmark_selection.env was not created: ${selection_path}")
endif()

file(READ "${selection_path}" selection_text)
foreach(required_entry
    "N_SELECTED=128"
    "N_SPEEDUP=96"
    "P_SELECTED=4"
    "D=8"
    "Q=200"
    "K=3"
    "EPSILON=1e-5"
    "CALIBRATION_MODE=N_PLUS_Q"
    "N_MAX_FEASIBLE=128")
    string(FIND "${selection_text}" "${required_entry}" entry_index)
    if(entry_index EQUAL -1)
        message(FATAL_ERROR "missing selection entry ${required_entry} in:\n${selection_text}")
    endif()
endforeach()

file(STRINGS "${runtime_path}" runtime_lines)
list(LENGTH runtime_lines runtime_line_count)
if(NOT runtime_line_count EQUAL 3)
    message(FATAL_ERROR "expected successful N sweep rows to be preserved before failure; found ${runtime_line_count} lines")
endif()
