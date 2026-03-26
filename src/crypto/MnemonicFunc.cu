// Author: Mikhail Khoroshavin aka "XopMC"

#include "cuda/Kernel.cuh"
#include "support/Words.cuh"

#include "third_party/secp256k1/secp256k1.cuh"
#include "third_party/secp256k1/secp256k1_batch_impl.cuh"
#include "third_party/secp256k1/secp256k1_field.cuh"
#include "third_party/secp256k1/secp256k1_group.cuh"
#include "third_party/secp256k1/secp256k1_scalar.cuh"
#include "third_party/fastpbkdf2/fastpbkdf2.cuh"
#include "third_party/ed25519/ed25519.h"

__device__ __align__(8) const char(*current_dict)[34] = { 0 };

__device__
// hardened_private_child_from_private: performs hardened private child from private.
void hardened_private_child_from_private(const extended_private_key_t* parent, extended_private_key_t* child, uint32_t hardened_child_number) {

	uint32_t hmacsha512_result[16];
	uint8_t hmac_input[40];
	hmac_input[0] = 0;
	memcpy(&hmac_input[1], parent->key, 32);
	hmac_input[33] = (hardened_child_number >> 24) & 0xFF;
	hmac_input[34] = (hardened_child_number >> 16) & 0xFF;
	hmac_input[35] = (hardened_child_number >> 8) & 0xFF;
	hmac_input[36] = hardened_child_number & 0xFF;
	hmac_sha512_const((uint32_t*)parent->chain_code, (uint32_t*)&hmac_input, hmacsha512_result);
	secp256k1_ec_seckey_tweak_add((uint8_t*)hmacsha512_result, (const uint8_t*)parent->key);
	memcpy(child->key, hmacsha512_result, 32);
	memcpy(child->chain_code, &hmacsha512_result[8], 32);
}

__device__
// hardened_private_child_from_private_precomp: performs hardened private child from private precomp.
void hardened_private_child_from_private_precomp(const extended_private_key_t* parent, extended_private_key_t* child, uint32_t hardened_child_number, const hmac_sha512_precomp_t* hctx) {
	uint8_t hmacsha512_result[64];
	uint8_t hmac_input[40];
	hmac_input[0] = 0;
	memcpy(&hmac_input[1], parent->key, 32);
	hmac_input[33] = (hardened_child_number >> 24) & 0xFF;
	hmac_input[34] = (hardened_child_number >> 16) & 0xFF;
	hmac_input[35] = (hardened_child_number >> 8) & 0xFF;
	hmac_input[36] = hardened_child_number & 0xFF;
	hmac_sha512_const_precomp(hctx, (const uint32_t*)hmac_input, (uint32_t*)hmacsha512_result);
	secp256k1_ec_seckey_tweak_add(hmacsha512_result, (const uint8_t*)parent->key);
	memcpy(child->key, hmacsha512_result, 32);
	memcpy(child->chain_code, hmacsha512_result + 32, 32);
}

__device__
// normal_private_child_from_private: performs normal private child from private.
void normal_private_child_from_private(const secp256k1_ge_storage* __restrict__ precPtr, const size_t precPitch, const extended_private_key_t* parent, extended_private_key_t* child, uint32_t normal_child_number) {
	uint32_t hmacsha512_result[16];
	extended_public_key_t pub;
	secp256k1_ec_pubkey_create((secp256k1_pubkey*)&pub.key, parent->key, precPtr, precPitch);

	uint8_t hmac_input[40];
	serialized_public_key((uint8_t*)&pub.key, (uint8_t*)&hmac_input);
	hmac_input[33] = (normal_child_number >> 24) & 0xFF;
	hmac_input[34] = (normal_child_number >> 16) & 0xFF;
	hmac_input[35] = (normal_child_number >> 8) & 0xFF;
	hmac_input[36] = normal_child_number & 0xFF;

	hmac_sha512_const((uint32_t*)parent->chain_code, (uint32_t*)&hmac_input, hmacsha512_result);
	secp256k1_ec_seckey_tweak_add((uint8_t*)hmacsha512_result, (const uint8_t*)parent->key);
	memcpy(child->key, hmacsha512_result, 32);
	memcpy(child->chain_code, &hmacsha512_result[8], 32);
}

