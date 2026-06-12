package JohnSnowPublicHealthModel {
    import ScalarValues::*;

    attribute def Meter :> Real { doc /* distance in m */ }
    attribute def Hour :> Real { doc /* time in h */ }
    attribute def Day :> Real { doc /* time in d */ }
    attribute def CaseCount :> Integer { doc /* number of disease cases */ }
    attribute def MortalityCount :> Integer { doc /* number of deaths */ }
    attribute def Probability :> Real { doc /* dimensionless probability from 0.0 to 1.0 */ }
    attribute def LiterPerDay :> Real { doc /* water volume flow in L/d */ }
    attribute def PeopleCount :> Integer { doc /* number of people */ }

    item def CholeraCase {
        attribute patientId : String;
        attribute onsetDay : Day;
        attribute outcomeFatal : Boolean;
        attribute distanceToPump : Meter;
        attribute householdWaterSource : String;
    }

    item def HouseholdInterview {
        attribute address : String;
        attribute residents : PeopleCount;
        attribute cases : CaseCount;
        attribute deaths : MortalityCount;
        attribute primaryWaterSource : String;
        attribute notes : String;
    }

    item def PumpUsageObservation {
        attribute pumpId : String;
        attribute householdsServed : PeopleCount;
        attribute estimatedFlow : LiterPerDay;
        attribute contaminationLikelihood : Probability;
    }

    item def EpidemicMapLayer {
        attribute mappedCases : CaseCount;
        attribute suspectedClusterRadius : Meter;
        attribute dominantPumpId : String;
    }

    item def InterventionOrder {
        attribute targetPumpId : String;
        attribute removeHandle : Boolean;
        attribute rationale : String;
    }

    port def CaseReportPort {
        in item caseReport : CholeraCase;
    }

    port def InterviewPort {
        out item interviewRequest : String;
        in item interviewResult : HouseholdInterview;
    }

    port def ObservationPort {
        in item pumpObservation : PumpUsageObservation;
    }

    port def MapDataPort {
        out item mapLayer : EpidemicMapLayer;
    }

    port def DecisionPort {
        out item order : InterventionOrder;
    }

    port def PublicNoticePort {
        out item notice : String;
    }

    part def JohnSnowBasedPublicHealthSystem {
        doc /* Primary function: detect a waterborne disease source by combining case reports, household interviews, geographic mapping, and pump-use evidence, then recommend a targeted intervention to reduce transmission. */

        attribute activeCases : CaseCount;
        attribute fatalities : MortalityCount;
        attribute investigationDuration : Day;
        attribute confidenceThreshold : Probability = 0.75;

        port caseInput : CaseReportPort;
        port interviewChannel : InterviewPort;
        port observationInput : ObservationPort;
        port mapOutput : MapDataPort;
        port decisionOutput : DecisionPort;
        port publicCommunication : PublicNoticePort;

        part investigator : EpidemiologicalInvestigator;
        part mapRoom : SpatialEvidenceMap;
        part surveyTeam : HouseholdSurveyTeam;
        part pumpNetwork : WaterPumpNetwork;
        part healthBoard : HealthBoardAuthority;
        part interventionCrew : PumpInterventionCrew;
        part communicationOffice : PublicCommunicationOffice;

        connect caseInput to investigator.caseReports;
        connect investigator.surveyRequests to surveyTeam.assignmentPort;
        connect surveyTeam.interviewResults to investigator.interviews;
        connect observationInput to pumpNetwork.observationPort;
        connect pumpNetwork.pumpEvidence to investigator.pumpEvidence;
        connect investigator.caseMapData to mapRoom.mapInput;
        connect mapRoom.clusterOutput to investigator.clusterEvidence;
        connect investigator.recommendation to healthBoard.recommendationInput;
        connect healthBoard.orderOutput to interventionCrew.workOrderInput;
        connect healthBoard.noticeOutput to communicationOffice.noticeInput;
        connect mapRoom.publicMapOutput to mapOutput;
        connect healthBoard.orderOutput to decisionOutput;
        connect communicationOffice.noticeOutput to publicCommunication;

        perform action investigateAndIntervene : OutbreakInvestigationAction;

        state def InvestigationStateMachine {
            state Monitoring;
            state CollectingEvidence;
            state MappingCluster;
            state TestingWaterHypothesis;
            state RecommendingIntervention;
            state InterventionExecuted;
            state MonitoringAfterIntervention;

            transition initial then Monitoring;
            transition Monitoring accept NewCaseReported then CollectingEvidence;
            transition CollectingEvidence accept MinimumEvidenceCollected then MappingCluster;
            transition MappingCluster accept ClusterDetected then TestingWaterHypothesis;
            transition TestingWaterHypothesis accept ConfidenceReached then RecommendingIntervention;
            transition TestingWaterHypothesis accept EvidenceInsufficient then CollectingEvidence;
            transition RecommendingIntervention accept BoardApproved then InterventionExecuted;
            transition InterventionExecuted accept PumpHandleRemoved then MonitoringAfterIntervention;
            transition MonitoringAfterIntervention accept CasesDeclining then Monitoring;
        }
    }

    part def EpidemiologicalInvestigator {
        attribute caseCountReviewed : CaseCount;
        attribute fatalityCountReviewed : MortalityCount;
        attribute waterborneHypothesisConfidence : Probability;

        port caseReports : CaseReportPort;
        port interviews : InterviewPort;
        port pumpEvidence : ObservationPort;
        port surveyRequests : InterviewPort;
        port caseMapData : MapDataPort;
        port clusterEvidence : MapDataPort;
        port recommendation : DecisionPort;

        action def FormWaterborneHypothesis {
            in item cases : CholeraCase;
            in item interviews : HouseholdInterview;
            in item pumpObservations : PumpUsageObservation;
            out item recommendation : InterventionOrder;
        }
    }

    part def SpatialEvidenceMap {
        attribute mapScale : Meter;
        attribute plottedCases : CaseCount;
        attribute clusterRadius : Meter;

        port mapInput : MapDataPort;
        port clusterOutput : MapDataPort;
        port publicMapOutput : MapDataPort;

        action def PlotCasesAndPumps {
            in item caseData : CholeraCase;
            in item pumpData : PumpUsageObservation;
            out item layer : EpidemicMapLayer;
        }
    }

    part def HouseholdSurveyTeam {
        attribute householdsVisited : PeopleCount;
        attribute interviewsCompleted : CaseCount;

        port assignmentPort : InterviewPort;
        port interviewResults : InterviewPort;

        action def ConductDoorToDoorSurvey {
            in item request : String;
            out item result : HouseholdInterview;
        }
    }

    part def WaterPumpNetwork {
        attribute pumpCount : Integer;
        attribute dailyWaterDistributed : LiterPerDay;

        port observationPort : ObservationPort;
        port pumpEvidence : ObservationPort;

        part broadStreetPump : PublicWaterPump {
            attribute pumpId : String = "Broad Street Pump";
            attribute estimatedFlow : LiterPerDay = 12000.0;
            attribute contaminationLikelihood : Probability = 0.91;
        }

        part brewerPump : PublicWaterPump {
            attribute pumpId : String = "Brewer Pump";
            attribute estimatedFlow : LiterPerDay = 4000.0;
            attribute contaminationLikelihood : Probability = 0.08;
        }

        part workhousePump : PublicWaterPump {
            attribute pumpId : String = "Workhouse Pump";
            attribute estimatedFlow : LiterPerDay = 3500.0;
            attribute contaminationLikelihood : Probability = 0.04;
        }
    }

    part def PublicWaterPump {
        attribute pumpId : String;
        attribute estimatedFlow : LiterPerDay;
        attribute contaminationLikelihood : Probability;
        attribute handleInstalled : Boolean = true;

        port usageObservation : ObservationPort;
    }

    part def HealthBoardAuthority {
        attribute approvalLatency : Hour;
        attribute acceptedConfidenceThreshold : Probability = 0.75;

        port recommendationInput : DecisionPort;
        port orderOutput : DecisionPort;
        port noticeOutput : PublicNoticePort;

        action def EvaluateRecommendation {
            in item order : InterventionOrder;
            out item approvedOrder : InterventionOrder;
            out item notice : String;
        }
    }

    part def PumpInterventionCrew {
        attribute crewSize : PeopleCount;
        attribute responseTime : Hour;

        port workOrderInput : DecisionPort;

        action def RemovePumpHandle {
            in item order : InterventionOrder;
            out item completed : Boolean;
        }
    }

    part def PublicCommunicationOffice {
        attribute noticesIssued : Integer;

        port noticeInput : PublicNoticePort;
        port noticeOutput : PublicNoticePort;

        action def IssuePublicHealthNotice {
            in item noticeText : String;
            out item distributedNotice : String;
        }
    }

    action def OutbreakInvestigationAction {
        in item reportedCase : CholeraCase;
        in item interview : HouseholdInterview;
        in item pumpObservation : PumpUsageObservation;
        out item evidenceLayer : EpidemicMapLayer;
        out item intervention : InterventionOrder;

        first start;
        then collectCases;
        then interviewHouseholds;
        then mapSpatialPattern;
        then compareWaterSources;
        then decideIntervention;
        then publishNotice;
        then done;

        action collectCases;
        action interviewHouseholds;
        action mapSpatialPattern;
        action compareWaterSources;
        action decideIntervention;
        action publishNotice;
    }

    requirement def PrimaryFunctionRequirement {
        subject system : JohnSnowBasedPublicHealthSystem;
        require constraint {
            system.activeCases >= 0
        }
        doc /* The system shall identify the most probable waterborne source of a cholera outbreak and initiate a targeted public-health intervention. */
    }

    requirement def EvidenceIntegrationRequirement {
        subject system : JohnSnowBasedPublicHealthSystem;
        require constraint {
            system.confidenceThreshold >= 0.75
        }
        doc /* The system shall combine case reports, household interviews, pump-use observations, and spatial clustering before recommending pump intervention. */
    }

    requirement def InterventionRequirement {
        subject system : JohnSnowBasedPublicHealthSystem;
        doc /* The system shall produce an intervention order to remove the handle of the suspected contaminated pump when waterborne-source confidence meets or exceeds the decision threshold. */
    }

    requirement def CommunicationRequirement {
        subject system : JohnSnowBasedPublicHealthSystem;
        doc /* The system shall issue a concise public notice describing the affected water source and advising residents to avoid it. */
    }

    requirement primaryFunction : PrimaryFunctionRequirement {
        subject system = snowSystem;
    }

    requirement evidenceIntegration : EvidenceIntegrationRequirement {
        subject system = snowSystem;
    }

    requirement interventionControl : InterventionRequirement {
        subject system = snowSystem;
    }

    requirement publicCommunication : CommunicationRequirement {
        subject system = snowSystem;
    }

    part snowSystem : JohnSnowBasedPublicHealthSystem {
        attribute activeCases : CaseCount = 616;
        attribute fatalities : MortalityCount = 185;
        attribute investigationDuration : Day = 10.0;
        attribute confidenceThreshold : Probability = 0.75;
    }
}