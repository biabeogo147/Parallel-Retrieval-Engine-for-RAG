#include "Config.hpp"

#include <sstream>
#include <string>
#include <utility>
#include <vector>

namespace retriever {

namespace {

std::string binary_name(const AppMode mode) {
    return mode == AppMode::Sequential ? "sequential_retriever" : "parallel_retriever";
}

std::string join_missing_flags(const std::vector<std::string>& flags) {
    std::ostringstream stream;
    for (std::size_t index = 0; index < flags.size(); ++index) {
        if (index > 0) {
            stream << ", ";
        }
        stream << flags[index];
    }
    return stream.str();
}

bool parse_positive_int(const std::string& value, int& parsed) {
    try {
        std::size_t consumed = 0;
        const int candidate = std::stoi(value, &consumed);
        if (consumed != value.size() || candidate <= 0) {
            return false;
        }
        parsed = candidate;
        return true;
    } catch (...) {
        return false;
    }
}

ParseResult failure(std::string message) {
    ParseResult result;
    result.ok = false;
    result.error = std::move(message);
    return result;
}

}  // namespace

ParseResult parse_config(const AppMode mode, const int argc, const char* const argv[]) {
    ParseResult result;
    result.ok = true;

    for (int index = 1; index < argc; ++index) {
        const std::string argument = argv[index];

        if (argument == "--help") {
            result.config.show_help = true;
            continue;
        }

        auto read_value = [&](const std::string& flag_name) -> ParseResult {
            if (index + 1 >= argc) {
                return failure("Missing value for " + flag_name);
            }
            ++index;
            ParseResult value_result;
            value_result.ok = true;
            value_result.error = argv[index];
            return value_result;
        };

        if (argument == "--vectors") {
            const auto value = read_value(argument);
            if (!value.ok) {
                return value;
            }
            result.config.vectors_path = value.error;
            continue;
        }

        if (argument == "--queries") {
            const auto value = read_value(argument);
            if (!value.ok) {
                return value;
            }
            result.config.queries_path = value.error;
            continue;
        }

        if (argument == "--output") {
            const auto value = read_value(argument);
            if (!value.ok) {
                return value;
            }
            result.config.output_path = value.error;
            continue;
        }

        if (argument == "--topk") {
            const auto value = read_value(argument);
            if (!value.ok) {
                return value;
            }
            if (!parse_positive_int(value.error, result.config.topk)) {
                return failure("Invalid value for --topk: " + value.error);
            }
            continue;
        }

        if (argument == "--log-level") {
            const auto value = read_value(argument);
            if (!value.ok) {
                return value;
            }
            if (!try_parse_log_level(value.error, result.config.log_level)) {
                return failure("Invalid value for --log-level: " + value.error);
            }
            continue;
        }

        if (argument == "--metrics") {
            if (mode != AppMode::Parallel) {
                return failure("Unknown option for " + binary_name(mode) + ": " + argument);
            }

            const auto value = read_value(argument);
            if (!value.ok) {
                return value;
            }
            result.config.metrics_path = value.error;
            continue;
        }

        return failure("Unknown option for " + binary_name(mode) + ": " + argument);
    }

    if (result.config.show_help) {
        return result;
    }

    std::vector<std::string> missing_flags;
    if (result.config.vectors_path.empty()) {
        missing_flags.emplace_back("--vectors");
    }
    if (result.config.queries_path.empty()) {
        missing_flags.emplace_back("--queries");
    }
    if (result.config.output_path.empty()) {
        missing_flags.emplace_back("--output");
    }
    if (result.config.topk <= 0) {
        missing_flags.emplace_back("--topk");
    }
    if (mode == AppMode::Parallel && result.config.metrics_path.empty()) {
        missing_flags.emplace_back("--metrics");
    }

    if (!missing_flags.empty()) {
        return failure("Missing required options: " + join_missing_flags(missing_flags));
    }

    return result;
}

std::string usage_text(const AppMode mode) {
    std::ostringstream usage;

    usage << "Usage: " << binary_name(mode) << " [options]\n\n";
    usage << "Phase 1 scaffold: CLI parsing, logging, and MPI bootstrap only.\n\n";
    usage << "Options:\n";
    usage << "  --help                 Show this help message and exit.\n";
    usage << "  --vectors <path>       Path to the memory vector dataset.\n";
    usage << "  --queries <path>       Path to the query vector dataset.\n";
    usage << "  --output <path>        Path to the output CSV file.\n";
    usage << "  --topk <int>           Number of results to return.\n";
    usage << "  --log-level <level>    One of: debug, info, warn, error.\n";

    if (mode == AppMode::Parallel) {
        usage << "  --metrics <path>       Path to the per-rank metrics CSV file.\n";
    }

    return usage.str();
}

}  // namespace retriever
