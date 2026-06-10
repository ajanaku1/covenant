// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @notice Status of an individual validator response and of the overall request.
/// @dev Values match the Somnia agent platform: None=0, Pending=1, Success=2, Failed=3, TimedOut=4.
enum ResponseStatus {
    None,
    Pending,
    Success,
    Failed,
    TimedOut
}

/// @notice How a request's subcommittee reaches consensus.
enum ConsensusType {
    Majority,
    Threshold
}

/// @notice A single validator's signed response to an agent request.
struct Response {
    address validator;
    bytes result;
    ResponseStatus status;
    uint256 receipt;
    uint256 timestamp;
    uint256 executionCost;
}

/// @notice Full request record handed back to the callback for context.
struct Request {
    uint256 id;
    address requester;
    address callbackAddress;
    bytes4 callbackSelector;
    address[] subcommittee;
    Response[] responses;
    uint256 responseCount;
    uint256 failureCount;
    uint256 threshold;
    uint256 createdAt;
    uint256 deadline;
    ResponseStatus status;
    ConsensusType consensusType;
    uint256 remainingBudget;
    uint256 perAgentBudget;
}

/// @notice The Somnia agent platform: invoke built-in agents and receive consensus callbacks.
/// @dev Testnet 0x037Bb9C718F3f7fe5eCBDB0b600D607b52706776, mainnet 0x5E5205CF39E766118C01636bED000A54D93163E6.
interface IAgentPlatform {
    /// @notice Invoke an agent with the platform's default subcommittee/consensus settings.
    function createRequest(uint256 agentId, address callbackAddress, bytes4 callbackSelector, bytes calldata payload)
        external
        payable
        returns (uint256 requestId);

    /// @notice Invoke an agent with an explicit subcommittee size, threshold, consensus type and timeout.
    function createAdvancedRequest(
        uint256 agentId,
        address callbackAddress,
        bytes4 callbackSelector,
        bytes calldata payload,
        uint256 subcommitteeSize,
        uint256 threshold,
        ConsensusType consensusType,
        uint256 timeout
    ) external payable returns (uint256 requestId);

    /// @notice Minimum value that must be sent with a request to cover validator execution.
    function getRequestDeposit() external view returns (uint256);
}

/// @notice The shape every callback contract must implement to receive agent responses.
interface IAgentConsumer {
    /// @notice Called by the platform once a request resolves (success, failure, or timeout).
    /// @dev Implementations MUST require(msg.sender == platform) and handle every ResponseStatus.
    function handleResponse(
        uint256 requestId,
        Response[] memory responses,
        ResponseStatus status,
        Request memory details
    ) external;
}
