#pragma once

#include "ParallelRetriever.hpp"

#include <cstdint>
#include <filesystem>
#include <vector>

namespace retriever {

struct RunMetricsRow {
    std::uint64_t N = 0;
    std::uint32_t D = 0;
    std::uint64_t Q = 0;
    int k = 0;
    int P = 0;
    double compute_time = 0.0;
    double communication_time = 0.0;
    double total_time = 0.0;
};

struct SpeedupRow {
    std::uint64_t N = 0;
    std::uint32_t D = 0;
    std::uint64_t Q = 0;
    int k = 0;
    int P = 0;
    double compute_time = 0.0;
    double communication_time = 0.0;
    double total_time = 0.0;
    double compute_speedup = 0.0;
    double total_speedup = 0.0;
    double compute_efficiency = 0.0;
    double total_efficiency = 0.0;
};

RunMetricsRow make_sequential_run_metrics(
    std::uint64_t N,
    std::uint32_t D,
    std::uint64_t Q,
    int k,
    double compute_time,
    double total_time);

RunMetricsRow make_parallel_run_metrics(
    std::uint64_t N,
    std::uint32_t D,
    std::uint64_t Q,
    int k,
    int P,
    const std::vector<ParallelRankMetrics>& rank_metrics);

SpeedupRow make_speedup_row(
    const RunMetricsRow& baseline,
    const RunMetricsRow& candidate);

void write_run_metrics_csv(
    const std::filesystem::path& path,
    const RunMetricsRow& row);

}  // namespace retriever
