#include "Config.hpp"
#include "Logger.hpp"

#include <iostream>

int main(int argc, const char* const argv[]) {
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
    logger.info("Phase 1 scaffold is active.");
    logger.info("Sequential retrieval is not implemented yet.");
    return 0;
}
