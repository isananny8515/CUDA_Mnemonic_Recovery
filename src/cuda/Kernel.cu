// Author: Mikhail Khoroshavin aka "XopMC"

#include "cuda/Kernel.cuh"

#include "third_party/secp256k1/secp256k1_common.cuh"
#include "third_party/secp256k1/secp256k1_field.cuh"
#include "third_party/secp256k1/secp256k1_prec8.cuh"
#include "third_party/secp256k1/secp256k1_group.cuh"
#include "third_party/secp256k1/secp256k1_scalar.cuh"
#include "third_party/secp256k1/secp256k1.cuh"
#include "third_party/secp256k1/secp256k1_batch_impl.cuh"






 __constant__ uint32_t _NUM_TARGET_HASHES[1] = { 0 };
 __constant__ uint32_t HASH_TARGET_WORDS[5] = { 0 };
__constant__ uint32_t HASH_TARGET_MASKS[5] = { 0 };
__constant__ uint32_t HASH_TARGET_LEN[1] = { 0 };
__constant__ uint32_t HASH_TARGET_ENABLED[1] = { 0 };
__constant__ __align__(8) uint8_t* _BLOOM_FILTER[100] = { 0 };
__device__ __align__(8) uint32_t* fingerprints_d[25] = { 0 };
__device__ __align__(8) size_t size_d[25] = { 0 };
__device__ __align__(8) size_t arrayLength_d[25] = { 0 };
__device__ __align__(8) size_t segmentCount_d[25] = { 0 };
__device__ __align__(8) size_t segmentCountLength_d[25] = { 0 };
__device__ __align__(8) size_t segmentLength_d[25] = { 0 };
__device__ __align__(8) size_t segmentLengthMask_d[25] = { 0 };

__constant__ __align__(8) uint32_t* fingerprints_d_Un[25] = { 0 };
__device__ __align__(8) size_t size_d_Un[25] = { 0 };
__device__ __align__(8) size_t arrayLength_d_Un[25] = { 0 };
__device__ __align__(8) size_t segmentCount_d_Un[25] = { 0 };
__constant__ __align__(8) size_t segmentCountLength_d_Un[25] = { 0 };
__constant__ __align__(8) size_t segmentLength_d_Un[25] = { 0 };
__constant__ __align__(8) size_t segmentLengthMask_d_Un[25] = { 0 };

__device__ __align__(8) uint16_t* fingerprints_d_Uc[25] = { 0 };
__device__ __align__(8) size_t size_d_Uc[25] = { 0 };
__device__ __align__(8) size_t arrayLength_d_Uc[25] = { 0 };
__device__ __align__(8) size_t segmentCount_d_Uc[25] = { 0 };
__device__ __align__(8) size_t segmentCountLength_d_Uc[25] = { 0 };
__device__ __align__(8) size_t segmentLength_d_Uc[25] = { 0 };
__device__ __align__(8) size_t segmentLengthMask_d_Uc[25] = { 0 };

__device__ __align__(8) uint8_t* fingerprints_d_Hc[25] = { 0 };
__device__ __align__(8) size_t size_d_Hc[25] = { 0 };
__device__ __align__(8) size_t arrayLength_d_Hc[25] = { 0 };
__device__ __align__(8) size_t segmentCount_d_Hc[25] = { 0 };
__device__ __align__(8) size_t segmentCountLength_d_Hc[25] = { 0 };
__device__ __align__(8) size_t segmentLength_d_Hc[25] = { 0 };
__device__ __align__(8) size_t segmentLengthMask_d_Hc[25] = { 0 };

__device__ curandState state;
 __constant__ uint32_t _USE_BLOOM_FILTER[1] = { 0 };
__constant__ int _bloom_count[1] = { 0 };
__device__ int _xor_count[1] = { 0 };
__constant__ int _xor_un_count[1] = { 0 };
__device__ int _xor_uc_count[1] = { 0 };
__device__ int _xor_hc_count[1] = { 0 };

__device__ bool useBloom_d = false;
__device__ bool useXor_d = false;
__device__ bool useXorUn_d = false;
__device__ bool useXorUc_d = false;
__device__ bool useXorHc_d = false;

