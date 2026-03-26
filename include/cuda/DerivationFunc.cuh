#pragma once
#include "cuda/Kernel.cuh"

#define DERIV_CACHE_SLOTS 4

// Multi-slot cache for secp256k1 derivation path reuse inside one worker thread.
typedef struct __align__(16) {
	uint32_t prev_offset[DERIV_CACHE_SLOTS];
	uint32_t prev_len[DERIV_CACHE_SLOTS];
	uint32_t valid[DERIV_CACHE_SLOTS];
	uint32_t last_was_normal[DERIV_CACHE_SLOTS];
	uint32_t hmac_precomp_valid[DERIV_CACHE_SLOTS];
	extended_private_key_t parent_key[DERIV_CACHE_SLOTS];
	extended_private_key_t path_end_key[DERIV_CACHE_SLOTS];
	uint8_t cached_pubkey[DERIV_CACHE_SLOTS][33];
	hmac_sha512_precomp_t hmac_precomp[DERIV_CACHE_SLOTS];
} deriv_cache_secp256k1_t;

// Single-slot cache for ed25519 hardened derivation reuse.
typedef struct __align__(16) {
	uint32_t prev_offset;
	uint32_t prev_len;
	uint32_t valid;
	uint32_t hmac_precomp_valid;
	extended_private_key_t parent_key;
	hmac_sha512_precomp_t hmac_precomp;
} deriv_cache_ed25519_t;

// Compares two derivation path prefixes with a small unrolled fast path.
__device__ __forceinline__ bool deriv_prefix_equal(const uint32_t* __restrict__ lhs, const uint32_t* __restrict__ rhs, uint32_t n)
{
	switch (n) {
	case 0: return true;
	case 1: return lhs[0] == rhs[0];
	case 2: return lhs[0] == rhs[0] && lhs[1] == rhs[1];
	case 3: return lhs[0] == rhs[0] && lhs[1] == rhs[1] && lhs[2] == rhs[2];
	case 4: return lhs[0] == rhs[0] && lhs[1] == rhs[1] && lhs[2] == rhs[2] && lhs[3] == rhs[3];
	case 5: return lhs[0] == rhs[0] && lhs[1] == rhs[1] && lhs[2] == rhs[2] && lhs[3] == rhs[3] && lhs[4] == rhs[4];
	case 6: return lhs[0] == rhs[0] && lhs[1] == rhs[1] && lhs[2] == rhs[2] && lhs[3] == rhs[3] && lhs[4] == rhs[4] && lhs[5] == rhs[5];
	case 7: return lhs[0] == rhs[0] && lhs[1] == rhs[1] && lhs[2] == rhs[2] && lhs[3] == rhs[3] && lhs[4] == rhs[4] && lhs[5] == rhs[5] && lhs[6] == rhs[6];
	case 8: return lhs[0] == rhs[0] && lhs[1] == rhs[1] && lhs[2] == rhs[2] && lhs[3] == rhs[3] && lhs[4] == rhs[4] && lhs[5] == rhs[5] && lhs[6] == rhs[6] && lhs[7] == rhs[7];
	default:
		for (uint32_t i = 0; i < n; i++) {
			if (lhs[i] != rhs[i]) return false;
		}
		return true;
	}
}

// Resets secp256k1 derivation cache validity flags.
__device__ __forceinline__ void deriv_cache_reset(deriv_cache_secp256k1_t* cache)
{
	if (cache) {
		for (int s = 0; s < DERIV_CACHE_SLOTS; s++) {
			cache->valid[s] = 0;
		}
	}
}

// Resets ed25519 derivation cache metadata.
__device__ __forceinline__ void deriv_cache_reset(deriv_cache_ed25519_t* cache)
{
	if (cache) {
		cache->valid = 0;
		cache->prev_len = 0;
		cache->prev_offset = 0;
		cache->hmac_precomp_valid = 0;
	}
}

