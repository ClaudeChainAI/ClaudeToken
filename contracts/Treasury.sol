I'll help develop the Treasury.sol contract with a focus on security, efficiency, and maintainability. Let's break down the development process:

1. First, let's outline the key features needed for a protocol treasury:
- Secure fund management
- Access control
- Multiple asset support (ETH + ERC20)
- Emergency functions
- Transparent accounting

2. Here's the production-ready code with detailed explanations:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title ClaudeChain Treasury
 * @dev Manages protocol treasury funds with multi-role access control
 * @author Claude AI Blockchain Team
 */
contract Treasury is AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    // Role definitions
    bytes32 public constant TREASURY_ADMIN_ROLE = keccak256("TREASURY_ADMIN_ROLE");
    bytes32 public constant SPENDER_ROLE = keccak256("SPENDER_ROLE");

    // Events
    event FundsDeposited(address indexed token, address indexed from, uint256 amount);
    event FundsWithdrawn(address indexed token, address indexed to, uint256 amount);
    event EmergencyWithdrawal(address indexed token, address indexed to, uint256 amount);
    event SpendingLimitUpdated(address indexed token, uint256 newLimit);

    // Spending limits per token
    mapping(address => uint256) public dailySpendingLimits;
    mapping(address => uint256) public dailySpentAmount;
    mapping(address => uint256) public lastSpendingDay;

    // Constants
    uint256 private constant ONE_DAY = 1 days;
    address private constant ETH_ADDRESS = address(0);

    /**
     * @dev Constructor sets up initial roles
     * @param admin Address of the initial admin
     */
    constructor(address admin) {
        require(admin != address(0), "Invalid admin address");
        
        _setupRole(DEFAULT_ADMIN_ROLE, admin);
        _setupRole(TREASURY_ADMIN_ROLE, admin);
    }

    /**
     * @dev Receive function to accept ETH
     */
    receive() external payable {
        emit FundsDeposited(ETH_ADDRESS, msg.sender, msg.value);
    }

    /**
     * @dev Deposits ERC20 tokens into the treasury
     * @param token Address of the ERC20 token
     * @param amount Amount to deposit
     */
    function depositToken(address token, uint256 amount) external nonReentrant {
        require(token != address(0), "Invalid token address");
        require(amount > 0, "Amount must be greater than 0");

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        emit FundsDeposited(token, msg.sender, amount);
    }

    /**
     * @dev Withdraws funds from the treasury
     * @param token Address of the token (0x0 for ETH)
     * @param to Recipient address
     * @param amount Amount to withdraw
     */
    function withdraw(
        address token,
        address to,
        uint256 amount
    ) external nonReentrant whenNotPaused onlyRole(SPENDER_ROLE) {
        require(to != address(0), "Invalid recipient");
        require(amount > 0, "Amount must be greater than 0");
        
        _checkAndUpdateSpendingLimit(token, amount);

        if (token == ETH_ADDRESS) {
            (bool success, ) = to.call{value: amount}("");
            require(success, "ETH transfer failed");
        } else {
            IERC20(token).safeTransfer(to, amount);
        }

        emit FundsWithdrawn(token, to, amount);
    }

    /**
     * @dev Updates daily spending limit for a token
     * @param token Address of the token
     * @param newLimit New daily spending limit
     */
    function updateSpendingLimit(
        address token,
        uint256 newLimit
    ) external onlyRole(TREASURY_ADMIN_ROLE) {
        dailySpendingLimits[token] = newLimit;
        emit SpendingLimitUpdated(token, newLimit);
    }

    /**
     * @dev Emergency withdrawal of all funds of a specific token
     * @param token Address of the token
     * @param to Recipient address
     */
    function emergencyWithdraw(
        address token,
        address to
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(to != address(0), "Invalid recipient");

        uint256 amount;
        if (token == ETH_ADDRESS) {
            amount = address(this).balance;
            (bool success, ) = to.call{value: amount}("");
            require(success, "ETH transfer failed");
        } else {
            amount = IERC20(token).balanceOf(address(this));
            IERC20(token).safeTransfer(to, amount);
        }

        emit EmergencyWithdrawal(token, to, amount);
    }

    /**
     * @dev Checks and updates daily spending limits
     * @param token Token address
     * @param amount Amount to spend
     */
    function _checkAndUpdateSpendingLimit(address token, uint256 amount) internal {
        uint256 limit = dailySpendingLimits[token];
        if (limit > 0) {
            uint256 currentDay = block.timestamp / ONE_DAY;
            if (currentDay > lastSpendingDay[token]) {
                dailySpentAmount[token] = 0;
                lastSpendingDay[token] = currentDay;
            }
            
            require(
                dailySpentAmount[token] + amount <= limit,
                "Daily spending limit exceeded"
            );
            
            dailySpentAmount[token] += amount;
        }
    }

    /**
     * @dev Returns the balance of a specific token
     * @param token Address of the token
     */
    function getBalance(address token) external view returns (uint256) {
        if (token == ETH_ADDRESS) {
            return address(this).balance;
        }
        return IERC20(token).balanceOf(address(this));
    }

    /**
     * @dev Pauses all non-admin functions
     */
    function pause() external onlyRole(TREASURY_ADMIN_ROLE) {
        _pause();
    }

    /**
     * @dev Unpauses all non-admin functions
     */
    function unpause() external onlyRole(TREASURY_ADMIN_ROLE) {
        _unpause();
    }
}
```

Key security features and design decisions:

1. Access Control:
- Used OpenZeppelin's AccessControl for role-based permissions
- Separate roles for admin and spender functions
- Emergency functions restricted to admin only

2. Security Measures:
- ReentrancyGuard to prevent reentrancy attacks
- Pausable functionality for emergency situations
- SafeERC20 for safe token transfers
- Comprehensive input validation
- Daily spending limits with automatic resets

3. Gas Optimization:
- Efficient storage usage
- Minimal state changes
- Use of constant values
- Optimized function modifiers

4. Error Handling:
- Detailed require statements
- Clear error messages
- Event emissions for important state changes

5. Additional Features:
- Support for both ETH and ERC20 tokens
- Daily spending limits with automatic reset
- Emergency withdrawal function
- Balance checking functionality
- Transparent event logging

To deploy this contract:
1. Install OpenZeppelin dependencies
2. Deploy with an initial admin address
3. Set up additional roles and spending limits
4. Test all functions thoroughly

The contract is designed to be:
- Secure against common attacks
- Flexible for future upgrades
- Easy to maintain
- Gas efficient
- Well-documented

Would you like me to explain any specific part in more detail?