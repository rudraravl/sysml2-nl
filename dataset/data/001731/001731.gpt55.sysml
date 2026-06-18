package VideoDiskRecorderModel {

  import ScalarValues::*;
  import SI::*;

  attribute def ElectricPotential {
    unit : Unit = V;
  }

  attribute def ElectricCurrent {
    unit : Unit = A;
  }

  attribute def Power {
    unit : Unit = W;
  }

  attribute def Frequency {
    unit : Unit = Hz;
  }

  attribute def DataRate {
    unit : Unit = bps;
  }

  attribute def StorageCapacity {
    unit : Unit = byte;
  }

  attribute def Duration {
    unit : Unit = s;
  }

  attribute def Temperature {
    unit : Unit = degC;
  }

  attribute def Percentage {
    unit : Unit = one;
  }

  attribute def ProgramIdentifier {
    :> ScalarValues::String;
  }

  enum def RecordingQuality {
    enum literal Low;
    enum literal Standard;
    enum literal High;
    enum literal Archive;
  }

  enum def RecorderMode {
    enum literal Off;
    enum literal Standby;
    enum literal Tuning;
    enum literal Recording;
    enum literal Playback;
    enum literal Paused;
    enum literal FinalizingDisk;
    enum literal Error;
  }

  enum def CommandKind {
    enum literal PowerOn;
    enum literal PowerOff;
    enum literal SelectChannel;
    enum literal StartRecording;
    enum literal StopRecording;
    enum literal ScheduleRecording;
    enum literal Play;
    enum literal Pause;
    enum literal StopPlayback;
    enum literal EjectDisk;
    enum literal DeleteProgram;
  }

  enum def DiskFormat {
    enum literal DVD_R;
    enum literal DVD_RW;
    enum literal BluRay_Recordable;
    enum literal InternalHardDisk;
    enum literal SolidStateDisk;
  }

  item def RadioFrequencySignal {
    attribute carrierFrequency : Frequency;
    attribute channelNumber : Integer;
    attribute signalLevel : Percentage;
  }

  item def BasebandVideoSignal {
    attribute horizontalResolution : Integer;
    attribute verticalResolution : Integer;
    attribute frameRate : Frequency;
    attribute interlaced : Boolean;
  }

  item def AudioSignal {
    attribute channelCount : Integer;
    attribute sampleRate : Frequency;
    attribute bitDepth : Integer;
  }

  item def TransportStream {
    attribute streamRate : DataRate;
    attribute containsVideo : Boolean;
    attribute containsAudio : Boolean;
    attribute containsProgramGuide : Boolean;
  }

  item def EncodedVideoStream {
    attribute codecName : String;
    attribute bitRate : DataRate;
    attribute horizontalResolution : Integer;
    attribute verticalResolution : Integer;
    attribute frameRate : Frequency;
    attribute quality : RecordingQuality;
  }

  item def EncodedAudioStream {
    attribute codecName : String;
    attribute bitRate : DataRate;
    attribute channelCount : Integer;
  }

  item def StoredProgram {
    attribute programId : ProgramIdentifier;
    attribute title : String;
    attribute duration : Duration;
    attribute videoSize : StorageCapacity;
    attribute quality : RecordingQuality;
    attribute protectedFromDeletion : Boolean;
  }

  item def PlaybackProgram {
    attribute programId : ProgramIdentifier;
    attribute elapsedTime : Duration;
    attribute totalDuration : Duration;
  }

  item def RemoteCommand {
    attribute kind : CommandKind;
    attribute selectedChannel : Integer;
    attribute targetProgramId : ProgramIdentifier;
    attribute requestedQuality : RecordingQuality;
  }

  item def RecordingSchedule {
    attribute programId : ProgramIdentifier;
    attribute title : String;
    attribute channelNumber : Integer;
    attribute startOffsetFromNow : Duration;
    attribute expectedDuration : Duration;
    attribute requestedQuality : RecordingQuality;
  }

  item def RecorderStatus {
    attribute mode : RecorderMode;
    attribute selectedChannel : Integer;
    attribute activeProgramId : ProgramIdentifier;
    attribute freeCapacity : StorageCapacity;
    attribute diskPresent : Boolean;
    attribute faultText : String;
  }

  item def ElectricalPower {
    attribute voltage : ElectricPotential;
    attribute currentLimit : ElectricCurrent;
    attribute frequency : Frequency;
  }

  port def RFInputPort {
    in item rf : RadioFrequencySignal;
  }

  port def AnalogVideoInputPort {
    in item video : BasebandVideoSignal;
    in item audio : AudioSignal;
  }

  port def DigitalTransportInputPort {
    in item stream : TransportStream;
  }

  port def EncodedVideoPort {
    out item video : EncodedVideoStream;
  }

  port def EncodedAudioPort {
    out item audio : EncodedAudioStream;
  }

  port def StorageWritePort {
    in item video : EncodedVideoStream;
    in item audio : EncodedAudioStream;
    in item metadata : StoredProgram;
  }

  port def StorageReadPort {
    out item storedProgram : StoredProgram;
  }

  port def PlaybackOutputPort {
    out item video : BasebandVideoSignal;
    out item audio : AudioSignal;
  }

  port def ControlInputPort {
    in item command : RemoteCommand;
  }

  port def ScheduleInputPort {
    in item schedule : RecordingSchedule;
  }

  port def StatusOutputPort {
    out item status : RecorderStatus;
  }

  port def PowerInputPort {
    in item power : ElectricalPower;
  }

  port def InternalControlPort {
    in item command : RemoteCommand;
    out item status : RecorderStatus;
  }

  part def RFFrontEndTuner {
    attribute minTuningFrequency : Frequency = 45 [MHz];
    attribute maxTuningFrequency : Frequency = 860 [MHz];
    attribute selectedChannel : Integer = 1;
    attribute channelLockAchieved : Boolean = false;

    port rfIn : RFInputPort;
    port transportOut : DigitalTransportInputPort;

    action tuneChannel {
      in item requestedCommand : RemoteCommand;
      out item selectedStream : TransportStream;
      assert constraint {
        requestedCommand.kind == CommandKind::SelectChannel
      }
    }
  }

  part def AnalogCaptureInterface {
    attribute supportedInputResolutionWidth : Integer = 720;
    attribute supportedInputResolutionHeight : Integer = 480;

    port analogIn : AnalogVideoInputPort;
    port digitizedTransportOut : DigitalTransportInputPort;

    action sampleAnalogProgram {
      in item incomingVideo : BasebandVideoSignal;
      in item incomingAudio : AudioSignal;
      out item sampledStream : TransportStream;
    }
  }

  part def VideoAudioEncoder {
    attribute supportedCodec : String = "MPEG-4 AVC / AAC";
    attribute maximumVideoBitRate : DataRate = 18000000 [bps];
    attribute standardVideoBitRate : DataRate = 6000000 [bps];

    port streamIn : DigitalTransportInputPort;
    port encodedVideoOut : EncodedVideoPort;
    port encodedAudioOut : EncodedAudioPort;

    action encodeForDiskRecording {
      in item sourceStream : TransportStream;
      in item requestedQuality : RecordingQuality;
      out item encodedVideo : EncodedVideoStream;
      out item encodedAudio : EncodedAudioStream;
    }
  }

  part def ProgramBuffer {
    attribute bufferCapacity : StorageCapacity = 1073741824 [byte];
    attribute retainedDuration : Duration = 1800 [s];

    port encodedVideoIn : StorageWritePort;
    port bufferedProgramOut : StorageReadPort;

    action absorbRateVariations {
      in item encodedVideo : EncodedVideoStream;
      in item encodedAudio : EncodedAudioStream;
      out item bufferedMetadata : StoredProgram;
    }
  }

  part def DiskStorageUnit {
    attribute diskFormat : DiskFormat = DiskFormat::InternalHardDisk;
    attribute totalCapacity : StorageCapacity = 1000000000000 [byte];
    attribute reservedSystemCapacity : StorageCapacity = 20000000000 [byte];
    attribute freeCapacity : StorageCapacity = 980000000000 [byte];
    attribute minimumRequiredFreeCapacity : StorageCapacity = 1073741824 [byte];
    attribute diskPresent : Boolean = true;
    attribute writeProtected : Boolean = false;

    port writePort : StorageWritePort;
    port readPort : StorageReadPort;

    action writeProgramToDisk {
      in item video : EncodedVideoStream;
      in item audio : EncodedAudioStream;
      in item metadata : StoredProgram;
      out item recordedProgram : StoredProgram;
      assert constraint {
        diskPresent and not writeProtected
      }
    }

    action readProgramFromDisk {
      in item requestedProgramId : ProgramIdentifier;
      out item selectedProgram : StoredProgram;
      assert constraint {
        diskPresent
      }
    }

    action deleteProgramFromDisk {
      in item requestedProgramId : ProgramIdentifier;
      out item updatedStatus : RecorderStatus;
    }
  }

  part def PlaybackDecoder {
    attribute supportedPlaybackCodec : String = "MPEG-4 AVC / AAC";
    attribute maximumOutputWidth : Integer = 1920;
    attribute maximumOutputHeight : Integer = 1080;

    port storedProgramIn : StorageReadPort;
    port playbackOut : PlaybackOutputPort;

    action decodeStoredProgram {
      in item storedProgram : StoredProgram;
      out item decodedVideo : BasebandVideoSignal;
      out item decodedAudio : AudioSignal;
    }
  }

  part def RecordingScheduler {
    attribute maximumScheduledEvents : Integer = 64;
    attribute automaticConflictResolutionEnabled : Boolean = true;

    port scheduleIn : ScheduleInputPort;
    port controlOut : InternalControlPort;

    action acceptRecordingSchedule {
      in item requestedSchedule : RecordingSchedule;
      out item scheduledCommand : RemoteCommand;
    }

    action startDueRecording {
      in item dueSchedule : RecordingSchedule;
      out item startCommand : RemoteCommand;
    }

    action stopExpiredRecording {
      in item activeSchedule : RecordingSchedule;
      out item stopCommand : RemoteCommand;
    }
  }

  part def RecorderController {
    attribute currentMode : RecorderMode = RecorderMode::Standby;
    attribute selectedChannel : Integer = 1;
    attribute activeProgramId : ProgramIdentifier = "";
    attribute maximumContinuousRecordingDuration : Duration = 28800 [s];
    attribute minimumDiskFreePercentage : Percentage = 0.02 [one];

    port userCommandIn : ControlInputPort;
    port schedulerCommandIn : InternalControlPort;
    port statusOut : StatusOutputPort;
    port tunerControlOut : InternalControlPort;
    port encoderControlOut : InternalControlPort;
    port storageControlOut : InternalControlPort;
    port playbackControlOut : InternalControlPort;

    action interpretUserCommand {
      in item command : RemoteCommand;
      out item internalCommand : RemoteCommand;
    }

    action publishStatus {
      out item status : RecorderStatus;
    }

    action coordinateRecording {
      in item startCommand : RemoteCommand;
      out item status : RecorderStatus;
    }

    action coordinatePlayback {
      in item playCommand : RemoteCommand;
      out item status : RecorderStatus;
    }

    state machine recorderControlStateMachine {
      state off;
      state standby;
      state tuning;
      state recording;
      state playback;
      state paused;
      state finalizingDisk;
      state error;

      initial then standby;

      transition standby_to_tuning
        first standby
        accept RemoteCommand
        if command.kind == CommandKind::SelectChannel
        then tuning;

      transition tuning_to_standby
        first tuning
        accept RecorderStatus
        if status.mode == RecorderMode::Standby
        then standby;

      transition standby_to_recording
        first standby
        accept RemoteCommand
        if command.kind == CommandKind::StartRecording
        then recording;

      transition tuning_to_recording
        first tuning
        accept RemoteCommand
        if command.kind == CommandKind::StartRecording
        then recording;

      transition recording_to_finalizing
        first recording
        accept RemoteCommand
        if command.kind == CommandKind::StopRecording
        then finalizingDisk;

      transition finalizing_to_standby
        first finalizingDisk
        accept RecorderStatus
        if status.mode == RecorderMode::Standby
        then standby;

      transition standby_to_playback
        first standby
        accept RemoteCommand
        if command.kind == CommandKind::Play
        then playback;

      transition playback_to_paused
        first playback
        accept RemoteCommand
        if command.kind == CommandKind::Pause
        then paused;

      transition paused_to_playback
        first paused
        accept RemoteCommand
        if command.kind == CommandKind::Play
        then playback;

      transition playback_to_standby
        first playback
        accept RemoteCommand
        if command.kind == CommandKind::StopPlayback
        then standby;

      transition paused_to_standby
        first paused
        accept RemoteCommand
        if command.kind == CommandKind::StopPlayback
        then standby;

      transition any_to_off
        first standby
        accept RemoteCommand
        if command.kind == CommandKind::PowerOff
        then off;

      transition off_to_standby
        first off
        accept RemoteCommand
        if command.kind == CommandKind::PowerOn
        then standby;
    }
  }

  part def FrontPanelAndRemoteReceiver {
    attribute infraredCarrierFrequency : Frequency = 38000 [Hz];
    attribute hasFrontPanelButtons : Boolean = true;
    attribute displayLineCount : Integer = 2;

    port commandOut : ControlInputPort;
    port statusIn : StatusOutputPort;

    action receiveUserCommand {
      out item command : RemoteCommand;
    }

    action displayRecorderStatus {
      in item status : RecorderStatus;
    }
  }

  part def PowerSupply {
    attribute nominalInputVoltage : ElectricPotential = 120 [V];
    attribute nominalOutputPower : Power = 45 [W];
    attribute standbyPower : Power = 1 [W];
    attribute operatingTemperatureLimit : Temperature = 50 [degC];

    port acInput : PowerInputPort;
    port dcOutput : PowerInputPort;

    action convertPower {
      in item mainsPower : ElectricalPower;
      out item regulatedPower : ElectricalPower;
    }
  }

  part def VideoDiskRecorder {
    attribute productName : String = "High Level Video Disk Recorder";
    attribute primaryFunction : String = "Capture television or external video programs, encode them, store them on disk media, and play stored programs back on demand.";
    attribute supportsScheduledRecording : Boolean = true;
    attribute supportsLiveRecording : Boolean = true;
    attribute supportsPlayback : Boolean = true;
    attribute canCaptureAndStore : Boolean = true;

    port antennaInput : RFInputPort;
    port externalAnalogInput : AnalogVideoInputPort;
    port remoteControlInput : ControlInputPort;
    port scheduleInput : ScheduleInputPort;
    port statusOutput : StatusOutputPort;
    port playbackOutput : PlaybackOutputPort;
    port mainsPowerInput : PowerInputPort;

    part tuner : RFFrontEndTuner;
    part analogCapture : AnalogCaptureInterface;
    part encoder : VideoAudioEncoder;
    part buffer : ProgramBuffer;
    part diskStorage : DiskStorageUnit;
    part playbackDecoder : PlaybackDecoder;
    part scheduler : RecordingScheduler;
    part controller : RecorderController;
    part userInterface : FrontPanelAndRemoteReceiver;
    part powerSupply : PowerSupply;

    connect antennaInput.rf to tuner.rfIn.rf;
    connect externalAnalogInput.video to analogCapture.analogIn.video;
    connect externalAnalogInput.audio to analogCapture.analogIn.audio;
    connect tuner.transportOut.stream to encoder.streamIn.stream;
    connect analogCapture.digitizedTransportOut.stream to encoder.streamIn.stream;
    connect encoder.encodedVideoOut.video to buffer.encodedVideoIn.video;
    connect encoder.encodedAudioOut.audio to buffer.encodedVideoIn.audio;
    connect buffer.bufferedProgramOut.storedProgram to diskStorage.writePort.metadata;
    connect encoder.encodedVideoOut.video to diskStorage.writePort.video;
    connect encoder.encodedAudioOut.audio to diskStorage.writePort.audio;
    connect diskStorage.readPort.storedProgram to playbackDecoder.storedProgramIn.storedProgram;
    connect playbackDecoder.playbackOut.video to playbackOutput.video;
    connect playbackDecoder.playbackOut.audio to playbackOutput.audio;
    connect remoteControlInput.command to controller.userCommandIn.command;
    connect scheduleInput.schedule to scheduler.scheduleIn.schedule;
    connect scheduler.controlOut.command to controller.schedulerCommandIn.command;
    connect controller.statusOut.status to statusOutput.status;
    connect controller.statusOut.status to userInterface.statusIn.status;
    connect userInterface.commandOut.command to controller.userCommandIn.command;
    connect mainsPowerInput.power to powerSupply.acInput.power;

    action primaryRecordProgramFunction {
      in item selectedChannelSignal : RadioFrequencySignal;
      in item userCommand : RemoteCommand;
      out item recordedProgram : StoredProgram;

      first start;
      then tuneBroadcast;
      then encodeIncomingProgram;
      then bufferEncodedProgram;
      then writeProgram;
      then reportReady;

      action start;
      action tuneBroadcast {
        in item rf : RadioFrequencySignal;
        out item tunedStream : TransportStream;
      }
      action encodeIncomingProgram {
        in item tunedStream : TransportStream;
        out item video : EncodedVideoStream;
        out item audio : EncodedAudioStream;
      }
      action bufferEncodedProgram {
        in item video : EncodedVideoStream;
        in item audio : EncodedAudioStream;
        out item metadata : StoredProgram;
      }
      action writeProgram {
        in item video : EncodedVideoStream;
        in item audio : EncodedAudioStream;
        in item metadata : StoredProgram;
        out item storedProgram : StoredProgram;
      }
      action reportReady {
        out item status : RecorderStatus;
      }
    }

    action primaryPlaybackFunction {
      in item selectedProgramId : ProgramIdentifier;
      out item video : BasebandVideoSignal;
      out item audio : AudioSignal;

      first loadProgramFromDisk;
      then decodeProgram;
      then outputProgram;

      action loadProgramFromDisk {
        in item programId : ProgramIdentifier;
        out item storedProgram : StoredProgram;
      }
      action decodeProgram {
        in item storedProgram : StoredProgram;
        out item decodedVideo : BasebandVideoSignal;
        out item decodedAudio : AudioSignal;
      }
      action outputProgram {
        in item decodedVideo : BasebandVideoSignal;
        in item decodedAudio : AudioSignal;
      }
    }

    state machine videoDiskRecorderOperationalBehavior {
      state poweredOff;
      state readyForCommand;
      state acceptingSchedule;
      state capturingProgram;
      state storingProgram;
      state playingStoredProgram;
      state safeStop;
      state faulted;

      initial then poweredOff;

      transition powerOn
        first poweredOff
        accept RemoteCommand
        if command.kind == CommandKind::PowerOn
        then readyForCommand;

      transition scheduleRecording
        first readyForCommand
        accept RemoteCommand
        if command.kind == CommandKind::ScheduleRecording
        then acceptingSchedule;

      transition scheduleAccepted
        first acceptingSchedule
        then readyForCommand;

      transition beginLiveRecording
        first readyForCommand
        accept RemoteCommand
        if command.kind == CommandKind::StartRecording
        then capturingProgram;

      transition captureToStore
        first capturingProgram
        then storingProgram;

      transition stopRecording
        first storingProgram
        accept RemoteCommand
        if command.kind == CommandKind::StopRecording
        then safeStop;

      transition finalizationComplete
        first safeStop
        then readyForCommand;

      transition beginPlayback
        first readyForCommand
        accept RemoteCommand
        if command.kind == CommandKind::Play
        then playingStoredProgram;

      transition stopPlayback
        first playingStoredProgram
        accept RemoteCommand
        if command.kind == CommandKind::StopPlayback
        then readyForCommand;

      transition shutdown
        first readyForCommand
        accept RemoteCommand
        if command.kind == CommandKind::PowerOff
        then poweredOff;
    }
  }

  requirement def PrimaryFunctionRequirement {
    subject recorder : VideoDiskRecorder;

    doc /* The Video Disk Recorder shall provide the high-level primary function of receiving a selected video program, converting it into a disk-recordable digital representation, storing it on disk media with program metadata, and making the stored program available for later playback. */

    require constraint {
      recorder.canCaptureAndStore == true
      and recorder.supportsLiveRecording == true
      and recorder.supportsPlayback == true
    }
  }

  requirement def RecordingCapacityRequirement {
    subject storage : DiskStorageUnit;

    doc /* The recording storage shall provide sufficient capacity for multiple programs and shall maintain a minimum free capacity threshold before accepting a new recording. */

    require constraint {
      storage.totalCapacity >= 500000000000 [byte]
      and storage.minimumRequiredFreeCapacity >= 1073741824 [byte]
      and storage.diskPresent == true
    }
  }

  requirement def ScheduledRecordingRequirement {
    subject recorder : VideoDiskRecorder;

    doc /* The recorder shall accept scheduled recording requests containing channel, start offset, duration, title, and quality, and shall initiate and terminate recordings automatically. */

    require constraint {
      recorder.supportsScheduledRecording == true
    }
  }

  requirement def PlaybackRequirement {
    subject decoder : PlaybackDecoder;

    doc /* The recorder shall decode a selected stored program and output synchronized baseband video and audio for display. */

    require constraint {
      decoder.maximumOutputWidth >= 1920
      and decoder.maximumOutputHeight >= 1080
    }
  }

  requirement def LowStandbyPowerRequirement {
    subject supply : PowerSupply;

    doc /* The recorder shall consume low power while waiting in standby for user or scheduled recording commands. */

    require constraint {
      supply.standbyPower <= 1 [W]
    }
  }

  requirement def UserStatusRequirement {
    subject controller : RecorderController;

    doc /* The recorder shall report operating mode, selected channel, active program identifier, free capacity, disk presence, and fault status to the user interface. */

    require constraint {
      controller.maximumContinuousRecordingDuration >= 7200 [s]
    }
  }

  part vdrSystem : VideoDiskRecorder;

  satisfy PrimaryFunctionRequirement by vdrSystem;
  satisfy ScheduledRecordingRequirement by vdrSystem;
  satisfy RecordingCapacityRequirement by vdrSystem.diskStorage;
  satisfy PlaybackRequirement by vdrSystem.playbackDecoder;
  satisfy LowStandbyPowerRequirement by vdrSystem.powerSupply;
  satisfy UserStatusRequirement by vdrSystem.controller;
}
