# Results CSV Reference

This guide explains the CSV files written under `results/` by the current retrieval, benchmark, and Phase 8 FAISS comparison pipeline.

Use this document when you need to answer questions like:

- What does each CSV file mean?
- What does each column mean?
- Which rows are per-query, per-rank, or per-run?
- How should I interpret the values in a report or benchmark note?

The same schemas also apply to reduced or custom benchmark runs under directories such as `results/smoke/`.

## Scope

This guide covers the current CSV outputs:

- `sequential_topk.csv`
- `parallel_topk.csv`
- `parallel_metrics.csv`
- `correctness.csv`
- `sequential_run_metrics.csv`
- `parallel_run_metrics.csv`
- `runtime_by_N.csv`
- `granularity.csv`
- `speedup.csv`
- `results/faiss/synthetic_topk.csv`
- `results/faiss/synthetic_run_metrics.csv`
- `results/faiss/synthetic_correctness.csv`
- `results/faiss/squad_topk.csv`
- `results/faiss/squad_run_metrics.csv`
- `results/faiss/squad_correctness.csv`
- `results/faiss/comparison.csv`

Related non-CSV outputs such as `benchmark_selection.env`, `granularity_summary.txt`, and `results/figures/*.png` are mentioned briefly at the end, but the main focus here is the CSV layer.

## Shared Conventions Across Result CSVs

Before reading the individual files, keep these project-wide conventions in mind.

### 1. IDs are row-index based

The current binary vector datasets do not store explicit external IDs. Because of that:

- `query_id` means the zero-based row index in the query dataset
- `memory_id` means the zero-based row index in the memory dataset

This rule is consistent across sequential output, parallel output, and correctness checking.

### 2. Times are measured in seconds

Timing columns such as `compute_time`, `communication_time`, and `total_time` are stored as floating-point seconds, not milliseconds.

Examples:

- `0.25000000` means one quarter of a second
- `14.34574531` means a little over fourteen seconds

### 3. Scores are floating-point similarity values

The retrievers currently operate on normalized vectors and exact dot products. Because of that:

- higher `score` means a better match
- equal scores are broken deterministically by `memory_id`
- scores are written with fixed decimal formatting

### 4. Row order is meaningful

Some files are sorted because the order itself carries meaning:

- top-k files are ordered by query block and rank position
- correctness files are ordered by increasing `query_id`
- speedup rows are ordered by increasing `P`

### 5. `results/smoke/` uses the same schemas

If you run the benchmark scripts with a custom `BENCH_RESULTS_DIR`, the filenames may move, but the CSV headers and column meanings do not change.

## Quick Map Of The Current CSV Files

| File | Produced by | Row granularity | Main purpose |
| --- | --- | --- | --- |
| `sequential_topk.csv` | `sequential_retriever` | one row per retrieved candidate | exact sequential retrieval output |
| `parallel_topk.csv` | `parallel_retriever` | one row per retrieved candidate | exact MPI retrieval output |
| `results/faiss/*_topk.csv` | `faiss_compare.py` | one row per retrieved candidate | exact FAISS external-baseline output |
| `parallel_metrics.csv` | `parallel_retriever --metrics` | one row per MPI rank | detailed per-rank timing and load-balance data |
| `correctness.csv` | `verify_results` | one row per query | sequential-versus-parallel correctness verdict |
| `results/faiss/*_correctness.csv` | `verify_results` | one row per query | sequential-versus-FAISS correctness verdict |
| `sequential_run_metrics.csv` | `sequential_retriever --run-metrics` | one row per run | benchmark summary for one sequential run |
| `parallel_run_metrics.csv` | `parallel_retriever --run-metrics` | one row per run | benchmark summary for one parallel run |
| `runtime_by_N.csv` | `run_calibrate_target.sh` | one row per tested `N` value from the initial `N` sweep | runtime sweep used to choose `N_SELECTED` or trigger fallback `Q` calibration |
| `granularity.csv` | `run_granularity.sh` | one row per MPI rank | canonical per-rank benchmark metrics artifact |
| `speedup.csv` | `run_speedup.sh` | one row per process count `P` | final speedup and efficiency table |
| `results/faiss/*_run_metrics.csv` | `faiss_compare.py` | one row per run | Phase 8 FAISS run-summary table |
| `results/faiss/comparison.csv` | `benchmark_csv.py build-faiss-comparison` | one row per dataset | final parallel-versus-FAISS comparison table |

