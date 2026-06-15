#include "BenchmarkMetrics.hpp"
#include "ParallelRetriever.hpp"

#include <functional>
#include <stdexcept>
#include <string>
#include <vector>

namespace {

using retriever::ParallelRankMetrics;
using retriever::RunMetricsRow;
using retriever::SpeedupRow;

void expect_true(const bool condition, const std::string& message) {
    if (!condition) {
        throw std::runtime_error(message);
    }
}

void expect_near(
    const double actual,
    const double expected,
    const double tolerance,
    const std::string& message) {
    if (actual < expected - tolerance || actual > expected + tolerance) {
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

void test_sequential_run_metrics_sets_expected_fields() {
    const RunMetricsRow row = retriever::make_sequential_run_metrics(
        64,
        8,
        5,
        3,
        0.125,
        0.125);

    expect_true(row.N == 64, "N should match");
    expect_true(row.D == 8, "D should match");
    expect_true(row.Q == 5, "Q should match");
    expect_true(row.k == 3, "k should match");
    expect_true(row.P == 1, "P should be 1 for sequential baseline");
    expect_near(row.compute_time, 0.125, 1e-12, "compute_time should match");
    expect_near(row.communication_time, 0.0, 1e-12, "communication_time should be zero");
    expect_near(row.total_time, 0.125, 1e-12, "total_time should match");
}

void test_parallel_run_metrics_uses_max_components_and_global_total() {
    const std::vector<ParallelRankMetrics> metrics = {
        {0, 16, 1.5, 0.3, 1.8, 2.1, 0.3},
        {1, 16, 1.8, 0.2, 2.0, 2.1, 0.1},
        {2, 16, 1.6, 0.4, 2.0, 2.1, 0.1},
    };

    const RunMetricsRow row =
        retriever::make_parallel_run_metrics(48, 8, 5, 3, 3, metrics);

    expect_true(row.N == 48, "N should match");
    expect_true(row.D == 8, "D should match");
    expect_true(row.Q == 5, "Q should match");
    expect_true(row.k == 3, "k should match");
    expect_true(row.P == 3, "P should match world size");
    expect_near(row.compute_time, 1.8, 1e-12, "compute_time should use max rank compute");
    expect_near(
        row.communication_time,
        0.4,
        1e-12,
        "communication_time should use max rank communication");
    expect_near(row.total_time, 2.1, 1e-12, "total_time should use global_total_time");
}

void test_speedup_row_for_baseline_is_identity() {
    const RunMetricsRow baseline = retriever::make_sequential_run_metrics(
        64,
        8,
        5,
        3,
        0.125,
        0.125);

    const SpeedupRow row = retriever::make_speedup_row(baseline, baseline);

    expect_true(row.P == 1, "P should remain 1");
    expect_near(row.compute_speedup, 1.0, 1e-12, "compute_speedup should be 1");
    expect_near(row.total_speedup, 1.0, 1e-12, "total_speedup should be 1");
    expect_near(row.compute_efficiency, 1.0, 1e-12, "compute_efficiency should be 1");
    expect_near(row.total_efficiency, 1.0, 1e-12, "total_efficiency should be 1");
}

void test_speedup_row_rejects_mismatched_shape() {
    const RunMetricsRow baseline = retriever::make_sequential_run_metrics(
        64,
        8,
        5,
        3,
        0.125,
        0.125);
    const RunMetricsRow mismatched = retriever::make_parallel_run_metrics(
        128,
        8,
        5,
        3,
        2,
        {
            {0, 64, 0.08, 0.02, 0.10, 0.10, 0.0},
            {1, 64, 0.09, 0.01, 0.10, 0.10, 0.0},
        });

    expect_throws<std::runtime_error>(
        [&]() { (void)retriever::make_speedup_row(baseline, mismatched); },
        "N");
}

}  // namespace

int main() {
    test_sequential_run_metrics_sets_expected_fields();
    test_parallel_run_metrics_uses_max_components_and_global_total();
    test_speedup_row_for_baseline_is_identity();
    test_speedup_row_rejects_mismatched_shape();
    return 0;
}
