// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/BGTokenFaucet.sol";

contract VaultTest is Test {
    BGTokenFaucet public bgTokenFaucet;

    function setUp() public {
        bgTokenFaucet = new BGTokenFaucet();
    }

    // function testMessageOnDeployment() public view {
    //     require(
    //         keccak256(bytes(yourContract.greeting())) ==
    //             keccak256("Building Unstoppable Apps!!!")
    //     );
    // }

    // function testSetNewMessage() public {
    //     yourContract.setGreeting("Learn Scaffold-ETH 2! :)");
    //     require(
    //         keccak256(bytes(yourContract.greeting())) ==
    //             keccak256("Learn Scaffold-ETH 2! :)")
    //     );
    // }
}
