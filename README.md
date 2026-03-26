<p align="center">
  <strong>English</strong> |
  <a href="./README.ru.md">Русский</a>
</p>

<p align="center">
  <img src="./docs/media/hero.svg" alt="CUDA_Mnemonic_Recovery hero" width="960">
</p>

<p align="center">
  <img alt="Platform" src="https://img.shields.io/badge/platform-Windows%20%7C%20Linux-0f172a?style=for-the-badge">
  <img alt="CUDA" src="https://img.shields.io/badge/CUDA-ready-0ea5e9?style=for-the-badge">
  <img alt="Focus" src="https://img.shields.io/badge/focus-BIP39%20Recovery-22c55e?style=for-the-badge">
  <img alt="Targets" src="https://img.shields.io/badge/targets-BTC%20%7C%20ETH%20%7C%20SOL%20%7C%20TON-f59e0b?style=for-the-badge">
</p>

# CUDA_Mnemonic_Recovery

Author: Mikhail Khoroshavin aka "XopMC"

`CUDA_Mnemonic_Recovery` is a focused CUDA tool for one very specific job: recover incomplete BIP39 mnemonic phrases quickly, validate them against real targets, and keep the workflow clear enough to trust in a real recovery session.

It is built for practical recovery work: real wildcard templates, real derivation lists, real filters, real multi-GPU runs, and output that stays easy to read when a long session is finally producing hits.

## Why This Tool Exists

- You have a real mnemonic backup with missing words marked as `*`.
- You want to validate candidates against exact hashes, Bloom filters, or XOR filters instead of scrolling through noise.
- You want one tool that can check Bitcoin, Ethereum, Solana, and TON-oriented targets from the same recovery flow.
- You want multi-GPU support without losing clarity or turning the workflow into a maze of unrelated modes.

## Visual Tour

### Command Help

<p>
  <img src="./docs/media/help-terminal.svg" alt="Command help screenshot" width="920">
</p>

### Single-GPU Recovery

<p>
  <img src="./docs/media/single-recovery.svg" alt="Single GPU recovery example" width="920">
</p>

### Multi-GPU Recovery

<p>
  <img src="./docs/media/multigpu-recovery.svg" alt="Multi GPU recovery example" width="920">
</p>

### Recovery Pipeline

<p>
  <img src="./docs/media/pipeline-diagram.svg" alt="Recovery pipeline diagram" width="920">
</p>

### Multi-GPU Work Split

<p>
  <img src="./docs/media/multigpu-diagram.svg" alt="Multi GPU work split diagram" width="920">
</p>

## Highlights

