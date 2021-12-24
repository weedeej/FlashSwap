/**
 *Submitted for verification at Etherscan.io on 2020-10-30
*/

/**
 *Submitted for verification at Etherscan.io on 2020-07-02
*/

// File: contracts/sol6/IERC20.sol

import "../../node_modules/@openzeppelin/contracts/math/SafeMath.sol";
import "../../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../node_modules/@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../../node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol";
// File: contracts/sol6/utils/PermissionGroupsNoModifiers.sol

pragma solidity ^0.6.6;


contract PermissionGroupsNoModifiers {
    address public admin;
    address public pendingAdmin;
    mapping(address => bool) internal operators;
    mapping(address => bool) internal alerters;
    address[] internal operatorsGroup;
    address[] internal alertersGroup;
    uint256 internal constant MAX_GROUP_SIZE = 50;

    event AdminClaimed(address newAdmin, address previousAdmin);
    event AlerterAdded(address newAlerter, bool isAdd);
    event OperatorAdded(address newOperator, bool isAdd);
    event TransferAdminPending(address pendingAdmin);

    constructor(address _admin) public {
        require(_admin != address(0), "admin 0");
        admin = _admin;
    }

    function getOperators() external view returns (address[] memory) {
        return operatorsGroup;
    }

    function getAlerters() external view returns (address[] memory) {
        return alertersGroup;
    }

    function addAlerter(address newAlerter) public {
        onlyAdmin();
        require(!alerters[newAlerter], "alerter exists"); // prevent duplicates.
        require(alertersGroup.length < MAX_GROUP_SIZE, "max alerters");

        emit AlerterAdded(newAlerter, true);
        alerters[newAlerter] = true;
        alertersGroup.push(newAlerter);
    }

    function addOperator(address newOperator) public {
        onlyAdmin();
        require(!operators[newOperator], "operator exists"); // prevent duplicates.
        require(operatorsGroup.length < MAX_GROUP_SIZE, "max operators");

        emit OperatorAdded(newOperator, true);
        operators[newOperator] = true;
        operatorsGroup.push(newOperator);
    }

    /// @dev Allows the pendingAdmin address to finalize the change admin process.
    function claimAdmin() public {
        require(pendingAdmin == msg.sender, "not pending");
        emit AdminClaimed(pendingAdmin, admin);
        admin = pendingAdmin;
        pendingAdmin = address(0);
    }

    function removeAlerter(address alerter) public {
        onlyAdmin();
        require(alerters[alerter], "not alerter");
        delete alerters[alerter];

        for (uint256 i = 0; i < alertersGroup.length; ++i) {
            if (alertersGroup[i] == alerter) {
                alertersGroup[i] = alertersGroup[alertersGroup.length - 1];
                alertersGroup.pop();
                emit AlerterAdded(alerter, false);
                break;
            }
        }
    }

    function removeOperator(address operator) public {
        onlyAdmin();
        require(operators[operator], "not operator");
        delete operators[operator];

        for (uint256 i = 0; i < operatorsGroup.length; ++i) {
            if (operatorsGroup[i] == operator) {
                operatorsGroup[i] = operatorsGroup[operatorsGroup.length - 1];
                operatorsGroup.pop();
                emit OperatorAdded(operator, false);
                break;
            }
        }
    }

    /// @dev Allows the current admin to set the pendingAdmin address
    /// @param newAdmin The address to transfer ownership to
    function transferAdmin(address newAdmin) public {
        onlyAdmin();
        require(newAdmin != address(0), "new admin 0");
        emit TransferAdminPending(newAdmin);
        pendingAdmin = newAdmin;
    }

    /// @dev Allows the current admin to set the admin in one tx. Useful initial deployment.
    /// @param newAdmin The address to transfer ownership to.
    function transferAdminQuickly(address newAdmin) public {
        onlyAdmin();
        require(newAdmin != address(0), "admin 0");
        emit TransferAdminPending(newAdmin);
        emit AdminClaimed(newAdmin, admin);
        admin = newAdmin;
    }

    function onlyAdmin() internal view {
        require(msg.sender == admin, "only admin");
    }

    function onlyAlerter() internal view {
        require(alerters[msg.sender], "only alerter");
    }

    function onlyOperator() internal view {
        require(operators[msg.sender], "only operator");
    }
}

