# MPI Cluster Setup Docs Plan

> **For engineers:** This document records what the physical three-machine MPI cluster documentation bundle implemented, what it intentionally did not automate, and how it fits the existing `docs/usage/` and `docs/development/` layers.

**Status:** Implemented and verified on 2026-06-17

**Goal:** Add a command-first `docs/usage/mpi-cluster/` bundle so a developer can bootstrap three physical computers, clone the repo on each new node, assemble a cluster, validate remote MPI launch, and run exact multi-node retrieval manually.

**Architecture:** The new cluster bundle stays in `docs/usage/` because it is an operational, onboarding-oriented workflow. It does not replace the canonical single-machine WSL development workflow. Instead, it layers a shared cluster core on top of three separate node bootstrap tracks:

- Windows + WSL2 + Ubuntu 24.04
- native Ubuntu 24.04
- macOS + Multipass + Ubuntu 24.04

The shared cluster core then standardizes:

- same repo path on every node
- same binary path on every node
- passwordless SSH from head to workers
- head-owned authoritative shared data
- local `data/` copies on every node for real MPI runs

**Tech Stack:** Markdown, Bash, PowerShell, zsh, WSL2 Ubuntu 24.04, native Ubuntu 24.04, Multipass Ubuntu 24.04, OpenMPI, SSH, `rsync`

---

### Task 1: Create the cluster usage bundle

**Files:**

- Create: `docs/usage/mpi-cluster/README.md`
- Create: `docs/usage/mpi-cluster/node-bootstrap-wsl.md`
- Create: `docs/usage/mpi-cluster/node-bootstrap-ubuntu.md`
- Create: `docs/usage/mpi-cluster/node-bootstrap-macos-multipass.md`
- Create: `docs/usage/mpi-cluster/cluster-assembly-and-validation.md`
- Create: `docs/usage/mpi-cluster/cluster-runbook.md`
- Create: `docs/usage/mpi-cluster/troubleshooting.md`

- [x] Add one shared cluster core plus three per-platform bootstrap tracks.
- [x] Keep the docs English-only and operationally focused.
- [x] Start each repo workflow from `~/work/Parallel-Retrieval-Engine-for-RAG`.
- [x] Document the manual multi-node MPI path without claiming cluster-aware benchmark automation exists.

### Task 2: Add bundled example artifacts

**Files:**

- Create: `docs/usage/mpi-cluster/examples/hosts.example`
- Create: `docs/usage/mpi-cluster/examples/ssh_config.example`

- [x] Provide a sample OpenMPI hostfile.
- [x] Provide a sample head-node SSH config.
- [x] Keep both examples explicitly editable rather than pretending they are zero-edit drop-ins.

### Task 3: Align the canonical indexes

**Files:**

- Modify: `README.md`
- Modify: `docs/usage/README.md`
- Modify: `docs/development/developer_guide.md`

- [x] Add a clear pointer from the repo root to the new cluster docs.
- [x] Keep `docs/usage/` as the operational home for multi-machine setup.
- [x] Keep `docs/development/developer_guide.md` as the technical single-machine reference and point out that physical cluster operations live under `docs/usage/mpi-cluster/`.

### Task 4: Lock the operational conventions

**Decisions implemented:**

- [x] Cluster size is fixed to `3` physical computers for this doc bundle.
- [x] The topology is `1 head node + 2 worker nodes`.
- [x] Canonical example hostnames are `rag-head`, `rag-worker1`, and `rag-worker2`.
- [x] Canonical repo path remains `~/work/Parallel-Retrieval-Engine-for-RAG`.
- [x] Authoritative shared data is managed from the head node.
- [x] Actual retrieval runs use local `data/` copies on each node.
- [x] WSL nodes are supported, but only as operator-managed nodes that must be launched and kept alive before remote MPI work.

### Task 5: Verification actually completed

**Repo/document checks run from `D:\DS-AI\Parallel-Retrieval-Engine-for-RAG`:**

- [x] confirmed the new usage paths fit the current `docs/usage/` bundle shape
- [x] confirmed all referenced repo scripts already exist:
  - `scripts/setup_wsl_dev_env.sh`
  - `scripts/configure_debug.sh`
  - `scripts/configure_release.sh`
  - `scripts/run_smoke_tests.sh`
- [x] confirmed the documented binary names match the current repo:
  - `sequential_retriever`
  - `parallel_retriever`
  - `verify_results`
  - `generate_vectors`
  - `generate_queries`
  - `inspect_dataset`
- [x] checked the updated Markdown links in `README.md`, `docs/usage/README.md`, `docs/development/developer_guide.md`, and the new `docs/usage/mpi-cluster/` bundle
- [x] confirmed current usage docs remain single-machine oriented and therefore do not overlap the new multi-node operational bundle

**WSL command-surface checks run from `/mnt/d/DS-AI/Parallel-Retrieval-Engine-for-RAG`:**

- [x] `./build/debug/sequential_retriever --help`
- [x] `mpirun -np 2 ./build/debug/parallel_retriever --help`
- [x] `./build/debug/verify_results --help`
- [x] `./build/debug/generate_vectors --help`
- [x] `./build/debug/generate_queries --help`
- [x] `./build/debug/inspect_dataset --help`
- [x] confirmed the expected debug binaries exist
- [x] confirmed the expected release retriever binaries exist
- [x] checked the current retrieval usage guide to keep the cluster flow aligned with the existing dataset and CSV contracts

**Observed result:**

- the repo already had the needed binaries and scripts for a manual three-machine MPI guide
- there was no existing `docs/usage/` source of truth for physical cluster setup, so adding `docs/usage/mpi-cluster/` did not duplicate an existing canonical topic
- the new bundle could stay operational and explicit without changing the current automation scripts

### Notes for the next person

- If you later add cluster-aware automation, update this bundle and the relevant benchmark usage docs in the same task.
- Keep physical cluster docs in `docs/usage/`, not `docs/development/`.
- If the MPI launch contract, repo path, or runtime-data policy changes, update:
  - `docs/usage/mpi-cluster/`
  - `docs/usage/README.md`
  - `README.md`
  - `docs/development/developer_guide.md`
