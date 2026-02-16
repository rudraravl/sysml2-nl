package 'Broadcast Automation System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def ContentID :> String;
	attribute def ScheduleID :> String;
	attribute def TimecodeValue :> String;
	attribute def ErrorCode :> Integer;
	
	attribute def PlaylistEntry {
		attribute contentID : ContentID;
		attribute scheduledStart : TimeValue;
		attribute duration : DurationValue;
		attribute priority : Integer;
	}
	
	attribute def BroadcastStatus {
		attribute onAir : Boolean;
		attribute currentContent : ContentID;
		attribute timecode : TimecodeValue;
		attribute errorState : ErrorCode;
	}
	
	item def MediaAsset {
		attribute assetID : ContentID;
		attribute duration : DurationValue;
		attribute videoFormat : String;
		attribute audioChannels : Integer;
		attribute fileSize : MassValue;
	}
	
	item def VideoSignal {
		attribute resolution : String;
		attribute frameRate : FrequencyValue;
		attribute bitrate : Real;
	}
	
	item def AudioSignal {
		attribute sampleRate : FrequencyValue;
		attribute bitDepth : Integer;
		attribute channels : Integer;
	}
	
	port def MediaInputPort {
		in item videoIn : VideoSignal;
		in item audioIn : AudioSignal;
	}
	
	port def MediaOutputPort {
		out item videoOut : VideoSignal;
		out item audioOut : AudioSignal;
	}
	
	port def ControlPort {
		in attribute commands : String[*];
		out attribute status : BroadcastStatus;
	}
	
	port def SchedulePort {
		in attribute playlist : PlaylistEntry[*];
		out attribute currentEntry : PlaylistEntry;
	}
	
	part def MediaServer {
		port mediaOut : MediaOutputPort;
		port control : ControlPort;
		
		attribute storedLibrary : MediaAsset[*];
		attribute currentAsset : MediaAsset;
		
		action def LoadAsset {
			in assetID : ContentID;
			out asset : MediaAsset;
		}
		
		action def PlayAsset {
			in asset : MediaAsset;
			out video : VideoSignal;
			out audio : AudioSignal;
		}
		
		perform action playback[*] ordered;
	}
	
	part def VideoRouter {
		port input1 : MediaInputPort;
		port input2 : MediaInputPort;
		port input3 : MediaInputPort;
		port output : MediaOutputPort;
		port control : ControlPort;
		
		attribute activeInput : Integer;
		
		action def SwitchInput {
			in inputNumber : Integer;
			out switched : Boolean;
		}
		
		action def RouteSignal {
			in video : VideoSignal;
			in audio : AudioSignal;
			out routedVideo : VideoSignal;
			out routedAudio : AudioSignal;
		}
	}
	
	part def PlayoutAutomation {
		port scheduleIn : SchedulePort;
		port controlOut : ControlPort;
		
		attribute activePlaylist : PlaylistEntry[*];
		attribute systemClock : TimeValue;
		attribute nextEvent : PlaylistEntry;
		
		action def LoadSchedule {
			in playlist : PlaylistEntry[*];
			out loaded : Boolean;
		}
		
		action def MonitorTime {
			in currentTime : TimeValue;
			in schedule : PlaylistEntry[*];
			out nextItem : PlaylistEntry;
		}
		
		action def IssueCommand {
			in targetItem : PlaylistEntry;
			out command : String;
		}
		
		state automationControl {
			entry; then idle;
			
			state idle {
				entry action initializeSystem;
			}
			
			accept scheduleLoaded;
			then standby;
			
			state standby {
				entry action loadPlaylist;
			}
			
			accept startCommand;
			then active;
			
			state active {
				entry action startBroadcast;
				do action monitorAndExecute;
			}
			
			accept errorDetected;
			then emergency;
			
			state emergency {
				entry action activateBackup;
			}
			
			accept systemRecovered;
			then active;
			
			accept stopCommand;
			then standby;
		}
	}
	
	part def MasterControl {
		port primaryIn : MediaInputPort;
		port backupIn : MediaInputPort;
		port airOut : MediaOutputPort;
		port control : ControlPort;
		
		attribute onAirSource : Integer;
		attribute backupActive : Boolean;
		
		action def SelectSource {
			in sourceID : Integer;
			out selected : Boolean;
		}
		
		action def MonitorSignal {
			in video : VideoSignal;
			in audio : AudioSignal;
			out quality : Real;
		}
		
		action def Failover {
			in primaryFailed : Boolean;
			out switchedToBackup : Boolean;
		}
	}
	
	part def GraphicsEngine {
		port graphicsOut : MediaOutputPort;
		port control : ControlPort;
		
		attribute templates : String[*];
		attribute activeGraphic : String;
		
		action def RenderGraphic {
			in templateID : String;
			in data : String[*];
			out graphic : VideoSignal;
		}
		
		action def OverlayGraphic {
			in baseVideo : VideoSignal;
			in graphic : VideoSignal;
			out composited : VideoSignal;
		}
	}
	
	part def TransmissionEncoder {
		port input : MediaInputPort;
		port control : ControlPort;
		
		attribute encodingProfile : String;
		attribute outputBitrate : Real;
		
		action def EncodeStream {
			in video : VideoSignal;
			in audio : AudioSignal;
			out encodedStream : String;
		}
		
		action def MonitorEncoder {
			out health : BroadcastStatus;
		}
	}
	
	part broadcastSystem : BroadcastAutomationSystem {
		part primaryServer : MediaServer;
		part backupServer : MediaServer;
		part router : VideoRouter;
		part automation : PlayoutAutomation;
		part masterControl : MasterControl;
		part graphics : GraphicsEngine;
		part encoder : TransmissionEncoder;
		
		connect primaryServer.mediaOut to router.input1;
		connect backupServer.mediaOut to router.input2;
		connect graphics.graphicsOut to router.input3;
		connect router.output to masterControl.primaryIn;
		connect masterControl.airOut to encoder.input;
		connect automation.controlOut to primaryServer.control;
		connect automation.controlOut to router.control;
		connect automation.controlOut to masterControl.control;
		
		perform action orchestrateBroadcast;
	}
	
	part def BroadcastAutomationSystem {
		doc /*
		A broadcast automation system that manages the complete workflow of television 
		or radio content delivery. The system automatically schedules, plays out, and 
		monitors media content according to a predefined playlist, ensuring continuous 
		and reliable on-air transmission with minimal human intervention.
		*/
		
		perform action orchestrateBroadcast : OrchestrateBroadcast;
	}
	
	action def CheckSchedule {
		in currentTime : TimeValue;
		in playlist : PlaylistEntry[*];
		out upcomingEvent : PlaylistEntry;
		out timeToEvent : DurationValue;
	}
	
	action def CueContent {
		in entry : PlaylistEntry;
		out contentReady : Boolean;
	}
	
	action def ExecutePlayout {
		in entry : PlaylistEntry;
		out playing : Boolean;
	}
	
	action def VerifyOutput {
		in expectedContent : ContentID;
		out verified : Boolean;
	}
	
	action def HandleFailure {
		in errorCode : ErrorCode;
		out recovered : Boolean;
	}
	
	action def OrchestrateBroadcast {
		first start;
		then merge continuousBroadcast;
		
		action checkSchedule : CheckSchedule {
			in currentTime : TimeValue;
			in playlist : PlaylistEntry[*];
			out upcomingEvent : PlaylistEntry;
			out timeToEvent : DurationValue;
		}
		
		then decide scheduleDecision;
			if checkSchedule.timeToEvent.num <= 30.0 then cueContent;
			if checkSchedule.timeToEvent.num > 30.0 then continuousBroadcast;
		
		action cueContent : CueContent {
			in entry = checkSchedule.upcomingEvent;
			out contentReady : Boolean;
		}
		
		then decide cueDecision;
			if cueContent.contentReady == true then executePlayout;
			if cueContent.contentReady == false then handleFailure;
		
		action executePlayout : ExecutePlayout {
			in entry = checkSchedule.upcomingEvent;
			out playing : Boolean;
		}
		
		then action verifyOutput : VerifyOutput {
			in expectedContent = checkSchedule.upcomingEvent.contentID;
			out verified : Boolean;
		}
		
		then decide verifyDecision;
			if verifyOutput.verified == true then continuousBroadcast;
			if verifyOutput.verified == false then handleFailure;
		
		action handleFailure : HandleFailure {
			in errorCode : ErrorCode;
			out recovered : Boolean;
		}
		
		then continuousBroadcast;
		then done;
	}
	
	requirement def ContinuousOperationRequirement {
		doc /*
		The broadcast automation system shall maintain continuous on-air operation 
		with 99.95% uptime, measured over any 30-day period.
		*/
		
		require constraint {
			uptimePercentage >= 99.95
		}
		
		attribute uptimePercentage : Real;
	}
	
	requirement def TimingAccuracyRequirement {
		doc /*
		The system shall execute all scheduled playout events with frame-accurate 
		timing, not exceeding 1 frame deviation from scheduled time.
		*/
		
		require constraint {
			timingError.num <= frameTime.num
		}
		
		attribute timingError : DurationValue;
		attribute frameTime : DurationValue;
	}
	
	requirement def AutomatedFailoverRequirement {
		doc /*
		Upon detection of primary playout failure, the system shall automatically 
		switch to backup playout within 2 seconds without interrupting on-air signal.
		*/
		
		require constraint {
			failoverTime <= 2.0
		}
		
		attribute failoverTime : Real;
	}
	
	requirement def ScheduleComplianceRequirement {
		doc /*
		The system shall execute at least 99.5% of scheduled playlist events 
		as programmed, with deviations logged and reported.
		*/
		
		require constraint {
			complianceRate >= 99.5
		}
		
		attribute complianceRate : Real;
	}
	
	requirement systemRequirements {
		doc /*
		Top-level requirements for the broadcast automation system ensuring 
		reliable, accurate, and compliant content delivery.
		*/
		
		require continuousOperation : ContinuousOperationRequirement;
		require timingAccuracy : TimingAccuracyRequirement;
		require automatedFailover : AutomatedFailoverRequirement;
		require scheduleCompliance : ScheduleComplianceRequirement;
	}
	
	requirement primaryFunctionRequirement {
		doc /*
		The broadcast automation system shall automatically manage the scheduling, 
		playout, routing, and transmission of broadcast content according to a 
		predefined playlist, ensuring continuous and reliable on-air delivery with 
		minimal human intervention.
		*/
		
		satisfy by broadcastSystem.orchestrateBroadcast;
	}
}