## 1. `sequential_topk.csv`, `parallel_topk.csv`, And `results/faiss/*_topk.csv`

These files share the same schema and the same interpretation rules.

### What these files represent

Each file records the final ranked retrieval output:

- one query contributes `k` rows
- each row is one retrieved memory candidate
- the rows inside a query block are already sorted from best match to worst match within the top-k window

The exact header is:

```text
query_id,rank_position,memory_id,score
```

Example row:

```text
0,1,0,0.99999988
```

That example means:

- query row `0`
- best-ranked result for that query
- memory row `0`
- similarity score about `0.99999988`

### Column-by-column explanation

#### `query_id`

**Type**

- integer

**Meaning**

- zero-based row index of the query vector inside the query dataset

**How it is assigned**

- if the query dataset has `Q` rows, valid `query_id` values run from `0` to `Q - 1`

**How to read it**

- all rows with the same `query_id` belong to the same query
- you should read those rows as one top-k block

**Important detail**

- `query_id` is not a text corpus identifier and is not currently loaded from metadata
- it is purely the query row position in the binary file

#### `rank_position`

**Type**

- integer

**Meaning**

- one-based rank inside that query’s top-k result list

**How it is assigned**

- `1` means the best candidate for that query
- `2` means the second-best candidate
- and so on until `k`

**How to read it**

- lower `rank_position` means better retrieval rank
- inside one `query_id` block, `rank_position` should be contiguous from `1` through `k`

**Important detail**

- this column is one-based by design, even though `query_id` and `memory_id` are zero-based
- that makes the ranking easier to read in reports and tables

#### `memory_id`

**Type**

- integer

**Meaning**

- zero-based row index of the retrieved memory vector inside the memory dataset

**How it is assigned**

- if the memory dataset has `N` rows, valid values run from `0` to `N - 1`

**How to read it**

- it identifies which memory row was retrieved
- the same `memory_id` may appear for multiple different queries

**Important detail**

- like `query_id`, this is currently a row-position identifier, not an external corpus key

#### `score`

**Type**

- floating-point number

**Meaning**

- exact similarity score between the current query vector and the retrieved memory vector

**Current scoring interpretation**

- the current system uses normalized vectors and exact dot products
- because the vectors are normalized, the score is effectively cosine-like similarity

**How to read it**

- larger values are better
- the top row for a query should have the largest `score` in that query block

**Formatting**

- written in fixed decimal form
- currently printed with eight digits after the decimal point

**Important detail**

- score ties are broken deterministically by `memory_id`
- if two candidates have identical `score`, the smaller `memory_id` ranks ahead

### Row-level invariants

For a valid top-k CSV:

- each `query_id` appears exactly `k` times
- the rows for one query should form a complete rank block
- `rank_position` should be contiguous from `1` to `k`
- the rows should already be in final output order

### When to use each file

- `sequential_topk.csv`
  - use as the exact single-process reference output
- `parallel_topk.csv`
  - use as the exact MPI output to compare against the sequential reference
- `results/faiss/synthetic_topk.csv`
  - use as the exact FAISS output for the synthetic binary dataset
- `results/faiss/squad_topk.csv`
  - use as the exact FAISS output for the current `SQuAD + MiniLM` real-corpus binary dataset

## 2. `parallel_metrics.csv` And `granularity.csv`

These two files also share the same schema.

### What these files represent

They are per-rank timing tables for one parallel retrieval invocation.

Use them when you want to inspect:

- how many memory rows each rank processed
- how much time each rank spent computing
- how much time each rank spent in MPI communication
- how balanced or unbalanced the run was

The exact header is:

```text
rank,local_N,compute_time,communication_time,active_time,global_total_time,idle_time
```

Example row:

```text
1,16,0.00014817,0.00006172,0.00020989,0.00021355,0.00000366
```

That means rank `1` owned `16` memory rows, spent around `0.00014817` seconds computing, around `0.00006172` seconds communicating, and had very little idle time relative to the global run duration.

