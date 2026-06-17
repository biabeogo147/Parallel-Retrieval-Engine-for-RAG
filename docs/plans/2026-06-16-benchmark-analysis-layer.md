# Benchmark Analysis Layer

> **For engineers:** This document records what the benchmark-analysis layer implemented, how it was verified, and what behavior is now locked so later report work can reuse a deterministic analysis pipeline instead of writing ad hoc benchmark notes.

**Status:** Implemented and verified on 2026-06-16

**Goal:** Add a reusable post-run analysis layer that reads the canonical benchmark CSV outputs, derives higher-level classifications, and writes machine-readable plus report-ready conclusions.

**Architecture:** The analysis layer is a stdlib-only Python script, `scripts/analyze_benchmarks.py`, that sits after the existing benchmark execution workflows. It does not rewrite raw benchmark CSVs. Instead it validates the required inputs, derives runtime/load-balance/speedup/FAISS classifications, writes `results/analysis/*`, and mirrors the final Markdown review into `docs/analysis/latest-benchmark-review.md`.

**Tech Stack:** Python 3 stdlib, existing benchmark CSV contracts, CTest, Markdown

---

### Task 1: Add the analysis entrypoint

**Files:**
- Create: `scripts/analyze_benchmarks.py`

- [x] Add CLI arguments:
  - `--results-dir`
  - `--output-dir`
  - `--docs-output`
- [x] Require the canonical benchmark inputs:
  - `runtime_by_N.csv`
  - `correctness.csv`
  - `granularity.csv`
  - `speedup.csv`
  - `faiss/comparison.csv`
  - `faiss/synthetic_correctness.csv`
  - `faiss/squad_correctness.csv`
  - `benchmark_selection.env`
- [x] Fail clearly when any required file is missing.

### Task 2: Lock the derived analysis outputs

**Files:**
- Create: `scripts/analyze_benchmarks.py`

- [x] Generate:
  - `runtime_analysis.csv`
  - `granularity_analysis.csv`
  - `speedup_analysis.csv`
  - `faiss_analysis.csv`
  - `benchmark_summary.json`
  - `final_conclusions.md`
- [x] Lock correctness gating:
  - `VALID`
  - `INVALID_UNTIL_CORRECTNESS_FIXED`
- [x] Lock the benchmark-interpretation classifications:
  - runtime target status
  - load-balance status
  - speedup regression and recommended operating point
  - FAISS gap class

### Task 3: Add report-facing docs

**Files:**
- Create: `docs/analysis/README.md`
- Create: `docs/analysis/report_mapping.md`

- [x] Document the analysis command and generated outputs.
- [x] Map the generated analysis artifacts to final report sections.
- [x] Treat `docs/analysis/latest-benchmark-review.md` as the canonical generated benchmark review path.

### Task 4: Add smoke coverage

**Files:**
- Modify: `CMakeLists.txt`
- Create: `tests/cmake/RunBenchmarkAnalysisSmoke.cmake`
- Create: `tests/cmake/RunBenchmarkAnalysisInvalidCorrectnessSmoke.cmake`
- Create: `tests/cmake/RunBenchmarkAnalysisMissingInputFail.cmake`

- [x] Validate the happy path with complete fixture inputs.
- [x] Validate that invalid correctness marks conclusions as invalid.
- [x] Validate that missing required input files fail with a named path.

### Task 5: Update canonical docs

**Files:**
- Modify: `README.md`
- Modify: `AGENTS.md`
- Modify: `docs/usage/benchmark-workflows.md`
- Modify: `docs/development/developer_guide.md`
- Modify: `docs/development/source_guide.md`

- [x] Add the analysis layer to the repo status and documentation index.
- [x] Add the post-run analysis command to the benchmark workflow docs.
- [x] Document the new script responsibility and artifact layout.
- [x] Add `docs/analysis/` as a canonical home for benchmark interpretation.

### Task 6: Verification actually completed

**Ubuntu WSL checks actually run from `/mnt/d/DS-AI/Parallel-Retrieval-Engine-for-RAG`:**

- [x] `ctest --test-dir build/debug -R "benchmark_analysis_" --output-on-failure`

**Observed result:**

- `benchmark_analysis_smoke` passed
- `benchmark_analysis_invalid_correctness_smoke` passed
- `benchmark_analysis_missing_input_fails` passed

### Notes for the next person

- The analysis layer is derived-only and should not be turned into a second benchmark runner.
- Raw benchmark CSV contracts remain canonical; the analysis outputs sit on top of them.
- If the report policy changes, update `docs/analysis/report_mapping.md` and the generated Markdown structure together.
