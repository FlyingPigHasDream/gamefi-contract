// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.7.3;

pragma experimental ABIEncoderV2;

////import "hardhat/console.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/EnumerableSet.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/ERC721Holder.sol";

import {FixedPointMath} from "./libraries/FixedPointMath.sol";
import {Pool} from "./libraries/pools/Pool.sol";
import {Stake} from "./libraries/pools/Stake.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./IERC721.sol";
 
interface IPair {  
  function token0() external view returns (address);
  function token1() external view returns (address);
  function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast); 
}
 
 
contract StakingNFT is ReentrancyGuard ,ERC721Holder {
  using FixedPointMath for FixedPointMath.FixedDecimal;
  using EnumerableSet for EnumerableSet.UintSet;
  using Pool for Pool.Data;
  using Pool for Pool.List;
  using SafeERC20 for IERC20;
  using SafeMath for uint256;
  using Stake for Stake.Data;
  using Address for address;

  //ok main
  address constant USDT =  0x382bB369d343125BfB2117af9c149795C6C65C50 ;  

  address public constant ZERO_ADDRESS = address(0);

  /// @dev Resolution for all fixed point numeric parameters which represent percents. The resolution allows for a
  /// granularity of 0.01% increments.
  uint256 public constant PERCENT_RESOLUTION = 10000;
 
  event PendingGovernanceUpdated(
    address pendingGovernance
  );

  event GovernanceUpdated(
    address governance
  );

  event RewardRateUpdated(
    uint256 rewardRate
  );

  event PoolRewardWeightUpdated(
    uint256 indexed poolId,
    uint256 rewardWeight
  );

  event PoolCreated(
    uint256 indexed poolId,
    uint256 indexed weight,
    IERC721 indexed token
  );

  event TokensDeposited(
    address indexed user,
    uint256 indexed poolId,
    uint256 amount
  );

  event TokensWithdrawn(
    address indexed user,
    uint256 indexed poolId,
    uint256 amount
  );

  event TokensClaimed(
    address indexed user,
    uint256 indexed poolId,
    uint256 amount
  );

  event RewardsUpdated(
    address rewards
  );

  event TokensMinted(
    address indexed user,
    uint256 amountIn,
    uint256 amountOut
  );

  event RefBonus(
    address indexed user,
    uint256 amount
  );
  

  /// @dev The token which will be minted as a reward for staking.
  IERC20 public reward;

  /// @dev The address of the account which currently has administrative capabilities over this contract.
  address public governance;

  address public pendingGovernance;

  uint256 public feePercent = 100;  //default 1%
 
  uint256 public stakingCount;
 
  /// @dev The address which will receive fees.
  address public feeAddress;

  /// @dev Tokens are mapped to their pool identifier plus one. Tokens that do not have an associated pool
  /// will return an identifier of zero.
  mapping(IERC721 => uint256) public tokenPoolIds;

  mapping(uint256 => uint256) public tokenWeights;

  /// @dev The context shared between the pools.
  Pool.Context private _ctx;

  /// @dev A list of all of the pools.
  Pool.List private _pools;
 

  /// @dev A mapping of all of the user stakes mapped first by pool and then by address.
  mapping(address => mapping(uint256 => Stake.Data)) private _stakes;
  mapping(address => EnumerableSet.UintSet) private _holderTokens;

	struct User {
		uint256 count;   
		address referrer;  
	}
  mapping (address => User) public users;

  constructor(
    IERC20 _reward,
    uint256 _rewardRate,
    address _feeAddressTo
  ) public {
    
    reward = _reward;
    governance = msg.sender;
 
    setRewardRate(_rewardRate);
    setRewardFee(_feeAddressTo);
  }
 
  /// @dev Checks that caller is not a eoa.
  ///
  /// This is used to prevent contracts from interacting.
  modifier noContractAllowed() {
        require(!address(msg.sender).isContract() && msg.sender == tx.origin, "Sorry we do not accept contract!");
        _;
  }
     

  /// @dev A modifier which reverts when the caller is not the governance.
  modifier onlyGovernance() {
    require(msg.sender == governance, "StakingDao: only governance");
    _;
  }
 

  function setFeePercent(uint256 _feePercent) external onlyGovernance {
    feePercent = _feePercent;
  }
 
 
  /// @dev Sets the governance.
  ///
  /// This function can only called by the current governance.
  ///
  /// @param _pendingGovernance the new pending governance.
  function setPendingGovernance(address _pendingGovernance) external onlyGovernance {
    require(_pendingGovernance != address(0), "StakingDao: pending governance address cannot be 0x0");
    pendingGovernance = _pendingGovernance;

    emit PendingGovernanceUpdated(_pendingGovernance);
  }

  function acceptGovernance() external {
    require(msg.sender == pendingGovernance, "StakingDao: only pending governance");

    address _pendingGovernance = pendingGovernance;
    governance = _pendingGovernance;

    emit GovernanceUpdated(_pendingGovernance);
  }

  /// @dev Sets the rewards address.
  ///
  /// This function revert  if _rewards is zero address.
  ///
  /// @param _rewards the new rewards contract.
  function setRewardFee(address _rewards) public onlyGovernance {
    require(_rewards != ZERO_ADDRESS, "StakingDao: rewards address cannot be 0x0.");

    feeAddress = _rewards;

    emit RewardsUpdated(_rewards);
  }

  /// @dev Sets the distribution reward rate.
  ///
  /// This will update all of the pools.
  ///
  /// @param _rewardRate The number of tokens to distribute per second.
  function setRewardRate(uint256 _rewardRate) public onlyGovernance {
    _updatePools();

    _ctx.rewardRate = _rewardRate;
    
    emit RewardRateUpdated(_rewardRate);
  }

  function getTokensOnStake(address _address) public view returns (uint256[] memory listOfStake) {
        uint256 _len = _holderTokens[_address].length();   
        uint256[] memory _tokens = new uint256[](_len);

        for (uint256 index = 0; index < _len; index++) {
            _tokens[index] = _holderTokens[_address].at(index);
        }

        return _tokens;
  }
   

  /// @dev Creates a new pool.
  ///
  /// The created pool will need to have its reward weight initialized before it begins generating rewards.
  ///
  /// @param _token The token the pool will accept for staking.
  ///
  /// @return the identifier for the newly created pool.
  function createPool(IERC721 _token, uint256 _rewardWeight) external onlyGovernance returns (uint256) {
    require(tokenPoolIds[_token] == 0, "StakingDao: token already has a pool");

    uint256 _poolId = _pools.length();
    require(_poolId == 0, "StakingDao: only one pool");

    _pools.push(Pool.Data({
      token: _token,
      totalDeposited: 0,
      rewardWeight: _rewardWeight,
      accumulatedRewardWeight: FixedPointMath.FixedDecimal(0),
      lastUpdatedBlock: block.number
    }));

    tokenPoolIds[_token] = _poolId + 1;

    //
    _updatePools();
    _ctx.totalRewardWeight = _ctx.totalRewardWeight.add(_rewardWeight);
    //

    emit PoolCreated(_poolId,_rewardWeight, _token);

    return _poolId;
  }

  function setPoolRewardWeight(uint256 _poolId, uint256 _rewardWeight) external onlyGovernance {
      _updatePools();

      uint256 _totalRewardWeight = _ctx.totalRewardWeight;
      Pool.Data storage _pool = _pools.get(_poolId);
      uint256 _currentRewardWeight = _pool.rewardWeight;
      if (_currentRewardWeight == _rewardWeight) {
        return;
      }

      _totalRewardWeight = _totalRewardWeight.sub(_currentRewardWeight).add(_rewardWeight);
      _pool.rewardWeight = _rewardWeight;

      emit PoolRewardWeightUpdated(_poolId, _rewardWeight);
      _ctx.totalRewardWeight = _totalRewardWeight;
  }

  /// @dev Sets the reward weights of all of the pools.
  ///
  /// @param _rewardWeights The reward weights of all of the pools.
  function setRewardWeights(uint256[] calldata _rewardWeights) external onlyGovernance {
    require(_rewardWeights.length == _pools.length(), "StakingDao: weights length mismatch");

    _updatePools();

    uint256 _totalRewardWeight = _ctx.totalRewardWeight;
    for (uint256 _poolId = 0; _poolId < _pools.length(); _poolId++) {
      Pool.Data storage _pool = _pools.get(_poolId);

      uint256 _currentRewardWeight = _pool.rewardWeight;
      if (_currentRewardWeight == _rewardWeights[_poolId]) {
        continue;
      }

      // 
      _totalRewardWeight = _totalRewardWeight.sub(_currentRewardWeight).add(_rewardWeights[_poolId]);
      _pool.rewardWeight = _rewardWeights[_poolId];

      emit PoolRewardWeightUpdated(_poolId, _rewardWeights[_poolId]);
    }

    _ctx.totalRewardWeight = _totalRewardWeight;
  }

 
  /// @dev Stakes tokens into a pool.
  ///
  /// @param _poolId        the pool to deposit tokens into.
 
  function deposit(uint256 _poolId, uint256 _tokenId, address referrer) external nonReentrant noContractAllowed {
    require(referrer != msg.sender, "referrer != msg.sender");
    require(_tokenId > 0, "zero id");

    Pool.Data storage _pool = _pools.get(_poolId);
    _pool.update(_ctx);

    Stake.Data storage _stake = _stakes[msg.sender][_poolId];
    _stake.update(_pool, _ctx);

    _deposit(_poolId, _tokenId);
 
    _holderTokens[msg.sender].add(_tokenId);
    stakingCount++;

    User storage user = users[msg.sender];
    if (user.referrer == address(0)) {
      user.referrer = (referrer == address(0)) ? governance : referrer ;
      users[referrer].count = users[referrer].count + 1 ;
    }   
  }

  function rewardPreDay() public view returns (uint256) {
    return _ctx.rewardRate.mul(21600) ;
  }


  /// @dev Withdraws staked tokens from a pool.
  ///
  /// @param _poolId          The pool to withdraw staked tokens from.
  function withdraw(uint256 _poolId, uint256 _tokenId) public nonReentrant noContractAllowed {
    require(_tokenId > 0, "zero id");
    require(_holderTokens[msg.sender].contains(_tokenId) , "Token id not found");

    Pool.Data storage _pool = _pools.get(_poolId);
    _pool.update(_ctx);

    Stake.Data storage _stake = _stakes[msg.sender][_poolId];
    _stake.update(_pool, _ctx);
    
    _claim(_poolId);
    _withdraw(_poolId, _tokenId);

    _holderTokens[msg.sender].remove(_tokenId);
    stakingCount--;
  }

  /// @dev Claims all rewarded tokens from a pool.
  ///
  /// @param _poolId The pool to claim rewards from.
  ///
  /// @notice use this function to claim the tokens from a corresponding pool by ID.
  function claim(uint256 _poolId) external nonReentrant {
    Pool.Data storage _pool = _pools.get(_poolId);
    _pool.update(_ctx);

    Stake.Data storage _stake = _stakes[msg.sender][_poolId];
    _stake.update(_pool, _ctx);

    _claim(_poolId);
  }


  /// @dev Gets the rate at which tokens are minted to stakers for all pools.
  ///
  /// @return the reward rate.
  function rewardRate() external view returns (uint256) {
    return _ctx.rewardRate;
  }

  /// @dev Gets the total reward weight between all the pools.
  ///
  /// @return the total reward weight.
  function totalRewardWeight() external view returns (uint256) {
    return _ctx.totalRewardWeight;
  }

  /// @dev Gets the number of pools that exist.
  ///
  /// @return the pool count.
  function poolCount() external view returns (uint256) {
    return _pools.length();
  }

  /// @dev Gets the token a pool accepts.
  ///
  /// @param _poolId the identifier of the pool.
  ///
  /// @return the token.
  function getPoolToken(uint256 _poolId) external view returns (IERC721) {
    Pool.Data storage _pool = _pools.get(_poolId);
    return _pool.token;
  }

  /// @dev Gets the total amount of funds staked in a pool.
  ///
  /// @param _poolId the identifier of the pool.
  ///
  /// @return the total amount of staked or deposited tokens.
  function getPoolTotalDeposited(uint256 _poolId) public view returns (uint256) {
    Pool.Data storage _pool = _pools.get(_poolId);
    return _pool.totalDeposited;
  }

  /// @dev Gets the reward weight of a pool which determines how much of the total rewards it receives per block.
  ///
  /// @param _poolId the identifier of the pool.
  ///
  /// @return the pool reward weight.
  function getPoolRewardWeight(uint256 _poolId) external view returns (uint256) {
    Pool.Data storage _pool = _pools.get(_poolId);
    return _pool.rewardWeight;
  }

  /// @dev Gets the amount of tokens per block being distributed to stakers for a pool.
  ///
  /// @param _poolId the identifier of the pool.
  ///
  /// @return the pool reward rate.
  function getPoolRewardRate(uint256 _poolId) external view returns (uint256) {
    Pool.Data storage _pool = _pools.get(_poolId);
    return _pool.getRewardRate(_ctx);
  }

  /// @dev Gets the number of tokens a user has staked into a pool.
  ///
  /// @param _account The account to query.
  /// @param _poolId  the identifier of the pool.
  ///
  /// @return the amount of deposited tokens.
  function getStakeTotalDeposited(address _account, uint256 _poolId) external view returns (uint256) {
    Stake.Data storage _stake = _stakes[_account][_poolId];
    return _stake.totalDeposited;
  }

  /// @dev Gets the number of unclaimed reward tokens a user can claim from a pool.
  ///
  /// @param _account The account to get the unclaimed balance of.
  /// @param _poolId  The pool to check for unclaimed rewards.
  ///
  /// @return the amount of unclaimed reward tokens a user has in a pool.
  function getStakeTotalUnclaimed(address _account, uint256 _poolId) external view returns (uint256) {
    Stake.Data storage _stake = _stakes[_account][_poolId];
    return _stake.getUpdatedTotalUnclaimed(_pools.get(_poolId), _ctx);
  }

  /// @dev Updates all of the pools.
  function _updatePools() internal {
    for (uint256 _poolId = 0; _poolId < _pools.length(); _poolId++) {
      Pool.Data storage _pool = _pools.get(_poolId);
      _pool.update(_ctx);
    }
  }
 
  /// @dev Stakes tokens into a pool.
  ///
  /// The pool and stake MUST be updated before calling this function.
  ///
  /// @param _poolId        the pool to deposit tokens into.

  function _deposit(uint256 _poolId, uint256 _tokenId )internal {
    Pool.Data storage _pool = _pools.get(_poolId);
    Stake.Data storage _stake = _stakes[msg.sender][_poolId];

    uint256 _depositAmount = _calcTokenValue(_pool.token, _tokenId);
    tokenWeights[_tokenId] = _depositAmount;
    _pool.totalDeposited = _pool.totalDeposited.add(_depositAmount);
    _stake.totalDeposited = _stake.totalDeposited.add(_depositAmount);

    _pool.token.transferFrom(msg.sender, address(this), _tokenId);//ERC721 ownership transferred

    emit TokensDeposited(msg.sender, _poolId, _tokenId);
  }

  function _calcTokenValue(IERC721 nft, uint256 _tokenId) internal view returns (uint256)  {
    uint256 mintPrice;
    uint256 skin;

    (,,,,,,mintPrice,,skin,,) = nft.getNFTInfoByID(_tokenId);
    return mintPrice ;  
  }
 
  /// @dev Withdraws staked tokens from a pool.
  ///
  /// The pool and stake MUST be updated before calling this function.
  ///
  /// @param _poolId          The pool to withdraw staked tokens from.

  function _withdraw(uint256 _poolId, uint256 _tokenId) internal {
    Pool.Data storage _pool = _pools.get(_poolId);
    Stake.Data storage _stake = _stakes[msg.sender][_poolId];

    uint256 _withdrawAmount = tokenWeights[_tokenId] ;
    _pool.totalDeposited = _pool.totalDeposited.sub(_withdrawAmount);
    _stake.totalDeposited = _stake.totalDeposited.sub(_withdrawAmount);

    _pool.token.transferFrom(address(this), msg.sender,  _tokenId);//ERC721 ownership transferred

    emit TokensWithdrawn(msg.sender, _poolId, _tokenId);
  }

  /// @dev Claims all rewarded tokens from a pool.
  ///
  /// The pool and stake MUST be updated before calling this function.
  ///
  /// @param _poolId The pool to claim rewards from.
  ///
  /// @notice use this function to claim the tokens from a corresponding pool by ID.
  function _claim(uint256 _poolId) internal {
    Stake.Data storage _stake = _stakes[msg.sender][_poolId];

    uint256 _claimAmount = _stake.totalUnclaimed;
    uint256 _feeAmount = _claimAmount.mul(feePercent).div(PERCENT_RESOLUTION);
    uint256 _mintAmount = _claimAmount.sub(_feeAmount);
    
    uint256 _balance = reward.balanceOf(address(this));

    if (_balance > _claimAmount) {
      _stake.totalUnclaimed = 0;
      reward.safeTransfer(feeAddress, _feeAmount);
      reward.safeTransfer(msg.sender, _mintAmount);
      emit TokensClaimed(msg.sender, _poolId, _claimAmount); 
    }
  }
    

}
