# Benchmark Workflows

This guide covers both:

- the current synthetic benchmark automation layer
- the separate Phase 8 FAISS external-baseline workflow

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
| `BENCH_FAISS_RESULTS_DIR` | output directory for Phase 8 FAISS artifacts | `$BENCH_RESULTS_DIR/faiss` |
| `BENCH_SQUAD_INPUT_DIR` | SQuAD parquet input root for Phase 8 real-corpus conversion | `/mnt/e/data/squad/plain_text` |
| `BENCH_SQUAD_OUTPUT_DIR` | converted real-corpus output directory for Phase 8 | `$repo_root/.cache/real_corpora/squad_minilm` |
| `BENCH_SQUAD_MODEL` | embedding model used by `prepare_squad_minilm.py` | `sentence-transformers/all-MiniLM-L6-v2` |
| `BENCH_SQUAD_QUERIES_LIMIT` | number of validation questions kept for the current real-corpus run | `100` |

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
- If you also need the Phase 8 external baseline, run `bash ./scripts/run_faiss_comparison.sh` afterward.
- After the raw benchmark and FAISS outputs exist, run the analysis layer described in section 10.

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

## 7. Phase 8 FAISS Comparison Workflow

This workflow is separate from `run_all_experiments.sh`. The synthetic benchmark pipeline remains the canonical speedup and granularity path, while Phase 8 adds an external-baseline comparison path.

**Prerequisites**

- Debug binaries already exist.
- `python3` is available inside WSL.
- For the real-corpus path, `/mnt/e/data/squad/plain_text` exists or `BENCH_SQUAD_OUTPUT_DIR` already contains prebuilt `vectors.bin` and `queries.bin`.
- On the first real-corpus run, the script may need network access to install Python packages and download the embedding model.

**Bash**

```bash
bash ./scripts/run_faiss_comparison.sh
```

**Expected artifacts**

- `results/faiss/synthetic_topk.csv`
- `results/faiss/synthetic_run_metrics.csv`
- `results/faiss/synthetic_correctness.csv`
- `results/faiss/squad_topk.csv`
- `results/faiss/squad_run_metrics.csv`
- `results/faiss/squad_correctness.csv`
- `results/faiss/comparison.csv`

**What success looks like**

- The script prints `Wrote ...` lines for all seven Phase 8 artifacts.
- `results/faiss/synthetic_correctness.csv` is all `PASS`.
- `results/faiss/squad_correctness.csv` is all `PASS`.
- `results/faiss/comparison.csv` contains two data rows:
  - `synthetic`
  - `squad_minilm`

**Next step**

- Open [results-csv-reference.md](results-csv-reference.md) and read the `results/faiss/*.csv` sections before writing report notes or sharing benchmark conclusions.
- Then run the benchmark-analysis command in section 10 so the conclusions are regenerated from the final CSV set.

## 8. Direct Real-Corpus Preparation Command

Use this when you want to prepare the current maintained SQuAD + MiniLM dataset explicitly instead of letting `run_faiss_comparison.sh` do it lazily.

**Prerequisites**

- `/mnt/e/data/squad/plain_text` exists.
- `python3` is available.
- The first run may need network access for Python dependencies and the embedding model.

**Bash**

```bash
python3 ./scripts/prepare_squad_minilm.py \
  --input-dir /mnt/e/data/squad/plain_text \
  --output-dir .cache/real_corpora/squad_minilm \
  --model sentence-transformers/all-MiniLM-L6-v2 \
  --queries-limit 100
```

**Expected artifacts**

- `.cache/real_corpora/squad_minilm/vectors.bin`
- `.cache/real_corpora/squad_minilm/queries.bin`
- `.cache/real_corpora/squad_minilm/metadata.tsv`

**What success looks like**

- The script prints `Wrote .../vectors.bin`, `Wrote .../queries.bin`, and `Wrote .../metadata.tsv`.
- It also prints the number of contexts, queries, and the embedding dimension.

**Next step**

- Run `bash ./scripts/run_faiss_comparison.sh` to compare sequential, parallel, and FAISS on both synthetic data and the prepared real corpus.

## 9. Reduced Or Customized Phase 8 Run

