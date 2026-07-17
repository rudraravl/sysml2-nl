package GoogleCastSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def DeviceID;
	attribute def MediaURL;
	attribute def SessionID;
	attribute def NetworkAddress;
	
	attribute def BitrateValue :> Real;
	
	item def MediaStream {
		attribute url : MediaURL;
		attribute format : String;
		attribute bitrate : BitrateValue;
		attribute resolution : String;
	}
	
	item def CastCommand {
		attribute sessionId : SessionID;
		attribute targetDevice : DeviceID;
		attribute mediaUrl : MediaURL;
		attribute commandAction : String;
	}
	
	item def DeviceStatus {
		attribute deviceId : DeviceID;
		attribute isAvailable : Boolean;
		attribute volume : Real;
		attribute playbackState : String;
	}
	
	item def DiscoveryBeacon {
		attribute deviceId : DeviceID;
		attribute deviceName : String;
		attribute capabilities : String[*];
	}
	
	port def WiFiPort {
		attribute address : NetworkAddress;
		out item transmit : MediaStream[*];
		in item receive : MediaStream[*];
		out item beaconOut : DiscoveryBeacon[*];
		in item beaconIn : DiscoveryBeacon[*];
	}
	
	port def ControlPort {
		out item commandOut : CastCommand[*];
		in item commandIn : CastCommand[*];
		out item statusOut : DeviceStatus[*];
		in item statusIn : DeviceStatus[*];
	}
	
	port def HDMIPort {
		attribute outputType : String;
		out item videoAudioOut : MediaStream[*];
	}
	
	part def SenderDevice {
		attribute deviceName : String;
		attribute deviceId : DeviceID;
		port wifiPort : WiFiPort;
		port controlPort : ControlPort;
		
		part mediaLibrary {
			attribute availableMedia : MediaURL[*];
		}
		
		part castController {
			perform action discoverDevices;
			perform action initiateSession;
			perform action controlPlayback;
		}
	}
	
	part def ReceiverDevice {
		attribute deviceId : DeviceID;
		attribute deviceName : String;
		port wifiPort : WiFiPort;
		port controlPort : ControlPort;
		port hdmiPort : HDMIPort;
		
		part mediaRenderer {
			perform action decodeStream;
			perform action renderContent;
		}
		
		part audioProcessor {
			attribute currentVolume : Real;
		}
		
		part videoProcessor {
			attribute currentResolution : String;
		}
	}
	
	part def WiFiRouter {
		attribute networkName : String;
		attribute bandwidth : BitrateValue;
		port senderPort : WiFiPort;
		port receiverPort : WiFiPort;
		
		perform action routePackets;
		perform action manageConnections;
	}
	
	part def Display {
		attribute screenSize : LengthValue;
		attribute resolution : String;
		port hdmiInput : HDMIPort;
		
		perform action displayContent;
	}
	
	action def DiscoverDevices {
		in searchCriteria : String;
		out availableDevices : DeviceStatus[*];
		
		first start;
		then action broadcastBeacon;
		then action collectResponses {
			out devices : DeviceStatus[*];
		}
		then assign availableDevices := collectResponses.devices;
		then done;
	}
	
	action def EstablishSession {
		in targetDevice : DeviceID;
		in mediaUrl : MediaURL;
		out sessionId : SessionID;
		out success : Boolean;
		
		first start;
		then action sendConnectionRequest;
		then decide;
			if connectionAccepted then createSession;
			if connectionRejected then failSession;
		action createSession {
			out newSessionId : SessionID;
		}
		then assign sessionId := createSession.newSessionId;
		then assign success := true;
		then done;
		action failSession;
		then assign success := false;
		then done;
	}
	
	action def StreamMedia {
		in mediaUrl : MediaURL;
		in sessionId : SessionID;
		in bitrate : BitrateValue;
		out stream : MediaStream;
		
		first start;
		then action fetchContent {
			in url : MediaURL = mediaUrl;
			out content : MediaStream;
		}
		then action encodeStream {
			in rawContent : MediaStream = fetchContent.content;
			in targetBitrate : BitrateValue = bitrate;
			out encodedStream : MediaStream;
		}
		then assign stream := encodeStream.encodedStream;
		then done;
	}
	
	action def RenderMedia {
		in stream : MediaStream;
		out displaySignal : MediaStream;
		
		first start;
		then action decodeVideo {
			in encodedStream : MediaStream = stream;
			out decodedVideo : MediaStream;
		}
		then action processAudio {
			in audioStream : MediaStream = stream;
			out processedAudio : MediaStream;
		}
		then action combineOutputs {
			in video : MediaStream = decodeVideo.decodedVideo;
			in audio : MediaStream = processAudio.processedAudio;
			out combined : MediaStream;
		}
		then assign displaySignal := combineOutputs.combined;
		then done;
	}
	
	action def CastMediaSession {
		in selectedMedia : MediaURL;
		in targetDeviceId : DeviceID;
		out sessionCompleted : Boolean;
		
		first start;
		then action discover : DiscoverDevices {
			in searchCriteria = "chromecast";
			out availableDevices;
		}
		then action establish : EstablishSession {
			in targetDevice = targetDeviceId;
			in mediaUrl = selectedMedia;
			out sessionId;
			out success;
		}
		then decide;
			if establish.success then beginStreaming;
			if not establish.success then endSession;
		then merge streamingLoop;
		action beginStreaming : StreamMedia {
			in mediaUrl = selectedMedia;
			in sessionId = establish.sessionId;
			in bitrate = 5.0;
			out stream;
		}
		then action render : RenderMedia {
			in stream = beginStreaming.stream;
			out displaySignal;
		}
		then decide;
			if continuePlayback then streamingLoop;
			if stopPlayback then endSession;
		action endSession;
		then assign sessionCompleted := true;
		then done;
	}
	
	part googleCastSystem {
		part smartphone : SenderDevice {
			:>> deviceName = "User Smartphone";
			:>> deviceId = "SENDER-001";
			perform action castSession references castMediaSession;
		}
		
		part chromecast : ReceiverDevice {
			:>> deviceName = "Living Room Chromecast";
			:>> deviceId = "RECEIVER-001";
			perform castMediaSession.render;
		}
		
		part wifiRouter : WiFiRouter {
			:>> networkName = "HomeNetwork";
			:>> bandwidth = 100.0;
		}
		
		part television : Display {
			:>> screenSize = 55.0;
			:>> resolution = "4K";
		}
		
		connect smartphone.wifiPort to wifiRouter.senderPort;
		connect wifiRouter.receiverPort to chromecast.wifiPort;
		connect chromecast.hdmiPort to television.hdmiInput;
		connect smartphone.controlPort to chromecast.controlPort;
	}
	
	occurrence def CastSessionInteraction {
		ref part sender :>> googleCastSystem.smartphone;
		ref part receiver :>> googleCastSystem.chromecast;
		ref part router :>> googleCastSystem.wifiRouter;
		
		message discoveryBeacon of DiscoveryBeacon
			from receiver.wifiPort to sender.wifiPort;
		
		then message deviceStatusMessage of DeviceStatus
			from receiver.controlPort to sender.controlPort;
		
		then message castCommandMessage of CastCommand
			from sender.controlPort to receiver.controlPort;
		
		then message mediaStreamToRouter of MediaStream
			from sender.wifiPort to router.senderPort;
		
		then message mediaStreamToReceiver of MediaStream
			from router.receiverPort to receiver.wifiPort;
		
		then message hdmiOutputMessage of MediaStream
			from receiver.hdmiPort to googleCastSystem.television.hdmiInput;
	}
	
	requirement def <'CAST-REQ-001'> wirelessConnectivity {
		doc /* The system shall support wireless connectivity over WiFi networks 
		       to enable communication between sender and receiver devices. */
		subject googleCastSystem;
		require constraint {
			googleCastSystem.wifiRouter.networkName != null
		}
	}
	
	requirement def <'CAST-REQ-002'> deviceDiscovery {
		doc /* The sender device shall discover available receiver devices 
		       on the local network through beacon broadcasting. */
		subject googleCastSystem.smartphone;
	}
	
	requirement def <'CAST-REQ-003'> mediaStreaming {
		doc /* The system shall stream media content from sender to receiver 
		       with appropriate encoding and bitrate adaptation. */
		subject googleCastSystem;
		require constraint {
			googleCastSystem.smartphone.wifiPort.transmit->size() > 0 implies
			googleCastSystem.chromecast.wifiPort.receive->size() > 0
		}
	}
	
	requirement def <'CAST-REQ-004'> hdmiOutput {
		doc /* The receiver device shall output decoded media to a display 
		       via HDMI connection. */
		subject googleCastSystem.chromecast;
		require constraint {
			googleCastSystem.chromecast.hdmiPort.outputType == "HDMI"
		}
	}
	
	requirement def <'CAST-REQ-005'> playbackControl {
		doc /* The sender device shall provide playback control capabilities 
		       including play, pause, stop, and seek operations. */
		subject googleCastSystem.smartphone;
	}
	
	requirement primaryCastFunction {
		doc /* The Google Cast system shall enable users to wirelessly stream 
		       media content from a sender device (smartphone, tablet, or computer) 
		       to a receiver device (Chromecast) connected to a display (television), 
		       allowing seamless casting of videos, music, photos, and other media 
		       over a local WiFi network with full playback control. */
		
		assume constraint networkAvailable {
			doc /* A functional WiFi network must be available and both devices 
			       must be connected to the same network. */
			googleCastSystem.wifiRouter.networkName != null
		}
		
		assume constraint devicesCompatible {
			doc /* Sender and receiver devices must support the Cast protocol 
			       and be on the same network segment. */
		}
		
		require wirelessConnectivity;
		require deviceDiscovery;
		require mediaStreaming;
		require hdmiOutput;
		require playbackControl;
	}
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import GoogleCastSystem::*;

    action orchestrator {
        attribute testMediaUrl : MediaURL;
        attribute testSessionId : SessionID;
        attribute testBitrate : BitrateValue = 0.0;
        action beginStreamingProbe : StreamMedia {
            in mediaUrl = testMediaUrl;
            in sessionId = testSessionId;
            in bitrate = testBitrate;
        }
        first beginStreamingProbe;
    }
}
