I'll help build a secure and gas-optimized price oracle contract for ClaudeChain. Let's break down the development process:

1. First, let's establish the core requirements:
- Decentralized price feeds
- Protection against price manipulation
- Freshness checks for price data
- Access control for authorized updaters
- Gas-efficient storage and updates

Here's the production-ready oracle implementation with detailed comments:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title ClaudeChain Price Oracle
 * @dev Secure price oracle implementation for ClaudeChain DeFi features
 * @notice This contract manages price feeds for various assets
 */
contract ClaudeChainOracle is AccessControl, ReentrancyGuard, Pausable {
    // Role definitions
    bytes32 public constant ORACLE_UPDATER_ROLE = keccak256("ORACLE_UPDATER_ROLE");
    bytes32 public constant ADMIN_ROLE = DEFAULT_ADMIN_ROLE;

    // Struct to store price data with metadata
    struct PriceData {
        uint256 price;           // Price with 18 decimals
        uint256 timestamp;       // Last update timestamp
        uint256 heartbeat;       // Maximum time between updates
        bool isActive;           // Whether this price feed is active
    }

    // Maximum allowed heartbeat (24 hours)
    uint256 public constant MAX_HEARTBEAT = 24 hours;
    
    // Minimum number of decimals for price data
    uint256 public constant PRICE_DECIMALS = 18;

    // Mapping from asset symbol to price data
    mapping(bytes32 => PriceData) public prices;

    // Events
    event PriceUpdated(bytes32 indexed symbol, uint256 price, uint256 timestamp);
    event HeartbeatUpdated(bytes32 indexed symbol, uint256 heartbeat);
    event PriceFeedActivated(bytes32 indexed symbol);
    event PriceFeedDeactivated(bytes32 indexed symbol);

    // Custom errors
    error InvalidPrice();
    error StalePrice(bytes32 symbol);
    error InvalidHeartbeat();
    error PriceFeedNotActive();
    error UnauthorizedAccess();

    /**
     * @dev Constructor to set up initial roles
     * @param admin Address of the admin
     */
    constructor(address admin) {
        _setupRole(ADMIN_ROLE, admin);
        _setRoleAdmin(ORACLE_UPDATER_ROLE, ADMIN_ROLE);
    }

    /**
     * @dev Updates price for a given asset
     * @param symbol Asset symbol (as bytes32)
     * @param newPrice New price value (with 18 decimals)
     */
    function updatePrice(bytes32 symbol, uint256 newPrice) 
        external 
        onlyRole(ORACLE_UPDATER_ROLE) 
        whenNotPaused 
        nonReentrant 
    {
        if (newPrice == 0) revert InvalidPrice();
        if (!prices[symbol].isActive) revert PriceFeedNotActive();

        prices[symbol].price = newPrice;
        prices[symbol].timestamp = block.timestamp;

        emit PriceUpdated(symbol, newPrice, block.timestamp);
    }

    /**
     * @dev Gets the current price for an asset
     * @param symbol Asset symbol (as bytes32)
     * @return Current price and timestamp
     */
    function getPrice(bytes32 symbol) 
        external 
        view 
        returns (uint256 price, uint256 timestamp) 
    {
        PriceData memory data = prices[symbol];
        
        if (!data.isActive) revert PriceFeedNotActive();
        if (block.timestamp - data.timestamp > data.heartbeat) {
            revert StalePrice(symbol);
        }

        return (data.price, data.timestamp);
    }

    /**
     * @dev Activates a new price feed
     * @param symbol Asset symbol (as bytes32)
     * @param heartbeat Maximum time between updates
     */
    function activatePriceFeed(bytes32 symbol, uint256 heartbeat) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        if (heartbeat == 0 || heartbeat > MAX_HEARTBEAT) revert InvalidHeartbeat();

        prices[symbol].isActive = true;
        prices[symbol].heartbeat = heartbeat;

        emit PriceFeedActivated(symbol);
        emit HeartbeatUpdated(symbol, heartbeat);
    }

    /**
     * @dev Deactivates a price feed
     * @param symbol Asset symbol (as bytes32)
     */
    function deactivatePriceFeed(bytes32 symbol) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        prices[symbol].isActive = false;
        emit PriceFeedDeactivated(symbol);
    }

    /**
     * @dev Updates heartbeat for a price feed
     * @param symbol Asset symbol (as bytes32)
     * @param newHeartbeat New heartbeat value
     */
    function updateHeartbeat(bytes32 symbol, uint256 newHeartbeat) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        if (newHeartbeat == 0 || newHeartbeat > MAX_HEARTBEAT) revert InvalidHeartbeat();
        if (!prices[symbol].isActive) revert PriceFeedNotActive();

        prices[symbol].heartbeat = newHeartbeat;
        emit HeartbeatUpdated(symbol, newHeartbeat);
    }

    /**
     * @dev Pauses the contract
     */
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    /**
     * @dev Unpauses the contract
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }
}
```

Key design decisions and security considerations:

1. **Access Control**:
- Using OpenZeppelin's AccessControl for role-based permissions
- Separate roles for admins and price updaters
- Only authorized updaters can modify prices

2. **Security Features**:
- ReentrancyGuard to prevent reentrancy attacks
- Pausable functionality for emergency situations
- Heartbeat mechanism to ensure price freshness
- Input validation for all parameters

3. **Gas Optimization**:
- Using bytes32 for asset symbols instead of strings
- Efficient storage layout in PriceData struct
- Minimal storage operations in price updates

4. **Error Handling**:
- Custom errors instead of strings for gas efficiency
- Comprehensive input validation
- Clear error messages for debugging

5. **Additional Features**:
- Price staleness checks
- Configurable heartbeat periods
- Activity status for price feeds
- Detailed event logging

To deploy this contract:
1. Deploy with admin address as constructor parameter
2. Grant ORACLE_UPDATER_ROLE to trusted price feed providers
3. Activate price feeds for required assets
4. Configure heartbeat periods based on asset volatility

The contract can be extended with additional features in future phases:
- Multi-source price aggregation
- Price deviation checks
- Automated price updates via chainlink keepers
- Historical price storage