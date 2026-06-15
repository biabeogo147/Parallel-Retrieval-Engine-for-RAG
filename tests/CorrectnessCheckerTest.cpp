#include "CorrectnessChecker.hpp"

#include <cmath>
#include <cstdint>
#include <functional>
#include <stdexcept>
#include <string>
#include <vector>

namespace {

using retriever::CorrectnessChecker;
using retriever::QueryCorrectnessResult;
using retriever::TopKCsvRow;

void expect_true(const bool condition, const std::string& message) {
    if (!condition) {
        throw std::runtime_error(message);
    }
}

void expect_equal(
    const std::size_t actual,
    const std::size_t expected,
    const std::string& message) {
    if (actual != expected) {
        throw std::runtime_error(message);
    }
}

void expect_float_equal(
    const float actual,
    const float expected,
    const float tolerance,
    const std::string& message) {
    if (std::abs(actual - expected) > tolerance) {
        throw std::runtime_error(message);
    }
}

void expect_result(
    const QueryCorrectnessResult& result,
    const std::uint64_t expected_query_id,
    const int expected_k,
    const bool expected_matched,
    const int expected_matched_ids,
    const float expected_max_score_diff,
    const std::string& expected_status) {
    expect_true(result.query_id == expected_query_id, "query_id should match");
    expect_true(result.k == expected_k, "k should match");
    expect_true(result.matched == expected_matched, "matched should match");
    expect_true(result.matched_ids == expected_matched_ids, "matched_ids should match");
    expect_float_equal(
        result.max_score_diff,
        expected_max_score_diff,
        1e-5f,
        "max_score_diff should match");
    expect_true(result.status == expected_status, "status should match");
}

std::vector<TopKCsvRow> sample_rows_for_query_zero() {
    return {
        {0, 1, 4, 0.95000000f},
        {0, 2, 2, 0.87000000f},
        {0, 3, 7, 0.81000000f},
    };
}

void test_exact_match_passes() {
    const auto sequential_rows = sample_rows_for_query_zero();
    const auto parallel_rows = sample_rows_for_query_zero();

    const auto results = CorrectnessChecker::compare(sequential_rows, parallel_rows, 1e-5);

    expect_equal(results.size(), 1, "should produce one result row");
    expect_result(results[0], 0, 3, true, 3, 0.0f, "PASS");
}

void test_memory_id_mismatch_fails() {
    const auto sequential_rows = sample_rows_for_query_zero();
    auto parallel_rows = sample_rows_for_query_zero();
    parallel_rows[1].memory_id = 99;

    const auto results = CorrectnessChecker::compare(sequential_rows, parallel_rows, 1e-5);

    expect_equal(results.size(), 1, "should produce one result row");
    expect_result(results[0], 0, 3, false, 2, 0.0f, "FAIL");
}

void test_score_difference_within_epsilon_passes() {
    const auto sequential_rows = sample_rows_for_query_zero();
    auto parallel_rows = sample_rows_for_query_zero();
    parallel_rows[2].score = 0.81000500f;

    const auto results = CorrectnessChecker::compare(sequential_rows, parallel_rows, 1e-4);

    expect_equal(results.size(), 1, "should produce one result row");
    expect_result(results[0], 0, 3, true, 3, 0.00000500f, "PASS");
}

void test_score_difference_above_epsilon_fails() {
    const auto sequential_rows = sample_rows_for_query_zero();
    auto parallel_rows = sample_rows_for_query_zero();
    parallel_rows[0].score = 0.93000000f;

    const auto results = CorrectnessChecker::compare(sequential_rows, parallel_rows, 1e-5);

    expect_equal(results.size(), 1, "should produce one result row");
    expect_result(results[0], 0, 3, false, 3, 0.02000000f, "FAIL");
}

void test_multiple_queries_are_sorted_and_compared() {
    const std::vector<TopKCsvRow> sequential_rows = {
        {1, 1, 8, 0.90000000f},
        {1, 2, 1, 0.88000000f},
        {0, 1, 4, 0.95000000f},
        {0, 2, 2, 0.87000000f},
    };
    const std::vector<TopKCsvRow> parallel_rows = sequential_rows;

    const auto results = CorrectnessChecker::compare(sequential_rows, parallel_rows, 1e-5);

    expect_equal(results.size(), 2, "should produce one result per query");
    expect_result(results[0], 0, 2, true, 2, 0.0f, "PASS");
    expect_result(results[1], 1, 2, true, 2, 0.0f, "PASS");
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

void test_duplicate_rank_is_rejected() {
    const std::vector<TopKCsvRow> sequential_rows = {
        {0, 1, 4, 0.95f},
        {0, 1, 2, 0.87f},
    };
    const std::vector<TopKCsvRow> parallel_rows = sequential_rows;

    expect_throws<std::runtime_error>(
        [&]() { (void)CorrectnessChecker::compare(sequential_rows, parallel_rows, 1e-5); },
        "duplicate");
}

void test_missing_rank_is_rejected() {
    const std::vector<TopKCsvRow> sequential_rows = {
        {0, 1, 4, 0.95f},
        {0, 3, 2, 0.87f},
    };
    const std::vector<TopKCsvRow> parallel_rows = sequential_rows;

    expect_throws<std::runtime_error>(
        [&]() { (void)CorrectnessChecker::compare(sequential_rows, parallel_rows, 1e-5); },
        "rank_position");
}

void test_query_set_mismatch_is_rejected() {
    const std::vector<TopKCsvRow> sequential_rows = {{0, 1, 4, 0.95f}};
    const std::vector<TopKCsvRow> parallel_rows = {{1, 1, 4, 0.95f}};

    expect_throws<std::runtime_error>(
        [&]() { (void)CorrectnessChecker::compare(sequential_rows, parallel_rows, 1e-5); },
        "query_id");
}

}  // namespace

int main() {
    test_exact_match_passes();
    test_memory_id_mismatch_fails();
    test_score_difference_within_epsilon_passes();
    test_score_difference_above_epsilon_fails();
    test_multiple_queries_are_sorted_and_compared();
    test_duplicate_rank_is_rejected();
    test_missing_rank_is_rejected();
    test_query_set_mismatch_is_rejected();
    return 0;
}
