// Author: Mikhail Khoroshavin aka "XopMC"

#include "cuda/Kernel.cuh"

#include "third_party/secp256k1/secp256k1.cuh"
#include "third_party/secp256k1/secp256k1_batch_impl.cuh"
#include "third_party/fastpbkdf2/fastpbkdf2.cuh"
#include "third_party/ed25519/ed25519.h"

#include "cuda/DerivationFunc.cuh"

namespace {

__device__ __forceinline__ void recovery_store_found_compat(
    bool* isResult,
    bool* buffResult,
    uint32_t starter,
    uint32_t c_path,
    const char* phrase,
    uint32_t phrase_len,
    const uint8_t* private_key32,
    const void* match_data,
    uint8_t type,
    int64_t current_round,
    const char* pass_start,
    int pass_size,
    uint8_t derivation_tag) {

    buffResult[starter] = true;
    isResult[0] = true;

    const unsigned long long idx = atomicAdd(&d_resultsCount[0], 1ull);
    if (idx >= MAX_FOUNDS_DEV) {
        return;
    }

    d_foundDerivations[idx] = c_path;
    memcpy(d_foundStrings[idx], phrase, phrase_len);
    d_len[idx][0] = phrase_len;
    memcpy(d_foundPrvKeys[idx], private_key32, 32u);
    if (match_data != nullptr) {
        memcpy(d_foundHash160[idx], match_data, 32u);
    }
    d_type[idx] = type;
    d_resultDerivationType[idx] = derivation_tag;
    d_round[idx] = current_round;

    if (IS_PASS) {
        int copy_len = pass_size;
        if (copy_len < 0) {
            copy_len = 0;
        }
        if (copy_len > 128) {
            copy_len = 128;
        }
        d_pass_size[idx] = static_cast<uint16_t>(copy_len);
        if (copy_len > 0 && pass_start != nullptr) {
            memcpy(d_pass[idx], pass_start, static_cast<size_t>(copy_len));
        }
    }
}

__device__ __forceinline__ void evaluate_secp_targets_from_private_key(
    bool* isResult,
    bool* buffResult,
    uint32_t starter,
    uint32_t c_path,
    const char* phrase,
    uint32_t phrase_len,
    const uint8_t* base_private_key,
    const secp256k1_ge_storage* __restrict__ precPtr,
    size_t precPitch,
    bool compressed,
    bool uncompressed,
    bool segwit,
    bool taproot,
    bool ethereum,
    bool xpoint,
    uint64_t round,
    const char* pass_start,
    int pass_size,
    uint8_t derivation_tag) {

    unsigned char pubKeys[65];
    unsigned char prvKeys[32];
    uint32_t hash160[8] = { 0 };
    memcpy(prvKeys, base_private_key, 32u);

    pubKeys[0] = 0x4;
    int keylenskip = 0;

    if (round > 0u) {
        bump_key_256(prvKeys, round, false);
    }

    for (uint64_t s = 0; s <= 2ull * round; ++s) {
        const int64_t current_round = static_cast<int64_t>(s) - static_cast<int64_t>(round);
        if (s == 0ull) {
            secp256k1_ec_pubkey_create(reinterpret_cast<secp256k1_pubkey*>(&pubKeys[1]), prvKeys, precPtr, precPitch);
        }

        if (uncompressed) {
            _GetHash160(pubKeys, keylenskip, reinterpret_cast<uint8_t*>(hash160));
            if (checkHash(hash160)) {
                recovery_store_found_compat(isResult, buffResult, starter, c_path, phrase, phrase_len, prvKeys, hash160, 0x01u, current_round, pass_start, pass_size, derivation_tag);
            }
        }

        if (compressed) {
            _GetHash160Comp(pubKeys, keylenskip, reinterpret_cast<uint8_t*>(hash160));
            if (checkHash(hash160)) {
                recovery_store_found_compat(isResult, buffResult, starter, c_path, phrase, phrase_len, prvKeys, hash160, 0x02u, current_round, pass_start, pass_size, derivation_tag);
            }
        }

        if (segwit) {
            if (!compressed) {
                _GetHash160Comp(pubKeys, keylenskip, reinterpret_cast<uint8_t*>(hash160));
            }
            _GetHash160P2SHCompFromHash(hash160, hash160);
            if (checkHash(hash160)) {
                recovery_store_found_compat(isResult, buffResult, starter, c_path, phrase, phrase_len, prvKeys, hash160, 0x03u, current_round, pass_start, pass_size, derivation_tag);
            }
        }

        if (ethereum) {
            unsigned char keccak_hash[32];
            uint32_t eth_hash160[8] = { 0 };
            keccak(reinterpret_cast<char*>(&pubKeys[1]), 64, keccak_hash, 32);
            for (int h = 12, i = 0; i < 5; ++i) {
                eth_hash160[i] = (keccak_hash[h++]) |
                    ((keccak_hash[h++] << 8) & 0x0000ff00) |
                    ((keccak_hash[h++] << 16) & 0x00ff0000) |
                    ((keccak_hash[h++] << 24) & 0xff000000);
            }
            if (checkHash(eth_hash160)) {
                recovery_store_found_compat(isResult, buffResult, starter, c_path, phrase, phrase_len, prvKeys, eth_hash160, 0x06u, current_round, pass_start, pass_size, derivation_tag);
            }
        }

        if (taproot) {
            uint8_t tap_hash[32] = { 0 };
            TweakTaproot(tap_hash, pubKeys, precPtr, precPitch);
            _GetRMD160(reinterpret_cast<uint32_t*>(tap_hash), hash160);
            if (checkHash(hash160)) {
                recovery_store_found_compat(isResult, buffResult, starter, c_path, phrase, phrase_len, prvKeys, tap_hash, 0x04u, current_round, pass_start, pass_size, derivation_tag);
            }
        }

        if (xpoint) {
            uint32_t xpoint_hash[8] = { 0 };
            memcpy(xpoint_hash, pubKeys + 1, 32u);
            if (checkHash(xpoint_hash)) {
                recovery_store_found_compat(isResult, buffResult, starter, c_path, phrase, phrase_len, prvKeys, xpoint_hash, 0x05u, current_round, pass_start, pass_size, derivation_tag);
            }
        }

        if (s < 2ull * round) {
            const bool wrapped = bump_key_256(prvKeys, 1ull, true);
            if (wrapped) {
                s += 2ull;
                memcpy(pubKeys, SECP_G65, sizeof(SECP_G65));
            }
            pub_add_basepoint_batch_from_prec(&pubKeys[0], 1, +1, precPtr);
        }
    }
}

__device__ __forceinline__ void evaluate_ed25519_targets_from_private_key(
    bool* isResult,
    bool* buffResult,
    uint32_t starter,
    uint32_t c_path,
    const char* phrase,
    uint32_t phrase_len,
    const uint8_t* base_private_key,
    bool solana,
    bool ton,
    bool ton_all,
    uint64_t round,
    const char* pass_start,
    int pass_size,
    uint8_t derivation_tag) {

    unsigned char private_key[32];
    unsigned char public_key[32];
    memcpy(private_key, base_private_key, 32u);

    if (round > 0u) {
        bump_key_256(private_key, round, false);
    }

    for (uint64_t s = 0; s <= 2ull * round; ++s) {
        const int64_t current_round = static_cast<int64_t>(s) - static_cast<int64_t>(round);
        ed25519_key_to_pub(private_key, public_key);

        if (solana && checkHash(reinterpret_cast<uint32_t*>(public_key))) {
            recovery_store_found_compat(isResult, buffResult, starter, c_path, phrase, phrase_len, private_key, public_key, 0x60u, current_round, pass_start, pass_size, derivation_tag);
        }

        if (ton) {
            uint8_t v3r1[32];
            pubkey_to_hash_ton(public_key, "v3r1", v3r1);
            if (checkHash(reinterpret_cast<uint32_t*>(v3r1))) {
                recovery_store_found_compat(isResult, buffResult, starter, c_path, phrase, phrase_len, private_key, v3r1, 0x85u, current_round, pass_start, pass_size, derivation_tag);
            }

            uint8_t v3r2[32];
            pubkey_to_hash_ton(public_key, "v3r2", v3r2);
            if (checkHash(reinterpret_cast<uint32_t*>(v3r2))) {
                recovery_store_found_compat(isResult, buffResult, starter, c_path, phrase, phrase_len, private_key, v3r2, 0x86u, current_round, pass_start, pass_size, derivation_tag);
            }

            uint8_t v4r2[32];
            pubkey_to_hash_ton(public_key, "v4r2", v4r2);
            if (checkHash(reinterpret_cast<uint32_t*>(v4r2))) {
                recovery_store_found_compat(isResult, buffResult, starter, c_path, phrase, phrase_len, private_key, v4r2, 0x88u, current_round, pass_start, pass_size, derivation_tag);
            }

            uint8_t v5r1[32];
            pubkey_to_hash_ton(public_key, "v5r1", v5r1);
            if (checkHash(reinterpret_cast<uint32_t*>(v5r1))) {
                recovery_store_found_compat(isResult, buffResult, starter, c_path, phrase, phrase_len, private_key, v5r1, 0x89u, current_round, pass_start, pass_size, derivation_tag);
            }
        }

        if (ton_all) {
            uint8_t v1r1[32];
            pubkey_to_hash_ton(public_key, "v1r1", v1r1);
            if (checkHash(reinterpret_cast<uint32_t*>(v1r1))) {
                recovery_store_found_compat(isResult, buffResult, starter, c_path, phrase, phrase_len, private_key, v1r1, 0x80u, current_round, pass_start, pass_size, derivation_tag);
            }

            uint8_t v1r2[32];
            pubkey_to_hash_ton(public_key, "v1r2", v1r2);
            if (checkHash(reinterpret_cast<uint32_t*>(v1r2))) {
                recovery_store_found_compat(isResult, buffResult, starter, c_path, phrase, phrase_len, private_key, v1r2, 0x81u, current_round, pass_start, pass_size, derivation_tag);
            }

            uint8_t v1r3[32];
            pubkey_to_hash_ton(public_key, "v1r3", v1r3);
            if (checkHash(reinterpret_cast<uint32_t*>(v1r3))) {
                recovery_store_found_compat(isResult, buffResult, starter, c_path, phrase, phrase_len, private_key, v1r3, 0x82u, current_round, pass_start, pass_size, derivation_tag);
            }

            uint8_t v2r1[32];
            pubkey_to_hash_ton(public_key, "v2r1", v2r1);
            if (checkHash(reinterpret_cast<uint32_t*>(v2r1))) {
                recovery_store_found_compat(isResult, buffResult, starter, c_path, phrase, phrase_len, private_key, v2r1, 0x83u, current_round, pass_start, pass_size, derivation_tag);
            }

            uint8_t v2r2[32];
            pubkey_to_hash_ton(public_key, "v2r2", v2r2);
            if (checkHash(reinterpret_cast<uint32_t*>(v2r2))) {
                recovery_store_found_compat(isResult, buffResult, starter, c_path, phrase, phrase_len, private_key, v2r2, 0x84u, current_round, pass_start, pass_size, derivation_tag);
            }

            uint8_t v3r1[32];
            pubkey_to_hash_ton(public_key, "v3r1", v3r1);
            if (checkHash(reinterpret_cast<uint32_t*>(v3r1))) {
                recovery_store_found_compat(isResult, buffResult, starter, c_path, phrase, phrase_len, private_key, v3r1, 0x85u, current_round, pass_start, pass_size, derivation_tag);
            }

            uint8_t v3r2[32];
            pubkey_to_hash_ton(public_key, "v3r2", v3r2);
            if (checkHash(reinterpret_cast<uint32_t*>(v3r2))) {
                recovery_store_found_compat(isResult, buffResult, starter, c_path, phrase, phrase_len, private_key, v3r2, 0x86u, current_round, pass_start, pass_size, derivation_tag);
            }

            uint8_t v4r1[32];
            pubkey_to_hash_ton(public_key, "v4r1", v4r1);
            if (checkHash(reinterpret_cast<uint32_t*>(v4r1))) {
                recovery_store_found_compat(isResult, buffResult, starter, c_path, phrase, phrase_len, private_key, v4r1, 0x87u, current_round, pass_start, pass_size, derivation_tag);
            }

            uint8_t v4r2[32];
            pubkey_to_hash_ton(public_key, "v4r2", v4r2);
            if (checkHash(reinterpret_cast<uint32_t*>(v4r2))) {
                recovery_store_found_compat(isResult, buffResult, starter, c_path, phrase, phrase_len, private_key, v4r2, 0x88u, current_round, pass_start, pass_size, derivation_tag);
            }

            uint8_t v5r1[32];
            pubkey_to_hash_ton(public_key, "v5r1", v5r1);
            if (checkHash(reinterpret_cast<uint32_t*>(v5r1))) {
                recovery_store_found_compat(isResult, buffResult, starter, c_path, phrase, phrase_len, private_key, v5r1, 0x89u, current_round, pass_start, pass_size, derivation_tag);
            }
        }

        if (s < 2ull * round) {
            bump_key_256(private_key, 1ull, true);
        }
    }
}

} // namespace

