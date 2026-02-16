package 'John Snow Epidemiological Investigation System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    doc /* 
        This model represents Dr. John Snow's pioneering epidemiological investigation system
        used during the 1854 Broad Street cholera outbreak in London. The system's primary 
        function is to identify disease outbreak sources through systematic field investigation,
        spatial mapping of cases, statistical analysis of disease patterns, and correlation 
        with environmental factors to enable evidence-based public health interventions.
    */
    
    attribute def GeographicLocation {
        attribute streetAddress : String;
        attribute latitude : Real;
        attribute longitude : Real;
        attribute districtName : String;
    }
    
    attribute def PatientRecord {
        attribute patientId : String;
        attribute residenceLocation : GeographicLocation;
        attribute onsetDate : String;
        attribute symptomSeverity : Real;
        attribute outcomeStatus : String;
        attribute primaryWaterSource : String;
    }
    
    attribute def WaterPumpData {
        attribute pumpId : String;
        attribute pumpLocation : GeographicLocation;
        attribute pumpType : String;
        attribute waterQuality : String;
        attribute usageFrequency : Real;
    }
    
    item def CaseReport {
        attribute patient : PatientRecord;
        attribute investigationDate : String;
        attribute verificationStatus : Boolean;
    }
    
    item def EpidemiologicalMap {
        attribute caseLocations : GeographicLocation[*];
        attribute pumpLocations : GeographicLocation[*];
        attribute caseDensityGrid : Real[*];
        attribute spatialExtent : LengthValue;
    }
    
    item def StatisticalAnalysis {
        attribute totalCases : Integer;
        attribute caseFatalityRate : Real;
        attribute spatialClusterCenter : GeographicLocation;
        attribute clusterRadius : LengthValue;
        attribute correlationCoefficient : Real;
        attribute confidenceLevel : Real;
    }
    
    item def InvestigationFindings {
        attribute identifiedSource : WaterPumpData;
        attribute supportingEvidence : String[*];
        attribute statisticalSignificance : Real;
        attribute recommendedAction : String;
        attribute publicHealthImpact : String;
    }
    
    part def FieldInvestigationUnit {
        out port caseReportsOut : CaseReport[*];
        out port waterSourceDataOut : WaterPumpData[*];
        
        action conductFieldwork {
            out collectedCases : CaseReport[*];
            out identifiedPumps : WaterPumpData[*];
            
            first start;
            then action interviewHouseholds {
                out patientData : PatientRecord[*];
            }
            then action documentWaterSources {
                out pumpData : WaterPumpData[*];
            }
            then action verifyInformation {
                in rawPatients : PatientRecord[*];
                in rawPumps : WaterPumpData[*];
                out verifiedCases : CaseReport[*];
                out verifiedPumps : WaterPumpData[*];
            }
            then assign collectedCases := verifyInformation.verifiedCases;
            then assign identifiedPumps := verifyInformation.verifiedPumps;
            then done;
        }
    }
    
    part def CartographicMappingUnit {
        in port caseDataIn : CaseReport[*];
        in port pumpDataIn : WaterPumpData[*];
        out port epidemiologicalMapOut : EpidemiologicalMap;
        
        action createDiseaseMap {
            in cases : CaseReport[*];
            in pumps : WaterPumpData[*];
            out diseaseMap : EpidemiologicalMap;
            
            first start;
            then action extractLocations {
                in caseReports : CaseReport[*];
                out casePositions : GeographicLocation[*];
            }
            then action plotCasesOnMap {
                in positions : GeographicLocation[*];
                in pumpPositions : WaterPumpData[*];
                out baseMap : EpidemiologicalMap;
            }
            then action calculateDensity {
                in mapData : EpidemiologicalMap;
                out enhancedMap : EpidemiologicalMap;
            }
            then assign diseaseMap := calculateDensity.enhancedMap;
            then done;
        }
    }
    
    part def StatisticalAnalysisUnit {
        in port mapDataIn : EpidemiologicalMap;
        in port caseDataIn : CaseReport[*];
        out port analysisResultsOut : StatisticalAnalysis;
        
        action performStatisticalAnalysis {
            in epidMap : EpidemiologicalMap;
            in caseData : CaseReport[*];
            out analysis : StatisticalAnalysis;
            
            first start;
            then action identifySpatialCluster {
                in caseLocations : GeographicLocation[*];
                out clusterCenter : GeographicLocation;
                out clusterSize : LengthValue;
            }
            then action calculateCaseMetrics {
                in cases : CaseReport[*];
                out totalCount : Integer;
                out fatalityRate : Real;
            }
            then action correlateWithWaterSources {
                in cluster : GeographicLocation;
                in pumps : WaterPumpData[*];
                out nearestPump : WaterPumpData;
                out correlation : Real;
            }
            then action assessStatisticalSignificance {
                in correlationValue : Real;
                in sampleSize : Integer;
                out significance : Real;
                out confidence : Real;
            }
            then done;
        }
    }
    
    part def HypothesisEvaluationUnit {
        in port statisticalDataIn : StatisticalAnalysis;
        in port pumpDataIn : WaterPumpData[*];
        out port findingsOut : InvestigationFindings;
        
        action evaluateWaterborneHypothesis {
            in stats : StatisticalAnalysis;
            in pumps : WaterPumpData[*];
            out findings : InvestigationFindings;
            
            first start;
            then action identifyMostLikelySource {
                in clusterCenter : GeographicLocation;
                in availablePumps : WaterPumpData[*];
                out suspectedPump : WaterPumpData;
            }
            then action compileEvidence {
                in statisticalData : StatisticalAnalysis;
                in sourcePump : WaterPumpData;
                out evidenceList : String[*];
            }
            then decide;
                if stats.correlationCoefficient > 0.75 then strongEvidence;
                if stats.correlationCoefficient <= 0.75 then weakEvidence;
            
            action strongEvidence {
                out recommendation : String;
            }
            then done;
            
            action weakEvidence {
                out recommendation : String;
            }
            then done;
        }
    }
    
    part def PublicHealthInterventionUnit {
        in port findingsIn : InvestigationFindings;
        out port interventionOrderOut : String;
        
        action implementIntervention {
            in investigationFindings : InvestigationFindings;
            out interventionAction : String;
            
            first start;
            then action reviewFindings {
                in findings : InvestigationFindings;
                out actionRequired : Boolean;
            }
            then decide;
                if reviewFindings.actionRequired then executeIntervention;
                else monitorSituation;
            
            action executeIntervention {
                out actionTaken : String;
            }
            then notifyAuthorities;
            
            action monitorSituation {
                out actionTaken : String;
            }
            then notifyAuthorities;
            
            action notifyAuthorities {
                out notification : String;
            }
            then done;
        }
    }
    
    part def EpidemiologicalInvestigationSystem {
        part fieldUnit : FieldInvestigationUnit {
            perform action investigation : conductFieldwork;
        }
        
        part mappingUnit : CartographicMappingUnit {
            perform action mapping : createDiseaseMap;
        }
        
        part analysisUnit : StatisticalAnalysisUnit {
            perform action analysis : performStatisticalAnalysis;
        }
        
        part evaluationUnit : HypothesisEvaluationUnit {
            perform action evaluation : evaluateWaterborneHypothesis;
        }
        
        part interventionUnit : PublicHealthInterventionUnit {
            perform action intervention : implementIntervention;
        }
        
        connection caseDataFlow connect 
            fieldUnit.caseReportsOut to mappingUnit.caseDataIn;
        
        connection pumpDataFlow connect 
            fieldUnit.waterSourceDataOut to mappingUnit.pumpDataIn;
        
        connection mapToAnalysis connect 
            mappingUnit.epidemiologicalMapOut to analysisUnit.mapDataIn;
        
        connection casesToAnalysis connect 
            fieldUnit.caseReportsOut to analysisUnit.caseDataIn;
        
        connection analysisToEvaluation connect 
            analysisUnit.analysisResultsOut to evaluationUnit.statisticalDataIn;
        
        connection pumpsToEvaluation connect 
            fieldUnit.waterSourceDataOut to evaluationUnit.pumpDataIn;
        
        connection findingsToIntervention connect 
            evaluationUnit.findingsOut to interventionUnit.findingsIn;
    }
    
    state def InvestigationLifecycle {
        entry; then initialAssessment;
        
        state initialAssessment {
            entry action assessOutbreakSeverity;
        }
        then fieldInvestigation;
        
        state fieldInvestigation {
            entry action deployInvestigators;
            do action collectData;
        }
        then spatialMapping;
        
        state spatialMapping {
            entry action createEpidemiologicalMap;
        }
        then statisticalAnalysis;
        
        state statisticalAnalysis {
            entry action analyzePatterns;
            do action calculateCorrelations;
        }
        then hypothesisTesting;
        
        state hypothesisTesting {
            entry action evaluateWaterborneTheory;
        }
        accept at hypothesisTesting
            if evidenceStrong
            then interventionPlanning;
        accept at hypothesisTesting
            if evidenceWeak
            then fieldInvestigation;
        
        state interventionPlanning {
            entry action formulateResponse;
        }
        then implementation;
        
        state implementation {
            entry action executePublicHealthMeasures;
            do action monitorOutcomeEffectiveness;
        }
        then evaluationComplete;
        
        state evaluationComplete;
    }
    
    requirement def EpidemiologicalInvestigationRequirement {
        doc /* Base requirement for epidemiological investigation capabilities */
        subject system : EpidemiologicalInvestigationSystem;
    }
    
    requirement <'REQ-001'> identifyDiseaseSource : EpidemiologicalInvestigationRequirement {
        doc /* 
            The system shall identify the environmental source of a disease outbreak
            through systematic collection and analysis of case distribution data,
            achieving a minimum correlation coefficient of 0.75 between disease
            incidence and suspected environmental factors.
        */
        
        require constraint minimumCaseData {
            doc /* At least 50 verified case reports required for statistical validity */
        }
        
        require constraint spatialPrecision {
            doc /* Case locations must be accurate to within 50 meters */
        }
        
        require constraint temporalAccuracy {
            doc /* Disease onset dates must be recorded with daily precision */
        }
        
        require constraint correlationThreshold {
            doc /* Statistical correlation must exceed 0.75 for source identification */
        }
    }
    
    requirement <'REQ-002'> enableEvidenceBasedIntervention : EpidemiologicalInvestigationRequirement {
        doc /* 
            The system shall provide evidence-based recommendations for public health
            interventions within 72 hours of initial outbreak detection, supported by
            statistical analysis and spatial correlation data.
        */
        
        assume constraint outbreakDetected {
            doc /* Disease outbreak has been detected and reported to authorities */
        }
        
        require constraint analysisCompletionTime {
            doc /* Complete investigation and analysis within 72 hours */
        }
        
        require constraint recommendationClarity {
            doc /* Intervention recommendations must be specific and actionable */
        }
        
        require constraint evidenceDocumentation {
            doc /* All findings must be supported by documented evidence */
        }
    }
    
    requirement <'REQ-003'> maintainInvestigationIntegrity : EpidemiologicalInvestigationRequirement {
        doc /* 
            The system shall maintain complete traceability and integrity of all
            collected data, ensuring reproducibility of analysis and verification
            of conclusions by independent reviewers.
        */
        
        require constraint dataCompleteness {
            doc /* Each case record must include location, date, symptoms, and water source */
        }
        
        require constraint verificationProcess {
            doc /* All case reports must be verified through independent confirmation */
        }
        
        require constraint auditTrail {
            doc /* Complete audit trail of data collection and analysis steps */
        }
        
        require constraint methodTransparency {
            doc /* Statistical methods and assumptions must be fully documented */
        }
    }
    
    requirement <'REQ-004'> supportScientificMethod : EpidemiologicalInvestigationRequirement {
        doc /* 
            The system shall support rigorous application of the scientific method,
            including hypothesis formation, systematic data collection, objective
            analysis, and evidence-based conclusions.
        */
        
        require constraint hypothesisDriven {
            doc /* Investigation must be guided by testable hypotheses */
        }
        
        require constraint systematicCollection {
            doc /* Data collection must follow standardized protocols */
        }
        
        require constraint objectiveAnalysis {
            doc /* Analysis methods must be objective and reproducible */
        }
    }
    
    action def ConductEpidemiologicalInvestigation {
        in attribute outbreakLocation : String;
        in attribute suspectedCause : String;
        out attribute conclusiveFindings : InvestigationFindings;
        
        first start;
        then merge investigationCycle;
        
        then action deployFieldTeam {
            out caseData : CaseReport[*];
            out environmentalData : WaterPumpData[*];
        }
        
        then action mapDiseaseDistribution {
            in cases : CaseReport[*];
            in pumps : WaterPumpData[*];
            out spatialMap : EpidemiologicalMap;
        }
        
        then action analyzeEpidemiologicalPattern {
            in diseaseMap : EpidemiologicalMap;
            in caseReports : CaseReport[*];
            out statisticalResults : StatisticalAnalysis;
        }
        
        then action testWaterborneHypothesis {
            in statistics : StatisticalAnalysis;
            in waterSources : WaterPumpData[*];
            out evaluationResults : InvestigationFindings;
        }
        
        then decide;
            if testWaterborneHypothesis.evaluationResults.statisticalSignificance > 0.95 then implementControl;
            else investigationCycle;
        
        action implementControl {
            in findings : InvestigationFindings;
            out controlMeasure : String;
        }
        then assign conclusiveFindings := testWaterborneHypothesis.evaluationResults;
        then done;
    }
    
    part broadStreetInvestigation : EpidemiologicalInvestigationSystem {
        attribute investigationSite : String = "Broad Street, Soho, London";
        attribute investigationPeriod : String = "August-September 1854";
        attribute primaryHypothesis : String = "Cholera transmission via contaminated water";
        attribute keyFinding : String = "Broad Street pump identified as outbreak source";
        attribute interventionTaken : String = "Removal of Broad Street pump handle";
        attribute historicalSignificance : String = "Established foundation of modern epidemiology";
        
        satisfy identifyDiseaseSource;
        satisfy enableEvidenceBasedIntervention;
        satisfy maintainInvestigationIntegrity;
        satisfy supportScientificMethod;
        
        perform state machine lifecycle : InvestigationLifecycle;
    }
}
