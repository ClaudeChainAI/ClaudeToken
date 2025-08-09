I'll help create a secure and gas-optimized token vesting contract for ClaudeChain. Let's break down the development process:

1. First, let's identify the key requirements:
- Support different vesting schedules for various stakeholders
- Allow cliff periods
- Ensure secure token release mechanism
- Prevent unauthorized withdrawals
- Support emergency functions for admin

2. Here's the implementation with detailed comments:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * @title ClaudeChain Token Vesting Contract
 * @dev Manages token vesting schedules for team members and investors
 */
contract TokenVesting is Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    struct VestingSchedule {
        uint256 totalAmount;        // Total tokens to be vested
        uint256 startTime;          // Start time of the vesting period
        uint256 cliffDuration;      // Cliff period in seconds
        uint256 duration;           // Total vesting duration in seconds
        uint256 releasedAmount;     // Amount of tokens already released
        bool revocable;             // Whether the vesting can be revoked
        bool revoked;               // Whether the vesting has been revoked
    }

    // The token being vested
    IERC20 public immutable token;

    // Mapping of beneficiary address to vesting schedule
    mapping(address => VestingSchedule) public vestingSchedules;

    // Events
    event VestingScheduleCreated(address indexed beneficiary, uint256 amount);
    event TokensReleased(address indexed beneficiary, uint256 amount);
    event VestingRevoked(address indexed beneficiary);

    // Custom errors
    error InvalidBeneficiary();
    error InvalidVestingParameters();
    error NoVestingScheduleFound();
    error CliffPeriodNotEnded();
    error NoTokensAvailable();
    error NotRevocable();
    error AlreadyRevoked();

    /**
     * @dev Constructor
     * @param _token Address of the ERC20 token contract
     */
    constructor(address _token) {
        if (_token == address(0)) revert InvalidBeneficiary();
        token = IERC20(_token);
    }

    /**
     * @dev Creates a new vesting schedule for a beneficiary
     * @param _beneficiary Address of the beneficiary
     * @param _startTime Start time of the vesting
     * @param _cliffDuration Duration of the cliff in seconds
     * @param _duration Duration of the vesting in seconds
     * @param _amount Total amount of tokens to be vested
     * @param _revocable Whether the vesting is revocable
     */
    function createVestingSchedule(
        address _beneficiary,
        uint256 _startTime,
        uint256 _cliffDuration,
        uint256 _duration,
        uint256 _amount,
        bool _revocable
    ) external onlyOwner {
        // Input validation
        if (_beneficiary == address(0)) revert InvalidBeneficiary();
        if (_duration == 0 || _amount == 0 || _duration < _cliffDuration) 
            revert InvalidVestingParameters();

        // Create new vesting schedule
        vestingSchedules[_beneficiary] = VestingSchedule({
            totalAmount: _amount,
            startTime: _startTime,
            cliffDuration: _cliffDuration,
            duration: _duration,
            releasedAmount: 0,
            revocable: _revocable,
            revoked: false
        });

        // Transfer tokens to this contract
        require(
            token.transferFrom(msg.sender, address(this), _amount),
            "Token transfer failed"
        );

        emit VestingScheduleCreated(_beneficiary, _amount);
    }

    /**
     * @dev Release vested tokens for msg.sender
     */
    function release() external nonReentrant {
        uint256 releasableAmount = getReleasableAmount(msg.sender);
        if (releasableAmount == 0) revert NoTokensAvailable();

        VestingSchedule storage schedule = vestingSchedules[msg.sender];
        schedule.releasedAmount = schedule.releasedAmount.add(releasableAmount);

        require(
            token.transfer(msg.sender, releasableAmount),
            "Token transfer failed"
        );

        emit TokensReleased(msg.sender, releasableAmount);
    }

    /**
     * @dev Calculate the releasable amount for a beneficiary
     * @param _beneficiary Address of the beneficiary
     * @return Amount of releasable tokens
     */
    function getReleasableAmount(address _beneficiary) public view returns (uint256) {
        VestingSchedule storage schedule = vestingSchedules[_beneficiary];
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
     * @dev Revoke the vesting schedule for a beneficiary
     * @param _beneficiary Address of the beneficiary
     */
    function revoke(address _beneficiary) external onlyOwner {
        VestingSchedule storage schedule = vestingSchedules[_beneficiary];
        if (!schedule.revocable) revert NotRevocable();
        if (schedule.revoked) revert AlreadyRevoked();

        uint256 vestedAmount = getReleasableAmount(_beneficiary);
        uint256 refundAmount = schedule.totalAmount.sub(schedule.releasedAmount).sub(vestedAmount);

        schedule.revoked = true;

        if (refundAmount > 0) {
            require(
                token.transfer(owner(), refundAmount),
                "Token transfer failed"
            );
        }

        emit VestingRevoked(_beneficiary);
    }
}
```

Key design decisions and security considerations:

1. Security:
- Using OpenZeppelin's battle-tested contracts
- ReentrancyGuard for external calls
- Comprehensive input validation
- Custom errors for gas optimization
- Access control using Ownable

2. Gas Optimization:
- Using custom errors instead of strings
- Immutable variables where possible
- Efficient storage layout
- Minimal storage operations

3. Features:
- Flexible vesting schedules with cliff periods
- Revocable vesting option
- Linear vesting after cliff period
- Emergency revoke functionality
- Complete event logging

4. Error Handling:
- Custom errors for better debugging
- Comprehensive input validation
- Safe math operations
- Clear require statements

To deploy this contract:
1. Deploy the ERC20 token contract first
2. Deploy this vesting contract with the token address
3. Approve the vesting contract to spend tokens
4. Create vesting schedules for beneficiaries

The contract can handle multiple vesting schedules for different stakeholders with varying terms. Let me know if you need any clarification or have specific requirements to add!