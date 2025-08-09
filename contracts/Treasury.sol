I'll help build a secure and optimized Treasury contract for ClaudeChain. Let's break down the development process:

1. First, let's identify the key requirements:
- Secure fund management
- Access control
- Multiple token support (native + ERC20)
- Emergency mechanisms
- Transparent transaction logging

2. Key security considerations:
- Reentrancy protection
- Role-based access control
- Circuit breakers
- Input validation
- Secure withdrawal patterns

Here's the production-ready Treasury.sol:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title ClaudeChain Treasury
 * @dev Manages protocol treasury funds with role-based access control
 * and secure fund management
 */
contract Treasury is ReentrancyGuard, AccessControl {
    using SafeERC20 for IERC20;

    // Role definitions
    bytes32 public constant TREASURER_ROLE = keccak256("TREASURER_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");

    // State variables
    bool public isPaused;
    uint256 public withdrawalLimit;
    mapping(address => uint256) public dailyWithdrawals;
    mapping(address => uint256) public lastWithdrawalDay;

    // Events
    event FundsDeposited(address indexed sender, uint256 amount);
    event FundsWithdrawn(address indexed recipient, uint256 amount);
    event TokensWithdrawn(address indexed token, address indexed recipient, uint256 amount);
    event WithdrawalLimitUpdated(uint256 newLimit);
    event EmergencyPause(address indexed triggeredBy);
    event EmergencyUnpause(address indexed triggeredBy);

    // Custom errors
    error InsufficientBalance();
    error WithdrawalLimitExceeded();
    error ContractPaused();
    error InvalidAmount();
    error TransferFailed();

    /**
     * @dev Constructor sets up initial roles and withdrawal limit
     * @param _admin Address of the initial admin
     * @param _initialWithdrawalLimit Initial daily withdrawal limit
     */
    constructor(address _admin, uint256 _initialWithdrawalLimit) {
        require(_admin != address(0), "Invalid admin address");
        require(_initialWithdrawalLimit > 0, "Invalid withdrawal limit");

        _setupRole(DEFAULT_ADMIN_ROLE, _admin);
        _setupRole(TREASURER_ROLE, _admin);
        _setupRole(EMERGENCY_ROLE, _admin);

        withdrawalLimit = _initialWithdrawalLimit;
        isPaused = false;
    }

    /**
     * @dev Allows the contract to receive native tokens
     */
    receive() external payable {
        emit FundsDeposited(msg.sender, msg.value);
    }

    /**
     * @dev Deposits native tokens into the treasury
     */
    function deposit() external payable {
        if (msg.value == 0) revert InvalidAmount();
        emit FundsDeposited(msg.sender, msg.value);
    }

    /**
     * @dev Withdraws native tokens from the treasury
     * @param _recipient Address to receive the funds
     * @param _amount Amount to withdraw
     */
    function withdrawNative(address _recipient, uint256 _amount) 
        external 
        nonReentrant 
        onlyRole(TREASURER_ROLE) 
    {
        if (isPaused) revert ContractPaused();
        if (_amount == 0) revert InvalidAmount();
        if (address(this).balance < _amount) revert InsufficientBalance();
        
        uint256 currentDay = block.timestamp / 1 days;
        if (lastWithdrawalDay[_recipient] < currentDay) {
            dailyWithdrawals[_recipient] = 0;
            lastWithdrawalDay[_recipient] = currentDay;
        }

        if (dailyWithdrawals[_recipient] + _amount > withdrawalLimit) {
            revert WithdrawalLimitExceeded();
        }

        dailyWithdrawals[_recipient] += _amount;

        (bool success, ) = _recipient.call{value: _amount}("");
        if (!success) revert TransferFailed();

        emit FundsWithdrawn(_recipient, _amount);
    }

    /**
     * @dev Withdraws ERC20 tokens from the treasury
     * @param _token Token address
     * @param _recipient Recipient address
     * @param _amount Amount to withdraw
     */
    function withdrawToken(
        address _token,
        address _recipient,
        uint256 _amount
    ) external nonReentrant onlyRole(TREASURER_ROLE) {
        if (isPaused) revert ContractPaused();
        if (_amount == 0) revert InvalidAmount();

        uint256 currentDay = block.timestamp / 1 days;
        if (lastWithdrawalDay[_recipient] < currentDay) {
            dailyWithdrawals[_recipient] = 0;
            lastWithdrawalDay[_recipient] = currentDay;
        }

        if (dailyWithdrawals[_recipient] + _amount > withdrawalLimit) {
            revert WithdrawalLimitExceeded();
        }

        dailyWithdrawals[_recipient] += _amount;

        IERC20(_token).safeTransfer(_recipient, _amount);
        emit TokensWithdrawn(_token, _recipient, _amount);
    }

    /**
     * @dev Updates the daily withdrawal limit
     * @param _newLimit New withdrawal limit
     */
    function updateWithdrawalLimit(uint256 _newLimit) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        require(_newLimit > 0, "Invalid limit");
        withdrawalLimit = _newLimit;
        emit WithdrawalLimitUpdated(_newLimit);
    }

    /**
     * @dev Emergency pause of all withdrawals
     */
    function emergencyPause() external onlyRole(EMERGENCY_ROLE) {
        isPaused = true;
        emit EmergencyPause(msg.sender);
    }

    /**
     * @dev Unpause withdrawals
     */
    function emergencyUnpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        isPaused = false;
        emit EmergencyUnpause(msg.sender);
    }

    /**
     * @dev Returns the current balance of native tokens
     */
    function getNativeBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /**
     * @dev Returns the current balance of an ERC20 token
     * @param _token Token address
     */
    function getTokenBalance(address _token) external view returns (uint256) {
        return IERC20(_token).balanceOf(address(this));
    }
}
```

Key design decisions and features:

1. Security:
- Used OpenZeppelin's ReentrancyGuard
- Implemented role-based access control
- Added withdrawal limits
- Emergency pause functionality
- Custom error handling
- Input validation

2. Gas Optimization:
- Used custom errors instead of strings
- Efficient storage usage
- Minimal state changes
- Optimized access control checks

3. Features:
- Support for both native and ERC20 tokens
- Daily withdrawal limits
- Emergency controls
- Transparent event logging
- Balance checking functions

4. Best Practices:
- Comprehensive documentation
- Clear function organization
- Secure withdrawal pattern
- Safe ERC20 token handling

To deploy this contract:
1. Install OpenZeppelin dependencies
2. Deploy with an admin address and initial withdrawal limit
3. Grant necessary roles to other addresses
4. Monitor events for transparency

The contract can be extended with additional features in future phases:
- Multi-signature requirements
- Investment strategies
- Automated distribution
- More sophisticated access controls

Let me know if you need any clarification or have questions about specific parts of the implementation!