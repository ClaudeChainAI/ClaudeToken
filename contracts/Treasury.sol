I'll help develop the Treasury.sol contract with security and best practices in mind. Let me walk you through the development process.

First, let's outline the key requirements and features for a protocol treasury:
1. Secure fund management
2. Role-based access control
3. Support for native token and ERC20 tokens
4. Emergency functions
5. Withdrawal limits and timelock mechanisms

Here's the production-ready code with detailed comments:

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
 * @notice Manages protocol treasury funds with role-based access and security measures
 * @dev Implements timelock and withdrawal limits for enhanced security
 */
contract Treasury is AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    // Role definitions
    bytes32 public constant TREASURER_ROLE = keccak256("TREASURER_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");

    // Withdrawal limits
    uint256 public constant MAX_WITHDRAWAL = 1000 ether;
    uint256 public constant TIMELOCK_DURATION = 24 hours;

    // Withdrawal request structure
    struct WithdrawalRequest {
        address recipient;
        uint256 amount;
        uint256 timestamp;
        bool isERC20;
        address tokenAddress;
        bool executed;
    }

    // State variables
    mapping(uint256 => WithdrawalRequest) public withdrawalRequests;
    uint256 public nextRequestId;
    mapping(address => uint256) public dailyWithdrawals;
    mapping(address => uint256) public lastWithdrawalDay;

    // Events
    event WithdrawalRequested(
        uint256 indexed requestId,
        address recipient,
        uint256 amount,
        address tokenAddress
    );
    event WithdrawalExecuted(
        uint256 indexed requestId,
        address recipient,
        uint256 amount
    );
    event FundsReceived(address indexed sender, uint256 amount);

    /**
     * @dev Constructor sets up initial roles
     * @param admin Address of the initial admin
     */
    constructor(address admin) {
        require(admin != address(0), "Invalid admin address");
        _setupRole(DEFAULT_ADMIN_ROLE, admin);
        _setupRole(TREASURER_ROLE, admin);
        _setupRole(EMERGENCY_ROLE, admin);
    }

    /**
     * @dev Receive function to accept native token payments
     */
    receive() external payable {
        emit FundsReceived(msg.sender, msg.value);
    }

    /**
     * @dev Request a withdrawal with timelock
     * @param recipient Address to receive funds
     * @param amount Amount to withdraw
     * @param tokenAddress Address of ERC20 token (address(0) for native token)
     */
    function requestWithdrawal(
        address recipient,
        uint256 amount,
        address tokenAddress
    ) external onlyRole(TREASURER_ROLE) whenNotPaused returns (uint256) {
        require(recipient != address(0), "Invalid recipient");
        require(amount > 0, "Invalid amount");
        
        // Check daily withdrawal limits
        uint256 today = block.timestamp / 1 days;
        if (lastWithdrawalDay[recipient] < today) {
            dailyWithdrawals[recipient] = 0;
            lastWithdrawalDay[recipient] = today;
        }
        
        require(
            dailyWithdrawals[recipient] + amount <= MAX_WITHDRAWAL,
            "Exceeds daily limit"
        );

        uint256 requestId = nextRequestId++;
        withdrawalRequests[requestId] = WithdrawalRequest({
            recipient: recipient,
            amount: amount,
            timestamp: block.timestamp,
            isERC20: tokenAddress != address(0),
            tokenAddress: tokenAddress,
            executed: false
        });

        emit WithdrawalRequested(requestId, recipient, amount, tokenAddress);
        return requestId;
    }

    /**
     * @dev Execute a pending withdrawal after timelock
     * @param requestId ID of the withdrawal request
     */
    function executeWithdrawal(uint256 requestId) 
        external 
        onlyRole(TREASURER_ROLE) 
        nonReentrant 
        whenNotPaused 
    {
        WithdrawalRequest storage request = withdrawalRequests[requestId];
        require(!request.executed, "Already executed");
        require(
            block.timestamp >= request.timestamp + TIMELOCK_DURATION,
            "Timelock active"
        );

        request.executed = true;
        dailyWithdrawals[request.recipient] += request.amount;

        if (request.isERC20) {
            IERC20 token = IERC20(request.tokenAddress);
            require(
                token.balanceOf(address(this)) >= request.amount,
                "Insufficient balance"
            );
            token.safeTransfer(request.recipient, request.amount);
        } else {
            require(
                address(this).balance >= request.amount,
                "Insufficient balance"
            );
            (bool success, ) = request.recipient.call{value: request.amount}("");
            require(success, "Transfer failed");
        }

        emit WithdrawalExecuted(requestId, request.recipient, request.amount);
    }

    /**
     * @dev Emergency withdrawal of all funds to safe address
     * @param safeAddress Address to receive funds
     */
    function emergencyWithdraw(address safeAddress) 
        external 
        onlyRole(EMERGENCY_ROLE) 
    {
        require(safeAddress != address(0), "Invalid safe address");
        uint256 balance = address(this).balance;
        if (balance > 0) {
            (bool success, ) = safeAddress.call{value: balance}("");
            require(success, "Transfer failed");
        }
    }

    /**
     * @dev Emergency withdrawal of ERC20 tokens
     * @param token Address of ERC20 token
     * @param safeAddress Address to receive tokens
     */
    function emergencyWithdrawERC20(
        address token,
        address safeAddress
    ) external onlyRole(EMERGENCY_ROLE) {
        require(safeAddress != address(0), "Invalid safe address");
        require(token != address(0), "Invalid token address");
        
        IERC20 tokenContract = IERC20(token);
        uint256 balance = tokenContract.balanceOf(address(this));
        if (balance > 0) {
            tokenContract.safeTransfer(safeAddress, balance);
        }
    }

    /**
     * @dev Pause all non-emergency functions
     */
    function pause() external onlyRole(EMERGENCY_ROLE) {
        _pause();
    }

    /**
     * @dev Unpause all non-emergency functions
     */
    function unpause() external onlyRole(EMERGENCY_ROLE) {
        _unpause();
    }
}
```

Key design decisions and security measures:

1. **Access Control**:
- Used OpenZeppelin's AccessControl for role-based permissions
- Separate roles for treasury operations and emergency functions

2. **Security Features**:
- ReentrancyGuard to prevent reentrancy attacks
- Pausable functionality for emergency situations
- Timelock mechanism for withdrawals
- Daily withdrawal limits
- Safe transfer patterns for ERC20 tokens

3. **Error Handling**:
- Comprehensive require statements
- Clear error messages
- Input validation

4. **Gas Optimization**:
- Efficient state variable usage
- Minimal storage operations
- Used mappings for O(1) lookups

5. **Additional Features**:
- Support for both native token and ERC20 tokens
- Emergency withdrawal functions
- Event emission for important actions
- Daily withdrawal tracking

The contract implements a two-step withdrawal process:
1. Request withdrawal (creates timelock)
2. Execute withdrawal (after timelock period)

This provides additional security and allows for monitoring of large withdrawals before they're executed.

To deploy this contract:
1. Ensure OpenZeppelin dependencies are installed
2. Deploy with initial admin address
3. Set up additional role holders as needed
4. Test all functions thoroughly, especially emergency functions