__constant__ __align__(4) uint8_t salt[12] = { 109, 110, 101, 109, 111, 110, 105, 99, 0, 0, 0, 1 };
__constant__ __align__(4) uint8_t salt_swap[16] = { 99, 105, 110, 111, 109, 101, 110, 109, 0, 0, 0, 0, 1, 0, 0, 0 };
__constant__ __align__(4) uint8_t ton_salt1[20] = { 'T', 'O', 'N', ' ', 'd', 'e', 'f', 'a', 'u', 'l', 't', ' ', 's', 'e', 'e', 'd', 0, 0, 0 , 1 };

__constant__ __align__(4) uint8_t ton_seed_swap[24] = { 'a', 'f', 'e', 'd', ' ', 'N', 'O', 'T','d', 'e', 'e', 's', ' ', 't', 'l', 'u',0,0,0,0,1,0,0,0 };
__constant__ __align__(4) uint8_t ton_salt[16] = { 'T', 'O', 'N', ' ', 'd', 'e', 'f', 'a', 'u', 'l', 't', ' ', 's', 'e', 'e', 'd' };
__constant__ __align__(4) uint8_t key001[16] = { 0x42, 0x69, 0x74, 0x63, 0x6f, 0x69, 0x6e, 0x20, 0x73, 0x65, 0x65, 0x64 , 0, 0, 0, 1 };
__constant__ __align__(4) uint8_t key[12] = { 0x42, 0x69, 0x74, 0x63, 0x6f, 0x69, 0x6e, 0x20, 0x73, 0x65, 0x65, 0x64 };
__constant__ __align__(4) uint8_t ed_key[12] = { 'e', 'd', '2', '5', '5', '1', '9', ' ', 's', 'e', 'e', 'd' };
__constant__ __align__(4) uint8_t ed_key_swap[16] = { 0x20, 0x39, 0x31, 0x35, 0x35, 0x32, 0x64, 0x65, 0, 0, 0, 0, 0x64, 0x65, 0x65, 0x73 };
__constant__ __align__(4) uint8_t key_swap[16] = { 0x20, 0x6e, 0x69, 0x6f, 0x63, 0x74, 0x69, 0x42, 0, 0, 0, 0, 0x64, 0x65, 0x65, 0x73 };
__device__ unsigned long long int d_resultsCount[1] = { 0 };

__constant__ __align__(64) uint8_t SECP_G65[65] = {
  0x04,
  0x79,0xbe,0x66,0x7e,0xf9,0xdc,0xbb,0xac,0x55,0xa0,0x62,0x95,0xce,0x87,0x0b,0x07,
  0x02,0x9b,0xfc,0xdb,0x2d,0xce,0x28,0xd9,0x59,0xf2,0x81,0x5b,0x16,0xf8,0x17,0x98,
  0x48,0x3a,0xda,0x77,0x26,0xa3,0xc4,0x65,0x5d,0xa4,0xfb,0xfc,0x0e,0x11,0x08,0xa8,
  0xfd,0x17,0xb4,0x48,0xa6,0x85,0x54,0x19,0x9c,0x47,0xd0,0x8f,0xfb,0x10,0xd4,0xb8
};

__device__ char           (*d_foundStrings)[512];
__device__ unsigned char  (*d_foundPrvKeys)[64];
__device__ uint32_t(*d_foundHash160)[20];
__device__ uint32_t(*d_len)[1];
__device__ uint8_t* d_type;
__device__ uint8_t* d_resultDerivationType;
__device__ uint32_t* d_foundDerivations;
__device__ char (*d_pass)[128];
__device__ uint16_t* d_pass_size;
__device__ int64_t* d_round;

__device__ bool secp256_d = false;
__device__ bool ed25519_d = false;
__device__ bool ed25519_bip32_d = false;
__device__ bool compressed_dev = false;
__device__ bool uncompressed_dev = false;
__device__ bool segwit_dev = false;
__device__ bool taproot_dev = false;
__device__ bool ethereum_dev = false;
__device__ bool xpoint_dev = false;
__device__ bool solana_dev = false;
__device__ bool ton_dev = false;
__device__ bool ton_all_dev = false;

__device__ uint64_t Seed = 0;
__device__ uint64_t pbkdf2_iterations = 2048;

__device__ uint32_t MAX_FOUNDS_DEV = 0;

__device__ bool FULL_d = false;
__device__ bool IS_PASS = false;