// Fallback evaluator for prepared recovery candidates that still need
// the full recovery target pipeline.
__global__ KERNEL_LAUNCH_BOUNDS void workerRecoveryCompat(bool* isResult, bool* buffResult, const secp256k1_ge_storage* __restrict__ precPtr, const size_t precPitch, char* __restrict__ lines, const uint32_t* __restrict__ indexes, const uint32_t indexes_size, const uint32_t* __restrict__ d_derivations, const uint32_t* __restrict__ derindex, const uint32_t der_indexes_size, const uint32_t der_start_index, const char* __restrict__ passwd, const uint32_t pass_size, uint64_t round) {
    const uint32_t tIx = blockIdx.x * blockDim.x + threadIdx.x;
    if (tIx >= indexes_size) {
        return;
    }

    const bool use_secp_derivation = secp256_d;
    const bool use_ed25519_derivation = ed25519_d;
    const bool use_ed25519_bip32_derivation = ed25519_bip32_d;

    const bool compressed = compressed_dev;
    const bool uncompressed = uncompressed_dev;
    const bool segwit = segwit_dev;
    const bool taproot = taproot_dev;
    const bool ethereum = ethereum_dev;
    const bool xpoint = xpoint_dev;
    const bool solana = solana_dev;
    const bool ton = ton_dev;
    const bool ton_all = ton_all_dev;

    const bool need_secp_targets = compressed || uncompressed || segwit || taproot || ethereum || xpoint;
    const bool need_ed_targets = solana || ton || ton_all;
    if ((!use_secp_derivation && !use_ed25519_derivation && !use_ed25519_bip32_derivation) || (!need_secp_targets && !need_ed_targets)) {
        return;
    }

    char* line_start;
    uint32_t line_len = 0u;
    if (tIx == 0u) {
        line_start = lines;
        line_len = indexes[0];
    }
    else {
        line_start = lines + indexes[tIx - 1];
        line_len = indexes[tIx] - indexes[tIx - 1];
    }

    char phrase[512] = { 0 };
    memcpy(phrase, line_start, line_len);

    const char* pass_start = passwd;
    const int pass_size_i = static_cast<int>(pass_size);

    const uint8_t* pbkdf_salt = salt;
    uint32_t pbkdf_salt_len = 8u;
    uint8_t pbkdf_salt_buf[128 + 8] = { 0 };
    if (pass_size_i > 0) {
        memcpy(pbkdf_salt_buf, pbkdf_salt, 8u);
        memcpy(pbkdf_salt_buf + 8u, pass_start, static_cast<size_t>(pass_size_i));
        pbkdf_salt = pbkdf_salt_buf;
        pbkdf_salt_len = 8u + static_cast<uint32_t>(pass_size_i);
    }

    __align__(16) uint32_t seed[64 / 4] = { 0 };
    fastpbkdf2_hmac_sha512(reinterpret_cast<const uint8_t*>(phrase), line_len, pbkdf_salt, pbkdf_salt_len, pbkdf2_iterations, reinterpret_cast<uint8_t*>(seed), 64u);

#pragma unroll
    for (int x = 0; x < 8; ++x) {
        reinterpret_cast<uint64_t*>(seed)[x] = SWAP512(reinterpret_cast<uint64_t*>(seed)[x]);
    }

    __align__(16) uint32_t secp_ipad[256 / 4] = { 0 };
    __align__(16) uint32_t secp_opad[256 / 4] = { 0 };
    __align__(16) uint32_t ed_ipad[256 / 4] = { 0 };
    __align__(16) uint32_t ed_opad[256 / 4] = { 0 };

    extended_private_key_t* secp_master_private = nullptr;
    extended_private_key_t* ed25519_master_private = nullptr;

    if (use_ed25519_derivation || use_ed25519_bip32_derivation) {
#pragma unroll
        for (int x = 0; x < 16 / 4; ++x) {
            ed_ipad[x] = 0x36363636u ^ reinterpret_cast<const uint32_t*>(&ed_key_swap)[x];
            ed_opad[x] = 0x5C5C5C5Cu ^ reinterpret_cast<const uint32_t*>(&ed_key_swap)[x];
        }
#pragma unroll
        for (int x = 16 / 4; x < 128 / 4; ++x) {
            ed_ipad[x] = 0x36363636u;
            ed_opad[x] = 0x5C5C5C5Cu;
        }
#pragma unroll
        for (int x = 0; x < 64 / 4; ++x) {
            ed_ipad[x + (128 / 4)] = seed[x];
        }
        sha512_swap(reinterpret_cast<uint64_t*>(ed_ipad), 192u, reinterpret_cast<uint64_t*>(&ed_opad[128 / 4]));
        sha512_swap(reinterpret_cast<uint64_t*>(ed_opad), 192u, reinterpret_cast<uint64_t*>(&ed_ipad[128 / 4]));
#pragma unroll
        for (int x = 0; x < 128 / 8; ++x) {
            reinterpret_cast<uint64_t*>(&ed_ipad[128 / 4])[x] = SWAP512(reinterpret_cast<uint64_t*>(&ed_ipad[128 / 4])[x]);
        }
        ed25519_master_private = reinterpret_cast<extended_private_key_t*>(&ed_ipad[128 / 4]);
    }

    if (use_secp_derivation) {
#pragma unroll
        for (int x = 0; x < 16 / 4; ++x) {
            secp_ipad[x] = 0x36363636u ^ reinterpret_cast<const uint32_t*>(&key_swap)[x];
            secp_opad[x] = 0x5C5C5C5Cu ^ reinterpret_cast<const uint32_t*>(&key_swap)[x];
        }
#pragma unroll
        for (int x = 16 / 4; x < 128 / 4; ++x) {
            secp_ipad[x] = 0x36363636u;
            secp_opad[x] = 0x5C5C5C5Cu;
        }
#pragma unroll
        for (int x = 0; x < 64 / 4; ++x) {
            secp_ipad[x + (128 / 4)] = seed[x];
        }
        sha512_swap(reinterpret_cast<uint64_t*>(secp_ipad), 192u, reinterpret_cast<uint64_t*>(&secp_opad[128 / 4]));
        sha512_swap(reinterpret_cast<uint64_t*>(secp_opad), 192u, reinterpret_cast<uint64_t*>(&secp_ipad[128 / 4]));
#pragma unroll
        for (int x = 0; x < 128 / 8; ++x) {
            reinterpret_cast<uint64_t*>(&secp_ipad[128 / 4])[x] = SWAP512(reinterpret_cast<uint64_t*>(&secp_ipad[128 / 4])[x]);
        }
        secp_master_private = reinterpret_cast<extended_private_key_t*>(&secp_ipad[128 / 4]);
    }

    uint32_t processed_elements_se = 0u;
    uint32_t processed_elements_ed = 0u;
    uint32_t processed_elements_ed_bip32 = 0u;
    deriv_cache_secp256k1_t secp_deriv_cache = {};
    deriv_cache_ed25519_t ed_deriv_cache = {};
    deriv_cache_secp256k1_t* secp_deriv_cache_ptr = (der_indexes_size > (der_start_index + 1u)) ? &secp_deriv_cache : nullptr;
    deriv_cache_ed25519_t* ed_deriv_cache_ptr = (der_indexes_size > (der_start_index + 1u)) ? &ed_deriv_cache : nullptr;
    uint32_t c_path = 0u;

    for (uint32_t start_point = der_start_index; start_point < der_indexes_size; ++start_point) {
        const uint32_t current_string_length = derindex[start_point];

        if (use_secp_derivation && secp_master_private != nullptr) {
            unsigned char secp_child_private[32] = { 0 };
            get_child_key_secp256k1(precPtr, precPitch, secp_master_private, d_derivations, current_string_length, processed_elements_se, secp_child_private, secp_deriv_cache_ptr);

            if (need_secp_targets) {
                evaluate_secp_targets_from_private_key(isResult, buffResult, tIx, c_path, phrase, line_len, secp_child_private, precPtr, precPitch, compressed, uncompressed, segwit, taproot, ethereum, xpoint, round, pass_start, pass_size_i, RESULT_DERIVATION_BIP32_SECP256K1);
            }
            if (need_ed_targets) {
                evaluate_ed25519_targets_from_private_key(isResult, buffResult, tIx, c_path, phrase, line_len, secp_child_private, solana, ton, ton_all, round, pass_start, pass_size_i, RESULT_DERIVATION_BIP32_SECP256K1);
            }
        }

        if (use_ed25519_derivation && ed25519_master_private != nullptr) {
            unsigned char ed_child_private[32] = { 0 };
            get_child_key_ed25519(ed25519_master_private, d_derivations, current_string_length, processed_elements_ed, ed_child_private, ed_deriv_cache_ptr);

            if (need_secp_targets) {
                evaluate_secp_targets_from_private_key(isResult, buffResult, tIx, c_path, phrase, line_len, ed_child_private, precPtr, precPitch, compressed, uncompressed, segwit, taproot, ethereum, xpoint, round, pass_start, pass_size_i, RESULT_DERIVATION_SLIP0010_ED25519);
            }
            if (need_ed_targets) {
                evaluate_ed25519_targets_from_private_key(isResult, buffResult, tIx, c_path, phrase, line_len, ed_child_private, solana, ton, ton_all, round, pass_start, pass_size_i, RESULT_DERIVATION_SLIP0010_ED25519);
            }
        }

        if (use_ed25519_bip32_derivation && ed25519_master_private != nullptr) {
            unsigned char ed_bip32_child_private[32] = { 0 };
            get_child_key_ed25519_bip32(ed25519_master_private, d_derivations, current_string_length, processed_elements_ed_bip32, ed_bip32_child_private);

            if (need_secp_targets) {
                evaluate_secp_targets_from_private_key(isResult, buffResult, tIx, c_path, phrase, line_len, ed_bip32_child_private, precPtr, precPitch, compressed, uncompressed, segwit, taproot, ethereum, xpoint, round, pass_start, pass_size_i, RESULT_DERIVATION_ED25519_BIP32_TEST);
            }
            if (need_ed_targets) {
                evaluate_ed25519_targets_from_private_key(isResult, buffResult, tIx, c_path, phrase, line_len, ed_bip32_child_private, solana, ton, ton_all, round, pass_start, pass_size_i, RESULT_DERIVATION_ED25519_BIP32_TEST);
            }
        }

        ++c_path;
    }
}
