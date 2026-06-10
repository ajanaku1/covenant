// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IAgentPlatform, IAgentConsumer, Response, Request, ResponseStatus, ConsensusType} from "./IAgentPlatform.sol";
import {IJsonApiAgent} from "./IJsonApiAgent.sol";
import {ILlmAgent} from "./ILlmAgent.sol";

/// @title AgentProbe
/// @notice Phase-0 de-risk helper: the smallest contract that proves the agent leg end-to-end —
///         createAdvancedRequest -> validator subcommittee -> handleResponse -> stored result + receipt.
/// @dev Mirrors exactly the callback discipline the full Covenant relies on:
///      (1) only the platform may call back, (2) every ResponseStatus is handled, (3) the median of
///      validator answers is taken so no single validator decides the outcome. Once this returns a
///      viewable receipt on testnet (~1 STT), the same wiring is trusted inside Covenant.
contract AgentProbe is IAgentConsumer {
    /// @dev JSON API Request agent id (Somnia testnet). Overridable per request for forward-compat.
    uint256 public constant JSON_API_AGENT_ID = 13174292974160097713;

    IAgentPlatform public immutable platform;
    address public immutable owner;

    /// @notice Snapshot of the most recent resolved request, for off-chain inspection.
    struct LastResult {
        uint256 requestId;
        ResponseStatus status;
        uint256 value; // median of validator results (interpreted as uint256/int256 by the caller)
        uint256 responseCount;
        uint256 receipt; // receipt of the first responding validator (Agent Explorer link key)
    }

    LastResult public last;

    event RequestSent(uint256 indexed requestId, uint256 indexed agentId);
    event ResponseHandled(uint256 indexed requestId, ResponseStatus status, uint256 median, uint256 responseCount);

    error NotPlatform();
    error NotOwner();

    constructor(IAgentPlatform _platform) {
        platform = _platform;
        owner = msg.sender;
    }

    /// @notice Ask the JSON API agent for a numeric field, fanning out to `subSize` validators.
    /// @dev Send enough value to cover the per-validator deposit; surplus is refunded by the platform.
    function probeJsonUint(
        string calldata url,
        string calldata jsonPath,
        uint8 decimals,
        uint256 subSize,
        uint256 threshold
    ) external payable returns (uint256 requestId) {
        if (msg.sender != owner) revert NotOwner();
        bytes memory payload = abi.encodeWithSelector(IJsonApiAgent.fetchUint.selector, url, jsonPath, decimals);
        requestId = platform.createAdvancedRequest{value: msg.value}(
            JSON_API_AGENT_ID,
            address(this),
            this.handleResponse.selector,
            payload,
            subSize,
            threshold,
            ConsensusType.Threshold,
            60 // timeout (seconds); 0 reverts InvalidTimeout
        );
        emit RequestSent(requestId, JSON_API_AGENT_ID);
    }

    /// @notice Ask the LLM agent to score an English clause 0..100, fanning out to `subSize` validators.
    function probeLlmScore(
        uint256 llmAgentId,
        string calldata prompt,
        string calldata system,
        uint256 subSize,
        uint256 threshold
    ) external payable returns (uint256 requestId) {
        if (msg.sender != owner) revert NotOwner();
        bytes memory payload =
            abi.encodeWithSelector(ILlmAgent.inferNumber.selector, prompt, system, int256(0), int256(100), false);
        requestId = platform.createAdvancedRequest{value: msg.value}(
            llmAgentId,
            address(this),
            this.handleResponse.selector,
            payload,
            subSize,
            threshold,
            ConsensusType.Threshold,
            60 // timeout (seconds); 0 reverts InvalidTimeout
        );
        emit RequestSent(requestId, llmAgentId);
    }

    /// @inheritdoc IAgentConsumer
    function handleResponse(
        uint256 requestId,
        Response[] memory responses,
        ResponseStatus status,
        Request memory /* details */
    )
        external
        override
    {
        if (msg.sender != address(platform)) revert NotPlatform();

        // Handle every terminal status explicitly; only Success carries usable results.
        if (status != ResponseStatus.Success) {
            last = LastResult({requestId: requestId, status: status, value: 0, responseCount: 0, receipt: 0});
            emit ResponseHandled(requestId, status, 0, 0);
            return;
        }

        (uint256 median, uint256 ok, uint256 receipt) = _aggregate(responses);
        last = LastResult({requestId: requestId, status: status, value: median, responseCount: ok, receipt: receipt});
        emit ResponseHandled(requestId, status, median, ok);
    }

    /// @dev Median of the successful validator results; ignores non-Success entries. Each result is
    ///      ABI-encoded as the agent method's return type (uint256 for fetchUint, int256 for inferNumber,
    ///      both 32 bytes), decoded here as uint256.
    function _aggregate(Response[] memory responses)
        private
        pure
        returns (uint256 median, uint256 ok, uint256 firstReceipt)
    {
        uint256 n = responses.length;
        uint256[] memory vals = new uint256[](n);
        for (uint256 i = 0; i < n; i++) {
            Response memory r = responses[i];
            if (r.status != ResponseStatus.Success || r.result.length != 32) continue;
            if (ok == 0) firstReceipt = r.receipt;
            vals[ok++] = abi.decode(r.result, (uint256));
        }
        if (ok == 0) return (0, 0, 0);
        median = _median(vals, ok);
    }

    /// @dev Insertion sort over the first `count` entries, then pick the middle (lower-mid for even count).
    function _median(uint256[] memory vals, uint256 count) private pure returns (uint256) {
        for (uint256 i = 1; i < count; i++) {
            uint256 key = vals[i];
            uint256 j = i;
            while (j > 0 && vals[j - 1] > key) {
                vals[j] = vals[j - 1];
                j--;
            }
            vals[j] = key;
        }
        return vals[(count - 1) / 2];
    }

    /// @notice Fund the probe (validator deposits) or recover surplus.
    receive() external payable {}

    function withdraw() external {
        if (msg.sender != owner) revert NotOwner();
        (bool sent,) = owner.call{value: address(this).balance}("");
        require(sent, "withdraw failed");
    }
}