### Column-by-column explanation

#### `rank`

**Type**

- integer

**Meaning**

- MPI rank number for the current process row

**How to read it**

- rank `0` is the root rank
- rank numbers usually run from `0` through `P - 1`

**Important detail**

- rank `0` has extra work in the current design because it also merges gathered candidates and writes final outputs

#### `local_N`

**Type**

- integer

**Meaning**

- number of memory vectors assigned to that rank by the shard formula

**How to read it**

- this tells you the data volume owned by that rank
- if the workload is perfectly even and `N` divides `P`, all rows should have the same `local_N`
- if `N` does not divide `P`, some ranks will have one more row than others

**Important detail**

- summing `local_N` across all rows should reconstruct the global `N`

#### `compute_time`

**Type**

- floating-point seconds

**Meaning**

- time that rank spent doing retrieval computation during the benchmark window

**What is included**

- local exact search over the shard
- on rank `0`, the global merge cost is also included

**How to read it**

- higher values mean more local compute work
- rank `0` may be slightly larger than other ranks because of merge overhead

#### `communication_time`

**Type**

- floating-point seconds

**Meaning**

- time that rank spent in MPI communication during the retrieval loop

**What is included**

- query broadcasts
- candidate gathers

**How to read it**

- higher values mean that rank spent more time waiting in or participating in communication calls

#### `active_time`

**Type**

- floating-point seconds

**Meaning**

- total time that rank spent doing tracked useful work during the measured retrieval loop

**Formula**

```text
active_time = compute_time + communication_time
```

**How to read it**

- this is the non-idle portion of the rank’s measured runtime

#### `global_total_time`

**Type**

- floating-point seconds

**Meaning**

- overall retrieval-loop duration for the parallel invocation

**How it is formed**

- it is the maximum wall time across ranks for the measured retrieval loop

**How to read it**

- this is the duration that matters for end-to-end parallel runtime
- it acts as the ceiling that each rank’s `active_time` is measured against

**Important detail**

- within one file, `global_total_time` should be the same for every row because it is a shared run-level value copied into each rank row

#### `idle_time`

**Type**

- floating-point seconds

**Meaning**

- portion of the global run time during which this rank was not accounted for by tracked compute or communication work

**Formula**

```text
idle_time = global_total_time - active_time
```

**How to read it**

- larger `idle_time` means more waiting relative to the overall run
- if some ranks have much larger `idle_time` than others, the run is likely imbalanced or communication-heavy

### How to interpret the whole file

Use these comparisons:

- compare `local_N`
  - shows whether the shard sizes are balanced
- compare `compute_time`
  - shows whether some ranks did meaningfully more compute work
- compare `communication_time`
  - shows whether communication cost dominated certain ranks
- compare `idle_time`
  - shows whether some ranks spent much more time waiting than others

### Which file to use when

- `parallel_metrics.csv`
  - manual or ad hoc per-rank inspection after a direct MPI run
- `granularity.csv`
  - the canonical benchmark artifact used by `run_granularity.sh`

## 3. `correctness.csv` And `results/faiss/*_correctness.csv`

### What this file represents

These files summarize whether another top-k output matches the sequential reference for each query.

It is produced by `verify_results`.

The exact header is:

```text
query_id,k,matched,matched_ids,max_score_diff,status
```

Each row corresponds to one query, not one retrieved candidate.

Which concrete comparison is being reported depends on the workflow:

- `correctness.csv`
  - sequential versus parallel
- `results/faiss/synthetic_correctness.csv`
  - sequential versus FAISS on the selected synthetic dataset
- `results/faiss/squad_correctness.csv`
  - sequential versus FAISS on the current `SQuAD + MiniLM` real-corpus dataset

### Column-by-column explanation

#### `query_id`

**Type**

- integer

**Meaning**

- zero-based query row index being checked

**How to read it**

- each row reports the correctness verdict for one query’s entire top-k block

#### `k`

**Type**

- integer

**Meaning**

- expected number of ranked rows for that query in each input top-k CSV

**How to read it**

- this tells you how many candidate positions were compared for the query

**Important detail**

- `k` should be the same across all rows in one correctness run

