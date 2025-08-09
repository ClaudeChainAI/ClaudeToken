I'll help build a secure and gas-optimized price oracle implementation for ClaudeChain. Let's break down the development process and key design decisions.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * @title ClaudeChain Price Oracle
 * @dev Decentralized price oracle for ClaudeChain DeFi features
 * @notice This contract manages price feeds for various assets
 */
contract ClaudeChainOracle is AccessControl, ReentrancyGuard, Pausable {
    using SafeMath for uint256;

    // Role definitions
    bytes32 public constant ORACLE_UPDATER_ROLE = keccak256("ORACLE_UPDATER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // Struct to store price data with metadata
    struct PriceData {
        uint256 price;           // Price with 18 decimals
        uint256 timestamp;       // Last update timestamp
        uint256 heartbeat;       // Maximum time between updates
        bool active;             // Whether this price feed is active
    }

    // Mapping from asset address to price data
    mapping(address => PriceData) private priceFeeds;
    
    // Minimum heartbeat duration (1 minute)
    uint256 public constant MIN_HEARTBEAT = 1 minutes;
    
    // Maximum heartbeat duration (1 day)
    uint256 public constant MAX_HEARTBEAT = 1 days;

    // Events
    event PriceUpdated(address indexed asset, uint256 price, uint256 timestamp);
    event PriceFeedAdded(address indexed asset, uint256 heartbeat);
    event PriceFeedRemoved(address indexed asset);
    event HeartbeatUpdated(address indexed asset, uint256 newHeartbeat);

    // Custom errors
    error InvalidPrice();
    error InvalidHeartbeat();
    error InvalidAsset();
    error StalePrice();
    error PriceFeedNotActive();

    /**
     * @dev Constructor sets up initial roles
     * @param admin Address of the admin
     */
    constructor(address admin) {
        _setupRole(DEFAULT_ADMIN_ROLE, admin);
        _setupRole(ADMIN_ROLE, admin);
    }

    /**
     * @dev Adds a new price feed
     * @param asset Asset address
     * @param initialPrice Initial price
     * @param heartbeat Maximum time between updates
     */
    function addPriceFeed(
        address asset,
        uint256 initialPrice,
        uint256 heartbeat
    ) external onlyRole(ADMIN_ROLE) {
        if (asset == address(0)) revert InvalidAsset();
        if (initialPrice == 0) revert InvalidPrice();
        if (heartbeat < MIN_HEARTBEAT || heartbeat > MAX_HEARTBEAT) {
            revert InvalidHeartbeat();
        }

        priceFeeds[asset] = PriceData({
            price: initialPrice,
            timestamp: block.timestamp,
            heartbeat: heartbeat,
            active: true
        });

        emit PriceFeedAdded(asset, heartbeat);
    }

    /**
     * @dev Updates price for an asset
     * @param asset Asset address
     * @param newPrice New price value
     */
    function updatePrice(
        address asset,
        uint256 newPrice
    ) external onlyRole(ORACLE_UPDATER_ROLE) whenNotPaused nonReentrant {
        PriceData storage feed = priceFeeds[asset];
        
        if (!feed.active) revert PriceFeedNotActive();
        if (newPrice == 0) revert InvalidPrice();

        feed.price = newPrice;
        feed.timestamp = block.timestamp;

        emit PriceUpdated(asset, newPrice, block.timestamp);
    }

    /**
     * @dev Gets the latest price for an asset
     * @param asset Asset address
     * @return price Latest price
     */
    function getLatestPrice(address asset) external view returns (uint256 price) {
        PriceData memory feed = priceFeeds[asset];
        
        if (!feed.active) revert PriceFeedNotActive();
        if (block.timestamp > feed.timestamp + feed.heartbeat) {
            revert StalePrice();
        }

        return feed.price;
    }

    /**
     * @dev Updates heartbeat for a price feed
     * @param asset Asset address
     * @param newHeartbeat New heartbeat duration
     */
    function updateHeartbeat(
        address asset,
        uint256 newHeartbeat
    ) external onlyRole(ADMIN_ROLE) {
        if (newHeartbeat < MIN_HEARTBEAT || newHeartbeat > MAX_HEARTBEAT) {
            revert InvalidHeartbeat();
        }

        PriceData storage feed = priceFeeds[asset];
        if (!feed.active) revert PriceFeedNotActive();

        feed.heartbeat = newHeartbeat;
        emit HeartbeatUpdated(asset, newHeartbeat);
    }

    /**
     * @dev Deactivates a price feed
     * @param asset Asset address
     */
    function removePriceFeed(
        address asset
    ) external onlyRole(ADMIN_ROLE) {
        PriceData storage feed = priceFeeds[asset];
        if (!feed.active) revert PriceFeedNotActive();

        feed.active = false;
        emit PriceFeedRemoved(asset);
    }

    /**
     * @dev Pauses price updates
     */
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    /**
     * @dev Unpauses price updates
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }
}
```

Key Design Decisions and Security Considerations:

1. Access Control:
- Implemented role-based access control using OpenZeppelin's AccessControl
- Separate roles for admin and oracle updaters
- Only authorized updaters can modify prices

2. Security Features:
- ReentrancyGuard to prevent reentrancy attacks
- Pausable functionality for emergency situations
- Heartbeat mechanism to ensure price freshness
- Input validation for all parameters
- Custom errors for gas efficiency

3. Price Data Structure:
- Stores price with metadata (timestamp, heartbeat, active status)
- 18 decimal precision for prices
- Heartbeat mechanism to detect stale prices

4. Gas Optimization:
- Used custom errors instead of require statements
- Efficient storage layout
- Minimal storage operations
- View functions where possible

5. Error Handling:
- Comprehensive input validation
- Clear error messages
- Proper access control checks

6. Events:
- Emitted for all important state changes
- Includes relevant indexed parameters

Additional Considerations:

1. This implementation can be extended with:
- Multi-oracle aggregation
- Price deviation checks
- Historical price tracking
- More sophisticated staleness checks

2. For production deployment:
- Thorough testing needed
- Security audit required
- Consider implementing emergency procedures
- Add more sophisticated price validation

3. Integration points:
- Can be used by other DeFi contracts
- Supports multiple assets
- Flexible heartbeat configuration

Let me know if you need any clarification or have questions about specific parts of the implementation!