// Kernel entry point: setPASS.
__global__ void setPASS()
{
	IS_PASS = true;
}

// Kernel entry point: setFULL.
__global__ void setFULL()
{
	FULL_d = true;
}

// Kernel entry point: SetCurve.
__global__ void SetCurve(bool secp256, bool ed25519, bool ed25519_bip32, bool compressed, bool uncompressed, bool segwit, bool taproot, bool ethereum, bool xpoint, bool solana, bool ton, bool ton_all) {

	secp256_d = secp256;
	ed25519_d = ed25519;
	ed25519_bip32_d = ed25519_bip32;
	compressed_dev = compressed;
	uncompressed_dev = uncompressed;
	segwit_dev = segwit;
	taproot_dev = taproot;
	ethereum_dev = ethereum;
	xpoint_dev = xpoint;
	solana_dev = solana;
	ton_dev = ton;
	ton_all_dev = ton_all;

}

// Kernel entry point: setFoundSize.
__global__ void setFoundSize(uint32_t max_founds)
{
	MAX_FOUNDS_DEV = max_founds;
	
}

// Kernel entry point: set_iter.
__global__ void set_iter(uint64_t pbkdf_iter)
{
	pbkdf2_iterations = pbkdf_iter;
}
// Kernel entry point: ecmult_big_create.
__global__ void ecmult_big_create(secp256k1_gej* gej_temp, secp256k1_fe* z_ratio, secp256k1_ge_storage* precPtr, size_t precPitch, unsigned int bits) {
	int64_t tIx = threadIdx.x + blockIdx.x * blockDim.x;
	if (tIx != 0) {
		return;
	}
	unsigned int windows;
	size_t window_size;
	size_t i, row;
	secp256k1_fe  fe_zinv;
	secp256k1_ge  ge_temp;
	secp256k1_ge  ge_window_one = secp256k1_ge_const_g;
	secp256k1_gej gej_window_base;

	/* We +1 to account for a possible high 1 bit after converting the privkey to signed digit form.    */
	/* This means our table reaches to 257 bits even though the privkey scalar is at most 256 bits.     */
	//unsigned int bits = (unsigned int)ECMULT_WINDOW_SIZE;
	windows = (256 / bits) + 1;
	window_size = (1 << (bits - 1));
	WINDOWS = windows;
	WINDOW_SIZE = window_size;
	ECMULT_WINDOW_SIZE = bits;
	//size_t total_size = (256 / bits) * window_size + (1 << (256 % bits));

	//windows = WINDOWS;
	//window_size = WINDOW_SIZE;
	//bits = ECMULT_WINDOW_SIZE;

	/* Total number of required point storage elements.                                 */
	/* This differs from the (windows * window_size) because the last row can be shrunk */
	/*   as it only needs to extend enough to include a possible 1 in the 257th bit.    */
	//total_size = (256 / bits) * window_size + (1 << (256 % bits));

	//rtn->gej_temp = (secp256k1_gej*)checked_malloc(&ctx->error_callback, sizeof(secp256k1_gej) * window_size);
	//rtn->z_ratio = (secp256k1_fe*)checked_malloc(&ctx->error_callback, sizeof(secp256k1_fe) * window_size);

	/************ Precomputed Table Initialization ************/
	secp256k1_gej_set_ge(&gej_window_base, &ge_window_one);

	/* This is the same for all windows.    */
	secp256k1_fe_set_int(&(z_ratio[0]), 0);


	for (row = 0; row < windows; row++) {
		/* The last row is a bit smaller, only extending to include the 257th bit. */
		window_size = (row == windows - 1 ? (1 << (256 % bits)) : (1 << (bits - 1)));

		/* The base element of each row is 2^bits times the previous row's base. */
		if (row > 0) {
			for (i = 0; i < bits; i++) {
				secp256k1_gej_double_var(&gej_window_base, &gej_window_base, NULL);
			}
		}
		gej_temp[0] = gej_window_base;

		/* The base element is also our "one" value for this row.   */
		/* If we are at offset 2^X, adding "one" should add 2^X.    */
		secp256k1_ge_set_gej(&ge_window_one, &gej_window_base);


		/* Repeated + 1s to fill the rest of the row.   */

		/* We capture the Z ratios between consecutive points for quick Z inversion.    */
		/*   gej_temp[i-1].z * z_ratio[i] => gej_temp[i].z                              */
		/* This means that z_ratio[i] = (gej_temp[i-1].z)^-1 * gej_temp[i].z            */
		/* If we know gej_temp[i].z^-1, we can get gej_temp[i-1].z^1 using z_ratio[i]   */
		/* Visually:                                    */
		/* i            0           1           2       */
		/* gej_temp     a           b           c       */
		/* z_ratio     NaN      (a^-1)*b    (b^-1)*c    */
		for (i = 1; i < window_size; i++) {
			secp256k1_gej_add_ge_var(&(gej_temp[i]), &(gej_temp[i - 1]), &ge_window_one, &(z_ratio[i]));
		}


		/* An unpacked version of secp256k1_ge_set_table_gej_var() that works   */
		/*   element by element instead of requiring a secp256k1_ge *buffer.    */

		/* Invert the last Z coordinate manually.   */
		i = window_size - 1;
		secp256k1_fe_inv(&fe_zinv, &(gej_temp[i].z));
		secp256k1_ge_set_gej_zinv(&ge_temp, &(gej_temp[i]), &fe_zinv);
		//secp256k1_ge_to_storage(&(prec[row][i]), &ge_temp);
		secp256k1_ge_storage* ROW_PREC = (secp256k1_ge_storage*)((char*)precPtr + row * precPitch) + i;
		secp256k1_ge_to_storage(ROW_PREC, &ge_temp);

		/* Use the last element's known Z inverse to determine the previous' Z inverse. */
		for (; i > 0; i--) {
			/* fe_zinv = (gej_temp[i].z)^-1                 */
			/* (gej_temp[i-1].z)^-1 = z_ratio[i] * fe_zinv  */
			secp256k1_fe_mul(&fe_zinv, &fe_zinv, &(z_ratio[i]));
			/* fe_zinv = (gej_temp[i-1].z)^-1               */

			secp256k1_ge_set_gej_zinv(&ge_temp, &(gej_temp[i - 1]), &fe_zinv);
			//secp256k1_ge_to_storage(&(prec[row][i - 1]), &ge_temp);

			secp256k1_ge_storage* ROW_PRECi_1 = (secp256k1_ge_storage*)((char*)precPtr + row * precPitch) + (i - 1);
			secp256k1_ge_to_storage(ROW_PRECi_1, &ge_temp);
		}
	}
}

