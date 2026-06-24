#pragma once

#include "Logger.hpp"

#include <cstdint>
#include <string>

namespace retriever {

enum class AppMode {
    Sequential,
    Parallel,
};

struct Config {
    bool show_help = false;
    std::string vectors_path;
    std::string queries_path;
    std::string output_path;
    std::string metrics_path;
    std::string run_metrics_path;
    int topk = 0;
    std::uint64_t limit_n = 0;
    LogLevel log_level = LogLevel::Info;
};

struct ParseResult {
    bool ok = false;
    Config config;
    std::string error;
};

ParseResult parse_config(AppMode mode, int argc, const char* const argv[]);
std::string usage_text(AppMode mode);

}  // namespace retriever
