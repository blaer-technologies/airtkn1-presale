AirTkn1 Presale – Smart Contract Audit Package

This repository contains the complete smart-contract package for the AirTkn1 Presale, part of the BLAER aviation ecosystem.
It includes the presale logic, token contract, vesting framework, and migration structure required for auditors to verify correctness, security, and upgradeability.

📌 Repository Structure
/contracts
│
├─ AirTkn.sol              # Base ERC20 token
├─ AirTkn1.sol             # Updated version (AirTkn1)
├─ AirTkn1Presale.sol      # Presale contract for AirTkn1
├─ AirTknMigration.sol     # Migration contract (v1 → v2)
└─ AirTknVesting.sol       # Vesting contract for team & investors

/frontend                  # Next.js + Tailwind CSS frontend application
/scripts                   # Hardhat scripts
/test                      # Hardhat test examples
hardhat.config.ts         # Hardhat compiler & network settings

📌 Auditor Notes

This package is structured for third-party security auditors and includes:

1. Token Implementation

Based on OpenZeppelin ERC20

Includes:

Transfer-enable switch (transfersEnabled)

Pausable-like behavior without Pausable inheritance

Ownership via Ownable

Internal _beforeTokenTransfer() override to enforce transfer gating

2. Presale Contract

Handles:

ETH → AirTkn1 purchase logic

Cap enforcement

Presale rate

Owner withdrawal of collected ETH

Purchase event logging

Prevents:

Over-allocation

Exceeding total presale supply

Reentrancy (via appropriate patterns)

3. Vesting Contract

Linear vesting for:

Team allocations

Investor allocations

Advisors or locked liquidity allocations

Features:

Cliff + duration

Revocable (configurable)

Claim function emits events

4. Migration Contract

Optional upgrade flow from older token version

Enforces:

Burn-and-mint or swap-and-disable patterns

Secured with:

Ownership restrictions

One-time migration toggles

🔐 Security Considerations

Auditors should verify:

Correct usage of Ownable and admin-only functions

_beforeTokenTransfer() gating logic

Overflow/underflow (solc 0.8.x has built-in checks)

Reentrancy risks in:

Purchase functions

Withdrawal functions

Accurate token accounting

Vesting math correctness

Migration one-way guarantees

No backdoor minting

Hardhat configuration matches compiler version 0.8.20

⚙️ Hardhat Project

This repository uses Hardhat for compilation and testing.

Compile
npx hardhat compile

Run tests
npx hardhat test

Deploy (example)
npx hardhat run scripts/send-op-tx.ts --network <network>

🎨 Frontend Application

This repository includes a Next.js frontend application with Tailwind CSS located in the `/frontend` directory.

Setup & Run Frontend
cd frontend
npm install
npm run dev

The frontend will be available at http://localhost:3000

Build for Production
cd frontend
npm run build
npm start

📄 Solidity Versions

All contracts are compiled with:

pragma solidity ^0.8.20;


(EVM target: Shanghai)

🧪 Testing Notes

You may include additional tests here:

Presale caps

Rate accuracy

Withdraw restrictions

Vesting cliffs

Early/late claim behavior

Transfer gating behavior

A few basic tests are included but auditors may expand coverage.

📬 Contact for Audit Coordination

For audit communication, please contact:

Jean Pierre Petit Guiot (Pierre Guiot)
Founder – Blaer Technologies
📧 pierre@blaer.io

🌐 https://blaer.io