__device__
// normal_private_child_from_private_cached_pub: performs normal private child from private cached pub.
void normal_private_child_from_private_cached_pub(const extended_private_key_t* parent, extended_private_key_t* child, uint32_t normal_child_number, const uint8_t* cached_serialized_pub) {
	uint32_t hmacsha512_result[16];
	uint8_t hmac_input[40];
	memcpy(hmac_input, cached_serialized_pub, 33);
	hmac_input[33] = (normal_child_number >> 24) & 0xFF;
	hmac_input[34] = (normal_child_number >> 16) & 0xFF;
	hmac_input[35] = (normal_child_number >> 8) & 0xFF;
	hmac_input[36] = normal_child_number & 0xFF;
	hmac_sha512_const((uint32_t*)parent->chain_code, (uint32_t*)&hmac_input, hmacsha512_result);
	secp256k1_ec_seckey_tweak_add((uint8_t*)hmacsha512_result, (const uint8_t*)parent->key);
	memcpy(child->key, hmacsha512_result, 32);
	memcpy(child->chain_code, &hmacsha512_result[8], 32);
}

__device__
// normal_private_child_from_private_cached_pub_precomp: performs normal private child from private cached pub precomp.
void normal_private_child_from_private_cached_pub_precomp(const extended_private_key_t* parent, extended_private_key_t* child, uint32_t normal_child_number, const uint8_t* cached_serialized_pub, const hmac_sha512_precomp_t* hctx) {
	uint8_t hmacsha512_result[64];
	uint8_t hmac_input[40];
	memcpy(hmac_input, cached_serialized_pub, 33);
	hmac_input[33] = (normal_child_number >> 24) & 0xFF;
	hmac_input[34] = (normal_child_number >> 16) & 0xFF;
	hmac_input[35] = (normal_child_number >> 8) & 0xFF;
	hmac_input[36] = normal_child_number & 0xFF;
	hmac_sha512_const_precomp(hctx, (const uint32_t*)hmac_input, (uint32_t*)hmacsha512_result);
	secp256k1_ec_seckey_tweak_add(hmacsha512_result, (const uint8_t*)parent->key);
	memcpy(child->key, hmacsha512_result, 32);
	memcpy(child->chain_code, hmacsha512_result + 32, 32);
}

__device__
// normal_private_child_from_private_save_pub: saves pub for normal private child from private.
void normal_private_child_from_private_save_pub(const secp256k1_ge_storage* __restrict__ precPtr, const size_t precPitch, const extended_private_key_t* parent, extended_private_key_t* child, uint32_t normal_child_number, uint8_t* out_serialized_pub) {
	uint32_t hmacsha512_result[16];
	extended_public_key_t pub;
	secp256k1_ec_pubkey_create((secp256k1_pubkey*)&pub.key, parent->key, precPtr, precPitch);

	uint8_t hmac_input[40];
	serialized_public_key((uint8_t*)&pub.key, (uint8_t*)&hmac_input);
	memcpy(out_serialized_pub, hmac_input, 33);
	hmac_input[33] = (normal_child_number >> 24) & 0xFF;
	hmac_input[34] = (normal_child_number >> 16) & 0xFF;
	hmac_input[35] = (normal_child_number >> 8) & 0xFF;
	hmac_input[36] = normal_child_number & 0xFF;

	hmac_sha512_const((uint32_t*)parent->chain_code, (uint32_t*)&hmac_input, hmacsha512_result);
	secp256k1_ec_seckey_tweak_add((uint8_t*)hmacsha512_result, (const uint8_t*)parent->key);
	memcpy(child->key, hmacsha512_result, 32);
	memcpy(child->chain_code, &hmacsha512_result[8], 32);
}

// Device helper: hardened_private_child_from_private_ed25519.
__device__  void hardened_private_child_from_private_ed25519(const extended_private_key_t* parent, extended_private_key_t* child, uint32_t hardened_child_number) {
	uint8_t hmacsha512_result[64];
	uint8_t hmac_input[40];
	hmac_input[0] = 0;
	memcpy(&hmac_input[1], parent->key, 32);

	hmac_input[33] = (hardened_child_number >> 24) & 0xFF;
	hmac_input[34] = (hardened_child_number >> 16) & 0xFF;
	hmac_input[35] = (hardened_child_number >> 8) & 0xFF;
	hmac_input[36] = hardened_child_number & 0xFF;
	hmac_sha512_const((uint32_t*)parent->chain_code, (uint32_t*)&hmac_input, (uint32_t*)&hmacsha512_result);

	memcpy(child->key, hmacsha512_result, 32);

	memcpy(child->chain_code, hmacsha512_result + 32, 32);
}

