// Microsoft's compiler has no <sys/time.h>. MicropolisCore's engine uses its
// gettimeofday for the clock that seeds the random numbers and for the
// blinking of the map's warnings; this is the same clock, from the C++
// standard library. See ../unistd.h for why this folder exists.
//
// Part of Metrobits, which is GPLv3 with Electronic Arts' additional terms
// (see LICENSE and micropolis-core/MicropolisGPLLicenseNotice.md).

#pragma once

#include <chrono>
#include <time.h>

struct timeval {
    time_t tv_sec;
    long tv_usec;
};

inline int gettimeofday(struct timeval *tv, void *) {
    using namespace std::chrono;
    const long long now = duration_cast<microseconds>(system_clock::now().time_since_epoch()).count();
    tv->tv_sec = static_cast<time_t>(now / 1000000);
    tv->tv_usec = static_cast<long>(now % 1000000);
    return 0;
}
