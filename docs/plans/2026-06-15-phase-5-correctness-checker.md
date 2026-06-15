# Phase 5 Correctness Checker Plan

> **For engineers:** This document records what Phase 5 implemented, what was verified, and what assumptions remain in place so later phases can build benchmark automation on top of a stable correctness workflow.

**Status:** Implemented and verified on 2026-06-15

**Goal:** Add a real `verify_results` tool that compares `sequential_topk.csv` and `parallel_topk.csv`, writes canonical `correctness.csv`, and exposes automation-friendly exit codes for pass, logical mismatch, and malformed input.

**Architecture:** Phase 5 extends `retriever_core` with `CorrectnessChecker` for shared top-k CSV comparison semantics, keeps CSV parsing and writing in `tools/verify_results.cpp`, adds direct unit coverage for comparison rules, and adds `CTest` smoke flows for pass, mismatch, and malformed-input cases.

**Tech Stack:** C++17, CMake, Ninja, OpenMPI, CTest, POSIX shell, WSL2 Ubuntu 24.04

---

### Task 1: Add the shared Phase 5 correctness core

**Files:**
- Create: `include/CorrectnessChecker.hpp`
- Create: `src/CorrectnessChecker.cpp`
- Modify: `CMakeLists.txt`

- [x] Add `TopKCsvRow`.
- [x] Add `QueryCorrectnessResult`.
- [x] Add `CorrectnessChecker::compare(...)`.
- [x] Keep row sorting, query grouping, rank validation, and compare semantics in `retriever_core`.
- [x] Reject:
  - duplicate `(query_id, rank_position)` rows
  - non-contiguous `rank_position`
  - inconsistent `k`
  - mismatched `query_id` sets

### Task 2: Add the `verify_results` CLI

**Files:**
- Create: `tools/verify_results.cpp`
- Modify: `CMakeLists.txt`

- [x] Add CLI flags:
  - `--sequential`
  - `--parallel`
  - `--epsilon`
  - `--output`
  - `--help`
- [x] Keep parser tool-local instead of extending retriever `Config`.
- [x] Read canonical top-k CSV files with exact header validation.
- [x] Write canonical correctness CSV header:
  - `query_id,k,matched,matched_ids,max_score_diff,status`
- [x] Return:
  - `0` when all queries pass
  - `1` when comparison succeeds but at least one query fails
  - `2` for invalid CLI arguments, malformed CSV input, or runtime error

### Task 3: Lock the Phase 5 comparison contract

**Files:**
- Modify: `tools/verify_results.cpp`
- Modify: `src/CorrectnessChecker.cpp`

- [x] Keep input top-k header exact:
  - `query_id,rank_position,memory_id,score`
- [x] Compare rows by:
  - `query_id`
  - `rank_position`
- [x] Define:
  - `matched_ids` = number of equal `memory_id` values at the same rank
  - `max_score_diff` = largest absolute score difference within the query
  - `matched = true` when `matched_ids == k` and `max_score_diff <= epsilon`
  - `status = PASS` or `FAIL`
- [x] Write `matched` as `true` or `false`.

### Task 4: Add direct tests and smoke coverage

**Files:**
- Create: `tests/CorrectnessCheckerTest.cpp`
- Create: `tests/cmake/RunVerifyResultsSmoke.cmake`
- Create: `tests/cmake/RunVerifyResultsMismatchSmoke.cmake`
- Create: `tests/cmake/RunVerifyResultsMalformedFail.cmake`
- Modify: `CMakeLists.txt`

- [x] Add `correctness_checker_test` for:
  - exact-match pass
  - `memory_id` mismatch
  - epsilon tolerance pass/fail behavior
  - multi-query sorting
  - duplicate rank rejection
  - missing-rank rejection
  - query-set mismatch rejection
- [x] Add `CTest` smoke checks for:
  - end-to-end sequential -> parallel -> verify workflow
  - mismatch exit code `1`
  - malformed-input exit code `2`
  - `verify_results --help`

### Task 5: Update canonical documentation

**Files:**
- Modify: `README.md`
- Modify: `docs/development/developer_guide.md`
- Modify: `docs/development/source_guide.md`
- Modify: `docs/development/data_pipeline_and_benchmarks.md`
- Create: `docs/plans/2026-06-15-phase-5-correctness-checker.md`

- [x] Update `README` overview, quickstart, phase status, and plan index.
- [x] Update `developer_guide.md` with the Phase 5 verification flow and `correctness.csv` contract.
- [x] Update `source_guide.md` with:
  - new runtime path
  - new shared component
  - new tool and tests
- [x] Update `data_pipeline_and_benchmarks.md` with:
  - correctness CSV schema
  - epsilon workflow
  - validation rules
  - WSL command sequence

### Task 6: Verification actually completed

**Ubuntu WSL checks actually run from `/mnt/d/DS-AI/Parallel-Retrieval-Engine-for-RAG`:**

- [x] `cmake --build build/debug`
- [x] `ctest --test-dir build/debug --output-on-failure`
- [x] `./build/debug/generate_vectors --N 64 --D 8 --output data/memory_vectors.bin`
- [x] `./build/debug/generate_queries --Q 5 --D 8 --output data/query_vectors.bin`
- [x] `./build/debug/sequential_retriever --vectors data/memory_vectors.bin --queries data/query_vectors.bin --topk 3 --output results/sequential_topk.csv`
- [x] `OMPI_ALLOW_RUN_AS_ROOT=1 OMPI_ALLOW_RUN_AS_ROOT_CONFIRM=1 mpirun -np 4 ./build/debug/parallel_retriever --vectors data/memory_vectors.bin --queries data/query_vectors.bin --topk 3 --output results/parallel_topk.csv --metrics results/parallel_metrics.csv`
- [x] `./build/debug/verify_results --sequential results/sequential_topk.csv --parallel results/parallel_topk.csv --epsilon 1e-5 --output results/correctness.csv`

**Observed result:**

- all `24/24` CTest cases passed
- the manual Phase 5 acceptance flow printed:
  - `All queries PASS`
- the acceptance run generated:
  - `results/sequential_topk.csv`
  - `results/parallel_topk.csv`
  - `results/parallel_metrics.csv`
  - `results/correctness.csv`
- the correctness CSV header matched exactly:
  - `query_id,k,matched,matched_ids,max_score_diff,status`
- the `Q = 5`, `k = 3` acceptance run produced:
  - `6` lines in `correctness.csv`
- the first correctness rows showed:
  - `true` for `matched`
  - `3` for `matched_ids`
  - `PASS` for `status`

### Notes for the next person

- `CorrectnessChecker` is the canonical place for per-query comparison semantics; do not duplicate this logic in later benchmark scripts.
- `verify_results` intentionally keeps CSV parsing tool-local so retriever `Config` stays scoped to retriever binaries only.
- Phase 5 establishes correctness verification, not benchmark aggregation; `runtime_by_N.csv`, `granularity.csv`, `speedup.csv`, and plotting remain later-phase work.
