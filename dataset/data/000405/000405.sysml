package CimonAssistantSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    package ItemDefinitions {
        item def VoiceCommand {
            attribute commandText : String;
            attribute timestamp : TimeValue;
            attribute speakerID : String;
        }
        
        item def AudioResponse {
            attribute responseText : String;
            attribute audioData : Real;
            attribute duration : TimeValue;
        }
        
        item def VideoFrame {
            attribute imageData : Real;
            attribute resolutionWidth : Integer;
            attribute resolutionHeight : Integer;
            attribute captureTime : TimeValue;
        }
        
        item def EnvironmentalData {
            attribute oxygenLevel : Real;
            attribute co2Level : Real;
            attribute temperature : TemperatureValue;
            attribute pressure : PressureValue;
            attribute humidity : Real;
        }
        
        item def NavigationCommand {
            attribute targetPosX : LengthValue;
            attribute targetPosY : LengthValue;
            attribute targetPosZ : LengthValue;
            attribute targetOrientX : Real;
            attribute targetOrientY : Real;
            attribute targetOrientZ : Real;
            attribute thrustX : ForceValue;
            attribute thrustY : ForceValue;
            attribute thrustZ : ForceValue;
        }
        
        item def ProcedureStep {
            attribute stepNumber : Integer;
            attribute instruction : String;
            attribute imageReference : String;
            attribute completed : Boolean;
        }
        
        item def PositionData {
            attribute posX : LengthValue;
            attribute posY : LengthValue;
            attribute posZ : LengthValue;
        }
    }
    
    package PortDefinitions {
        port def VoiceInteractionPort {
            in voiceInput : ItemDefinitions::VoiceCommand;
            out audioOutput : ItemDefinitions::AudioResponse;
        }
        
        port def VideoStreamPort {
            out videoFeed : ItemDefinitions::VideoFrame;
        }
        
        port def EnvironmentalSensorPort {
            out environmentalReadings : ItemDefinitions::EnvironmentalData;
        }
        
        port def NavigationControlPort {
            in navigationCmd : ItemDefinitions::NavigationCommand;
            out positionFeedback : ItemDefinitions::PositionData;
        }
        
        port def DataLinkPort {
            inout telemetryData : String;
        }
    }
    
    package ComponentDefinitions {
        part def VoiceRecognitionSystem {
            attribute recognitionAccuracy : Real;
            
            port voicePort : PortDefinitions::VoiceInteractionPort;
            
            action processVoiceInput {
                in rawAudio : ItemDefinitions::VoiceCommand;
                out recognizedCommand : ItemDefinitions::VoiceCommand;
            }
        }
        
        part def AIProcessingCore {
            attribute processingPower : PowerValue;
            attribute memoryCapacity : Real;
            
            action analyzeRequest {
                in command : ItemDefinitions::VoiceCommand;
                out interpretation : String;
            }
            
            action generateResponse {
                in interpretation : String;
                out response : ItemDefinitions::AudioResponse;
            }
            
            action retrieveProcedure {
                in procedureName : String;
                out steps : ItemDefinitions::ProcedureStep;
            }
            
            action monitorEnvironment {
                in envData : ItemDefinitions::EnvironmentalData;
                out alert : ItemDefinitions::AudioResponse;
            }
        }
        
        part def EnvironmentalMonitoringSystem {
            attribute samplingRate : FrequencyValue;
            
            port sensorPort : PortDefinitions::EnvironmentalSensorPort;
            
            action measureEnvironment {
                out readings : ItemDefinitions::EnvironmentalData;
            }
        }
        
        part def VideoDocumentationSystem {
            attribute resolutionWidth : Integer;
            attribute resolutionHeight : Integer;
            attribute frameRate : FrequencyValue;
            
            port videoPort : PortDefinitions::VideoStreamPort;
            
            action captureVideo {
                out frame : ItemDefinitions::VideoFrame;
            }
        }
        
        part def AutonomousNavigationSystem {
            attribute maxThrust : ForceValue;
            attribute positionAccuracy : LengthValue;
            
            port navPort : PortDefinitions::NavigationControlPort;
            
            action calculateTrajectory {
                in targetPosX : LengthValue;
                in targetPosY : LengthValue;
                in targetPosZ : LengthValue;
                in currentPosX : LengthValue;
                in currentPosY : LengthValue;
                in currentPosZ : LengthValue;
                out navCommand : ItemDefinitions::NavigationCommand;
            }
            
            action executeManeuver {
                in navCmd : ItemDefinitions::NavigationCommand;
                out thrustOutputX : ForceValue;
                out thrustOutputY : ForceValue;
                out thrustOutputZ : ForceValue;
            }
        }
        
        part def CommunicationModule {
            attribute bandwidth : Real;
            attribute transmitPower : PowerValue;
            
            port dataLink : PortDefinitions::DataLinkPort;
            
            action transmitData {
                in data : String;
                out status : Boolean;
            }
            
            action receiveData {
                out data : String;
            }
        }
    }
    
    package BehaviorDefinitions {
        action def AssistCrewMember {
            in voiceCmd : ItemDefinitions::VoiceCommand;
            out audioResp : ItemDefinitions::AudioResponse;
            
            first start;
            then action analyze : ComponentDefinitions::AIProcessingCore::analyzeRequest {
                in command = voiceCmd;
                out interpretation : String;
            }
            then action respond : ComponentDefinitions::AIProcessingCore::generateResponse {
                in interpretation = analyze.interpretation;
                out response : ItemDefinitions::AudioResponse;
            }
            then assign audioResp := respond.response;
            then done;
        }
        
        action def MonitorStationEnvironment {
            in envData : ItemDefinitions::EnvironmentalData;
            out alertResponse : ItemDefinitions::AudioResponse;
            
            first start;
            then action checkEnv : ComponentDefinitions::AIProcessingCore::monitorEnvironment {
                in envData = envData;
                out alert : ItemDefinitions::AudioResponse;
            }
            then assign alertResponse := checkEnv.alert;
            then done;
        }
        
        action def NavigateToPosition {
            in targetX : LengthValue;
            in targetY : LengthValue;
            in targetZ : LengthValue;
            in currentX : LengthValue;
            in currentY : LengthValue;
            in currentZ : LengthValue;
            out thrustX : ForceValue;
            out thrustY : ForceValue;
            out thrustZ : ForceValue;
            
            first start;
            then action calcTraj : ComponentDefinitions::AutonomousNavigationSystem::calculateTrajectory {
                in targetPosX = targetX;
                in targetPosY = targetY;
                in targetPosZ = targetZ;
                in currentPosX = currentX;
                in currentPosY = currentY;
                in currentPosZ = currentZ;
                out navCommand : ItemDefinitions::NavigationCommand;
            }
            then action execManeuver : ComponentDefinitions::AutonomousNavigationSystem::executeManeuver {
                in navCmd = calcTraj.navCommand;
                out thrustOutputX : ForceValue;
                out thrustOutputY : ForceValue;
                out thrustOutputZ : ForceValue;
            }
            then assign thrustX := execManeuver.thrustOutputX;
            then assign thrustY := execManeuver.thrustOutputY;
            then assign thrustZ := execManeuver.thrustOutputZ;
            then done;
        }
        
        state def CimonOperationalStates {
            entry; then idle;
            
            state idle {
                entry action initializeSystems;
            }
            
            state listening {
                entry action activateVoiceRecognition;
            }
            
            state processing {
                entry action analyzeInput;
            }
            
            state responding {
                entry action generateResponse;
            }
            
            state monitoring {
                entry action continuousMonitoring;
            }
            
            transition idle_to_listening
                first idle
                accept voiceDetected : ItemDefinitions::VoiceCommand
                then listening;
                
            transition listening_to_processing
                first listening
                accept commandReceived : ItemDefinitions::VoiceCommand
                then processing;
                
            transition processing_to_responding
                first processing
                accept analysisComplete
                then responding;
                
            transition responding_to_monitoring
                first responding
                accept responseDelivered
                then monitoring;
                
            transition monitoring_to_idle
                first monitoring
                accept sessionComplete
                then idle;
                
            transition monitoring_to_listening
                first monitoring
                accept newVoiceDetected : ItemDefinitions::VoiceCommand
                then listening;
        }
    }
    
    part def Cimon {
        doc /* 
            Cimon (Crew Interactive Mobile Companion) is an autonomous 
            AI-powered assistant designed for space station operations.
            Its primary function is to provide interactive assistance to astronauts
            through voice interaction, environmental monitoring, procedure guidance,
            video documentation, and autonomous navigation within the station.
        */
        
        attribute mass : MassValue;
        attribute diameter : LengthValue;
        attribute operatingPower : PowerValue;
        
        part voiceSystem : ComponentDefinitions::VoiceRecognitionSystem;
        part aiCore : ComponentDefinitions::AIProcessingCore;
        part envMonitor : ComponentDefinitions::EnvironmentalMonitoringSystem;
        part videoSystem : ComponentDefinitions::VideoDocumentationSystem;
        part navigation : ComponentDefinitions::AutonomousNavigationSystem;
        part comms : ComponentDefinitions::CommunicationModule;
        
        port crewInterface : PortDefinitions::VoiceInteractionPort;
        port visualInterface : PortDefinitions::VideoStreamPort;
        port environmentalMonitoring : PortDefinitions::EnvironmentalSensorPort;
        port mobilityControl : PortDefinitions::NavigationControlPort;
        port groundLink : PortDefinitions::DataLinkPort;
        
        connect voiceSystem.voicePort to crewInterface;
        connect videoSystem.videoPort to visualInterface;
        connect envMonitor.sensorPort to environmentalMonitoring;
        connect navigation.navPort to mobilityControl;
        connect comms.dataLink to groundLink;
        
        perform action providePrimaryFunction {
            first start;
            then merge awaitInteraction;
            
            action awaitInteraction {
                accept crewRequest : ItemDefinitions::VoiceCommand via crewInterface;
            }
            
            then action assistCrew : BehaviorDefinitions::AssistCrewMember {
                in voiceCmd = awaitInteraction.crewRequest;
                out audioResp : ItemDefinitions::AudioResponse;
            }
            
            then action deliverResponse {
                in response = assistCrew.audioResp;
                send response via crewInterface;
            }
            
            then action monitorContinuously {
                perform envMonitor.measureEnvironment;
                out envReadings : ItemDefinitions::EnvironmentalData;
            }
            
            then action checkEnvironment : BehaviorDefinitions::MonitorStationEnvironment {
                in envData = monitorContinuously.envReadings;
                out alertResponse : ItemDefinitions::AudioResponse;
            }
            
            then decide;
                if checkEnvironment.done then awaitInteraction;
            
            then awaitInteraction;
        }
    }
    
    part cimonInstance : Cimon {
        :>> mass = 5.0[kg];
        :>> diameter = 0.32[m];
        :>> operatingPower = 40.0[W];
        
        perform action assistSpaceStationCrew references providePrimaryFunction;
    }
    
    requirement def CrewAssistanceRequirement {
        doc /* 
            The system shall provide autonomous assistance to crew members 
            through voice interaction and environmental monitoring.
        */
        
        require constraint voiceResponseTime {
            doc /* Response to crew voice commands shall occur within 2 seconds. */
        }
        
        require constraint continuousMonitoring {
            doc /* Environmental monitoring shall operate continuously during active periods. */
        }
        
        require constraint mobilityRange {
            doc /* The system shall maintain autonomous mobility within the station module. */
        }
    }
    
    requirement def SafetyRequirement {
        doc /* 
            The system shall monitor environmental conditions and alert crew 
            to potential hazards.
        */
        
        require constraint airQualityMonitoring {
            doc /* Oxygen and CO2 levels shall be monitored at minimum 1 Hz frequency. */
        }
        
        require constraint collisionAvoidance {
            doc /* The system shall avoid collisions with crew and equipment during movement. */
        }
    }
    
    requirement cimonMissionRequirements {
        doc /* 
            Cimon shall serve as an intelligent, mobile assistant for astronauts 
            aboard space stations, providing voice-interactive support, procedure 
            guidance, environmental monitoring, and companionship during long-duration missions.
        */
        
        subject cimonInstance;
        
        require crewAssistance : CrewAssistanceRequirement;
        require safety : SafetyRequirement;
        
        assume constraint microgravityEnvironment {
            doc /* The system operates in microgravity conditions. */
        }
        
        assume constraint powerAvailability {
            doc /* Station power is available for system operation. */
        }
    }
}
