package UbiquitousComputingSystem {

    import ScalarValues::*;
    import ScalarFunctions::*;

    // ===== Value Types with Units =====

    value def TemperatureValue :> Real { unit '°C'; }
    value def IlluminanceValue :> Real { unit 'lux'; }
    value def SoundPressureValue :> Real { unit 'dB'; }
    value def OccupancyCount :> Integer { unit 'person'; }
    value def DistanceValue :> Real { unit 'm'; }
    value def ConfidenceValue :> Real { unit 'percent'; min 0; max 100; }
    value def DataRateValue :> Real { unit 'Mbps'; }
    value def LatencyValue :> Real { unit 'ms'; }
    value def PowerValue :> Real { unit 'W'; }

    // ===== Item Types =====

    item def TemperatureReading {
        value temperature : TemperatureValue;
        value timestamp : String;
        value sensorId : String;
    }

    item def IlluminanceReading {
        value illuminance : IlluminanceValue;
        value timestamp : String;
        value sensorId : String;
    }

    item def SoundReading {
        value soundLevel : SoundPressureValue;
        value timestamp : String;
        value sensorId : String;
    }

    item def OccupancyReading {
        value count : OccupancyCount;
        value timestamp : String;
        value sensorId : String;
    }

    item def RawSensorData {
        value temperatureReadings : TemperatureReading[0..*];
        value illuminanceReadings : IlluminanceReading[0..*];
        value soundReadings : SoundReading[0..*];
        value occupancyReadings : OccupancyReading[0..*];
    }

    item def UserActivity {
        value activityType : String;
        value confidence : ConfidenceValue;
        value timestamp : String;
    }

    item def UserPreferences {
        value preferredTemperature : TemperatureValue;
        value preferredIlluminance : IlluminanceValue;
        value notificationLevel : String;
    }

    item def ProximityInfo {
        value deviceId : String;
        value distance : DistanceValue;
        value timestamp : String;
    }

    item def UserContextData {
        value userId : String;
        value currentActivity : UserActivity;
        value proximityList : ProximityInfo[0..*];
        value preferences : UserPreferences;
        value timestamp : String;
    }

    item def FusedContextSnapshot {
        value zoneId : String;
        value rawSensorData : RawSensorData;
        value userContextData : UserContextData[0..*];
        value inferredIntent : String;
        value intentConfidence : ConfidenceValue;
        value timestamp : String;
    }

    item def AdaptationPlan {
        value planId : String;
        value targetZoneId : String;
        value targetUserId : String;
        value actions : AdaptationAction[0..*];
        value requiresUserConfirmation : Boolean;
        value timestamp : String;
    }

    item def AdaptationAction {
        value actionType : String;
        value targetDeviceId : String;
        value parameterName : String;
        value parameterValue : String;
        value priority : Integer;
    }

    item def DeviceCommand {
        value commandId : String;
        value targetDeviceId : String;
        value actionType : String;
        value parameterName : String;
        value parameterValue : String;
        value source : String;
    }

    item def UserConfirmationRequest {
        value requestId : String;
        value userId : String;
        value proposedPlan : AdaptationPlan;
        value timestamp : String;
    }

    item def UserConfirmationResponse {
        value requestId : String;
        value userId : String;
        value approved : Boolean;
        value modifiedParameters : String[0..*];
    }

    // ===== Port Definitions =====

    port def SensorDataOut {
        out rawSensorData : RawSensorData;
    }

    port def SensorDataIn {
        in rawSensorData : RawSensorData;
    }

    port def UserContextOut {
        out userContextData : UserContextData;
    }

    port def UserContextIn {
        in userContextData : UserContextData;
    }

    port def FusedContextOut {
        out fusedContext : FusedContextSnapshot;
    }

    port def FusedContextIn {
        in fusedContext : FusedContextSnapshot;
    }

    port def AdaptationPlanOut {
        out adaptationPlan : AdaptationPlan;
    }

    port def AdaptationPlanIn {
        in adaptationPlan : AdaptationPlan;
    }

    port def CommandOut {
        out deviceCommand : DeviceCommand;
    }

    port def CommandIn {
        in deviceCommand : DeviceCommand;
    }

    port def ConfirmationRequestOut {
        out confirmationRequest : UserConfirmationRequest;
    }

    port def ConfirmationRequestIn {
        in confirmationRequest : UserConfirmationRequest;
    }

    port def ConfirmationResponseOut {
        out confirmationResponse : UserConfirmationResponse;
    }

    port def ConfirmationResponseIn {
        in confirmationResponse : UserConfirmationResponse;
    }

    // ===== Context Sensors =====

    part def ContextSensor {
        attribute sensorId : String;
        attribute location : String;
        port sensorOut : SensorDataOut;
    }

    part def TemperatureSensor :> ContextSensor {
        attribute measuredTemperature : TemperatureValue;
        action measureTemperature {
            out tempReading : TemperatureReading;
        }
    }

    part def LightSensor :> ContextSensor {
        attribute measuredIlluminance : IlluminanceValue;
        action measureIlluminance {
            out lightReading : IlluminanceReading;
        }
    }

    part def SoundSensor :> ContextSensor {
        attribute measuredSoundLevel : SoundPressureValue;
        action measureSound {
            out soundReading : SoundReading;
        }
    }

    part def OccupancySensor :> ContextSensor {
        attribute detectedCount : OccupancyCount;
        action countPeople {
            out occupancyReading : OccupancyReading;
        }
    }

    part def SensorCluster {
        attribute clusterId : String;
        attribute zoneId : String;
        port sensorDataOut : SensorDataOut;
        part tempSensor : TemperatureSensor;
        part lightSensor : LightSensor;
        part soundSensor : SoundSensor;
        part occupancySensor : OccupancySensor;

        connection : SensorDataOut>~>SensorDataIn {
            source tempSensor.sensorOut;
            target sensorDataOut;
        }
        connection : SensorDataOut>~>SensorDataIn {
            source lightSensor.sensorOut;
            target sensorDataOut;
        }
        connection : SensorDataOut>~>SensorDataIn {
            source soundSensor.sensorOut;
            target sensorDataOut;
        }
        connection : SensorDataOut>~>SensorDataIn {
            source occupancySensor.sensorOut;
            target sensorDataOut;
        }
    }

    // ===== User Devices =====

    part def UserDevice {
        attribute deviceId : String;
        attribute userId : String;
        attribute deviceType : String;
        port userContextOut : UserContextOut;
        port commandIn : CommandIn;
        port confirmationRequestIn : ConfirmationRequestIn;
        port confirmationResponseOut : ConfirmationResponseOut;

        attribute currentActivity : UserActivity;
        attribute preferences : UserPreferences;
        attribute proximityList : ProximityInfo[0..*];

        action trackActivity {
            in currentActivityType : String;
            out updatedActivity : UserActivity;
        }

        action trackProximity {
            out updatedProximity : ProximityInfo[0..*];
        }

        action executeCommand {
            in receivedCommand : DeviceCommand;
        }
    }

    part def Smartphone :> UserDevice {
        attribute screenOn : Boolean;
        action displayNotification {
            in message : String;
        }
    }

    part def Wearable :> UserDevice {
        attribute heartRate : Integer;
        action monitorVitals {
            out vitalsData : String;
        }
    }

    part def Tablet :> UserDevice {
        attribute displayBrightness : IlluminanceValue;
        action adjustBrightness {
            in targetBrightness : IlluminanceValue;
        }
    }

    part def SmartAppliance {
        attribute applianceId : String;
        attribute applianceType : String;
        port commandIn : CommandIn;
        action executeCommand {
            in receivedCommand : DeviceCommand;
        }
    }

    part def SmartThermostat :> SmartAppliance {
        attribute currentSetpoint : TemperatureValue;
        action setTemperature {
            in targetTemperature : TemperatureValue;
        }
    }

    part def SmartLighting :> SmartAppliance {
        attribute currentBrightness : IlluminanceValue;
        action setBrightness {
            in targetBrightness : IlluminanceValue;
        }
    }

    // ===== Infrastructure Layer =====

    part def EdgeProcessor {
        attribute processorId : String;
        attribute zoneId : String;
        attribute processingLatency : LatencyValue;
        port sensorDataIn : SensorDataIn;
        port userContextIn : UserContextIn;
        port fusedContextOut : FusedContextOut;
        port confirmationResponseIn : ConfirmationResponseIn;

        state EdgeProcessorBehavior {
            entry action { send FusedContextSnapshot(); }
            state Idle;
            state Collecting {
                entry action { collectRawData(); }
                do action { fuseSensorData(); }
                exit action { inferIntent(); }
            }
            state Fusing {
                do action { performDataFusion(); }
            }
            state Analyzing {
                do action { performLocalAnalysis(); }
            }
            transition Idle to Collecting when sensorDataIn.rawSensorData->notEmpty();
            transition Collecting to Fusing when sensorDataIn.rawSensorData->size() > 0;
            transition Fusing to Analyzing when fusedContextOut.fusedContext->notEmpty();
            transition Analyzing to Idle when fusedContextOut.fusedContext->isSent();
        }

        action collectRawData {
            in sensorData : RawSensorData;
            out collectedData : RawSensorData;
        }

        action fuseSensorData {
            in raw : RawSensorData;
            out fused : RawSensorData;
        }

        action inferIntent {
            in data : RawSensorData;
            in userCtx : UserContextData;
            out intent : String;
            out confidence : ConfidenceValue;
        }

        action performDataFusion {
            in raw : RawSensorData;
            out fused : RawSensorData;
        }

        action performLocalAnalysis {
            in fused : RawSensorData;
            in userCtx : UserContextData[0..*];
            out snapshot : FusedContextSnapshot;
        }
    }

    part def CloudService {
        attribute serviceId : String;
        attribute serviceName : String;
        port fusedContextIn : FusedContextIn;
        port adaptationPlanOut : AdaptationPlanOut;
        port confirmationRequestOut : ConfirmationRequestOut;
        port confirmationResponseIn : ConfirmationResponseIn;

        attribute longTermPreferences : UserPreferences[0..*];
        attribute behavioralPatterns : String[0..*];

        state CloudServiceBehavior {
            state Receiving;
            state Analyzing {
                do action { analyzeContext(); }
            }
            state Planning {
                do action { generateAdaptationPlan(); }
            }
            state AwaitingConfirmation {
                do action { waitForUserConfirmation(); }
            }
            state Dispatching {
                do action { dispatchPlan(); }
            }
            transition Receiving to Analyzing when fusedContextIn.fusedContext->notEmpty();
            transition Analyzing to Planning when fusedContextIn.fusedContext->isProcessed();
            transition Planning to AwaitingConfirmation when adaptationPlanOut.adaptationPlan.requiresUserConfirmation == true;
            transition Planning to Dispatching when adaptationPlanOut.adaptationPlan.requiresUserConfirmation == false;
            transition AwaitingConfirmation to Dispatching when confirmationResponseIn.confirmationResponse.approved == true;
            transition AwaitingConfirmation to Receiving when confirmationResponseIn.confirmationResponse.approved == false;
            transition Dispatching to Receiving when adaptationPlanOut.adaptationPlan->isSent();
        }

        action analyzeContext {
            in fusedContext : FusedContextSnapshot;
            in longTermPrefs : UserPreferences[0..*];
            out analysisResult : String;
        }

        action generateAdaptationPlan {
            in analysisResult : String;
            in fusedContext : FusedContextSnapshot;
            out plan : AdaptationPlan;
        }

        action waitForUserConfirmation {
            in plan : AdaptationPlan;
            out request : UserConfirmationRequest;
        }

        action dispatchPlan {
            in plan : AdaptationPlan;
            out dispatchedPlan : AdaptationPlan;
        }
    }

    part def NetworkInfrastructure {
        attribute networkId : String;
        attribute dataRate : DataRateValue;
        port sensorDataIn : SensorDataIn;
        port fusedContextOut : FusedContextOut;
        port adaptationPlanOut : AdaptationPlanOut;
        port commandOut : CommandOut;
        action routeData {
            in data : RawSensorData;
            out routedData : RawSensorData;
        }
    }

    // ===== Top-Level System =====

    part def UbiquitousComputingEnvironment {
        attribute environmentId : String;
        attribute zoneCount : Integer;

        part sensorClusters : SensorCluster[1..*] {
            part tempSensor : TemperatureSensor;
            part lightSensor : LightSensor;
            part soundSensor : SoundSensor;
            part occupancySensor : OccupancySensor;
        }

        part userDevices : UserDevice[0..*] {
            part smartphones : Smartphone[0..*];
            part wearables : Wearable[0..*];
            part tablets : Tablet[0..*];
        }

        part smartAppliances : SmartAppliance[0..*] {
            part thermostats : SmartThermostat[0..*];
            part lightingSystems : SmartLighting[0..*];
        }

        part edgeProcessors : EdgeProcessor[1..*];
        part cloudServices : CloudService[1..*];
        part network : NetworkInfrastructure;

        // Sensor clusters to edge processors
        connection : SensorDataOut>~>SensorDataIn {
            source sensorClusters.sensorDataOut;
            target edgeProcessors.sensorDataIn;
        }

        // User devices to edge processors
        connection : UserContextOut>~>UserContextIn {
            source userDevices.userContextOut;
            target edgeProcessors.userContextIn;
        }

        // Edge processors to cloud services
        connection : FusedContextOut>~>FusedContextIn {
            source edgeProcessors.fusedContextOut;
            target cloudServices.fusedContextIn;
        }

        // Cloud services to user devices (adaptation plans)
        connection : AdaptationPlanOut>~>AdaptationPlanIn {
            source cloudServices.adaptationPlanOut;
            target userDevices.commandIn;
        }

        // Cloud services to smart appliances (commands)
        connection : AdaptationPlanOut>~>AdaptationPlanIn {
            source cloudServices.adaptationPlanOut;
            target smartAppliances.commandIn;
        }

        // Cloud services to user devices (confirmation requests)
        connection : ConfirmationRequestOut>~>ConfirmationRequestIn {
            source cloudServices.confirmationRequestOut;
            target userDevices.confirmationRequestIn;
        }

        // User devices to cloud services (confirmation responses)
        connection : ConfirmationResponseOut>~>ConfirmationResponseIn {
            source userDevices.confirmationResponseOut;
            target cloudServices.confirmationResponseIn;
        }

        // User devices to edge processors (confirmation responses forwarded)
        connection : ConfirmationResponseOut>~>ConfirmationResponseIn {
            source userDevices.confirmationResponseOut;
            target edgeProcessors.confirmationResponseIn;
        }

        state SystemOperationLoop {
            state Sensing {
                do action { gatherContext(); }
            }
            state EdgeProcessing {
                do action { filterAndAnalyze(); }
            }
            state CloudPlanning {
                do action { generatePlan(); }
            }
            state Executing {
                do action { executeCommands(); }
            }
            transition Sensing to EdgeProcessing when sensorClusters.sensorDataOut.rawSensorData->notEmpty();
            transition EdgeProcessing to CloudPlanning when edgeProcessors.fusedContextOut.fusedContext->notEmpty();
            transition CloudPlanning to Executing when cloudServices.adaptationPlanOut.adaptationPlan->notEmpty();
            transition Executing to Sensing when userDevices.commandIn.deviceCommand->isProcessed();
        }

        action gatherContext {
            out sensorData : RawSensorData;
            out userContext : UserContextData;
        }

        action filterAndAnalyze {
            in sensorData : RawSensorData;
            in userContext : UserContextData;
            out fusedContext : FusedContextSnapshot;
        }

        action generatePlan {
            in fusedContext : FusedContextSnapshot;
            out plan : AdaptationPlan;
        }

        action executeCommands {
            in plan : AdaptationPlan;
            out commands : DeviceCommand[0..*];
        }
    }

    // ===== Requirements =====

    package Requirements {

        requirement def UbiquitousComputingRequirement {
            doc "The system shall provide intelligent services that adapt to user needs and environmental conditions without requiring direct user interaction."
        }

        requirement ContextSensing : UbiquitousComputingRequirement {
            doc "The system shall deploy a dense network of context sensors measuring temperature, light, sound, and occupancy."
            subject sensorClusters : SensorCluster[1..*];
            objective {
                sensorClusters->size() >= 1 and
                sensorClusters.tempSensor->notEmpty() and
                sensorClusters.lightSensor->notEmpty() and
                sensorClusters.soundSensor->notEmpty() and
                sensorClusters.occupancySensor->notEmpty();
            }
        }

        requirement RealTimeContextPicture : UbiquitousComputingRequirement {
            doc "The system shall provide a real-time picture of environmental context with latency below 500 ms."
            subject edgeProcessors : EdgeProcessor[1..*];
            objective {
                edgeProcessors.processingLatency < 500 [ms];
            }
        }

        requirement UserDeviceTracking : UbiquitousComputingRequirement {
            doc "User devices shall track current activity, proximity, and saved preferences."
            subject userDevices : UserDevice[0..*];
            objective {
                userDevices.currentActivity->notEmpty() and
                userDevices.preferences->notEmpty() and
                userDevices.proximityList->notEmpty();
            }
        }

        requirement EdgeDataFusion : UbiquitousComputingRequirement {
            doc "Edge processors shall fuse raw sensor data from multiple sensors into a coherent local picture."
            subject edgeProcessors : EdgeProcessor[1..*];
            objective {
                edgeProcessors.fusedContextOut.fusedContext->notEmpty();
            }
        }

        requirement EdgeIntentInference : UbiquitousComputingRequirement {
            doc "Edge processors shall perform time-sensitive analysis including inferring user immediate intent."
            subject edgeProcessors : EdgeProcessor[1..*];
            objective {
                edgeProcessors.fusedContextOut.fusedContext.inferredIntent->notEmpty();
            }
        }

        requirement CloudHighLevelAnalysis : UbiquitousComputingRequirement {
            doc "Cloud services shall analyze processed information against long-term preferences and behavioral patterns."
            subject cloudServices : CloudService[1..*];
            objective {
                cloudServices.longTermPreferences->notEmpty() and
                cloudServices.behavioralPatterns->notEmpty();
            }
        }

        requirement CloudAdaptationPlanning : UbiquitousComputingRequirement {
            doc "Cloud services shall decide on the best way for the environment to adapt and generate an adaptation plan."
            subject cloudServices : CloudService[1..*];
            objective {
                cloudServices.adaptationPlanOut.adaptationPlan->notEmpty();
            }
        }

        requirement CommandExecution : UbiquitousComputingRequirement {
            doc "The system shall translate adaptation plans into specific commands sent to user devices and smart appliances."
            subject environment : UbiquitousComputingEnvironment;
            objective {
                environment.userDevices.commandIn.deviceCommand->notEmpty() or
                environment.smartAppliances.commandIn.deviceCommand->notEmpty();
            }
        }

        requirement ProactiveAdaptation : UbiquitousComputingRequirement {
            doc "The system shall proactively anticipate user needs with a high degree of confidence before acting."
            subject cloudServices : CloudService[1..*];
            objective {
                cloudServices.adaptationPlanOut.adaptationPlan.requiresUserConfirmation == false implies
                cloudServices.fusedContextIn.fusedContext.intentConfidence >= 75 [percent];
            }
        }

        requirement UserConfirmationOnUncertainty : UbiquitousComputingRequirement {
            doc "In cases of uncertainty, the system shall prompt the user for confirmation before executing adaptation plans."
            subject cloudServices : CloudService[1..*];
            objective {
                cloudServices.fusedContextIn.fusedContext.intentConfidence < 75 [percent] implies
                cloudServices.adaptationPlanOut.adaptationPlan.requiresUserConfirmation == true;
            }
        }

        requirement ContinuousLoop : UbiquitousComputingRequirement {
            doc "The system shall operate in a continuous loop of sensing, edge processing, cloud planning, and command execution."
            subject environment : UbiquitousComputingEnvironment;
            objective {
                environment.SystemOperationLoop.Sensing->isActive() or
                environment.SystemOperationLoop.EdgeProcessing->isActive() or
                environment.SystemOperationLoop.CloudPlanning->isActive() or
                environment.SystemOperationLoop.Executing->isActive();
            }
        }

        requirement SeamlessBackgroundOperation : UbiquitousComputingRequirement {
            doc "Computing shall fade into the background, providing intelligent services without requiring direct user interaction."
            subject environment : UbiquitousComputingEnvironment;
            objective {
                environment.cloudServices.adaptationPlanOut.adaptationPlan.requiresUserConfirmation == false;
            }
        }
    }

    // ===== Verification =====

    verification VerifyContextSensing satisfies ContextSensing {
        subject sensorClusters : SensorCluster[1..*];
        objective {
            sensorClusters->size() >= 1 and
            sensorClusters.tempSensor->notEmpty() and
            sensorClusters.lightSensor->notEmpty() and
            sensorClusters.soundSensor->notEmpty() and
            sensorClusters.occupancySensor->notEmpty();
        }
    }

    verification VerifyEdgeLatency satisfies RealTimeContextPicture {
        subject edgeProcessors : EdgeProcessor[1..*];
        objective {
            edgeProcessors.processingLatency < 500 [ms];
        }
    }

    verification VerifyProactiveConfidence satisfies ProactiveAdaptation {
        subject cloudServices : CloudService[1..*];
        objective {
            cloudServices.adaptationPlanOut.adaptationPlan.requiresUserConfirmation == false implies
            cloudServices.fusedContextIn.fusedContext.intentConfidence >= 75 [percent];
        }
    }

    verification VerifyUserConfirmation satisfies UserConfirmationOnUncertainty {
        subject cloudServices : CloudService[1..*];
        objective {
            cloudServices.fusedContextIn.fusedContext.intentConfidence < 75 [percent] implies
            cloudServices.adaptationPlanOut.adaptationPlan.requiresUserConfirmation == true;
        }
    }

    verification VerifyContinuousLoop satisfies ContinuousLoop {
        subject environment : UbiquitousComputingEnvironment;
        objective {
            environment.SystemOperationLoop.Sensing->isActive() or
            environment.SystemOperationLoop.EdgeProcessing->isActive() or
            environment.SystemOperationLoop.CloudPlanning->isActive() or
            environment.SystemOperationLoop.Executing->isActive();
        }
    }
}
