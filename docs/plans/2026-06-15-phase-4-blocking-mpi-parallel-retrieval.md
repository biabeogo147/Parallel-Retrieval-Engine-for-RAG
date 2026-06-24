# Phase 4 Blocking MPI Parallel Retrieval Plan

> **For engineers:** This document records what Phase 4 implemented, what was verified, and what assumptions remain in place so Phase 5 can add correctness tooling and Phase 6 can add benchmark orchestration without redesigning the MPI retrieval path.

**Status:** Implemented and verified on 2026-06-15

**Goal:** Turn `parallel_retriever` into a real exact blocking MPI retriever that reuses the Phase 3 local-search core, writes canonical top-k CSV output, and emits one per-rank metrics CSV for the current invocation.

**Architecture:** Phase 4 extends `retriever_core` with `ParallelRetriever` for global merge logic, keeps MPI transport in `MpiUtils` linked only into the parallel binary, and rewrites `main_parallel.cpp` into the real shard-load, broadcast, local-search, gather, merge, and metrics-writing path. Tests cover merge semantics directly and validate blocking MPI behavior end-to-end under `CTest`.

**Tech Stack:** C++17, CMake, Ninja, OpenMPI, CTest, POSIX shell, WSL2 Ubuntu 24.04

---

### Task 1: Add the shared Phase 4 merge core

**Files:**
- Create: `include/ParallelRetriever.hpp`
- Create: `src/ParallelRetriever.cpp`
- Modify: `CMakeLists.txt`

- [x] Add `ParallelRetriever::merge_query_results(...)`.
- [x] Add `ParallelRankMetrics`.
- [x] Keep `ParallelRetriever` MPI-agnostic.
- [x] Reuse `TopKHeap` for deterministic best-k retention and ordering.
- [x] Filter sentinel candidate slots before the global merge.

### Task 2: Add blocking MPI helpers outside `retriever_core`

**Files:**
- Create: `include/MpiUtils.hpp`
- Create: `src/MpiUtils.cpp`
- Modify: `CMakeLists.txt`

- [x] Add `broadcast_query_vector(...)`.
- [x] Add `pack_local_candidates_fixed_k(...)`.
- [x] Add `gather_fixed_candidates(...)` with primitive arrays only.
- [x] Add `gather_rank_metrics(...)`.
- [x] Add `gather_startup_errors(...)` with fixed-size char buffers to avoid startup deadlocks.
- [x] Keep `MpiUtils` linked only into `parallel_retriever`, not into `retriever_core`.

### Task 3: Replace the MPI scaffold with the real retrieval flow

**Files:**
- Modify: `src/main_parallel.cpp`
- Modify: `src/Config.cpp`

- [x] Keep `MpiSession` as the MPI lifecycle owner.
- [x] Keep parse/help behavior centralized on rank `0`.
- [x] Load memory vectors per-rank via `BinaryDataset::read_shard(...)`.
- [x] Read the query header on every rank and the full query payload only on rank `0`.
- [x] Validate normalized + row-major flags, dimension compatibility, and global `topk`.
- [x] Broadcast one query vector at a time with blocking `MPI_Bcast`.
- [x] Reuse `SequentialRetriever::search_local(...)` for shard-local exact search.
- [x] Gather fixed-size local top-k ids and scores with blocking `MPI_Gather`.
- [x] Merge the gathered candidates on rank `0`.
- [x] Write:
  - `parallel_topk.csv`
  - `parallel_metrics.csv`
- [x] Update parallel help text so it no longer claims scaffold-only behavior.

### Task 4: Lock the Phase 4 output contracts

**Files:**
- Modify: `src/main_parallel.cpp`

- [x] Use top-k CSV header exactly:
  - `query_id,rank_position,memory_id,score`
- [x] Keep zero-based global `query_id` and `memory_id`.
- [x] Keep one-based `rank_position`.
- [x] Keep `score` formatting at `std::fixed` with `std::setprecision(8)`.
- [x] Lock metrics CSV header exactly:
  - `rank,local_N,compute_time,communication_time,active_time,global_total_time,idle_time`
