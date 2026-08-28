package UbiquitousComputingSystem {

    private import ScalarValues::*;

    // ---- Attribute types ----
    attribute def TemperatureValue :> ScalarValues::Real;
    attribute def IlluminanceValue :> ScalarValues::Real;
    attribute def SoundPressureValue :> ScalarValues::Real;
    attribute def OccupancyCount :> ScalarValues::Integer;
    attribute def ConfidenceValue :> ScalarValues::Real;
    attribute def ProximityDistance :> ScalarValues::Real;
    attribute def LatencyValue :> ScalarValues::Real;
    attribute def FrequencyValue :> ScalarValues::Real;

    // ---- Item types ----
    item def SensorData {
        attribute timestamp : ScalarValues::String;
        attribute sourceId : ScalarValues::String;
    }
    item def TemperatureData :> SensorData {
        attribute value : TemperatureValue;
    }
    item def IlluminanceData :> SensorData {
        attribute value : IlluminanceValue;
    }
    item def SoundData :> SensorData {
        attribute value : SoundPressureValue;
    }
    item def OccupancyData :> SensorData {
        attribute value : OccupancyCount;
    }
    item def UserContext {
        attribute activity : ScalarValues::String;
        attribute proximity : ProximityDistance;
        attribute prefTemp : TemperatureValue;
        attribute prefIlluminance : IlluminanceValue;
        attribute prefNotification : ScalarValues::Boolean;
    }
    item def FusedContext {
        attribute localContext : ScalarValues::String;
        attribute inferredIntent : ScalarValues::String;
        attribute confidence : ConfidenceValue;
    }
    item def AdaptationPlan {
        attribute targetDevice : ScalarValues::String;
        attribute commandType : ScalarValues::String;
        attribute paramTemp : TemperatureValue;
        attribute paramIlluminance : IlluminanceValue;
        attribute confidence : ConfidenceValue;
    }
    item def Command {
        attribute deviceId : ScalarValues::String;
        attribute actionType : ScalarValues::String;
        attribute targetTemp : TemperatureValue;
        attribute targetIlluminance : IlluminanceValue;
    }
    item def ConfirmationRequest {
        attribute requestMessage : ScalarValues::String;
        attribute proposedPlan : AdaptationPlan;
    }
    item def ConfirmationResponse {
        attribute approved : ScalarValues::Boolean;
    }

    // ---- Port definitions ----
    port def SensorOutPort {
        out item data : SensorData;
    }
    port def SensorInPort {
        in item data : SensorData;
    }
    port def UserContextOutPort {
        out item ctx : UserContext;
    }
    port def UserContextInPort {
        in item ctx : UserContext;
    }
    port def AdaptationPlanOutPort {
        out item plan : AdaptationPlan;
    }
    port def AdaptationPlanInPort {
        in item plan : AdaptationPlan;
    }
    port def CommandInPort {
        in item cmd : Command;
    }
    port def CommandOutPort {
        out item cmd : Command;
    }
    port def FusedContextOutPort {
        out item fctx : FusedContext;
    }
    port def FusedContextInPort {
        in item fctx : FusedContext;
    }
    port def ConfirmationPort {
        in item req : ConfirmationRequest;
        out item resp : ConfirmationResponse;
    }

    // ---- Action definitions ----
    action def FuseAndAnalyze {
        in item raw : SensorData[1..*];
        out item fused : FusedContext;
        first start;
        then action fuse {
            in item inRaw : SensorData[1..*] = raw;
            out item outFused : FusedContext;
        }
        then action inferIntent {
            in item inFused : FusedContext = fuse.outFused;
            out item refined : FusedContext;
        }
        then done;
        bind fused = inferIntent.refined;
    }

    action def GeneratePlan {
        in item fused : FusedContext[1..*];
        in item userCtx : UserContext[1..*];
        out item plan : AdaptationPlan;
        first start;
        then action analyze {
            in item inFused : FusedContext[1..*] = fused;
            in item inCtx : UserContext[1..*] = userCtx;
            out item candidate : AdaptationPlan;
        }
        then action finalize {
            in item c : AdaptationPlan = analyze.candidate;
            out item p : AdaptationPlan;
        }
        then done;
        bind plan = finalize.p;
    }

    // ---- Part definitions ----
    part def ContextSensor {
        port sensorOut : SensorOutPort;
        attribute sensorId : ScalarValues::String;
        attribute samplingRate : FrequencyValue;
    }

    part def TemperatureSensor :> ContextSensor {
        :>> sensorOut : SensorOutPort {
            :>> data : TemperatureData;
        }
    }
    part def LightSensor :> ContextSensor {
        :>> sensorOut : SensorOutPort {
            :>> data : IlluminanceData;
        }
    }
    part def SoundSensor :> ContextSensor {
        :>> sensorOut : SensorOutPort {
            :>> data : SoundData;
        }
    }
    part def OccupancySensor :> ContextSensor {
        :>> sensorOut : SensorOutPort {
            :>> data : OccupancyData;
        }
    }

    part def UserDevice {
        port ctxOut : UserContextOutPort;
        port planIn : AdaptationPlanInPort;
        port confirm : ConfirmationPort;
        attribute deviceId : ScalarValues::String;
        attribute currentActivity : ScalarValues::String;
        attribute proximity : ProximityDistance;
        attribute prefTemp : TemperatureValue;
        attribute prefIlluminance : IlluminanceValue;
        attribute prefNotification : ScalarValues::Boolean;
    }

    part def EdgeProcessor {
        port sensorIn : SensorInPort[1..*];
        port fusedOut : FusedContextOutPort;
        attribute edgeId : ScalarValues::String;
        attribute processingLatency : LatencyValue;
        action fuseAndAnalyze : FuseAndAnalyze;
    }

    part def CloudService {
        port fusedIn : FusedContextInPort[1..*];
        port userCtxIn : UserContextInPort[1..*];
        port planOut : AdaptationPlanOutPort;
        port cmdOut : CommandOutPort;
        attribute serviceId : ScalarValues::String;
        attribute confidenceThreshold : ConfidenceValue;
        action generatePlan : GeneratePlan;
    }

    part def SmartAppliance {
        port cmdIn : CommandInPort;
        attribute applianceId : ScalarValues::String;
    }
    
    part def SmartLight :> SmartAppliance;
    part def SmartThermostat :> SmartAppliance;

    // ---- Connection definitions ----
    connection def SensorToEdge {
        end sensorEnd : ContextSensor;
        end edgeEnd : EdgeProcessor;
        flow sensorEnd.sensorOut.data to edgeEnd.sensorIn.data;
    }
    connection def EdgeToCloud {
        end edgeEnd : EdgeProcessor;
        end cloudEnd : CloudService;
        flow edgeEnd.fusedOut.fctx to cloudEnd.fusedIn.fctx;
    }
    connection def CloudToDevice {
        end cloudEnd : CloudService;
        end deviceEnd : UserDevice;
        flow cloudEnd.planOut.plan to deviceEnd.planIn.plan;
    }
    connection def CloudToAppliance {
        end cloudEnd : CloudService;
        end applianceEnd : SmartAppliance;
        flow cloudEnd.cmdOut.cmd to applianceEnd.cmdIn.cmd;
    }
    connection def UserToCloud {
        end userEnd : UserDevice;
        end cloudEnd : CloudService;
        flow userEnd.ctxOut.ctx to cloudEnd.userCtxIn.ctx;
    }

    // ---- Top-level system assembly ----
    part def UbiquitousSystem {
        attribute systemName : ScalarValues::String;

        part tempSensors : TemperatureSensor[1..*];
        part lightSensors : LightSensor[1..*];
        part soundSensors : SoundSensor[1..*];
        part occupancySensors : OccupancySensor[1..*];

        part userDevices : UserDevice[1..*];
        part smartLights : SmartLight[1..*];
        part smartThermostats : SmartThermostat[1..*];

        part edgeProcessors : EdgeProcessor[1..*];
        part cloudServices : CloudService[1..*];

        connection : SensorToEdge connect tempSensors to edgeProcessors;
        connection : SensorToEdge connect lightSensors to edgeProcessors;
        connection : SensorToEdge connect soundSensors to edgeProcessors;
        connection : SensorToEdge connect occupancySensors to edgeProcessors;

        connection : EdgeToCloud connect edgeProcessors to cloudServices;

        connection : UserToCloud connect userDevices to cloudServices;

        connection : CloudToDevice connect cloudServices to userDevices;
        connection : CloudToAppliance connect cloudServices to smartLights;
        connection : CloudToAppliance connect cloudServices to smartThermostats;
    }

    // ---- State machine for proactive adaptation ----
    state machine def AdaptationStateMachine {
        attribute confidence : ScalarValues::Real;
        attribute confidenceThreshold : ScalarValues::Real = 0.8;
        attribute approved : ScalarValues::Boolean;
        
        initial;
        state Gathering;
        state Processing;
        state Planning;
        state Confirming;
        state Executing;
        
        transition from initial to Gathering;
        transition t1 from Gathering to Processing;
        transition t2 from Processing to Planning;
        transition t3 from Planning to Confirming when confidence < confidenceThreshold;
        transition t4 from Planning to Executing when confidence >= confidenceThreshold;
        transition t5 from Confirming to Executing when approved;
        transition t6 from Executing to Gathering;
    }

    // ---- Requirements ----
    requirement def ProactiveAdaptation {
        doc /** The system shall proactively adapt the environment to user needs without requiring direct interaction. */
        attribute confidenceThreshold : ScalarValues::Real;
        constraint { confidenceThreshold >= 0.8 }
    }

    requirement def SeamlessOperation {
        doc /** Computing shall fade into the background, providing intelligent services transparently. */
        attribute maxLatency : ScalarValues::Real;
        constraint { maxLatency <= 500 }
    }

    requirement def ContextAwareness {
        doc /** The system shall maintain a real-time picture of environmental context using distributed sensors. */
        attribute minSamplingRate : ScalarValues::Real;
        constraint { minSamplingRate >= 1.0 }
    }

    requirement def UserPreferenceTracking {
        doc /** User devices shall track activity, proximity, and saved preferences for adaptation. */
        attribute trackedAttributes : ScalarValues::String;
        constraint { trackedAttributes == "activity, proximity, preferences" }
    }

    requirement def EdgeProcessingRequirement {
        doc /** Edge processors shall fuse sensor data and perform time-sensitive analysis locally. */
        attribute maxEdgeLatency : ScalarValues::Real;
        constraint { maxEdgeLatency <= 50 }
    }

    requirement def CloudDecisionMaking {
        doc /** Cloud services shall analyze data against long-term preferences and decide on adaptation plans. */
        attribute confidenceThreshold : ScalarValues::Real;
        constraint { confidenceThreshold >= 0.85 }
    }

    requirement def CommandExecution {
        doc /** The system shall translate adaptation plans into specific commands for smart devices and appliances. */
        attribute commandTypes : ScalarValues::String;
        constraint { commandTypes == "dim lights, set thermostat" }
    }

    // Requirement usages
    requirement proactiveAdaptation : ProactiveAdaptation;
    requirement seamlessOperation : SeamlessOperation;
    requirement contextAwareness : ContextAwareness;
    requirement userPreferenceTracking : UserPreferenceTracking;
    requirement edgeProcessing : EdgeProcessingRequirement;
    requirement cloudDecisionMaking : CloudDecisionMaking;
    requirement commandExecution : CommandExecution;

    // ---- Requirement satisfaction ----
    part def UbiquitousSystemWithReqs :> UbiquitousSystem {
        satisfy proactiveAdaptation by cloudServices;
        satisfy seamlessOperation by edgeProcessors;
        satisfy contextAwareness by tempSensors;
        satisfy userPreferenceTracking by userDevices;
        satisfy edgeProcessing by edgeProcessors;
        satisfy cloudDecisionMaking by cloudServices;
        satisfy commandExecution by smartLights;

        state machine adaptationSM : AdaptationStateMachine;
    }

    part ubiquitousSystem : UbiquitousSystemWithReqs;
}
