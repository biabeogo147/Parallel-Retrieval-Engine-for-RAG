#include "Config.hpp"
#include "Logger.hpp"

#include <cassert>
#include <stdexcept>
#include <string>

using retriever::AppMode;
using retriever::Config;
using retriever::LogLevel;

namespace {

void expect_true(bool condition, const std::string& message) {
    if (!condition) {
        throw std::runtime_error(message);
    }
}

void test_help_for_sequential() {
    const char* argv[] = {"sequential_retriever", "--help"};
    const auto result = retriever::parse_config(AppMode::Sequential, 2, argv);

    expect_true(result.ok, "help parse should succeed");
    expect_true(result.config.show_help, "help flag should be set");
    expect_true(result.config.log_level == LogLevel::Info, "default log level should be info");
}

void test_missing_required_options() {
    const char* argv[] = {"sequential_retriever"};
    const auto result = retriever::parse_config(AppMode::Sequential, 1, argv);

    expect_true(!result.ok, "missing options should fail");
    expect_true(result.error.find("--vectors") != std::string::npos, "missing vectors should be reported");
}

void test_invalid_topk() {
    const char* argv[] = {
        "sequential_retriever",
        "--vectors",
        "vectors.bin",
        "--queries",
        "queries.bin",
        "--output",
        "out.csv",
        "--topk",
        "zero",
    };

    const auto result = retriever::parse_config(AppMode::Sequential, 9, argv);

    expect_true(!result.ok, "non-numeric topk should fail");
    expect_true(result.error.find("--topk") != std::string::npos, "topk error should mention flag");
}

void test_invalid_log_level() {
    const char* argv[] = {
        "sequential_retriever",
        "--vectors",
        "vectors.bin",
        "--queries",
        "queries.bin",
        "--output",
        "out.csv",
        "--topk",
        "10",
        "--log-level",
        "trace",
    };

    const auto result = retriever::parse_config(AppMode::Sequential, 11, argv);

    expect_true(!result.ok, "invalid log level should fail");
    expect_true(result.error.find("log-level") != std::string::npos, "log level error should mention flag");
}

void test_parallel_requires_metrics() {
    const char* argv[] = {
        "parallel_retriever",
        "--vectors",
        "vectors.bin",
        "--queries",
        "queries.bin",
        "--output",
        "out.csv",
        "--topk",
        "10",
    };

    const auto result = retriever::parse_config(AppMode::Parallel, 9, argv);

    expect_true(!result.ok, "parallel config without metrics should fail");
    expect_true(result.error.find("--metrics") != std::string::npos, "metrics should be reported missing");
}

void test_parallel_valid_config() {
    const char* argv[] = {
        "parallel_retriever",
        "--vectors",
        "vectors.bin",
        "--queries",
        "queries.bin",
        "--output",
        "out.csv",
        "--topk",
        "10",
        "--metrics",
        "metrics.csv",
        "--run-metrics",
        "run.csv",
        "--log-level",
        "debug",
    };

    const auto result = retriever::parse_config(AppMode::Parallel, 15, argv);

    expect_true(result.ok, "parallel config should parse");
    expect_true(!result.config.show_help, "help flag should be unset");
    expect_true(result.config.metrics_path == "metrics.csv", "metrics path should parse");
    expect_true(result.config.run_metrics_path == "run.csv", "run metrics path should parse");
    expect_true(result.config.topk == 10, "topk should parse");
    expect_true(result.config.log_level == LogLevel::Debug, "debug log level should parse");
}

void test_sequential_accepts_run_metrics() {
    const char* argv[] = {
        "sequential_retriever",
        "--vectors",
        "vectors.bin",
        "--queries",
        "queries.bin",
        "--output",
        "out.csv",
        "--topk",
        "10",
        "--run-metrics",
        "run.csv",
    };

    const auto result = retriever::parse_config(AppMode::Sequential, 11, argv);

    expect_true(result.ok, "sequential config with run metrics should parse");
    expect_true(result.config.run_metrics_path == "run.csv", "run metrics path should parse");
}

void test_usage_text() {
    const auto sequential_usage = retriever::usage_text(AppMode::Sequential);
    const auto parallel_usage = retriever::usage_text(AppMode::Parallel);

    expect_true(sequential_usage.find("Usage: sequential_retriever") != std::string::npos, "sequential usage should contain binary name");
    expect_true(parallel_usage.find("Usage: parallel_retriever") != std::string::npos, "parallel usage should contain binary name");
    expect_true(sequential_usage.find("--run-metrics <path>") != std::string::npos, "sequential usage should document run metrics");
    expect_true(parallel_usage.find("--metrics <path>") != std::string::npos, "parallel usage should document metrics");
    expect_true(parallel_usage.find("--run-metrics <path>") != std::string::npos, "parallel usage should document run metrics");
    expect_true(
        parallel_usage.find("blocking MPI retrieval") != std::string::npos,
        "parallel usage should describe the Phase 4 retrieval path");
}

}  // namespace

int main() {
    test_help_for_sequential();
    test_missing_required_options();
    test_invalid_topk();
    test_invalid_log_level();
    test_parallel_requires_metrics();
    test_parallel_valid_config();
    test_sequential_accepts_run_metrics();
    test_usage_text();
    return 0;
}
