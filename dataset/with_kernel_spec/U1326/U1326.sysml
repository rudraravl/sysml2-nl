package AsteriskVoIPPBX {
	private import ScalarValues::*;
	private import SI::*;

	value type ExtensionNumber :> Integer;
	value type PhoneNumber :> Integer;
	value type IpAddress :> String;
	value type CallId :> String;
	value type CallDuration :> Real;

	attribute def CodecType :> String;
	attribute def CallStatus :> String;
	attribute def OffHook;
	attribute def OnHook;

	item def AudioFrame {
		attribute codec : CodecType;
		attribute payloadSize : Integer;
	}

	item def SipMessage {
		attribute method : String;
		attribute fromExt : ExtensionNumber;
		attribute toExt : PhoneNumber;
		attribute callId : CallId;
		attribute sdp : String;
		attribute codec : CodecType;
	}

	item def CallRecord {
		attribute callId : CallId;
		attribute source : ExtensionNumber;
		attribute destination : PhoneNumber;
		attribute startTime : String;
		attribute duration : CallDuration;
		attribute status : CallStatus;
	}

	port def SipSignalPort {
		in ref incoming : SipMessage;
		out ref outgoing : SipMessage;
	}

	port def MediaRtpPort {
		in ref framesIn : AudioFrame;
		out ref framesOut : AudioFrame;
		attribute codec : CodecType;
	}

	port def CdrPort {
		in ref record : CallRecord;
	}

	part def Registrar {
		attribute registeredExtensions : ExtensionNumber[0..*];
		attribute registeredIps : IpAddress[0..*];
		port sipPort : SipSignalPort;
		exhibit state RegistrarState {
			entry; then Idle;
			state Idle;
			transition doRegister
				first Idle
				accept msg : SipMessage via sipPort
				if msg.method == "REGISTER"
				then Registered;
			state Registered;
			transition doLookup
				first Registered
				accept msg : SipMessage via sipPort
				if msg.method == "LOOKUP"
				then Registered;
			transition doUnregister
				first Registered
				accept msg : SipMessage via sipPort
				if msg.method == "UNREGISTER"
				then Idle;
		}
	}

	part def DialPlanEngine {
		port sipPort : SipSignalPort;
		exhibit state DialPlanState {
			entry; then Idle;
			state Idle;
			transition routeInternal
				first Idle
				accept msg : SipMessage via sipPort
				if msg.toExt < 1000
				then Idle;
			transition routeExternal
				first Idle
				accept msg : SipMessage via sipPort
				if msg.toExt >= 1000
				then Idle;
		}
	}

	part def MediaBridge {
		port mediaA : MediaRtpPort;
		port mediaB : MediaRtpPort;
		port translatorPort : MediaRtpPort;
		perform action bridge {
			first start;
			then action forwardAtoB;
			then action forwardBtoA;
			then done;
		}
	}

	part def CodecTranslator {
		port inPort : ~MediaRtpPort;
		port outPort : MediaRtpPort;
		perform action translate {
			first start;
			then action convert;
			then done;
		}
	}

	part def CdrManager {
		port cdrPort : CdrPort;
		item records : CallRecord[0..*];
		exhibit state CdrManagerState {
			entry; then Idle;
			state Idle;
			transition logCall
				first Idle
				accept record : CallRecord via cdrPort
				then Idle;
		}
	}

	part def SipTrunk {
		attribute trunkId : String;
		attribute providerHost : IpAddress;
		port sipPort : ~SipSignalPort;
		port externalMedia : ~MediaRtpPort;
		exhibit state TrunkState {
			entry; then Idle;
			state Idle;
			transition outgoingCall
				first Idle
				accept msg : SipMessage via sipPort
				if msg.method == "INVITE"
				then Routing;
			state Routing;
			transition routed
				first Routing
				accept msg : SipMessage via sipPort
				if msg.method == "200 OK"
				then Active;
			transition routingFailed
				first Routing
				accept msg : SipMessage via sipPort
				if msg.method == "486 BUSY"
				then Idle;
			state Active;
			transition endCall
				first Active
				accept msg : SipMessage via sipPort
				if msg.method == "BYE"
				then Idle;
		}
	}

	part def SipEndpoint {
		attribute extension : ExtensionNumber;
		attribute ipAddr : IpAddress;
		attribute currentCodec : CodecType;
		port sipPort : ~SipSignalPort;
		port mediaPort : ~MediaRtpPort;
		exhibit state EndpointState {
			entry; then Unregistered;
			state Unregistered;
			transition doRegister
				first Unregistered
				do send new SipMessage("REGISTER", extension, 0, "", "", "") via sipPort
				then AwaitingOk;
			state AwaitingOk;
			transition regAck
				first AwaitingOk
				accept msg : SipMessage via sipPort
				if msg.method == "200 OK"
				then Registered;
			transition regFailed
				first AwaitingOk
				accept msg : SipMessage via sipPort
				if msg.method == "403 FORBIDDEN"
				then Unregistered;
			state Registered;
			transition placeCall
				first Registered
				accept OffHook
				do send new SipMessage("INVITE", extension, 0, "", "", currentCodec) via sipPort
				then Ringing;
			state Ringing;
			transition answered
				first Ringing
				accept msg : SipMessage via sipPort
				if msg.method == "200 OK"
				then InCall;
			transition rejected
				first Ringing
				accept msg : SipMessage via sipPort
				if msg.method == "486 BUSY"
				then Registered;
			state InCall;
			transition hangup
				first InCall
				accept OnHook
				do send new SipMessage("BYE", extension, 0, "", "", "") via sipPort
				then Registered;
		}
	}

	part def PbxCore {
		attribute maxConcurrentCalls : Integer = 50;
		attribute activeCalls : Integer = 0;
		port endpointSip : SipSignalPort;
		port trunkSip : SipSignalPort;
		port registrarSip : ~SipSignalPort;
		port dialPlanSip : ~SipSignalPort;
		port cdrPort : ~CdrPort;
		exhibit state PbxState {
			entry; then Idle;
			state Idle;
			transition handleInvite
				first Idle
				accept msg : SipMessage via endpointSip
				if msg.method == "INVITE"
				then Setup;
			state Setup;
			transition sessionEstablished
				first Setup
				accept msg : SipMessage via trunkSip
				if msg.method == "200 OK"
				then Active;
			transition sessionFailed
				first Setup
				accept msg : SipMessage via trunkSip
				if msg.method == "486 BUSY"
				then Idle;
			state Active;
			transition callTerminated
				first Active
				accept msg : SipMessage via endpointSip
				if msg.method == "BYE"
				then Idle;
		}
	}

	part pbxSystem {
		part core : PbxCore;
		part dialPlan : DialPlanEngine;
		part registrar : Registrar;
		part mediaBridge : MediaBridge;
		part codecTranslator : CodecTranslator;
		part cdrManager : CdrManager;
		part trunk : SipTrunk;
		part endpoint1 : SipEndpoint {
			:>> extension = 101;
			:>> ipAddr = "192.168.1.10";
			:>> currentCodec = "G.711";
		}
		part endpoint2 : SipEndpoint {
			:>> extension = 102;
			:>> ipAddr = "192.168.1.11";
			:>> currentCodec = "G.722";
		}
		interface endpoint1.sipPort to core.endpointSip;
		interface endpoint2.sipPort to core.endpointSip;
		interface trunk.sipPort to core.trunkSip;
		interface dialPlan.sipPort to core.dialPlanSip;
		interface registrar.sipPort to core.registrarSip;
		interface core.cdrPort to cdrManager.cdrPort;
		interface endpoint1.mediaPort to mediaBridge.mediaA;
		interface endpoint2.mediaPort to mediaBridge.mediaB;
		interface mediaBridge.translatorPort to codecTranslator.inPort;
		interface codecTranslator.outPort to trunk.externalMedia;
	}

	requirement def MaxConcurrentCallsRequirement {
		/* The PBX Core shall support a maximum of 50 simultaneous calls. */
	}
	requirement def CallLoggingRequirement {
		/* Every call shall be logged by the CDR Manager with source, destination, duration, and status. */
	}
	requirement def CodecTranslationRequirement {
		/* The Codec Translator shall translate between incompatible audio codecs during media bridging. */
	}
	requirement def DialPlanRoutingRequirement {
		/* The Dial Plan Engine shall route 3-digit numbers internally and 10-digit numbers prefixed with 9 externally. */
	}
	requirement def EndpointRegistrationRequirement {
		/* Each SIP Endpoint shall register with the Registrar upon startup providing its extension and IP address. */
	}
	requirement def MediaBridgingRequirement {
		/* The Media Bridge shall forward RTP audio frames between call participants. */
	}

	requirement maxCallsReq : MaxConcurrentCallsRequirement;
	requirement callLoggingReq : CallLoggingRequirement;
	requirement codecTranslationReq : CodecTranslationRequirement;
	requirement dialPlanRoutingReq : DialPlanRoutingRequirement;
	requirement endpointRegistrationReq : EndpointRegistrationRequirement;
	requirement mediaBridgingReq : MediaBridgingRequirement;

	satisfy maxCallsReq by pbxSystem.core;
	satisfy callLoggingReq by pbxSystem.cdrManager;
	satisfy codecTranslationReq by pbxSystem.codecTranslator;
	satisfy dialPlanRoutingReq by pbxSystem.dialPlan;
	satisfy endpointRegistrationReq by pbxSystem.registrar;
	satisfy mediaBridgingReq by pbxSystem.mediaBridge;
}
