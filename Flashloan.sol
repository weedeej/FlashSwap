pragma solidity ^0.6.6;

import "./src/Interfaces/FlashLoanReceiverBase.sol";
import "./src/Interfaces/ILendingPoolAddressesProvider.sol";
import "./src/Interfaces/ILendingPool.sol";
import "./src/Interfaces/IUniSwap.sol";
import "./src/Contracts/KyberNetwork.sol";
contract Flashloan is FlashLoanReceiverBase {

    constructor(address _addressProvider) FlashLoanReceiverBase(_addressProvider) public {}

    /**
        This function is called after your contract has received the flash loaned amount
     */
    function executeOperation(
        address _from,
        uint256 _amount,
        address _to,
        bytes calldata _params
    )
        external
        override
    {
        require(_amount <= getBalanceInternal(address(this), _from), "Invalid balance, was the flashLoan successful?");
        uint fee = ((_amount * 3) / 997) + 1;
        uint totalDebt = _amount.add(fee);
        //
        // Your logic goes here.
        // !! Ensure that *this contract* has enough of `_reserve` funds to payback the `_fee` !!
        //
        //emit Log("loan amount", _amount);
        //emit Log("fee", fee);
        //emit Log("amount to repay", totalDebt);
        TestKyber(payable(_from), payable (_to), _amount);
        transferFundsBackToPoolInternal(_from, totalDebt);
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

    function TestKyber(address payable from, address payable to, uint amt) public returns(uint256)
    {
      bytes memory data = "";
      IERC20(from).approve(address(this),amt);
      KyberNetworkProxy K = KyberNetworkProxy(0xc153eeAD19e0DBbDb3462Dcc2B703cC6D738A37c);
      return K.swapTokenToToken(IERC20(from),amt,IERC20(to),1);
    }

    function TestUniswap(address from, address to, uint amt) public returns(uint)
    {
        address[] memory path;
        path[0] = from;
        path[1] = to;
        UniswapV2Router02 V = new UniswapV2Router02(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f, 0xd0A1E359811322d97991E03f863a0C30C2cF029C);
        return V.swapExactTokensForTokens(amt, 1, path, address(this), 0)[0];
    }
  // Uniswap V2 router  
  // 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
  // 0xff795577d9ac8bd7d90ee22b6c1703490b6512fd - Dai
  address private constant WETH = 0xd0A1E359811322d97991E03f863a0C30C2cF029C ;
  // Uniswap V2 factory
  address private constant FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
  //event Log(string message, uint val);
}