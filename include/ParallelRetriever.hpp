#pragma once

#include "SequentialRetriever.hpp"

#include <cstdint>
#include <limits>
#include <vector>

namespace retriever {

inline constexpr std::uint64_t kSentinelMemoryId =
    std::numeric_limits<std::uint64_t>::max();

struct ParallelRankMetrics {
    int rank = 0;
    std::uint64_t local_N = 0;
    double compute_time = 0.0;
    double communication_time = 0.0;
    double active_time = 0.0;
    double global_total_time = 0.0;
    double idle_time = 0.0;
};

class ParallelRetriever {
public:
    static QueryTopKResult merge_query_results(
        std::uint64_t query_id,
        const std::vector<RetrievalCandidate>& gathered_candidates,
        int topk);
};

}  // namespace retriever