// Derives secp256k1 child private key with optional path-prefix cache acceleration.
__device__ __forceinline__ void get_child_key_secp256k1(const secp256k1_ge_storage* __restrict__ precPtr, const size_t precPitch, const extended_private_key_t* __restrict__ master_private, const uint32_t* __restrict__  d_derivations, const uint32_t currentStringLength,  uint32_t& processedElements, uint8_t* out, deriv_cache_secp256k1_t* cache = nullptr)
{
	const uint32_t path_offset = processedElements;
	const uint32_t* __restrict__ deriv = d_derivations + path_offset;
	processedElements += currentStringLength;

	if (currentStringLength == 0) {
		memcpy(out, master_private->key, 32);
		deriv_cache_reset(cache);
		return;
	}

	if (!cache) {
		extended_private_key_t start_key = *master_private;
		for (uint32_t i = 0; i < currentStringLength; i++) {
			const uint32_t derivationValue = deriv[i];
			if (derivationValue < 0x80000000u) {
				normal_private_child_from_private(precPtr, precPitch, &start_key, &start_key, derivationValue);
			}
			else {
				hardened_private_child_from_private(&start_key, &start_key, derivationValue);
			}
		}
		memcpy(out, start_key.key, 32);
		return;
	}

	extended_private_key_t start_key;
	extended_private_key_t parent_before_last = *master_private;
	uint32_t i = 0;
	bool cache_hit = false;
	bool use_cached_pub = false;
	int hit_slot = -1;
	int best_prefix_len = -1;

	for (int s = 0; s < DERIV_CACHE_SLOTS; s++) {
		if (!cache->valid[s]) continue;
		const uint32_t* slot_deriv = d_derivations + cache->prev_offset[s];
		const uint32_t slot_len = cache->prev_len[s];
		int reuse_len = -1;
		bool is_same_except_last = false;

		if (currentStringLength == slot_len && deriv_prefix_equal(deriv, slot_deriv, currentStringLength - 1)) {
			reuse_len = (int)(currentStringLength - 1);
			is_same_except_last = true;
		}
		else if (slot_len < currentStringLength && deriv_prefix_equal(deriv, slot_deriv, slot_len)) {
			reuse_len = (int)slot_len;
		}
		if (reuse_len > best_prefix_len) {
			best_prefix_len = reuse_len;
			hit_slot = s;
			cache_hit = true;
			if (is_same_except_last) {
				start_key = cache->parent_key[s];
				i = currentStringLength - 1;
				parent_before_last = cache->parent_key[s];
				use_cached_pub = (cache->last_was_normal[s] && deriv[currentStringLength - 1] < 0x80000000u);
			}
			else {
				start_key = cache->path_end_key[s];
				i = slot_len;
				parent_before_last = cache->path_end_key[s];
				use_cached_pub = false;
			}
		}
	}

	if (!cache_hit) {
		start_key = *master_private;
	}

	for (; i < currentStringLength; i++) {
		if (i == currentStringLength - 1) {
			parent_before_last = start_key;
		}
		const uint32_t derivationValue = deriv[i];
		if (derivationValue < 0x80000000u) {
			if (i == currentStringLength - 1 && use_cached_pub && hit_slot >= 0 && cache->hmac_precomp_valid[hit_slot]) {
				normal_private_child_from_private_cached_pub_precomp(&start_key, &start_key, derivationValue, cache->cached_pubkey[hit_slot], &cache->hmac_precomp[hit_slot]);
			}
			else if (i == currentStringLength - 1 && use_cached_pub && hit_slot >= 0) {
				normal_private_child_from_private_cached_pub(&start_key, &start_key, derivationValue, cache->cached_pubkey[hit_slot]);
			}
			else if (cache && i == currentStringLength - 1) {
				normal_private_child_from_private_save_pub(precPtr, precPitch, &start_key, &start_key, derivationValue, cache->cached_pubkey[0]);
			}
			else {
				normal_private_child_from_private(precPtr, precPitch, &start_key, &start_key, derivationValue);
			}
		}
		else {
			if (i == currentStringLength - 1 && cache_hit && hit_slot >= 0 && cache->hmac_precomp_valid[hit_slot]) {
				hardened_private_child_from_private_precomp(&start_key, &start_key, derivationValue, &cache->hmac_precomp[hit_slot]);
			}
			else {
				hardened_private_child_from_private(&start_key, &start_key, derivationValue);
			}
		}
	}

	memcpy(out, start_key.key, 32);

	if (cache) {
		int store_slot = -1;
		for (int s = 0; s < DERIV_CACHE_SLOTS; s++) {
			if (!cache->valid[s]) {
				store_slot = s;
				break;
			}
		}
		if (store_slot < 0) store_slot = 0;

		cache->prev_offset[store_slot] = path_offset;
		cache->prev_len[store_slot] = currentStringLength;
		cache->valid[store_slot] = 1;
		cache->parent_key[store_slot] = parent_before_last;
		cache->path_end_key[store_slot] = start_key;
		if (deriv[currentStringLength - 1] < 0x80000000u) {
			const uint8_t* src = (cache_hit && use_cached_pub && hit_slot >= 0) ? cache->cached_pubkey[hit_slot] : cache->cached_pubkey[0];
			memcpy(cache->cached_pubkey[store_slot], src, 33);
		}
		cache->last_was_normal[store_slot] = (deriv[currentStringLength - 1] < 0x80000000u) ? 1 : 0;
		hmac_sha512_const_precompute((const uint32_t*)parent_before_last.chain_code, &cache->hmac_precomp[store_slot]);
		cache->hmac_precomp_valid[store_slot] = 1;
	}
}

