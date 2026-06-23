# 2026-06-23 Cluster No-FAISS Expedited Rerun

## Objective

Finish the validated two-node cluster rerun after the operator explicitly chose to skip FAISS, without discarding the already-completed calibration work.

## Scope

Included:

- reuse the finished cluster calibration outputs from:
  - `results/cluster/2026-06-23-local-plus-199-e-root-final`
  - `/mnt/e/data/pdp_retrieve_engine/results/cluster/2026-06-23-local-plus-199-e-root-final`
- complete:
  - selected-workload sequential exact run
  - sequential-versus-parallel correctness verification
  - expedited speedup sweep
  - cluster postprocess
- update canonical docs so the no-FAISS cluster path is reproducible

Excluded:

- rerunning Phase 8 FAISS comparison
- redoing Stage 1 N/Q calibration from zero
- changing retrieval contracts or CSV schemas

## Architecture Summary

The completed rerun used this hybrid flow:

1. keep the already-generated Stage 1 calibration outputs
2. stop the long six-stage wrapper before FAISS
3. reuse the selected `Q=400` parallel calibration outputs as the canonical selected-workload parallel artifacts
4. run the selected-workload sequential baseline exactly once
5. verify correctness
6. pin `N_SPEEDUP=2000000` for an expedited speedup sweep
7. run cluster postprocess with FAISS intentionally absent

## Files Updated

- `scripts/run_cluster_postprocess.sh`
- `scripts/analyze_benchmarks.py`
- `docs/analysis/README.md`
- `docs/development/developer_guide.md`
- `docs/usage/results-csv-reference.md`
- `docs/usage/mpi-cluster/two-node-runbook-local-plus-199.md`
- `docs/plans/2026-06-23-cluster-no-faiss-expedited-rerun.md`
- `results/cluster/2026-06-23-local-plus-199-e-root-final/`
- `docs/analysis/latest-cluster-benchmark-review.md`

## Implemented Result

Final validated cluster result directory:

- `results/cluster/2026-06-23-local-plus-199-e-root-final/`

Key selections:

- `N_SELECTED=10000000`
- `Q=400`
- `CALIBRATION_MODE=N_PLUS_Q`
- `N_SPEEDUP=2000000`
- `P_SELECTED=14`

Selected-workload metrics:

- sequential:
  - `10000000,384,400,10,1,792.45887554,0.00000000,792.45887554`
- parallel:
  - `10000000,384,400,10,14,137.86811244,20.44452541,144.11783635`

Correctness outcome:

- `correctness.csv` is all `PASS`
- query count:
  - `400`

Speedup outcome at the expedited `N_SPEEDUP=2000000` scale:

- `P=14` row:
  - `2000000,384,400,10,14,27.63879480,5.02974455,29.28756019,5.64598044,5.32813569,0.40328432,0.38058112`

Postprocess outcome:

- `analysis/` created successfully
- `figures/` created successfully
- `docs/analysis/latest-cluster-benchmark-review.md` refreshed successfully
- report text explicitly states:
  - `FAISS comparison was skipped for this run`

## Acceptance Criteria

- no-FAISS cluster postprocess succeeds
- selected-workload correctness is all `PASS`
- `speedup.csv` exists and is built from the expedited `N_SPEEDUP=2000000` baseline
- final cluster result directory contains:
  - `analysis/`
  - `figures/`
- the case-specific runbook documents the validated expedited flow

## Verification

Targeted code-path verification:

```bash
cd /mnt/d/DS-AI/Parallel-Retrieval-Engine-for-RAG
ctest --test-dir build/debug --output-on-failure -R cluster_postprocess
ctest --test-dir build/debug --output-on-failure -R benchmark_analysis_
```

Final artifact verification:

```bash
cd ~/work/Parallel-Retrieval-Engine-for-RAG
RESULT_DIR=/mnt/e/data/pdp_retrieve_engine/results/cluster/2026-06-23-local-plus-199-e-root-final

test -f "${RESULT_DIR}/correctness.csv"
test -f "${RESULT_DIR}/speedup.csv"
test -f "${RESULT_DIR}/analysis/final_conclusions.md"
test -f "${RESULT_DIR}/figures/runtime_by_N.png"
grep -q "PASS" "${RESULT_DIR}/correctness.csv"
grep -q "FAISS comparison was skipped for this run" "${RESULT_DIR}/analysis/final_conclusions.md"
```

## Assumptions And Defaults

- the operator chose to skip FAISS intentionally for this rerun
- preserving the finished Stage 1 calibration outputs was better than rerunning the whole six-stage wrapper
- the expedited `N_SPEEDUP=2000000` choice was a deliberate time-saving deviation from the earlier broader speedup-candidate sweep
- the canonical artifact roots remain:
  - external storage:
    - `/mnt/e/data/pdp_retrieve_engine/results/cluster/2026-06-23-local-plus-199-e-root-final`
  - mirrored repo copy:
    - `results/cluster/2026-06-23-local-plus-199-e-root-final`
