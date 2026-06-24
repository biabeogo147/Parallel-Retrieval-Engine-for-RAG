# External Benchmark Storage Rerun Record

## Objective

Recover the unfinished two-node cluster benchmark rerun after the WSL ext4 virtual disk on `C:` grew too aggressively during calibration, and move the heavy benchmark working set to `/mnt/e/data/pdp_retrieve_engine` before the next full rerun.

## Scope

- update the benchmark shell layer so a single external storage root can own heavy benchmark artifacts
- update the dedicated two-node cluster bundle so MPI runtime inputs still resolve under identical repo-relative paths on both nodes
- update the operator docs for the validated `rag-head + rag-worker1` topology
- keep the actual retriever binaries and CSV contracts unchanged

## Architecture Summary

The root-cause was not only the default scratch path inside the repo. The cluster wrapper also assumed that generated datasets lived under the repo root because worker synchronization reused repo-relative paths directly. That assumption breaks if we point scratch storage to `/mnt/e/data/...`.

The updated design keeps two layers:

1. external storage layer
   - `BENCH_STORAGE_ROOT=/mnt/e/data/pdp_retrieve_engine`
   - owns heavy scratch datasets, results, `.venv`, and real-corpus conversion cache
2. repo-local runtime staging layer
   - `.cache/cluster_runtime/<run-tag>/...`
   - lightweight symlink paths on the head node
   - real file copies on the worker at the same repo-relative destinations

This preserves MPI path consistency across nodes without forcing the heavy source datasets back into the WSL ext4 disk.

## Files Updated

- `scripts/benchmark_common.sh`
- `scripts/cluster_common.sh`
- `scripts/run_cluster_two_node_bundle.sh`
- `tests/cmake/RunClusterBundleDryRunSmoke.cmake`
- `README.md`
- `docs/development/developer_guide.md`
- `docs/usage/benchmark-workflows.md`
- `docs/usage/results-csv-reference.md`
- `docs/usage/mpi-cluster/cluster-runbook.md`
- `docs/usage/mpi-cluster/examples/two_node_bundle.env.example`
- `docs/usage/mpi-cluster/two-node-runbook-local-plus-199.md`

## Acceptance Criteria

- benchmark scripts accept `BENCH_STORAGE_ROOT` and derive the heavy default paths from it
- the two-node cluster bundle can keep runtime MPI input paths repo-local even when the source datasets live under `/mnt/e/data/pdp_retrieve_engine`
- the dedicated dry-run smoke covers the external-storage configuration surface
- the two-node runbook documents:
  - external storage root
  - repo-local runtime staging
  - optional mirroring of final results back into `results/cluster/...`

## Verification Commands

These are the checks to run before claiming the external-storage rerun path is ready:

```bash
# from the WSL-native head-node checkout
ctest --test-dir build/debug --output-on-failure -R cluster_bundle_dry_run_smoke

bash scripts/run_cluster_two_node_bundle.sh \
  --config .cache/cluster/two_node_bundle.env \
  --run-tag <new-run-tag> \
  --dry-run
```

If WSL and the worker are both healthy, the next step is the real rerun with:

```bash
bash scripts/run_cluster_two_node_bundle.sh \
  --config .cache/cluster/two_node_bundle.env \
  --run-tag <new-run-tag>
```

## Assumptions And Defaults

- canonical head checkout remains `~/work/Parallel-Retrieval-Engine-for-RAG`
- canonical worker repo path remains `~/work/Parallel-Retrieval-Engine-for-RAG`
- benchmark artifact root for the current machine is `/mnt/e/data/pdp_retrieve_engine`
- runtime staging stays under the head repo at `.cache/cluster_runtime/`
- final cluster outputs may live primarily under the external storage root and then be mirrored back into `results/cluster/` when needed for local review
