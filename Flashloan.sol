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
        address _reserve,
        uint256 _amount,
        uint256 _dummyParam,
        bytes calldata _params
    )
        external
        override
    {
        require(_amount <= getBalanceInternal(address(this), _reserve), "Invalid balance, was the flashLoan successful?");
        uint fee = ((_amount * 3) / 997) + 1;
        uint totalDebt = _amount.add(fee);
        //
        // Your logic goes here.
        // !! Ensure that *this contract* has enough of `_reserve` funds to payback the `_fee` !!
        //
        emit Log("loan amount", _amount);
        emit Log("fee", fee);
        emit Log("amount to repay", totalDebt);
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

    function test(address from, address to, uint amt) public returns(uint256 returnVal)
    {
      bytes memory data = "";
      KyberNetwork K = KyberNetwork(0x692f391bCc85cefCe8C237C01e1f636BbD70EA4D);
      return K.tradeWithHint(address(this), ERC20(from), amt, ERC20(to), 0xBd07468fe5C27aFce46a49dFe78f0D0e2416297A, 1 ether, 1, 0xBd07468fe5C27aFce46a49dFe78f0D0e2416297A, data);
    }
  // Uniswap V2 router  
  // 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
  // 0xff795577d9ac8bd7d90ee22b6c1703490b6512fd - Dai
  address private constant WETH = 0xd0A1E359811322d97991E03f863a0C30C2cF029C ;
  // Uniswap V2 factory
  address private constant FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
  event Log(string message, uint val);
}