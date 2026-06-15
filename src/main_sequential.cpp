#include "BinaryDataset.hpp"
#include "Config.hpp"
#include "Logger.hpp"
#include "SequentialRetriever.hpp"

#include <filesystem>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <stdexcept>

namespace {

void write_results_csv(
    const std::filesystem::path& path,
    const std::vector<retriever::QueryTopKResult>& results) {
    const auto parent = path.parent_path();
    if (!parent.empty()) {
        std::filesystem::create_directories(parent);
    }

    std::ofstream stream(path, std::ios::trunc);
    if (!stream) {
        throw std::runtime_error("failed to open output CSV for writing: " + path.string());
    }

    stream << "query_id,rank_position,memory_id,score\n";
    stream << std::fixed << std::setprecision(8);

    for (const auto& query_result : results) {
        for (std::size_t rank_index = 0; rank_index < query_result.topk.size(); ++rank_index) {
            const auto& candidate = query_result.topk[rank_index];
            stream
                << query_result.query_id << ','
                << (rank_index + 1) << ','
                << candidate.memory_id << ','
                << candidate.score << '\n';
        }
    }

    if (!stream) {
        throw std::runtime_error("failed while writing output CSV: " + path.string());
    }
}

}  // namespace

int main(int argc, const char* const argv[]) {
    try {
        const auto result = retriever::parse_config(retriever::AppMode::Sequential, argc, argv);

        if (!result.ok) {
            std::cerr << "Error: " << result.error << "\n\n";
            std::cerr << retriever::usage_text(retriever::AppMode::Sequential);
            return 1;
        }

        if (result.config.show_help) {
            std::cout << retriever::usage_text(retriever::AppMode::Sequential);
            return 0;
        }

        const retriever::Logger logger(result.config.log_level);
        const auto memory_dataset = retriever::BinaryDataset::read_all(result.config.vectors_path);
        const auto query_dataset = retriever::BinaryDataset::read_all(result.config.queries_path);

        logger.info(
            "Loaded " +
            std::to_string(memory_dataset.header.num_vectors) +
            " memory vectors with dimension " +
            std::to_string(memory_dataset.header.dimension) +
            ".");
        logger.info(
            "Loaded " +
            std::to_string(query_dataset.header.num_vectors) +
            " query vectors.");

        const auto retrieval_results =
            retriever::SequentialRetriever::search_all(memory_dataset, query_dataset, result.config.topk);

        write_results_csv(result.config.output_path, retrieval_results);

        logger.info(
            "Wrote sequential retrieval results to " +
            result.config.output_path +
            ".");
        return 0;
    } catch (const std::exception& ex) {
        std::cerr << "Error: " << ex.what() << '\n';
        return 1;
    }
}
