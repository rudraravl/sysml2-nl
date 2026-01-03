package SelfDrivingCarImpactSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    private import RiskMetadata::*;
    private import RiskLevelEnum::*;
    private import ModelingMetadata::StatusKind;

    attribute def SafetyMetric {
        attribute accidentReductionRate : Real;
        attribute fatalityReductionRate : Real;
        attribute injuryReductionRate : Real;
    }

    attribute def TrafficEfficiencyMetric {
        attribute averageSpeed : SpeedValue;
        attribute congestionReductionRate : Real;
        attribute travelTimeReduction : DurationValue;
        attribute throughputIncrease : Real;
    }

    attribute def EnvironmentalMetric {
        attribute emissionsReduction : Real;
        attribute fuelEfficiencyImprovement : Real;
        attribute energyConsumptionRate : PowerValue;
    }

    attribute def EconomicMetric {
        attribute jobsDisplaced : Integer;
        attribute jobsCreated : Integer;
        attribute productivityGain : Real;
        attribute infrastructureCost : Real;
        attribute operationalSavings : Real;
    }

    attribute def AccessibilityMetric {
        attribute mobilityForDisabled : Real;
        attribute mobilityForElderly : Real;
        attribute serviceAreaCoverage : Real;
        attribute affordabilityIndex : Real;
    }

    item def TrafficData {
        attribute vehicleCount : Integer;
        attribute autonomousVehicleCount : Integer;
        attribute averageVelocity : SpeedValue;
        attribute congestionLevel : Real;
        attribute timestamp : DurationValue;
    }

    item def SafetyData {
        attribute accidentCount : Integer;
        attribute fatalityCount : Integer;
        attribute nearMissCount : Integer;
        attribute severityIndex : Real;
        attribute timestamp : DurationValue;
    }

    item def EnvironmentalData {
        attribute emissionLevel : Real;
        attribute fuelConsumption : Real;
        attribute energyUsage : PowerValue;
        attribute timestamp : DurationValue;
    }

    item def EconomicData {
        attribute employmentImpact : Integer;
        attribute costSavings : Real;
        attribute revenueGenerated : Real;
        attribute timestamp : DurationValue;
    }

    item def ImpactReport {
        attribute safetyImpact : SafetyMetric;
        attribute trafficImpact : TrafficEfficiencyMetric;
        attribute environmentalImpact : EnvironmentalMetric;
        attribute economicImpact : EconomicMetric;
        attribute accessibilityImpact : AccessibilityMetric;
        attribute overallScore : Real;
        attribute timestamp : DurationValue;
    }

    port def TrafficDataPort {
        in item trafficInput : TrafficData;
        out item trafficOutput : TrafficData;
    }

    port def SafetyDataPort {
        in item safetyInput : SafetyData;
        out item safetyOutput : SafetyData;
    }

    port def EnvironmentalDataPort {
        in item envInput : EnvironmentalData;
        out item envOutput : EnvironmentalData;
    }

    port def EconomicDataPort {
        in item economicInput : EconomicData;
        out item economicOutput : EconomicData;
    }

    port def ReportPort {
        out item report : ImpactReport;
    }

    part def AutonomousVehicleFleet {
        attribute fleetSize : Integer;
        attribute autonomyLevel : Integer;
        attribute deploymentRate : Real;
        attribute operationalHours : DurationValue;

        port trafficPort : TrafficDataPort;
        port safetyPort : SafetyDataPort;
        port envPort : EnvironmentalDataPort;

        perform action operateFleet : OperateAutonomousFleet;
    }

    part def TrafficManagementSystem {
        port trafficInputPort : TrafficDataPort;
        port trafficOutputPort : TrafficDataPort;

        perform action manageTraffic : ManageTrafficFlow;
    }

    part def SafetyMonitoringSystem {
        port safetyInputPort : SafetyDataPort;
        port safetyOutputPort : SafetyDataPort;

        perform action monitorSafety : MonitorSafetyMetrics;
    }

    part def EnvironmentalMonitoringSystem {
        port envInputPort : EnvironmentalDataPort;
        port envOutputPort : EnvironmentalDataPort;

        perform action monitorEnvironment : MonitorEnvironmentalImpact;
    }

    part def EconomicAnalysisSystem {
        port economicInputPort : EconomicDataPort;
        port economicOutputPort : EconomicDataPort;

        perform action analyzeEconomics : AnalyzeEconomicImpact;
    }

    part def ImpactAnalysisEngine {
        port trafficDataPort : TrafficDataPort;
        port safetyDataPort : SafetyDataPort;
        port envDataPort : EnvironmentalDataPort;
        port economicDataPort : EconomicDataPort;
        port reportOutputPort : ReportPort;

        perform action analyzeImpact : AnalyzeOverallImpact;
        exhibit state impactStates : ImpactAssessmentStates;
    }

    part def TransportationInfrastructure {
        attribute roadNetworkSize : LengthValue;
        attribute smartInfrastructureDeployment : Real;
        attribute v2iCapability : Boolean;

        port trafficPort : TrafficDataPort;
    }

    action def OperateAutonomousFleet {
        in fleetSize : Integer;
        in autonomyLevel : Integer;
        out trafficData : TrafficData;
        out safetyData : SafetyData;
        out environmentalData : EnvironmentalData;
    }

    action def ManageTrafficFlow {
        in currentTraffic : TrafficData;
        in autonomousVehicleData : TrafficData;
        out optimizedTraffic : TrafficData;
        out efficiencyMetric : TrafficEfficiencyMetric;
    }

    action def MonitorSafetyMetrics {
        in safetyData : SafetyData;
        out safetyMetric : SafetyMetric;
    }

    action def MonitorEnvironmentalImpact {
        in environmentalData : EnvironmentalData;
        out environmentalMetric : EnvironmentalMetric;
    }

    action def AnalyzeEconomicImpact {
        in economicData : EconomicData;
        out economicMetric : EconomicMetric;
    }

    action def CalculateAccessibilityImpact {
        in fleetSize : Integer;
        in serviceArea : Real;
        out accessibilityMetric : AccessibilityMetric;
    }

    action def AnalyzeOverallImpact {
        in trafficData : TrafficData;
        in safetyData : SafetyData;
        in environmentalData : EnvironmentalData;
        in economicData : EconomicData;
        out impactReport : ImpactReport;

        first start;
        then action assessSafety : MonitorSafetyMetrics {
            in safetyData = AnalyzeOverallImpact::safetyData;
            out safetyMetric;
        }
        then action assessEnvironment : MonitorEnvironmentalImpact {
            in environmentalData = AnalyzeOverallImpact::environmentalData;
            out environmentalMetric;
        }
        then action assessEconomics : AnalyzeEconomicImpact {
            in economicData = AnalyzeOverallImpact::economicData;
            out economicMetric;
        }
        then action calculateTrafficEfficiency {
            in trafficData = AnalyzeOverallImpact::trafficData;
            out trafficMetric : TrafficEfficiencyMetric;
        }
        then action calculateAccessibility : CalculateAccessibilityImpact {
            in fleetSize = 10000;
            in serviceArea = 0.85;
            out accessibilityMetric;
        }
        then action generateReport {
            in safety = assessSafety.safetyMetric;
            in environment = assessEnvironment.environmentalMetric;
            in economic = assessEconomics.economicMetric;
            in traffic = calculateTrafficEfficiency.trafficMetric;
            in accessibility = calculateAccessibility.accessibilityMetric;
            out report : ImpactReport;
        }
        then assign impactReport := generateReport.report;
        then done;
    }

    state def ImpactAssessmentStates {
        attribute penetrationRate : Real;
        attribute deploymentPhase : String;

        entry; then initialDeployment;

        state initialDeployment {
            entry assign ImpactAssessmentStates::deploymentPhase := "Initial";
            entry assign ImpactAssessmentStates::penetrationRate := 0.05;
        }

        state growthPhase {
            entry assign ImpactAssessmentStates::deploymentPhase := "Growth";
            entry assign ImpactAssessmentStates::penetrationRate := 0.30;
        }

        state maturityPhase {
            entry assign ImpactAssessmentStates::deploymentPhase := "Maturity";
            entry assign ImpactAssessmentStates::penetrationRate := 0.70;
        }

        state saturationPhase {
            entry assign ImpactAssessmentStates::deploymentPhase := "Saturation";
            entry assign ImpactAssessmentStates::penetrationRate := 0.95;
        }

        transition initialToGrowth
            first initialDeployment
            if ImpactAssessmentStates::penetrationRate > 0.10
            then growthPhase;

        transition growthToMaturity
            first growthPhase
            if ImpactAssessmentStates::penetrationRate > 0.50
            then maturityPhase;

        transition maturityToSaturation
            first maturityPhase
            if ImpactAssessmentStates::penetrationRate > 0.90
            then saturationPhase;
    }

    connection def TrafficDataConnection {
        end source : TrafficDataPort;
        end target : TrafficDataPort;
    }

    connection def SafetyDataConnection {
        end source : SafetyDataPort;
        end target : SafetyDataPort;
    }

    connection def EnvironmentalDataConnection {
        end source : EnvironmentalDataPort;
        end target : EnvironmentalDataPort;
    }

    connection def EconomicDataConnection {
        end source : EconomicDataPort;
        end target : EconomicDataPort;
    }

    part impactSystem : SelfDrivingCarImpactSystem {
        part avFleet : AutonomousVehicleFleet {
            attribute :>> fleetSize = 10000;
            attribute :>> autonomyLevel = 5;
            attribute :>> deploymentRate = 0.15;
        }

        part trafficMgmt : TrafficManagementSystem;
        part safetyMonitor : SafetyMonitoringSystem;
        part envMonitor : EnvironmentalMonitoringSystem;
        part economicAnalyzer : EconomicAnalysisSystem;
        part impactEngine : ImpactAnalysisEngine;
        part infrastructure : TransportationInfrastructure {
            attribute :>> roadNetworkSize = 50000.0 [m];
            attribute :>> smartInfrastructureDeployment = 0.60;
            attribute :>> v2iCapability = true;
        }

        connection avToTraffic : TrafficDataConnection
            connect avFleet.trafficPort to trafficMgmt.trafficInputPort;

        connection avToSafety : SafetyDataConnection
            connect avFleet.safetyPort to safetyMonitor.safetyInputPort;

        connection avToEnv : EnvironmentalDataConnection
            connect avFleet.envPort to envMonitor.envInputPort;

        connection trafficToAnalysis : TrafficDataConnection
            connect trafficMgmt.trafficOutputPort to impactEngine.trafficDataPort;

        connection safetyToAnalysis : SafetyDataConnection
            connect safetyMonitor.safetyOutputPort to impactEngine.safetyDataPort;

        connection envToAnalysis : EnvironmentalDataConnection
            connect envMonitor.envOutputPort to impactEngine.envDataPort;

        connection economicToAnalysis : EconomicDataConnection
            connect economicAnalyzer.economicOutputPort to impactEngine.economicDataPort;

        connection infraToTraffic : TrafficDataConnection
            connect infrastructure.trafficPort to trafficMgmt.trafficInputPort;

        perform action assessSystemImpact : AnalyzeOverallImpact;
    }

    requirement def SafetyImpactRequirement {
        doc /* The deployment of autonomous vehicles shall reduce traffic fatalities by at least 90% compared to human-driven vehicles. */

        require constraint {
            safetyMetric.fatalityReductionRate >= 0.90
        }

        attribute safetyMetric : SafetyMetric;
    }

    requirement def TrafficEfficiencyRequirement {
        doc /* The system shall improve overall traffic flow efficiency by reducing congestion by at least 40%. */

        require constraint {
            trafficMetric.congestionReductionRate >= 0.40
        }

        attribute trafficMetric : TrafficEfficiencyMetric;
    }

    requirement def EnvironmentalImpactRequirement {
        doc /* The autonomous vehicle fleet shall reduce transportation-related emissions by at least 30%. */

        require constraint {
            environmentalMetric.emissionsReduction >= 0.30
        }

        attribute environmentalMetric : EnvironmentalMetric;
    }

    requirement def AccessibilityRequirement {
        doc /* The system shall provide mobility access to at least 95% of elderly and disabled populations in service areas. */

        require constraint {
            accessibilityMetric.mobilityForDisabled >= 0.95 and
            accessibilityMetric.mobilityForElderly >= 0.95
        }

        attribute accessibilityMetric : AccessibilityMetric;
    }

    requirement def EconomicViabilityRequirement {
        doc /* The system shall demonstrate positive economic impact with operational savings exceeding infrastructure costs within 10 years. */

        require constraint {
            economicMetric.operationalSavings > economicMetric.infrastructureCost
        }

        attribute economicMetric : EconomicMetric;
    }

    requirement <'SDC-001'> systemMissionRequirement {
        doc /* The self-driving car impact system shall continuously assess and quantify the societal, economic, environmental, and safety impacts of autonomous vehicle deployment to inform policy decisions and optimize deployment strategies. */

        @StatusInfo {
            status = StatusKind::required;
            risk {
                totalRisk = high;
                technicalRisk = high;
                scheduleRisk = medium;
                costRisk = high;
            }
            originator = "Transportation Authority";
            owner = "System Integration Team";
        }

        subject impactSystem;

        require safetyReq : SafetyImpactRequirement;
        require trafficReq : TrafficEfficiencyRequirement;
        require envReq : EnvironmentalImpactRequirement;
        require accessReq : AccessibilityRequirement;
        require economicReq : EconomicViabilityRequirement;
    }

    requirement <'SDC-002'> dataCollectionRequirement {
        doc /* The system shall collect real-time traffic, safety, environmental, and economic data from the autonomous vehicle fleet with 99.9% availability. */

        @StatusInfo {
            status = StatusKind::required;
            risk {
                totalRisk = medium;
                technicalRisk = high;
                scheduleRisk = low;
                costRisk = medium;
            }
            owner = "Data Engineering Team";
        }

        require constraint {
            dataAvailability >= 0.999
        }

        attribute dataAvailability : Real;
    }

    requirement <'SDC-003'> reportingRequirement {
        doc /* The system shall generate comprehensive impact reports at regular intervals not exceeding 24 hours with complete analysis of all impact dimensions. */

        @StatusInfo {
            status = StatusKind::required;
            risk {
                totalRisk = low;
                technicalRisk = medium;
                scheduleRisk = low;
                costRisk = low;
            }
            owner = "Analytics Team";
        }

        require constraint {
            reportingInterval <= 24.0
        }

        attribute reportingInterval : Real;
    }
}
