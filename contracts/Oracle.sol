I'll help create a secure and optimized Oracle.sol contract for ClaudeChain. Let's break down the development process and key considerations.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title Oracle
 * @dev Decentralized price oracle for ClaudeChain
 * @notice This contract manages price feeds for various assets
 * @author ClaudeChain Team
 */
contract Oracle is AccessControl, ReentrancyGuard, Pausable {
    // Role definitions
    bytes32 public constant ORACLE_UPDATER_ROLE = keccak256("ORACLE_UPDATER_ROLE");
    
    // Struct to store price data with metadata
    struct PriceData {
        uint256 price;        // Price with 18 decimals
        uint256 timestamp;    // Last update timestamp
        bool isActive;        // Whether this price feed is active
    }

    // Mapping from asset symbol hash to price data
    mapping(bytes32 => PriceData) private priceFeeds;
    
    // Minimum delay between updates (15 minutes)
    uint256 public constant MIN_UPDATE_DELAY = 15 minutes;
    
    // Maximum age of price data (1 hour)
    uint256 public constant MAX_PRICE_AGE = 1 hours;

    // Events
    event PriceUpdated(bytes32 indexed assetId, uint256 price, uint256 timestamp);
    event PriceFeedActivated(bytes32 indexed assetId);
    event PriceFeedDeactivated(bytes32 indexed assetId);

    // Custom errors
    error InvalidPrice();
    error UpdateTooFrequent();
    error PriceTooOld();
    error PriceFeedNotActive();
    error InvalidAssetId();

    /**
     * @dev Constructor
     * @param admin Address that will have admin rights
     */
    constructor(address admin) {
        _setupRole(DEFAULT_ADMIN_ROLE, admin);
        _setupRole(ORACLE_UPDATER_ROLE, admin);
    }

    /**
     * @dev Updates price for an asset
     * @param assetId Hash of the asset symbol
     * @param newPrice New price value (18 decimals)
     */
    function updatePrice(bytes32 assetId, uint256 newPrice) 
        external 
        onlyRole(ORACLE_UPDATER_ROLE) 
        whenNotPaused 
        nonReentrant 
    {
        if (assetId == bytes32(0)) revert InvalidAssetId();
        if (newPrice == 0) revert InvalidPrice();

        PriceData storage priceData = priceFeeds[assetId];
        
        if (!priceData.isActive) revert PriceFeedNotActive();
        
        // Check minimum delay between updates
        if (block.timestamp - priceData.timestamp < MIN_UPDATE_DELAY) {
            revert UpdateTooFrequent();
        }

        priceData.price = newPrice;
        priceData.timestamp = block.timestamp;

        emit PriceUpdated(assetId, newPrice, block.timestamp);
    }

    /**
     * @dev Gets the current price of an asset
     * @param assetId Hash of the asset symbol
     * @return price Current price
     */
    function getPrice(bytes32 assetId) 
        external 
        view 
        returns (uint256 price) 
    {
        PriceData memory priceData = priceFeeds[assetId];
        
        if (!priceData.isActive) revert PriceFeedNotActive();
        if (block.timestamp - priceData.timestamp > MAX_PRICE_AGE) {
            revert PriceTooOld();
        }

        return priceData.price;
    }

    /**
     * @dev Activates a price feed for an asset
     * @param assetId Hash of the asset symbol
     */
    function activatePriceFeed(bytes32 assetId) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        if (assetId == bytes32(0)) revert InvalidAssetId();
        
        priceFeeds[assetId].isActive = true;
        emit PriceFeedActivated(assetId);
    }

    /**
     * @dev Deactivates a price feed for an asset
     * @param assetId Hash of the asset symbol
     */
    function deactivatePriceFeed(bytes32 assetId) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        if (assetId == bytes32(0)) revert InvalidAssetId();
        
        priceFeeds[assetId].isActive = false;
        emit PriceFeedDeactivated(assetId);
    }

    /**
     * @dev Pauses all price updates
     */
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    /**
     * @dev Unpauses price updates
     */
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
}
```

Key Development Decisions and Features:

1. Security Measures:
- Used OpenZeppelin's AccessControl for role-based permissions
- Implemented ReentrancyGuard to prevent reentrancy attacks
- Added Pausable functionality for emergency situations
- Strict input validation and custom error messages
- Timestamp checks for price staleness

2. Gas Optimization:
- Used mappings for O(1) lookups
- Implemented custom errors instead of strings
- Cached storage variables in memory where appropriate
- Minimal storage usage in PriceData struct

3. Price Feed Management:
- Active/inactive status for each price feed
- Minimum delay between updates to prevent manipulation
- Maximum age check for prices to ensure freshness
- Administrator controls for feed activation

4. Error Handling:
- Custom errors for specific failure cases
- Comprehensive input validation
- Clear error messages for easier debugging

5. Events:
- Emitted for all important state changes
- Indexed parameters for efficient filtering

Usage Example:
```solidity
// Deploy
address admin = msg.sender;
Oracle oracle = new Oracle(admin);

// Activate price feed for an asset
bytes32 assetId = keccak256("ETH-USD");
oracle.activatePriceFeed(assetId);

// Update price
uint256 newPrice = 1800 * 10**18; // $1800 with 18 decimals
oracle.updatePrice(assetId, newPrice);

// Get price
uint256 price = oracle.getPrice(assetId);
```

This implementation provides a secure and efficient oracle system for ClaudeChain. The code is production-ready but should undergo thorough testing and auditing before deployment.