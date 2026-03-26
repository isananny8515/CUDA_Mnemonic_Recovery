#ifndef _HASH_LOOKUP_HOST_H
#define _HASH_LOOKUP_HOST_H
#include <cuda_runtime.h>
#include <cstring>
#include <mutex>
#include <string>
#include <vector>

typedef struct hash160 {
	uint32_t h[5];

	// hash160: computes 160.
	hash160(const uint32_t hash[5])
	{
		memcpy(h, hash, sizeof(uint32_t) * 5);
	}
}hash160;

class CudaHashLookup {

private:
	uint8_t* _bloomHostData[100];  // CPU-side bloom data, loaded once from files
	size_t   _bloomHostSize[100];  // byte count per bloom slot
	int      _bloomCount;
	bool     _bloomFilesLoaded;
	std::mutex _mutex;

	cudaError_t loadBloomFromFiles(const std::vector<std::string>& targets);
	cudaError_t uploadBloomToGPU();

	void cleanup();

public:

	// CudaHashLookup: computes lookup for cuda.
	CudaHashLookup() : _bloomCount(0), _bloomFilesLoaded(false)
	{
		// Initialize all host bloom pointers to null.
		for (int a = 0; a < 100; ++a) {
			_bloomHostData[a] = nullptr;
			_bloomHostSize[a] = 0;
		}
	}

	// ~CudaHashLookup: releases resources during object destruction.
	~CudaHashLookup()
	{
		cleanup();
	}

	cudaError_t setTargets(const std::vector<std::string>& targets);
};

#endif
