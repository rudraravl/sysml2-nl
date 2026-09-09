// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title AttestationRegistry
 * @notice Manages verifiable attestations without custodying any tokens.
 * @dev Each attestation is identified by a unique bytes32 identifier and links
 *      an issuer, a schema identifier, and a cryptographic hash of the attestation data.
 *      Only the original issuer may revoke an attestation. A maximum of 10,000
 *      attestations may be issued per schema identifier.
 */
contract AttestationRegistry {
    /* ------------------------------------------------------------------ */
    /*                              ERRORS                                */
    /* ------------------------------------------------------------------ */

    error AttestationAlreadyExists(bytes32 attestationId);
    error AttestationDoesNotExist(bytes32 attestationId);
    error AttestationAlreadyRevoked(bytes32 attestationId);
    error NotAttestationIssuer(bytes32 attestationId, address caller);
    error SchemaAttestationLimitReached(bytes32 schemaId, uint256 limit);
    error InvalidAttestationId(bytes32 attestationId);
    error InvalidSchemaId(bytes32 schemaId);
    error InvalidDataHash(bytes32 dataHash);
    error IndexOutOfBounds(uint256 index);

    /* ------------------------------------------------------------------ */
    /*                              EVENTS                                */
    /* ------------------------------------------------------------------ */

    /**
     * @dev Emitted when a new attestation is issued.
     * @param attestationId Unique identifier of the attestation.
     * @param issuer Address of the attestation issuer.
     * @param schemaId Identifier of the schema used.
     * @param dataHash Cryptographic hash of the attestation data.
     * @param issuedAt Block timestamp at issuance.
     */
    event AttestationIssued(
        bytes32 indexed attestationId,
        address indexed issuer,
        bytes32 indexed schemaId,
        bytes32 dataHash,
        uint64 issuedAt
    );

    /**
     * @dev Emitted when an attestation is revoked.
     * @param attestationId Unique identifier of the attestation.
     * @param issuer Address of the attestation issuer.
     * @param schemaId Identifier of the schema used.
     * @param revokedAt Block timestamp at revocation.
     */
    event AttestationRevoked(
        bytes32 indexed attestationId,
        address indexed issuer,
        bytes32 indexed schemaId,
        uint64 revokedAt
    );

    /* ------------------------------------------------------------------ */
    /*                             CONSTANTS                             */
    /* ------------------------------------------------------------------ */

    /// @dev Maximum number of attestations that may be issued per schema identifier.
    uint256 public constant MAX_ATTESTATIONS_PER_SCHEMA = 10_000;

    /* ------------------------------------------------------------------ */
    /*                             STRUCTS                                */
    /* ------------------------------------------------------------------ */

    struct Attestation {
        address issuer;
        bytes32 schemaId;
        bytes32 dataHash;
        uint64 issuedAt;
        uint64 revokedAt;
        bool revoked;
        bool exists;
    }

    /* ------------------------------------------------------------------ */
    /*                            STORAGE                                 */
    /* ------------------------------------------------------------------ */

    /// @dev Maps attestation identifiers to their stored records.
    mapping(bytes32 attestationId => Attestation) private s_attestations;

    /// @dev Tracks the number of attestations issued per schema identifier.
    mapping(bytes32 schemaId => uint256 count) private s_schemaAttestationCount;

    /// @dev Ordered list of all attestation identifiers ever issued.
    bytes32[] private s_attestationIds;

    /* ------------------------------------------------------------------ */
    /*                            MODIFIERS                               */
    /* ------------------------------------------------------------------ */

    modifier onlyExistingAttestation(bytes32 attestationId) {
        if (attestationId == bytes32(0)) revert InvalidAttestationId(attestationId);
        if (!s_attestations[attestationId].exists) revert AttestationDoesNotExist(attestationId);
        _;
    }

    /* ------------------------------------------------------------------ */
    /*                           CONSTRUCTOR                              */
    /* ------------------------------------------------------------------ */

    constructor() {}

    /* ------------------------------------------------------------------ */
    /*                       EXTERNAL / PUBLIC API                        */
    /* ------------------------------------------------------------------ */

    /**
     * @notice Issues a new attestation. The caller becomes the issuer of record.
     * @param attestationId Unique identifier for the new attestation.
     * @param schemaId Identifier of the schema under which the attestation is issued.
     * @param dataHash Cryptographic hash of the attestation data.
     * @return The attestation identifier.
     */
    function issueAttestation(
        bytes32 attestationId,
        bytes32 schemaId,
        bytes32 dataHash
    ) external returns (bytes32) {
        if (attestationId == bytes32(0)) revert InvalidAttestationId(attestationId);
        if (schemaId == bytes32(0)) revert InvalidSchemaId(schemaId);
        if (dataHash == bytes32(0)) revert InvalidDataHash(dataHash);
        if (s_attestations[attestationId].exists) {
            revert AttestationAlreadyExists(attestationId);
        }
        if (s_schemaAttestationCount[schemaId] >= MAX_ATTESTATIONS_PER_SCHEMA) {
            revert SchemaAttestationLimitReached(schemaId, MAX_ATTESTATIONS_PER_SCHEMA);
        }

        // Effects
        s_attestations[attestationId] = Attestation({
            issuer: msg.sender,
            schemaId: schemaId,
            dataHash: dataHash,
            issuedAt: uint64(block.timestamp),
            revokedAt: 0,
            revoked: false,
            exists: true
        });
        s_attestationIds.push(attestationId);
        s_schemaAttestationCount[schemaId] += 1;

        emit AttestationIssued(
            attestationId,
            msg.sender,
            schemaId,
            dataHash,
            uint64(block.timestamp)
        );

        return attestationId;
    }

    /**
     * @notice Revokes an existing attestation. Only the original issuer may revoke.
     * @param attestationId Unique identifier of the attestation to revoke.
     */
    function revokeAttestation(bytes32 attestationId)
        external
        onlyExistingAttestation(attestationId)
    {
        Attestation storage att = s_attestations[attestationId];
        if (att.issuer != msg.sender) {
            revert NotAttestationIssuer(attestationId, msg.sender);
        }
        if (att.revoked) {
            revert AttestationAlreadyRevoked(attestationId);
        }

        // Effects
        att.revoked = true;
        att.revokedAt = uint64(block.timestamp);

        emit AttestationRevoked(
            attestationId,
            att.issuer,
            att.schemaId,
            uint64(block.timestamp)
        );
    }

    /**
     * @notice Returns the full details of an attestation.
     * @param attestationId Unique identifier of the attestation.
     * @return issuer The address that issued the attestation.
     * @return schemaId The schema identifier.
     * @return dataHash The cryptographic hash of the attestation data.
     * @return issuedAt Timestamp of issuance.
     * @return revokedAt Timestamp of revocation (0 if not revoked).
     * @return revoked Whether the attestation has been revoked.
     */
    function getAttestation(bytes32 attestationId)
        external
        view
        onlyExistingAttestation(attestationId)
        returns (
            address issuer,
            bytes32 schemaId,
            bytes32 dataHash,
            uint64 issuedAt,
            uint64 revokedAt,
            bool revoked
        )
    {
        Attestation storage att = s_attestations[attestationId];
        return (
            att.issuer,
            att.schemaId,
            att.dataHash,
            att.issuedAt,
            att.revokedAt,
            att.revoked
        );
    }

    /**
     * @notice Returns whether an attestation exists and has not been revoked.
     * @param attestationId Unique identifier of the attestation.
     * @return True if the attestation exists and is not revoked.
     */
    function isAttestationValid(bytes32 attestationId) external view returns (bool) {
        Attestation storage att = s_attestations[attestationId];
        return att.exists && !att.revoked;
    }

    /**
     * @notice Returns whether an attestation identifier has been issued.
     * @param attestationId Unique identifier of the attestation.
     * @return True if the attestation exists.
     */
    function attestationExists(bytes32 attestationId) external view returns (bool) {
        return s_attestations[attestationId].exists;
    }

    /**
     * @notice Returns the number of attestations issued under a given schema.
     * @param schemaId The schema identifier.
     * @return The count of attestations issued under the schema.
     */
    function getSchemaAttestationCount(bytes32 schemaId) external view returns (uint256) {
        return s_schemaAttestationCount[schemaId];
    }

    /**
     * @notice Returns the total number of attestations issued.
     * @return The total count of attestation identifiers stored.
     */
    function getTotalAttestations() external view returns (uint256) {
        return s_attestationIds.length;
    }

    /**
     * @notice Returns the attestation identifier at a given index.
     * @param index The sequential index in the list of all attestations.
     * @return The attestation identifier.
     */
    function getAttestationIdByIndex(uint256 index) external view returns (bytes32) {
        if (index >= s_attestationIds.length) revert IndexOutOfBounds(index);
        return s_attestationIds[index];
    }
}