// File: contracts/sol6/utils/WithdrawableNoModifiers.sol

pragma solidity ^0.6.6;




contract WithdrawableNoModifiers is PermissionGroupsNoModifiers {
    constructor(address _admin) public PermissionGroupsNoModifiers(_admin) {}

    event EtherWithdraw(uint256 amount, address sendTo);
    event TokenWithdraw(IERC20 token, uint256 amount, address sendTo);

    /// @dev Withdraw Ethers
    function withdrawEther(uint256 amount, address payable sendTo) external {
        onlyAdmin();
        (bool success, ) = sendTo.call{value: amount}("");
        require(success);
        emit EtherWithdraw(amount, sendTo);
    }

    /// @dev Withdraw all IERC20 compatible tokens
    /// @param token IERC20 The address of the token contract
    function withdrawToken(
        IERC20 token,
        uint256 amount,
        address sendTo
    ) external {
        onlyAdmin();
        token.transfer(sendTo, amount);
        emit TokenWithdraw(token, amount, sendTo);
    }
}

// File: contracts/sol6/utils/Utils5.sol

pragma solidity ^0.6.6;



/**
 * @title Kyber utility file
 * mostly shared constants and rate calculation helpers
 * inherited by most of kyber contracts.
 * previous utils implementations are for previous solidity versions.
 */
