// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @notice Method surface of the built-in LLM Inference agent.
/// @dev Only used for `.selector` when ABI-encoding request payloads — never called directly.
///      Covenant's judge leg uses `inferNumber` to score an English clause 0..100 against fetched
///      evidence; the validator subcommittee runs the model independently and the platform returns
///      each validator's answer in `Response.result` (ABI-encoded int256), which Covenant aggregates
///      by median so no single validator can swing a payout.
interface ILlmAgent {
    /// @param prompt          The question / clause to evaluate.
    /// @param system          System instruction steering the model.
    /// @param minValue        Lower bound of the allowed answer.
    /// @param maxValue        Upper bound of the allowed answer.
    /// @param chainOfThought  Whether the model may reason before answering.
    function inferNumber(
        string calldata prompt,
        string calldata system,
        int256 minValue,
        int256 maxValue,
        bool chainOfThought
    ) external returns (int256);

    /// @param allowedValues  Closed set the answer must be drawn from (empty = open string).
    function inferString(
        string calldata prompt,
        string calldata system,
        bool chainOfThought,
        string[] calldata allowedValues
    ) external returns (string memory);

    function inferChat(string[] calldata roles, string[] calldata messages, bool chainOfThought)
        external
        returns (string memory);
}
