#include "MpiSession.hpp"

#include <mpi.h>

namespace retriever {

MpiSession::MpiSession(int& argc, char**& argv) {
    int initialized = 0;
    MPI_Initialized(&initialized);

    if (!initialized) {
        MPI_Init(&argc, &argv);
        owns_mpi_ = true;
    }

    MPI_Comm_rank(MPI_COMM_WORLD, &rank_);
    MPI_Comm_size(MPI_COMM_WORLD, &size_);
}

MpiSession::~MpiSession() {
    int finalized = 0;
    MPI_Finalized(&finalized);

    if (owns_mpi_ && !finalized) {
        MPI_Finalize();
    }
}

int MpiSession::rank() const {
    return rank_;
}

int MpiSession::size() const {
    return size_;
}

}  // namespace retriever
