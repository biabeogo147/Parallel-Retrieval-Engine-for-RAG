#include "Logger.hpp"

#include <algorithm>
#include <cctype>
#include <iostream>

namespace retriever {

namespace {

std::string to_lower_copy(std::string value) {
    std::transform(value.begin(), value.end(), value.begin(), [](unsigned char ch) {
        return static_cast<char>(std::tolower(ch));
    });
    return value;
}

}  // namespace

bool try_parse_log_level(const std::string& value, LogLevel& level) {
    const auto lowered = to_lower_copy(value);

    if (lowered == "debug") {
        level = LogLevel::Debug;
        return true;
    }
    if (lowered == "info") {
        level = LogLevel::Info;
        return true;
    }
    if (lowered == "warn") {
        level = LogLevel::Warn;
        return true;
    }
    if (lowered == "error") {
        level = LogLevel::Error;
        return true;
    }

    return false;
}

const char* to_string(const LogLevel level) {
    switch (level) {
        case LogLevel::Debug:
            return "DEBUG";
        case LogLevel::Info:
            return "INFO";
        case LogLevel::Warn:
            return "WARN";
        case LogLevel::Error:
            return "ERROR";
    }

    return "UNKNOWN";
}

Logger::Logger(const LogLevel minimum_level) : minimum_level_(minimum_level) {}

void Logger::debug(const std::string& message) const {
    log(LogLevel::Debug, message);
}

void Logger::info(const std::string& message) const {
    log(LogLevel::Info, message);
}

void Logger::warn(const std::string& message) const {
    log(LogLevel::Warn, message);
}

void Logger::error(const std::string& message) const {
    log(LogLevel::Error, message);
}

bool Logger::should_log(const LogLevel level) const {
    return static_cast<int>(level) >= static_cast<int>(minimum_level_);
}

void Logger::log(const LogLevel level, const std::string& message) const {
    if (!should_log(level)) {
        return;
    }

    std::cerr << "[" << to_string(level) << "] " << message << '\n';
}

}  // namespace retriever
