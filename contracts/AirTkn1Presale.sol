// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./AirTkn1.sol";

/**
 * @title AirTkn1Presale
 * @dev Handles Discount Round 1 presale logic:
 *      - Accepts USDC (6 decimals).
 *      - Price: $0.50 per token → 2 AirTkn1 per 1 USDC.
 *      - Applies tiered bonus based on cumulative contribution.
 *      - Enforces 8,000,000 token cap across base + bonus.
 */
contract AirTkn1Presale is Ownable {
    AirTkn1 public immutable airTkn1;
    IERC20 public immutable usdc;
    address public immutable treasury;

    // 1 USDC (1e6) → 2 AirTkn1 (2e18)
    // tokenAmount = usdcAmount * 2 * 1e12
    uint256 public constant TOKENS_PER_USDC = 2;
    uint256 public constant CAP = 8_000_000e18;

    uint256 public totalSold;
    uint256 public start;
    uint256 public end;

    // Tier boundaries in USDC (6 decimals)
    uint256 public constant BASIC_MIN   = 500e6;
    uint256 public constant BASIC_MAX   = 2_000e6;
    uint256 public constant PRO_MIN     = 2_001e6;
    uint256 public constant PRO_MAX     = 10_000e6;
    uint256 public constant PREMIUM_MIN = 10_001e6;

    // bonuses in basis points (1% = 100 bps)
    uint256 public constant BASIC_BPS   = 300;  // +3%
    uint256 public constant PRO_BPS     = 500;  // +5%
    uint256 public constant PREMIUM_BPS = 800;  // +8%

    mapping(address => uint256) public contributionUSDC;
    mapping(address => bool) public whitelist;
    bool public whitelistEnabled = true;

    event TokensPurchased(
        address indexed buyer,
        uint256 usdcSpent,
        uint256 baseTokens,
        uint256 bonusTokens,
        uint256 totalTokens
    );

    constructor(
        address _airTkn1,
        address _usdc,
        address _treasury,
        uint256 _start,
        uint256 _end
    ) Ownable(msg.sender){
        require(_airTkn1 != address(0), "Presale: AirTkn1 zero address");
        require(_usdc != address(0), "Presale: USDC zero address");
        require(_treasury != address(0), "Presale: treasury zero address");

        airTkn1 = AirTkn1(_airTkn1);
        usdc = IERC20(_usdc);
        treasury = _treasury;
        start = _start;
        end = _end;
    }

    // --- Admin ---

    function setWhitelist(address user, bool allowed) external onlyOwner {
        whitelist[user] = allowed;
    }

    function setWhitelistEnabled(bool enabled) external onlyOwner {
        whitelistEnabled = enabled;
    }

    function setTimeWindow(uint256 _start, uint256 _end) external onlyOwner {
        start = _start;
        end = _end;
    }

    // --- Core buy function ---

    function buyWithUSDC(uint256 usdcAmount) external {
        require(block.timestamp >= start && block.timestamp <= end, "Presale: not active");
        if (whitelistEnabled) {
            require(whitelist[msg.sender], "Presale: not whitelisted");
        }
        require(usdcAmount > 0, "Presale: zero amount");

        // Pull USDC to treasury
        require(usdc.transferFrom(msg.sender, treasury, usdcAmount), "Presale: USDC transfer failed");

        // Base tokens: 6d → 18d
        uint256 baseTokens = usdcAmount * TOKENS_PER_USDC * 1e12;

        uint256 newContribution = contributionUSDC[msg.sender] + usdcAmount;
        contributionUSDC[msg.sender] = newContribution;

        uint256 bonusBps = _getBonusBps(newContribution);
        uint256 bonusTokens = (baseTokens * bonusBps) / 10_000;
        uint256 totalTokens = baseTokens + bonusTokens;

        require(totalSold + totalTokens <= CAP, "Presale: cap exceeded");

        totalSold += totalTokens;
        airTkn1.mint(msg.sender, totalTokens);

        emit TokensPurchased(msg.sender, usdcAmount, baseTokens, bonusTokens, totalTokens);
    }

    function _getBonusBps(uint256 cumulativeUsdc) internal pure returns (uint256) {
        if (cumulativeUsdc >= PREMIUM_MIN) {
            return PREMIUM_BPS;
        } else if (cumulativeUsdc >= PRO_MIN && cumulativeUsdc <= PRO_MAX) {
            return PRO_BPS;
        } else if (cumulativeUsdc >= BASIC_MIN && cumulativeUsdc <= BASIC_MAX) {
            return BASIC_BPS;
        } else {
            return 0;
        }
    }
}
