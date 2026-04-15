# 🏛️ AgentCourt

**Dispute Resolution Protocol for AI Agents on X Layer**

> *Built for Build X Hackathon 2026*

---

## The Problem

AI agents are moving trillions on-chain but have no way to resolve disputes when things go wrong. When an agent executes a bad trade or fails to deliver, there's no recourse.

[Bench](https://x.com/rajkaria_) proves agents got a fair price. But what happens **after** you discover bad execution? AgentCourt completes the loop.

---

## The Solution

AgentCourt is an on-chain arbitration protocol where:

- Anyone can **file a dispute** against an AI agent
- **Evidence** (like Bench certificates) is submitted on-chain
- A **2-of-3 arbitrator panel** votes on resolution
- **Automatic compensation** and reputation updates follow the ruling

---

## How It Works

```
[Claimant]
    │
    ▼
1. File Dispute ──── Pay 0.001 OKB fee, submit Bench cert hash
    │
    ▼
2. Submit Evidence ─ Attach proof (IPFS hashes, signed payloads)
    │
    ▼
3. Arbitration ───── 3 arbitrators vote (2/3 majority needed)
    │
    ▼
4. Resolution ─────── Winner compensated, reputations updated on-chain
```

| Step | Action | Who |
|------|--------|-----|
| **File** | Pay 0.001 OKB + submit `benchCertHash` | Claimant |
| **Evidence** | `submitEvidence(disputeId, bytes)` | Anyone |
| **Vote** | `voteOnDispute(disputeId, bool)` | Arbitrators only |
| **Resolve** | Auto-triggered on 2/3 consensus | ArbitratorPool → DisputeRegistry |

---

## Deployed Contracts (X Layer Testnet)

| Contract | Address |
|----------|---------|
| `AgentReputation` | `0xBcf4E24835fE496ba8426A84b22dd338E181BC33` |
| `DisputeRegistry` | `0x48f611D77d18ad446C65E174C3C9EED42BaF3c0A` |
| `ArbitratorPool` | `0xfcb1F7eb5e163464939969bf2fe5f82fC8ad03A2` |

---

## Smart Contracts

```
contracts/
├── AgentReputation.sol   — Tracks int256 reputation scores per address
├── DisputeRegistry.sol   — Core filing, evidence, and resolution logic
└── ArbitratorPool.sol    — 3-arbitrator voting with 2/3 consensus trigger
```

### Contract Interactions

```
DisputeRegistry ◄──── ArbitratorPool (calls resolveDispute on consensus)
      │
      └──────────────► AgentReputation (updates scores on resolution)
```

### Reputation Rules

| Outcome | Claimant | Respondent |
|---------|----------|------------|
| Claimant wins | +10 | -20 |
| Respondent wins | -5 | no change |

---

## Tech Stack

- **Solidity 0.8.20** — Smart contracts
- **Hardhat** — Development & deployment framework
- **X Layer** — OKX L2 (OKB native token)
- **Ethers.js** — Contract interaction

---

## Quick Start

```bash
# Install dependencies
npm install

# Compile contracts
npx hardhat compile

# Run tests
npx hardhat test

# Deploy to X Layer testnet
npx hardhat run scripts/deploy.js --network xlayer_testnet

# Deploy to X Layer mainnet
npx hardhat run scripts/deploy.js --network xlayer_mainnet
```

### Deployment Order

The `scripts/deploy.js` script handles all wiring automatically:

```
1. Deploy AgentReputation
2. Deploy DisputeRegistry(agentReputation)
3. Deploy ArbitratorPool(arb0, arb1, arb2, disputeRegistry)
4. agentReputation.setDisputeRegistry(disputeRegistry)
5. disputeRegistry.setArbitratorPool(arbitratorPool)
```

---

## Environment Setup

Create a `.env` file in the project root:

```env
PRIVATE_KEY=your_deployer_private_key
XLAYER_TESTNET_RPC=https://testrpc.xlayer.tech
XLAYER_MAINNET_RPC=https://rpc.xlayer.tech
```

---

## Future Roadmap

- **x402 integration** — Arbitrator payments via HTTP payment protocol
- **Bench protocol integration** — Automatic evidence import from Bench certificates
- **Decentralized arbitrator staking** — Stake OKB to join the arbitrator pool
- **Cross-chain dispute support** — Via OnchainOS for multi-chain agent activity
- **DAO governance** — Community-controlled arbitrator selection and fee parameters

---

## Built For

**Build X Hackathon on X Layer — April 2026**

---

*"Bench proves the crime. AgentCourt delivers justice."*
