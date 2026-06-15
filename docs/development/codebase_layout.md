# Codebase Layout

## Top-Level Responsibilities

### `include/`

Public project headers for shared code used across binaries and tests. Phase 1 keeps this small:

- `Config.hpp`: CLI contract and validation result types
- `Logger.hpp`: log-level parsing and stderr logger
- `MpiSession.hpp`: minimal MPI lifecycle wrapper

### `src/`

Implementation files and entrypoints.

- `Config.cpp`: parse and validate CLI arguments
- `Logger.cpp`: logging implementation
- `MpiSession.cpp`: MPI bootstrap and teardown
- `main_sequential.cpp`: sequential CLI stub
- `main_parallel.cpp`: MPI CLI stub

### `tests/`

Small executable or script-based checks used by `CTest`.

- `ConfigLoggerTest.cpp`: parser and usage-contract verification

Future phases may add more CLI smoke checks and algorithm tests here.

### `scripts/`

POSIX shell helpers intended to run inside Ubuntu WSL.

- `setup_wsl_dev_env.sh`: package install and tool verification
- `configure_debug.sh`: configure the debug build tree
- `configure_release.sh`: configure the release build tree
- `run_smoke_tests.sh`: build and run the Phase 1 smoke suite

### `tools/`

Standalone helper binaries and utilities that are not part of the main retriever entrypoints. Phase 1 leaves this empty on purpose so later phases can add dataset generators and inspectors without mixing them into `src/`.

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

Phase 1 introduces these targets:

- `retriever_core`
- `sequential_retriever`
- `parallel_retriever`
- `config_logger_test`

`retriever_core` is the shared internal layer. Later phases should prefer extending it instead of duplicating parsing or logging logic in individual binaries.

## Maintainability Rules

1. Shared logic belongs in `retriever_core`, not duplicated in each `main`.
2. New docs must use the refactored `docs/development` and `docs/plans` paths.
3. WSL-first commands should be the default in docs and scripts.
4. Empty future directories should stay obvious and intentional rather than filled with placeholder code.
