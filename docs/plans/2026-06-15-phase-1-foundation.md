# Phase 1 Codebase + WSL Dev Foundation Plan

> **For engineers:** This document records what Phase 1 implemented, what was verified, and what assumptions remain in place so the next person can continue from a known-good baseline.

**Status:** Implemented and verified on 2026-06-15

**Goal:** Establish a maintainable WSL-first C++17 and OpenMPI foundation before implementing retrieval logic.

**Architecture:** Phase 1 introduces a small shared core library, two CLI entrypoints, CTest-based smoke coverage, POSIX shell helpers for WSL, and developer-facing documentation. The focus is repository structure, toolchain bootstrap, and stable interfaces rather than retrieval behavior.

**Tech Stack:** C++17, CMake, Ninja, OpenMPI, CTest, POSIX shell, WSL2 Ubuntu 24.04

---

### Task 1: Establish the repository scaffold

**Files:**
- Create: `CMakeLists.txt`
- Create: `include/`
- Create: `src/`
- Create: `tests/`
- Create: `scripts/`
- Create: `tools/.gitkeep`
- Create: `data/.gitkeep`
- Create: `results/.gitkeep`
- Modify: `.gitignore`

- [x] Add a top-level CMake project using `C++17`, `find_package(MPI REQUIRED)`, and `include(CTest)`.
- [x] Define build targets:
  - `retriever_core`
  - `sequential_retriever`
  - `parallel_retriever`
  - `config_logger_test`
- [x] Keep build artifacts out of source under `build/debug` and `build/release`.
- [x] Update `.gitignore` to ignore `build/`, generated data/results, and local dev artifacts.

### Task 2: Lock the Phase 1 CLI contract

**Files:**
- Create: `include/Config.hpp`
- Create: `include/Logger.hpp`
- Create: `include/MpiSession.hpp`
- Create: `src/Config.cpp`
- Create: `src/Logger.cpp`
- Create: `src/MpiSession.cpp`
- Create: `src/main_sequential.cpp`
- Create: `src/main_parallel.cpp`

- [x] Implement CLI parsing and validation for:
  - `--help`
  - `--vectors <path>`
  - `--queries <path>`
  - `--output <path>`
  - `--topk <int>`
  - `--log-level <debug|info|warn|error>`
  - `--metrics <path>` for the parallel binary only
- [x] Make `sequential_retriever --help` print stable usage and exit `0`.
- [x] Make `parallel_retriever --help` initialize MPI, print from rank `0` only, and exit cleanly.
- [x] Keep both binaries as Phase 1 stubs; retrieval logic is intentionally not implemented yet.

### Task 3: Add maintainability-first test and script scaffolding

**Files:**
- Create: `tests/ConfigLoggerTest.cpp`
- Create: `scripts/common.sh`
- Create: `scripts/setup_wsl_dev_env.sh`
- Create: `scripts/configure_debug.sh`
- Create: `scripts/configure_release.sh`
- Create: `scripts/run_smoke_tests.sh`

- [x] Add a small executable test for parser, usage text, and log-level validation.
- [x] Register `CTest` coverage for:
  - core parser/logger test
  - `sequential_retriever --help`
  - unknown-flag failure
  - missing-value failure
  - `parallel_retriever --help` under `mpirun`
- [x] Make the MPI smoke path tolerant of temporary `root` WSL sessions by setting:

```bash
OMPI_ALLOW_RUN_AS_ROOT=1
OMPI_ALLOW_RUN_AS_ROOT_CONFIRM=1
```

only where needed for automated verification.

### Task 4: Make docs a first-class deliverable

**Files:**
- Create: `README.md`
- Create: `docs/development/dev_workflow.md`
- Create: `docs/development/codebase_layout.md`
- Modify: `docs/development/environment_setup.md`
- Modify: `docs/development/project_scope.md`
- Modify: `docs/development/parallel_agent_memory_retriever_plan.md`
- Modify: `docs/plans/2026-06-15-phase-0-documentation.md`

- [x] Write a WSL-first `README` with quickstart, smoke commands, and current phase scope.
- [x] Add a dedicated development workflow doc with canonical paths:
  - repo root: `~/work/Parallel-Retrieval-Engine-for-RAG`
  - dataset root: `/mnt/e/data`
- [x] Add a codebase layout doc so new contributors know where each class of artifact belongs.
- [x] Update environment setup docs with the explicit Ubuntu installation step.
- [x] Fix stale links caused by the `docs/` folder refactor so paths now point to `docs/development/...` and `docs/plans/...`.

### Task 5: Verification actually completed

**Windows-side checks:**

- [x] `wsl --status`
- [x] `wsl -l -v`
- [x] `wsl -d Ubuntu-24.04 -- echo hello`

**Ubuntu WSL checks actually run from `/mnt/d/DS-AI/Parallel-Retrieval-Engine-for-RAG`:**

- [x] `apt-get update && apt-get install -y build-essential cmake ninja-build pkg-config openmpi-bin libopenmpi-dev gdb valgrind python3 python3-pip python3-venv sudo`
- [x] `mpicxx --version`
- [x] `mpirun --version`
- [x] `cmake --version`
- [x] `ninja --version`
- [x] `bash ./scripts/configure_debug.sh`
- [x] `cmake --build build/debug`
- [x] `ctest --test-dir build/debug --output-on-failure`
- [x] `./build/debug/sequential_retriever --help`
- [x] `OMPI_ALLOW_RUN_AS_ROOT=1 OMPI_ALLOW_RUN_AS_ROOT_CONFIRM=1 mpirun -np 4 ./build/debug/parallel_retriever --help`
- [x] `bash ./scripts/run_smoke_tests.sh`

**Observed result:** all five CTest cases passed, both CLI help paths worked, and the smoke script completed successfully.

### Notes for the next person

- The preferred long-term workflow is still a normal Ubuntu user at `~/work/Parallel-Retrieval-Engine-for-RAG`.
- Verification in this session was done from `/mnt/d/DS-AI/Parallel-Retrieval-Engine-for-RAG` because that is where the active checkout currently lives.
- The current Ubuntu distro was running as `root` during verification, which is why the MPI smoke flow includes the temporary OpenMPI root override.
- Retrieval logic, binary dataset IO, benchmark runners, and plotting remain Phase 2+ work.
