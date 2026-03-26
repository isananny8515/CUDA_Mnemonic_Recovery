// Author: Mikhail Khoroshavin aka "XopMC"

#include "cuda/Kernel.cuh"
#include "third_party/hash/sha256.h"

#include <algorithm>
#include <atomic>
#include <cstdio>
#include <cstring>
#include <mutex>
#include <string>
#include <utility>
#include <vector>

bool STOP_THREAD = false;
uint64_t false_positive = 0;

extern thread_local int DEVICE_NR;
extern thread_local char* p_str;
extern thread_local unsigned char* p_prv;
extern thread_local uint32_t* p_h160;
extern thread_local uint8_t* p_typ;
extern thread_local uint8_t* p_result_derivation_type;
extern thread_local uint32_t* p_len1;
extern thread_local uint32_t* p_der;
extern thread_local char* p_pas;
extern thread_local uint16_t* p_pas_size;
extern thread_local int64_t* p_round;
extern thread_local unsigned long long* p_results_count;
extern bool g_save_output_with_gpu_prefix;

bool recovery_cpu_verify_enabled();
bool recovery_cpu_verify_hit(const uint32_t* raw_match_words);

namespace {

bool g_silent_mode = false;
bool g_has_passphrases = false;
std::mutex g_result_write_mutex;
std::mutex g_founds_mutex;

thread_local int g_save_output_gpu_id = -1;
thread_local bool g_save_output_stdout_line_start = true;
thread_local bool g_save_output_file_line_start = true;

struct RetrievedResults {
    size_t count = 0;
    std::vector<uint32_t> derivations;
    std::vector<char> mnemonics;
    std::vector<unsigned char> private_keys;
    std::vector<uint32_t> matches;
    std::vector<uint8_t> types;
    std::vector<uint8_t> derivation_types;
    std::vector<uint32_t> lengths;
    std::vector<int64_t> rounds;
    std::vector<char> passphrases;
    std::vector<uint16_t> passphrase_sizes;
};

// save_output_set_gpu_prefix: applies the current worker's GPU output prefix state.
void save_output_set_gpu_prefix(const int gpu_id) {
    g_save_output_gpu_id = gpu_id;
    g_save_output_stdout_line_start = true;
    g_save_output_file_line_start = true;
}

// save_output_apply_gpu_prefix: injects a per-GPU prefix without breaking line boundaries.
std::string save_output_apply_gpu_prefix(FILE* stream, const std::string& input) {
    if (g_save_output_gpu_id < 0 || stream == nullptr || stream == stderr || input.empty()) {
        return input;
    }

    bool* line_start = (stream == stdout) ? &g_save_output_stdout_line_start : &g_save_output_file_line_start;
    const std::string prefix = "GPU " + std::to_string(g_save_output_gpu_id) + ":";

    std::string out;
    out.reserve(input.size() + (prefix.size() * 2u));
    for (const char ch : input) {
        if (*line_start && ch != '\n') {
            out.append(prefix);
            *line_start = false;
        }
        out.push_back(ch);
        if (ch == '\n') {
            *line_start = true;
        }
    }
    return out;
}

// increment_founds: updates the shared found counter safely from save workers.
void increment_founds(std::atomic_uint32_t* pFounds) {
    if (pFounds == nullptr) {
        return;
    }

    pFounds->fetch_add(1u, std::memory_order_relaxed);
}

// increment_false_positive: updates CPU-verify false positives safely from save workers.
void increment_false_positive() {
    std::lock_guard<std::mutex> lock(g_founds_mutex);
    ++false_positive;
}

uint8_t decode_base_type(const uint8_t type) {
    if (type < ENDO_TAG_BASE) {
        return type;
    }

    const uint8_t group = static_cast<uint8_t>((type - ENDO_TAG_BASE) / ENDO_GROUP_STRIDE);
    switch (group) {
    case ENDO_GROUP_COMPRESSED:   return 0x02;
    case ENDO_GROUP_SEGWIT:       return 0x03;
    case ENDO_GROUP_UNCOMPRESSED: return 0x01;
    case ENDO_GROUP_ETH:          return 0x06;
    case ENDO_GROUP_TAPROOT:      return 0x04;
    case ENDO_GROUP_XPOINT:       return 0x05;
    default:                      return type;
    }
}

const char* coin_type_name(const uint8_t type) {
    switch (decode_base_type(type)) {
    case 0x01: return "UNCOMPRESSED";
    case 0x02: return "COMPRESSED";
    case 0x03: return "SEGWIT";
    case 0x04: return "TAPROOT";
    case 0x05: return "XPOINT";
    case 0x06: return "ETH";
    case 0x60: return "SOLANA";
    case 0x80: return "TON(v1r1)";
    case 0x81: return "TON(v1r2)";
    case 0x82: return "TON(v1r3)";
    case 0x83: return "TON(v2r1)";
    case 0x84: return "TON(v2r2)";
    case 0x85: return "TON(v3r1)";
    case 0x86: return "TON(v3r2)";
    case 0x87: return "TON(v4r1)";
    case 0x88: return "TON(v4r2)";
    case 0x89: return "TON(v5r1)";
    default:   return "unknown";
    }
}

const char* derivation_type_name(const uint8_t derivation_type, const uint8_t coin_type) {
    switch (derivation_type) {
    case RESULT_DERIVATION_BIP32_SECP256K1:
        return "bip32-secp256k1";
    case RESULT_DERIVATION_SLIP0010_ED25519:
        return "slip0010-ed25519";
    default:
        switch (decode_base_type(coin_type)) {
        case 0x60:
        case 0x80:
        case 0x81:
        case 0x82:
        case 0x83:
        case 0x84:
        case 0x85:
        case 0x86:
        case 0x87:
        case 0x88:
        case 0x89:
            return "slip0010-ed25519";
        default:
            return "bip32-secp256k1";
        }
    }
}

size_t match_size_for_type(const uint8_t type) {
    switch (decode_base_type(type)) {
    case 0x01:
    case 0x02:
    case 0x03:
    case 0x06:
        return 20;
    case 0x04:
    case 0x05:
    case 0x60:
    case 0x80:
    case 0x81:
    case 0x82:
    case 0x83:
    case 0x84:
    case 0x85:
    case 0x86:
    case 0x87:
    case 0x88:
    case 0x89:
    case 0x8A:
    case 0x8B:
    case 0x8C:
        return 32;
    default:
        return 32;
    }
}

const char* const BASE58_ALPHABET = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";
constexpr uint16_t CRC16_POLY = 0x1021u;
constexpr uint16_t CRC_INIT = 0x0000u;
constexpr uint8_t BOUNCEABLE_TAG = 0x11u;
constexpr uint8_t NON_BOUNCEABLE_TAG = 0x51u;
constexpr uint8_t TEST_FLAG = 0x80u;
const std::string BASE64_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";

std::string hex_encode(const uint8_t* data, const size_t size) {
    static constexpr char kHex[] = "0123456789abcdef";
    std::string out;
    out.resize(size * 2u);
    for (size_t i = 0; i < size; ++i) {
        const uint8_t value = data[i];
        out[(i * 2u) + 0u] = kHex[value >> 4];
        out[(i * 2u) + 1u] = kHex[value & 0x0Fu];
    }
    return out;
}

std::string encodeBase58_d(const uint8_t* bytes, size_t length) {
    if (bytes == nullptr || length == 0u) {
        return std::string();
    }

    size_t zeros = 0u;
    while (zeros < length && bytes[zeros] == 0u) {
        ++zeros;
    }

    std::vector<uint8_t> b58;
    b58.reserve((length - zeros) * 138u / 100u + 1u);

    for (size_t i = zeros; i < length; ++i) {
        uint32_t carry = bytes[i];
        for (size_t j = 0; j < b58.size(); ++j) {
            const uint32_t x = static_cast<uint32_t>(b58[j]) * 256u + carry;
            b58[j] = static_cast<uint8_t>(x % 58u);
            carry = x / 58u;
        }
        while (carry > 0u) {
            b58.push_back(static_cast<uint8_t>(carry % 58u));
            carry /= 58u;
        }
    }

    std::string out;
    out.reserve(zeros + b58.size());
    out.append(zeros, '1');
    for (size_t i = 0; i < b58.size(); ++i) {
        out.push_back(BASE58_ALPHABET[b58[b58.size() - 1u - i]]);
    }
    return out;
}

std::string hash160ToBase58_d(const uint8_t hash160[20], const uint8_t prefix) {
    uint8_t extended[25] = { 0 };
    extended[0] = prefix;
    std::memcpy(&extended[1], hash160, 20u);

    uint8_t hash[32] = { 0 };
    sha256(extended, 21u, hash);
    sha256(hash, 32u, hash);
    std::memcpy(&extended[21], hash, 4u);
    return encodeBase58_d(extended, 25u);
}

uint32_t bech32_polymod_step_d(const uint32_t pre) {
    const uint8_t b = static_cast<uint8_t>(pre >> 25);
    return ((pre & 0x1FFFFFFu) << 5) ^
        (((b >> 0) & 1u) != 0u ? 0x3b6a57b2u : 0u) ^
        (((b >> 1) & 1u) != 0u ? 0x26508e6du : 0u) ^
        (((b >> 2) & 1u) != 0u ? 0x1ea119fau : 0u) ^
        (((b >> 3) & 1u) != 0u ? 0x3d4233ddu : 0u) ^
        (((b >> 4) & 1u) != 0u ? 0x2a1462b3u : 0u);
}

int bech32_encode(char* output, const char* hrp, const uint8_t* data, const size_t data_len, const bool bech32m = false) {
    static constexpr char charset[] = "qpzry9x8gf2tvdw0s3jn54khce6mua7l";

    uint32_t chk = 1u;
    size_t i = 0u;
    while (hrp[i] != 0) {
        const int ch = hrp[i];
        if (ch < 33 || ch > 126 || (ch >= 'A' && ch <= 'Z')) {
            return 0;
        }
        chk = bech32_polymod_step_d(chk) ^ static_cast<uint32_t>(ch >> 5);
        ++i;
    }

    chk = bech32_polymod_step_d(chk);
    while (*hrp != 0) {
        chk = bech32_polymod_step_d(chk) ^ static_cast<uint32_t>(*hrp & 0x1f);
        *(output++) = *(hrp++);
    }
    *(output++) = '1';

    for (i = 0; i < data_len; ++i) {
        if ((data[i] >> 5) != 0u) {
            return 0;
        }
        chk = bech32_polymod_step_d(chk) ^ data[i];
        *(output++) = charset[data[i]];
    }

    for (i = 0; i < 6u; ++i) {
        chk = bech32_polymod_step_d(chk);
    }
    chk ^= (bech32m ? 0x2bc830a3u : 1u);

    for (i = 0; i < 6u; ++i) {
        *(output++) = charset[(chk >> ((5u - i) * 5u)) & 0x1fu];
    }
    *output = 0;
    return 1;
}

int convert_bits(uint8_t* out, size_t* outlen, const int outbits, const uint8_t* in, size_t inlen, const int inbits, const int pad) {
    uint32_t val = 0u;
    int bits = 0;
    const uint32_t maxv = (1u << outbits) - 1u;
    while (inlen-- > 0u) {
        val = (val << inbits) | *(in++);
        bits += inbits;
        while (bits >= outbits) {
            bits -= outbits;
            out[(*outlen)++] = static_cast<uint8_t>((val >> bits) & maxv);
        }
    }

    if (pad != 0) {
        if (bits != 0) {
            out[(*outlen)++] = static_cast<uint8_t>((val << (outbits - bits)) & maxv);
        }
    } else if (((val << (outbits - bits)) & maxv) != 0u || bits >= inbits) {
        return 0;
    }
    return 1;
}

int segwit_addr_encode(char* output, const char* hrp, const uint16_t witver, const uint8_t* witprog, const size_t witprog_len) {
    uint8_t data[65] = { 0 };
    size_t datalen = 0u;
    if (witver > 16u) {
        return 0;
    }
    if (witver == 0u && witprog_len != 20u && witprog_len != 32u) {
        return 0;
    }
    if (witprog_len < 2u || witprog_len > 40u) {
        return 0;
    }

    data[0] = static_cast<uint8_t>(witver);
    convert_bits(data + 1, &datalen, 5, witprog, witprog_len, 8, 1);
    ++datalen;
    return bech32_encode(output, hrp, data, datalen, witver != 0u);
}

uint16_t crc16(const std::vector<uint8_t>& data) {
    uint16_t crc = CRC_INIT;
    for (const uint8_t byte : data) {
        crc ^= static_cast<uint16_t>(byte) << 8;
        for (int i = 0; i < 8; ++i) {
            if ((crc & 0x8000u) != 0u) {
                crc = static_cast<uint16_t>((crc << 1) ^ CRC16_POLY);
            } else {
                crc = static_cast<uint16_t>(crc << 1);
            }
        }
    }
    return static_cast<uint16_t>(crc & 0xFFFFu);
}

std::string base64_encode(const std::vector<uint8_t>& input) {
    std::string encoded;
    encoded.reserve(((input.size() + 2u) / 3u) * 4u);

    int i = 0;
    int j = 0;
    uint8_t char_array_3[3] = { 0 };
    uint8_t char_array_4[4] = { 0 };

    for (const uint8_t byte : input) {
        char_array_3[i++] = byte;
        if (i == 3) {
            char_array_4[0] = (char_array_3[0] & 0xfcu) >> 2;
            char_array_4[1] = static_cast<uint8_t>(((char_array_3[0] & 0x03u) << 4) + ((char_array_3[1] & 0xf0u) >> 4));
            char_array_4[2] = static_cast<uint8_t>(((char_array_3[1] & 0x0fu) << 2) + ((char_array_3[2] & 0xc0u) >> 6));
            char_array_4[3] = static_cast<uint8_t>(char_array_3[2] & 0x3fu);
            for (i = 0; i < 4; ++i) {
                encoded.push_back(BASE64_CHARS[char_array_4[i]]);
            }
            i = 0;
        }
    }

    if (i != 0) {
        for (j = i; j < 3; ++j) {
            char_array_3[j] = '\0';
        }
        char_array_4[0] = (char_array_3[0] & 0xfcu) >> 2;
        char_array_4[1] = static_cast<uint8_t>(((char_array_3[0] & 0x03u) << 4) + ((char_array_3[1] & 0xf0u) >> 4));
        char_array_4[2] = static_cast<uint8_t>(((char_array_3[1] & 0x0fu) << 2) + ((char_array_3[2] & 0xc0u) >> 6));
        for (j = 0; j < i + 1; ++j) {
            encoded.push_back(BASE64_CHARS[char_array_4[j]]);
        }
        while (i++ < 3) {
            encoded.push_back('=');
        }
    }

    return encoded;
}

std::string generate_ton_address(const uint8_t* hash, const bool is_testnet = false, const bool is_bounceable = false, const int8_t workchain = 0) {
    std::vector<uint8_t> address_data;
    address_data.reserve(36u);
    address_data.push_back(is_bounceable ? BOUNCEABLE_TAG : NON_BOUNCEABLE_TAG);
    if (is_testnet) {
        address_data[0] |= TEST_FLAG;
    }
    address_data.push_back(static_cast<uint8_t>(workchain));
    address_data.insert(address_data.end(), hash, hash + 32u);

    const uint16_t checksum = crc16(address_data);
    address_data.push_back(static_cast<uint8_t>(checksum >> 8));
    address_data.push_back(static_cast<uint8_t>(checksum & 0xFFu));
    return base64_encode(address_data);
}

std::string escape_value(const char* value, const size_t size) {
    std::string out;
    out.reserve(size + 8u);
    for (size_t i = 0; i < size; ++i) {
        const char ch = value[i];
        switch (ch) {
        case '\\': out += "\\\\"; break;
        case '"':  out += "\\\""; break;
        case '\n':
        case '\r':
        case '\t':
            out += ' ';
            break;
        default:
            out += ch;
            break;
        }
    }
    return out;
}

std::string escape_value(const std::string& value) {
    return escape_value(value.data(), value.size());
}

bool is_default_derivation_type(const uint8_t type, const uint8_t derivation_type) {
    const uint8_t base_type = decode_base_type(type);
    const bool expects_ed25519 =
        base_type == 0x60u ||
        (base_type >= 0x80u && base_type <= 0x89u);
    if (expects_ed25519) {
        return derivation_type == RESULT_DERIVATION_SLIP0010_ED25519;
    }
    return derivation_type == RESULT_DERIVATION_BIP32_SECP256K1;
}

std::string format_type_label(const uint8_t type, const char* override_label = nullptr) {
    return override_label != nullptr ? override_label : coin_type_name(type);
}

std::string format_derivation_label(const std::string& derivation, const uint8_t type, const uint8_t derivation_type) {
    if (derivation_type == 0u || is_default_derivation_type(type, derivation_type)) {
        return derivation;
    }

    std::string label;
    label.reserve(derivation.size() + 32u);
    label += "(";
    label += derivation_type_name(derivation_type, type);
    label += ") ";
    label += derivation;
    return label;
}

std::string format_round_suffix(const int64_t round) {
    if (round == 0) {
        return std::string();
    }
    return (round > 0 ? " +" : " -") + std::to_string(round > 0 ? round : -round);
}

std::string format_output_value(const uint8_t type, const uint8_t* match_bytes, const size_t match_size, const bool save) {
    if (!save) {
        return hex_encode(match_bytes, match_size);
    }

    switch (decode_base_type(type)) {
    case 0x01:
    case 0x02:
        return hash160ToBase58_d(match_bytes, 0x00u);
    case 0x03:
        return hash160ToBase58_d(match_bytes, 0x05u);
    case 0x04: {
        char output[86] = { 0 };
        return segwit_addr_encode(output, "bc", 1u, match_bytes, 32u) != 0 ? std::string(output) : hex_encode(match_bytes, match_size);
    }
    case 0x05:
        return hex_encode(match_bytes, match_size);
    case 0x06:
        return "0x" + hex_encode(match_bytes, 20u);
    case 0x60:
        return encodeBase58_d(match_bytes, 32u);
    case 0x80:
    case 0x81:
    case 0x82:
    case 0x83:
    case 0x84:
    case 0x85:
    case 0x86:
    case 0x87:
    case 0x88:
    case 0x89:
        return generate_ton_address(match_bytes);
    default:
        return hex_encode(match_bytes, match_size);
    }
}

std::string format_found_line(const std::string& mnemonic,
                              const std::string& derivation,
                              const std::string& private_key_hex,
                              const std::string& round_suffix,
                              const std::string& type_label,
                              const std::string& value,
                              const char* passphrase_raw,
                              const uint16_t passphrase_size) {
    std::string line;
    line.reserve(768u);
    line += "[!] Found: ";
    line += mnemonic;
    line += ":";
    line += derivation;
    line += ":";
    line += private_key_hex;
    line += round_suffix;
    line += ":";
    line += type_label;
    line += ":";
    line += value;
    if (passphrase_raw != nullptr && passphrase_size > 0u) {
        line += ":passphrase=\"";
        line += escape_value(passphrase_raw, passphrase_size);
        line += "\"";
    }
    line += "\n";
    return line;
}

bool activate_result_device() {
    return cudaSetDevice(DEVICE_NR) == cudaSuccess;
}

bool resolve_results_counter(unsigned long long*& counter_ptr) {
    if (p_results_count != nullptr) {
        counter_ptr = p_results_count;
        return true;
    }

    void* raw_counter_ptr = nullptr;
    if (cudaGetSymbolAddress(&raw_counter_ptr, d_resultsCount) != cudaSuccess || raw_counter_ptr == nullptr) {
        return false;
    }

    counter_ptr = reinterpret_cast<unsigned long long*>(raw_counter_ptr);
    return true;
}

bool reset_results_counter() {
    if (!activate_result_device()) {
        return false;
    }

    unsigned long long* counter_ptr = nullptr;
    if (!resolve_results_counter(counter_ptr) || counter_ptr == nullptr) {
        return false;
    }

    return cudaMemset(counter_ptr, 0, sizeof(unsigned long long)) == cudaSuccess;
}

bool cpu_verify_hit(const uint32_t* raw_match_words) {
    if (!recovery_cpu_verify_enabled()) {
        return true;
    }

    if (recovery_cpu_verify_hit(raw_match_words)) {
        return true;
    }

    increment_false_positive();
    return false;
}

bool fetch_results(RetrievedResults& out) {
    if (!activate_result_device()) {
        return false;
    }

    unsigned long long result_count_host = 0;
    unsigned long long* dev_result_count = nullptr;
    if (!resolve_results_counter(dev_result_count) ||
        cudaMemcpy(&result_count_host, dev_result_count, sizeof(result_count_host), cudaMemcpyDeviceToHost) != cudaSuccess) {
        return false;
    }

    if (result_count_host == 0ull) {
        reset_results_counter();
        return true;
    }

    out.count = std::min<size_t>(static_cast<size_t>(result_count_host), static_cast<size_t>(MAX_FOUNDS));
    out.derivations.resize(out.count);
    out.mnemonics.resize(out.count * 512u);
    out.private_keys.resize(out.count * 64u);
    out.matches.resize(out.count * 20u);
    out.types.resize(out.count);
    out.derivation_types.resize(out.count);
    out.lengths.resize(out.count);
    out.rounds.resize(out.count);

    char (*dev_mnemonics)[512] = nullptr;
    unsigned char (*dev_private_keys)[64] = nullptr;
    uint32_t (*dev_matches)[20] = nullptr;
    uint32_t* dev_derivations = nullptr;
    uint8_t* dev_types = nullptr;
    uint8_t* dev_derivation_types = nullptr;
    uint32_t (*dev_lengths)[1] = nullptr;
    int64_t* dev_rounds = nullptr;

    dev_derivations = p_der;
    dev_mnemonics = reinterpret_cast<char (*)[512]>(p_str);
    dev_private_keys = reinterpret_cast<unsigned char (*)[64]>(p_prv);
    dev_matches = reinterpret_cast<uint32_t (*)[20]>(p_h160);
    dev_types = p_typ;
    dev_derivation_types = p_result_derivation_type;
    dev_lengths = reinterpret_cast<uint32_t (*)[1]>(p_len1);
    dev_rounds = p_round;

    if ((dev_derivations == nullptr && cudaMemcpyFromSymbol(&dev_derivations, d_foundDerivations, sizeof(dev_derivations)) != cudaSuccess) ||
        (dev_mnemonics == nullptr && cudaMemcpyFromSymbol(&dev_mnemonics, d_foundStrings, sizeof(dev_mnemonics)) != cudaSuccess) ||
        (dev_private_keys == nullptr && cudaMemcpyFromSymbol(&dev_private_keys, d_foundPrvKeys, sizeof(dev_private_keys)) != cudaSuccess) ||
        (dev_matches == nullptr && cudaMemcpyFromSymbol(&dev_matches, d_foundHash160, sizeof(dev_matches)) != cudaSuccess) ||
        (dev_types == nullptr && cudaMemcpyFromSymbol(&dev_types, d_type, sizeof(dev_types)) != cudaSuccess) ||
        (dev_derivation_types == nullptr && cudaMemcpyFromSymbol(&dev_derivation_types, d_resultDerivationType, sizeof(dev_derivation_types)) != cudaSuccess) ||
        (dev_lengths == nullptr && cudaMemcpyFromSymbol(&dev_lengths, d_len, sizeof(dev_lengths)) != cudaSuccess) ||
        (dev_rounds == nullptr && cudaMemcpyFromSymbol(&dev_rounds, d_round, sizeof(dev_rounds)) != cudaSuccess)) {
        return false;
    }

    if (cudaMemcpy(out.derivations.data(), dev_derivations, out.count * sizeof(uint32_t), cudaMemcpyDeviceToHost) != cudaSuccess ||
        cudaMemcpy(out.mnemonics.data(), dev_mnemonics, out.mnemonics.size() * sizeof(char), cudaMemcpyDeviceToHost) != cudaSuccess ||
        cudaMemcpy(out.private_keys.data(), dev_private_keys, out.private_keys.size() * sizeof(unsigned char), cudaMemcpyDeviceToHost) != cudaSuccess ||
        cudaMemcpy(out.matches.data(), dev_matches, out.matches.size() * sizeof(uint32_t), cudaMemcpyDeviceToHost) != cudaSuccess ||
        cudaMemcpy(out.types.data(), dev_types, out.count * sizeof(uint8_t), cudaMemcpyDeviceToHost) != cudaSuccess ||
        cudaMemcpy(out.derivation_types.data(), dev_derivation_types, out.count * sizeof(uint8_t), cudaMemcpyDeviceToHost) != cudaSuccess ||
        cudaMemcpy(out.lengths.data(), dev_lengths, out.count * sizeof(uint32_t), cudaMemcpyDeviceToHost) != cudaSuccess ||
        cudaMemcpy(out.rounds.data(), dev_rounds, out.count * sizeof(int64_t), cudaMemcpyDeviceToHost) != cudaSuccess) {
        return false;
    }

    if (g_has_passphrases) {
        char (*dev_passphrases)[128] = reinterpret_cast<char (*)[128]>(p_pas);
        uint16_t* dev_passphrase_sizes = p_pas_size;
        out.passphrases.resize(out.count * 128u);
        out.passphrase_sizes.resize(out.count);
        if ((dev_passphrases == nullptr && cudaMemcpyFromSymbol(&dev_passphrases, d_pass, sizeof(dev_passphrases)) != cudaSuccess) ||
            (dev_passphrase_sizes == nullptr && cudaMemcpyFromSymbol(&dev_passphrase_sizes, d_pass_size, sizeof(dev_passphrase_sizes)) != cudaSuccess) ||
            cudaMemcpy(out.passphrases.data(), dev_passphrases, out.passphrases.size() * sizeof(char), cudaMemcpyDeviceToHost) != cudaSuccess ||
            cudaMemcpy(out.passphrase_sizes.data(), dev_passphrase_sizes, out.count * sizeof(uint16_t), cudaMemcpyDeviceToHost) != cudaSuccess) {
            return false;
        }
        cudaMemset(dev_passphrases, 0, out.passphrases.size() * sizeof(char));
        cudaMemset(dev_passphrase_sizes, 0, out.count * sizeof(uint16_t));
    }

    cudaMemset(dev_derivations, 0, out.count * sizeof(uint32_t));
    cudaMemset(dev_mnemonics, 0, out.mnemonics.size() * sizeof(char));
    cudaMemset(dev_private_keys, 0, out.private_keys.size() * sizeof(unsigned char));
    cudaMemset(dev_matches, 0, out.matches.size() * sizeof(uint32_t));
    cudaMemset(dev_types, 0, out.count * sizeof(uint8_t));
    cudaMemset(dev_derivation_types, 0, out.count * sizeof(uint8_t));
    cudaMemset(dev_lengths, 0, out.count * sizeof(uint32_t));
    cudaMemset(dev_rounds, 0, out.count * sizeof(int64_t));
    reset_results_counter();

    return true;
}

std::string derivation_name(const std::vector<std::string>& derivations, const uint32_t index) {
    if (index < derivations.size()) {
        return derivations[index];
    }
    return std::to_string(index);
}

void write_line(FILE* file, const std::string& line) {
    const std::string file_text = save_output_apply_gpu_prefix(file, line);
    const std::string stdout_text = save_output_apply_gpu_prefix(stdout, line);

    std::lock_guard<std::mutex> lock(g_result_write_mutex);
    if (file != nullptr && !file_text.empty()) {
        std::fputs(file_text.c_str(), file);
        std::fflush(file);
    }
    if (!g_silent_mode && !stdout_text.empty()) {
        std::fputs(stdout_text.c_str(), stdout);
        std::fflush(stdout);
    }
}

// SaveResult_Worker: performs CPU verification and output formatting off the recovery dispatch thread.
void SaveResult_Worker(FILE* file,
                       std::atomic_uint32_t* pFounds,
                       bool save,
                       std::vector<std::string> Der_list,
                       RetrievedResults results) {
    for (size_t i = 0; i < results.count; ++i) {
        const uint32_t* match_words = results.matches.data() + (i * 20u);
        if (!cpu_verify_hit(match_words)) {
            continue;
        }

        increment_founds(pFounds);

        const char* mnemonic_raw = results.mnemonics.data() + (i * 512u);
        const uint32_t mnemonic_len = std::min<uint32_t>(results.lengths[i], 511u);
        const std::string mnemonic(mnemonic_raw, mnemonic_raw + mnemonic_len);
        const uint8_t type = results.types[i];
        const unsigned char* private_key = results.private_keys.data() + (i * 64u);
        const size_t match_size = match_size_for_type(type);
        const uint8_t* match_bytes = reinterpret_cast<const uint8_t*>(match_words);
        const std::string derivation = format_derivation_label(
            derivation_name(Der_list, results.derivations[i]),
            type,
            results.derivation_types[i]);
        const std::string private_key_hex = hex_encode(private_key, 32u);
        const std::string round_suffix = format_round_suffix(results.rounds[i]);

        const char* passphrase_raw = nullptr;
        uint16_t passphrase_size = 0u;
        if (save && g_has_passphrases && i < results.passphrase_sizes.size()) {
            passphrase_size = std::min<uint16_t>(results.passphrase_sizes[i], 128u);
            if (passphrase_size > 0u) {
                passphrase_raw = results.passphrases.data() + (i * 128u);
            }
        }

        write_line(file, format_found_line(
            mnemonic,
            derivation,
            private_key_hex,
            round_suffix,
            format_type_label(type),
            format_output_value(type, match_bytes, match_size, save),
            passphrase_raw,
            passphrase_size));

        if (save && decode_base_type(type) == 0x02u) {
            char segwit_output[86] = { 0 };
            if (segwit_addr_encode(segwit_output, "bc", 0u, match_bytes, 20u) != 0) {
                write_line(file, format_found_line(
                    mnemonic,
                    derivation,
                    private_key_hex,
                    round_suffix,
                    format_type_label(type, "P2WPKH"),
                    segwit_output,
                    passphrase_raw,
                    passphrase_size));
            }
        }
    }
}

// drain_save_threads_locked: joins and clears all queued save workers while the caller holds the save mutex.
void drain_save_threads_locked() {
    for (auto& t : g_save_threads) {
        if (t.joinable()) {
            t.join();
        }
    }
    g_save_threads.clear();
}

} // namespace

__host__ void setSilentMode() {
    g_silent_mode = true;
}

__host__ void setPassMode() {
    g_has_passphrases = true;
}

__host__ void SaveResult(FILE* file, std::atomic_uint32_t& Founds, bool save, std::vector<std::string> Der_list) {
    RetrievedResults results;
    if (!fetch_results(results) || results.count == 0u) {
        return;
    }

    std::lock_guard<std::mutex> lock(g_save_threads_mutex);
    const int prefixed_gpu_id = g_save_output_with_gpu_prefix ? DEVICE_NR : -1;
    g_save_threads.emplace_back([prefixed_gpu_id,
                                 file,
                                 pFounds = &Founds,
                                 save,
                                 Der_list = std::move(Der_list),
                                 results = std::move(results)]() mutable {
        save_output_set_gpu_prefix(prefixed_gpu_id);
        SaveResult_Worker(file, pFounds, save, std::move(Der_list), std::move(results));
        save_output_set_gpu_prefix(-1);
    });

    if (FULL) {
        drain_save_threads_locked();
    }
}