contract Utils5 {
    IERC20 internal constant ETH_TOKEN_ADDRESS = IERC20(
        0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE
    );
    uint256 internal constant PRECISION = (10**18);
    uint256 internal constant MAX_QTY = (10**28); // 10B tokens
    uint256 internal constant MAX_RATE = (PRECISION * 10**7); // up to 10M tokens per eth
    uint256 internal constant MAX_DECIMALS = 18;
    uint256 internal constant ETH_DECIMALS = 18;
    uint256 constant BPS = 10000; // Basic Price Steps. 1 step = 0.01%
    uint256 internal constant MAX_ALLOWANCE = uint256(-1); // token.approve inifinite

    mapping(IERC20 => uint256) internal decimals;

    function getUpdateDecimals(IERC20 token) internal returns (uint256) {
        if (token == ETH_TOKEN_ADDRESS) return ETH_DECIMALS; // save storage access
        uint256 tokenDecimals = decimals[token];
        // moreover, very possible that old tokens have decimals 0
        // these tokens will just have higher gas fees.
        if (tokenDecimals == 0) {
            tokenDecimals = token.decimals();
            decimals[token] = tokenDecimals;
        }

        return tokenDecimals;
    }

    function setDecimals(IERC20 token) internal {
        if (decimals[token] != 0) return; //already set

        if (token == ETH_TOKEN_ADDRESS) {
            decimals[token] = ETH_DECIMALS;
        } else {
            decimals[token] = token.decimals();
        }
    }

    /// @dev get the balance of a user.
    /// @param token The token type
    /// @return The balance
    function getBalance(IERC20 token, address user) internal view returns (uint256) {
        if (token == ETH_TOKEN_ADDRESS) {
            return user.balance;
        } else {
            return token.balanceOf(user);
        }
    }

    function getDecimals(IERC20 token) internal view returns (uint256) {
        if (token == ETH_TOKEN_ADDRESS) return ETH_DECIMALS; // save storage access
        uint256 tokenDecimals = decimals[token];
        // moreover, very possible that old tokens have decimals 0
        // these tokens will just have higher gas fees.
        if (tokenDecimals == 0) return token.decimals();

        return tokenDecimals;
    }

    function calcDestAmount(
        IERC20 src,
        IERC20 dest,
        uint256 srcAmount,
        uint256 rate
    ) internal view returns (uint256) {
        return calcDstQty(srcAmount, getDecimals(src), getDecimals(dest), rate);
    }

    function calcSrcAmount(
        IERC20 src,
        IERC20 dest,
        uint256 destAmount,
        uint256 rate
    ) internal view returns (uint256) {
        return calcSrcQty(destAmount, getDecimals(src), getDecimals(dest), rate);
    }

    function calcDstQty(
        uint256 srcQty,
        uint256 srcDecimals,
        uint256 dstDecimals,
        uint256 rate
    ) internal pure returns (uint256) {
        require(srcQty <= MAX_QTY, "srcQty > MAX_QTY");
        require(rate <= MAX_RATE, "rate > MAX_RATE");

        if (dstDecimals >= srcDecimals) {
            require((dstDecimals - srcDecimals) <= MAX_DECIMALS, "dst - src > MAX_DECIMALS");
            return (srcQty * rate * (10**(dstDecimals - srcDecimals))) / PRECISION;
        } else {
            require((srcDecimals - dstDecimals) <= MAX_DECIMALS, "src - dst > MAX_DECIMALS");
            return (srcQty * rate) / (PRECISION * (10**(srcDecimals - dstDecimals)));
        }
    }

    function calcSrcQty(
        uint256 dstQty,
        uint256 srcDecimals,
        uint256 dstDecimals,
        uint256 rate
    ) internal pure returns (uint256) {
        require(dstQty <= MAX_QTY, "dstQty > MAX_QTY");
        require(rate <= MAX_RATE, "rate > MAX_RATE");

        //source quantity is rounded up. to avoid dest quantity being too low.
        uint256 numerator;
        uint256 denominator;
        if (srcDecimals >= dstDecimals) {
            require((srcDecimals - dstDecimals) <= MAX_DECIMALS, "src - dst > MAX_DECIMALS");
            numerator = (PRECISION * dstQty * (10**(srcDecimals - dstDecimals)));
            denominator = rate;
        } else {
            require((dstDecimals - srcDecimals) <= MAX_DECIMALS, "dst - src > MAX_DECIMALS");
            numerator = (PRECISION * dstQty);
            denominator = (rate * (10**(dstDecimals - srcDecimals)));
        }
        return (numerator + denominator - 1) / denominator; //avoid rounding down errors
    }

    function calcRateFromQty(
        uint256 srcAmount,
        uint256 destAmount,
        uint256 srcDecimals,
        uint256 dstDecimals
    ) internal pure returns (uint256) {
        require(srcAmount <= MAX_QTY, "srcAmount > MAX_QTY");
        require(destAmount <= MAX_QTY, "destAmount > MAX_QTY");

        if (dstDecimals >= srcDecimals) {
            require((dstDecimals - srcDecimals) <= MAX_DECIMALS, "dst - src > MAX_DECIMALS");
            return ((destAmount * PRECISION) / ((10**(dstDecimals - srcDecimals)) * srcAmount));
        } else {
            require((srcDecimals - dstDecimals) <= MAX_DECIMALS, "src - dst > MAX_DECIMALS");
            return ((destAmount * PRECISION * (10**(srcDecimals - dstDecimals))) / srcAmount);
        }
    }

    function minOf(uint256 x, uint256 y) internal pure returns (uint256) {
        return x > y ? y : x;
    }
}

// File: contracts/sol6/IKyberNetwork.sol

pragma solidity ^0.6.6;



interface IKyberNetwork {
    event KyberTrade(
        IERC20 indexed src,
        IERC20 indexed dest,
        uint256 ethWeiValue,
        uint256 networkFeeWei,
        uint256 customPlatformFeeWei,
        bytes32[] t2eIds,
        bytes32[] e2tIds,
        uint256[] t2eSrcAmounts,
        uint256[] e2tSrcAmounts,
        uint256[] t2eRates,
        uint256[] e2tRates
    );

    function tradeWithHintAndFee(
        address payable trader,
        IERC20 src,
        uint256 srcAmount,
        IERC20 dest,
        address payable destAddress,
        uint256 maxDestAmount,
        uint256 minConversionRate,
        address payable platformWallet,
        uint256 platformFeeBps,
        bytes calldata hint
    ) external payable returns (uint256 destAmount);