// loadHashTarget: loads hash target.
cudaError_t loadHashTarget(const uint32_t words[5], const uint32_t masks[5], uint32_t lenBytes, bool enabled) {
	uint32_t zero_words[5] = { 0, 0, 0, 0, 0 };
	const uint32_t* src_words = (enabled && words) ? words : zero_words;
	const uint32_t* src_masks = (enabled && masks) ? masks : zero_words;
	const uint32_t len = enabled ? lenBytes : 0u;
	const uint32_t en = enabled ? 1u : 0u;

	cudaError_t st = cudaMemcpyToSymbol(HASH_TARGET_WORDS, src_words, sizeof(uint32_t) * 5);
	if (st != cudaSuccess) return st;
	st = cudaMemcpyToSymbol(HASH_TARGET_MASKS, src_masks, sizeof(uint32_t) * 5);
	if (st != cudaSuccess) return st;
	st = cudaMemcpyToSymbol(HASH_TARGET_LEN, &len, sizeof(uint32_t));
	if (st != cudaSuccess) return st;
	return cudaMemcpyToSymbol(HASH_TARGET_ENABLED, &en, sizeof(uint32_t));
}
// cudaMemcpyToSymbol_BLOOM_FILTER: performs cuda memcpy to symbol bloom filter.
cudaError_t cudaMemcpyToSymbol_BLOOM_FILTER(uint8_t* _bloomFilterPtr, int count) {
	int hostValue = count + 1;
	cudaError_t err1 = cudaMemcpyToSymbol(_bloom_count, &hostValue, sizeof(int));

	// Store device pointer in _BLOOM_FILTER[count].
	cudaError_t err2 = cudaMemcpyToSymbol(_BLOOM_FILTER, &_bloomFilterPtr, sizeof(uint8_t*), count * sizeof(uint8_t*), cudaMemcpyHostToDevice);

	// Return setup error immediately if present.
	if (err1 != cudaSuccess) {
		printf("error num blooms\n");
		return err1;
	}
	return err2;
}

