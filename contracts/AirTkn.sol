// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title AirTkn
 * @dev Main Blaer token (simplified stub for audit).
 *      Total max supply: 250,000,000 tokens (18 decimals).
 *      For now, the entire supply is minted to a treasury address.
 */
contract AirTkn is ERC20, Ownable {
    uint256 public constant MAX_SUPPLY = 250_000_000e18;

    constructor(address treasury)
    ERC20("Blaer Token", "AirTkn")
    Ownable(msg.sender)
{
    require(treasury != address(0), "AirTkn: zero treasury");
    _mint(treasury, MAX_SUPPLY);
}

}