    function listTokenForReserve(
        address reserve,
        IERC20 token,
        bool add
    ) external;

    function enabled() external view returns (bool);

    function getExpectedRateWithHintAndFee(
        IERC20 src,
        IERC20 dest,
        uint256 srcQty,
        uint256 platformFeeBps,
        bytes calldata hint
    )
        external
        view
        returns (
            uint256 expectedRateAfterNetworkFee,
            uint256 expectedRateAfterAllFees
        );

    function getNetworkData()
        external
        view
        returns (
            uint256 negligibleDiffBps,
            uint256 networkFeeBps,
            uint256 expiryTimestamp
        );

    function maxGasPrice() external view returns (uint256);
}

// File: contracts/sol6/IKyberNetworkProxy.sol

pragma solidity ^0.6.6;



interface IKyberNetworkProxy {

    event ExecuteTrade(
        address indexed trader,
        IERC20 src,
        IERC20 dest,
        address destAddress,
        uint256 actualSrcAmount,
        uint256 actualDestAmount,
        address platformWallet,
        uint256 platformFeeBps
    );

    /// @notice backward compatible
    function tradeWithHint(
        ERC20 src,
        uint256 srcAmount,
        ERC20 dest,
        address payable destAddress,
        uint256 maxDestAmount,
        uint256 minConversionRate,
        address payable walletId,
        bytes calldata hint
    ) external payable returns (uint256);

    function tradeWithHintAndFee(
        IERC20 src,
        uint256 srcAmount,
        IERC20 dest,
        address payable destAddress,
        uint256 maxDestAmount,
        uint256 minConversionRate,
        address payable platformWallet,
        uint256 platformFeeBps,
        bytes calldata hint
    ) external payable returns (uint256 destAmount);

    function trade(
        IERC20 src,
        uint256 srcAmount,
        IERC20 dest,
        address payable destAddress,
        uint256 maxDestAmount,
        uint256 minConversionRate,
        address payable platformWallet
    ) external payable returns (uint256);

    /// @notice backward compatible
    /// @notice Rate units (10 ** 18) => destQty (twei) / srcQty (twei) * 10 ** 18
    function getExpectedRate(
        ERC20 src,
        ERC20 dest,
        uint256 srcQty
    ) external view returns (uint256 expectedRate, uint256 worstRate);

    function getExpectedRateAfterFee(
        IERC20 src,
        IERC20 dest,
        uint256 srcQty,
        uint256 platformFeeBps,
        bytes calldata hint
    ) external view returns (uint256 expectedRate);
}

// File: contracts/sol6/ISimpleKyberProxy.sol

pragma solidity ^0.6.6;



/*
 * @title simple Kyber Network proxy interface
 * add convenient functions to help with kyber proxy API
 */
interface ISimpleKyberProxy {
    function swapTokenToEther(
        IERC20 token,
        uint256 srcAmount,
        uint256 minConversionRate
    ) external returns (uint256 destAmount);

    function swapEtherToToken(IERC20 token, uint256 minConversionRate)
        external
        payable
        returns (uint256 destAmount);

    function swapTokenToToken(
        IERC20 src,
        uint256 srcAmount,
        IERC20 dest,
        uint256 minConversionRate
    ) external returns (uint256 destAmount);
}

// File: contracts/sol6/IKyberReserve.sol

pragma solidity ^0.6.6;



interface IKyberReserve {
    function trade(
        IERC20 srcToken,
        uint256 srcAmount,
        IERC20 destToken,
        address payable destAddress,
        uint256 conversionRate,
        bool validate
    ) external payable returns (bool);

    function getConversionRate(
        IERC20 src,
        IERC20 dest,
        uint256 srcQty,
        uint256 blockNumber
    ) external view returns (uint256);
}

// File: contracts/sol6/IKyberHint.sol

pragma solidity ^0.6.6;



