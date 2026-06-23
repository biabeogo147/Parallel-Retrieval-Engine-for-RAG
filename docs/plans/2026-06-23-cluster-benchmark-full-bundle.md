# 2026-06-23 Cluster Benchmark Full Bundle

## Objective

Close the remaining operational gap after the validated two-node manual cluster run by adding:

- dedicated two-node cluster bundle scripts
- a postprocess-only cluster analysis wrapper
- operator-facing bundle documentation and config examples
- canonical doc updates for cluster analysis and result locations

## Scope

Included:

- add shared cluster shell helpers for the validated `rag-head + rag-worker1` topology
- add a dedicated two-node bundle wrapper that runs calibration, correctness, granularity, speedup, FAISS comparison, and postprocess stages into one cluster result directory
- add a postprocess-only wrapper that regenerates cluster `analysis/` and `figures/`
- add a shell-sourced example config for the two-node bundle
- update the canonical usage, development, README, and analysis docs to point to the new operator flow
- add smoke coverage for:
  - cluster bundle dry-run planning
  - cluster postprocess artifact generation

Excluded:

- rewriting the generic three-node cluster docs into automated orchestration
- changing retrieval logic, MPI contracts, dataset format, or CSV schemas
- claiming a fresh real two-node rerun from this Windows-mounted workspace

## Architecture Summary

The new cluster operator surface is:

- `scripts/cluster_common.sh`
  - shared helper layer for the validated two-node physical cluster flow
- `scripts/run_cluster_two_node_bundle.sh`
  - end-to-end wrapper for:
    - runtime calibration
    - selected synthetic correctness run
    - granularity summary
    - speedup sweep
    - FAISS comparisons
    - cluster postprocess
- `scripts/run_cluster_postprocess.sh`
  - postprocess-only wrapper that regenerates:
    - `results/cluster/<run-tag>/figures/`
    - `results/cluster/<run-tag>/analysis/`
    - `docs/analysis/latest-cluster-benchmark-review.md`

The dedicated runbook remains:

- `docs/usage/mpi-cluster/two-node-runbook-local-plus-199.md`

Generic cluster guides remain generic and manual-first. The only automation added here is the dedicated validated two-node wrapper.

## Files Modified

- `CMakeLists.txt`
- `scripts/analyze_benchmarks.py`
- `docs/analysis/README.md`
- `README.md`
- `docs/development/developer_guide.md`
- `docs/development/source_guide.md`
- `docs/usage/README.md`
- `docs/usage/results-csv-reference.md`
- `docs/usage/mpi-cluster/README.md`
- `docs/usage/mpi-cluster/cluster-runbook.md`
- `docs/usage/mpi-cluster/two-node-runbook-local-plus-199.md`
- `docs/plans/2026-06-23-cluster-benchmark-full-bundle.md`

Created:

- `scripts/cluster_common.sh`
- `scripts/run_cluster_postprocess.sh`
- `scripts/run_cluster_two_node_bundle.sh`
- `tests/cmake/RunClusterPostprocessSmoke.cmake`
- `tests/cmake/RunClusterBundleDryRunSmoke.cmake`
- `docs/usage/mpi-cluster/examples/two_node_bundle.env.example`
- `docs/analysis/latest-cluster-benchmark-review.md`

## Implementation Summary

### 1. Added the dedicated cluster bundle wrappers

Implemented:

- `cluster_common.sh`
  - physical-core detection
  - hostfile rewriting for per-`P` sweeps
  - worker sync helpers
  - WSL-specific OpenMPI launch flags
  - WSL-mounted-checkout guard for real cluster execution
- `run_cluster_two_node_bundle.sh`
  - the maintained `6`-stage operator flow for the validated two-node topology
- `run_cluster_postprocess.sh`
  - figure and analysis regeneration for an existing `results/cluster/<run-tag>/` directory

### 2. Added test-first smoke coverage

Added and verified:

- `cluster_bundle_dry_run_smoke`
  - proves the bundle exposes the intended six-stage plan and result paths
- `cluster_postprocess_smoke`
  - proves the postprocess wrapper creates cluster figures, analysis tables, JSON summary, Markdown conclusions, and the cluster docs-output review

### 3. Added operator-facing cluster bundle docs

Added:

- `docs/usage/mpi-cluster/examples/two_node_bundle.env.example`

Updated:

- the dedicated two-node runbook so it now covers:
  - manual baseline workflow
  - bundle-config preparation
  - full-bundle rerun
  - postprocess-only regeneration
  - expected `analysis/` and `figures/` outputs

### 4. Updated canonical indexes and references

Aligned:

- `README.md`
- `docs/usage/README.md`
- `docs/usage/mpi-cluster/README.md`
- `docs/usage/results-csv-reference.md`
- `docs/development/developer_guide.md`
- `docs/development/source_guide.md`
- `docs/analysis/README.md`

so the new cluster bundle flow has one clear home and the cluster analysis doc path is indexed.

## Acceptance Criteria

- cluster bundle dry-run exposes the intended six stages and result paths
- cluster postprocess smoke produces figures, derived analysis outputs, and the cluster docs-output review
- the validated two-node runbook records both:
  - the manual baseline flow
  - the dedicated full-bundle rerun flow
- the generic cluster docs remain generic instead of absorbing the validated case-specific operator process
- the analysis docs explain both:
  - single-machine benchmark review output
  - cluster benchmark review output

## Verification Commands

Targeted cluster smoke tests:

```powershell
wsl.exe -d Ubuntu-24.04 -- bash -lc "cd /mnt/d/DS-AI/Parallel-Retrieval-Engine-for-RAG && ctest --test-dir build/debug --output-on-failure -R 'cluster_(postprocess|bundle_dry_run)_smoke'"
```

Reference discovery checks:

```powershell
rg -n "run_cluster_two_node_bundle|run_cluster_postprocess|latest-cluster-benchmark-review|two_node_bundle.env.example" README.md docs scripts tests
```

## Assumptions And Defaults

- the validated physical cluster remains:
  - `rag-head` as a WSL Ubuntu 24.04 head node
  - `rag-worker1` as the Ubuntu server worker
- the dedicated bundle wrapper is for that validated two-node topology, not a claim of generic N-node automation
- real cluster execution must still launch from a WSL-native head-node checkout such as:
  - `~/work/Parallel-Retrieval-Engine-for-RAG`
- this task verified the new operator surface through targeted smoke coverage, not through a fresh full physical-cluster rerun from the current Windows-mounted workspace
