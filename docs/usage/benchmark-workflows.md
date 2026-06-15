# Benchmark Workflows

This guide covers the current synthetic benchmark automation layer.

All commands below assume:

```bash
cd ~/work/Parallel-Retrieval-Engine-for-RAG
```

## Shared Prerequisites

Before using any benchmark script:

- `build/debug/` must already exist.
- The debug binaries must already be built.
- `python3` and `mpirun` must be available in WSL.

The fastest prerequisite path is:

```bash
./scripts/configure_debug.sh
cmake --build build/debug
ctest --test-dir build/debug --output-on-failure
```

## Benchmark Environment Variables

These are the current public script knobs exposed by `scripts/benchmark_common.sh`.

| Variable | Meaning | Current default |
| --- | --- | --- |
| `BENCH_BUILD_DIR` | build tree used by the benchmark scripts | `$repo_root/build/debug` |
| `BENCH_RESULTS_DIR` | final benchmark output directory | `$repo_root/results` |
| `BENCH_SCRATCH_DIR` | scratch datasets and intermediate CSVs | `$repo_root/.cache/benchmarks` |
| `BENCH_D` | vector dimension | `384` |
| `BENCH_Q` | query count | `100` |
| `BENCH_TOPK` | retrieval top-k | `10` |
| `BENCH_EPSILON` | correctness epsilon | `1e-5` |
| `BENCH_N_CANDIDATES` | candidate `N` values for selection | `100000 200000 500000 1000000 2000000` |
| `BENCH_P_SELECTED` | canonical process count for selection, correctness, and granularity | detected physical core count |
| `BENCH_P_LIST` | process counts used for the speedup sweep | generated as `1 2 4 ... X 2X` |
| `BENCH_PLOT_VENV_DIR` | plotting virtual environment path | `$repo_root/.venv` |
| `BENCH_PYTHON_STDLIB` | Python interpreter used for CSV helper scripts | `python3` |

## `benchmark_selection.env`

`run_select_N.sh` writes a manifest at:

```text
results/benchmark_selection.env
```

That file currently stores:

- `N_SELECTED`
- `N_SPEEDUP`
- `P_SELECTED`
- `D`
- `Q`
- `K`
- `EPSILON`

The later stage scripts load this file automatically. In the normal flow, do not edit it by hand.

For a detailed explanation of the CSV files produced by these stages, including every output column, see [results-csv-reference.md](results-csv-reference.md).

## 1. Default Full Benchmark Run

**Prerequisites**

- Debug build and tests already pass.

**Bash**

```bash
bash ./scripts/run_all_experiments.sh
```

**Expected artifacts**

- `results/runtime_by_N.csv`
- `results/benchmark_selection.env`
- `results/sequential_topk.csv`
- `results/parallel_topk.csv`
- `results/correctness.csv`
- `results/granularity.csv`
- `results/granularity_summary.txt`
- `results/speedup.csv`
- `results/figures/runtime_by_N.png`
- `results/figures/granularity.png`
- `results/figures/speedup_runtime.png`
- `results/figures/speedup_curves.png`

**What success looks like**

- The script prints `Benchmark automation completed.`
- The final CSV and PNG files appear under `results/`.

**Next step**

- Inspect the generated CSVs with [results-csv-reference.md](results-csv-reference.md), or re-run with a reduced custom profile.

## 2. Stage: Runtime-By-N Selection

**Prerequisites**

- Debug binaries already exist.

**Bash**

```bash
bash ./scripts/run_select_N.sh
```

**Expected artifacts**

- `results/runtime_by_N.csv`
- `results/benchmark_selection.env`

**What success looks like**

- The script prints:
  - `Wrote .../runtime_by_N.csv`
  - `Wrote .../benchmark_selection.env`

**Next step**

- Run correctness or granularity on the selected `N`.

## 3. Stage: Correctness Workflow

**Prerequisites**

- `results/benchmark_selection.env` already exists from `run_select_N.sh`.

**Bash**

```bash
bash ./scripts/run_correctness.sh
```

**Expected artifacts**

- `results/sequential_topk.csv`
- `results/parallel_topk.csv`
- `results/correctness.csv`

**What success looks like**

- `verify_results` prints `All queries PASS`.
- The script prints `Wrote .../correctness.csv`.

**Next step**

- Run granularity or speedup.

## 4. Stage: Granularity Workflow

**Prerequisites**

- `results/benchmark_selection.env` already exists from `run_select_N.sh`.

**Bash**

```bash
bash ./scripts/run_granularity.sh
```

**Expected artifacts**

- `results/granularity.csv`
- `results/granularity_summary.txt`

**What success looks like**

- The script prints the contents of `granularity_summary.txt`.
- The summary may say either `BALANCED` or `UNBALANCED`; `UNBALANCED` is a valid measured result, not a script failure.

**Next step**

- Run the speedup stage or the full plot pipeline.

## 5. Stage: Speedup Workflow

**Prerequisites**

- `results/benchmark_selection.env` already exists from `run_select_N.sh`.

**Bash**

```bash
bash ./scripts/run_speedup.sh
```

**Expected artifacts**

- `results/speedup.csv`

**What success looks like**

- The script prints `Wrote .../speedup.csv`.
- The CSV header is:
  - `N,D,Q,k,P,compute_time,communication_time,total_time,compute_speedup,total_speedup,compute_efficiency,total_efficiency`

**Next step**

- Run `run_all_experiments.sh` if you still need the generated figures.

## 6. Reduced Or Customized Benchmark Run

Use this pattern when you want a faster smoke-sized benchmark run or you want to isolate results from the default `results/` directory.

**Prerequisites**

- Debug binaries already exist.

**Bash**

```bash
BENCH_D=8 \
BENCH_Q=5 \
BENCH_TOPK=3 \
BENCH_N_CANDIDATES="64 128" \
BENCH_P_SELECTED=4 \
BENCH_P_LIST="2 4" \
BENCH_RESULTS_DIR=results/smoke \
BENCH_SCRATCH_DIR=.cache/benchmarks-smoke \
bash ./scripts/run_all_experiments.sh
```

**Expected artifacts**

- `results/smoke/runtime_by_N.csv`
- `results/smoke/benchmark_selection.env`
- `results/smoke/correctness.csv`
- `results/smoke/granularity.csv`
- `results/smoke/speedup.csv`
- `results/smoke/figures/*.png`

**What success looks like**

- The run finishes faster than the default profile.
- The default `results/` directory is left untouched except for any existing files from earlier runs.

**Next step**

- Compare the smoke profile outputs with the default profile outputs, using [results-csv-reference.md](results-csv-reference.md) to interpret each CSV schema.

## Notes

- `run_all_experiments.sh` is the only script that bootstraps the plotting virtual environment and generates figures.
- The stage scripts reuse or generate synthetic datasets under the benchmark scratch directory automatically.
- If you change `BENCH_RESULTS_DIR` or `BENCH_SCRATCH_DIR`, remember to inspect or clean those custom paths later instead of the defaults.
