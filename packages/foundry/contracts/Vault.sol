// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

////////////////////
// Enums ///////////
////////////////////

enum StrategyChangeType {
    ADDED,
    REVOKED
}

enum Roles {
    ADD_STRATEGY_MANAGER, // Can add strategies to the vault.
    REVOKE_STRATEGY_MANAGER, // Can remove strategies from the vault.
    FORCE_REVOKE_MANAGER, // Can force remove a strategy causing a loss.
    ACCOUNTANT_MANAGER, // Can set the accountant that assess fees.
    QUEUE_MANAGER, // Can set the default withdrawal queue.
    REPORTING_MANAGER, // Calls report for strategies.
    DEBT_MANAGER, // Adds and removes debt from strategies.
    MAX_DEBT_MANAGER, // Can set the max debt for a strategy.
    DEPOSIT_LIMIT_MANAGER, // Sets deposit limit and module for the vault.
    WITHDRAW_LIMIT_MANAGER, // Sets the withdraw limit module.
    MINIMUM_IDLE_MANAGER, // Sets the minimum total idle the vault should keep.
    PROFIT_UNLOCK_MANAGER, // Sets the profit_max_unlock_time.
    DEBT_PURCHASER, // Can purchase bad debt from the vault.
    EMERGENCY_MANAGER // Can shutdown vault in an emergency.

}

enum RoleStatusChange {
    OPENED,
    CLOSED
}

enum Rounding {
    ROUND_DOWN,
    ROUND_UP
}

////////////////////
// Constants ///////
////////////////////

// The max length the withdrawal queue can be.
uint256 constant MAX_QUEUE = 10;

// The max basis points that can be charged for fees.
uint256 constant MAX_BPS = 10000;

// Extended for profit locking calculations.
uint256 constant MAX_BPS_EXTENDED = 1000000000000;

// API Version of the Vault
string constant API_VERSION = "1";

////////////////////
// Interfaces //////
////////////////////

interface IStrategy {
    function asset() external view returns (address);

    function balanceOf(address owner) external view returns (uint256);

    function maxDeposit(address receiver) external view returns (uint256);

    function redeem(uint256 shares, address receiver, address owner) external returns (uint256);

    function deposit(uint256 assets, address receiver) external returns (uint256);

    function totalAssets() external view returns (uint256);

    function convertToAssets(uint256 shares) external view returns (uint256);

    function convertToShares(uint256 assets) external view returns (uint256);

    function previewWithdraw(uint256 assets) external view returns (uint256);

    function maxRedeem(address owner) external view returns (uint256);
}

interface IAccountant {
    function report(address strategy, uint256 gain, uint256 loss) external returns (uint256, uint256);
}

interface IDepositLimitModule {
    function availableDepositLimit(address receiver) external view returns (uint256);
}

interface IWithdrawLimitModule {
    function availableWithdrawLimit(address owner, uint256 maxLoss, address[] memory) external view returns (uint256);
}

interface IVaultFactory {
    function protocolFeeConfig() external view returns (uint16, address);
}

