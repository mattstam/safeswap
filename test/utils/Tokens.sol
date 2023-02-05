// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.17;

import "@openzeppelin/token/ERC20/ERC20.sol";

contract FooToken is ERC20 {
    /// @dev mint an amount of FOO tokens for the deployer
    constructor(uint256 _mintAmount) ERC20("FooToken", "FOO") {
        _mint(msg.sender, _mintAmount);
    }
}

contract BarToken is ERC20 {
    /// @dev mint an amount of BAR tokens for the deployer
    constructor(uint256 _mintAmount) ERC20("BarToken", "BAR") {
        _mint(msg.sender, _mintAmount);
    }
}
