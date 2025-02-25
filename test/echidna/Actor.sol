// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

interface IRecipeNFT is IERC721 {
    function getWeight(uint256 tokenId) external view returns (uint256);
}

contract StakeBake is ReentrancyGuard, Pausable, Ownable {
    using ECDSA for bytes32;

    // --- Structs ---
    struct Stake {
        uint256 tokenId;
        uint256 weight;
        uint256 lockingPeriodInBlocks;
        uint256 startBlock;
        uint256 expectedStakingRewardPoints;
        bool claimed;
    }

    struct Pool {
        IRecipeNFT recipeNFT;
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
        uint256 multiplier;
        uint256 endBlock;
    }

    struct MultiSig {
        address[] signers;
        uint256 requiredSignatures;
        mapping(bytes32 => mapping(address => bool)) signatures;
        mapping(address => bool) isSigner;
    }

    struct VestingSchedule {
        uint256 totalAmount;
        uint256 cliff;
        uint256 duration;
        uint256 start;
    }

    // --- State Variables ---
    uint256 public immutable vestingDuration;
    uint256 public immutable stakingProgramEndsBlock;
    IERC20 public immutable rewardToken;

    mapping(address => mapping(uint256 => mapping(uint256 => Stake))) public userStakes;
    mapping(address => mapping(uint256 => uint256[])) public userStakedTokenIds;
    mapping(address => mapping(uint256 => uint256)) public userRewardPoints;
    mapping(bytes32 => uint256) public continuousRewards; // account => poolId => reward
    mapping(address => mapping(uint256 => uint256)) public userRewardPerTokenPaid; // account => poolId => rewardPerTokenPaid
    mapping(uint256 => Pool) public pools;
    mapping(uint256 => uint256) public poolTotalRewardPoints;
    mapping(uint256 => Booster) public poolBoosters;
    uint256 public poolCount;
    uint256 public totalRewardFund;
    mapping(address => uint256) public grantedTokens;
    mapping(address => uint256) public releasedTokens;
    mapping(address => VestingSchedule) public vestingSchedules;

    bool public isEmergencyStopped;
    MultiSig public multiSig;

    // --- Events ---
    event PoolCreated(uint256 indexed poolId, address recipeNFT, uint256 rewardRatePoints, uint256 rewardRatePerSecond);
    event StakeLocked(address indexed user, uint256 indexed poolId, uint256 tokenId, uint256 lockingPeriod, uint256 points);
    event StakePeriodAdjusted(address indexed user, uint256 indexed poolId, uint256 newPeriod);
    event BoosterActivated(uint256 indexed poolId, uint256 multiplier, uint256 endBlock);
    event RewardClaimed(address indexed user, uint256 indexed poolId, uint256 continuousReward, uint256 lockedReward);
    event EmergencyStop(bool stopped);
    event RewardFundAdded(uint256 amount);
    event RewardReleased(address indexed user, uint256 amount);
    event StakeUnlockedPrematurely(address indexed user, uint256 tokenId, uint256 poolId, uint256 penaltyApplied);
    event StakeUnlocked(address indexed user, uint256 tokenId, uint256 poolId, uint256 rewardPoints);
    event VestingScheduleCreated(address indexed user, uint256 totalAmount, uint256 cliff, uint256 duration);
    event TokensGranted(address indexed user, uint256 amount);

    // --- Constructor ---
    constructor(
        address rewardToken_,
        uint256 stakingDurationInBlocks_,
        uint256 vestingDuration_,
        address[] memory multiSigSigners_,
        uint256 multiSigRequiredSignatures_
    ) {
        require(rewardToken_ != address(0), "Reward token address cannot be zero");
        require(multiSigRequiredSignatures_ > 0, "Required signatures must be greater than zero");
        require(multiSigSigners_.length >= multiSigRequiredSignatures_, "Invalid multi-signature configuration");

        rewardToken = IERC20(rewardToken_);
        stakingProgramEndsBlock = block.number + stakingDurationInBlocks_;
        vestingDuration = vestingDuration_;

        multiSig.signers = multiSigSigners_;
        multiSig.requiredSignatures = multiSigRequiredSignatures_;
        for (uint256 i = 0; i < multiSigSigners_.length; i++) {
            multiSig.isSigner[multiSigSigners_[i]] = true;
        }
    }

    // --- Modifiers ---
    modifier onlyMultiSig() {
        require(multiSig.isSigner[msg.sender], "Not a multi-signature signer");
        _;
    }

    modifier updateContinuousReward(address account_, uint256 poolId_) {
        Pool storage pool = pools[poolId_];
        uint256 currentRewardPerToken = rewardPerToken(poolId_);
        uint256 currentLastTimeRewardApplicable = lastTimeRewardApplicable(poolId_);
        uint256 currentEarnedContinuous;

        if (account_ != address(0)) {
            currentEarnedContinuous = earnedContinuous(account_, poolId_);
        }

        _;

        pool.rewardPerTokenStored = currentRewardPerToken;
        pool.updatedAt = currentLastTimeRewardApplicable;

        if (account_ != address(0)) {
            bytes32 userPoolKey = getUserPoolKey(account_, poolId_);
            continuousRewards[userPoolKey] = currentEarnedContinuous;
            userRewardPerTokenPaid[account_][poolId_] = currentRewardPerToken;
        }
    }

    // --- Helper Functions ---
    function getUserPoolKey(address user, uint256 poolId) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(user, poolId));
    }

    function lastTimeRewardApplicable(uint256 poolId_) public view returns (uint256) {
        Pool memory pool = pools[poolId_];
        return block.number < stakingProgramEndsBlock ? block.number : stakingProgramEndsBlock;
    }

    // --- Pool Management ---
    function createPool(
        address recipeNFT_,
        uint256 rewardRatePoints_,
        uint256 rewardRatePerSecond_,
        uint256 earlyWithdrawalPenalty_
    ) external onlyOwner whenNotPaused onlyMultiSig {
        require(recipeNFT_ != address(0), "Invalid recipe NFT address");
        require(earlyWithdrawalPenalty_ <= 100, "Early withdrawal penalty must be <= 100");

        pools[poolCount] = Pool(
            IRecipeNFT(recipeNFT_),
            0,
            rewardRatePerSecond_,
            rewardRatePoints_,
            0,
            block.timestamp,
            0,
            true,
            earlyWithdrawalPenalty_
        );
        emit PoolCreated(poolCount, recipeNFT_, rewardRatePoints_, rewardRatePerSecond_);
        poolCount++;
    }

    // --- Staking Functions ---
    function removeTokenFromArray(uint256[] storage array, uint256 tokenId) internal {
        uint256 length = array.length;
        for (uint256 i = 0; i < length; i++) {
            if (array[i] == tokenId) {
                array[i] = array[length - 1];
                array.pop();
                break;
            }
        }
    }

    function lockTokens(uint256 poolId_, uint256 tokenId_, uint256 lockingPeriodInBlocks_)
        external
        whenNotPaused
        nonReentrant
        updateContinuousReward(msg.sender, poolId_)
    {
        require(!isEmergencyStopped, "Emergency stop is active");
        require(poolId_ < poolCount, "Invalid pool ID");
        require(pools[poolId_].active, "Pool is not active");
        require(
            block.number + lockingPeriodInBlocks_ <= stakingProgramEndsBlock,
            "Locking period exceeds staking program duration"
        );
        require(userStakes[msg.sender][poolId_][tokenId_].tokenId == 0, "Token is already staked");
        require(lockingPeriodInBlocks_ > 0, "Locking period must be greater than zero");

        Pool storage pool = pools[poolId_];
        IRecipeNFT recipeNFT = pool.recipeNFT; // Cache the recipeNFT
        uint256 weight = recipeNFT.getWeight(tokenId_);
        uint256 rewardPoints = calculateRewardPoints(weight, lockingPeriodInBlocks_, pool.rewardRatePoints, poolId_);

        userStakes[msg.sender][poolId_][tokenId_] = Stake(
            tokenId_,
            weight,
            lockingPeriodInBlocks_,
            block.number,
            rewardPoints,
            false
        );
        userStakedTokenIds[msg.sender][poolId_].push(tokenId_);
        pool.totalStaked += weight;
        userRewardPoints[msg.sender][poolId_] += rewardPoints;
        poolTotalRewardPoints[poolId_] += rewardPoints;

        IERC721(address(recipeNFT)).transferFrom(msg.sender, address(this), tokenId_);
        emit StakeLocked(msg.sender, poolId_, tokenId_, lockingPeriodInBlocks_, rewardPoints);
    }

    // --- Rewards ---
    function calculateRewardPoints(uint256 weight_, uint256 period_, uint256 rate_, uint256 poolId_)
        private
        view
        returns (uint256)
    {
        uint256 booster = poolBoosters[poolId_].endBlock > block.number ? poolBoosters[poolId_].multiplier : 1e18;
        return (weight_ * period_ * rate_ * booster) / 1e18;
    }

    function rewardPerToken(uint256 poolId_) public view returns (uint256) {
        Pool memory pool = pools[poolId_];
        if (pool.totalStaked == 0) return pool.rewardPerTokenStored;
        return
            pool.rewardPerTokenStored +
            ((pool.rewardRatePerSecond * (lastTimeRewardApplicable(poolId_) - pool.updatedAt) * 1e18) /
                pool.totalStaked);
    }

    function earnedContinuous(address account_, uint256 poolId_) public view returns (uint256) {
        bytes32 userPoolKey = getUserPoolKey(account_, poolId_);
        Pool memory pool = pools[poolId_];
        uint256 reward = 0;
        uint256 stakedTokenCount = userStakedTokenIds[account_][poolId_].length;
        uint256 cachedRewardPerToken = rewardPerToken(poolId_);
        for (uint256 i = 0; i < stakedTokenCount; i++) {
            uint256 tokenId = userStakedTokenIds[account_][poolId_][i];
            Stake storage stake = userStakes[account_][poolId_][tokenId];
            reward += ((stake.weight * (cachedRewardPerToken - userRewardPerTokenPaid[account_][poolId_])) / 1e18);
        }
        return reward + continuousRewards[userPoolKey];
    }

    function claimRewards(uint256 poolId_) external nonReentrant updateContinuousReward(msg.sender, poolId_) {
        require(!isEmergencyStopped, "Emergency stop is active");
        require(poolId_ < poolCount, "Invalid pool ID");
        require(pools[poolId_].active, "Pool is not active");

        bytes32 userPoolKey = getUserPoolKey(msg.sender, poolId_);
        uint256 continuousReward = continuousRewards[userPoolKey];
        uint256 lockedReward = 0;

        uint256 stakedTokenCount = userStakedTokenIds[msg.sender][poolId_].length;
        for (uint256 i = 0; i < stakedTokenCount; i++) {
            uint256 tokenId = userStakedTokenIds[msg.sender][poolId_][i];
            Stake storage stake = userStakes[msg.sender][poolId_][tokenId];
            if (!stake.claimed && block.number >= stake.startBlock + stake.lockingPeriodInBlocks) {
                lockedReward += stake.expectedStakingRewardPoints;
                stake.claimed = true;
            }
        }

        uint256 totalReward = continuousReward + lockedReward;
        require(totalReward > 0, "No rewards to claim");
        require(totalRewardFund >= totalReward, "Insufficient reward fund");

        continuousRewards[userPoolKey] = 0;
        userRewardPoints[msg.sender][poolId_] -= lockedReward;
        totalRewardFund -= totalReward;

        require(rewardToken.transfer(msg.sender, totalReward), "Reward transfer failed");

        emit RewardClaimed(msg.sender, poolId_, continuousReward, lockedReward);
    }

    function unlockTokens(uint256 poolId_, uint256 tokenId_) external nonReentrant updateContinuousReward(msg.sender, poolId_) {
        require(!isEmergencyStopped, "Emergency stop is active");
        require(poolId_ < poolCount, "Invalid pool ID");
        require(pools[poolId_].active, "Pool is not active");

        Stake storage stake = userStakes[msg.sender][poolId_][tokenId_];
        require(stake.tokenId == tokenId_, "Token not staked by user");

        Pool storage pool = pools[poolId_];
        bool isMature = block.number >= stake.startBlock + stake.lockingPeriodInBlocks;
        uint256 rewardPoints = 0;

        // Remove token from userStakedTokenIds
        uint256[] storage tokenIds = userStakedTokenIds[msg.sender][poolId_];
        removeTokenFromArray(tokenIds, tokenId_);

        pool.totalStaked -= stake.weight;

        if (isMature && !stake.claimed) {
            // Full reward if mature and not claimed
            rewardPoints = stake.expectedStakingRewardPoints;
            userRewardPoints[msg.sender][poolId_] -= rewardPoints;
            poolTotalRewardPoints[poolId_] -= rewardPoints;
            totalRewardFund -= rewardPoints;
            require(rewardToken.transfer(msg.sender, rewardPoints), "Reward transfer failed");
            emit StakeUnlocked(msg.sender, tokenId_, poolId_, rewardPoints);
        } else if (!isMature) {
            // Apply penalty for early withdrawal
            uint256 penalty = (stake.expectedStakingRewardPoints * pool.earlyWithdrawalPenalty) / 100;
            rewardPoints = stake.expectedStakingRewardPoints - penalty;
            userRewardPoints[msg.sender][poolId_] -= stake.expectedStakingRewardPoints;
            poolTotalRewardPoints[poolId_] -= stake.expectedStakingRewardPoints;
            totalRewardFund -= rewardPoints;
            require(rewardToken.transfer(msg.sender, rewardPoints), "Reward transfer failed");
            emit StakeUnlockedPrematurely(msg.sender, tokenId_, poolId_, penalty);
        } else {
            // No rewards if already claimed
            emit StakeUnlocked(msg.sender, tokenId_, poolId_, 0);
        }

        // Return NFT
        IRecipeNFT recipeNFT = pool.recipeNFT;
        IERC721(address(recipeNFT)).transferFrom(address(this), msg.sender, tokenId_);
        delete userStakes[msg.sender][poolId_][tokenId_];
    }

    // --- Emergency Stop ---
    function emergencyStop() external onlyOwner onlyMultiSig {
        isEmergencyStopped = !isEmergencyStopped;
        emit EmergencyStop(isEmergencyStopped);
    }

    // --- Vesting ---
    function createVestingSchedule(
        address user_,
        uint256 totalAmount_,
        uint256 cliffInBlocks_,
        uint256 durationInBlocks_
    ) external onlyOwner onlyMultiSig {
        require(user_ != address(0), "Invalid user address");
        require(totalAmount_ > 0, "Total amount must be greater than zero");
        require(durationInBlocks_ > 0, "Duration must be greater than zero");

        vestingSchedules[user_] = VestingSchedule(
            totalAmount_,
            block.number + cliffInBlocks_,
            durationInBlocks_,
            block.number
        );

        emit VestingScheduleCreated(user_, totalAmount_, cliffInBlocks_, durationInBlocks_);
    }

    // --- Multi-Sig Functions ---
    function submitSignature(bytes32 hash, bytes memory signature) external {
        require(multiSig.isSigner[msg.sender], "Not a multi-signature signer");
        require(!multiSig.signatures[hash][msg.sender], "Signer has already submitted signature");

        address signer = hash.recover(signature);
        require(multiSig.isSigner[signer], "Invalid signer");
        multiSig.signatures[hash][msg.sender] = true;

        // Check if enough signatures have been collected
        uint256 signatureCount = 0;
        for (uint256 i = 0; i < multiSig.signers.length; i++) {
            if (multiSig.signatures[hash][multiSig.signers[i]]) {
                signatureCount++;
            }
        }

        if (signatureCount >= multiSig.requiredSignatures) {
            // Execute the transaction
            (bool success,) = address(this).call(abi.encodeWithSelector(hash));
            require(success, "Transaction execution failed");

            // Clear signatures after execution
            for (uint256 i = 0; i < multiSig.signers.length; i++) {
                delete multiSig.signatures[hash][multiSig.signers[i]];
            }
        }
    }

    function addRewardFund(uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be greater than zero");
        require(rewardToken.transferFrom(msg.sender, address(this), amount), "Token transfer failed");
        totalRewardFund += amount;
        emit RewardFundAdded(amount);
    }

    function releaseVestedTokens(address user_) external {
        require(user_ != address(0), "Invalid user address");
        VestingSchedule storage schedule = vestingSchedules[user_];
        require(schedule.totalAmount > 0, "No vesting schedule for user");
        require(block.number >= schedule.cliff, "Vesting cliff not reached");

        uint256 vestedAmount = calculateVestedAmount(user_);
        uint256 unreleasedAmount = vestedAmount - releasedTokens[user_];
        require(unreleasedAmount > 0, "No tokens to release");

        releasedTokens[user_] += unreleasedAmount;
        require(rewardToken.transfer(user_, unreleasedAmount), "Token transfer failed");
        emit RewardReleased(user_, unreleasedAmount);
    }

    function calculateVestedAmount(address user_) public view returns (uint256) {
        VestingSchedule storage schedule = vestingSchedules[user_];
        if (block.number >= schedule.start + schedule.duration) {
            return schedule.totalAmount;
        } else {
            return (schedule.totalAmount * (block.number - schedule.start)) / schedule.duration;
        }
    }

    function grantTokens(address user_, uint256 amount_) external onlyOwner {
        require(user_ != address(0), "Invalid user address");
        require(amount_ > 0, "Amount must be greater than zero");
        require(totalRewardFund >= amount_, "Insufficient reward fund");

        grantedTokens[user_] += amount_;
        totalRewardFund -= amount_;
        require(rewardToken.transfer(user_, amount_), "Reward transfer failed");
        emit TokensGranted(user_, amount_);
    }
}
