#include "ParallelRetriever.hpp"

#include "TopKHeap.hpp"

#include <stdexcept>

namespace retriever {

QueryTopKResult ParallelRetriever::merge_query_results(
    const std::uint64_t query_id,
    const std::vector<RetrievalCandidate>& gathered_candidates,
    const int topk) {
    if (topk < 1) {
        throw std::runtime_error("topk must be at least 1");
    }

    TopKHeap heap(topk);

    for (const auto& candidate : gathered_candidates) {
        if (candidate.memory_id == kSentinelMemoryId) {
            continue;
        }
        heap.push(candidate);
    }

    QueryTopKResult result;
    result.query_id = query_id;
    result.topk = heap.sorted_results();
    return result;
}

}  // namespace retriever
