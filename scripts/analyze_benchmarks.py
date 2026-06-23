#!/usr/bin/env python3

from __future__ import annotations

import argparse
import csv
import json
import math
from pathlib import Path
import statistics

from benchmark_csv import (
    CORRECTNESS_FIELDS,
    FAISS_COMPARISON_FIELDS,
    GRANULARITY_FIELDS,
    RUN_METRICS_FIELDS,
    SPEEDUP_FIELDS,
    read_csv_rows,
)


RUNTIME_ANALYSIS_FIELDS = [
    "N",
    "D",
    "Q",
    "k",
    "P",
    "compute_time",
    "communication_time",
    "total_time",
    "target_status",
    "seconds_to_target_lower",
    "seconds_to_target_upper",
    "is_selected_n",
    "recommended_scaling_action",
]

GRANULARITY_ANALYSIS_FIELDS = [
    "rank",
    "local_N",
    "compute_time",
    "communication_time",
    "active_time",
    "global_total_time",
    "idle_time",
    "compute_share",
    "communication_share",
    "idle_share",
    "load_balance_status",
]

SPEEDUP_ANALYSIS_FIELDS = [
    "N",
    "D",
    "Q",
    "k",
    "P",
    "compute_time",
    "communication_time",
    "total_time",
    "compute_speedup",
    "total_speedup",
    "compute_efficiency",
    "total_efficiency",
    "communication_share",
    "incremental_compute_speedup_gain",
    "incremental_total_speedup_gain",
    "efficiency_band",
    "is_best_total_speedup",
    "is_regression_point",
]

