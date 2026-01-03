package MythTVDigitalVideoRecorder {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def ChannelIdentifier :> Integer;
    attribute def ProgramTitle :> String;
    attribute def RecordingQuality;
    attribute def EPGEntry;
    attribute def UserCommand;
    attribute def BitrateUnit;
    
    value def BitrateValue :> Real;
    
    item def RFSignal {
        attribute frequency : FrequencyValue;
        attribute bandwidth : FrequencyValue;
    }
    
    item def VideoStream {
        attribute resolution : VideoResolution;
        attribute bitrate : BitrateValue;
        attribute format : String;
    }
    
    item def AudioStream {
        attribute sampleRate : FrequencyValue;
        attribute channels : Integer;
        attribute bitrate : BitrateValue;
    }
    
    item def EncodedContent {
        attribute video : VideoStream;
        attribute audio : AudioStream;
        attribute duration : TimeValue;
        attribute fileSize : MassValue;
    }
    
    attribute def VideoResolution {
        attribute width : Integer;
        attribute height : Integer;
    }
    
    port def RFInputPort {
        in attribute signal : RFSignal;
    }
    
    port def VideoOutputPort {
        out attribute videoData : VideoStream;
    }
    
    port def AudioOutputPort {
        out attribute audioData : AudioStream;
    }
    
    port def DataPort {
        in attribute inData : EncodedContent;
        out attribute outData : EncodedContent;
    }
    
    port def ControlPort {
        in attribute commands : UserCommand;
        out attribute status : String;
    }
    
    part def TunerCard {
        port rfInput : RFInputPort;
        port videoOut : VideoOutputPort;
        port audioOut : AudioOutputPort;
        
        attribute currentChannel : ChannelIdentifier;
        attribute signalStrength : Real;
        
        action def TuneToChannel {
            in channel : ChannelIdentifier;
            in rfSignal : RFSignal;
            out videoStream : VideoStream;
            out audioStream : AudioStream;
        }
    }
    
    part def VideoEncoder {
        port videoIn : VideoOutputPort;
        port audioIn : AudioOutputPort;
        port encodedOut : DataPort;
        
        attribute encodingQuality : RecordingQuality;
        attribute targetBitrate : BitrateValue;
        
        action def EncodeStream {
            in video : VideoStream;
            in audio : AudioStream;
            in quality : RecordingQuality;
            out encoded : EncodedContent;
        }
    }
    
    part def StorageSubsystem {
        port dataInterface : DataPort;
        
        attribute totalCapacity : MassValue;
        attribute usedSpace : MassValue;
        attribute availableSpace : MassValue;
        
        action def WriteRecording {
            in content : EncodedContent;
            in filename : String;
            out success : Boolean;
        }
        
        action def ReadRecording {
            in filename : String;
            out content : EncodedContent;
        }
        
        action def DeleteRecording {
            in filename : String;
            out freedSpace : MassValue;
        }
    }
    
    part def EPGDatabase {
        attribute programGuide : EPGEntry[*];
        
        action def UpdateGuideData {
            in newEntries : EPGEntry[*];
        }
        
        action def SearchPrograms {
            in searchCriteria : String;
            out results : EPGEntry[*];
        }
        
        action def GetProgramInfo {
            in channel : ChannelIdentifier;
            in time : TimeValue;
            out programInfo : EPGEntry;
        }
    }
    
    item def RecordingSchedule {
        attribute channel : ChannelIdentifier;
        attribute startTime : TimeValue;
        attribute endTime : TimeValue;
        attribute programTitle : ProgramTitle;
        attribute quality : RecordingQuality;
    }
    
    part def RecordingScheduler {
        attribute scheduledRecordings : RecordingSchedule[*];
        
        action def CreateSchedule {
            in programInfo : EPGEntry;
            in channel : ChannelIdentifier;
            in startTime : TimeValue;
            in duration : TimeValue;
            out schedule : RecordingSchedule;
        }
        
        action def CheckConflicts {
            in newSchedule : RecordingSchedule;
            out hasConflict : Boolean;
            out conflictingSchedules : RecordingSchedule[*];
        }
        
        action def GetNextRecording {
            out nextSchedule : RecordingSchedule;
        }
    }
    
    part def PlaybackEngine {
        port contentIn : DataPort;
        port videoOut : VideoOutputPort;
        port audioOut : AudioOutputPort;
        
        attribute currentPosition : TimeValue;
        attribute playbackSpeed : Real;
        attribute isPaused : Boolean;
        
        action def StartPlayback {
            in content : EncodedContent;
            out video : VideoStream;
            out audio : AudioStream;
        }
        
        action def PausePlayback;
        
        action def ResumePlayback;
        
        action def SeekToPosition {
            in position : TimeValue;
        }
        
        action def StopPlayback;
    }
    
    part def FrontendUI {
        port userControl : ControlPort;
        port backendComm : DataPort;
        
        action def DisplayMainMenu {
            out menuOptions : String[*];
        }
        
        action def ProcessUserInput {
            in command : UserCommand;
            out action : String;
        }
        
        action def DisplayLiveTV {
            in videoStream : VideoStream;
            in audioStream : AudioStream;
        }
        
        action def DisplayRecordingsList {
            in recordings : String[*];
        }
    }
    
    part def BackendServer {
        part tuner1 : TunerCard;
        part tuner2 : TunerCard;
        part encoder1 : VideoEncoder;
        part encoder2 : VideoEncoder;
        part storage : StorageSubsystem;
        part epg : EPGDatabase;
        part scheduler : RecordingScheduler;
        
        bind tuner1.videoOut = encoder1.videoIn;
        bind tuner1.audioOut = encoder1.audioIn;
        bind tuner2.videoOut = encoder2.videoIn;
        bind tuner2.audioOut = encoder2.audioIn;
        bind encoder1.encodedOut = storage.dataInterface;
        bind encoder2.encodedOut = storage.dataInterface;
        
        state def BackendOperationStates {
            entry; then idle;
            
            state idle;
            
            accept scheduleEvent;
            then preparingRecording;
            
            state preparingRecording;
            then recording;
            
            state recording;
            accept recordingDone;
            then idle;
        }
        
        perform action ExecuteRecording {
            in schedule : RecordingSchedule;
            out recordedFile : String;
            
            action allocateTuner {
                out tuner : TunerCard;
            }
            then action tune : TunerCard::TuneToChannel {
                in channel = schedule.channel;
                in rfSignal;
                out videoStream;
                out audioStream;
            }
            then action encode : VideoEncoder::EncodeStream {
                in video = tune.videoStream;
                in audio = tune.audioStream;
                in quality = schedule.quality;
                out encoded;
            }
            then action store : StorageSubsystem::WriteRecording {
                in content = encode.encoded;
                in filename = schedule.programTitle;
                out success;
            }
            then assign recordedFile := schedule.programTitle;
        }
    }
    
    part def FrontendClient {
        part playback : PlaybackEngine;
        part ui : FrontendUI;
        
        bind ui.backendComm = playback.contentIn;
        
        state def FrontendStates {
            entry; then mainMenu;
            
            state mainMenu;
            
            accept watchLiveCommand;
            then watchingLiveTV;
            
            accept viewRecordingsCommand;
            then browsingRecordings;
            
            state watchingLiveTV;
            accept exitCommand;
            then mainMenu;
            
            state browsingRecordings;
            accept playCommand;
            then playingRecording;
            
            state playingRecording;
            accept pauseCommand;
            then paused;
            
            accept stopCommand;
            then mainMenu;
            
            state paused;
            accept resumeCommand;
            then playingRecording;
        }
        
        perform action OperateFrontend : FrontendStates;
    }
    
    part mythTVSystem {
        part backend : BackendServer;
        part frontend : FrontendClient;
        
        bind frontend.ui.backendComm = backend.storage.dataInterface;
        
        perform action ProvideDigitalVideoRecording {
            in tvBroadcast : RFSignal;
            in userInput : UserCommand[*];
            out displayOutput : VideoStream;
            
            first start;
            then merge continueOperation;
            
            then action captureAndStore {
                action receiveBroadcast {
                    in signal = tvBroadcast;
                    out video : VideoStream;
                    out audio : AudioStream;
                }
                flow from receiveBroadcast.video to encodeContent.video;
                flow from receiveBroadcast.audio to encodeContent.audio;
                
                action encodeContent {
                    in video : VideoStream;
                    in audio : AudioStream;
                    out encoded : EncodedContent;
                }
                flow from encodeContent.encoded to saveRecording.content;
                
                action saveRecording {
                    in content : EncodedContent;
                }
            }
            
            then action handleUserRequest {
                accept command : UserCommand;
                then decide;
                    if command == watchLiveCmd then provideLiveTV;
                    if command == playRecordingCmd then providePlayback;
                    if command == scheduleRecordingCmd then scheduleProgram;
                    else continueOperation;
                
                action provideLiveTV {
                    action streamLive {
                        out liveVideo : VideoStream;
                    }
                    then assign displayOutput := streamLive.liveVideo;
                }
                
                action providePlayback {
                    action retrieveRecording {
                        out recording : EncodedContent;
                    }
                    flow from retrieveRecording.recording to playContent.content;
                    
                    action playContent {
                        in content : EncodedContent;
                        out playbackVideo : VideoStream;
                    }
                    then assign displayOutput := playContent.playbackVideo;
                }
                
                action scheduleProgram {
                    perform backend.scheduler.CreateSchedule;
                }
            }
            
            then continueOperation;
        }
    }
    
    requirement def SystemRequirement;
    
    requirement <'MYTH-REQ-001'> primaryFunction : SystemRequirement {
        doc /*
            The MythTV system shall provide comprehensive digital video recording 
            capabilities by capturing television broadcasts through tuner cards, 
            encoding the content to digital format, storing recordings to persistent 
            storage, and enabling users to watch live television or play back 
            recorded programs on demand through an integrated frontend interface 
            with full playback control including pause, resume, and seek operations.
        */
        
        subject mythTVSystem;
        
        require recordingCapability;
        require playbackCapability;
        require schedulingCapability;
        require userInterfaceCapability;
    }
    
    requirement <'MYTH-REQ-002'> recordingCapability : SystemRequirement {
        doc /*
            The system shall capture television signals from multiple tuner cards 
            simultaneously, encode video and audio streams to compressed digital 
            format, and store the encoded content to disk storage according to 
            user-defined recording schedules managed by the EPG and scheduler.
        */
    }
    
    requirement <'MYTH-REQ-003'> playbackCapability : SystemRequirement {
        doc /*
            The system shall retrieve stored recordings from disk storage, decode 
            the content, and provide real-time playback with support for pause, 
            resume, seek, and stop operations through the playback engine.
        */
    }
    
    requirement <'MYTH-REQ-004'> schedulingCapability : SystemRequirement {
        doc /*
            The system shall maintain an electronic program guide database, allow 
            users to schedule recordings based on program information, detect and 
            resolve scheduling conflicts, and automatically execute recordings at 
            the scheduled times.
        */
    }
    
    requirement <'MYTH-REQ-005'> userInterfaceCapability : SystemRequirement {
        doc /*
            The system shall provide a frontend user interface that accepts user 
            commands for navigating menus, browsing the program guide, scheduling 
            recordings, watching live television, selecting recorded programs, and 
            controlling playback functions.
        */
    }
    
    attribute watchLiveCmd : UserCommand;
    attribute playRecordingCmd : UserCommand;
    attribute scheduleRecordingCmd : UserCommand;
}
