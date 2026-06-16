# Phase 8 FAISS Baseline Comparison

> **For engineers:** This document records what Phase 8 actually implemented, what was verified, and what remains intentionally deferred so the FAISS baseline path stays aligned with the project contracts instead of drifting into a second retrieval system.

**Status:** Implemented and partially verified on 2026-06-16

**Goal:** Add a maintained external-baseline comparison workflow using FAISS exact flat on the same binary datasets already consumed by `sequential_retriever` and `parallel_retriever`, plus one real-corpus conversion path based on `SQuAD + sentence-transformers/all-MiniLM-L6-v2`.

**Architecture:** Phase 8 stays outside `retriever_core`. The C++ codebase remains the canonical implementation of exact sequential and exact MPI retrieval. FAISS is integrated through WSL-first Python and shell tooling:

- `phase8_common.py` mirrors the repository binary and CSV contracts on the Python side
- `faiss_compare.py` runs `faiss.IndexFlatIP` and writes canonical top-k plus FAISS run-metrics CSVs
- `prepare_squad_minilm.py` converts SQuAD parquet inputs into normalized binary vectors plus `metadata.tsv`
- `run_faiss_comparison.sh` orchestrates sequential, parallel, and FAISS runs over both synthetic data and the current real-corpus path
- `benchmark_csv.py build-faiss-comparison` aggregates the final comparison table

**Tech Stack:** POSIX shell, Python 3, `faiss-cpu`, `numpy`, `pyarrow`, `sentence-transformers`, CMake, CTest, OpenMPI, WSL2 Ubuntu 24.04

---

### Task 1: Extend the benchmark shell foundation for Phase 8

**Files:**
- Modify: `scripts/benchmark_common.sh`
- Create: `scripts/requirements-faiss.txt`
- Create: `scripts/requirements-phase8.txt`

- [x] Add Phase 8 result and dataset path defaults:
  - `BENCH_FAISS_RESULTS_DIR`
  - `BENCH_SQUAD_INPUT_DIR`
  - `BENCH_SQUAD_OUTPUT_DIR`
  - `BENCH_SQUAD_MODEL`
  - `BENCH_SQUAD_QUERIES_LIMIT`
- [x] Add `ensure_phase8_python(...)` to bootstrap a repo-local `.venv/` for FAISS-only or real-corpus conversion dependencies.
- [x] Keep the existing synthetic benchmark helpers reusable instead of introducing a second shell foundation.

### Task 2: Add the Python-side shared contract helpers

**Files:**
- Create: `scripts/phase8_common.py`

- [x] Mirror the repository binary header contract:
  - `magic = PMRAGV1`
  - `version = 1`
  - normalized + row-major flags
- [x] Add binary dataset reading and validation for the Python tools.
- [x] Add canonical top-k CSV writing with deterministic tie handling.
- [x] Add Phase 8 run-metrics CSV writing with schema:
  - `dataset_name,N,D,Q,k,threads,build_time,compute_time,total_time`
- [x] Add `metadata.tsv` writing for the real-corpus conversion path.

### Task 3: Add the FAISS exact-flat baseline runner

**Files:**
- Create: `scripts/faiss_compare.py`

- [x] Implement CLI parsing for:
  - `--vectors`
  - `--queries`
  - `--topk`
  - `--threads`
  - `--output-topk`
  - `--output-metrics`
  - optional `--dataset-name`
- [x] Load binary datasets through the shared Phase 8 helper layer.
- [x] Validate normalized, row-major, same-dimension, and `topk` preconditions.
- [x] Run `faiss.IndexFlatIP` with `faiss.omp_set_num_threads(...)`.
- [x] Write canonical top-k CSV plus one-row FAISS run-metrics CSV.
- [x] Lock `total_time = compute_time` to preserve the chosen fairness policy.

### Task 4: Add the real-corpus conversion path

**Files:**
- Create: `scripts/prepare_squad_minilm.py`

- [x] Read `train-*.parquet` and `validation-*.parquet` from the SQuAD input directory.
- [x] Use unique train `context` values as memory texts.
- [x] Use validation `question` values as query texts.
- [x] Encode both sides with `sentence-transformers/all-MiniLM-L6-v2`.
- [x] Write:
  - `vectors.bin`
  - `queries.bin`
  - `metadata.tsv`
- [x] Keep the produced vectors normalized and compatible with the existing C++ retrievers.

### Task 5: Add the maintained orchestration workflow