// Device helper: hardened_private_child_from_private_ed25519_precomp.
__device__  void hardened_private_child_from_private_ed25519_precomp(const extended_private_key_t* parent, extended_private_key_t* child, uint32_t hardened_child_number, const hmac_sha512_precomp_t* hctx) {
	uint8_t hmacsha512_result[64];
	uint8_t hmac_input[40];
	hmac_input[0] = 0;
	memcpy(&hmac_input[1], parent->key, 32);
	hmac_input[33] = (hardened_child_number >> 24) & 0xFF;
	hmac_input[34] = (hardened_child_number >> 16) & 0xFF;
	hmac_input[35] = (hardened_child_number >> 8) & 0xFF;
	hmac_input[36] = hardened_child_number & 0xFF;
	hmac_sha512_const_precomp(hctx, (const uint32_t*)hmac_input, (uint32_t*)hmacsha512_result);
	memcpy(child->key, hmacsha512_result, 32);
	memcpy(child->chain_code, hmacsha512_result + 32, 32);
}

__device__ void ed25519_bip32_ckd_priv_hardened(const extended_private_key_t* parent,
	extended_private_key_t* child,
	uint32_t i_hardened)
{
	uint8_t in[1 + 32 + 4];
	uint8_t out64[64];

	in[0] = 0x00;
	memcpy(in + 1, parent->key, 32);
	in[33] = (uint8_t)(i_hardened >> 24);
	in[34] = (uint8_t)(i_hardened >> 16);
	in[35] = (uint8_t)(i_hardened >> 8);
	in[36] = (uint8_t)(i_hardened);

	hmac_sha512_const((const uint32_t*)parent->chain_code,
		(const uint32_t*)in,
		(uint32_t*)out64);

	memcpy(child->key, out64, 32);  // IL
	memcpy(child->chain_code, out64 + 32, 32);  // IR
}

__device__ void ed25519_bip32_ckd_priv_normal(const extended_private_key_t* parent,
	extended_private_key_t* child,
	uint32_t i_normal)
{
	uint8_t A_par[32];
	ed25519_publickey(parent->key, A_par);

	uint8_t inZ[1 + 32 + 4];
	uint8_t Z64[64];
	inZ[0] = 0x02;
	memcpy(inZ + 1, A_par, 32);
	inZ[33] = (uint8_t)(i_normal >> 24);
	inZ[34] = (uint8_t)(i_normal >> 16);
	inZ[35] = (uint8_t)(i_normal >> 8);
	inZ[36] = (uint8_t)(i_normal);

	hmac_sha512_const((const uint32_t*)parent->chain_code,
		(const uint32_t*)inZ,
		(uint32_t*)Z64);

	uint8_t inI2[1 + 32 + 4];
	uint8_t I2[64];
	inI2[0] = 0x03;
	memcpy(inI2 + 1, A_par, 32);
	memcpy(inI2 + 33, inZ + 33, 4);

	hmac_sha512_const((const uint32_t*)parent->chain_code,
		(const uint32_t*)inI2,
		(uint32_t*)I2);

	add_modL_from_bytes(child->key, parent->key, Z64 /* IL */);

	memcpy(child->chain_code, I2 + 32, 32);
}

// Kernel entry point: setDict.
__global__ void setDict(int lang)
{
	if (lang == 0) {
		current_dict = wordsEN;
	}
	else if (lang == 1) {
		current_dict = wordsSP;
	}
	else if (lang == 2) {
		current_dict = wordsJA;
	}
	else if (lang == 3) {
		current_dict = wordsIT;
	}
	else if (lang == 4) {
		current_dict = wordsFR;
	}
	else if (lang == 5) {
		current_dict = wordsCZ;
	}
	else if (lang == 6) {
		current_dict = wordsPO;
	}
	else if (lang == 7) {
		current_dict = wordsKO;
	}
	else if (lang == 8) {
		current_dict = wordsCHS;
	}
	else if (lang == 9) {
		current_dict = wordsCHT;
	}
	else
	{
		current_dict = wordsEN;
	}

}

// Kernel entry point: setDictPointer.
__global__ void setDictPointer(const char (*dict)[34])
{
	if (dict != nullptr) {
		current_dict = dict;
	}
	else {
		current_dict = wordsEN;
	}
}

