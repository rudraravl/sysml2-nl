package UbiquitousComputingSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def DeviceIdentifier;
    attribute def UserIdentifier;
    attribute def Timestamp;
    
    attribute def LocationData {
        attribute latitude : Real;
        attribute longitude : Real;
        attribute elevation : ISQ::LengthValue;
    }
    
    attribute def EnvironmentalContext {
        attribute timestamp : Timestamp;
        attribute location : LocationData;
        attribute ambientTemperature : ISQ::ThermodynamicTemperatureValue;
        attribute illuminance : ISQ::IlluminanceValue;
        attribute soundLevel : ISQ::SoundPressureLevelValue;
        attribute occupancyCount : Integer;
    }
    
    attribute def UserContext {
        attribute userID : UserIdentifier;
        attribute currentActivity : String;
        attribute preferences : UserPreferences;
        attribute deviceProximity : ISQ::LengthValue;
    }
    
    attribute def UserPreferences {
        attribute preferredTemperature : ISQ::ThermodynamicTemperatureValue;
        attribute preferredLightLevel : ISQ::IlluminanceValue;
        attribute notificationLevel : Integer;
    }
    
    attribute def AdaptationCommand {
        attribute commandID : String;
        attribute targetDeviceID : DeviceIdentifier;
        attribute actionType : String;
        attribute parameters : Real[*];
    }
    
    port def ContextSensingPort {
        out environmentalData : EnvironmentalContext;
        out userData : UserContext;
    }
    
    port def ServicePort {
        in contextRequest : UserContext;
        out adaptationResponse : AdaptationCommand;
    }
    
    port def ActuationPort {
        in command : AdaptationCommand;
        out status : String;
    }
    
    port def CommunicationPort {
        in dataStream : EnvironmentalContext;
        out processedData : AdaptationCommand;
    }
    
    part def ContextSensor {
        attribute sensorID : DeviceIdentifier;
        attribute samplingRate : ISQ::FrequencyValue;
        port sensingOutput : ContextSensingPort;
        
        action senseEnvironment : CaptureEnvironmentalContext {
            out contextData : EnvironmentalContext;
        }
        
        perform senseEnvironment;
    }
    
    part def UserDevice {
        attribute deviceID : DeviceIdentifier;
        attribute batteryLevel : Real;
        port userInterface : ServicePort;
        port actuationControl : ActuationPort;
        
        action trackUserActivity : MonitorUserBehavior {
            out userContext : UserContext;
        }
        
        action executeAdaptation : ApplyAdaptationCommand {
            in command : AdaptationCommand;
            out executionStatus : String;
        }
    }
    
    part def EdgeProcessor {
        attribute processorID : DeviceIdentifier;
        attribute computeCapacity : ISQ::PowerValue;
        port dataInput : CommunicationPort;
        port commandOutput : ~CommunicationPort;
        
        action aggregateContext : FuseContextData {
            in environmentalContext : EnvironmentalContext[*];
            in userContext : UserContext[*];
            out fusedContext : EnvironmentalContext;
        }
        
        action inferIntent : AnalyzeUserIntent {
            in fusedContext : EnvironmentalContext;
            in userContext : UserContext;
            out inferredIntent : String;
            out confidenceLevel : Real;
        }
    }
    
    part def ContextAwareService {
        attribute serviceID : String;
        attribute serviceType : String;
        port serviceInterface : ~ServicePort;
        
        action analyzeContext : ProcessContextInformation {
            in environmentalContext : EnvironmentalContext;
            in userContext : UserContext;
            out analysisResult : String;
        }
        
        action generateAdaptation : CreateAdaptationStrategy {
            in analysisResult : String;
            in userPreferences : UserPreferences;
            out adaptationPlan : AdaptationCommand[*];
        }
    }
    
    part def InfrastructureLayer {
        part edgeNodes : EdgeProcessor[3..10];
        part cloudServices : ContextAwareService[5..15];
        part networkFabric {
            attribute bandwidth : ISQ::PowerValue;
            attribute latency : ISQ::TimeValue;
        }
        
        action routeData : ManageDataFlow {
            in sourceNode : EdgeProcessor;
            in targetService : ContextAwareService;
            out routingPath : String;
        }
    }
    
    action def CaptureEnvironmentalContext {
        out contextData : EnvironmentalContext;
    }
    
    action def MonitorUserBehavior {
        out userContext : UserContext;
    }
    
    action def ApplyAdaptationCommand {
        in command : AdaptationCommand;
        out executionStatus : String;
    }
    
    action def FuseContextData {
        in environmentalContext : EnvironmentalContext[*];
        in userContext : UserContext[*];
        out fusedContext : EnvironmentalContext;
    }
    
    action def AnalyzeUserIntent {
        in fusedContext : EnvironmentalContext;
        in userContext : UserContext;
        out inferredIntent : String;
        out confidenceLevel : Real;
    }
    
    action def ProcessContextInformation {
        in environmentalContext : EnvironmentalContext;
        in userContext : UserContext;
        out analysisResult : String;
    }
    
    action def CreateAdaptationStrategy {
        in analysisResult : String;
        in userPreferences : UserPreferences;
        out adaptationPlan : AdaptationCommand[*];
    }
    
    action def ManageDataFlow {
        in sourceNode : EdgeProcessor;
        in targetService : ContextAwareService;
        out routingPath : String;
    }
    
    action def DistributeAdaptations {
        in adaptationPlan : AdaptationCommand[*];
        out distributionStatus : String[*];
    }
    
    action def GatherContextualInformation {
        out environmentalContexts : EnvironmentalContext[*];
        out userContexts : UserContext[*];
    }
    
    action def DeliverContextAwareServices {
        in environmentalContexts : EnvironmentalContext[*];
        in userContexts : UserContext[*];
        out adaptationCommands : AdaptationCommand[*];
    }
    
    part def UbiquitousComputingEnvironment {
        part sensors : ContextSensor[15..50];
        part devices : UserDevice[30..100];
        part infrastructure : InfrastructureLayer;
    }
    
    part ubiquitousEnvironment : UbiquitousComputingEnvironment {
        part sensors : ContextSensor[15..50] {
            port sensingOutput : ContextSensingPort;
        }
        
        part devices : UserDevice[30..100] {
            port userInterface : ServicePort;
            port actuationControl : ActuationPort;
        }
        
        part infrastructure : InfrastructureLayer {
            part edgeNodes : EdgeProcessor[5..8];
            part cloudServices : ContextAwareService[8..12];
        }
        
        connect sensors.sensingOutput to infrastructure.edgeNodes.dataInput;
        connect devices.userInterface to infrastructure.cloudServices.serviceInterface;
        connect infrastructure.edgeNodes.commandOutput to devices.actuationControl;
        
        perform action provideUbiquitousServices : DeliverContextAwareServices;
    }
    
    action provideUbiquitousServices : DeliverContextAwareServices {
        first start;
        then merge continuousAdaptation;
        
        action collectContext : GatherContextualInformation {
            out environmentalContexts : EnvironmentalContext[*];
            out userContexts : UserContext[*];
        }
        
        then action fuseData : FuseContextData {
            in environmentalContext = collectContext.environmentalContexts;
            in userContext = collectContext.userContexts;
            out fusedContext : EnvironmentalContext;
        }
        
        then action analyzeIntent : AnalyzeUserIntent {
            in fusedContext = fuseData.fusedContext;
            in userContext = collectContext.userContexts[1];
            out inferredIntent : String;
            out confidenceLevel : Real;
        }
        
        then decide adaptationDecision;
            if analyzeIntent.confidenceLevel >= 0.75 then proceedWithAdaptation;
            if analyzeIntent.confidenceLevel < 0.75 then requestUserConfirmation;
        
        action proceedWithAdaptation {
            first action processContext : ProcessContextInformation {
                in environmentalContext = fuseData.fusedContext;
                in userContext = collectContext.userContexts[1];
                out analysisResult : String;
            }
            
            then action createStrategy : CreateAdaptationStrategy {
                in analysisResult = processContext.analysisResult;
                in userPreferences = collectContext.userContexts[1].preferences;
                out adaptationPlan : AdaptationCommand[*];
            }
            
            then action distributeCommands : DistributeAdaptations {
                in adaptationPlan = createStrategy.adaptationPlan;
                out distributionStatus : String[*];
            }
        }
        
        action requestUserConfirmation {
            out confirmationRequest : String;
        }
        
        then continuousAdaptation;
    }
    
    connection def ContextDataFlow {
        end source : ContextSensingPort;
        end target : CommunicationPort;
    }
    
    connection def ServiceFlow {
        end source : ServicePort;
        end target : ~ServicePort;
    }
    
    connection def CommandFlow {
        end source : ~CommunicationPort;
        end target : ActuationPort;
    }
    
    requirement def UbiquitousComputingCapability {
        doc /* The ubiquitous computing system shall provide seamless, context-aware 
               computing services that transparently adapt to user needs and environmental 
               conditions across a distributed network of embedded devices and sensors, 
               enabling computing to fade into the background of everyday activities. */
        
        require transparentIntegration : TransparentIntegration;
        require contextAwareness : ContextAwareness;
        require proactiveAdaptation : ProactiveAdaptation;
        require scalableInfrastructure : ScalableInfrastructure;
    }
    
    requirement transparentIntegration : TransparentIntegration {
        doc /* Computing devices and services shall integrate seamlessly into the 
               physical environment, operating without requiring explicit user attention 
               or manual configuration. */
    }
    
    requirement contextAwareness : ContextAwareness {
        doc /* The system shall continuously sense, interpret, and respond to 
               environmental conditions, user activities, and social context to 
               provide relevant services. */
        
        assume constraint accurateSensing {
            doc /* Environmental sensors must provide accurate readings with 
                   measurement uncertainty less than 5%. */
        }
        
        assume constraint timelyDataCollection {
            doc /* Context data must be collected and processed with latency 
                   less than 500 milliseconds. */
        }
    }
    
    requirement proactiveAdaptation : ProactiveAdaptation {
        doc /* The system shall anticipate user needs and proactively adapt 
               services and device behaviors based on learned patterns and 
               inferred intent. */
        
        require constraint minimumConfidence {
            doc /* Proactive adaptations shall only be executed when intent 
                   inference confidence exceeds 75%. */
        }
    }
    
    requirement scalableInfrastructure : ScalableInfrastructure {
        doc /* The infrastructure shall support dynamic scaling from tens to 
               hundreds of devices while maintaining service quality. */
        
        require constraint deviceCapacity {
            doc /* The system shall support at least 30 concurrent user devices 
                   and 15 environmental sensors. */
        }
    }
    
    requirement <'UC-SYS-001'> systemRequirement : UbiquitousComputingCapability {
        subject ubiquitousEnvironment;
        
        assume constraint minimumDeployment {
            doc /* At least 15 sensors and 30 user devices must be deployed 
                   for effective ubiquitous computing coverage. */
        }
        
        assume constraint networkConnectivity {
            doc /* Network infrastructure must provide 99.5% uptime and support 
                   minimum 100 Mbps data rate. */
        }
        
        require constraint adaptationLatency {
            doc /* End-to-end latency from context sensing to device adaptation 
                   shall not exceed 2 seconds under normal operating conditions. */
        }
        
        require constraint serviceAvailability {
            doc /* Context-aware services shall maintain 99.9% availability 
                   during operational hours. */
        }
        
        require constraint userPrivacy {
            doc /* User context data shall be anonymized and encrypted before 
                   transmission beyond edge processing nodes. */
        }
    }
}
