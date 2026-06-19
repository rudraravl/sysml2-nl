package ExploratoryEngineeringSystemModel {
    private import ScalarValues::*;
    private import SI::*;
    private import ISQ::*;

    attribute def ConfidenceRatio :> ScalarValues::Real;
    attribute def DataCapacityGB :> ScalarValues::Real;
    attribute def DataRateMbps :> ScalarValues::Real;
    attribute def AngularCoverageDeg :> ScalarValues::Real;
    attribute def SampleVolumeML :> ScalarValues::Real;

    enum def MissionMode {
        enum poweredOff;
        enum ready;
        enum surveying;
        enum experimenting;
        enum synthesizing;
        enum transmitting;
        enum safeMode;
        enum complete;
    }

    item def ExplorationObjective {
        attribute objectiveId : ScalarValues::String;
        attribute missionAreaName : ScalarValues::String;
        attribute desiredEvidenceConfidence : ConfidenceRatio = 0.85;
        attribute maximumMissionDuration :> ISQ::time = 28800 [SI::s];
    }

    item def DigitalCommand {
        attribute commandId : ScalarValues::String;
        attribute priority : ScalarValues::Integer;
        attribute issuedTime :> ISQ::time;
    }

    item def ElectricalPower {
        attribute voltage :> ISQ::electricPotential = 48 [SI::V];
        attribute current :> ISQ::electricCurrent;
        attribute power :> ISQ::power;
    }

    item def SensorObservation {
        attribute observationId : ScalarValues::String;
        attribute confidence : ConfidenceRatio;
        attribute range :> ISQ::length;
        attribute captureTime :> ISQ::time;
        attribute ambientTemperature :> ISQ::thermodynamicTemperature;
    }

    item def EnvironmentalSample {
        attribute sampleId : ScalarValues::String;
        attribute volume : SampleVolumeML;
        attribute collectionRange :> ISQ::length;
        attribute collectionTime :> ISQ::time;
    }

    item def ExperimentPlan {
        attribute planId : ScalarValues::String;
        attribute targetPhenomenon : ScalarValues::String;
        attribute plannedDuration :> ISQ::time;
        attribute allowedEnergy :> ISQ::energy;
        attribute expectedConfidenceGain : ConfidenceRatio;
    }

    item def ExperimentResult {
        attribute resultId : ScalarValues::String;
        attribute measuredConfidence : ConfidenceRatio;
        attribute consumedEnergy :> ISQ::energy;
        attribute elapsedTime :> ISQ::time;
        attribute resultSummary : ScalarValues::String;
    }

    item def EngineeringInsight {
        attribute insightId : ScalarValues::String;
        attribute opportunityDescription : ScalarValues::String;
        attribute technicalRiskDescription : ScalarValues::String;
        attribute confidence : ConfidenceRatio;
        attribute evidenceCount : ScalarValues::Integer;
    }

    item def EngineeringRecommendation {
        attribute recommendationId : ScalarValues::String;
        attribute primaryOption : ScalarValues::String;
        attribute rationale : ScalarValues::String;
        attribute confidence : ConfidenceRatio;
        attribute residualRisk : ConfidenceRatio;
    }

    item def TelemetryPacket {
        attribute packetId : ScalarValues::String;
        attribute mode : MissionMode;
        attribute healthScore : ConfidenceRatio;
        attribute availableEnergy :> ISQ::energy;
        attribute timestamp :> ISQ::time;
    }

    item def HazardAlert {
        attribute alertId : ScalarValues::String;
        attribute severity : ConfidenceRatio;
        attribute hazardDescription : ScalarValues::String;
        attribute detectionRange :> ISQ::length;
    }

    port def PowerInputPort {
        in item power : ElectricalPower;
    }

    port def PowerOutputPort {
        out item power : ElectricalPower;
    }

    port def CommandInputPort {
        in item command : DigitalCommand;
    }

    port def CommandOutputPort {
        out item command : DigitalCommand;
    }

    port def ObservationInputPort {
        in item observation : SensorObservation;
    }

    port def ObservationOutputPort {
        out item observation : SensorObservation;
    }

    port def SampleInputPort {
        in item sample : EnvironmentalSample;
    }

    port def SampleOutputPort {
        out item sample : EnvironmentalSample;
    }

    port def ExperimentPlanInputPort {
        in item plan : ExperimentPlan;
    }

    port def ExperimentPlanOutputPort {
        out item plan : ExperimentPlan;
    }

    port def ExperimentResultInputPort {
        in item result : ExperimentResult;
    }

    port def ExperimentResultOutputPort {
        out item result : ExperimentResult;
    }

    port def InsightInputPort {
        in item insight : EngineeringInsight;
    }

    port def InsightOutputPort {
        out item insight : EngineeringInsight;
    }

    port def RecommendationOutputPort {
        out item recommendation : EngineeringRecommendation;
    }

    port def TelemetryInputPort {
        in item telemetry : TelemetryPacket;
    }

    port def TelemetryOutputPort {
        out item telemetry : TelemetryPacket;
    }

    port def HazardInputPort {
        in item hazard : HazardAlert;
    }

    port def HazardOutputPort {
        out item hazard : HazardAlert;
    }

    action def FormulateExplorationPlan {
        in item objective : ExplorationObjective;
        out item plan : ExperimentPlan;
    }

    action def SurveyEnvironment {
        in item objective : ExplorationObjective;
        out item observation : SensorObservation;
        out item sample : EnvironmentalSample;
    }

    action def AnalyzeObservations {
        in item observation : SensorObservation;
        in item sample : EnvironmentalSample;
        out item insight : EngineeringInsight;
    }

    action def SelectExperiment {
        in item insight : EngineeringInsight;
        out item plan : ExperimentPlan;
    }

    action def ExecuteRapidExperiment {
        in item plan : ExperimentPlan;
        in item sample : EnvironmentalSample;
        out item result : ExperimentResult;
    }

    action def SynthesizeRecommendation {
        in item insight : EngineeringInsight;
        in item result : ExperimentResult;
        out item recommendation : EngineeringRecommendation;
    }

    action def TransmitRecommendation {
        in item recommendation : EngineeringRecommendation;
        out item telemetry : TelemetryPacket;
    }

    action def ConductExploratoryEngineeringMission {
        in item objective : ExplorationObjective;
        out item recommendation : EngineeringRecommendation;

        action formulatePlan : FormulateExplorationPlan;
        action surveyContext : SurveyEnvironment;
        action analyzeEvidence : AnalyzeObservations;
        action selectExperiment : SelectExperiment;
        action executeExperiment : ExecuteRapidExperiment;
        action synthesizeDecision : SynthesizeRecommendation;
        action transmitDecision : TransmitRecommendation;

        succession s1 first formulatePlan then surveyContext;
        succession s2 first surveyContext then analyzeEvidence;
        succession s3 first analyzeEvidence then selectExperiment;
        succession s4 first selectExperiment then executeExperiment;
        succession s5 first executeExperiment then synthesizeDecision;
        succession s6 first synthesizeDecision then transmitDecision;
    }

    state def ExploratoryEngineeringLifecycle {
        state poweredOff;
        state ready;
        state surveying;
        state experimenting;
        state synthesizing;
        state transmitting;
        state safeMode;
        state complete;

        transition initialize first poweredOff then ready;
        transition beginSurvey first ready then surveying;
        transition startExperiment first surveying then experimenting;
        transition beginSynthesis first experimenting then synthesizing;
        transition beginTransmit first synthesizing then transmitting;
        transition finishMission first transmitting then complete;
        transition surveyHazard first surveying then safeMode;
        transition experimentHazard first experimenting then safeMode;
        transition recoverFromSafeMode first safeMode then ready;
    }

    part def BatteryModule {
        attribute storedEnergy :> ISQ::energy = 5400000 [SI::J];
        attribute nominalVoltage :> ISQ::electricPotential = 48 [SI::V];
        attribute maximumDischargePower :> ISQ::power = 1200 [SI::W];

        port powerOut : PowerOutputPort;
    }

    part def PowerSubsystem {
        attribute totalStoredEnergy :> ISQ::energy = 10800000 [SI::J];
        attribute regulatedVoltage :> ISQ::electricPotential = 48 [SI::V];
        attribute peakOutputPower :> ISQ::power = 1800 [SI::W];

        part batteryA : BatteryModule;
        part batteryB : BatteryModule;

        port controlPowerOut : PowerOutputPort;
        port mobilityPowerOut : PowerOutputPort;
        port payloadPowerOut : PowerOutputPort;
        port communicationPowerOut : PowerOutputPort;

        connection batteryABus connect batteryA.powerOut to controlPowerOut;
        connection batteryBBus connect batteryB.powerOut to payloadPowerOut;
    }

    part def WheelModule {
        attribute wheelDiameter :> ISQ::length = 0.28 [SI::m];
        attribute continuousTorque :> ISQ::torque = 18 [SI::N * SI::m];
        attribute maximumSpeed :> ISQ::speed = 1.2 [SI::m / SI::s];

        port powerIn : PowerInputPort;
        port commandIn : CommandInputPort;
    }

    part def MobilitySubsystem {
        attribute traversableSlope : AngularCoverageDeg = 25.0;
        attribute maximumRange :> ISQ::length = 1500 [SI::m];
        attribute cruiseSpeed :> ISQ::speed = 0.6 [SI::m / SI::s];

        part frontLeftWheel : WheelModule;
        part frontRightWheel : WheelModule;
        part centerLeftWheel : WheelModule;
        part centerRightWheel : WheelModule;
        part rearLeftWheel : WheelModule;
        part rearRightWheel : WheelModule;

        port powerIn : PowerInputPort;
        port commandIn : CommandInputPort;
        port hazardOut : HazardOutputPort;
    }

    part def LidarSensor {
        attribute range :> ISQ::length = 80 [SI::m];
        attribute angularCoverage : AngularCoverageDeg = 270.0;
        attribute measurementPower :> ISQ::power = 35 [SI::W];

        port powerIn : PowerInputPort;
        port observationOut : ObservationOutputPort;
    }

    part def MultispectralCamera {
        attribute groundSampleDistance :> ISQ::length = 0.02 [SI::m];
        attribute fieldOfView : AngularCoverageDeg = 90.0;
        attribute measurementPower :> ISQ::power = 22 [SI::W];

        port powerIn : PowerInputPort;
        port observationOut : ObservationOutputPort;
    }

    part def MicroSampler {
        attribute maximumSampleVolume : SampleVolumeML = 50.0;
        attribute reach :> ISQ::length = 0.75 [SI::m];
        attribute collectionPower :> ISQ::power = 65 [SI::W];

        port powerIn : PowerInputPort;
        port sampleOut : SampleOutputPort;
    }

    part def SensorSuite {
        attribute nominalSensorPower :> ISQ::power = 160 [SI::W];
        attribute observationConfidenceTarget : ConfidenceRatio = 0.80;

        part lidar : LidarSensor;
        part camera : MultispectralCamera;
        part sampler : MicroSampler;

        port powerIn : PowerInputPort;
        port observationOut : ObservationOutputPort;
        port sampleOut : SampleOutputPort;
        port hazardOut : HazardOutputPort;

        connection lidarObservation connect lidar.observationOut to observationOut;
        connection cameraObservation connect camera.observationOut to observationOut;
        connection samplerSample connect sampler.sampleOut to sampleOut;
    }

    part def RapidPrototypeTool {
        attribute buildEnvelopeLength :> ISQ::length = 0.25 [SI::m];
        attribute buildEnvelopeWidth :> ISQ::length = 0.25 [SI::m];
        attribute buildEnvelopeHeight :> ISQ::length = 0.20 [SI::m];
        attribute maximumToolPower :> ISQ::power = 420 [SI::W];

        port powerIn : PowerInputPort;
        port commandIn : ExperimentPlanInputPort;
        port resultOut : ExperimentResultOutputPort;
    }

    part def ExperimentInstrument {
        attribute measurementPower :> ISQ::power = 120 [SI::W];
        attribute measurementUncertainty : ConfidenceRatio = 0.05;

        port powerIn : PowerInputPort;
        port sampleIn : SampleInputPort;
        port resultOut : ExperimentResultOutputPort;
    }

    part def ExperimentBay {
        attribute maximumExperimentDuration :> ISQ::time = 7200 [SI::s];
        attribute maximumExperimentEnergy :> ISQ::energy = 1800000 [SI::J];

        part prototypeTool : RapidPrototypeTool;
        part instrument : ExperimentInstrument;

        port powerIn : PowerInputPort;
        port sampleIn : SampleInputPort;
        port planIn : ExperimentPlanInputPort;
        port resultOut : ExperimentResultOutputPort;

        perform action runExperiment : ExecuteRapidExperiment;

        connection toolResult connect prototypeTool.resultOut to resultOut;
        connection instrumentResult connect instrument.resultOut to resultOut;
    }

    part def AnalysisComputer {
        attribute computePower :> ISQ::power = 95 [SI::W];
        attribute storageCapacity : DataCapacityGB = 2048.0;
        attribute modelUpdateCycleTime :> ISQ::time = 30 [SI::s];

        port powerIn : PowerInputPort;
        port observationIn : ObservationInputPort;
        port sampleIn : SampleInputPort;
        port experimentResultIn : ExperimentResultInputPort;
        port insightOut : InsightOutputPort;
        port recommendationOut : RecommendationOutputPort;

        perform action analyzeObservations : AnalyzeObservations;
        perform action synthesizeRecommendation : SynthesizeRecommendation;
    }

    part def MissionController {
        attribute controlCycleTime :> ISQ::time = 0.1 [SI::s];
        attribute primaryFunctionAvailability : ConfidenceRatio = 0.97;
        attribute currentMode : MissionMode = MissionMode::ready;

        port powerIn : PowerInputPort;
        port externalCommandIn : CommandInputPort;
        port safetyOverrideIn : CommandInputPort;
        port driveCommandOut : CommandOutputPort;
        port experimentPlanOut : ExperimentPlanOutputPort;
        port insightIn : InsightInputPort;
        port recommendationIn : RecommendationOutputPort;
        port telemetryOut : TelemetryOutputPort;

        perform action missionBehavior : ConductExploratoryEngineeringMission;
        exhibit state lifecycle : ExploratoryEngineeringLifecycle;
    }

    part def SafetyManager {
        attribute hazardResponseTime :> ISQ::time = 1.0 [SI::s];
        attribute safeStopDistance :> ISQ::length = 1.5 [SI::m];

        port powerIn : PowerInputPort;
        port hazardIn : HazardInputPort;
        port overrideOut : CommandOutputPort;
        port telemetryOut : TelemetryOutputPort;
    }

    part def CommunicationSubsystem {
        attribute uplinkRate : DataRateMbps = 2.0;
        attribute downlinkRate : DataRateMbps = 12.0;
        attribute transmitPower :> ISQ::power = 75 [SI::W];

        port powerIn : PowerInputPort;
        port commandOut : CommandOutputPort;
        port telemetryIn : TelemetryInputPort;
        port recommendationIn : RecommendationOutputPort;
    }

    part def ExploratoryEngineeringSystem {
        attribute primaryFunctionDescription : ScalarValues::String =
            "Explore uncertain contexts, gather evidence, run rapid experiments, and produce high-confidence engineering recommendations.";
        attribute dryMass :> ISQ::mass = 38 [SI::kg];
        attribute operatingRadius :> ISQ::length = 1500 [SI::m];
        attribute maximumMissionDuration :> ISQ::time = 28800 [SI::s];
        attribute maximumExperimentCycleTime :> ISQ::time = 7200 [SI::s];
        attribute primaryFunctionAvailability : ConfidenceRatio = 0.97;
        attribute evidenceTraceabilityScore : ConfidenceRatio = 0.93;

        part power : PowerSubsystem;
        part mobility : MobilitySubsystem;
        part sensors : SensorSuite;
        part experimentBay : ExperimentBay;
        part analysisComputer : AnalysisComputer;
        part missionController : MissionController;
        part safetyManager : SafetyManager;
        part communications : CommunicationSubsystem;

        port externalCommandIn : CommandInputPort;
        port telemetryOut : TelemetryOutputPort;
        port recommendationOut : RecommendationOutputPort;

        perform action conductExploratoryEngineering : ConductExploratoryEngineeringMission;
        exhibit state operationalLifecycle : ExploratoryEngineeringLifecycle;

        connection controlPower connect power.controlPowerOut to missionController.powerIn;
        connection computePower connect power.payloadPowerOut to analysisComputer.powerIn;
        connection sensorPower connect power.payloadPowerOut to sensors.powerIn;
        connection experimentPower connect power.payloadPowerOut to experimentBay.powerIn;
        connection mobilityPower connect power.mobilityPowerOut to mobility.powerIn;
        connection safetyPower connect power.controlPowerOut to safetyManager.powerIn;
        connection communicationPower connect power.communicationPowerOut to communications.powerIn;

        connection externalCommandRoute connect externalCommandIn to communications.commandOut;
        connection commandToController connect communications.commandOut to missionController.externalCommandIn;
        connection driveCommandBus connect missionController.driveCommandOut to mobility.commandIn;
        connection safetyOverrideBus connect safetyManager.overrideOut to missionController.safetyOverrideIn;

        connection observationBus connect sensors.observationOut to analysisComputer.observationIn;
        connection sampleBusToAnalysis connect sensors.sampleOut to analysisComputer.sampleIn;
        connection sampleBusToExperiment connect sensors.sampleOut to experimentBay.sampleIn;
        connection insightBus connect analysisComputer.insightOut to missionController.insightIn;
        connection experimentPlanBus connect missionController.experimentPlanOut to experimentBay.planIn;
        connection experimentResultBus connect experimentBay.resultOut to analysisComputer.experimentResultIn;

        connection mobilityHazardBus connect mobility.hazardOut to safetyManager.hazardIn;
        connection sensorHazardBus connect sensors.hazardOut to safetyManager.hazardIn;

        connection controllerTelemetryBus connect missionController.telemetryOut to communications.telemetryIn;
        connection safetyTelemetryBus connect safetyManager.telemetryOut to communications.telemetryIn;
        connection recommendationBus connect analysisComputer.recommendationOut to recommendationOut;
        connection recommendationDownlink connect analysisComputer.recommendationOut to communications.recommendationIn;
        connection telemetryDownlink connect communications.telemetryIn to telemetryOut;
    }

    requirement def PrimaryFunctionRequirement {
        subject system : ExploratoryEngineeringSystem;

        doc /* The system shall perform exploratory engineering at a high level by transforming uncertain objectives into evidence-backed engineering recommendations. */

        require constraint {
            system.primaryFunctionAvailability >= 0.95
        }

        require constraint {
            system.evidenceTraceabilityScore >= 0.90
        }
    }

    requirement def ExplorationEnduranceRequirement {
        subject system : ExploratoryEngineeringSystem;

        require constraint {
            system.maximumMissionDuration >= 28800 [SI::s]
        }

        require constraint {
            system.operatingRadius >= 1000 [SI::m]
        }
    }

    requirement def RapidExperimentRequirement {
        subject system : ExploratoryEngineeringSystem;

        require constraint {
            system.maximumExperimentCycleTime <= 7200 [SI::s]
        }
    }

    part exploratoryEngineeringPlatform : ExploratoryEngineeringSystem;

    requirement primaryFunction : PrimaryFunctionRequirement {
        subject system = exploratoryEngineeringPlatform;
    }

    requirement explorationEndurance : ExplorationEnduranceRequirement {
        subject system = exploratoryEngineeringPlatform;
    }

    requirement rapidExperimentCycle : RapidExperimentRequirement {
        subject system = exploratoryEngineeringPlatform;
    }
}
