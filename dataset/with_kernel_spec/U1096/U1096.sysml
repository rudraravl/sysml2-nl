package AutonomousVehicleSocietalImpactSystem {
	private import ISQ::*;
	private import SI::*;
	private import ScalarValues::*;

	value def Percentage :> Real;
	value def AccidentRateValue :> Real;
	value def FatalityRateValue :> Real;
	value def CommuteTimeValue :> TimeValue;
	value def EmissionValue :> MassValue;
	value def JobCountValue :> Integer;
	value def TrafficFlowValue :> Real;
	value def EnergyConsumptionValue :> EnergyValue;
	value def AccessibilityScoreValue :> Real;
	value def AdoptionRateValue :> Real;
	value def CongestionIndexValue :> Real;

	item def FleetData {
		attribute numberOfVehicles : Integer;
		attribute operationalHours : TimeValue;
		attribute milesTraveled : LengthValue;
		attribute accidentsCount : Integer;
		attribute energyConsumption : EnergyConsumptionValue;
	}

	item def InfrastructureData {
		attribute trafficFlow : TrafficFlowValue;
		attribute smartInfrastructureActive : Boolean;
	}

	item def SafetyMetrics {
		attribute accidentRate : AccidentRateValue;
		attribute fatalityRate : FatalityRateValue;
	}

	item def TrafficMetrics {
		attribute averageSpeed : SpeedValue;
		attribute congestionIndex : CongestionIndexValue;
		attribute averageCommuteTime : CommuteTimeValue;
	}

	item def EnvironmentalMetrics {
		attribute co2Emissions : EmissionValue;
		attribute noxEmissions : EmissionValue;
	}

	item def EconomicMetrics {
		attribute jobsCreated : JobCountValue;
		attribute jobsDisplaced : JobCountValue;
		attribute netJobImpact : JobCountValue;
		attribute costBenefitRatio : Real;
	}

	item def AccessibilityMetrics {
		attribute serviceCoverage : Percentage;
		attribute mobilityIndex : Real;
		attribute accessibilityScore : AccessibilityScoreValue;
	}

	item def ImpactReportData {
		attribute safetyScore : Real;
		attribute trafficScore : Real;
		attribute environmentalScore : Real;
		attribute economicScore : Real;
		attribute accessibilityScore : AccessibilityScoreValue;
		attribute overallImpactScore : Real;
		attribute fatalityReduction : Percentage;
		attribute commuteImprovement : Percentage;
		attribute emissionDecrease : Percentage;
		attribute netJobImpact : JobCountValue;
	}

	calc def AccidentRateCalculation {
		in accidents : Integer;
		in miles : LengthValue;
		return rate : AccidentRateValue = accidents / (miles / 1000000.0);
	}

	calc def FatalityRateCalculation {
		in fatalities : Integer;
		in miles : LengthValue;
		return rate : FatalityRateValue = fatalities / (miles / 1000000.0);
	}

	calc def EmissionCalculation {
		in energy : EnergyConsumptionValue;
		return co2 : EmissionValue = energy * 0.5;
	}

	calc def TrafficOptimizationCalc {
		in flow : TrafficFlowValue;
		in smartActive : Boolean;
		return avgCommute : CommuteTimeValue;
		return congestionIdx : CongestionIndexValue;
	}

	calc def EconomicImpactCalc {
		in vehicles : Integer;
		return jobsCreated : JobCountValue;
		return jobsDisplaced : JobCountValue;
		return netJobImpact : JobCountValue = jobsCreated - jobsDisplaced;
	}

	calc def OverallImpactCalc {
		in safety : SafetyMetrics;
		in traffic : TrafficMetrics;
		in env : EnvironmentalMetrics;
		in econ : EconomicMetrics;
		in access : AccessibilityMetrics;
		return report : ImpactReportData;
	}

	state def AssessmentStages {
		state initialDeployment;
		state growthPhase;
		state marketSaturation;
		transition initialToGrowth from initialDeployment to growthPhase;
		transition growthToSaturation from growthPhase to marketSaturation;
	}

	part def AutonomousVehicleFleet {
		attribute numberOfVehicles : Integer;
		attribute totalOperationalHours : TimeValue;
		attribute totalMilesTraveled : LengthValue;
		attribute accidentsCount : Integer;
		attribute energyConsumption : EnergyConsumptionValue;
		out port fleetDataOut : FleetData;
		bind fleetDataOut.numberOfVehicles = numberOfVehicles;
		bind fleetDataOut.operationalHours = totalOperationalHours;
		bind fleetDataOut.milesTraveled = totalMilesTraveled;
		bind fleetDataOut.accidentsCount = accidentsCount;
		bind fleetDataOut.energyConsumption = energyConsumption;
	}

	part def TransportationInfrastructure {
		attribute trafficFlow : TrafficFlowValue;
		attribute smartInfrastructureActive : Boolean;
		out port infraDataOut : InfrastructureData;
		bind infraDataOut.trafficFlow = trafficFlow;
		bind infraDataOut.smartInfrastructureActive = smartInfrastructureActive;
	}

	part def TrafficManagementSystem {
		in port infraDataIn : InfrastructureData;
		out port trafficMetricsOut : TrafficMetrics;
		calc optimizeFlow : TrafficOptimizationCalc {
			in flow = infraDataIn.trafficFlow;
			in smartActive = infraDataIn.smartInfrastructureActive;
			return avgCommute;
			return congestionIdx;
		}
		bind trafficMetricsOut.averageCommuteTime = optimizeFlow.avgCommute;
		bind trafficMetricsOut.congestionIndex = optimizeFlow.congestionIdx;
	}

	part def SafetyMonitoringSystem {
		in port fleetDataIn : FleetData;
		out port safetyMetricsOut : SafetyMetrics;
		calc accidentRateCalc : AccidentRateCalculation {
			in accidents = fleetDataIn.accidentsCount;
			in miles = fleetDataIn.milesTraveled;
			return rate;
		}
		calc fatalityRateCalc : FatalityRateCalculation {
			in fatalities = fleetDataIn.accidentsCount;
			in miles = fleetDataIn.milesTraveled;
			return rate;
		}
		bind safetyMetricsOut.accidentRate = accidentRateCalc.rate;
		bind safetyMetricsOut.fatalityRate = fatalityRateCalc.rate;
	}

	part def EnvironmentalMonitoringSystem {
		in port fleetDataIn : FleetData;
		out port envMetricsOut : EnvironmentalMetrics;
		calc emissionCalc : EmissionCalculation {
			in energy = fleetDataIn.energyConsumption;
			return co2;
		}
		bind envMetricsOut.co2Emissions = emissionCalc.co2;
	}

	part def EconomicMonitoringSystem {
		in port fleetDataIn : FleetData;
		out port econMetricsOut : EconomicMetrics;
		calc econCalc : EconomicImpactCalc {
			in vehicles = fleetDataIn.numberOfVehicles;
			return jobsCreated;
			return jobsDisplaced;
			return netJobImpact;
		}
		bind econMetricsOut.jobsCreated = econCalc.jobsCreated;
		bind econMetricsOut.jobsDisplaced = econCalc.jobsDisplaced;
		bind econMetricsOut.netJobImpact = econCalc.netJobImpact;
	}

	part def AccessibilityMonitoringSystem {
		in port fleetDataIn : FleetData;
		out port accessMetricsOut : AccessibilityMetrics;
		attribute serviceCoverage : Percentage = 95.0;
		attribute mobilityIndex : Real = 0.92;
		bind accessMetricsOut.serviceCoverage = serviceCoverage;
		bind accessMetricsOut.mobilityIndex = mobilityIndex;
		bind accessMetricsOut.accessibilityScore = serviceCoverage;
	}

	part def ImpactAnalysisEngine {
		in port safetyIn : SafetyMetrics;
		in port trafficIn : TrafficMetrics;
		in port envIn : EnvironmentalMetrics;
		in port econIn : EconomicMetrics;
		in port accessIn : AccessibilityMetrics;
		out port reportOut : ImpactReportData;

		attribute adoptionRate : AdoptionRateValue;

		state machine assessmentStages : AssessmentStages;

		calc overallCalc : OverallImpactCalc {
			in safety = safetyIn;
			in traffic = trafficIn;
			in env = envIn;
			in econ = econIn;
			in access = accessIn;
			return report;
		}
		bind reportOut = overallCalc.report;
	}

	part def ImpactReport {
		in port reportDataIn : ImpactReportData;
		attribute fatalityReduction : Percentage;
		attribute commuteImprovement : Percentage;
		attribute emissionDecrease : Percentage;
		attribute netJobImpact : JobCountValue;
		attribute overallScore : Real;
		bind fatalityReduction = reportDataIn.fatalityReduction;
		bind commuteImprovement = reportDataIn.commuteImprovement;
		bind emissionDecrease = reportDataIn.emissionDecrease;
		bind netJobImpact = reportDataIn.netJobImpact;
		bind overallScore = reportDataIn.overallImpactScore;
	}

	requirement def SocietalImpactRequirements {
		attribute targetFatalityReduction : Percentage = 50.0;
		attribute targetCommuteImprovement : Percentage = 20.0;
		attribute targetEmissionDecrease : Percentage = 30.0;
		attribute targetAccessibilityScore : AccessibilityScoreValue = 80.0;

		requirement safetyImprovementReq {
			doc /* The system shall demonstrate at least a 50% reduction in traffic fatality rate compared to baseline. */
		}
		requirement trafficEfficiencyReq {
			doc /* The system shall improve average commute time by at least 20%. */
		}
		requirement emissionReductionReq {
			doc /* The system shall reduce CO2 emissions by at least 30% per vehicle mile. */
		}
		requirement accessibilityReq {
			doc /* The system shall achieve an accessibility score of at least 80% for elderly and disabled populations. */
		}
	}

	part def SocietalImpactAnalysisSystem {
		part fleet : AutonomousVehicleFleet;
		part infrastructure : TransportationInfrastructure;
		part trafficMgmt : TrafficManagementSystem;
		part safetyMon : SafetyMonitoringSystem;
		part envMon : EnvironmentalMonitoringSystem;
		part econMon : EconomicMonitoringSystem;
		part accessMon : AccessibilityMonitoringSystem;
		part analysisEngine : ImpactAnalysisEngine;
		part report : ImpactReport;

		connect fleet.fleetDataOut to safetyMon.fleetDataIn;
		connect fleet.fleetDataOut to envMon.fleetDataIn;
		connect fleet.fleetDataOut to econMon.fleetDataIn;
		connect fleet.fleetDataOut to accessMon.fleetDataIn;
		connect infrastructure.infraDataOut to trafficMgmt.infraDataIn;
		connect trafficMgmt.trafficMetricsOut to analysisEngine.trafficIn;
		connect safetyMon.safetyMetricsOut to analysisEngine.safetyIn;
		connect envMon.envMetricsOut to analysisEngine.envIn;
		connect econMon.econMetricsOut to analysisEngine.econIn;
		connect accessMon.accessMetricsOut to analysisEngine.accessIn;
		connect analysisEngine.reportOut to report.reportDataIn;

		requirement societalImpactReqs : SocietalImpactRequirements;

		satisfy societalImpactReqs::safetyImprovementReq by safetyMon;
		satisfy societalImpactReqs::trafficEfficiencyReq by trafficMgmt;
		satisfy societalImpactReqs::emissionReductionReq by envMon;
		satisfy societalImpactReqs::accessibilityReq by accessMon;
	}
}
