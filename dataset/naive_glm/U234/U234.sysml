package GHTF {
    import ScalarValues::*;
    import SI::*;

    // ---- Value Types ----
    value type Percentage :> Real {
        private unit unit = 1 [%];
    }

    value type ConsensusThreshold :> Percentage {
        default value = 75 [%];
    }

    value type DocumentVersion :> String;

    value type DocumentId :> String;

    // ---- Enumerations ----
    enum def Region { NorthAmerica; Europe; Asia; Other; }

    enum def DocumentStatus {
        Proposed;
        Drafted;
        UnderReview;
        Revised;
        Published;
        Adopted;
    }

    enum def VoteDecision { Approve; Reject; Abstain; }

    enum def FeedbackType { Comment; Objection; Endorsement; Suggestion; }

    enum def StakeholderCategory { Industry; Patient; Academic; Clinical; }

    // ---- Item Definitions ----
    item def Proposal {
        attribute proposalId : DocumentId;
        attribute title : String;
        attribute description : String;
        attribute sourceRegion : Region;
        attribute submittedBy : String;
    }

    item def Feedback {
        attribute feedbackId : DocumentId;
        attribute type : FeedbackType;
        attribute comment : String;
        attribute author : String;
        attribute targetDocumentId : DocumentId;
    }

    item def Vote {
        attribute voteId : DocumentId;
        attribute decision : VoteDecision;
        attribute authorityId : String;
        attribute documentId : DocumentId;
    }

    item def RegulatoryGuidanceDocument {
        attribute documentId : DocumentId;
        attribute title : String;
        attribute version : DocumentVersion;
        attribute status : DocumentStatus;
        attribute consensusLevel : Percentage;
        attribute content : String;
        attribute focusArea : String;
    }

    // ---- Part Definitions ----
    part def RegulatoryAuthority {
        attribute name : String;
        attribute region : Region;
        attribute isMember : Boolean = true;

        port out proposalPort : Proposal;
        port in documentPort : RegulatoryGuidanceDocument;
        port out votePort : Vote;
        port out feedbackPort : Feedback;
        port in publishedDocPort : RegulatoryGuidanceDocument;

        action submitProposal {
            out p : Proposal;
        }

        action castVote {
            in doc : RegulatoryGuidanceDocument;
            out v : Vote;
        }

        action provideFeedback {
            in doc : RegulatoryGuidanceDocument;
            out f : Feedback;
        }

        action adoptDocument {
            in doc : RegulatoryGuidanceDocument;
        }
    }

    part def StudyGroup {
        attribute groupId : String;
        attribute focusArea : String;

        port in proposalPort : Proposal;
        port in feedbackPort : Feedback;
        port in existingStandardPort : RegulatoryGuidanceDocument;
        port out draftPort : RegulatoryGuidanceDocument;
        port out revisedPort : RegulatoryGuidanceDocument;

        action developDraft {
            in proposals : Proposal[*];
            in feedback : Feedback[*];
            in existingStandards : RegulatoryGuidanceDocument[*];
            out draft : RegulatoryGuidanceDocument;
        }

        action reviseDraft {
            in draft : RegulatoryGuidanceDocument;
            in feedback : Feedback[*];
            out revised : RegulatoryGuidanceDocument;
        }
    }

    part def Secretariat {
        attribute location : String = "Brussels";
        attribute documentCount : Integer = 0;

        port in draftPort : RegulatoryGuidanceDocument;
        port in votePort : Vote;
        port in revisedPort : RegulatoryGuidanceDocument;
        port out documentOutPort : RegulatoryGuidanceDocument;
        port out distributionPort : RegulatoryGuidanceDocument;

        action distributeDocument {
            in doc : RegulatoryGuidanceDocument;
            out distributed : RegulatoryGuidanceDocument;
        }

        action evaluateConsensus {
            in votes : Vote[*];
            out consensusLevel : Percentage;
        }

        action publishDocument {
            in doc : RegulatoryGuidanceDocument;
            out published : RegulatoryGuidanceDocument;
        }

        action trackProgress {
            in doc : RegulatoryGuidanceDocument;
        }

        action distributeForAdoption {
            in doc : RegulatoryGuidanceDocument;
            out distributed : RegulatoryGuidanceDocument;
        }
    }

    part def Stakeholder {
        attribute name : String;
        attribute category : StakeholderCategory;

        port in documentPort : RegulatoryGuidanceDocument;
        port out feedbackPort : Feedback;

        action provideInput {
            in doc : RegulatoryGuidanceDocument;
            out f : Feedback;
        }
    }

    // ---- Requirements ----
    requirement def HarmonizationGoal {
        doc /* The system shall create consistent, harmonized standards that ensure patient safety while facilitating global medical device approval. */
    }

    requirement def ConsensusRequirement {
        doc /* A guidance document cannot be published until it achieves at least 75% consensus among participating regulatory authorities. */
        attribute threshold : ConsensusThreshold = 75 [%];
        constraint { consensusLevel >= threshold }
    }

    requirement def DocumentLifecycleRequirement {
        doc /* Each regulatory guidance document shall follow a structured lifecycle: proposal, draft, review, revision, and publication. */
    }

    requirement def StakeholderInclusionRequirement {
        doc /* Stakeholders shall be able to provide feedback and input into the harmonization process. */
    }

    requirement def RegionalRepresentationRequirement {
        doc /* Regulatory authorities from North America, Europe, and Asia shall participate in the harmonization process. */
    }

    // ---- Connection Definitions ----
    connection def ProposalFlow {
        end sourceProposal : Proposal;
        end targetProposal : Proposal;
    }

    connection def DocumentFlow {
        end sourceDocument : RegulatoryGuidanceDocument;
        end targetDocument : RegulatoryGuidanceDocument;
    }

    connection def VoteFlow {
        end sourceVote : Vote;
        end targetVote : Vote;
    }

    connection def FeedbackFlow {
        end sourceFeedback : Feedback;
        end targetFeedback : Feedback;
    }

    // ---- State Machine: Document Lifecycle ----
    state def DocumentLifecycle {
        attribute consensusLevel : Percentage;

        entry; then Proposed;

        state Proposed {
            entry action collectProposalsAndFeedback();
            do action gatherInput();
            exit action logProposalPhase();
        }

        state Drafted {
            entry action developDraftDocument();
            do action studyGroupDrafting();
            exit action registerDraft();
        }

        state UnderReview {
            entry action circulateForReview();
            do action collectVotesAndFeedback();
            exit action evaluateConsensusLevel();
        }

        state Revised {
            entry action reviseDocument();
            do action incorporateFeedback();
            exit action registerRevision();
        }

        state Published {
            entry action publishFinalDocument();
            do action formalPublication();
            exit action notifyAuthorities();
        }

        state Adopted {
            entry action distributeForAdoption();
            do action supportLocalAdoption();
        }

        transition from Proposed to Drafted;
        transition from Drafted to UnderReview;
        transition from UnderReview to Revised if consensusLevel < 75 [%];
        transition from UnderReview to Published if consensusLevel >= 75 [%];
        transition from Revised to UnderReview;
        transition from Published to Adopted;
    }

    // ---- Actions ----
    action def CollectProposalsAndFeedback {
        in proposals : Proposal[*];
        in feedback : Feedback[*];
        out collectedProposals : Proposal[*];
        out collectedFeedback : Feedback[*];
    }

    action def DevelopDraftDocument {
        in proposals : Proposal[*];
        in feedback : Feedback[*];
        in existingStandards : RegulatoryGuidanceDocument[*];
        out draft : RegulatoryGuidanceDocument;
    }

    action def CirculateForReview {
        in doc : RegulatoryGuidanceDocument;
        out distributedDoc : RegulatoryGuidanceDocument;
    }

    action def EvaluateConsensusLevel {
        in votes : Vote[*];
        out consensusLevel : Percentage;
    }

    action def ReviseDocument {
        in draft : RegulatoryGuidanceDocument;
        in feedback : Feedback[*];
        out revised : RegulatoryGuidanceDocument;
    }

    action def PublishFinalDocument {
        in doc : RegulatoryGuidanceDocument;
        out published : RegulatoryGuidanceDocument;
    }

    action def DistributeForAdoption {
        in doc : RegulatoryGuidanceDocument;
        out distributed : RegulatoryGuidanceDocument;
    }

    // ---- System ----
    part ghtfSystem :> GHTFSystem;

    part def GHTFSystem {
        attribute systemName : String = "Global Harmonization Task Force";
        attribute mission : String = "Align medical device regulatory practices across countries and regions.";

        // Regulatory Authorities
        part fda : RegulatoryAuthority {
            attribute name = "FDA";
            attribute region = Region::NorthAmerica;
        }
        part ema : RegulatoryAuthority {
            attribute name = "EMA";
            attribute region = Region::Europe;
        }
        part pmda : RegulatoryAuthority {
            attribute name = "PMDA";
            attribute region = Region::Asia;
        }
        part healthCanada : RegulatoryAuthority {
            attribute name = "Health Canada";
            attribute region = Region::NorthAmerica;
        }
        part mhlw : RegulatoryAuthority {
            attribute name = "MHLW";
            attribute region = Region::Asia;
        }

        // Study Groups
        part sg1 : StudyGroup {
            attribute groupId = "SG1";
            attribute focusArea = "Pre-market Review";
        }
        part sg2 : StudyGroup {
            attribute groupId = "SG2";
            attribute focusArea = "Post-market Surveillance";
        }
        part sg3 : StudyGroup {
            attribute groupId = "SG3";
            attribute focusArea = "Quality Systems";
        }
        part sg4 : StudyGroup {
            attribute groupId = "SG4";
            attribute focusArea = "Clinical Evaluation";
        }

        // Secretariat
        part secretariat : Secretariat {
            attribute location = "Brussels";
        }

        // Stakeholders
        part industryAssoc : Stakeholder {
            attribute name = "Global Industry Association";
            attribute category = StakeholderCategory::Industry;
        }
        part patientAdvocacy : Stakeholder {
            attribute name = "Patient Advocacy Coalition";
            attribute category = StakeholderCategory::Patient;
        }
        part clinicalSociety : Stakeholder {
            attribute name = "International Clinical Society";
            attribute category = StakeholderCategory::Clinical;
        }
        part academicConsortium : Stakeholder {
            attribute name = "Academic Research Consortium";
            attribute category = StakeholderCategory::Academic;
        }

        // Connections: Proposals from authorities to study groups
        connection : ProposalFlow from fda.proposalPort to sg1.proposalPort;
        connection : ProposalFlow from ema.proposalPort to sg1.proposalPort;
        connection : ProposalFlow from pmda.proposalPort to sg2.proposalPort;
        connection : ProposalFlow from healthCanada.proposalPort to sg3.proposalPort;
        connection : ProposalFlow from mhlw.proposalPort to sg4.proposalPort;

        // Connections: Drafts from study groups to secretariat
        connection : DocumentFlow from sg1.draftPort to secretariat.draftPort;
        connection : DocumentFlow from sg2.draftPort to secretariat.draftPort;
        connection : DocumentFlow from sg3.draftPort to secretariat.draftPort;
        connection : DocumentFlow from sg4.draftPort to secretariat.draftPort;

        // Connections: Revised documents from study groups to secretariat
        connection : DocumentFlow from sg1.revisedPort to secretariat.revisedPort;
        connection : DocumentFlow from sg2.revisedPort to secretariat.revisedPort;
        connection : DocumentFlow from sg3.revisedPort to secretariat.revisedPort;
        connection : DocumentFlow from sg4.revisedPort to secretariat.revisedPort;

        // Connections: Secretariat distributes documents to authorities for review
        connection : DocumentFlow from secretariat.documentOutPort to fda.documentPort;
        connection : DocumentFlow from secretariat.documentOutPort to ema.documentPort;
        connection : DocumentFlow from secretariat.documentOutPort to pmda.documentPort;
        connection : DocumentFlow from secretariat.documentOutPort to healthCanada.documentPort;
        connection : DocumentFlow from secretariat.documentOutPort to mhlw.documentPort;

        // Connections: Secretariat distributes documents to stakeholders for review
        connection : DocumentFlow from secretariat.documentOutPort to industryAssoc.documentPort;
        connection : DocumentFlow from secretariat.documentOutPort to patientAdvocacy.documentPort;
        connection : DocumentFlow from secretariat.documentOutPort to clinicalSociety.documentPort;
        connection : DocumentFlow from secretariat.documentOutPort to academicConsortium.documentPort;

        // Connections: Votes from authorities to secretariat
        connection : VoteFlow from fda.votePort to secretariat.votePort;
        connection : VoteFlow from ema.votePort to secretariat.votePort;
        connection : VoteFlow from pmda.votePort to secretariat.votePort;
        connection : VoteFlow from healthCanada.votePort to secretariat.votePort;
        connection : VoteFlow from mhlw.votePort to secretariat.votePort;

        // Connections: Feedback from stakeholders to study groups
        connection : FeedbackFlow from industryAssoc.feedbackPort to sg1.feedbackPort;
        connection : FeedbackFlow from patientAdvocacy.feedbackPort to sg2.feedbackPort;
        connection : FeedbackFlow from clinicalSociety.feedbackPort to sg4.feedbackPort;
        connection : FeedbackFlow from academicConsortium.feedbackPort to sg3.feedbackPort;

        // Connections: Feedback from authorities to study groups
        connection : FeedbackFlow from fda.feedbackPort to sg1.feedbackPort;
        connection : FeedbackFlow from ema.feedbackPort to sg4.feedbackPort;
        connection : FeedbackFlow from pmda.feedbackPort to sg2.feedbackPort;

        // Connections: Published documents distributed for adoption
        connection : DocumentFlow from secretariat.distributionPort to fda.publishedDocPort;
        connection : DocumentFlow from secretariat.distributionPort to ema.publishedDocPort;
        connection : DocumentFlow from secretariat.distributionPort to pmda.publishedDocPort;
        connection : DocumentFlow from secretariat.distributionPort to healthCanada.publishedDocPort;
        connection : DocumentFlow from secretariat.distributionPort to mhlw.publishedDocPort;

        // Requirement satisfaction
        satisfy HarmonizationGoal by ghtfSystem;
        satisfy ConsensusRequirement by secretariat.evaluateConsensus;
        satisfy DocumentLifecycleRequirement by secretariat;
        satisfy StakeholderInclusionRequirement by industryAssoc, patientAdvocacy, clinicalSociety, academicConsortium;
        satisfy RegionalRepresentationRequirement by fda, ema, pmda, healthCanada, mhlw;

        // Document lifecycle state machine instance
        part currentDocument : RegulatoryGuidanceDocument {
            attribute documentId = "GHTF-DOC-001";
            attribute title = "Harmonized Medical Device Classification Rules";
            attribute version = "1.0";
            attribute status = DocumentStatus::Proposed;
            attribute consensusLevel : Percentage = 0 [%];
            attribute focusArea = "Pre-market Review";
        }

        exhibit DocumentLifecycle on currentDocument;
    }
}
