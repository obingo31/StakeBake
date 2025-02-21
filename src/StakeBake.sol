// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title StakeBake
 * @notice Enhanced staking contract with advanced features
 * @dev This contract allows users to stake tokens, earn rewards based on locking periods, and claim continuous rewards.
 */
contract StakeBake is ReentrancyGuard, Pausable {
    struct Stake {
        uint72 tokenAmount;
        uint24 lockingPeriodInBlocks;
        uint32 startBlock;
        uint128 expectedStakingRewardPoints;
        bool claimed;
    }

    struct Pool {
        IERC20 stakingToken;
        uint256 totalStaked;
        uint256 rewardRatePerSecond;
        uint256 rewardRatePoints;
        uint256 finishAt;
        uint256 updatedAt;
        uint256 rewardPerTokenStored;
        bool active;
        uint256 earlyWithdrawalPenalty; // Percentage (0-100)
    }

    struct Booster {
        uint256 multiplier; // 1e18 = 1x
        uint256 endBlock;
    }

    mapping(address => mapping(uint256 => Stake)) public userStakes;
    mapping(address => mapping(uint256 => uint256)) public userRewardPoints;
    mapping(address => mapping(uint256 => uint256)) public userRewardPerTokenPaid;
    mapping(address => uint256) public continuousRewards;
    mapping(uint256 => Pool) public pools;
    mapping(uint256 => uint256) public poolTotalRewardPoints;
    mapping(uint256 => Booster) public poolBoosters;

    uint256 public poolCount;
    uint256 public totalRewardFund;
    IERC20 immutable public rewardToken;
    mapping(address => uint256) public grantedTokens;
    mapping(address => uint256) public releasedTokens;
    uint256 immutable public vestingDuration;
    uint256 immutable public stakingProgramEndsBlock;
    address immutable public owner;

    bool public emergencyStopped;
    mapping(address => bool) public admins;
    MultiSig public multiSig;

    struct MultiSig {
        address[] signers;
        uint256 requiredSignatures;
        mapping(bytes32 => uint256) signatures;
    }

    event PoolCreated(uint256 indexed poolId, address stakingToken, uint256 rewardRatePoints, uint256 rewardRatePerSecond);
    event StakeLocked(address indexed user, uint256 indexed poolId, uint256 amount, uint256 lockingPeriod, uint256 points);
    event StakePeriodAdjusted(address indexed user, uint256 indexed poolId, uint256 newPeriod);
    event BoosterActivated(uint256 indexed poolId, uint256 multiplier, uint256 endBlock);
    event CompoundRewards(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 indexed poolId, uint256 continuousReward, uint256 lockedReward);
    event EmergencyStop(bool stopped);
    event RewardFundAdded(uint256 amount);
    event RewardReleased(address indexed user, uint256 amount);
    event StakeUnlockedPrematurely(address indexed user, uint256 amount, uint256 lockingPeriod, uint256 blockNumber);
    event StakeUnlocked(address indexed user, uint256 amount, uint256 lockingPeriod, uint256 rewardPoints);

    constructor(
        address rewardToken_,
        uint256 stakingDurationInBlocks_,
        uint256 vestingDuration_,
        address owner_,
        address[] memory multiSigSigners_,
        uint256 multiSigRequiredSignatures_
    ) {
        require(owner_ != address(0), "Owner address cannot be zero");
        require(rewardToken_ != address(0), "Reward token address cannot be zero");
        require(multiSigSigners_.length >= multiSigRequiredSignatures_, "Invalid multi-signature configuration");

        owner = owner_;
        admins[owner_] = true;
        rewardToken = IERC20(rewardToken_);
        stakingProgramEndsBlock = block.number + stakingDurationInBlocks_;
        vestingDuration = vestingDuration_;
        multiSig.signers = multiSigSigners_;
        multiSig.requiredSignatures = multiSigRequiredSignatures_;
    }

    modifier onlyOwnerOrAdmin() {
        require(msg.sender == owner || admins[msg.sender], "Not authorized: Only owner or admin can call this function");
        _;
    }

    modifier onlyMultiSig() {
        require(isMultiSigSigner(msg.sender), "Not authorized: Only multi-signature signers can call this function");
        _;
    }

    modifier updateContinuousReward(address account_, uint256 poolId_) {
        Pool storage pool = pools[poolId_];
        pool.rewardPerTokenStored = rewardPerToken(poolId_);
        pool.updatedAt = lastTimeRewardApplicable(poolId_);
        if (account_ != address(0)) {
            continuousRewards[account_] += earnedContinuous(account_, poolId_);
            userRewardPerTokenPaid[account_][poolId_] = pool.rewardPerTokenStored;
        }
        _;
    }

    // Enhanced Pool Management
    function createPool(
        address stakingToken_, 
        uint256 rewardRatePoints_, 
        uint256 rewardRatePerSecond_,
        uint256 earlyWithdrawalPenalty_
    ) external onlyOwnerOrAdmin whenNotPaused {
        require(stakingToken_ != address(0), "Invalid staking token address");
        require(earlyWithdrawalPenalty_ <= 100, "Early withdrawal penalty must be <= 100");

        pools[poolCount] = Pool(
            IERC20(stakingToken_),
            0,
            rewardRatePerSecond_,
            rewardRatePoints_,
            0,
            block.timestamp,
            0,
            true,
            earlyWithdrawalPenalty_
        );
        emit PoolCreated(poolCount, stakingToken_, rewardRatePoints_, rewardRatePerSecond_);
        poolCount++;
    }

    function activateBooster(uint256 poolId_, uint256 multiplier_, uint256 durationInBlocks_) 
        external onlyOwnerOrAdmin {
        require(poolId_ < poolCount, "Invalid pool ID");
        poolBoosters[poolId_] = Booster(multiplier_, block.number + durationInBlocks_);
        emit BoosterActivated(poolId_, multiplier_, block.number + durationInBlocks_);
    }

    // Staking Functions
    function lockTokens(uint256 poolId_, uint72 tokenAmount_, uint24 lockingPeriodInBlocks_)
        external whenNotPaused nonReentrant updateContinuousReward(msg.sender, poolId_) {
        require(!emergencyStopped, "Emergency stop is active");
        require(poolId_ < poolCount, "Invalid pool ID");
        require(pools[poolId_].active, "Pool is not active");
        require(block.number <= stakingProgramEndsBlock - lockingPeriodInBlocks_, "Locking period exceeds staking program duration");
        require(userStakes[msg.sender][poolId_].tokenAmount == 0, "User already has an active stake in this pool");

        Pool storage pool = pools[poolId_];
        uint128 rewardPoints = calculateRewardPoints(tokenAmount_, lockingPeriodInBlocks_, pool.rewardRatePoints, poolId_);

        userStakes[msg.sender][poolId_] = Stake(tokenAmount_, lockingPeriodInBlocks_, uint32(block.number), rewardPoints, false);
        pool.totalStaked += tokenAmount_;
        poolTotalRewardPoints[poolId_] += rewardPoints;
        userRewardPoints[msg.sender][poolId_] += rewardPoints;

        require(pool.stakingToken.transferFrom(msg.sender, address(this), tokenAmount_), "Transfer failed: Insufficient balance or allowance");
        emit StakeLocked(msg.sender, poolId_, tokenAmount_, lockingPeriodInBlocks_, rewardPoints);
    }

    function adjustLockingPeriod(uint256 poolId_, uint24 newLockingPeriod_) 
        external nonReentrant updateContinuousReward(msg.sender, poolId_) {
        Stake storage stake = userStakes[msg.sender][poolId_];
        require(stake.tokenAmount > 0, "No active stake found");
        require(!stake.claimed, "Stake already claimed");
        require(block.number <= stakingProgramEndsBlock - newLockingPeriod_, "New locking period exceeds staking program duration");

        uint128 newPoints = calculateRewardPoints(
            stake.tokenAmount,
            newLockingPeriod_,
            pools[poolId_].rewardRatePoints,
            poolId_
        );

        poolTotalRewardPoints[poolId_] = poolTotalRewardPoints[poolId_] - stake.expectedStakingRewardPoints + newPoints;
        userRewardPoints[msg.sender][poolId_] = userRewardPoints[msg.sender][poolId_] - stake.expectedStakingRewardPoints + newPoints;
        stake.lockingPeriodInBlocks = newLockingPeriod_;
        stake.expectedStakingRewardPoints = newPoints;

        emit StakePeriodAdjusted(msg.sender, poolId_, newLockingPeriod_);
    }

    function unlockTokens(uint256 poolId_) 
        external nonReentrant updateContinuousReward(msg.sender, poolId_) {
        Stake storage stake = userStakes[msg.sender][poolId_];
        require(stake.tokenAmount > 0, "No active stake found");
        require(!stake.claimed, "Stake already claimed");

        Pool storage pool = pools[poolId_];
        uint256 returnAmount = stake.tokenAmount;
        
        if (block.number < stake.startBlock + stake.lockingPeriodInBlocks) {
            uint256 penalty = (stake.tokenAmount * pool.earlyWithdrawalPenalty) / 100;
            returnAmount -= penalty;
            totalRewardFund += penalty; // Penalty goes to reward pool
        }
        _processEarlyUnlock(msg.sender, poolId_, stake);

        pool.totalStaked -= stake.tokenAmount;
        stake.claimed = true;
        require(pool.stakingToken.transfer(msg.sender, returnAmount), "Transfer failed: Insufficient contract balance");
    }

    // Reward Calculations
    function calculateRewardPoints(uint72 amount_, uint24 period_, uint256 rate_, uint256 poolId_) 
        private view returns (uint128) {
        uint256 booster = poolBoosters[poolId_].endBlock > block.number ? 
            poolBoosters[poolId_].multiplier : 1e18;
        return uint128((uint256(amount_) * period_ * rate_ * booster) / 1e18);
    }

    function rewardPerToken(uint256 poolId_) public view returns (uint256) {
        Pool memory pool = pools[poolId_];
        if (pool.totalStaked == 0) return pool.rewardPerTokenStored;
        return pool.rewardPerTokenStored + 
            (pool.rewardRatePerSecond * (lastTimeRewardApplicable(poolId_) - pool.updatedAt) * 1e18) / 
            pool.totalStaked;
    }

    function earnedContinuous(address account_, uint256 poolId_) public view returns (uint256) {
        return ((userStakes[account_][poolId_].tokenAmount * 
            (rewardPerToken(poolId_) - userRewardPerTokenPaid[account_][poolId_])) / 1e18) + 
            continuousRewards[account_];
    }

    // Reward Management
    function claimRewards(uint256[] calldata poolIds_) 
        external nonReentrant {
        uint256 totalContinuous = 0;
        uint256 totalLocked = 0;

        for (uint256 i = 0; i < poolIds_.length; i++) {
            uint256 poolId = poolIds_[i];
            require(poolId < poolCount, "Invalid pool ID");
            _updateContinuousReward(msg.sender, poolId);
            
            Stake memory stake = userStakes[msg.sender][poolId];
            totalContinuous += continuousRewards[msg.sender];
            continuousRewards[msg.sender] = 0;

            if (block.number > stakingProgramEndsBlock && stake.claimed && userRewardPoints[msg.sender][poolId] > 0) {
                uint256 lockedReward = (totalRewardFund * userRewardPoints[msg.sender][poolId]) / 
                    poolTotalRewardPoints[poolId];
                userRewardPoints[msg.sender][poolId] = 0;
                totalLocked += lockedReward;
                _grantTokens(msg.sender, lockedReward);
            }
            emit RewardClaimed(msg.sender, poolId, totalContinuous, totalLocked);
        }

        if (totalContinuous > 0) {
            require(rewardToken.transfer(msg.sender, totalContinuous), "Transfer failed: Insufficient contract balance");
        }
    }

    function compoundRewards(uint256[] calldata poolIds_) 
        external nonReentrant updateContinuousReward(msg.sender, poolIds_[0]) {
        uint256 totalContinuous = continuousRewards[msg.sender];
        require(totalContinuous > 0, "No rewards to compound");

        continuousRewards[msg.sender] = 0;
        Pool storage pool = pools[poolIds_[0]];
        uint72 amount = uint72(totalContinuous);
        
        uint128 rewardPoints = calculateRewardPoints(amount, userStakes[msg.sender][poolIds_[0]].lockingPeriodInBlocks, 
            pool.rewardRatePoints, poolIds_[0]);
        
        userStakes[msg.sender][poolIds_[0]].tokenAmount += amount;
        pool.totalStaked += amount;
        poolTotalRewardPoints[poolIds_[0]] += rewardPoints;
        userRewardPoints[msg.sender][poolIds_[0]] += rewardPoints;

        require(rewardToken.approve(address(this), totalContinuous), "Approve failed");
        require(rewardToken.transferFrom(address(this), address(this), totalContinuous), "Transfer failed");
        emit CompoundRewards(msg.sender, totalContinuous);
    }

    // Helper functions
    function _updateContinuousReward(address account_, uint256 poolId_) private {
        Pool storage pool = pools[poolId_];
        pool.rewardPerTokenStored = rewardPerToken(poolId_);
        pool.updatedAt = lastTimeRewardApplicable(poolId_);
        continuousRewards[account_] += earnedContinuous(account_, poolId_);
        userRewardPerTokenPaid[account_][poolId_] = pool.rewardPerTokenStored;
    }

    function lastTimeRewardApplicable(uint256 poolId_) public view returns (uint256) {
        return pools[poolId_].finishAt < block.timestamp ? pools[poolId_].finishAt : block.timestamp;
    }


///@notice Grant tokens to a user
///@param account_ The address of the user
///@param amount_ The amount of tokens to grant
    function _grantTokens(address account_, uint256 amount_) private {
        grantedTokens[account_] += amount_;
    }

///@notice Release vested tokens to the user
///@dev This function releases the vested tokens to the user based on the vesting schedule
    function release() external nonReentrant {
        uint256 releasable = _releasableAmount(msg.sender);
        require(releasable > 0, "No tokens to release");

        releasedTokens[msg.sender] += releasable;
        require(rewardToken.transfer(msg.sender, releasable), "Transfer failed: Insufficient contract balance");
        emit RewardReleased(msg.sender, releasable);
    }

    function _releasableAmount(address account) private view returns (uint256) {
        return _vestedAmount(account) - releasedTokens[account];
    }

    function _vestedAmount(address account) private view returns (uint256) {
        uint256 totalGranted = grantedTokens[account];
        if (block.number >= stakingProgramEndsBlock + vestingDuration) {
            return totalGranted;
        } else {
            return (totalGranted * (block.number - stakingProgramEndsBlock)) / vestingDuration;
        }
    }

    function _processEarlyUnlock(address account, uint256 poolId, Stake storage stake) private {
        emit StakeUnlockedPrematurely(account, stake.tokenAmount, stake.lockingPeriodInBlocks, block.number);
    }

    function isMultiSigSigner(address account) public view returns (bool) {
        for (uint256 i = 0; i < multiSig.signers.length; i++) {
            if (multiSig.signers[i] == account) {
                return true;
            }
        }
        return false;
    }

    function addMultiSigSignature(bytes32 txHash) external onlyMultiSig {
        multiSig.signatures[txHash]++;
    }

    function executeMultiSigTransaction(bytes32 txHash, address to, uint256 value, bytes calldata data) external onlyMultiSig {
        require(multiSig.signatures[txHash] >= multiSig.requiredSignatures, "Not enough signatures");
        (bool success, ) = to.call{value: value}(data);
        require(success, "Transaction failed");
    }

    function getPoolInfo(uint256 poolId_) external view returns (Pool memory, Booster memory) {
        return (pools[poolId_], poolBoosters[poolId_]);
    }
}