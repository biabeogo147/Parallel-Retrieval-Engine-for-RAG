#include "BinaryDataset.hpp"
#include "SequentialRetriever.hpp"
#include "TopKHeap.hpp"

#include <cmath>
#include <cstdint>
#include <functional>
#include <stdexcept>
#include <string>
#include <vector>

namespace {

using retriever::BinaryDataset;
using retriever::BinaryDatasetContents;
using retriever::QueryTopKResult;
using retriever::RetrievalCandidate;
using retriever::SequentialRetriever;
using retriever::TopKHeap;

void expect_true(const bool condition, const std::string& message) {
    if (!condition) {
        throw std::runtime_error(message);
    }
}

void expect_near(
    const float actual,
    const float expected,
    const float tolerance,
    const std::string& message) {
    if (std::fabs(actual - expected) > tolerance) {
        throw std::runtime_error(message);
    }
}

template <typename ExceptionType>
void expect_throws(
    const std::function<void()>& fn,
    const std::string& expected_message_fragment) {
    try {
        fn();
    } catch (const ExceptionType& ex) {
        expect_true(
            std::string(ex.what()).find(expected_message_fragment) != std::string::npos,
            "exception message should mention " + expected_message_fragment);
        return;
    }

    throw std::runtime_error("expected exception was not thrown");
}

BinaryDatasetContents make_dataset(
    const std::uint64_t num_vectors,
    const std::uint32_t dimension,
    const std::vector<float>& values) {
    BinaryDatasetContents dataset;
    dataset.header = BinaryDataset::make_header(
        num_vectors,
        dimension,
        BinaryDataset::kFlagNormalized | BinaryDataset::kFlagRowMajor);
    dataset.values = values;
    return dataset;
}

void expect_candidate(
    const RetrievalCandidate& candidate,
    const std::uint64_t expected_id,
    const float expected_score) {
    expect_true(candidate.memory_id == expected_id, "memory_id should match expected value");
    expect_near(candidate.score, expected_score, 1e-6f, "score should match expected value");
}

void test_heap_keeps_only_best_k() {
    TopKHeap heap(2);
    heap.push(0, 0.10f);
    heap.push(1, 0.90f);
    heap.push(2, 0.40f);
    heap.push(3, 0.80f);

    const auto results = heap.sorted_results();
    expect_true(results.size() == 2, "heap should keep exactly k candidates");
    expect_candidate(results[0], 1, 0.90f);
    expect_candidate(results[1], 3, 0.80f);
}

void test_heap_tie_break_prefers_lower_memory_id() {
    TopKHeap heap(2);
    heap.push(7, 0.50f);
    heap.push(2, 0.50f);
    heap.push(4, 0.50f);

    const auto results = heap.sorted_results();
    expect_true(results.size() == 2, "heap should keep two tied candidates");
    expect_candidate(results[0], 2, 0.50f);
    expect_candidate(results[1], 4, 0.50f);
}

void test_single_query_topk_matches_expected_scores() {
    const auto memory_dataset = make_dataset(
        4,
        2,
        {
            1.0f, 0.0f,
            0.0f, 1.0f,
            0.8f, 0.6f,
            -1.0f, 0.0f,
        });
    const auto query_dataset = make_dataset(1, 2, {1.0f, 0.0f});

    const QueryTopKResult result = SequentialRetriever::search_local(
        memory_dataset.header,
        memory_dataset.values.data(),
        memory_dataset.header.num_vectors,
        query_dataset.header,
        query_dataset.values.data(),
        0,
        3);

    expect_true(result.query_id == 0, "query_id should be preserved");
    expect_true(result.topk.size() == 3, "should return requested top-k count");
    expect_candidate(result.topk[0], 0, 1.0f);
    expect_candidate(result.topk[1], 2, 0.8f);
    expect_candidate(result.topk[2], 1, 0.0f);
}

void test_search_all_returns_expected_multi_query_results() {
    const auto memory_dataset = make_dataset(
        4,
        2,
        {
            1.0f, 0.0f,
            0.0f, 1.0f,
            0.8f, 0.6f,
            -1.0f, 0.0f,
        });
    const auto query_dataset = make_dataset(
        2,
        2,
        {
            1.0f, 0.0f,
            0.0f, 1.0f,
        });

    const auto results = SequentialRetriever::search_all(memory_dataset, query_dataset, 2);

    expect_true(results.size() == 2, "should return one result set per query");
    expect_true(results[0].query_id == 0, "first query id should be 0");
    expect_true(results[1].query_id == 1, "second query id should be 1");

    expect_candidate(results[0].topk[0], 0, 1.0f);
    expect_candidate(results[0].topk[1], 2, 0.8f);
    expect_candidate(results[1].topk[0], 1, 1.0f);
    expect_candidate(results[1].topk[1], 2, 0.6f);
}

void test_memory_id_offset_is_applied_to_local_scan() {
    const auto memory_dataset = make_dataset(
        2,
        2,
        {
            1.0f, 0.0f,
            0.6f, 0.8f,
        });
    const auto query_dataset = make_dataset(1, 2, {1.0f, 0.0f});

    const QueryTopKResult result = SequentialRetriever::search_local(
        memory_dataset.header,
        memory_dataset.values.data(),
        2,
        query_dataset.header,
        query_dataset.values.data(),
        5,
        2,
        10);

    expect_true(result.query_id == 5, "query_id should match caller-provided value");
    expect_candidate(result.topk[0], 10, 1.0f);
    expect_candidate(result.topk[1], 11, 0.6f);
}

void test_dimension_mismatch_fails() {
    const auto memory_dataset = make_dataset(2, 2, {1.0f, 0.0f, 0.0f, 1.0f});
    const auto query_dataset = make_dataset(1, 3, {1.0f, 0.0f, 0.0f});

    expect_throws<std::runtime_error>(
        [&]() { (void)SequentialRetriever::search_all(memory_dataset, query_dataset, 1); },
        "dimension mismatch");
}

void test_topk_greater_than_num_vectors_fails() {
    const auto memory_dataset = make_dataset(2, 2, {1.0f, 0.0f, 0.0f, 1.0f});
    const auto query_dataset = make_dataset(1, 2, {1.0f, 0.0f});

    expect_throws<std::runtime_error>(
        [&]() { (void)SequentialRetriever::search_all(memory_dataset, query_dataset, 3); },
        "topk");
}

}  // namespace

int main() {
    test_heap_keeps_only_best_k();
    test_heap_tie_break_prefers_lower_memory_id();
    test_single_query_topk_matches_expected_scores();
    test_search_all_returns_expected_multi_query_results();
    test_memory_id_offset_is_applied_to_local_scan();
    test_dimension_mismatch_fails();
    test_topk_greater_than_num_vectors_fails();
    return 0;
}
