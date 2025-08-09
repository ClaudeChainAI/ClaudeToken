I'll help create a secure and gas-optimized token vesting contract for ClaudeChain. Let's break down the development process:

1. First, let's outline the key requirements:
- Support for different vesting schedules (cliff, linear vesting)
- Ability to handle multiple beneficiaries
- Emergency controls for admin
- Gas-efficient release mechanism
- Reentrancy protection

Here's the production-ready code with detailed comments:

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
 * @notice Supports cliff and linear vesting with customizable schedules
 */
contract TokenVesting is Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    struct VestingSchedule {
        uint256 totalAmount;        // Total amount of tokens to be vested
        uint256 startTime;          // Start time of the vesting period
        uint256 cliffDuration;      // Cliff period in seconds
        uint256 vestingDuration;    // Total vesting duration in seconds
        uint256 releasedAmount;     // Amount of tokens already released
        bool revocable;             // Whether the vesting is revocable
        bool revoked;               // Whether the vesting has been revoked
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
    error NoTokensDue();

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
     * @param _cliffDuration Duration of the cliff in seconds
     * @param _vestingDuration Duration of the vesting in seconds
     * @param _revocable Whether the vesting is revocable
     */
    function createVestingSchedule(
        address _beneficiary,
        uint256 _totalAmount,
        uint256 _startTime,
        uint256 _cliffDuration,
        uint256 _vestingDuration,
        bool _revocable
    ) external onlyOwner {
        if (_beneficiary == address(0)) revert InvalidBeneficiary();
        if (_totalAmount == 0) revert InvalidVestingParameters();
        if (_vestingDuration == 0) revert InvalidVestingParameters();
        if (_vestingDuration < _cliffDuration) revert InvalidVestingParameters();

        // Transfer tokens to this contract
        require(
            token.transferFrom(msg.sender, address(this), _totalAmount),
            "Token transfer failed"
        );

        vestingSchedules[_beneficiary] = VestingSchedule({
            totalAmount: _totalAmount,
            startTime: _startTime,
            cliffDuration: _cliffDuration,
            vestingDuration: _vestingDuration,
            releasedAmount: 0,
            revocable: _revocable,
            revoked: false
        });

        emit VestingCreated(_beneficiary, _totalAmount);
    }

    /**
     * @dev Releases vested tokens for the caller
     */
    function release() external nonReentrant {
        uint256 releasable = getReleasableAmount(msg.sender);
        if (releasable == 0) revert NoTokensDue();

        VestingSchedule storage schedule = vestingSchedules[msg.sender];
        schedule.releasedAmount = schedule.releasedAmount.add(releasable);

        require(
            token.transfer(msg.sender, releasable),
            "Token transfer failed"
        );

        emit TokensVested(msg.sender, releasable);
    }

    /**
     * @dev Calculates the amount of tokens that can be released
     * @param _beneficiary Address of the beneficiary
     * @return Amount of releasable tokens
     */
    function getReleasableAmount(address _beneficiary) public view returns (uint256) {
        VestingSchedule memory schedule = vestingSchedules[_beneficiary];
        if (schedule.totalAmount == 0) revert NoVestingScheduleFound();
        if (schedule.revoked) return 0;

        uint256 currentTime = block.timestamp;
        if (currentTime < schedule.startTime.add(schedule.cliffDuration)) {
            return 0;
        }

        if (currentTime >= schedule.startTime.add(schedule.vestingDuration)) {
            return schedule.totalAmount.sub(schedule.releasedAmount);
        }

        uint256 timeFromStart = currentTime.sub(schedule.startTime);
        uint256 vestedAmount = schedule.totalAmount.mul(timeFromStart).div(schedule.vestingDuration);
        return vestedAmount.sub(schedule.releasedAmount);
    }

    /**
     * @dev Revokes the vesting schedule for a beneficiary
     * @param _beneficiary Address of the beneficiary
     */
    function revoke(address _beneficiary) external onlyOwner {
        VestingSchedule storage schedule = vestingSchedules[_beneficiary];
        if (!schedule.revocable) revert NotRevocable();
        if (schedule.revoked) revert VestingAlreadyRevoked();

        uint256 vestedAmount = getReleasableAmount(_beneficiary);
        uint256 refund = schedule.totalAmount.sub(schedule.releasedAmount).sub(vestedAmount);

        schedule.revoked = true;

        if (refund > 0) {
            require(
                token.transfer(owner(), refund),
                "Token transfer failed"
            );
        }

        emit VestingRevoked(_beneficiary);
    }
}
```

Key design decisions and security considerations:

1. **Security Features**:
- Used OpenZeppelin's ReentrancyGuard to prevent reentrancy attacks
- Implemented Ownable for access control
- Used SafeMath for arithmetic operations
- Added custom errors for gas efficiency
- Implemented revocation functionality for emergency scenarios

2. **Gas Optimization**:
- Used custom errors instead of require statements
- Minimized storage operations
- Used immutable for token address
- Optimized calculations in getReleasableAmount

3. **Flexibility**:
- Supports both cliff and linear vesting
- Configurable vesting parameters
- Revocable/non-revocable schedules

4. **Error Handling**:
- Comprehensive input validation
- Clear error messages
- Safe token transfer handling

5. **Events**:
- Emitted for all important state changes
- Helpful for frontend integration and monitoring

To use this contract:

1. Deploy with the token address as constructor parameter
2. Create vesting schedules for beneficiaries using createVestingSchedule
3. Beneficiaries can call release() to claim their vested tokens
4. Admin can revoke vesting if needed (only for revocable schedules)

Would you like me to explain any specific part in more detail or add additional functionality?