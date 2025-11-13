// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./AirTkn1.sol";
import "./AirTknVesting.sol";

/**
 * @title AirTknMigration
 * @dev Handles migration from AirTkn1 (presale receipts) to vested AirTkn allocations:
 *      - Burns AirTkn1 from user.
 *      - Calls vesting.addAllocation(user, amount).
 */
contract AirTknMigration is Ownable {
    AirTkn1 public immutable airTkn1;
    AirTknVesting public immutable vesting;
    bool public redeemEnabled;

    event Redeemed(address indexed user, uint256 amount);

    constructor(address _airTkn1, address _vesting) Ownable(msg.sender) {
        require(_airTkn1 != address(0), "Migration: AirTkn1 zero address");
        require(_vesting != address(0), "Migration: vesting zero address");

        airTkn1 = AirTkn1(_airTkn1);
        vesting = AirTknVesting(_vesting);
    }

    function setRedeemEnabled(bool enabled) external onlyOwner {
        redeemEnabled = enabled;
    }

    function redeem(uint256 amount) external {
        require(redeemEnabled, "Migration: redeem disabled");
        require(amount > 0, "Migration: zero amount");

        airTkn1.burnFrom(msg.sender, amount);

        vesting.addAllocation(msg.sender, amount);

        emit Redeemed(msg.sender, amount);
    }
}
