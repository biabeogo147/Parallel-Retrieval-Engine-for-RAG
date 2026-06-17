# Report Mapping

This file maps the generated benchmark-analysis artifacts to the report structure expected by the project.

## 1. Experimental Setup And Fairness Policy

Primary sources:

- `docs/development/data_pipeline_and_benchmarks.md`
- `results/analysis/benchmark_summary.json`
- `results/analysis/faiss_analysis.csv`

Use this section to explain:

- synthetic benchmark policy
- sequential baseline policy for speedup
- FAISS fairness policy where `faiss_total_time = faiss_compute_time`
- excluded costs such as dataset load, CSV writing, and text embedding generation

## 2. Runtime Selection And Chosen N

Primary sources:

- `results/runtime_by_N.csv`
- `results/benchmark_selection.env`
- `results/analysis/runtime_analysis.csv`

Use this section to explain:

- which `N` values were tested
- whether the chosen `N_SELECTED` actually hit the intended runtime target
- why the selected row was still used if no row entered the target window

## 3. Sequential-Vs-Parallel Correctness Conclusion

Primary sources:

- `results/correctness.csv`
- `results/analysis/benchmark_summary.json`
- `docs/analysis/latest-benchmark-review.md`

Use this section to explain:

- that correctness is gated before any performance conclusion
- how many queries passed
- the maximum observed score difference

## 4. Load Balancing / Granularity Conclusion

Primary sources:

- `results/granularity.csv`
- `results/granularity_summary.txt`
- `results/analysis/granularity_analysis.csv`

Use this section to explain:

- shard-size equality or mismatch
- compute and communication balance
- why a large relative idle-gap ratio may still coexist with tiny absolute skew

## 5. Speedup And Efficiency Conclusion

Primary sources:

- `results/speedup.csv`
- `results/analysis/speedup_analysis.csv`
- `docs/analysis/latest-benchmark-review.md`

Use this section to explain:

- best total speedup
- recommended operating point
- first worker count where total speedup regressed
- the role of communication overhead in limiting scaling

## 6. FAISS External Baseline Conclusion

Primary sources:

- `results/faiss/comparison.csv`
- `results/analysis/faiss_analysis.csv`
- `results/faiss/synthetic_correctness.csv`
- `results/faiss/squad_correctness.csv`

Use this section to explain:

- exact-match correctness against the sequential reference
- the measured runtime gap versus FAISS
- why FAISS remains an external realism baseline rather than the project implementation target

## 7. Final Conclusion And Future Direction

Primary sources:

- `results/analysis/benchmark_summary.json`
- `results/analysis/final_conclusions.md`
- `docs/analysis/latest-benchmark-review.md`

Use this section to summarize:

- whether the benchmark run is valid
- whether the current runtime scale is large enough
- what operating point is defensible
- what the next implementation phase should prioritize
