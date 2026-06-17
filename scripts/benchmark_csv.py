#!/usr/bin/env python3

from __future__ import annotations

import argparse
import csv
from pathlib import Path

RUN_METRICS_FIELDS = [
    "N",
    "D",
    "Q",
    "k",
    "P",
    "compute_time",
    "communication_time",
    "total_time",
]

SPEEDUP_FIELDS = [
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
]

GRANULARITY_FIELDS = [
    "rank",
    "local_N",
    "compute_time",
    "communication_time",
    "active_time",
    "global_total_time",
    "idle_time",
]

CORRECTNESS_FIELDS = [
    "query_id",
    "k",
    "matched",
    "matched_ids",
    "max_score_diff",
    "status",
]

FAISS_RUN_METRICS_FIELDS = [
    "dataset_name",
    "N",
    "D",
    "Q",
    "k",
    "threads",
    "build_time",
    "compute_time",
    "total_time",
]

FAISS_COMPARISON_FIELDS = [
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
]


def parse_run_metrics_row(raw_row: dict[str, str]) -> dict[str, float | int]:
    return {
        "N": int(raw_row["N"]),
        "D": int(raw_row["D"]),
        "Q": int(raw_row["Q"]),
        "k": int(raw_row["k"]),
        "P": int(raw_row["P"]),
        "compute_time": float(raw_row["compute_time"]),
        "communication_time": float(raw_row["communication_time"]),
        "total_time": float(raw_row["total_time"]),
    }


def parse_faiss_run_metrics_row(raw_row: dict[str, str]) -> dict[str, float | int | str]:
    return {
        "dataset_name": raw_row["dataset_name"],
        "N": int(raw_row["N"]),
        "D": int(raw_row["D"]),
        "Q": int(raw_row["Q"]),
        "k": int(raw_row["k"]),
        "threads": int(raw_row["threads"]),
        "build_time": float(raw_row["build_time"]),
        "compute_time": float(raw_row["compute_time"]),
        "total_time": float(raw_row["total_time"]),
    }


def format_float(value: float) -> str:
    return f"{value:.8f}"