// Derives ed25519 hardened child key with optional one-path cache acceleration.
__device__ __forceinline__ void get_child_key_ed25519(const extended_private_key_t* __restrict__ master_private, const uint32_t* __restrict__  d_derivations, const uint32_t currentStringLength, uint32_t& processedElements, uint8_t* out, deriv_cache_ed25519_t* cache = nullptr)
{
	const uint32_t path_offset = processedElements;
	const uint32_t* __restrict__ deriv = d_derivations + path_offset;
	processedElements += currentStringLength;

	if (currentStringLength == 0) {
		memcpy(out, master_private->key, 32);
		deriv_cache_reset(cache);
		return;
	}

	if (!cache) {
		extended_private_key_t start_key = *master_private;
		for (uint32_t i = 0; i < currentStringLength; i++) {
			uint32_t der_ed = deriv[i];
			if (der_ed < 0x80000000u) {
				der_ed |= 0x80000000u;
			}
			hardened_private_child_from_private_ed25519(&start_key, &start_key, der_ed);
		}
		memcpy(out, start_key.key, 32);
		return;
	}

	extended_private_key_t start_key;
	extended_private_key_t parent_before_last = *master_private;
	uint32_t i = 0;
	bool cache_hit = false;

	if (cache &&
		cache->valid &&
		currentStringLength == cache->prev_len &&
		deriv_prefix_equal(deriv, d_derivations + cache->prev_offset, currentStringLength - 1))
	{
		cache_hit = true;
		start_key = cache->parent_key;
		i = currentStringLength - 1;
		parent_before_last = cache->parent_key;
	}
	else {
		start_key = *master_private;
	}

	for (; i < currentStringLength; i++) {
		if (i == currentStringLength - 1) {
			parent_before_last = start_key;
		}
		uint32_t der_ed = deriv[i];
		if (der_ed < 0x80000000u) {
			der_ed |= 0x80000000u;
		}
		if (i == currentStringLength - 1 && cache_hit && cache->hmac_precomp_valid) {
			hardened_private_child_from_private_ed25519_precomp(&start_key, &start_key, der_ed, &cache->hmac_precomp);
		}
		else {
			hardened_private_child_from_private_ed25519(&start_key, &start_key, der_ed);
		}
	}

	memcpy(out, start_key.key, 32);

	if (cache) {
		cache->prev_offset = path_offset;
		cache->prev_len = currentStringLength;
		cache->valid = 1;
		cache->parent_key = parent_before_last;
		hmac_sha512_const_precompute((const uint32_t*)parent_before_last.chain_code, &cache->hmac_precomp);
		cache->hmac_precomp_valid = 1;
	}
	else {
		deriv_cache_reset(cache);
	}

}

// Derives Cardano CIP-1852 child key (mixed hardened/normal indexes).
__device__ __forceinline__ void get_child_key_cip1852(const extended_private_key_t* __restrict__ master_private, const uint32_t* __restrict__ d_derivations, const uint32_t currentStringLength, uint32_t& processedElements, uint8_t* out32)
{
	if (currentStringLength == 0) {
		memcpy(out32, master_private->key, 32);
		return;
	}

	extended_private_key_t k = *master_private;
	const uint32_t* __restrict__ deriv = d_derivations + processedElements;
	processedElements += currentStringLength;

	for (uint32_t i = 0; i < currentStringLength; i++) {
		const uint32_t idx = deriv[i];
		if (idx & 0x80000000u) {
			ed25519_bip32_ckd_priv_hardened(&k, &k, idx);
		}
		else {
			ed25519_bip32_ckd_priv_normal(&k, &k, idx);
		}
	}
	memcpy(out32, k.key, 32);
}
