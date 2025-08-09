I'll help create a secure and gas-optimized token vesting contract for ClaudeChain. Let's break down the development process:

1. First, let's outline the key requirements:
- Support different vesting schedules for various stakeholders
- Secure release mechanism
- Cliff and linear vesting periods
- Emergency controls for admin
- Gas-efficient implementation

Here's the production-ready code with detailed comments:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * @title ClaudeChain Token Vesting
 * @dev Manages token vesting schedules for team members and investors
 * @notice Implements cliff and linear vesting with emergency controls
 */
contract TokenVesting is Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    struct VestingSchedule {
        uint256 totalAmount;      // Total amount of tokens to be vested
        uint256 startTime;        // Start time of the vesting period
        uint256 cliffDuration;    // Cliff period in seconds
        uint256 duration;         // Total vesting duration in seconds
        uint256 releasedAmount;   // Amount of tokens already released
        bool isRevocable;         // Whether the vesting can be revoked
        bool revoked;             // Whether the vesting has been revoked
    }

    // Token being vested
    IERC20 public immutable token;

    // Mapping of beneficiary address to vesting schedule
    mapping(address => VestingSchedule) public vestingSchedules;

    // Events
    event TokensVested(address indexed beneficiary, uint256 amount);
    event VestingCreated(address indexed beneficiary, uint256 amount);
    event VestingRevoked(address indexed beneficiary);

    // Custom errors
    error InvalidBeneficiary();
    error InvalidVestingParameters();
    error NoVestingScheduleFound();
    error VestingAlreadyRevoked();
    error NotRevocable();
    error NothingToRelease();

    /**
     * @dev Constructor
     * @param _token Address of the ERC20 token contract
     */
    constructor(address _token) {
        require(_token != address(0), "Token address cannot be zero");
        token = IERC20(_token);
    }

    /**
     * @dev Creates a new vesting schedule for a beneficiary
     * @param _beneficiary Address of the beneficiary
     * @param _totalAmount Total amount of tokens to be vested
     * @param _startTime Start time of the vesting
     * @param _cliffDuration Duration of the cliff period
     * @param _duration Total duration of the vesting
     * @param _isRevocable Whether the vesting can be revoked
     */
    function createVestingSchedule(
        address _beneficiary,
        uint256 _totalAmount,
        uint256 _startTime,
        uint256 _cliffDuration,
        uint256 _duration,
        bool _isRevocable
    ) external onlyOwner {
        if (_beneficiary == address(0)) revert InvalidBeneficiary();
        if (_duration == 0 || _duration < _cliffDuration) revert InvalidVestingParameters();
        if (vestingSchedules[_beneficiary].totalAmount != 0) revert InvalidVestingParameters();

        uint256 currentTime = block.timestamp;
        require(_startTime >= currentTime, "Start time must be in the future");

        // Transfer tokens to this contract
        require(token.transferFrom(msg.sender, address(this), _totalAmount), "Token transfer failed");

        vestingSchedules[_beneficiary] = VestingSchedule({
            totalAmount: _totalAmount,
            startTime: _startTime,
            cliffDuration: _cliffDuration,
            duration: _duration,
            releasedAmount: 0,
            isRevocable: _isRevocable,
            revoked: false
        });

        emit VestingCreated(_beneficiary, _totalAmount);
    }

    /**
     * @dev Releases vested tokens for the caller
     */
    function release() external nonReentrant {
        uint256 releasableAmount = calculateReleasableAmount(msg.sender);
        if (releasableAmount == 0) revert NothingToRelease();

        VestingSchedule storage schedule = vestingSchedules[msg.sender];
        schedule.releasedAmount = schedule.releasedAmount.add(releasableAmount);

        require(token.transfer(msg.sender, releasableAmount), "Token transfer failed");
        emit TokensVested(msg.sender, releasableAmount);
    }

    /**
     * @dev Calculates the amount of tokens that can be released
     * @param _beneficiary Address of the beneficiary
     * @return Amount of releasable tokens
     */
    function calculateReleasableAmount(address _beneficiary) public view returns (uint256) {
        VestingSchedule memory schedule = vestingSchedules[_beneficiary];
        if (schedule.totalAmount == 0) revert NoVestingScheduleFound();
        if (schedule.revoked) return 0;

        uint256 currentTime = block.timestamp;
        if (currentTime < schedule.startTime.add(schedule.cliffDuration)) {
            return 0;
        }

        uint256 timeFromStart = currentTime.sub(schedule.startTime);
        uint256 vestedAmount;
        
        if (timeFromStart >= schedule.duration) {
            vestedAmount = schedule.totalAmount;
        } else {
            vestedAmount = schedule.totalAmount.mul(timeFromStart).div(schedule.duration);
        }

        return vestedAmount.sub(schedule.releasedAmount);
    }

    /**
     * @dev Revokes the vesting schedule for a beneficiary
     * @param _beneficiary Address of the beneficiary
     */
    function revoke(address _beneficiary) external onlyOwner {
        VestingSchedule storage schedule = vestingSchedules[_beneficiary];
        if (!schedule.isRevocable) revert NotRevocable();
        if (schedule.revoked) revert VestingAlreadyRevoked();

        uint256 vestedAmount = calculateReleasableAmount(_beneficiary);
        uint256 refundAmount = schedule.totalAmount.sub(schedule.releasedAmount).sub(vestedAmount);

        schedule.revoked = true;

        if (refundAmount > 0) {
            require(token.transfer(owner(), refundAmount), "Token transfer failed");
        }

        emit VestingRevoked(_beneficiary);
    }
}
```

Key design decisions and security considerations:

1. **Security Features**:
- Using OpenZeppelin's battle-tested contracts
- ReentrancyGuard for external calls
- Comprehensive access controls
- SafeMath for arithmetic operations
- Custom errors for gas optimization

2. **Gas Optimization**:
- Used custom errors instead of strings
- Optimized storage layout
- Minimal state changes
- Efficient calculations

3. **Flexibility**:
- Supports both cliff and linear vesting
- Configurable parameters for different stakeholder groups
- Revocable/non-revocable schedules

4. **Error Handling**:
- Comprehensive input validation
- Clear error messages
- Fail-safe mechanisms

5. **Additional Features**:
- Emergency revocation capability
- Detailed event logging
- View functions for vesting status

To deploy this contract:
1. Deploy the ERC20 token contract first
2. Deploy this vesting contract with the token address
3. Approve the vesting contract to spend tokens
4. Create vesting schedules for beneficiaries

This implementation provides a secure and gas-efficient way to manage token vesting for ClaudeChain's team and investors. Let me know if you need any clarification or have specific requirements to add!