Use this pattern when you want to redirect Phase 8 outputs into a separate folder or reuse a custom prebuilt real-corpus directory.

**Prerequisites**

- Debug binaries already exist.
- If `BENCH_SQUAD_OUTPUT_DIR` already contains `vectors.bin` and `queries.bin`, the script will reuse them and skip embedding generation.

**Bash**

```bash
BENCH_D=8 \
BENCH_Q=5 \
BENCH_TOPK=3 \
BENCH_N_CANDIDATES="64" \
BENCH_P_SELECTED=4 \
BENCH_P_LIST="2 4" \
BENCH_RESULTS_DIR=results/faiss-smoke \
BENCH_FAISS_RESULTS_DIR=results/faiss-smoke/faiss \
BENCH_SCRATCH_DIR=.cache/benchmarks-faiss-smoke \
BENCH_SQUAD_OUTPUT_DIR=.cache/real_corpora/squad_minilm_smoke \
bash ./scripts/run_faiss_comparison.sh
```

**Expected artifacts**

- `results/faiss-smoke/faiss/synthetic_topk.csv`
- `results/faiss-smoke/faiss/synthetic_run_metrics.csv`
- `results/faiss-smoke/faiss/synthetic_correctness.csv`
- `results/faiss-smoke/faiss/squad_topk.csv`
- `results/faiss-smoke/faiss/squad_run_metrics.csv`
- `results/faiss-smoke/faiss/squad_correctness.csv`
- `results/faiss-smoke/faiss/comparison.csv`

**What success looks like**

- The custom Phase 8 outputs appear under `results/faiss-smoke/faiss/`.
- The default `results/faiss/` directory is left untouched.

**Next step**

- Compare the custom output tables with the default profile, again using [results-csv-reference.md](results-csv-reference.md) to interpret the schemas.

## 10. Analyze The Final Benchmark Outputs

Use this step after:

- `bash ./scripts/run_all_experiments.sh`
- `bash ./scripts/run_faiss_comparison.sh`

so the repo also generates report-ready conclusions from the final CSV set instead of leaving interpretation as a manual step.

**Prerequisites**

- `results/runtime_by_N.csv` already exists.
- `results/correctness.csv` already exists.
- `results/granularity.csv` already exists.
- `results/speedup.csv` already exists.
- `results/faiss/comparison.csv` already exists.
- `results/faiss/synthetic_correctness.csv` and `results/faiss/squad_correctness.csv` already exist.

**Bash**

```bash
python3 ./scripts/analyze_benchmarks.py \
  --results-dir results \
  --output-dir results/analysis \
  --docs-output docs/analysis/latest-benchmark-review.md
```

**Expected artifacts**

- `results/analysis/runtime_analysis.csv`
- `results/analysis/granularity_analysis.csv`
- `results/analysis/speedup_analysis.csv`
- `results/analysis/faiss_analysis.csv`
- `results/analysis/benchmark_summary.json`
- `results/analysis/final_conclusions.md`
- `docs/analysis/latest-benchmark-review.md`

**What success looks like**

- The script prints `Wrote ...` lines for all seven outputs.
- `benchmark_summary.json` includes either:
  - `VALID`
  - `INVALID_UNTIL_CORRECTNESS_FIXED`
- `docs/analysis/latest-benchmark-review.md` contains all 8 conclusion sections, ready to adapt into the report.

**Next step**

- Read [../analysis/README.md](../analysis/README.md) and [../analysis/report_mapping.md](../analysis/report_mapping.md) to map the generated findings into the final thesis/report structure.

## Notes

- `run_all_experiments.sh` is the only script that bootstraps the plotting virtual environment and generates figures.
- The stage scripts reuse or generate synthetic datasets under the benchmark scratch directory automatically.
- If you change `BENCH_RESULTS_DIR` or `BENCH_SCRATCH_DIR`, remember to inspect or clean those custom paths later instead of the defaults.
- `run_all_experiments.sh` remains synthetic-only by design.
- `run_faiss_comparison.sh` reuses the same `.venv/` directory for FAISS and real-corpus conversion dependencies.
- If `BENCH_SQUAD_OUTPUT_DIR` already contains binary outputs, `run_faiss_comparison.sh` skips the expensive embedding-preparation step and reuses them directly.
