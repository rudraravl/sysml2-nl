package BusinessVoIPPlatform {

    import ScalarValues::*;

    // ===== Value Types and Units =====

    value type Voltage :> Real;
    unit volt : Voltage;

    value type Power :> Real;
    unit watt : Power;

    value type Frequency :> Real;
    unit hertz : Frequency;

    value type DataRate :> Real;
    unit megaBitPerSec : DataRate;

    value type Duration :> Real;
    unit second : Duration;

    value type ElectricCurrent :> Real;
    unit ampere : ElectricCurrent;

    value type CallCount :> Integer;
    value type UserCount :> Integer;
    value type ExtensionNumber :> String;

    // ===== Items =====

    item def AudioSignal {
        attribute amplitude : Voltage;
        attribute frequency : Frequency;
    }

    item def DataPacket {
        attribute sourceId : String;
        attribute destId : String;
        attribute payloadSize : Integer;
    }

    item def VoiceDataPacket :> DataPacket {
        attribute sequenceNumber : Integer;
        attribute timestamp : Duration;
        attribute codecType : String;
    }

    item def CallSignalingMessage :> DataPacket {
        attribute messageType : String;
        attribute callingExtension : ExtensionNumber;
        attribute calledExtension : ExtensionNumber;
    }

    item def VoicemailMessage {
        attribute messageId : String;
        attribute mailboxId : String;
        attribute duration : Duration;
        attribute recordingTimestamp : String;
        attribute isRead : Boolean = false;
    }

    item def ElectricalPower {
        attribute voltage : Voltage;
        attribute current : ElectricCurrent;
    }

    // ===== Ports =====

    port def EthernetPort {
        in dataIn : VoiceDataPacket;
        out dataOut : VoiceDataPacket;
        in signalingIn : CallSignalingMessage;
        out signalingOut : CallSignalingMessage;
    }

    port def HandsetAudioPort {
        out micAudio : AudioSignal;
        in speakerAudio : AudioSignal;
    }

    port def PowerPort {
        in power : ElectricalPower;
    }

    // ===== Connections =====

    connection def EthernetLink {
        end a : EthernetPort;
        end b : EthernetPort;
        flow a.dataOut to b.dataIn : VoiceDataPacket;
        flow b.dataOut to a.dataIn : VoiceDataPacket;
        flow a.signalingOut to b.signalingIn : CallSignalingMessage;
        flow b.signalingOut to a.signalingIn : CallSignalingMessage;
    }

    connection def HandsetLink {
        end a : HandsetAudioPort;
        end b : ~HandsetAudioPort;
        flow a.micAudio to b.micAudio : AudioSignal;
        flow b.speakerAudio to a.speakerAudio : AudioSignal;
    }

    connection def PowerLink {
        end source : ~PowerPort;
        end load : PowerPort;
        flow source.power to load.power : ElectricalPower;
    }

    // ===== Parts =====

    part def TelephoneHandset {
        port audioInterface : HandsetAudioPort;
        attribute extension : ExtensionNumber;
        attribute isOffHook : Boolean = false;

        action pickUp() { }
        action hangUp() { }

        state {
            state onHook initial;
            state offHook;
            transition onHook to offHook when isOffHook;
            transition offHook to onHook when !isOffHook;
        }
    }

    part def VoiceCodec {
        port analogSide : HandsetAudioPort;
        port digitalSide : EthernetPort;
        port powerIn : PowerPort;

        attribute sampleRate : Frequency = 8000 [hertz];
        attribute bitRate : DataRate = 0.064 [megaBitPerSec];
        attribute codecType : String = "G.711";

        action encode(in analog : AudioSignal) : VoiceDataPacket { }
        action decode(in digital : VoiceDataPacket) : AudioSignal { }
        action processStream() { }
    }

    part def IPPhone {
        part handset : TelephoneHandset;
        part codec : VoiceCodec;
        port networkPort : EthernetPort;
        port powerIn : PowerPort;

        attribute extension : ExtensionNumber;
        attribute isRegistered : Boolean = false;
        attribute hasIncomingCall : Boolean = false;
        attribute calleeAnswered : Boolean = false;
        attribute noAnswerTimeout : Boolean = false;
        attribute messageComplete : Boolean = false;

        action register() { }
        action dial(called : ExtensionNumber) { }
        action answer() { }
        action endCall() { }
        action playRingingTone() { }

        connection : HandsetLink connect handset.audioInterface to codec.analogSide;
        connection connect codec.digitalSide to networkPort;

        state {
            state idle initial;
            state dialing;
            state ringing;
            state inCall;
            state voicemailForwarded;

            transition idle to dialing when handset.isOffHook;
            transition idle to ringing when hasIncomingCall;
            transition dialing to inCall when calleeAnswered;
            transition dialing to voicemailForwarded when noAnswerTimeout;
            transition ringing to inCall when handset.isOffHook;
            transition ringing to voicemailForwarded when noAnswerTimeout;
            transition inCall to idle when !handset.isOffHook;
            transition voicemailForwarded to idle when messageComplete;
        }
    }

    part def CallManager {
        port networkPort : EthernetPort;
        port powerIn : PowerPort;

        attribute maxSimultaneousCalls : CallCount = 32;
        attribute activeCallCount : CallCount = 0;
        attribute registeredExtensions : ExtensionNumber[*];
        attribute routingTable : ExtensionNumber[*];

        attribute callRequested : Boolean = false;
        attribute calleeAnswered : Boolean = false;
        attribute noAnswerTimeout : Boolean = false;
        attribute hangupDetected : Boolean = false;
        attribute teardownComplete : Boolean = false;
        attribute voicemailComplete : Boolean = false;

        action routeCall(calling : ExtensionNumber, called : ExtensionNumber) : ExtensionNumber { }
        action registerPhone(ext : ExtensionNumber) { }
        action unregisterPhone(ext : ExtensionNumber) { }
        action forwardToVoicemail(ext : ExtensionNumber) { }
        action establishChannel(a : ExtensionNumber, b : ExtensionNumber) { }
        action teardownChannel() { }
        action checkNoAnswerTimeout() { }

        state {
            state idle initial;
            state callSetup;
            state callActive;
            state callTeardown;
            state voicemailForward;

            transition idle to callSetup when callRequested;
            transition callSetup to callActive when calleeAnswered;
            transition callSetup to voicemailForward when noAnswerTimeout;
            transition callActive to callTeardown when hangupDetected;
            transition callTeardown to idle when teardownComplete;
            transition voicemailForward to idle when voicemailComplete;
        }
    }

    part def VoicemailServer {
        port networkPort : EthernetPort;
        port powerIn : PowerPort;

        attribute supportedUsers : UserCount = 60;
        attribute storageCapacityMB : Integer = 50000;
        attribute mailboxes : String[*];
        attribute notificationInterval : Duration = 30 [second];

        attribute callForwarded : Boolean = false;
        attribute callerHungUp : Boolean = false;
        attribute messageStored : Boolean = false;
        attribute notificationSent : Boolean = false;
        attribute userRetrieval : Boolean = false;
        attribute playbackDone : Boolean = false;

        action recordMessage(caller : ExtensionNumber, mailboxId : String) : VoicemailMessage { }
        action storeMessage(msg : VoicemailMessage) { }
        action notifyUser(userId : String) { }
        action playMessage(mailboxId : String) { }
        action deleteMessage(msgId : String) { }
        action markAsRead(msgId : String) { }

        state {
            state idle initial;
            state recording;
            state storing;
            state notifying;
            state playback;

            transition idle to recording when callForwarded;
            transition recording to storing when callerHungUp;
            transition storing to notifying when messageStored;
            transition notifying to idle when notificationSent;
            transition idle to playback when userRetrieval;
            transition playback to idle when playbackDone;
        }
    }

    part def NetworkSwitch {
        port uplinkPorts : EthernetPort[2];
        port switchPorts : EthernetPort[24];
        port powerIn : PowerPort;

        attribute portCount : Integer = 24;
        attribute throughput : DataRate = 1000 [megaBitPerSec];
        attribute switchingCapacity : DataRate = 1000 [megaBitPerSec];
        attribute macAddressTable : String[*];

        attribute hardwareFailure : Boolean = false;
        attribute recoveryDetected : Boolean = false;

        action forwardPacket(pkt : VoiceDataPacket) { }
        action learnMacAddress(portId : Integer, mac : String) { }
        action updateAddressTable() { }

        state {
            state operational initial;
            state fault;
            transition operational to fault when hardwareFailure;
            transition fault to operational when recoveryDetected;
        }
    }

    part def PowerSupply {
        port outputPort : ~PowerPort;

        attribute inputVoltage : Voltage = 120 [volt];
        attribute outputVoltage : Voltage = 48 [volt];
        attribute maxOutputPower : Power = 500 [watt];
        attribute efficiency : Real = 0.85;
        attribute inputFrequency : Frequency = 60 [hertz];

        attribute powerSwitchOn : Boolean = false;
        attribute overloadDetected : Boolean = false;
        attribute manualReset : Boolean = false;

        action convertACtoDC() { }
        action regulateOutput() { }
        action protectOverload() { }

        state {
            state off initial;
            state on;
            state fault;
            transition off to on when powerSwitchOn;
            transition on to fault when overloadDetected;
            transition fault to off when manualReset;
        }
    }

    // ===== Requirements =====

    requirement def SupportSimultaneousCalls {
        attribute minCalls : CallCount = 32;
        doc /* The system shall support at least 32 simultaneous calls. */;
    }

    requirement def SupportVoicemailUsers {
        attribute minUsers : UserCount = 60;
        doc /* The system shall provide voicemail for at least 60 users. */;
    }

    requirement def MaintainVoiceQuality {
        attribute minSampleRate : Frequency = 8000 [hertz];
        attribute maxLatency : Duration = 0.15 [second];
        doc /* The system shall maintain high voice quality with adequate sample rate and low latency. */;
    }

    requirement def EnsureReliability {
        attribute minUptimeFraction : Real = 0.999;
        doc /* The system shall maintain at least 99.9 percent uptime. */;
    }

    requirement def ProvidePower {
        attribute requiredVoltage : Voltage = 48 [volt];
        attribute minPowerCapacity : Power = 500 [watt];
        doc /* The power supply shall provide adequate power to all network equipment. */;
    }

    requirement def NetworkInterconnect {
        attribute minSwitchPorts : Integer = 24;
        attribute minThroughput : DataRate = 1000 [megaBitPerSec];
        doc /* The network switch shall interconnect all devices with adequate bandwidth. */;
    }

    // ===== System Assembly =====

    part def VoIPSystem {
        part callManager : CallManager;
        part voicemailServer : VoicemailServer;
        part networkSwitch : NetworkSwitch;
        part powerSupply : PowerSupply;
        part phones : IPPhone[2..*];

        attribute systemId : String;
        attribute maxSupportedPhones : Integer = 64;

        connection : EthernetLink connect callManager.networkPort to networkSwitch.uplinkPorts[1];
        connection : EthernetLink connect voicemailServer.networkPort to networkSwitch.uplinkPorts[2];
        connection : EthernetLink connect phones.networkPort to networkSwitch.switchPorts;

        connection : PowerLink connect powerSupply.outputPort to networkSwitch.powerIn;
        connection : PowerLink connect powerSupply.outputPort to callManager.powerIn;
        connection : PowerLink connect powerSupply.outputPort to voicemailServer.powerIn;
        connection : PowerLink connect powerSupply.outputPort to phones.powerIn;

        action placeCall(caller : ExtensionNumber, callee : ExtensionNumber) {
            doc /*
                Caller lifts handset on IP Phone.
                IP Phone signals Call Manager via network switch.
                Call Manager routes call to callee extension.
                If answered, voice channel established through network switch.
                If unanswered, call forwarded to voicemail server.
            */;
        }

        action answerIncomingCall(callee : ExtensionNumber) {
            doc /*
                Callee phone rings on incoming call.
                Callee lifts handset to answer.
                Voice channel established through network switch.
            */;
        }

        action leaveVoicemail(caller : ExtensionNumber, mailboxId : String) {
            doc /*
                Unanswered call forwarded to voicemail server.
                Voicemail server records caller message.
                Message stored in user mailbox.
                User notified of new message.
            */;
        }

        requirement simultaneousCallsReq : SupportSimultaneousCalls;
        requirement voicemailUsersReq : SupportVoicemailUsers;
        requirement voiceQualityReq : MaintainVoiceQuality;
        requirement reliabilityReq : EnsureReliability;
        requirement powerReq : ProvidePower;
        requirement networkReq : NetworkInterconnect;

        satisfaction simultaneousCallsReq by callManager;
        satisfaction voicemailUsersReq by voicemailServer;
        satisfaction voiceQualityReq by phones;
        satisfaction powerReq by powerSupply;
        satisfaction networkReq by networkSwitch;
    }

    satisfaction VoIPSystem.reliabilityReq by VoIPSystem;
}
