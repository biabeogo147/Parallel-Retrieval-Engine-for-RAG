# Codebase Layout

## Top-Level Responsibilities

### `include/`

Public project headers for shared code used across binaries and tests.

- `Config.hpp`: CLI contract and validation result types
- `Logger.hpp`: log-level parsing and stderr logger
- `MpiSession.hpp`: minimal MPI lifecycle wrapper
- `BinaryDataset.hpp`: binary header contract, full reads, and shard-aware reads

### `src/`

Implementation files and entrypoints.

- `Config.cpp`: parse and validate CLI arguments
- `Logger.cpp`: logging implementation
- `MpiSession.cpp`: MPI bootstrap and teardown
- `BinaryDataset.cpp`: binary dataset read/write and shard computation
- `main_sequential.cpp`: sequential CLI stub
- `main_parallel.cpp`: MPI CLI stub

### `tests/`

Small executable or script-based checks used by `CTest`.

- `ConfigLoggerTest.cpp`: parser and usage-contract verification
- `BinaryDatasetTest.cpp`: binary header validation, payload validation, and shard logic
- `tests/cmake/*.cmake`: CLI smoke and determinism checks for generator tools

Later phases may add retrieval correctness and benchmark-result checks here.

### `scripts/`

POSIX shell helpers intended to run inside Ubuntu WSL.

- `setup_wsl_dev_env.sh`: package install and tool verification
- `configure_debug.sh`: configure the debug build tree
- `configure_release.sh`: configure the release build tree
- `run_smoke_tests.sh`: build and run the Phase 1 smoke suite

### `tools/`

Standalone helper binaries and utilities that are not part of the main retriever entrypoints.

- `generate_vectors.cpp`: deterministic synthetic memory-vector generator
- `generate_queries.cpp`: deterministic synthetic query-vector generator
- `inspect_dataset.cpp`: read-only binary header inspection tool
- `SyntheticGeneratorCommon.hpp`: shared tool-only generator and parser helpers

### `data/`

Local generated datasets produced during development. This directory is kept in git only with a placeholder and should not contain committed large binaries.

### `results/`

Local CSVs, benchmark tables, and other generated outputs. Like `data/`, this stays mostly untracked.

### `docs/development/`

Canonical technical docs:

- project scope
- algorithm design
- benchmark strategy
- environment setup
- dev workflow
- codebase layout
- master project plan

### `docs/plans/`

Execution plans and planning artifacts tied to dated work items.

## Build Targets

The current build introduces these targets:

- `retriever_core`
- `sequential_retriever`
- `parallel_retriever`
- `config_logger_test`
- `generate_vectors`
- `generate_queries`
- `inspect_dataset`
- `binary_dataset_test`

`retriever_core` is the shared internal layer. Later phases should prefer extending it instead of duplicating parsing or logging logic in individual binaries.

## Maintainability Rules

1. Shared logic belongs in `retriever_core`, not duplicated in each `main`.
2. New docs must use the refactored `docs/development` and `docs/plans` paths.
3. WSL-first commands should be the default in docs and scripts.
4. Tool-only helpers should stay under `tools/` unless they become shared runtime code needed by retrievers and tests.