// Device helper: char.
__device__ __noinline__  void GenerateMnemonic(const char* __restrict__  entropy, size_t entropy_size, char* __restrict__  mnemonic_phrase, const char (*words)[34], size_t& mnemo_len) {
	size_t checksum_size_bits = entropy_size * 8 / 32;
	size_t total_bits = entropy_size * 8 + checksum_size_bits;
	size_t word_count = total_bits / 11;

	uint8_t hash[32];
	sha256_d((uint32_t*)entropy, entropy_size, (uint32_t*)hash);
	size_t bit_offset = 0;
	size_t offset = 0;

	for (size_t i = 0; i < word_count; ++i) {
		size_t index = 0;

#pragma unroll 11
		for (size_t j = 0; j < 11; ++j) {
			size_t byte_pos = bit_offset / 8;
			size_t bit_pos = 7 - (bit_offset % 8);

			uint8_t current_byte = (byte_pos < entropy_size) ? entropy[byte_pos] : hash[byte_pos - entropy_size];
			if (current_byte & (1 << bit_pos)) {
				index |= 1 << (10 - j);
			}
			++bit_offset;
		}


		const char* word_d = words[index];
		size_t word_length = 0;


		while (word_d[word_length] != '\0') {
			++word_length;
		}

		memcpy(mnemonic_phrase + offset, word_d, word_length);
		offset += word_length;


		if (i < word_count - 1) {
			mnemonic_phrase[offset++] = ' ';
		}
	}

	mnemo_len = offset;
}

// Kernel entry point: rand_state.
__global__ void rand_state() {
	int id = threadIdx.x + blockIdx.x * blockDim.x;

	unsigned long long seed = clock64();


	curand_init(seed, id, 0, &state);
}

// Device helper: random32.
__device__ void random32(uint32_t* output, int size) {

	uint32_t id = threadIdx.x + blockIdx.x * blockDim.x;

	for (int i = 0; i < size / 4; i++)
	{
		output[i] = curand(&state) ^ id;
	}
}

__constant__ uint8_t TAG_TAPTWEAK[32] = {
  0xe8,0x0f,0xe1,0x63,0x9c,0x9c,0xa0,0x50,0xe3,0xaf,0x1b,0x39,0xc1,0x43,0xc6,0x3e,
  0x42,0x9c,0xbc,0xeb,0x15,0xd9,0x40,0xfb,0xb5,0xc5,0xa1,0xf4,0xaf,0x57,0xc5,0xe9
};

// Device helper: be32.
__device__ __forceinline__ uint32_t be32(const uint8_t* p) {
	return ((uint32_t)p[0] << 24) | ((uint32_t)p[1] << 16) |
		((uint32_t)p[2] << 8) | ((uint32_t)p[3]);
}

// Device helper: sha256_taptweak_px.
__device__ __inline__ void sha256_taptweak_px(const uint8_t Px[32], uint8_t out[32]) {
	uint32_t H[8];
	SHA256Initialize(H);

	uint32_t w0[16];
#pragma unroll
	for (int i = 0; i < 8; i++) {
		w0[i] = be32(&TAG_TAPTWEAK[4 * i]);
		w0[i + 8] = be32(&TAG_TAPTWEAK[4 * i]);
	}
	SHA256Transform(H, w0);

	uint32_t w1[16];
#pragma unroll
	for (int i = 0; i < 8; i++) {
		w1[i] = be32(&Px[4 * i]);
	}
	w1[8] = 0x80000000U;
#pragma unroll
	for (int i = 9; i < 15; i++) w1[i] = 0;
	w1[15] = 0x00000300U;

	SHA256Transform(H, w1);

#pragma unroll
	for (int i = 0; i < 8; i++) {
		out[4 * i + 0] = (uint8_t)(H[i] >> 24);
		out[4 * i + 1] = (uint8_t)(H[i] >> 16);
		out[4 * i + 2] = (uint8_t)(H[i] >> 8);
		out[4 * i + 3] = (uint8_t)(H[i]);
	}
}

