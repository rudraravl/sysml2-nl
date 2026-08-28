package BioethicsOversightSystem {
	doc
	/*
	 * Comprehensive Bioethics Oversight System for managing and enforcing
	 * ethical standards for research involving human subjects.
	 * Covers the full lifecycle: submission, review, approval, monitoring, reporting.
	 */
	private import ScalarValues::Real;
	private import ScalarValues::String;
	private import ScalarValues::Boolean;
	private import ScalarValues::Natural;
	private import ISQ::*;
	private import SI::*;

	attribute def ReadabilityScore :> Real {
		doc /* Flesch-Kincaid readability score (0-100; higher = more readable). */
	}

	attribute def RiskProbability :> Real {
		doc /* Probability of harm to a participant (0..1). */
	}

	attribute def RiskSeverityScore :> Natural {
		doc /* Severity of harm on an ordinal scale (1..5). */
	}

	attribute def EncryptionKeyLengthBits :> Natural {
		doc /* Encryption key length in bits. */
	}

	attribute def DurationInDays :> Real {
		doc /* Duration expressed in days. */
	}

	enum def RiskLevel {
		minimal;
		moderate;
		high;
		severe;
	}

	enum def DecisionType {
		approval;
		modificationsRequired;
		rejection;
	}

	enum def EthicalPrinciple {
		autonomy;
		beneficence;
		nonMaleficence;
		justice;
	}

	enum def AuditStatus {
		conformant;
		nonConformant;
		requiresFollowUp;
	}

	enum def AuditFrequencyKind {
		monthly;
		quarterly;
		annual;
	}

	enum def LanguageCode {
		en;
		es;
		fr;
		de;
		zh;
	}

	attribute def PrincipalInvestigatorId :> String;
	attribute def ProtocolIdentifier :> String;
	attribute def DocumentIdentifier :> String;
	attribute def DecisionIdentifier :> String;
	attribute def AuditIdentifier :> String;
	attribute def ConcernIdentifier :> String;
	attribute def DatasetIdentifier :> String;
	attribute def ParticipantIdentifier :> String;
	attribute def BoardIdentifier :> String;

	item def ResearchProtocol {
		attribute protocolId : ProtocolIdentifier;
		attribute title : String;
		attribute principalInvestigator : PrincipalInvestigatorId;
		attribute institution : String;
		attribute expectedParticipantCount : Natural;
		attribute riskLevel : RiskLevel;
		attribute principleCompliance : EthicalPrinciple[0..*];
	}

	item def ConsentDocument {
		attribute documentId : DocumentIdentifier;
		attribute protocolId : ProtocolIdentifier;
		attribute langCode : LanguageCode;
		attribute readabilityScore : ReadabilityScore;
		attribute disclosesRisks : Boolean;
		attribute disclosesBenefits : Boolean;
		attribute disclosesRightToWithdraw : Boolean;
		attribute containsVoluntaryParticipation : Boolean;
		attribute containsConfidentialityNote : Boolean;
	}

	item def ReviewDecision {
		attribute decisionId : DecisionIdentifier;
		attribute protocolId : ProtocolIdentifier;
		attribute decisionType : DecisionType;
		attribute conditions : String[0..*];
		attribute reviewDurationDays : DurationInDays;
	}

	item def AuditReport {
		attribute reportId : AuditIdentifier;
		attribute protocolId : ProtocolIdentifier;
		attribute auditDate : String;
		attribute protocolAdherenceStatus : AuditStatus;
		attribute consentProcessStatus : AuditStatus;
		attribute dataProtectionStatus : AuditStatus;
		attribute adverseEventsReported : Boolean;
		attribute findings : String[0..*];
	}

	item def DeIdentifiedDataset {
		attribute datasetId : DatasetIdentifier;
		attribute sourceProtocolId : ProtocolIdentifier;
		attribute recordCount : Natural;
		attribute isDeIdentified : Boolean;
		attribute anonymizationMethod : String;
	}

	item def EncryptedPayload {
		attribute payloadId : DocumentIdentifier;
		attribute algorithm : String;
		attribute keyLengthBits : EncryptionKeyLengthBits;
		attribute ciphertextRef : String;
	}

	item def ParticipantConcern {
		attribute concernId : ConcernIdentifier;
		attribute participantId : ParticipantIdentifier;
		attribute protocolId : ProtocolIdentifier;
		attribute description : String;
		attribute raisedAt : String;
		attribute resolved : Boolean;
	}

	item def InvestigationReport {
		attribute concernId : ConcernIdentifier;
		attribute findings : String;
		attribute correctiveActions : String[0..*];
		attribute escalated : Boolean;
	}

	item def ApprovalNotification {
		attribute protocolId : ProtocolIdentifier;
		attribute decisionType : DecisionType;
		attribute issuedAt : String;
	}

	item def ConsentValidationResult {
		attribute documentId : DocumentIdentifier;
		attribute isValid : Boolean;
		attribute issues : String[0..*];
	}

	item def IdentifiableDataset {
		attribute datasetId : DatasetIdentifier;
		attribute sourceProtocolId : ProtocolIdentifier;
		attribute recordCount : Natural;
		attribute containsPII : Boolean;
	}

	port def ProtocolSubmissionPort {
		in submittedProtocol : ResearchProtocol;
		in submittedConsent : ConsentDocument;
	}

	port def DecisionEmissionPort {
		out issuedDecision : ReviewDecision;
		out approvalNotification : ApprovalNotification;
	}

	port def ConsentValidationPort {
		in consentForValidation : ConsentDocument;
		out validationResult : ConsentValidationResult;
	}

	port def AuditCoordinationPort {
		in protocolForAudit : ResearchProtocol;
		out auditReport : AuditReport;
	}

	port def DataProtectionPort {
		in sourceDataset : IdentifiableDataset;
		out deIdentifiedDataset : DeIdentifiedDataset;
		out encryptedPayload : EncryptedPayload;
	}

	port def AdvocacyChannelPort {
		in participantConcern : ParticipantConcern;
		out investigationReport : InvestigationReport;
	}

	port def ComplianceNotificationPort {
		out adverseEventNotice : Boolean;
		out deviationNotice : Boolean;
	}

	part def InstitutionalReviewBoard {
		doc /* Central committee responsible for formal review of research proposals. */
		attribute boardId : BoardIdentifier;
		attribute quorumSize : Natural;
		attribute meetingFrequencyDays : DurationInDays;

		port submissionReceiver : ProtocolSubmissionPort;
		port decisionEmitter : DecisionEmissionPort;
		port consentRequester : ~ConsentValidationPort;
		port complianceReceiver : ~ComplianceNotificationPort;

		state ReviewLifecycle {
			entry; then awaitingSubmission;
			state awaitingSubmission {
				doc /* Waiting for a research protocol and consent to be submitted. */
			}
			transition receiveSubmission
				first awaitingSubmission
				accept submissionReceiver.submittedProtocol
				then riskAssessment;
			state riskAssessment {
				doc /* Assess potential risks to participants. */
				do action assessRisk {
					in protocol : ResearchProtocol;
					out riskLevel : RiskLevel;
					out probability : RiskProbability;
					out severity : RiskSeverityScore;
					action classifyRisk;
					action estimateProbability;
					action estimateSeverity;
				}
			}
			transition finishRisk
				first riskAssessment
				then ethicalEvaluation;
			state ethicalEvaluation {
				doc /* Evaluate against autonomy, beneficence, non-maleficence, justice. */
				do action evaluateEthics {
					in protocol : ResearchProtocol;
					out principleScores : EthicalPrinciple[0..*];
					action assessAutonomy;
					action assessBeneficence;
					action assessNonMaleficence;
					action assessJustice;
				}
			}
			transition finishEthics
				first ethicalEvaluation
				then consentValidation;
			state consentValidation {
				do action validateConsentFlow {
					action requestValidation send ConsentDocument via consentRequester;
					action awaitResult accept result : ConsentValidationResult via consentRequester;
				}
			}
			transition finishConsent
				first consentValidation
				then decisionMaking;
			state decisionMaking {
				do action issueDecision {
					in protocol : ResearchProtocol;
					in riskLevel : RiskLevel;
					in principleScores : EthicalPrinciple[0..*];
					out decision : ReviewDecision;
					out notification : ApprovalNotification;
					action determineDecisionType;
					action recordConditions;
					action emitDecision send decision via decisionEmitter;
					action emitNotification send notification via decisionEmitter;
				}
			}
			transition completeCycle
				first decisionMaking
				then awaitingSubmission;
		}
	}

	part def ConsentManagementSystem {
		doc /* Supports the IRB by validating informed consent forms. */
		attribute systemId : BoardIdentifier;
		attribute minimumReadabilityScore : ReadabilityScore = 60.0;
		attribute supportedLanguages : LanguageCode[1..*] = (LanguageCode::en, LanguageCode::es, LanguageCode::fr);

		port consentReceiver : ConsentValidationPort;

		perform action validateConsent {
			in consent : ConsentDocument;
			out result : ConsentValidationResult;
			action checkReadability {
				doc /* Verify readability against minimum threshold. */
			}
			action checkRequiredDisclosures {
				doc /* Verify risks, benefits, right-to-withdraw are disclosed. */
			}
			action checkLanguageAvailability {
				doc /* Verify availability in required languages. */
			}
			action compileValidationResult;
		}
	}

	part def ComplianceMonitoringSystem {
		doc /* Performs regular audits of approved research projects. */
		attribute systemId : BoardIdentifier;
		attribute defaultAuditFrequency : AuditFrequencyKind;

		port auditInterface : AuditCoordinationPort;
		port complianceNotifier : ComplianceNotificationPort;

		state MonitoringLifecycle {
			entry; then idle;
			state idle;
			transition startAudit
				first idle
				accept auditInterface.protocolForAudit
				then auditing;
			state auditing {
				do action conductAudit {
					in protocol : ResearchProtocol;
					out report : AuditReport;
					action verifyProtocolAdherence;
					action verifyConsentProcess;
					action verifyDataProtection;
					action verifyAdverseEventReporting;
					action compileReport;
				}
			}
			transition auditComplete
				first auditing
				then reporting;
			state reporting {
				do action sendReport {
					action emitReport send conductAudit.report via auditInterface;
				}
			}
			transition reportComplete
				first reporting
				then idle;
		}
	}

	part def DataPrivacyModule {
		doc /* Safeguards sensitive participant information via de-identification, encryption, and access controls. */
		attribute moduleId : BoardIdentifier;
		attribute defaultEncryptionAlgorithm : String = "AES";
		attribute defaultKeyLengthBits : EncryptionKeyLengthBits = 256;
		attribute authorizedPersonnel : String[0..*];

		port dataProtection : DataProtectionPort;

		perform action protectData {
			in source : IdentifiableDataset;
			out deIdentified : DeIdentifiedDataset;
			out encrypted : EncryptedPayload;
			action removePersonalIdentifiers {
				doc /* Strip direct and quasi-identifiers. */
			}
			action applyEncryption {
				doc /* Encrypt the de-identified payload. */
			}
			action enforceAccessControls {
				doc /* Apply role-based access policy. */
			}
		}
	}

	part def ParticipantAdvocacyOffice {
		doc /* Direct point of contact and support resource for participants. */
		attribute officeId : BoardIdentifier;
		attribute advocateCount : Natural;
		attribute hotlineAvailable : Boolean;

		port advocacyInterface : AdvocacyChannelPort;

		state AdvocacyLifecycle {
			entry; then available;
			state available;
			transition receiveConcern
				first available
				accept advocacyInterface.participantConcern
				then investigating;
			state investigating {
				do action investigateConcern {
					in concern : ParticipantConcern;
					out report : InvestigationReport;
					action logConcern;
					action gatherEvidence;
					action determineCorrectiveAction;
					action decideEscalation;
				}
			}
			transition investigationDone
				first investigating
				then responding;
			state responding {
				do action sendReport {
					action emitReport send investigateConcern.report via advocacyInterface;
				}
			}
			transition responseDone
				first responding
				then available;
		}
	}

	requirement def EthicalReviewRequirement {
		doc /* All research involving human subjects must undergo ethical review by an IRB prior to participant enrollment. */
		subject protocol : ResearchProtocol;
		assume constraint submittedComplete {
			doc /* Protocol and consent documents are fully submitted. */
		}
		require constraint reviewedByIRB {
			doc /* IRB shall issue a formal decision before enrollment begins. */
		}
	}

	requirement def ConsentQualityRequirement {
		doc /* Consent documents must be readable, complete, and multilingual. */
		subject consent : ConsentDocument;
		require constraint readabilityAboveThreshold {
			doc /* Readability score must be at or above the minimum. */
		}
		require constraint requiredDisclosuresPresent {
			doc /* Risks, benefits, and right to withdraw must be disclosed. */
		}
		require constraint languagesAvailable {
			doc /* Consent must be available in all required languages. */
		}
	}

	requirement def DataPrivacyRequirement {
		doc /* Participant data must be de-identified, encrypted, and access-controlled. */
		subject dataset : DeIdentifiedDataset;
		assume constraint containsSensitiveData {
			doc /* Dataset is presumed to contain identifiable participant data. */
		}
		require constraint fullyDeIdentified {
			doc /* All direct and quasi-identifiers shall be removed. */
		}
		require constraint encryptedAtRest {
			doc /* Data shall be encrypted with AES-256 or stronger. */
		}
		require constraint accessControlled {
			doc /* Only authorized personnel shall have access. */
		}
	}

	requirement def MonitoringRequirement {
		doc /* Approved studies must be audited periodically to confirm adherence. */
		subject protocol : ResearchProtocol;
		require constraint periodicAudits {
			doc /* Audits shall be conducted at the defined frequency. */
		}
		require constraint adverseEventReporting {
			doc /* Adverse events shall be reported promptly. */
		}
	}

	requirement def AdvocacyRequirement {
		doc /* A participant advocacy office shall be available to receive concerns. */
		subject concern : ParticipantConcern;
		require constraint channelAvailable {
			doc /* A hotline channel shall be available. */
		}
		require constraint concernInvestigated {
			doc /* Every received concern shall be investigated. */
		}
	}

	part def BioethicsSystem {
		doc /* Top-level assembly integrating all oversight components. */
		attribute systemId : BoardIdentifier;
		attribute jurisdiction : String;

		part irb : InstitutionalReviewBoard {
			attribute boardId : BoardIdentifier = "IRB-001";
			attribute quorumSize : Natural = 5;
			attribute meetingFrequencyDays : DurationInDays = 30;
		}
		part consentMgmt : ConsentManagementSystem {
			attribute systemId : BoardIdentifier = "CMS-001";
			attribute minimumReadabilityScore : ReadabilityScore = 60.0;
			attribute supportedLanguages : LanguageCode[3] = (LanguageCode::en, LanguageCode::es, LanguageCode::fr);
		}
		part complianceMonitor : ComplianceMonitoringSystem {
			attribute systemId : BoardIdentifier = "CMS-MON-001";
			attribute defaultAuditFrequency : AuditFrequencyKind = AuditFrequencyKind::quarterly;
		}
		part dataPrivacy : DataPrivacyModule {
			attribute moduleId : BoardIdentifier = "DPM-001";
		}
		part advocacyOffice : ParticipantAdvocacyOffice {
			attribute officeId : BoardIdentifier = "PAO-001";
			attribute advocateCount : Natural = 4;
			attribute hotlineAvailable : Boolean = true;
		}

		connection irbToConsentMgmt connect irb.consentRequester to consentMgmt.consentReceiver;
		connection irbToCompliance connect irb.complianceReceiver to complianceMonitor.complianceNotifier;

		requirement ethicalReviewReq : EthicalReviewRequirement;
		requirement consentQualityReq : ConsentQualityRequirement;
		requirement dataPrivacyReq : DataPrivacyRequirement;
		requirement monitoringReq : MonitoringRequirement;
		requirement advocacyReq : AdvocacyRequirement;

		satisfy ethicalReviewReq by irb;
		satisfy consentQualityReq by consentMgmt;
		satisfy dataPrivacyReq by dataPrivacy;
		satisfy monitoringReq by complianceMonitor;
		satisfy advocacyReq by advocacyOffice;

		assert satisfy ethicalReviewReq by irb;
		assert satisfy consentQualityReq by consentMgmt;
		assert satisfy dataPrivacyReq by dataPrivacy;
		assert satisfy monitoringReq by complianceMonitor;
		assert satisfy advocacyReq by advocacyOffice;
	}
}
