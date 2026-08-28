package MythTV_DVR {
	private import ISQ::*;
	private import ScalarValues::*;
	
	package ValueTypes {
		attribute def ChannelNumber :> Integer;
		attribute def Frequency_MHz :> Real;
		attribute def DataRate_Mbps :> Real;
		attribute def StorageCapacity_GB :> Real;
		attribute def Duration_s :> Real;
		attribute def Timestamp :> String;
		attribute def Resolution :> String;
	}
	
	package ItemTypes {
		private import ValueTypes::*;
		
		item def VideoStream {
			attribute bitrate : DataRate_Mbps;
			attribute resolution : Resolution;
		}
		item def AudioStream {
			attribute bitrate : DataRate_Mbps;
		}
		item def TVSignal {
			attribute channel : ChannelNumber;
			attribute frequency : Frequency_MHz;
			attribute video : VideoStream;
			attribute audio : AudioStream;
		}
		item def TuneCommand {
			attribute channel : ChannelNumber;
		}
		item def EncodedProgramFile {
			attribute fileName : String;
			attribute sizeGB : StorageCapacity_GB;
			attribute durationSec : Duration_s;
			attribute recordingTimestamp : Timestamp;
		}
		item def EPGEntry {
			attribute programId : String;
			attribute channel : ChannelNumber;
			attribute startTime : Timestamp;
			attribute endTime : Timestamp;
			attribute title : String;
		}
		item def EPGQuery {
			attribute channel : ChannelNumber;
			attribute timeSpanSec : Duration_s;
		}
		item def RecordingScheduleRequest {
			attribute programId : String;
		}
		item def RecordingScheduleResponse {
			attribute scheduleId : String;
			attribute conflictResolved : Boolean;
		}
		item def PlaybackRequest {
			attribute programId : String;
		}
		item def PlaybackCommand {
			attribute commandType : String;
			attribute seekPositionSec : Duration_s;
		}
		item def VideoFrame {
			attribute data : String;
		}
		item def AudioFrame {
			attribute data : String;
		}
	}
	
	package PortTypes {
		private import ItemTypes::*;
		
		port def TVSignalOut {
			out item tvSignal : TVSignal;
		}
		port def TVSignalIn {
			in item tvSignal : TVSignal;
		}
		port def EncodedFileOut {
			out item file : EncodedProgramFile;
		}
		port def EncodedFileIn {
			in item file : EncodedProgramFile;
		}
		port def TuneCommandIn {
			in item tune : TuneCommand;
		}
		port def EPGQueryIn {
			in item query : EPGQuery;
		}
		port def EPGResultOut {
			out item entries : EPGEntry[0..*];
		}
		port def ScheduleRequestIn {
			in item request : RecordingScheduleRequest;
		}
		port def ScheduleResponseOut {
			out item response : RecordingScheduleResponse;
		}
		port def PlaybackRequestIn {
			in item request : PlaybackRequest;
		}
		port def PlaybackCommandIn {
			in item command : PlaybackCommand;
		}
		port def VideoDisplayOut {
			out item videoFrame : VideoFrame;
		}
		port def AudioDisplayOut {
			out item audioFrame : AudioFrame;
		}
		port def ServerPort {
			in item scheduleRequest : RecordingScheduleRequest;
			out item scheduleResponse : RecordingScheduleResponse;
			in item epgQuery : EPGQuery;
			out item epgEntries : EPGEntry[0..*];
			in item playbackRequest : PlaybackRequest;
			out item recordedFile : EncodedProgramFile;
			out item liveSignal : TVSignal;
		}
		port def ClientPort {
			out item scheduleRequest : RecordingScheduleRequest;
			in item scheduleResponse : RecordingScheduleResponse;
			out item epgQuery : EPGQuery;
			in item epgEntries : EPGEntry[0..*];
			out item playbackRequest : PlaybackRequest;
			in item recordedFile : EncodedProgramFile;
			in item liveSignal : TVSignal;
		}
	}
	
	package Parts {
		private import ValueTypes::*;
		private import ItemTypes::*;
		private import PortTypes::*;
		
		part def TunerCard {
			port signalOut : TVSignalOut;
			port controlIn : TuneCommandIn;
			attribute tunerId : String;
		}
		part def VideoEncoder {
			port signalIn : TVSignalIn;
			port encodedOut : EncodedFileOut;
			attribute encoderId : String;
		}
		part def StorageSubsystem {
			port fileIn : EncodedFileIn;
			port fileOut : EncodedFileOut;
			port playbackRequestIn : PlaybackRequestIn;
			attribute totalCapacityGB : StorageCapacity_GB;
			attribute usedSpaceGB : StorageCapacity_GB;
		}
		part def EPGDatabase {
			port schedulerQueryIn : EPGQueryIn;
			port schedulerResultOut : EPGResultOut;
			port clientQueryIn : EPGQueryIn;
			port clientResultOut : EPGResultOut;
			attribute entries : EPGEntry[0..*];
		}
		part def Scheduler {
			port scheduleRequestIn : ScheduleRequestIn;
			port scheduleResponseOut : ScheduleResponseOut;
			port epgQueryOut : ~EPGQueryIn;
			port epgResultIn : ~EPGResultOut;
			port tuner1ControlOut : ~TuneCommandIn;
			port tuner2ControlOut : ~TuneCommandIn;
		}
		
		part def BackendServer {
			part tuner1 : TunerCard;
			part tuner2 : TunerCard;
			part encoder1 : VideoEncoder;
			part encoder2 : VideoEncoder;
			part storage : StorageSubsystem;
			part epg : EPGDatabase;
			part scheduler : Scheduler;
			port serverIF : ServerPort;
			
			connect tuner1.signalOut to encoder1.signalIn;
			connect tuner1.signalOut to serverIF.liveSignal;
			connect encoder1.encodedOut to storage.fileIn;
			connect tuner2.signalOut to encoder2.signalIn;
			connect encoder2.encodedOut to storage.fileIn;
			connect scheduler.tuner1ControlOut to tuner1.controlIn;
			connect scheduler.tuner2ControlOut to tuner2.controlIn;
			connect scheduler.epgQueryOut to epg.schedulerQueryIn;
			connect epg.schedulerResultOut to scheduler.epgResultIn;
			connect serverIF.scheduleRequest to scheduler.scheduleRequestIn;
			connect scheduler.scheduleResponseOut to serverIF.scheduleResponse;
			connect serverIF.epgQuery to epg.clientQueryIn;
			connect epg.clientResultOut to serverIF.epgEntries;
			connect serverIF.playbackRequest to storage.playbackRequestIn;
			connect storage.fileOut to serverIF.recordedFile;
		}
		
		part def GUI {
			port scheduleRequestOut : ~ScheduleRequestIn;
			port scheduleResponseIn : ~ScheduleResponseOut;
			port epgQueryOut : ~EPGQueryIn;
			port epgResultIn : ~EPGResultOut;
			port playbackRequestOut : ~PlaybackRequestIn;
			port playbackCommandOut : ~PlaybackCommandIn;
		}
		
		part def PlaybackEngine {
			port liveStreamIn : TVSignalIn;
			port fileStreamIn : EncodedFileIn;
			port videoDisplayOut : VideoDisplayOut;
			port audioDisplayOut : AudioDisplayOut;
			port commandIn : PlaybackCommandIn;
		}
		
		part def FrontendClient {
			part gui : GUI;
			part playback : PlaybackEngine;
			port clientIF : ClientPort;
			
			connect gui.scheduleRequestOut to clientIF.scheduleRequest;
			connect clientIF.scheduleResponse to gui.scheduleResponseIn;
			connect gui.epgQueryOut to clientIF.epgQuery;
			connect clientIF.epgEntries to gui.epgResultIn;
			connect gui.playbackRequestOut to clientIF.playbackRequest;
			connect gui.playbackCommandOut to playback.commandIn;
			connect clientIF.recordedFile to playback.fileStreamIn;
			connect clientIF.liveSignal to playback.liveStreamIn;
		}
		
		part def MythTVDVRSystem {
			part backend : BackendServer;
			part frontend : FrontendClient;
			
			connect frontend.clientIF.scheduleRequest to backend.serverIF.scheduleRequest;
			connect backend.serverIF.scheduleResponse to frontend.clientIF.scheduleResponse;
			connect frontend.clientIF.epgQuery to backend.serverIF.epgQuery;
			connect backend.serverIF.epgEntries to frontend.clientIF.epgEntries;
			connect frontend.clientIF.playbackRequest to backend.serverIF.playbackRequest;
			connect backend.serverIF.recordedFile to frontend.clientIF.recordedFile;
			connect backend.serverIF.liveSignal to frontend.clientIF.liveSignal;
		}
	}
	
	package Behaviors {
		private import ValueTypes::*;
		private import ItemTypes::*;
		private import Parts::*;
		
		action def ResolveSchedulingConflicts;
		action def AllocateTuner;
		action def TuneTuner;
		action def EncodeVideo;
		action def StoreEncodedFile;
		action def StartPlaybackDecode;
		action def PausePlayback;
		action def ResumePlayback;
		action def StopPlayback;
		action def SeekPlayback;
		
		state def SchedulerStates {
			state idle;
			state scheduling;
			state recording;
			
			transition schedule
				first idle
				accept request : RecordingScheduleRequest
				do action ResolveSchedulingConflicts
				then scheduling;
			
			transition allocate
				first scheduling
				accept request : RecordingScheduleRequest
				do action AllocateTuner
				then recording;
			
			transition finish
				first recording
				accept request : RecordingScheduleRequest
				do action StoreEncodedFile
				then idle;
		}
		
		state def PlaybackEngineStates {
			state stopped;
			state playing;
			state paused;
			
			transition play
				first stopped
				accept cmd : PlaybackCommand
				if cmd.commandType == "play"
				do action StartPlaybackDecode
				then playing;
			
			transition pause
				first playing
				accept cmd : PlaybackCommand
				if cmd.commandType == "pause"
				do action PausePlayback
				then paused;
			
			transition resume
				first paused
				accept cmd : PlaybackCommand
				if cmd.commandType == "resume"
				do action ResumePlayback
				then playing;
			
			transition stopFromPlaying
				first playing
				accept cmd : PlaybackCommand
				if cmd.commandType == "stop"
				do action StopPlayback
				then stopped;
			
			transition stopFromPaused
				first paused
				accept cmd : PlaybackCommand
				if cmd.commandType == "stop"
				do action StopPlayback
				then stopped;
			
			transition seek
				first playing
				accept cmd : PlaybackCommand
				if cmd.commandType == "seek"
				do action SeekPlayback
				then playing;
		}
		
		state def BackendServerStates {
			state idle;
			state recording;
			state streaming;
			
			transition startRecording
				first idle
				accept request : RecordingScheduleRequest
				then recording;
			
			transition stopRecording
				first recording
				accept request : RecordingScheduleRequest
				then idle;
			
			transition startStreaming
				first idle
				accept request : PlaybackRequest
				then streaming;
			
			transition stopStreaming
				first streaming
				accept request : PlaybackRequest
				then idle;
		}
	}
	
	package Requirements {
		private import Parts::*;
		
		requirement def ClientServerArchitecture {
			doc /* The system shall separate backend recording and storage functions from frontend user interaction and viewing. */
		}
		requirement def SimultaneousRecording {
			doc /* The system shall support recording at least two programs simultaneously using multiple tuner cards. */
		}
		requirement def LiveTvPause {
			doc /* The system shall allow pausing and resuming live TV streams. */
		}
		requirement def AutomaticSchedulingConflictResolution {
			doc /* The scheduler shall automatically resolve recording schedule conflicts when too many shows are scheduled at once. */
		}
		requirement def EPGIntegration {
			doc /* The backend shall maintain an Electronic Program Guide database with up-to-date TV listings. */
		}
		requirement def PlaybackControl {
			doc /* The frontend playback engine shall support pause, resume, stop, and seek operations on recordings. */
		}
		requirement def StorageManagement {
			doc /* The storage subsystem shall manage available disk space and organize the library of recorded programs. */
		}
		
		requirement clientServerReq : ClientServerArchitecture {
			subject :>> MythTVDVRSystem;
		}
		requirement simultaneousRecReq : SimultaneousRecording {
			subject :>> BackendServer;
		}
		requirement liveTvPauseReq : LiveTvPause {
			subject :>> PlaybackEngine;
		}
		requirement conflictResolutionReq : AutomaticSchedulingConflictResolution {
			subject :>> Scheduler;
		}
		requirement epgReq : EPGIntegration {
			subject :>> EPGDatabase;
		}
		requirement playbackControlReq : PlaybackControl {
			subject :>> PlaybackEngine;
		}
		requirement storageReq : StorageManagement {
			subject :>> StorageSubsystem;
		}
	}
	
	part mythtvSystem : MythTVDVRSystem;
}
