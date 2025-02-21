// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestERC20 is ERC20 {
    constructor(string memory name, string memory symbol, uint8 decimals) ERC20(name, symbol) {
        initialize(name, symbol, decimals);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

     function burn(address from, uint256 amount) public {
        _burn(from, amount);
    }
}