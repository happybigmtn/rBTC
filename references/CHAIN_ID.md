# Chain Identity (rBTC)

## Status
Locked for rBitcoin v0 (genesis values computed).

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
- Timestamp (unix): 1770140165
- Nonce: 0
- Difficulty bits: 0x207fffff
- Merkle root: b3830cd05f183ef0835f65a5490b93600612377d85178a8a9593d18cd910d59c
- Hash: 292cb2dd254cdcee717850a1f57a8150088baf1466129d3d9ea107bbf851110e

## Files
- `references/GENESIS.json`

## Notes
- Only chain-identity constants are allowed to change via the immutable patch.
