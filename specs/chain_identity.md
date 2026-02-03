# Chain Identity (rBTC)

## Summary
Define a rebased chain identity that starts from a new genesis block with r-prefixed naming.

## Acceptance Criteria
1. Chain name, ticker, HRP, network magic, and default ports are declared in `references/CHAIN_ID.md`.
2. Genesis block parameters are defined and embedded in the patch.
3. Seeds strategy is documented with either a fixed list or signed rotation.
4. Address prefixes are updated for the rBTC chain.

## Open Decisions
- Final chain name and ticker string variants.
- Ports and magic values.
- Seed strategy and key custody if signed.
