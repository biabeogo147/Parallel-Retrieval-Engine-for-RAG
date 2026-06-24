# Benchmark Analysis Docs

This folder is the canonical home for report-oriented interpretation of benchmark outputs after the runtime, correctness, granularity, speedup, and optional FAISS comparison workflows have already run.

Use this folder when you need:

- a reusable explanation layer on top of `results/*.csv`
- report-ready conclusions and next-step recommendations
- a stable mapping from raw benchmark artifacts to thesis/report sections

## Canonical Command

Run the analysis layer from the repo root after the benchmark and FAISS workflows finish:

```bash
python3 ./scripts/analyze_benchmarks.py \
  --results-dir results \
  --output-dir results/analysis \
  --docs-output docs/analysis/latest-benchmark-review.md
```

For a dedicated physical-cluster result directory that already contains the canonical raw CSVs, either run the cluster wrapper:

```bash
bash scripts/run_cluster_postprocess.sh \
  --results-dir results/cluster/<run-tag> \
  --docs-output docs/analysis/latest-cluster-benchmark-review.md
```

or call the analysis layer directly:

```bash
python3 ./scripts/analyze_benchmarks.py \
  --results-dir results/cluster/<run-tag> \
  --output-dir results/cluster/<run-tag>/analysis \
  --docs-output docs/analysis/latest-cluster-benchmark-review.md
```

## Generated Outputs

The command above generates:

- `results/analysis/runtime_analysis.csv`
- `results/analysis/granularity_analysis.csv`
- `results/analysis/speedup_analysis.csv`
- `results/analysis/faiss_analysis.csv`
- `results/analysis/benchmark_summary.json`
- `results/analysis/final_conclusions.md`
- `docs/analysis/latest-benchmark-review.md`

The cluster variant generates the same analysis family under:

- `results/cluster/<run-tag>/analysis/`
- `docs/analysis/latest-cluster-benchmark-review.md`

## Which File To Cite

- `results/analysis/runtime_analysis.csv`
  - use for explaining whether the selected `N` truly hit the intended runtime window
- `results/analysis/granularity_analysis.csv`
  - use for load-balance interpretation beyond the raw per-rank CSV
- `results/analysis/speedup_analysis.csv`
  - use for identifying the recommended operating point and the first regression point
- `results/analysis/faiss_analysis.csv`
  - use for external-baseline gap classification and fairness discussion when FAISS artifacts are present
  - if FAISS was intentionally skipped for the run, this file may contain only the header row and the paired Markdown review will say so explicitly
- `results/analysis/benchmark_summary.json`
  - use for machine-readable summaries or follow-up automation
- `docs/analysis/latest-benchmark-review.md`
  - use as the main report-ready narrative artifact
- `docs/analysis/latest-cluster-benchmark-review.md`
  - use as the report-ready narrative artifact for one dedicated physical-cluster run directory

## Notes

- The analysis layer is derived-only. It never rewrites the raw benchmark CSVs.
- The analysis layer reads `results/benchmark_selection.env` as part of the benchmark contract. In particular, it uses `N_SELECTED`, `N_SPEEDUP`, `Q`, `CALIBRATION_MODE`, and `N_MAX_FEASIBLE` to interpret the runtime story correctly.
- If `CALIBRATION_MODE=N_PLUS_Q`, the generated Markdown review states explicitly that `N`-only targeting was infeasible on the current hardware and that the benchmark intentionally escalated `Q`.
- If any correctness file contains a `FAIL`, the generated summary marks performance conclusions as `INVALID_UNTIL_CORRECTNESS_FIXED`.
- The cluster postprocess path now supports both:
  - a full cluster run that includes Phase 8 FAISS artifacts
  - a no-FAISS cluster rerun where `results/cluster/<run-tag>/faiss/` is absent or intentionally empty
- In the no-FAISS case, `analysis/faiss_analysis.csv` is still created with its fixed schema, but it contains no data rows and the generated Markdown review states `FAISS comparison was skipped for this run`.
- The analysis docs are English-only to stay aligned with the rest of the repository documentation.
