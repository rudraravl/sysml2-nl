package DECT_CordlessPhoneSystem {
    import ScalarValues::*;
    import ISQ::*;

    //------------------------------------------------------------------
    // Value Types
    //------------------------------------------------------------------
    value type Voltage :> Real { unit "V"; }
    value type Frequency :> Real { unit "MHz"; }
    value type DataRate :> Real { unit "kb/s"; }
    value type BatteryLevel :> Real { unit "%"; }
    value type Power :> Real { unit "W"; }
    value type ChannelNumber :> Integer;
    value type HandsetId :> Integer;
    value type CallId :> Integer;

    //------------------------------------------------------------------
    // Item Definitions
    //------------------------------------------------------------------
    item def AudioSignal;

    item def VoiceSample {
        attribute sampleRate : DataRate = 32.0;
        attribute bitsPerSample : Integer = 16;
    }

    item def VoicePacket {
        attribute sequenceNumber : Integer;
        attribute payload : VoiceSample[1..*];
        attribute timestamp : Integer;
    }

    item def ControlMessage {
        attribute messageType : String;
        attribute sourceId : HandsetId;
        attribute destinationId : HandsetId;
    }

    item def RegistrationRequest :> ControlMessage {
        attribute handsetFirmwareVersion : String;
        attribute handsetHardwareId : String;
    }

    item def RegistrationAck :> ControlMessage {
        attribute assignedHandsetId : HandsetId;
        attribute encryptionKey : String;
    }

    item def CallSetupRequest :> ControlMessage {
        attribute dialedNumber : String;
    }

    item def CallAlert :> ControlMessage {
        attribute callerId : String;
    }

    item def ChannelAllocation :> ControlMessage {
        attribute channelNumber : ChannelNumber;
        attribute callId : CallId;
    }

    item def CallTerminate :> ControlMessage {
        attribute callId : CallId;
        attribute reason : String;
    }

    item def DTMFTone {
        attribute digit : String;
    }

    item def KeypadInput {
        attribute key : String;
    }

    item def DisplayMessage {
        attribute text : String;
        attribute line : Integer;
    }

    item def BatteryStatus {
        attribute level : BatteryLevel;
        attribute charging : Boolean;
    }

    //------------------------------------------------------------------
    // Port Definitions
    //------------------------------------------------------------------
    port def RadioPort {
        in item rxControl : ControlMessage;
        out item txControl : ControlMessage;
        in item rxVoice : VoicePacket;
        out item txVoice : VoicePacket;
        attribute operatingFrequency : Frequency = 1880.0;
    }

    port def TelephoneLinePort {
        in item incomingAudio : AudioSignal;
        out item outgoingAudio : AudioSignal;
        in item ringSignal : ControlMessage;
        out item lineStatus : ControlMessage;
    }

    port def AudioInPort {
        in item audio : AudioSignal;
    }

    port def AudioOutPort {
        out item audio : AudioSignal;
    }

    port def KeypadPort {
        in item input : KeypadInput;
    }

    port def DisplayPort {
        out item message : DisplayMessage;
    }

    port def BatteryPort {
        out item status : BatteryStatus;
    }

    port def RingerPort {
        out item ringCommand : ControlMessage;
    }

    //------------------------------------------------------------------
    // Requirement Definitions
    //------------------------------------------------------------------
    requirement def RegistrationRequirement {
        doc "A handset must register with the base station before use."
        subject : Handset;
        objective {
            /* The handset shall establish a secure encrypted link with the base station. */
        }
    }

    requirement def MultiHandsetRequirement {
        doc "The base station shall support up to six registered handsets."
        subject : BaseStation;
        attribute maxHandsets : Integer = 6;
        objective {
            /* The base station shall maintain registration records for up to six handsets simultaneously. */
        }
    }

    requirement def SimultaneousCallRequirement {
        doc "The base station shall support multiple simultaneous calls."
        subject : BaseStation;
        attribute maxSimultaneousCalls : Integer = 4;
        objective {
            /* The base station shall allocate distinct radio channels for each active call. */
        }
    }

    requirement def VoiceQualityRequirement {
        doc "Voice communication shall meet DECT audio quality standards."
        subject : Handset;
        attribute minDataRate : DataRate = 32.0;
        objective {
            /* The audio codec shall digitize and compress voice at no less than 32 kb/s. */
        }
    }

    requirement def LowBatteryRequirement {
        doc "The handset shall warn the user when battery is low."
        subject : Handset;
        attribute lowBatteryThreshold : BatteryLevel = 15.0;
        objective {
            /* The handset shall enter a low-battery warning state and alert the user when battery level falls below the threshold. */
        }
    }

    requirement def StandbyRequirement {
        doc "The handset shall enter standby after registration."
        subject : Handset;
        objective {
            /* The handset shall listen for incoming calls and accept user-initiated call requests while in standby. */
        }
    }

    //------------------------------------------------------------------
    // Part Definitions
    //------------------------------------------------------------------

    part def TelephoneLineInterface {
        port linePort : TelephoneLinePort;
        attribute lineConnected : Boolean = true;

        action def RingDetection :> Action {
            out ringDetected : Boolean;
        }
        action def AudioBypass :> Action {
            in audioIn : AudioSignal;
            out audioOut : AudioSignal;
        }
    }

    part def RadioTransceiver {
        port radioPort : RadioPort;
        attribute channelNumber : ChannelNumber;
        attribute maxChannels : Integer = 60;
        attribute transmitPower : Power = 0.01;

        action def TuneChannel :> Action {
            in channel : ChannelNumber;
        }
        action def Transmit :> Action {
            in control : ControlMessage;
            in voice : VoicePacket;
        }
        action def Receive :> Action {
            out control : ControlMessage;
            out voice : VoicePacket;
        }
    }

    part def CallController {
        port internalRadio : RadioPort;
        port lineInterface : TelephoneLinePort;

        attribute registeredHandsets : HandsetId[0..6];
        attribute activeCalls : CallId[0..4];
        attribute nextCallId : CallId = 1;
        attribute nextHandsetId : HandsetId = 1;

        action def RegisterHandset :> Action {
            in request : RegistrationRequest;
            out ack : RegistrationAck;
        }
        action def SetupCall :> Action {
            in request : CallSetupRequest;
            out allocation : ChannelAllocation;
        }
        action def RouteVoice :> Action {
            in handsetVoice : VoicePacket;
            in lineAudio : AudioSignal;
            out toLine : AudioSignal;
            out toHandset : VoicePacket;
        }
        action def TerminateCall :> Action {
            in terminate : CallTerminate;
        }
        action def AlertHandset :> Action {
            in alert : CallAlert;
            out forwardedAlert : CallAlert;
        }
    }

    part def BaseStation {
        port linePort : TelephoneLinePort;
        port radioPort : RadioPort;

        part lineInterface : TelephoneLineInterface {
            port linePort : TelephoneLinePort;
        }
        part transceiver : RadioTransceiver {
            port radioPort : RadioPort;
        }
        part callController : CallController {
            port internalRadio : RadioPort;
            port lineInterface : TelephoneLinePort;
        }

        satisfy MultiHandsetRequirement {
            subject self;
        }
        satisfy SimultaneousCallRequirement {
            subject self;
        }

        connection lineConn connect lineInterface.linePort to callController.lineInterface;
        connection radioConn connect transceiver.radioPort to callController.internalRadio;
        connection externalLine connect self.linePort to lineInterface.linePort;
        connection externalRadio connect self.radioPort to transceiver.radioPort;
    }

    part def Microphone {
        port audioOut : AudioOutPort;
        action def CaptureAudio :> Action {
            out audio : AudioSignal;
        }
    }

    part def Speaker {
        port audioIn : AudioInPort;
        action def PlayAudio :> Action {
            in audio : AudioSignal;
        }
    }

    part def AudioCodec {
        port micInput : AudioInPort;
        port speakerOutput : AudioOutPort;
        port packetOutput : RadioPort;
        port packetInput : RadioPort;

        attribute sampleRate : DataRate = 32.0;

        action def Encode :> Action {
            in audio : AudioSignal;
            out packet : VoicePacket;
        }
        action def Decode :> Action {
            in packet : VoicePacket;
            out audio : AudioSignal;
        }
    }

    part def Keypad {
        port keypadPort : KeypadPort;
        action def ReadKey :> Action {
            out input : KeypadInput;
        }
    }

    part def Display {
        port displayPort : DisplayPort;
        action def RenderMessage :> Action {
            in message : DisplayMessage;
        }
    }

    part def Ringer {
        port ringerPort : RingerPort;
        action def Ring :> Action {
            in command : ControlMessage;
        }
    }

    part def Battery {
        port batteryPort : BatteryPort;
        attribute capacity : Voltage = 3.6;
        attribute currentLevel : BatteryLevel = 100.0;
        attribute charging : Boolean = false;

        action def Discharge :> Action {
            out status : BatteryStatus;
        }
        action def Charge :> Action {
            out status : BatteryStatus;
        }
    }

    part def PowerManagement {
        port batteryPort : BatteryPort;
        attribute lowThreshold : BatteryLevel = 15.0;

        action def MonitorBattery :> Action {
            in status : BatteryStatus;
            out lowBatteryWarning : Boolean;
        }
    }

    part def Handset {
        port radioPort : RadioPort;

        part transceiver : RadioTransceiver {
            port radioPort : RadioPort;
        }
        part microphone : Microphone {
            port audioOut : AudioOutPort;
        }
        part speaker : Speaker {
            port audioIn : AudioInPort;
        }
        part codec : AudioCodec {
            port micInput : AudioInPort;
            port speakerOutput : AudioOutPort;
            port packetOutput : RadioPort;
            port packetInput : RadioPort;
        }
        part keypad : Keypad {
            port keypadPort : KeypadPort;
        }
        part display : Display {
            port displayPort : DisplayPort;
        }
        part ringer : Ringer {
            port ringerPort : RingerPort;
        }
        part battery : Battery {
            port batteryPort : BatteryPort;
        }
        part powerManagement : PowerManagement {
            port batteryPort : BatteryPort;
        }

        satisfy RegistrationRequirement {
            subject self;
        }
        satisfy VoiceQualityRequirement {
            subject self;
        }
        satisfy LowBatteryRequirement {
            subject self;
        }
        satisfy StandbyRequirement {
            subject self;
        }

        attribute handsetId : HandsetId;
        attribute registered : Boolean = false;

        connection micToCodec connect microphone.audioOut to codec.micInput;
        connection codecToSpeaker connect codec.speakerOutput to speaker.audioIn;
        connection codecToRadio connect codec.packetOutput to transceiver.radioPort;
        connection radioToCodec connect transceiver.radioPort to codec.packetInput;
        connection batteryToPower connect battery.batteryPort to powerManagement.batteryPort;
        connection externalRadio connect self.radioPort to transceiver.radioPort;

        //------------------------------------------------------------------
        // Handset State Machine
        //------------------------------------------------------------------
        state def HandsetStateMachine {
            entry action {
                /* Initialize handset subsystems */
            }

            state Unregistered {
                entry action {
                    /* Handset not yet registered with base station */
                }
                transition to Registering
                    when radioPort.rxControl.~(RegistrationRequest) != null
                    if !registered;
            }

            state Registering {
                entry action {
                    /* Send registration request to base station */
                }
                do action {
                    /* Wait for RegistrationAck from base station */
                }
                transition to Standby
                    when radioPort.rxControl.~(RegistrationAck) != null
                    then action {
                        registered := true;
                        handsetId := radioPort.rxControl.~(RegistrationAck).assignedHandsetId;
                    }
                transition to Unregistered
                    when [timeout 30.0];
            }

            state Standby {
                entry action {
                    /* Listen for incoming calls, await user input */
                }
                transition to Ringing
                    when radioPort.rxControl.~(CallAlert) != null;
                transition to Dialing
                    when keypad.keypadPort.input != null;
                transition to LowBatteryWarning
                    when powerManagement.batteryPort.status.level < 15.0;
            }

            state Ringing {
                entry action {
                    /* Activate ringer and display caller ID */
                    ringer.ringerPort.ringCommand := radioPort.rxControl.~(CallAlert);
                }
                transition to ActiveCall
                    when keypad.keypadPort.input.key == "Answer";
                transition to Standby
                    when keypad.keypadPort.input.key == "Reject";
            }

            state Dialing {
                entry action {
                    /* Collect digits and send CallSetupRequest */
                }
                transition to ActiveCall
                    when radioPort.rxControl.~(ChannelAllocation) != null;
                transition to Standby
                    when keypad.keypadPort.input.key == "Cancel";
            }

            state ActiveCall {
                entry action {
                    /* Dedicated channel allocated; exchange voice packets */
                }
                do action {
                    /* Continuously encode/decode voice and exchange VoicePacket with base station */
                }
                transition to Standby
                    when radioPort.rxControl.~(CallTerminate) != null
                    then action {
                        /* Release channel, return to standby */
                    }
                transition to Standby
                    when keypad.keypadPort.input.key == "EndCall";
                transition to LowBatteryWarning
                    when powerManagement.batteryPort.status.level < 15.0;
            }

            state LowBatteryWarning {
                entry action {
                    /* Display low battery warning, emit audible alert */
                    display.displayPort.message := DisplayMessage { text = "Battery Low", line = 1; };
                }
                transition to Standby
                    when powerManagement.batteryPort.status.level >= 15.0;
                transition to Unregistered
                    when powerManagement.batteryPort.status.level < 5.0;
            }
        }

        exhibit HandsetStateMachine;
    }

    //------------------------------------------------------------------
    // System-Level Part
    //------------------------------------------------------------------
    part def DECTSystem {
        part baseStation : BaseStation;
        part handsets : Handset[1..6];

        connection baseRadio connect baseStation.radioPort to handsets.radioPort;

        requirement constraint {
            /* All handsets shall communicate exclusively through the base station radio interface. */
        }
    }

    //------------------------------------------------------------------
    // Instantiation
    //------------------------------------------------------------------
    part dectSystem : DECTSystem {
        part baseStation : BaseStation;
        part handsets : Handset[3];
    }
}
