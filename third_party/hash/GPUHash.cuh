#pragma once
#include <cstdint>
#include "cuda_runtime.h"
#include "device_launch_parameters.h"
// Initialise state
__device__  void SHA256Initialize(uint32_t s[8]);


__device__ void SHA256TransformPre(int level, uint32_t s[8], uint32_t* w, uint32_t* hashPre);

__device__ void SHA256TransformFromPre(const int level, uint32_t s[8], uint32_t* __restrict__ w, const uint32_t* __restrict__  hashPre);

// Perform SHA-256 transformations, process 64-byte chunks
__device__  void SHA256Transform(uint32_t s[8], uint32_t* __restrict__ w);

__device__ void SHA256(const uint8_t* __restrict__ msg, size_t len, uint8_t out[32]);

__device__
void SHA224(const uint8_t* __restrict__ msg, size_t len, uint8_t out[28]);

__device__ void armory_to_chain(const uint8_t* rootkey, uint8_t* chaincode);

__device__ void hmac_sha256(const uint8_t* __restrict__ key, size_t key_len,
    const uint8_t* __restrict__ msg, size_t msg_len,
    uint8_t* out_mac);

__device__ void RIPEMD160Initialize(uint32_t s[5]);

__device__  void RIPEMD160Transform(uint32_t s[5], uint32_t* __restrict__  w);

__device__   void _GetHash160(const unsigned char* __restrict__  pubkey, int& keyLen, uint8_t* __restrict__ hash);


__device__   void _GetHash160Comp(unsigned char* pubkey, int& keyLen, uint8_t* hash);

__device__ void _GetHash160Comp_fast(uint64_t* x, uint8_t isOdd, uint8_t* hash);

// Both odd and !odd compressed hashes from same x. Writes to hash_odd (prefix 0x03) and hash_even (prefix 0x02).
__device__ void _GetHash160CompSym(uint64_t* x, uint8_t* hash_odd, uint8_t* hash_even);

__device__ void _GetHash160Uncomp_fast(uint64_t* x, uint64_t* y, uint8_t* hash);
__device__ void u64x4_to_pubkey65(uint64_t* px, uint64_t* py, unsigned char* out65);
__device__ void u64x4_to_x32(uint64_t* px, unsigned char* out32);


__device__   void _GetHash160ED(unsigned char* pubkey, int& keyLen, uint8_t* hash);




__device__ void _GetHash160(const uint32_t* x32, const uint32_t* y32, uint8_t* hash);

__device__  void _GetHash160P2SHCompFromHash(uint32_t* h, uint32_t* hash);

__device__  void _GetRMD160(const uint32_t* h, uint32_t* hash);

__device__ void MD5(const uint8_t* data, size_t len, uint8_t out16[16]);

__device__ uint32_t crc32_ieee(const uint8_t* data, size_t len);

__device__ void chacha20poly1305_encrypt(const uint8_t key[32], const uint8_t nonce[12], const uint8_t* plaintext, size_t pt_len, uint8_t* ciphertext, uint8_t tag[16]);


// Device helper: easy16_nibble.
__device__ __forceinline__ int easy16_nibble(unsigned char c) {
    if (c >= 'A' && c <= 'Z') c = (unsigned char)(c + ('a' - 'A'));

    switch (c) {
    case 'a': return 0;
    case 's': return 1;
    case 'd': return 2;
    case 'f': return 3;
    case 'g': return 4;
    case 'h': return 5;
    case 'j': return 6;
    case 'k': return 7;
    case 'w': return 8;
    case 'e': return 9;
    case 'r': return 10;
    case 't': return 11;
    case 'u': return 12;
    case 'i': return 13;
    case 'o': return 14;
    case 'n': return 15;
    default:  return -1;
    }
}

__device__ __forceinline__ int armory_easy16_to_bytes(
    const char* s, int len,
    unsigned char* out, int out_cap,
    bool strip_checksum
) {
    int out_i = 0;

    int hi = -1;         
    int line_pos = 0;       

    for (int i = 0; i < len; ++i) {
        unsigned char c = (unsigned char)s[i];

        if (c <= 0x20) continue;

        int v = easy16_nibble(c);
        if (v < 0) return -1; 

        if (hi < 0) {
            hi = v;
            continue;
        }

        unsigned char b = (unsigned char)((hi << 4) | v);
        hi = -1;

        if (!strip_checksum) {
            if (out_i >= out_cap) return -3;
            out[out_i++] = b;
        }
        else {
            if (line_pos < 16) {
                if (out_i >= out_cap) return -3;
                out[out_i++] = b;
            }
            line_pos++;
            if (line_pos == 18) line_pos = 0;
        }
    }

    if (hi >= 0) return -2;   
    if (strip_checksum && line_pos) return -4; 
    return out_i;
}