- [x] Define:
  - `compute_time` = local scan time, plus merge time on rank `0`
  - `communication_time` = query broadcast + candidate gather time
  - `active_time = compute_time + communication_time`
  - `global_total_time` = maximum retrieval-loop wall time across ranks
  - `idle_time = global_total_time - active_time`

### Task 5: Add direct tests and MPI smoke coverage

**Files:**
- Create: `tests/ParallelRetrieverTest.cpp`
- Create: `tests/cmake/RunParallelRetrievalSmoke.cmake`
- Create: `tests/cmake/RunParallelWorldSizeGtNSmoke.cmake`
- Create: `tests/cmake/RunParallelDimensionMismatchFail.cmake`
- Modify: `tests/ConfigLoggerTest.cpp`
- Modify: `CMakeLists.txt`

- [x] Add `parallel_retriever_test` for:
  - global best-k merge
  - tie-break on `memory_id`
  - sentinel filtering
  - empty-rank handling
- [x] Add MPI smoke checks for:
  - sequential vs parallel CSV equivalence on small input
  - metrics CSV existence and line count
  - `world_size > N`
  - dimension mismatch failure under `mpirun`
- [x] Update the help-text expectation in `ConfigLoggerTest.cpp`.

### Task 6: Update canonical documentation

**Files:**
- Modify: `README.md`
- Modify: `docs/development/source_guide.md`
- Modify: `docs/development/developer_guide.md`
- Modify: `docs/development/data_pipeline_and_benchmarks.md`
- Create: `docs/plans/2026-06-15-phase-4-blocking-mpi-parallel-retrieval.md`

- [x] Update `README` phase status and quickstart commands.
- [x] Update `source_guide.md` so `parallel_retriever` is documented as a real retrieval path, not a scaffold.
- [x] Update `developer_guide.md` with the Phase 4 MPI run/verify flow.
- [x] Update `data_pipeline_and_benchmarks.md` with the parallel output and metrics CSV contracts.

### Task 7: Verification actually completed

**Ubuntu WSL checks actually run from `/mnt/d/DS-AI/Parallel-Retrieval-Engine-for-RAG`:**

- [x] `bash ./scripts/configure_debug.sh`
- [x] `cmake --build build/debug`
- [x] `ctest --test-dir build/debug --output-on-failure`
- [x] `./build/debug/generate_vectors --N 64 --D 8 --output data/memory_vectors.bin`
- [x] `./build/debug/generate_queries --Q 5 --D 8 --output data/query_vectors.bin`
- [x] `./build/debug/sequential_retriever --vectors data/memory_vectors.bin --queries data/query_vectors.bin --topk 3 --output results/sequential_topk.csv`
- [x] `mpirun -np 4 ./build/debug/parallel_retriever --vectors data/memory_vectors.bin --queries data/query_vectors.bin --topk 3 --output results/parallel_topk.csv --metrics results/parallel_metrics.csv`
- [x] parallel dimension mismatch run fails non-zero with a clear error

**Observed result:**

- all `19/19` CTest cases passed
- the acceptance run generated:
  - `results/parallel_topk.csv`
  - `results/parallel_metrics.csv`
- the top-k CSV header matched exactly:
  - `query_id,rank_position,memory_id,score`
- the metrics CSV header matched exactly:
  - `rank,local_N,compute_time,communication_time,active_time,global_total_time,idle_time`
- the `Q = 5`, `k = 3` acceptance run produced:
  - `16` lines in `parallel_topk.csv`
  - `5` lines in `parallel_metrics.csv`
- the small-input MPI smoke matched the sequential CSV exactly
- the `world_size > N` MPI smoke passed
- the dimension mismatch MPI smoke detected the expected failure

### Notes for the next person

- Phase 4 reuses `SequentialRetriever::search_local(...)` as the shard-local exact kernel; do not fork that logic in later phases unless there is a measured reason.
- The fixed-size gather design deliberately avoids custom MPI datatypes and `MPI_Gatherv`; keep that simplicity unless later profiling proves it is a bottleneck.
- `parallel_metrics.csv` is invocation-local metrics output, not the later benchmark-summary CSV layer.
- Correctness comparison tooling and benchmark automation remain later-phase work.
