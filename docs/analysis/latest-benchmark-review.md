# Latest Benchmark Review

## 1. Benchmark Validity Check

Evidence: sequential-vs-parallel correctness checked 100 queries with all_pass=true, FAISS synthetic all_pass=true, and FAISS squad all_pass=true.

Report-ready statement: The benchmark validity status for this run is `VALID`.

Do not overclaim: if the status is not `VALID`, treat all performance numbers as provisional until correctness is repaired and the benchmark is rerun.

## 2. Runtime-by-N Findings

Evidence: `N_SELECTED=2000000` produced `total_time=16.00208485` seconds with target status `UNDER_TARGET`. The largest tested N was `2000000` with `total_time=16.00208485` seconds.

Report-ready statement: Even the largest tested N stays below the 120-180 second target window. Expand BENCH_N_CANDIDATES first; revisit Q only after the N sweep reaches the target runtime band.

Do not overclaim: selecting the closest available N is not the same as actually hitting the intended 120-180 second benchmark window.

## 3. Correctness Findings

Evidence: sequential-vs-parallel max_score_diff was `0.00000000`. FAISS synthetic max_score_diff was `0.00000101`. FAISS squad max_score_diff was `0.00000051`.

Report-ready statement: The sequential baseline, MPI retriever, and maintained FAISS baselines all align under the current deterministic ordering and epsilon policy for this run.

Do not overclaim: correctness here means exact agreement on the same vector inputs, not proof of semantic relevance against external text labels.

## 4. Granularity/Load-Balance Findings

Evidence: `local_N` ranged from `200000` to `200000`, `compute_cv=0.00169604`, `active_cv=0.00015744`, and `idle_relative_gap=0.94978714`.

Report-ready statement: The current load-balance classification is `BALANCED_BUT_IDLE_RATIO_SENSITIVE`.

Do not overclaim: a large relative idle-gap ratio can coexist with tiny absolute skew, so this signal must be interpreted together with `absolute_idle_spread` and the per-rank active times.

## 5. Speedup Findings

Evidence: the best total speedup appeared at `P=10` with `total_speedup=8.91643499`; the first total-speedup regression appeared at `P=20`; the recommended operating point is `P=10`.

Report-ready statement: Communication share stays manageable through P=10 and then rises to 48.35% at P=20, which is also the first total-speedup regression point.

Do not overclaim: the highest tested worker count is not automatically the best operating point once communication starts eroding total speedup.

## 6. FAISS Comparison Findings

Evidence: synthetic total_ratio was `5.29865739` with gap_class `LARGE_GAP`; squad_minilm total_ratio was `6.22703085` with gap_class `LARGE_GAP`.

Report-ready statement: Exact-match correctness holds against the sequential reference. Treat FAISS as an external optimized baseline, not as the project implementation target.

Do not overclaim: FAISS is an optimized external CPU exact-flat baseline, so the project should frame this result as realism-oriented comparison rather than a requirement to outperform FAISS.

## 7. Final Conclusion

Evidence: runtime status was `UNDER_TARGET`, load-balance status was `BALANCED_BUT_IDLE_RATIO_SENSITIVE`, and recommended operating point was `P=10`.

Report-ready statement: The system is correct and scales to a practical operating point of P=10, but the current workload still undershoots the intended 2-3 minute runtime target. Load-balance classification is BALANCED_BUT_IDLE_RATIO_SENSITIVE, and FAISS remains an external faster baseline with the largest observed total_ratio=6.23.

Do not overclaim: this conclusion is only about the current exact retrieval kernel and benchmark setup, not a general claim about all retrieval systems or ANN baselines.

## 8. Recommended Next Steps

Evidence: the current benchmark layer now supports deterministic reruns, derived analysis CSVs, JSON summaries, and report-ready Markdown output.

Report-ready statement:

1. Priority 1: Make the runtime benchmark hit the intended 120-180 second target by expanding BENCH_N_CANDIDATES, then revisiting Q only if needed.
2. Priority 2: Keep P_SELECTED near physical cores and stop treating 2X workers as a canonical operating point if a regression appears.
3. Priority 3: Keep the report wording honest about load balance when idle-gap ratio is sensitive but absolute skew is tiny.
4. Priority 4: Treat FAISS as a realism baseline; do not promise to outperform it with the current exact blocking MPI design.
5. Priority 5: If a future performance phase is approved, focus on communication reduction and orchestration improvements before adding new corpora.

Do not overclaim: these next steps are prioritized for the current repo direction and should be revised only if the project scope or benchmark policy changes.
