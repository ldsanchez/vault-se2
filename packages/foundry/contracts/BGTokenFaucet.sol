// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract BGTokenFaucet is ERC20 {
    constructor() ERC20("BGToken", "BG") {}

    function requestTokens(uint256 _quantity) public {
        _mint(msg.sender, _quantity * (10 ** decimals()));
    }
}
