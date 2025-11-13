# blaer-airtkn1-presale
AirTkn1 presale, vesting, and migration contracts for audit  
## Contracts

- `contracts/AirTkn1.sol`  
  Non-transferable presale receipt token. Capped at 8,000,000. Only presale contract can mint. Transfers disabled (only mint/burn) until explicitly enabled. Built on OpenZeppelin ERC20 v5 + Ownable.

- `contracts/AirTkn1Presale.sol`  
  USDC-based presale contract for Round 1. Handles price ($0.50), cap, timestamps and funds forwarding to treasury.

- `contracts/AirTknVesting.sol`  
  TGE vesting: 5% unlocked at TGE, 6-month cliff on the remaining 95%, then 15-month linear vesting.

- `contracts/AirTknMigration.sol`  
  After TGE, burns user `AirTkn1` and registers the corresponding $AirTkn allocation in the vesting contract.

- `contracts/AirTkn.sol`  
  Placeholder main $AirTkn token for now (minted to treasury). Final tokenomics/logic will live in the main repo.
  
## How to compile

```bash
npm install
npx hardhat compile
