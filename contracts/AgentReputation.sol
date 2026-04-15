// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title AgentReputation
 * @notice Tracks on-chain reputation scores for AI agents on X Layer.
 *         Scores are adjusted by DisputeRegistry upon dispute resolution.
 *         Claimants who win gain +10; respondents who lose lose -20.
 */
contract AgentReputation {
    // -------------------------------------------------------------------------
    // State
    // -------------------------------------------------------------------------

    /// @notice Owner who can set the authorised DisputeRegistry address once.
    address public immutable owner;

    /// @notice The only contract allowed to call updateReputation.
    address public disputeRegistry;

    /// @notice reputation[agent] — can be negative (int256).
    mapping(address => int256) private reputation;

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------

    event ReputationUpdated(address indexed agent, int256 delta, int256 newScore);
    event DisputeRegistrySet(address indexed registry);

    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    error OnlyDisputeRegistry();
    error OnlyOwner();
    error RegistryAlreadySet();

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    constructor() {
        owner = msg.sender;
    }

    // -------------------------------------------------------------------------
    // Admin
    // -------------------------------------------------------------------------

    /**
     * @notice Set the DisputeRegistry address. Can only be called once by owner.
     * @param _registry Address of the deployed DisputeRegistry contract.
     */
    function setDisputeRegistry(address _registry) external {
        if (msg.sender != owner) revert OnlyOwner();
        if (disputeRegistry != address(0)) revert RegistryAlreadySet();
        disputeRegistry = _registry;
        emit DisputeRegistrySet(_registry);
    }

    // -------------------------------------------------------------------------
    // Core
    // -------------------------------------------------------------------------

    /**
     * @notice Update reputation scores after a dispute is resolved.
     *         Only the DisputeRegistry may call this.
     * @param claimant      The party who filed the dispute.
     * @param respondent    The party who was accused.
     * @param claimantWins  True if the ruling favours the claimant.
     */
    function updateReputation(
        address claimant,
        address respondent,
        bool claimantWins
    ) external {
        if (msg.sender != disputeRegistry) revert OnlyDisputeRegistry();

        if (claimantWins) {
            reputation[claimant] += 10;
            reputation[respondent] -= 20;

            emit ReputationUpdated(claimant,  10, reputation[claimant]);
            emit ReputationUpdated(respondent, -20, reputation[respondent]);
        } else {
            // Frivolous claim: penalise the claimant slightly.
            reputation[claimant] -= 5;
            emit ReputationUpdated(claimant, -5, reputation[claimant]);
        }
    }

    // -------------------------------------------------------------------------
    // Views
    // -------------------------------------------------------------------------

    /**
     * @notice Returns the current reputation score of an agent.
     * @param agent Address to query.
     */
    function getReputation(address agent) external view returns (int256) {
        return reputation[agent];
    }
}