interface IKyberHint {
    enum TradeType {BestOfAll, MaskIn, MaskOut, Split}
    enum HintErrors {
        NoError, // Hint is valid
        NonEmptyDataError, // reserveIDs and splits must be empty for BestOfAll hint
        ReserveIdDupError, // duplicate reserveID found
        ReserveIdEmptyError, // reserveIDs array is empty for MaskIn and Split trade type
        ReserveIdSplitsError, // reserveIDs and splitBpsValues arrays do not have the same length
        ReserveIdSequenceError, // reserveID sequence in array is not in increasing order
        ReserveIdNotFound, // reserveID isn't registered or doesn't exist
        SplitsNotEmptyError, // splitBpsValues is not empty for MaskIn or MaskOut trade type
        TokenListedError, // reserveID not listed for the token
        TotalBPSError // total BPS for Split trade type is not 10000 (100%)
    }

    function buildTokenToEthHint(
        IERC20 tokenSrc,
        TradeType tokenToEthType,
        bytes32[] calldata tokenToEthReserveIds,
        uint256[] calldata tokenToEthSplits
    ) external view returns (bytes memory hint);

    function buildEthToTokenHint(
        IERC20 tokenDest,
        TradeType ethToTokenType,
        bytes32[] calldata ethToTokenReserveIds,
        uint256[] calldata ethToTokenSplits
    ) external view returns (bytes memory hint);

    function buildTokenToTokenHint(
        IERC20 tokenSrc,
        TradeType tokenToEthType,
        bytes32[] calldata tokenToEthReserveIds,
        uint256[] calldata tokenToEthSplits,
        IERC20 tokenDest,
        TradeType ethToTokenType,
        bytes32[] calldata ethToTokenReserveIds,
        uint256[] calldata ethToTokenSplits
    ) external view returns (bytes memory hint);

    function parseTokenToEthHint(IERC20 tokenSrc, bytes calldata hint)
        external
        view
        returns (
            TradeType tokenToEthType,
            bytes32[] memory tokenToEthReserveIds,
            IKyberReserve[] memory tokenToEthAddresses,
            uint256[] memory tokenToEthSplits
        );

    function parseEthToTokenHint(IERC20 tokenDest, bytes calldata hint)
        external
        view
        returns (
            TradeType ethToTokenType,
            bytes32[] memory ethToTokenReserveIds,
            IKyberReserve[] memory ethToTokenAddresses,
            uint256[] memory ethToTokenSplits
        );

    function parseTokenToTokenHint(IERC20 tokenSrc, IERC20 tokenDest, bytes calldata hint)
        external
        view
        returns (
            TradeType tokenToEthType,
            bytes32[] memory tokenToEthReserveIds,
            IKyberReserve[] memory tokenToEthAddresses,
            uint256[] memory tokenToEthSplits,
            TradeType ethToTokenType,
            bytes32[] memory ethToTokenReserveIds,
            IKyberReserve[] memory ethToTokenAddresses,
            uint256[] memory ethToTokenSplits
        );
}

// File: contracts/sol6/KyberNetworkProxy.sol

pragma solidity ^0.6.6;









/**
 *   @title kyberProxy for kyberNetwork contract
 *   The contract provides the following functions:
 *   - Get rates
 *   - Trade execution
 *   - Simple T2E, E2T and T2T trade APIs
 *   - Has some checks in place to safeguard takers
 */
