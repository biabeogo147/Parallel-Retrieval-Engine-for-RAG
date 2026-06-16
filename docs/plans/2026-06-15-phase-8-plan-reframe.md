# Phase 8 Plan Reframe

> **For engineers:** This document records the documentation-only reframe applied to the master project plan on 2026-06-15, so later implementation work can start from the updated Phase 8 direction instead of the old AI-agent demo direction.

**Status:** Master plan updated on 2026-06-15

**Goal:** Replace Phase 8 in `docs/development/parallel_agent_memory_retriever_plan.md` from a metadata-backed AI-agent demo into a FAISS external baseline comparison phase.

**Architecture:** The reframe keeps the core thesis intact: the project still owns its exact sequential and MPI implementations, while FAISS is introduced only as an external baseline. The Phase 8 plan now targets a WSL-first Python workflow around `faiss.IndexFlatIP`, synthetic benchmark reuse, and one real-corpus conversion path through SQuAD plus `sentence-transformers/all-MiniLM-L6-v2`.

**Tech Stack:** Markdown documentation, WSL2 Ubuntu 24.04 assumptions, FAISS CPU baseline, `sentence-transformers`, SQuAD parquet inputs

---

## What Changed In The Master Plan

- Replaced the old `Phase 8 - Demo AI Agent memory retrieval` block with `Phase 8 - FAISS external baseline comparison`.
- Updated the Phase 8 objectives, deliverables, acceptance criteria, and command examples to use:
  - `scripts/faiss_compare.py`
  - `scripts/prepare_squad_minilm.py`
  - `scripts/run_faiss_comparison.sh`
- Locked the intended Phase 8 policies directly in the plan:
  - `IndexFlatIP` exact flat CPU baseline only
  - synthetic benchmark reuse without a second vector format
  - SQuAD train-context / validation-question real-corpus path
  - `all-MiniLM-L6-v2`
  - `queries-limit = 100`
  - `epsilon = 1e-5`
  - fair timing split between `build_time` and `compute_time`
  - FAISS thread count derived from `P_SELECTED`
- Reworked the later master-plan sections so the document no longer points to:
  - `main_demo.cpp`
  - `agent_memory_demo`
  - demo-only acceptance text
- Updated the codebase sketch, report outline, risk table, final design decisions, and concluding summary so they all align with the new Phase 8 direction.

## Important Clarifications

- This document does **not** mean Phase 8 has been implemented in code yet.
- This is a documentation reframe only: it changes the agreed project direction and implementation target for the next phase.
- The old metadata/memory-text demo idea is preserved only as `future work / appendix direction`, not as a numbered phase.

## Static Verification Performed

- Confirmed the master plan previously contained the old demo Phase 8 references.
- Updated the master plan so the old acceptance command and demo deliverables were removed.
- Re-checked the master plan after editing to ensure the intended FAISS Phase 8 text is now present and the old demo-specific references are gone.