#### `matched`

**Type**

- boolean-like text

**Meaning**

- whether the query passed the correctness check

**Pass condition**

- `matched_ids == k`
- and `max_score_diff <= epsilon`

**How to read it**

- `true` means the query passed
- `false` means at least one part of the check failed

#### `matched_ids`

**Type**

- integer

**Meaning**

- number of rank positions where the sequential reference and the comparison output have the same `memory_id`

**How to read it**

- this is a position-by-position match count
- it is not an unordered set overlap

**Important detail**

- if the right IDs appear but in the wrong rank positions, `matched_ids` will still drop

#### `max_score_diff`

**Type**

- floating-point number

**Meaning**

- largest absolute score difference between aligned sequential rows and comparison rows for that query

**Formula**

```text
max_score_diff = max(abs(seq.score - par.score))
```

**How to read it**

- smaller is better
- `0` means the aligned scores matched exactly at the printed precision and internal compare path

**Important detail**

- this value is checked against the chosen `epsilon`

#### `status`

**Type**

- text

**Meaning**

- human-readable verdict string

**Current values**

- `PASS`
- `FAIL`

**How to read it**

- it mirrors the logical outcome in a report-friendly form

### How to interpret the whole file

- if every row is `PASS`, the overall comparison is correct
- if one or more rows are `FAIL`, inspect:
  - `matched_ids`
  - `max_score_diff`
  - the underlying sequential top-k CSV
  - the corresponding comparison top-k CSV

## 4. `sequential_run_metrics.csv`, `parallel_run_metrics.csv`, And `runtime_by_N.csv`

These files share the same core schema:

```text
N,D,Q,k,P,compute_time,communication_time,total_time
```

### What these files represent

They are run-summary tables, not candidate tables and not per-rank tables.

Use them when you need one compact benchmark row describing a full invocation.

### File-by-file meaning

#### `sequential_run_metrics.csv`

- produced by `sequential_retriever --run-metrics`
- usually contains one row
- that row is the benchmark summary for one sequential run

#### `parallel_run_metrics.csv`

- produced by `parallel_retriever --run-metrics`
- usually contains one row
- that row is the benchmark summary for one parallel run

#### `runtime_by_N.csv`

- produced by `run_calibrate_target.sh`
- contains multiple rows
- each row is a parallel benchmark summary for one tested memory size `N`
- this file records only the initial `N` sweep; if the final manifest uses `CALIBRATION_MODE=N_PLUS_Q`, the selected runtime target was reached later by increasing `Q`, not by adding extra rows here

### Column-by-column explanation

#### `N`

**Type**

- integer

**Meaning**

- number of memory vectors used in the run

**How to read it**

- larger `N` means a larger memory database

#### `D`

**Type**

- integer

**Meaning**

- vector dimension used in the run

**How to read it**

- this is usually fixed across a benchmark campaign

#### `Q`

**Type**

- integer

**Meaning**

- number of query vectors processed in the run

**How to read it**

- larger `Q` means more query work per invocation

#### `k`

**Type**

- integer

**Meaning**

- requested top-k value for the retrieval run

**How to read it**

- this is the retrieval depth, not a dataset size

#### `P`

**Type**

- integer

**Meaning**

- process count used for the run

**How to read it**

- `P = 1` for the sequential baseline row
- `P > 1` for the MPI runs

#### `compute_time`

**Type**

- floating-point seconds

**Meaning**

- measured retrieval-kernel compute time for the run summary

**Sequential summary rule**

- it is the measured exact local-search window

**Parallel summary rule**

- it is the maximum `compute_time` across ranks for that run

**How to read it**

- use it when you want to compare compute-only scaling rather than total runtime scaling

#### `communication_time`

**Type**

- floating-point seconds

**Meaning**

- measured MPI communication time in the run summary

**Sequential summary rule**

- always `0`

**Parallel summary rule**

- maximum `communication_time` across ranks

**How to read it**

- higher values indicate more time spent in MPI communication

#### `total_time`

**Type**

- floating-point seconds

**Meaning**

- benchmark timing window used for fair runtime and speedup comparison

**Important boundary**

- this timing window does not include dataset load
- it also does not include CSV writing

