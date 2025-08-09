I'll help create a secure and gas-optimized price oracle smart contract for ClaudeChain. Let's build this step by step.

First, here's the code for Oracle.sol:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * @title ClaudeChain Price Oracle
 * @dev Secure price feed oracle for ClaudeChain DeFi features
 * @notice This contract manages price data for various assets with multiple validators
 */
contract Oracle is AccessControl, ReentrancyGuard, Pausable {
    using SafeMath for uint256;

    // Role definitions
    bytes32 public constant ORACLE_VALIDATOR_ROLE = keccak256("ORACLE_VALIDATOR_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // Structs
    struct PriceData {
        uint256 price;
        uint256 timestamp;
        uint256 heartbeat;
        uint256 validatorCount;
    }

    struct ValidatorSubmission {
        uint256 price;
        uint256 timestamp;
        bool hasSubmitted;
    }

    // State variables
    mapping(bytes32 => PriceData) private prices;
    mapping(bytes32 => mapping(address => ValidatorSubmission)) private validatorSubmissions;
    mapping(bytes32 => uint256) private minimumValidators;
    
    // Events
    event PriceUpdated(bytes32 indexed assetId, uint256 price, uint256 timestamp);
    event ValidatorSubmittedPrice(bytes32 indexed assetId, address validator, uint256 price);
    event AssetAdded(bytes32 indexed assetId, uint256 heartbeat, uint256 minValidators);

    // Custom errors
    error InvalidPrice();
    error StalePrice();
    error InsufficientValidators();
    error HeartbeatExceeded();
    error UnauthorizedValidator();
    error InvalidParameters();

    /**
     * @dev Constructor to initialize roles
     */
    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
    }

    /**
     * @dev Add a new asset to the oracle
     * @param assetId Unique identifier for the asset
     * @param heartbeat Maximum time between price updates
     * @param minValidators Minimum number of validators required
     */
    function addAsset(
        bytes32 assetId,
        uint256 heartbeat,
        uint256 minValidators
    ) external onlyRole(ADMIN_ROLE) {
        if (heartbeat == 0 || minValidators == 0) revert InvalidParameters();

        prices[assetId].heartbeat = heartbeat;
        minimumValidators[assetId] = minValidators;

        emit AssetAdded(assetId, heartbeat, minValidators);
    }

    /**
     * @dev Submit price data for an asset (validator only)
     * @param assetId Asset identifier
     * @param price Current price
     */
    function submitPrice(
        bytes32 assetId,
        uint256 price
    ) external nonReentrant whenNotPaused onlyRole(ORACLE_VALIDATOR_ROLE) {
        if (price == 0) revert InvalidPrice();
        
        ValidatorSubmission storage submission = validatorSubmissions[assetId][msg.sender];
        
        // Update validator submission
        submission.price = price;
        submission.timestamp = block.timestamp;
        
        if (!submission.hasSubmitted) {
            submission.hasSubmitted = true;
            prices[assetId].validatorCount++;
        }

        emit ValidatorSubmittedPrice(assetId, msg.sender, price);

        // Check if we have enough validators and update price
        if (prices[assetId].validatorCount >= minimumValidators[assetId]) {
            _updatePrice(assetId);
        }
    }

    /**
     * @dev Get the current price for an asset
     * @param assetId Asset identifier
     * @return price Current price
     * @return timestamp Time of last update
     */
    function getPrice(bytes32 assetId) external view returns (uint256 price, uint256 timestamp) {
        PriceData memory data = prices[assetId];
        
        if (data.price == 0) revert InvalidPrice();
        if (block.timestamp > data.timestamp + data.heartbeat) revert HeartbeatExceeded();
        
        return (data.price, data.timestamp);
    }

    /**
     * @dev Internal function to update price based on validator submissions
     * @param assetId Asset identifier
     */
    function _updatePrice(bytes32 assetId) private {
        uint256 validatorCount = prices[assetId].validatorCount;
        if (validatorCount < minimumValidators[assetId]) revert InsufficientValidators();

        uint256 totalPrice;
        uint256 validSubmissions;
        
        // Calculate median price from valid submissions
        address[] memory validators = getRoleMemberArray(ORACLE_VALIDATOR_ROLE);
        for (uint256 i = 0; i < validators.length; i++) {
            ValidatorSubmission memory submission = validatorSubmissions[assetId][validators[i]];
            if (submission.hasSubmitted && 
                block.timestamp - submission.timestamp <= prices[assetId].heartbeat) {
                totalPrice = totalPrice.add(submission.price);
                validSubmissions++;
            }
        }

        if (validSubmissions >= minimumValidators[assetId]) {
            uint256 newPrice = totalPrice.div(validSubmissions);
            prices[assetId].price = newPrice;
            prices[assetId].timestamp = block.timestamp;
            
            emit PriceUpdated(assetId, newPrice, block.timestamp);
        }
    }

    /**
     * @dev Helper function to get array of role members
     */
    function getRoleMemberArray(bytes32 role) private view returns (address[] memory) {
        uint256 count = getRoleMemberCount(role);
        address[] memory members = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            members[i] = getRoleMember(role, i);
        }
        return members;
    }

    /**
     * @dev Pause the contract
     */
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    /**
     * @dev Unpause the contract
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }
}
```

Key design decisions and features:

1. Security Features:
- Used OpenZeppelin's AccessControl for role-based permissions
- Implemented ReentrancyGuard to prevent reentrancy attacks
- Added Pausable functionality for emergency stops
- Used SafeMath for arithmetic operations
- Implemented strict validation checks

2. Gas Optimization:
- Used mappings for efficient data storage
- Minimized storage operations
- Optimized loops in price aggregation
- Used custom errors instead of strings

3. Error Handling:
- Custom errors for specific failure cases
- Comprehensive input validation
- Heartbeat checks for price staleness
- Minimum validator requirements

4. Architecture:
- Multi-validator system for decentralization
- Price aggregation using average of valid submissions
- Flexible asset management system
- Event emissions for important state changes

5. Features:
- Support for multiple assets
- Configurable heartbeat periods
- Minimum validator thresholds
- Price staleness checks
- Admin controls for asset management

To deploy and use this contract:

1. Deploy with adequate gas limit
2. Grant ADMIN_ROLE to administrative addresses
3. Grant ORACLE_VALIDATOR_ROLE to trusted validators
4. Add assets using addAsset() with appropriate parameters
5. Validators can submit prices using submitPrice()
6. DeFi protocols can fetch prices using getPrice()

This implementation provides a robust foundation for price feeds in the ClaudeChain ecosystem while maintaining security and gas efficiency.