// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./DisputeRegistry.sol";

/**
 * @title ArbitratorPool
 * @notice Manages a panel of 3 arbitrators for AgentCourt on X Layer.
 *
 *  Voting rules:
 *  - Each arbitrator may cast exactly one vote (true = claimant wins,
 *    false = respondent wins) per dispute.
 *  - When any two arbitrators agree (2-of-3 majority) the dispute is
 *    automatically resolved by calling DisputeRegistry.resolveDispute().
 */
contract ArbitratorPool {
    // -------------------------------------------------------------------------
    // Constants
    // -------------------------------------------------------------------------

    uint256 public constant TOTAL_ARBITRATORS = 3;
    uint256 public constant REQUIRED_VOTES     = 2;   // simple majority

    // -------------------------------------------------------------------------
    // Types
    // -------------------------------------------------------------------------

    struct VoteRecord {
        bool    hasVoted;
        bool    vote;       // true = claimant wins
    }

    struct DisputeVotes {
        uint8   votesFor;      // votes where vote == true
        uint8   votesAgainst;  // votes where vote == false
        bool    concluded;     // true after resolveDispute has been called
        /// @dev arbitrator address => their individual record
        mapping(address => VoteRecord) records;
    }

    // -------------------------------------------------------------------------
    // State
    // -------------------------------------------------------------------------

    /// @notice The three authorised arbitrators (immutable after construction).
    address[TOTAL_ARBITRATORS] public arbitrators;

    /// @notice The DisputeRegistry this pool operates on.
    DisputeRegistry public immutable registry;

    /// @dev Voting state per dispute ID.
    mapping(uint256 => DisputeVotes) private _votes;

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------

    event VoteCast(
        uint256 indexed disputeId,
        address indexed arbitrator,
        bool    vote,
        uint8   votesFor,
        uint8   votesAgainst
    );

    event ConsensusReached(uint256 indexed disputeId, bool claimantWins);

    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    error NotAnArbitrator(address caller);
    error AlreadyVoted(uint256 disputeId, address arbitrator);
    error DisputeAlreadyConcluded(uint256 disputeId);

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    /**
     * @param arb0      First arbitrator address.
     * @param arb1      Second arbitrator address.
     * @param arb2      Third arbitrator address.
     * @param _registry Address of the deployed DisputeRegistry contract.
     */
    constructor(
        address arb0,
        address arb1,
        address arb2,
        address _registry
    ) {
        arbitrators[0] = arb0;
        arbitrators[1] = arb1;
        arbitrators[2] = arb2;
        registry = DisputeRegistry(payable(_registry));
    }

    // -------------------------------------------------------------------------
    // Core — Voting
    // -------------------------------------------------------------------------

    /**
     * @notice Cast a vote on an open dispute.
     * @param disputeId The ID of the dispute to vote on.
     * @param vote      True = claimant should win, false = respondent should win.
     */
    function voteOnDispute(uint256 disputeId, bool vote) external {
        // 1. Validate the caller is a registered arbitrator.
        if (!_isArbitrator(msg.sender)) revert NotAnArbitrator(msg.sender);

        DisputeVotes storage dv = _votes[disputeId];

        // 2. Guard against double-voting and post-resolution votes.
        if (dv.concluded) revert DisputeAlreadyConcluded(disputeId);
        if (dv.records[msg.sender].hasVoted) revert AlreadyVoted(disputeId, msg.sender);

        // 3. Record vote.
        dv.records[msg.sender] = VoteRecord({hasVoted: true, vote: vote});
        if (vote) {
            dv.votesFor++;
        } else {
            dv.votesAgainst++;
        }

        emit VoteCast(disputeId, msg.sender, vote, dv.votesFor, dv.votesAgainst);

        // 4. Check for majority and auto-resolve if reached.
        if (dv.votesFor >= REQUIRED_VOTES || dv.votesAgainst >= REQUIRED_VOTES) {
            bool claimantWins = dv.votesFor >= REQUIRED_VOTES;
            dv.concluded = true;

            emit ConsensusReached(disputeId, claimantWins);

            // Delegate final resolution to the registry.
            registry.resolveDispute(disputeId, claimantWins);
        }
    }

    // -------------------------------------------------------------------------
    // Views
    // -------------------------------------------------------------------------

    /**
     * @notice Returns the current vote tallies for a dispute.
     * @param disputeId The dispute ID to query.
     * @return votesFor      Number of "claimant wins" votes so far.
     * @return votesAgainst  Number of "respondent wins" votes so far.
     * @return concluded     Whether a majority was reached and dispute resolved.
     */
    function getVoteSummary(uint256 disputeId)
        external
        view
        returns (uint8 votesFor, uint8 votesAgainst, bool concluded)
    {
        DisputeVotes storage dv = _votes[disputeId];
        return (dv.votesFor, dv.votesAgainst, dv.concluded);
    }

    /**
     * @notice Check whether a specific arbitrator has voted on a dispute.
     * @param disputeId  The dispute ID.
     * @param arbitrator The arbitrator to query.
     * @return hasVoted  True if a vote was recorded.
     * @return vote      The vote value (only meaningful if hasVoted == true).
     */
    function getArbitratorVote(uint256 disputeId, address arbitrator)
        external
        view
        returns (bool hasVoted, bool vote)
    {
        VoteRecord storage vr = _votes[disputeId].records[arbitrator];
        return (vr.hasVoted, vr.vote);
    }

    /**
     * @notice Returns all three arbitrator addresses.
     */
    function getArbitrators() external view returns (address[TOTAL_ARBITRATORS] memory) {
        return arbitrators;
    }

    // -------------------------------------------------------------------------
    // Internal helpers
    // -------------------------------------------------------------------------

    function _isArbitrator(address addr) internal view returns (bool) {
        for (uint256 i = 0; i < TOTAL_ARBITRATORS; i++) {
            if (arbitrators[i] == addr) return true;
        }
        return false;
    }
}
