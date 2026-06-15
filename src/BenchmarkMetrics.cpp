#include "BenchmarkMetrics.hpp"

#include <algorithm>
#include <fstream>
#include <iomanip>
#include <stdexcept>
#include <string>

namespace retriever {
namespace {

void validate_positive_dimensions(
    const std::uint64_t N,
    const std::uint32_t D,
    const std::uint64_t Q,
    const int k,
    const int P) {
    if (N == 0) {
        throw std::runtime_error("N must be greater than 0");
    }
    if (D == 0) {
        throw std::runtime_error("D must be greater than 0");
    }
    if (Q == 0) {
        throw std::runtime_error("Q must be greater than 0");
    }
    if (k < 1) {
        throw std::runtime_error("k must be at least 1");
    }
    if (P < 1) {
        throw std::runtime_error("P must be at least 1");
    }
}

void validate_non_negative_time(const double value, const std::string& field_name) {
    if (value < 0.0) {
        throw std::runtime_error(field_name + " must be non-negative");
    }
}

}  // namespace

RunMetricsRow make_sequential_run_metrics(
    const std::uint64_t N,
    const std::uint32_t D,
    const std::uint64_t Q,
    const int k,
    const double compute_time,
    const double total_time) {
    validate_positive_dimensions(N, D, Q, k, 1);
    validate_non_negative_time(compute_time, "compute_time");
    validate_non_negative_time(total_time, "total_time");

    RunMetricsRow row;
    row.N = N;
    row.D = D;
    row.Q = Q;
    row.k = k;
    row.P = 1;
    row.compute_time = compute_time;
    row.communication_time = 0.0;
    row.total_time = total_time;
    return row;
}

RunMetricsRow make_parallel_run_metrics(
    const std::uint64_t N,
    const std::uint32_t D,
    const std::uint64_t Q,
    const int k,
    const int P,
    const std::vector<ParallelRankMetrics>& rank_metrics) {
    validate_positive_dimensions(N, D, Q, k, P);
    if (rank_metrics.empty()) {
        throw std::runtime_error("rank metrics must not be empty");
    }

    double max_compute_time = 0.0;
    double max_communication_time = 0.0;
    double global_total_time = 0.0;

    for (const auto& metric : rank_metrics) {
        max_compute_time = std::max(max_compute_time, metric.compute_time);
        max_communication_time = std::max(max_communication_time, metric.communication_time);
        global_total_time = std::max(global_total_time, metric.global_total_time);
    }

    RunMetricsRow row;
    row.N = N;
    row.D = D;
    row.Q = Q;
    row.k = k;
    row.P = P;
    row.compute_time = max_compute_time;
    row.communication_time = max_communication_time;
    row.total_time = global_total_time;
    return row;
}

SpeedupRow make_speedup_row(
    const RunMetricsRow& baseline,
    const RunMetricsRow& candidate) {
    if (baseline.N != candidate.N) {
        throw std::runtime_error("N must match between baseline and candidate rows");
    }
    if (baseline.D != candidate.D) {
        throw std::runtime_error("D must match between baseline and candidate rows");
    }
    if (baseline.Q != candidate.Q) {
        throw std::runtime_error("Q must match between baseline and candidate rows");
    }
    if (baseline.k != candidate.k) {
        throw std::runtime_error("k must match between baseline and candidate rows");
    }
    if (baseline.P != 1) {
        throw std::runtime_error("baseline row must use P=1");
    }
    if (baseline.compute_time <= 0.0 || baseline.total_time <= 0.0) {
        throw std::runtime_error("baseline times must be positive");
    }
    if (candidate.compute_time <= 0.0 || candidate.total_time <= 0.0) {
        throw std::runtime_error("candidate times must be positive");
    }

    SpeedupRow row;
    row.N = candidate.N;
    row.D = candidate.D;
    row.Q = candidate.Q;
    row.k = candidate.k;
    row.P = candidate.P;
    row.compute_time = candidate.compute_time;
    row.communication_time = candidate.communication_time;
    row.total_time = candidate.total_time;
    row.compute_speedup = baseline.compute_time / candidate.compute_time;
    row.total_speedup = baseline.total_time / candidate.total_time;
    row.compute_efficiency = row.compute_speedup / static_cast<double>(candidate.P);
    row.total_efficiency = row.total_speedup / static_cast<double>(candidate.P);
    return row;
}

void write_run_metrics_csv(
    const std::filesystem::path& path,
    const RunMetricsRow& row) {
    const auto parent = path.parent_path();
    if (!parent.empty()) {
        std::filesystem::create_directories(parent);
    }

    std::ofstream stream(path, std::ios::trunc);
    if (!stream) {
        throw std::runtime_error("failed to open run metrics CSV for writing: " + path.string());
    }

    stream << "N,D,Q,k,P,compute_time,communication_time,total_time\n";
    stream << std::fixed << std::setprecision(8);
    stream
        << row.N << ','
        << row.D << ','
        << row.Q << ','
        << row.k << ','
        << row.P << ','
        << row.compute_time << ','
        << row.communication_time << ','
        << row.total_time << '\n';

    if (!stream) {
        throw std::runtime_error("failed while writing run metrics CSV: " + path.string());
    }
}

}  // namespace retriever
