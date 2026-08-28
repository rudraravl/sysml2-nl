package CholeraInvestigation {
	private import ScalarValues::*;
	private import SI::m;

	unit def cases;
	unit def fatalities;
	unit def percent;
	unit def deg;
	unit def dimensionless;

	value type def Cases :> Real {
		doc /* Count of cholera cases. */
		unit : cases;
	}
	value type def Fatalities :> Real {
		unit : fatalities;
	}
	value type def FatalityRate :> Real {
		unit : percent;
	}
	value type def Latitude :> Real {
		unit : deg;
	}
	value type def Longitude :> Real {
		unit : deg;
	}
	value type def Distance :> Real {
		doc /* Distance in meters. */
		unit : m;
	}
	value type def CorrelationStrength :> Real {
		unit : dimensionless;
	}

	item def PatientRecord {
		attribute caseId : String;
		attribute residence : String;
		attribute symptoms : String;
		attribute onsetDate : String;
		attribute primaryWaterSource : String;
		attribute latitude : Latitude;
		attribute longitude : Longitude;
		attribute fatal : Boolean;
	}
	item def PumpRecord {
		attribute pumpName : String;
		attribute latitude : Latitude;
		attribute longitude : Longitude;
		attribute streetLocation : String;
	}
	item def CaseLocation {
		attribute caseId : String;
		attribute latitude : Latitude;
		attribute longitude : Longitude;
	}
	item def EpidemiologicalMap {
		attribute mapId : String;
		attribute caseLocations : CaseLocation[0..*];
		attribute pumpLocations : PumpRecord[0..*];
		attribute clusterRadius : Distance;
	}
	item def StatisticalResult {
		attribute totalCases : Cases;
		attribute totalFatalities : Fatalities;
		attribute fatalityRate : FatalityRate;
		attribute clusterCenterLat : Latitude;
		attribute clusterCenterLon : Longitude;
		attribute likelySourcePump : String;
		attribute correlationStrength : CorrelationStrength;
		attribute meanDistanceToLikelySource : Distance;
	}
	item def Findings {
		attribute hypothesis : String;
		attribute evidenceSummary : String;
		attribute probableSource : String;
		attribute recommendation : String;
		attribute confidenceLevel : Real;
	}
	item def InterventionAction {
		attribute actionId : String;
		attribute description : String;
		attribute targetPump : String;
		attribute implemented : Boolean;
		attribute outcome : String;
	}

	calc def ClusterCenter {
		in caseLocations : CaseLocation[0..*];
		out centerLat : Latitude;
		out centerLon : Longitude;
	}
	calc def PumpCorrelation {
		in caseLocations : CaseLocation[0..*];
		in pumps : PumpRecord[0..*];
		out likelySourcePump : String;
		out correlationStrength : CorrelationStrength;
		out meanDistance : Distance;
	}
	calc def FatalityRateCalc {
		in cases : Cases;
		in fatalities : Fatalities;
		out rate : FatalityRate;
	}

	action def CollectHouseholdData {
		out patients : PatientRecord[0..*];
	}
	action def SurveyPumps {
		out pumps : PumpRecord[0..*];
	}
	action def AssembleFieldData {
		in patients : PatientRecord[0..*];
		in pumps : PumpRecord[0..*];
		out records : PatientRecord[0..*];
		out pumpRecs : PumpRecord[0..*];
	}
	action def PlotCases {
		in patients : PatientRecord[0..*];
		out caseLocations : CaseLocation[0..*];
	}
	action def PlotPumps {
		in pumps : PumpRecord[0..*];
		out pumpLocations : PumpRecord[0..*];
	}
	action def ComposeMap {
		in caseLocations : CaseLocation[0..*];
		in pumpLocations : PumpRecord[0..*];
		out mapOut : EpidemiologicalMap;
	}
	action def ComputeTotals {
		in patients : PatientRecord[0..*];
		out totalCases : Cases;
		out totalFatalities : Fatalities;
	}
	action def ComputeFatalityRate {
		in totalCases : Cases;
		in totalFatalities : Fatalities;
		out rate : FatalityRate;
	}
	action def IdentifyClusterCenter {
		in map : EpidemiologicalMap;
		out centerLat : Latitude;
		out centerLon : Longitude;
	}
	action def CorrelateWithPumps {
		in map : EpidemiologicalMap;
		out likelySourcePump : String;
		out correlationStrength : CorrelationStrength;
		out meanDistance : Distance;
	}
	action def AssembleResults {
		in totalCases : Cases;
		in totalFatalities : Fatalities;
		in rate : FatalityRate;
		in centerLat : Latitude;
		in centerLon : Longitude;
		in likelySourcePump : String;
		in correlationStrength : CorrelationStrength;
		in meanDistance : Distance;
		out resultOut : StatisticalResult;
	}
	action def AssessEvidence {
		in result : StatisticalResult;
		out evidenceSummary : String;
		out confidenceLevel : Real;
	}
	action def IdentifyProbableSource {
		in result : StatisticalResult;
		out probableSource : String;
	}
	action def FormulateRecommendation {
		in probableSource : String;
		out recommendation : String;
	}
	action def CompileFindings {
		in evidenceSummary : String;
		in confidenceLevel : Real;
		in probableSource : String;
		in recommendation : String;
		out findingsOut : Findings;
	}
	action def ReviewEvidence {
		in findings : Findings;
		out approved : Boolean;
	}
	action def ImplementAction {
		in findings : Findings;
		out actionOut : InterventionAction;
	}

	part def FieldInvestigationUnit {
		doc /* On-the-ground data collection team. */
		out port patientRecordsOut : PatientRecord[0..*];
		out port pumpRecordsOut : PumpRecord[0..*];
		attribute householdsVisited : Integer;
		attribute pumpsSurveyed : Integer;
		action collectHouseholdData : CollectHouseholdData;
		action surveyPumps : SurveyPumps;
		action assembleFieldData : AssembleFieldData;
	}
	part def CartographicMappingUnit {
		doc /* Creates the epidemiological spot map. */
		in port patientRecordsIn : PatientRecord[0..*];
		in port pumpRecordsIn : PumpRecord[0..*];
		out port mapOut : EpidemiologicalMap;
		action plotCases : PlotCases;
		action plotPumps : PlotPumps;
		action composeMap : ComposeMap;
	}
	part def StatisticalAnalysisUnit {
		doc /* Quantitative analysis of case data and map. */
		in port mapIn : EpidemiologicalMap;
		in port caseDataIn : PatientRecord[0..*];
		out port resultOut : StatisticalResult;
		action computeTotals : ComputeTotals;
		action computeFatalityRate : ComputeFatalityRate;
		action identifyClusterCenter : IdentifyClusterCenter;
		action correlateWithPumps : CorrelateWithPumps;
		action assembleResults : AssembleResults;
	}
	part def HypothesisEvaluationUnit {
		doc /* Tests the waterborne hypothesis and compiles findings. */
		in port resultIn : StatisticalResult;
		out port findingsOut : Findings;
		attribute hypothesis : String = "Cholera is a waterborne disease transmitted through contaminated public water supplies.";
		action assessEvidence : AssessEvidence;
		action identifyProbableSource : IdentifyProbableSource;
		action formulateRecommendation : FormulateRecommendation;
		action compileFindings : CompileFindings;
	}
	part def PublicHealthInterventionUnit {
		doc /* Reviews findings and implements the recommended action. */
		in port findingsIn : Findings;
		out port actionOut : InterventionAction;
		action reviewEvidence : ReviewEvidence;
		action implementAction : ImplementAction;
	}

	part def CholeraInvestigationSystem {
		doc /* John Snow's 1854 Broad Street cholera outbreak investigation methodology. */
		part fieldUnit : FieldInvestigationUnit;
		part mappingUnit : CartographicMappingUnit;
		part analysisUnit : StatisticalAnalysisUnit;
		part evaluationUnit : HypothesisEvaluationUnit;
		part interventionUnit : PublicHealthInterventionUnit;

		connect fieldUnit.patientRecordsOut to mappingUnit.patientRecordsIn;
		connect fieldUnit.pumpRecordsOut to mappingUnit.pumpRecordsIn;
		connect mappingUnit.mapOut to analysisUnit.mapIn;
		connect fieldUnit.patientRecordsOut to analysisUnit.caseDataIn;
		connect analysisUnit.resultOut to evaluationUnit.resultIn;
		connect evaluationUnit.findingsOut to interventionUnit.findingsIn;

		state investigationWorkflow {
			state DataCollection;
			state Mapping;
			state Analysis;
			state Evaluation;
			state Intervention;
			state Completed;
			transition t1 from DataCollection to Mapping;
			transition t2 from Mapping to Analysis;
			transition t3 from Analysis to Evaluation;
			transition t4 from Evaluation to Intervention;
			transition t5 from Intervention to Completed;
		}
	}

	requirement def IdentifyOutbreakSourceRequirement {
		doc /* The investigation shall identify the most probable source of the cholera outbreak. */
		subject investigation : CholeraInvestigationSystem;
		requirement shallIdentifySource {
			doc /* The system shall determine a likely source pump with correlation strength above 0.7. */
		}
	}
	requirement def FieldDataCollectionRequirement {
		doc /* Field data shall include patient residence, symptoms, onset date, and primary water source. */
	}
	requirement def MappingRequirement {
		doc /* The system shall produce a spot map plotting all cholera cases and water pumps. */
	}
	requirement def StatisticalAnalysisRequirement {
		doc /* The system shall compute total cases, fatality rate, cluster center, and pump correlation. */
	}
	requirement def InterventionRequirement {
		doc /* The system shall recommend and document an intervention action targeting the probable source. */
	}

	requirement def CholeraInvestigationRequirements {
		requirement identifyOutbreakSource : IdentifyOutbreakSourceRequirement;
		requirement fieldDataCollection : FieldDataCollectionRequirement;
		requirement mapping : MappingRequirement;
		requirement statisticalAnalysis : StatisticalAnalysisRequirement;
		requirement intervention : InterventionRequirement;
	}

	requirement investigationRequirements : CholeraInvestigationRequirements;

	part broadStreetInvestigation : CholeraInvestigationSystem {
		doc /* The 1854 Broad Street cholera outbreak investigation. */
		part :>> fieldUnit {
			attribute :>> householdsVisited = 400;
			attribute :>> pumpsSurveyed = 13;
		}
		part :>> evaluationUnit {
			attribute :>> hypothesis = "Cholera is transmitted through contaminated water from the Broad Street pump.";
		}
	}
}
