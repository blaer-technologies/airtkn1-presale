// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title AirTknVesting
 * @dev Vesting contract for Discount Round 1 allocations:
 *      - 5% unlocked at TGE.
 *      - 6-month cliff on remaining 95%.
 *      - 15-month linear vesting after cliff (21 months total from TGE).
 */
contract AirTknVesting is Ownable {
    IERC20 public immutable airTkn;

    uint256 public immutable tgeTimestamp;
    uint256 public immutable cliffDuration;
    uint256 public immutable vestingDuration;

    uint256 public constant TGE_BPS = 500; // 5%
    uint256 public constant BPS_DENOMINATOR = 10_000;

    struct Schedule {
        uint256 total;
        uint256 claimed;
        bool initialized;
    }

    // ✅ fixed line (no stray ">")
    mapping(address => Schedule) public schedules;

    event ScheduleUpdated(address indexed user, uint256 newTotal, uint256 immediatePaid);
    event Claimed(address indexed user, uint256 amount);

    constructor(
        address _airTkn,
        uint256 _tgeTimestamp,
        uint256 _cliffDuration,
        uint256 _vestingDuration
    ) Ownable(msg.sender){
        require(_airTkn != address(0), "Vesting: AirTkn zero address");
        require(_tgeTimestamp > block.timestamp, "Vesting: TGE in past");
        require(_vestingDuration > 0, "Vesting: zero vesting duration");

        airTkn = IERC20(_airTkn);
        tgeTimestamp = _tgeTimestamp;
        cliffDuration = _cliffDuration;
        vestingDuration = _vestingDuration;
    }

    modifier onlyAfterTGE() {
        require(block.timestamp >= tgeTimestamp, "Vesting: before TGE");
        _;
    }

    /**
     * @dev Called by migration/treasury when user redeems AirTkn1.
     *      - Increases user's total allocation.
     *      - Sends 5% immediately.
     *      - Locks 95% subject to cliff + vesting.
     */
    function addAllocation(address user, uint256 amount) external onlyOwner onlyAfterTGE {
        require(user != address(0), "Vesting: zero user");
        require(amount > 0, "Vesting: zero amount");

        Schedule storage s = schedules[user];

        s.total += amount;

        uint256 immediate = (amount * TGE_BPS) / BPS_DENOMINATOR;

        s.claimed += immediate;

        if (!s.initialized) {
            s.initialized = true;
        }

        require(airTkn.transfer(user, immediate), "Vesting: immediate transfer failed");

        emit ScheduleUpdated(user, s.total, immediate);
    }

    function claim() external onlyAfterTGE {
        Schedule storage s = schedules[msg.sender];
        require(s.initialized, "Vesting: no schedule");

        uint256 vested = vestedAmount(msg.sender);
        uint256 claimable = vested - s.claimed;
        require(claimable > 0, "Vesting: nothing to claim");

        s.claimed = vested;

        require(airTkn.transfer(msg.sender, claimable), "Vesting: claim transfer failed");

        emit Claimed(msg.sender, claimable);
    }

    function vestedAmount(address user) public view returns (uint256) {
        Schedule memory s = schedules[user];
        if (!s.initialized) return 0;

        if (block.timestamp < tgeTimestamp) {
            return 0;
        }

        uint256 tgeVested = (s.total * TGE_BPS) / BPS_DENOMINATOR;
        uint256 locked = s.total - tgeVested;

        uint256 cliffTime = tgeTimestamp + cliffDuration;

        if (block.timestamp <= cliffTime) {
            return tgeVested;
        }

        uint256 timeFromCliff = block.timestamp - cliffTime;
        if (timeFromCliff >= vestingDuration) {
            return s.total;
        } else {
            uint256 vestedLocked = (locked * timeFromCliff) / vestingDuration;
            return tgeVested + vestedLocked;
        }
    }
}
