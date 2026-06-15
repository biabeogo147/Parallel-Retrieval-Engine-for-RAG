#!/usr/bin/env python3

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


def select_n(input_path: Path, output_env: Path, target_lower: float, target_upper: float, p_selected: int, epsilon: str) -> None:
    rows = [parse_run_metrics_row(row) for row in read_csv_rows(input_path, RUN_METRICS_FIELDS)]
    if not rows:
        raise RuntimeError(f"No rows available in {input_path}")

    within_range = [row for row in rows if target_lower <= float(row["total_time"]) <= target_upper]
    if within_range:
        selected = min(within_range, key=lambda row: int(row["N"]))
    else:
        selected = min(
            rows,
            key=lambda row: (abs(float(row["total_time"]) - 150.0), int(row["N"])),
        )

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

    speedup_parser = subparsers.add_parser("build-speedup")
    speedup_parser.add_argument("--baseline", required=True, type=Path)
    speedup_parser.add_argument("--output", required=True, type=Path)
    speedup_parser.add_argument("inputs", nargs="*", type=Path)

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

    if args.command == "build-speedup":
        build_speedup(args.baseline, args.inputs, args.output)
        return

    if args.command == "summarize-granularity":
        print(summarize_granularity(args.input, args.output), end="")
        return

    raise RuntimeError(f"Unhandled command: {args.command}")


if __name__ == "__main__":
    main()
