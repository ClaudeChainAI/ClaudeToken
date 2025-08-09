I'll help create the Mining.sol contract for ClaudeChain. Let's break this down into steps and implement it with best practices.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title ClaudeChain Mining Contract
 * @dev Manages mining operations and reward distribution for ClaudeChain
 * @notice This contract handles token mining mechanics and distributes rewards
 */
contract Mining is Ownable, ReentrancyGuard, Pausable {
    // State variables
    IERC20 public immutable rewardToken;
    
    uint256 public constant BLOCKS_PER_EPOCH = 50400; // ~7 days at 12 sec blocks
    uint256 public constant INITIAL_REWARD_PER_BLOCK = 100 ether; // 100 tokens
    uint256 public constant HALVING_PERIOD = 1051200; // ~4 years worth of blocks
    
    uint256 public lastRewardBlock;
    uint256 public accRewardPerShare;
    uint256 public totalStaked;
    
    // Structs
    struct UserInfo {
        uint256 amount;          // How many tokens the user has staked
        uint256 rewardDebt;      // Reward debt
        uint256 lastClaimBlock;  // Last block number when rewards were claimed
    }
    
    // Mappings
    mapping(address => UserInfo) public userInfo;
    
    // Events
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 reward);
    
    /**
     * @dev Constructor sets the reward token address
     * @param _rewardToken Address of the ERC20 token used for rewards
     */
    constructor(address _rewardToken) {
        require(_rewardToken != address(0), "Invalid token address");
        rewardToken = IERC20(_rewardToken);
        lastRewardBlock = block.number;
    }
    
    /**
     * @dev Calculates current block reward based on halving schedule
     * @return Current reward per block
     */
    function getCurrentBlockReward() public view returns (uint256) {
        uint256 halvings = (block.number - lastRewardBlock) / HALVING_PERIOD;
        if (halvings >= 64) return 0; // After 64 halvings, reward becomes 0
        return INITIAL_REWARD_PER_BLOCK >> halvings;
    }
    
    /**
     * @dev Updates reward variables
     */
    function updatePool() public {
        if (block.number <= lastRewardBlock) return;
        
        if (totalStaked == 0) {
            lastRewardBlock = block.number;
            return;
        }
        
        uint256 multiplier = block.number - lastRewardBlock;
        uint256 reward = multiplier * getCurrentBlockReward();
        accRewardPerShare += (reward * 1e12) / totalStaked;
        lastRewardBlock = block.number;
    }
    
    /**
     * @dev Stakes tokens into the mining contract
     * @param _amount Amount of tokens to stake
     */
    function stake(uint256 _amount) external nonReentrant whenNotPaused {
        require(_amount > 0, "Cannot stake 0");
        
        updatePool();
        UserInfo storage user = userInfo[msg.sender];
        
        if (user.amount > 0) {
            uint256 pending = (user.amount * accRewardPerShare / 1e12) - user.rewardDebt;
            if (pending > 0) {
                safeRewardTransfer(msg.sender, pending);
                emit RewardClaimed(msg.sender, pending);
            }
        }
        
        require(rewardToken.transferFrom(msg.sender, address(this), _amount), "Transfer failed");
        user.amount += _amount;
        user.rewardDebt = user.amount * accRewardPerShare / 1e12;
        totalStaked += _amount;
        
        emit Staked(msg.sender, _amount);
    }
    
    /**
     * @dev Withdraws staked tokens
     * @param _amount Amount of tokens to withdraw
     */
    function withdraw(uint256 _amount) external nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        require(user.amount >= _amount, "Insufficient balance");
        
        updatePool();
        
        uint256 pending = (user.amount * accRewardPerShare / 1e12) - user.rewardDebt;
        if (pending > 0) {
            safeRewardTransfer(msg.sender, pending);
            emit RewardClaimed(msg.sender, pending);
        }
        
        if (_amount > 0) {
            user.amount -= _amount;
            totalStaked -= _amount;
            require(rewardToken.transfer(msg.sender, _amount), "Transfer failed");
            emit Withdrawn(msg.sender, _amount);
        }
        
        user.rewardDebt = user.amount * accRewardPerShare / 1e12;
    }
    
    /**
     * @dev Claims pending rewards
     */
    function claimRewards() external nonReentrant {
        updatePool();
        UserInfo storage user = userInfo[msg.sender];
        uint256 pending = (user.amount * accRewardPerShare / 1e12) - user.rewardDebt;
        
        require(pending > 0, "No rewards to claim");
        
        user.rewardDebt = user.amount * accRewardPerShare / 1e12;
        safeRewardTransfer(msg.sender, pending);
        
        emit RewardClaimed(msg.sender, pending);
    }
    
    /**
     * @dev Safe reward transfer function, just in case if rounding error causes pool to not have enough tokens
     */
    function safeRewardTransfer(address _to, uint256 _amount) internal {
        uint256 balance = rewardToken.balanceOf(address(this));
        if (_amount > balance) {
            require(rewardToken.transfer(_to, balance), "Transfer failed");
        } else {
            require(rewardToken.transfer(_to, _amount), "Transfer failed");
        }
    }
    
    /**
     * @dev Returns pending rewards for a user
     * @param _user Address of the user
     * @return Pending reward amount
     */
    function pendingRewards(address _user) external view returns (uint256) {
        UserInfo storage user = userInfo[_user];
        uint256 _accRewardPerShare = accRewardPerShare;
        
        if (block.number > lastRewardBlock && totalStaked != 0) {
            uint256 multiplier = block.number - lastRewardBlock;
            uint256 reward = multiplier * getCurrentBlockReward();
            _accRewardPerShare += (reward * 1e12) / totalStaked;
        }
        
        return (user.amount * _accRewardPerShare / 1e12) - user.rewardDebt;
    }
    
    // Emergency functions
    function pause() external onlyOwner {
        _pause();
    }
    
    function unpause() external onlyOwner {
        _unpause();
    }
}
```

Key design decisions and features:

1. **Security Features**:
- Used OpenZeppelin's ReentrancyGuard to prevent reentrancy attacks
- Implemented Pausable for emergency situations
- Safe math operations using Solidity 0.8.x
- Safe transfer function to handle edge cases
- Ownership controls for admin functions

2. **Gas Optimization**:
- Used immutable for constant values
- Minimized storage operations
- Efficient reward calculation mechanism
- Batched updates in single transactions

3. **Error Handling**:
- Comprehensive require statements
- Clear error messages
- Safely handles edge cases in reward distribution

4. **Mining Mechanics**:
- Block-based reward system
- Halving mechanism every ~4 years
- Accurate reward tracking per user
- Fair distribution based on stake amount

5. **Features**:
- Staking mechanism
- Reward distribution
- Withdrawal functionality
- Pending reward calculation
- Emergency pause/unpause

To deploy this contract:
1. Deploy the reward token contract first
2. Deploy this Mining contract with the reward token address
3. Transfer initial reward tokens to the Mining contract
4. Users can then stake tokens and earn rewards

The contract uses a block-based reward system with halving periods similar to Bitcoin, but adapted for ClaudeChain's specific needs. The reward calculation is done per block and distributed proportionally to stakers based on their stake amount.