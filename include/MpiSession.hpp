#pragma once

namespace retriever {

class MpiSession {
public:
    MpiSession(int& argc, char**& argv);
    ~MpiSession();

    MpiSession(const MpiSession&) = delete;
    MpiSession& operator=(const MpiSession&) = delete;

    int rank() const;
    int size() const;

private:
    bool owns_mpi_ = false;
    int rank_ = 0;
    int size_ = 1;
};

}  // namespace retriever
