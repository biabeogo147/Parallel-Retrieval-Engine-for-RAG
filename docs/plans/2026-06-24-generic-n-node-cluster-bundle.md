# Generic N-Node Cluster Bundle Plan

## Objective

Add a generic post-calibration cluster rerun wrapper that works for `rag-head + N workers` without changing retriever contracts, dataset formats, or the existing validated two-node full bundle.

## Scope

Included:

- add a generic `run_cluster_n_node_bundle.sh` operator wrapper
- add a generic `cluster_n_node_common.sh` helper layer
- keep setup, dataset generation, dataset sync, and FAISS or real-corpus comparison manual
- add a tracked `n_node_bundle.env.example`
- add dry-run smoke coverage for the new wrapper
- update the canonical cluster docs and indexes for the new generic rerun path
- normalize stale references to the actual two-node runbook filename

Excluded:

- changing `parallel_retriever`, `verify_results`, MPI contracts, or CSV schemas
- replacing the existing validated two-node full bundle
- adding cluster-aware dataset generation, `rsync`, SSH orchestration, or FAISS automation to the new wrapper

## Architecture Summary

The new generic operator surface is:

- `scripts/cluster_n_node_common.sh`
  - sources and validates the shell config
  - parses a hostfile with explicit `slots=...`
  - computes the total MPI slot budget
  - rewrites reduced hostfiles in host order for per-`P` sweeps
  - runs `parallel_retriever` with the same WSL-safe OpenMPI flags already used by the dedicated two-node flow
- `scripts/run_cluster_n_node_bundle.sh`
  - consumes an existing `benchmark_selection.env`
  - assumes the selected and speedup datasets already exist identically on every node
  - runs:
    - selected synthetic correctness run
    - granularity summary
    - speedup sweep
    - cluster postprocess

The generic runbook remains operator-focused:

- manual:
  - hostfile prep
  - dataset generation
  - dataset sync
  - selection-manifest prep
  - optional manual FAISS or real-corpus runs
- automated:
  - `run_cluster_n_node_bundle.sh`
  - `run_cluster_postprocess.sh`

## Files Modified

Created:

- `scripts/cluster_n_node_common.sh`
- `scripts/run_cluster_n_node_bundle.sh`
- `docs/usage/mpi-cluster/examples/n_node_bundle.env.example`
- `tests/cmake/RunClusterNNodeBundleDryRunSmoke.cmake`
- `docs/plans/2026-06-24-generic-n-node-cluster-bundle.md`

Modified:

- `CMakeLists.txt`
- `README.md`
- `docs/usage/README.md`
- `docs/usage/mpi-cluster/README.md`
- `docs/usage/mpi-cluster/cluster-runbook.md`
- `docs/development/developer_guide.md`
- `docs/development/source_guide.md`

## Acceptance Criteria

- the new wrapper works for `rag-head + N workers` when hostfile and dataset paths were prepared manually
- the wrapper never generates datasets, never `rsync`s files, never SSH-orchestrates workers, and never runs FAISS
- `--dry-run` reports resolved result paths, parsed node count, total slot budget, and the 4 expected stages
- the existing `run_cluster_two_node_bundle.sh` behavior stays unchanged
- `cluster-runbook.md` clearly separates:
  - manual setup and sync
  - generic post-calibration rerun automation
  - the dedicated two-node full-bundle path
- updated indexes point to `two-node-runbook-two-nodes.md`

## Verification Commands

Primary smoke checks:

```bash
ctest --test-dir build/debug --output-on-failure -R "cluster_(bundle_dry_run|n_node_bundle_dry_run)_smoke"
```

Discovery and doc-index checks:

```bash
rg -n "run_cluster_n_node_bundle|n_node_bundle.env.example|two-node-runbook-two-nodes" README.md docs scripts tests
```

Direct dry-run check:

```bash
bash scripts/run_cluster_n_node_bundle.sh \
  --config .cache/cluster/n_node_bundle.env \
  --run-tag smoke-n-node \
  --dry-run
```

## Assumptions And Defaults

- the canonical environment remains WSL2 + Ubuntu 24.04 + OpenMPI
- the hostfile is the authoritative source for generic N-node topology and must include explicit slot counts
- all nodes already expose identical selected-workload and speedup-workload dataset paths before the wrapper starts
- the provided `benchmark_selection.env` already reflects a previously chosen workload
- FAISS and optional real-corpus runs remain manual runbook steps outside the new wrapper
