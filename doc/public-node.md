# Public rBTC Nodes

rBTC can run as a public Bitcoin-style node, but it should not reuse your existing Bitcoin Core mainnet paths.

## Ports

- P2P: `19333/TCP`
- RPC: `19332/TCP` and keep it bound to `127.0.0.1` unless you have a specific secured remote-RPC reason

## Fast path

From a verified repo checkout:

```bash
sudo ./scripts/public-apply.sh --address YOUR_RBTC_ADDRESS --enable-now
sudo ufw allow 19333/tcp
```

This installs:

- `bitcoind` and `bitcoin-cli` into `/usr/local/lib/rbtc/`
- `rbtc-cli`, `rbtc-bitcoind`, `rbtc-doctor`, `rbtc-public-apply`, and `rbtc-start-cpu-miner` into `/usr/local/bin/`
- config in `/etc/rbitcoin/bitcoin.conf`
- datadir in `/var/lib/rbitcoin`
- systemd units `rbtc-bitcoind.service` and `rbtc-cpuminer.service`
- pinned `cpuminer-opt` as the default SHA256d CPU miner

## Health checks

Run:

```bash
rbtc-doctor --conf /etc/rbitcoin/bitcoin.conf --datadir /var/lib/rbitcoin --json --strict --expect-public --expect-miner
```

Healthy public nodes should show:

- genesis hash `6a934d6728eda510ec92aef31275c40cc7c84f2a7518749c07c347adadad3e45`
- at least one peer connection
- `listen=1`
- at least one advertised local address once inbound routing is working
- a running `cpuminer-opt` process for `rbtc-cpuminer.service`

## Current public peers

- `95.111.227.14:19333`
- `95.111.239.142:19333`
- `161.97.114.192:19333`
- `161.97.117.0:19333`
- `194.163.144.177:19333`
- `185.218.126.23:19333`
- `185.239.209.227:19333`
