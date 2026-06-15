#pragma once

#include <cmath>
#include <cstdint>
#include <filesystem>
#include <limits>
#include <random>
#include <stdexcept>
#include <string>
#include <vector>

namespace retriever::tooling {

struct SyntheticGeneratorOptions {
    bool show_help = false;
    std::uint64_t count = 0;
    std::uint32_t dimension = 0;
    std::uint64_t seed = 12345;
    std::filesystem::path output_path;
};

struct SyntheticGeneratorParseResult {
    bool ok = false;
    SyntheticGeneratorOptions options;
    std::string error;
};

inline std::string generator_usage_text(
    const std::string& binary_name,
    const std::string& count_flag) {
    return
        "Usage: " + binary_name + " " + count_flag + " <int> --D <int> --output <path> [--seed <uint64>] [--help]\n"
        "\n"
        "Required options:\n"
        "  " + count_flag + " <int>\n"
        "  --D <int>\n"
        "  --output <path>\n"
        "\n"
        "Optional options:\n"
        "  --seed <uint64>    Default: 12345\n"
        "  --help\n";
}

inline bool try_parse_uint64(
    const std::string& text,
    std::uint64_t& value,
    const bool require_positive) {
    if (!text.empty() && text.front() == '-') {
        return false;
    }

    try {
        std::size_t consumed = 0;
        const auto parsed = std::stoull(text, &consumed);
        if (consumed != text.size()) {
            return false;
        }

        if (require_positive && parsed == 0) {
            return false;
        }

        value = parsed;
        return true;
    } catch (...) {
        return false;
    }
}

inline bool try_parse_positive_dimension(const std::string& text, std::uint32_t& value) {
    std::uint64_t parsed = 0;
    if (!try_parse_uint64(text, parsed, true) || parsed > std::numeric_limits<std::uint32_t>::max()) {
        return false;
    }

    value = static_cast<std::uint32_t>(parsed);
    return true;
}

inline SyntheticGeneratorParseResult parse_generator_args(
    const int argc,
    const char* const argv[],
    const std::string& count_flag) {
    SyntheticGeneratorParseResult result;

    for (int index = 1; index < argc; ++index) {
        const std::string argument = argv[index];

        if (argument == "--help") {
            result.ok = true;
            result.options.show_help = true;
            return result;
        }

        auto require_value = [&](const std::string& flag_name) -> const char* {
            if (index + 1 >= argc) {
                throw std::runtime_error("missing value for " + flag_name);
            }

            ++index;
            return argv[index];
        };

        try {
            if (argument == count_flag) {
                const std::string value = require_value(count_flag);
                if (!try_parse_uint64(value, result.options.count, true)) {
                    throw std::runtime_error(count_flag + " must be a positive integer");
                }
            } else if (argument == "--D") {
                const std::string value = require_value("--D");
                if (!try_parse_positive_dimension(value, result.options.dimension)) {
                    throw std::runtime_error("--D must be a positive integer");
                }
            } else if (argument == "--output") {
                result.options.output_path = require_value("--output");
            } else if (argument == "--seed") {
                const std::string value = require_value("--seed");
                if (!try_parse_uint64(value, result.options.seed, false)) {
                    throw std::runtime_error("--seed must be a uint64");
                }
            } else {
                throw std::runtime_error("unknown flag: " + argument);
            }
        } catch (const std::runtime_error& ex) {
            result.error = ex.what();
            return result;
        }
    }

    if (result.options.count == 0) {
        result.error = "missing required option: " + count_flag;
        return result;
    }

    if (result.options.dimension == 0) {
        result.error = "missing required option: --D";
        return result;
    }

    if (result.options.output_path.empty()) {
        result.error = "missing required option: --output";
        return result;
    }

    result.ok = true;
    return result;
}

inline double uniform_unit_interval(std::mt19937_64& engine) {
    const long double numerator = static_cast<long double>(engine()) + 0.5L;
    const long double denominator = static_cast<long double>(std::mt19937_64::max()) + 1.0L;
    return static_cast<double>(numerator / denominator);
}

inline std::vector<float> generate_normalized_vectors(
    const std::uint64_t vector_count,
    const std::uint32_t dimension,
    const std::uint64_t seed) {
    if (vector_count == 0) {
        return {};
    }

    if (dimension == 0) {
        throw std::runtime_error("dimension must be positive");
    }

    if (vector_count > std::numeric_limits<std::uint64_t>::max() / static_cast<std::uint64_t>(dimension)) {
        throw std::runtime_error("requested dataset is too large for this process");
    }

    const auto total_values = vector_count * static_cast<std::uint64_t>(dimension);
    if (total_values > static_cast<std::uint64_t>(std::numeric_limits<std::size_t>::max())) {
        throw std::runtime_error("requested dataset is too large for this process");
    }

    std::vector<float> values(static_cast<std::size_t>(total_values), 0.0f);
    std::mt19937_64 engine(seed);
    constexpr double kTwoPi = 6.28318530717958647692;

    std::size_t cursor = 0;
    for (std::uint64_t vector_index = 0; vector_index < vector_count; ++vector_index) {
        const auto row_start = cursor;
        double norm_squared = 0.0;

        for (std::uint32_t component = 0; component < dimension; ++component) {
            if ((component % 2u) == 0u) {
                double u1 = uniform_unit_interval(engine);
                if (u1 <= 0.0) {
                    u1 = std::numeric_limits<double>::min();
                }
                const double u2 = uniform_unit_interval(engine);
                const double radius = std::sqrt(-2.0 * std::log(u1));
                const double theta = kTwoPi * u2;

                const double z0 = radius * std::cos(theta);
                values[cursor] = static_cast<float>(z0);
                norm_squared += z0 * z0;
                ++cursor;

                if (component + 1u < dimension) {
                    const double z1 = radius * std::sin(theta);
                    values[cursor] = static_cast<float>(z1);
                    norm_squared += z1 * z1;
                    ++cursor;
                    ++component;
                }
            }
        }

        const double norm = std::sqrt(norm_squared);
        if (norm == 0.0) {
            values[row_start] = 1.0f;
            for (std::size_t index = row_start + 1; index < cursor; ++index) {
                values[index] = 0.0f;
            }
            continue;
        }

        for (std::size_t index = row_start; index < cursor; ++index) {
            values[index] = static_cast<float>(static_cast<double>(values[index]) / norm);
        }
    }

    return values;
}

}  // namespace retriever::tooling
