package GHTF {
    private import ScalarValues::Real;
    private import ScalarValues::Boolean;
    private import ScalarValues::String;
    private import ScalarValues::Integer;
    private import SI::*;

    attribute def ConsensusThreshold :> Real {
        doc /* Minimum fraction of approving authorities required for publication. */
    }
    attribute def ConsensusLevel :> Real {
        doc /* Actual measured level of agreement among authorities. */
    }
    attribute def RegionName :> String;
    attribute def DocumentTitle :> String;
    attribute def DocumentVersion :> Integer;
    attribute def AuthorityName :> String;
    attribute def StakeholderCategory :> String;
    attribute def FocusArea :> String;

    item def RegulatoryGuidanceDocument {
        attribute title : DocumentTitle;
        attribute version : DocumentVersion;
        attribute isPublished : Boolean;
    }
    item def Proposal :> RegulatoryGuidanceDocument {
        doc /* Initial proposal submitted by an authority or stakeholder. */
    }
    item def DraftDocument :> RegulatoryGuidanceDocument {
        doc /* Working draft produced by a study group. */
    }
    item def ReviewedDocument :> RegulatoryGuidanceDocument {
        doc /* Document that has completed a review cycle. */
    }
    item def FinalDocument :> RegulatoryGuidanceDocument {
        doc /* Published final guidance ready for adoption. */
    }
    item def Feedback {
        attribute text : String;
        attribute submitter : String;
    }
    item def Vote {
        attribute approve : Boolean;
        attribute authorityId : String;
    }
    item def ExistingStandard {
        attribute standardId : String;
    }

    port def DocumentExchange {
        out document : RegulatoryGuidanceDocument;
        in feedback : Feedback;
    }
    port def VotingPort {
        out vote : Vote;
    }
    port def DistributionPort {
        out finalDoc : FinalDocument;
    }

    interface def DocumentFlow {
        end sender : DocumentExchange;
        end receiver : ~DocumentExchange;
    }
    interface def VotingChannel {
        end authority : VotingPort;
        end secretariat : ~VotingPort;
    }
    interface def DistributionChannel {
        end secretariat : DistributionPort;
        end authority : ~DistributionPort;
    }

    part def RegulatoryAuthority {
        attribute name : AuthorityName;
        attribute region : RegionName;
        attribute isMember : Boolean;
        port docPort : DocumentExchange;
        port votePort : VotingPort;
        port adoptPort : ~DistributionPort;

        state authorityState {
            entry; then idle;
            state idle;
            transition idle_to_reviewing
                first idle
                accept draft : DraftDocument via docPort
                then reviewing;
            state reviewing {
                do action provideFeedback {
                    in draft : DraftDocument;
                    out feedback : Feedback;
                }
            }
            transition reviewing_to_voting
                first reviewing
                accept reviewed : ReviewedDocument via docPort
                then voting;
            state voting {
                do action castVote {
                    in document : ReviewedDocument;
                    out vote : Vote;
                }
            }
            transition voting_to_adopting
                first voting
                accept final : FinalDocument via adoptPort
                then adopting;
            state adopting;
            transition adopting_to_idle
                first adopting
                accept after 720[h]
                then idle;
        }
    }

    part def StudyGroup {
        attribute focusArea : FocusArea;
        port docPort : DocumentExchange;

        action def DraftingProcess {
            in proposals : Proposal[*];
            in standards : ExistingStandard[*];
            in feedback : Feedback[*];
            out draft : DraftDocument;
        }

        state groupState {
            entry; then waiting;
            state waiting;
            transition waiting_to_drafting
                first waiting
                accept proposal : Proposal via docPort
                then drafting;
            state drafting {
                do action developDraft : DraftingProcess;
            }
            transition drafting_to_revising
                first drafting
                accept feedback : Feedback via docPort
                then revising;
            state revising {
                do action reviseDraft : DraftingProcess;
            }
            transition revising_to_waiting
                first revising
                accept final : FinalDocument via docPort
                then waiting;
        }
    }

    part def Secretariat {
        attribute location : String = "Brussels";
        attribute minConsensus : ConsensusThreshold = 0.75;
        port docPort : DocumentExchange;
        port votePort : ~VotingPort;
        port distPort : DistributionPort;

        action def EvaluateConsensus {
            in votes : Vote[*];
            in authorityCount : Integer;
            out consensus : ConsensusLevel;
            out sufficient : Boolean;
        }

        action def PublishDocument {
            in reviewed : ReviewedDocument;
            out finalDoc : FinalDocument;
        }

        state secretariatState {
            entry; then collecting;
            state collecting;
            transition collecting_to_distributing
                first collecting
                accept draft : DraftDocument via docPort
                then distributing;
            state distributing;
            transition distributing_to_evaluating
                first distributing
                accept vote : Vote via votePort
                then evaluating;
            state evaluating;
            transition evaluating_to_publishing
                first evaluating
                accept ConsensusReached
                then publishing;
            transition evaluating_to_requesting
                first evaluating
                accept ConsensusNotReached
                then requestingRevision;
            state requestingRevision;
            transition requestingRevision_to_distributing
                first requestingRevision
                accept draft : DraftDocument via docPort
                then distributing;
            state publishing;
            transition publishing_to_distributingFinal
                first publishing
                then distributingFinal;
            state distributingFinal;
            transition distributingFinal_to_collecting
                first distributingFinal
                accept after 336[h]
                then collecting;
        }
    }

    part def Stakeholder {
        attribute name : String;
        attribute category : StakeholderCategory;
        port docPort : DocumentExchange;

        state stakeholderState {
            entry; then inactive;
            state inactive;
            transition inactive_to_active
                first inactive
                accept draft : DraftDocument via docPort
                then active;
            state active {
                do action submitFeedback {
                    in draft : DraftDocument;
                    out feedback : Feedback;
                }
            }
            transition active_to_inactive
                first active
                accept after 240[h]
                then inactive;
        }
    }

    requirement def MinConsensusRequirement {
        doc /* A guidance document cannot be published until at least 75% of
             * participating regulatory authorities approve it. */
        subject secretariat : Secretariat;
        constraint {
            secretariat.minConsensus >= 0.75
        }
    }

    requirement def PatientSafetyRequirement {
        doc /* All harmonized standards must ensure patient safety. */
        subject document : RegulatoryGuidanceDocument;
    }

    requirement def GlobalAdoptionRequirement {
        doc /* Final published guidance must be distributed to all member
             * authorities for adoption into local regulations. */
        subject secretariat : Secretariat;
    }

    part ghtfSystem {
        part secretariat : Secretariat {
            satisfy MinConsensusRequirement;
            satisfy GlobalAdoptionRequirement;
        }
        part fda : RegulatoryAuthority {
            attribute name = "FDA";
            attribute region = "North America";
        }
        part ema : RegulatoryAuthority {
            attribute name = "EMA";
            attribute region = "Europe";
        }
        part pmda : RegulatoryAuthority {
            attribute name = "PMDA";
            attribute region = "Asia";
        }
        part studyGroup1 : StudyGroup {
            attribute focusArea = "Pre-market Evaluation";
        }
        part studyGroup2 : StudyGroup {
            attribute focusArea = "Post-market Surveillance";
        }
        part industryAssoc : Stakeholder {
            attribute name = "Medical Device Industry Association";
            attribute category = "Industry";
        }
        part patientAdvocacy : Stakeholder {
            attribute name = "Patient Advocacy Group";
            attribute category = "Patient";
        }

        interface docFlowFda : DocumentFlow {
            end sender :>> fda.docPort;
            end receiver :>> secretariat.docPort;
        }
        interface docFlowEma : DocumentFlow {
            end sender :>> ema.docPort;
            end receiver :>> secretariat.docPort;
        }
        interface docFlowPmda : DocumentFlow {
            end sender :>> pmda.docPort;
            end receiver :>> secretariat.docPort;
        }

        interface voteFda : VotingChannel {
            end authority :>> fda.votePort;
            end secretariat :>> secretariat.votePort;
        }
        interface voteEma : VotingChannel {
            end authority :>> ema.votePort;
            end secretariat :>> secretariat.votePort;
        }
        interface votePmda : VotingChannel {
            end authority :>> pmda.votePort;
            end secretariat :>> secretariat.votePort;
        }

        interface distFda : DistributionChannel {
            end secretariat :>> secretariat.distPort;
            end authority :>> fda.adoptPort;
        }
        interface distEma : DistributionChannel {
            end secretariat :>> secretariat.distPort;
            end authority :>> ema.adoptPort;
        }
        interface distPmda : DistributionChannel {
            end secretariat :>> secretariat.distPort;
            end authority :>> pmda.adoptPort;
        }

        interface docFlowSg1 : DocumentFlow {
            end sender :>> studyGroup1.docPort;
            end receiver :>> secretariat.docPort;
        }
        interface docFlowSg2 : DocumentFlow {
            end sender :>> studyGroup2.docPort;
            end receiver :>> secretariat.docPort;
        }

        interface docFlowIndustry : DocumentFlow {
            end sender :>> industryAssoc.docPort;
            end receiver :>> secretariat.docPort;
        }
        interface docFlowPatient : DocumentFlow {
            end sender :>> patientAdvocacy.docPort;
            end receiver :>> secretariat.docPort;
        }
    }

    action def HarmonizationWorkflow {
        in initialProposals : Proposal[*];
        in existingStandards : ExistingStandard[*];
        out finalGuidance : FinalDocument;

        action collectInputs {
            in proposals = initialProposals;
            in standards = existingStandards;
            out consolidatedProposals : Proposal[*];
        }
        then developDraft;
        action developDraft {
            in proposals = collectInputs.consolidatedProposals;
            in standards = existingStandards;
            out draft : DraftDocument;
        }
        then circulateForReview;
        action circulateForReview {
            in draft = developDraft.draft;
            out reviewedDoc : ReviewedDocument;
            out votes : Vote[*];
            out reviewFeedback : Feedback[*];
        }
        then checkConsensus;
        action checkConsensus {
            in votes = circulateForReview.votes;
            out consensusLevel : ConsensusLevel;
            out isSufficient : Boolean;
        }
        then revise;
        action revise {
            in feedback = circulateForReview.reviewFeedback;
            in draft = developDraft.draft;
            out revisedDraft : DraftDocument;
        }
        flow revise.revisedDraft to circulateForReview.draft;
        then publish;
        action publish {
            in reviewed = circulateForReview.reviewedDoc;
            out finalDoc : FinalDocument;
        }
        then distribute;
        action distribute {
            in finalDoc = publish.finalDoc;
            out distributedDoc : FinalDocument;
        }
        flow distribute.distributedDoc to finalGuidance;
    }
}
