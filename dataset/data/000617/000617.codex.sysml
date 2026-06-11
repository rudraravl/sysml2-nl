package GlobalHarmonizationTaskForceSystem {

  import ScalarValues::*;
  import ISQ::*;

  attribute def Percent :> Real;
  attribute def CalendarDay :> Real;
  attribute def DocumentCount :> Integer;
  attribute def VoteCount :> Integer;

  item def RegulatoryProposal {
    attribute proposalId : String;
    attribute title : String;
    attribute submittingRegion : String;
    attribute deviceRiskClass : String;
    attribute intendedUseSummary : String;
  }

  item def HarmonizationGuidance {
    attribute guidanceId : String;
    attribute title : String;
    attribute scope : String;
    attribute revision : String;
    attribute approvalDate : String;
    attribute status : GuidanceStatus;
  }

  item def RegionalRegulatoryInput {
    attribute regionName : String;
    attribute legalBasis : String;
    attribute technicalStandardReferences : String;
    attribute divergenceSummary : String;
  }

  item def StakeholderComment {
    attribute commentId : String;
    attribute stakeholderType : StakeholderType;
    attribute commentText : String;
    attribute disposition : CommentDisposition;
  }

  item def ConsensusDecision {
    attribute decisionId : String;
    attribute approvalRatio : Percent;
    attribute affirmativeVotes : VoteCount;
    attribute negativeVotes : VoteCount;
    attribute decisionDate : String;
    attribute accepted : Boolean;
  }

  item def ImplementationReport {
    attribute regionName : String;
    attribute implementedGuidanceId : String;
    attribute implementationProgress : Percent;
    attribute barriers : String;
    attribute reportDate : String;
  }

  enum def GuidanceStatus {
    enum draft;
    enum consultation;
    enum consensusReview;
    enum approved;
    enum published;
    enum retired;
  }

  enum def StakeholderType {
    enum regulator;
    enum industry;
    enum clinicalProfessional;
    enum patientRepresentative;
    enum standardsBody;
    enum publicHealthAgency;
  }

  enum def CommentDisposition {
    enum accepted;
    enum partiallyAccepted;
    enum rejected;
    enum deferred;
  }

  port def ProposalIntakePort {
    in item proposal : RegulatoryProposal;
  }

  port def RegionalInputPort {
    in item input : RegionalRegulatoryInput;
  }

  port def CommentPort {
    in item comment : StakeholderComment;
    out item response : StakeholderComment;
  }

  port def GuidancePublicationPort {
    out item guidance : HarmonizationGuidance;
  }

  port def DecisionPort {
    out item decision : ConsensusDecision;
  }

  port def ImplementationMonitoringPort {
    in item report : ImplementationReport;
    out item guidance : HarmonizationGuidance;
  }

  part def GHTFHarmonizationSystem {
    attribute missionStatement : String = "Coordinate international medical device regulators and stakeholders to produce globally harmonized regulatory guidance that supports patient safety, innovation, and efficient market access.";
    attribute minimumConsensusThreshold : Percent = 80.0;
    attribute targetConsultationPeriod : CalendarDay = 90.0;
    attribute maximumDraftRevisionCycles : Integer = 4;

    port proposalIntake : ProposalIntakePort;
    port regionalInput : RegionalInputPort;
    port consultation : CommentPort;
    port publication : GuidancePublicationPort;
    port decisionOutput : DecisionPort;
    port implementationMonitoring : ImplementationMonitoringPort;

    part steeringCommittee : SteeringCommittee;
    part secretariat : Secretariat;
    part regionalRegulatorForum : RegionalRegulatorForum;
    part technicalWorkingGroup : TechnicalWorkingGroup;
    part stakeholderConsultationBoard : StakeholderConsultationBoard;
    part consensusBoard : ConsensusBoard;
    part guidanceRepository : GuidanceRepository;
    part implementationTracker : ImplementationTracker;

    connect proposalIntake to secretariat.proposalReceiver;
    connect secretariat.acceptedProposalOutput to steeringCommittee.proposalReviewInput;
    connect steeringCommittee.workItemOutput to technicalWorkingGroup.workItemInput;
    connect regionalInput to regionalRegulatorForum.regionalInputReceiver;
    connect regionalRegulatorForum.comparativeAnalysisOutput to technicalWorkingGroup.regulatoryComparisonInput;
    connect technicalWorkingGroup.draftGuidanceOutput to stakeholderConsultationBoard.draftInput;
    connect consultation to stakeholderConsultationBoard.publicCommentInterface;
    connect stakeholderConsultationBoard.commentDispositionOutput to technicalWorkingGroup.commentResolutionInput;
    connect technicalWorkingGroup.consensusDraftOutput to consensusBoard.consensusDraftInput;
    connect consensusBoard.decisionOutput to decisionOutput;
    connect consensusBoard.approvedGuidanceOutput to guidanceRepository.guidanceInput;
    connect guidanceRepository.publicationOutput to publication;
    connect guidanceRepository.publicationOutput to implementationMonitoring.guidance;
    connect implementationMonitoring to implementationTracker.implementationReportInput;
  }

  part def Secretariat {
    attribute intakeCompletenessTarget : Percent = 95.0;
    port proposalReceiver : ProposalIntakePort;
    port acceptedProposalOutput {
      out item proposal : RegulatoryProposal;
    }

    action screenProposal {
      in item submittedProposal : RegulatoryProposal;
      out item acceptedProposal : RegulatoryProposal;
      first start;
      then verifyScope;
      then verifyCompleteness;
      then registerWorkItem;
      then done;

      action verifyScope;
      action verifyCompleteness;
      action registerWorkItem;
    }
  }

  part def SteeringCommittee {
    attribute memberRegions : Integer = 5;
    attribute strategicPriorityScoreThreshold : Real = 7.5;

    port proposalReviewInput {
      in item proposal : RegulatoryProposal;
    }

    port workItemOutput {
      out item proposal : RegulatoryProposal;
    }

    action prioritizeWorkItem {
      in item candidate : RegulatoryProposal;
      out item selected : RegulatoryProposal;
      first assessPublicHealthValue;
      then assessInternationalDivergence;
      then assessFeasibility;
      then authorizeWorkingGroup;
      then done;

      action assessPublicHealthValue;
      action assessInternationalDivergence;
      action assessFeasibility;
      action authorizeWorkingGroup;
    }
  }

  part def RegionalRegulatorForum {
    attribute representedRegions : Integer = 5;
    port regionalInputReceiver : RegionalInputPort;
    port comparativeAnalysisOutput {
      out item input : RegionalRegulatoryInput;
    }

    action compareRegionalRequirements {
      in item regionalInputs : RegionalRegulatoryInput;
      out item harmonizationGapAnalysis : RegionalRegulatoryInput;
      first collectRequirements;
      then identifyCommonPrinciples;
      then documentDivergences;
      then publishGapAnalysis;
      then done;

      action collectRequirements;
      action identifyCommonPrinciples;
      action documentDivergences;
      action publishGapAnalysis;
    }
  }

  part def TechnicalWorkingGroup {
    attribute clinicalExperts : Integer = 6;
    attribute regulatoryExperts : Integer = 10;
    attribute standardsExperts : Integer = 4;
    attribute targetDraftQualityScore : Percent = 90.0;

    port workItemInput {
      in item proposal : RegulatoryProposal;
    }

    port regulatoryComparisonInput {
      in item input : RegionalRegulatoryInput;
    }

    port draftGuidanceOutput {
      out item guidance : HarmonizationGuidance;
    }

    port commentResolutionInput {
      in item comment : StakeholderComment;
    }

    port consensusDraftOutput {
      out item guidance : HarmonizationGuidance;
    }

    action developGuidance {
      in item workItem : RegulatoryProposal;
      in item gapAnalysis : RegionalRegulatoryInput;
      in item resolvedComment : StakeholderComment;
      out item consensusReadyGuidance : HarmonizationGuidance;

      first defineScope;
      then mapRiskPrinciples;
      then writeDraftGuidance;
      then integrateStakeholderComments;
      then verifyTraceabilityToSafetyObjectives;
      then releaseConsensusDraft;
      then done;

      action defineScope;
      action mapRiskPrinciples;
      action writeDraftGuidance;
      action integrateStakeholderComments;
      action verifyTraceabilityToSafetyObjectives;
      action releaseConsensusDraft;
    }
  }

  part def StakeholderConsultationBoard {
    attribute consultationPeriod : CalendarDay = 90.0;
    attribute minimumCommentResponseRate : Percent = 100.0;

    port draftInput {
      in item guidance : HarmonizationGuidance;
    }

    port publicCommentInterface : CommentPort;

    port commentDispositionOutput {
      out item comment : StakeholderComment;
    }

    action conductConsultation {
      in item draftGuidance : HarmonizationGuidance;
      in item publicComment : StakeholderComment;
      out item disposedComment : StakeholderComment;

      first publishDraftForConsultation;
      then collectComments;
      then categorizeComments;
      then assignDisposition;
      then issueResponseMatrix;
      then done;

      action publishDraftForConsultation;
      action collectComments;
      action categorizeComments;
      action assignDisposition;
      action issueResponseMatrix;
    }
  }

  part def ConsensusBoard {
    attribute consensusThreshold : Percent = 80.0;
    attribute quorumThreshold : Percent = 75.0;

    port consensusDraftInput {
      in item guidance : HarmonizationGuidance;
    }

    port decisionOutput : DecisionPort;

    port approvedGuidanceOutput {
      out item guidance : HarmonizationGuidance;
    }

    action decideConsensus {
      in item consensusDraft : HarmonizationGuidance;
      out item decision : ConsensusDecision;
      out item approvedGuidance : HarmonizationGuidance;

      first validateQuorum;
      then conductRegionalVote;
      then computeApprovalRatio;
      then recordDecision;
      then ifAcceptedPublishable;
      then done;

      action validateQuorum;
      action conductRegionalVote;
      action computeApprovalRatio;
      action recordDecision;
      action ifAcceptedPublishable;
    }
  }

  part def GuidanceRepository {
    attribute retainedGuidanceDocuments : DocumentCount;
    attribute archiveRetentionPeriod : CalendarDay = 3650.0;

    port guidanceInput {
      in item guidance : HarmonizationGuidance;
    }

    port publicationOutput : GuidancePublicationPort;

    action publishGuidance {
      in item approvedGuidance : HarmonizationGuidance;
      out item publishedGuidance : HarmonizationGuidance;

      first assignIdentifier;
      then applyVersionControl;
      then publishPublicRecord;
      then notifyRegions;
      then done;

      action assignIdentifier;
      action applyVersionControl;
      action publishPublicRecord;
      action notifyRegions;
    }
  }

  part def ImplementationTracker {
    attribute targetRegionalAdoption : Percent = 85.0;
    attribute reportingInterval : CalendarDay = 180.0;

    port implementationReportInput : ImplementationMonitoringPort;

    action monitorImplementation {
      in item report : ImplementationReport;
      out adoptionProgress : Percent;

      first collectRegionalReports;
      then assessAdoptionStatus;
      then identifyImplementationBarriers;
      then recommendMaintenanceAction;
      then done;

      action collectRegionalReports;
      action assessAdoptionStatus;
      action identifyImplementationBarriers;
      action recommendMaintenanceAction;
    }
  }

  state def HarmonizationLifecycle {
    entry action initializeWorkProgram;
    state proposed;
    state screened;
    state prioritized;
    state drafting;
    state publicConsultation;
    state commentResolution;
    state consensusVoting;
    state approved;
    state published;
    state implementationMonitoring;
    state revisionRequired;
    state retired;

    transition first proposed;
    transition proposed_to_screened
      first proposed
      then screened;

    transition screened_to_prioritized
      first screened
      then prioritized;

    transition prioritized_to_drafting
      first prioritized
      then drafting;

    transition drafting_to_publicConsultation
      first drafting
      then publicConsultation;

    transition publicConsultation_to_commentResolution
      first publicConsultation
      then commentResolution;

    transition commentResolution_to_consensusVoting
      first commentResolution
      then consensusVoting;

    transition consensusVoting_to_approved
      first consensusVoting
      then approved;

    transition approved_to_published
      first approved
      then published;

    transition published_to_implementationMonitoring
      first published
      then implementationMonitoring;

    transition implementationMonitoring_to_revisionRequired
      first implementationMonitoring
      then revisionRequired;

    transition revisionRequired_to_drafting
      first revisionRequired
      then drafting;

    transition implementationMonitoring_to_retired
      first implementationMonitoring
      then retired;
  }

  requirement def ReqPrimaryFunction {
    doc /* The system shall provide a high-level international harmonization function by transforming regional medical device regulatory differences into consensus guidance for regulators, manufacturers, and public health stakeholders. */
  }

  requirement def ReqStakeholderConsultation {
    attribute requiredConsultationPeriod : CalendarDay = 90.0;
    doc /* The system shall expose draft guidance to structured stakeholder consultation for at least the required consultation period. */
  }

  requirement def ReqConsensusThreshold {
    attribute requiredApprovalRatio : Percent = 80.0;
    doc /* The system shall approve harmonized guidance only when the approval ratio is greater than or equal to the required approval ratio. */
  }

  requirement def ReqTraceability {
    doc /* Each published guidance document shall be traceable to an approved work item, regional regulatory inputs, stakeholder comments, consensus decision, and implementation monitoring record. */
  }

  requirement def ReqImplementationMonitoring {
    attribute targetRegionalAdoption : Percent = 85.0;
    doc /* The system shall monitor regional implementation and identify barriers when adoption is below the target regional adoption level. */
  }

  requirement def ReqDocumentControl {
    attribute archiveRetentionPeriod : CalendarDay = 3650.0;
    doc /* The system shall maintain version-controlled guidance records and preserve retired guidance for the archive retention period. */
  }

  satisfy ReqPrimaryFunction by GHTFHarmonizationSystem;
  satisfy ReqStakeholderConsultation by StakeholderConsultationBoard;
  satisfy ReqConsensusThreshold by ConsensusBoard;
  satisfy ReqTraceability by GuidanceRepository;
  satisfy ReqImplementationMonitoring by ImplementationTracker;
  satisfy ReqDocumentControl by GuidanceRepository;

  part ghtfHarmonizationSystem : GHTFHarmonizationSystem;

}