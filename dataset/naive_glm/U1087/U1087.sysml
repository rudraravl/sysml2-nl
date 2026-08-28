package HorizonScanningSystem {

    import ScalarValues::*;
    import ISQ::*;

    // ---- Value Types with Units ----
    value type Distance_km > Real { unit 'km'; }
    value type Speed_kn > Real { unit 'kn'; }
    value type Bearing_deg > Real { unit 'deg'; min 0; max 360; }
    value type Elevation_deg > Real { unit 'deg'; min -90; max 90; }
    value type Confidence > Real { min 0.0; max 1.0; }
    value type ThreatScore > Integer { min 0; max 100; }
    value type Time_ms > Real { unit 'ms'; }
    value type Frequency_GHz > Real { unit 'GHz'; }
    value type PixelCount > Integer { unit 'pixel'; }
    value type Temperature_K > Real { unit 'K'; }
    value type SNR_dB > Real { unit 'dB'; }
    value type RCS_m2 > Real { unit 'm^2'; }

    // ---- Enumerations ----
    enum SystemState { standby; initializing; calibrating; activeScanning; faulted; }
    enum SensorMode { idle; sweeping; tracking; cued; }
    enum TargetClass { unknown; vessel; aircraft; missile; drone; debris; wildlife; }
    enum ThreatLevel { benign; low; medium; high; critical; }

    // ---- Signal Items ----
    item def StartSignal;
    item def CalibrationRequired;
    item def CalibrationComplete;
    item def FaultSignal;
    item def ResetSignal;

    // ---- Data Items ----
    item def RadarReturn {
        attribute range : Distance_km;
        attribute bearing : Bearing_deg;
        attribute elevation : Elevation_deg;
        attribute radialSpeed : Speed_kn;
        attribute snr : SNR_dB;
        attribute timestamp : Time_ms;
    }

    item def EOImage {
        attribute pixelCount : PixelCount;
        attribute bearing : Bearing_deg;
        attribute elevation : Elevation_deg;
        attribute timestamp : Time_ms;
    }

    item def IRImage {
        attribute pixelCount : PixelCount;
        attribute bearing : Bearing_deg;
        attribute elevation : Elevation_deg;
        attribute peakTemperature : Temperature_K;
        attribute timestamp : Time_ms;
    }

    item def ScanDirective {
        attribute sectorStart : Bearing_deg;
        attribute sectorEnd : Bearing_deg;
        attribute elevationFloor : Elevation_deg;
        attribute elevationCeiling : Elevation_deg;
        attribute dwellTime : Time_ms;
        attribute priority : Integer;
    }

    item def FusedTrack {
        attribute trackId : String;
        attribute range : Distance_km;
        attribute bearing : Bearing_deg;
        attribute elevation : Elevation_deg;
        attribute speed : Speed_kn;
        attribute heading : Bearing_deg;
        attribute confidence : Confidence;
        attribute classification : TargetClass := TargetClass::unknown;
        attribute threatLevel : ThreatLevel := ThreatLevel::benign;
        attribute lastUpdate : Time_ms;
    }

    item def ThreatSignature {
        attribute signatureId : String;
        attribute targetClass : TargetClass;
        attribute radarCrossSection : RCS_m2;
        attribute thermalSignature : Temperature_K;
        attribute typicalSpeed : Speed_kn;
        attribute baselineThreat : ThreatLevel;
    }

    item def OperatorAlert {
        attribute alertId : String;
        attribute trackId : String;
        attribute threatLevel : ThreatLevel;
        attribute issuedAt : Time_ms;
    }

    // ---- Port Definitions ----
    port def RadarOutPort { out radarReturn : RadarReturn; }
    port def EOOutPort { out eoImage : EOImage; }
    port def IROutPort { out irImage : IRImage; }
    port def ScanCommandPort { out directive : ScanDirective; in ack : Boolean; }
    port def SensorDataInPort { in radarReturn : RadarReturn; in eoImage : EOImage; in irImage : IRImage; }
    port def TrackOutPort { out track : FusedTrack; }
    port def TrackInPort { in track : FusedTrack; }
    port def AlertOutPort { out alert : OperatorAlert; }
    port def AlertInPort { in alert : OperatorAlert; }
    port def ThreatDBOutPort { out signature : ThreatSignature; }
    port def ThreatDBInPort { in signature : ThreatSignature; }

    // ---- Radar Sensor ----
    part def RadarSensor {
        attribute maxRange : Distance_km := 75;
        attribute frequency : Frequency_GHz := 9.5;
        attribute beamWidth : Bearing_deg := 3.0;
        attribute mode : SensorMode := SensorMode::idle;
        attribute detectionThreshold : SNR_dB := 12.0;

        port radarOut : RadarOutPort;
        port scanCmd : ScanCommandPort;

        action def emitReturn {
            out return : RadarReturn;
        }

        action def acknowledgeDirective {
            in directive : ScanDirective;
            out ack : Boolean;
        }

        state machine radarBehavior {
            entry; then idle;
            state idle;
            transition t1
                first idle
                accept ScanDirective via scanCmd
                then sweeping;
            state sweeping {
                do emitReturn;
            }
            transition t2
                first sweeping
                accept ScanDirective via scanCmd
                if scanCmd.directive.priority > 1
                then tracking;
            state tracking {
                do emitReturn;
            }
            transition t3
                first tracking
                accept ScanDirective via scanCmd
                then sweeping;
            transition t4
                first sweeping
                accept ScanDirective via scanCmd
                if scanCmd.directive.priority == 0
                then idle;
        }
    }

    // ---- Electro-Optical Sensor ----
    part def EOSensor {
        attribute fieldOfView : Bearing_deg := 6.0;
        attribute zoomLevel : Real := 30.0;
        attribute mode : SensorMode := SensorMode::idle;
        attribute resolution : PixelCount := 4096;

        port eoOut : EOOutPort;
        port scanCmd : ScanCommandPort;

        action def captureFrame {
            out frame : EOImage;
        }

        state machine eoBehavior {
            entry; then idle;
            state idle;
            transition t1
                first idle
                accept ScanDirective via scanCmd
                then sweeping;
            state sweeping {
                do captureFrame;
            }
            transition t2
                first sweeping
                accept ScanDirective via scanCmd
                if scanCmd.directive.priority > 1
                then cued;
            state cued {
                do captureFrame;
            }
            transition t3
                first cued
                accept ScanDirective via scanCmd
                then sweeping;
        }
    }

    // ---- Infrared Sensor ----
    part def IRSensor {
        attribute fieldOfView : Bearing_deg := 8.0;
        attribute sensitivity : Temperature_K := 290.0;
        attribute mode : SensorMode := SensorMode::idle;
        attribute resolution : PixelCount := 2048;

        port irOut : IROutPort;
        port scanCmd : ScanCommandPort;

        action def captureThermal {
            out frame : IRImage;
        }

        state machine irBehavior {
            entry; then idle;
            state idle;
            transition t1
                first idle
                accept ScanDirective via scanCmd
                then sweeping;
            state sweeping {
                do captureThermal;
            }
            transition t2
                first sweeping
                accept ScanDirective via scanCmd
                if scanCmd.directive.priority > 1
                then cued;
            state cued {
                do captureThermal;
            }
            transition t3
                first cued
                accept ScanDirective via scanCmd
                then sweeping;
        }
    }

    // ---- Scan Coordinator ----
    part def ScanCoordinator {
        attribute cyclePeriod : Time_ms := 4000;
        attribute sectorCount : Integer := 8;
        attribute currentSector : Integer := 1;
        attribute sweepRate : Bearing_deg := 60.0;

        port radarCmd : ScanCommandPort;
        port eoCmd : ScanCommandPort;
        port irCmd : ScanCommandPort;

        action def generateDirective {
            in sectorIndex : Integer;
            out directive : ScanDirective;
        }

        action def advanceSector {
            inout sector : Integer;
        }

        state machine coordinatorBehavior {
            entry; then orchestrating;
            state orchestrating {
                do generateDirective;
                do advanceSector;
            }
            transition t1
                first orchestrating
                accept @cyclePeriod
                then orchestrating;
        }
    }

    // ---- Fusion Processor ----
    part def FusionProcessor {
        attribute processingBudget : Time_ms := 800;
        attribute fusionConfidenceThreshold : Confidence := 0.7;
        attribute highThreatThreshold : ThreatScore := 75;

        port sensorIn : SensorDataInPort;
        port trackOut : TrackOutPort;
        port alertOut : AlertOutPort;
        port dbIn : ThreatDBInPort;

        attribute currentTracks : FusedTrack[0..*];

        action def fuseData {
            in radar : RadarReturn;
            in eo : EOImage;
            in ir : IRImage;
            out track : FusedTrack;
        }

        action def classifyTrack {
            in track : FusedTrack;
            in signature : ThreatSignature;
            out classified : FusedTrack;
        }

        action def evaluateThreat {
            in track : FusedTrack;
            out scored : FusedTrack;
        }

        action def issueAlert {
            in track : FusedTrack;
            out alert : OperatorAlert;
        }

        state machine fusionBehavior {
            entry; then receiving;
            state receiving;
            transition t_radar
                first receiving
                accept RadarReturn via sensorIn
                then fusing;
            transition t_eo
                first receiving
                accept EOImage via sensorIn
                then fusing;
            transition t_ir
                first receiving
                accept IRImage via sensorIn
                then fusing;
            state fusing {
                do fuseData;
            }
            transition t_fuse
                first fusing
                then classifying;
            state classifying {
                do classifyTrack;
            }
            transition t_class
                first classifying
                then evaluating;
            state evaluating {
                do evaluateThreat;
            }
            transition t_eval_low
                first evaluating
                if currentTracks.threatLevel == ThreatLevel::high
                then alerting;
            transition t_eval_high
                first evaluating
                if currentTracks.threatLevel == ThreatLevel::critical
                then alerting;
            transition t_eval_normal
                first evaluating
                if currentTracks.threatLevel != ThreatLevel::high and currentTracks.threatLevel != ThreatLevel::critical
                then publishing;
            state alerting {
                do issueAlert;
            }
            transition t_alert
                first alerting
                then publishing;
            state publishing {
                // publish fused track to console
            }
            transition t_pub
                first publishing
                then receiving;
        }
    }

    // ---- Threat Database ----
    part def ThreatDatabase {
        attribute updateInterval : Time_ms := 3600000;
        attribute signatureCount : Integer := 0;
        attribute signatures : ThreatSignature[0..*];

        port dbOut : ThreatDBOutPort;

        action def refreshSignatures {
            out updated : ThreatSignature[0..*];
        }

        action def querySignature {
            in classHint : TargetClass;
            out signature : ThreatSignature;
        }

        state machine dbBehavior {
            entry; then available;
            state available {
                do refreshSignatures;
            }
            transition t1
                first available
                accept @updateInterval
                then available;
        }
    }

    // ---- Operator Console ----
    part def OperatorConsole {
        attribute displayRefreshRate : Time_ms := 100;
        attribute activeAlerts : OperatorAlert[0..*];
        attribute displayedTracks : FusedTrack[0..*];

        port trackIn : TrackInPort;
        port alertIn : AlertInPort;

        action def renderTrack {
            in track : FusedTrack;
        }

        action def raiseAlert {
            in alert : OperatorAlert;
        }

        action def acknowledgeAlert {
            in alertId : String;
        }

        state machine consoleBehavior {
            entry; then monitoring;
            state monitoring;
            transition t_track
                first monitoring
                accept FusedTrack via trackIn
                do renderTrack
                then monitoring;
            transition t_alert
                first monitoring
                accept OperatorAlert via alertIn
                do raiseAlert
                then monitoring;
        }
    }

    // ---- Top-Level Horizon Scanner System ----
    part def HorizonScanner {
        attribute systemState : SystemState := SystemState::standby;
        attribute maxResponseTime : Time_ms := 1000;
        attribute operationalUptime : Time_ms := 0;

        part radar : RadarSensor;
        part eo : EOSensor;
        part ir : IRSensor;
        part coordinator : ScanCoordinator;
        part fusion : FusionProcessor;
        part threatDB : ThreatDatabase;
        part console : OperatorConsole;

        // Connections: coordinator commands to sensors
        connection coordinator.radarCmd to radar.scanCmd;
        connection coordinator.eoCmd to eo.scanCmd;
        connection coordinator.irCmd to ir.scanCmd;

        // Connections: sensor outputs to fusion processor
        connection radar.radarOut to fusion.sensorIn;
        connection eo.eoOut to fusion.sensorIn;
        connection ir.irOut to fusion.sensorIn;

        // Connection: threat database to fusion processor
        connection threatDB.dbOut to fusion.dbIn;

        // Connections: fusion outputs to operator console
        connection fusion.trackOut to console.trackIn;
        connection fusion.alertOut to console.alertIn;

        state machine systemBehavior {
            entry; then standby;
            state standby;
            transition t_standby_init
                first standby
                accept StartSignal
                then initializing;
            state initializing {
                do coordinator.generateDirective;
            }
            transition t_init_cal
                first initializing
                accept CalibrationRequired
                then calibrating;
            state calibrating {
                do radar.emitReturn;
                do eo.captureFrame;
                do ir.captureThermal;
            }
            transition t_cal_active
                first calibrating
                accept CalibrationComplete
                then activeScanning;
            state activeScanning {
                do coordinator.generateDirective;
            }
            transition t_active_fault
                first activeScanning
                accept FaultSignal
                then faulted;
            state faulted;
            transition t_fault_standby
                first faulted
                accept ResetSignal
                then standby;
            transition t_active_standby
                first activeScanning
                accept ResetSignal
                then standby;
        }
    }

    // ---- Requirements ----
    requirement def DetectionRangeRequirement {
        doc "The radar sensor shall detect objects at ranges up to 75 kilometers.";
        subject scanner : HorizonScanner;
        constraint { scanner.radar.maxRange >= 75 [km]; }
    }

    requirement def ResponseTimeRequirement {
        doc "The end-to-end process from initial sensor detection to threat evaluation shall complete in under one second.";
        subject scanner : HorizonScanner;
        constraint { scanner.maxResponseTime <= 1000 [ms]; }
    }

    requirement def FusionRequirement {
        doc "The Fusion Processor shall combine radar, electro-optical, and infrared data into a single unified FusedTrack.";
        subject proc : FusionProcessor;
        constraint { proc.sensorIn.radarReturn.isDefined and proc.sensorIn.eoImage.isDefined and proc.sensorIn.irImage.isDefined; }
    }

    requirement def ThreatAlertRequirement {
        doc "When a high-priority or critical threat is identified, the system shall automatically issue an alert to the Operator Console.";
        subject scanner : HorizonScanner;
        constraint { scanner.console.alertIn.alert.threatLevel == ThreatLevel::high or scanner.console.alertIn.alert.threatLevel == ThreatLevel::critical; }
    }

    requirement def StateCoverageRequirement {
        doc "The system shall operate in standby, initialization, calibration, and active scanning states.";
        subject scanner : HorizonScanner;
        constraint { scanner.systemState in { SystemState::standby; SystemState::initializing; SystemState::calibrating; SystemState::activeScanning; }; }
    }

    requirement def ContinuousScanRequirement {
        doc "The Scan Coordinator shall direct all three sensors to sweep designated horizon sectors in a continuous cycle.";
        subject coord : ScanCoordinator;
        constraint { coord.cyclePeriod > 0 [ms] and coord.sectorCount > 0; }
    }

    requirement def ThreatDatabaseRequirement {
        doc "The Threat Database shall be regularly updated with known signatures for classification comparison.";
        subject db : ThreatDatabase;
        constraint { db.updateInterval > 0 [ms]; }
    }

    requirement def MultiSensorRequirement {
        doc "The system shall include three complementary sensors: long-range radar, electro-optical, and infrared.";
        subject scanner : HorizonScanner;
        constraint { scanner.radar.isDefined and scanner.eo.isDefined and scanner.ir.isDefined; }
    }

    // ---- Requirement Satisfaction ----
    satisfaction DetectionRangeRequirement by HorizonScanner;
    satisfaction ResponseTimeRequirement by HorizonScanner;
    satisfaction FusionRequirement by FusionProcessor;
    satisfaction ThreatAlertRequirement by HorizonScanner;
    satisfaction StateCoverageRequirement by HorizonScanner;
    satisfaction ContinuousScanRequirement by ScanCoordinator;
    satisfaction ThreatDatabaseRequirement by ThreatDatabase;
    satisfaction MultiSensorRequirement by HorizonScanner;

}
