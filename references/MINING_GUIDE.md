# Mining Guide (rBTC)

## Goal
Connect external miners to an rBitcoin node via RPC using `getblocktemplate`.

## 1) Start a seed node

```bash
./scripts/build_from_tag.sh v30.2
./scripts/run_node.sh --datadir ~/.rbitcoin --network main
```

## 2) Configure RPC (seed node)
Create `~/.rbitcoin/bitcoin.conf`:

```conf
server=1
rpcuser=rbtc
rpcpassword=change_me
rpcbind=0.0.0.0
rpcallowip=10.0.0.0/8
rpcport=19332
port=19333
listen=1
txindex=1
```

Restart the node after updating the config.

## 3) Point miners at the node
Example with `cpuminer` (if installed):

```bash
minerd -a sha256d -o http://<seed-ip>:19332 -u rbtc -p change_me
```

For ASICs or stratum-based miners, run a stratum proxy (e.g. ckpool or stratum-mining-proxy) that forwards to the node’s RPC.

## 4) Verify mining
On the seed node:

```bash
./build/bitcoin-cli -datadir ~/.rbitcoin getblockcount
```

## Notes
- Open TCP port `19333` for P2P and `19332` for RPC (firewall).
- For private testnets, restrict `rpcallowip` to your miner IP range.
