# Phase 7 Experiment Automation Plan

> **For engineers:** This document records what Phase 7 implemented, what was verified, and what assumptions remain in place so later phases can build on a stable synthetic benchmark workflow instead of re-inventing orchestration and reporting glue.

**Status:** Implemented and verified on 2026-06-15

**Goal:** Add a WSL-first automation layer that runs the full synthetic benchmark workflow: select `N`, verify correctness, inspect granularity, measure speedup, and generate figures.

**Architecture:** Phase 7 keeps orchestration in POSIX shell scripts, keeps CSV selection and speedup math in a focused Python helper, and keeps plotting in a separate headless `matplotlib` script. No new benchmark C++ executable is introduced; the retriever binaries remain the canonical runtime and metrics producers.

**Tech Stack:** POSIX shell, Python 3 stdlib, `matplotlib` with backend `Agg`, CMake, Ninja, OpenMPI, CTest, WSL2 Ubuntu 24.04

---

### Task 1: Add the shared benchmark script foundation

**Files:**
- Create: `scripts/benchmark_common.sh`
- Create: `scripts/benchmark_csv.py`
- Create: `scripts/plot_results.py`
- Create: `scripts/requirements-benchmark.txt`

- [x] Add shared shell helpers for command checks, dataset reuse, result-folder setup, and `mpirun` invocation.
- [x] Detect physical core count and derive a default `BENCH_P_LIST`.
- [x] Add CSV helper commands for:
  - merging one-row run metrics
  - selecting `N_SELECTED`
  - building `speedup.csv`
  - summarizing granularity idle-time spread
- [x] Add headless plotting for:
  - `runtime_by_N.png`
  - `granularity.png`
  - `speedup_runtime.png`
  - `speedup_curves.png`
- [x] Keep plotting dependencies isolated in a repo-local `.venv/`.

### Task 2: Add the four benchmark stages plus all-in-one orchestration

**Files:**
- Create: `scripts/run_select_N.sh`
- Create: `scripts/run_correctness.sh`
- Create: `scripts/run_granularity.sh`
- Create: `scripts/run_speedup.sh`
- Create: `scripts/run_all_experiments.sh`

- [x] Implement runtime-by-`N` selection with output:
  - `results/runtime_by_N.csv`
  - `results/benchmark_selection.env`
- [x] Implement correctness workflow with output:
  - `results/sequential_topk.csv`
  - `results/parallel_topk.csv`
  - `results/correctness.csv`
- [x] Implement granularity workflow with output:
  - `results/granularity.csv`
  - `results/granularity_summary.txt`
- [x] Implement speedup workflow with output:
  - `results/speedup.csv`
- [x] Implement all-in-one automation that runs the four stages and then generates figures.

### Task 3: Lock selection and benchmark semantics

**Files:**
- Create: `scripts/benchmark_csv.py`
- Modify: `docs/development/data_pipeline_and_benchmarks.md`

- [x] Lock `N_SELECTED` rule:
  - smallest row with `120 <= total_time <= 180`
  - otherwise closest row to `150` seconds
- [x] Lock `N_SPEEDUP = 2 * N_SELECTED`.
- [x] Lock `speedup.csv` so the `P = 1` row comes from the sequential baseline.
- [x] Keep `granularity.csv` equal to the per-rank metrics CSV contract from Phase 4.
- [x] Keep all final benchmark artifacts under `results/`.

### Task 4: Add benchmark automation smoke coverage

**Files:**
- Create: `tests/cmake/RunBenchmarkSelectNSmoke.cmake`
- Create: `tests/cmake/RunBenchmarkCorrectnessSmoke.cmake`
- Create: `tests/cmake/RunBenchmarkGranularitySmoke.cmake`
- Create: `tests/cmake/RunBenchmarkSpeedupSmoke.cmake`
- Create: `tests/cmake/RunBenchmarkAllExperimentsSmoke.cmake`
- Modify: `CMakeLists.txt`

- [x] Add a reduced-profile select-`N` smoke case.
- [x] Add a reduced-profile correctness stage smoke case.
- [x] Add a reduced-profile granularity stage smoke case.
- [x] Add a reduced-profile speedup stage smoke case.
- [x] Add a reduced-profile all-experiments smoke case that also verifies figure generation.

### Task 5: Update canonical documentation

**Files:**
- Modify: `README.md`
- Modify: `docs/development/developer_guide.md`
- Modify: `docs/development/source_guide.md`
- Modify: `docs/development/data_pipeline_and_benchmarks.md`
- Create: `docs/plans/2026-06-15-phase-7-experiment-automation.md`

- [x] Document the benchmark scripts and their outputs.
- [x] Document `benchmark_selection.env`.
- [x] Document the final benchmark CSV schemas and generated figure names.
- [x] Record the automation layer as part of the canonical developer workflow.

### Task 6: Verification actually completed

**Ubuntu WSL checks actually run from `/mnt/d/DS-AI/Parallel-Retrieval-Engine-for-RAG`:**

- [x] `ctest --test-dir build/debug --output-on-failure -R 'benchmark_select_n_smoke|benchmark_correctness_script_smoke|benchmark_granularity_script_smoke|benchmark_speedup_script_smoke'`
- [x] `ctest --test-dir build/debug --output-on-failure -R 'benchmark_all_experiments_smoke'`
- [x] `ctest --test-dir build/debug --output-on-failure`
- [x] `bash scripts/run_all_experiments.sh`

**Observed result:**

- all targeted Phase 7 benchmark-automation smoke cases passed
- the later full repository verification also passed with `32/32` CTest cases green
- the reduced-profile all-experiments smoke generated:
  - `runtime_by_N.csv`
  - `correctness.csv`
  - `granularity.csv`
  - `speedup.csv`
  - all four expected PNG figures
- the plotting flow successfully bootstrapped the repo-local `.venv/` and `matplotlib`
- the benchmark scripts produced the expected selection manifest and reused the retriever binaries as the only runtime executables
- the default acceptance run completed successfully and wrote:
  - `results/runtime_by_N.csv`
  - `results/benchmark_selection.env`
  - `results/correctness.csv`
  - `results/granularity.csv`
  - `results/speedup.csv`
  - `results/figures/*.png`
- the default selection manifest resolved to:
  - `N_SELECTED=2000000`
  - `N_SPEEDUP=4000000`
  - `P_SELECTED=10`
- the current default granularity summary reported:
  - `Load balancing verdict: UNBALANCED`
  - `idle_time_relative_gap=0.97568827`

### Notes for the next person

- Phase 7 is still synthetic-only; real-text preprocessing and corpus conversion remain later work.
- `run_all_experiments.sh` uses the current automation defaults (`D = 384`, `Q = 100`, `k = 10`) unless the caller overrides them with environment variables.
- The Python helper layer is intentionally narrow: use it for CSV math and plotting, not as a replacement for the retriever runtime or benchmark semantics already locked in C++.
