package 'Video Disk Recorder System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def BroadcastSignal;
    attribute def VideoStream;
    attribute def AudioStream;
    attribute def EncodedData;
    
    enum def UserCommand {
        RECORD;
        PLAY;
        STOP;
        PAUSE;
        RESUME_RECORD;
        RESUME_PLAY;
        DELETE;
    }
    
    attribute def ProgramMetadata {
        attribute title : ScalarValues::String;
        attribute channel : ScalarValues::String;
        attribute recordTime : ScalarValues::String;
        attribute duration : DurationValue;
    }
    
    item def RecordedProgram {
        attribute programMetadata : ProgramMetadata;
        attribute videoData : EncodedData;
        attribute audioData : EncodedData;
        attribute fileSize : MassValue;
    }
    
    port def BroadcastInputPort {
        in item signal : BroadcastSignal;
    }
    
    port def VideoOutputPort {
        out item video : VideoStream;
        out item audio : AudioStream;
    }
    
    port def ControlPort {
        in item command : UserCommand;
        out item status : ScalarValues::String;
    }
    
    part def TunerUnit {
        port broadcastIn : BroadcastInputPort;
        port tunedOutput {
            out item video : VideoStream;
            out item audio : AudioStream;
        }
        
        action tuneChannel {
            in broadcast : BroadcastSignal;
            in channelNumber : ScalarValues::String;
            out videoOut : VideoStream;
            out audioOut : AudioStream;
        }
    }
    
    part def EncoderUnit {
        port encoderInput {
            in item videoIn : VideoStream;
            in item audioIn : AudioStream;
        }
        port encoderOutput {
            out item encodedVideo : EncodedData;
            out item encodedAudio : EncodedData;
        }
        
        attribute compressionRatio : ScalarValues::Real;
        
        action compressVideo {
            in rawVideo : VideoStream;
            in quality : ScalarValues::Real;
            out compressed : EncodedData;
        }
        
        action compressAudio {
            in rawAudio : AudioStream;
            out compressed : EncodedData;
        }
    }
    
    part def DecoderUnit {
        port decoderInput {
            in item encodedVideo : EncodedData;
            in item encodedAudio : EncodedData;
        }
        port decoderOutput {
            out item videoOut : VideoStream;
            out item audioOut : AudioStream;
        }
        
        action decompressVideo {
            in compressed : EncodedData;
            out rawVideo : VideoStream;
        }
        
        action decompressAudio {
            in compressed : EncodedData;
            out rawAudio : AudioStream;
        }
    }
    
    part def StorageUnit {
        attribute totalCapacity : MassValue;
        attribute usedSpace : MassValue;
        attribute availableSpace : MassValue;
        attribute programLibrary : RecordedProgram[0..*];
        
        port storageInterface {
            in item writeData : EncodedData;
            in item writeRequest : ProgramMetadata;
            in item readRequest : ScalarValues::String;
            out item readData : RecordedProgram;
        }
        
        action writeProgram {
            in videoData : EncodedData;
            in audioData : EncodedData;
            in programMetadata : ProgramMetadata;
            out success : ScalarValues::Boolean;
            out program : RecordedProgram;
        }
        
        action readProgram {
            in programId : ScalarValues::String;
            out program : RecordedProgram;
            out found : ScalarValues::Boolean;
        }
        
        action deleteProgram {
            in programId : ScalarValues::String;
            out success : ScalarValues::Boolean;
        }
        
        action checkSpace {
            in requiredSize : MassValue;
            out available : ScalarValues::Boolean;
        }
    }
    
    part def ControllerUnit {
        port userInterface : ControlPort;
        port controlSignals {
            out item mode : ScalarValues::String;
            out item targetChannel : ScalarValues::String;
            out item targetProgram : ScalarValues::String;
        }
        
        state controlStateMachine {
            initial state Idle;
            
            state Idle {
                transition first to Recording
                    accept cmd : UserCommand
                    if cmd == UserCommand::RECORD;
                    
                transition second to Playing
                    accept cmd : UserCommand
                    if cmd == UserCommand::PLAY;
            }
            
            state Recording {
                entry action startRecording;
                do action continueRecording;
                
                transition first to Idle
                    accept cmd : UserCommand
                    if cmd == UserCommand::STOP;
                    
                transition second to Paused
                    accept cmd : UserCommand
                    if cmd == UserCommand::PAUSE;
            }
            
            state Playing {
                entry action startPlayback;
                do action continuePlayback;
                
                transition first to Idle
                    accept cmd : UserCommand
                    if cmd == UserCommand::STOP;
                    
                transition second to Paused
                    accept cmd : UserCommand
                    if cmd == UserCommand::PAUSE;
            }
            
            state Paused {
                transition first to Recording
                    accept cmd : UserCommand
                    if cmd == UserCommand::RESUME_RECORD;
                    
                transition second to Playing
                    accept cmd : UserCommand
                    if cmd == UserCommand::RESUME_PLAY;
                    
                transition third to Idle
                    accept cmd : UserCommand
                    if cmd == UserCommand::STOP;
            }
        }
    }
    
    action def RecordBroadcast {
        in channelId : ScalarValues::String;
        in programInfo : ProgramMetadata;
        out recordedProgram : RecordedProgram;
    }
    
    action def PlaybackRecording {
        in programId : ScalarValues::String;
        out videoOutput : VideoStream;
        out audioOutput : AudioStream;
    }
    
    part def VideoDiskRecorder {
        port antennaInput : BroadcastInputPort;
        port displayOutput : VideoOutputPort;
        port userControl : ControlPort;
        
        part tuner : TunerUnit;
        part encoder : EncoderUnit {
            attribute :>> compressionRatio = 0.25;
        }
        part decoder : DecoderUnit;
        part storage : StorageUnit {
            attribute :>> totalCapacity = 500000[g];
            attribute :>> usedSpace = 0[g];
            attribute :>> availableSpace = 500000[g];
        }
        part controller : ControllerUnit;
        
        connection connect antennaInput to tuner.broadcastIn;
        connection connect tuner.tunedOutput to encoder.encoderInput;
        connection connect encoder.encoderOutput to storage.storageInterface;
        connection connect storage.storageInterface to decoder.decoderInput;
        connection connect decoder.decoderOutput to displayOutput;
        connection connect userControl to controller.userInterface;
        
        perform action operateVDR;
    }
    
    action operateVDR {
        first start;
        then merge awaitCommand;
        
        action awaitCommand {
            accept userCmd : UserCommand;
        }
        
        then decide;
            if userCmd == UserCommand::RECORD then recordMode;
            if userCmd == UserCommand::PLAY then playbackMode;
            if userCmd == UserCommand::DELETE then deleteMode;
            if userCmd == UserCommand::STOP then stopMode;
        
        action recordMode : RecordBroadcast {
            in channelId : ScalarValues::String;
            in programInfo : ProgramMetadata;
            out recordedProgram : RecordedProgram;
        }
        then awaitCommand;
        
        action playbackMode : PlaybackRecording {
            in programId : ScalarValues::String;
            out videoOutput : VideoStream;
            out audioOutput : AudioStream;
        }
        then awaitCommand;
        
        action deleteMode {
            action removeProgram {
                in programId : ScalarValues::String;
                out success : ScalarValues::Boolean;
            }
        }
        then awaitCommand;
        
        action stopMode {
            action haltCurrentOperation;
        }
        then awaitCommand;
    }
    
    requirement <'VDR-REQ-001'> primaryFunctionRequirement {
        doc /* 
            The Video Disk Recorder shall receive broadcast television signals,
            encode and store selected programs to digital storage media,
            and provide playback capability of stored content on user demand.
            The system shall support recording while simultaneously playing back
            previously recorded content.
        */
        
        subject vdrSystem : VideoDiskRecorder;
        
        require constraint recordingCapability {
            doc /* The system shall capture and store broadcast content. */
        }
        
        require constraint playbackCapability {
            doc /* The system shall retrieve and display stored content. */
        }
        
        require constraint simultaneousOperation {
            doc /* The system shall support concurrent record and playback. */
        }
    }
    
    requirement <'VDR-REQ-002'> storageRequirement {
        doc /* 
            The Video Disk Recorder shall provide minimum storage capacity
            of 500 GB for recorded programs with automatic space management.
        */
        
        subject vdrSystem : VideoDiskRecorder;
        
        require constraint minimumCapacity {
            vdrSystem.storage.totalCapacity >= 500000[g]
        }
        
        require constraint spaceMonitoring {
            doc /* The system shall monitor and report available storage space. */
        }
    }
    
    requirement <'VDR-REQ-003'> userControlRequirement {
        doc /* 
            The Video Disk Recorder shall accept user commands for record,
            play, pause, stop, and delete operations with responsive feedback.
        */
        
        subject vdrSystem : VideoDiskRecorder;
        
        require constraint commandProcessing {
            doc /* The controller shall process all standard user commands. */
        }
        
        require constraint stateManagement {
            doc /* The system shall maintain proper operational states. */
        }
    }
    
    requirement <'VDR-REQ-004'> encodingQualityRequirement {
        doc /* 
            The Video Disk Recorder shall encode video with configurable
            compression maintaining acceptable quality-to-size ratio.
        */
        
        subject vdrSystem : VideoDiskRecorder;
        
        require constraint compressionEfficiency {
            vdrSystem.encoder.compressionRatio >= 0.2 and 
            vdrSystem.encoder.compressionRatio <= 0.5
        }
    }
    
    part vdrSystem : VideoDiskRecorder {
        satisfy primaryFunctionRequirement;
        satisfy storageRequirement;
        satisfy userControlRequirement;
        satisfy encodingQualityRequirement;
    }
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import 'Video Disk Recorder System'::*;

    action orchestrator {
        attribute testProgramInfo : ProgramMetadata {
            attribute title = "";
            attribute channel = "";
            attribute recordTime = "";
            attribute duration : DurationValue;
        }
        action recordModeProbe : RecordBroadcast {
            in channelId = "";
            in programInfo = testProgramInfo;
        }
        first recordModeProbe;
    }
}
