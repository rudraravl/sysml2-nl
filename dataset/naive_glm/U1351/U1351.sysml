package MythTV_DVR {
    import ScalarValues::*;
    
    // ===== Value Types with Units =====
    value type def ChannelNumber :> Integer {
        attribute unit : String = "channel";
    }
    value type def FrequencyValue :> Real {
        attribute unit : String = "Hz";
    }
    value type def BitrateValue :> Real {
        attribute unit : String = "Mbps";
    }
    value type def DiskSpaceValue :> Real {
        attribute unit : String = "GB";
    }
    value type def DurationValue :> Real {
        attribute unit : String = "s";
    }
    value type def TimestampValue :> Real {
        attribute unit : String = "s";
    }
    
    // ===== Item Types =====
    item def BroadcastSignal {
        attribute channel : ChannelNumber;
        attribute frequency : FrequencyValue;
        attribute signalStrength : Real;
    }
    
    item def EncodedStream {
        attribute bitrate : BitrateValue;
        attribute duration : DurationValue;
        attribute codec : String;
    }
    
    item def RecordedProgram {
        attribute title : String;
        attribute channel : ChannelNumber;
        attribute startTime : TimestampValue;
        attribute duration : DurationValue;
        attribute fileSize : DiskSpaceValue;
        attribute filePath : String;
    }
    
    item def ProgramGuideEntry {
        attribute title : String;
        attribute channel : ChannelNumber;
        attribute startTime : TimestampValue;
        attribute duration : DurationValue;
        attribute description : String;
        attribute episodeId : String optional;
    }
    
    item def RecordingRequest {
        attribute title : String;
        attribute channel : ChannelNumber;
        attribute startTime : TimestampValue;
        attribute duration : DurationValue;
        attribute priority : Integer = 0;
    }
    
    item def PlaybackCommand {
        attribute command : String;
        attribute seekPosition : TimestampValue optional;
    }
    
    item def PlaybackStatus {
        attribute isPlaying : Boolean;
        attribute isPaused : Boolean;
        attribute currentPosition : TimestampValue;
        attribute totalDuration : DurationValue;
    }
    
    // ===== Port Definitions =====
    port def BroadcastPort {
        out broadcast : BroadcastSignal;
    }
    
    port def EncodedStreamPort {
        out stream : EncodedStream;
    }
    
    port def StoragePort {
        out recorded : RecordedProgram;
    }
    
    port def ControlPort {
        in request : RecordingRequest;
        in command : PlaybackCommand;
        out guide : ProgramGuideEntry;
        out status : PlaybackStatus;
    }
    
    // ===== Tuner Card =====
    part def TunerCard {
        port broadcastIn : BroadcastPort;
        port streamOut : EncodedStreamPort;
        
        attribute locked : Boolean = false;
        attribute currentChannel : ChannelNumber optional;
        attribute maxFrequency : FrequencyValue = 1.0e9;
        
        state def TunerState {
            entry action assign locked = false;
            state Idle {
                entry action assign locked = false;
            }
            state Tuning {
                entry action assign locked = false;
            }
            state Locked {
                entry action assign locked = true;
            }
            transition Idle to Tuning
                when broadcastIn.broadcast.channel != currentChannel
                then action assign currentChannel = broadcastIn.broadcast.channel;
            transition Tuning to Locked
                when broadcastIn.broadcast.signalStrength > 0.5;
            transition Locked to Idle
                when broadcastIn.broadcast.channel != currentChannel;
        }
        
        action def TuneToChannel {
            in channel : ChannelNumber;
            then action assign currentChannel = channel;
            then action assign locked = true;
        }
        
        action def CaptureSignal {
            out captured : EncodedStream;
            then action assign captured.bitrate = 0.0;
            then action assign captured.codec = "raw";
        }
    }
    
    // ===== Video Encoder =====
    part def VideoEncoder {
        port streamIn : EncodedStreamPort;
        port streamOut : EncodedStreamPort;
        
        attribute encodingBitrate : BitrateValue = 8.0;
        attribute codec : String = "MPEG-4";
        attribute active : Boolean = false;
        
        action def Encode {
            in raw : EncodedStream;
            out encoded : EncodedStream;
            then action assign encoded.bitrate = encodingBitrate;
            then action assign encoded.codec = codec;
            then action assign active = true;
        }
        
        action def StopEncoding {
            then action assign active = false;
        }
    }
    
    // ===== Storage Subsystem =====
    part def StorageSubsystem {
        port storageIn : StoragePort;
        port storageOut : StoragePort;
        
        attribute totalSpace : DiskSpaceValue = 2000.0;
        attribute usedSpace : DiskSpaceValue = 0.0;
        attribute recordings : RecordedProgram[0..*];
        
        attribute freeSpace : DiskSpaceValue = totalSpace - usedSpace;
        
        action def SaveRecording {
            in program : RecordedProgram;
            then action append recordings = program;
            then action assign usedSpace = usedSpace + program.fileSize;
        }
        
        action def RetrieveRecording {
            in title : String;
            out program : RecordedProgram;
            then action select program from recordings where program.title == title;
        }
        
        action def DeleteRecording {
            in title : String;
            then action remove recordings where recordings.title == title;
            then action assign usedSpace = usedSpace - recordings.fileSize;
        }
        
        action def ManageDiskSpace {
            then action assign freeSpace = totalSpace - usedSpace;
            then if freeSpace < 50.0 then DeleteRecording
        }
    }
    
    // ===== EPG Database =====
    part def EPGDatabase {
        port controlOut : ControlPort;
        
        attribute listings : ProgramGuideEntry[0..*];
        attribute lastUpdate : TimestampValue = 0.0;
        attribute updateInterval : DurationValue = 86400.0;
        
        action def UpdateListings {
            then action assign lastUpdate = lastUpdate + updateInterval;
        }
        
        action def QueryGuide {
            out entries : ProgramGuideEntry[0..*];
            then action assign entries = listings;
        }
        
        action def QueryByChannel {
            in channel : ChannelNumber;
            out entries : ProgramGuideEntry[0..*];
            then action select entries from listings where listings.channel == channel;
        }
    }
    
    // ===== Scheduler =====
    part def Scheduler {
        port controlIn : ControlPort;
        
        attribute scheduledRecordings : RecordingRequest[0..*];
        attribute maxConcurrent : Integer = 4;
        attribute conflictCount : Integer = 0;
        
        action def ScheduleRecording {
            in request : RecordingRequest;
            then action append scheduledRecordings = request;
            then action ResolveConflicts;
        }
        
        action def ResolveConflicts {
            then action count overlapping recordings;
            then if count > maxConcurrent then action assign conflictCount = count - maxConcurrent;
            then action drop lowest priority recordings;
        }
        
        action def CancelRecording {
            in title : String;
            then action remove scheduledRecordings where scheduledRecordings.title == title;
        }
        
        action def GetNextRecording {
            out request : RecordingRequest;
            then action select request from scheduledRecordings where request.startTime is earliest;
        }
    }
    
    // ===== Backend Server =====
    part def BackendServer {
        port controlIn : ControlPort;
        port streamOut : EncodedStreamPort;
        port storageOut : StoragePort;
        
        part tuners : TunerCard[1..4];
        part encoders : VideoEncoder[1..4];
        part storage : StorageSubsystem;
        part epg : EPGDatabase;
        part scheduler : Scheduler;
        
        connection broadcastToEncoder connect tuners.streamOut to encoders.streamIn;
        connection encoderToStorage connect encoders.streamOut to storage.storageIn;
        connection controlToScheduler connect controlIn to scheduler.controlIn;
        connection controlToEPG connect controlIn to epg.controlOut;
        
        action def InitiateRecording {
            in request : RecordingRequest;
            then action select available tuner;
            then action TuneToChannel;
            then action Encode;
            then action SaveRecording;
        }
        
        action def StreamToClient {
            in title : String;
            then action RetrieveRecording;
            then action stream recorded file to frontend;
        }
        
        action def HandleConflict {
            then action ResolveConflicts;
        }
    }
    
    // ===== Playback Engine =====
    part def PlaybackEngine {
        port streamIn : EncodedStreamPort;
        port controlIn : ControlPort;
        
        attribute isPlaying : Boolean = false;
        attribute isPaused : Boolean = false;
        attribute currentPosition : TimestampValue = 0.0;
        attribute totalDuration : DurationValue = 0.0;
        attribute playbackSpeed : Real = 1.0;
        
        state def PlaybackState {
            state Stopped {
                entry action assign isPlaying = false;
                entry action assign isPaused = false;
                entry action assign currentPosition = 0.0;
            }
            state Playing {
                entry action assign isPlaying = true;
                entry action assign isPaused = false;
            }
            state Paused {
                entry action assign isPaused = true;
                entry action assign isPlaying = false;
            }
            transition Stopped to Playing
                when controlIn.command.command == "play";
            transition Playing to Paused
                when controlIn.command.command == "pause";
            transition Paused to Playing
                when controlIn.command.command == "resume";
            transition Playing to Stopped
                when controlIn.command.command == "stop";
            transition Paused to Stopped
                when controlIn.command.command == "stop";
            transition Playing to Playing
                when controlIn.command.command == "seek"
                then action assign currentPosition = controlIn.command.seekPosition;
            transition Paused to Paused
                when controlIn.command.command == "seek"
                then action assign currentPosition = controlIn.command.seekPosition;
        }
        
        action def Decode {
            in stream : EncodedStream;
            then action assign totalDuration = stream.duration;
        }
        
        action def Display {
            then action render video frames;
        }
        
        action def Seek {
            in position : TimestampValue;
            then action assign currentPosition = position;
        }
        
        action def Pause {
            then action assign isPaused = true;
        }
        
        action def Resume {
            then action assign isPaused = false;
        }
        
        action def Stop {
            then action assign isPlaying = false;
            then action assign isPaused = false;
            then action assign currentPosition = 0.0;
        }
    }
    
    // ===== Frontend Client =====
    part def FrontendClient {
        port controlOut : ControlPort;
        port streamIn : EncodedStreamPort;
        port storageIn : StoragePort;
        
        part playbackEngine : PlaybackEngine;
        
        attribute selectedChannel : ChannelNumber optional;
        attribute selectedRecording : String optional;
        
        action def BrowseGuide {
            then action QueryGuide;
            then action display program listings;
        }
        
        action def ManageRecordings {
            then action display scheduled recordings;
            then action allow user to add or cancel recordings;
        }
        
        action def NavigateLibrary {
            then action display recorded programs;
            then action allow user to select recording;
        }
        
        action def SelectRecording {
            in title : String;
            then action assign selectedRecording = title;
            then action request stream from backend;
        }
        
        action def SelectLiveChannel {
            in channel : ChannelNumber;
            then action assign selectedChannel = channel;
            then action request live stream from backend tuner;
        }
        
        action def SendPlaybackCommand {
            in command : PlaybackCommand;
            then action send command to backend;
        }
    }
    
    // ===== Top-Level System =====
    part def MythTVSystem {
        part backend : BackendServer;
        part frontend : FrontendClient;
        
        connection controlLink connect frontend.controlOut to backend.controlIn;
        connection streamLink connect backend.streamOut to frontend.streamIn;
        connection storageLink connect backend.storageOut to frontend.storageIn;
        connection playbackControl connect frontend.controlOut to frontend.playbackEngine.controlIn;
        connection playbackStream connect frontend.streamIn to frontend.playbackEngine.streamIn;
        
        action def StartSystem {
            then action initialize backend;
            then action initialize frontend;
            then action load EPG listings;
        }
        
        action def ShutdownSystem {
            then action stop all recordings;
            then action stop playback;
            then action flush storage;
        }
    }
    
    // ===== Requirements =====
    requirement def DVRRequirement {
        doc /* Base requirement for the MythTV DVR system. */
    }
    
    requirement WatchLiveTV : DVRRequirement {
        subject system : MythTVSystem;
        doc /* The system shall allow users to watch live television through the frontend. */
    }
    
    requirement PauseLiveTV : DVRRequirement {
        subject playbackEngine : PlaybackEngine;
        doc /* The playback engine shall allow users to pause live television streams. */
    }
    
    requirement RecordProgram : DVRRequirement {
        subject backend : BackendServer;
        doc /* The backend shall allow users to record television programs. */
    }
    
    requirement SimultaneousRecording : DVRRequirement {
        subject backend : BackendServer;
        doc /* The backend shall support simultaneous recording of multiple programs via multiple tuner cards. */
    }
    
    requirement ConflictResolution : DVRRequirement {
        subject scheduler : Scheduler;
        doc /* The scheduler shall automatically resolve conflicts when too many shows are scheduled at once. */
    }
    
    requirement PlaybackControl : DVRRequirement {
        subject playbackEngine : PlaybackEngine;
        doc /* The playback engine shall support pause, resume, stop, and seek operations. */
    }
    
    requirement StreamRecordedContent : DVRRequirement {
        subject backend : BackendServer;
        doc /* The backend shall stream recorded files to the frontend for playback. */
    }
    
    requirement EPGMaintenance : DVRRequirement {
        subject epg : EPGDatabase;
        doc /* The EPG database shall maintain up-to-date TV listings. */
    }
    
    requirement StorageManagement : DVRRequirement {
        subject storage : StorageSubsystem;
        doc /* The storage subsystem shall manage available disk space and organize the library of recorded programs. */
    }
    
    requirement ClientServerArchitecture : DVRRequirement {
        subject system : MythTVSystem;
        doc /* The system shall separate core recording and storage functions in the backend from user interaction in the frontend. */
    }
    
    // ===== Requirement Satisfaction =====
    satisfaction satisfy WatchLiveTV by MythTVSystem;
    satisfaction satisfy PauseLiveTV by PlaybackEngine;
    satisfaction satisfy RecordProgram by BackendServer;
    satisfaction satisfy SimultaneousRecording by BackendServer;
    satisfaction satisfy ConflictResolution by Scheduler;
    satisfaction satisfy PlaybackControl by PlaybackEngine;
    satisfaction satisfy StreamRecordedContent by BackendServer;
    satisfaction satisfy EPGMaintenance by EPGDatabase;
    satisfaction satisfy StorageManagement by StorageSubsystem;
    satisfaction satisfy ClientServerArchitecture by MythTVSystem;
}
