# Third-Party Notices

`CUDA_Mnemonic_Recovery` bundles or derives code and data from several third-party components. Their original notices, attribution requirements, and license terms must remain available in source and binary distributions.

## Included Components

| Component | Location | Purpose |
| --- | --- | --- |
| NVIDIA CUDA Toolkit | system dependency | CUDA compilation, runtime, and GPU execution |
| secp256k1 support code | `third_party/secp256k1/` | Bitcoin-style elliptic-curve derivation and address checks |
| ed25519-donna | `third_party/ed25519/` | Solana-related Ed25519 derivation and public-key operations |
| fast PBKDF2 implementation | `third_party/fastpbkdf2/` | Mnemonic seed derivation and passphrase handling |
| Bloom/XOR filter support | `src/crypto/filter.cpp`, `include/recovery/filter.h`, `include/support/xor_filter.cuh`, `include/support/uint128_t.cuh` | Fast candidate filtering and verification |
| Embedded BIP39 wordlists | `include/recovery/RecoveryWordlistsEmbedded.h`, `assets/wordlists/` | Built-in recovery dictionaries packaged into the binary |

## Distribution Notes

- Keep this file together with `LICENSE.txt` when redistributing the project.
- Preserve any upstream notices already embedded in third-party source files.
- If you package binaries, include the licenses or notice texts required by the third-party components you redistribute.
