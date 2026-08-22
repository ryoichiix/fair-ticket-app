# FairTicket

**Anti-scalping event ticketing on Monad.** Every ticket enforces its own fairness — a per-wallet cap at the primary sale so bots can't bulk-buy, and a resale price cap enforced by the contract itself, not a platform's promise. Checking in at the gate requires sending a transaction from the ticket's actual owner wallet, so a forwarded screenshot is useless.

- **Live demo:** _add your hosted frontend URL here_
- **Contract address (Monad Testnet):** _add after deployment_
- **Explorer link (verified source):** _add after verification_

## Why this needs a blockchain, briefly

A normal ticketing app's rules are only as strong as the company's willingness to enforce them — and India's 2024-2025 concert scalping crisis (Coldplay, Diljit Dosanjh) included an Enforcement Directorate money-laundering probe into exactly that kind of platform-side failure. Here, the price cap is bytecode in a public contract, not a policy anyone — including us — could quietly bend.

## What's on-chain

| Function | What it does |
|---|---|
| `createEvent(...)` | Organizer sets face price, resale cap (basis points), supply, and per-wallet mint limit |
| `mint(eventId)` | Buy a ticket at face price — reverts past the per-wallet limit or sold-out supply |
| `listForResale(tokenId, price)` | List a ticket for resale — reverts if price exceeds the cap |
| `buyResale(tokenId)` | Buy a listed ticket — funds go straight to the seller, ticket transfers instantly |
| `checkIn(tokenId)` | Called by the ticket's owner wallet at the gate — marks it used, reverts on reuse |
| `resaleCap(tokenId)` | View the max legal resale price for a given ticket |

## Project structure

```
fair-ticket/
├── src/FairTicket.sol       # the contract
├── script/Deploy.s.sol      # deployment script (creates one demo event)
├── foundry.toml
├── remappings.txt
└── lib/                     # openzeppelin-contracts, forge-std
```

## Run it yourself

**Requirements:** [Foundry](https://book.getfoundry.sh/getting-started/installation) installed, a wallet with Monad testnet MON ([faucet](https://faucet.monad.xyz)).

```bash
git clone <this repo url>
cd fair-ticket

# install dependencies (already vendored in lib/, or re-fetch with:)
forge install OpenZeppelin/openzeppelin-contracts@v5.1.0 --no-commit
forge install foundry-rs/forge-std --no-commit

# build
forge build

# deploy to Monad testnet (creates one demo event automatically)
export PRIVATE_KEY=your_testnet_private_key
forge script script/Deploy.s.sol --rpc-url monad_testnet --broadcast

# verify the deployed contract's source on the explorer
forge verify-contract <deployed_address> src/FairTicket.sol:FairTicket \
  --chain 10143 \
  --verifier sourcify \
  --verifier-url https://sourcify-api-monad.blockvision.org
```

**Monad Testnet details:** Chain ID `10143` · RPC `https://testnet-rpc.monad.xyz` · Explorer `https://testnet.monadexplorer.com`

## Frontend

Built with Next.js + wagmi/viem. See `/frontend` for the web app that connects a wallet, mints, lists/buys resale, and checks in at the gate. `npm install && npm run dev` inside that folder.

## Team

Team Rockerz — Monad Blitz Hyderabad V3, August 22, 2026
