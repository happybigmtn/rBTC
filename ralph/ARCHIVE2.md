# Implementation Plan Archive

## Review Signoff (2026-02-02) - SIGNED OFF

- [x] Binary memo encoding (70-80% size reduction) — Already implemented in social.rs

- [x] Batch message type (0x80) with MAX_BATCH_ACTIONS = 5 — `zebra-chain/src/transaction/memo/social.rs`

- [x] BatchMessage struct with encode/decode roundtrip

- [x] Required Tests: 14 tests covering batch parsing roundtrip, max actions, mixed types, nested prevention

- [x] Wallet batch queue RPC types — `zebra-rpc/src/methods/types/social.rs` BatchQueueRequest/Response
  - Note: `cargo test -p zebra-rpc batch_queue_` failed due to librocksdb-sys C++ build errors (missing `<cstdint>`).

- [x] Indexer batch parsing support — `zebra-rpc/src/indexer/batch.rs` with 16 tests

- [x] Channel open/close transaction types (0xC0, 0xC1, 0xC2) — `zebra-chain/src/transaction/memo/social.rs`

- [x] Channel RPC types and methods (5 methods) — `zebra-rpc/src/methods.rs`

- [x] Indexer channel parsing module — `zebra-rpc/src/indexer/channels.rs`

- [x] Dispute resolution mechanism (consensus-side feature) — ChannelDispute 0xC3, z_channel_dispute/z_dispute_status RPC

- [x] Required Tests: 45+ tests covering channel lifecycle, parsing, RPC types, dispute resolution

#### 6.1.3 Indexer Scaling

- [x] Miner price signaling in block nonces (PRICE_SIGNAL_MAGIC "BCPR", 8 bytes + 24 bytes PoW)

