package VoIPSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    item def AnalogVoiceSignal;

    item def VoicePacket {
        attribute sequenceNumber : Integer;
        attribute timestamp : Integer;
        attribute payloadSize : Integer;
    }

    item def CallSetupMessage {
        attribute sourceId : String;
        attribute destinationId : String;
        attribute callId : String;
    }

    item def CallAnswerMessage {
        attribute callId : String;
    }

    item def VoicemailMessage {
        attribute callerId : String;
        attribute mailboxId : String;
        attribute duration : Integer;
        attribute timestamp : String;
    }

    item def VoicemailNotification {
        attribute mailboxId : String;
        attribute messageCount : Integer;
    }

    attribute def RoutingTableEntry {
        attribute extension : String;
        attribute ipAddress : String;
        attribute portNumber : Integer;
    }

    attribute def PowerSpec {
        attribute voltage : ElectricPotentialValue = 48 [V];
        attribute current : ElectricCurrentValueValue = 0.5 [A];
    }

    attribute def AudioQuality {
        attribute samplingRate : FrequencyValue = 8000 [Hz];
        attribute bitDepth : Integer = 8;
    }

    port def EthernetPort {
        in item rxPackets : VoicePacket;
        out item txPackets : VoicePacket;
        in item rxCallSetup : CallSetupMessage;
        out item txCallSetup : CallSetupMessage;
        in item rxCallAnswer : CallAnswerMessage;
        out item txCallAnswer : CallAnswerMessage;
    }

    port def VoicemailPort {
        out item voicemailRequest : CallSetupMessage;
        in item voicemailMessage : VoicemailMessage;
        in item notification : VoicemailNotification;
    }

    port def PowerPort {
        in attribute power : PowerSpec;
    }

    port def HandsetPort {
        out item microphoneAudio : AnalogVoiceSignal;
        in item speakerAudio : AnalogVoiceSignal;
        attribute offHook : Boolean;
    }

    part def TelephoneHandset {
        port handsetIF : HandsetPort;
        attribute isOffHook : Boolean = false;
    }

    part def VoiceCodec {
        attribute audioQuality : AudioQuality;
        port handsetIF : ~HandsetPort;
        port networkIF : EthernetPort;

        action encode {
            in item analog : AnalogVoiceSignal;
            out item digital : VoicePacket;
        }

        action decode {
            in item digital : VoicePacket;
            out item analog : AnalogVoiceSignal;
        }
    }

    part def IPPhone {
        attribute extension : String;
        attribute ipAddress : String;
        port ethernetIF : EthernetPort;
        port powerIn : PowerPort;
        part handset : TelephoneHandset;
        part codec : VoiceCodec;

        connect handset.handsetIF to codec.handsetIF;
        connect codec.networkIF to ethernetIF;

        state def PhoneBehavior {
            state OnHook;
            state OffHook;
            state Dialing;
            state Ringing;
            state Connected;
            state CallEnded;

            transition to OffHook from OnHook when handset.isOffHook == true;
            transition to Dialing from OffHook when true;
            transition to Ringing from Dialing accept CallSetupMessage;
            transition to Connected from Ringing accept CallAnswerMessage;
            transition to CallEnded from Connected when handset.isOffHook == false;
            transition to OnHook from CallEnded when true;
        }

        exhibit PhoneBehavior;
    }

    part def CallManager {
        attribute routingTable : RoutingTableEntry[1..*];
        attribute maxSimultaneousCalls : Integer = 32;
        attribute destinationFound : Boolean;
        port networkIF : EthernetPort;
        port voicemailIF : VoicemailPort;

        action routeCall {
            in item setupMsg : CallSetupMessage;
            out item routedSetup : CallSetupMessage;
        }

        action checkAvailability {
            in item setupMsg : CallSetupMessage;
            out item isAvailable : Boolean;
        }

        action forwardToVoicemail {
            in item setupMsg : CallSetupMessage;
            out item voicemailReq : CallSetupMessage;
        }

        state def CallManagerBehavior {
            state Idle;
            state ProcessingCall;
            state Routing;
            state Forwarding;

            transition to ProcessingCall from Idle accept CallSetupMessage;
            transition to Routing from ProcessingCall when true;
            transition to Idle from Routing when destinationFound == true;
            transition to Forwarding from Routing when destinationFound == false;
            transition to Idle from Forwarding when true;
        }

        exhibit CallManagerBehavior;
    }

    part def VoicemailServer {
        attribute maxMailboxes : Integer = 64;
        port networkIF : EthernetPort;
        port voicemailIF : ~VoicemailPort;

        action recordMessage {
            in item request : CallSetupMessage;
            out item recordedMessage : VoicemailMessage;
        }

        action storeMessage {
            in item message : VoicemailMessage;
        }

        action notifyUser {
            in item message : VoicemailMessage;
            out item notification : VoicemailNotification;
        }

        state def VoicemailBehavior {
            state Idle;
            state Recording;
            state Storing;
            state Notifying;

            transition to Recording from Idle accept CallSetupMessage;
            transition to Storing from Recording when true;
            transition to Notifying from Storing when true;
            transition to Idle from Notifying when true;
        }

        exhibit VoicemailBehavior;
    }

    part def NetworkSwitch {
        attribute portCount : Integer = 24;
        attribute throughput : Integer = 1000000000;
        port devicePorts : ~EthernetPort[1..*];
        port powerIn : PowerPort;

        action forwardPacket {
            in item packet : VoicePacket;
            in item destinationPort : Integer;
        }
    }

    part def PowerSupply {
        attribute inputVoltage : ElectricPotentialValue = 120 [V];
        attribute outputVoltage : ElectricPotentialValue = 48 [V];
        attribute outputCurrent : ElectricCurrentValueValue = 10 [A];
        port powerOut : ~PowerPort[1..*];

        action convertPower {
            in item inputPower : PowerSpec;
            out item outputPower : PowerSpec;
        }
    }

    part def VoIPSystem {
        attribute systemCapacity : Integer = 32;
        attribute supportedUsers : Integer = 64;

        part callManager : CallManager {
            port :>> networkIF;
            port :>> voicemailIF;
        }

        part voicemailServer : VoicemailServer {
            port :>> networkIF;
            port :>> voicemailIF;
        }

        part networkSwitch : NetworkSwitch {
            port :>> devicePorts;
            port :>> powerIn;
        }

        part powerSupply : PowerSupply {
            port :>> powerOut;
        }

        part phones : IPPhone[1..*] {
            port :>> ethernetIF;
            port :>> powerIn;
            part :>> handset;
            part :>> codec;
        }

        connect powerSupply.powerOut to networkSwitch.powerIn;
        connect powerSupply.powerOut to phones.powerIn;
        connect callManager.networkIF to networkSwitch.devicePorts;
        connect voicemailServer.networkIF to networkSwitch.devicePorts;
        connect phones.ethernetIF to networkSwitch.devicePorts;
        connect callManager.voicemailIF to voicemailServer.voicemailIF;
    }

    requirement def SimultaneousCallCapacity {
        attribute minCalls : Integer = 32;
        subject system : VoIPSystem;
        require system.systemCapacity >= minCalls;
    }

    requirement def VoicemailCapacity {
        attribute minMailboxes : Integer = 48;
        subject server : VoicemailServer;
        require server.maxMailboxes >= minMailboxes;
    }

    requirement def VoiceQualityRequirement {
        attribute minSamplingRate : FrequencyValue = 8000 [Hz];
        attribute minBitDepth : Integer = 8;
        subject codec : VoiceCodec;
        require (codec.audioQuality.samplingRate >= minSamplingRate) and (codec.audioQuality.bitDepth >= minBitDepth);
    }

    requirement def SystemReliability {
        attribute minUptimePercent : Real = 99.9;
        subject system : VoIPSystem;
        doc /* The system shall maintain at least 99.9% uptime during business hours. */
    }

    requirement def CallRoutingRequirement {
        subject manager : CallManager;
        doc /* The Call Manager shall route all incoming calls to the correct destination
             based on the routing table. If the destination is unavailable, the call
             shall be forwarded to the Voicemail Server. */
    }

    requirement def PowerConversionRequirement {
        attribute requiredOutputVoltage : ElectricPotentialValue = 48 [V];
        subject supply : PowerSupply;
        require supply.outputVoltage == requiredOutputVoltage;
    }

    part systemInstance : VoIPSystem {
        satisfy SimultaneousCallCapacity by systemInstance;
        satisfy SystemReliability by systemInstance;
        satisfy CallRoutingRequirement by callManager;
        satisfy VoicemailCapacity by voicemailServer;
        satisfy VoiceQualityRequirement by phones.codec;
        satisfy PowerConversionRequirement by powerSupply;
    }
}
