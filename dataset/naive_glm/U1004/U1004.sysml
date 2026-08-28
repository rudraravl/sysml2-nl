package BroadcastAutomationSystem {
    import ScalarValues::*;
    import ISQ::*;
    
    // ===== Value Types =====
    
    value type FrameRate > Real {
        doc /* Frames per second */;
        unit 'fps';
    }
    
    value type Bitrate > Real {
        doc /* Data rate in megabits per second */;
        unit 'Mbps';
    }
    
    value type ResolutionWidth > Integer {
        doc /* Horizontal pixel count */;
        unit 'px';
    }
    
    value type ResolutionHeight > Integer {
        doc /* Vertical pixel count */;
        unit 'px';
    }
    
    value type SignalLevel > Real {
        doc /* Video signal level in millivolts */;
        unit 'mV';
    }
    
    value type Latency > Real {
        doc /* End-to-end latency in milliseconds */;
        unit 'ms';
    }
    
    value type UptimeRatio > Real {
        doc /* Availability ratio, dimensionless 0..1 */;
    }
    
    // ===== Enumerations =====
    
    enum MediaKind {
        program;
        commercial;
        promotion;
        movie;
        graphic;
    }
    
    enum EventStatus {
        scheduled;
        cued;
        playing;
        completed;
        skipped;
        failed;
    }
    
    enum SignalSource {
        primaryServer;
        backupServer;
        graphicsEngine;
        emergency;
    }
    
    enum DeliveryStandard {
        dvbT;
        atsc;
        isdb;
        cable;
        satellite;
        ipStream;
    }
    
    enum CommandKind {
        loadAsset;
        play;
        stop;
        cue;
        take;
        clearGraphics;
        switchSource;
        failover;
        standby;
    }
    
    // ===== Item Types =====
    
    item def MediaAsset {
        attribute id : String;
        attribute title : String;
        attribute kind : MediaKind;
        attribute duration : DurationValue;
        attribute frameRate : FrameRate := 25.0;
        attribute width : ResolutionWidth := 1920;
        attribute height : ResolutionHeight := 1080;
        attribute filePath : String;
    }
    
    item def ScheduleEvent {
        attribute eventId : String;
        attribute assetId : String;
        attribute scheduledStart : InstantValue;
        attribute scheduledDuration : DurationValue;
        attribute status : EventStatus := scheduled;
        attribute source : SignalSource := primaryServer;
        part ref asset : MediaAsset;
    }
    
    item def Playlist {
        attribute channel : String;
        attribute broadcastDate : Date;
        attribute events : ScheduleEvent[0..*];
    }
    
    item def VideoSignal {
        attribute width : ResolutionWidth;
        attribute height : ResolutionHeight;
        attribute frameRate : FrameRate;
        attribute level : SignalLevel;
        attribute active : Boolean := true;
    }
    
    item def AudioSignal {
        attribute channels : Integer := 2;
        attribute sampleRateHz : Integer := 48000;
        attribute levelDb : Real := -12.0;
        attribute active : Boolean := true;
    }
    
    item def GraphicsLayer {
        attribute layerId : String;
        attribute templateName : String;
        attribute visible : Boolean := true;
        attribute opacity : Real := 1.0;
    }
    
    item def Command {
        attribute kind : CommandKind;
        attribute targetId : String;
        attribute payload : String;
        attribute issuedAt : InstantValue;
    }
    
    item def TelemetryReport {
        attribute componentId : String;
        attribute healthy : Boolean;
        attribute timestamp : InstantValue;
        attribute detail : String;
    }
    
    // ===== Port Definitions =====
    
    port def CommandPort {
        out commands : Command[0..*];
        in acknowledgements : Command[0..*];
    }
    
    port def VideoOutPort {
        out video : VideoSignal;
    }
    
    port def VideoInPort {
        in video : VideoSignal;
    }
    
    port def AudioOutPort {
        out audio : AudioSignal;
    }
    
    port def AudioInPort {
        in audio : AudioSignal;
    }
    
    port def MediaPort {
        in assets : MediaAsset[0..*];
        out loadedAsset : MediaAsset;
    }
    
    port def SchedulePort {
        in playlist : Playlist;
        out currentEvent : ScheduleEvent;
    }
    
    port def TelemetryPort {
        out report : TelemetryReport;
    }
    
    port def GraphicsControlPort {
        in layers : GraphicsLayer[0..*];
        out compositedVideo : VideoSignal;
    }
    
    // ===== Component Definitions =====
    
    part def PlayoutAutomation {
        doc /* Central controller that ingests the playlist and issues frame-accurate commands. */;
        
        attribute systemClock : InstantValue;
        attribute activePlaylist : Playlist;
        attribute currentEventIndex : Integer := 0;
        attribute frameAccuracyTolerance : DurationValue := 0 [ms];
        
        port scheduleIn : SchedulePort;
        port cmdMedia : CommandPort;
        port cmdBackup : CommandPort;
        port cmdGraphics : CommandPort;
        port cmdRouter : CommandPort;
        port cmdMaster : CommandPort;
        port cmdEncoder : CommandPort;
        port telemetry : TelemetryPort;
        
        state machine behavior : PlayoutStateMachine {
            entry; then idle;
            
            state idle;
            transition idle_to_standby
                first idle
                accept SchedulePort.playlist
                then standby;
            
            state standby {
                entry; 
                // Pre-cue first event
            }
            transition standby_to_active
                first standby
                accept ClockTick
                guard activePlaylist.events->size() > 0
                then active;
            
            state active {
                // Dispatch commands at scheduled times
                do dispatchEvents;
            }
            transition active_to_emergency
                first active
                accept CriticalFault
                then emergency;
            transition active_to_idle
                first active
                accept PlaylistComplete
                then idle;
            
            state emergency {
                entry; 
                // Trigger failover
                do failoverProcedure;
            }
            transition emergency_to_active
                first emergency
                accept FaultCleared
                guard primaryRestored
                then active;
        }
        
        action dispatchEvents {
            in events : ScheduleEvent[0..*];
            out commands : Command[0..*];
            
            // For each event whose scheduledStart equals systemClock,
            // emit loadAsset/play/switchSource/take commands to relevant components.
        }
        
        action failoverProcedure {
            out commands : Command[0..*];
            // Issue failover command to MasterControl and switchSource to BackupServer
        }
    }
    
    part def MediaServer {
        doc /* Stores and plays media assets; provides primary video/audio feed. */;
        
        attribute serverId : String;
        attribute library : MediaAsset[0..*];
        attribute nowPlaying : MediaAsset;
        attribute healthy : Boolean := true;
        attribute maxBitrate : Bitrate := 50.0;
        
        port cmdIn : CommandPort;
        port mediaOut : MediaPort;
        port videoOut : VideoOutPort;
        port audioOut : AudioOutPort;
        port telemetry : TelemetryPort;
        
        action playAsset {
            in asset : MediaAsset;
            out video : VideoSignal;
            out audio : AudioSignal;
        }
        
        action cueAsset {
            in asset : MediaAsset;
        }
        
        action stop {
            out video : VideoSignal;
            out audio : AudioSignal;
        }
    }
    
    part def BackupServer :> MediaServer {
        doc /* Identical redundancy server; activated on primary failure. */;
        attribute role : String := "backup";
        attribute syncOffset : DurationValue := 0 [ms];
    }
    
    part def GraphicsEngine {
        doc /* Composites on-screen graphics onto video feed. */;
        
        attribute engineId : String;
        attribute activeLayers : GraphicsLayer[0..*];
        attribute healthy : Boolean := true;
        
        port cmdIn : CommandPort;
        port videoIn : VideoInPort;
        port graphicsCtrl : GraphicsControlPort;
        port videoOut : VideoOutPort;
        port telemetry : TelemetryPort;
        
        action composite {
            in baseVideo : VideoSignal;
            in layers : GraphicsLayer[0..*];
            out composited : VideoSignal;
        }
        
        action updateLayer {
            in layer : GraphicsLayer;
        }
    }
    
    part def VideoRouter {
        doc /* Switchboard selecting active source under automation control. */;
        
        attribute routerId : String;
        attribute selectedSource : SignalSource := primaryServer;
        attribute healthy : Boolean := true;
        
        port cmdIn : CommandPort;
        port primaryIn : VideoInPort;
        port backupIn : VideoInPort;
        port graphicsIn : VideoInPort;
        port primaryAudioIn : AudioInPort;
        port backupAudioIn : AudioInPort;
        port videoOut : VideoOutPort;
        port audioOut : AudioOutPort;
        port telemetry : TelemetryPort;
        
        action switchSource {
            in source : SignalSource;
            out video : VideoSignal;
            out audio : AudioSignal;
        }
    }
    
    part def MasterControl {
        doc /* Final QC and automated failover before transmission. */;
        
        attribute unitId : String;
        attribute activeFeed : SignalSource := primaryServer;
        attribute healthy : Boolean := true;
        attribute signalThreshold : SignalLevel := 700.0;
        attribute failoverLatency : Latency := 40 [ms];
        
        port cmdIn : CommandPort;
        port primaryIn : VideoInPort;
        port backupIn : VideoInPort;
        port primaryAudioIn : AudioInPort;
        port backupAudioIn : AudioInPort;
        port videoOut : VideoOutPort;
        port audioOut : AudioOutPort;
        port telemetry : TelemetryPort;
        
        state machine qcBehavior {
            entry; then monitoring;
            
            state monitoring {
                do checkSignal;
            }
            transition to_failover
                first monitoring
                accept SignalLoss
                then failover;
            
            state failover {
                entry; 
                do switchToBackup;
            }
            transition back_to_monitoring
                first failover
                accept PrimaryRestored
                then monitoring;
        }
        
        action checkSignal {
            in video : VideoSignal;
            in audio : AudioSignal;
            out healthy : Boolean;
        }
        
        action switchToBackup {
            out video : VideoSignal;
            out audio : AudioSignal;
        }
    }
    
    part def TransmissionEncoder {
        doc /* Compresses and formats final signal for delivery. */;
        
        attribute encoderId : String;
        attribute delivery : DeliveryStandard := ipStream;
        attribute outputBitrate : Bitrate := 8.0;
        attribute healthy : Boolean := true;
        
        port cmdIn : CommandPort;
        port videoIn : VideoInPort;
        port audioIn : AudioInPort;
        port telemetry : TelemetryPort;
        
        action encode {
            in video : VideoSignal;
            in audio : AudioSignal;
            in standard : DeliveryStandard;
            in bitrate : Bitrate;
            out transportStream : Blob;
        }
    }
    
    // ===== System-Level Assembly =====
    
    part BroadcastSystem {
        doc /* Complete 24/7 broadcast automation system assembly. */;
        
        attribute channelName : String := "Channel-1";
        attribute targetUptime : UptimeRatio := 0.9999;
        
        part controller : PlayoutAutomation {
            :>> activePlaylist;
        }
        part primaryServer : MediaServer {
            :>> serverId := "MEDIA-PRIMARY";
        }
        part backupServer : BackupServer {
            :>> serverId := "MEDIA-BACKUP";
        }
        part graphics : GraphicsEngine {
            :>> engineId := "GFX-01";
        }
        part router : VideoRouter {
            :>> routerId := "ROUTER-01";
        }
        part masterControl : MasterControl {
            :>> unitId := "MC-01";
        }
        part encoder : TransmissionEncoder {
            :>> encoderId := "ENC-01";
        }
        
        // Schedule ingestion
        connect externalPlaylist :>> controller.scheduleIn.playlist;
        
        // Command distribution
        connect controller.cmdMedia to primaryServer.cmdIn;
        connect controller.cmdBackup to backupServer.cmdIn;
        connect controller.cmdGraphics to graphics.cmdIn;
        connect controller.cmdRouter to router.cmdIn;
        connect controller.cmdMaster to masterControl.cmdIn;
        connect controller.cmdEncoder to encoder.cmdIn;
        
        // Media server video/audio to router
        connect primaryServer.videoOut.video to router.primaryIn.video;
        connect primaryServer.audioOut.audio to router.primaryAudioIn.audio;
        connect backupServer.videoOut.video to router.backupIn.video;
        connect backupServer.audioOut.audio to router.backupAudioIn.audio;
        
        // Graphics engine: takes router output as base, composites, returns to router graphics input
        connect router.videoOut.video to graphics.videoIn.video;
        connect graphics.videoOut.video to router.graphicsIn.video;
        
        // Router output to master control
        connect router.videoOut.video to masterControl.primaryIn.video;
        connect router.audioOut.audio to masterControl.primaryAudioIn.audio;
        // Backup feed direct to master control for failover
        connect backupServer.videoOut.video to masterControl.backupIn.video;
        connect backupServer.audioOut.audio to masterControl.backupAudioIn.audio;
        
        // Master control to encoder
        connect masterControl.videoOut.video to encoder.videoIn.video;
        connect masterControl.audioOut.audio to encoder.audioIn.audio;
        
        // Telemetry aggregation
        connect primaryServer.telemetry.report to controller.telemetry.report;
        connect backupServer.telemetry.report to controller.telemetry.report;
        connect graphics.telemetry.report to controller.telemetry.report;
        connect router.telemetry.report to controller.telemetry.report;
        connect masterControl.telemetry.report to controller.telemetry.report;
        connect encoder.telemetry.report to controller.telemetry.report;
        
        // System-level state machine
        state machine systemOperation {
            entry; then idle;
            
            state idle {
                doc /* No playlist loaded; components in standby. */;
            }
            transition idle_to_standby
                first idle
                accept PlaylistLoaded
                then standby;
            
            state standby {
                doc /* Playlist loaded; events pre-cued; awaiting activation. */;
            }
            transition standby_to_active
                first standby
                accept BroadcastStart
                then active;
            
            state active {
                doc /* On-air broadcasting; frame-accurate event execution. */;
            }
            transition active_to_emergency
                first active
                accept CriticalFault
                then emergency;
            transition active_to_idle
                first active
                accept BroadcastEnd
                then idle;
            
            state emergency {
                doc /* Automated failover procedures engaged. */;
                entry; 
                do automatedFailover;
            }
            transition emergency_to_active
                first emergency
                accept FaultCleared
                then active;
        }
        
        action automatedFailover {
            doc /* Switch to backup server, route backup feed, confirm on-air continuity. */;
            out failoverCommands : Command[0..*];
        }
    }
    
    // ===== Requirements =====
    
    requirement def FrameAccuratePlayout {
        subject : BroadcastSystem;
        doc /* Events shall be triggered at their scheduled time with frame accuracy. */;
        attribute tolerance : DurationValue := 0 [ms];
        require constraint { tolerance <= 0 [ms] }
    }
    
    requirement def ContinuousOperation {
        subject : BroadcastSystem;
        doc /* System shall support 24/7 continuous on-air delivery. */;
        attribute minUptime : UptimeRatio := 0.9999;
        require constraint { subject.targetUptime >= minUptime }
    }
    
    requirement def RedundantMediaPath {
        subject : BroadcastSystem;
        doc /* A backup media server shall be available and synchronized with the primary. */;
        require constraint { subject.backupServer.healthy == true }
    }
    
    requirement def AutomatedFailover {
        subject : MasterControl;
        doc /* On primary signal loss, master control shall switch to backup within failoverLatency. */;
        attribute maxLatency : Latency := 100 [ms];
        require constraint { subject.failoverLatency <= maxLatency }
    }
    
    requirement def MultiStandardDelivery {
        subject : TransmissionEncoder;
        doc /* Encoder shall support all defined delivery standards. */;
        require constraint { subject.delivery in DeliveryStandard }
    }
    
    requirement def ScheduleIngestion {
        subject : PlayoutAutomation;
        doc /* Controller shall ingest a daily playlist and execute all contained events in order. */;
        require constraint { subject.activePlaylist.events->size() > 0 }
    }
    
    requirement def GraphicsOverlay {
        subject : GraphicsEngine;
        doc /* Graphics engine shall composite logos, tickers, and banners onto the video feed. */;
        require constraint { subject.activeLayers->size() >= 0 }
    }
    
    requirement def SystemStateCoverage {
        subject : BroadcastSystem;
        doc /* System shall operate through idle, standby, active, and emergency states. */;
        require constraint { 
            subject.systemOperation.ide != null and
            subject.systemOperation.standby != null and
            subject.systemOperation.active != null and
            subject.systemOperation.emergency != null
        }
    }
    
    requirement def TelemetryMonitoring {
        subject : BroadcastSystem;
        doc /* All components shall report telemetry to the controller for health monitoring. */;
        require constraint { subject.controller.telemetry != null }
    }
    
    // ===== Satisfaction =====
    
    satisfaction frameAccurateSatisfies : FrameAccuratePlayout {
        subject :>> subject = BroadcastSystem;
    }
    
    satisfaction continuousSatisfies : ContinuousOperation {
        subject :>> subject = BroadcastSystem;
    }
    
    satisfaction failoverSatisfies : AutomatedFailover {
        subject :>> subject = BroadcastSystem.masterControl;
    }
    
    satisfaction deliverySatisfies : MultiStandardDelivery {
        subject :>> subject = BroadcastSystem.encoder;
    }
    
    satisfaction scheduleSatisfies : ScheduleIngestion {
        subject :>> subject = BroadcastSystem.controller;
    }
    
    satisfaction graphicsSatisfies : GraphicsOverlay {
        subject :>> subject = BroadcastSystem.graphics;
    }
    
    satisfaction stateSatisfies : SystemStateCoverage {
        subject :>> subject = BroadcastSystem;
    }
    
    satisfaction telemetrySatisfies : TelemetryMonitoring {
        subject :>> subject = BroadcastSystem;
    }
    
    satisfaction redundancySatisfies : RedundantMediaPath {
        subject :>> subject = BroadcastSystem;
    }
}