contract Vault is ReentrancyGuard {
    ////////////////////
    // Immutable ///////
    ////////////////////

    // Underlying token used by the vault.
    ERC20 immutable ASSET;

    // The number of decimals the underlying token has.
    uint256 immutable DECIMALS;

    // Deployer contract used to retrieve the protocol fee config.
    address payable immutable FACTORY;

    ////////////////////
    // Errors //////////
    ////////////////////

    error Vault__ProfitUnlockTimeTooLong();
    error Vault__InsufficientAllowance();
    error Vault__InsufficientFunds();
    error ERC20__ApproveFailed();
    error ERC20__TransferFailed();
    error Vault__AmountTooHigh();
    error Vault__IsShutdown();
    error Vault__ExceedsDepositLimit();
    error Vault__CannotMintZero();
    error Vault__CannotDepositZero();
    error Vault__ZeroAddress();
    error Vault__MaxLoss();
    error Vault__ExceedsWithdrawLimit();
    error Vault__NoSharesToRedeem();
    error Vault__InsufficientSharesToRedeem();
    error Vault__InvalidAsset();
    error Vault__StrategyAlredyActive();
    error Vault__StrategyNotActive();
    error Vault__StrategyHasDebt();
    error Vault__NewDebtEqualsCurrentDebt();
    error Vault__NothingToWithdraw();
    error Vault__StrategyHasUnrealizedLosses();
    error Vault__TargetDebtHigherThanMaxDebt();
    error Vault__NothingToDeposit();
    error Vault__NoFundsToDeposit();
    error Vault__UsingDepositModule();
    // Check this
    error Vault__UsingDepositLimit();
    error Vault__NotAllowed();
    error Vault__NotRoleManager();
    error Vault__NothingToBuyWith();
    error Vault__NothingToBuy();
    error Vault__CannotBuyZero();
    error Vault__InvalidOwner();
    error Vault__PermitExpired();
    error Vault__NotEnough();
    error Vault__InvalidSignature();

    ////////////////////
    // Events //////////
    ////////////////////

    // ERC4626 events
    event Deposit(address indexed sender, address indexed owner, uint256 assets, uint256 shares);

    event Withdraw(address indexed sender, address indexed receiver, address owener, uint256 assets, uint256 shares);

    // ERC20 events
    event Transfer(address indexed sender, address indexed receiver, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);

    // Strategy events

    event StrategyChanged(address indexed strategy, StrategyChangeType indexed changeType);

    event StrategyReported(
        address indexed strategy,
        uint256 gain,
        uint256 loss,
        uint256 currentDebt,
        uint256 protocolFees,
        uint256 totalFees,
        uint256 totalRefunds
    );

    // Debt Management events

    event DebtUpdated(address indexed strategy, uint256 currentDebt, uint256 newDebt);

    // Role Update events

    event RoleSet(address indexed account, Roles indexed role);

    event RolesStatusChanged(Roles indexed role, RoleStatusChange indexed status);

    // Management events

    event UpdateRoleManager(address indexed roleManager);

    event UpdateAccountant(address indexed accountant);

    event UpdateDepositLimitModule(address indexed depositLimitModule);

    event UpdateWithdrawLimitModule(address indexed withdrawLimitModule);

    event UpdateDefaultQueue(address[MAX_QUEUE] newDefaultQueue);

    event UpdateUseDefaultQueue(bool useDefaultQueue);

    event UpdateMaxDebtForStrategy(address indexed sender, address indexed strategy, uint256 maxDebt);

    event UpdateDepositLimit(uint256 depositLimit);

    event UpdateMinimumTotalIdle(uint256 minimumTotalIdle);

    event UpdateProfitMaxUnlockTime(uint256 profitMaxUnlockTime);

    event DebtPurchased(address indexed strategy, uint256 amount);

    event Shutdown();

    ////////////////////
    // Structs /////////
    ////////////////////

    struct StrategyParams {
        uint256 activation;
        uint256 lastReport;
        uint256 currentDebt;
        uint256 maxDebt;
    }

    ////////////////////
    // Mappings ////////
    ////////////////////

    mapping(address => StrategyParams) public s_strategies;
    // address[MAX_QUEUE] public s_defaultQueue;
    // address[] public s_defaultQueue = new address[](MAX_QUEUE);
    address[] public s_defaultQueue;
    bool public s_useDefaultQueue;

    mapping(address => uint256) s_balanceOf;
    mapping(address => mapping(address => uint256)) allowance;
    uint256 public s_totalSupply;

    uint256 s_totalDebt;
    uint256 s_totalIdle;
    uint256 public s_minimumTotalIdle;
    uint256 public s_depositLimit;
    address public s_accountant;
    address public s_depositLimitModule;
    address public s_withdrawLimitModule;
    mapping(address => Roles) public s_roles;
    mapping(Roles => bool) public s_openRoles;
    address public s_roleManager;
    address public s_furureRoleManager;

    string public s_name;
    string public s_symbol;

    bool s_isShutdown;
    uint256 s_profitMaxUnlockTime;
    uint256 s_fullProfitUnlockDate;
    uint256 s_profitUnlockingRate;
    uint256 s_lastProfitUpdate;

    mapping(address => uint256) public nonces;
    bytes32 constant DOMAIN_TYPE_HASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 constant PERMIT_TYPE_HASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce, uint256 deadline)");

    constructor(
        ERC20 _asset,
        string memory _name,
        string memory _symbol,
        address _roleManager,
        uint256 _profitMaxUnlockTime
    ) payable {
        ASSET = _asset;
        DECIMALS = _asset.decimals();
        FACTORY = payable(msg.sender);

        if (_profitMaxUnlockTime > 31556952) {
            revert Vault__ProfitUnlockTimeTooLong();
        }

        s_profitMaxUnlockTime = _profitMaxUnlockTime;

        s_name = _name;
        s_symbol = _symbol;
        s_roleManager = _roleManager;
    }

    function _approve(address owner, address spender, uint256 amount) internal returns (bool) {
        allowance[owner][spender] = amount;
        emit Approval(owner, spender, amount);
        return true;
    }

    function _spendAllowance(address owner, address spender, uint256 amount) internal {
        uint256 currentAllowance = allowance[owner][spender];
        if (currentAllowance < amount) {
            revert Vault__InsufficientAllowance();
        }
        _approve(owner, spender, currentAllowance - amount);
    }

    function _transfer(address sender, address receiver, uint256 amount) internal {
        uint256 senderBalance = s_balanceOf[sender];
        if (senderBalance < amount) {
            revert Vault__InsufficientFunds();
        }
        s_balanceOf[sender] = senderBalance - amount;
        s_balanceOf[receiver] += amount;
        emit Transfer(sender, receiver, amount);
    }

    function _transferFrom(address sender, address receiver, uint256 amount) internal returns (bool) {
        _spendAllowance(sender, msg.sender, amount);
        _transfer(sender, receiver, amount);
        return true;
    }

    function _increaseAllowance(address owner, address spender, uint256 amount) internal returns (bool) {
        uint256 newAllowance = allowance[owner][spender] + amount;
        _approve(owner, spender, newAllowance);
        emit Approval(owner, spender, newAllowance);
        return true;
    }

    function _decreaseAllowance(address owner, address spender, uint256 amount) internal returns (bool) {
        uint256 newAllowance = allowance[owner][spender] - amount;
        _approve(owner, spender, newAllowance);
        emit Approval(owner, spender, newAllowance);
        return true;
    }

    function _permit(address owner, address spender, uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        internal
        returns (bool)
    {
        if (owner == address(0)) {
            revert Vault__InvalidOwner();
        }
        if (deadline < block.timestamp) {
            revert Vault__PermitExpired();
        }
        uint256 nonce = nonces[owner];
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator(),
                keccak256(
                    abi.encodePacked(
                        PERMIT_TYPE_HASH,
                        bytes32(bytes20(owner)),
                        bytes32(bytes20(spender)),
                        bytes32(amount),
                        bytes32(nonce),
                        bytes32(deadline)
                    )
                )
            )
        );
        if (owner != ecrecover(digest, v, r, s)) {
            revert Vault__InvalidSignature();
        }

        allowance[owner][spender] = amount;
        nonces[owner] = nonce + 1;
        emit Approval(owner, spender, amount);
        return true;
    }

    function _burnShares(uint256 shares, address owner) internal {
        s_balanceOf[owner] -= shares;
        s_totalSupply -= shares;
        emit Transfer(owner, address(0), shares);
    }

    function _unlockedShares() internal view returns (uint256) {
        uint256 fullProfitUnlockDate = s_fullProfitUnlockDate;
        uint256 unlockedShares = 0;
        if (fullProfitUnlockDate > block.timestamp) {
            unlockedShares = s_profitUnlockingRate * (block.timestamp - s_lastProfitUpdate) / MAX_BPS_EXTENDED;
        } else if (fullProfitUnlockDate != 0) {
            unlockedShares = s_balanceOf[address(this)];
        }
        return unlockedShares;
    }

    function _totalSupply() internal view returns (uint256) {
        return s_totalSupply - _unlockedShares();
    }

    function _burnUnlockedShares() internal {
        uint256 unlockedShares = _unlockedShares();
        if (unlockedShares == 0) {
            return;
        }

        if (s_fullProfitUnlockDate > block.timestamp) {
            s_lastProfitUpdate = block.timestamp;
        }

        _burnShares(unlockedShares, address(this));
    }

    function _totalAssets() internal view returns (uint256) {
        return s_totalIdle + s_totalDebt;
    }

    function _convertToAssets(uint256 shares, Rounding rounding) internal view returns (uint256) {
        if (shares == type(uint256).max || shares == 0) {
            return shares;
        }
        uint256 totalSupply = _totalSupply();
        uint256 totalAssets = _totalAssets();
        if (totalSupply == 0) {
            return shares;
        }
        uint256 numerator = shares * totalAssets;
        uint256 amount = numerator / totalSupply;
        if (rounding == Rounding.ROUND_UP && numerator % totalSupply != 0) {
            return amount += 1;
        }

        return amount;
    }

    function _convertToShares(uint256 assets, Rounding rounding) internal view returns (uint256) {
        if (assets == type(uint256).max || assets == 0) {
            return assets;
        }
        uint256 totalSupply = _totalSupply();
        uint256 totalAssets = _totalAssets();
        if (totalAssets == 0) {
            if (s_totalSupply == 0) {
                return assets;
            } else {
                return 0;
            }
        }
        uint256 numerator = assets * totalSupply;
        uint256 shares = numerator / totalAssets;
        if (rounding == Rounding.ROUND_UP && numerator % totalAssets != 0) {
            return shares += 1;
        }

        return shares;
    }

    function _erc20SafeApprove(address token, address spender, uint256 amount) internal {
        if (ERC20(token).approve(spender, amount) == false) {
            revert ERC20__ApproveFailed();
        }
    }

    function _erc20SafeTransferFrom(address token, address sender, address receiver, uint256 amount) internal {
        if (ERC20(token).transferFrom(sender, receiver, amount) == false) {
            revert ERC20__TransferFailed();
        }
    }

    function _erc20SafeTransfer(address token, address receiver, uint256 amount) internal {
        if (ERC20(token).transfer(receiver, amount) == false) {
            revert ERC20__TransferFailed();
        }
    }

    function _issueShares(uint256 shares, address recipient) internal {
        s_balanceOf[recipient] += shares;
        s_totalSupply += shares;
        emit Transfer(address(0), recipient, shares);
    }

    function _issueSharesForAmount(uint256 amount, address recipient) internal returns (uint256) {
        uint256 totalSupply = _totalSupply();
        uint256 totalAssets = _totalAssets();
        uint256 newShares = 0;
        if (totalSupply == 0) {
            newShares = amount;
        } else if (totalAssets > amount) {
            newShares = amount * totalSupply / (totalAssets - amount);
        } else {
            if (totalAssets <= amount) {
                revert Vault__AmountTooHigh();
            }
        }
        if (newShares == 0) {
            return 0;
        }

        _issueShares(newShares, recipient);

        return newShares;
    }

    function _maxDeposit(address receiver) internal view returns (uint256) {
        if (receiver == address(this) || receiver == address(0)) {
            return 0;
        }
        address depositLimitModule = s_depositLimitModule;
        if (depositLimitModule == address(0)) {
            return IDepositLimitModule(depositLimitModule).availableDepositLimit(receiver);
        }
        uint256 totalAssets = _totalAssets();
        uint256 depositLimit = s_depositLimit;
        if (totalAssets >= depositLimit) {
            return 0;
        }
        return depositLimit - totalAssets;
    }

    function _maxWithdraw(address owner, uint256 maxLoss, address[] memory strategies)
        internal
        view
        returns (uint256)
    {
        uint256 maxAssets = _convertToAssets(s_balanceOf[owner], Rounding.ROUND_DOWN);

        address withdrawLimitModule = s_withdrawLimitModule;
        if (withdrawLimitModule != address(0)) {
            return Math.min(
                IWithdrawLimitModule(withdrawLimitModule).availableWithdrawLimit(owner, maxLoss, strategies), maxAssets
            );
        }

        uint256 currentIdle = s_totalIdle;
        if (maxAssets > currentIdle) {
            uint256 have = currentIdle;
            uint256 loss = 0;

            // address[MAX_QUEUE] memory _strategies = s_defaultQueue;
            address[] memory _strategies = new address[](MAX_QUEUE);
            _strategies = s_defaultQueue;

            if (strategies.length != 0 && !(s_useDefaultQueue)) {
                _strategies = strategies;
            }

            for (uint256 i = 0; i < _strategies.length; i++) {
                address strategy = _strategies[i];
                if (strategy == address(0)) {
                    revert Vault__StrategyNotActive();
                }

                uint256 toWithdraw = Math.min(maxAssets - have, s_strategies[strategy].currentDebt);

                uint256 unrealizedLoss = _assessSharesOfUnrealizedLosses(strategy, toWithdraw);

                uint256 strategyLimit =
                    IStrategy(strategy).convertToAssets(IStrategy(strategy).maxRedeem(address(this)));

                if (strategyLimit < toWithdraw - unrealizedLoss) {
                    unrealizedLoss = unrealizedLoss * strategyLimit / toWithdraw;
                    toWithdraw = strategyLimit + unrealizedLoss;
                }

                if (toWithdraw == 0) {
                    continue;
                }

                if (unrealizedLoss > 0 && maxLoss < MAX_BPS) {
                    if (loss + unrealizedLoss > (have + toWithdraw) * maxLoss / MAX_BPS) {
                        break;
                    }
                }

                have += toWithdraw;

                if (have >= maxAssets) {
                    break;
                }

                loss += unrealizedLoss;
            }

            maxAssets = have;
        }
        return maxAssets;
    }

    function _deposit(address sender, address recipient, uint256 assets) internal returns (uint256) {
        if (s_isShutdown) {
            revert Vault__IsShutdown();
        }
        if (assets > _maxDeposit(recipient)) {
            revert Vault__ExceedsDepositLimit();
        }
        _erc20SafeTransferFrom(address(ASSET), sender, address(this), assets);
        s_totalIdle += assets;

        uint256 shares = _issueSharesForAmount(assets, recipient);

        if (shares <= 0) {
            revert Vault__CannotMintZero();
        }
        emit Deposit(sender, recipient, assets, shares);

        return shares;
    }

    function _mint(address sender, address recipient, uint256 shares) internal returns (uint256) {
        if (s_isShutdown) {
            revert Vault__IsShutdown();
        }
        uint256 assets = _convertToAssets(shares, Rounding.ROUND_UP);
        if (assets <= 0) {
            revert Vault__CannotDepositZero();
        }
        if (assets > _maxDeposit(recipient)) {
            revert Vault__ExceedsDepositLimit();
        }
        _erc20SafeTransferFrom(address(ASSET), sender, address(this), assets);
        s_totalIdle += assets;

        _issueShares(shares, recipient);

        emit Deposit(sender, recipient, assets, shares);
        return assets;
    }

    function _assessSharesOfUnrealizedLosses(address strategy, uint256 assetsNeeded) internal view returns (uint256) {
        uint256 strategyCurrentDebt = s_strategies[strategy].currentDebt;
        uint256 vaultShares = IStrategy(strategy).balanceOf(address(this));
        uint256 strategyAssets = IStrategy(strategy).convertToAssets(vaultShares);

        if (strategyAssets >= strategyCurrentDebt || strategyCurrentDebt == 0) {
            return 0;
        }

        uint256 numerator = assetsNeeded * strategyAssets;
        uint256 lossesUserShare = assetsNeeded - numerator / strategyCurrentDebt;

        if (numerator % strategyCurrentDebt != 0) {
            lossesUserShare += 1;
        }
        return lossesUserShare;
    }

    function _withdrawFromStrategy(address strategy, uint256 assetsToWithdraw) internal {
        uint256 sharesToRedeem = Math.min(
            IStrategy(strategy).previewWithdraw(assetsToWithdraw), IStrategy(strategy).balanceOf(address(this))
        );
        IStrategy(strategy).redeem(sharesToRedeem, address(this), address(this));
    }

    function _redeem(
        address sender,
        address receiver,
        address owner,
        uint256 assets,
        uint256 sharesToBurn,
        uint256 maxLoss,
        address[] memory strategies
    ) internal returns (uint256) {
        if (receiver == address(0)) {
            revert Vault__ZeroAddress();
        }
        if (maxLoss > MAX_BPS) {
            revert Vault__MaxLoss();
        }
        if (s_withdrawLimitModule != address(0)) {
            if (assets > _maxWithdraw(owner, maxLoss, strategies)) {
                revert Vault__ExceedsWithdrawLimit();
            }
        }

        uint256 shares = sharesToBurn;
        uint256 sharesBalance = s_balanceOf[owner];

        if (shares <= 0) {
            revert Vault__NoSharesToRedeem();
        }
        if (sharesBalance < shares) {
            revert Vault__InsufficientSharesToRedeem();
        }

        if (sender != owner) {
            _spendAllowance(owner, sender, sharesToBurn);
        }

        uint256 requestedAssets = assets;

        uint256 currTotalIdle = s_totalIdle;

        if (requestedAssets > currTotalIdle) {
            address[] memory _strategies = s_defaultQueue;

            if (strategies.length != 0 && !(s_useDefaultQueue)) {
                _strategies = strategies;
            }

            uint256 currTotalDebt = s_totalDebt;

            uint256 assetsNeeded = requestedAssets - currTotalIdle;
            uint256 assetsToWithdraw = 0;

            uint256 previousBalance = ASSET.balanceOf(address(this));

            for (uint256 i = 0; i < _strategies.length; i++) {
                address strategy = _strategies[i];
                if (strategy == address(0)) {
                    revert Vault__StrategyNotActive();
                }

                uint256 currentDebt = s_strategies[strategy].currentDebt;

                assetsToWithdraw = Math.min(assetsNeeded, currentDebt);

                uint256 maxWithdraw = IStrategy(strategy).convertToAssets(IStrategy(strategy).maxRedeem(address(this)));

                uint256 unrealizedLossesShare = _assessSharesOfUnrealizedLosses(strategy, assetsToWithdraw);
                if (unrealizedLossesShare > 0) {
                    if (maxWithdraw < assetsToWithdraw - unrealizedLossesShare) {
                        uint256 wanted = assetsToWithdraw - unrealizedLossesShare;
                        unrealizedLossesShare = unrealizedLossesShare * maxWithdraw / wanted;
                        assetsToWithdraw = maxWithdraw + unrealizedLossesShare;
                    }

                    assetsToWithdraw -= unrealizedLossesShare;
                    requestedAssets -= unrealizedLossesShare;
                    assetsNeeded -= unrealizedLossesShare;
                    currTotalDebt -= unrealizedLossesShare;

                    if (maxWithdraw == 0 && unrealizedLossesShare > 0) {
                        uint256 newDebt = currentDebt - unrealizedLossesShare;

                        s_strategies[strategy].currentDebt = newDebt;
                        emit DebtUpdated(strategy, currentDebt, newDebt);
                    }
                }

                assetsToWithdraw = Math.min(assetsToWithdraw, maxWithdraw);

                if (assetsToWithdraw == 0) {
                    continue;
                }

                _withdrawFromStrategy(strategy, assetsToWithdraw);
                uint256 postBalance = ASSET.balanceOf(address(this));

                uint256 withdrawn = postBalance - previousBalance;
                uint256 loss = 0;
                if (withdrawn > assetsToWithdraw) {
                    if (withdrawn > currentDebt) {
                        assetsToWithdraw = currentDebt;
                    } else {
                        assetsToWithdraw += withdrawn - assetsToWithdraw;
                    }
                } else if (withdrawn < assetsToWithdraw) {
                    loss = assetsToWithdraw - withdrawn;
                }

                currTotalIdle += assetsToWithdraw - loss;
                requestedAssets -= loss;
                currTotalDebt -= assetsToWithdraw;

                uint256 newDebt = currentDebt - (assetsToWithdraw + unrealizedLossesShare);

                s_strategies[strategy].currentDebt = newDebt;
                emit DebtUpdated(strategy, currentDebt, newDebt);

                if (requestedAssets <= currTotalIdle) {
                    break;
                }

                previousBalance = postBalance;

                assetsNeeded -= assetsToWithdraw;
            }

            if (currTotalIdle < requestedAssets) {
                revert Vault__InsufficientFunds();
            }
            s_totalDebt = currTotalDebt;
        }

        if (assets > requestedAssets && maxLoss < MAX_BPS) {
            if (assets - requestedAssets > (assets * maxLoss / MAX_BPS)) {
                revert Vault__MaxLoss();
            }
        }

        _burnShares(shares, owner);
        s_totalIdle = currTotalIdle - requestedAssets;
        _erc20SafeTransfer(address(ASSET), receiver, requestedAssets);

        emit Withdraw(sender, receiver, owner, requestedAssets, shares);
        return requestedAssets;
    }

    function _addStrategy(address newStrategy) internal {
        if (newStrategy == address(0) || newStrategy == address(this)) {
            revert Vault__ZeroAddress();
        }
        if (IStrategy(newStrategy).asset() != address(ASSET)) {
            revert Vault__InvalidAsset();
        }
        if (s_strategies[newStrategy].activation != 0) {
            revert Vault__StrategyAlredyActive();
        }
        s_strategies[newStrategy] =
            StrategyParams({activation: block.timestamp, lastReport: block.timestamp, currentDebt: 0, maxDebt: 0});

        if (s_defaultQueue.length < MAX_QUEUE) {
            s_defaultQueue.push(newStrategy);
        }

        emit StrategyChanged(newStrategy, StrategyChangeType.ADDED);
    }

    // Check this
    function _revokeStrategy(address strategy, bool force) internal {
        if (s_strategies[strategy].activation == 0) {
            revert Vault__StrategyNotActive();
        }
        uint256 loss = 0;

        if (s_strategies[strategy].currentDebt != 0) {
            if (force) {
                revert Vault__StrategyHasDebt();
            }
            loss = s_strategies[strategy].currentDebt;
            s_totalDebt -= loss;
            emit StrategyReported(strategy, 0, loss, 0, 0, 0, 0);
        }
        s_strategies[strategy] = StrategyParams({activation: 0, lastReport: 0, currentDebt: 0, maxDebt: 0});

        // Check this
        address[] memory newQueue = new address[](s_defaultQueue.length);

        for (uint256 i = 0; i < s_defaultQueue.length; i++) {
            if (s_defaultQueue[i] != strategy) {
                newQueue[i] = s_defaultQueue[i];
            }
        }
        s_defaultQueue = newQueue;

        emit StrategyChanged(strategy, StrategyChangeType.REVOKED);
    }

    function _updateDebt(address strategy, uint256 targetDebt) internal returns (uint256) {
        uint256 newDebt = targetDebt;
        uint256 currentDebt = s_strategies[strategy].currentDebt;

        if (s_isShutdown) {
            newDebt = 0;
        }

        if (newDebt == currentDebt) {
            revert Vault__NewDebtEqualsCurrentDebt();
        }

        if (currentDebt > newDebt) {
            uint256 assetsToWithdraw = currentDebt - newDebt;

            uint256 minimumTotalIdle = s_minimumTotalIdle;
            uint256 totalIdle = s_totalIdle;

            if (totalIdle + assetsToWithdraw < minimumTotalIdle) {
                assetsToWithdraw = minimumTotalIdle - totalIdle;
                if (assetsToWithdraw > currentDebt) {
                    assetsToWithdraw = currentDebt;
                }
            }

            uint256 withdrawable = IStrategy(strategy).convertToAssets(IStrategy(strategy).maxRedeem(address(this)));
            if (withdrawable == 0) {
                revert Vault__NothingToWithdraw();
            }

            if (withdrawable < assetsToWithdraw) {
                assetsToWithdraw = withdrawable;
            }

            uint256 unrealizedLossesShare = _assessSharesOfUnrealizedLosses(strategy, assetsToWithdraw);
            if (unrealizedLossesShare != 0) {
                revert Vault__StrategyHasUnrealizedLosses();
            }

            uint256 preBalance = ASSET.balanceOf(address(this));
            _withdrawFromStrategy(strategy, assetsToWithdraw);
            uint256 postBalance = ASSET.balanceOf(address(this));

            uint256 withdrawn = Math.min(postBalance - preBalance, currentDebt);

            if (withdrawn > assetsToWithdraw) {
                assetsToWithdraw = withdrawn;
            }

            s_totalIdle += withdrawn;
            s_totalDebt -= assetsToWithdraw;

            newDebt = currentDebt - assetsToWithdraw;
        } else {
            if (newDebt > s_strategies[strategy].maxDebt) {
                revert Vault__TargetDebtHigherThanMaxDebt();
            }

            uint256 maxDeposit = IStrategy(strategy).maxDeposit(address(this));
            if (maxDeposit == 0) {
                revert Vault__NothingToDeposit();
            }

            uint256 assetsToDeposit = newDebt - currentDebt;
            if (assetsToDeposit > maxDeposit) {
                assetsToDeposit = maxDeposit;
            }

            uint256 minimumTotalIdle = s_minimumTotalIdle;
            uint256 totalIdle = s_totalIdle;

            if (totalIdle <= minimumTotalIdle) {
                revert Vault__NoFundsToDeposit();
            }
            uint256 availableIdle = totalIdle - minimumTotalIdle;

            if (assetsToDeposit > availableIdle) {
                assetsToDeposit = availableIdle;
            }

            if (assetsToDeposit > 0) {
                _erc20SafeTransfer(address(ASSET), strategy, assetsToDeposit);

                uint256 preBalance = ASSET.balanceOf(address(this));
                IStrategy(strategy).deposit(assetsToDeposit, address(this));
                uint256 postBalance = ASSET.balanceOf(address(this));

                _erc20SafeApprove(address(ASSET), strategy, 0);

                assetsToDeposit = preBalance - postBalance;

                s_totalIdle -= assetsToDeposit;
                s_totalDebt += assetsToDeposit;
            }

            newDebt = currentDebt + assetsToDeposit;
        }
        s_strategies[strategy].currentDebt = newDebt;
        emit DebtUpdated(strategy, currentDebt, newDebt);

        return newDebt;
    }

    function _processReport(address strategy) internal returns (uint256, uint256) {
        if (s_strategies[strategy].activation == 0) {
            revert Vault__StrategyNotActive();
        }

        _burnUnlockedShares();

        uint256 strategyShares = IStrategy(strategy).balanceOf(address(this));
        uint256 totalAssets = IStrategy(strategy).convertToAssets(strategyShares);
        uint256 currentDebt = s_strategies[strategy].currentDebt;

        uint256 gain = 0;
        uint256 loss = 0;

        if (totalAssets > currentDebt) {
            gain = totalAssets - currentDebt;
        } else {
            loss = currentDebt - totalAssets;
        }

        uint256 totalFees = 0;
        uint256 totalRefunds = 0;
        uint256 protocolFees = 0;
        address protocolFeeRecipient = address(0);

        address accountant = s_accountant;
        if (accountant != address(0)) {
            (totalFees, totalRefunds) = IAccountant(accountant).report(strategy, gain, loss);

            if (totalFees > 0) {
                uint16 protocolFeeBps = 0;
                (protocolFeeBps, protocolFeeRecipient) = IVaultFactory(FACTORY).protocolFeeConfig();

                if (protocolFeeBps > 0) {
                    protocolFees = totalFees * protocolFeeBps / MAX_BPS;
                }
            }
        }

        uint256 sharesToBurn = 0;
        uint256 accountantFeeShares = 0;
        uint256 protocolFeeShares = 0;
        if (loss + totalFees > 0) {
            sharesToBurn += _convertToShares(loss + totalFees, Rounding.ROUND_UP);

            if (totalFees > 0) {
                accountantFeeShares = _convertToShares(totalFees - protocolFees, Rounding.ROUND_DOWN);
                if (protocolFees > 0) {
                    protocolFeeShares = _convertToShares(protocolFees, Rounding.ROUND_DOWN);
                }
            }
        }

        uint256 newlyLockedShares = 0;
        if (totalRefunds > 0) {
            totalRefunds = Math.min(
                totalRefunds, Math.min(ASSET.balanceOf(accountant), ASSET.allowance(accountant, address(this)))
            );
            _erc20SafeTransferFrom(address(ASSET), accountant, address(this), totalRefunds);
            s_totalIdle += totalRefunds;
        }

        if (gain > 0) {
            s_strategies[strategy].currentDebt += gain;
            s_totalDebt += gain;
        }

        uint256 profitMaxUnlockTime = s_profitMaxUnlockTime;
        if (gain + totalRefunds > 0 && profitMaxUnlockTime != 0) {
            newlyLockedShares = _issueSharesForAmount(gain + totalRefunds, address(this));
        }

        if (loss > 0) {
            s_strategies[strategy].currentDebt -= loss;
            s_totalDebt -= loss;
        }
        uint256 previouslyLockedShares = s_balanceOf[address(this)] - newlyLockedShares;

        if (sharesToBurn > 0) {
            sharesToBurn = Math.min(sharesToBurn, previouslyLockedShares + newlyLockedShares);
            _burnShares(sharesToBurn, address(this));

            uint256 sharesNotToLock = Math.min(sharesToBurn, newlyLockedShares);
            newlyLockedShares -= sharesNotToLock;
            previouslyLockedShares -= (sharesToBurn - sharesNotToLock);
        }

        if (accountantFeeShares > 0) {
            _issueShares(accountantFeeShares, accountant);
        }

        if (protocolFeeShares > 0) {
            _issueShares(protocolFeeShares, protocolFeeRecipient);
        }

        uint256 totalLockedShares = previouslyLockedShares + newlyLockedShares;
        if (totalLockedShares > 0) {
            uint256 previouslyLockedTime = 0;
            uint256 _fullProfitUnlockDate = s_fullProfitUnlockDate;
            if (_fullProfitUnlockDate > block.timestamp) {
                previouslyLockedTime = previouslyLockedShares * (_fullProfitUnlockDate - block.timestamp);
            }

            uint256 newProfitLockingPeriod =
                (previouslyLockedTime + newlyLockedShares * profitMaxUnlockTime) / totalLockedShares;
            s_profitUnlockingRate = totalLockedShares * MAX_BPS_EXTENDED / newProfitLockingPeriod;
            s_fullProfitUnlockDate = block.timestamp + newProfitLockingPeriod;
            s_lastProfitUpdate = block.timestamp;
        } else {
            s_profitUnlockingRate = 0;
        }
        s_strategies[strategy].lastReport = block.timestamp;

        emit StrategyReported(
            strategy,
            gain,
            loss,
            s_strategies[strategy].currentDebt,
            _convertToAssets(protocolFeeShares, Rounding.ROUND_DOWN),
            _convertToAssets(protocolFeeShares + accountantFeeShares, Rounding.ROUND_DOWN),
            totalRefunds
        );

        return (gain, loss);
    }

    function setAccountant(address newAccountant) external {
        _enforceRole(msg.sender, Roles.ACCOUNTANT_MANAGER);
        s_accountant = newAccountant;
    }

    function setDefaultQueue(address[MAX_QUEUE] memory newDefaultQueue) external {
        _enforceRole(msg.sender, Roles.QUEUE_MANAGER);
        s_defaultQueue = newDefaultQueue;

        for (uint256 i = 0; i < newDefaultQueue.length; i++) {
            if (s_strategies[newDefaultQueue[i]].activation == 0) {
                revert Vault__StrategyNotActive();
            }
        }
        s_defaultQueue = newDefaultQueue;

        emit UpdateDefaultQueue(newDefaultQueue);
    }

    function setUseDefaultQueue(bool useDefaultQueue) external {
        _enforceRole(msg.sender, Roles.QUEUE_MANAGER);
        s_useDefaultQueue = useDefaultQueue;

        emit UpdateUseDefaultQueue(useDefaultQueue);
    }

    function setDepositLimit(uint256 depositLimit) external {
        if (s_isShutdown) {
            revert Vault__IsShutdown();
        }
        _enforceRole(msg.sender, Roles.DEPOSIT_LIMIT_MANAGER);
        if (s_depositLimitModule != address(0)) {
            revert Vault__UsingDepositModule();
        }

        s_depositLimit = depositLimit;

        emit UpdateDepositLimit(depositLimit);
    }

    function setDepositLimitModule(address depositLimitModule) external {
        if (s_isShutdown) {
            revert Vault__IsShutdown();
        }
        _enforceRole(msg.sender, Roles.DEPOSIT_LIMIT_MANAGER);
        // Check this
        if (s_depositLimit == type(uint256).max) {
            revert Vault__UsingDepositLimit();
        }

        emit UpdateDepositLimitModule(depositLimitModule);
    }

    function setWithdrawLimitModule(address withdrawLimitModule) external {
        if (s_isShutdown) {
            revert Vault__IsShutdown();
        }
        _enforceRole(msg.sender, Roles.WITHDRAW_LIMIT_MANAGER);
        s_withdrawLimitModule = withdrawLimitModule;

        emit UpdateWithdrawLimitModule(withdrawLimitModule);
    }

    function setMinimumTotalIdle(uint256 minimumTotalIdle) external {
        // if (s_isShutdown) {
        //     revert Vault__IsShutdown();
        // }
        _enforceRole(msg.sender, Roles.MINIMUM_IDLE_MANAGER);
        s_minimumTotalIdle = minimumTotalIdle;

        emit UpdateMinimumTotalIdle(minimumTotalIdle);
    }

    function setProfitMaxUnlockTime(uint256 profitMaxUnlockTime) external {
        // if (s_isShutdown) {
        //     revert Vault__IsShutdown();
        // }
        _enforceRole(msg.sender, Roles.PROFIT_UNLOCK_MANAGER);
        if (profitMaxUnlockTime > 31556952) {
            revert Vault__ProfitUnlockTimeTooLong();
        }

        if (profitMaxUnlockTime == 0) {
            _burnShares(s_balanceOf[address(this)], address(this));
            s_profitUnlockingRate = 0;
            s_fullProfitUnlockDate = 0;
        }

        s_profitMaxUnlockTime = profitMaxUnlockTime;

        emit UpdateProfitMaxUnlockTime(profitMaxUnlockTime);
    }

    function _enforceRole(address account, Roles role) internal {
        if (s_roles[account] != role || s_openRoles[role] == false) {
            revert Vault__NotAllowed();
        }
    }

    function setRole(address account, Roles role) external {
        if (msg.sender != s_roleManager) {
            revert Vault__NotRoleManager();
        }
        s_roles[account] = role;
    }

    function addRole(address account, Roles role) external {
        if (msg.sender != s_roleManager) {
            revert Vault__NotRoleManager();
        }
        // Check this
        s_roles[account] = Roles(uint256(s_roles[account]) | uint256(role));

        emit RoleSet(account, s_roles[account]);
    }

    function removeRole(address account, Roles role) external {
        if (msg.sender != s_roleManager) {
            revert Vault__NotRoleManager();
        }
        // Check this
        s_roles[account] = Roles(uint256(s_roles[account]) & ~uint256(role));

        emit RoleSet(account, s_roles[account]);
    }

    function setOpenRole(Roles role) external {
        if (msg.sender != s_roleManager) {
            revert Vault__NotRoleManager();
        }
        s_openRoles[role] = true;

        emit RolesStatusChanged(role, RoleStatusChange.OPENED);
    }

    function transferRoleManager(address roleManager) external {
        if (msg.sender != s_roleManager) {
            revert Vault__NotRoleManager();
        }
        s_furureRoleManager = roleManager;
    }

    function acceptRoleManager() external {
        if (msg.sender != s_furureRoleManager) {
            revert Vault__NotRoleManager();
        }
        s_roleManager = s_furureRoleManager;
        s_furureRoleManager = address(0);

        emit UpdateRoleManager(s_roleManager);
    }

    function isShutdown() external view returns (bool) {
        return s_isShutdown;
    }

    function unlockedShares() external view returns (uint256) {
        return _unlockedShares();
    }

    function pricePerShare() external view returns (uint256) {
        return _convertToAssets(10 ** DECIMALS, Rounding.ROUND_DOWN);
    }

    // Check this
    function getDefaultQueue() external view returns (address[] memory) {
        return s_defaultQueue;
    }

    function processReport(address strategy) external returns (uint256, uint256) {
        _enforceRole(msg.sender, Roles.REPORTING_MANAGER);
        return _processReport(strategy);
    }

    function buyDebt(address strategy, uint256 amount) external nonReentrant {
        _enforceRole(msg.sender, Roles.DEBT_PURCHASER);
        if (s_strategies[strategy].activation == 0) {
            revert Vault__StrategyNotActive();
        }

        uint256 currentDebt = s_strategies[strategy].currentDebt;
        uint256 _amount = amount;

        if (currentDebt <= 0) {
            revert Vault__NothingToBuy();
        }
        if (_amount <= 0) {
            revert Vault__NothingToBuyWith();
        }

        if (_amount > currentDebt) {
            _amount = currentDebt;
        }

        uint256 shares = IStrategy(strategy).balanceOf(address(this)) * _amount / currentDebt;

        if (shares <= 0) {
            revert Vault__CannotBuyZero();
        }

        _erc20SafeTransferFrom(address(ASSET), msg.sender, address(this), _amount);

        s_strategies[strategy].currentDebt -= _amount;
        s_totalDebt -= _amount;
        s_totalIdle += _amount;

        emit DebtUpdated(strategy, currentDebt, currentDebt - _amount);

        _erc20SafeTransfer(strategy, msg.sender, shares);

        emit DebtPurchased(strategy, _amount);
    }

    function addStrategy(address newStrategy) external {
        _enforceRole(msg.sender, Roles.ADD_STRATEGY_MANAGER);
        _addStrategy(newStrategy);
    }

    // Check this
    function revokeStrategy(address strategy, bool force) external {
        _enforceRole(msg.sender, Roles.REVOKE_STRATEGY_MANAGER);
        _revokeStrategy(strategy, force);
    }

    function forceRevokeStrategy(address strategy) external {
        _enforceRole(msg.sender, Roles.REVOKE_STRATEGY_MANAGER);
        _revokeStrategy(strategy, true);
    }

    function updateMaxDebtForStrategy(address strategy, uint256 newMaxDebt) external {
        _enforceRole(msg.sender, Roles.MAX_DEBT_MANAGER);
        if (s_strategies[strategy].activation == 0) {
            revert Vault__StrategyNotActive();
        }
        s_strategies[strategy].maxDebt = newMaxDebt;

        emit UpdateMaxDebtForStrategy(msg.sender, strategy, newMaxDebt);
    }

    function updateDebt(address strategy, uint256 targetDebt) external nonReentrant {
        _enforceRole(msg.sender, Roles.DEBT_MANAGER);
        _updateDebt(strategy, targetDebt);
    }

    function shutdownVault() external {
        _enforceRole(msg.sender, Roles.EMERGENCY_MANAGER);
        if (s_isShutdown) {
            revert Vault__IsShutdown();
        }
        s_isShutdown = true;

        if (s_depositLimitModule != address(0)) {
            s_depositLimitModule = address(0);

            emit UpdateDepositLimitModule(address(0));
        }

        s_depositLimit = 0;
        emit UpdateDepositLimit(0);

        s_roles[msg.sender] = Roles(uint256(s_roles[msg.sender]) & ~uint256(Roles.DEBT_MANAGER));
        emit Shutdown();
    }

    function deposit(uint256 assets, address receiver) external nonReentrant returns (uint256) {
        return _deposit(msg.sender, receiver, assets);
    }

    function mint(uint256 shares, address receiver) external nonReentrant returns (uint256) {
        return _mint(msg.sender, receiver, shares);
    }

    function withdraw(uint256 assets, address receiver, address owner, uint256 maxloss, address[] memory strategies)
        external
        nonReentrant
        returns (uint256)
    {
        uint256 shares = _convertToShares(assets, Rounding.ROUND_UP);
        _redeem(msg.sender, receiver, owner, assets, shares, maxloss, strategies);
        return shares;
    }

    // Check this
    function redeem(uint256 shares, address receiver, address owner, uint256 maxLoss, address[] memory strategies)
        external
        nonReentrant
        returns (uint256)
    {
        uint256 assets = _convertToAssets(shares, Rounding.ROUND_DOWN);
        return _redeem(msg.sender, receiver, owner, assets, shares, maxLoss, strategies);
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        _approve(msg.sender, spender, amount);
        return _approve(msg.sender, spender, amount);
    }

    function transfer(address receiver, uint256 amount) external returns (bool) {
        _transfer(msg.sender, receiver, amount);
        return true;
    }

    function transferFrom(address sender, address receiver, uint256 amount) external returns (bool) {
        if (receiver == address(0) || receiver == address(this)) {
            revert Vault__ZeroAddress();
        }
        return _transferFrom(sender, receiver, amount);
    }

    function increaseAllowance(address spender, uint256 amount) external returns (bool) {
        return _increaseAllowance(msg.sender, spender, amount);
    }

    function decreaseAllowance(address spender, uint256 amount) external returns (bool) {
        return _decreaseAllowance(msg.sender, spender, amount);
    }

    function permit(address owner, address spender, uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external
        returns (bool)
    {
        _permit(owner, spender, amount, deadline, v, r, s);
    }

    // Check this
    function balanceOf(address addr) external view returns (uint256) {
        if (addr == address(this)) {
            return s_balanceOf[addr] - _unlockedShares();
        }
        s_balanceOf[addr];
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply();
    }

    function asset() external view returns (address) {
        return address(ASSET);
    }

    function decimals() external view returns (uint8) {
        return uint8(DECIMALS);
    }

    function totalAssets() external view returns (uint256) {
        return _totalAssets();
    }

    function totalIdle() external view returns (uint256) {
        return s_totalIdle;
    }

    function totalDebt() external view returns (uint256) {
        return s_totalDebt;
    }

    function convertToShares(uint256 assets) external view returns (uint256) {
        return _convertToShares(assets, Rounding.ROUND_DOWN);
    }

    function previewDeposit(uint256 assets) external view returns (uint256) {
        return _convertToShares(assets, Rounding.ROUND_DOWN);
    }

    function previewMint(uint256 shares) external view returns (uint256) {
        return _convertToAssets(shares, Rounding.ROUND_UP);
    }

    function convertToAssets(uint256 shares) external view returns (uint256) {
        return _convertToAssets(shares, Rounding.ROUND_DOWN);
    }

    function maxDeposit(address receiver) external view returns (uint256) {
        return _maxDeposit(receiver);
    }

    function maxMint(address receiver) external view returns (uint256) {
        uint256 maxDeposit = _maxDeposit(receiver);
        return _convertToShares(maxDeposit, Rounding.ROUND_DOWN);
    }

    function maxWithdraw(address owner, uint256 maxLoss, address[] memory strategies) external view returns (uint256) {
        return _maxWithdraw(owner, maxLoss, strategies);
    }

    function maxRedeem(address owner, uint256 maxLoss, address[] memory strategies) external view returns (uint256) {
        return
            Math.min(_convertToShares(_maxWithdraw(owner, maxLoss, strategies), Rounding.ROUND_UP), s_balanceOf[owner]);
    }

    function previewWithdraw(uint256 assets) external view returns (uint256) {
        return _convertToShares(assets, Rounding.ROUND_UP);
    }

    function previewRedeem(uint256 shares) external view returns (uint256) {
        return _convertToAssets(shares, Rounding.ROUND_DOWN);
    }

    function apiVersion() external pure returns (string memory) {
        return API_VERSION;
    }

    function assetsShareOfUnrealizedLosses(address strategy, uint256 assetsNeeded) external view returns (uint256) {
        if (s_strategies[strategy].currentDebt < assetsNeeded) {
            revert Vault__NotEnough();
        }
        return _assessSharesOfUnrealizedLosses(strategy, assetsNeeded);
    }

    function profitMaxUnlockTime() external view returns (uint256) {
        return s_profitMaxUnlockTime;
    }

    function fullProfitUnlockDate() external view returns (uint256) {
        return s_fullProfitUnlockDate;
    }

    function profitUnlockingRate() external view returns (uint256) {
        return s_profitUnlockingRate;
    }

    function lastProfitUodate() external view returns (uint256) {
        return s_lastProfitUpdate;
    }

    function domainSeparator() internal view returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                DOMAIN_TYPE_HASH,
                keccak256(bytes("BG Vault")),
                keccak256(bytes(API_VERSION)),
                bytes32(block.chainid),
                bytes32(bytes20(address(this)))
            )
        );
    }

    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return domainSeparator();
    }
}