def read_csv_rows(path: Path, expected_fields: list[str]) -> list[dict[str, str]]:
    with path.open("r", newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        if reader.fieldnames != expected_fields:
            raise RuntimeError(
                f"Unexpected CSV header in {path}: {reader.fieldnames} != {expected_fields}"
            )
        return list(reader)


def read_single_run_metrics(path: Path) -> dict[str, float | int]:
    rows = read_csv_rows(path, RUN_METRICS_FIELDS)
    if len(rows) != 1:
        raise RuntimeError(f"Expected exactly one run metrics row in {path}, found {len(rows)}")
    return parse_run_metrics_row(rows[0])


def read_single_faiss_run_metrics(path: Path) -> dict[str, float | int | str]:
    rows = read_csv_rows(path, FAISS_RUN_METRICS_FIELDS)
    if len(rows) != 1:
        raise RuntimeError(f"Expected exactly one FAISS run metrics row in {path}, found {len(rows)}")
    return parse_faiss_run_metrics_row(rows[0])


def read_correctness_summary(path: Path) -> dict[str, float | str]:
    rows = read_csv_rows(path, CORRECTNESS_FIELDS)
    if not rows:
        raise RuntimeError(f"No correctness rows available in {path}")

    status = "PASS"
    max_score_diff = 0.0
    for row in rows:
        if row["status"] != "PASS":
            status = "FAIL"
        max_score_diff = max(max_score_diff, float(row["max_score_diff"]))

    return {
        "correctness_status": status,
        "max_score_diff": max_score_diff,
    }


def write_run_metrics_table(path: Path, rows: list[dict[str, float | int]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=RUN_METRICS_FIELDS)
        writer.writeheader()
        for row in rows:
            writer.writerow(
                {
                    "N": row["N"],
                    "D": row["D"],
                    "Q": row["Q"],
                    "k": row["k"],
                    "P": row["P"],
                    "compute_time": format_float(float(row["compute_time"])),
                    "communication_time": format_float(float(row["communication_time"])),
                    "total_time": format_float(float(row["total_time"])),
                }
            )


def merge_run_metrics(inputs: list[Path], output: Path) -> None:
    rows = [read_single_run_metrics(path) for path in inputs]
    rows.sort(key=lambda row: (int(row["N"]), int(row["P"])))
    write_run_metrics_table(output, rows)


def choose_target_row(
    rows: list[dict[str, float | int]],
    key_field: str,
    target_lower: float,
    target_upper: float,
) -> tuple[dict[str, float | int], bool]:
    within_range = [row for row in rows if target_lower <= float(row["total_time"]) <= target_upper]
    if within_range:
        return min(within_range, key=lambda row: int(row[key_field])), True

    return min(
        rows,
        key=lambda row: (abs(float(row["total_time"]) - 150.0), int(row[key_field])),
    ), False


def has_row_in_target(rows: list[dict[str, float | int]], target_lower: float, target_upper: float) -> bool:
    return any(target_lower <= float(row["total_time"]) <= target_upper for row in rows)


def resolve_calibration_context(
    n_rows: list[dict[str, float | int]],
    q_rows: list[dict[str, float | int]] | None,
    target_lower: float,
    target_upper: float,
) -> dict[str, int | str]:
    if not n_rows:
        raise RuntimeError("N sweep requires at least one successful runtime row")

    n_selected_row, n_only_hit = choose_target_row(n_rows, "N", target_lower, target_upper)
    n_max_feasible = max(int(row["N"]) for row in n_rows)

    if n_only_hit:
        return {
            "N_SELECTED": int(n_selected_row["N"]),
            "Q_SELECTED": int(n_selected_row["Q"]),
            "D": int(n_selected_row["D"]),
            "K": int(n_selected_row["k"]),
            "CALIBRATION_MODE": "N_ONLY",
            "N_MAX_FEASIBLE": n_max_feasible,
        }

    if not q_rows:
        raise RuntimeError("Q sweep rows are required when N-only calibration does not hit the target window")

    q_selected_row, _ = choose_target_row(q_rows, "Q", target_lower, target_upper)
    return {
        "N_SELECTED": n_max_feasible,
        "Q_SELECTED": int(q_selected_row["Q"]),
        "D": int(q_selected_row["D"]),
        "K": int(q_selected_row["k"]),
        "CALIBRATION_MODE": "N_PLUS_Q",
        "N_MAX_FEASIBLE": n_max_feasible,
    }


def select_speedup_n(
    rows: list[dict[str, float | int]],
    max_total_time: float,
) -> int:
    if not rows:
        raise RuntimeError("speedup probe rows are required")

    sorted_rows = sorted(rows, key=lambda row: int(row["N"]))
    fitting_rows = [row for row in sorted_rows if float(row["total_time"]) <= max_total_time]
    if fitting_rows:
        return int(fitting_rows[-1]["N"])
    return int(sorted_rows[0]["N"])


def print_calibration_context(
    n_input: Path,
    q_input: Path | None,
    target_lower: float,
    target_upper: float,
) -> None:
    n_rows = [parse_run_metrics_row(row) for row in read_csv_rows(n_input, RUN_METRICS_FIELDS)]
    q_rows = None
    if q_input is not None:
        q_rows = [parse_run_metrics_row(row) for row in read_csv_rows(q_input, RUN_METRICS_FIELDS)]

    context = resolve_calibration_context(n_rows, q_rows, target_lower, target_upper)
    print(f"N_SELECTED={int(context['N_SELECTED'])}")
    print(f"Q_SELECTED={int(context['Q_SELECTED'])}")
    print(f"D={int(context['D'])}")
    print(f"K={int(context['K'])}")
    print(f"CALIBRATION_MODE={context['CALIBRATION_MODE']}")
    print(f"N_MAX_FEASIBLE={int(context['N_MAX_FEASIBLE'])}")


def write_calibration_manifest(
    n_input: Path,
    q_input: Path | None,
    speedup_input: Path,
    output_env: Path,
    target_lower: float,
    target_upper: float,
    p_selected: int,
    epsilon: str,
    speedup_baseline_limit: float,
) -> None:
    n_rows = [parse_run_metrics_row(row) for row in read_csv_rows(n_input, RUN_METRICS_FIELDS)]
    q_rows = None
    if q_input is not None:
        q_rows = [parse_run_metrics_row(row) for row in read_csv_rows(q_input, RUN_METRICS_FIELDS)]

    context = resolve_calibration_context(n_rows, q_rows, target_lower, target_upper)
    speedup_rows = [parse_run_metrics_row(row) for row in read_csv_rows(speedup_input, RUN_METRICS_FIELDS)]

    expected_q = int(context["Q_SELECTED"])
    expected_d = int(context["D"])
    expected_k = int(context["K"])
    for row in speedup_rows:
        if int(row["Q"]) != expected_q or int(row["D"]) != expected_d or int(row["k"]) != expected_k:
            raise RuntimeError("speedup probe rows must match the calibrated D, Q, and k values")

    n_speedup = select_speedup_n(speedup_rows, speedup_baseline_limit)

    output_env.parent.mkdir(parents=True, exist_ok=True)
    with output_env.open("w", encoding="utf-8") as handle:
        handle.write(f"N_SELECTED={int(context['N_SELECTED'])}\n")
        handle.write(f"N_SPEEDUP={n_speedup}\n")
        handle.write(f"P_SELECTED={p_selected}\n")
        handle.write(f"D={expected_d}\n")
        handle.write(f"Q={expected_q}\n")
        handle.write(f"K={expected_k}\n")
        handle.write(f"EPSILON={epsilon}\n")
        handle.write(f"CALIBRATION_MODE={context['CALIBRATION_MODE']}\n")
        handle.write(f"N_MAX_FEASIBLE={int(context['N_MAX_FEASIBLE'])}\n")


def row_in_target(input_path: Path, target_lower: float, target_upper: float) -> int:
    rows = [parse_run_metrics_row(row) for row in read_csv_rows(input_path, RUN_METRICS_FIELDS)]
    return 0 if has_row_in_target(rows, target_lower, target_upper) else 1


def select_n(
    input_path: Path,
    output_env: Path,
    target_lower: float,
    target_upper: float,
    p_selected: int,
    epsilon: str,
) -> None:
    rows = [parse_run_metrics_row(row) for row in read_csv_rows(input_path, RUN_METRICS_FIELDS)]
    if not rows:
        raise RuntimeError(f"No rows available in {input_path}")

    selected, _ = choose_target_row(rows, "N", target_lower, target_upper)

    output_env.parent.mkdir(parents=True, exist_ok=True)
    with output_env.open("w", encoding="utf-8") as handle:
        handle.write(f"N_SELECTED={int(selected['N'])}\n")
        handle.write(f"N_SPEEDUP={int(selected['N']) * 2}\n")
        handle.write(f"P_SELECTED={p_selected}\n")
        handle.write(f"D={int(selected['D'])}\n")
        handle.write(f"Q={int(selected['Q'])}\n")
        handle.write(f"K={int(selected['k'])}\n")
        handle.write(f"EPSILON={epsilon}\n")


def build_speedup(baseline_path: Path, input_paths: list[Path], output: Path) -> None:
    baseline = read_single_run_metrics(baseline_path)
    if int(baseline["P"]) != 1:
        raise RuntimeError("Baseline run metrics row must use P=1")

    rows: list[dict[str, float | int]] = []
    candidate_rows = [baseline]
    candidate_rows.extend(read_single_run_metrics(path) for path in input_paths)

    for candidate in candidate_rows:
        if int(candidate["P"]) == 1 and candidate is not baseline:
            continue
        for field_name in ("N", "D", "Q", "k"):
            if int(candidate[field_name]) != int(baseline[field_name]):
                raise RuntimeError(f"Mismatched {field_name} between baseline and candidate rows")

        compute_time = float(candidate["compute_time"])
        total_time = float(candidate["total_time"])
        if compute_time <= 0.0 or total_time <= 0.0:
            raise RuntimeError("Run metrics times must be positive to build speedup rows")

        rows.append(
            {
                "N": int(candidate["N"]),
                "D": int(candidate["D"]),
                "Q": int(candidate["Q"]),
                "k": int(candidate["k"]),
                "P": int(candidate["P"]),
                "compute_time": compute_time,
                "communication_time": float(candidate["communication_time"]),
                "total_time": total_time,
                "compute_speedup": float(baseline["compute_time"]) / compute_time,
                "total_speedup": float(baseline["total_time"]) / total_time,
                "compute_efficiency": (float(baseline["compute_time"]) / compute_time) / int(candidate["P"]),
                "total_efficiency": (float(baseline["total_time"]) / total_time) / int(candidate["P"]),
            }
        )

    rows.sort(key=lambda row: int(row["P"]))
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=SPEEDUP_FIELDS)
        writer.writeheader()
        for row in rows:
            writer.writerow(
                {
                    "N": row["N"],
                    "D": row["D"],
                    "Q": row["Q"],
                    "k": row["k"],
                    "P": row["P"],
                    "compute_time": format_float(float(row["compute_time"])),
                    "communication_time": format_float(float(row["communication_time"])),
                    "total_time": format_float(float(row["total_time"])),
                    "compute_speedup": format_float(float(row["compute_speedup"])),
                    "total_speedup": format_float(float(row["total_speedup"])),
                    "compute_efficiency": format_float(float(row["compute_efficiency"])),
                    "total_efficiency": format_float(float(row["total_efficiency"])),
                }
            )


def build_faiss_comparison(
    parallel_metric_paths: list[Path],
    faiss_metric_paths: list[Path],
    correctness_paths: list[Path],
    output: Path,
) -> None:
    if not parallel_metric_paths or not faiss_metric_paths or not correctness_paths:
        raise RuntimeError("build-faiss-comparison requires at least one metrics/correctness trio")
    if not (
        len(parallel_metric_paths) == len(faiss_metric_paths) == len(correctness_paths)
    ):
        raise RuntimeError("parallel-metrics, faiss-metrics, and correctness must have the same count")

    rows: list[dict[str, float | int | str]] = []
    for parallel_path, faiss_path, correctness_path in zip(
        parallel_metric_paths,
        faiss_metric_paths,
        correctness_paths,
        strict=True,
    ):
        parallel_metrics = read_single_run_metrics(parallel_path)
        faiss_metrics = read_single_faiss_run_metrics(faiss_path)
        correctness_summary = read_correctness_summary(correctness_path)

        for field_name in ("N", "D", "Q", "k"):
            if int(parallel_metrics[field_name]) != int(faiss_metrics[field_name]):
                raise RuntimeError(
                    f"Mismatched {field_name} between parallel and FAISS metrics: "
                    f"{parallel_path} vs {faiss_path}"
                )

        if int(parallel_metrics["P"]) <= 0:
            raise RuntimeError(f"parallel worker count must be positive: {parallel_path}")
        if int(faiss_metrics["threads"]) <= 0:
            raise RuntimeError(f"FAISS thread count must be positive: {faiss_path}")
        if float(parallel_metrics["total_time"]) <= 0.0 or float(faiss_metrics["total_time"]) <= 0.0:
            raise RuntimeError("total_time must be positive to build FAISS comparison rows")

        rows.append(
            {
                "dataset_name": str(faiss_metrics["dataset_name"]),
                "N": int(faiss_metrics["N"]),
                "D": int(faiss_metrics["D"]),
                "Q": int(faiss_metrics["Q"]),
                "k": int(faiss_metrics["k"]),
                "parallel_workers": int(parallel_metrics["P"]),
                "faiss_threads": int(faiss_metrics["threads"]),
                "parallel_compute_time": float(parallel_metrics["compute_time"]),
                "parallel_communication_time": float(parallel_metrics["communication_time"]),
                "parallel_total_time": float(parallel_metrics["total_time"]),
                "faiss_build_time": float(faiss_metrics["build_time"]),
                "faiss_compute_time": float(faiss_metrics["compute_time"]),
                "faiss_total_time": float(faiss_metrics["total_time"]),
                "total_ratio": float(parallel_metrics["total_time"]) / float(faiss_metrics["total_time"]),
                "correctness_status": str(correctness_summary["correctness_status"]),
                "max_score_diff": float(correctness_summary["max_score_diff"]),
            }
        )

    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=FAISS_COMPARISON_FIELDS)
        writer.writeheader()
        for row in rows:
            writer.writerow(
                {
                    "dataset_name": row["dataset_name"],
                    "N": row["N"],
                    "D": row["D"],
                    "Q": row["Q"],
                    "k": row["k"],
                    "parallel_workers": row["parallel_workers"],
                    "faiss_threads": row["faiss_threads"],
                    "parallel_compute_time": format_float(float(row["parallel_compute_time"])),
                    "parallel_communication_time": format_float(float(row["parallel_communication_time"])),
                    "parallel_total_time": format_float(float(row["parallel_total_time"])),
                    "faiss_build_time": format_float(float(row["faiss_build_time"])),
                    "faiss_compute_time": format_float(float(row["faiss_compute_time"])),
                    "faiss_total_time": format_float(float(row["faiss_total_time"])),
                    "total_ratio": format_float(float(row["total_ratio"])),
                    "correctness_status": row["correctness_status"],
                    "max_score_diff": format_float(float(row["max_score_diff"])),
                }
            )


