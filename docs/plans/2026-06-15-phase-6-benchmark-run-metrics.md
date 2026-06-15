# Phase 6 Benchmark Run Metrics Plan

> **For engineers:** This document records what Phase 6 implemented, what was verified, and what assumptions remain in place so Phase 7 can automate experiments without redefining timing semantics or CSV contracts.

**Status:** Implemented and verified on 2026-06-15

**Goal:** Lock benchmark-summary metrics inside the codebase so both retriever binaries can emit one canonical run-summary CSV row for later aggregation, speedup calculation, and reporting.

**Architecture:** Phase 6 extends `retriever_core` with `BenchmarkMetrics`, adds optional `--run-metrics` support to both retriever binaries, and keeps the existing per-rank Phase 4 metrics CSV untouched for granularity analysis. Tests cover summary-row math directly and smoke-check the CLI outputs end-to-end.

**Tech Stack:** C++17, CMake, Ninja, OpenMPI, CTest, POSIX shell, WSL2 Ubuntu 24.04

---

### Task 1: Add the shared benchmark-summary core

**Files:**
- Create: `include/BenchmarkMetrics.hpp`
- Create: `src/BenchmarkMetrics.cpp`
- Modify: `CMakeLists.txt`

- [x] Add `RunMetricsRow`.
- [x] Add `SpeedupRow`.
- [x] Add `make_sequential_run_metrics(...)`.
- [x] Add `make_parallel_run_metrics(...)`.
- [x] Add `make_speedup_row(...)`.
- [x] Add a narrow shared writer for the canonical one-run summary CSV schema.
- [x] Keep the timing contract explicit:
  - sequential `P = 1`
  - sequential `communication_time = 0`
  - parallel `compute_time = max(rank.compute_time)`
  - parallel `communication_time = max(rank.communication_time)`
  - parallel `total_time = global_total_time`

### Task 2: Extend both retriever CLIs with optional run-summary output

**Files:**
- Modify: `include/Config.hpp`
- Modify: `src/Config.cpp`
- Modify: `src/main_sequential.cpp`
- Modify: `src/main_parallel.cpp`

- [x] Add optional `--run-metrics <path>` to the retriever CLI contract.
- [x] Update sequential help text to include the new flag.
- [x] Update parallel help text to include the new flag.
- [x] Make `sequential_retriever` write one summary row when `--run-metrics` is present.
- [x] Make `parallel_retriever` write one summary row on rank `0` when `--run-metrics` is present.
- [x] Keep dataset load and CSV writing outside the benchmark timing window used for `total_time`.

### Task 3: Add direct tests and executable smoke coverage

**Files:**
- Create: `tests/BenchmarkMetricsTest.cpp`
- Create: `tests/cmake/RunSequentialRunMetricsSmoke.cmake`
- Create: `tests/cmake/RunParallelRunMetricsSmoke.cmake`
- Modify: `tests/ConfigLoggerTest.cpp`
- Modify: `CMakeLists.txt`

- [x] Add `benchmark_metrics_test` for:
  - sequential baseline row semantics
  - parallel aggregation semantics
  - speedup and efficiency math
  - validation of mismatched benchmark dimensions
- [x] Add a sequential smoke case that writes and validates the one-row summary CSV.
- [x] Add a parallel smoke case that writes and validates both:
  - `parallel_metrics.csv`
  - the one-row parallel summary CSV
- [x] Update parser tests so the new flag is part of the stable CLI contract.

### Task 4: Update canonical documentation

**Files:**
- Modify: `README.md`
- Modify: `docs/development/developer_guide.md`
- Modify: `docs/development/source_guide.md`
- Modify: `docs/development/data_pipeline_and_benchmarks.md`
- Create: `docs/plans/2026-06-15-phase-6-benchmark-run-metrics.md`

- [x] Document the new `--run-metrics` flag in the main quickstart flow.
- [x] Document the one-row summary CSV schema and timing semantics.
- [x] Record `BenchmarkMetrics` as part of the maintained shared core.

### Task 5: Verification actually completed

**Ubuntu WSL checks actually run from `/mnt/d/DS-AI/Parallel-Retrieval-Engine-for-RAG`:**

- [x] `cmake --build build/debug --target config_logger_test benchmark_metrics_test sequential_retriever parallel_retriever`
- [x] `ctest --test-dir build/debug --output-on-failure -R 'config_logger_test|benchmark_metrics_test|sequential_run_metrics_smoke|parallel_run_metrics_smoke'`
- [x] `cmake --build build/debug`
- [x] `ctest --test-dir build/debug --output-on-failure`

**Observed result:**

- all targeted Phase 6 checks passed
- the later full repository verification also passed with `32/32` CTest cases green
- sequential `--run-metrics` wrote the exact header:
  - `N,D,Q,k,P,compute_time,communication_time,total_time`
- sequential summary rows used `P = 1` and `communication_time = 0`
- parallel `--run-metrics` wrote the exact same one-row schema
- parallel summary `total_time` matched the retrieval-loop timing contract used by Phase 4 per-rank metrics

### Notes for the next person

- `parallel_metrics.csv` keeps its Phase 4 schema and remains the source for granularity analysis.
- `SpeedupRow` expects a true sequential baseline row with `P = 1`; do not substitute `parallel_retriever -np 1`.
- Phase 7 can now treat retriever binaries as the canonical source of benchmark-summary data instead of reconstructing timings in shell.
