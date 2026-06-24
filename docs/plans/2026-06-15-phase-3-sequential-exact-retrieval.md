# Phase 3 Sequential Exact Retrieval Plan

> **For engineers:** This document records what Phase 3 implemented, what was verified, and what assumptions remain in place so Phase 4 can parallelize a stable exact-search core instead of redesigning the sequential path.

**Status:** Implemented and verified on 2026-06-15

**Goal:** Turn `sequential_retriever` into a real exact top-k binary-dataset retriever, while keeping the scoring core reusable for later local shard search in the MPI path.

**Architecture:** Phase 3 extends `retriever_core` with `TopKHeap` and `SequentialRetriever`, keeps dataset file I/O and CSV writing in `main_sequential.cpp`, and adds `CTest` coverage for heap ordering, exact results, CLI smoke, and dimension-mismatch failure behavior.

**Tech Stack:** C++17, CMake, Ninja, OpenMPI, CTest, POSIX shell, WSL2 Ubuntu 24.04

---

### Task 1: Add a reusable exact-search core

**Files:**
- Create: `include/TopKHeap.hpp`
- Create: `src/TopKHeap.cpp`
- Create: `include/SequentialRetriever.hpp`
- Create: `src/SequentialRetriever.cpp`
- Modify: `CMakeLists.txt`

- [x] Add `RetrievalCandidate { uint64_t memory_id; float score; }`.
- [x] Add `QueryTopKResult { uint64_t query_id; std::vector<RetrievalCandidate> topk; }`.
- [x] Implement deterministic ranking rules:
  - higher score is better
  - on score ties, lower `memory_id` is better
  - the heap root is the worst retained candidate
- [x] Implement `SequentialRetriever::search_local(...)` for one query over a contiguous flat memory buffer.
- [x] Implement `SequentialRetriever::search_all(...)` for the full sequential run.
- [x] Keep the retrieval core in-memory only, with no dataset copies and no CSV writer inside `retriever_core`.

### Task 2: Enforce the Phase 3 retrieval contract

**Files:**
- Modify: `src/SequentialRetriever.cpp`

- [x] Reject dimension mismatch with `std::runtime_error`.
- [x] Reject missing normalized flag on either dataset.
- [x] Reject missing row-major flag on either dataset.
- [x] Reject `topk < 1`.
- [x] Reject `topk > num_vectors` for the full sequential path.
- [x] Keep `memory_id_offset` support in the local search method for future Phase 4 shard reuse.

### Task 3: Replace the sequential CLI scaffold with the real pipeline

**Files:**
- Modify: `src/main_sequential.cpp`
- Modify: `src/Config.cpp`

- [x] Keep `parse_config(...)` as the CLI entrypoint.
- [x] Keep `--help` behavior stable and successful.
- [x] Load `vectors.bin` and `queries.bin` via `BinaryDataset::read_all(...)`.
- [x] Run the shared `SequentialRetriever`.
- [x] Write canonical CSV output with header exactly:
  - `query_id,rank_position,memory_id,score`
- [x] Write `score` with `std::fixed` and `std::setprecision(8)`.
- [x] Catch exceptions and print clean `Error: ...` failures.
- [x] Update sequential help text so it no longer claims the binary is only a Phase 1 scaffold.

### Task 4: Add test coverage for exact retrieval behavior

**Files:**
- Create: `tests/SequentialRetrieverTest.cpp`
- Create: `tests/cmake/RunSequentialRetrievalSmoke.cmake`
- Create: `tests/cmake/RunSequentialDimensionMismatchFail.cmake`
- Modify: `CMakeLists.txt`

- [x] Add `sequential_retriever_test` for:
  - heap keeps only the best `k`
  - tie-break on `memory_id`
  - exact single-query top-k on a known matrix
  - exact multi-query results
  - `memory_id_offset`
  - dimension mismatch failure
  - `topk > num_vectors` failure
- [x] Add CLI smoke checks for:
  - dataset generation
  - real sequential run
  - CSV existence
  - exact CSV header
  - line count = `Q * k + 1`
- [x] Add a mismatched-dimension CLI smoke case that must fail.

### Task 5: Update canonical documentation

**Files:**
- Modify: `README.md`
- Modify: `docs/development/source_guide.md`
- Modify: `docs/development/developer_guide.md`
- Modify: `docs/development/data_pipeline_and_benchmarks.md`
- Create: `docs/plans/2026-06-15-phase-3-sequential-exact-retrieval.md`

- [x] Update `README` quickstart with real sequential retrieval commands.
- [x] Update `source_guide.md` to explain the Phase 3 runtime path and new shared components.
- [x] Update `developer_guide.md` to document the exact sequential run flow.
- [x] Update `data_pipeline_and_benchmarks.md` with:
  - row-index ID convention
  - normalized + row-major retrieval preconditions
  - Phase 3 sequential CSV contract

### Task 6: Verification actually completed

**Ubuntu WSL checks actually run from `/mnt/d/DS-AI/Parallel-Retrieval-Engine-for-RAG`:**

- [x] `bash scripts/configure_debug.sh`
- [x] `cmake --build build/debug`
- [x] `ctest --test-dir build/debug --output-on-failure`
- [x] `./build/debug/generate_vectors --N 64 --D 8 --output data/memory_vectors.bin`
- [x] `./build/debug/generate_queries --Q 5 --D 8 --output data/query_vectors.bin`
- [x] `./build/debug/sequential_retriever --vectors data/memory_vectors.bin --queries data/query_vectors.bin --topk 3 --output results/sequential_topk.csv`
- [x] mismatched-dimension sequential run fails non-zero with a clear error

**Observed result:**

- all `15/15` CTest cases passed
- the sequential smoke case generated `results/sequential_topk.csv`
- the CSV header matched exactly:
  - `query_id,rank_position,memory_id,score`
- the `Q = 5`, `k = 3` acceptance run produced `16` CSV lines
- the CLI mismatch smoke detected the expected `dimension mismatch` failure

### Notes for the next person

- Phase 3 defines `query_id` and `memory_id` from zero-based row position because the current binary format does not store explicit IDs.
- The sequential core assumes normalized row-major `float32` datasets and now enforces those assumptions explicitly.
- `SequentialRetriever::search_local(...)` is the intended Phase 4 reuse point for rank-local shard search.
- Parallel retrieval, metrics CSV generation, and sequential-vs-parallel correctness comparison remain later-phase work.
