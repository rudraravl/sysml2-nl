package SnowCholeraInvestigation {
    import ScalarValues::*;

    // ---- Units ----
    unit meter;
    unit day;
    unit count;
    unit fraction;

    // ---- Value types ----
    value type CountOf :> Integer { unit count; }
    value type FatalityRate :> Real { unit fraction; }
    value type LatitudeOf :> Real;
    value type LongitudeOf :> Real;
    value type DistanceOf :> Real { unit meter; }
    value type DurationOf :> Real { unit day; }
    value type DateOf :> String;
    value type ConfidenceOf :> Real { unit fraction; }

    // ---- Enumerations ----
    enum SymptomKind { diarrhea, vomiting, dehydration, cramps, cyanosis, none }
    enum WaterSourceKind { pump, well, river, company_supply, unknown }
    enum PumpStatus { operational, handle_removed, decommissioned }
    enum InterventionKind { remove_pump_handle, sanitize_water, quarantine, boil_water_advisory, none }
    enum HypothesisStatus { untested, supported, refuted, inconclusive }
    enum InvestigationPhase { idle, collecting, mapping, analyzing, evaluating, intervening, complete }

    // ---- Item definitions ----
    item def PatientRecord {
        attribute caseId : String;
        attribute householdId : String;
        attribute residenceAddress : String;
        attribute residenceLat : LatitudeOf;
        attribute residenceLon : LongitudeOf;
        attribute symptom : SymptomKind;
        attribute dateOfOnset : DateOf;
        attribute primaryWaterSource : WaterSourceKind;
        attribute waterSourceName : String;
        attribute fatal : Boolean;
    }

    item def PumpRecord {
        attribute pumpId : String;
        attribute pumpName : String;
        attribute street : String;
        attribute lat : LatitudeOf;
        attribute lon : LongitudeOf;
        attribute status : PumpStatus;
    }

    item def CaseLocation {
        attribute caseId : String;
        attribute lat : LatitudeOf;
        attribute lon : LongitudeOf;
    }

    item def EpidemiologicalMap {
        attribute mapId : String;
        attribute caseLocations : CaseLocation[0..*];
        attribute pumpLocations : PumpRecord[0..*];
        attribute clusterCenterLat : LatitudeOf;
        attribute clusterCenterLon : LongitudeOf;
        attribute maxClusterRadius : DistanceOf;
    }

    item def StatisticalReport {
        attribute totalCases : CountOf;
        attribute totalFatalities : CountOf;
        attribute fatalityRate : FatalityRate;
        attribute clusterCenterLat : LatitudeOf;
        attribute clusterCenterLon : LongitudeOf;
        attribute nearestPumpId : String;
        attribute correlationStrength : Real;
        attribute candidateSourcePumpId : String;
        attribute meanDistanceToCandidate : DistanceOf;
    }

    item def Findings {
        attribute hypothesis : String;
        attribute hypothesisStatus : HypothesisStatus;
        attribute probableSourcePumpId : String;
        attribute supportingEvidence : String[0..*];
        attribute recommendedAction : InterventionKind;
        attribute confidence : ConfidenceOf;
    }

    item def InterventionAction {
        attribute actionKind : InterventionKind;
        attribute targetPumpId : String;
        attribute implemented : Boolean;
        attribute outcome : String;
    }

    // ---- Port definitions ----
    port def PatientDataPort { inout patientRecords : PatientRecord[0..*]; }
    port def PumpDataPort { inout pumpRecords : PumpRecord[0..*]; }
    port def MapDataPort { inout map : EpidemiologicalMap; }
    port def ReportPort { inout report : StatisticalReport; }
    port def FindingsPort { inout findings : Findings; }
    port def ActionPort { inout action : InterventionAction; }

    // ---- Field Investigation Unit ----
    part def FieldInvestigationUnit {
        port out patientOut : PatientDataPort;
        port out pumpOut : PumpDataPort;
        attribute householdsInterviewed : CountOf = 0;
        attribute pumpsSurveyed : CountOf = 0;
        attribute investigationDuration : DurationOf = 0;

        action def InterviewHousehold {
            in address : String;
            in lat : LatitudeOf;
            in lon : LongitudeOf;
            out record : PatientRecord;
        }

        action def SurveyPump {
            in street : String;
            in lat : LatitudeOf;
            in lon : LongitudeOf;
            out record : PumpRecord;
        }

        action def ConductFieldInvestigation {
            out patientRecords : PatientRecord[0..*];
            out pumpRecords : PumpRecord[0..*];
        }

        action conductInvestigation : ConductFieldInvestigation;
    }

    // ---- Cartographic Mapping Unit ----
    part def CartographicMappingUnit {
        port in patientIn : PatientDataPort;
        port in pumpIn : PumpDataPort;
        port out mapOut : MapDataPort;
        attribute mapsProduced : CountOf = 0;

        action def PlotCases {
            in records : PatientRecord[0..*];
            out locations : CaseLocation[0..*];
        }

        action def PlotPumps {
            in pumps : PumpRecord[0..*];
            out plotted : PumpRecord[0..*];
        }

        action def AssembleMap {
            in caseLocations : CaseLocation[0..*];
            in pumpRecords : PumpRecord[0..*];
            out map : EpidemiologicalMap;
        }

        action produceMap {
            in records : PatientRecord[0..*] = patientIn.patientRecords;
            in pumps : PumpRecord[0..*] = pumpIn.pumpRecords;
            out resultMap : EpidemiologicalMap = mapOut.map;
        }
    }

    // ---- Statistical Analysis Unit ----
    part def StatisticalAnalysisUnit {
        port in mapIn : MapDataPort;
        port in patientIn : PatientDataPort;
        port out reportOut : ReportPort;
        attribute reportsGenerated : CountOf = 0;

        action def CountCases {
            in records : PatientRecord[0..*];
            out total : CountOf;
        }

        action def ComputeFatality {
            in records : PatientRecord[0..*];
            out fatalities : CountOf;
            out rate : FatalityRate;
        }

        action def FindClusterCenter {
            in map : EpidemiologicalMap;
            out lat : LatitudeOf;
            out lon : LongitudeOf;
        }

        action def CorrelateWithPumps {
            in map : EpidemiologicalMap;
            out pumpId : String;
            out strength : Real;
            out meanDistance : DistanceOf;
        }

        action analyze {
            in sourceMap : EpidemiologicalMap = mapIn.map;
            in records : PatientRecord[0..*] = patientIn.patientRecords;
            out report : StatisticalReport = reportOut.report;
        }
    }

    // ---- Hypothesis Evaluation Unit ----
    part def HypothesisEvaluationUnit {
        port in reportIn : ReportPort;
        port out findingsOut : FindingsPort;
        attribute hypothesis : String = "Cholera is a waterborne disease transmitted via contaminated water";
        attribute status : HypothesisStatus = HypothesisStatus::untested;

        action def AssessEvidence {
            in report : StatisticalReport;
            out status : HypothesisStatus;
        }

        action def IdentifyProbableSource {
            in report : StatisticalReport;
            out pumpId : String;
        }

        action def CompileFindings {
            in report : StatisticalReport;
            in status : HypothesisStatus;
            in probableSource : String;
            out findings : Findings;
        }

        action evaluate {
            in report : StatisticalReport = reportIn.report;
            out findings : Findings = findingsOut.findings;
        }
    }

    // ---- Public Health Intervention Unit ----
    part def PublicHealthInterventionUnit {
        port in findingsIn : FindingsPort;
        port out actionOut : ActionPort;
        attribute interventionsImplemented : CountOf = 0;

        action def ReviewEvidence {
            in findings : Findings;
            out approved : Boolean;
        }

        action def ImplementAction {
            in findings : Findings;
            out action : InterventionAction;
        }

        action intervene {
            in findings : Findings = findingsIn.findings;
            out action : InterventionAction = actionOut.action;
        }
    }

    // ---- Top-level system ----
    part def CholeraInvestigationSystem {
        attribute systemName : String = "Snow Broad Street Cholera Investigation";
        attribute outbreakYear : Integer = 1854;
        attribute outbreakLocation : String = "Soho, London";
        attribute currentPhase : InvestigationPhase = InvestigationPhase::idle;

        part fieldUnit : FieldInvestigationUnit;
        part mappingUnit : CartographicMappingUnit;
        part analysisUnit : StatisticalAnalysisUnit;
        part evaluationUnit : HypothesisEvaluationUnit;
        part interventionUnit : PublicHealthInterventionUnit;

        connect fieldUnit.patientOut to mappingUnit.patientIn;
        connect fieldUnit.pumpOut to mappingUnit.pumpIn;
        connect mappingUnit.mapOut to analysisUnit.mapIn;
        connect fieldUnit.patientOut to analysisUnit.patientIn;
        connect analysisUnit.reportOut to evaluationUnit.reportIn;
        connect evaluationUnit.findingsOut to interventionUnit.findingsIn;

        port out finalAction : ActionPort = interventionUnit.actionOut;

        state def InvestigationLifecycle {
            initial start;
            state CollectingFieldData {
                entry action { fieldUnit.conductInvestigation; }
            }
            state MappingCases {
                entry action { mappingUnit.produceMap; }
            }
            state AnalyzingStatistics {
                entry action { analysisUnit.analyze; }
            }
            state EvaluatingHypothesis {
                entry action { evaluationUnit.evaluate; }
            }
            state ImplementingIntervention {
                entry action { interventionUnit.intervene; }
            }
            state Complete;

            transition start to CollectingFieldData;
            transition CollectingFieldData to MappingCases
                when fieldUnit.householdsInterviewed > 0;
            transition MappingCases to AnalyzingStatistics
                when mappingUnit.mapsProduced > 0;
            transition AnalyzingStatistics to EvaluatingHypothesis
                when analysisUnit.reportsGenerated > 0;
            transition EvaluatingHypothesis to ImplementingIntervention
                when evaluationUnit.status == HypothesisStatus::supported;
            transition ImplementingIntervention to Complete
                when interventionUnit.interventionsImplemented > 0;
        }

        exhibit InvestigationLifecycle;
    }

    // ---- Requirements ----
    requirement def InvestigationRequirement {
        doc /* The system shall pinpoint the origin of a disease outbreak through systematic field data collection, spatial mapping, and statistical analysis. */
        attribute maxInvestigationDuration : DurationOf = 14;
    }

    requirement def DataCollectionRequirement {
        doc /* The field investigation unit shall interview households to gather patient records including residence, symptoms, date of onset, and primary water source, and shall survey all public water pumps. */
        attribute minHouseholdsInterviewed : CountOf = 50;
        attribute minPumpsSurveyed : CountOf = 5;
    }

    requirement def MappingRequirement {
        doc /* The cartographic mapping unit shall produce a spot map plotting the geographic location of every cholera case and every water pump. */
        attribute mapAccuracy : DistanceOf = 10;
    }

    requirement def StatisticalRequirement {
        doc /* The statistical analysis unit shall compute total cases, fatality rate, cluster center, and correlation of case locations with nearby water sources. */
        attribute maxClusterRadius : DistanceOf = 200;
    }

    requirement def HypothesisRequirement {
        doc /* The hypothesis evaluation unit shall test the waterborne disease hypothesis, identify the most probable source pump, and compile findings with a recommended action. */
        attribute minConfidence : ConfidenceOf = 0.7;
    }

    requirement def InterventionRequirement {
        doc /* The public health intervention unit shall review the evidence and implement the recommended action to halt the outbreak. */
        attribute maxResponseTime : DurationOf = 2;
    }

    requirement investigationGoal : InvestigationRequirement {
        subject system : CholeraInvestigationSystem;
    }

    requirement dataCollection : DataCollectionRequirement {
        subject fieldUnit : FieldInvestigationUnit;
    }

    requirement mapping : MappingRequirement {
        subject mappingUnit : CartographicMappingUnit;
    }

    requirement statistics : StatisticalRequirement {
        subject analysisUnit : StatisticalAnalysisUnit;
    }

    requirement hypothesis : HypothesisRequirement {
        subject evaluationUnit : HypothesisEvaluationUnit;
    }

    requirement intervention : InterventionRequirement {
        subject interventionUnit : PublicHealthInterventionUnit;
    }

    // ---- Verification actions ----
    action def VerifyDataCollection {
        in unit : FieldInvestigationUnit;
        in req : DataCollectionRequirement;
        out passed : Boolean;
    }

    action def VerifyMapping {
        in unit : CartographicMappingUnit;
        in req : MappingRequirement;
        out passed : Boolean;
    }

    action def VerifyStatistics {
        in unit : StatisticalAnalysisUnit;
        in req : StatisticalRequirement;
        out passed : Boolean;
    }

    action def VerifyHypothesis {
        in unit : HypothesisEvaluationUnit;
        in req : HypothesisRequirement;
        out passed : Boolean;
    }

    action def VerifyIntervention {
        in unit : PublicHealthInterventionUnit;
        in req : InterventionRequirement;
        out passed : Boolean;
    }

    // ---- A sample configured investigation ----
    part broadStreetInvestigation : CholeraInvestigationSystem {
        attribute systemName = "Broad Street Cholera Investigation 1854";
        redefines outbreakYear = 1854;
        redefines outbreakLocation = "Broad Street, Soho, London";

        part fieldUnit : FieldInvestigationUnit {
            redefines householdsInterviewed = 73;
            redefines pumpsSurveyed = 13;
        }
        part mappingUnit : CartographicMappingUnit {
            redefines mapsProduced = 1;
        }
        part analysisUnit : StatisticalAnalysisUnit {
            redefines reportsGenerated = 1;
        }
        part evaluationUnit : HypothesisEvaluationUnit {
            redefines status = HypothesisStatus::supported;
        }
        part interventionUnit : PublicHealthInterventionUnit {
            redefines interventionsImplemented = 1;
        }
    }
}
