// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @notice Method surface of the built-in LLM Parse Website agent (id 12875401142070969085).
/// @dev Only used for `.selector` when ABI-encoding request payloads — never called directly.
///      Covenant's milestone check is one ExtractANumber request: the agent fetches `url`, reads the
///      English `prompt`/`description`, and each validator independently returns a 0..100 score for
///      how well the clause is satisfied. The platform hands those back in `Response.result`
///      (ABI-encoded uint256); Covenant takes the median so one validator can't swing a payout.
interface IParseWebsiteAgent {
    /// @param key                 Identifier for the extracted field.
    /// @param description         Context explaining what the model should evaluate.
    /// @param min                 Lower bound of the answer (0,0 disables bounds).
    /// @param max                 Upper bound of the answer.
    /// @param prompt              Natural-language instruction; also used as the search query.
    /// @param url                 Target URL (or domain when resolveUrl is true).
    /// @param resolveUrl          true = search the domain; false = scrape the URL directly.
    /// @param numPages            Max pages to fetch (capped at 1 when resolveUrl is false).
    /// @param confidenceThreshold Min model confidence (0..100) for a valid response.
    function ExtractANumber(
        string calldata key,
        string calldata description,
        uint256 min,
        uint256 max,
        string calldata prompt,
        string calldata url,
        bool resolveUrl,
        uint8 numPages,
        uint8 confidenceThreshold
    ) external returns (uint256);

    function ExtractString(
        string calldata key,
        string calldata description,
        string[] calldata options,
        string calldata prompt,
        string calldata url,
        bool resolveUrl,
        uint8 numPages,
        uint8 confidenceThreshold
    ) external returns (string memory);
}
