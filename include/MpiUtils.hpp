#pragma once

#include "ParallelRetriever.hpp"

#include <cstdint>
#include <string>
#include <vector>

namespace retriever {

struct StartupErrorReport {
    bool any_error = false;
    std::string message;
};

void broadcast_query_vector(float* buffer, std::uint32_t dimension, int root);

void pack_local_candidates_fixed_k(
    const QueryTopKResult& result,
    int topk,
    std::vector<std::uint64_t>& ids,
    std::vector<float>& scores);

void gather_fixed_candidates(
    const std::vector<std::uint64_t>& local_ids,
    const std::vector<float>& local_scores,
    int root,
    std::vector<std::uint64_t>& gathered_ids,
    std::vector<float>& gathered_scores);

std::vector<ParallelRankMetrics> gather_rank_metrics(
    int rank,
    std::uint64_t local_N,
    double compute_time,
    double communication_time,
    double local_total_time,
    int root);

StartupErrorReport gather_startup_errors(
    bool has_error,
    const std::string& message,
    int root);

}  // namespace retriever
