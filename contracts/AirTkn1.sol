// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title AirTkn1
 * @dev Non-transferable receipt token for Discount Round 1 presale.
 *      - Capped at 8,000,000 tokens (18 decimals).
 *      - Only a designated minter (presale contract) can mint.
 *      - Transfers are disabled (only mint & burn allowed) unless owner enables them.
 */
contract AirTkn1 is ERC20, Ownable {
    uint256 public constant CAP = 8_000_000e18; // 8M tokens
    bool public transfersEnabled;
    address public minter; // presale contract

    constructor()
        ERC20("Blaer Presale Round 1", "AirTkn1")
        Ownable(msg.sender)
    {}

    modifier onlyMinter() {
        require(msg.sender == minter, "AirTkn1: caller is not minter");
        _;
    }

    function setMinter(address _minter) external onlyOwner {
        require(_minter != address(0), "AirTkn1: zero address");
        minter = _minter;
    }

    function setTransfersEnabled(bool enabled) external onlyOwner {
        transfersEnabled = enabled;
    }

    function mint(address to, uint256 amount) external onlyMinter {
        require(totalSupply() + amount <= CAP, "AirTkn1: cap exceeded");
        _mint(to, amount);
    }

    /**
     * @dev Used by migration/vesting contracts to burn user balances.
     *      User must approve this contract or call directly.
     */
    function burnFrom(address account, uint256 amount) external {
        if (msg.sender != account) {
            uint256 allowed = allowance(account, msg.sender);
            require(allowed >= amount, "AirTkn1: allowance too low");
            _approve(account, msg.sender, allowed - amount);
        }
        _burn(account, amount);
    }

    /**
     * @dev OpenZeppelin v5 uses _update instead of _beforeTokenTransfer.
     *      Here we block user-to-user transfers while allowing mint (from=0)
     *      and burn (to=0) unless transfersEnabled is true.
     */
    function _update(address from, address to, uint256 value)
        internal
        override
    {
        if (!transfersEnabled) {
            // Allow mint (from == 0) and burn (to == 0) only
            if (from != address(0) && to != address(0)) {
                revert("AirTkn1: transfers disabled");
            }
        }

        super._update(from, to, value);
    }
}
