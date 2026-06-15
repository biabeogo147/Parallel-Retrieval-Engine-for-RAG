#pragma once

#include <string>

namespace retriever {

enum class LogLevel {
    Debug,
    Info,
    Warn,
    Error,
};

bool try_parse_log_level(const std::string& value, LogLevel& level);
const char* to_string(LogLevel level);

class Logger {
public:
    explicit Logger(LogLevel minimum_level);

    void debug(const std::string& message) const;
    void info(const std::string& message) const;
    void warn(const std::string& message) const;
    void error(const std::string& message) const;

private:
    bool should_log(LogLevel level) const;
    void log(LogLevel level, const std::string& message) const;

    LogLevel minimum_level_;
};

}  // namespace retriever
