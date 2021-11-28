pragma solidity ^0.6.6;

import "./src/Interfaces/FlashLoanReceiverBase.sol";
import "./src/Interfaces/ILendingPoolAddressesProvider.sol";
import "./src/Interfaces/ILendingPool.sol";
import "./src/Interfaces/IUniSwap.sol";

contract Flashloan is FlashLoanReceiverBase {

    constructor(address _addressProvider) FlashLoanReceiverBase(_addressProvider) public {}

    /**
        This function is called after your contract has received the flash loaned amount
     */
    function executeOperation(
        address _reserve,
        uint256 _amount,
        uint256 _fee,
        bytes calldata _params
    )
        external
        override
    {
        require(_amount <= getBalanceInternal(address(this), _reserve), "Invalid balance, was the flashLoan successful?");

        //
        // Your logic goes here.
        // !! Ensure that *this contract* has enough of `_reserve` funds to payback the `_fee` !!
        //

        uint totalDebt = _amount.add(_fee);
        transferFundsBackToPoolInternal(_reserve, totalDebt);
    }

    /**
        Flash loan 1000000000000000000 wei (1 ether) worth of `_asset`
     */
    function flashloan(address _asset) public onlyOwner {
        bytes memory data = "";
        uint amount = 1 ether;

        ILendingPool lendingPool = ILendingPool(addressesProvider.getLendingPool());
        lendingPool.flashLoan(address(this), _asset, amount, data);
    }

    // Uniswap V2 router
  // 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
  // 0xff795577d9ac8bd7d90ee22b6c1703490b6512fd - Dai
  address private constant WETH = 0xd0A1E359811322d97991E03f863a0C30C2cF029C ;
  // Uniswap V2 factory
  address private constant FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;

  event Log(string message, uint val);

  function testFlashSwap(address _tokenBorrow, uint _amount) external {
    address pair = IUniswapV2Factory(FACTORY).getPair(_tokenBorrow, WETH);
    require(pair != address(0), "!pair");

    address token0 = IUniswapV2Pair(pair).token0();
    address token1 = IUniswapV2Pair(pair).token1();
    uint amount0Out = _tokenBorrow == token0 ? _amount : 0;
    uint amount1Out = _tokenBorrow == token1 ? _amount : 0;

    // need to pass some data to trigger uniswapV2Call
    bytes memory data = abi.encode(_tokenBorrow, _amount);

    IUniswapV2Pair(pair).swap(amount0Out, amount1Out, address(this), data);
  }

  // called by pair contract
  function uniswapV2Call(
    address _sender,
    uint _amount0,
    uint _amount1,
    bytes calldata _data
  ) external {
    address token0 = IUniswapV2Pair(msg.sender).token0();
    address token1 = IUniswapV2Pair(msg.sender).token1();
    address pair = IUniswapV2Factory(FACTORY).getPair(token0, token1);
    require(msg.sender == pair, "!pair");
    require(_sender == address(this), "!sender");

    (address tokenBorrow, uint amount) = abi.decode(_data, (address, uint));

    // about 0.3%
    uint fee = ((amount * 3) / 997) + 1;
    uint amountToRepay = amount + fee;

    // do stuff here
    emit Log("amount", amount);
    emit Log("amount0", _amount0);
    emit Log("amount1", _amount1);
    emit Log("fee", fee);
    emit Log("amount to repay", amountToRepay);

    IERC20(tokenBorrow).transfer(pair, amountToRepay);
  }
}
