I'll help create a secure and gas-optimized token vesting contract for ClaudeChain. Let's break down the development process:

1. First, let's identify the key requirements:
- Support for different vesting schedules
- Secure fund locking and release mechanisms
- Cliff periods functionality
- Emergency controls for admin
- Gas-efficient withdrawal system

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
        uint256 totalAmount;        // Total amount of tokens to be vested
        uint256 startTime;          // Start time of the vesting period
        uint256 cliffDuration;      // Duration of cliff in seconds
        uint256 duration;           // Duration of vesting in seconds
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
        require(_token != address(0), "Token address cannot be zero");
        token = IERC20(_token);
    }

    /**
     * @dev Creates a new vesting schedule
     * @param _beneficiary Address of the beneficiary
     * @param _totalAmount Total amount of tokens to be vested
     * @param _startTime Start time of the vesting
     * @param _cliffDuration Duration of the cliff period
     * @param _duration Total duration of the vesting
     * @param _revocable Whether the vesting is revocable
     */
    function createVestingSchedule(
        address _beneficiary,
        uint256 _totalAmount,
        uint256 _startTime,
        uint256 _cliffDuration,
        uint256 _duration,
        bool _revocable
    ) external onlyOwner {
        // Validation
        if (_beneficiary == address(0) ||
            _totalAmount == 0 ||
            _duration == 0 ||
            _duration < _cliffDuration ||
            vestingSchedules[_beneficiary].totalAmount != 0) {
            revert InvalidVestingParameters();
        }

        // Transfer tokens to this contract
        require(
            token.transferFrom(msg.sender, address(this), _totalAmount),
            "Token transfer failed"
        );

        // Create new vesting schedule
        vestingSchedules[_beneficiary] = VestingSchedule({
            totalAmount: _totalAmount,
            startTime: _startTime,
            cliffDuration: _cliffDuration,
            duration: _duration,
            releasedAmount: 0,
            revocable: _revocable,
            revoked: false
        });

        emit VestingCreated(_beneficiary, _totalAmount);
    }

    /**
     * @dev Calculates the releasable amount of tokens
     * @param _beneficiary Address of the beneficiary
     * @return Amount of releasable tokens
     */
    function computeReleasableAmount(address _beneficiary) 
        public 
        view 
        returns (uint256) 
    {
        VestingSchedule storage schedule = vestingSchedules[_beneficiary];
        
        if (schedule.totalAmount == 0) {
            revert NoVestingScheduleFound();
        }
        
        if (schedule.revoked) {
            return 0;
        }

        // Check if cliff period has ended
        if (block.timestamp < schedule.startTime.add(schedule.cliffDuration)) {
            return 0;
        }

        // If vesting has ended, return all remaining tokens
        if (block.timestamp >= schedule.startTime.add(schedule.duration)) {
            return schedule.totalAmount.sub(schedule.releasedAmount);
        }

        // Calculate vested tokens based on time
        uint256 timeFromStart = block.timestamp.sub(schedule.startTime);
        uint256 vestedAmount = schedule.totalAmount.mul(timeFromStart).div(schedule.duration);
        return vestedAmount.sub(schedule.releasedAmount);
    }

    /**
     * @dev Release vested tokens to beneficiary
     */
    function release() external nonReentrant {
        uint256 releasable = computeReleasableAmount(msg.sender);
        
        if (releasable == 0) {
            revert NoTokensAvailable();
        }

        VestingSchedule storage schedule = vestingSchedules[msg.sender];
        schedule.releasedAmount = schedule.releasedAmount.add(releasable);

        require(
            token.transfer(msg.sender, releasable),
            "Token transfer failed"
        );

        emit TokensVested(msg.sender, releasable);
    }

    /**
     * @dev Revoke vesting schedule
     * @param _beneficiary Address of the beneficiary
     */
    function revoke(address _beneficiary) external onlyOwner {
        VestingSchedule storage schedule = vestingSchedules[_beneficiary];

        if (!schedule.revocable) {
            revert NotRevocable();
        }
        
        if (schedule.revoked) {
            revert AlreadyRevoked();
        }

        uint256 vestedAmount = computeReleasableAmount(_beneficiary);
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
- Used OpenZeppelin's battle-tested contracts for core functionality
- Implemented ReentrancyGuard for external calls
- Added comprehensive input validation
- Used SafeMath for arithmetic operations
- Implemented proper access control

2. Gas Optimization:
- Used custom errors instead of require statements
- Minimized storage operations
- Efficient computation of vested amounts
- Strategic use of immutable variables

3. Features:
- Flexible vesting schedules with cliff periods
- Revocable and non-revocable vesting options
- Precise time-based vesting calculations
- Emergency revocation mechanism

4. Error Handling:
- Custom errors for better gas efficiency and clarity
- Comprehensive input validation
- Clear error messages for different scenarios

5. Best Practices:
- Comprehensive event emissions
- Clear function documentation
- Gas-efficient storage patterns
- Professional code structure

To deploy this contract:
1. Deploy the ERC20 token contract first
2. Deploy this vesting contract with the token address
3. Approve the vesting contract to spend tokens
4. Create vesting schedules for beneficiaries

Would you like me to explain any particular aspect in more detail?