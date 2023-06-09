// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

contract Token is ERC20, Ownable,ERC20Burnable {
 
    address public Wallet;
    bool public isSwap;
    address public PancakeSwap;
    uint256 public ReflectionTaxAmount;
    // address public constant WBNB = 0x9c3C9283D3e44854697Cd22D3Faa240Cfb032889;
    // uint24 public constant poolFee = 500; 

    uint24 public poolFee;
    address public WBNB;
    address public constant routerAddress = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    ISwapRouter public immutable swapRouter = ISwapRouter(routerAddress);
     

    struct Cap{
        uint SellTax;
        uint BuyTax;
        uint XAmount;
        uint currentAmount;
    }
    struct ReflectionUserTax{
        bool withdraw;
        bool TAmount;
    }
    // mappings
    mapping(address => bool) public whiteList;
    mapping(address => ReflectionUserTax) public reflectionUserDetail;
    mapping(uint => Cap) public Taxs;

    IERC20 public linkToken;
    IERC20 public WBNBToken;

    constructor() ERC20("Froggies Token", "FRGST") {
        _mint(msg.sender, 100000000000000 * 10 ** decimals());
        WBNBToken = IERC20(WBNB);
        Wallet = address(this);
        linkToken = IERC20(address(this));
    }
    // ============ WhiteList FUNCTIONS ============
    /* 
        @dev WhiteList take address as a parameter and make this address true in the whiteList.  
    */
    function WhiteList(address _address) public {
        whiteList[_address] = true;
    } 
    // ============ swapExactInputSingle FUNCTIONS ============
    /* 
        @dev swapExactInputSingle this function take amount of token that you want to swap.  
    */
    function swapExactInputSingle(uint256 amountIn,address recipientAddresss) public returns (uint256 amountOut)
    {
        linkToken.approve(address(swapRouter), amountIn);
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: address(this),
                tokenOut: WBNB,
                fee: poolFee,
                recipient: recipientAddresss,
                deadline: block.timestamp,
                amountIn: amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });
        amountOut = swapRouter.exactInputSingle(params);
    }

    // ============ transfer FUNCTIONS ============
    /* 
        @dev transfer take two parameter address of receiver and amount that you want to send.  
    */
    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        if(whiteList[msg.sender]){
            return super.transfer(to, amount);        
        }else{
            if(msg.sender == PancakeSwap){
                uint ReflectionAmount = ((amount*Taxs[1].BuyTax)/100);
                uint LPAmount = ((amount*Taxs[2].BuyTax)/100);
                uint InvestmentAmount = ((amount*Taxs[3].BuyTax)/100);
                uint MarkettingAmount = ((amount*Taxs[4].BuyTax)/100);
                ReflectionTaxAmount += ReflectionAmount;
                reflectionUserDetail[msg.sender].TAmount = true;
                if(((Taxs[2].currentAmount + LPAmount) >= Taxs[2].XAmount) && (Taxs[2].XAmount != 0)) {
                    super.transfer(PancakeSwap,(Taxs[2].XAmount/2));
                    swapExactInputSingle((Taxs[2].XAmount/2),PancakeSwap);
                    Taxs[2].currentAmount = (Taxs[2].currentAmount + LPAmount) -  Taxs[2].XAmount;
                }else{
                    Taxs[2].currentAmount += LPAmount;
                }
                if(((Taxs[4].currentAmount + MarkettingAmount) >= Taxs[4].XAmount) && isSwap && (Taxs[4].XAmount != 0))  {
                    swapExactInputSingle(Taxs[4].XAmount,address(this));
                    Taxs[4].currentAmount = (Taxs[4].currentAmount + MarkettingAmount) -  Taxs[4].XAmount;
                }else{
                    Taxs[4].currentAmount += MarkettingAmount;
                }  
                super.transfer(Wallet,ReflectionAmount);
                super.transfer(Wallet,LPAmount);
                super.burn(InvestmentAmount);
                super.transfer(Wallet,MarkettingAmount);
                return super.transfer(to, (amount-(ReflectionAmount+LPAmount+InvestmentAmount+MarkettingAmount)));
            }else if(to == PancakeSwap)
            {
                uint ReflectionAmount = ((amount*Taxs[1].SellTax)/100);
                uint LPAmount = ((amount*Taxs[2].SellTax)/100);
                uint InvestmentAmount = ((amount*Taxs[3].SellTax)/100);
                uint MarkettingAmount = ((amount*Taxs[4].SellTax)/100);
                ReflectionTaxAmount += ReflectionAmount;
                reflectionUserDetail[msg.sender].TAmount = true;
                if(((Taxs[2].currentAmount + LPAmount) >= Taxs[2].XAmount) && (Taxs[2].XAmount != 0)) {
                    super.transfer(PancakeSwap,(Taxs[2].XAmount/2));
                    swapExactInputSingle((Taxs[2].XAmount/2),PancakeSwap);
                    Taxs[2].currentAmount = (Taxs[2].currentAmount + LPAmount) -  Taxs[2].XAmount;
                }else{
                    Taxs[2].currentAmount += LPAmount;
                }
                if(((Taxs[4].currentAmount + MarkettingAmount) >= Taxs[4].XAmount) && isSwap && (Taxs[4].XAmount != 0)) {
                    swapExactInputSingle(Taxs[4].XAmount,address(this));
                    Taxs[4].currentAmount = (Taxs[4].currentAmount + MarkettingAmount) -  Taxs[4].XAmount;
                }else{
                    Taxs[4].currentAmount += MarkettingAmount;
                }  
                super.transfer(Wallet,ReflectionAmount);
                super.transfer(Wallet,LPAmount);
                super.burn(InvestmentAmount);
                super.transfer(Wallet,MarkettingAmount);
                return super.transfer(to,amount-(ReflectionAmount+LPAmount+InvestmentAmount+MarkettingAmount));
            }
            else{
                return super.transfer(to, amount);
            }
        }  
    }

    // ============ WithdrawReflectionTaxPersentage FUNCTIONS ============
    /* 
        @dev WithdrawReflectionTaxPersentage take one parameter(user address) and calculate reflection amount of user and send amount at the user address.  
    */
    function WithdrawReflectionTaxPersentage(address from) public {
        require(reflectionUserDetail[from].TAmount,"First Transfer Tokens");
        require(!reflectionUserDetail[from].withdraw,"You Already Withdraw");  
        uint256 transferAmount = ((balanceOf(from)) * ReflectionTaxAmount) /totalSupply();
        reflectionUserDetail[from].withdraw = true;
        ReflectionTaxAmount -= transferAmount;
        linkToken.transfer(from,transferAmount);
    }

    // ============ setReflectionSellTax FUNCTIONS ============
    /* 
        @dev setReflectionSellTax take Tax percentage as a parameter and set this percentage to ReflectionSellTax variable.  
    */
    function setReflectionSellTax(uint Tax) public onlyOwner{
        require(Taxs[1].BuyTax +Taxs[2].BuyTax+Taxs[3].BuyTax+Taxs[4].BuyTax+Taxs[1].SellTax + Taxs[2].SellTax + Taxs[3].SellTax + Taxs[4].SellTax + Tax <= 15,"Sum of Tax Persentage must be 0 to 15");
        Taxs[1].SellTax = Tax;
    }

    // ============ setLPSellTax FUNCTIONS ============
    /* 
        @dev setLPSellTax take Tax percentage as a parameter and set this percentage to LPSellTax variable.  
    */
    function setLPSellTax(uint Tax) public onlyOwner{
        require(Taxs[1].BuyTax +Taxs[2].BuyTax+Taxs[3].BuyTax+Taxs[4].BuyTax+Taxs[1].SellTax + Taxs[3].SellTax + Taxs[4].SellTax + Tax <= 15,"Sum of Tax Persentage must be 0 to 15");
        Taxs[2].SellTax = Tax;
    }

    // ============ setInvestmentSellTax FUNCTIONS ============
    /* 
        @dev setInvestmentSellTax take Tax percentage as a parameter and set this percentage to InvestmentSellTax variable.  
    */
    function setInvestmentSellTax(uint Tax) public onlyOwner{
        require(Taxs[1].BuyTax +Taxs[2].BuyTax+Taxs[3].BuyTax+Taxs[4].BuyTax+Taxs[1].SellTax + Taxs[2].SellTax + Taxs[4].SellTax + Tax <= 15,"Sum of Tax Persentage must be 0 to 15");
        Taxs[3].SellTax = Tax;
    }

    // ============ setMarkettingSellTax FUNCTIONS ============
    /* 
        @dev setMarkettingSellTax take Tax percentage as a parameter and set this percentage to MarkettingSellTax variable.  
    */
    function setMarkettingSellTax(uint Tax) public onlyOwner{
        require(Taxs[1].BuyTax +Taxs[2].BuyTax+Taxs[3].BuyTax+Taxs[4].BuyTax+Taxs[1].SellTax + Taxs[2].SellTax + Taxs[3].SellTax + Tax <= 15,"Sum of Tax Persentage must be 0 to 15");
        Taxs[4].SellTax = Tax;
    }

    // ============ setReflectionBuyTax FUNCTIONS ============
    /* 
        @dev setReflectionBuyTax take Tax percentage as a parameter and set this percentage to ReflectionBuyTax variable.  
    */
    function setReflectionBuyTax(uint Tax) public onlyOwner{
        require(Taxs[2].BuyTax+Taxs[3].BuyTax+Taxs[4].BuyTax+Taxs[1].SellTax + Taxs[2].SellTax + Taxs[3].SellTax + Taxs[4].SellTax + Tax <= 15,"Sum of Tax Persentage must be 0 to 15");
        Taxs[1].BuyTax = Tax;
    }

    // ============ setLPBuyTax FUNCTIONS ============
    /* 
        @dev setLPBuyTax take Tax percentage as a parameter and set this percentage to LPBuyTax variable.  
    */
    function setLPBuyTax(uint Tax) public onlyOwner{
        require(Taxs[1].BuyTax +Taxs[3].BuyTax+Taxs[4].BuyTax+Taxs[1].SellTax + Taxs[2].SellTax + Taxs[3].SellTax + Taxs[4].SellTax + Tax <= 15,"Sum of Tax Persentage must be 0 to 15");
        Taxs[2].BuyTax = Tax;
    }

    // ============ setInvestmentBuyTax FUNCTIONS ============
    /* 
        @dev setInvestmentBuyTax take Tax percentage as a parameter and set this percentage to InvestmentBuyTax variable.  
    */
    function setInvestmentBuyTax(uint Tax) public onlyOwner{
        require(Taxs[1].BuyTax +Taxs[2].BuyTax+Taxs[4].BuyTax+Taxs[1].SellTax + Taxs[2].SellTax + Taxs[3].SellTax + Taxs[4].SellTax + Tax <= 15,"Sum of Tax Persentage must be 0 to 15");
        Taxs[3].BuyTax = Tax;
    }

    // ============ setMarkettingBuyTax FUNCTIONS ============
    /* 
        @dev setMarkettingBuyTax take Tax percentage as a parameter and set this percentage to MarkettingBuyTax variable.  
    */
    function setMarkettingBuyTax(uint Tax) public onlyOwner{
        require(Taxs[1].BuyTax +Taxs[2].BuyTax+Taxs[3].BuyTax+Taxs[1].SellTax + Taxs[2].SellTax + Taxs[3].SellTax + Taxs[4].SellTax + Tax <= 15,"Sum of Tax Persentage must be 0 to 15");
        Taxs[4].BuyTax = Tax;
    }

    // ============ setLPXAmount FUNCTIONS ============
    /* 
        @dev setLPXAmount take Amount percentage as a parameter and set this percentage to LPXAmount variable.  
    */
    function setLPXAmount(uint Amount) public onlyOwner{
        Taxs[2].XAmount = Amount;
    }

    // ============ setMarkettingXAmount FUNCTIONS ============
    /* 
        @dev setMarkettingXAmount take Amount percentage as a parameter and set this percentage to MarkettingXAmount variable.  
    */
    function setMarkettingXAmount(uint Amount) public onlyOwner{
        Taxs[4].XAmount = Amount;
    }

    // ============ setMarkettingSwap FUNCTIONS ============
    /* 
        @dev setMarkettingSwap take bool parameter to open Swap.  
    */
    function setMarkettingSwap(bool check) public onlyOwner{
        isSwap = check;
    }

    // ============ getBalanceWETh FUNCTIONS ============
    /* 
        @dev getBalanceWETh this function takes address and return the balance of WBNB.  
    */
    function getBalanceWBNB(address contractAddress) view public returns(uint256 Balance){
        return(WBNBToken.balanceOf(contractAddress));
    }

    // ============ WithdrawWETH FUNCTIONS ============
    /* 
        @dev WithdrawWETH this function takes amount and transfer this amount to the connected address 
        but this function is onlyOwner Function(No one can run this function except admin).  
    */
    function WithdrawWBNB(address to,uint amount) public onlyOwner{
        WBNBToken.transfer(to,amount);
    }

    // ============ WithdrawTokens FUNCTIONS ============
    /* 
        @dev WithdrawTokens this function takes amount and transfer this amount to the connected address 
        but this function is onlyOwner Function(No one can run this function except admin).  
    */
    function WithdrawTokens(address to,uint amount) public onlyOwner{
        linkToken.transfer(to,amount);
    }

    // ============ setAddressFee FUNCTIONS ============
    /* 
        @dev setAddress&Fee this function takes address(_PancakeSwapAddress,_WBNBAddress) and Fee amount(_poolFee). 
        @param Given parameter set according to their variables.
    */
    function setAddressFee(address _PancakeSwapAddress,address _WBNBAddress,uint24 _poolFee) public onlyOwner {
        PancakeSwap = _PancakeSwapAddress;
        WBNBToken = IERC20(_WBNBAddress);
        WBNB = _WBNBAddress;
        poolFee = _poolFee;
    }

}
