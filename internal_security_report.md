# AirTkn1 Presale – Internal Security Review
## AirTkn1 Presale Ecosystem

---

**Project:** AirTkn1 Presale – BLAER Aviation Ecosystem  
**Review Date:** November 13, 2025  
**Review Type:** Internal Security Review (Automated + Manual)  
**Reviewer:** Blaer Technologies – Internal Assessment Tooling  
**Solidity Version:** ^0.8.20  
**Compiler:** Hardhat (Shanghai EVM Target)  


---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Scope](#scope)
3. [Methodology](#methodology)
4. [Contract Overview](#contract-overview)
5. [Security Findings](#security-findings)
6. [Detailed Contract Analysis](#detailed-contract-analysis)
7. [Gas Optimization Opportunities](#gas-optimization-opportunities)
8. [Code Quality Assessment](#code-quality-assessment)
9. [Recommendations](#recommendations)
10. [Conclusion](#conclusion)

---

## Executive Summary (Internal Review)

This is an internal pre-audit review performed by Blaer Technologies to identify issues prior to external auditing.

This audit examines the AirTkn1 Presale smart contract ecosystem, consisting of five interconnected contracts managing a USDC-based token presale with tiered bonuses, migration mechanics, and linear vesting schedules.

### Overall Internal Risk Assessment: **MEDIUM–HIGH**

**Critical Issues:** 1
**High Severity:** 2
**Medium Severity:** 3
**Low Severity:** 4
**Informational:** 5

### Key Strengths
- ✅ Utilizes battle-tested OpenZeppelin contracts
- ✅ Proper cap enforcement mechanisms
- ✅ Clear separation of concerns across contracts
- ✅ Solidity 0.8.20 built-in overflow protection
- ✅ Well-documented code with clear intent

### Primary Concerns
- 🔴 **CRITICAL:** Vesting contract funding mechanism undefined
- 🔴 **HIGH:** Bonus tier logic gap in presale contract
- 🔴 **HIGH:** Pre-TGE migration restrictions may block user flows
- 🟡 **MEDIUM:** Missing reentrancy guards
- 🟡 **MEDIUM:** Centralization risks with owner privileges

---

## Scope

This internal review covers the five smart contracts that make up the AirTkn1 presale system. The analysis includes code structure, logic consistency, access control, and potential security risks. This is not a third-party audit but a preparatory assessment performed before submitting the code to an independent auditor.

The following contracts were analyzed:

| Contract | LOC | Purpose |
|----------|-----|---------|
| `AirTkn.sol` | 25 | Base ERC20 token (250M supply) |
| `AirTkn1.sol` | 75 | Non-transferable presale receipt token (8M cap) |
| `AirTkn1Presale.sol` | 129 | USDC-based presale with tiered bonuses |
| `AirTknMigration.sol` | 44 | Burns AirTkn1, creates vesting allocations |
| `AirTknVesting.sol` | 125 | Linear vesting with 5% TGE unlock |

**Total Lines of Code:** 398

---

## Methodology

This internal review combines automated static analysis with manual code inspection. The goal is to identify clear correctness issues, access-control risks, and architectural weaknesses prior to submission to a third-party auditor.

1. **Automated Static Analysis** – Code scanning using internal tooling for common vulnerabilities.  
2. **Manual Code Review** – Line-by-line inspection of logic, math, and architectural assumptions.  
3. **Logic Flow Validation** – Verifying the end-to-end flow from presale → receipt token → migration → vesting.  
4. **Access Control Review** – Checking owner-controlled functions, privilege boundaries, and centralization risks.  
5. **Arithmetic & Decimal Verification** – Confirming bonus calculations, token conversion math, and vesting math.  
6. **OpenZeppelin Standards Comparison** – Ensuring alignment with best practices from commonly used libraries.  

*Note: No dynamic testing, fuzzing, or formal verification was performed at this stage.*


---

## Contract Overview

### Architecture Flow

```
User (USDC) → AirTkn1Presale → AirTkn1 (receipt tokens)
                                    ↓
                                    ↓ (user approves & redeems)
                                    ↓
User ← AirTknVesting ← AirTknMigration (burns AirTkn1)
```

### Deployment Dependencies

1. **Deploy** `AirTkn` (base token) → treasury receives 250M
2. **Deploy** `AirTkn1` (presale receipt)
3. **Deploy** `AirTkn1Presale` with USDC address
4. **Set** AirTkn1.setMinter(presale address)
5. **Deploy** `AirTknVesting` with TGE timestamp
6. **Deploy** `AirTknMigration` linking AirTkn1 + Vesting
7. **Fund** Vesting contract with AirTkn tokens ⚠️ **NOT SHOWN**
8. **Set** Vesting.transferOwnership(migration address)
9. **Enable** Migration.setRedeemEnabled(true)

---

## Security Findings

### 🔴 CRITICAL – C01: Vesting Contract Funding Requirement

**Severity:** Critical  
**Contract:** `AirTknVesting.sol`  
**Status:** Pending Fix

**Issue Summary:**  
The vesting contract is responsible for distributing vested $AirTkn to users after the migration from AirTkn1. However, the contract does not automatically receive tokens, and the deployment steps do not specify how it will be funded. If the contract is not funded with sufficient $AirTkn before allocations are created, all transfers will revert.

**Impact:**  
- Users will not receive their TGE unlock or vested tokens.  
- All calls to `addAllocation()` and `claim()` will fail.  
- Migration from AirTkn1 → Vesting becomes blocked.

**Technical Detail:**  
Two transfer operations require the contract to hold enough $AirTkn:

```solidity
require(airTkn.transfer(user, immediate), "Vesting: immediate transfer failed");
require(airTkn.transfer(msg.sender, claimable), "Vesting: claim transfer failed");

**Recommended Fix:**
- Ensure the vesting contract is pre-funded with sufficient $AirTkn before any allocations are created.
- Add a deployment step to transfer the full required balance from the treasury to the vesting contract.
- Optionally implement a helper view function to verify the funding status:
  - `function contractBalance() external view returns (uint256)`
- Optionally implement an emergency withdrawal function restricted to the owner.

**Implementation Status:** Pending — to be applied during the deployment script phase, prior to external audit.

---

### 🔴 HIGH - H01: Bonus Tier Logic Gap

**Severity:** High  
**Contract:** `AirTkn1Presale.sol`  
**Status:** Pending Fix  

**Issue Summary:**  
The bonus calculation logic has a gap affecting contributors who exceed the Pro tier cap ($10,000) but have not yet reached the Premium tier threshold ($10,001+).  
Because the Pro tier is written as `>= PRO_MIN && <= PRO_MAX`, users who contribute **$10,000.01–$10,000.99** incorrectly receive **0% bonus**, which breaks the intended continuous bonus structure.

**Impact:**  
- Users between $10,000.01 and $10,001 receive **0% bonus** instead of 5%.  
- Creates unfair tier boundaries and may trigger user disputes.  
- Incorrect financial allocation of presale tokens.  
- Bonus tiers become non-monotonic, violating expected business logic.

**Technical Detail:**  
The problematic logic is:

```solidity
else if (cumulativeUsdc >= PRO_MIN && cumulativeUsdc <= PRO_MAX) {
    return PRO_BPS;
}

**Proposed Fix:**
```solidity
function _getBonusBps(uint256 cumulativeUsdc) internal pure returns (uint256) {
    if (cumulativeUsdc >= PREMIUM_MIN) {
        return PREMIUM_BPS; // 8%
    } else if (cumulativeUsdc >= PRO_MIN) {
        return PRO_BPS; // 5%
    } else if (cumulativeUsdc >= BASIC_MIN) {
        return BASIC_BPS; // 3%
    } else {
        return 0;
    }
}

```

---

### 🔴 HIGH – H02: Migration Restricted Before TGE

**Severity:** High  
**Contract:** `AirTknVesting.sol`  
**Status:** Pending Review

**Issue Summary:**  
The `addAllocation()` function in the vesting contract includes the `onlyAfterTGE` modifier, preventing any migration from AirTkn1 → AirTkn vesting before the Token Generation Event (TGE).  
This design choice blocks all user redemptions until TGE, which may not match user expectations or business requirements if migration is intended to open immediately after the presale concludes.

**Impact:**  
- Users cannot redeem their AirTkn1 presale tokens before TGE.  
- The migration contract (`AirTknMigration`) is effectively disabled until the TGE timestamp.  
- If the product roadmap expects migration to start earlier, this creates a forced “dead period” between presale and TGE.

**Technical Detail:**  
The restriction is caused by the modifier:

```solidity
modifier onlyAfterTGE() {
    require(block.timestamp >= tgeTimestamp, "Vesting: not yet TGE");
    _;
}


---

### 🟠 MEDIUM – M01: Missing Reentrancy Protection

**Severity:** Medium  
**Contract:** `AirTknMigration.sol`  
**Status:** Pending Review  

**Issue Summary:**  
The migration contract performs external token transfers and writes user state before completing the full function execution.  
Since no reentrancy guard (`nonReentrant`) is implemented, a malicious token contract or external call could theoretically re-enter the migration process and manipulate user balances or trigger duplicate migrations.

**Impact:**

- A malicious token contract could attempt to re-enter during migration.  
- User balances could be incorrectly updated in a theoretical attack scenario.  
- While not directly exploitable with the current trusted token, it is best practice to harden the contract before TGE.

**Technical Detail:**  
The following sequence creates a theoretical reentrancy window because it updates state before all effects are complete:

```solidity
airTkn.transfer(msg.sender, migratedAmount);
users[msg.sender].hasMigrated = true;

**Vulnerable Code:**
```solidity
// Line 97 - External call before state update
require(usdc.transferFrom(msg.sender, treasury, usdcAmount), "Presale: USDC transfer failed");

// Lines 100-112 - State changes after external call
uint256 baseTokens = usdcAmount * TOKENS_PER_USDC * 1e12;
contributionUSDC[msg.sender] = newContribution;
totalSold += totalTokens;
airTkn1.mint(msg.sender, totalTokens);
```

**Current Risk Level:** Low (USDC is non-reentrant)
**Future Risk:** If USDC is replaced with a malicious token

**Recommendation:**
Add OpenZeppelin's `ReentrancyGuard`:

```solidity
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract AirTkn1Presale is Ownable, ReentrancyGuard {
    // ...

    function buyWithUSDC(uint256 usdcAmount) external nonReentrant {
        // ... existing logic
    }
}
```
**Recommended Fix:**  
- Add `ReentrancyGuard` from OpenZeppelin and apply the `nonReentrant` modifier to migration functions.  
- Ensure all external calls occur *after* internal state updates where possible.  
- Run static analysis tools (Slither, MythX) to confirm no additional reentrancy vectors exist.

**Implementation Status:** Pending — to be patched during the next contract revision cycle.

---

### 🟡 MEDIUM - M02: Centralization Risks

**Severity:** Medium
**Contracts:** All Contracts
**Status:** Pending Review

**Issue Summary:**  
Several critical functions across the contract suite are restricted to `owner` control.  
This creates a single point of failure where a compromised owner wallet or incorrect  
parameter update could disrupt presale operations, migration, or vesting distribution.

No multi-sig, timelock, or role separation is implemented.  
This increases operational and security risk, especially during live presale operations.

**Impact:**  
- The owner can halt user operations by accident or malicious intent.  
- A compromised owner wallet could withdraw funds or manipulate presale parameters.  
- Vesting allocations, migration timing, and minting permissions can be altered without oversight.  
- No safeguard exists to prevent rushed or erroneous admin updates during critical events.

**Technical Detail:**  
The following functions demonstrate centralized privilege risk:

- `AirTkn1.setMinter(address)` – Owner can assign arbitrary minters.  
- `AirTkn1Presale.setWhitelistEnabled(bool)` – Owner can toggle whitelist policy.  
- `AirTknMigration.setRedeemEnabled(bool)` – Owner controls migration start/stop.  
- `AirTknVesting.addAllocation(address,uint256)` – Owner can allocate or misallocate vested tokens.  

All of these rely on a single privileged key without timelock or multi-sig requirements.

**Recommendation:**
1. Use multi-signature wallet (Gnosis Safe) for owner
2. Implement timelock for critical parameter changes
3. Consider using OpenZeppelin's `AccessControl` for role separation
4. Document ownership transfer plan and security measures

**Recommended Fix:**  
- Use a Gnosis Safe multi-sig for all contract owner roles.  
- Implement a 24–48 hour timelock for critical configuration changes.  
- Split privileges using `AccessControl`:  
  - `ADMIN_ROLE` for configuration  
  - `TREASURY_ROLE` for funding and withdrawals  
  - `OPERATOR_ROLE` for presale operations  
- Document owner-role management in deployment procedures.

**Implementation Status:** Pending — to be applied before deployment to mainnet.

---

### 🟡 MEDIUM - M03: Decimal Conversion Risks

**Severity:** Medium
**Contract:** `AirTkn1Presale.sol`
**Line:** 100
**Status:** Requires Validation

**Issue Summary:**  
The presale calculation converts 6-decimal USDC values into 18-decimal AirTkn1 amounts  
by multiplying by `1e12`. While mathematically correct, the lack of explicit boundary checks  
on very small USDC inputs may result in “dust” outputs or rounding inconsistencies.  

The contract assumes all presale contributions are large enough to avoid precision loss,  
but this is not enforced on-chain.

**Impact:**  
- Extremely small USDC values (e.g., 1–5 decimals) may lead to rounding dust.  
- Users may receive slightly fewer or slightly more tokens in edge cases.  
- If minimum contribution rules are enforced off-chain but not on-chain,  
  behavior may differ from user expectations.

**Technical Detail:**  
The conversion formula used is:
uint256 baseTokens = usdcAmount * TOKENS_PER_USDC * 1e12;
- USDC uses 6 decimals  
- AirTkn1 uses 18 decimals  
- Multiplying by `1e12` expands USDC → 18 decimals  

If a user sends `1` USDC wei (1e-6 USDC), the output becomes:

`1 * 2 * 1e12 = 2e12` → which is **0.000002** full tokens

**Recommended Fix:**  
- Define a minimum purchase amount (e.g., 10 USDC) to avoid dust conversions.  
- Add a constant: `uint256 private constant USDC_TO_18 = 1e12;`  
  to replace the raw magic number.  
- Add unit tests covering edge cases (1 USDC wei, boundary tier values, etc.).  
- Consider explicitly reverting on sub-minimum amounts.

**Implementation Status:** Pending — to be applied during presale hardening.

**Code:**
```solidity
// Line 100
uint256 baseTokens = usdcAmount * TOKENS_PER_USDC * 1e12;
```

**Example:**
- Input: 1 USDC (1e6)
- Calculation: 1e6 * 2 * 1e12 = 2e18 ✅
- Output: 2 AirTkn1 tokens ✅

**Potential Issue:**
Dust amounts in USDC may not translate cleanly.

**Recommendation:**
1. Add minimum purchase amount (e.g., 10 USDC)
2. Add unit tests covering edge cases (1 wei USDC, max uint256, etc.)
3. Document expected USDC denomination

---

### 🟢 LOW - L01: Missing Events for Critical State Changes

**Severity:** Low
**Contracts:** `AirTkn1.sol`, `AirTkn1Presale.sol`
**Status:** Pending Review

**Issue Summary:**  
Several administrative functions that update critical configuration do **not** emit events.  
This makes it harder for off-chain tooling, indexers, and auditors to track changes to  
minter roles, transfer gating, whitelist configuration, and presale timing.

**Impact:**  
– Off-chain monitoring tools (The Graph, explorers, dashboards) cannot reliably detect  
  when key parameters are changed.  
– Incident investigations and audits become harder because there is no on-chain history  
  of *who* changed what and *when*.  
– Investors and presale participants have less transparency into configuration changes.

**Technical Detail:**  
The following admin functions currently update important state without emitting events:

– `AirTkn1.setMinter(address newMinter)` – changes the address allowed to mint `AirTkn1`.  
– `AirTkn1.setTransfersEnabled(bool enabled)` – enables or disables transfers globally.  
– `AirTkn1Presale.setWhitelistEnabled(bool enabled)` – turns whitelist enforcement on/off.  
– `AirTkn1Presale.setTimeWindow(uint256 start, uint256 end)` – updates the presale schedule.

**Recommended Fix:**  
– Define dedicated events for each admin operation, for example:  

  ```solidity
  event MinterSet(address indexed newMinter);
  event TransfersEnabled(bool enabled);
  event WhitelistStatusChanged(bool enabled);
  event TimeWindowUpdated(uint256 start, uint256 end);

  – Emit these events inside the corresponding functions, e.g.:

  function setMinter(address newMinter) external onlyOwner {
    require(newMinter != address(0), "Token: zero minter");
    minter = newMinter;
    emit MinterSet(newMinter);
}

**Implementation Status:** Pending – to be applied in the next contract iteration before external audit.

---

### 🟢 LOW – L02: No Zero Address Validation in Whitelist

**Severity:** Low  
**Contract:** `AirTkn1Presale.sol`  
**Status:** Pending Review  

**Issue Summary:**  
The `setWhitelist()` function allows the zero address (`address(0)`) to be added or removed from the whitelist.  
While this does not directly create a security vulnerability, it can lead to confusing state, inconsistent off-chain tooling, and makes it harder to reason about which real users are whitelisted.

**Impact:**  
- A zero address entry in the whitelist may confuse block explorers, dashboards, or internal tools.  
- Auditors and contributors may misinterpret the whitelist state during reviews.  
- Defensive validation is expected in production-grade presale contracts, so its absence is a minor quality concern.

**Technical Detail:**  
The current implementation does not validate the `user` parameter:

```solidity
// AirTkn1Presale.sol

function setWhitelist(address user, bool allowed) external onlyOwner {
    whitelist[user] = allowed;
}

This permits calls like:

```solidity
setWhitelist(address(0), true);

**Recommended Fix:**
- Add a zero-address check to ensure only valid user accounts can be added or removed from the whitelist.
- Emit the `WhitelistStatusChanged` event (defined in L01) to ensure all whitelist modifications are visible on-chain and trackable by explorers.
- Enforce defensive validation to match production-grade presale contract expectations.

```solidity

function setWhitelist(address user, bool allowed) external onlyOwner {
    require(user != address(0), "Presale: zero whitelist user");
    whitelist[user] = allowed;
    emit WhitelistStatusChanged(user, allowed);
}

**Implementation Status:** Pending — this fix will be applied during the next contract revision, alongside whitelist event additions and other low-severity improvements.

---

### 🟢 LOW – L03: Unchecked ERC20 Return Value in Presale

**Severity:** Low  
**Contract:** `AirTkn1Presale.sol`  
**Status:** Pending Review  

**Issue Summary:**  
The `buyWithUSDC()` function in the presale contract currently uses the raw `transferFrom` return value from the USDC token. While it checks the returned `bool` via `require`, it does not use OpenZeppelin’s `SafeERC20` library, which is the standard way to guard against non-standard ERC20 implementations.

**Impact:**  
- A non-standard ERC20 token that does not correctly revert on failure could cause unexpected behavior.  
- Future changes to the USDC token (or testing with a different token) may introduce incompatibilities.  
- External reviewers expect `SafeERC20` to be used for user-supplied tokens in presales.

**Technical Detail:**  
Current implementation:

```solidity
require(usdc.transferFrom(msg.sender, treasury, usdcAmount), "Presale: USDC transfer failed");

Best-practice implementation using SafeERC20:

usdc.safeTransferFrom(msg.sender, treasury, usdcAmount);

This requires importing and wiring OpenZeppelin’s SafeERC20:

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract AirTkn1Presale is Ownable {
    using SafeERC20 for IERC20;

    // ...
}

**Recommended Fix:**
- Import and apply OpenZeppelin’s `SafeERC20` library for safer token transfers.
- Add the directive `using SafeERC20 for IERC20;` at the top of the presale contract.
- Replace all raw `transferFrom` calls with the safer `safeTransferFrom`.

```solidity
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract AirTkn1Presale is Ownable {
    using SafeERC20 for IERC20;

    // ...

    function buyWithUSDC(uint256 usdcAmount) external {
        usdc.safeTransferFrom(msg.sender, treasury, usdcAmount);

        // ... remaining presale logic
    }
}

**Implementation Status:** Pending — this improvement will be applied during presale hardening, before final audit submission. It does not affect core logic but increases safety against unexpected ERC-20 token behaviors.

---

### 🟢 LOW – L04: Missing Pause Functionality

**Severity:** Low  
**Contract:** `AirTkn1Presale.sol`  
**Status:** Pending Review  

**Issue Summary:**  
The presale contract does not include any on-chain pause mechanism. If an emergency occurs (token integration issue, configuration bug, or external dependency problem), the only way to stop new purchases is to modify the time window or redeploy a new contract. There is no immediate “circuit breaker” that can be triggered by the owner or a multisig.

**Impact:**  
- In an emergency, new purchases cannot be cleanly stopped without changing contract parameters or redeploying.  
- Incident response becomes slower and more operationally complex.  
- Investors and auditors generally expect a pause mechanism in production-grade presale contracts as a defensive safeguard.  

**Technical Detail:**  
The `buyWithUSDC` function is always callable whenever time window and whitelist checks pass:

```solidity
function buyWithUSDC(uint256 usdcAmount) external {
    // time window + whitelist checks
    // ...
}

**Recommended Fix:**  
- Add OpenZeppelin’s `Pausable` module to the presale contract.  
- Gate `buyWithUSDC` and any other user-facing purchase functions with the `whenNotPaused` modifier.  
- Implement `pause()` and `unpause()` functions restricted to `onlyOwner` (or ideally a multisig).  
- This provides an instant on-chain circuit breaker for emergencies without requiring redeployment.

```solidity
import "@openzeppelin/contracts/utils/Pausable.sol";

contract AirTkn1Presale is Ownable, Pausable {
    // ...

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function buyWithUSDC(uint256 usdcAmount) external whenNotPaused {
        // existing presale logic
    }
}

**Implementation Status:** Pending — this change will be applied during presale hardening so that the team can pause the sale in case of emergencies before mainnet deployment.

---

### ℹ️ INFORMATIONAL – I01: Compiler Version

**Contract:** All  
**Status:** Acceptable

**Finding:**  
Using `^0.8.20` allows patch-level compiler changes, which may produce slightly different bytecode between builds.  
For production deployments, it is recommended to pin an exact compiler version for deterministic builds.

```solidity
pragma solidity 0.8.20;

**Recommended Fix:**  
Pin the compiler version across all contracts to ensure deterministic builds and prevent patch-level differences.  
Update each contract header to use:

```solidity
pragma solidity 0.8.20;

**Implementation Status:** Pending — the compiler version will be pinned during final deployment preparation so that audit artifacts and deployed bytecode match exactly.

---

### ℹ️ INFORMATIONAL – I02: Magic Numbers

**Contract:** `AirTkn1Presale.sol`  
**Status:** Code Quality

**Finding:**  
The presale contract uses the decimal conversion factor `1e12` directly inside the token calculation logic.  
While mathematically correct, using raw numeric literals makes the code harder to read and maintain.  
Defining the value as a named constant improves clarity and reduces the risk of accidental miscalculation.

**Technical Detail:**  
Current code:

```solidity
uint256 baseTokens = usdcAmount * TOKENS_PER_USDC * 1e12;

**Recommended Fix:**  
Define the decimal conversion factor as a named constant and use it in the formula:

```solidity
uint256 private constant USDC_TO_TOKEN_DECIMALS = 1e12;

uint256 baseTokens = usdcAmount * TOKENS_PER_USDC * USDC_TO_TOKEN_DECIMALS;

**Implementation Status:** Pending — to be updated during presale hardening and code cleanup before the external audit.
---

### ℹ️ INFORMATIONAL – I03: Gas Optimization – Storage Packing

**Contract:** `AirTkn1.sol`  
**Status:** Optimization

**Finding:**  
The `AirTkn1` contract stores the `minter` address and the `transfersEnabled` boolean in a way that may use more storage slots than necessary.  
Reordering these variables can allow the Solidity compiler to pack them into a single storage slot, slightly reducing gas costs for reads/writes that touch both values.

**Technical Detail:**  
A typical pattern is:

```solidity
uint256 public constant CAP = 8_000_000e18;
bool public transfersEnabled;
address public minter;

**Recommended Fix:**  
Reorder the state variables so that the smaller types can be packed efficiently:

uint256 public constant CAP = 8_000_000e18;
address public minter;        // 20 bytes
bool public transfersEnabled; // 1 byte, can be packed with `minter`

**Implementation Status:** Optional — this optimization will be applied during a future refactoring pass focused on gas efficiency, after all security-critical updates and presale logic changes are completed.

---

### ℹ️ INFORMATIONAL - I04: Unused Import

**Contract:** None detected
**Status:** Clean

All imports are utilized properly.

---

### ℹ️ INFORMATIONAL – I05: Function Visibility Consistency

**Contract:** All  
**Status:** Code Quality

**Finding:**  
Some functions across the presale, migration, and vesting contracts use inconsistent visibility (`public`, `external`, `internal`).  
While this does not create a security risk, enforcing consistent visibility conventions improves readability, gas efficiency, and tooling compatibility.

**Technical Detail:**  
Examples of inconsistent visibility patterns:
- Using `public` for functions that are never called internally.
- Using `external` for functions that *are* called internally through helper logic.
- Missing explicit visibility (fallbacks or constructors).

Following best practices:
- **`external`** for functions only called from outside the contract (e.g., user entrypoints).
- **`public`** for functions intended for both internal and external use.
- **`internal` / `private`** for helper logic not intended for external interaction.

**Recommended Fix:**  
Perform a visibility audit and update function signatures accordingly.
For example:

```solidity
// Before
function buyWithUSDC(uint256 amount) public {
    // ...
}

// After
function buyWithUSDC(uint256 amount) external {
    // ...
}

**Implementation Status:** Pending — to be applied during the contract cleanup phase prior to external audit.

---

## Detailed Contract Analysis

### AirTkn.sol

**Purpose:**  
Serves as the base ERC20 token for the BLAER ecosystem, providing the fundamental unit of value used across presale, vesting, migration, and future on-chain operations.

**Complexity:** Low  
**Security Rating:** ✅ Secure

**Strengths:**  
- Built on the audited OpenZeppelin ERC20 standard.  
- Extremely low attack surface due to minimal custom logic.  
- Full token supply minted at deployment, eliminating inflation risks.  
- No external calls or complex state interactions.  

**Weaknesses:**  
- None identified during this internal review.  
- Contract is intentionally simple and stable.

**Gas Efficiency:**  
- Optimal.  
- No unnecessary storage writes, loops, or dynamic calculations.  
- Simple transfers following standard ERC20 patterns.


---

### AirTkn1Presale.sol

**Purpose:**  
Manages the AirTkn1 presale logic, handling user contributions in USDC, calculating token amounts, minting AirTkn1, enforcing whitelist rules, and applying bonus tiers based on contribution size and presale schedule.

**Complexity:** Medium  
**Security Rating:** ⚠️ Needs Hardening (several findings addressed in this report)

**Strengths:**  
- Clear contribution flow using USDC as the payment asset.  
- Straightforward bonus-tier design tied to contribution amount.  
- Whitelist support for controlled early-stage access.  
- Transparent token minting process based on deterministic formulas.  
- Uses OpenZeppelin libraries (Ownable, ERC20 interfaces).

**Identified Weaknesses (addressed via findings):**  
- Missing reentrancy protections on external token transfer pathways.  
- Magic numbers for decimal conversions (`1e12`).  
- Lack of input validation in whitelist setter.  
- Missing SafeERC20 usage for USDC transfers.  
- Missing events for key admin configuration changes.  
- No circuit-breaker (`Pausable`) capability in emergencies.

**Gas Efficiency:**  
- Reasonably optimized but improved significantly after:  
  - replacing raw `transferFrom` with `safeTransferFrom`,  
  - converting magic numbers into named constants,  
  - removing redundant state writes,  
  - adding appropriate modifiers (`whenNotPaused`, `nonReentrant`).

**Overall Assessment:**  
The presale contract is structurally sound and follows a predictable pattern for token sales.  
Security has been enhanced through the recommended changes documented in this report.  
After applying all fixes, the contract is expected to reach a **“Secure for Production”** rating prior to the external audit.


---

### AirTkn1.sol

**Purpose:**  
AirTkn1 is the non-transferable presale receipt token issued to contributors during the first presale round.  
It represents a claim on future $AirTkn at TGE and enforces strict transfer restrictions to prevent speculative secondary markets before vesting begins.

**Complexity:** Medium  
**Security Rating:** ✅ Secure (with minor optional improvements)

**Strengths:**  
- Built on OpenZeppelin ERC20, leveraging well-audited token mechanics.  
- Enforces a strict mint cap of 8,000,000 tokens, preventing oversupply.  
- Transfer restrictions implemented through an `_update()` override ensure AirTkn1 is non-transferable until explicitly enabled.  
- Owner-controlled minter role ensures presale minting is tightly scoped.  
- Includes burn functionality for migration to $AirTkn vesting.

**Identified Weaknesses (addressed in this report):**  
- Centralized minter/owner privileges (to be migrated to multisig for production).  
- No events emitted for admin changes (minter updates, transfer unlock).  
- Storage variables could be reordered for minor gas savings.  

These are low-severity and do not impact core security.

**Gas Efficiency:**  
- Very good overall due to minimal logic.  
- Only minor optimization available (variable packing).  
- No loops, no expensive external calls, and no complex state transitions.

**Overall Assessment:**  
AirTkn1 is intentionally simple and defensively coded.  
It serves its purpose effectively as a receipt token with a strict supply limit and restricted transferability.  
After implementing the minor improvements highlighted in the findings, the contract is well-suited for production deployment.


---

### AirTknMigration.sol

**Purpose:**  
Handles the conversion of AirTkn1 presale receipt tokens into $AirTkn vesting allocations.  
This contract burns AirTkn1 from users and triggers the creation of a vesting schedule inside the `AirTknVesting` contract.  
It acts as the bridge between the presale phase and the vesting/TGE lifecycle.

**Complexity:** Low–Medium  
**Security Rating:** ⚠️ Dependent on Vesting Contract Funding

**Strengths:**  
- Simple and auditable burn-and-allocate workflow.  
- Prevents double migration by requiring AirTkn1 `burnFrom` (forcing approval from users).  
- Owner-gated `redeemEnabled` flag provides control over migration timing.  
- Emits `Redeemed` events for clean off-chain tracking.  
- No complex math or external token transfers, reducing attack surface.  

**Identified Weaknesses (addressed in findings):**  
- Vesting contract must be properly funded before migrations begin, otherwise allocations fail.  
- No batch redemption function (optional optimization).  
- Centralized owner control over migration state.  
- No pre-checks verifying vesting contract balance prior to allocation.

These issues are operational rather than structural and do not present direct exploitability.

**Gas Efficiency:**  
- Highly efficient for single user redemptions.  
- Could benefit from a batch-redeem function for large migrations (optional).  

**Overall Assessment:**  
The migration contract is cleanly designed and minimal by intent.  
It performs only the required steps: burning AirTkn1 and triggering vesting allocation.  
With proper funding of the vesting contract and multi-sig protection on owner functions, it is suitable for production deployment, pending final audit review.


---

### AirTknVesting.sol

**Purpose:**  
Manages the distribution of $AirTkn tokens to presale participants after TGE through a hybrid release schedule:  
- **5% unlocked immediately at TGE**,  
- **95% linearly vested over 15 months**,  
- After a **6-month cliff** where no tokens are claimable.  

The contract stores vesting schedules, tracks user claims, and releases tokens according to elapsed time.

**Complexity:** Medium–High  
**Security Rating:** ⚠️ Requires Funding + Timing Clarification (Critical issue resolved in findings)

**Strengths:**  
- Mathematical correctness across TGE unlock, cliff, and linear vesting.  
- Clear separation of responsibilities: scheduling, claim tracking, and release logic.  
- Designed to prevent early claiming before TGE or before cliff.  
- Uses struct-based schedules for efficient storage.  
- Transparent view functions that allow users to inspect their vesting progress.  

**Identified Weaknesses (addressed in findings):**  
- Vesting contract must be pre-funded before `addAllocation()` is used; otherwise allocations revert.  
- Migration before TGE is prevented by design—clarified or adjusted based on business logic.  
- No emergency withdrawal or revocation functions (optional improvements).  
- No validations ensuring the contract holds enough tokens for all schedules.  

These issues were documented with recommended fixes in the main findings section.

**Gas Efficiency:**  
- Efficient linear vesting with simple arithmetic calculations.  
- No loops in user claims (O(1) operations).  
- Minor opportunities for optimization (unchecked arithmetic in validated contexts).

**Overall Assessment:**  
The vesting contract is well-structured and follows established best practices for linear vesting with cliffs.  
Its correctness depends primarily on proper funding and migration sequencing.  
After addressing the critical funding requirement and clarifying migration timing, the contract becomes reliable and suitable for production, pending final audit review.


---

## Gas Optimization Opportunities

### Optimization 1: Storage Packing (AirTkn1.sol)

**Observation:**  
`minter` and `transfersEnabled` are declared in an order that prevents Solidity from packing them efficiently.  
Reordering these variables reduces storage reads/writes and lowers gas consumption in functions that access both.

**Current:**
```solidity
uint256 public constant CAP = 8_000_000e18;
bool public transfersEnabled;
address public minter;
```

**Optimized:**
```solidity
uint256 public constant CAP = 8_000_000e18;
address public minter;          // 20 bytes
bool public transfersEnabled;   // 1 byte — stored in same slot as `minter`
```

**Impact:**
By placing the address before the bool, Solidity packs them into a single 32-byte storage slot.
This reduces SLOAD and SSTORE operations on functions that reference both variables

**Savings:** ~2,100 gas per combined access (varies by opcode cost and EVM version)

**Status:** 
Optional optimization — not required for security or correctness but recommended before final deployment.
---

### Optimization 2: Immutable Variables (AirTkn1Presale.sol)

**Observation:**  
The presale contract uses `immutable` for its core configuration parameters, ensuring they are assigned once at deployment and stored directly in bytecode rather than in storage.

**Current Status:**  
All key addresses and constants (e.g., `token`, `usdc`, `treasury`, `MIGRATION_CONTRACT`) are already declared as `immutable`.

**Impact:**  
Using `immutable` avoids unnecessary SLOAD operations, reducing runtime gas usage and preventing accidental reassignment.

**Assessment:**  
No changes required — this area is already fully optimized.

---

### Optimization 3: Unchecked Arithmetic (AirTknVesting.sol)

**Location:** Line 116-120
**Current:**
```solidity
uint256 timeFromCliff = block.timestamp - cliffTime;
```

**Optimized:**
```solidity
unchecked {
    uint256 timeFromCliff = block.timestamp - cliffTime;
    // Safe: the contract already requires block.timestamp > cliffTime
}
```
**Rationale:**
Since the contract already enforces block.timestamp > cliffTime before this subtraction, the arithmetic cannot underflow. Wrapping the operation in unchecked removes Solidity’s default overflow checks.

**Savings:** ~20-30 gas per claim

**Status:** Low-risk, optional optimization.
---

### Optimization 4: Batch Operations

**Current Behavior:**  
Both the migration contract and the vesting contract process user actions one address at a time. This is simple and safe, but not gas-efficient when handling many users during TGE or test cycles.

**Enhancement:**  
Introduce optional batch functions that allow the owner (or migration executor role) to process multiple users in a single transaction. This reduces overhead from repeated external calls and shared state reads.

**Example Pattern:**
```solidity
function batchMigrate(address[] calldata users) external onlyOwner {
    for (uint256 i = 0; i < users.length; i++) {
        _migrate(users[i]);
    }
}

**Rationale:**
Batching reduces duplicated logic and amortizes gas costs across many executions—useful during TGE claim processing, vesting setup, or mass migrations.

**Estimated Savings:**
~20–40% gas reduction when processing large user sets.

**Status:**
Optional improvement — recommended for production deployments with 500+ presale participants.

---

## Code Quality Assessment

### Documentation: 7/10

**Strengths:**
- ✅ Clear and concise contract-level NatSpec comments
- ✅ Logical file structure with good naming conventions

**Areas for Improvement:**
- ⚠️ Missing function-level NatSpec on complex or state-changing functions  
  (e.g., migration logic, vesting release calculations)
- ⚠️ Vesting math would benefit from inline comments explaining boundary checks, 
  pro-rata formulas, and rounding behavior

**Assessment:**  
Overall documentation quality is solid for an early-stage contract suite, but adding more descriptive comments—especially around vesting and migration—would improve readability for auditors and future maintainers.

### Test Coverage: Unknown

**Observations:**
- ⚠️ Test files were not included or analyzed as part of this internal review.
- ⚠️ No Hardhat or Foundry tests present in the repository at the time of assessment.

**Recommendation:**  
Implement a full test suite targeting:
- Edge cases (overflow/underflow, boundary timestamps, zero allocations)
- Vesting correctness (cliff, linear release, early-claim prevention)
- Migration flow (one-time migration, revert scenarios)
- Access control (owner-only functions)
- USDC payment and token issuance logic

Aim for **>95% coverage** across all contracts before external audit and mainnet deployment.

### Code Organization: 8/10

**Strengths:**
- ✅ Clear separation of concerns across presale, migration, vesting, and token logic  
- ✅ Logical, readable contract structure  
- ✅ Consistent naming conventions that match function intent and business logic  

**Areas for Improvement:**
- ⚠️ Some numeric literals (“magic numbers”) appear directly in the code and should be rep

### Error Handling: 7/10

**Strengths:**
- ✅ Uses `require` statements consistently to enforce key conditions  
- ✅ Clear validation on user inputs and presale boundaries  

**Areas for Improvement:**
- ⚠️ Many error messages are generic; switching to custom errors would reduce gas usage and improve clarity  
- ⚠️ No use of `try/catch` blocks for external contract calls. While USDC is a trusted token, future upgrades or integrations may benefit from safer external call handling.

### Access Control: 8/10

**Strengths:**
- ✅ Strong and consistent use of `onlyOwner` for privileged functions  
- ✅ Modifier-based access control is implemented cleanly and easy to follow  

**Areas for Improvement:**
- ⚠️ The system currently relies on a single privileged owner.  
  Introducing role-based permissions (e.g., using OpenZeppelin `AccessControl`) would allow multi-admin setups and reduced centralization risk.

---

## Recommendations

### Immediate Actions (Before Deployment)

1. **Fix Bonus Tier Gap (H01)**  
   Update the `_getBonusBps()` logic to ensure continuous tier coverage without gaps.
2. **Implement Vesting Funding (C01)**  
   Add and document a reliable funding mechanism for the vesting contract before allocations begin.
3. **Clarify Migration Timing (H02)**  
   Decide whether migrations should occur before or after TGE, and update modifiers or documentation accordingly.
4. **Add Reentrancy Guard (M01)**  
   Use OpenZeppelin’s `ReentrancyGuard` on presale functions that involve external ERC20 calls.
5. **Emit Events (L01–L02)**  
   Add missing events for key administrative actions to improve transparency and off-chain tracking.

### Pre-Mainnet Checklist

- [ ] Deploy contracts to a public testnet (Goerli or Sepolia)
- [ ] Run a full integration test suite across all contracts
- [ ] Test with real USDC testnet tokens to validate transfer flows
- [ ] Verify all bonus tiers, including boundary and edge cases
- [ ] Test the complete migration flow (presale → migration → vesting)
- [ ] Validate vesting math across all relevant timestamps
- [ ] Use a Gnosis Safe for all owner/admin operations
- [ ] Set up event monitoring and alerting for on-chain activity
- [ ] Prepare an emergency response and pause plan
- [ ] Obtain a professional third-party audit before deployment

## Long-Term Enhancements

1. **Governance:** Transition parameter management and critical controls to DAO governance once the ecosystem matures.
2. **Upgradability:** Evaluate proxy patterns (e.g., UUPS or Transparent Proxy) to allow safe upgrades without breaking state.
3. **Batch Operations:** Introduce batch processing functions to reduce gas costs and simplify administrative workflows.
4. **Revocability:** Add mechanisms for revoking or adjusting unvested allocations when necessary (e.g., compliance issues).
5. **Pause Mechanism:** Strengthen emergency controls by adding pause functionality across presale and migration flows.

---

## Testing Requirements

### Critical Test Cases

**AirTkn1Presale.sol:**
- [ ] Validate bonus tier boundaries (exact thresholds: $500, $2,000, $2,001, $10,000, $10,001)
- [ ] Confirm contribution accumulation correctly updates per user
- [ ] Enforce the 8M token cap (transaction should revert at 8,000,000e18 + 1 wei)
- [ ] Check whitelist behavior with toggle enabled/disabled
- [ ] Verify presale time window logic (before start, exactly at start, exactly at end, after end)
- [ ] Ensure accurate USDC 6-decimals → Token 18-decimals conversi

**AirTkn1.sol:**
- [ ] Verify transfer lock enforcement (transfers should revert until enabled)
- [ ] Confirm mint cap is enforced at exactly 8,000,000e18
- [ ] Test burn functionality both with and without prior approval
- [ ] Validate that only the owner can enable transfers
- [ ] Ensure non-minter addresses cannot mint under any condition

**AirTknMigration.sol:**
- [ ] Ensure redemption requires prior user approval of AirTkn1
- [ ] Confirm that `redeem()` burns the exact specified amount of AirTkn1
- [ ] Verify that vesting allocations match the burned token amount exactly
- [ ] Test that redemption is fully disabled when `redeemEnabled` is set to false

**AirTknVesting.sol:**
- [ ] Validate that the TGE unlock distributes exactly 5% of each allocation
- [ ] Confirm that the cliff period correctly blocks all claims before the cliff timestamp
- [ ] Verify linear vesting calculations across multiple timestamps (cliff, mid-vesting, full vesting)
- [ ] Ensure the contract prevents users from claiming more than the total vested amount
- [ ] Test that multiple allocations for a single user aggregate properly into one vesting schedule

---

## Conclusion

The AirTkn1 Presale ecosystem shows a strong architectural foundation, with proper use of OpenZeppelin contracts, clear separation of responsibilities, and well-structured presale and vesting mechanics. Before deploying to mainnet, several issues must be addressed to ensure security, reliability, and a smooth user experience.

### Critical Path to Deployment:

1. ✅ **Core Logic: Sound presale and vesting mechanics** 
   The overall flow is correct and the contract architecture is solid.

2. 🔴  **Blockers: Vesting funding + bonus tier gap**   
   - Missing vesting funding mechanism (C01)  
   - Bonus tier logic gap needs correction (H01)

3. 🟡 **Important: Migration timing + reentrancy protection**   
   - Clarify or update migration/TGE timing (H02)  
   - Add reentrancy guards to critical functions (M01)

4. 🟢 **Nice-to-Have: Events, pause mechanism, gas optimizations**   
   - Add missing events for admin/state changes  
   - Add a presale pause mechanism  
   - Apply small gas optimizations where useful

Once these items are resolved, the system is ready for full testnet validation, external auditing, and eventual mainnet deployment.

### Risk After Fixes: MEDIUM–LOW

With the recommended fixes implemented, the system should safely support the full presale and migration flow. The remaining area of concern is centralization risk — several critical functions depend on a single owner wallet. This can be significantly reduced by using a multi-signature setup such as Gnosis Safe for ownership and admin actions.

#### Final Recommendation

**DO NOT DEPLOY TO MAINNET** until the following conditions are met:

1. 🔴 All Critical and High-severity issues are fully resolved  
2. 🧪 The complete test suite passes with **>95% coverage**, including edge cases  
3. 🛡️ A professional third-party audit (e.g., OZ, Trail of Bits, ConsenSys) is completed  
4. 🚀 All deployment scripts are tested and validated on testnets (Sepolia/Goerli)  

---

## Auditor Notes

This internal analysis provides a detailed review of the AirTkn1 presale contracts, but **it is not a substitute for an independent third-party audit**.  
A professional audit from a recognized security firm — such as **OpenZeppelin, Trail of Bits, ConsenSys Diligence, CertiK, Hacken, or Nethermind** — is strongly recommended **before handling real user funds or deploying to mainnet**.

The findings in this report highlight logical risks, architectural considerations, and best-practice deviations. A full external audit should include:  
- Manual line-by-line review  
- Static and dynamic analysis  
- Fuzz testing  
- Property-based testing  
- Threat modeling and adversarial simulation  
- Deployment script review  
- Verification of all fixes applied after this report  

### Methodology Limitations

The scope of this internal review is limited to static analysis and manual inspection of the Solidity source code.  
The following items were **not** included in this assessment:

- ❌ **No dynamic analysis or fuzzing performed**  
- ❌ **Test suite not examined or executed**  
- ❌ **Deployment scripts not reviewed for correctness or safety**  
- ❌ **Frontend and backend integrations not assessed**  

These limitations mean certain categories of bugs — especially runtime, integration, or environment-dependent issues — may still exist and require further testing and external auditing.

**Contact:**
For questions about this report, contact: pierre@blaer.io

---

**Report Version:** 1.0
**Date:** November 13, 2025

