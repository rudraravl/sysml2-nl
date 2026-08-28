import ScalarValues::*;

package CIMON_System {
    
    attribute def OxygenLevel :> Real;
    attribute def CO2Level :> Real;
    attribute def Temperature :> Real;
    attribute def Pressure :> Real;
    attribute def Humidity :> Real;
    
    attribute def EnvData {
        o2 : OxygenLevel;
        co2 : CO2Level;
        temp : Temperature;
        pres : Pressure;
        hum : Humidity;
    }
    
    attribute def VoiceCommand { text : String; }
    attribute def AudioResponse { text : String; }
    attribute def VideoFeed { stream : String; }
    attribute def NavigationCommand { target : String; }
    attribute def Telemetry { data : String; }
    
    port def VoiceInPort { in cmd : VoiceCommand; }
    port def VoiceOutPort { out cmd : VoiceCommand; }
    port def AudioOutPort { out audio : AudioResponse; }
    port def AudioInPort { in audio : AudioResponse; }
    port def VideoOutPort { out video : VideoFeed; }
    port def EnvDataOutPort { out data : EnvData; }
    port def EnvDataInPort { in data : EnvData; }
    port def NavCmdOutPort { out cmd : NavigationCommand; }
    port def NavCmdInPort { in cmd : NavigationCommand; }
    port def TelemetryOutPort { out data : Telemetry; }
    port def TelemetryInPort { in data : Telemetry; }
    
    action def Listen;
    action def ProcessCommand;
    action def GenerateResponse;
    action def MonitorEnvironment;
    action def GenerateAlert;
    action def InterpretVoiceCommand;
    action def CalculateTrajectory;
    action def ProcessAndRespond {
        action process : ProcessCommand;
        action respond : GenerateResponse;
    }
    
    part def AIProcessingCore {
        port voiceIn : VoiceInPort;
        port audioOut : AudioOutPort;
        port envDataIn : EnvDataInPort;
        port navCmdOut : NavCmdOutPort;
        port telemetryOut : TelemetryOutPort;
        action interpretVoice : InterpretVoiceCommand;
    }
    
    part def VoiceRecognitionSystem {
        port micIn : VoiceInPort;
        port voiceOut : VoiceOutPort;
        port audioIn : AudioInPort;
        port speakerOut : AudioOutPort;
    }
    
    part def VideoDocumentationSystem {
        port videoOut : VideoOutPort;
    }
    
    part def AutonomousNavigationSystem {
        port navCmdIn : NavCmdInPort;
        action calculateTrajectory : CalculateTrajectory;
    }
    
    part def EnvironmentalMonitoringSystem {
        port envDataOut : EnvDataOutPort;
        attribute oxygenLevel : OxygenLevel;
        attribute co2Level : CO2Level;
        attribute temperature : Temperature;
        attribute pressure : Pressure;
        attribute humidity : Humidity;
    }
    
    part def CommunicationModule {
        port telemetryIn : TelemetryInPort;
        port telemetryOut : TelemetryOutPort;
    }
    
    part def Crew {
        port voiceOut : VoiceOutPort;
        port audioIn : AudioInPort;
    }
    
    part def GroundControl {
        port telemetryIn : TelemetryInPort;
    }
    
    state def CIMONBehavior {
        entry; then Standby;
        state Standby {
            do Listen;
        }
        transition first Standby
            accept cmd : VoiceCommand
            do ProcessAndRespond
            then Monitoring;
        state Monitoring {
            do MonitorEnvironment;
        }
        transition first Monitoring
            accept data : EnvData
            if data.o2 < 19.5 or data.co2 > 5000.0
            do GenerateAlert
            then Monitoring;
        transition first Monitoring
            accept cmd : VoiceCommand
            do ProcessAndRespond
            then Monitoring;
    }
    
    part def CIMON {
        part aiCore : AIProcessingCore;
        part voiceSystem : VoiceRecognitionSystem;
        part videoSystem : VideoDocumentationSystem;
        part navSystem : AutonomousNavigationSystem;
        part envSystem : EnvironmentalMonitoringSystem;
        part commModule : CommunicationModule;
        part crew : Crew;
        part groundControl : GroundControl;
        
        interface crewToVoice connect crew.voiceOut to voiceSystem.micIn;
        interface voiceToAI connect voiceSystem.voiceOut to aiCore.voiceIn;
        interface aiToVoice connect aiCore.audioOut to voiceSystem.audioIn;
        interface voiceToCrew connect voiceSystem.speakerOut to crew.audioIn;
        interface envToAI connect envSystem.envDataOut to aiCore.envDataIn;
        interface aiToNav connect aiCore.navCmdOut to navSystem.navCmdIn;
        interface aiToComm connect aiCore.telemetryOut to commModule.telemetryIn;
        interface commToGround connect commModule.telemetryOut to groundControl.telemetryIn;
        
        exhibit state CIMONBehavior;
    }
    
    requirement def CIMON_Requirements {
        subject cimon : CIMON;
        requirement autonomousOperation {
            doc /* CIMON shall operate autonomously as a free-floating companion. */
        }
        requirement voiceInteraction {
            doc /* CIMON shall process voice commands and generate audible responses. */
        }
        requirement environmentalSafety {
            doc /* CIMON shall monitor environment and alert crew if readings are outside safe limits. */
        }
        requirement autonomousNavigation {
            doc /* CIMON shall navigate autonomously without colliding with crew or equipment. */
        }
    }
}
