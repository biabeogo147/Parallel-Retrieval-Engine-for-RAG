# Usage Onboarding Docs Plan

> **For engineers:** This document records what the `docs/usage/` onboarding bundle implemented, what was verified, and how it relates to the canonical `docs/development/` references.

**Status:** Implemented and verified on 2026-06-15

**Goal:** Add a command-first `docs/usage/` bundle so a developer can go from fresh clone to setup, build, retrieval, correctness checking, and benchmark automation without first reading the deeper technical docs.

**Architecture:** The new `docs/usage/` folder is the user-facing operational layer. It does not replace `docs/development/`; instead it links downward into the technical references while keeping fresh-clone onboarding, workflow commands, and troubleshooting in one compact location.

**Tech Stack:** Markdown, WSL2 Ubuntu 24.04, Bash command workflows, existing repo scripts and binaries

---

### Task 1: Create the `docs/usage/` bundle

**Files:**

- Create: `docs/usage/README.md`
- Create: `docs/usage/getting-started-wsl.md`
- Create: `docs/usage/retrieval-workflows.md`
- Create: `docs/usage/benchmark-workflows.md`
- Create: `docs/usage/troubleshooting.md`

- [x] Add a command-first entrypoint for developers after `git clone`.
- [x] Split usage content by responsibility instead of making one giant handbook.
- [x] Keep all operational examples WSL-first and Bash-first.
- [x] Document the current synthetic retrieval and benchmark workflows only.

### Task 2: Clarify the doc boundary with the technical references

**Files:**

- Modify: `README.md`
- Modify: `AGENTS.md`
- Modify: `docs/development/developer_guide.md`
- Modify: `docs/development/data_pipeline_and_benchmarks.md`

- [x] Add `docs/usage/` as the operational how-to home.
- [x] Keep `docs/development/` as the technical reference layer.
- [x] Reduce duplicated operational walkthrough content in `README.md`.

### Task 3: Verify the documented command surface

**Files:**

- Review: `scripts/*.sh`
- Review: `scripts/benchmark_common.sh`
- Review: current CLI binaries and flags

- [x] Confirm documented script names match the repository.
- [x] Confirm benchmark environment variables match the current public script surface.
- [x] Confirm retrieval and benchmark command examples align with the current binaries.

### Task 4: Verification actually completed

**Ubuntu WSL checks actually run from `/mnt/d/DS-AI/Parallel-Retrieval-Engine-for-RAG`:**

- [x] `bash scripts/setup_wsl_dev_env.sh`
- [x] `bash scripts/configure_debug.sh`
- [x] `cmake --build build/debug`
- [x] `ctest --test-dir build/debug --output-on-failure`
- [x] `bash scripts/run_smoke_tests.sh`
- [x] the small synthetic retrieval flow from `docs/usage/retrieval-workflows.md`
- [x] `bash scripts/run_all_experiments.sh`
- [x] a reduced custom benchmark run using overridden `BENCH_*` variables

**Observed result:**

- the usage docs matched the current scripts and binaries
- the internal Markdown links checked in `README.md`, `docs/usage/`, and the updated canonical development docs all resolved successfully
- the setup, build, test, and smoke flow ran successfully in WSL
- the optional release configure/build flow also completed successfully
- the retrieval flow generated the documented synthetic artifacts and correctness CSV
- the default benchmark automation flow generated the documented CSVs, manifest, and figures
- the reduced-profile benchmark example also completed and wrote outputs to its custom result directory
- the current default benchmark selection manifest resolved to:
  - `N_SELECTED=2000000`
  - `N_SPEEDUP=4000000`
  - `P_SELECTED=10`
- the current reduced-profile benchmark selection manifest resolved to:
  - `N_SELECTED=64`
  - `N_SPEEDUP=128`
  - `P_SELECTED=4`
- the current reduced-profile benchmark example also generated its documented figure set under `results/smoke/figures/`

### Notes for the next person

- Add new user-facing command workflows to `docs/usage/`, not to `docs/development/`.
- Keep `docs/development/` focused on contracts, architecture, and maintenance explanation.
- If a script or CLI flag changes, update both the relevant usage guide and the deeper technical reference in the same task.
