# Agent Mining Quickstart

## Summary
Enable agents to mine a block with a single documented command on a dev chain.

## Acceptance Criteria
1. `scripts/mine_solo.sh` mines at least one block on a dev configuration.
2. Logs show the mined block height and the coinbase address used.
3. `skill/SKILL.md` includes a quickstart that completes in under 5 minutes on Linux.
4. Mining workflow does not require manual config spelunking.

## Out of Scope
- Production mining pool implementation.