**Sequential summary rule**

- equals the measured sequential retrieval window

**Parallel summary rule**

- equals the global parallel retrieval-loop time

**How to read it**

- this is the main number to use for end-to-end benchmark comparisons

### How to interpret each file

#### `sequential_run_metrics.csv`

Use this as the baseline row when you want:

- a fair `P = 1` denominator for speedup
- the exact sequential timing reference

#### `parallel_run_metrics.csv`

Use this when you want:

- one compact summary row for a single MPI run
- a bridge between detailed per-rank data and high-level benchmark tables

#### `runtime_by_N.csv`

Use this when you want:

- to see how runtime changes as `N` grows
- to choose `N_SELECTED` for the later benchmark stages

## 5. `speedup.csv`

### What this file represents

This is the final benchmark comparison table across process counts.

It extends the run-summary schema with derived speedup and efficiency columns.

The exact header is:

```text
N,D,Q,k,P,compute_time,communication_time,total_time,compute_speedup,total_speedup,compute_efficiency,total_efficiency
```

### Important baseline rule

The `P = 1` row in `speedup.csv` is the true sequential baseline row, not a parallel run executed with one rank.

That distinction matters because:

- the sequential path is the intended denominator
- `communication_time` is correctly `0`
- the benchmark contract stays aligned with the project design

### Column-by-column explanation

#### `N`, `D`, `Q`, `k`, `P`, `compute_time`, `communication_time`, `total_time`

These columns have the same meanings as in the run-summary files above.

#### `compute_speedup`

**Type**

- floating-point number

**Meaning**

- speedup measured using compute-only time

**Formula**

```text
compute_speedup = sequential_baseline.compute_time / row.compute_time
```

**How to read it**

- `1.0` means no compute-speed advantage over the sequential baseline
- `2.0` means the compute portion ran twice as fast
- values below `1.0` mean the parallel configuration was slower on compute time

#### `total_speedup`

**Type**

- floating-point number

**Meaning**

- speedup measured using total benchmark runtime

**Formula**

```text
total_speedup = sequential_baseline.total_time / row.total_time
```

**How to read it**

- this is usually the most report-friendly speedup metric
- it includes the effect of communication, not just pure compute

#### `compute_efficiency`

**Type**

- floating-point number

**Meaning**

- efficiency of the compute-speedup relative to process count

**Formula**

```text
compute_efficiency = compute_speedup / P
```

**How to read it**

- `1.0` would mean ideal linear compute scaling
- values below `1.0` show the fraction of ideal scaling actually achieved

#### `total_efficiency`

**Type**

- floating-point number

**Meaning**

- efficiency of the total-runtime speedup relative to process count

**Formula**

```text
total_efficiency = total_speedup / P
```

**How to read it**

- this is usually stricter than `compute_efficiency` because it also reflects communication overhead

### How to interpret the whole table

Look for these patterns:

- `P` increases while `total_speedup` increases
  - good parallel scaling
- `P` increases but `total_speedup` flattens
  - diminishing returns
- `communication_time` rises sharply at higher `P`
  - communication is becoming a limiting factor
- `efficiency` drops as `P` grows
  - expected to some degree, but large drops are a sign of overhead or imbalance

## 6. `results/faiss/*_run_metrics.csv`

These files are the Phase 8 FAISS run-summary tables.

The current maintained files are:

- `results/faiss/synthetic_run_metrics.csv`
- `results/faiss/squad_run_metrics.csv`

The exact header is:

```text
dataset_name,N,D,Q,k,threads,build_time,compute_time,total_time
```

### What these files represent

Each file contains one row describing one FAISS exact-flat invocation over one binary memory/query dataset pair.

They are not per-rank tables and they are not candidate tables.

They exist so the project can compare its custom MPI retriever with an external library baseline while keeping the timing policy explicit.

### Column-by-column explanation

#### `dataset_name`

**Type**

- text

**Meaning**

- logical dataset label chosen by the workflow

**Current expected values**

- `synthetic`
- `squad_minilm`

**How to read it**

- it tells you which dataset family the row belongs to
- it is the join key used later in `results/faiss/comparison.csv`

#### `N`

**Type**

- integer

**Meaning**

