package 'Asterisk VoIP PBX System' {
    private import ScalarValues::*;
    private import ISQ::*;
    
    attribute def ExtensionNumber :> String;
    attribute def IPAddress :> String;
    attribute def CallID :> String;
    attribute def SIPMessageType :> String;
    attribute def CodecType :> String;
    attribute def DialPlanPattern :> String;
    
    attribute def CallDuration :> ISQ::TimeValue;
    attribute def AudioBitrate :> ISQ::DataRateValue;
    attribute def PacketLoss :> Real;
    attribute def Latency :> ISQ::TimeValue;
    
    item def SIPMessage {
        attribute messageType : SIPMessageType;
        attribute callID : CallID;
        attribute fromExtension : ExtensionNumber;
        attribute toExtension : ExtensionNumber;
    }
    
    item def RTPPacket {
        attribute payload : String;
        attribute sequenceNumber : Integer;
        attribute timestamp : ISQ::TimeValue;
    }
    
    port def SIPSignalingPort {
        in sipRequest : SIPMessage;
        out sipResponse : SIPMessage;
    }
    
    port def RTPMediaPort {
        in inboundAudio : RTPPacket;
        out outboundAudio : RTPPacket;
    }
    
    port def NetworkInterface {
        attribute ipAddress : IPAddress;
        attribute portNumber : Integer;
    }
    
    part def SIPEndpoint {
        attribute extensionNumber : ExtensionNumber;
        attribute registeredIP : IPAddress;
        port sipPort : SIPSignalingPort;
        port rtpPort : RTPMediaPort;
        port network : NetworkInterface;
    }
    
    part def SIPTrunk {
        attribute trunkName : String;
        attribute providerIP : IPAddress;
        port sipPort : SIPSignalingPort;
        port rtpPort : RTPMediaPort;
    }
    
    part def DialPlanEngine {
        attribute patterns : DialPlanPattern[*];
        attribute contexts : String[*];
        perform action routeCall;
    }
    
    part def CallDetailRecordManager {
        attribute records : CallDetailRecord[*];
        perform action logCall;
    }
    
    part def MediaBridge {
        attribute activeChannels : Integer;
        attribute maxChannels : Integer;
        perform action bridgeAudio;
    }
    
    part def CodecTranslator {
        attribute supportedCodecs : CodecType[*];
        perform action transcodeAudio;
    }
    
    item def CallDetailRecord {
        attribute callID : CallID;
        attribute source : ExtensionNumber;
        attribute destination : ExtensionNumber;
        attribute startTime : ISQ::TimeValue;
        attribute duration : CallDuration;
        attribute disposition : String;
    }
    
    action def RegisterEndpoint {
        in extension : ExtensionNumber;
        in ipAddress : IPAddress;
        out registered : Boolean;
    }
    
    action def RouteCall {
        in calledNumber : ExtensionNumber;
        in dialPlanPatterns : DialPlanPattern[*];
        out targetEndpoint : ExtensionNumber;
        out routeFound : Boolean;
    }
    
    action def EstablishSIPSession {
        in caller : ExtensionNumber;
        in callee : ExtensionNumber;
        out sessionID : CallID;
        out established : Boolean;
    }
    
    action def BridgeAudio {
        in channel1Audio : RTPPacket;
        in channel2Audio : RTPPacket;
        in codec : CodecType;
        out bridgedAudio1 : RTPPacket;
        out bridgedAudio2 : RTPPacket;
    }
    
    action def TranscodeAudio {
        in inputAudio : RTPPacket;
        in sourceCodec : CodecType;
        in targetCodec : CodecType;
        out outputAudio : RTPPacket;
    }
    
    action def LogCallDetail {
        in callID : CallID;
        in source : ExtensionNumber;
        in destination : ExtensionNumber;
        in duration : CallDuration;
        out cdr : CallDetailRecord;
    }
    
    state def CallState {
        entry; then idle;
        
        state idle;
        transition idle_to_ringing
            first idle
            accept invite : SIPMessage
            then ringing;
        
        state ringing;
        transition ringing_to_answered
            first ringing
            accept answer : SIPMessage
            then answered;
        transition ringing_to_busy
            first ringing
            accept busy : SIPMessage
            then idle;
        
        state answered;
        transition answered_to_idle
            first answered
            accept bye : SIPMessage
            then idle;
    }
    
    part def AsteriskPBXCore {
        doc /* 
            Asterisk PBX Core provides comprehensive Voice over IP (VoIP) 
            Private Branch Exchange functionality including call routing, 
            media bridging, protocol translation, and call management.
        */
        
        attribute systemVersion : String;
        attribute maxConcurrentCalls : Integer;
        attribute registeredExtensions : ExtensionNumber[*];
        
        port managementInterface : NetworkInterface;
        
        part sipChannelDriver {
            attribute activeChannels : Integer;
            port sipPorts : SIPSignalingPort[*];
        }
        
        part rtpEngine : MediaBridge {
            :>> maxChannels = 1000;
            port rtpPorts : RTPMediaPort[*];
        }
        
        part dialPlan : DialPlanEngine {
            :>> patterns = ("_1XX", "_2XX", "_9NXXNXXXXXX");
            :>> contexts = ("internal", "external", "voicemail");
        }
        
        part cdrManager : CallDetailRecordManager;
        
        part codecHandler : CodecTranslator {
            :>> supportedCodecs = ("G.711", "G.722", "G.729", "Opus");
        }
        
        part registrar {
            attribute registrationTable : ExtensionNumber[*];
            perform action registerEndpoint : RegisterEndpoint;
        }
        
        perform action processCall : ProcessVoIPCall;
    }
    
    action def ProcessVoIPCall {
        in incomingRequest : SIPMessage;
        out callSuccessful : Boolean;
        
        first start;
        then merge awaitIncoming;
        
        then action receiveInvite {
            accept invite : SIPMessage;
        }
        
        then action validateExtension {
            in calledNumber = receiveInvite.invite.toExtension;
            out isValid : Boolean;
        }
        
        then decide;
            if validateExtension.isValid then routeCall;
            if not validateExtension.isValid then rejectCall;
        
        action routeCall : RouteCall {
            in calledNumber = receiveInvite.invite.toExtension;
            in dialPlanPatterns;
            out targetEndpoint;
            out routeFound;
        }
        then decide;
            if routeCall.routeFound then establishSession;
            if not routeCall.routeFound then sendBusy;
        
        action establishSession : EstablishSIPSession {
            in caller = receiveInvite.invite.fromExtension;
            in callee = routeCall.targetEndpoint;
            out sessionID;
            out established;
        }
        then decide;
            if establishSession.established then activeCall;
            if not establishSession.established then sendBusy;
        
        action activeCall {
            action bridgeMedia : BridgeAudio {
                in channel1Audio;
                in channel2Audio;
                in codec = "G.711";
                out bridgedAudio1;
                out bridgedAudio2;
            }
        }
        then logCall;
        
        action logCall : LogCallDetail {
            in callID = establishSession.sessionID;
            in source = receiveInvite.invite.fromExtension;
            in destination = routeCall.targetEndpoint;
            in duration;
            out cdr;
        }
        then assign callSuccessful := true;
        then awaitIncoming;
        
        action rejectCall {
            then assign callSuccessful := false;
        }
        then awaitIncoming;
        
        action sendBusy {
            then assign callSuccessful := false;
        }
        then awaitIncoming;
        
        then done;
    }
    
    part asteriskPBXSystem {
        part pbxCore : AsteriskPBXCore {
            :>> systemVersion = "Asterisk 20.0";
            :>> maxConcurrentCalls = 500;
            :>> registeredExtensions = ("100", "101", "102", "200", "201");
        }
        
        part extension100 : SIPEndpoint {
            :>> extensionNumber = "100";
            :>> registeredIP = "192.168.1.100";
        }
        
        part extension101 : SIPEndpoint {
            :>> extensionNumber = "101";
            :>> registeredIP = "192.168.1.101";
        }
        
        part extension102 : SIPEndpoint {
            :>> extensionNumber = "102";
            :>> registeredIP = "192.168.1.102";
        }
        
        part pstnTrunk : SIPTrunk {
            :>> trunkName = "PrimaryPSTN";
            :>> providerIP = "203.0.113.10";
        }
        
        connect extension100.sipPort to pbxCore.sipChannelDriver.sipPorts[0];
        connect extension101.sipPort to pbxCore.sipChannelDriver.sipPorts[1];
        connect extension102.sipPort to pbxCore.sipChannelDriver.sipPorts[2];
        connect pstnTrunk.sipPort to pbxCore.sipChannelDriver.sipPorts[3];
        
        connect extension100.rtpPort to pbxCore.rtpEngine.rtpPorts[0];
        connect extension101.rtpPort to pbxCore.rtpEngine.rtpPorts[1];
        connect extension102.rtpPort to pbxCore.rtpEngine.rtpPorts[2];
        connect pstnTrunk.rtpPort to pbxCore.rtpEngine.rtpPorts[3];
    }
    
    requirement def PBXFunctionalRequirement;
    requirement def PBXPerformanceRequirement;
    requirement def PBXReliabilityRequirement;
    
    requirement <'REQ-PBX-001'> primaryFunction : PBXFunctionalRequirement {
        doc /* 
            The Asterisk PBX system shall provide comprehensive Voice over IP 
            communication services by managing SIP signaling for call setup, 
            teardown, and control; routing calls through a configurable dial plan 
            based on extension patterns and contexts; bridging real-time audio 
            streams between connected parties using RTP protocol; performing codec 
            translation when endpoints use different audio formats; maintaining 
            endpoint registration; and logging detailed call records for all 
            completed calls.
        */
        subject asteriskPBXSystem.pbxCore;
        
        assume constraint networkAvailable {
            doc /* Network connectivity is available and stable. */
            asteriskPBXSystem.pbxCore.managementInterface.ipAddress != ""
        }
        
        require constraint callProcessing {
            doc /* System shall successfully process and route calls. */
            asteriskPBXSystem.pbxCore.processCall.callSuccessful == true
        }
    }
    
    requirement <'REQ-PBX-002'> concurrentCallCapacity : PBXPerformanceRequirement {
        doc /* 
            The system shall support at least 500 concurrent calls with 
            acceptable audio quality.
        */
        subject asteriskPBXSystem.pbxCore;
        
        require constraint maxCalls {
            asteriskPBXSystem.pbxCore.maxConcurrentCalls >= 500
        }
        
        require constraint mediaBridgeCapacity {
            asteriskPBXSystem.pbxCore.rtpEngine.maxChannels >= 1000
        }
    }
    
    requirement <'REQ-PBX-003'> callSetupLatency : PBXPerformanceRequirement {
        doc /* 
            Call setup time from INVITE to ringing shall not exceed 500 milliseconds 
            for internal calls.
        */
        subject asteriskPBXSystem.pbxCore;
    }
    
    requirement <'REQ-PBX-004'> codecSupport : PBXFunctionalRequirement {
        doc /* 
            The system shall support multiple audio codecs including G.711, G.722, 
            G.729, and Opus with transparent transcoding between them.
        */
        subject asteriskPBXSystem.pbxCore.codecHandler;
        
        require constraint minimumCodecs {
            asteriskPBXSystem.pbxCore.codecHandler.supportedCodecs->size() >= 4
        }
    }
    
    requirement <'REQ-PBX-005'> callDetailRecording : PBXFunctionalRequirement {
        doc /* 
            The system shall generate and store call detail records for all 
            completed calls including source, destination, duration, and disposition.
        */
        subject asteriskPBXSystem.pbxCore.cdrManager;
    }
    
    requirement <'REQ-PBX-006'> dialPlanFlexibility : PBXFunctionalRequirement {
        doc /* 
            The system shall support configurable dial plan patterns for routing 
            calls to internal extensions, external trunks, and special services.
        */
        subject asteriskPBXSystem.pbxCore.dialPlan;
        
        require constraint patternSupport {
            asteriskPBXSystem.pbxCore.dialPlan.patterns->size() >= 3
        }
    }
    
    requirement <'REQ-PBX-007'> audioQuality : PBXPerformanceRequirement {
        doc /* 
            The system shall maintain audio quality with packet loss below 1% 
            and latency below 150ms for active calls.
        */
        subject asteriskPBXSystem.pbxCore.rtpEngine;
    }
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import 'Asterisk VoIP PBX System'::*;

    part testSubject : SIPEndpoint {
        exhibit state sm : CallState;
    }

    action orchestrator {
        attribute testCalledNumber : ExtensionNumber = "";
        action routeCallProbe : RouteCall {
            in calledNumber = testCalledNumber;
            // TODO(human): unsupported input type for dialPlanPatterns: DialPlanPattern[*] (type is not a primitive, enum, extracted payload def, or known value type)
        }
        first routeCallProbe;
    }
}