__device__ size_t TweakTaproot_batch(
	uint8_t* __restrict__ out,
	const uint8_t* __restrict__ pub_uncomp,
	const int count,
	const secp256k1_ge_storage* __restrict__ precPtr,
	const size_t precPitch
) {
	secp256k1_scratch scr;
	int produced = 0;

#pragma unroll
	for (int i = 0; i < count; ++i) {
		const uint8_t* p = &pub_uncomp[i * 65];
		if (p[0] != 0x04) {
			scr.gej[i].infinity = 1;
			continue;
		}

		secp256k1_fe x, y;
		(void)secp256k1_fe_set_b32(&x, p + 1);
		(void)secp256k1_fe_set_b32(&y, p + 33);
		secp256k1_ge P;
		secp256k1_ge_set_xy(&P, &x, &y);

		secp256k1_fe_normalize_var(&P.y);
		if (secp256k1_fe_is_odd(&P.y)) {
			secp256k1_ge Pneg = P;
			secp256k1_fe_negate(&Pneg.y, &Pneg.y, 1);
			P = Pneg;
		}

		uint8_t Px[32], h[32];
		secp256k1_fe_normalize_var(&P.x);
		secp256k1_fe_get_b32(Px, &P.x);

		sha256_taptweak_px(Px, h);

		secp256k1_scalar t;
		secp256k1_scalar_set_b32(&t, h, NULL);

		secp256k1_gej tG;
#ifdef ECMULT_BIG_TABLE
		int windowLimit = WINDOWS_SIZE_CONST[0];
		unsigned int wlimit = ECMULT_WINDOW_SIZE_CONST[0];
		secp256k1_ecmult_big(&tG, &t, precPtr, precPitch, windowLimit, wlimit);
#else
		secp256k1_ecmult_gen(&tG, &t);
#endif

		secp256k1_gej_add_ge_var(&scr.gej[i], &tG, &P, NULL);

		if (!scr.gej[i].infinity) {
			scr.fe_in[produced] = scr.gej[i].z;
			produced++;
		}
	}

	if (produced > 0) {
		secp256k1_fe_inv_all_var(produced, scr.fe_out, scr.fe_in);
	}

	int used = 0;
#pragma unroll
	for (int i = 0; i < count; ++i) {
		uint8_t* xo = &out[i * 32];

		if (scr.gej[i].infinity) {
#pragma unroll
			for (int k = 0; k < 32; k++) xo[k] = 0;
			continue;
		}

		secp256k1_ge A;
		secp256k1_ge_set_gej_zinv(&A, &scr.gej[i], &scr.fe_out[used++]);

		secp256k1_fe_normalize_var(&A.y);
		if (secp256k1_fe_is_odd(&A.y)) {
			secp256k1_ge_neg(&A, &A);
		}

		secp256k1_fe_normalize_var(&A.x);
		secp256k1_fe_get_b32(xo, &A.x);
	}

	return (size_t)produced;
}

__device__ void TweakTaproot(
	uint8_t* __restrict__ out,
	const uint8_t* __restrict__ pub_uncomp,
	const secp256k1_ge_storage* __restrict__ precPtr,
	const size_t precPitch
) {
	secp256k1_scratch3 scr;
	int produced = 0;



	const uint8_t* p = &pub_uncomp[0];
	if (p[0] != 0x04) {
		scr.gej.infinity = 1;
		return;
	}

	secp256k1_fe x, y;
	(void)secp256k1_fe_set_b32(&x, p + 1);
	(void)secp256k1_fe_set_b32(&y, p + 33);
	secp256k1_ge P;
	secp256k1_ge_set_xy(&P, &x, &y);

	secp256k1_fe_normalize_var(&P.y);
	if (secp256k1_fe_is_odd(&P.y)) {
		secp256k1_ge Pneg = P;
		secp256k1_fe_negate(&Pneg.y, &Pneg.y, 1);
		P = Pneg;
	}

	uint8_t Px[32], h[32];
	secp256k1_fe_normalize_var(&P.x);
	secp256k1_fe_get_b32(Px, &P.x);

	sha256_taptweak_px(Px, h);

	secp256k1_scalar t;
	secp256k1_scalar_set_b32(&t, h, NULL);

	secp256k1_gej tG;
#ifdef ECMULT_BIG_TABLE
	int windowLimit = WINDOWS_SIZE_CONST[0];
	unsigned int wlimit = ECMULT_WINDOW_SIZE_CONST[0];
	secp256k1_ecmult_big(&tG, &t, precPtr, precPitch, windowLimit, wlimit);
#else
	secp256k1_ecmult_gen(&tG, &t);
#endif

	secp256k1_gej_add_ge_var(&scr.gej, &tG, &P, NULL);

	if (!scr.gej.infinity) {
		scr.fe_in = scr.gej.z;
		produced++;
	}
	

	if (produced > 0) {
		secp256k1_fe_inv_all_var(produced, &scr.fe_out, &scr.fe_in);
	}

	uint8_t* xo = &out[0];

		if (scr.gej.infinity) {
#pragma unroll
			for (int k = 0; k < 32; k++) xo[k] = 0;
			return;
		}

		secp256k1_ge A;
		secp256k1_ge_set_gej_zinv(&A, &scr.gej, &scr.fe_out);

		secp256k1_fe_normalize_var(&A.y);
		if (secp256k1_fe_is_odd(&A.y)) {
			secp256k1_ge_neg(&A, &A);
		}

		secp256k1_fe_normalize_var(&A.x);
		secp256k1_fe_get_b32(xo, &A.x);
	
}