- number of memory vectors indexed by FAISS

**How to read it**

- larger `N` means a larger FAISS database

#### `D`

**Type**

- integer

**Meaning**

- vector dimension used by the FAISS index

**How to read it**

- for the current SQuAD + MiniLM path, this is expected to be `384`

#### `Q`

**Type**

- integer

**Meaning**

- number of query vectors searched against the index

**How to read it**

- this should match the query count used by the sequential and parallel comparison runs on the same dataset

#### `k`

**Type**

- integer

**Meaning**

- requested top-k value passed to FAISS search

**How to read it**

- this should match the retrieval depth used by the project retrievers for the same comparison row

#### `threads`

**Type**

- integer

**Meaning**

- FAISS OpenMP thread count used during the run

**How to read it**

- this is the Phase 8 thread-side analogue of MPI worker count
- the current workflow sets it from the same canonical selection as `P_SELECTED`

#### `build_time`

**Type**

- floating-point seconds

**Meaning**

- time spent constructing the FAISS flat index contents

**Current boundary**

- measured around `IndexFlatIP.add(...)`

**How to read it**

- this is the cold-start indexing cost
- it is reported for fairness discussion, but it is not folded into the current canonical `total_time`

#### `compute_time`

**Type**

- floating-point seconds

**Meaning**

- time spent performing the FAISS search

**Current boundary**

- measured around `IndexFlatIP.search(...)`

**How to read it**

- this is the core number used to compare FAISS runtime against the project retriever runtime in Phase 8

#### `total_time`

**Type**

- floating-point seconds

**Meaning**

- canonical FAISS timing used in the final comparison table

**Current rule**

- `total_time = compute_time`

**How to read it**

- Phase 8 intentionally excludes FAISS build cost from the main denominator so the external comparison lines up with the retrieval-only timing window already used by the project retrievers

### How to interpret these files

- use `synthetic_run_metrics.csv` when you want the external-baseline timing on the selected synthetic dataset
- use `squad_run_metrics.csv` when you want the external-baseline timing on the converted real corpus
- compare these rows against `parallel_run_metrics.csv` only through the controlled aggregation in `results/faiss/comparison.csv`

## 7. `results/faiss/comparison.csv`

### What this file represents

This is the final Phase 8 comparison table.

Each row compares:

- one project parallel run summary
- one FAISS run summary
- one correctness CSV summary

for one dataset family.

The exact header is:

```text
dataset_name,N,D,Q,k,parallel_workers,faiss_threads,parallel_compute_time,parallel_communication_time,parallel_total_time,faiss_build_time,faiss_compute_time,faiss_total_time,total_ratio,correctness_status,max_score_diff
```

### Column-by-column explanation

#### `dataset_name`

**Type**

- text

**Meaning**

- logical dataset label for the comparison row

**Current expected values**

- `synthetic`
- `squad_minilm`

#### `N`

**Type**

- integer

**Meaning**

- number of memory vectors used by both the project retriever and FAISS for this row

#### `D`

**Type**

- integer

**Meaning**

- shared vector dimension used by both systems for this row

#### `Q`

**Type**

- integer

**Meaning**

- shared query count used by both systems for this row

#### `k`

**Type**

- integer

**Meaning**

- shared top-k value used by both systems for this row

#### `parallel_workers`

**Type**

- integer

**Meaning**

- MPI worker count used by `parallel_retriever`

**How to read it**

- this is the project-side parallelism value

#### `faiss_threads`

**Type**

- integer

**Meaning**

- FAISS OpenMP thread count

**How to read it**

- this is the baseline-side parallelism value
- the current workflow keeps it aligned with the selected worker-count policy, but the column still appears explicitly so report tables stay honest

#### `parallel_compute_time`

**Type**

- floating-point seconds

**Meaning**

- project parallel run-summary compute time for this dataset

**Current rule**

- copied from the Phase 6/7 parallel run-summary row

#### `parallel_communication_time`

**Type**

- floating-point seconds

**Meaning**

- project parallel run-summary communication time for this dataset

**How to read it**

- this shows the MPI overhead that FAISS does not have in the same form

#### `parallel_total_time`

**Type**

- floating-point seconds

**Meaning**

