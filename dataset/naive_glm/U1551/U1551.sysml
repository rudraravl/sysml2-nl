package DARPAOperationalFramework {
    import ScalarValues::*;
    import ScalarFunctions::*;

    // ===== Value Types with Units =====
    value def USD :> Real {
        unit 'USD';
    }
    value def TRLLevel :> Integer {
        constraint { self >= 1 and self <= 9 }
    }
    value def RiskScore :> Integer {
        constraint { self >= 1 and self <= 10 }
    }
    value def PerformanceMetric :> Real {
        unit 'percent';
        constraint { self >= 0.0 and self <= 100.0 }
    }
    value def DurationMonths :> Real {
        unit 'month';
    }

    // ===== Item Definitions =====
    item def ResearchProposal {
        attribute proposalId : String;
        attribute title : String;
        attribute technicalArea : String;
        attribute requestedFunding : USD;
        attribute riskAssessment : RiskScore;
        attribute innovationScore : RiskScore;
    }

    item def ReviewDecision {
        attribute proposalId : String;
        attribute approved : Boolean;
        attribute meritScore : RiskScore;
        attribute reviewerNotes : String;
    }

    item def FundingAward {
        attribute awardId : String;
        attribute proposalId : String;
        attribute amount : USD;
        attribute recipient : String;
        attribute duration : DurationMonths;
    }

    item def TechnicalData {
        attribute dataId : String;
        attribute performanceMetrics : PerformanceMetric;
        attribute description : String;
    }

    item def Prototype {
        attribute prototypeId : String;
        attribute name : String;
        attribute technicalArea : String;
        attribute trl : TRLLevel := 4;
        attribute performance : PerformanceMetric := 0.0;
    }

    item def TestReport {
        attribute reportId : String;
        attribute prototypeId : String;
        attribute measuredPerformance : PerformanceMetric;
        attribute resultingTRL : TRLLevel;
        attribute passed : Boolean;
    }

    item def TransitionPackage {
        attribute packageId : String;
        attribute prototypeId : String;
        attribute documentation : String;
        attribute finalTRL : TRLLevel;
        attribute operationalAssessment : String;
    }

    // ===== Port Definitions =====
    port def ProposalSolicitationPort {
        out item : ResearchProposal;
    }
    port def ProposalSubmissionPort {
        in item : ResearchProposal;
    }
    port def ReviewDecisionPort {
        out item : ReviewDecision;
    }
    port def FundingAwardPort {
        out item : FundingAward;
    }
    port def FundingReceiptPort {
        in item : FundingAward;
    }
    port def PrototypeDeliveryPort {
        out item : Prototype;
    }
    port def PrototypeReceiptPort {
        in item : Prototype;
    }
    port def TechnicalDataPort {
        out item : TechnicalData;
    }
    port def TestReportPort {
        out item : TestReport;
    }
    port def TestReportReceiptPort {
        in item : TestReport;
    }
    port def TransitionPackagePort {
        out item : TransitionPackage;
    }
    port def TransitionPackageReceiptPort {
        in item : TransitionPackage;
    }

    // ===== Part Definitions =====
    part def ProgramManager {
        attribute managerId : String;
        attribute name : String;
        attribute technicalChallenge : String;
        attribute focusArea : String;

        port solicitation : ProposalSolicitationPort;
        port submissions : ProposalSubmissionPort;
        port reviewInput : ReviewDecisionPort;
        port fundingOut : FundingAwardPort;
        port testReportIn : TestReportReceiptPort;

        attribute activePrograms : Integer := 0;

        action def defineTechnicalChallenge {
            in challenge : String;
            out solicitation : ResearchProposal;
        }

        action def authorizeFunding {
            in decision : ReviewDecision;
            out award : FundingAward;
        }

        exhibit state ProgramLifecycle {
            entry; then Soliciting;
            state Soliciting {
                entry { send ResearchProposal to solicitation; }
                accept submittedProposal : ResearchProposal via submissions;
                then Reviewing;
            }
            state Reviewing {
                accept decision : ReviewDecision via reviewInput;
                if decision.approved {
                    then Funding;
                } else {
                    then Soliciting;
                }
            }
            state Funding {
                entry { send FundingAward to fundingOut; }
                then Monitoring;
            }
            state Monitoring {
                accept report : TestReport via testReportIn;
                if report.passed {
                    then Transitioning;
                } else {
                    then Soliciting;
                }
            }
            state Transitioning {
                entry { activePrograms := activePrograms - 1; }
                then done;
            }
        }
    }

    part def TechnicalReviewBoard {
        attribute boardId : String;
        attribute expertiseAreas : String;
        attribute memberCount : Integer;

        port proposalsIn : ProposalSubmissionPort;
        port decisionsOut : ReviewDecisionPort;

        action def evaluateProposal {
            in proposal : ResearchProposal;
            out decision : ReviewDecision;
        }

        exhibit state ReviewCycle {
            entry; then Awaiting;
            state Awaiting {
                accept proposal : ResearchProposal via proposalsIn;
                then Evaluating;
            }
            state Evaluating {
                do evaluateProposal;
                then Deciding;
            }
            state Deciding {
                entry { send ReviewDecision to decisionsOut; }
                then Awaiting;
            }
        }
    }

    part def ResearchPerformer {
        attribute performerId : String;
        attribute organizationName : String;
        attribute organizationType : String;
        attribute fundingReceived : USD := 0.0;

        port fundingIn : FundingReceiptPort;
        port prototypeOut : PrototypeDeliveryPort;
        port dataOut : TechnicalDataPort;

        action def conductResearch {
            in award : FundingAward;
            out prototype : Prototype;
            out data : TechnicalData;
        }

        exhibit state ResearchExecution {
            entry; then Idle;
            state Idle {
                accept award : FundingAward via fundingIn;
                fundingReceived := fundingReceived + award.amount;
                then Developing;
            }
            state Developing {
                do conductResearch;
                then Delivering;
            }
            state Delivering {
                entry {
                    send Prototype to prototypeOut;
                    send TechnicalData to dataOut;
                }
                then Idle;
            }
        }
    }

    part def TestAndEvaluationFacility {
        attribute facilityId : String;
        attribute facilityName : String;
        attribute capabilityAreas : String;

        port prototypeIn : PrototypeReceiptPort;
        port reportOut : TestReportPort;

        action def testPrototype {
            in prototype : Prototype;
            out report : TestReport;
        }

        exhibit state TestCycle {
            entry; then Ready;
            state Ready {
                accept prototype : Prototype via prototypeIn;
                then Testing;
            }
            state Testing {
                do testPrototype;
                then Reporting;
            }
            state Reporting {
                entry { send TestReport to reportOut; }
                then Ready;
            }
        }
    }

    part def TransitionOffice {
        attribute officeId : String;
        attribute officeName : String;
        attribute partnerAgencies : String;

        port reportIn : TestReportReceiptPort;
        port packageOut : TransitionPackagePort;

        action def prepareTransitionPackage {
            in report : TestReport;
            out pkg : TransitionPackage;
        }

        exhibit state TransitionProcess {
            entry; then Waiting;
            state Waiting {
                accept report : TestReport via reportIn;
                if report.passed {
                    then Packaging;
                } else {
                    then Waiting;
                }
            }
            state Packaging {
                do prepareTransitionPackage;
                then Handoff;
            }
            state Handoff {
                entry { send TransitionPackage to packageOut; }
                then Waiting;
            }
        }
    }

    part def PartnerAgency {
        attribute agencyId : String;
        attribute agencyName : String;
        attribute serviceBranch : String;

        port packageIn : TransitionPackageReceiptPort;

        attribute receivedCapabilities : Integer := 0;

        exhibit state AdoptionCycle {
            entry; then Receptive;
            state Receptive {
                accept pkg : TransitionPackage via packageIn;
                receivedCapabilities := receivedCapabilities + 1;
                then Receptive;
            }
        }
    }

    // ===== Composite System =====
    part def AdvancedTechDevelopmentAgency {
        attribute agencyName : String := "Advanced Research Projects Agency";
        attribute mission : String := "Create breakthrough technologies for national security";

        part programManager : ProgramManager {
            managerId := "PM-001";
            name := "Lead Program Manager";
            technicalChallenge := "Prevent technological surprise";
            focusArea := "AI, Hypersonics, Biotechnology";
        }
        part reviewBoard : TechnicalReviewBoard {
            boardId := "TRB-001";
            expertiseAreas := "AI, Hypersonics, Biotechnology, Quantum";
            memberCount := 12;
        }
        part performer : ResearchPerformer {
            performerId := "RP-001";
            organizationName := "National Innovation Lab";
            organizationType := "University";
        }
        part testFacility : TestAndEvaluationFacility {
            facilityId := "TEF-001";
            facilityName := "National Prototyping Test Center";
            capabilityAreas := "Hypersonics, AI, Biotech";
        }
        part transitionOffice : TransitionOffice {
            officeId := "TO-001";
            officeName := "Technology Transition Office";
            partnerAgencies := "Army, Navy, Air Force, SOCOM";
        }
        part partner : PartnerAgency {
            agencyId := "PA-001";
            agencyName := "Joint Operational Command";
            serviceBranch := "Joint";
        }

        // Connections
        connection programManager.solicitation to reviewBoard.proposalsIn;
        connection reviewBoard.decisionsOut to programManager.reviewInput;
        connection programManager.fundingOut to performer.fundingIn;
        connection performer.prototypeOut to testFacility.prototypeIn;
        connection performer.dataOut to testFacility.prototypeIn;
        connection testFacility.reportOut to programManager.testReportIn;
        connection testFacility.reportOut to transitionOffice.reportIn;
        connection transitionOffice.packageOut to partner.packageIn;
    }

    // ===== Requirements =====
    requirement def BreakthroughTechnologyMission {
        subject agency : AdvancedTechDevelopmentAgency;
        objective {
            doc "The agency shall create breakthrough technologies and capabilities for national security."
        }
        assume { agency.mission == "Create breakthrough technologies for national security" }
    }

    requirement def ProposalSolicitationRequirement {
        subject pm : ProgramManager;
        objective {
            doc "The Program Manager shall solicit innovative research proposals from external organizations."
        }
        require { pm.technicalChallenge != "" }
    }

    requirement def TechnicalReviewRequirement {
        subject board : TechnicalReviewBoard;
        objective {
            doc "The Technical Review Board shall assess technical merit, innovation, and risk of each proposal."
        }
        require { board.memberCount > 0 }
    }

    requirement def ResearchPerformerRequirement {
        subject performer : ResearchPerformer;
        objective {
            doc "The Research Performer shall mature an approved concept into a functional prototype."
        }
        require { performer.fundingReceived > 0.0 }
    }

    requirement def PrototypeTestingRequirement {
        subject facility : TestAndEvaluationFacility;
        objective {
            doc "The Test and Evaluation Facility shall validate prototype performance and determine TRL."
        }
        require { facility.capabilityAreas != "" }
    }

    requirement def TransitionRequirement {
        subject office : TransitionOffice;
        objective {
            doc "The Transition Office shall prepare a complete Transition Package for successful prototypes."
        }
        require { office.partnerAgencies != "" }
    }

    requirement def CapabilityAdoptionRequirement {
        subject partner : PartnerAgency;
        objective {
            doc "The Partner Agency shall receive and adopt transitioned capabilities for operational use."
        }
        require { partner.receivedCapabilities >= 0 }
    }

    requirement agencyMissionRequirement : BreakthroughTechnologyMission {
        subject agency : AdvancedTechDevelopmentAgency::agency;
    }
    requirement solicitationRequirement : ProposalSolicitationRequirement {
        subject pm : AdvancedTechDevelopmentAgency::programManager;
    }
    requirement reviewRequirement : TechnicalReviewRequirement {
        subject board : AdvancedTechDevelopmentAgency::reviewBoard;
    }
    requirement performerRequirement : ResearchPerformerRequirement {
        subject performer : AdvancedTechDevelopmentAgency::performer;
    }
    requirement testingRequirement : PrototypeTestingRequirement {
        subject facility : AdvancedTechDevelopmentAgency::testFacility;
    }
    requirement transitionRequirement : TransitionRequirement {
        subject office : AdvancedTechDevelopmentAgency::transitionOffice;
    }
    requirement adoptionRequirement : CapabilityAdoptionRequirement {
        subject partner : AdvancedTechDevelopmentAgency::partner;
    }
}
