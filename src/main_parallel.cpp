#include "BenchmarkMetrics.hpp"
#include "BinaryDataset.hpp"
#include "Config.hpp"
#include "Logger.hpp"
#include "MpiUtils.hpp"
#include "MpiSession.hpp"
#include "ParallelRetriever.hpp"
#include "SequentialRetriever.hpp"

#include <mpi.h>

#include <algorithm>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <stdexcept>
#include <vector>

namespace {

bool has_flag(const retriever::BinaryDatasetHeader& header, const std::uint32_t flag) {
    return (header.flags & flag) != 0;
}

void validate_parallel_inputs(
    const retriever::BinaryDatasetHeader& memory_header,
    const retriever::BinaryDatasetHeader& query_header,
    const int topk) {
    if (!has_flag(memory_header, retriever::BinaryDataset::kFlagNormalized)) {
        throw std::runtime_error("memory dataset must set the normalized flag");
    }

    if (!has_flag(query_header, retriever::BinaryDataset::kFlagNormalized)) {
        throw std::runtime_error("query dataset must set the normalized flag");
    }

    if (!has_flag(memory_header, retriever::BinaryDataset::kFlagRowMajor)) {
        throw std::runtime_error("memory dataset must set the row-major flag");
    }

    if (!has_flag(query_header, retriever::BinaryDataset::kFlagRowMajor)) {
        throw std::runtime_error("query dataset must set the row-major flag");
    }

    if (memory_header.dimension != query_header.dimension) {
        throw std::runtime_error("dimension mismatch between memory and query datasets");
    }

    if (topk < 1) {
        throw std::runtime_error("topk must be at least 1");
    }

    if (static_cast<std::uint64_t>(topk) > memory_header.num_vectors) {
        throw std::runtime_error("topk must not exceed the number of memory vectors");
    }
}

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

void write_metrics_csv(
    const std::filesystem::path& path,
    const std::vector<retriever::ParallelRankMetrics>& metrics) {
    const auto parent = path.parent_path();
    if (!parent.empty()) {
        std::filesystem::create_directories(parent);
    }

    std::ofstream stream(path, std::ios::trunc);
    if (!stream) {
        throw std::runtime_error("failed to open metrics CSV for writing: " + path.string());
    }

    stream << "rank,local_N,compute_time,communication_time,active_time,global_total_time,idle_time\n";
    stream << std::fixed << std::setprecision(8);

    for (const auto& metric : metrics) {
        stream
            << metric.rank << ','
            << metric.local_N << ','
            << metric.compute_time << ','
            << metric.communication_time << ','
            << metric.active_time << ','
            << metric.global_total_time << ','
            << metric.idle_time << '\n';
    }

    if (!stream) {
        throw std::runtime_error("failed while writing metrics CSV: " + path.string());
    }
}

}  // namespace

