# Chain Identity (rBTC)

## Status
Locked for rBitcoin v0 (genesis values computed when patch is generated).

## Naming
- Chain name: rBitcoin
- Ticker: rBTC
- Human-readable prefix (bech32): rbc

## Network Magic + Ports
- Message start (magic): 0x72 0x42 0x54 0x43  # ASCII "rBTC"
- Default P2P port: 19333
- Default RPC port: 19332

## Address Prefixes (Base58)
- P2PKH prefix: 60 (0x3c)
- P2SH prefix: 85 (0x55)
- WIF prefix: 188 (0xbc)

## Seeds
- Strategy: fixed list (start empty), add via config or DNS later
- Seed list: (none)

## Genesis
- Timestamp message: "rBitcoin rebased from genesis"
- Timestamp (unix): TBD (set by genesis generator)
- Nonce: TBD (set by genesis generator)
- Difficulty bits: TBD (set by genesis generator)
- Merkle root: TBD (set by genesis generator)
- Hash: TBD (set by genesis generator)

## Notes
- Only chain-identity constants are allowed to change via the immutable patch.
- All fields above are finalized for v0; genesis computed values are derived from the timestamp message and target bits.
