# Phase 2 Dataset Generator + Loader Plan

> **For engineers:** This document records what Phase 2 implemented, what was verified, and what assumptions remain in place so later retrieval work can start from a stable binary dataset contract.

**Status:** Implemented and verified on 2026-06-15

**Goal:** Add the synthetic vector pipeline only: deterministic normalized dataset generation, binary dataset IO, shard-aware loading, and a small inspection tool.

**Architecture:** Phase 2 extends `retriever_core` with binary dataset support, keeps generator CLI parsing local to the tool layer, and uses `CTest` smoke coverage to verify generation, inspection, and determinism from the WSL/OpenMPI development environment.

**Tech Stack:** C++17, CMake, Ninja, OpenMPI, CTest, POSIX shell, WSL2 Ubuntu 24.04

---

### Task 1: Lock the binary dataset contract in shared core

**Files:**
- Create: `include/BinaryDataset.hpp`
- Create: `src/BinaryDataset.cpp`
- Modify: `CMakeLists.txt`

- [x] Add `BinaryDatasetHeader`, `BinaryDatasetContents`, `BinaryDatasetShard`, and `ShardBounds`.
- [x] Implement:
  - `BinaryDataset::write(...)`
  - `BinaryDataset::read_header(...)`
  - `BinaryDataset::read_all(...)`
  - `BinaryDataset::read_shard(...)`
  - `BinaryDataset::compute_shard_bounds(...)`
- [x] Keep the on-disk header aligned with `docs/development/algorithm_design.md`:
  - `magic[8] = "PMRAGV1"`
  - `version = 1`
  - `flags`
  - `num_vectors`
  - `dimension`
  - `reserved0`
- [x] Reject invalid magic, invalid version, zero dimension, truncated payloads, and file sizes inconsistent with header metadata.

### Task 2: Add the synthetic generator and inspection tools

**Files:**
- Create: `tools/SyntheticGeneratorCommon.hpp`
- Create: `tools/generate_vectors.cpp`
- Create: `tools/generate_queries.cpp`
- Create: `tools/inspect_dataset.cpp`
- Modify: `CMakeLists.txt`

- [x] Add `generate_vectors` with:
  - required `--N <int>`
  - required `--D <int>`
  - required `--output <path>`
  - optional `--seed <uint64>` default `12345`
- [x] Add `generate_queries` with:
  - required `--Q <int>`
  - required `--D <int>`
  - required `--output <path>`
  - optional `--seed <uint64>` default `12345`
- [x] Add `inspect_dataset --input <path>`.
- [x] Keep generator parsers local to the tool layer instead of expanding the retriever `Config` type.
- [x] Generate deterministic L2-normalized `float32` vectors and write the normalized + row-major flags.

### Task 3: Add verification coverage in CTest

**Files:**
- Create: `tests/BinaryDatasetTest.cpp`
- Create: `tests/cmake/GenerateAndInspectDataset.cmake`
- Create: `tests/cmake/CheckGeneratorDeterminism.cmake`
- Modify: `CMakeLists.txt`

- [x] Add `binary_dataset_test` for:
  - header round-trip
  - invalid magic
  - invalid version
  - zero dimension
  - truncated payload
  - divisible shard bounds
  - non-divisible shard bounds
  - shard slice reads
- [x] Add CLI smoke tests for:
  - `generate_vectors --help`
  - `generate_queries --help`
  - `inspect_dataset --help`
  - generate + inspect vectors
  - generate + inspect queries
- [x] Add determinism coverage:
  - same seed + same args => identical bytes
  - different seed => different bytes

### Task 4: Update documentation and maintenance guidance

**Files:**
- Create: `docs/development/dataset_pipeline.md`
- Create: `docs/plans/2026-06-15-phase-2-dataset-generator-loader.md`
- Modify: `README.md`
- Modify: `docs/development/codebase_layout.md`
- Modify: `docs/development/dev_workflow.md`
- Modify: `docs/development/environment_setup.md`
- Modify: `scripts/run_smoke_tests.sh`

- [x] Add a focused dataset pipeline doc with the header contract, generator usage, seed behavior, and shard semantics.
- [x] Update `README` quickstart with the new synthetic dataset commands.
- [x] Remove stale wording that still treated `tools/` as intentionally empty.
- [x] Normalize smoke-doc wording so Phase 2 work is reflected in onboarding docs and scripts.

### Task 5: Verification actually completed

**Ubuntu WSL checks actually run from `/mnt/d/DS-AI/Parallel-Retrieval-Engine-for-RAG`:**

- [x] `bash ./scripts/configure_debug.sh`
- [x] `cmake --build build/debug`
- [x] `ctest --test-dir build/debug --output-on-failure`
- [x] `bash ./scripts/run_smoke_tests.sh`
- [x] `./build/debug/generate_vectors --N 100000 --D 384 --output data/memory_vectors.bin`
- [x] `./build/debug/generate_queries --Q 100 --D 384 --output data/query_vectors.bin`
- [x] `./build/debug/inspect_dataset --input data/memory_vectors.bin`
- [x] `./build/debug/inspect_dataset --input data/query_vectors.bin`

**Observed result:**

- all `12/12` CTest cases passed
- the smoke wrapper completed successfully
- `inspect_dataset` reported:
  - `num_vectors = 100000`
  - `dimension = 384`
  - `flags = 3`
- query inspection reported:
  - `num_vectors = 100`
  - `dimension = 384`

### Notes for the next person

- Phase 2 is still synthetic-only. No MS MARCO, SQuAD, or UIT-ViQuAD2.0 conversion work has been added yet.
- The repo-local `data/` directory is the intended place for generated synthetic binaries.
- `/mnt/e/data` remains the canonical mount for larger external benchmark corpora and future converted datasets.
- Phase 3 can now assume:
  - vectors are already normalized
  - payloads are row-major `float32`
  - shard reads return contiguous local slices
