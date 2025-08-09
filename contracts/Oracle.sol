I'll help create a secure and gas-optimized price oracle contract for ClaudeChain. Let's build this step by step.

First, here's the complete code for Oracle.sol with detailed explanations:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title Oracle
 * @dev Price oracle contract for ClaudeChain DeFi features
 * @notice This contract manages price feeds for various assets
 * @author ClaudeChain Team
 */
contract Oracle is AccessControl, ReentrancyGuard, Pausable {
    // Role definitions
    bytes32 public constant ORACLE_UPDATER_ROLE = keccak256("ORACLE_UPDATER_ROLE");
    
    // Struct to store price data with timestamp
    struct PriceData {
        uint256 price;      // Price with 8 decimals
        uint256 timestamp;  // Last update timestamp
        bool isActive;      // Whether this price feed is active
    }

    // Maximum age of price data in seconds
    uint256 public constant MAX_PRICE_AGE = 3600; // 1 hour

    // Minimum delay between updates to prevent price manipulation
    uint256 public constant MIN_UPDATE_DELAY = 15; // 15 seconds

    // Mapping of asset address to price data
    mapping(address => PriceData) public priceFeeds;

    // Events
    event PriceUpdated(address indexed asset, uint256 price, uint256 timestamp);
    event PriceFeedActivated(address indexed asset);
    event PriceFeedDeactivated(address indexed asset);

    // Custom errors
    error PriceTooOld(address asset, uint256 timestamp);
    error UpdateTooFrequent(address asset, uint256 lastUpdate);
    error PriceFeedNotActive(address asset);
    error InvalidPrice();
    error InvalidAsset();

    /**
     * @dev Constructor to set up roles
     */
    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ORACLE_UPDATER_ROLE, msg.sender);
    }

    /**
     * @dev Updates price for an asset
     * @param asset Address of the asset
     * @param newPrice New price with 8 decimals
     */
    function updatePrice(address asset, uint256 newPrice) 
        external 
        onlyRole(ORACLE_UPDATER_ROLE) 
        nonReentrant 
        whenNotPaused 
    {
        // Input validation
        if (asset == address(0)) revert InvalidAsset();
        if (newPrice == 0) revert InvalidPrice();

        PriceData storage priceData = priceFeeds[asset];
        
        // Check if price feed is active
        if (!priceData.isActive) revert PriceFeedNotActive(asset);

        // Check minimum update delay
        if (block.timestamp - priceData.timestamp < MIN_UPDATE_DELAY) {
            revert UpdateTooFrequent(asset, priceData.timestamp);
        }

        // Update price data
        priceData.price = newPrice;
        priceData.timestamp = block.timestamp;

        emit PriceUpdated(asset, newPrice, block.timestamp);
    }

    /**
     * @dev Gets the current price of an asset
     * @param asset Address of the asset
     * @return Price with 8 decimals
     */
    function getPrice(address asset) 
        external 
        view 
        returns (uint256) 
    {
        PriceData memory priceData = priceFeeds[asset];

        // Verify price feed is active and not stale
        if (!priceData.isActive) revert PriceFeedNotActive(asset);
        if (block.timestamp - priceData.timestamp > MAX_PRICE_AGE) {
            revert PriceTooOld(asset, priceData.timestamp);
        }

        return priceData.price;
    }

    /**
     * @dev Activates a price feed for an asset
     * @param asset Address of the asset to activate
     */
    function activatePriceFeed(address asset) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        if (asset == address(0)) revert InvalidAsset();
        
        priceFeeds[asset].isActive = true;
        emit PriceFeedActivated(asset);
    }

    /**
     * @dev Deactivates a price feed for an asset
     * @param asset Address of the asset to deactivate
     */
    function deactivatePriceFeed(address asset) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        if (asset == address(0)) revert InvalidAsset();
        
        priceFeeds[asset].isActive = false;
        emit PriceFeedDeactivated(asset);
    }

    /**
     * @dev Pauses the contract
     */
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    /**
     * @dev Unpauses the contract
     */
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
}
```

Key design decisions and features:

1. **Security Features**:
- Used OpenZeppelin's AccessControl for role-based permissions
- Implemented ReentrancyGuard to prevent reentrancy attacks
- Added Pausable functionality for emergency stops
- Included price staleness checks
- Minimum update delay to prevent price manipulation
- Custom error handling for better gas efficiency

2. **Gas Optimization**:
- Used custom errors instead of require statements
- Minimized storage operations
- Efficient data structures with PriceData struct
- View functions for read-only operations

3. **Error Handling**:
- Comprehensive input validation
- Clear custom error messages
- Checks for price staleness and update frequency
- Active status verification

4. **Features**:
- Price updates with timestamp tracking
- Price feed activation/deactivation
- Maximum age for price data
- Minimum delay between updates
- Role-based access control

5. **Events**:
- Price updates
- Price feed activation/deactivation
- Inherited events from OpenZeppelin contracts

To deploy and use this contract:

1. Deploy with adequate gas
2. Grant ORACLE_UPDATER_ROLE to trusted oracles
3. Activate price feeds for assets
4. Begin updating prices

The contract can be extended with:
- Multi-oracle consensus
- Price deviation checks
- More sophisticated staleness checks
- Additional asset metadata

Let me know if you need any clarification or have questions about specific parts of the implementation!