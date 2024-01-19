// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./Vault.sol";

/**
 * @title VaultFactory
 * @notice Factory for creating new vaults
 */
contract VaultFactory {
    ////////////////////
    // Errors //////////
    ////////////////////

    error VaultFactory__IsShutdown();
    error VaultFactory__NotGovernance();
    error VaultFactory__FeeBpsGtMaxFeeBps();
    error VaultFactory__FeeRecipientZeroAddress();
    error VaultFactory__NotPendingGovernance();

    ////////////////////
    // Events //////////
    ////////////////////

    event NewVault(address indexed vaultAddress, address indexed asset);
    event UpdateProtocolFeeBps(uint16 oldFeeBps, uint16 newFeeBps);
    event UpdateProtocolFeeRecipient(address oldFeeRecipient, address newFeeRecipient);
    event UpdateCustomProtocolFee(address indexed vault, uint16 newCustomProtocolFee);
    event RemoveCustomProtocolFee(address indexed vault);
    event FactoryShutdown();
    event UpdateGovernance(address indexed governance);
    event NewPendingGovernance(address indexed pendingGovernance);

    struct PFConfig {
        // Percent of protocol's split of fees in Basis Points.
        uint16 feeBps;
        //Address the protocol fees get paid to.
        address feeRecipient;
    }

    // Identifier for this version of the vault.
    string constant VAULT_API_VERSION = "1";

    // The max amount the protocol fee can be set to.
    uint16 constant MAX_FEE_BPS = 5000; // 50%

    // The address of the Vault Blueprint contract.
    // address immutable VAULT_BLUEPRINT;

    // State of the Factory. If True no new vaults can be deployed.
    bool public s_isShutdown;
    // Address that can set or change the fee configs.
    address public s_governance;
    // Pending governance waiting to be accepted.
    address public s_pendingGovernance;
    // Name for the factory identification.
    string public s_name;

    // The default config for assessing protocol fees.
    PFConfig public s_defaultProtocolFeeConfig;
    // Custom fee to charge for a specific vault or strategy.
    mapping(address => uint16) public s_customProtocolFee;
    // Represents if a custom protocol fee should be used.
    mapping(address => bool) public s_useCustomProtocolFee;

    /**
     * Constructor
     * @param name Name of the factory
     * @param governance Address of the factory governance
     */
    constructor(string memory name, address governance) {
        s_name = name;
        s_governance = governance;
    }

    /**
     * @notice Depliy a new vault
     * @param asset Address of the asset to be deposited
     * @param name Name of the new vault
     * @param symbol Symbol of the new vault
     * @param roleManager Address of the role manager
     * @param profitMaxUnlockTime Time in seconds until profit is unlocked
     * @return vaultAddress Address of the new vault
     */
    function deployNewVault(
        ERC20 asset,
        string memory name,
        string memory symbol,
        address roleManager,
        uint256 profitMaxUnlockTime
    ) external payable returns (address vaultAddress) {
        if (s_isShutdown) {
            revert VaultFactory__IsShutdown();
        }
        /// Create a new instance
        Vault vault = (new Vault){value: msg.value}(asset, name, symbol, roleManager, profitMaxUnlockTime);

        emit NewVault(address(vault), address(asset));

        return address(vault);
    }

    /**
     * @notice Get the version of the factory
     * @return version Version of the factory
     */
    function apiVersion() external pure returns (string memory) {
        return VAULT_API_VERSION;
    }

    function protocolFeeConfig() external view returns (PFConfig memory) {
        if (s_useCustomProtocolFee[msg.sender]) {
            return PFConfig(s_defaultProtocolFeeConfig.feeBps, s_defaultProtocolFeeConfig.feeRecipient);
        } else {
            return s_defaultProtocolFeeConfig;
        }
    }

    function setDefaultProtocolFeeBps(uint16 newFeeBps) external {
        if (msg.sender != s_governance) {
            revert VaultFactory__NotGovernance();
        }
        if (newFeeBps > MAX_FEE_BPS) {
            revert VaultFactory__FeeBpsGtMaxFeeBps();
        }
        emit UpdateProtocolFeeBps(s_defaultProtocolFeeConfig.feeBps, newFeeBps);
        s_defaultProtocolFeeConfig.feeBps = newFeeBps;
    }

    /**
     * @notice Set the protocol fee config recipient
     * @param newFeeRecipient Address the protocol fees get paid to.
     */
    function setProtocolFeeRecipient(address newFeeRecipient) external {
        if (msg.sender != s_governance) {
            revert VaultFactory__NotGovernance();
        }
        if (newFeeRecipient == address(0)) {
            revert VaultFactory__FeeRecipientZeroAddress();
        }
        emit UpdateProtocolFeeRecipient(s_defaultProtocolFeeConfig.feeRecipient, newFeeRecipient);
        s_defaultProtocolFeeConfig.feeRecipient = newFeeRecipient;
    }

    /**
     * @notice Set the custom protocol fee for a vault
     * @param vault Address of the vault to set the custom fee for.
     * @param newCustomFeeBps Percent of protocol's split of fees in Basis Points.
     */
    function setCustomProtocolFeeBps(address vault, uint16 newCustomFeeBps) external {
        if (msg.sender != s_governance) {
            revert VaultFactory__NotGovernance();
        }
        if (newCustomFeeBps > MAX_FEE_BPS) {
            revert VaultFactory__FeeBpsGtMaxFeeBps();
        }
        if (s_defaultProtocolFeeConfig.feeRecipient == address(0)) {
            revert VaultFactory__FeeRecipientZeroAddress();
        }
        s_customProtocolFee[vault] = newCustomFeeBps;
        if (!s_useCustomProtocolFee[vault]) {
            s_useCustomProtocolFee[vault] = true;
        }
        emit UpdateCustomProtocolFee(vault, newCustomFeeBps);
    }

    /**
     * @notice Remove the custom protocol fee for a vault
     * @param vault Address of the vault to remove the custom fee for.
     */
    function removeCustomProtocolFee(address vault) external {
        if (msg.sender != s_governance) {
            revert VaultFactory__NotGovernance();
        }
        s_customProtocolFee[vault] = 0;
        s_useCustomProtocolFee[vault] = false;
        emit RemoveCustomProtocolFee(vault);
    }

    /**
     * @notice Shutdown the factory
     */
    function shutdownFactory() external {
        if (msg.sender != s_governance) {
            revert VaultFactory__NotGovernance();
        }
        if (s_isShutdown) {
            revert VaultFactory__IsShutdown();
        }
        s_isShutdown = true;
        emit FactoryShutdown();
    }

    /**
     * @notice Set the governance address
     * @param newGovernance Address of the new governance
     */
    function setGovernance(address newGovernance) external {
        if (msg.sender != s_governance) {
            revert VaultFactory__NotGovernance();
        }
        s_pendingGovernance = newGovernance;
        emit NewPendingGovernance(newGovernance);
    }

    /**
     * @notice Accept the pending governance address
     */
    function acceptGovernance() external {
        if (msg.sender != s_pendingGovernance) {
            revert VaultFactory__NotPendingGovernance();
        }
        s_governance = s_pendingGovernance;
        emit UpdateGovernance(s_governance);
    }
}