FAISS_ANALYSIS_FIELDS = [
    "dataset_name",
    "N",
    "D",
    "Q",
    "k",
    "parallel_workers",
    "faiss_threads",
    "parallel_compute_time",
    "parallel_communication_time",
    "parallel_total_time",
    "faiss_build_time",
    "faiss_compute_time",
    "faiss_total_time",
    "total_ratio",
    "correctness_status",
    "max_score_diff",
    "build_share",
    "parallel_comm_share",
    "gap_class",
    "report_positioning",
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Analyze benchmark CSV outputs and generate report-ready summaries."
    )
    parser.add_argument("--results-dir", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--docs-output", type=Path, required=True)
    return parser.parse_args()


def format_float(value: float) -> str:
    return f"{value:.8f}"


def format_bool(value: bool) -> str:
    return "true" if value else "false"


def parse_manifest(path: Path) -> dict[str, str]:
    manifest: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        if "=" not in stripped:
            raise RuntimeError(f"invalid manifest line in {path}: {line}")
        key, value = stripped.split("=", 1)
        manifest[key] = value
    return manifest


def require_file(path: Path) -> None:
    if not path.is_file():
        raise RuntimeError(f"missing required benchmark input: {path}")


def detect_faiss_input_mode(paths: dict[str, Path]) -> str:
    existing = {name: path.is_file() for name, path in paths.items()}
    if all(existing.values()):
        return "present"
    if not any(existing.values()):
        return "skipped"

    missing = [name for name, is_present in existing.items() if not is_present]
    raise RuntimeError(
        "partial FAISS benchmark inputs detected; either provide all FAISS files or none: "
        + ", ".join(missing)
    )


def read_run_metrics_table(path: Path) -> list[dict[str, float | int]]:
    rows = read_csv_rows(path, RUN_METRICS_FIELDS)
    parsed_rows: list[dict[str, float | int]] = []
    for row in rows:
        parsed_rows.append(
            {
                "N": int(row["N"]),
                "D": int(row["D"]),
                "Q": int(row["Q"]),
                "k": int(row["k"]),
                "P": int(row["P"]),
                "compute_time": float(row["compute_time"]),
                "communication_time": float(row["communication_time"]),
                "total_time": float(row["total_time"]),
            }
        )
    if not parsed_rows:
        raise RuntimeError(f"no rows available in {path}")
    return parsed_rows


def read_granularity_table(path: Path) -> list[dict[str, float | int]]:
    rows = read_csv_rows(path, GRANULARITY_FIELDS)
    parsed_rows: list[dict[str, float | int]] = []
    for row in rows:
        parsed_rows.append(
            {
                "rank": int(row["rank"]),
                "local_N": int(row["local_N"]),
                "compute_time": float(row["compute_time"]),
                "communication_time": float(row["communication_time"]),
                "active_time": float(row["active_time"]),
                "global_total_time": float(row["global_total_time"]),
                "idle_time": float(row["idle_time"]),
            }
        )
    if not parsed_rows:
        raise RuntimeError(f"no rows available in {path}")
    return parsed_rows


def read_speedup_table(path: Path) -> list[dict[str, float | int]]:
    rows = read_csv_rows(path, SPEEDUP_FIELDS)
    parsed_rows: list[dict[str, float | int]] = []
    for row in rows:
        parsed_rows.append(
            {
                "N": int(row["N"]),
                "D": int(row["D"]),
                "Q": int(row["Q"]),
                "k": int(row["k"]),
                "P": int(row["P"]),
                "compute_time": float(row["compute_time"]),
                "communication_time": float(row["communication_time"]),
                "total_time": float(row["total_time"]),
                "compute_speedup": float(row["compute_speedup"]),
                "total_speedup": float(row["total_speedup"]),
                "compute_efficiency": float(row["compute_efficiency"]),
                "total_efficiency": float(row["total_efficiency"]),
            }
        )
    if not parsed_rows:
        raise RuntimeError(f"no rows available in {path}")
    return parsed_rows


def read_faiss_comparison_table(path: Path) -> list[dict[str, float | int | str]]:
    rows = read_csv_rows(path, FAISS_COMPARISON_FIELDS)
    parsed_rows: list[dict[str, float | int | str]] = []
    for row in rows:
        parsed_rows.append(
            {
                "dataset_name": row["dataset_name"],
                "N": int(row["N"]),
                "D": int(row["D"]),
                "Q": int(row["Q"]),
                "k": int(row["k"]),
                "parallel_workers": int(row["parallel_workers"]),
                "faiss_threads": int(row["faiss_threads"]),
                "parallel_compute_time": float(row["parallel_compute_time"]),
                "parallel_communication_time": float(row["parallel_communication_time"]),
                "parallel_total_time": float(row["parallel_total_time"]),
                "faiss_build_time": float(row["faiss_build_time"]),
                "faiss_compute_time": float(row["faiss_compute_time"]),
                "faiss_total_time": float(row["faiss_total_time"]),
                "total_ratio": float(row["total_ratio"]),
                "correctness_status": row["correctness_status"],
                "max_score_diff": float(row["max_score_diff"]),
            }
        )
    if not parsed_rows:
        raise RuntimeError(f"no rows available in {path}")
    return parsed_rows


def read_correctness_summary(path: Path) -> dict[str, object]:
    rows = read_csv_rows(path, CORRECTNESS_FIELDS)
    if not rows:
        raise RuntimeError(f"no rows available in {path}")

    failing_queries: list[int] = []
    max_score_diff = 0.0
    for row in rows:
        if row["status"] != "PASS":
            failing_queries.append(int(row["query_id"]))
        max_score_diff = max(max_score_diff, float(row["max_score_diff"]))

    return {
        "path": str(path),
        "query_count": len(rows),
        "all_pass": not failing_queries,
        "failing_queries": failing_queries,
        "max_score_diff": max_score_diff,
    }


def safe_cv(values: list[float]) -> float:
    if not values:
        return 0.0
    mean_value = statistics.fmean(values)
    if math.isclose(mean_value, 0.0, abs_tol=1e-12):
        return 0.0
    return statistics.pstdev(values) / mean_value


def write_csv(path: Path, fieldnames: list[str], rows: list[dict[str, object]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def analyze_runtime(
    rows: list[dict[str, float | int]],
    manifest: dict[str, str],
    final_selected_total_time: float | None = None,
    target_lower: float = 120.0,
    target_upper: float = 180.0,
) -> tuple[list[dict[str, object]], dict[str, object]]:
    selected_n = int(manifest["N_SELECTED"])
    selected_q = int(manifest["Q"])
    calibration_mode = manifest.get("CALIBRATION_MODE", "N_ONLY")
    n_max_feasible = int(manifest.get("N_MAX_FEASIBLE", manifest["N_SELECTED"]))
    selected_row: dict[str, float | int] | None = None
    max_n_row = max(rows, key=lambda row: int(row["N"]))
    analysis_rows: list[dict[str, object]] = []

    for row in sorted(rows, key=lambda item: int(item["N"])):
        total_time = float(row["total_time"])
        if target_lower <= total_time <= target_upper:
            target_status = "IN_TARGET"
            scaling_action = "keep_current_candidate"
        elif total_time < target_lower:
            target_status = "UNDER_TARGET"
            scaling_action = "increase_n"
        else:
            target_status = "OVER_TARGET"
            scaling_action = "decrease_n"

        is_selected = int(row["N"]) == selected_n
        if is_selected:
            selected_row = row

        analysis_rows.append(
            {
                "N": int(row["N"]),
                "D": int(row["D"]),
                "Q": int(row["Q"]),
                "k": int(row["k"]),
                "P": int(row["P"]),
                "compute_time": format_float(float(row["compute_time"])),
                "communication_time": format_float(float(row["communication_time"])),
                "total_time": format_float(total_time),
                "target_status": target_status,
                "seconds_to_target_lower": format_float(target_lower - total_time),
                "seconds_to_target_upper": format_float(target_upper - total_time),
                "is_selected_n": format_bool(is_selected),
                "recommended_scaling_action": scaling_action,
            }
        )

    if selected_row is None:
        raise RuntimeError(f"N_SELECTED={selected_n} is not present in runtime_by_N.csv")

    selected_total_time = (
        final_selected_total_time
        if final_selected_total_time is not None
        else float(selected_row["total_time"])
    )

    if target_lower <= selected_total_time <= target_upper:
        selected_status = "IN_TARGET"
    elif selected_total_time < target_lower:
        selected_status = "UNDER_TARGET"
    else:
        selected_status = "OVER_TARGET"

    if calibration_mode == "N_PLUS_Q":
        if target_lower <= selected_total_time <= target_upper:
            overall_recommendation = (
                f"N-only calibration was infeasible on the current hardware after reaching N_MAX_FEASIBLE={n_max_feasible}. "
                f"The benchmark therefore fixed N_SELECTED={selected_n} and escalated Q to {selected_q}, producing total_time={selected_total_time:.8f} seconds inside the 120-180 second target window."
            )
        elif selected_status == "UNDER_TARGET":
            overall_recommendation = (
                f"N-only calibration was infeasible on the current hardware after reaching N_MAX_FEASIBLE={n_max_feasible}. "
                f"The benchmark therefore fixed N_SELECTED={selected_n} and escalated Q to {selected_q}, but the final calibrated runtime is still below the target window at {selected_total_time:.8f} seconds."
            )
        else:
            overall_recommendation = (
                f"N-only calibration was infeasible on the current hardware after reaching N_MAX_FEASIBLE={n_max_feasible}. "
                f"The benchmark therefore fixed N_SELECTED={selected_n} and escalated Q to {selected_q}, but the final calibrated runtime now exceeds the target window at {selected_total_time:.8f} seconds."
            )
    elif target_lower <= selected_total_time <= target_upper:
        overall_recommendation = "Selected runtime is already inside the target window. Keep N_SELECTED as the canonical benchmark scale."
    elif float(max_n_row["total_time"]) < target_lower:
        overall_recommendation = (
            "Even the largest tested N stays below the 120-180 second target window. Expand BENCH_N_CANDIDATES first; revisit Q only after the N sweep reaches the target runtime band."
        )
    elif selected_total_time < target_lower:
        overall_recommendation = (
            "The selected runtime is still below the 120-180 second target window. Increase N before changing Q."
        )
    else:
        overall_recommendation = (
            "The selected runtime exceeds the 120-180 second target window. Reduce N before changing Q."
        )

    summary = {
        "selected_n": selected_n,
        "selected_q": selected_q,
        "selected_total_time": selected_total_time,
        "selected_target_status": selected_status,
        "calibration_mode": calibration_mode,
        "n_max_feasible": n_max_feasible,
        "max_tested_n": int(max_n_row["N"]),
        "max_tested_total_time": float(max_n_row["total_time"]),
        "overall_recommendation": overall_recommendation,
    }
    return analysis_rows, summary


def analyze_granularity(rows: list[dict[str, float | int]]) -> tuple[list[dict[str, object]], dict[str, object]]:
    sorted_rows = sorted(rows, key=lambda row: int(row["rank"]))
    global_total_values = [float(row["global_total_time"]) for row in sorted_rows]
    global_total_time = global_total_values[0]
    for value in global_total_values[1:]:
        if not math.isclose(value, global_total_time, rel_tol=0.0, abs_tol=1e-6):
            raise RuntimeError("granularity.csv contains inconsistent global_total_time values")

    local_ns = [int(row["local_N"]) for row in sorted_rows]
    compute_times = [float(row["compute_time"]) for row in sorted_rows]
    communication_times = [float(row["communication_time"]) for row in sorted_rows]
    active_times = [float(row["active_time"]) for row in sorted_rows]
    idle_times = [float(row["idle_time"]) for row in sorted_rows]

    local_n_min = min(local_ns)
    local_n_max = max(local_ns)
    compute_cv = safe_cv(compute_times)
    communication_cv = safe_cv(communication_times)
    active_cv = safe_cv(active_times)
    idle_relative_gap = 0.0 if max(idle_times) <= 1e-12 else (max(idle_times) - min(idle_times)) / max(idle_times)
    absolute_idle_spread = max(idle_times) - min(idle_times)

    non_root_compute_times = [float(row["compute_time"]) for row in sorted_rows if int(row["rank"]) != 0]
    root_compute_overhead = 0.0
    if non_root_compute_times:
        root_compute_overhead = float(sorted_rows[0]["compute_time"]) - statistics.fmean(non_root_compute_times)

    mean_communication = statistics.fmean(communication_times)
    root_communication_ratio = 1.0
    if mean_communication > 1e-12:
        root_communication_ratio = float(sorted_rows[0]["communication_time"]) / mean_communication

    core_balanced = local_n_max - local_n_min <= 1 and compute_cv <= 0.05 and active_cv <= 0.05
    communication_skew = communication_cv > 0.10 or root_communication_ratio >= 1.25

    if core_balanced and idle_relative_gap > 0.25 and absolute_idle_spread <= 0.01 * global_total_time:
        load_balance_status = "BALANCED_BUT_IDLE_RATIO_SENSITIVE"
    elif communication_skew:
        load_balance_status = "COMMUNICATION_SKEW"
    elif not core_balanced:
        load_balance_status = "LOAD_IMBALANCE"
    else:
        load_balance_status = "WELL_BALANCED"

    analysis_rows: list[dict[str, object]] = []
    for row in sorted_rows:
        compute_time = float(row["compute_time"])
        communication_time = float(row["communication_time"])
        idle_time = float(row["idle_time"])
        analysis_rows.append(
            {
                "rank": int(row["rank"]),
                "local_N": int(row["local_N"]),
                "compute_time": format_float(compute_time),
                "communication_time": format_float(communication_time),
                "active_time": format_float(float(row["active_time"])),
                "global_total_time": format_float(global_total_time),
                "idle_time": format_float(idle_time),
                "compute_share": format_float(compute_time / global_total_time),
                "communication_share": format_float(communication_time / global_total_time),
                "idle_share": format_float(idle_time / global_total_time),
                "load_balance_status": load_balance_status,
            }
        )

    summary = {
        "local_n_min": local_n_min,
        "local_n_max": local_n_max,
        "compute_cv": compute_cv,
        "communication_cv": communication_cv,
        "active_cv": active_cv,
        "idle_relative_gap": idle_relative_gap,
        "absolute_idle_spread": absolute_idle_spread,
        "root_compute_overhead": root_compute_overhead,
        "load_balance_status": load_balance_status,
        "global_total_time": global_total_time,
    }
    return analysis_rows, summary


def efficiency_band(total_efficiency: float) -> str:
    if total_efficiency >= 0.90:
        return "EXCELLENT"
    if total_efficiency >= 0.75:
        return "GOOD"
    if total_efficiency >= 0.50:
        return "MODERATE"
    return "WEAK"


def analyze_speedup(rows: list[dict[str, float | int]]) -> tuple[list[dict[str, object]], dict[str, object]]:
    sorted_rows = sorted(rows, key=lambda row: int(row["P"]))
    best_total_row = max(sorted_rows, key=lambda row: float(row["total_speedup"]))
    best_compute_row = max(sorted_rows, key=lambda row: float(row["compute_speedup"]))

    first_regression_p: int | None = None
    analysis_rows: list[dict[str, object]] = []
    previous_row: dict[str, float | int] | None = None

    for row in sorted_rows:
        total_time = float(row["total_time"])
        communication_time = float(row["communication_time"])
        is_regression_point = False
        incremental_compute = 0.0
        incremental_total = 0.0
        if previous_row is not None:
            incremental_compute = float(row["compute_speedup"]) - float(previous_row["compute_speedup"])
            incremental_total = float(row["total_speedup"]) - float(previous_row["total_speedup"])
            if float(row["total_speedup"]) < float(previous_row["total_speedup"]):
                is_regression_point = True
                if first_regression_p is None:
                    first_regression_p = int(row["P"])

        analysis_rows.append(
            {
                "N": int(row["N"]),
                "D": int(row["D"]),
                "Q": int(row["Q"]),
                "k": int(row["k"]),
                "P": int(row["P"]),
                "compute_time": format_float(float(row["compute_time"])),
                "communication_time": format_float(communication_time),
                "total_time": format_float(total_time),
                "compute_speedup": format_float(float(row["compute_speedup"])),
                "total_speedup": format_float(float(row["total_speedup"])),
                "compute_efficiency": format_float(float(row["compute_efficiency"])),
                "total_efficiency": format_float(float(row["total_efficiency"])),
                "communication_share": format_float(communication_time / total_time),
                "incremental_compute_speedup_gain": format_float(incremental_compute),
                "incremental_total_speedup_gain": format_float(incremental_total),
                "efficiency_band": efficiency_band(float(row["total_efficiency"])),
                "is_best_total_speedup": format_bool(int(row["P"]) == int(best_total_row["P"])),
                "is_regression_point": format_bool(is_regression_point),
            }
        )
        previous_row = row

    candidate_rows = sorted_rows
    if first_regression_p is not None:
        candidate_rows = [row for row in sorted_rows if int(row["P"]) < first_regression_p]

    efficiency_candidates = [row for row in candidate_rows if float(row["total_efficiency"]) >= 0.85]
    if efficiency_candidates:
        recommended_operating_row = max(efficiency_candidates, key=lambda row: int(row["P"]))
    else:
        recommended_operating_row = best_total_row

    if first_regression_p is not None:
        regression_row = next(row for row in sorted_rows if int(row["P"]) == first_regression_p)
        previous_regression_row = next(
            row for row in sorted_rows if int(row["P"]) < first_regression_p and int(row["P"]) == int(sorted_rows[sorted_rows.index(regression_row) - 1]["P"])
        )
        communication_breakdown_note = (
            f"Communication share stays manageable through P={int(previous_regression_row['P'])} and then rises to "
            f"{communication_time_fraction(regression_row):.2%} at P={first_regression_p}, which is also the first total-speedup regression point."
        )
    else:
        communication_breakdown_note = (
            "No total-speedup regression appears in the tested worker counts; communication share does not overtake the scaling gains inside the current sweep."
        )

    summary = {
        "best_total_speedup_p": int(best_total_row["P"]),
        "best_total_speedup": float(best_total_row["total_speedup"]),
        "best_compute_speedup_p": int(best_compute_row["P"]),
        "best_compute_speedup": float(best_compute_row["compute_speedup"]),
        "speedup_regression_p": first_regression_p,
        "recommended_operating_p": int(recommended_operating_row["P"]),
        "communication_breakdown_note": communication_breakdown_note,
    }
    return analysis_rows, summary


def communication_time_fraction(row: dict[str, float | int]) -> float:
    total_time = float(row["total_time"])
    if total_time <= 0.0:
        return 0.0
    return float(row["communication_time"]) / total_time


def analyze_faiss(rows: list[dict[str, float | int | str]]) -> tuple[list[dict[str, object]], dict[str, object]]:
    analysis_rows: list[dict[str, object]] = []
    worst_ratio_row = max(rows, key=lambda row: float(row["total_ratio"]))

    for row in rows:
        faiss_build_time = float(row["faiss_build_time"])
        faiss_compute_time = float(row["faiss_compute_time"])
        parallel_total_time = float(row["parallel_total_time"])
        parallel_communication_time = float(row["parallel_communication_time"])
        build_denominator = faiss_build_time + faiss_compute_time
        build_share = 0.0 if build_denominator <= 0.0 else faiss_build_time / build_denominator
        parallel_comm_share = 0.0 if parallel_total_time <= 0.0 else parallel_communication_time / parallel_total_time

        total_ratio = float(row["total_ratio"])
        if total_ratio <= 1.25:
            gap_class = "COMPETITIVE"
        elif total_ratio <= 2.50:
            gap_class = "MODERATE_GAP"
        else:
            gap_class = "LARGE_GAP"

        correctness_status = str(row["correctness_status"])
        if correctness_status == "PASS":
            if int(row["parallel_workers"]) > int(row["faiss_threads"]):
                report_positioning = (
                    "Exact-match correctness holds against the sequential reference. Treat FAISS as an external optimized single-node exact-flat baseline on the head node while the project result is a distributed MPI run, not as the project implementation target."
                )
            else:
                report_positioning = (
                    "Exact-match correctness holds against the sequential reference. Treat FAISS as an external optimized baseline, not as the project implementation target."
                )
        else:
            report_positioning = (
                "Correctness does not hold against the sequential reference yet, so timing comparisons to FAISS are only provisional."
            )

        analysis_rows.append(
            {
                "dataset_name": row["dataset_name"],
                "N": int(row["N"]),
                "D": int(row["D"]),
                "Q": int(row["Q"]),
                "k": int(row["k"]),
                "parallel_workers": int(row["parallel_workers"]),
                "faiss_threads": int(row["faiss_threads"]),
                "parallel_compute_time": format_float(float(row["parallel_compute_time"])),
                "parallel_communication_time": format_float(parallel_communication_time),
                "parallel_total_time": format_float(parallel_total_time),
                "faiss_build_time": format_float(faiss_build_time),
                "faiss_compute_time": format_float(faiss_compute_time),
                "faiss_total_time": format_float(float(row["faiss_total_time"])),
                "total_ratio": format_float(total_ratio),
                "correctness_status": correctness_status,
                "max_score_diff": format_float(float(row["max_score_diff"])),
                "build_share": format_float(build_share),
                "parallel_comm_share": format_float(parallel_comm_share),
                "gap_class": gap_class,
                "report_positioning": report_positioning,
            }
        )

    summary = {
        "dataset_count": len(rows),
        "worst_total_ratio_dataset": str(worst_ratio_row["dataset_name"]),
        "worst_total_ratio": float(worst_ratio_row["total_ratio"]),
    }
    return analysis_rows, summary


def skipped_faiss_summary() -> dict[str, object]:
    return {
        "status": "SKIPPED",
        "dataset_count": 0,
        "worst_total_ratio_dataset": "SKIPPED",
        "worst_total_ratio": 0.0,
    }


def build_final_conclusion(
    performance_conclusions_status: str,
    runtime_summary: dict[str, object],
    granularity_summary: dict[str, object],
    speedup_summary: dict[str, object],
    faiss_summary: dict[str, object],
    faiss_enabled: bool,
) -> str:
    if performance_conclusions_status != "VALID":
        return (
            "Correctness is not fully stable yet, so the benchmark run cannot support final performance claims. The next action is to fix correctness first, then rerun the full analysis."
        )

    runtime_status = str(runtime_summary["selected_target_status"])
    load_balance_status = str(granularity_summary["load_balance_status"])
    recommended_p = int(speedup_summary["recommended_operating_p"])
    if not faiss_enabled:
        if runtime_status == "UNDER_TARGET":
            return (
                f"The system is correct and scales to a practical operating point of P={recommended_p}, but the current workload still undershoots the intended 2-3 minute runtime target. "
                f"Load-balance classification is {load_balance_status}. This run intentionally skipped the external FAISS comparison and focuses on the sequential-vs-parallel benchmark story."
            )
        if runtime_status == "OVER_TARGET":
            return (
                f"The system is correct and scales to a practical operating point of P={recommended_p}, but the selected workload is already above the intended runtime target. "
                f"Load-balance classification is {load_balance_status}. This run intentionally skipped the external FAISS comparison and focuses on the sequential-vs-parallel benchmark story."
            )
        return (
            f"The system is correct, the selected workload sits inside the intended benchmark window, and the recommended operating point is P={recommended_p}. "
            f"Load-balance classification is {load_balance_status}. This run intentionally skipped the external FAISS comparison and focuses on the sequential-vs-parallel benchmark story."
        )

    worst_faiss_ratio = float(faiss_summary["worst_total_ratio"])
    if runtime_status == "UNDER_TARGET":
        return (
            f"The system is correct and scales to a practical operating point of P={recommended_p}, but the current workload still undershoots the intended 2-3 minute runtime target. "
            f"Load-balance classification is {load_balance_status}, and FAISS remains an external faster baseline with the largest observed total_ratio={worst_faiss_ratio:.2f}."
        )
    if runtime_status == "OVER_TARGET":
        return (
            f"The system is correct and scales to a practical operating point of P={recommended_p}, but the selected workload is already above the intended runtime target. "
            f"Load-balance classification is {load_balance_status}, and FAISS remains the faster external baseline with worst total_ratio={worst_faiss_ratio:.2f}."
        )
    return (
        f"The system is correct, the selected workload sits inside the intended benchmark window, and the recommended operating point is P={recommended_p}. "
        f"Load-balance classification is {load_balance_status}, while FAISS remains the faster external baseline with worst total_ratio={worst_faiss_ratio:.2f}."
    )


def prioritized_next_steps(calibration_mode: str, faiss_enabled: bool) -> list[str]:
    faiss_step = (
        "Priority 4: Treat FAISS as a realism baseline; do not promise to outperform it with the current exact blocking MPI design."
        if faiss_enabled
        else "Priority 4: FAISS comparison was skipped for this run; if an external baseline is needed later, execute the FAISS workflow separately."
    )

    if calibration_mode == "N_PLUS_Q":
        return [
            "Priority 1: Keep the current N ceiling explicit in the report; future runtime retuning should revisit memory capacity or sharding strategy before blindly increasing N again.",
            "Priority 2: Keep P_SELECTED near physical cores and stop treating 2X workers as a canonical operating point if a regression appears.",
            "Priority 3: Keep the report wording honest about load balance when idle-gap ratio is sensitive but absolute skew is tiny.",
            faiss_step,
            "Priority 5: If a future performance phase is approved, focus on communication reduction and orchestration improvements before adding new corpora.",
        ]

    return [
        "Priority 1: Make the runtime benchmark hit the intended 120-180 second target by expanding BENCH_N_CANDIDATES, then revisiting Q only if needed.",
        "Priority 2: Keep P_SELECTED near physical cores and stop treating 2X workers as a canonical operating point if a regression appears.",
        "Priority 3: Keep the report wording honest about load balance when idle-gap ratio is sensitive but absolute skew is tiny.",
        faiss_step,
        "Priority 5: If a future performance phase is approved, focus on communication reduction and orchestration improvements before adding new corpora.",
    ]


def render_markdown(
    title: str,
    performance_conclusions_status: str,
    runtime_summary: dict[str, object],
    correctness_summaries: dict[str, dict[str, object]],
    granularity_summary: dict[str, object],
    speedup_summary: dict[str, object],
    faiss_rows: list[dict[str, object]],
    faiss_enabled: bool,
    final_conclusion: str,
) -> str:
    sequential_correctness = correctness_summaries["sequential_vs_parallel"]

    next_steps_lines = "\n".join(
        f"{index}. {step}"
        for index, step in enumerate(
            prioritized_next_steps(str(runtime_summary["calibration_mode"]), faiss_enabled),
            start=1,
        )
    )

    if faiss_enabled:
        faiss_synthetic = correctness_summaries["faiss_synthetic"]
        faiss_squad = correctness_summaries["faiss_squad"]
        synthetic_faiss_row = next(row for row in faiss_rows if row["dataset_name"] == "synthetic")
        squad_faiss_row = next(row for row in faiss_rows if row["dataset_name"] == "squad_minilm")
        validity_evidence = (
            f"sequential-vs-parallel correctness checked {sequential_correctness['query_count']} queries with all_pass={str(sequential_correctness['all_pass']).lower()}, "
            f"FAISS synthetic all_pass={str(faiss_synthetic['all_pass']).lower()}, and FAISS squad all_pass={str(faiss_squad['all_pass']).lower()}."
        )
        correctness_evidence = (
            f"sequential-vs-parallel max_score_diff was `{float(sequential_correctness['max_score_diff']):.8f}`. "
            f"FAISS synthetic max_score_diff was `{float(faiss_synthetic['max_score_diff']):.8f}`. "
            f"FAISS squad max_score_diff was `{float(faiss_squad['max_score_diff']):.8f}`."
        )
        correctness_statement = (
            "The sequential baseline, MPI retriever, and maintained FAISS baselines all align under the current deterministic ordering and epsilon policy for this run."
        )
        faiss_section = f"""## 6. FAISS Comparison Findings

Evidence: synthetic total_ratio was `{synthetic_faiss_row['total_ratio']}` with gap_class `{synthetic_faiss_row['gap_class']}`; squad_minilm total_ratio was `{squad_faiss_row['total_ratio']}` with gap_class `{squad_faiss_row['gap_class']}`.

Report-ready statement: {synthetic_faiss_row['report_positioning']}

Do not overclaim: FAISS is an optimized external CPU exact-flat baseline, so the project should frame this result as realism-oriented comparison rather than a requirement to outperform FAISS.
"""
    else:
        validity_evidence = (
            f"sequential-vs-parallel correctness checked {sequential_correctness['query_count']} queries with all_pass={str(sequential_correctness['all_pass']).lower()}. "
            "FAISS comparison was skipped for this run."
        )
        correctness_evidence = (
            f"sequential-vs-parallel max_score_diff was `{float(sequential_correctness['max_score_diff']):.8f}`. "
            "No FAISS correctness CSVs were generated because FAISS comparison was skipped for this run."
        )
        correctness_statement = (
            "The sequential baseline and MPI retriever align under the current deterministic ordering and epsilon policy for this run."
        )
        faiss_section = """## 6. FAISS Comparison Status

Evidence: no `results/faiss/` comparison artifacts were provided for this run.

Report-ready statement: FAISS comparison was skipped for this run, so the current review focuses on the in-repo sequential-vs-parallel benchmark story only.

Do not overclaim: without the external baseline artifacts, this review cannot make any cross-system timing claim against FAISS.
"""

    return f"""# {title}

## 1. Benchmark Validity Check

Evidence: {validity_evidence}

Report-ready statement: The benchmark validity status for this run is `{performance_conclusions_status}`.

Do not overclaim: if the status is not `VALID`, treat all performance numbers as provisional until correctness is repaired and the benchmark is rerun.

## 2. Runtime-by-N Findings

    Evidence: `N_SELECTED={runtime_summary['selected_n']}` and `Q={runtime_summary['selected_q']}` produced `total_time={float(runtime_summary['selected_total_time']):.8f}` seconds with target status `{runtime_summary['selected_target_status']}`. The largest tested N was `{runtime_summary['max_tested_n']}` with `total_time={float(runtime_summary['max_tested_total_time']):.8f}` seconds under the initial N sweep.

Report-ready statement: {runtime_summary['overall_recommendation']}

Do not overclaim: selecting the closest available N is not the same as actually hitting the intended 120-180 second benchmark window.

## 3. Correctness Findings

Evidence: {correctness_evidence}

Report-ready statement: {correctness_statement}

Do not overclaim: correctness here means exact agreement on the same vector inputs, not proof of semantic relevance against external text labels.

## 4. Granularity/Load-Balance Findings

Evidence: `local_N` ranged from `{granularity_summary['local_n_min']}` to `{granularity_summary['local_n_max']}`, `compute_cv={float(granularity_summary['compute_cv']):.8f}`, `active_cv={float(granularity_summary['active_cv']):.8f}`, and `idle_relative_gap={float(granularity_summary['idle_relative_gap']):.8f}`.

Report-ready statement: The current load-balance classification is `{granularity_summary['load_balance_status']}`.

Do not overclaim: a large relative idle-gap ratio can coexist with tiny absolute skew, so this signal must be interpreted together with `absolute_idle_spread` and the per-rank active times.

## 5. Speedup Findings

Evidence: the best total speedup appeared at `P={speedup_summary['best_total_speedup_p']}` with `total_speedup={float(speedup_summary['best_total_speedup']):.8f}`; the first total-speedup regression appeared at `P={speedup_summary['speedup_regression_p']}`; the recommended operating point is `P={speedup_summary['recommended_operating_p']}`.

Report-ready statement: {speedup_summary['communication_breakdown_note']}

Do not overclaim: the highest tested worker count is not automatically the best operating point once communication starts eroding total speedup.

{faiss_section}

## 7. Final Conclusion

Evidence: runtime status was `{runtime_summary['selected_target_status']}`, load-balance status was `{granularity_summary['load_balance_status']}`, and recommended operating point was `P={speedup_summary['recommended_operating_p']}`.

Report-ready statement: {final_conclusion}

Do not overclaim: this conclusion is only about the current exact retrieval kernel and benchmark setup, not a general claim about all retrieval systems or ANN baselines.

## 8. Recommended Next Steps

Evidence: the current benchmark layer now supports deterministic reruns, derived analysis CSVs, JSON summaries, and report-ready Markdown output.

Report-ready statement:

{next_steps_lines}

Do not overclaim: these next steps are prioritized for the current repo direction and should be revised only if the project scope or benchmark policy changes.
"""


def write_analysis_docs(
    output_dir: Path,
    docs_output: Path,
    markdown_body: str,
) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    docs_output.parent.mkdir(parents=True, exist_ok=True)
    (output_dir / "final_conclusions.md").write_text(markdown_body, encoding="utf-8")
    docs_output.write_text(markdown_body, encoding="utf-8")


def main() -> int:
    args = parse_args()
    results_dir = args.results_dir.expanduser().resolve()
    output_dir = args.output_dir.expanduser().resolve()
    docs_output = args.docs_output.expanduser().resolve()

    required_files = {
        "runtime_by_n": results_dir / "runtime_by_N.csv",
        "correctness": results_dir / "correctness.csv",
        "granularity": results_dir / "granularity.csv",
        "speedup": results_dir / "speedup.csv",
        "selection_manifest": results_dir / "benchmark_selection.env",
    }
    optional_faiss_files = {
        "faiss_comparison": results_dir / "faiss" / "comparison.csv",
        "faiss_synthetic_correctness": results_dir / "faiss" / "synthetic_correctness.csv",
        "faiss_squad_correctness": results_dir / "faiss" / "squad_correctness.csv",
    }

    try:
        for path in required_files.values():
            require_file(path)

        faiss_mode = detect_faiss_input_mode(optional_faiss_files)
        faiss_enabled = faiss_mode == "present"
        manifest = parse_manifest(required_files["selection_manifest"])
        selected_n = int(manifest["N_SELECTED"])

        runtime_rows = read_run_metrics_table(required_files["runtime_by_n"])
        granularity_rows = read_granularity_table(required_files["granularity"])
        speedup_rows = read_speedup_table(required_files["speedup"])
        faiss_rows = read_faiss_comparison_table(optional_faiss_files["faiss_comparison"]) if faiss_enabled else []

        granularity_analysis_rows, granularity_summary = analyze_granularity(granularity_rows)
        runtime_analysis_rows, runtime_summary = analyze_runtime(
            runtime_rows,
            manifest,
            granularity_summary["global_total_time"]
            if manifest.get("CALIBRATION_MODE", "N_ONLY") == "N_PLUS_Q"
            else None,
        )
        speedup_analysis_rows, speedup_summary = analyze_speedup(speedup_rows)
        if faiss_enabled:
            faiss_analysis_rows, faiss_summary = analyze_faiss(faiss_rows)
        else:
            faiss_analysis_rows = []
            faiss_summary = skipped_faiss_summary()

        correctness_summaries = {"sequential_vs_parallel": read_correctness_summary(required_files["correctness"])}
        if faiss_enabled:
            correctness_summaries["faiss_synthetic"] = read_correctness_summary(optional_faiss_files["faiss_synthetic_correctness"])
            correctness_summaries["faiss_squad"] = read_correctness_summary(optional_faiss_files["faiss_squad_correctness"])

        all_correct = all(bool(summary["all_pass"]) for summary in correctness_summaries.values())
        performance_conclusions_status = "VALID" if all_correct else "INVALID_UNTIL_CORRECTNESS_FIXED"

        final_conclusion = build_final_conclusion(
            performance_conclusions_status,
            runtime_summary,
            granularity_summary,
            speedup_summary,
            faiss_summary,
            faiss_enabled,
        )

        benchmark_summary = {
            "analysis_version": 1,
            "performance_conclusions_status": performance_conclusions_status,
            "inputs": {
                **{key: str(path) for key, path in required_files.items()},
                **{key: str(path) for key, path in optional_faiss_files.items() if faiss_enabled},
            },
            "selection_manifest": manifest,
            "runtime": runtime_summary,
            "correctness": correctness_summaries,
            "granularity": granularity_summary,
            "speedup": speedup_summary,
            "faiss": faiss_summary,
            "final_conclusion": final_conclusion,
            "next_steps": prioritized_next_steps(str(runtime_summary["calibration_mode"]), faiss_enabled),
            "project_framing": (
                "The project is valuable as an exact distributed retrieval kernel and benchmarked parallel-computing exercise: it is correctness-gated and it exposes measurable scaling behavior."
                if not faiss_enabled
                else "The project is valuable as an exact distributed retrieval kernel and benchmarked parallel-computing exercise: it is correctness-gated, it exposes measurable scaling behavior, and it can now be compared honestly against an external FAISS baseline."
            ),
        }

        write_csv(output_dir / "runtime_analysis.csv", RUNTIME_ANALYSIS_FIELDS, runtime_analysis_rows)
        write_csv(output_dir / "granularity_analysis.csv", GRANULARITY_ANALYSIS_FIELDS, granularity_analysis_rows)
        write_csv(output_dir / "speedup_analysis.csv", SPEEDUP_ANALYSIS_FIELDS, speedup_analysis_rows)
        write_csv(output_dir / "faiss_analysis.csv", FAISS_ANALYSIS_FIELDS, faiss_analysis_rows)
        (output_dir / "benchmark_summary.json").write_text(
            json.dumps(benchmark_summary, indent=2),
            encoding="utf-8",
        )

        markdown_body = render_markdown(
            "Latest Benchmark Review",
            performance_conclusions_status,
            runtime_summary,
            correctness_summaries,
            granularity_summary,
            speedup_summary,
            faiss_analysis_rows,
            faiss_enabled,
            final_conclusion,
        )
        write_analysis_docs(output_dir, docs_output, markdown_body)

        print(f"Wrote {output_dir / 'runtime_analysis.csv'}")
        print(f"Wrote {output_dir / 'granularity_analysis.csv'}")
        print(f"Wrote {output_dir / 'speedup_analysis.csv'}")
        print(f"Wrote {output_dir / 'faiss_analysis.csv'}")
        print(f"Wrote {output_dir / 'benchmark_summary.json'}")
        print(f"Wrote {output_dir / 'final_conclusions.md'}")
        print(f"Wrote {docs_output}")
        return 0
    except Exception as exc:  # noqa: BLE001
        print(f"Error: {exc}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
