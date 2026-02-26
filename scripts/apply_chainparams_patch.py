#!/usr/bin/env python3
import json
import re
import sys
from pathlib import Path

ROOT = Path(sys.argv[1])
GENESIS_JSON = Path(sys.argv[2])

with GENESIS_JSON.open('r') as f:
    genesis = json.load(f)

# constants
message_start = [0x72, 0x42, 0x54, 0x43]
p2p_port = 19333
rpc_port = 19332
bech32_hrp = "rbc"
p2pkh = 60
p2sh = 85
wif = 188
seed_nodes = [
    "95.111.227.14",
    "95.111.229.108",
    "95.111.239.142",
    "161.97.83.147",
    "161.97.97.83",
    "161.97.114.192",
    "161.97.117.0",
    "194.163.144.177",
    "185.218.126.23",
    "185.239.209.227",
]

pow_limit = "7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"

chainparams = ROOT / "src" / "kernel" / "chainparams.cpp"
baseparams = ROOT / "src" / "chainparamsbase.cpp"

text = chainparams.read_text()

# Update consensus activation heights to 0 and BIP34 hash to genesis
text = re.sub(r"consensus\.BIP34Height = \d+;", "consensus.BIP34Height = 0;", text, count=1)
text = re.sub(r'consensus\.BIP34Hash = uint256\{"[0-9a-f]+"\};',
              f'consensus.BIP34Hash = uint256{{"{genesis["hash"]}"}};', text, count=1)
text = re.sub(r"consensus\.BIP65Height = \d+;", "consensus.BIP65Height = 0;", text, count=1)
text = re.sub(r"consensus\.BIP66Height = \d+;", "consensus.BIP66Height = 0;", text, count=1)
text = re.sub(r"consensus\.CSVHeight = \d+;", "consensus.CSVHeight = 0;", text, count=1)
text = re.sub(r"consensus\.SegwitHeight = \d+;", "consensus.SegwitHeight = 0;", text, count=1)
text = re.sub(r"consensus\.MinBIP9WarningHeight = \d+;", "consensus.MinBIP9WarningHeight = 0;", text, count=1)

# Pow limit and min difficulty
text = re.sub(r'consensus\.powLimit = uint256\{"[0-9a-f]+"\};',
              f'consensus.powLimit = uint256{{"{pow_limit}"}};', text, count=1)
text = re.sub(r"consensus\.fPowAllowMinDifficultyBlocks = false;", "consensus.fPowAllowMinDifficultyBlocks = true;", text, count=1)

# Minimum chain work and assume valid
text = re.sub(r'consensus\.nMinimumChainWork = uint256\{"[0-9a-f]+"\};',
              "consensus.nMinimumChainWork = uint256{};", text, count=1)
text = re.sub(r'consensus\.defaultAssumeValid = uint256\{"[0-9a-f]+"\};',
              "consensus.defaultAssumeValid = uint256{};", text, count=1)

# Message start and ports
text = re.sub(r"pchMessageStart\[0\] = 0x[0-9a-f]+;", f"pchMessageStart[0] = 0x{message_start[0]:02x};", text, count=1)
text = re.sub(r"pchMessageStart\[1\] = 0x[0-9a-f]+;", f"pchMessageStart[1] = 0x{message_start[1]:02x};", text, count=1)
text = re.sub(r"pchMessageStart\[2\] = 0x[0-9a-f]+;", f"pchMessageStart[2] = 0x{message_start[2]:02x};", text, count=1)
text = re.sub(r"pchMessageStart\[3\] = 0x[0-9a-f]+;", f"pchMessageStart[3] = 0x{message_start[3]:02x};", text, count=1)
text = re.sub(r"nDefaultPort = \d+;", f"nDefaultPort = {p2p_port};", text, count=1)