//BIP39 Mnemonic to Entropy

typedef const char (*dict_t)[34];

__device__ __forceinline__ int dict_count() { return 10; }
// Device helper: dict_at.
__device__ __forceinline__ dict_t dict_at(int i) {
	switch (i) {
	default:
	case 0:  return wordsEN;
	case 1:  return wordsSP;
	case 2:  return wordsJA;
	case 3:  return wordsIT;
	case 4:  return wordsFR;
	case 5:  return wordsCZ;
	case 6:  return wordsPO;
	case 7:  return wordsKO;
	case 8:  return wordsCHS;
	case 9:  return wordsCHT;
	}
}


// Device helper: cmp_word_len.
__device__ __forceinline__ int cmp_word_len(const char* a, int alen, const char* b) {
	for (int i = 0;; ++i) {
		char ca = (i < alen) ? a[i] : 0, cb = b[i];
		if (ca != cb) return (unsigned char)ca < (unsigned char)cb ? -1 : 1;
		if (ca == 0) return 0;
	}
}

// Device helper: find_in_dict.
__device__ __forceinline__ int find_in_dict(const char* w, int wl, dict_t d) {
	int lo = 0, hi = 2047;
	while (lo <= hi) {
		int mid = (lo + hi) >> 1;
		int c = cmp_word_len(w, wl, d[mid]);
		if (c == 0) return mid;
		if (c < 0) hi = mid - 1; else lo = mid + 1;
	}
	return -1;
}


// Device helper: pack_indices.
__device__ __forceinline__ int pack_indices(const int* idx, int n, uint8_t* bits/*>= (11*n+7)/8 */) {
	int bitpos = 0;
	for (int i = 0; i < n; ++i) {
		int v = idx[i] & 0x7FF;
		for (int b = 10; b >= 0; --b) {
			int bit = (v >> b) & 1;
			bits[bitpos >> 3] |= (uint8_t)(bit << (7 - (bitpos & 7)));
			++bitpos;
		}
	}
	return bitpos;
}

// Device helper: take_bits_msb.
__device__ __forceinline__ void take_bits_msb(const uint8_t* bits, int ENT_bits, uint8_t* out) {
	int full = ENT_bits >> 3, rem = ENT_bits & 7;
	for (int i = 0; i < full; ++i) out[i] = bits[i];
	if (rem) out[full] = bits[full] & (0xFF << (8 - rem));
}

__device__ int split_words(const char* s, int slen,
	const char* wp[], int wl[], int maxw)
{
	const char* p = s;
	const char* end = s + slen;
	int n = 0;

	while (p < end) {
		while (p < end && *p == ' ') ++p;
		if (p >= end) break;
		const char* a = p;
		while (p < end && *p != ' ') ++p;

		if (n < maxw) {
			wp[n] = a;
			wl[n] = (int)(p - a);
			++n;
		}
		else {
			break;
		}
	}
	return n;
}

// Device helper: mnemonic_to_entropy.
__device__ bool mnemonic_to_entropy(const char* phrase, int slen, uint8_t* out_entropy, uint32_t* out_len)
{
	const int MAXW = 64;
	const char* wp[MAXW]; int wl[MAXW];
	int n = split_words(phrase, slen, wp, wl, MAXW);
	if (n <= 0) return false;

	int idx[MAXW];
	for (int d = 0; d < dict_count(); ++d) {
		dict_t dict = dict_at(d);
		bool ok = true;
		for (int i = 0; i < n; ++i) {
			int k = find_in_dict(wp[i], wl[i], dict);
			if (k < 0) { ok = false; break; }
			idx[i] = k;
		}
		if (!ok) continue;

		const int total_bits = 11 * n;
		const int bits_bytes = (total_bits + 7) >> 3;
		uint8_t bits[(64 * 11 + 7) / 8 + 1];
		for (int i = 0; i < bits_bytes; ++i) bits[i] = 0;

		pack_indices(idx, n, bits);

		int ENT_bits = (total_bits * 32) / 33;
		take_bits_msb(bits, ENT_bits, out_entropy);
		*out_len = (uint32_t)((ENT_bits + 7) >> 3);
		return true;
	}
	return false;
}
