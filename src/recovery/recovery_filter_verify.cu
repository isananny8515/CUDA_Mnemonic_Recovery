// Author: Mikhail Khoroshavin aka "XopMC"

#include "recovery/filter.h"

#include <cstring>

bool recovery_cpu_verify_enabled() {
    return useBloomCPU || useXorCPU;
}

bool recovery_cpu_verify_hit(const uint32_t* raw_match_words) {
    if (!recovery_cpu_verify_enabled()) {
        return true;
    }

    hash160_t probe{};
    std::memcpy(&probe.ul[0], raw_match_words, 32);
    return find_in_bloom(probe);
}
