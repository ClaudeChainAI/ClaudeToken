I'll help develop the Registry.sol contract with a focus on security, efficiency, and maintainability. Let's break down the development process:

1. First, let's outline the key requirements:
- Store and resolve contract addresses
- Handle access control
- Support upgradeable architecture
- Include version control
- Implement robust error handling

Here's the production-ready code with detailed explanations:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

/**
 * @title Registry
 * @dev Global contract registry and resolver for ClaudeChain
 * @author ClaudeChain Team
 * @notice This contract manages the registration and resolution of contract addresses
 */
contract Registry is 
    Initializable, 
    OwnableUpgradeable, 
    PausableUpgradeable, 
    ReentrancyGuardUpgradeable 
{
    // Custom errors
    error Registry__InvalidAddress();
    error Registry__ContractNotFound();
    error Registry__ContractAlreadyRegistered();
    error Registry__Unauthorized();

    // Events
    event ContractRegistered(string indexed name, address indexed contractAddress, uint256 version);
    event ContractUpdated(string indexed name, address indexed oldAddress, address indexed newAddress, uint256 version);
    event ContractRemoved(string indexed name, address indexed contractAddress);

    // Structs
    struct ContractEntry {
        address contractAddress;
        uint256 version;
        bool isActive;
        uint256 timestamp;
    }

    // State variables
    mapping(bytes32 => ContractEntry) private _contracts;
    mapping(address => bool) private _authorizedUpdaters;
    
    // Constants
    uint256 private constant VERSION_INITIAL = 1;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initializes the contract
     */
    function initialize() public initializer {
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        
        // Add deployer as authorized updater
        _authorizedUpdaters[msg.sender] = true;
    }

    /**
     * @dev Registers a new contract
     * @param name Contract name
     * @param contractAddress Contract address
     */
    function registerContract(string calldata name, address contractAddress) 
        external 
        onlyAuthorizedUpdater 
        whenNotPaused 
        nonReentrant 
    {
        if (contractAddress == address(0)) revert Registry__InvalidAddress();
        
        bytes32 nameHash = keccak256(bytes(name));
        if (_contracts[nameHash].isActive) revert Registry__ContractAlreadyRegistered();

        _contracts[nameHash] = ContractEntry({
            contractAddress: contractAddress,
            version: VERSION_INITIAL,
            isActive: true,
            timestamp: block.timestamp
        });

        emit ContractRegistered(name, contractAddress, VERSION_INITIAL);
    }

    /**
     * @dev Updates an existing contract address
     * @param name Contract name
     * @param newAddress New contract address
     */
    function updateContract(string calldata name, address newAddress)
        external
        onlyAuthorizedUpdater
        whenNotPaused
        nonReentrant
    {
        if (newAddress == address(0)) revert Registry__InvalidAddress();
        
        bytes32 nameHash = keccak256(bytes(name));
        ContractEntry storage entry = _contracts[nameHash];
        
        if (!entry.isActive) revert Registry__ContractNotFound();

        address oldAddress = entry.contractAddress;
        entry.contractAddress = newAddress;
        entry.version += 1;
        entry.timestamp = block.timestamp;

        emit ContractUpdated(name, oldAddress, newAddress, entry.version);
    }

    /**
     * @dev Resolves a contract address by name
     * @param name Contract name
     * @return Contract address and version
     */
    function resolveContract(string calldata name) 
        external 
        view 
        returns (address, uint256) 
    {
        bytes32 nameHash = keccak256(bytes(name));
        ContractEntry memory entry = _contracts[nameHash];
        
        if (!entry.isActive) revert Registry__ContractNotFound();
        
        return (entry.contractAddress, entry.version);
    }

    /**
     * @dev Adds an authorized updater
     * @param updater Address to authorize
     */
    function addAuthorizedUpdater(address updater) 
        external 
        onlyOwner 
    {
        if (updater == address(0)) revert Registry__InvalidAddress();
        _authorizedUpdaters[updater] = true;
    }

    /**
     * @dev Removes an authorized updater
     * @param updater Address to remove
     */
    function removeAuthorizedUpdater(address updater) 
        external 
        onlyOwner 
    {
        if (updater == address(0)) revert Registry__InvalidAddress();
        _authorizedUpdaters[updater] = false;
    }

    /**
     * @dev Checks if an address is an authorized updater
     * @param updater Address to check
     */
    function isAuthorizedUpdater(address updater) 
        external 
        view 
        returns (bool) 
    {
        return _authorizedUpdaters[updater];
    }

    /**
     * @dev Modifier to restrict access to authorized updaters
     */
    modifier onlyAuthorizedUpdater() {
        if (!_authorizedUpdaters[msg.sender]) revert Registry__Unauthorized();
        _;
    }

    /**
     * @dev Pauses the contract
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpauses the contract
     */
    function unpause() external onlyOwner {
        _unpause();
    }
}
```

Key design decisions and features:

1. Security:
- Used OpenZeppelin's battle-tested contracts
- Implemented access control with authorized updaters
- Added reentrancy protection
- Included contract pausability
- Used custom errors for gas efficiency
- Implemented version control

2. Gas Optimization:
- Used mappings for O(1) lookups
- Implemented custom errors instead of strings
- Used calldata for function parameters
- Minimized storage operations

3. Error Handling:
- Custom errors for specific failure cases
- Input validation for addresses
- Checks for contract existence
- Authorization checks

4. Features:
- Contract registration
- Contract updates with version tracking
- Address resolution
- Authorized updater management
- Pausability for emergency situations

5. Events:
- Comprehensive event logging for off-chain tracking
- Indexed parameters for efficient filtering

This implementation provides a secure and efficient registry system for ClaudeChain. It can be deployed behind a proxy for upgradeability and includes all necessary security features for a production environment.

Would you like me to explain any particular aspect in more detail or provide additional functionality?