// Kernel entry point: setFilterType.
__global__ void setFilterType(bool bloomUse, bool xorFilter, bool xorFilterUn, bool xorFilterUc, bool xorFilterHc)
{
	useBloom_d = bloomUse;
	useXor_d = xorFilter;
	useXorUn_d = xorFilterUn;
	useXorUc_d = xorFilterUc;
	useXorHc_d = xorFilterHc;
	uint64_t rng_counter = 0x726b2b9d438b9d4d;
	Seed = rng_splitmix64(&rng_counter);

}

// Kernel entry point: cudaXORCopy.
__global__ void cudaXORCopy(int count, size_t size_h, size_t arrayLength_h, size_t segmentCount_h, size_t segmentCountLength_h, size_t segmentLength_h, size_t segmentLengthMask_h) {

	size_d[count] = size_h;
	arrayLength_d[count] = arrayLength_h;
	segmentCount_d[count] = segmentCount_h;
	segmentCountLength_d[count] = segmentCountLength_h;
	segmentLength_d[count] = segmentLength_h;
	segmentLengthMask_d[count] = segmentLengthMask_h;

}

// Kernel entry point: cudaXORUnCopy.
__global__ void cudaXORUnCopy(int count, size_t size_h, size_t arrayLength_h, size_t segmentCount_h, size_t segmentCountLength_h, size_t segmentLength_h, size_t segmentLengthMask_h) {
	(void)segmentCountLength_h;
	(void)segmentLength_h;
	(void)segmentLengthMask_h;

	size_d_Un[count] = size_h;
	arrayLength_d_Un[count] = arrayLength_h;
	segmentCount_d_Un[count] = segmentCount_h;

}

// Kernel entry point: cudaXORUcCopy.
__global__ void cudaXORUcCopy(int count, size_t size_h, size_t arrayLength_h, size_t segmentCount_h, size_t segmentCountLength_h, size_t segmentLength_h, size_t segmentLengthMask_h) {

	size_d_Uc[count] = size_h;
	arrayLength_d_Uc[count] = arrayLength_h;
	segmentCount_d_Uc[count] = segmentCount_h;
	segmentCountLength_d_Uc[count] = segmentCountLength_h;
	segmentLength_d_Uc[count] = segmentLength_h;
	segmentLengthMask_d_Uc[count] = segmentLengthMask_h;

}

// Kernel entry point: cudaXORHcCopy.
__global__ void cudaXORHcCopy(int count, size_t size_h, size_t arrayLength_h, size_t segmentCount_h, size_t segmentCountLength_h, size_t segmentLength_h, size_t segmentLengthMask_h) {

	size_d_Hc[count] = size_h;
	arrayLength_d_Hc[count] = arrayLength_h;
	segmentCount_d_Hc[count] = segmentCount_h;
	segmentCountLength_d_Hc[count] = segmentCountLength_h;
	segmentLength_d_Hc[count] = segmentLength_h;
	segmentLengthMask_d_Hc[count] = segmentLengthMask_h;

}

// cudaMemcpyToSymbol_XOR: performs cuda memcpy to symbol xor.
cudaError_t cudaMemcpyToSymbol_XOR(uint32_t* deviceFilter, int count, size_t size_h, size_t arrayLength_h, size_t segmentCount_h, size_t segmentCountLength_h, size_t segmentLength_h, size_t segmentLengthMask_h) {
	int hostValue = count + 1;
	cudaError_t err1 = cudaMemcpyToSymbol(_xor_count, &hostValue, sizeof(int));

	cudaError_t err2 = cudaMemcpyToSymbol(fingerprints_d, &deviceFilter, sizeof(uint32_t*), count * sizeof(uint32_t*), cudaMemcpyHostToDevice);


	cudaXORCopy << <1, 1 >> > (count, size_h, arrayLength_h, segmentCount_h, segmentCountLength_h, segmentLength_h, segmentLengthMask_h);

	if (err1 != cudaSuccess) {
		printf("Error updating XOR filter count\n");
		return err1;
	}


	return err2;
}