- Recover missing BIP39 words with `*` wildcards.
- Use embedded BIP39 wordlists or force an external `-wordlist FILE`.
- Feed templates inline or from files.
- Check candidates against exact `-hash`, Bloom filters, XOR filters, and optional CPU-side verification.
- Build XOR filters with [XorFilter](https://github.com/XopMC/XorFilter) and plug them straight into the recovery flow.
- Select Bitcoin-like, Ethereum, Solana, and TON target families with one CLI.
- Override derivation routing with `-d_type` when wallet behavior does not match the usual coin-native path.
- Run one GPU or several GPUs with the same recovery workflow.
- Keep save/output compact, readable, and practical for long recovery sessions.

## Supported Target Families

`-c` selects which target families are derived and checked.

| Letter | Family | Typical output |
| --- | --- | --- |
| `c` | Compressed | Bitcoin compressed address / hash160 |
| `u` | Uncompressed | Legacy uncompressed address / hash160 |
| `s` | SegWit | P2SH-wrapped SegWit style output |
| `r` | Taproot | Bech32m taproot output |
| `x` | XPoint | X-only/public point style match |
| `e` | Ethereum | Ethereum address / hash |
| `S` | Solana | Solana public address / raw target |
| `t` | TON | Core TON wallet sweep |
| `T` | TON-all | Extended TON wallet sweep |

Any `-c` letters outside this set are rejected in the public release.

## Build

### Windows with CMake

```powershell
cmake --preset windows-release
cmake --build --preset windows-release --config Release
```

### Windows with Visual Studio

```powershell
msbuild CUDA_Mnemonic_Recovery.sln /p:Configuration=Release /p:Platform=x64
```

### Linux / WSL

```bash
make configure
make build
```

### Force a local `sm_89` build

```powershell
cmake --preset windows-release -D CMAKE_CUDA_ARCHITECTURES=89
cmake --build --preset windows-release --config Release
```

## Prebuilt GitHub Bundles

GitHub Actions is set up to produce two distribution archives:

- `CUDA_Mnemonic_Recovery-windows-builds.zip`
- `CUDA_Mnemonic_Recovery-linux-builds.tar.gz`

Each archive contains these build profiles:

| Profile | Intended cards | Notes |
| --- | --- | --- |
| `sm_61-dlto` | GTX 10xx / Pascal | Dedicated legacy-friendly build |
| `sm_75-dlto` | RTX 20xx / Turing | Best fit for RTX 20xx cards |
| `sm_86-dlto` | RTX 30xx / Ampere | Dedicated Ampere build |
| `sm_89-dlto` | RTX 40xx / Ada | Dedicated Ada build |
| `sm_120-dlto` | RTX 50xx / Blackwell | Dedicated Blackwell build |
| `universal-sm_86-sm_120-dlto` | RTX 30xx / 40xx / 50xx | One binary for modern cards from `sm_86` through `sm_120` |

Release bundles are built with CUDA `12.8` and CUDA device link-time optimization (`-dlto`) enabled. That choice is deliberate: CUDA `12.8` still covers `sm_61` and newer profiles, while the universal `sm_86-sm_120` build stays focused on RTX `30xx` through `50xx`. RTX `20xx` remains on the dedicated `sm_75` build.

The packaged binaries are prepared to be easy to move between machines:

- Windows builds use the static MSVC runtime and static CUDA runtime.
- Linux builds use the static CUDA runtime plus static `libstdc++` / `libgcc`.
- A compatible NVIDIA driver is still required on the target machine.

## Quick Start

### Recover one missing word from the command line

```bash
CUDA_Mnemonic_Recovery -recovery "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon *" -d examples/derivations/default.txt
```

### Recover from a file with template lines

```bash
CUDA_Mnemonic_Recovery -recovery -i examples/templates.txt -d examples/derivations/default.txt
```

### Validate against a real exact hash

```bash
CUDA_Mnemonic_Recovery -device 2 -recovery "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon * *" -d examples/derivations/default.txt -c c -hash d986ed01b7a22225a70edbf2ba7cfb63a15cb3aa
```

### Recover with an XOR filter

```bash
CUDA_Mnemonic_Recovery -recovery -i examples/templates.txt -d examples/derivations/default.txt -xc wallet.xor_c -xx wallet.xor_u -c cus
```

### Recover with passphrases from a file

```bash
CUDA_Mnemonic_Recovery -recovery -i examples/templates.txt -d examples/derivations/default.txt -pass examples/passphrases.txt -c e
```

### Check Solana through BTC-style derivation rules

```bash
CUDA_Mnemonic_Recovery -recovery -i examples/templates.txt -d examples/derivations/default.txt -c S -d_type 1
```

## File Input Formats

### Recovery templates file

Each line is one mnemonic template. Missing words are written as `*`.

Example: [`examples/templates.txt`](./examples/templates.txt)

```text
abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon *
legal winner thank year wave sausage worth useful legal winner thank *
```

Rules:

- one template per line
- use spaces between words
- use `*` for every unknown word
- keep the line as a normal mnemonic phrase, only with missing positions replaced

### Derivations file

Each line is one derivation path.

Example: [`examples/derivations/default.txt`](./examples/derivations/default.txt)

```text
m/44'/0'/0'/0/0
m/49'/0'/0'/0/0
m/84'/0'/0'/0/0
m/86'/0'/0'/0/0
m/44'/60'/0'/0/0
m/44'/501'/0'/0'
m/44'/607'/0'/0/0
```

### Passphrase file

Each line is one passphrase candidate.

Example: [`examples/passphrases.txt`](./examples/passphrases.txt)

```text
TREZOR
wallet-passphrase-example
```

## Command Line Reference

### Recovery sources

| Option | Meaning | Notes |
| --- | --- | --- |
| `-recovery "..."` | Add one template inline | Repeatable |
| `-recovery -i FILE` | Load templates from file | Repeatable |
| `-wordlist FILE` | Override embedded BIP39 wordlist | Must still be a valid 2048-word BIP39 list |
| `-d FILE` | Load derivation paths from file | Required |

### Targets and derivation routing

| Option | Meaning |
| --- | --- |
| `-c TYPES` | Target family selection. Default: `cus` |
| `-d_type 1|2|3` | Force derivation engine: `1=bip32-secp256k1`, `2=slip0010-ed25519`, `3=check both` |

If `-d_type` is omitted, routing stays target-native:

- secp-style targets use the usual BIP32/secp256k1 path
- Solana and TON stay on their native ed25519-oriented route

### Filters and direct targets

| Option | Meaning |
| --- | --- |
| `-hash HEX` | Match an exact target hash or hash prefix |
| `-bf FILE` | Load a Bloom filter |
| `-xu FILE` | Load `.xor_u`, the uncompressed XOR filter format |
| `-xc FILE` | Load `.xor_c`, a compact GPU-side XOR prefilter |
| `-xuc FILE` | Load `.xor_uc`, an even smaller GPU-side XOR prefilter |
| `-xh FILE` | Load `.xor_hc`, the smallest GPU-side XOR prefilter |
| `-xx FILE` | CPU verify using an uncompressed `.xor_u` filter |
| `-xb FILE` | CPU verify with Bloom filter |

## XOR Filters and XorFilter

If you want XOR filters for this project, generate them with [XorFilter](https://github.com/XopMC/XorFilter).

Recommended workflow:

- `.xor_u` is the only XOR format recommended for a full standalone run without extra CPU confirmation.
- `.xor_c`, `.xor_uc`, and `.xor_hc` are compact GPU prefilters. They are excellent for reducing memory and accelerating broad scans, but they should not be treated as the final truth in a full recovery session.
- For `.xor_c`, `.xor_uc`, and `.xor_hc`, add `-xx wallet.xor_u` so the survivors are rechecked on the CPU against an uncompressed `.xor_u` filter.

Practical example:

```bash
CUDA_Mnemonic_Recovery -recovery -i examples/templates.txt -d examples/derivations/default.txt -xc wallet.xor_c -xx wallet.xor_u -c cus
```

That pattern gives you a compact GPU filter on the front end and a precise CPU re-check on the back end.

### Runtime and output

| Option | Meaning |
| --- | --- |
| `-pbkdf N` | Override PBKDF2 iteration count. Default: `2048` |
| `-pass VALUE|FILE` | Use one passphrase string or a passphrase file |
| `-device LIST` | Use one or more GPUs, for example `2`, `2,3`, `0-3` |
| `-b N` | Force CUDA blocks |
| `-t N` | Force CUDA threads per block |
| `-fsize N` | Found-buffer capacity |
| `-o FILE` | Output file. Default: `result.txt` |
| `-save` | Save address-oriented output instead of raw match hash |
| `-silent` | Suppress console hit printing |
| `-h`, `-help` | Show public help |

## Understanding `-save`

The tool keeps compact colon-separated `Found` lines.

Without `-save`, the last field is the raw matched hash/target bytes:

```text
[!] Found: <mnemonic>:<derivation>:<private_key_hex>:COMPRESSED:<matched_hash>
```

With `-save`, the last field becomes the address-oriented output instead:

```text
[!] Found: <mnemonic>:<derivation>:<private_key_hex>:COMPRESSED:<address>
```

What stays the same:

- the private key is still written
- the derivation path is still written
- the coin/type label is still written

What changes:

- raw hash output becomes address-oriented output
- compressed Bitcoin emits an additional `P2WPKH` line

Examples:

```text
[!] Found: ...:COMPRESSED:1LqBGSKuX5yYUonjxT5qGfpUsXKYYWeabA
[!] Found: ...:P2WPKH:bc1qmxrw6qdh5g3ztfcwm0et5l8mvws4eva24kmp8m
[!] Found: ...:ETH:0x9858effd232b4033e47d90003d41ec34ecaeda94
[!] Found: ...:SOLANA:EHqmfkN89RJ7Y33CXM6uCzhVeuywHoJXZZLszBHHZy7o
```

In mixed derivation runs, non-default derivation engines are annotated next to the derivation path, not in the coin label:

```text
[!] Found: ...:(bip32-secp256k1) m/44'/501'/0'/0':<private_key>:SOLANA:<value>
```

## Multi-GPU

Multi-GPU mode is enabled through `-device LIST`.

Examples:

```bash
CUDA_Mnemonic_Recovery -device 2,3 -recovery -i examples/templates.txt -d examples/derivations/default.txt -c c
CUDA_Mnemonic_Recovery -device 0-3 -recovery -i examples/templates.txt -d examples/derivations/default.txt -c cusrxeStT
```

What the tool does in multi-GPU mode:

- initializes one recovery slot per selected GPU
- splits the recovery workload across slots
- keeps per-slot accounting
- aggregates final tested / checksum-valid totals
- keeps async save workers alive until the end of the run

### Reproducible benchmark fixture

Fixture file: [`examples/bench/templates-8x-2missing.txt`](./examples/bench/templates-8x-2missing.txt)

Reference benchmark command:

```bash
CUDA_Mnemonic_Recovery -device 0-3 -recovery -i examples/bench/templates-8x-2missing.txt -d examples/derivations/default.txt -c c -hash d986ed01b7a22225a70edbf2ba7cfb63a15cb3aa -silent
```

Local measurement on this machine after fixing multi-GPU totals:

| GPUs | Devices | Workload | Wall-clock |
| --- | --- | --- | --- |
| 1 | `2` | 8 templates, 2 missing words each, default derivations, exact hash target | `5.42 s` |
| 2 | `2,3` | Same workload | `4.62 s` |
| 4 | `0,1,2,3` | Same workload | `4.13 s` |

Measured speedup on that short benchmark:

- `2 GPU`: about `1.17x`
- `4 GPU`: about `1.31x`

Important note:

- these numbers are honest local measurements, not marketing numbers
- this workload is short and pays a noticeable GPU initialization cost
- longer or heavier workloads can scale differently

## Troubleshooting

### The tool says `-d FILE is required`

That is expected. Public documentation assumes explicit derivation files for recovery runs.

### I want to recover from a file instead of typing the phrase

Use:

```bash
CUDA_Mnemonic_Recovery -recovery -i examples/templates.txt -d examples/derivations/default.txt
```

### My wallet uses unusual derivation logic

Try `-d_type`:

- `-d_type 1` for forced BIP32/secp256k1
- `-d_type 2` for forced SLIP-0010 ed25519
- `-d_type 3` to try both

### `-save` does not show the raw hash anymore

That is by design. `-save` switches the last field to address-oriented output.

### Can I use several GPUs?

Yes. Use `-device LIST`, for example:

```bash
-device 2,3
-device 0-3
```

## Repository Layout

- `src/app/` entry point, CLI, config
- `src/recovery/` recovery pipeline and host-side runtime
- `src/crypto/` mnemonic, TON, filters, hashes
- `src/cuda/` CUDA recovery workers and device control
- `include/` project headers
- `support/` shared host utilities
- `third_party/` bundled crypto and PBKDF2 code
- `assets/wordlists/` source BIP39 wordlists
- `examples/` ready-to-run sample inputs
- `docs/media/` README visuals and social preview assets

## Responsible Use

This project is intended for legitimate mnemonic recovery workflows only.

Use it only when you have the legal right to recover the wallet, phrase, or backup involved. See [`RESPONSIBLE_USE.md`](./RESPONSIBLE_USE.md) for the short policy and [`SECURITY.md`](./SECURITY.md) for private vulnerability reporting guidance.
