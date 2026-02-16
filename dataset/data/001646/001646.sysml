package Control4HomeAutomationSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    
    attribute def DeviceIdentifier :> String;
    attribute def IPAddress :> String;
    attribute def BrightnessLevel :> Real;
    attribute def TemperatureSetpoint :> ThermodynamicTemperatureValue;
    attribute def VolumeLevel :> Real;
    
    enum def DeviceState {
        offline;
        online;
        standby;
        active;
        error;
    }
    
    enum def LightingState {
        off;
        on;
        dimmed;
    }
    
    enum def HVACMode {
        off;
        heating;
        cooling;
        auto;
    }
    
    enum def SecurityMode {
        disarmed;
        armedHome;
        armedAway;
        triggered;
    }
    
    enum def AudioState {
        stopped;
        playing;
        paused;
    }
    
    item def ControlMessage {
        attribute commandType : String;
        attribute targetDevice : DeviceIdentifier;
        attribute parameters : String;
    }
    
    item def StatusMessage {
        attribute sourceDevice : DeviceIdentifier;
        attribute currentState : DeviceState;
        attribute timestamp : String;
    }
    
    port def NetworkPort {
        attribute address : IPAddress;
        attribute bandwidth : Real;
        out item outgoingMessages : ControlMessage[*];
        in item incomingMessages : StatusMessage[*];
    }
    
    port def DeviceControlPort {
        out item commands : ControlMessage[*];
        in item status : StatusMessage[*];
    }
    
    part def LightingController {
        attribute deviceId : DeviceIdentifier;
        attribute currentBrightness : BrightnessLevel;
        attribute lightState : LightingState;
        
        port controlPort : DeviceControlPort;
        
        state lightingBehavior {
            entry; then offState;
            
            state offState;
            
            transition offToOn
                first offState
                accept turnOnCommand
                then onState;
            
            state onState;
            
            transition onToOff
                first onState
                accept turnOffCommand
                then offState;
            
            transition onToDimmed
                first onState
                accept dimCommand
                then dimmedState;
            
            state dimmedState {
                do action adjustBrightness;
            }
            
            transition dimmedToOn
                first dimmedState
                accept brightenCommand
                then onState;
            
            transition dimmedToOff
                first dimmedState
                accept turnOffCommand
                then offState;
        }
    }
    
    part def ThermostatController {
        attribute deviceId : DeviceIdentifier;
        attribute currentTemperature : TemperatureSetpoint;
        attribute targetTemperature : TemperatureSetpoint;
        attribute hvacMode : HVACMode;
        
        port controlPort : DeviceControlPort;
        
        action def RegulateTemperature {
            in current : TemperatureSetpoint;
            in target : TemperatureSetpoint;
            out mode : HVACMode;
            
            decide;
                if current < target then setHeating;
                if current > target then setCooling;
            
            action setHeating {
                mode = HVACMode::heating;
            }
            
            action setCooling {
                mode = HVACMode::cooling;
            }
        }
    }
    
    part def SecurityPanel {
        attribute deviceId : DeviceIdentifier;
        attribute securityMode : SecurityMode;
        attribute sensorsActive : Integer;
        
        port controlPort : DeviceControlPort;
        
        state securityBehavior {
            entry; then disarmed;
            
            state disarmed;
            
            transition disarmToHome
                first disarmed
                accept armHomeCommand
                then armedHome;
            
            transition disarmToAway
                first disarmed
                accept armAwayCommand
                then armedAway;
            
            state armedHome {
                do action monitorPerimeterSensors;
            }
            
            state armedAway {
                do action monitorAllSensors;
            }
            
            transition homeToDisarm
                first armedHome
                accept disarmCommand
                then disarmed;
            
            transition awayToDisarm
                first armedAway
                accept disarmCommand
                then disarmed;
            
            transition homeToTriggered
                first armedHome
                accept breachDetected
                then triggered;
            
            transition awayToTriggered
                first armedAway
                accept breachDetected
                then triggered;
            
            state triggered {
                do action soundAlarm;
                do action notifyAuthorities;
            }
            
            transition triggeredToDisarm
                first triggered
                accept disarmCommand
                then disarmed;
        }
    }
    
    part def AudioZoneController {
        attribute deviceId : DeviceIdentifier;
        attribute volume : VolumeLevel;
        attribute audioState : AudioState;
        attribute currentSource : String;
        
        port controlPort : DeviceControlPort;
        
        state audioBehavior {
            entry; then stopped;
            
            state stopped;
            
            transition stoppedToPlaying
                first stopped
                accept playCommand
                then playing;
            
            state playing {
                do action streamAudio;
            }
            
            transition playingToPaused
                first playing
                accept pauseCommand
                then paused;
            
            transition playingToStopped
                first playing
                accept stopCommand
                then stopped;
            
            state paused;
            
            transition pausedToPlaying
                first paused
                accept resumeCommand
                then playing;
            
            transition pausedToStopped
                first paused
                accept stopCommand
                then stopped;
        }
    }
    
    part def Control4MainController {
        attribute controllerId : DeviceIdentifier;
        attribute processorLoad : Real;
        attribute connectedDevices : Integer;
        
        port networkInterface : NetworkPort;
        port lightingControl[1..*] : DeviceControlPort;
        port climateControl[1..*] : DeviceControlPort;
        port securityControl : DeviceControlPort;
        port audioControl[1..*] : DeviceControlPort;
        
        action def ProcessAutomationScene {
            in sceneName : String;
            out lightCommands : ControlMessage[*];
            out climateCommands : ControlMessage[*];
            out audioCommands : ControlMessage[*];
            
            decide;
                if sceneName == "GoodMorning" then morningScene;
                if sceneName == "MovieTime" then movieScene;
                if sceneName == "GoodNight" then nightScene;
                if sceneName == "Away" then awayScene;
            
            action morningScene {
                action setLightsOn;
                action setTemperature;
                action playMusic;
            }
            
            action movieScene {
                action dimLights;
                action setAudioTheater;
            }
            
            action nightScene {
                action turnOffLights;
                action lowerTemperature;
                action armSecurity;
            }
            
            action awayScene {
                action turnOffAllLights;
                action setEcoMode;
                action armSecurityAway;
            }
        }
        
        action def MonitorSystemHealth {
            in deviceStatuses : StatusMessage[*];
            out systemHealthy : Boolean;
            
            first start;
            then action checkDevices {
                systemHealthy = true;
            }
            then merge continueMonitoring;
            then action evaluateStatuses;
            then decide;
                if evaluateStatuses.allOnline then healthy;
            
            action healthy {
                systemHealthy = true;
            }
            then continueMonitoring;
        }
    }
    
    part def UserInterface {
        attribute interfaceType : String;
        attribute screenActive : Boolean;
        
        port userInput;
        port displayOutput;
        port controllerConnection : NetworkPort;
    }
    
    part def NetworkSwitch {
        attribute switchId : DeviceIdentifier;
        attribute portCount : Integer;
        
        port uplinkPort : NetworkPort;
        port devicePorts[8] : NetworkPort;
    }
    
    part def Control4HomeSystem {
        attribute systemName : String;
        attribute firmwareVersion : String;
        attribute totalDeviceCount : Integer;
        
        part mainController : Control4MainController {
            attribute :>> controllerId;
            attribute :>> processorLoad;
            attribute :>> connectedDevices;
        }
        
        part networkSwitch : NetworkSwitch {
            attribute :>> portCount = 8;
        }
        
        part touchscreens : UserInterface[3] {
            attribute :>> interfaceType = "Touchscreen";
            attribute :>> screenActive;
        }
        
        part lightingZones : LightingController[8] {
            attribute :>> deviceId;
            attribute :>> currentBrightness;
            attribute :>> lightState;
        }
        
        part thermostats : ThermostatController[3] {
            attribute :>> deviceId;
            attribute :>> currentTemperature;
            attribute :>> targetTemperature;
            attribute :>> hvacMode;
        }
        
        part securitySystem : SecurityPanel {
            attribute :>> deviceId;
            attribute :>> securityMode;
            attribute :>> sensorsActive = 12;
        }
        
        part audioZones : AudioZoneController[6] {
            attribute :>> deviceId;
            attribute :>> volume;
            attribute :>> audioState;
            attribute :>> currentSource;
        }
        
        connection controllerToSwitch connect mainController.networkInterface to networkSwitch.uplinkPort;
        
        perform action automationControl : Control4AutomationBehavior;
    }
    
    action def Control4AutomationBehavior {
        first start;
        then merge mainLoop;
        
        action mainLoop;
        then fork parallelTasks;
        
        action parallelTasks {
            action monitorHealth : Control4MainController::MonitorSystemHealth;
            
            action processUserRequests {
                action receiveInput;
                then action executeScene : Control4MainController::ProcessAutomationScene;
            }
            
            action regulateClimate {
                action checkTemperatures;
                then action adjustHVAC : ThermostatController::RegulateTemperature;
            }
        }
        
        then join synchronize;
        action synchronize;
        then mainLoop;
    }
    
    requirement <'REQ-C4-001'> primarySystemFunction {
        doc /* The Control4 system shall provide centralized, intelligent automation 
             * and control of residential lighting, climate, security, and audio/video 
             * systems through a unified interface and programmable scenes.
             */
        subject system : Control4HomeSystem;
    }
    
    requirement <'REQ-C4-002'> deviceIntegrationCapacity {
        doc /* The system shall support integration and control of at least 20 
             * smart devices across multiple subsystems simultaneously.
             */
        subject system : Control4HomeSystem;
        assert constraint {
            system.totalDeviceCount >= 20
        }
    }
    
    requirement <'REQ-C4-003'> sceneExecutionTime {
        doc /* The system shall execute automation scenes with all device commands 
             * dispatched within 2 seconds of user activation.
             */
        subject controller : Control4HomeSystem::mainController;
    }
    
    requirement <'REQ-C4-004'> systemReliability {
        doc /* The main controller shall maintain operational status with 99.9 percent 
             * uptime during normal operating conditions.
             */
        subject controller : Control4HomeSystem::mainController;
    }
    
    requirement <'REQ-C4-005'> securityResponse {
        doc /* The security subsystem shall detect and respond to breach events 
             * within 500 milliseconds of sensor activation.
             */
        subject security : Control4HomeSystem::securitySystem;
    }
    
    requirement <'REQ-C4-006'> multiZoneAudio {
        doc /* The system shall support independent audio control for at least 
             * 6 separate zones with synchronized playback capability.
             */
        subject audioZones : Control4HomeSystem::audioZones;
        assert constraint {
            audioZones->size() >= 6
        }
    }
    
    requirement <'REQ-C4-007'> userInterfaceAccess {
        doc /* The system shall provide at least 3 touchscreen interfaces for 
             * distributed user access throughout the residence.
             */
        subject interfaces : Control4HomeSystem::touchscreens;
        assert constraint {
            interfaces->size() >= 3
        }
    }
    
    part myControl4Home : Control4HomeSystem {
        attribute :>> systemName = "Residential Automation System";
        attribute :>> firmwareVersion = "3.4.1";
        attribute :>> totalDeviceCount = 26;
    }
    
    satisfy primarySystemFunction by myControl4Home;
    satisfy deviceIntegrationCapacity by myControl4Home;
    satisfy systemReliability by myControl4Home.mainController;
    satisfy securityResponse by myControl4Home.securitySystem;
    satisfy multiZoneAudio by myControl4Home.audioZones;
    satisfy userInterfaceAccess by myControl4Home.touchscreens;
}
