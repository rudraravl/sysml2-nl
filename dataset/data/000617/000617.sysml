package 'Global Harmonization Task Force System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import Time::*;
	
	comment SystemOverview
	/* The Global Harmonization Task Force (GHTF) system facilitates international
	 * convergence of medical device regulatory practices. It coordinates regulatory
	 * authorities, develops harmonized guidance documents, and promotes adoption
	 * of consistent standards across regions to ensure patient safety while
	 * enabling efficient market access for medical devices globally.
	 */
	
	attribute def DocumentIdentifier {
		attribute id : String;
		attribute version : String;
		attribute issueDate : TimeInstantValue;
	}
	
	attribute def RegulatoryGuidance {
		attribute identifier : DocumentIdentifier;
		attribute title : String;
		attribute scope : String;
		attribute consensusLevel : Real;
	}
	
	attribute def RegionalInput {
		attribute sourceRegion : RegionCode;
		attribute submissionDate : TimeInstantValue;
		attribute content : String;
	}
	
	attribute def ConsensusScore :> Real;
	
	enum def RegionCode {
		northAmerica;
		europe;
		asiaPacific;
		latinAmerica;
		africa;
	}
	
	enum def DocumentState {
		draft;
		underReview;
		consensusBuilding;
		approved;
		published;
		archived;
	}
	
	enum def DeviceRiskClass {
		classI;
		classIIa;
		classIIb;
		classIII;
	}
	
	item def GuidanceDocument {
		attribute guidance : RegulatoryGuidance;
		attribute currentState : DocumentState;
		attribute approvalCount : Integer;
	}
	
	item def MedicalDeviceStandard {
		attribute riskClass : DeviceRiskClass;
		attribute standardReference : String;
	}
	
	port def RegionalSubmissionPort {
		in item regionalInput : RegionalInput;
	}
	
	port def GuidancePublicationPort {
		out item publishedGuidance : GuidanceDocument;
	}
	
	port def ConsensusCoordinationPort {
		inout item workingDocument : GuidanceDocument;
		out consensusMetric : ConsensusScore;
	}
	
	part def RegulatoryAuthority {
		attribute region : RegionCode;
		attribute memberSince : TimeInstantValue;
		attribute activeParticipation : Boolean;
		port submission : RegionalSubmissionPort;
		port reception : GuidancePublicationPort;
	}
	
	part def StudyGroup {
		attribute studyGroupId : String;
		attribute focusArea : String;
		attribute chairRegion : RegionCode;
		port coordination : ConsensusCoordinationPort;
	}
	
	part def Secretariat {
		attribute location : String;
		attribute staffCount : Integer;
		port documentManagement : GuidancePublicationPort;
		port consensusTracking : ConsensusCoordinationPort;
	}
	
	part def StakeholderLiaison {
		attribute organizationType : String;
		port feedback : RegionalSubmissionPort;
	}
	
	part def GHTFSystem {
		attribute systemName : String;
		attribute establishedYear : Integer;
		attribute activeRegions : Integer;
		attribute minimumConsensusThreshold : ConsensusScore;
		
		part regulatoryAuthorities : RegulatoryAuthority[4..10];
		part studyGroups : StudyGroup[1..5];
		part secretariat : Secretariat;
		part stakeholders : StakeholderLiaison[0..*];
	}
	
	requirement def HarmonizationObjective {
		doc /* The GHTF system shall achieve convergence of medical device
		 * regulatory requirements across participating regions to facilitate
		 * global market access while maintaining patient safety standards. */
		subject system : GHTFSystem;
		require constraint {
			system.minimumConsensusThreshold >= 0.75
		}
	}
	
	requirement def TimelinessRequirement {
		doc /* Guidance documents shall progress from draft to publication
		 * within 24 months to ensure timely regulatory harmonization. */
	}
	
	requirement def RegionalRepresentationRequirement {
		doc /* The system shall include active participation from at least
		 * four distinct geographic regions to ensure global perspective. */
		subject system : GHTFSystem;
		require constraint {
			system.activeRegions >= 4
		}
	}
	
	requirement def ConsensusRequirement {
		doc /* Published guidance shall achieve minimum 75% consensus among
		 * participating regulatory authorities. */
	}
	
	action def CollectRegionalInputs {
		in submissions : RegionalInput[1..*];
		out consolidatedInputs : RegionalInput[1..*];
	}
	
	action def DevelopDraftGuidance {
		in consolidatedInputs : RegionalInput[1..*];
		in existingStandards : MedicalDeviceStandard[0..*];
		out draftDocument : GuidanceDocument;
	}
	
	action def CirculateForReview {
		in draftDocument : GuidanceDocument;
		out reviewDocument : GuidanceDocument;
	}
	
	action def EvaluateConsensus {
		in reviewDocument : GuidanceDocument;
		in approvalResponses : Boolean[1..*];
		out consensusAchieved : Boolean;
		out consensusScore : ConsensusScore;
	}
	
	action def ReviseDocument {
		inout document : GuidanceDocument;
		in feedback : RegionalInput[1..*];
	}
	
	action def PublishGuidance {
		in approvedDocument : GuidanceDocument;
		out publishedGuidance : GuidanceDocument;
	}
	
	action def MonitorAdoption {
		in publishedGuidance : GuidanceDocument;
		out adoptionMetrics : RegionalInput[0..*];
	}
	
	action def HarmonizationWorkflow {
		first start;
		then merge continueDevelopment;
		
		then action collectInputs : CollectRegionalInputs {
			in submissions : RegionalInput[1..*];
			out consolidatedInputs : RegionalInput[1..*];
		}
		
		then action developDraft : DevelopDraftGuidance {
			in consolidatedInputs = collectInputs.consolidatedInputs;
			in existingStandards : MedicalDeviceStandard[0..*];
			out draftDocument : GuidanceDocument;
		}
		
		then action circulate : CirculateForReview {
			in draftDocument = developDraft.draftDocument;
			out reviewDocument : GuidanceDocument;
		}
		
		then action evaluateConsensus : EvaluateConsensus {
			in reviewDocument = circulate.reviewDocument;
			in approvalResponses : Boolean[1..*];
			out consensusAchieved : Boolean;
			out consensusScore : ConsensusScore;
		}
		
		then decide;
			if evaluateConsensus.consensusAchieved then publish;
			if !evaluateConsensus.consensusAchieved then revise;
		
		action publish : PublishGuidance {
			in approvedDocument = evaluateConsensus.reviewDocument;
			out publishedGuidance : GuidanceDocument;
		}
		
		then action monitor : MonitorAdoption {
			in publishedGuidance = publish.publishedGuidance;
			out adoptionMetrics : RegionalInput[0..*];
		}
		
		then done;
		
		action revise : ReviseDocument {
			inout document = evaluateConsensus.reviewDocument;
			in feedback : RegionalInput[1..*];
		}
		
		then continueDevelopment;
	}
	
	state def GuidanceLifecycle {
		entry; then initial;
		
		initial state initial;
		
		transition initial_to_drafting
			first initial
			accept inputsReceived : RegionalInput
			then drafting;
		
		state drafting {
			entry; then developing;
			state developing;
			
			transition developing_to_readyForReview
				first developing
				then readyForReview;
			
			state readyForReview;
		}
		
		transition drafting_to_reviewing
			first drafting
			then reviewing;
		
		state reviewing {
			entry; then collectingFeedback;
			state collectingFeedback;
			
			transition collectingFeedback_to_evaluating
				first collectingFeedback
				then evaluating;
			
			state evaluating;
		}
		
		transition reviewing_to_approved
			first reviewing
			then approved;
		
		transition reviewing_to_revision
			first reviewing
			then revision;
		
		state revision;
		
		transition revision_to_drafting
			first revision
			then drafting;
		
		state approved {
			entry; then publishing;
			state publishing;
			
			transition publishing_to_active
				first publishing
				then active;
			
			state active;
		}
		
		transition approved_to_monitoring
			first approved
			then monitoring;
		
		state monitoring;
		
		transition monitoring_to_archived
			first monitoring
			accept superseded : GuidanceDocument
			then archived;
		
		state archived;
	}
	
	part ghtfSystem : GHTFSystem {
		attribute :>> systemName = "Global Harmonization Task Force";
		attribute :>> establishedYear = 1992;
		attribute :>> activeRegions;
		attribute :>> minimumConsensusThreshold = 0.75;
		
		part :>> regulatoryAuthorities : RegulatoryAuthority[4..10] {
			attribute :>> region;
			attribute :>> memberSince;
			attribute :>> activeParticipation = true;
		}
		
		part :>> studyGroups : StudyGroup[1..5] {
			attribute :>> studyGroupId;
			attribute :>> focusArea;
		}
		
		part :>> secretariat : Secretariat {
			attribute :>> location = "Brussels";
			attribute :>> staffCount = 12;
		}
		
		part :>> stakeholders : StakeholderLiaison[0..*] {
			attribute :>> organizationType;
		}
		
		connection regionalToStudyGroup : RegionalInputConnection
			connect regulatoryAuthorities.submission to studyGroups.coordination;
		
		connection studyGroupToSecretariat : CoordinationConnection
			connect studyGroups.coordination to secretariat.consensusTracking;
		
		connection secretariatToAuthorities : PublicationConnection
			connect secretariat.documentManagement to regulatoryAuthorities.reception;
		
		connection stakeholderInput : StakeholderInputConnection
			connect stakeholders.feedback to studyGroups.coordination;
		
		perform action harmonizationWorkflow : HarmonizationWorkflow;
		
		exhibit state guidanceLifecycle : GuidanceLifecycle;
		
		assert harmonizationObjective : HarmonizationObjective {
			subject system = ghtfSystem;
		}
		
		assert timelinessReq : TimelinessRequirement;
		
		assert regionalRepresentation : RegionalRepresentationRequirement {
			subject system = ghtfSystem;
		}
		
		assert consensusReq : ConsensusRequirement;
		
		assert constraint minimumRegionalParticipation {
			activeRegions >= 4
		}
		
		assert constraint consensusThresholdMet {
			minimumConsensusThreshold >= 0.75
		}
		
		assert constraint adequateStudyGroups {
			studyGroups#(1) >= 1
		}
	}
	
	connection def RegionalInputConnection {
		end source : RegionalSubmissionPort;
		end target : ConsensusCoordinationPort;
	}
	
	connection def CoordinationConnection {
		end source : ConsensusCoordinationPort;
		end target : ConsensusCoordinationPort;
	}
	
	connection def PublicationConnection {
		end source : GuidancePublicationPort;
		end target : GuidancePublicationPort;
	}
	
	connection def StakeholderInputConnection {
		end source : RegionalSubmissionPort;
		end target : ConsensusCoordinationPort;
	}
}