contract KyberNetworkProxy is
    IKyberNetworkProxy,
    ISimpleKyberProxy,
    WithdrawableNoModifiers,
    Utils5
{
    using SafeERC20 for IERC20;

    IKyberNetwork public kyberNetwork;
    IKyberHint public kyberHintHandler; // kyberHintHhandler pointer for users.

    event KyberNetworkSet(IKyberNetwork newKyberNetwork, IKyberNetwork previousKyberNetwork);
    event KyberHintHandlerSet(IKyberHint kyberHintHandler);

    constructor(address payable _admin) public WithdrawableNoModifiers(_admin) {
        /*empty body*/
    }

    /// @notice Backward compatible function
    /// @notice Use token address ETH_TOKEN_ADDRESS for ether
    /// @dev Trade from src to dest token and sends dest token to destAddress
    /// @param src Source token
    /// @param srcAmount Amount of src tokens in twei
    /// @param dest Destination token
    /// @param destAddress Address to send tokens to
    /// @param maxDestAmount A limit on the amount of dest tokens in twei
    /// @param minConversionRate The minimal conversion rate. If actual rate is lower, trade reverts
    /// @param platformWallet Platform wallet address for receiving fees
    /// @return Amount of actual dest tokens in twei
    function trade(
        IERC20 src,
        uint256 srcAmount,
        IERC20 dest,
        address payable destAddress,
        uint256 maxDestAmount,
        uint256 minConversionRate,
        address payable platformWallet
    ) external payable override returns (uint256) {
        bytes memory hint;

        return
            doTrade(
                src,
                srcAmount,
                dest,
                destAddress,
                maxDestAmount,
                minConversionRate,
                platformWallet,
                0,
                hint
            );
    }

    /// @notice Backward compatible function
    /// @notice Use token address ETH_TOKEN_ADDRESS for ether
    /// @dev Trade from src to dest token and sends dest token to destAddress
    /// @param src Source token
    /// @param srcAmount Amount of src tokens in twei
    /// @param dest Destination token
    /// @param destAddress Address to send tokens to
    /// @param maxDestAmount A limit on the amount of dest tokens in twei
    /// @param minConversionRate The minimal conversion rate. If actual rate is lower, trade reverts
    /// @param walletId Platform wallet address for receiving fees
    /// @param hint Advanced instructions for running the trade 
    /// @return Amount of actual dest tokens in twei
    function tradeWithHint(
        ERC20 src,
        uint256 srcAmount,
        ERC20 dest,
        address payable destAddress,
        uint256 maxDestAmount,
        uint256 minConversionRate,
        address payable walletId,
        bytes calldata hint
    ) external payable override returns (uint256) {
        return
            doTrade(
                src,
                srcAmount,
                dest,
                destAddress,
                maxDestAmount,
                minConversionRate,
                walletId,
                0,
                hint
            );
    }

    /// @notice Use token address ETH_TOKEN_ADDRESS for ether
    /// @dev Trade from src to dest token and sends dest token to destAddress
    /// @param src Source token
    /// @param srcAmount Amount of src tokens in twei
    /// @param dest Destination token
    /// @param destAddress Address to send tokens to
    /// @param maxDestAmount A limit on the amount of dest tokens in twei
    /// @param minConversionRate The minimal conversion rate. If actual rate is lower, trade reverts
    /// @param platformWallet Platform wallet address for receiving fees
    /// @param platformFeeBps Part of the trade that is allocated as fee to platform wallet. Ex: 10000 = 100%, 100 = 1%
    /// @param hint Advanced instructions for running the trade 
    /// @return destAmount Amount of actual dest tokens in twei
    function tradeWithHintAndFee(
        IERC20 src,
        uint256 srcAmount,
        IERC20 dest,
        address payable destAddress,
        uint256 maxDestAmount,
        uint256 minConversionRate,
        address payable platformWallet,
        uint256 platformFeeBps,
        bytes calldata hint
    ) external payable override returns (uint256 destAmount) {
        return
            doTrade(
                src,
                srcAmount,
                dest,
                destAddress,
                maxDestAmount,
                minConversionRate,
                platformWallet,
                platformFeeBps,
                hint
            );
    }

    /// @dev Trade from src to dest token. Sends dest tokens to msg sender
    /// @param src Source token
    /// @param srcAmount Amount of src tokens in twei
    /// @param dest Destination token
    /// @param minConversionRate The minimal conversion rate. If actual rate is lower, trade reverts
    /// @return Amount of actual dest tokens in twei
    function swapTokenToToken(
        IERC20 src,
        uint256 srcAmount,
        IERC20 dest,
        uint256 minConversionRate
    ) external override returns (uint256) {
        bytes memory hint;

        return
            doTrade(
                src,
                srcAmount,
                dest,
                msg.sender,
                MAX_QTY,
                minConversionRate,
                address(0),
                0,
                hint
            );
    }

    /// @dev Trade from eth -> token. Sends token to msg sender
    /// @param token Destination token
    /// @param minConversionRate The minimal conversion rate. If actual rate is lower, trade reverts
    /// @return Amount of actual dest tokens in twei
    function swapEtherToToken(IERC20 token, uint256 minConversionRate)
        external
        payable
        override
        returns (uint256)
    {
        bytes memory hint;

        return
            doTrade(
                ETH_TOKEN_ADDRESS,
                msg.value,
                token,
                msg.sender,
                MAX_QTY,
                minConversionRate,
                address(0),
                0,
                hint
            );
    }

    /// @dev Trade from token -> eth. Sends eth to msg sender
    /// @param token Source token
    /// @param srcAmount Amount of src tokens in twei
    /// @param minConversionRate The minimal conversion rate. If actual rate is lower, trade reverts
    /// @return Amount of actual dest tokens in twei
    function swapTokenToEther(
        IERC20 token,
        uint256 srcAmount,
        uint256 minConversionRate
    ) external override returns (uint256) {
        bytes memory hint;

        return
            doTrade(
                token,
                srcAmount,
                ETH_TOKEN_ADDRESS,
                msg.sender,
                MAX_QTY,
                minConversionRate,
                address(0),
                0,
                hint
            );
    }

    function setKyberNetwork(IKyberNetwork _kyberNetwork) external {
        onlyAdmin();
        require(_kyberNetwork != IKyberNetwork(0), "kyberNetwork 0");
        emit KyberNetworkSet(_kyberNetwork, kyberNetwork);

        kyberNetwork = _kyberNetwork;
    }

    function setHintHandler(IKyberHint _kyberHintHandler) external {
        onlyAdmin();
        require(_kyberHintHandler != IKyberHint(0), "kyberHintHandler 0");
        emit KyberHintHandlerSet(_kyberHintHandler);

        kyberHintHandler = _kyberHintHandler;
    }

    /// @notice Backward compatible function
    /// @notice Use token address ETH_TOKEN_ADDRESS for ether
    /// @dev Get expected rate for a trade from src to dest tokens, with amount srcQty (no platform fee)
    /// @param src Source token
    /// @param dest Destination token
    /// @param srcQty Amount of src tokens in twei
    /// @return expectedRate for a trade after deducting network fee. Rate = destQty (twei) / srcQty (twei) * 10 ** 18
    /// @return worstRate for a trade. Usually expectedRate * 97 / 100
    ///             Use worstRate value as trade min conversion rate at your own risk
    function getExpectedRate(
        ERC20 src,
        ERC20 dest,
        uint256 srcQty
    ) external view override returns (uint256 expectedRate, uint256 worstRate) {
        bytes memory hint;
        (expectedRate, ) = kyberNetwork.getExpectedRateWithHintAndFee(
            src,
            dest,
            srcQty,
            0,
            hint
        );
        // use simple backward compatible optoin.
        worstRate = (expectedRate * 97) / 100;
    }

    /// @notice Use token address ETH_TOKEN_ADDRESS for ether
    /// @dev Get expected rate for a trade from src to dest tokens, amount srcQty and fees
    /// @param src Source token
    /// @param dest Destination token
    /// @param srcQty Amount of src tokens in twei
    /// @param platformFeeBps Part of the trade that is allocated as fee to platform wallet. Ex: 10000 = 100%, 100 = 1%
    /// @param hint Advanced instructions for running the trade 
    /// @return expectedRate for a trade after deducting network + platform fee
    ///             Rate = destQty (twei) / srcQty (twei) * 10 ** 18
    function getExpectedRateAfterFee(
        IERC20 src,
        IERC20 dest,
        uint256 srcQty,
        uint256 platformFeeBps,
        bytes calldata hint
    ) external view override returns (uint256 expectedRate) {
        (, expectedRate) = kyberNetwork.getExpectedRateWithHintAndFee(
            src,
            dest,
            srcQty,
            platformFeeBps,
            hint
        );
    }

    function maxGasPrice() external view returns (uint256) {
        return kyberNetwork.maxGasPrice();
    }

    function enabled() external view returns (bool) {
        return kyberNetwork.enabled();
    }

    /// helper structure for function doTrade
    struct UserBalance {
        uint256 srcTok;
        uint256 destTok;
    }

    function doTrade(
        IERC20 src,
        uint256 srcAmount,
        IERC20 dest,
        address payable destAddress,
        uint256 maxDestAmount,
        uint256 minConversionRate,
        address payable platformWallet,
        uint256 platformFeeBps,
        bytes memory hint
    ) internal returns (uint256) {
        UserBalance memory balanceBefore = prepareTrade(src, dest, srcAmount, destAddress);

        uint256 reportedDestAmount = kyberNetwork.tradeWithHintAndFee{value: msg.value}(
            msg.sender,
            src,
            srcAmount,
            dest,
            destAddress,
            maxDestAmount,
            minConversionRate,
            platformWallet,
            platformFeeBps,
            hint
        );
        TradeOutcome memory tradeOutcome = calculateTradeOutcome(
            src,
            dest,
            destAddress,
            platformFeeBps,
            balanceBefore
        );

        require(
            tradeOutcome.userDeltaDestToken == reportedDestAmount,
            "kyberNetwork returned wrong amount"
        );
        require(
            tradeOutcome.userDeltaDestToken <= maxDestAmount,
            "actual dest amount exceeds maxDestAmount"
        );
        require(tradeOutcome.actualRate >= minConversionRate, "rate below minConversionRate");

        emit ExecuteTrade(
            msg.sender,
            src,
            dest,
            destAddress,
            tradeOutcome.userDeltaSrcToken,
            tradeOutcome.userDeltaDestToken,
            platformWallet,
            platformFeeBps
        );

        return tradeOutcome.userDeltaDestToken;
    }

    /// helper structure for function prepareTrade
    struct TradeOutcome {
        uint256 userDeltaSrcToken;
        uint256 userDeltaDestToken;
        uint256 actualRate;
    }

    function prepareTrade(
        IERC20 src,
        IERC20 dest,
        uint256 srcAmount,
        address destAddress
    ) internal returns (UserBalance memory balanceBefore) {
        if (src == ETH_TOKEN_ADDRESS) {
            require(msg.value == srcAmount, "sent eth not equal to srcAmount");
        } else {
            require(msg.value == 0, "sent eth not 0");
        }

        balanceBefore.srcTok = getBalance(src, msg.sender);
        balanceBefore.destTok = getBalance(dest, destAddress);

        if (src == ETH_TOKEN_ADDRESS) {
            balanceBefore.srcTok += msg.value;
        } else {
            //safeTransferFrom
            src.safeTransferFrom(msg.sender, address(kyberNetwork), srcAmount);
        }
    }

    function calculateTradeOutcome(
        IERC20 src,
        IERC20 dest,
        address destAddress,
        uint256 platformFeeBps,
        UserBalance memory balanceBefore
    ) internal returns (TradeOutcome memory outcome) {
        uint256 srcTokenBalanceAfter;
        uint256 destTokenBalanceAfter;

        srcTokenBalanceAfter = getBalance(src, msg.sender);
        destTokenBalanceAfter = getBalance(dest, destAddress);

        //protect from underflow
        require(
            destTokenBalanceAfter > balanceBefore.destTok,
            "wrong amount in destination address"
        );
        require(balanceBefore.srcTok > srcTokenBalanceAfter, "wrong amount in source address");

        outcome.userDeltaSrcToken = balanceBefore.srcTok - srcTokenBalanceAfter;
        outcome.userDeltaDestToken = destTokenBalanceAfter - balanceBefore.destTok;

        // what would be the src amount after deducting platformFee
        // not protecting from platform fee
        uint256 srcTokenAmountAfterDeductingFee = (outcome.userDeltaSrcToken *
            (BPS - platformFeeBps)) / BPS;

        outcome.actualRate = calcRateFromQty(
            srcTokenAmountAfterDeductingFee,
            outcome.userDeltaDestToken,
            getUpdateDecimals(src),
            getUpdateDecimals(dest)
        );
    }
}