# Benchmark Analysis Docs

This folder is the canonical home for report-oriented interpretation of benchmark outputs after the runtime, correctness, granularity, speedup, and FAISS comparison workflows have already run.

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

## Generated Outputs

The command above generates:

- `results/analysis/runtime_analysis.csv`
- `results/analysis/granularity_analysis.csv`
- `results/analysis/speedup_analysis.csv`
- `results/analysis/faiss_analysis.csv`
- `results/analysis/benchmark_summary.json`
- `results/analysis/final_conclusions.md`
- `docs/analysis/latest-benchmark-review.md`

## Which File To Cite

- `results/analysis/runtime_analysis.csv`
  - use for explaining whether the selected `N` truly hit the intended runtime window
- `results/analysis/granularity_analysis.csv`
  - use for load-balance interpretation beyond the raw per-rank CSV
- `results/analysis/speedup_analysis.csv`
  - use for identifying the recommended operating point and the first regression point
- `results/analysis/faiss_analysis.csv`
  - use for external-baseline gap classification and fairness discussion
- `results/analysis/benchmark_summary.json`
  - use for machine-readable summaries or follow-up automation
- `docs/analysis/latest-benchmark-review.md`
  - use as the main report-ready narrative artifact

## Notes

- The analysis layer is derived-only. It never rewrites the raw benchmark CSVs.
- If any correctness file contains a `FAIL`, the generated summary marks performance conclusions as `INVALID_UNTIL_CORRECTNESS_FIXED`.
- The analysis docs are English-only to stay aligned with the rest of the repository documentation.
