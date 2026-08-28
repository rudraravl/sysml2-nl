package MediaStreamingEcosystem {

	import ScalarValues::*;
	import ISQ::*;

	// ---------- Value Types with Units ----------
	
	value def PowerUnit :> Real { unit = "W"; }
	value def Voltage :> Real { unit = "V"; }
	value def Current :> Real { unit = "A"; }
	value def DataRate :> Real { unit = "Mbps"; }
	value def ResolutionWidth :> Integer { unit = "px"; }
	value def ResolutionHeight :> Integer { unit = "px"; }
	value def BufferSize :> Integer { unit = "MB"; }
	value def Frequency :> Real { unit = "GHz"; }
	value def Temperature :> Real { unit = "degC"; }

	// ---------- Enumerations ----------
	
	enum def StreamQuality {
		SD = 0;
		HD = 1;
		FHD = 2;
		UHD_4K = 3;
	}
	
	enum def MediaType {
		VIDEO;
		AUDIO;
		IMAGE;
	}
	
	enum def ConnectionState {
		DISCONNECTED;
		DISCOVERING;
		AUTHENTICATING;
		CONNECTED;
		ERROR;
	}
	
	enum def PlaybackState {
		IDLE;
		BUFFERING;
		PLAYING;
		PAUSED;
		ERROR;
	}

	// ---------- Item Types ----------
	
	item def CastCommand {
		attribute mediaUrl : String;
		attribute mediaType : MediaType;
		attribute requestedQuality : StreamQuality;
		attribute sessionId : String;
	}
	
	item def MediaStream {
		attribute url : String;
		attribute mediaType : MediaType;
		attribute quality : StreamQuality;
		attribute bitrate : DataRate;
		attribute duration : DurationValue;
	}
	
	item def RawMediaData {
		attribute packetId : Integer;
		attribute payloadSize : Integer;
		attribute timestamp : DurationValue;
		attribute isKeyFrame : Boolean;
	}
	
	item def DecodedMedia {
		attribute videoFrames : Integer;
		attribute audioSamples : Integer;
		attribute currentQuality : StreamQuality;
	}
	
	item def VideoSignal {
		attribute resolutionWidth : ResolutionWidth;
		attribute resolutionHeight : ResolutionHeight;
		attribute refreshRate : Integer;
		attribute colorDepth : Integer;
		attribute isHDR : Boolean;
	}
	
	item def PowerSupply {
		attribute voltage : Voltage;
		attribute current : Current;
		attribute isStable : Boolean;
	}
	
	item def NetworkPacket {
		attribute sourceIp : String;
		attribute destIp : String;
		attribute payload : RawMediaData;
		attribute checksum : Integer;
	}
	
	item def StatusReport {
		attribute connectionState : ConnectionState;
		attribute playbackState : PlaybackState;
		attribute bufferLevel : BufferSize;
		attribute currentQuality : StreamQuality;
	}

	// ---------- Port Definitions ----------
	
	port def HDMIOutputPort {
		out item videoSignal : VideoSignal;
	}
	
	port def USBPowerPort {
		in item powerInput : PowerSupply;
	}
	
	port def WiFiPort {
		in item castCmd : CastCommand;
		in item netPackets : NetworkPacket;
		out item status : StatusReport;
	}
	
	port def HDMIInputPort {
		in item videoSignal : VideoSignal;
	}
	
	port def USBPowerOutputPort {
		out item powerOutput : PowerSupply;
	}
	
	port def WiFiClientPort {
		out item castCmd : CastCommand;
		in item status : StatusReport;
	}
	
	port def WiFiRouterPort {
		in item castCmd : CastCommand;
		out item netPackets : NetworkPacket;
		in item status : StatusReport;
	}

	// ---------- Interfaces ----------
	
	interface def HDMIInterface {
		end sourceHDMI : HDMIOutputPort;
		end destHDMI : HDMIInputPort;
	}
	
	interface def USBPowerInterface {
		end sourceUSB : USBPowerOutputPort;
		end destUSB : USBPowerPort;
	}
	
	interface def WiFiInterface {
		end clientWiFi : WiFiClientPort;
		end routerWiFi : WiFiRouterPort;
	}
	
	interface def DeviceWiFiInterface {
		end deviceWiFi : WiFiPort;
		end routerWiFi2 : WiFiRouterPort;
	}

	// ---------- Chromecast Device ----------
	
	part def Chromecast {
		attribute weight : Real = 0.047; // kg
		attribute dimensions : String = "51.9 x 51.9 x 13.5 mm";
		attribute maxResolutionWidth : ResolutionWidth = 3840;
		attribute maxResolutionHeight : ResolutionHeight = 2160;
		attribute maxPowerConsumption : PowerUnit = 2.5;
		attribute supportedWiFiFreq : Frequency = 5.0;
		
		port hdmiOut : HDMIOutputPort;
		port usbPowerIn : USBPowerPort;
		port wifiNet : WiFiPort;
		
		part networkInterface : NetworkInterface {
			attribute macAddress : String;
			attribute ipAddress : String;
			attribute supportedStandards : String = "802.11ac/n";
			attribute maxDataRate : DataRate = 433.0;
			
			port internalNetOut : WiFiPort {
				out item castCmd : CastCommand;
				out item netPackets : NetworkPacket;
			}
			port internalNetIn : WiFiPort {
				in item status : StatusReport;
			}
			
			action receiveCastCommand {
				in cmd : CastCommand;
			}
			
			action downloadMedia {
				in url : String;
				out packets : NetworkPacket;
			}
			
			action reportStatus {
				out status : StatusReport;
			}
		}
		
		part mediaProcessor : MediaProcessor {
			attribute cpuClock : Frequency = 1.2;
			attribute bufferCapacity : BufferSize = 512;
			attribute currentBufferLevel : BufferSize;
			attribute adaptiveBitrateEnabled : Boolean = true;
			attribute supportedCodecs : String = "H.264, VP8, VP9, HEVC";
			
			action bufferMedia {
				in raw : RawMediaData;
				out buffered : RawMediaData;
			}
			
			action decodeMedia {
				in raw : RawMediaData;
				out decoded : DecodedMedia;
			}
			
			action adjustQuality {
				in networkCondition : DataRate;
				out newQuality : StreamQuality;
			}
		}
		
		part videoRenderer : VideoRenderer {
			attribute maxOutputWidth : ResolutionWidth = 3840;
			attribute maxOutputHeight : ResolutionHeight = 2160;
			attribute supportedRefreshRates : String = "24, 30, 60";
			attribute supportsHDR : Boolean = true;
			
			action renderVideo {
				in decoded : DecodedMedia;
				out signal : VideoSignal;
			}
		}
		
		part powerController : PowerController {
			attribute inputVoltage : Voltage = 5.0;
			attribute inputCurrent : Current = 1.0;
			attribute powerEfficiency : Real = 0.92;
			attribute thermalThreshold : Temperature = 85.0;
			
			action regulatePower {
				in supply : PowerSupply;
				out regulated : PowerSupply;
			}
			
			action monitorThermal {
				out temp : Temperature;
			}
		}
		
		// Internal connections
		connection netToProcessor {
			from networkInterface.internalNetOut.netPackets;
			to mediaProcessor.bufferMedia.raw;
		}
		connection processorToRenderer {
			from mediaProcessor.decodeMedia.decoded;
			to videoRenderer.renderVideo.decoded;
		}
		connection rendererToHDMI {
			from videoRenderer.renderVideo.signal;
			to hdmiOut.videoSignal;
		}
		connection powerToController {
			from usbPowerIn.powerInput;
			to powerController.regulatePower.supply;
		}
		connection controllerToNetwork {
			from powerController.regulatePower.regulated;
			to networkInterface; // implicit power distribution
		}
		connection statusFeedback {
			from mediaProcessor;
			to networkInterface.internalNetIn.status;
		}
		
		// State Machine
		state def ChromecastStateMachine {
			entry action initializeDevice {
				// Power on self-test
			}
			
			state disconnected {
				entry action logDisconnected;
				execute action waitForPower {
					// Wait for stable power
				}
				transition to discovering
					when usbPowerIn.powerInput.isStable == true;
			}
			
			state discovering {
				entry action scanNetwork {
					// Scan for WiFi networks
				}
				transition to authenticating
					when networkInterface.ipAddress != "";
				transition to errorState
					when networkInterface.ipAddress == "";
			}
			
			state authenticating {
				entry action authenticate {
					// Authenticate with WiFi router
				}
				transition to connected
					when true; // authentication success
				transition to errorState
					when false; // authentication failure
			}
			
			state connected {
				entry action notifyReady {
					// Notify ready to receive cast commands
				}
				transition to idle
					when true;
			}
			
			state idle {
				entry action waitForCommand;
				transition to buffering
					when wifiNet.castCmd.mediaUrl != "";
			}
			
			state buffering {
				entry action startBuffer {
					// Begin buffering media data
				}
				execute action monitorBuffer {
					// Monitor buffer level
				}
				transition to playing
					when mediaProcessor.currentBufferLevel > 64;
				transition to errorState
					when mediaProcessor.currentBufferLevel == 0;
			}
			
			state playing {
				entry action startPlayback {
					// Begin media playback
				}
				execute action streamMedia {
					// Continuously stream and decode
				}
				transition to paused
					when wifiNet.castCmd.sessionId == ""; // user pause
				transition to buffering
					when mediaProcessor.currentBufferLevel < 32;
				transition to idle
					when false; // media complete
			}
			
			state paused {
				entry action pausePlayback;
				transition to playing
					when true; // user resume
				transition to idle
					when false; // user stop
			}
			
			state errorState {
				entry action handleError {
					// Log error and attempt recovery
				}
				execute action attemptRecovery {
					// Attempt to recover connection
				}
				transition to disconnected
					when true; // recovery initiated
			}
		}
		
		exhibit ChromecastStateMachine;
	}

	// ---------- Sub-component Definitions ----------
	
	part def NetworkInterface {
		attribute macAddress : String;
		attribute ipAddress : String;
		attribute supportedStandards : String;
		attribute maxDataRate : DataRate;
		
		port netPort : WiFiPort;
		
		action receiveCastCommand {
			in cmd : CastCommand;
		}
		
		action downloadMedia {
			in url : String;
			out packets : NetworkPacket;
		}
		
		action reportStatus {
			out status : StatusReport;
		}
	}
	
	part def MediaProcessor {
		attribute cpuClock : Frequency;
		attribute bufferCapacity : BufferSize;
		attribute currentBufferLevel : BufferSize;
		attribute adaptiveBitrateEnabled : Boolean;
		attribute supportedCodecs : String;
		
		action bufferMedia {
			in raw : RawMediaData;
			out buffered : RawMediaData;
		}
		
		action decodeMedia {
			in raw : RawMediaData;
			out decoded : DecodedMedia;
		}
		
		action adjustQuality {
			in networkCondition : DataRate;
			out newQuality : StreamQuality;
		}
	}
	
	part def VideoRenderer {
		attribute maxOutputWidth : ResolutionWidth;
		attribute maxOutputHeight : ResolutionHeight;
		attribute supportedRefreshRates : String;
		attribute supportsHDR : Boolean;
		
		port videoOut : HDMIOutputPort;
		
		action renderVideo {
			in decoded : DecodedMedia;
			out signal : VideoSignal;
		}
	}
	
	part def PowerController {
		attribute inputVoltage : Voltage;
		attribute inputCurrent : Current;
		attribute powerEfficiency : Real;
		attribute thermalThreshold : Temperature;
		
		action regulatePower {
			in supply : PowerSupply;
			out regulated : PowerSupply;
		}
		
		action monitorThermal {
			out temp : Temperature;
		}
	}

	// ---------- External System Components ----------
	
	part def MobilePhone {
		attribute deviceName : String;
		attribute osType : String;
		attribute castAppInstalled : Boolean = true;
		
		port wifiClient : WiFiClientPort;
		
		action sendCastCommand {
			in mediaUrl : String;
			in mediaType : MediaType;
			in quality : StreamQuality;
			out cmd : CastCommand;
		}
		
		action receiveStatus {
			in status : StatusReport;
		}
	}
	
	part def Television {
		attribute displayName : String;
		attribute screenSize : Real; // inches
		attribute nativeResolutionWidth : ResolutionWidth;
		attribute nativeResolutionHeight : ResolutionHeight;
		attribute supportsHDR : Boolean;
		
		port hdmiIn : HDMIInputPort;
		
		action displayVideo {
			in signal : VideoSignal;
		}
	}
	
	part def WiFiRouter {
		attribute ssid : String;
		attribute securityProtocol : String = "WPA3";
		attribute frequencyBand : Frequency = 5.0;
		attribute maxClients : Integer = 32;
		
		port routerPort : WiFiRouterPort;
		
		action routeCastCommand {
			in cmd : CastCommand;
			out forwarded : CastCommand;
		}
		
		action routeMediaPackets {
			out packets : NetworkPacket;
		}
		
		action authenticateDevice {
			in macAddress : String;
			out success : Boolean;
		}
	}
	
	part def PowerAdapter {
		attribute outputVoltage : Voltage = 5.0;
		attribute outputCurrent : Current = 1.0;
		attribute plugType : String = "USB-A";
		attribute isEnergyStarRated : Boolean = true;
		
		port usbOutput : USBPowerOutputPort;
		
		action convertPower {
			out supply : PowerSupply;
		}
	}

	// ---------- System Assembly ----------
	
	part MediaStreamingSystem {
		part chromecast : Chromecast;
		part mobilePhone : MobilePhone;
		part television : Television;
		part wifiRouter : WiFiRouter;
		part powerAdapter : PowerAdapter;
		
		// External interfaces
		interface hdmiConnection : HDMIInterface {
			end sourceHDMI :>> chromecast.hdmiOut;
			end destHDMI :>> television.hdmiIn;
		}
		
		interface powerConnection : USBPowerInterface {
			end sourceUSB :>> powerAdapter.usbOutput;
			end destUSB :>> chromecast.usbPowerIn;
		}
		
		interface phoneToRouter : WiFiInterface {
			end clientWiFi :>> mobilePhone.wifiClient;
			end routerWiFi :>> wifiRouter.routerPort;
		}
		
		interface deviceToRouter : DeviceWiFiInterface {
			end deviceWiFi :>> chromecast.wifiNet;
			end routerWiFi2 :>> wifiRouter.routerPort;
		}
		
		// Flow of cast command from phone through router to chromecast
		flow castFlow from mobilePhone.sendCastCommand.cmd to wifiRouter.routeCastCommand.forwarded to chromecast.wifiNet.castCmd;
		
		// Flow of media packets from router to chromecast
		flow mediaFlow from wifiRouter.routeMediaPackets.packets to chromecast.wifiNet.netPackets;
		
		// Flow of video signal from chromecast to television
		flow videoFlow from chromecast.hdmiOut.videoSignal to television.hdmiIn.videoSignal;
		
		// Flow of power from adapter to chromecast
		flow powerFlow from powerAdapter.convertPower.supply to chromecast.usbPowerIn.powerInput;
		
		// Status feedback flow
		flow statusFlow from chromecast.wifiNet.status to mobilePhone.wifiClient.status;
	}

	// ---------- Requirements ----------
	
	requirement def StreamingRequirement {
		doc /* The system shall allow a user to stream media from a mobile phone to a television via a Chromecast-like device. */
	}
	
	requirement def PortabilityRequirement {
		doc /* The Chromecast device shall be small, lightweight, and portable. */
		attribute maxWeight : Real = 0.05; // kg
		attribute maxVolume : Real = 50000; // mm^3
	}
	
	requirement def HDMIOutputRequirement {
		doc /* The Chromecast shall output video through an HDMI port supporting up to 4K UHD resolution. */
		attribute minWidth : ResolutionWidth = 3840;
		attribute minHeight : ResolutionHeight = 2160;
		attribute minRefreshRate : Integer = 60;
	}
	
	requirement def USBPowerRequirement {
		doc /* The Chromecast shall be powered through a USB port with low power consumption. */
		attribute requiredVoltage : Voltage = 5.0;
		attribute requiredCurrent : Current = 1.0;
		attribute maxPowerConsumption : PowerUnit = 3.0;
	}
	
	requirement def WiFiConnectivityRequirement {
		doc /* The Chromecast shall connect to a home WiFi network to receive cast commands and download media content. */
		attribute supportedStandard : String = "802.11ac";
		attribute minDataRate : DataRate = 100.0;
	}
	
	requirement def MediaProcessingRequirement {
		doc /* The Media Processor shall buffer, decode, and adaptively adjust stream quality based on network conditions. */
		attribute minBufferCapacity : BufferSize = 256;
		attribute adaptiveBitrate : Boolean = true;
		attribute supportedCodecs : String = "H.264, VP9, HEVC";
	}
	
	requirement def StateManagementRequirement {
		doc /* The Chromecast shall manage operational states including disconnected, discovering, authenticating, connected, idle, buffering, playing, paused, and error. */
		attribute maxTransitionTime : DurationValue = 5 [s];
		attribute gracefulErrorHandling : Boolean = true;
	}
	
	requirement def UserExperienceRequirement {
		doc /* The system shall provide a stable streaming experience with minimal buffering and graceful error recovery. */
		attribute maxBufferingTime : DurationValue = 10 [s];
		attribute maxLatency : DurationValue = 2 [s];
		attribute errorRecoveryTime : DurationValue = 30 [s];
	}
	
	requirement StreamingReq : StreamingRequirement {
		subject MediaStreamingSystem;
	}
	
	requirement PortabilityReq : PortabilityRequirement {
		subject Chromecast;
		verify weightCheck : Chromecast.weight <= maxWeight;
	}
	
	requirement HDMIReq : HDMIOutputRequirement {
		subject Chromecast;
		verify resolutionCheck : Chromecast.maxResolutionWidth >= minWidth;
	}
	
	requirement USBPowerReq : USBPowerRequirement {
		subject Chromecast;
		verify powerCheck : Chromecast.maxPowerConsumption <= maxPowerConsumption;
	}
	
	requirement WiFiReq : WiFiConnectivityRequirement {
		subject Chromecast.networkInterface;
		verify dataRateCheck : Chromecast.networkInterface.maxDataRate >= minDataRate;
	}
	
	requirement MediaProcReq : MediaProcessingRequirement {
		subject Chromecast.mediaProcessor;
		verify bufferCheck : Chromecast.mediaProcessor.bufferCapacity >= minBufferCapacity;
	}
	
	requirement StateMgmtReq : StateManagementRequirement {
		subject Chromecast;
	}
	
	requirement UXReq : UserExperienceRequirement {
		subject MediaStreamingSystem;
	}

}
