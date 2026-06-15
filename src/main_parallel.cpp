#include "Config.hpp"
#include "Logger.hpp"
#include "MpiSession.hpp"

#include <iostream>
#include <vector>

int main(int argc, char** argv) {
    retriever::MpiSession mpi_session(argc, argv);
    std::vector<const char*> args(argv, argv + argc);

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

    if (mpi_session.rank() == 0) {
        const retriever::Logger logger(result.config.log_level);
        logger.info("Phase 1 scaffold is active.");
        logger.info("Parallel retrieval is not implemented yet.");
    }

    return 0;
}