def summarize_granularity(input_path: Path, output_path: Path | None) -> str:
    rows = read_csv_rows(input_path, GRANULARITY_FIELDS)
    if not rows:
        raise RuntimeError(f"No rows available in {input_path}")

    idle_times = [float(row["idle_time"]) for row in rows]
    max_idle = max(idle_times)
    min_idle = min(idle_times)
    relative_gap = 0.0 if max_idle <= 1e-12 else (max_idle - min_idle) / max_idle
    balanced = relative_gap <= 0.25
    verdict = "BALANCED" if balanced else "UNBALANCED"

    message = (
        f"Load balancing verdict: {verdict}\n"
        f"idle_time_relative_gap={relative_gap:.8f}\n"
        f"max_idle_time={max_idle:.8f}\n"
        f"min_idle_time={min_idle:.8f}\n"
    )

    if output_path is not None:
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(message, encoding="utf-8")

    return message


def main() -> None:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)

    merge_parser = subparsers.add_parser("merge-run-metrics")
    merge_parser.add_argument("--output", required=True, type=Path)
    merge_parser.add_argument("inputs", nargs="+", type=Path)

    select_parser = subparsers.add_parser("select-n")
    select_parser.add_argument("--input", required=True, type=Path)
    select_parser.add_argument("--output-env", required=True, type=Path)
    select_parser.add_argument("--target-lower", type=float, default=120.0)
    select_parser.add_argument("--target-upper", type=float, default=180.0)
    select_parser.add_argument("--p-selected", type=int, required=True)
    select_parser.add_argument("--epsilon", required=True)

    row_in_target_parser = subparsers.add_parser("row-in-target")
    row_in_target_parser.add_argument("--input", required=True, type=Path)
    row_in_target_parser.add_argument("--target-lower", type=float, default=120.0)
    row_in_target_parser.add_argument("--target-upper", type=float, default=180.0)

    print_calibration_parser = subparsers.add_parser("print-calibration-context")
    print_calibration_parser.add_argument("--n-input", required=True, type=Path)
    print_calibration_parser.add_argument("--q-input", type=Path)
    print_calibration_parser.add_argument("--target-lower", type=float, default=120.0)
    print_calibration_parser.add_argument("--target-upper", type=float, default=180.0)

    write_calibration_parser = subparsers.add_parser("write-calibration-manifest")
    write_calibration_parser.add_argument("--n-input", required=True, type=Path)
    write_calibration_parser.add_argument("--q-input", type=Path)
    write_calibration_parser.add_argument("--speedup-input", required=True, type=Path)
    write_calibration_parser.add_argument("--output-env", required=True, type=Path)
    write_calibration_parser.add_argument("--target-lower", type=float, default=120.0)
    write_calibration_parser.add_argument("--target-upper", type=float, default=180.0)
    write_calibration_parser.add_argument("--p-selected", type=int, required=True)
    write_calibration_parser.add_argument("--epsilon", required=True)
    write_calibration_parser.add_argument("--speedup-baseline-limit", type=float, default=600.0)

    speedup_parser = subparsers.add_parser("build-speedup")
    speedup_parser.add_argument("--baseline", required=True, type=Path)
    speedup_parser.add_argument("--output", required=True, type=Path)
    speedup_parser.add_argument("inputs", nargs="*", type=Path)

    faiss_comparison_parser = subparsers.add_parser("build-faiss-comparison")
    faiss_comparison_parser.add_argument("--output", required=True, type=Path)
    faiss_comparison_parser.add_argument("--parallel-metrics", action="append", required=True, type=Path)
    faiss_comparison_parser.add_argument("--faiss-metrics", action="append", required=True, type=Path)
    faiss_comparison_parser.add_argument("--correctness", action="append", required=True, type=Path)

    granularity_parser = subparsers.add_parser("summarize-granularity")
    granularity_parser.add_argument("--input", required=True, type=Path)
    granularity_parser.add_argument("--output", type=Path)

    args = parser.parse_args()

    if args.command == "merge-run-metrics":
        merge_run_metrics(args.inputs, args.output)
        return

    if args.command == "select-n":
        select_n(
            args.input,
            args.output_env,
            args.target_lower,
            args.target_upper,
            args.p_selected,
            args.epsilon,
        )
        return

    if args.command == "row-in-target":
        raise SystemExit(row_in_target(args.input, args.target_lower, args.target_upper))

    if args.command == "print-calibration-context":
        print_calibration_context(
            args.n_input,
            args.q_input,
            args.target_lower,
            args.target_upper,
        )
        return

    if args.command == "write-calibration-manifest":
        write_calibration_manifest(
            args.n_input,
            args.q_input,
            args.speedup_input,
            args.output_env,
            args.target_lower,
            args.target_upper,
            args.p_selected,
            args.epsilon,
            args.speedup_baseline_limit,
        )
        return

    if args.command == "build-speedup":
        build_speedup(args.baseline, args.inputs, args.output)
        return

    if args.command == "build-faiss-comparison":
        build_faiss_comparison(
            args.parallel_metrics,
            args.faiss_metrics,
            args.correctness,
            args.output,
        )
        return

    if args.command == "summarize-granularity":
        print(summarize_granularity(args.input, args.output), end="")
        return

    raise RuntimeError(f"Unhandled command: {args.command}")


if __name__ == "__main__":
    main()
