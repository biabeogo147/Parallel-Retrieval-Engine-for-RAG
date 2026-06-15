#include "CorrectnessChecker.hpp"

#include <cmath>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>

namespace {

struct VerifyResultsOptions {
    bool show_help = false;
    std::string sequential_path;
    std::string parallel_path;
    std::string output_path;
    double epsilon = 0.0;
    bool has_epsilon = false;
};

std::string usage_text() {
    return
        "Usage: verify_results --sequential <path> --parallel <path> --epsilon <float> --output <path> [--help]\n"
        "\n"
        "Required options:\n"
        "  --sequential <path>\n"
        "  --parallel <path>\n"
        "  --epsilon <float>\n"
        "  --output <path>\n"
        "\n"
        "Optional options:\n"
        "  --help\n";
}

std::uint64_t parse_uint64(
    const std::string& value,
    const std::string& field_name,
    const std::size_t line_number) {
    if (!value.empty() && value.front() == '-') {
        throw std::runtime_error(
            "invalid " + field_name + " on line " + std::to_string(line_number));
    }

    std::size_t consumed = 0;
    const auto parsed = std::stoull(value, &consumed);
    if (consumed != value.size()) {
        throw std::runtime_error(
            "invalid " + field_name + " on line " + std::to_string(line_number));
    }

    return parsed;
}

float parse_float(
    const std::string& value,
    const std::string& field_name,
    const std::size_t line_number) {
    std::size_t consumed = 0;
    const auto parsed = std::stof(value, &consumed);
    if (consumed != value.size()) {
        throw std::runtime_error(
            "invalid " + field_name + " on line " + std::to_string(line_number));
    }

    if (!std::isfinite(parsed)) {
        throw std::runtime_error(
            "invalid " + field_name + " on line " + std::to_string(line_number));
    }

    return parsed;
}

double parse_double_argument(const std::string& value, const std::string& field_name) {
    std::size_t consumed = 0;
    const auto parsed = std::stod(value, &consumed);
    if (consumed != value.size()) {
        throw std::runtime_error("invalid value for " + field_name);
    }

    if (!std::isfinite(parsed)) {
        throw std::runtime_error("invalid value for " + field_name);
    }

    return parsed;
}

std::vector<std::string> split_csv_fields(const std::string& line, const std::size_t line_number) {
    std::vector<std::string> fields;
    std::size_t start = 0;

    while (start <= line.size()) {
        const auto delimiter = line.find(',', start);
        if (delimiter == std::string::npos) {
            fields.push_back(line.substr(start));
            break;
        }

        fields.push_back(line.substr(start, delimiter - start));
        start = delimiter + 1;
    }

    if (fields.size() != 4) {
        throw std::runtime_error(
            "expected 4 CSV fields on line " + std::to_string(line_number));
    }

    return fields;
}

VerifyResultsOptions parse_args(int argc, const char* const argv[]) {
    VerifyResultsOptions options;

    for (int index = 1; index < argc; ++index) {
        const std::string argument = argv[index];
        if (argument == "--help") {
            options.show_help = true;
            return options;
        }

        if (index + 1 >= argc) {
            throw std::runtime_error("missing value for " + argument);
        }

        const auto value = std::string(argv[++index]);
        if (argument == "--sequential") {
            options.sequential_path = value;
            continue;
        }

        if (argument == "--parallel") {
            options.parallel_path = value;
            continue;
        }

        if (argument == "--epsilon") {
            options.epsilon = parse_double_argument(value, "--epsilon");
            options.has_epsilon = true;
            continue;
        }

        if (argument == "--output") {
            options.output_path = value;
            continue;
        }

        throw std::runtime_error("unknown flag: " + argument);
    }

    if (options.sequential_path.empty()) {
        throw std::runtime_error("missing required option: --sequential");
    }

    if (options.parallel_path.empty()) {
        throw std::runtime_error("missing required option: --parallel");
    }

    if (!options.has_epsilon) {
        throw std::runtime_error("missing required option: --epsilon");
    }

    if (options.epsilon <= 0.0) {
        throw std::runtime_error("--epsilon must be greater than 0");
    }

    if (options.output_path.empty()) {
        throw std::runtime_error("missing required option: --output");
    }

    return options;
}

std::vector<retriever::TopKCsvRow> read_topk_csv(const std::filesystem::path& path) {
    std::ifstream stream(path);
    if (!stream) {
        throw std::runtime_error("failed to open CSV for reading: " + path.string());
    }

    std::string line;
    if (!std::getline(stream, line)) {
        throw std::runtime_error("CSV is empty: " + path.string());
    }

    if (line != "query_id,rank_position,memory_id,score") {
        throw std::runtime_error("unexpected CSV header in " + path.string());
    }

    std::vector<retriever::TopKCsvRow> rows;
    std::size_t line_number = 1;
    while (std::getline(stream, line)) {
        ++line_number;
        if (line.empty()) {
            throw std::runtime_error(
                "unexpected empty CSV row on line " +
                std::to_string(line_number) +
                " in " +
                path.string());
        }

        const auto fields = split_csv_fields(line, line_number);
        retriever::TopKCsvRow row;
        row.query_id = parse_uint64(fields[0], "query_id", line_number);
        row.rank_position = parse_uint64(fields[1], "rank_position", line_number);
        row.memory_id = parse_uint64(fields[2], "memory_id", line_number);
        row.score = parse_float(fields[3], "score", line_number);
        rows.push_back(row);
    }

    return rows;
}

void write_correctness_csv(
    const std::filesystem::path& path,
    const std::vector<retriever::QueryCorrectnessResult>& results) {
    const auto parent = path.parent_path();
    if (!parent.empty()) {
        std::filesystem::create_directories(parent);
    }

    std::ofstream stream(path, std::ios::trunc);
    if (!stream) {
        throw std::runtime_error("failed to open output CSV for writing: " + path.string());
    }

    stream << "query_id,k,matched,matched_ids,max_score_diff,status\n";
    stream << std::boolalpha << std::fixed << std::setprecision(8);

    for (const auto& result : results) {
        stream
            << result.query_id << ','
            << result.k << ','
            << result.matched << ','
            << result.matched_ids << ','
            << result.max_score_diff << ','
            << result.status << '\n';
    }

    if (!stream) {
        throw std::runtime_error("failed while writing correctness CSV: " + path.string());
    }
}

}  // namespace

int main(int argc, const char* const argv[]) {
    VerifyResultsOptions options;
    try {
        options = parse_args(argc, argv);
    } catch (const std::exception& ex) {
        std::cerr << "Error: " << ex.what() << "\n\n";
        std::cerr << usage_text();
        return 2;
    }

    if (options.show_help) {
        std::cout << usage_text();
        return 0;
    }

    try {
        const auto sequential_rows = read_topk_csv(options.sequential_path);
        const auto parallel_rows = read_topk_csv(options.parallel_path);
        const auto results = retriever::CorrectnessChecker::compare(
            sequential_rows,
            parallel_rows,
            options.epsilon);

        write_correctness_csv(options.output_path, results);

        std::size_t passed_queries = 0;
        for (const auto& result : results) {
            if (result.matched) {
                ++passed_queries;
            }
        }

        if (passed_queries == results.size()) {
            std::cout << "All queries PASS\n";
            return 0;
        }

        std::cout
            << "Correctness check FAILED: "
            << passed_queries
            << '/'
            << results.size()
            << " queries passed\n";
        return 1;
    } catch (const std::exception& ex) {
        std::cerr << "Error: " << ex.what() << "\n";
        return 2;
    }
}