# Genesis block setup
pattern = re.compile(r"genesis = CreateGenesisBlock\([\s\S]*?\);\n\s*consensus\.hashGenesisBlock = genesis\.GetHash\(\);\n\s*assert\(consensus\.hashGenesisBlock == uint256\{\"[0-9a-f]+\"\}\);\n\s*assert\(genesis\.hashMerkleRoot == uint256\{\"[0-9a-f]+\"\}\);", re.MULTILINE)

replacement = (
    f"const char* rbtc_timestamp = \"{genesis['timestamp']}\";\n"
    "        const CScript rbtc_genesis_script = CScript() << \"04678afdb0fe5548271967f1a67130b7105cd6a828e03909a67962e0ea1f61deb649f6bc3f4cef38c4f35504e51ec112de5c384df7ba0b8d578a4c702b6bf11d5f\"_hex << OP_CHECKSIG;\n"
    f"        genesis = CreateGenesisBlock(rbtc_timestamp, rbtc_genesis_script, {genesis['time']}, {genesis['nonce']}, {genesis['bits']}, {genesis['version']}, 50 * COIN);\n"
    "        consensus.hashGenesisBlock = genesis.GetHash();\n"
    f"        assert(consensus.hashGenesisBlock == uint256{{\"{genesis['hash']}\"}});\n"
    f"        assert(genesis.hashMerkleRoot == uint256{{\"{genesis['merkle_root']}\"}});"
)

text, n = pattern.subn(replacement, text, count=1)
if n != 1:
    raise SystemExit("Failed to replace genesis block section")

# Seeds: replace DNS seeds with Contabo fleet bootstrap seeds
seed_lines = "\n        vSeeds.clear();\n" + "".join(
    f'        vSeeds.emplace_back("{seed}");\n' for seed in seed_nodes
)
text = re.sub(
    r"\n\s*base58Prefixes\[PUBKEY_ADDRESS\] =",
    f"{seed_lines}        base58Prefixes[PUBKEY_ADDRESS] =",
    text,
    count=1,
)

# Base58 prefixes and bech32
text = re.sub(r"base58Prefixes\[PUBKEY_ADDRESS\] = std::vector<unsigned char>\(1,\d+\);",
              f"base58Prefixes[PUBKEY_ADDRESS] = std::vector<unsigned char>(1,{p2pkh});", text, count=1)
text = re.sub(r"base58Prefixes\[SCRIPT_ADDRESS\] = std::vector<unsigned char>\(1,\d+\);",
              f"base58Prefixes[SCRIPT_ADDRESS] = std::vector<unsigned char>(1,{p2sh});", text, count=1)
text = re.sub(r"base58Prefixes\[SECRET_KEY\] =\s*std::vector<unsigned char>\(1,\d+\);",
              f"base58Prefixes[SECRET_KEY] =     std::vector<unsigned char>(1,{wif});", text, count=1)
text = re.sub(r"bech32_hrp = \"[a-z0-9]+\";", f"bech32_hrp = \"{bech32_hrp}\";", text, count=1)

# Fixed seeds: clear for mainnet
text = re.sub(r"vFixedSeeds = std::vector<uint8_t>\(std::begin\(chainparams_seed_main\), std::end\(chainparams_seed_main\)\);",
              "vFixedSeeds.clear();", text, count=1)

# Assume chain sizes to 0
text = re.sub(r"m_assumed_blockchain_size = \d+;", "m_assumed_blockchain_size = 0;", text, count=1)
text = re.sub(r"m_assumed_chain_state_size = \d+;", "m_assumed_chain_state_size = 0;", text, count=1)

# Assumeutxo data empty
text = re.sub(r"m_assumeutxo_data = \{[\s\S]*?\};", "m_assumeutxo_data = {};", text, count=1)

chainparams.write_text(text)

# Update base params for main chain
btext = baseparams.read_text()
btext = re.sub(r"return std::make_unique<CBaseChainParams>\(\"\", 8332\);",
               f"return std::make_unique<CBaseChainParams>(\"rbitcoin\", {rpc_port});", btext, count=1)
baseparams.write_text(btext)

print("OK")