int main(int argc, char** argv) {
    retriever::MpiSession mpi_session(argc, argv);
    std::vector<const char*> args(argv, argv + argc);

    try {
        const auto result = retriever::parse_config(
            retriever::AppMode::Parallel,
            argc,
            args.data()
        );

        if (!result.ok) {
            if (mpi_session.rank() == 0) {
                std::cerr << "Error: " << result.error << "\n\n";
                std::cerr << retriever::usage_text(retriever::AppMode::Parallel);
            }
            return 1;
        }

        if (result.config.show_help) {
            if (mpi_session.rank() == 0) {
                std::cout << retriever::usage_text(retriever::AppMode::Parallel);
            }
            return 0;
        }

        retriever::BinaryDatasetShard memory_shard;
        retriever::BinaryDatasetHeader query_header;
        retriever::BinaryDatasetContents query_dataset;
        bool startup_failed = false;
        std::string startup_error_message;

        try {
            memory_shard = retriever::BinaryDataset::read_shard(
                result.config.vectors_path,
                mpi_session.rank(),
                mpi_session.size());
            query_header = retriever::BinaryDataset::read_header(result.config.queries_path);
            if (mpi_session.rank() == 0) {
                query_dataset = retriever::BinaryDataset::read_all(result.config.queries_path);
            }
            validate_parallel_inputs(memory_shard.header, query_header, result.config.topk);
        } catch (const std::exception& ex) {
            startup_failed = true;
            startup_error_message = ex.what();
        }

        const auto startup_report =
            retriever::gather_startup_errors(startup_failed, startup_error_message, 0);
        if (startup_report.any_error) {
            if (mpi_session.rank() == 0) {
                std::cerr << "Error: " << startup_report.message << '\n';
            }
            return 1;
        }

        const retriever::Logger logger(result.config.log_level);
        if (mpi_session.rank() == 0) {
            logger.info(
                "Loaded query dataset with " +
                std::to_string(query_header.num_vectors) +
                " queries of dimension " +
                std::to_string(query_header.dimension) +
                ".");
            logger.info(
                "Running blocking MPI retrieval across " +
                std::to_string(mpi_session.size()) +
                " ranks.");
        }

        std::vector<float> broadcast_query(
            static_cast<std::size_t>(query_header.dimension),
            0.0f);
        std::vector<retriever::QueryTopKResult> global_results;
        if (mpi_session.rank() == 0) {
            global_results.reserve(static_cast<std::size_t>(query_header.num_vectors));
        }

        double compute_time = 0.0;
        double communication_time = 0.0;
        const double total_start = MPI_Wtime();

        for (std::uint64_t query_id = 0; query_id < query_header.num_vectors; ++query_id) {
            if (mpi_session.rank() == 0) {
                const auto query_offset =
                    query_id * static_cast<std::uint64_t>(query_header.dimension);
                std::copy_n(
                    query_dataset.values.data() + query_offset,
                    static_cast<std::size_t>(query_header.dimension),
                    broadcast_query.begin());
            }

            double communication_start = MPI_Wtime();
            retriever::broadcast_query_vector(
                broadcast_query.data(),
                query_header.dimension,
                0);
            communication_time += MPI_Wtime() - communication_start;

            const double compute_start = MPI_Wtime();
            const auto local_result = retriever::SequentialRetriever::search_local(
                memory_shard.header,
                memory_shard.values.data(),
                memory_shard.bounds.count,
                query_header,
                broadcast_query.data(),
                query_id,
                result.config.topk,
                memory_shard.bounds.start_index);
            compute_time += MPI_Wtime() - compute_start;

            std::vector<std::uint64_t> local_ids;
            std::vector<float> local_scores;
            retriever::pack_local_candidates_fixed_k(
                local_result,
                result.config.topk,
                local_ids,
                local_scores);

            std::vector<std::uint64_t> gathered_ids;
            std::vector<float> gathered_scores;
            communication_start = MPI_Wtime();
            retriever::gather_fixed_candidates(
                local_ids,
                local_scores,
                0,
                gathered_ids,
                gathered_scores);
            communication_time += MPI_Wtime() - communication_start;

            if (mpi_session.rank() == 0) {
                std::vector<retriever::RetrievalCandidate> gathered_candidates;
                gathered_candidates.reserve(gathered_ids.size());
                for (std::size_t index = 0; index < gathered_ids.size(); ++index) {
                    gathered_candidates.push_back({
                        gathered_ids[index],
                        gathered_scores[index],
                    });
                }

                const double merge_start = MPI_Wtime();
                global_results.push_back(retriever::ParallelRetriever::merge_query_results(
                    query_id,
                    gathered_candidates,
                    result.config.topk));
                compute_time += MPI_Wtime() - merge_start;
            }
        }

        const double local_total_time = MPI_Wtime() - total_start;
        const auto metrics = retriever::gather_rank_metrics(
            mpi_session.rank(),
            memory_shard.bounds.count,
            compute_time,
            communication_time,
            local_total_time,
            0);

        if (mpi_session.rank() == 0) {
            write_results_csv(result.config.output_path, global_results);
            write_metrics_csv(result.config.metrics_path, metrics);
            if (!result.config.run_metrics_path.empty()) {
                retriever::write_run_metrics_csv(
                    result.config.run_metrics_path,
                    retriever::make_parallel_run_metrics(
                        memory_shard.header.num_vectors,
                        memory_shard.header.dimension,
                        query_header.num_vectors,
                        result.config.topk,
                        mpi_session.size(),
                        metrics));
            }
            logger.info(
                "Wrote parallel retrieval results to " +
                result.config.output_path +
                ".");
            logger.info(
                "Wrote per-rank metrics to " +
                result.config.metrics_path +
                ".");
        }

        return 0;
    } catch (const std::exception& ex) {
        if (mpi_session.rank() == 0) {
            std::cerr << "Error: " << ex.what() << '\n';
        }
        return 1;
    }
}
