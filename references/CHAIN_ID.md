# rBitcoin Chain Identity

These values are locked by the immutable patch and must never change after genesis.

- Chain name: rBitcoin
- Ticker: rBTC
- Message start: 0x72 0x42 0x54 0x43
- Default P2P port: 19333
- Default RPC port: 19332
- Base58 prefixes
  - P2PKH: 60
  - P2SH: 85
  - WIF: 188
- Bech32 HRP: rbc
- Seeds: Contabo fleet bootstraps via vSeeds
  - 95.111.227.14
  - 95.111.229.108
  - 95.111.239.142
  - 161.97.83.147
  - 161.97.97.83
  - 161.97.114.192
  - 161.97.117.0
  - 194.163.144.177
  - 185.218.126.23
  - 185.239.209.227
  - vFixedSeeds remains cleared

## Consensus Baseline
- BIP34 activation height: 100000 (delayed to improve CPU miner compatibility)
- BIP65/BIP66/CSV/Segwit activation heights: 0 (active from genesis)
- powLimit: 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
- fPowAllowMinDifficultyBlocks: true

## Genesis
- Timestamp: rBitcoin genesis reset 2026-02-26; prior chain versions are invalid.
- Time: 1772127762
- Bits: 0x207fffff
- Nonce: 1
- Hash: 6a934d6728eda510ec92aef31275c40cc7c84f2a7518749c07c347adadad3e45
- Merkle root: 833fdbe289f2071f7abacb84b751b682a16850b6593a732579542b65923b69b2
- Coinbase pubkey: 04678afdb0fe5548271967f1a67130b7105cd6a828e03909a67962e0ea1f61deb649f6bc3f4cef38c4f35504e51ec112de5c384df7ba0b8d578a4c702b6bf11d5f
