package DynaliteSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def ChannelAddress :> Integer;
    attribute def DimLevel :> Real;
    attribute def SceneNumber :> Integer;
    attribute def OccupancyState :> Boolean;
    attribute def LuxReading :> Real;
    
    attribute def BrightnessLevel :> Real;
    
    item def ControlMessage {
        attribute targetChannel : ChannelAddress;
        attribute commandLevel : BrightnessLevel;
        attribute fadeTime : TimeValue;
    }
    
    item def SensorReading {
        attribute occupancyDetected : OccupancyState;
        attribute lightLevel : LuxReading;
        attribute timestamp : TimeValue;
    }
    
    item def PowerSupply {
        attribute voltage : ISQ::VoltageValue;
        attribute current : ISQ::ElectricCurrentValue;
        attribute frequency : ISQ::FrequencyValue;
    }
    
    port def ControlBusPort {
        in item commandReceived : ControlMessage;
        out item commandSent : ControlMessage;
        out item statusUpdate : ControlMessage;
    }
    
    port def PowerInputPort {
        in item power : PowerSupply;
    }
    
    port def LoadOutputPort {
        out item controlledPower : PowerSupply;
    }
    
    port def SensorInputPort {
        in item sensorData : SensorReading;
    }
    
    part def DynaliteNetworkController {
        attribute controllerAddress : ChannelAddress;
        attribute activeSceneId : SceneNumber;
        
        port networkBus : ControlBusPort;
        port sensorInput : SensorInputPort;
        
        perform action processNetworkCommands;
        perform action executeSceneRecall;
    }
    
    part def DynaliteChannelRelay {
        attribute channelId : ChannelAddress;
        attribute currentOutputLevel : BrightnessLevel;
        attribute maximumLoad : PowerValue;
        
        port powerInput : PowerInputPort;
        port controlBus : ControlBusPort;
        port loadOutput : LoadOutputPort;
        
        perform action adjustOutputLevel;
    }
    
    part def MotionSensor {
        attribute detectionRadius : LengthValue;
        attribute timeoutDuration : TimeValue;
        
        port dataOutput : SensorInputPort;
        
        perform action monitorOccupancy;
    }
    
    part def PhotocellSensor {
        attribute measurementRange : LuxReading;
        attribute calibrationFactor : Real;
        
        port dataOutput : SensorInputPort;
        
        perform action measureLightLevel;
    }
    
    part def LightingFixture {
        attribute ratedPower : PowerValue;
        attribute currentBrightness : BrightnessLevel;
        
        port powerConnection : LoadOutputPort;
    }
    
    action def ProcessControlCommand {
        in receivedCommand : ControlMessage;
        in currentLevel : BrightnessLevel;
        out updatedLevel : BrightnessLevel;
        out relayCommand : ControlMessage;
    }
    
    action def AnalyzeSensorInputs {
        in occupancyStatus : OccupancyState;
        in ambientLightLevel : LuxReading;
        in currentScene : SceneNumber;
        out generatedCommand : ControlMessage;
    }
    
    action def ModulateOutput {
        in desiredLevel : BrightnessLevel;
        in presentLevel : BrightnessLevel;
        in transitionTime : TimeValue;
        out modulatedPower : PowerSupply;
    }
    
    action def RecallLightingScene {
        in sceneId : SceneNumber;
        out channelSettings : BrightnessLevel[*];
    }
    
    action def AutomatedLightingOperation {
        in environmentalData : SensorReading;
        in programmedScene : SceneNumber;
        out controlCommands : ControlMessage[*];
        
        first start;
        then action analyzeSensors : AnalyzeSensorInputs {
            in occupancyStatus = environmentalData.occupancyDetected;
            in ambientLightLevel = environmentalData.lightLevel;
            in currentScene = programmedScene;
            out generatedCommand;
        }
        then decide;
            if analyzeSensors.generatedCommand != null then executeCommand;
            else continueMonitoring;
        action executeCommand : ProcessControlCommand {
            in receivedCommand = analyzeSensors.generatedCommand;
            in currentLevel;
            out updatedLevel;
            out relayCommand;
        }
        then action modulateLoad : ModulateOutput {
            in desiredLevel = executeCommand.updatedLevel;
            in presentLevel;
            in transitionTime;
            out modulatedPower;
        }
        then continueMonitoring;
        merge continueMonitoring;
        then done;
    }
    
    part dynaliteControlSystem : DynaliteNetworkController {
        doc /* 
            The Dynalite system is a sophisticated distributed lighting control platform 
            that provides intelligent automation and management of building illumination. 
            Its primary function is to orchestrate lighting across multiple zones by 
            integrating networked controllers, relay modules, and environmental sensors 
            to automatically adjust lighting levels based on occupancy detection, daylight 
            harvesting, and user-programmed scenes, while enabling centralized monitoring, 
            scheduling, and energy optimization throughout the facility.
        */
        
        attribute systemAddress : ChannelAddress = 1;
        attribute defaultScene : SceneNumber = 1;
        
        part centralController : DynaliteNetworkController {
            attribute controllerAddress = 1;
            perform action sceneManagement : RecallLightingScene;
            perform action commandProcessing : ProcessControlCommand;
        }
        
        part channelRelay1 : DynaliteChannelRelay {
            attribute channelId = 1;
            attribute maximumLoad = 2400[W];
            perform action outputControl : ModulateOutput;
        }
        
        part channelRelay2 : DynaliteChannelRelay {
            attribute channelId = 2;
            attribute maximumLoad = 2400[W];
            perform action outputControl : ModulateOutput;
        }
        
        part channelRelay3 : DynaliteChannelRelay {
            attribute channelId = 3;
            attribute maximumLoad = 1800[W];
            perform action outputControl : ModulateOutput;
        }
        
        part channelRelay4 : DynaliteChannelRelay {
            attribute channelId = 4;
            attribute maximumLoad = 1800[W];
            perform action outputControl : ModulateOutput;
        }
        
        part motionDetector1 : MotionSensor {
            attribute detectionRadius = 10[m];
            attribute timeoutDuration = 600[s];
        }
        
        part lightSensor1 : PhotocellSensor {
            attribute measurementRange = 2000.0;
            attribute calibrationFactor = 1.0;
        }
        
        part fixture1 : LightingFixture {
            attribute ratedPower = 600[W];
        }
        
        part fixture2 : LightingFixture {
            attribute ratedPower = 600[W];
        }
        
        part fixture3 : LightingFixture {
            attribute ratedPower = 450[W];
        }
        
        part fixture4 : LightingFixture {
            attribute ratedPower = 450[W];
        }
        
        connect centralController.networkBus to channelRelay1.controlBus;
        connect centralController.networkBus to channelRelay2.controlBus;
        connect centralController.networkBus to channelRelay3.controlBus;
        connect centralController.networkBus to channelRelay4.controlBus;
        
        connect motionDetector1.dataOutput to centralController.sensorInput;
        connect lightSensor1.dataOutput to centralController.sensorInput;
        
        connect channelRelay1.loadOutput to fixture1.powerConnection;
        connect channelRelay2.loadOutput to fixture2.powerConnection;
        connect channelRelay3.loadOutput to fixture3.powerConnection;
        connect channelRelay4.loadOutput to fixture4.powerConnection;
        
        perform action automatedOperation : AutomatedLightingOperation {
            in environmentalData;
            in programmedScene = defaultScene;
            out controlCommands;
        }
    }
    
    requirement def LightingAutomationRequirement {
        doc /* The system shall provide comprehensive automated lighting control responsive to environmental conditions. */
        
        require constraint occupancyResponseTime {
            doc /* The system shall activate lighting within 500 milliseconds of occupancy detection. */
        }
        
        require constraint daylightCompensation {
            doc /* The system shall proportionally dim artificial lighting based on available natural daylight. */
        }
        
        require constraint sceneConsistency {
            doc /* The system shall synchronize all channels when recalling predefined lighting scenes. */
        }
    }
    
    requirement def SystemPerformanceRequirement {
        doc /* The Dynalite system shall maintain reliable and precise operation under all conditions. */
        
        require constraint outputAccuracy {
            doc /* The system shall regulate channel output within plus or minus 1 percent of commanded level. */
        }
        
        require constraint networkReliability {
            doc /* Control bus communication shall maintain error rate below 0.001 percent. */
        }
        
        require constraint loadProtection {
            doc /* The system shall prevent overload conditions by limiting output to rated channel capacity. */
        }
    }
    
    requirement systemFunctionalRequirements {
        subject dynaliteControlSystem;
        
        require LightingAutomationRequirement;
        require SystemPerformanceRequirement;
    }
}