// cudaMemcpyToSymbol_XORUn: performs cuda memcpy to symbol xorun.
cudaError_t cudaMemcpyToSymbol_XORUn(uint32_t* deviceFilter, int count, size_t size_h, size_t arrayLength_h, size_t segmentCount_h, size_t segmentCountLength_h, size_t segmentLength_h, size_t segmentLengthMask_h) {
	int hostValue = count + 1;
	cudaError_t err1 = cudaMemcpyToSymbol(_xor_un_count, &hostValue, sizeof(int));

	cudaError_t err2 = cudaMemcpyToSymbol(fingerprints_d_Un, &deviceFilter, sizeof(uint32_t*), count * sizeof(uint32_t*), cudaMemcpyHostToDevice);
	cudaError_t err3 = cudaMemcpyToSymbol(segmentCountLength_d_Un, &segmentCountLength_h, sizeof(size_t), count * sizeof(size_t), cudaMemcpyHostToDevice);
	cudaError_t err4 = cudaMemcpyToSymbol(segmentLength_d_Un, &segmentLength_h, sizeof(size_t), count * sizeof(size_t), cudaMemcpyHostToDevice);
	cudaError_t err5 = cudaMemcpyToSymbol(segmentLengthMask_d_Un, &segmentLengthMask_h, sizeof(size_t), count * sizeof(size_t), cudaMemcpyHostToDevice);


	cudaXORUnCopy << <1, 1 >> > (count, size_h, arrayLength_h, segmentCount_h, segmentCountLength_h, segmentLength_h, segmentLengthMask_h);

	if (err1 != cudaSuccess) {
		printf("Error updating XOR filter count\n");
		return err1;
	}
	if (err2 != cudaSuccess) return err2;
	if (err3 != cudaSuccess) return err3;
	if (err4 != cudaSuccess) return err4;
	if (err5 != cudaSuccess) return err5;


	return cudaSuccess;
}

// cudaMemcpyToSymbol_XORUc: performs cuda memcpy to symbol xoruc.
cudaError_t cudaMemcpyToSymbol_XORUc(uint16_t* deviceFilter, int count, size_t size_h, size_t arrayLength_h, size_t segmentCount_h, size_t segmentCountLength_h, size_t segmentLength_h, size_t segmentLengthMask_h) {
	int hostValue = count + 1;
	cudaError_t err1 = cudaMemcpyToSymbol(_xor_uc_count, &hostValue, sizeof(int));

	cudaError_t err2 = cudaMemcpyToSymbol(fingerprints_d_Uc, &deviceFilter, sizeof(uint16_t*), count * sizeof(uint16_t*), cudaMemcpyHostToDevice);


	cudaXORUcCopy << <1, 1 >> > (count, size_h, arrayLength_h, segmentCount_h, segmentCountLength_h, segmentLength_h, segmentLengthMask_h);

	if (err1 != cudaSuccess) {
		printf("Error updating XOR filter count\n");
		return err1;
	}


	return err2;
}

// cudaMemcpyToSymbol_XORHc: performs cuda memcpy to symbol xorhc.
cudaError_t cudaMemcpyToSymbol_XORHc(uint8_t* deviceFilter, int count, size_t size_h, size_t arrayLength_h, size_t segmentCount_h, size_t segmentCountLength_h, size_t segmentLength_h, size_t segmentLengthMask_h) {
	int hostValue = count + 1;
	cudaError_t err1 = cudaMemcpyToSymbol(_xor_hc_count, &hostValue, sizeof(int));

	cudaError_t err2 = cudaMemcpyToSymbol(fingerprints_d_Hc, &deviceFilter, sizeof(uint8_t*), count * sizeof(uint8_t*), cudaMemcpyHostToDevice);


	cudaXORHcCopy << <1, 1 >> > (count, size_h, arrayLength_h, segmentCount_h, segmentCountLength_h, segmentLength_h, segmentLengthMask_h);

	if (err1 != cudaSuccess) {
		printf("Error updating XOR filter count\n");
		return err1;
	}


	return err2;
}
// loadWindow: loads window.
cudaError_t loadWindow(unsigned int windowSize, unsigned int windows) {
	int _l[1];
	_l[0] = windows;
	cudaMemcpyToSymbol(WINDOWS_SIZE_CONST, _l, 1 * sizeof(unsigned int));
	_l[0] = windowSize;
	return cudaMemcpyToSymbol(ECMULT_WINDOW_SIZE_CONST, _l, 1 * sizeof(unsigned int));
}

