I'll help create ClaudeToken.sol with a focus on security, optimization, and best practices. Let's break down the development process:

1. First, I'll define the core requirements:
- ERC-20 compliance
- Enhanced security features
- Minting/burning capabilities
- Access control
- Anti-manipulation protections

2. Here's the production-ready code with detailed explanations:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title ClaudeToken
 * @dev Implementation of the ClaudeChain native token with enhanced security features
 * @author ClaudeChain Team
 */
contract ClaudeToken is ERC20, Pausable, AccessControl, ReentrancyGuard {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // Anti-whale transfer limit
    uint256 public maxTransferAmount;
    
    // Mapping to track daily transfer amounts
    mapping(address => uint256) public dailyTransferAmount;
    mapping(address => uint256) public lastTransferTimestamp;

    // Events
    event MaxTransferAmountUpdated(uint256 newAmount);
    event TokensBurned(address indexed burner, uint256 amount);
    event TokensMinted(address indexed to, uint256 amount);

    /**
     * @dev Constructor initializes the token with name, symbol, and roles
     */
    constructor() ERC20("ClaudeToken", "CLAUDE") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
        _setupRole(BURNER_ROLE, msg.sender);
        _setupRole(PAUSER_ROLE, msg.sender);

        // Set initial max transfer amount (10% of total supply)
        maxTransferAmount = 100_000_000 * 10**decimals();
    }

    /**
     * @dev Modifier to check daily transfer limits
     */
    modifier checkTransferLimit(address from, uint256 amount) {
        if (from != address(0) && !hasRole(DEFAULT_ADMIN_ROLE, from)) {
            require(amount <= maxTransferAmount, "Transfer exceeds max amount");
            
            // Reset daily transfer amount if it's a new day
            if (block.timestamp >= lastTransferTimestamp[from] + 24 hours) {
                dailyTransferAmount[from] = 0;
                lastTransferTimestamp[from] = block.timestamp;
            }

            require(
                dailyTransferAmount[from] + amount <= maxTransferAmount,
                "Daily transfer limit exceeded"
            );
            dailyTransferAmount[from] += amount;
        }
        _;
    }

    /**
     * @dev Mints new tokens. Only callable by addresses with MINTER_ROLE.
     */
    function mint(address to, uint256 amount) 
        external 
        onlyRole(MINTER_ROLE) 
        nonReentrant 
    {
        require(to != address(0), "Cannot mint to zero address");
        _mint(to, amount);
        emit TokensMinted(to, amount);
    }

    /**
     * @dev Burns tokens. Only callable by addresses with BURNER_ROLE.
     */
    function burn(address from, uint256 amount) 
        external 
        onlyRole(BURNER_ROLE) 
        nonReentrant 
    {
        require(from != address(0), "Cannot burn from zero address");
        _burn(from, amount);
        emit TokensBurned(from, amount);
    }

    /**
     * @dev Updates the maximum transfer amount. Only admin can call.
     */
    function updateMaxTransferAmount(uint256 newAmount) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        require(newAmount > 0, "Invalid transfer amount");
        maxTransferAmount = newAmount;
        emit MaxTransferAmountUpdated(newAmount);
    }

    /**
     * @dev Pauses token transfers. Only PAUSER_ROLE can call.
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @dev Unpauses token transfers. Only PAUSER_ROLE can call.
     */
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
     * @dev Override transfer function to add transfer limits and pausability
     */
    function transfer(address to, uint256 amount)
        public
        override
        whenNotPaused
        checkTransferLimit(msg.sender, amount)
        returns (bool)
    {
        return super.transfer(to, amount);
    }

    /**
     * @dev Override transferFrom function to add transfer limits and pausability
     */
    function transferFrom(address from, address to, uint256 amount)
        public
        override
        whenNotPaused
        checkTransferLimit(from, amount)
        returns (bool)
    {
        return super.transferFrom(from, to, amount);
    }

    /**
     * @dev Required override for AccessControl interface
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
```

Key security features and design decisions:

1. **Access Control**:
- Implemented role-based access using OpenZeppelin's AccessControl
- Separate roles for minting, burning, and pausing
- Only authorized addresses can perform privileged operations

2. **Security Measures**:
- ReentrancyGuard for mint/burn functions
- Pausable functionality for emergency stops
- Transfer limits to prevent whale manipulation
- Daily transfer limits
- Zero address checks

3. **Gas Optimization**:
- Efficient use of modifiers
- Minimal storage operations
- Optimized checks in transfer limits

4. **Error Handling**:
- Comprehensive require statements
- Clear error messages
- Event emissions for important state changes

5. **Enhanced Features**:
- Anti-whale mechanism with maxTransferAmount
- Daily transfer tracking
- Pausable transfers
- Detailed event logging

To deploy this contract:
1. Install OpenZeppelin dependencies
2. Deploy using a secure wallet
3. Set up initial roles and transfer limits
4. Verify the contract on the blockchain explorer

Let me know if you need any clarification or have questions about specific parts of the implementation!