I'll help create a secure and optimized ERC-20 token contract for ClaudeChain. Let's build this step by step.

First, here's the complete code for ClaudeToken.sol:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title ClaudeToken
 * @dev Implementation of the ClaudeChain native token
 * @custom:security-contact security@claudechain.io
 */
contract ClaudeToken is ERC20, ERC20Burnable, Pausable, AccessControl, ReentrancyGuard {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    
    uint256 public constant INITIAL_SUPPLY = 1_000_000_000 * 10**18; // 1 billion tokens
    uint256 public constant MAX_SUPPLY = 2_000_000_000 * 10**18; // 2 billion tokens
    
    // Events
    event MinterAdded(address indexed account);
    event MinterRemoved(address indexed account);
    event TokensMinted(address indexed to, uint256 amount);
    event TokensBurned(address indexed from, uint256 amount);

    /**
     * @dev Contract initializer
     * @notice Sets up initial roles and mints initial supply
     */
    constructor() ERC20("ClaudeToken", "CLAUDE") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
        _setupRole(PAUSER_ROLE, msg.sender);
        
        _mint(msg.sender, INITIAL_SUPPLY);
    }

    /**
     * @dev Mints new tokens
     * @param to Address to receive the tokens
     * @param amount Amount of tokens to mint
     * Requirements:
     * - Caller must have MINTER_ROLE
     * - Total supply after minting must not exceed MAX_SUPPLY
     */
    function mint(address to, uint256 amount) 
        external 
        onlyRole(MINTER_ROLE) 
        whenNotPaused 
        nonReentrant 
    {
        require(to != address(0), "Invalid address");
        require(totalSupply() + amount <= MAX_SUPPLY, "Would exceed max supply");
        
        _mint(to, amount);
        emit TokensMinted(to, amount);
    }

    /**
     * @dev Burns tokens from the caller's account
     * @param amount Amount of tokens to burn
     */
    function burn(uint256 amount) 
        public 
        virtual 
        override 
        whenNotPaused 
        nonReentrant 
    {
        super.burn(amount);
        emit TokensBurned(_msgSender(), amount);
    }

    /**
     * @dev Pauses all token transfers
     * Requirements:
     * - Caller must have PAUSER_ROLE
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @dev Unpauses all token transfers
     * Requirements:
     * - Caller must have PAUSER_ROLE
     */
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
     * @dev Hook that is called before any transfer of tokens
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override whenNotPaused {
        super._beforeTokenTransfer(from, to, amount);
    }
}
```

Key Design Decisions and Security Features:

1. **Inheritance Structure**:
- Used OpenZeppelin's battle-tested contracts as base
- Implemented ERC20, ERC20Burnable, Pausable, AccessControl, and ReentrancyGuard

2. **Security Measures**:
- Role-based access control for critical functions
- ReentrancyGuard to prevent reentrancy attacks
- Pausable functionality for emergency situations
- Input validation for critical parameters
- Events for important state changes

3. **Supply Management**:
- Fixed initial supply of 1 billion tokens
- Maximum cap of 2 billion tokens
- Controlled minting through MINTER_ROLE

4. **Gas Optimization**:
- Efficient use of storage variables
- Minimal state changes
- Use of constant values where possible

5. **Error Handling**:
- Explicit require statements with clear error messages
- Proper access control checks
- Safe math operations (implicit in Solidity ^0.8.0)

To deploy this contract:

1. Install dependencies:
```bash
npm install @openzeppelin/contracts
```

2. Compile:
```bash
npx hardhat compile
```

3. Deploy script (example):
```javascript
const ClaudeToken = await ethers.getContractFactory("ClaudeToken");
const claudeToken = await ClaudeToken.deploy();
await claudeToken.deployed();
```

Additional considerations for production:

1. Add comprehensive unit tests
2. Conduct security audits
3. Implement gradual rollout strategy
4. Set up monitoring for events
5. Create documentation for token economics

Would you like me to elaborate on any of these aspects or provide additional features?