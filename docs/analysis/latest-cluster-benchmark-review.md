# Latest Benchmark Review

## 1. Benchmark Validity Check

Evidence: sequential-vs-parallel correctness checked 400 queries with all_pass=true. FAISS comparison was skipped for this run.

Report-ready statement: The benchmark validity status for this run is `VALID`.

Do not overclaim: if the status is not `VALID`, treat all performance numbers as provisional until correctness is repaired and the benchmark is rerun.

## 2. Runtime-by-N Findings

    Evidence: `N_SELECTED=10000000` and `Q=400` produced `total_time=144.11783635` seconds with target status `IN_TARGET`. The largest tested N was `10000000` with `total_time=36.62555562` seconds under the initial N sweep.

Report-ready statement: N-only calibration was infeasible on the current hardware after reaching N_MAX_FEASIBLE=10000000. The benchmark therefore fixed N_SELECTED=10000000 and escalated Q to 400, producing total_time=144.11783635 seconds inside the 120-180 second target window.

Do not overclaim: selecting the closest available N is not the same as actually hitting the intended 120-180 second benchmark window.

## 3. Correctness Findings

Evidence: sequential-vs-parallel max_score_diff was `0.00000000`. No FAISS correctness CSVs were generated because FAISS comparison was skipped for this run.

Report-ready statement: The sequential baseline and MPI retriever align under the current deterministic ordering and epsilon policy for this run.

Do not overclaim: correctness here means exact agreement on the same vector inputs, not proof of semantic relevance against external text labels.

## 4. Granularity/Load-Balance Findings

Evidence: `local_N` ranged from `714285` to `714286`, `compute_cv=0.09647618`, `active_cv=0.04007047`, and `idle_relative_gap=0.99995090`.

Report-ready statement: The current load-balance classification is `COMMUNICATION_SKEW`.

Do not overclaim: a large relative idle-gap ratio can coexist with tiny absolute skew, so this signal must be interpreted together with `absolute_idle_spread` and the per-rank active times.

## 5. Speedup Findings

Evidence: the best total speedup appeared at `P=14` with `total_speedup=5.32813569`; the first total-speedup regression appeared at `P=None`; the recommended operating point is `P=2`.

Report-ready statement: No total-speedup regression appears in the tested worker counts; communication share does not overtake the scaling gains inside the current sweep.

Do not overclaim: the highest tested worker count is not automatically the best operating point once communication starts eroding total speedup.

## 6. FAISS Comparison Status

Evidence: no `results/faiss/` comparison artifacts were provided for this run.

Report-ready statement: FAISS comparison was skipped for this run, so the current review focuses on the in-repo sequential-vs-parallel benchmark story only.

Do not overclaim: without the external baseline artifacts, this review cannot make any cross-system timing claim against FAISS.


## 7. Final Conclusion

Evidence: runtime status was `IN_TARGET`, load-balance status was `COMMUNICATION_SKEW`, and recommended operating point was `P=2`.

Report-ready statement: The system is correct, the selected workload sits inside the intended benchmark window, and the recommended operating point is P=2. Load-balance classification is COMMUNICATION_SKEW. This run intentionally skipped the external FAISS comparison and focuses on the sequential-vs-parallel benchmark story.

Do not overclaim: this conclusion is only about the current exact retrieval kernel and benchmark setup, not a general claim about all retrieval systems or ANN baselines.

## 8. Recommended Next Steps

Evidence: the current benchmark layer now supports deterministic reruns, derived analysis CSVs, JSON summaries, and report-ready Markdown output.

Report-ready statement:

1. Priority 1: Keep the current N ceiling explicit in the report; future runtime retuning should revisit memory capacity or sharding strategy before blindly increasing N again.
2. Priority 2: Keep P_SELECTED near physical cores and stop treating 2X workers as a canonical operating point if a regression appears.
3. Priority 3: Keep the report wording honest about load balance when idle-gap ratio is sensitive but absolute skew is tiny.
4. Priority 4: FAISS comparison was skipped for this run; if an external baseline is needed later, execute the FAISS workflow separately.
5. Priority 5: If a future performance phase is approved, focus on communication reduction and orchestration improvements before adding new corpora.

Do not overclaim: these next steps are prioritized for the current repo direction and should be revised only if the project scope or benchmark policy changes.
