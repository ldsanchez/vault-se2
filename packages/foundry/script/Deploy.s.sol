//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// import "../contracts/YourContract.sol";
import "../contracts/BGTokenFaucet.sol";
import "../contracts/VaultFactory.sol";
import "../contracts/Vault.sol";
import "./DeployHelpers.s.sol";

contract DeployScript is ScaffoldETHDeploy {
    error InvalidPrivateKey(string);

    function run() external {
        uint256 deployerPrivateKey = setupLocalhostEnv();
        if (deployerPrivateKey == 0) {
            revert InvalidPrivateKey(
                "You don't have a deployer account. Make sure you have set DEPLOYER_PRIVATE_KEY in .env or use `yarn generate` to generate a new random account"
            );
        }
        vm.startBroadcast(deployerPrivateKey);
        BGTokenFaucet bgTokenFaucet = new BGTokenFaucet();
        console.logString(string.concat("BGTokenFaucet deployed at: ", vm.toString(address(bgTokenFaucet))));
        vm.stopBroadcast();

        // vm.startBroadcast(deployerPrivateKey);
        // Vault vault = new Vault(bgTokenFaucet, 100);
        // console.logString(string.concat("Vault deployed at: ", vm.toString(address(vault))));
        // vm.stopBroadcast();

        vm.startBroadcast(deployerPrivateKey);
        VaultFactory vaultFactory = new VaultFactory("VaultFactory", address(this));
        console.logString(string.concat("VaultFactory deployed at: ", vm.toString(address(vaultFactory))));
        vm.stopBroadcast();

        /**
         * This function generates the file containing the contracts Abi definitions.
         * These definitions are used to derive the types needed in the custom scaffold-eth hooks, for example.
         * This function should be called last.
         */
        exportDeployments();
    }

    function test() public {}
}
