package BroadcastAutomationSystemModel {

    private import ScalarValues::*;
    private import SI::*;
    private import ISQ::*;

    attribute def Percent :> Real {
        unit = "%";
    }

    attribute def FrameRate :> Real {
        unit = "frame/s";
    }

    attribute def BitRate :> Real {
        unit = "Mbit/s";
    }

    attribute def Timecode :> String;
    attribute def MediaIdentifier :> String;
    attribute def ProgramIdentifier :> String;
    attribute def ChannelIdentifier :> String;

    enum def BroadcastMode {
        enum linear;
        enum liveBreakIn;
        enum emergencyOverride;
        enum maintenance;
    }

    enum def MediaState {
        enum unavailable;
        enum available;
        enum queued;
        enum playing;
        enum complete;
        enum failed;
    }

    item def VideoEssence {
        attribute resolutionWidth : Integer;
        attribute resolutionHeight : Integer;
        attribute frameRate : FrameRate;
        attribute codec : String;
        attribute bitrate : BitRate;
    }

    item def AudioEssence {
        attribute channelCount : Integer;
        attribute sampleRate : FrequencyValue;
        attribute loudnessLufs : Real;
        attribute codec : String;
        attribute bitrate : BitRate;
    }

    item def MediaAsset {
        attribute assetId : MediaIdentifier;
        attribute title : String;
        attribute duration : TimeValue;
        attribute houseNumber : String;
        attribute video : VideoEssence;
        attribute audio : AudioEssence;
        attribute state : MediaState;
        attribute checksum : String;
    }

    item def PlaylistEvent {
        attribute eventId : String;
        attribute programId : ProgramIdentifier;
        attribute plannedStart : Timecode;
        attribute plannedDuration : TimeValue;
        attribute hardStart : Boolean;
        attribute assetRef : MediaIdentifier;
        attribute secondaryEvents : String;
    }

    item def Playlist {
        attribute playlistId : String;
        attribute channelId : ChannelIdentifier;
        attribute broadcastDate : String;
        item events : PlaylistEvent[1..*];
    }

    item def ControlCommand {
        attribute commandId : String;
        attribute targetDevice : String;
        attribute commandName : String;
        attribute scheduledAt : Timecode;
        attribute parameters : String;
    }

    item def StatusMessage {
        attribute sourceDevice : String;
        attribute healthy : Boolean;
        attribute message : String;
        attribute measuredLatency : TimeValue;
        attribute timestamp : Timecode;
    }

    item def TransportStream {
        attribute serviceId : Integer;
        attribute programClockReferenceStable : Boolean;
        attribute bitrate : BitRate;
        item video : VideoEssence;
        item audio : AudioEssence;
    }

    item def Alarm {
        attribute alarmId : String;
        attribute severity : Integer;
        attribute source : String;
        attribute description : String;
        attribute active : Boolean;
    }

    port def PlaylistInputPort {
        in item playlist : Playlist;
    }

    port def MediaInputPort {
        in item asset : MediaAsset;
    }

    port def CommandOutputPort {
        out item command : ControlCommand;
    }

    port def StatusInputPort {
        in item status : StatusMessage;
    }

    port def TransportOutputPort {
        out item stream : TransportStream;
    }

    port def AlarmOutputPort {
        out item alarm : Alarm;
    }

    port def OperatorControlPort {
        in item command : ControlCommand;
        out item status : StatusMessage;
        out item alarm : Alarm;
    }

    action def ValidatePlaylist {
        in item playlist : Playlist;
        out valid : Boolean;
        out item alarm : Alarm;

        first start;
        then checkEvents;
        then verifyTiming;
        then verifyAssetReferences;
        then decision acceptOrReject;

        if acceptOrReject then validPlaylist;
        else invalidPlaylist;

        then done;

        action checkEvents;
        action verifyTiming;
        action verifyAssetReferences;
        action validPlaylist {
            out valid = true;
        }
        action invalidPlaylist {
            out valid = false;
        }
    }

    action def CueMedia {
        in item event : PlaylistEvent;
        in item asset : MediaAsset;
        out item command : ControlCommand;
        out ready : Boolean;
    }

    action def ExecutePlayout {
        in item event : PlaylistEvent;
        in item asset : MediaAsset;
        out item stream : TransportStream;
        out item status : StatusMessage;
    }

    action def MonitorBroadcastHealth {
        in item status : StatusMessage;
        out healthy : Boolean;
        out item alarm : Alarm;
    }

    action def SwitchToBackupPath {
        in reason : String;
        out item command : ControlCommand;
        out backupActive : Boolean;
    }

    action def GenerateAsRunLogEntry {
        in item event : PlaylistEvent;
        in actualStart : Timecode;
        in actualDuration : TimeValue;
        in completed : Boolean;
        out logRecord : String;
    }

    state def AutomationOperationalState {
        entry action initializeAutomation;

        state Idle;
        state LoadingSchedule;
        state ValidatingSchedule;
        state Ready;
        state Cueing;
        state OnAir;
        state Hold;
        state LiveBreakIn;
        state EmergencyOverride;
        state FaultRecovery;
        state Maintenance;

        initial then Idle;

        transition Idle_to_LoadingSchedule
            first Idle
            accept ControlCommand
            if commandName == "LOAD_PLAYLIST"
            then LoadingSchedule;

        transition LoadingSchedule_to_ValidatingSchedule
            first LoadingSchedule
            then ValidatingSchedule;

        transition ValidatingSchedule_to_Ready
            first ValidatingSchedule
            if true
            then Ready;

        transition Ready_to_Cueing
            first Ready
            accept ControlCommand
            if commandName == "CUE_NEXT"
            then Cueing;

        transition Cueing_to_OnAir
            first Cueing
            accept ControlCommand
            if commandName == "TAKE"
            then OnAir;

        transition OnAir_to_Cueing
            first OnAir
            accept ControlCommand
            if commandName == "NEXT_EVENT"
            then Cueing;

        transition OnAir_to_Hold
            first OnAir
            accept ControlCommand
            if commandName == "HOLD"
            then Hold;

        transition Hold_to_OnAir
            first Hold
            accept ControlCommand
            if commandName == "RESUME"
            then OnAir;

        transition OnAir_to_LiveBreakIn
            first OnAir
            accept ControlCommand
            if commandName == "LIVE_BREAK_IN"
            then LiveBreakIn;

        transition LiveBreakIn_to_OnAir
            first LiveBreakIn
            accept ControlCommand
            if commandName == "RETURN_TO_PLAYLIST"
            then OnAir;

        transition Any_to_EmergencyOverride
            first Idle, LoadingSchedule, ValidatingSchedule, Ready, Cueing, OnAir, Hold, LiveBreakIn, FaultRecovery
            accept ControlCommand
            if commandName == "EMERGENCY_OVERRIDE"
            then EmergencyOverride;

        transition EmergencyOverride_to_Ready
            first EmergencyOverride
            accept ControlCommand
            if commandName == "CLEAR_EMERGENCY"
            then Ready;

        transition Any_to_FaultRecovery
            first LoadingSchedule, ValidatingSchedule, Ready, Cueing, OnAir, Hold, LiveBreakIn
            accept Alarm
            if severity >= 2
            then FaultRecovery;

        transition FaultRecovery_to_Ready
            first FaultRecovery
            accept StatusMessage
            if healthy == true
            then Ready;

        transition Ready_to_Maintenance
            first Ready
            accept ControlCommand
            if commandName == "ENTER_MAINTENANCE"
            then Maintenance;

        transition Maintenance_to_Idle
            first Maintenance
            accept ControlCommand
            if commandName == "EXIT_MAINTENANCE"
            then Idle;
    }

    part def MediaRepository {
        port ingest : MediaInputPort;
        port statusOut : StatusInputPort;

        attribute storageCapacity : DataSizeValue = 8000 [SI::giga] "byte";
        attribute availableCapacity : DataSizeValue;
        attribute assetAvailability : Percent;
        attribute checksumVerificationEnabled : Boolean = true;

        part assetCatalog {
            item storedAssets : MediaAsset[0..*];
        }
    }

    part def ScheduleManager {
        port playlistIn : PlaylistInputPort;
        port commandOut : CommandOutputPort;
        port alarmOut : AlarmOutputPort;

        attribute activeChannel : ChannelIdentifier;
        attribute scheduleHorizon : TimeValue = 48 [SI::h];
        attribute minimumEventGap : TimeValue = 0.04 [SI::s];

        perform action validatePlaylist : ValidatePlaylist;
    }

    part def PlayoutController {
        port commandOut : CommandOutputPort;
        port statusIn : StatusInputPort;
        port alarmOut : AlarmOutputPort;

        attribute mode : BroadcastMode = BroadcastMode::linear;
        attribute frameAccurateSwitching : Boolean = true;
        attribute maximumAllowedTimingError : TimeValue = 0.02 [SI::s];

        exhibit state operationalState : AutomationOperationalState;

        perform action cueMedia : CueMedia;
        perform action executePlayout : ExecutePlayout;
        perform action switchToBackup : SwitchToBackupPath;
        perform action logAsRun : GenerateAsRunLogEntry;
    }

    part def VideoServer {
        port commandIn : CommandOutputPort;
        port mediaIn : MediaInputPort;
        port statusOut : StatusInputPort;
        port streamOut : TransportOutputPort;

        attribute outputFrameRate : FrameRate = 59.94 [frame/s];
        attribute nominalOutputBitrate : BitRate = 35 [Mbit/s];
        attribute outputLatency : TimeValue = 0.2 [SI::s];
        attribute primaryChannelAvailable : Boolean;
        attribute backupChannelAvailable : Boolean;
    }

    part def GraphicsEngine {
        port commandIn : CommandOutputPort;
        port statusOut : StatusInputPort;
        port streamOut : TransportOutputPort;

        attribute maximumLayers : Integer = 12;
        attribute renderLatency : TimeValue = 0.08 [SI::s];
        attribute fillKeyOutputEnabled : Boolean = true;
    }

    part def AudioProcessor {
        port commandIn : CommandOutputPort;
        port statusOut : StatusInputPort;
        port streamOut : TransportOutputPort;

        attribute targetLoudness : Real = -24.0;
        attribute truePeakLimit : Real = -2.0;
        attribute channelConfiguration : String = "5.1 plus stereo downmix";
    }

    part def MasterControlSwitcher {
        port commandIn : CommandOutputPort;
        port videoInA : TransportOutputPort;
        port videoInB : TransportOutputPort;
        port graphicsIn : TransportOutputPort;
        port audioIn : TransportOutputPort;
        port statusOut : StatusInputPort;
        port programOut : TransportOutputPort;

        attribute switchingAccuracy : TimeValue = 0.01 [SI::s];
        attribute emergencyInputAvailable : Boolean;
        attribute activeSourceName : String;
    }

    part def TransmissionEncoder {
        port programIn : TransportOutputPort;
        port commandIn : CommandOutputPort;
        port statusOut : StatusInputPort;
        port transportOut : TransportOutputPort;

        attribute encodedBitrate : BitRate = 18 [Mbit/s];
        attribute encoderLatency : TimeValue = 1.5 [SI::s];
        attribute closedCaptionPassThrough : Boolean = true;
        attribute audioMetadataPassThrough : Boolean = true;
    }

    part def HealthMonitor {
        port statusIn : StatusInputPort;
        port alarmOut : AlarmOutputPort;
        port commandOut : CommandOutputPort;

        attribute statusPollingInterval : TimeValue = 1 [SI::s];
        attribute maximumPermittedDeviceLatency : TimeValue = 2 [SI::s];
        attribute alarmSuppressionWindow : TimeValue = 10 [SI::s];

        perform action monitorHealth : MonitorBroadcastHealth;
    }

    part def OperatorConsole {
        port operatorControl : OperatorControlPort;
        port playlistOut : PlaylistInputPort;
        port commandOut : CommandOutputPort;
        port alarmIn : AlarmOutputPort;
        port statusIn : StatusInputPort;

        attribute authenticatedOperator : String;
        attribute manualTakeEnabled : Boolean = true;
        attribute emergencyOverrideArmed : Boolean = false;
    }

    part def AsRunLogger {
        port statusIn : StatusInputPort;

        attribute retentionPeriod : TimeValue = 730 [SI::d];
        attribute logFormat : String = "eventId, assetId, plannedStart, actualStart, actualDuration, result";
        attribute immutableStorageEnabled : Boolean = true;
    }

    part def BroadcastAutomationSystem {
        port playlistInput : PlaylistInputPort;
        port mediaInput : MediaInputPort;
        port operatorInterface : OperatorControlPort;
        port broadcastOutput : TransportOutputPort;
        port alarmOutput : AlarmOutputPort;

        attribute systemName : String = "Integrated Broadcast Automation System";
        attribute primaryFunction : String = "Automatically schedule, cue, switch, play, monitor, and log broadcast media and live sources to produce a continuous frame-accurate program output.";
        attribute supportedChannels : Integer = 4;
        attribute requiredAvailability : Percent = 99.99 [%];
        attribute maximumOnAirTimingError : TimeValue = 0.04 [SI::s];

        part repository : MediaRepository;
        part scheduler : ScheduleManager;
        part controller : PlayoutController;
        part primaryVideoServer : VideoServer;
        part backupVideoServer : VideoServer;
        part graphics : GraphicsEngine;
        part audioProcessor : AudioProcessor;
        part switcher : MasterControlSwitcher;
        part encoder : TransmissionEncoder;
        part monitor : HealthMonitor;
        part console : OperatorConsole;
        part logger : AsRunLogger;

        connect playlistInput to scheduler.playlistIn;
        connect mediaInput to repository.ingest;
        connect console.playlistOut to scheduler.playlistIn;
        connect console.commandOut to controller.commandOut;
        connect operatorInterface to console.operatorControl;

        connect scheduler.commandOut to controller.commandOut;
        connect controller.commandOut to primaryVideoServer.commandIn;
        connect controller.commandOut to backupVideoServer.commandIn;
        connect controller.commandOut to graphics.commandIn;
        connect controller.commandOut to audioProcessor.commandIn;
        connect controller.commandOut to switcher.commandIn;
        connect controller.commandOut to encoder.commandIn;

        connect repository.ingest to primaryVideoServer.mediaIn;
        connect repository.ingest to backupVideoServer.mediaIn;

        connect primaryVideoServer.streamOut to switcher.videoInA;
        connect backupVideoServer.streamOut to switcher.videoInB;
        connect graphics.streamOut to switcher.graphicsIn;
        connect audioProcessor.streamOut to switcher.audioIn;
        connect switcher.programOut to encoder.programIn;
        connect encoder.transportOut to broadcastOutput;

        connect primaryVideoServer.statusOut to monitor.statusIn;
        connect backupVideoServer.statusOut to monitor.statusIn;
        connect graphics.statusOut to monitor.statusIn;
        connect audioProcessor.statusOut to monitor.statusIn;
        connect switcher.statusOut to monitor.statusIn;
        connect encoder.statusOut to monitor.statusIn;

        connect monitor.commandOut to controller.commandOut;
        connect monitor.alarmOut to alarmOutput;
        connect scheduler.alarmOut to alarmOutput;
        connect controller.alarmOut to alarmOutput;
        connect monitor.alarmOut to console.alarmIn;

        connect encoder.statusOut to logger.statusIn;
        connect switcher.statusOut to logger.statusIn;
    }

    requirement def ContinuousBroadcastRequirement {
        subject system : BroadcastAutomationSystem;

        require constraint {
            system.requiredAvailability >= 99.99 [%]
        }

        doc
        /*
         The system shall provide continuous automated broadcast playout for configured channels with no planned interruption during normal linear operation.
        */
    }

    requirement def FrameAccuratePlayoutRequirement {
        subject system : BroadcastAutomationSystem;

        require constraint {
            system.maximumOnAirTimingError <= 0.04 [SI::s]
        }

        doc
        /*
         The system shall cue, start, switch, and complete playlist events within one video frame of the planned event boundary.
        */
    }

    requirement def ScheduleValidationRequirement {
        subject scheduler : ScheduleManager;

        require constraint {
            scheduler.minimumEventGap >= 0 [SI::s]
        }

        doc
        /*
         The schedule manager shall validate playlist timing, event sequence, hard starts, asset references, and secondary event instructions before release to air.
        */
    }

    requirement def MediaAvailabilityRequirement {
        subject repository : MediaRepository;

        require constraint {
            repository.assetAvailability >= 99.95 [%]
        }

        doc
        /*
         The media repository shall verify that all scheduled assets are present, readable, and checksum-valid before they are eligible for automated playout.
        */
    }

    requirement def RedundantPlayoutRequirement {
        subject system : BroadcastAutomationSystem;

        require constraint {
            system.primaryVideoServer.backupChannelAvailable == true
        }

        doc
        /*
         The system shall maintain a backup playout path and command automatic failover when the active path cannot provide valid output.
        */
    }

    requirement def EmergencyOverrideRequirement {
        subject controller : PlayoutController;

        doc
        /*
         The playout controller shall accept an emergency override command from the operator console and route the emergency source to program output ahead of scheduled events.
        */
    }

    requirement def AsRunLoggingRequirement {
        subject logger : AsRunLogger;

        require constraint {
            logger.immutableStorageEnabled == true
        }

        doc
        /*
         The logger shall record completed, skipped, failed, manually taken, live break-in, and emergency override events with actual time and duration.
        */
    }

    requirement def HealthMonitoringRequirement {
        subject monitor : HealthMonitor;

        require constraint {
            monitor.statusPollingInterval <= 1 [SI::s]
        }

        doc
        /*
         The health monitor shall collect device status, detect unavailable or late devices, raise alarms, and command backup switching when broadcast continuity is at risk.
        */
    }

    satisfy ContinuousBroadcastRequirement by BroadcastAutomationSystem;
    satisfy FrameAccuratePlayoutRequirement by BroadcastAutomationSystem;
    satisfy ScheduleValidationRequirement by ScheduleManager;
    satisfy MediaAvailabilityRequirement by MediaRepository;
    satisfy RedundantPlayoutRequirement by BroadcastAutomationSystem;
    satisfy EmergencyOverrideRequirement by PlayoutController;
    satisfy AsRunLoggingRequirement by AsRunLogger;
    satisfy HealthMonitoringRequirement by HealthMonitor;

}