// Author: Mikhail Khoroshavin aka "XopMC"

#include "cuda/Kernel.cuh"

// Recovery-only standalone build keeps a compact device helper layer here
// because the fallback evaluator still needs lightweight 256-bit key stepping.

__device__ void loadBE256toWords(const uint8_t src[32], uint32_t out[8]) {
#pragma unroll
    for (int i = 0; i < 8; ++i) {
        out[i] =
            (static_cast<uint32_t>(src[4 * i + 0]) << 24) |
            (static_cast<uint32_t>(src[4 * i + 1]) << 16) |
            (static_cast<uint32_t>(src[4 * i + 2]) << 8) |
            (static_cast<uint32_t>(src[4 * i + 3]) << 0);
    }
}

__device__ void storeWordsToBE256(const uint32_t in[8], uint8_t dst[32]) {
#pragma unroll
    for (int i = 0; i < 8; ++i) {
        const uint32_t word = in[i];
        dst[4 * i + 0] = static_cast<uint8_t>(word >> 24);
        dst[4 * i + 1] = static_cast<uint8_t>(word >> 16);
        dst[4 * i + 2] = static_cast<uint8_t>(word >> 8);
        dst[4 * i + 3] = static_cast<uint8_t>(word >> 0);
    }
}

__device__ int add64to256_device(const uint32_t in[8], uint64_t val64, uint32_t out[8]) {
    const uint32_t hi = static_cast<uint32_t>(val64 >> 32);
    const uint32_t lo = static_cast<uint32_t>(val64);
    uint64_t carry = 0ull;

    uint64_t sum = static_cast<uint64_t>(in[7]) + lo;
    out[7] = static_cast<uint32_t>(sum);
    carry = sum >> 32;

    sum = static_cast<uint64_t>(in[6]) + hi + carry;
    out[6] = static_cast<uint32_t>(sum);
    carry = sum >> 32;

#pragma unroll
    for (int i = 5; i >= 0; --i) {
        sum = static_cast<uint64_t>(in[i]) + carry;
        out[i] = static_cast<uint32_t>(sum);
        carry = sum >> 32;
    }

    return static_cast<int>(carry);
}

__device__ int sub64from256_device(const uint32_t in[8], uint64_t val64, uint32_t out[8]) {
    const uint32_t hi = static_cast<uint32_t>(val64 >> 32);
    const uint32_t lo = static_cast<uint32_t>(val64);
    uint64_t borrow = 0ull;

    auto sub_word = [&](int index, uint32_t rhs) {
        const uint64_t lhs = static_cast<uint64_t>(in[index]);
        const uint64_t need = static_cast<uint64_t>(rhs) + borrow;
        if (lhs >= need) {
            out[index] = static_cast<uint32_t>(lhs - need);
            borrow = 0ull;
        } else {
            out[index] = static_cast<uint32_t>((1ull << 32) + lhs - need);
            borrow = 1ull;
        }
    };

    sub_word(7, lo);
    sub_word(6, hi);
#pragma unroll
    for (int i = 5; i >= 0; --i) {
        sub_word(i, 0u);
    }

    return static_cast<int>(borrow & 1ull);
}

// Advances a 256-bit private key by +/- n without bringing back the old big-int TU.
__device__ bool bump_key_256(uint8_t* __restrict__ prv32, uint64_t n, bool plus) {
    bool wrapped_to_min = false;
    __align__(16) uint32_t current[8];
    __align__(16) uint32_t result[8];

    loadBE256toWords(prv32, current);
    if (plus) {
        add64to256_device(current, n, result);
    } else {
        sub64from256_device(current, n, result);
    }

    const uint32_t orv =
        result[0] | result[1] | result[2] | result[3] |
        result[4] | result[5] | result[6] | result[7];

    if (plus && orv == 0u) {
        result[0] = 0u;
        result[1] = 0u;
        result[2] = 0u;
        result[3] = 0u;
        result[4] = 0u;
        result[5] = 0u;
        result[6] = 0u;
        result[7] = 2u;
        wrapped_to_min = true;
    }

    storeWordsToBE256(result, prv32);
    return wrapped_to_min;
}
