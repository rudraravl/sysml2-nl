package VideoDiskRecorderSpecification {

  import ScalarValues::*;
  import SI::*;

  attribute def StorageCapacityGB :> Real {
    unit = "GB";
  }

  attribute def DataRateMbps :> Real {
    unit = "Mb/s";
  }

  attribute def FrequencyHz :> Real {
    unit = "Hz";
  }

  attribute def DurationSeconds :> Real {
    unit = "s";
  }

  attribute def PowerWatt :> Real {
    unit = "W";
  }

  item def EncodedVideoStream {
    attribute codec : String;
    attribute resolution : String;
    attribute frameRate : FrequencyHz;
    attribute bitRate : DataRateMbps;
  }

  item def AudioStream {
    attribute codec : String;
    attribute channelCount : Integer;
    attribute bitRate : DataRateMbps;
  }

  item def ProgramMetadata {
    attribute title : String;
    attribute channelName : String;
    attribute startTimeUtc : String;
    attribute duration : DurationSeconds;
    attribute parentalRating : String;
  }

  item def RecordedProgramFile {
    attribute fileName : String;
    attribute fileSize : StorageCapacityGB;
    attribute videoCodec : String;
    attribute audioCodec : String;
    attribute duration : DurationSeconds;
    attribute protectedFromDeletion : Boolean;
  }

  item def UserCommand {
    attribute commandName : String;
    attribute issuedBy : String;
  }

  item def PlaybackSignal {
    attribute resolution : String;
    attribute frameRate : FrequencyHz;
    attribute audioChannels : Integer;
  }

  port def VideoInputPort {
    in item video : EncodedVideoStream;
    in item audio : AudioStream;
    in item metadata : ProgramMetadata;
  }

  port def DisplayOutputPort {
    out item playback : PlaybackSignal;
  }

  port def ControlPort {
    in item command : UserCommand;
  }

  port def StoragePort {
    in item fileToStore : RecordedProgramFile;
    out item storedFile : RecordedProgramFile;
  }

  part def Tuner {
    attribute tunedChannel : String;
    attribute locked : Boolean;
    port broadcastIn : VideoInputPort;
    port transportOut : VideoInputPort;
  }

  part def Encoder {
    attribute targetVideoBitRate : DataRateMbps = 8.0;
    attribute targetAudioBitRate : DataRateMbps = 0.384;
    port rawIn : VideoInputPort;
    port encodedOut : VideoInputPort;
  }

  part def DiskStorage {
    attribute totalCapacity : StorageCapacityGB = 2000.0;
    attribute reservedSystemCapacity : StorageCapacityGB = 50.0;
    attribute usedCapacity : StorageCapacityGB;
    attribute availableCapacity : StorageCapacityGB;
    attribute sustainedWriteRate : DataRateMbps = 120.0;
    port storageAccess : StoragePort;
  }

  part def PlaybackDecoder {
    attribute supportedVideoCodecs : String = "MPEG-2,H.264,H.265";
    attribute supportedAudioCodecs : String = "AAC,AC3,PCM";
    port fileIn : StoragePort;
    port displayOut : DisplayOutputPort;
  }

  part def Scheduler {
    attribute clockUtc : String;
    attribute maximumConcurrentRecordings : Integer = 2;
    port controlIn : ControlPort;
  }

  part def UserInterface {
    attribute displayLanguage : String = "en-US";
    port remoteControlIn : ControlPort;
    port schedulerOut : ControlPort;
  }

  part def PowerSupply {
    attribute inputPower : PowerWatt;
    attribute outputPower : PowerWatt = 65.0;
    attribute healthy : Boolean;
  }

  action def CaptureBroadcast {
    in item selectedVideo : EncodedVideoStream;
    in item selectedAudio : AudioStream;
    in item selectedMetadata : ProgramMetadata;
    out item capturedVideo : EncodedVideoStream;
    out item capturedAudio : AudioStream;
    out item capturedMetadata : ProgramMetadata;
  }

  action def EncodeProgram {
    in item capturedVideo : EncodedVideoStream;
    in item capturedAudio : AudioStream;
    in item capturedMetadata : ProgramMetadata;
    out item programFile : RecordedProgramFile;
  }

  action def StoreProgram {
    in item programFile : RecordedProgramFile;
    out item storedProgram : RecordedProgramFile;
  }

  action def PlayRecordedProgram {
    in item storedProgram : RecordedProgramFile;
    out item playbackSignal : PlaybackSignal;
  }

  action def PrimaryRecordFunction {
    in item broadcastVideo : EncodedVideoStream;
    in item broadcastAudio : AudioStream;
    in item metadata : ProgramMetadata;
    out item storedRecording : RecordedProgramFile;

    action capture : CaptureBroadcast {
      in item selectedVideo = broadcastVideo;
      in item selectedAudio = broadcastAudio;
      in item selectedMetadata = metadata;
    }

    action encode : EncodeProgram {
      in item capturedVideo = capture.capturedVideo;
      in item capturedAudio = capture.capturedAudio;
      in item capturedMetadata = capture.capturedMetadata;
    }

    action store : StoreProgram {
      in item programFile = encode.programFile;
    }

    bind storedRecording = store.storedProgram;
  }

  state def RecorderOperatingState {
    state Off;
    state Standby;
    state Recording;
    state Playback;
    state Error;

    transition powerApplied first Off then Standby;
    transition startRecording first Standby then Recording;
    transition recordingComplete first Recording then Standby;
    transition startPlayback first Standby then Playback;
    transition stopPlayback first Playback then Standby;
    transition faultDetected first Standby then Error;
    transition recordingFault first Recording then Error;
    transition playbackFault first Playback then Error;
    transition reset first Error then Standby;
    transition powerRemoved first Standby then Off;
  }

  part def VideoDiskRecorder {
    attribute modelName : String = "HighLevelVideoDiskRecorder";
    attribute primaryFunction : String = "Receive scheduled or user-selected video programming, encode it if needed, store it as digital files on local disk storage, and later reproduce selected recordings for display.";
    attribute nominalPowerConsumption : PowerWatt = 42.0;
    attribute maximumRecordingBitRate : DataRateMbps = 25.0;

    port antennaOrCableInput : VideoInputPort;
    port displayOutput : DisplayOutputPort;
    port userControl : ControlPort;

    part tuner : Tuner;
    part encoder : Encoder;
    part disk : DiskStorage;
    part decoder : PlaybackDecoder;
    part scheduler : Scheduler;
    part userInterface : UserInterface;
    part powerSupply : PowerSupply;

    state operatingState : RecorderOperatingState;

    connection inputToTuner connect antennaOrCableInput to tuner.broadcastIn;
    connection tunerToEncoder connect tuner.transportOut to encoder.rawIn;
    connection encoderToDisk connect encoder.encodedOut to disk.storageAccess;
    connection diskToDecoder connect disk.storageAccess to decoder.fileIn;
    connection decoderToDisplay connect decoder.displayOut to displayOutput;
    connection controlToUi connect userControl to userInterface.remoteControlIn;
    connection uiToScheduler connect userInterface.schedulerOut to scheduler.controlIn;

    perform action record : PrimaryRecordFunction;
    perform action playback : PlayRecordedProgram;
  }

  requirement def RecordVideoRequirement {
    subject recorder : VideoDiskRecorder;
    require constraint {
      recorder.disk.availableCapacity > 0.0
    }
  }

  requirement def PreserveProgramMetadataRequirement {
    subject recording : RecordedProgramFile;
    require constraint {
      recording.fileName != "" and recording.duration > 0.0
    }
  }

  requirement def PlaybackRequirement {
    subject recorder : VideoDiskRecorder;
    require constraint {
      recorder.decoder.supportedVideoCodecs != "" and recorder.decoder.supportedAudioCodecs != ""
    }
  }

  requirement def StorageCapacityRequirement {
    subject recorder : VideoDiskRecorder;
    require constraint {
      recorder.disk.totalCapacity >= 500.0
    }
  }

  requirement def PrimaryFunctionRequirement {
    subject recorder : VideoDiskRecorder;
    doc /* The Video Disk Recorder shall provide the high-level capability to capture an incoming video program, store it on disk as a recorded program file, and play the stored program on demand. */
    require constraint {
      recorder.maximumRecordingBitRate <= recorder.disk.sustainedWriteRate
    }
  }

  part systemContext {
    part recorder : VideoDiskRecorder;

    item sampleVideo : EncodedVideoStream {
      attribute codec = "H.264";
      attribute resolution = "1920x1080";
      attribute frameRate = 60.0;
      attribute bitRate = 10.0;
    }

    item sampleAudio : AudioStream {
      attribute codec = "AAC";
      attribute channelCount = 2;
      attribute bitRate = 0.192;
    }

    item sampleMetadata : ProgramMetadata {
      attribute title = "Evening News";
      attribute channelName = "Channel 8";
      attribute startTimeUtc = "2026-06-11T23:00:00Z";
      attribute duration = 1800.0;
      attribute parentalRating = "TV-G";
    }

    satisfy PrimaryFunctionRequirement by recorder;
    satisfy StorageCapacityRequirement by recorder;
    satisfy PlaybackRequirement by recorder;
  }
}