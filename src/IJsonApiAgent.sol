// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @notice Method surface of the built-in JSON API Request agent.
/// @dev Only used for `.selector` when ABI-encoding request payloads — never called directly.
///      A request payload is `abi.encodeWithSelector(IJsonApiAgent.fetchUint.selector, url, jsonPath, decimals)`.
///      The agent fetches `url`, walks the dot-notation `jsonPath`, and the validator subcommittee
///      returns the value as `Response.result`, ABI-encoded as the method's return type.
interface IJsonApiAgent {
    /// @param url       HTTP(S) endpoint returning JSON.
    /// @param jsonPath  Dot-notation path into the response, e.g. "data.0.price".
    /// @param decimals  Fixed-point scaling applied to the numeric value.
    function fetchUint(string calldata url, string calldata jsonPath, uint8 decimals) external returns (uint256);

    function fetchInt(string calldata url, string calldata jsonPath, uint8 decimals) external returns (int256);

    function fetchString(string calldata url, string calldata jsonPath) external returns (string memory);

    function fetchBool(string calldata url, string calldata jsonPath) external returns (bool);

    function fetchUintArray(string calldata url, string calldata jsonPath, uint8 decimals)
        external
        returns (uint256[] memory);

    function fetchStringArray(string calldata url, string calldata jsonPath) external returns (string[] memory);
}