- project parallel run-summary total retrieval time for this dataset

**How to read it**

- this is the project-side denominator used in the final total-runtime ratio

#### `faiss_build_time`

**Type**

- floating-point seconds

**Meaning**

- FAISS index-construction cost for this dataset

**How to read it**

- use this when discussing cold-start tradeoffs
- do not mix it into the main total-runtime ratio unless you are intentionally doing a separate cold-start analysis

#### `faiss_compute_time`

**Type**

- floating-point seconds

**Meaning**

- FAISS search cost for this dataset

#### `faiss_total_time`

**Type**

- floating-point seconds

**Meaning**

- canonical FAISS total time for the Phase 8 comparison

**Current rule**

- equal to `faiss_compute_time`

#### `total_ratio`

**Type**

- floating-point number

**Meaning**

- relative runtime ratio between the project parallel path and the FAISS baseline

**Formula**

```text
total_ratio = parallel_total_time / faiss_total_time
```

**How to read it**

- values above `1.0` mean the project parallel path was slower than FAISS on this comparison window
- values below `1.0` mean the project parallel path was faster than FAISS on this comparison window
- values near `1.0` mean the two paths had similar runtime on the chosen metric

#### `correctness_status`

**Type**

- text

**Meaning**

- dataset-level correctness verdict derived from the corresponding correctness CSV

**Current values**

- `PASS`
- `FAIL`

**How it is formed**

- `PASS` only if every query row in the corresponding correctness CSV is `PASS`

#### `max_score_diff`

**Type**

- floating-point number

**Meaning**

- largest score difference observed anywhere in the corresponding correctness CSV

**How to read it**

- smaller is better
- `0` means the compared outputs matched exactly at the checked score precision

### How to interpret the whole table

Use each row as one report-ready comparison unit.

For example:

- if `correctness_status = PASS`, the FAISS output matched the sequential reference under the current deterministic ordering contract
- if `total_ratio > 1`, the project parallel path took longer than FAISS on the same dataset and timing window
- if `faiss_build_time` is large but `faiss_total_time` is small, FAISS has low steady-state search cost but non-trivial cold-start indexing cost

This file is usually the best single CSV to quote when you need one compact answer to: "How did the custom MPI retriever compare with FAISS on the maintained datasets?"

## Related Non-CSV Outputs In `results/`

These are not CSV files, but they often appear next to the CSV outputs and are easy to confuse with them.

### `benchmark_selection.env`

- shell-style manifest produced by `run_calibrate_target.sh`
- stores `N_SELECTED`, `N_SPEEDUP`, `P_SELECTED`, `D`, `Q`, `K`, `EPSILON`, `CALIBRATION_MODE`, and `N_MAX_FEASIBLE`
- consumed by later benchmark scripts

Useful reading rules:

- `N_SELECTED` is the canonical dataset size for correctness, granularity, and the synthetic FAISS path
- `N_SPEEDUP` is the separate speedup-only dataset size
- `CALIBRATION_MODE=N_ONLY` means the target runtime was reached during the initial `N` sweep
- `CALIBRATION_MODE=N_PLUS_Q` means the runtime target needed `Q` escalation after the largest feasible `N` was still too small
- `N_MAX_FEASIBLE` is the largest successful `N` from the initial `N` sweep

### `granularity_summary.txt`

- short text summary produced by `run_granularity.sh`
- summarizes the idle-time gap and prints a verdict such as `BALANCED` or `UNBALANCED`

### `results/figures/*.png`

- plot images generated by `run_all_experiments.sh`
- visual presentation layer built from the CSV benchmark outputs

## Which File To Read For Which Question

Use this shortcut:

- “What candidates were retrieved?”
  - `sequential_topk.csv` or `parallel_topk.csv`
- “How much work did each MPI rank do?”
  - `parallel_metrics.csv` or `granularity.csv`
- “Did the parallel output match the sequential output?”
  - `correctness.csv`
- “What is the one-line timing summary for this run?”
  - `sequential_run_metrics.csv` or `parallel_run_metrics.csv`
- “How did runtime change with dataset size?”
  - `runtime_by_N.csv`
- “How much speedup did different process counts achieve?”
  - `speedup.csv`
