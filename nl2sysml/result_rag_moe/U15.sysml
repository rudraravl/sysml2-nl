// Define an interface between a smartphone and a smart TV for screen mirroring functionality.
package ScreenMirroringSystem {
	doc /* 
	 * This model defines the system for screen mirroring from a smartphone to a smart TV.
	 * It specifies the components, their interfaces, data flows, behaviors, and requirements
	 * for a high-quality, responsive, and reliable mirroring experience.
	 */
	
	private import ScalarValues::*;
	private import Quantities::*;
	private import MeasurementReferences::*;
	private import ISQ::*;
	private import SI::*;
	
	/* VALUE TYPES, ENUMERATIONS, AND ITEM DEFINITIONS */
	
	attribute def Resolution {
		attribute width : Natural;
		attribute height : Natural;
	}
	
	attribute def DataRate :> ISQ::frequency;
	
	item def VideoStream {
		attribute resolution : Resolution;
		attribute frameRate : ISQ::frequency;
		attribute bitRate : DataRate;
		attribute codec : String;
	}
	
	item def AudioStream {
		attribute sampleRate : ISQ::frequency;
		attribute bitRate : DataRate;
		attribute channels : Natural;
		attribute codec : String;
	}
	
	enum def ControlAction {
		play, pause, stop, seekForward, seekBackward
	}
	
	item def ControlCommand {
		attribute action : ControlAction;
		attribute timestamp : ISQ::time;
	}
	
	enum def ConnectionState {
		disconnected, discovering, pairing, connected, streaming, error
	}
	
	item def StatusUpdate {
		attribute state : ConnectionState;
		attribute bufferLevel : Real; // Percentage, 0.0 to 1.0
		attribute errorCount : Natural;
	}
	
	/* PORT DEFINITIONS */
	
	port def MirroringSourcePort {
		doc "Port for the device sending the media stream (e.g., Smartphone)."
		out item video : VideoStream;
		out item audio : AudioStream;
		in item control : ControlCommand;
		out item status : StatusUpdate;
	}
	
	port def MirroringSinkPort {
		doc "Port for the device receiving the media stream (e.g., Smart TV)."
		in item video : VideoStream;
		in item audio : AudioStream;
		out item control : ControlCommand;
		in item status : StatusUpdate;
	}
	
	/* PART DEFINITIONS */
	
	part def Smartphone {
		attribute deviceName : String;
		attribute screenResolution : Resolution;
		
		port mirrorPort : MirroringSourcePort;
		
		part encoder : MediaEncoder;
		part transceiver : WirelessTransceiver;
		part controller : MirroringController;
	}
	
	part def SmartTV {
		attribute modelNumber : String;
		attribute displaySize : ISQ::length;
		
		port mirrorPort : MirroringSinkPort;
		
		part decoder : MediaDecoder;
		part receiver : WirelessTransceiver;
		part controller : MirroringController;
		part display : TVDisplay;
	}
	
	part def MediaEncoder;
	part def MediaDecoder;
	part def WirelessTransceiver;
	part def TVDisplay;
	
	part def MirroringController {
		attribute currentState : ConnectionState;
		part stateMachine : ConnectionLifecycle;
	}
	
	/* BEHAVIOR DEFINITION (STATE MACHINE) */
	
	state def ConnectionLifecycle {
		entry action initialize;
		
		state Disconnected;
		state Discovering {
			entry action scanForPeers;
		}
		state Pairing {
			entry action exchangeCredentials;
			do action negotiateCapabilities;
		}
		state Connected {
			entry action establishSession;
		}
		state Streaming {
			entry action startMediaFlow;
			do action monitorConnection;
			exit action stopMediaFlow;
			
			state Playing {
				do action transmitData;
			}
			state Paused {
				entry action pauseTransmission;
			}
			
			transition from Playing to Paused
				accept PauseEvent;
			
			transition from Paused to Playing
				accept PlayEvent;
		}
		state Error {
			entry action logError;
			do action attemptRecovery;
		}
		
		transition from Disconnected to Discovering
			accept UserInitiatesDiscovery;
			
		transition from Discovering to Pairing
			accept PeerFound;
			
		transition from Pairing to Connected
			accept PairingSucceeded;
			
		transition from Pairing to Disconnected
			accept PairingFailed;
			
		transition from Connected to Streaming
			accept UserStartsStreaming;
			
		transition from Streaming to Connected
			accept UserStopsStreaming;
			
		transition from Connected to Disconnected
			accept UserDisconnects;
			
		transition from Streaming to Error
			accept ConnectionLost;
			
		transition from Error to Connected
			accept RecoverySucceeded;
			
		transition from Error to Disconnected
			accept RecoveryFailed;
	}
	
	// Action definitions for state machine triggers and behaviors
	action def initialize;
	action def scanForPeers;
	action def exchangeCredentials;
	action def negotiateCapabilities;
	action def establishSession;
	action def startMediaFlow;
	action def monitorConnection;
	action def stopMediaFlow;
	action def transmitData;
	action def pauseTransmission;
	action def logError;
	action def attemptRecovery;
	
	// Event definitions for state machine transitions
	action def UserInitiatesDiscovery;
	action def PeerFound;
	action def PairingSucceeded;
	action def PairingFailed;
	action def UserStartsStreaming;
	action def UserStopsStreaming;
	action def UserDisconnects;
	action def ConnectionLost;
	action def RecoverySucceeded;
	action def RecoveryFailed;
	action def PauseEvent;
	action def PlayEvent;

	/* INTERFACE DEFINITION */
	
	interface def ScreenMirroringInterface {
		doc "Defines the connection and data flows for screen mirroring."
		end source : MirroringSourcePort;
		end sink : MirroringSinkPort;
		
		flow source.video to sink.video;
		flow source.audio to sink.audio;
		flow sink.control to source.control;
		flow source.status to sink.status;
	}
	
	/* REQUIREMENT DEFINITIONS */
	
	requirement def ScreenMirroringPerformance {
		id = "SYS-REQ-001";
		text = "The system shall provide a high-quality and responsive screen mirroring experience.";
		
		attribute minResolution : Resolution = Resolution { width = 1920; height = 1080; };
		attribute minFrameRate : ISQ::frequency = 30.0 [SI::hertz];
		attribute maxLatency : ISQ::time = 100.0 [SI::millisecond];
		attribute maxAudioVideoSkew : ISQ::time = 40.0 [SI::millisecond];
		attribute encryptionRequired : Boolean = true;
	}
	
	/* SYSTEM ASSEMBLY */
	
	part def ScreenMirroringSystem {
		part phone : Smartphone {
			attribute deviceName = "MyPhone";
			attribute screenResolution = Resolution { width = 2400; height = 1080; };
		}
		
		part tv : SmartTV {
			attribute modelNumber = "TV-4K-2024";
			attribute displaySize = 65.0 [SI::in];
		}
		
		interface connection : ScreenMirroringInterface connect
			source ::> phone.mirrorPort to
			sink ::> tv.mirrorPort;
			
		satisfy ScreenMirroringPerformance by self;
	}
}