**Files:**
- Create: `scripts/run_faiss_comparison.sh`
- Modify: `scripts/benchmark_csv.py`

- [x] Reuse or generate `results/benchmark_selection.env`.
- [x] Run sequential retrieval on the selected synthetic dataset.
- [x] Run parallel retrieval on the selected synthetic dataset.
- [x] Run FAISS on the same synthetic dataset and verify exact-match correctness through `verify_results`.
- [x] Reuse or prepare the `SQuAD + MiniLM` binary dataset.
- [x] Run sequential retrieval, parallel retrieval, FAISS, and correctness verification on that real-corpus dataset.
- [x] Add `build-faiss-comparison` to `benchmark_csv.py`.
- [x] Lock `results/faiss/comparison.csv` schema to:
  - `dataset_name,N,D,Q,k,parallel_workers,faiss_threads,parallel_compute_time,parallel_communication_time,parallel_total_time,faiss_build_time,faiss_compute_time,faiss_total_time,total_ratio,correctness_status,max_score_diff`

### Task 6: Add CTest smoke coverage

**Files:**
- Modify: `CMakeLists.txt`
- Create: `tests/cmake/RunFaissComparisonTableSmoke.cmake`
- Create: `tests/cmake/RunFaissComparisonWorkflowSmoke.cmake`

- [x] Add a pure table-builder smoke test for `benchmark_csv.py build-faiss-comparison`.
- [x] Add a reduced-profile orchestration smoke test for `run_faiss_comparison.sh`.
- [x] Keep the workflow smoke self-contained by creating a tiny prebuilt real-corpus fixture instead of downloading the real embedding model during CTest.

### Task 7: Update canonical docs

**Files:**
- Modify: `README.md`
- Modify: `docs/development/developer_guide.md`
- Modify: `docs/development/source_guide.md`
- Modify: `docs/development/data_pipeline_and_benchmarks.md`
- Modify: `docs/usage/README.md`
- Modify: `docs/usage/benchmark-workflows.md`
- Modify: `docs/usage/results-csv-reference.md`
- Create: `docs/plans/2026-06-16-phase-8-faiss-baseline-comparison.md`

- [x] Update the phase summary and deferred-work wording in `README.md`.
- [x] Document the Phase 8 WSL workflow, artifact locations, and new script responsibilities.
- [x] Extend the source guide with the Phase 8 runtime path and new script/test responsibilities.
- [x] Lock the FAISS metrics and comparison-table semantics in the benchmark contract doc.
- [x] Update the usage docs so fresh-clone developers can run the FAISS workflow and interpret the new CSV outputs.

### Task 8: Verification actually completed

**WSL checks actually run from `/mnt/d/DS-AI/Parallel-Retrieval-Engine-for-RAG`:**

- [x] `cmake -S . -B build/debug -G Ninja -DCMAKE_BUILD_TYPE=Debug -DCMAKE_CXX_COMPILER=mpicxx`
- [x] `cmake --build build/debug`
- [x] `ctest --test-dir build/debug -R benchmark_faiss_comparison_table_smoke --output-on-failure`
- [x] `ctest --test-dir build/debug -R benchmark_faiss_comparison_workflow_smoke --output-on-failure`

**Observed result:**

- the new FAISS comparison-table smoke test passed
- the reduced-profile FAISS orchestration smoke test passed
- the workflow smoke produced:
  - synthetic FAISS top-k CSV
  - synthetic FAISS run-metrics CSV
  - synthetic FAISS correctness CSV
  - real-fixture FAISS top-k CSV
  - real-fixture FAISS run-metrics CSV
  - real-fixture FAISS correctness CSV
  - `comparison.csv`

**Important verification boundary:**

- the smoke workflow used a tiny prebuilt real-corpus fixture through `BENCH_SQUAD_OUTPUT_DIR`
- the full real SQuAD conversion path with actual `sentence-transformers/all-MiniLM-L6-v2` download was implemented, but it was not exercised end-to-end during this verification pass

### Notes for the next person

- Phase 8 keeps FAISS outside the C++ retrieval core on purpose. Do not move FAISS into `retriever_core` unless the project direction changes explicitly.
- `speedup.csv` and the Phase 6-7 synthetic benchmark story remain unchanged; FAISS comparison is a separate report table, not a new speedup denominator.
- The current maintained real-corpus path is only:
  - SQuAD parquet input
  - `all-MiniLM-L6-v2`
  - normalized binary outputs
- Broader corpus conversion, alternate ANN baselines, and metadata-backed demo layers remain future work.
