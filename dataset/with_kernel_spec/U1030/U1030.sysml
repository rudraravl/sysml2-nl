package DECTSystem {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;

    attribute def Frequency :> FrequencyValue;
    attribute def BatteryLevel :> Real;
    attribute def HandsetId :> Integer;
    attribute def CallId :> Integer;

    item def VoicePacket {
        attribute callId : CallId;
        attribute timestamp : TimeValue;
    }
    item def ControlMessage {
        attribute messageType : String;
        attribute handsetId : HandsetId;
    }
    item def AnalogAudio;
    item def KeyEvent {
        attribute keyCode : Integer;
    }
    item def DisplayText {
        attribute text : String;
    }
    item def ElectricalPower {
        attribute voltage : ElectricPotentialValue;
        attribute current : ElectricCurrentValue;
    }

    item def RegistrationRequest :> ControlMessage;
    item def RegistrationAck :> ControlMessage;
    item def CallSetupRequest :> ControlMessage;
    item def CallTerminateRequest :> ControlMessage;
    item def RingingSignal :> ControlMessage;
    item def ChannelAllocation :> ControlMessage {
        attribute channelFreq : Frequency;
    }

    port def RadioPort {
        attribute frequency : Frequency;
        out item voiceOut : VoicePacket;
        in item voiceIn : VoicePacket;
        out item controlOut : ControlMessage;
        in item controlIn : ControlMessage;
    }

    port def TelephoneLinePort {
        in item lineIn : AnalogAudio;
        out item lineOut : AnalogAudio;
    }

    port def AudioOutPort {
        out item audio : AnalogAudio;
    }

    port def DataPort {
        out item dataOut : VoicePacket;
        in item dataIn : VoicePacket;
    }

    port def PowerPort {
        out item power : ElectricalPower;
    }

    part def Microphone {
        port audioOut : AudioOutPort;
    }

    part def Speaker {
        port audioIn : ~AudioOutPort;
    }

    part def AudioCodec {
        port micInput : ~AudioOutPort;
        port speakerOutput : AudioOutPort;
        port dataIF : ~DataPort;
        action encode {
            in analog : AnalogAudio;
            out packet : VoicePacket;
        }
        action decode {
            in packet : VoicePacket;
            out analog : AnalogAudio;
        }
    }

    part def RadioTransceiver {
        attribute operatingFrequency : Frequency;
        attribute channelCount : Integer;
        port antennaIF : RadioPort;
        port basebandIF : RadioPort;
        port dataIF : DataPort;
        action tuneChannel {
            in freq : Frequency;
        }
    }

    part def CallController {
        attribute activeCalls : Integer;
        port radioIF : ~RadioPort;
        port lineIF : ~TelephoneLinePort;
        action setupCall {
            in request : CallSetupRequest;
            out allocation : ChannelAllocation;
        }
        action terminateCall {
            in request : CallTerminateRequest;
        }
        action routeVoice {
            in fromLine : AnalogAudio;
            out toRadio : VoicePacket;
        }
    }

    part def RegistrationManager {
        attribute registeredHandsets : HandsetId[0..6];
        port radioIF : ~RadioPort;
        action registerHandset {
            in request : RegistrationRequest;
            out ack : RegistrationAck;
        }
    }

    part def Keypad;
    part def Display;
    part def Ringer;

    part def PowerManager {
        attribute batteryLevel : BatteryLevel;
        attribute lowThreshold : Real = 10.0;
        attribute highThreshold : Real = 20.0;
        port batteryIn : ~PowerPort;
        action monitorBattery {
            out level : BatteryLevel;
        }
    }

    part def Battery {
        attribute capacity : ElectricChargeValue;
        attribute chargeLevel : BatteryLevel;
        port powerOut : PowerPort;
    }

    part def BaseStation {
        attribute maxHandsets : Integer = 6;
        attribute supportedChannels : Integer = 6;

        port telephoneLine : TelephoneLinePort;
        port radio : RadioPort;

        part callController : CallController;
        part registrationManager : RegistrationManager;
        part radioTransceiver : RadioTransceiver;

        connect callController.radioIF to radioTransceiver.basebandIF;
        connect registrationManager.radioIF to radioTransceiver.basebandIF;
        connect callController.lineIF to telephoneLine;
        connect radioTransceiver.antennaIF to radio;

        state baseStationStates {
            entry; then idle;
            state idle;
            state setup;
            state active;

            transition idle_to_setup
                first idle
                accept CallSetupRequest
                then setup;

            transition setup_to_active
                first setup
                accept ChannelAllocation
                then active;

            transition active_to_idle
                first active
                accept CallTerminateRequest
                then idle;
        }
    }

    part def Handset {
        attribute handsetId : HandsetId;
        attribute isRegistered : Boolean = false;
        attribute batteryLevel : BatteryLevel;

        port radio : ~RadioPort;

        part radioTransceiver : RadioTransceiver;
        part audioCodec : AudioCodec;
        part microphone : Microphone;
        part speaker : Speaker;
        part keypad : Keypad;
        part display : Display;
        part ringer : Ringer;
        part powerManager : PowerManager;
        part battery : Battery;

        connect microphone.audioOut to audioCodec.micInput;
        connect audioCodec.speakerOutput to speaker.audioIn;
        connect audioCodec.dataIF to radioTransceiver.dataIF;
        connect radioTransceiver.antennaIF to radio;
        connect battery.powerOut to powerManager.batteryIn;

        state handsetStates {
            entry; then unregistered;
            state unregistered;
            state idle;
            state ringing;
            state active;
            state lowBattery;

            transition unregistered_to_idle
                first unregistered
                accept RegistrationAck
                then idle;

            transition idle_to_ringing
                first idle
                accept RingingSignal
                then ringing;

            transition ringing_to_active
                first ringing
                accept KeyEvent
                then active;

            transition idle_to_active
                first idle
                accept KeyEvent
                then active;

            transition active_to_idle
                first active
                accept KeyEvent
                then idle;

            transition idle_to_lowBattery
                first idle
                when batteryLevel < 10.0
                then lowBattery;

            transition lowBattery_to_idle
                first lowBattery
                when batteryLevel >= 20.0
                then idle;
        }
    }

    connection def RadioLink {
        end baseStationRadio : RadioPort;
        end handsetRadio : ~RadioPort;
    }

    requirement def SecureCommunication {
        doc /* The system shall provide secure wireless voice communication between the base station and handsets. */
    }

    requirement def SupportMultipleHandsets {
        doc /* The base station shall support up to 6 registered handsets simultaneously. */
    }

    requirement def HighQualityVoice {
        doc /* The system shall provide high-quality digitized voice communication with low latency. */
    }

    requirement def BatteryLife {
        doc /* The handset shall monitor battery level and alert the user when below threshold. */
    }

    part dectSystem {
        part baseStation : BaseStation;
        part handset1 : Handset;
        part handset2 : Handset;

        connect baseStation.radio to handset1.radio via RadioLink;
        connect baseStation.radio to handset2.radio via RadioLink;

        satisfy SecureCommunication by baseStation.registrationManager;
        satisfy SupportMultipleHandsets by baseStation;
        satisfy HighQualityVoice by handset1.audioCodec;
        satisfy BatteryLife by handset1.powerManager;
    }
}
