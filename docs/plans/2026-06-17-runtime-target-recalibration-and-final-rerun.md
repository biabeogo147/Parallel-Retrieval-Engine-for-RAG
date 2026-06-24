# Runtime Target Recalibration And Final Benchmark Rerun

## Objective

Implement the recalibration plan that:

- replaces the old `N`-only benchmark target selection with an explicit `N`-first / `Q`-fallback calibration policy
- decouples `N_SPEEDUP` from `2 * N_SELECTED`
- reruns the synthetic benchmark workflow on the calibrated profile
- reruns the FAISS comparison workflow if the current hardware can support it
- records the final benchmark conclusions and next-step direction in-repo

## Scope

This task covered:

- benchmark automation scripts
- calibration manifest semantics
- benchmark and analysis documentation
- benchmark smoke coverage
- the final calibrated synthetic rerun
- the completed final Phase 8 rerun

It did not change:

- the C++ retrieval core
- the binary dataset contract
- the sequential or MPI exact ordering rules

## Architecture Summary

The updated benchmark flow is:

1. `scripts/run_calibrate_target.sh`
   - sweep `N` at base `Q`
   - keep successful rows even if a larger `N` fails
   - fall back to a `Q` sweep when `N` alone cannot hit `120-180s`
   - choose `N_SPEEDUP` from explicit sequential probes
2. `scripts/run_correctness.sh`
3. `scripts/run_granularity.sh`
4. `scripts/run_speedup.sh`
5. plot generation and analysis

The manifest now records:

- `N_SELECTED`
- `N_SPEEDUP`
- `P_SELECTED`
- `D`
- `Q`
- `K`
- `EPSILON`
- `CALIBRATION_MODE`
- `N_MAX_FEASIBLE`

## Files Modified

### Benchmark automation and helpers

- `scripts/benchmark_common.sh`
- `scripts/benchmark_csv.py`
- `scripts/run_calibrate_target.sh`
- `scripts/run_select_N.sh`
- `scripts/run_all_experiments.sh`
- `scripts/run_correctness.sh`
- `scripts/run_granularity.sh`
- `scripts/run_speedup.sh`
- `scripts/run_faiss_comparison.sh`
- `scripts/analyze_benchmarks.py`
- `scripts/phase8_common.py`
- `scripts/faiss_compare.py`

### Tests

- `CMakeLists.txt`
- `tests/cmake/RunBenchmarkSelectNSmoke.cmake`
- `tests/cmake/RunBenchmarkCorrectnessSmoke.cmake`
- `tests/cmake/RunBenchmarkGranularitySmoke.cmake`
- `tests/cmake/RunBenchmarkSpeedupSmoke.cmake`
- `tests/cmake/RunBenchmarkAllExperimentsSmoke.cmake`
- `tests/cmake/RunFaissComparisonWorkflowSmoke.cmake`
- `tests/cmake/RunBenchmarkAnalysisSmoke.cmake`
- `tests/cmake/RunBenchmarkAnalysisInvalidCorrectnessSmoke.cmake`
- `tests/cmake/RunBenchmarkAnalysisMissingInputFail.cmake`
- `tests/cmake/RunBenchmarkCalibrateTargetNOnlySmoke.cmake`
- `tests/cmake/RunBenchmarkCalibrateTargetNPlusQSmoke.cmake`
- `tests/cmake/RunBenchmarkAnalysisCalibrationAwareSmoke.cmake`

### Canonical docs

- `docs/development/data_pipeline_and_benchmarks.md`
- `docs/development/developer_guide.md`
- `docs/development/source_guide.md`
- `docs/usage/benchmark-workflows.md`
- `docs/usage/results-csv-reference.md`
- `docs/analysis/README.md`
- `docs/analysis/latest-benchmark-review.md`

### Derived analysis artifacts

- `results/analysis/benchmark_summary.json`
- `results/analysis/final_conclusions.md`

## Acceptance Criteria And Outcome

### 1. Calibration semantics

Implemented.

Observed final manifest:

```text
N_SELECTED=10000000
N_SPEEDUP=4000000
P_SELECTED=10
D=384
Q=200
K=10
EPSILON=1e-5
CALIBRATION_MODE=N_PLUS_Q
N_MAX_FEASIBLE=10000000
```

Interpretation:

- `N`-only targeting was not feasible within the successful `N` sweep
- the calibrated runtime target was reached by holding `N = 10,000,000` and escalating `Q = 200`
- the speedup stage uses a separate synthetic size, `N_SPEEDUP = 4,000,000`

### 2. Synthetic correctness

Implemented and verified.

- `results/correctness.csv` is all `PASS`

### 3. Granularity

Implemented and verified.

- canonical output written to `results/granularity.csv`
- current verdict: `UNBALANCED`
- important nuance: the absolute idle times are very small, so the stronger bottleneck signal comes from the speedup table

### 4. Speedup

Implemented and verified.

Best current point:

- `P = 10`
- `total_speedup = 8.80647991`
- `compute_speedup = 8.95163351`

Regression point:

- `P = 20`
- `total_speedup = 5.07320297`
- `communication_time = 66.59557807s`

Conclusion:

- the next optimization direction should target communication/orchestration cost, not larger synthetic `N`

### 5. Final Phase 8 rerun

Implemented and verified.

Observed constraint:

- the synthetic FAISS exact-flat run at `N_SELECTED = 10,000,000` hit a real WSL memory ceiling
- `dmesg` confirmed the FAISS Python process was OOM-killed at about `15.0 GiB` anonymous RSS
- the exact-flat index itself is close enough to the current WSL memory limit that a WSL-only FAISS rerun is not reliable at this synthetic scale

