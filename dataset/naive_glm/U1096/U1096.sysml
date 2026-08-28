package SocietalImpactAnalysisSystem {
    import ScalarValues::*;

    package Units {
        value def Count :> Real;
        value def Hours :> Real;
        value def Percent :> Real;
        value def Fatalities :> Real;
        value def Accidents :> Real;
        value def VehiclesPerHour :> Real;
        value def TonsCO2 :> Real;
        value def USD :> Real;
        value def Jobs :> Real;
        value def Minutes :> Real;
        value def Index :> Real;
        value def KilowattHours :> Real;
        value def AdoptionRate :> Percent;
    }

    package Items {
        item def RawTelemetry {
            attribute vehicleCount : Count;
            attribute operationalHours : Hours;
            attribute energyConsumed : KilowattHours;
        }
        item def InfrastructureSignal {
            attribute intersectionId : String;
            attribute congestionLevel : Percent;
            attribute v2iMessages : Count;
        }
        item def TrafficData {
            attribute averageCommuteTime : Minutes;
            attribute throughput : VehiclesPerHour;
            attribute congestionIndex : Index;
        }
        item def SafetyData {
            attribute accidentCount : Accidents;
            attribute fatalityCount : Fatalities;
            attribute fatalityReduction : Percent;
        }
        item def EnvironmentalData {
            attribute emissions : TonsCO2;
            attribute emissionsReduction : Percent;
            attribute energyEfficiency : Index;
        }
        item def EconomicData {
            attribute jobsCreated : Jobs;
            attribute jobsDisplaced : Jobs;
            attribute netEconomicValue : USD;
        }
        item def AccessibilityData {
            attribute elderlyMobilityIndex : Index;
            attribute disabledAccessIndex : Index;
            attribute underservedCoverage : Percent;
        }
        item def AggregatedMetrics {
            attribute traffic : TrafficData;
            attribute safety : SafetyData;
            attribute environment : EnvironmentalData;
            attribute economy : EconomicData;
            attribute accessibility : AccessibilityData;
            attribute adoptionRate : AdoptionRate;
        }
        item def ImpactReport {
            attribute reportId : String;
            attribute generationTimestamp : String;
            attribute fatalityReductionPct : Percent;
            attribute commuteImprovementPct : Percent;
            attribute emissionsReductionPct : Percent;
            attribute netJobsImpact : Jobs;
            attribute accessibilityScore : Index;
            attribute overallAssessment : String;
        }
    }

    package Ports {
        port def TelemetryOut {
            out item : Items::RawTelemetry;
        }
        port def InfrastructureOut {
            out item : Items::InfrastructureSignal;
        }
        port def TrafficIn {
            in item : Items::RawTelemetry;
            in item : Items::InfrastructureSignal;
        }
        port def TrafficOut {
            out item : Items::TrafficData;
        }
        port def SafetyIn {
            in item : Items::RawTelemetry;
        }
        port def SafetyOut {
            out item : Items::SafetyData;
        }
        port def EnvironmentalIn {
            in item : Items::RawTelemetry;
        }
        port def EnvironmentalOut {
            out item : Items::EnvironmentalData;
        }
        port def EconomicIn {
            in item : Items::RawTelemetry;
        }
        port def EconomicOut {
            out item : Items::EconomicData;
        }
        port def MetricsIn {
            in item : Items::TrafficData;
            in item : Items::SafetyData;
            in item : Items::EnvironmentalData;
            in item : Items::EconomicData;
        }
        port def ReportOut {
            out item : Items::ImpactReport;
        }
    }

    part def AutonomousVehicleFleet {
        attribute fleetSize : Count;
        attribute dailyOperationalHours : Hours;
        port telemetryPort : Ports::TelemetryOut;
        exhibit state FleetOperation {
            entry; then Operating;
            state Operating;
            transition Operating to Operating;
        }
        action emitTelemetry {
            out telemetry : Items::RawTelemetry;
        }
    }

    part def TransportationInfrastructure {
        attribute smartIntersections : Count;
        port infrastructurePort : Ports::InfrastructureOut;
        action emitSignals {
            out signal : Items::InfrastructureSignal;
        }
    }

    part def TrafficManagementSystem {
        port trafficIn : Ports::TrafficIn;
        port trafficOut : Ports::TrafficOut;
        action optimizeFlow {
            in raw : Items::RawTelemetry;
            in infra : Items::InfrastructureSignal;
            out result : Items::TrafficData;
        }
    }

    part def SafetyMonitoringSystem {
        port safetyIn : Ports::SafetyIn;
        port safetyOut : Ports::SafetyOut;
        action analyzeSafety {
            in raw : Items::RawTelemetry;
            out result : Items::SafetyData;
        }
    }

    part def EnvironmentalMonitoringSystem {
        port envIn : Ports::EnvironmentalIn;
        port envOut : Ports::EnvironmentalOut;
        action analyzeEnvironment {
            in raw : Items::RawTelemetry;
            out result : Items::EnvironmentalData;
        }
    }

    part def EconomicMonitoringSystem {
        port econIn : Ports::EconomicIn;
        port econOut : Ports::EconomicOut;
        action analyzeEconomy {
            in raw : Items::RawTelemetry;
            out result : Items::EconomicData;
        }
    }

    part def ImpactAnalysisEngine {
        port metricsIn : Ports::MetricsIn;
        port reportOut : Ports::ReportOut;
        attribute currentAdoptionRate : AdoptionRate;

        exhibit state AssessmentLifecycle {
            entry; then InitialDeployment;
            state InitialDeployment;
            state GrowingAdoption;
            state MarketSaturation;
            transition InitialDeployment to GrowingAdoption
                when currentAdoptionRate > 0.25;
            transition GrowingAdoption to MarketSaturation
                when currentAdoptionRate > 0.75;
            transition MarketSaturation to MarketSaturation;
        }

        action aggregateMetrics {
            in traffic : Items::TrafficData;
            in safety : Items::SafetyData;
            in environment : Items::EnvironmentalData;
            in economy : Items::EconomicData;
            out metrics : Items::AggregatedMetrics;
        }

        action generateReport {
            in metrics : Items::AggregatedMetrics;
            out report : Items::ImpactReport;
        }
    }

    part def ReportingSubsystem {
        port reportIn : Ports::ReportOut;
        attribute publishedReports : Count;
        action publishReport {
            in report : Items::ImpactReport;
        }
    }

    part def SocietalImpactAnalysisPlatform {
        part fleet : AutonomousVehicleFleet {
            attribute fleetSize = 5000;
            attribute dailyOperationalHours = 18.0;
        }
        part infrastructure : TransportationInfrastructure {
            attribute smartIntersections = 1200;
        }
        part trafficSystem : TrafficManagementSystem;
        part safetySystem : SafetyMonitoringSystem;
        part environmentalSystem : EnvironmentalMonitoringSystem;
        part economicSystem : EconomicMonitoringSystem;
        part analysisEngine : ImpactAnalysisEngine;
        part reporting : ReportingSubsystem;

        connection fleet.telemetryPort to trafficSystem.trafficIn;
        connection fleet.telemetryPort to safetySystem.safetyIn;
        connection fleet.telemetryPort to environmentalSystem.envIn;
        connection fleet.telemetryPort to economicSystem.econIn;
        connection infrastructure.infrastructurePort to trafficSystem.trafficIn;

        connection trafficSystem.trafficOut to analysisEngine.metricsIn;
        connection safetySystem.safetyOut to analysisEngine.metricsIn;
        connection environmentalSystem.envOut to analysisEngine.metricsIn;
        connection economicSystem.econOut to analysisEngine.metricsIn;

        connection analysisEngine.reportOut to reporting.reportIn;
    }

    package Requirements {
        requirement def SocietalImpactRequirement {
            attribute id : String;
            attribute text : String;
        }

        requirement ContinuousDataCollection :> SocietalImpactRequirement {
            attribute id = "REQ-001";
            attribute text = "The system shall continuously collect telemetry from the autonomous vehicle fleet and transportation infrastructure.";
        }

        requirement MultiDomainAnalysis :> SocietalImpactRequirement {
            attribute id = "REQ-002";
            attribute text = "The system shall analyze data across safety, traffic, environmental, economic, and accessibility domains.";
        }

        requirement StagedAssessment :> SocietalImpactRequirement {
            attribute id = "REQ-003";
            attribute text = "The system shall evaluate impact through distinct stages from initial deployment to market saturation.";
        }

        requirement QuantifiedReporting :> SocietalImpactRequirement {
            attribute id = "REQ-004";
            attribute text = "The system shall produce an impact report quantifying reductions in fatalities, commute improvements, and emissions decreases.";
        }

        requirement AccessibilityEvaluation :> SocietalImpactRequirement {
            attribute id = "REQ-005";
            attribute text = "The system shall measure accessibility improvements for elderly and disabled populations.";
        }
    }

    package Verification {
        verification VerifyDataCollection
            verify Requirements::ContinuousDataCollection {
            subject = SocietalImpactAnalysisPlatform::fleet;
            objective {
                verify that fleet.telemetryPort.out.item.vehicleCount > 0;
            }
        }

        verification VerifyMultiDomainAnalysis
            verify Requirements::MultiDomainAnalysis {
            subject = SocietalImpactAnalysisPlatform::analysisEngine;
            objective {
                verify that analysisEngine.metricsIn.in.item.size >= 4;
            }
        }

        verification VerifyStagedAssessment
            verify Requirements::StagedAssessment {
            subject = SocietalImpactAnalysisPlatform::analysisEngine;
            objective {
                verify that analysisEngine.AssessmentLifecycle.InitialDeployment.isActive
                    or analysisEngine.AssessmentLifecycle.GrowingAdoption.isActive
                    or analysisEngine.AssessmentLifecycle.MarketSaturation.isActive;
            }
        }

        verification VerifyQuantifiedReporting
            verify Requirements::QuantifiedReporting {
            subject = SocietalImpactAnalysisPlatform::reporting;
            objective {
                verify that reporting.publishedReports > 0;
            }
        }
    }
}
