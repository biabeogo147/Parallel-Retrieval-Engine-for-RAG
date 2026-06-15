#include "ParallelRetriever.hpp"

#include <cstdint>
#include <functional>
#include <limits>
#include <stdexcept>
#include <string>
#include <vector>

namespace {

using retriever::ParallelRetriever;
using retriever::QueryTopKResult;
using retriever::RetrievalCandidate;

void expect_true(const bool condition, const std::string& message) {
    if (!condition) {
        throw std::runtime_error(message);
    }
}

void expect_candidate(
    const RetrievalCandidate& candidate,
    const std::uint64_t expected_id,
    const float expected_score) {
    expect_true(candidate.memory_id == expected_id, "memory_id should match expected value");
    expect_true(candidate.score == expected_score, "score should match expected value");
}

void test_merge_keeps_global_best_k() {
    const std::vector<RetrievalCandidate> gathered = {
        {0, 0.20f},
        {4, 0.90f},
        {9, 0.70f},
        {3, 0.80f},
    };

    const QueryTopKResult result = ParallelRetriever::merge_query_results(7, gathered, 3);

    expect_true(result.query_id == 7, "query_id should be preserved");
    expect_true(result.topk.size() == 3, "should keep top 3 candidates");
    expect_candidate(result.topk[0], 4, 0.90f);
    expect_candidate(result.topk[1], 3, 0.80f);
    expect_candidate(result.topk[2], 9, 0.70f);
}

void test_merge_breaks_ties_with_lower_memory_id() {
    const std::vector<RetrievalCandidate> gathered = {
        {7, 0.50f},
        {2, 0.50f},
        {4, 0.50f},
    };

    const QueryTopKResult result = ParallelRetriever::merge_query_results(0, gathered, 2);

    expect_true(result.topk.size() == 2, "should keep requested number of candidates");
    expect_candidate(result.topk[0], 2, 0.50f);
    expect_candidate(result.topk[1], 4, 0.50f);
}

void test_merge_ignores_sentinel_candidates() {
    const std::vector<RetrievalCandidate> gathered = {
        {1, 0.70f},
        {std::numeric_limits<std::uint64_t>::max(), -std::numeric_limits<float>::infinity()},
        {0, 0.90f},
    };

    const QueryTopKResult result = ParallelRetriever::merge_query_results(3, gathered, 3);

    expect_true(result.topk.size() == 2, "sentinel candidates should be discarded");
    expect_candidate(result.topk[0], 0, 0.90f);
    expect_candidate(result.topk[1], 1, 0.70f);
}

void test_merge_handles_empty_ranks() {
    const std::vector<RetrievalCandidate> gathered = {
        {std::numeric_limits<std::uint64_t>::max(), -std::numeric_limits<float>::infinity()},
        {5, 0.40f},
        {std::numeric_limits<std::uint64_t>::max(), -std::numeric_limits<float>::infinity()},
        {3, 0.60f},
    };

    const QueryTopKResult result = ParallelRetriever::merge_query_results(2, gathered, 2);

    expect_true(result.topk.size() == 2, "valid candidates from non-empty ranks should be kept");
    expect_candidate(result.topk[0], 3, 0.60f);
    expect_candidate(result.topk[1], 5, 0.40f);
}

}  // namespace

int main() {
    test_merge_keeps_global_best_k();
    test_merge_breaks_ties_with_lower_memory_id();
    test_merge_ignores_sentinel_candidates();
    test_merge_handles_empty_ranks();
    return 0;
}
