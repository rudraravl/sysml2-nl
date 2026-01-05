package 'Sonos Multi-Room Audio System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def NetworkSSID;
	attribute def IPAddress;
	attribute def MACAddress;
	attribute def AudioCodec;
	attribute def TrackID;
	attribute def PlaylistID;
	attribute def RoomID;
	
	value def AudioQuality {
		attribute sampleRate : Real;
		attribute bitDepth : Real;
		attribute channels : Integer;
	}
	
	value def VolumeLevel : Real {
		assert constraint { 0.0 <= self and self <= 100.0 }
	}
	
	value def LatencyValue : TimeValue {
		assert constraint { self < 2.0 [s] }
	}
	
	item def AudioStream {
		attribute codec : AudioCodec;
		attribute quality : AudioQuality;
		attribute timestamp : TimeValue;
	}
	
	item def PlaybackCommand {
		attribute trackID : TrackID;
		attribute targetRooms : RoomID[1..*];
		attribute volume : VolumeLevel;
	}
	
	item def PauseCommand;
	item def StopCommand;
	item def VolumeAdjustCommand {
		attribute newVolume : VolumeLevel;
	}
	item def GroupRoomsCommand {
		attribute rooms : RoomID[*];
	}
	
	item def ControlCommand {
		attribute playCmd : PlaybackCommand[0..1];
		attribute pauseCmd : PauseCommand[0..1];
		attribute stopCmd : StopCommand[0..1];
		attribute volumeCmd : VolumeAdjustCommand[0..1];
		attribute groupCmd : GroupRoomsCommand[0..1];
	}
	
	port def NetworkPort {
		in commandIn : ControlCommand;
		out statusOut : AudioStream;
		attribute address : IPAddress;
	}
	
	port def AudioOutputPort {
		out audioSignal : AudioStream;
	}
	
	port def MeshPort {
		inout syncData : AudioStream;
		attribute signalStrength : PowerValue;
	}
	
	state def SpeakerStateMachine {
		entry; then idle;
		
		state idle;
		
		transition idle_to_connecting
			first idle
			accept connectCommand : ControlCommand
			then connecting;
		
		state connecting;
		
		transition connecting_to_ready
			first connecting
			then ready;
		
		state ready;
		
		transition ready_to_buffering
			first ready
			accept playCommand : PlaybackCommand
			then buffering;
		
		state buffering;
		
		transition buffering_to_playing
			first buffering
			then playing;
		
		state playing;
		
		transition playing_to_paused
			first playing
			accept pauseCommand : ControlCommand
			then paused;
		
		state paused;
		
		transition paused_to_playing
			first paused
			accept resumeCommand : ControlCommand
			then playing;
		
		transition playing_to_ready
			first playing
			accept stopCommand : ControlCommand
			then ready;
		
		transition ready_to_idle
			first ready
			accept disconnectCommand : ControlCommand
			then idle;
	}
	
	part def SonosSpeaker {
		attribute speakerID : RoomID;
		attribute currentVolume : VolumeLevel;
		attribute macAddress : MACAddress;
		
		port networkPort : NetworkPort;
		port meshPort : MeshPort;
		port audioOut : AudioOutputPort;
		
		part wifiModule {
			attribute ssid : NetworkSSID;
			in networkStream : AudioStream;
			out decodedStream : AudioStream;
		}
		
		part audioProcessor {
			in digitalAudio : AudioStream;
			out processedAudio : AudioStream;
		}
		
		part amplifier {
			in audioInput : AudioStream;
			in volumeLevel : VolumeLevel;
			out amplifiedAudio : AudioStream;
		}
		
		part driver {
			in audioSignal : AudioStream;
		}
		
		exhibit state speakerState : SpeakerStateMachine;
	}
	
	part def SonosController {
		attribute controllerID : MACAddress;
		
		port controlPort : NetworkPort;
		
		part userInterface {
			in userInput : ControlCommand;
			out displayStatus : AudioStream;
		}
		
		part playbackEngine {
			in command : PlaybackCommand;
			out streamRequest : AudioStream;
		}
		
		part groupManager {
			in groupCommand : RoomID[*];
			out synchronizationSignal : AudioStream;
		}
	}
	
	part def MusicSource {
		attribute sourceType : AudioCodec;
		
		port streamPort {
			out musicStream : AudioStream;
		}
		
		part streamingService {
			attribute serviceName : String;
			out stream : AudioStream;
		}
		
		part localLibrary {
			attribute libraryPath : String;
			out libraryStream : AudioStream;
		}
	}
	
	action def ReceiveAudioStream {
		in sourceStream : AudioStream;
		in networkAddress : IPAddress;
		out bufferedAudio : AudioStream;
	}
	
	action def SynchronizePlayback {
		in masterTimestamp : TimeValue;
		in audioData : AudioStream;
		in speakerGroup : RoomID[1..*];
		out synchronizedAudio : AudioStream;
	}
	
	action def ProcessAudio {
		in rawAudio : AudioStream;
		in volumeSetting : VolumeLevel;
		out processedAudio : AudioStream;
	}
	
	action def AmplifyAndOutput {
		in audioInput : AudioStream;
		in volume : VolumeLevel;
		out audioOutput : AudioStream;
	}
	
	action def MultiRoomAudioPlayback {
		in musicSource : AudioStream;
		in targetRooms : RoomID[1..*];
		in volumeLevels : VolumeLevel[1..*];
		out playbackStatus : Boolean;
		
		first start;
		then action receive : ReceiveAudioStream {
			in sourceStream = musicSource;
			out bufferedAudio;
		}
		then merge continuePlayback;
		then action synchronize : SynchronizePlayback {
			in audioData = receive.bufferedAudio;
			in speakerGroup = targetRooms;
			out synchronizedAudio;
		}
		then decide;
			if synchronize.synchronizedAudio != null then processAudio;
			if synchronize.synchronizedAudio == null then errorHandling;
		action processAudio : ProcessAudio {
			in rawAudio = synchronize.synchronizedAudio;
			out processedAudio;
		}
		then action amplifyOutput : AmplifyAndOutput {
			in audioInput = processAudio.processedAudio;
			out audioOutput;
		}
		then continuePlayback;
		action errorHandling {
			then done;
		}
	}
	
	requirement def SynchronizationRequirement {
		doc /* All speakers in a synchronized group shall maintain audio playback alignment within 2 milliseconds. */
		
		subject speakers : SonosSpeaker[2..*];
		
		require constraint {
			doc /* Maximum inter-speaker latency must not exceed 2ms */
		}
	}
	
	requirement def AudioFidelityRequirement {
		doc /* System shall support lossless audio quality up to 24-bit/48kHz. */
		
		subject audioQuality : AudioQuality;
		
		require constraint {
			audioQuality.bitDepth <= 24.0 and
			audioQuality.sampleRate <= 48000.0
		}
	}
	
	requirement def WirelessConnectivityRequirement {
		doc /* Each speaker shall maintain stable wireless mesh connectivity with adjacent speakers. */
		
		subject speaker : SonosSpeaker;
	}
	
	requirement def MultiRoomCapabilityRequirement {
		doc /* System shall support simultaneous playback across multiple rooms with independent or grouped control. */
		
		subject system : SonosSystem;
	}
	
	requirement <'SYS-REQ-001'> primarySystemRequirement {
		doc /* The Sonos system shall deliver synchronized, high-fidelity multi-room audio playback across a wireless mesh network. */
		
		assume constraint wifiNetworkAvailable {
			doc /* A WiFi network with sufficient bandwidth (minimum 54 Mbps) is available. */
		}
		
		require SynchronizationRequirement;
		require AudioFidelityRequirement;
		require WirelessConnectivityRequirement;
		require MultiRoomCapabilityRequirement;
	}
	
	part def SonosSystem {
		part livingRoom : SonosSpeaker;
		part kitchen : SonosSpeaker;
		part bedroom : SonosSpeaker;
		part controller : SonosController;
		part musicSource : MusicSource;
	}
	
	part sonosSystem : SonosSystem {
		doc /* Complete Sonos wireless multi-room audio system installation */
		
		part livingRoom : SonosSpeaker {
			:>> speakerID = "LivingRoom";
			:>> currentVolume = 50.0;
		}
		
		part kitchen : SonosSpeaker {
			:>> speakerID = "Kitchen";
			:>> currentVolume = 45.0;
		}
		
		part bedroom : SonosSpeaker {
			:>> speakerID = "Bedroom";
			:>> currentVolume = 30.0;
		}
		
		part controller : SonosController;
		
		part musicSource : MusicSource;
		
		connection meshLink1 connect
			livingRoom.meshPort to kitchen.meshPort;
		
		connection meshLink2 connect
			kitchen.meshPort to bedroom.meshPort;
		
		connection controlLink1 connect
			controller.controlPort to livingRoom.networkPort;
		
		connection controlLink2 connect
			controller.controlPort to kitchen.networkPort;
		
		connection controlLink3 connect
			controller.controlPort to bedroom.networkPort;
		
		perform action playMusic : MultiRoomAudioPlayback {
			in musicSource = sonosSystem.musicSource.streamPort.musicStream;
			in targetRooms = (livingRoom.speakerID, kitchen.speakerID);
			in volumeLevels = (livingRoom.currentVolume, kitchen.currentVolume);
		}
	}
}
