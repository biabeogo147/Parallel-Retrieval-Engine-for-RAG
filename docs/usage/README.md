# Usage Docs

This folder is the command-first entrypoint for developers who have just cloned the repository and want to use it without reading the deeper architecture material first.

Use `docs/usage/` for:

- WSL onboarding after `git clone`
- build and smoke-test commands
- synthetic retrieval workflows
- benchmark automation workflows
- physical multi-machine MPI setup and validation workflows
- common troubleshooting and safe generated-state cleanup

Use `docs/development/` for:

- technical contracts
- dataset and benchmark policy
- source-code walkthroughs
- codebase structure and maintenance rules

## Reading Order

1. [getting-started-wsl.md](getting-started-wsl.md)
2. [retrieval-workflows.md](retrieval-workflows.md)
3. [results-csv-reference.md](results-csv-reference.md)
4. [benchmark-workflows.md](benchmark-workflows.md)
5. [troubleshooting.md](troubleshooting.md)

If you need a physical three-machine MPI cluster instead of the normal single-machine path, branch into:

- [mpi-cluster/README.md](mpi-cluster/README.md)
- [mpi-cluster/two-node-runbook-two-nodes.md](mpi-cluster/two-node-runbook-two-nodes.md) if you want the exact validated local-WSL-head plus one-Ubuntu-worker flow, including the dedicated full-bundle rerun and cluster postprocess steps

If you only need the shortest path after cloning, start with `getting-started-wsl.md`, then jump directly to the specific workflow you need.

## Command Conventions

- Bash commands assume you are already inside Ubuntu WSL.
- PowerShell commands are used only for installing or launching WSL from Windows.
- Unless a section says otherwise, run commands from:

```bash
cd ~/work/Parallel-Retrieval-Engine-for-RAG
```

- Paths inside command examples are repo-relative unless marked as external dataset paths.

## Canonical Paths

- WSL repo root: `~/work/Parallel-Retrieval-Engine-for-RAG`
- External dataset root in WSL: `/mnt/e/data`

## Artifact Map

- `build/debug/`
  - debug binaries and CMake/Ninja build files
- `build/release/`
  - release binaries and release build files
- `data/`
  - local synthetic dataset files such as `memory_vectors.bin` and `query_vectors.bin`
- `results/`
  - top-k CSV outputs, correctness CSVs, benchmark tables, selection manifest, generated figures, and Phase 8 `results/faiss/` artifacts
- `.cache/benchmarks/`
  - scratch benchmark datasets and intermediate CSV files created by the automation scripts
- `.cache/real_corpora/`
  - converted real-corpus binaries and metadata created by the current `SQuAD + MiniLM` Phase 8 workflow
- `.venv/`
  - repo-local Python virtual environment used by benchmark plotting and Phase 8 Python dependencies such as FAISS and sentence-transformers

## Deeper Technical References

When you need more than the operational steps, continue here:

- [../development/project_specification.md](../development/project_specification.md)
  - scope, algorithm design, and fixed contracts
- [../development/data_pipeline_and_benchmarks.md](../development/data_pipeline_and_benchmarks.md)
  - dataset rules, benchmark semantics, and CSV contracts
- [../development/developer_guide.md](../development/developer_guide.md)
  - technical WSL rationale, codebase layout, and maintenance guidance
- [../development/source_guide.md](../development/source_guide.md)
  - runtime flow and source-file responsibilities

## Typical First Session

If you want the shortest successful path:

1. Follow [getting-started-wsl.md](getting-started-wsl.md).
2. Run the small synthetic flow in [retrieval-workflows.md](retrieval-workflows.md).
3. Read [results-csv-reference.md](results-csv-reference.md) to understand the generated outputs.
4. When that works, move to [benchmark-workflows.md](benchmark-workflows.md), including the separate FAISS comparison workflow if you need the Phase 8 baseline path.
5. If anything fails, check [troubleshooting.md](troubleshooting.md).

## Physical MPI Cluster Setup

Use [mpi-cluster/README.md](mpi-cluster/README.md) when:

- you are preparing three physical computers instead of one local development machine
- you need one shared cluster workflow after separate per-node bootstrap steps
- you want to run `parallel_retriever` across multiple LAN-reachable Ubuntu environments

Use [mpi-cluster/two-node-runbook-two-nodes.md](mpi-cluster/two-node-runbook-two-nodes.md) when:

- you specifically want the exact `rag-head + rag-worker1` process that was already executed and verified on this repo
- you prefer one end-to-end checklist over adapting the generic cluster guides
- you want the dedicated operator wrapper flow around:
  - `scripts/run_cluster_two_node_bundle.sh`
  - `scripts/run_cluster_postprocess.sh`
  - `results/cluster/<run-tag>/analysis/`
  - `results/cluster/<run-tag>/figures/`

Use [mpi-cluster/cluster-runbook.md](mpi-cluster/cluster-runbook.md) when:

- you already prepared the hostfile, synchronized datasets, and selected-workload manifest manually
- you want the generic `rag-head + N workers` post-calibration rerun wrapper:
  - `scripts/run_cluster_n_node_bundle.sh`
- you want that generic wrapper to produce a real ascending `runtime_by_N.csv` sweep plus a fixed speedup sweep through `P=32`, with oversubscription above the hostfile slot total when needed
- you want FAISS or optional real-corpus work to remain explicit manual steps outside the generic cluster bundle

That bundle keeps the current repo boundaries intact:

- `docs/usage/mpi-cluster/`
  - operational, copy-paste oriented multi-machine setup and runbook
- `docs/development/`
  - deeper technical contracts, architecture, and maintenance guidance
