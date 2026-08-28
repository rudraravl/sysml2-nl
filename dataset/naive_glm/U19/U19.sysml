package CIMON {

    import ScalarValues::*;
    import ISQ::*;
    import ISQSpace::*;
    import ISQTemperature::*;
    import ISQPressure::*;
    import ISQVolume::*;
    import ISQTime::*;

    // ---------- Value types with units ----------

    value def Percentage :> Real {
        unit '%';
    }

    value def OxygenConcentration :> Real {
        unit '%';
    }

    value def CO2Concentration :> Real {
        unit '%';
    }

    value def TemperatureValue :> Real {
        unit 'K';
    }

    value def PressureValue :> Real {
        unit 'Pa';
    }

    value def HumidityValue :> Real {
        unit '%';
    }

    value def SoundLevel :> Real {
        unit 'dB';
    }

    value def Distance :> Real {
        unit 'm';
    }

    value def Velocity :> Real {
        unit 'm/s';
    }

    value def Thrust :> Real {
        unit 'N';
    }

    value def DataRate :> Real {
        unit 'bit/s';
    }

    // ---------- Item definitions ----------

    item def VoiceCommand {
        attribute text : String;
        attribute timestamp : TimeValue;
    }

    item def VoiceResponse {
        attribute text : String;
        attribute language : String;
        attribute duration : TimeValue;
    }

    item def VideoFrame {
        attribute resolution : String;
        attribute timestamp : TimeValue;
        attribute encoded : Boolean;
    }

    item def EnvironmentalSample {
        attribute oxygen : OxygenConcentration;
        attribute co2 : CO2Concentration;
        attribute temperature : TemperatureValue;
        attribute pressure : PressureValue;
        attribute humidity : HumidityValue;
        attribute timestamp : TimeValue;
    }

    item def HazardAlert {
        attribute severity : String;
        attribute description : String;
        attribute timestamp : TimeValue;
    }

    item def NavigationGoal {
        attribute targetX : Distance;
        attribute targetY : Distance;
        attribute targetZ : Distance;
        attribute priority : Integer;
    }

    item def ThrusterCommand {
        attribute thrustX : Thrust;
        attribute thrustY : Thrust;
        attribute thrustZ : Thrust;
        attribute duration : TimeValue;
    }

    item def TelemetryPacket {
        attribute source : String;
        attribute payload : String;
        attribute timestamp : TimeValue;
    }

    item def ProcedureDocument {
        attribute title : String;
        attribute content : String;
        attribute experimentId : String;
    }

    // ---------- Port definitions ----------

    port def AudioInPort {
        in item voiceCommand : VoiceCommand;
    }

    port def AudioOutPort {
        out item voiceResponse : VoiceResponse;
        out item hazardAlert : HazardAlert;
    }

    port def VideoPort {
        out item videoFrame : VideoFrame;
    }

    port def EnvironmentalPort {
        out item environmentalSample : EnvironmentalSample;
    }

    port def NavigationCommandPort {
        in item navigationGoal : NavigationGoal;
        out item thrusterCommand : ThrusterCommand;
    }

    port def DataLinkPort {
        out item telemetry : TelemetryPacket;
        in item groundCommand : String;
    }

    port def InternalCommandPort {
        out item procedureRequest : String;
        in item procedureDocument : ProcedureDocument;
    }

    // ---------- Subsystem part definitions ----------

    part def AIProcessingCore {
        attribute processingLoad : Percentage = 0;
        attribute safeOxygenMin : OxygenConcentration = 19.5;
        attribute safeOxygenMax : OxygenConcentration = 23.5;
        attribute safeCO2Max : CO2Concentration = 0.5;
        attribute safeTempMin : TemperatureValue = 291.15;
        attribute safeTempMax : TemperatureValue = 298.15;
        attribute safePressureMin : PressureValue = 99000;
        attribute safePressureMax : PressureValue = 103000;
        attribute safeHumidityMin : HumidityValue = 30;
        attribute safeHumidityMax : HumidityValue = 70;

        port audioIn : AudioInPort;
        port audioOut : AudioOutPort;
        port envIn : EnvironmentalPort;
        port navCmd : NavigationCommandPort;
        port dataLink : DataLinkPort;
        port internalCmd : InternalCommandPort;

        action def InterpretVoiceCommand {
            in command : VoiceCommand;
            out response : VoiceResponse;
            out procedureRequest : String;
        }

        action def EvaluateEnvironment {
            in sample : EnvironmentalSample;
            out alert : HazardAlert[0..1];
        }

        action def GenerateResponse {
            in text : String;
            out response : VoiceResponse;
        }

        action def RetrieveProcedure {
            in request : String;
            out document : ProcedureDocument;
        }

        state def AIProcessingCoreBehavior {
            entry;
            state Standby {
                entry;
                do action listen;
                transition to ProcessingCommand
                    when audioIn.voiceCommand->notEmpty();
            }
            state ProcessingCommand {
                entry;
                do action InterpretVoiceCommand
                    in command = audioIn.voiceCommand
                    out response to audioOut.voiceResponse
                    out procedureRequest to internalCmd.procedureRequest;
                transition to DeliveringResponse
                    when audioOut.voiceResponse->notEmpty();
            }
            state DeliveringResponse {
                entry;
                do action GenerateResponse;
                transition to MonitoringEnvironment
                    when audioOut.voiceResponse->isEmpty();
            }
            state MonitoringEnvironment {
                entry;
                do action EvaluateEnvironment
                    in sample = envIn.environmentalSample
                    out alert to audioOut.hazardAlert;
                transition to ProcessingCommand
                    when audioIn.voiceCommand->notEmpty();
            }
        }

        exhibit AIProcessingCoreBehavior;
    }

    part def VoiceRecognitionSystem {
        attribute active : Boolean = true;
        attribute sensitivity : SoundLevel = 50;

        port audioOut : AudioInPort;
        port speakerOut : AudioOutPort;

        action def CaptureAudio {
            out command : VoiceCommand;
        }

        action def SynthesizeSpeech {
            in response : VoiceResponse;
        }

        state def VoiceRecognitionBehavior {
            state Listening {
                do action CaptureAudio out command to audioOut.voiceCommand;
                transition to Idle when audioOut.voiceCommand->notEmpty();
            }
            state Idle {
                transition to Listening when audioOut.voiceCommand->isEmpty();
            }
        }

        exhibit VoiceRecognitionBehavior;
    }

    part def VideoDocumentationSystem {
        attribute resolution : String = "1280x720";
        attribute frameRate : Integer = 30;
        attribute recording : Boolean = false;

        port videoOut : VideoPort;

        action def CaptureFrame {
            out frame : VideoFrame;
        }

        action def StreamVideo {
            do action CaptureFrame out frame to videoOut.videoFrame;
        }

        state def VideoDocumentationBehavior {
            state Streaming {
                do action StreamVideo;
            }
        }

        exhibit VideoDocumentationBehavior;
    }

    part def AutonomousNavigationSystem {
        attribute maxVelocity : Velocity = 0.5;
        attribute collisionAvoidanceEnabled : Boolean = true;
        attribute currentX : Distance = 0;
        attribute currentY : Distance = 0;
        attribute currentZ : Distance = 0;

        port navCmd : NavigationCommandPort;

        action def CalculateTrajectory {
            in goal : NavigationGoal;
            out command : ThrusterCommand;
        }

        action def AvoidCollision {
            in obstacleDistance : Distance;
            out command : ThrusterCommand;
        }

        state def NavigationBehavior {
            state Idle {
                transition to Navigating when navCmd.navigationGoal->notEmpty();
            }
            state Navigating {
                do action CalculateTrajectory
                    in goal = navCmd.navigationGoal
                    out command to navCmd.thrusterCommand;
                transition to Idle when navCmd.navigationGoal->isEmpty();
            }
        }

        exhibit NavigationBehavior;
    }

    part def EnvironmentalMonitoringSystem {
        attribute samplingInterval : TimeValue = 1.0;

        port envOut : EnvironmentalPort;

        action def SampleAtmosphere {
            out sample : EnvironmentalSample;
        }

        state def EnvironmentalMonitoringBehavior {
            state Sampling {
                do action SampleAtmosphere out sample to envOut.environmentalSample;
            }
        }

        exhibit EnvironmentalMonitoringBehavior;
    }

    part def CommunicationModule {
        attribute uplinkRate : DataRate = 1000000;
        attribute downlinkRate : DataRate = 500000;
        attribute connected : Boolean = true;

        port dataLink : DataLinkPort;

        action def TransmitTelemetry {
            in packet : TelemetryPacket;
        }

        action def ReceiveGroundCommand {
            out command : String;
        }

        state def CommunicationBehavior {
            state Connected {
                do action TransmitTelemetry in packet = dataLink.telemetry;
                do action ReceiveGroundCommand out command to dataLink.groundCommand;
            }
        }

        exhibit CommunicationBehavior;
    }

    part def ThrusterAssembly {
        attribute thrustRating : Thrust = 0.5;
        port commandIn : NavigationCommandPort;

        action def ApplyThrust {
            in command : ThrusterCommand;
        }

        state def ThrusterBehavior {
            state Ready {
                do action ApplyThrust in command = commandIn.thrusterCommand;
            }
        }

        exhibit ThrusterBehavior;
    }

    // ---------- Top-level CIMON assembly ----------

    part def CIMON {
        attribute serialNumber : String = "CIMON-001";
        attribute firmwareVersion : String = "2.4.0";
        attribute missionName : String = "ISS-Crew-Assist";

        part aiCore : AIProcessingCore;
        part voiceSystem : VoiceRecognitionSystem;
        part videoSystem : VideoDocumentationSystem;
        part navigationSystem : AutonomousNavigationSystem;
        part environmentalSystem : EnvironmentalMonitoringSystem;
        part communicationModule : CommunicationModule;
        part thrusters : ThrusterAssembly;

        connection def AudioCommandFlow connect voiceSystem.audioOut to aiCore.audioIn;
        connection def AudioResponseFlow connect aiCore.audioOut to voiceSystem.speakerOut;
        connection def EnvironmentalDataFlow connect environmentalSystem.envOut to aiCore.envIn;
        connection def NavigationCommandFlow connect aiCore.navCmd to navigationSystem.navCmd;
        connection def ThrusterCommandFlow connect navigationSystem.navCmd to thrusters.commandIn;
        connection def TelemetryFlow connect aiCore.dataLink to communicationModule.dataLink;
        connection def VideoFeedFlow connect videoSystem.videoOut to communicationModule.dataLink;

        // Operational state machine for CIMON as a whole
        state def CIMONOperationalStates {
            state PoweredOff {
                transition to StandbyMode when true;
            }
            state StandbyMode {
                entry;
                transition to ProcessingRequest
                    when aiCore.audioIn.voiceCommand->notEmpty();
            }
            state ProcessingRequest {
                entry;
                transition to Responding when aiCore.audioOut.voiceResponse->notEmpty();
            }
            state Responding {
                entry;
                transition to ContinuousMonitoring when aiCore.audioOut.voiceResponse->isEmpty();
            }
            state ContinuousMonitoring {
                entry;
                transition to ProcessingRequest
                    when aiCore.audioIn.voiceCommand->notEmpty();
                transition to Alerting
                    when aiCore.audioOut.hazardAlert->notEmpty();
            }
            state Alerting {
                entry;
                transition to ContinuousMonitoring when aiCore.audioOut.hazardAlert->isEmpty();
            }
        }

        exhibit CIMONOperationalStates;
    }

    // ---------- Requirements ----------

    requirement def VoiceInteractionRequirement {
        subject cimon : CIMON;
        objective {
            doc /* CIMON shall recognize spoken crew commands and respond with synthesized speech. */
        }
        assume cimon.voiceSystem.active == true;
        require cimon.aiCore.audioIn.voiceCommand->notEmpty() implies
                cimon.aiCore.audioOut.voiceResponse->notEmpty();
    }

    requirement def EnvironmentalSafetyRequirement {
        subject cimon : CIMON;
        objective {
            doc /* CIMON shall generate an audible alert when environmental readings exceed safe limits. */
        }
        require cimon.aiCore.envIn.environmentalSample.oxygen < cimon.aiCore.safeOxygenMin or
                cimon.aiCore.envIn.environmentalSample.oxygen > cimon.aiCore.safeOxygenMax or
                cimon.aiCore.envIn.environmentalSample.co2 > cimon.aiCore.safeCO2Max or
                cimon.aiCore.envIn.environmentalSample.temperature < cimon.aiCore.safeTempMin or
                cimon.aiCore.envIn.environmentalSample.temperature > cimon.aiCore.safeTempMax or
                cimon.aiCore.envIn.environmentalSample.pressure < cimon.aiCore.safePressureMin or
                cimon.aiCore.envIn.environmentalSample.pressure > cimon.aiCore.safePressureMax or
                cimon.aiCore.envIn.environmentalSample.humidity < cimon.aiCore.safeHumidityMin or
                cimon.aiCore.envIn.environmentalSample.humidity > cimon.aiCore.safeHumidityMax
                implies cimon.aiCore.audioOut.hazardAlert->notEmpty();
    }

    requirement def AutonomousMobilityRequirement {
        subject cimon : CIMON;
        objective {
            doc /* CIMON shall navigate to specified locations without colliding with crew or equipment. */
        }
        require cimon.navigationSystem.collisionAvoidanceEnabled == true;
        require cimon.navigationSystem.navCmd.navigationGoal->notEmpty() implies
                cimon.navigationSystem.navCmd.thrusterCommand->notEmpty();
    }

    requirement def VideoDocumentationRequirement {
        subject cimon : CIMON;
        objective {
            doc /* CIMON shall provide a live video feed for procedure documentation and ground control. */
        }
        require cimon.videoSystem.videoOut.videoFrame->notEmpty();
    }

    requirement def GroundCommunicationRequirement {
        subject cimon : CIMON;
        objective {
            doc /* CIMON shall transmit telemetry to ground control via the communication module. */
        }
        require cimon.communicationModule.connected == true;
        require cimon.aiCore.dataLink.telemetry->notEmpty() implies
                cimon.communicationModule.dataLink.telemetry->notEmpty();
    }

    requirement def OperationalStateRequirement {
        subject cimon : CIMON;
        objective {
            doc /* CIMON shall transition through standby, processing, responding, and monitoring states. */
        }
        require cimon.CIMONOperationalStates.StandbyMode->isActive() or
                cimon.CIMONOperationalStates.ProcessingRequest->isActive() or
                cimon.CIMONOperationalStates.Responding->isActive() or
                cimon.CIMONOperationalStates.ContinuousMonitoring->isActive() or
                cimon.CIMONOperationalStates.Alerting->isActive();
    }

    // ---------- Requirement satisfaction ----------

    satisfaction satisfyVoiceInteraction by cimonInstance : CIMON {
        requirement VoiceInteractionRequirement;
    }

    satisfaction satisfyEnvironmentalSafety by cimonInstance : CIMON {
        requirement EnvironmentalSafetyRequirement;
    }

    satisfaction satisfyAutonomousMobility by cimonInstance : CIMON {
        requirement AutonomousMobilityRequirement;
    }

    satisfaction satisfyVideoDocumentation by cimonInstance : CIMON {
        requirement VideoDocumentationRequirement;
    }

    satisfaction satisfyGroundCommunication by cimonInstance : CIMON {
        requirement GroundCommunicationRequirement;
    }

    satisfaction satisfyOperationalState by cimonInstance : CIMON {
        requirement OperationalStateRequirement;
    }

}
