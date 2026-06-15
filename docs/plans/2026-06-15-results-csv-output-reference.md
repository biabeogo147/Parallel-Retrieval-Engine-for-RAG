# Results CSV Output Reference Docs

> **For engineers:** This document records the dedicated CSV-output reference added for the `results/` directory, what it covers, and what was verified against the current repository outputs.

**Status:** Implemented and verified on 2026-06-15

**Goal:** Add a user-facing reference document that explains every current CSV output file under `results/` and clearly defines every column so developers can read benchmark and retrieval outputs without reverse-engineering the schemas.

**Architecture:** The new document lives in `docs/usage/` because it is a command-adjacent output-interpretation guide rather than a deeper contract/spec document. It complements, rather than replaces, the schema and benchmark semantics already documented in `docs/development/`.

**Tech Stack:** Markdown, existing `results/` CSV artifacts, existing retrieval and benchmark documentation

---

### Task 1: Add a dedicated CSV output reference

**Files:**

- Create: `docs/usage/results-csv-reference.md`

- [x] Document `sequential_topk.csv`.
- [x] Document `parallel_topk.csv`.
- [x] Document `parallel_metrics.csv`.
- [x] Document `correctness.csv`.
- [x] Document `sequential_run_metrics.csv`.
- [x] Document `parallel_run_metrics.csv`.
- [x] Document `runtime_by_N.csv`.
- [x] Document `granularity.csv`.
- [x] Document `speedup.csv`.
- [x] Explain each column in detail, including row granularity and interpretation guidance.

### Task 2: Make the new reference discoverable

**Files:**

- Modify: `docs/usage/README.md`
- Modify: `docs/usage/retrieval-workflows.md`
- Modify: `docs/usage/benchmark-workflows.md`
- Modify: `README.md`

- [x] Add the new reference to the usage reading order.
- [x] Link to the reference from retrieval workflows.
- [x] Link to the reference from benchmark workflows.
- [x] Add the new reference to the top-level README documentation index.

### Task 3: Verification actually completed

**Repository checks actually run:**

- [x] Internal Markdown link resolution check across `README.md`, `docs/usage/`, and the updated canonical development docs
- [x] Review of the current `results/` directory contents
- [x] Review of live CSV headers from:
  - `results/sequential_topk.csv`
  - `results/parallel_metrics.csv`
  - `results/runtime_by_N.csv`
- [x] Review of the current command and schema references already documented in `docs/development/`

**Observed result:**

- the new results reference matched the currently generated CSV files
- the internal Markdown links resolved successfully after adding the new page
- the new page is now discoverable from the usage index, retrieval workflows, benchmark workflows, and top-level README

### Notes for the next person

- If a new CSV file is added under `results/` as part of the supported workflow, update `docs/usage/results-csv-reference.md` in the same task.
- If a column meaning changes, update both the usage reference and the deeper technical benchmark/spec docs together.
