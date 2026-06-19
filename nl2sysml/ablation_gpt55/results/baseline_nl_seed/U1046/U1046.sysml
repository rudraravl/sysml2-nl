package EmergingTechnologyResilienceSystem {
    import ScalarValues::*;

    attribute def Kilowatt :> Real {
        doc "Unit: kW. Rate of electrical power transfer."
    }

    attribute def KilowattHour :> Real {
        doc "Unit: kW*h. Stored or consumed electrical energy."
    }

    attribute def Millisecond :> Real {
        doc "Unit: ms. Time duration."
    }

    attribute def Percent :> Real {
        doc "Unit: %. Ratio expressed from 0 to 100."
    }

    attribute def Gigabyte :> Real {
        doc "Unit: GB. Digital storage capacity."
    }

    attribute def MegabitPerSecond :> Real {
        doc "Unit: Mb/s. Data transfer rate."
    }

    attribute def Kilometer :> Real {
        doc "Unit: km. Distance."
    }

    attribute def CelsiusDegree :> Real {
        doc "Unit: degC. Temperature."
    }

    attribute def ConfidenceScore :> Real {
        doc "Unitless score from 0.0 to 1.0."
    }

    item def ElectricalPower {
        attribute amount : Kilowatt;
    }

    item def StoredEnergy {
        attribute amount : KilowattHour;
    }

    item def SensorObservation {
        attribute sourceId : String;
        attribute observedPhenomenon : String;
        attribute temperature : CelsiusDegree;
        attribute locationRadius : Kilometer;
        attribute confidence : ConfidenceScore;
    }

    item def RobotTelemetry {
        attribute robotId : String;
        attribute batteryState : Percent;
        attribute distanceFromBase : Kilometer;
        attribute healthState : String;
    }

    item def DroneImagery {
        attribute droneId : String;
        attribute coverageRadius : Kilometer;
        attribute dataSize : Gigabyte;
        attribute confidence : ConfidenceScore;
    }

    item def CitizenAlert {
        attribute alertId : String;
        attribute alertText : String;
        attribute confidence : ConfidenceScore;
    }

    item def QuantumSafeKey {
        attribute keyIdentifier : String;
        attribute algorithm : String;
        attribute validForSeconds : Real;
    }

    item def EncryptedDataFrame {
        attribute frameId : String;
        attribute payloadSize : Gigabyte;
        attribute encryptionAlgorithm : String;
    }

    item def DigitalTwinModelUpdate {
        attribute modelVersion : String;
        attribute changedAssets : Integer;
        attribute updateSize : Gigabyte;
    }

    item def IncidentForecast {
        attribute incidentType : String;
        attribute probability : Percent;
        attribute predictedImpactRadius : Kilometer;
        attribute forecastConfidence : ConfidenceScore;
    }

    item def ResiliencePlan {
        attribute planId : String;
        attribute targetIncidentType : String;
        attribute estimatedRiskReduction : Percent;
        attribute expectedExecutionMinutes : Real;
    }

    item def AutonomousCommand {
        attribute commandId : String;
        attribute targetAssetId : String;
        attribute commandText : String;
        attribute priority : Integer;
    }

    port def PowerInputPort {
        in item power : ElectricalPower;
    }

    port def PowerOutputPort {
        out item power : ElectricalPower;
    }

    port def EnergyStoragePort {
        inout item energy : StoredEnergy;
    }

    port def SensorDataInPort {
        in item observation : SensorObservation;
    }

    port def TelemetryInPort {
        in item telemetry : RobotTelemetry;
    }

    port def ImageryInPort {
        in item imagery : DroneImagery;
    }

    port def CitizenAlertInPort {
        in item alert : CitizenAlert;
    }

    port def SecureDataInPort {
        in item frame : EncryptedDataFrame;
        in item key : QuantumSafeKey;
    }

    port def SecureDataOutPort {
        out item frame : EncryptedDataFrame;
        out item key : QuantumSafeKey;
    }

    port def ModelUpdatePort {
        inout item update : DigitalTwinModelUpdate;
    }

    port def ForecastOutPort {
        out item forecast : IncidentForecast;
    }

    port def PlanOutPort {
        out item plan : ResiliencePlan;
    }

    port def CommandOutPort {
        out item command : AutonomousCommand;
    }

    port def CommandInPort {
        in item command : AutonomousCommand;
    }

    part def RenewableMicrogrid {
        attribute peakGeneration : Kilowatt;
        attribute storageCapacity : KilowattHour;
        attribute reserveMargin : Percent;

        port generatedPower : PowerOutputPort;
        port storedEnergy : EnergyStoragePort;
    }

    part def EdgeSensorMesh {
        attribute sensorCount : Integer;
        attribute coverageRadius : Kilometer;
        attribute averageLatency : Millisecond;
        attribute networkBandwidth : MegabitPerSecond;

        port sensorOutput : SensorDataInPort;
        port secureOutput : SecureDataOutPort;
    }

    part def AutonomousDroneFleet {
        attribute droneCount : Integer;
        attribute patrolRadius : Kilometer;
        attribute nominalFlightMinutes : Real;

        port imageryOutput : ImageryInPort;
        port telemetryOutput : TelemetryInPort;
        port commandInput : CommandInPort;
        port secureOutput : SecureDataOutPort;
    }

    part def GroundRobotFleet {
        attribute robotCount : Integer;
        attribute operatingRadius : Kilometer;
        attribute payloadCapacityKg : Real;

        port telemetryOutput : TelemetryInPort;
        port commandInput : CommandInPort;
        port secureOutput : SecureDataOutPort;
    }

    part def QuantumSafeSecurityGateway {
        attribute supportedAlgorithm : String;
        attribute keyRotationPeriodSeconds : Real;
        attribute throughput : MegabitPerSecond;
        attribute addedLatency : Millisecond;

        port rawSecureInput : SecureDataInPort;
        port protectedOutput : SecureDataOutPort;
        port protectedInput : SecureDataInPort;
        port rawSecureOutput : SecureDataOutPort;
    }

    part def EdgeAIComputeCluster {
        attribute acceleratorCount : Integer;
        attribute peakPowerDemand : Kilowatt;
        attribute inferenceLatencyTarget : Millisecond;
        attribute modelStorage : Gigabyte;

        port powerInput : PowerInputPort;
        port secureDataInput : SecureDataInPort;
        port forecastOutput : ForecastOutPort;
        port modelUpdatePort : ModelUpdatePort;
    }

    part def UrbanDigitalTwinCore {
        attribute representedAssetCount : Integer;
        attribute modelRefreshPeriod : Millisecond;
        attribute storageCapacity : Gigabyte;
        attribute simulationHorizonHours : Real;

        port modelUpdatePort : ModelUpdatePort;
        port secureDataInput : SecureDataInPort;
        port forecastOutput : ForecastOutPort;
        port planOutput : PlanOutPort;
    }

    part def ResilienceOrchestrator {
        attribute decisionCycleTime : Millisecond;
        attribute minimumPlanConfidence : ConfidenceScore;
        attribute maximumAutonomyLevel : Integer;

        port forecastInput : ForecastOutPort;
        port planInput : PlanOutPort;
        port droneCommandOutput : CommandOutPort;
        port robotCommandOutput : CommandOutPort;
        port publicAlertInput : CitizenAlertInPort;
    }

    part def HumanOperatorConsole {
        attribute displayCount : Integer;
        attribute reviewTimeoutSeconds : Real;

        port secureDataInput : SecureDataInPort;
        port planInput : PlanOutPort;
        port manualCommandOutput : CommandOutPort;
    }

    action def AcquireUrbanSignals {
        in item sensorObservation : SensorObservation;
        in item droneImagery : DroneImagery;
        in item robotTelemetry : RobotTelemetry;
        in item citizenAlert : CitizenAlert;
        out item protectedFrame : EncryptedDataFrame;
    }

    action def ApplyQuantumSafeProtection {
        in item unprotectedFrame : EncryptedDataFrame;
        in item sessionKey : QuantumSafeKey;
        out item protectedFrame : EncryptedDataFrame;
    }

    action def UpdateDigitalTwin {
        in item protectedFrame : EncryptedDataFrame;
        out item modelUpdate : DigitalTwinModelUpdate;
    }

    action def RunPredictiveInference {
        in item modelUpdate : DigitalTwinModelUpdate;
        out item forecast : IncidentForecast;
    }

    action def GenerateResiliencePlan {
        in item forecast : IncidentForecast;
        out item plan : ResiliencePlan;
    }

    action def DispatchAutonomousResponse {
        in item plan : ResiliencePlan;
        out item droneCommand : AutonomousCommand;
        out item robotCommand : AutonomousCommand;
    }

    action def HighLevelPrimaryFunction {
        doc "Fuse real-time sensor, drone, robot, and citizen information into a secure urban digital twin; use edge AI to forecast disruptions; and coordinate autonomous resilience responses."

        action acquire : AcquireUrbanSignals;
        action protect : ApplyQuantumSafeProtection;
        action updateTwin : UpdateDigitalTwin;
        action infer : RunPredictiveInference;
        action plan : GenerateResiliencePlan;
        action dispatch : DispatchAutonomousResponse;

        flow acquire.protectedFrame to protect.unprotectedFrame;
        flow protect.protectedFrame to updateTwin.protectedFrame;
        flow updateTwin.modelUpdate to infer.modelUpdate;
        flow infer.forecast to plan.forecast;
        flow plan.plan to dispatch.plan;
    }

    state def ResilienceOperatingStates {
        state PoweredOff;
        state Standby;
        state Monitoring;
        state Predicting;
        state CoordinatingResponse;
        state DegradedSecureMode;
        state Maintenance;

        transition initial then PoweredOff;

        transition PowerAvailable
            first PoweredOff
            then Standby;

        transition BeginMission
            first Standby
            then Monitoring;

        transition SignificantSignalDetected
            first Monitoring
            then Predicting;

        transition ForecastExceedsThreshold
            first Predicting
            then CoordinatingResponse;

        transition ResponseCompleted
            first CoordinatingResponse
            then Monitoring;

        transition SecurityAnomalyDetectedFromMonitoring
            first Monitoring
            then DegradedSecureMode;

        transition SecurityAnomalyDetectedFromPredicting
            first Predicting
            then DegradedSecureMode;

        transition SecurityRecovered
            first DegradedSecureMode
            then Monitoring;

        transition MaintenanceRequested
            first Standby
            then Maintenance;

        transition MaintenanceCompleted
            first Maintenance
            then Standby;
    }

    part def EmergingTechnologyResiliencePlatform {
        doc "System based on emerging technologies: edge artificial intelligence, digital twins, autonomous robotics, quantum-safe cybersecurity, IoT sensing, and renewable microgrid power. Its primary high-level function is to maintain urban resilience by understanding current conditions, forecasting disruptions, and coordinating safe response actions."

        attribute primaryFunction : String = "Securely fuse urban data into a digital twin, predict resilience risks using edge AI, and orchestrate autonomous response assets.";
        attribute autonomyLevel : Integer = 4;
        attribute availabilityTarget : Percent = 99.5;
        attribute maximumDecisionLatency : Millisecond = 500.0;
        attribute minimumForecastConfidence : ConfidenceScore = 0.85;
        attribute protectedDataThroughput : MegabitPerSecond = 10000.0;

        part microgrid : RenewableMicrogrid {
            attribute peakGeneration = 750.0;
            attribute storageCapacity = 2200.0;
            attribute reserveMargin = 25.0;
        }

        part sensorMesh : EdgeSensorMesh {
            attribute sensorCount = 2500;
            attribute coverageRadius = 35.0;
            attribute averageLatency = 50.0;
            attribute networkBandwidth = 5000.0;
        }

        part drones : AutonomousDroneFleet {
            attribute droneCount = 36;
            attribute patrolRadius = 18.0;
            attribute nominalFlightMinutes = 45.0;
        }

        part robots : GroundRobotFleet {
            attribute robotCount = 24;
            attribute operatingRadius = 8.0;
            attribute payloadCapacityKg = 60.0;
        }

        part securityGateway : QuantumSafeSecurityGateway {
            attribute supportedAlgorithm = "ML-KEM-1024 and ML-DSA-87";
            attribute keyRotationPeriodSeconds = 300.0;
            attribute throughput = 12000.0;
            attribute addedLatency = 8.0;
        }

        part edgeAI : EdgeAIComputeCluster {
            attribute acceleratorCount = 128;
            attribute peakPowerDemand = 420.0;
            attribute inferenceLatencyTarget = 150.0;
            attribute modelStorage = 800.0;
        }

        part digitalTwin : UrbanDigitalTwinCore {
            attribute representedAssetCount = 120000;
            attribute modelRefreshPeriod = 250.0;
            attribute storageCapacity = 50000.0;
            attribute simulationHorizonHours = 72.0;
        }

        part orchestrator : ResilienceOrchestrator {
            attribute decisionCycleTime = 500.0;
            attribute minimumPlanConfidence = 0.85;
            attribute maximumAutonomyLevel = 4;
        }

        part operatorConsole : HumanOperatorConsole {
            attribute displayCount = 8;
            attribute reviewTimeoutSeconds = 60.0;
        }

        port externalPowerInput : PowerInputPort;
        port publicAlertInput : CitizenAlertInPort;

        connection externalPowerToMicrogrid
            connect externalPowerInput to microgrid.generatedPower;

        connection microgridToEdgeAI
            connect microgrid.generatedPower to edgeAI.powerInput;

        connection sensorMeshToSecurity
            connect sensorMesh.secureOutput to securityGateway.rawSecureInput;

        connection dronesToSecurity
            connect drones.secureOutput to securityGateway.rawSecureInput;

        connection robotsToSecurity
            connect robots.secureOutput to securityGateway.rawSecureInput;

        connection securityToEdgeAI
            connect securityGateway.protectedOutput to edgeAI.secureDataInput;

        connection securityToDigitalTwin
            connect securityGateway.protectedOutput to digitalTwin.secureDataInput;

        connection edgeAIModelToDigitalTwin
            connect edgeAI.modelUpdatePort to digitalTwin.modelUpdatePort;

        connection edgeAIForecastToOrchestrator
            connect edgeAI.forecastOutput to orchestrator.forecastInput;

        connection digitalTwinForecastToOrchestrator
            connect digitalTwin.forecastOutput to orchestrator.forecastInput;

        connection digitalTwinPlanToOrchestrator
            connect digitalTwin.planOutput to orchestrator.planInput;

        connection publicAlertsToOrchestrator
            connect publicAlertInput to orchestrator.publicAlertInput;

        connection orchestratorToDrones
            connect orchestrator.droneCommandOutput to drones.commandInput;

        connection orchestratorToRobots
            connect orchestrator.robotCommandOutput to robots.commandInput;

        connection operatorConsoleToDrones
            connect operatorConsole.manualCommandOutput to drones.commandInput;

        connection operatorConsoleToRobots
            connect operatorConsole.manualCommandOutput to robots.commandInput;

        perform action primaryFunctionBehavior : HighLevelPrimaryFunction;

        exhibit state operatingState : ResilienceOperatingStates;
    }

    requirement def PrimaryFunctionRequirement {
        doc "The system shall provide a high-level resilience function by securely collecting multimodal urban data, maintaining a digital twin, predicting disruptions, and coordinating autonomous response actions."
        subject platform : EmergingTechnologyResiliencePlatform;
    }

    requirement def EmergingTechnologyBasisRequirement {
        doc "The system shall be based on multiple emerging technologies including edge AI, digital twin simulation, autonomous robotics, quantum-safe cybersecurity, IoT sensing, and renewable microgrid energy."
        subject platform : EmergingTechnologyResiliencePlatform;
    }

    requirement def SecureLatencyRequirement {
        doc "The system shall keep secure decision-cycle latency at or below 500 ms during normal monitoring and response coordination."
        subject platform : EmergingTechnologyResiliencePlatform;
        require constraint {
            platform.maximumDecisionLatency <= 500.0
        }
    }

    requirement def ForecastConfidenceRequirement {
        doc "The system shall generate incident forecasts with a minimum confidence score of 0.85 before autonomous coordination of response assets."
        subject platform : EmergingTechnologyResiliencePlatform;
        require constraint {
            platform.minimumForecastConfidence >= 0.85
        }
    }

    requirement def AvailabilityRequirement {
        doc "The system shall maintain at least 99.5 percent operational availability for city resilience monitoring."
        subject platform : EmergingTechnologyResiliencePlatform;
        require constraint {
            platform.availabilityTarget >= 99.5
        }
    }

    requirement def QuantumSafeProtectionRequirement {
        doc "The system shall protect operational data exchanges using quantum-safe key establishment and digital signatures."
        subject platform : EmergingTechnologyResiliencePlatform;
    }

    part resiliencePlatform : EmergingTechnologyResiliencePlatform;

    requirement primaryFunctionRequirement : PrimaryFunctionRequirement {
        subject platform = resiliencePlatform;
    }

    requirement emergingTechnologyBasisRequirement : EmergingTechnologyBasisRequirement {
        subject platform = resiliencePlatform;
    }

    requirement secureLatencyRequirement : SecureLatencyRequirement {
        subject platform = resiliencePlatform;
    }

    requirement forecastConfidenceRequirement : ForecastConfidenceRequirement {
        subject platform = resiliencePlatform;
    }

    requirement availabilityRequirement : AvailabilityRequirement {
        subject platform = resiliencePlatform;
    }

    requirement quantumSafeProtectionRequirement : QuantumSafeProtectionRequirement {
        subject platform = resiliencePlatform;
    }
}