Mitigation implemented:

- `scripts/faiss_compare.py` now batch-loads vectors from `memmap` into `IndexFlatIP`
- a small smoke run passed after that refactor

Final execution strategy:

- keep the retriever reference path on canonical Ubuntu WSL
- run the FAISS Python baseline host-side on the same `D:\...` binary files, where the memory ceiling is higher than the WSL default cap
- keep the output contracts unchanged

Observed final Phase 8 results:

- `results/faiss/synthetic_correctness.csv` is all `PASS`
- `results/faiss/squad_correctness.csv` is all `PASS`
- `results/faiss/comparison.csv` was generated successfully
- synthetic comparison result:
  - `total_ratio = 1.15843120`
  - `gap_class = COMPETITIVE`
- SQuAD comparison result:
  - `total_ratio = 5.16494404`
  - `gap_class = LARGE_GAP`

## Verification Commands

### Repository test suite

Executed successfully before the final rerun:

```bash
ctest --test-dir build/debug --output-on-failure
```

Observed result:

- `40/40` tests passed

### Calibration

Executed successfully:

```bash
bash ./scripts/run_calibrate_target.sh
```

### Correctness

Executed successfully:

```bash
bash ./scripts/run_correctness.sh
```

Observed result:

- `All queries PASS`

### Granularity

Executed successfully:

```bash
bash ./scripts/run_granularity.sh
```

### Speedup

Executed successfully:

```bash
bash ./scripts/run_speedup.sh
```

### Plot generation

Executed successfully using the repo-local virtual environment:

```bash
./.venv/bin/python ./scripts/plot_results.py --results-dir results
```

### Phase 8

Executed successfully as a hybrid rerun:

```bash
python faiss_compare.py ... synthetic ...
python faiss_compare.py ... squad_minilm ...
verify_results ... synthetic ...
verify_results ... squad_minilm ...
python benchmark_csv.py build-faiss-comparison ...
python analyze_benchmarks.py ...
```

Observed result:

- `results/faiss/synthetic_topk.csv` generated
- `results/faiss/synthetic_run_metrics.csv` generated
- `results/faiss/synthetic_correctness.csv` generated with all `PASS`
- `results/faiss/squad_topk.csv` generated
- `results/faiss/squad_run_metrics.csv` generated
- `results/faiss/squad_correctness.csv` generated with all `PASS`
- `results/faiss/comparison.csv` generated
- `results/analysis/*` regenerated successfully
- `docs/analysis/latest-benchmark-review.md` regenerated successfully

## Deviation From The Original Rerun Sequence

The original execution plan said to:

1. run `run_calibrate_target.sh`
2. then run `run_all_experiments.sh`

In practice, `run_calibrate_target.sh` took about `89` minutes on the current machine because it executed the full `N` sweep, the fallback `Q` sweep, and the sequential speedup probes at large synthetic scales.

To avoid paying that same calibration cost a second time immediately afterward, the final synthetic rerun was executed stage-by-stage with the already generated complete manifest:

1. `run_correctness.sh`
2. `run_granularity.sh`
3. `run_speedup.sh`
4. `plot_results.py`

This preserved the calibrated outputs without rerunning the 89-minute stage-1 sweep again.

The final Phase 8 rerun also deviated from the canonical WSL-only expectation for FAISS execution:

1. WSL remained the canonical environment for:
   - `sequential_retriever`
   - `parallel_retriever`
   - `verify_results`
   - `ctest`
2. The FAISS Python process itself was run host-side against the same repo-local binary files because:
   - the WSL memory cap is `15 GiB`
   - `IndexFlatIP` at `N_SELECTED = 10,000,000`, `D = 384` is too close to that limit

This was an execution workaround for the final rerun, not a change to the project’s canonical WSL-first design.

## Assumptions And Defaults

- Canonical environment remains `WSL2 + Ubuntu 24.04 + OpenMPI`
- Current machine facts used during the rerun:
  - about `15 GiB` usable WSL memory
  - `10` physical CPU cores
- Host-side Python was available for the final FAISS rerun through the local desktop runtime bundle
- The `120-180s` runtime window remained fixed
- The calibrated result proves that this machine now needs `N_PLUS_Q` rather than further `N`-only expansion

## Next Actions

1. Keep the current calibrated synthetic benchmark conclusions in the report:
   - `CALIBRATION_MODE = N_PLUS_Q`
   - `N_SELECTED = 10,000,000`
   - `Q = 200`
   - recommended operating point `P = 10`
2. Move optimization effort toward:
   - communication reduction
   - orchestration changes
   - possibly non-blocking MPI in later work
3. Decide whether Phase 8 synthetic FAISS should be formalized as:
   - a higher-memory WSL path, or
   - an explicitly documented host-side baseline fallback for machines where WSL exact-flat memory is too tight
4. Consider refining the report language around granularity:
   - keep `BALANCED_BUT_IDLE_RATIO_SENSITIVE`
   - avoid overclaiming imbalance when absolute idle skew is tiny
5. Re-run only if the benchmark policy changes materially:

```bash
ctest --test-dir build/debug --output-on-failure
bash ./scripts/run_calibrate_target.sh
bash ./scripts/run_correctness.sh
bash ./scripts/run_granularity.sh
bash ./scripts/run_speedup.sh
python3 ./scripts/analyze_benchmarks.py ...
```
