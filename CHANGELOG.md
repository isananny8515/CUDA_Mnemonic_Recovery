# Changelog

All notable changes to `CUDA_Mnemonic_Recovery` will be documented in this file.

## Unreleased

- polished public-facing console wording and visuals
- moved benchmark methodology into `BENCHMARKS.md`
- added `VALIDATION.md`, `CITATION.cff`, and `RELEASE_CHECKLIST.md`
- added fixed validation fixtures and release-validation scripts
- separated experimental `-d_type 4` documentation from core production claims

## v1.0.0 - 2026-03-27

- initial public release of the standalone BIP39 recovery tool
- Windows and Linux build bundles
- multi-GPU support
- exact hash, Bloom, XOR, `-save`, and passphrase support
- cross-derivation routing with `-d_type 1/2/3`
- experimental `-d_type 4` available as an explicit advanced mode
