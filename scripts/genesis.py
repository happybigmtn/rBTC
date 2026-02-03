#!/usr/bin/env python3
import argparse
import hashlib
import struct
import time
import json

COIN = 100000000

def sha256d(b: bytes) -> bytes:
    return hashlib.sha256(hashlib.sha256(b).digest()).digest()

def ser_uint32(i):
    return struct.pack('<I', i)

def ser_int32(i):
    return struct.pack('<i', i)

def ser_uint64(i):
    return struct.pack('<Q', i)

def ser_varint(i):
    if i < 0xfd:
        return bytes([i])
    elif i <= 0xffff:
        return b'\xfd' + struct.pack('<H', i)
    elif i <= 0xffffffff:
        return b'\xfe' + struct.pack('<I', i)
    else:
        return b'\xff' + struct.pack('<Q', i)

def encode_script_num(n: int) -> bytes:
    if n == 0:
        return b''
    neg = n < 0
    abs_n = -n if neg else n
    result = bytearray()
    while abs_n:
        result.append(abs_n & 0xff)
        abs_n >>= 8
    # If highest bit set, add sign byte
    if result[-1] & 0x80:
        result.append(0x80 if neg else 0x00)
    elif neg:
        result[-1] |= 0x80
    return bytes(result)

def push_data(data: bytes) -> bytes:
    l = len(data)
    if l < 0x4c:
        return bytes([l]) + data
    elif l <= 0xff:
        return b'\x4c' + bytes([l]) + data
    elif l <= 0xffff:
        return b'\x4d' + struct.pack('<H', l) + data
    else:
        return b'\x4e' + struct.pack('<I', l) + data

def build_coinbase_script(psz: str, script_nbits: int) -> bytes:
    # CScript() << 486604799 << CScriptNum(4) << pszTimestamp
    script = b''
    script += push_data(encode_script_num(script_nbits))
    script += push_data(encode_script_num(4))
    script += push_data(psz.encode('utf-8'))
    return script

def build_coinbase_tx(psz: str, script_nbits: int, reward_sat: int, pubkey_hex: str) -> bytes:
    script_sig = build_coinbase_script(psz, script_nbits)
    tx = b''
    tx += ser_int32(1)  # version
    tx += ser_varint(1)  # vin count
    tx += b'\x00' * 32  # prevout hash
    tx += struct.pack('<I', 0xffffffff)  # prevout index
    tx += ser_varint(len(script_sig)) + script_sig
    tx += struct.pack('<I', 0xffffffff)  # sequence
    tx += ser_varint(1)  # vout count
    tx += ser_uint64(reward_sat)
    pubkey = bytes.fromhex(pubkey_hex)
    pubkey_script = push_data(pubkey) + b'\xac'  # OP_CHECKSIG
    tx += ser_varint(len(pubkey_script)) + pubkey_script
    tx += struct.pack('<I', 0)  # locktime
    return tx

def bits_to_target(bits: int) -> int:
    exponent = bits >> 24
    mantissa = bits & 0xffffff
    if exponent <= 3:
        target = mantissa >> (8 * (3 - exponent))
    else:
        target = mantissa << (8 * (exponent - 3))
    return target

def serialize_header(version, prev_hash, merkle_root, ntime, nbits, nonce):
    return (
        ser_int32(version) +
        prev_hash +
        merkle_root +
        ser_uint32(ntime) +
        ser_uint32(nbits) +
        ser_uint32(nonce)
    )

def mine_genesis(psz, ntime, nbits, version, reward, pubkey_script_hex, script_nbits=486604799, max_tries=20000000):
    tx = build_coinbase_tx(psz, script_nbits, reward, pubkey_script_hex)
    tx_hash = sha256d(tx)
    merkle_root = tx_hash

    target = bits_to_target(nbits)
    prev_hash = b'\x00' * 32

    nonce = 0
    while nonce < max_tries:
        header = serialize_header(version, prev_hash, merkle_root, ntime, nbits, nonce)
        h = sha256d(header)
        # Interpret hash as little-endian integer for comparison
        h_int = int.from_bytes(h, 'little')
        if h_int <= target:
            return nonce, h, merkle_root, tx_hash
        nonce += 1
    raise RuntimeError("Nonce not found in max_tries")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--timestamp', default='rBitcoin rebased from genesis')
    parser.add_argument('--time', type=int, default=int(time.time()))
    parser.add_argument('--bits', type=lambda x: int(x, 0), default=0x207fffff)
    parser.add_argument('--script-nbits', type=lambda x: int(x, 0), default=486604799)
    parser.add_argument('--version', type=int, default=1)
    parser.add_argument('--reward', type=float, default=50.0)
    parser.add_argument('--pubkey', default='04678afdb0fe5548271967f1a67130b7105cd6a828e03909a67962e0ea1f61deb649f6bc3f4cef38c4f35504e51ec112de5c384df7ba0b8d578a4c702b6bf11d5f')
    parser.add_argument('--max-tries', type=int, default=20000000)
    parser.add_argument('--json', action='store_true')
    args = parser.parse_args()

    reward_sat = int(args.reward * COIN)
    nonce, block_hash, merkle_root, tx_hash = mine_genesis(
        args.timestamp,
        args.time,
        args.bits,
        args.version,
        reward_sat,
        args.pubkey,
        script_nbits=args.script_nbits,
        max_tries=args.max_tries,
    )

    data = {
        "timestamp": args.timestamp,
        "time": args.time,
        "bits": hex(args.bits),
        "version": args.version,
        "reward": reward_sat,
        "nonce": nonce,
        "merkle_root": merkle_root[::-1].hex(),
        "hash": block_hash[::-1].hex(),
        "txid": tx_hash[::-1].hex(),
    }

    if args.json:
        print(json.dumps(data, indent=2))
    else:
        for k, v in data.items():
            print(f"{k}: {v}")

if __name__ == '__main__':
    main()
