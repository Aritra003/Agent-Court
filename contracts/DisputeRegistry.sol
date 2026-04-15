// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./AgentReputation.sol";

/**
 * @title DisputeRegistry
 * @notice Core registry for AgentCourt disputes on X Layer.
 *
 *  Flow:
 *  1. Any address calls fileDispute() with a 0.001 OKB filing fee.
 *  2. Either party calls submitEvidence() to attach evidence hashes.
 *  3. ArbitratorPool reaches a 2-of-3 consensus and calls resolveDispute().
 *  4. On resolution the filing fee is refunded to the claimant if they win,
 *     and AgentReputation scores are updated.
 */
contract DisputeRegistry {
    // -------------------------------------------------------------------------
    // Constants
    // -------------------------------------------------------------------------

    /// @notice Required filing fee: 0.001 OKB (18-decimal native token).
    uint256 public constant FILING_FEE = 0.001 ether;

    // -------------------------------------------------------------------------
    // Types
    // -------------------------------------------------------------------------

    enum Status { Filed, Resolved }

    struct Dispute {
        uint256     id;
        address     claimant;
        address     respondent;
        bytes32     benchCertHash;   // hash of the AI agent benchmark certificate
        uint256     claimedDamages;  // informational — expressed in wei
        Status      status;
        uint256     filedAt;
        bool        claimantWon;     // set on resolution
    }

    // -------------------------------------------------------------------------
    // State
    // -------------------------------------------------------------------------

    /// @notice Owner used only for one-time setup of the ArbitratorPool address.
    address public immutable owner;

    /// @notice ArbitratorPool contract — the only address allowed to call resolveDispute().
    address public arbitratorPool;

    /// @notice AgentReputation contract called on every resolution.
    AgentReputation public immutable reputationContract;

    /// @dev Internal dispute counter (1-indexed so 0 can mean "not found").
    uint256 private _nextId = 1;

    /// @dev Primary dispute storage.
    mapping(uint256 => Dispute) private _disputes;

    /// @dev Evidence blobs attached to each dispute (append-only list per id).
    mapping(uint256 => bytes[]) private _evidence;

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------

    event DisputeFiled(
        uint256 indexed disputeId,
        address indexed claimant,
        address indexed respondent,
        bytes32 benchCertHash,
        uint256 claimedDamages
    );

    event EvidenceSubmitted(uint256 indexed disputeId, address indexed submitter, uint256 evidenceIndex);

    event DisputeResolved(uint256 indexed disputeId, bool claimantWon, uint256 compensationPaid);

    event ArbitratorPoolSet(address indexed pool);

    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    error InsufficientFilingFee(uint256 required, uint256 provided);
    error DisputeNotFound(uint256 disputeId);
    error DisputeAlreadyResolved(uint256 disputeId);
    error OnlyArbitratorPool();
    error OnlyOwner();
    error PoolAlreadySet();
    error TransferFailed();
    error InvalidRespondent();

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    /**
     * @param _reputationContract Address of the deployed AgentReputation contract.
     */
    constructor(address _reputationContract) {
        owner = msg.sender;
        reputationContract = AgentReputation(_reputationContract);
    }

    // -------------------------------------------------------------------------
    // Admin
    // -------------------------------------------------------------------------

    /**
     * @notice Set the ArbitratorPool address. Can only be called once by owner.
     * @param _pool Address of the deployed ArbitratorPool contract.
     */
    function setArbitratorPool(address _pool) external {
        if (msg.sender != owner) revert OnlyOwner();
        if (arbitratorPool != address(0)) revert PoolAlreadySet();
        arbitratorPool = _pool;
        emit ArbitratorPoolSet(_pool);
    }

    // -------------------------------------------------------------------------
    // Core — Filing
    // -------------------------------------------------------------------------

    /**
     * @notice File a new dispute against a respondent.
     * @param respondent     The AI agent / address being accused.
     * @param benchCertHash  Keccak256 hash of the relevant benchmark certificate.
     * @param claimedDamages Damages amount (wei) the claimant is seeking.
     * @return disputeId     The unique ID assigned to this dispute.
     */
    function fileDispute(
        address respondent,
        bytes32 benchCertHash,
        uint256 claimedDamages
    ) external payable returns (uint256 disputeId) {
        if (msg.value < FILING_FEE) revert InsufficientFilingFee(FILING_FEE, msg.value);
        if (respondent == address(0) || respondent == msg.sender) revert InvalidRespondent();

        disputeId = _nextId++;

        _disputes[disputeId] = Dispute({
            id:             disputeId,
            claimant:       msg.sender,
            respondent:     respondent,
            benchCertHash:  benchCertHash,
            claimedDamages: claimedDamages,
            status:         Status.Filed,
            filedAt:        block.timestamp,
            claimantWon:    false
        });

        emit DisputeFiled(disputeId, msg.sender, respondent, benchCertHash, claimedDamages);
    }

    // -------------------------------------------------------------------------
    // Core — Evidence
    // -------------------------------------------------------------------------

    /**
     * @notice Attach raw evidence bytes to an open dispute.
     *         Either party (or anyone) may submit evidence while it is unresolved.
     * @param disputeId The dispute to annotate.
     * @param evidence  Arbitrary bytes — typically an IPFS CID or signed payload.
     */
    function submitEvidence(uint256 disputeId, bytes calldata evidence) external {
        Dispute storage d = _requireOpen(disputeId);
        uint256 idx = _evidence[disputeId].length;
        _evidence[disputeId].push(evidence);

        emit EvidenceSubmitted(disputeId, msg.sender, idx);
    }

    // -------------------------------------------------------------------------
    // Core — Resolution
    // -------------------------------------------------------------------------

    /**
     * @notice Resolve a dispute. Only callable by the ArbitratorPool contract
     *         once a 2-of-3 voting consensus has been reached.
     * @param disputeId    The dispute to resolve.
     * @param claimantWins True if the ruling favours the claimant.
     */
    function resolveDispute(uint256 disputeId, bool claimantWins) external {
        if (msg.sender != arbitratorPool) revert OnlyArbitratorPool();

        Dispute storage d = _requireOpen(disputeId);
        d.status     = Status.Resolved;
        d.claimantWon = claimantWins;

        // Update on-chain reputation scores.
        reputationContract.updateReputation(d.claimant, d.respondent, claimantWins);

        // Transfer the filing fee to the claimant if they prevailed.
        uint256 compensation = claimantWins ? FILING_FEE : 0;
        if (compensation > 0) {
            (bool ok, ) = d.claimant.call{value: compensation}("");
            if (!ok) revert TransferFailed();
        }

        emit DisputeResolved(disputeId, claimantWins, compensation);
    }

    // -------------------------------------------------------------------------
    // Views
    // -------------------------------------------------------------------------

    /**
     * @notice Retrieve the full record for a dispute.
     * @param disputeId The dispute ID to query.
     */
    function getDispute(uint256 disputeId) external view returns (Dispute memory) {
        if (_disputes[disputeId].id == 0) revert DisputeNotFound(disputeId);
        return _disputes[disputeId];
    }

    /**
     * @notice Returns the evidence list for a dispute.
     * @param disputeId The dispute ID to query.
     */
    function getEvidence(uint256 disputeId) external view returns (bytes[] memory) {
        return _evidence[disputeId];
    }

    /**
     * @notice Returns the total number of disputes ever filed (includes resolved).
     */
    function getDisputeCount() external view returns (uint256) {
        return _nextId - 1;
    }

    // -------------------------------------------------------------------------
    // Internal helpers
    // -------------------------------------------------------------------------

    function _requireOpen(uint256 disputeId) internal view returns (Dispute storage d) {
        d = _disputes[disputeId];
        if (d.id == 0) revert DisputeNotFound(disputeId);
        if (d.status == Status.Resolved) revert DisputeAlreadyResolved(disputeId);
    }

    // -------------------------------------------------------------------------
    // Receive — accept plain OKB transfers (e.g. top-ups from protocol treasury)
    // -------------------------------------------------------------------------

    receive() external payable {}
}
