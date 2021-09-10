// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.7.3;
 
import "./IERC721.sol";

interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    // for lp
   
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
    function kLast() external view returns (uint);    
}


interface IPool {
  function getPoolTotalDeposited(uint256 _poolId) external view returns (uint256);
}

contract PriceOracle {
    
    address owner;
 
  
    //ok main
    address constant USDT =  0x382bB369d343125BfB2117af9c149795C6C65C50 ;   
    address constant WOKT =  0x8F8526dbfd6E38E3D8307702cA8469Bae6C56C15 ;   
    address constant OKFly = 0x02F093513b7872CdFC518e51eD67f88F0e469592 ; //精度 9  
 
    address constant USDT_WOKT = 0xF3098211d012fF5380A03D80f150Ac6E5753caA8;
    address constant OKFly_WOKT = 0x64Bc364416FE0F86f832cFBf68052ccbD4E1d17a;
   
   
    constructor() public {
        owner = msg.sender;
    } 
 
    // function usdt_balance( address _lptoken) public view returns (uint256){
    //     uint token_balance;
    //     uint256 usd_balance;

    //     IERC20 pair = IERC20(_lptoken);
    //     if (pair.token0() == USDT) 
    //         (usd_balance, token_balance, ) = pair.getReserves();     
    //     else
    //         (token_balance, usd_balance , ) = pair.getReserves();           

    //     return usd_balance;
    // }  

    // function wfc_balance( address _lptoken) public view returns (uint256){
    //     uint token_balance;
    //     uint256 wfc_balance;

    //     IERC20 pair = IERC20(_lptoken);
    //     if (pair.token0() == WFC) 
    //         (wfc_balance, token_balance, ) = pair.getReserves();     
    //     else
    //         (token_balance, wfc_balance , ) = pair.getReserves();           
            
    //     return wfc_balance;
    // } 

    // X-USDT OR USDT-X  , return x price
    function amm_price_as_usd( address _lptoken) public view returns (uint256){
        uint token_balance;
        uint256 usd_balance;

        IERC20 pair = IERC20(_lptoken);
        if (pair.token0() == USDT) 
            (usd_balance, token_balance, ) = pair.getReserves();     
        else
            (token_balance, usd_balance , ) = pair.getReserves();           

        uint256 price = usd_balance * 1e18 / token_balance;
        return price;
    }    
   
     function oktUsdtPrice() public view returns (uint256){
        return amm_price_as_usd(USDT_WOKT);
    }    

     //返回值 包含18位小数
     //比如现在返回值为 5366985310 , 表示 1 OKfly == 0.00000000536698531 $
     function okflyUsdtPrice( ) public view returns (uint256){
        uint token_balance;
        uint256 okt_balance;

        IERC20 pair = IERC20(OKFly_WOKT);
        if (pair.token0() == WOKT) 
            (okt_balance, token_balance, ) = pair.getReserves();     
        else
            (token_balance, okt_balance , ) = pair.getReserves();           

        uint256 price = okt_balance * oktUsdtPrice() / token_balance / 1e9;
        return price;  
    }    
   
    //返回值 包含18位小数
     function okflyOktPrice( ) public view returns (uint256){
        uint token_balance;
        uint256 okt_balance;

        IERC20 pair = IERC20(OKFly_WOKT);
        if (pair.token0() == WOKT) 
            (okt_balance, token_balance, ) = pair.getReserves();     
        else
            (token_balance, okt_balance , ) = pair.getReserves();           

        uint256 price = okt_balance *1e9 / token_balance ;
        return price;  
    }  

    //返回实时usdt 对okfly 数量
    //比如传入 1000000000000000000 , 返回 188950857541742552 , okfly 是9位小数
    function usdtToOkfly(uint256 _usdtAmount)  public view returns (uint256 okflyAmount) {
        return _usdtAmount * 1e9 / okflyUsdtPrice() ;
    }
    function _calcTokenValue(IERC721 nft, uint256 _tokenId) internal view returns (uint256)  {
        uint256 level;
        uint256 skin;

        (,,,level,,,,,skin,,) = nft.getNFTInfoByID(_tokenId);
        return level * 1e18 ; //test
    }

 
    //  _pool_address : StakingNFT 或 StakingDAO 的合约地址
    // _reward_pre_day : _reward_pre_day  每天奖励多少 okfly 代币
    function nft_pool_apy(address _pool_address, uint256 _reward_pre_day ) public  view returns (uint256){
        uint256 staking_value = IPool(_pool_address).getPoolTotalDeposited(0) * okflyUsdtPrice();          
        return _reward_pre_day * 1e18  *  okflyUsdtPrice() * 365 * 100 / staking_value;  
    } 

    // function nft_pool_apy_ex(address _nft_address, address _pool_address, uint256 _reward_pre_day ) public  view returns (uint256){
    //     uint256 staking_value = IERC721(_nft_address).balanceOf(_pool_address) * okflyUsdtPrice();          
    //     return _reward_pre_day * 1e18  *  okflyUsdtPrice() * 365 * 100 / staking_value;  
    // }     
}