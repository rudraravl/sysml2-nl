package LORROS {
    import ISQ::*;
    import ScalarValues::*;
    import Time::*;

    // ---- Value Types ----
    value type def Distance :> Real { unit 'm'; }
    value type def Angle :> Real { unit 'deg'; }
    value type def AngularRate :> Real { unit 'deg/s'; }
    value type def Power :> Real { unit 'W'; }
    value type def Energy :> Real { unit 'Wh'; }
    value type def Voltage :> Real { unit 'V'; }
    value type def Temperature :> Real { unit 'K'; }
    value type def Frequency :> Real { unit 'Hz'; }
    value type def DataRate :> Real { unit 'bit/s'; }
    value type def Speed :> Real { unit 'm/s'; }
    value type def Confidence :> Real { min 0.0; max 1.0; }

    // ---- Enumerations ----
    enum def TargetClass {
        literal unknown;
        literal personnel;
        literal lightVehicle;
        literal armoredVehicle;
        literal aircraft;
        literal watercraft;
        literal structure;
    }

    enum def ThreatLevel {
        literal none;
        literal low;
        literal medium;
        literal high;
        literal critical;
    }

    enum def MissionPhase {
        literal idle;
        literal searching;
        literal tracking;
        literal identifying;
        literal designating;
        literal reporting;
    }

    enum def PowerSource {
        literal battery;
        literal solar;
        literal hybrid;
    }

    enum def LaserMode {
        literal off;
        literal rangefinder;
        literal designator;
    }

    // ---- Item Types ----
    item def GeoCoordinate {
        attribute latitude : Angle;
        attribute longitude : Angle;
        attribute altitude : Distance;
    }

    item def TargetTrack {
        attribute trackId : Integer;
        attribute position : GeoCoordinate;
        attribute velocity : Speed;
        attribute heading : Angle;
        attribute thermalSignature : Temperature;
        attribute classification : TargetClass;
        attribute threat : ThreatLevel;
        attribute confidence : Confidence;
        attribute range : Distance;
    }

    item def ImageFrame {
        attribute timestamp : TimeInstant;
        attribute azimuth : Angle;
        attribute elevation : Angle;
        attribute resolution : Integer;
        attribute pixels : Integer;
    }

    item def ThermalFrame {
        attribute timestamp : TimeInstant;
        attribute azimuth : Angle;
        attribute elevation : Angle;
        attribute minTemperature : Temperature;
        attribute maxTemperature : Temperature;
    }

    item def RangeMeasurement {
        attribute timestamp : TimeInstant;
        attribute range : Distance;
        attribute azimuth : Angle;
        attribute elevation : Angle;
    }

    item def LaserPulse {
        attribute mode : LaserMode;
        attribute code : Integer;
        attribute wavelength : Distance;
        attribute energy : Energy;
    }

    item def TargetReport {
        attribute track : TargetTrack;
        attribute designating : Boolean;
        attribute timestamp : TimeInstant;
    }

    item def CommandMessage {
        attribute commandId : Integer;
        attribute searchAreaCenter : GeoCoordinate;
        attribute searchRadius : Distance;
        attribute engagementAuthorized : Boolean;
        attribute rulesOfEngagement : String;
    }

    item def TelemetryMessage {
        attribute systemPosition : GeoCoordinate;
        attribute powerSource : PowerSource;
        attribute batteryLevel : Energy;
        attribute phase : MissionPhase;
        attribute timestamp : TimeInstant;
    }

    item def PowerFlow {
        attribute voltage : Voltage;
        attribute current : Real;
        attribute source : PowerSource;
    }

    // ---- Port Definitions ----
    port def ImageOut { out image : ImageFrame; }
    port def ThermalOut { out thermal : ThermalFrame; }
    port def RangeOut { out range : RangeMeasurement; }
    port def LaserOut { out pulse : LaserPulse; }
    port def GimbalCommand { in azimuth : Angle; in elevation : Angle; in rate : AngularRate; }
    port def GimbalFeedback { out azimuth : Angle; out elevation : Angle; out stabilized : Boolean; }
    port def TrackOut { out track : TargetTrack; }
    port def CommandIn { in command : CommandMessage; }
    port def TelemetryOut { out telemetry : TelemetryMessage; }
    port def ReportOut { out report : TargetReport; }
    port def GeoOut { out coordinate : GeoCoordinate; }
    port def PowerOut { out power : PowerFlow; }
    port def PowerIn { in power : PowerFlow; }

    // ---- Part Definitions ----

    part def EOCamera {
        attribute focalLength : Distance = 0.4 [m];
        attribute sensorResolution : Integer = 4096;
        attribute fieldOfView : Angle = 2.0 [deg];
        port imagePort : ImageOut;
        attribute powerDraw : Power = 25.0 [W];

        action def CaptureFrame {
            in azimuth : Angle;
            in elevation : Angle;
            out frame : ImageFrame;
        }

        perform action capture : CaptureFrame;
    }

    part def IRSensor {
        attribute detectorType : String = "cooledMWIR";
        attribute fieldOfView : Angle = 4.0 [deg];
        attribute minResolvableTemp : Temperature = 0.05 [K];
        port thermalPort : ThermalOut;
        attribute powerDraw : Power = 40.0 [W];

        action def CaptureThermal {
            in azimuth : Angle;
            in elevation : Angle;
            out frame : ThermalFrame;
        }

        perform action capture : CaptureThermal;
    }

    part def LaserUnit {
        attribute maxRange : Distance = 20000 [m];
        attribute wavelength : Distance = 1.064e-6 [m];
        attribute designatorCode : Integer = 1688;
        attribute mode : LaserMode = LaserMode::off;
        port laserPort : LaserOut;
        port rangePort : RangeOut;
        attribute powerDraw : Power = 30.0 [W];

        action def FireLaser {
            in targetAzimuth : Angle;
            in targetElevation : Angle;
            in requestedMode : LaserMode;
            out pulse : LaserPulse;
            out range : RangeMeasurement;
        }

        perform action fire : FireLaser;
    }

    part def Gimbal {
        attribute azimuthRange : Angle = 360 [deg];
        attribute elevationRangeMin : Angle = -90 [deg];
        attribute elevationRangeMax : Angle = 90 [deg];
        attribute stabilizationAccuracy : Angle = 5e-6 [deg];
        attribute maxSlewRate : AngularRate = 60 [deg/s];
        port commandPort : GimbalCommand;
        port feedbackPort : GimbalFeedback;
        attribute powerDraw : Power = 20.0 [W];

        action def Stabilize {
            in commandedAzimuth : Angle;
            in commandedElevation : Angle;
            out actualAzimuth : Angle;
            out actualElevation : Angle;
            out stable : Boolean;
        }

        perform action stabilize : Stabilize;
    }

    part def SensorSuite {
        part eoCamera : EOCamera;
        part irSensor : IRSensor;
        part laserUnit : LaserUnit;
        part gimbal : Gimbal;

        port imagePort : ImageOut;
        port thermalPort : ThermalOut;
        port rangePort : RangeOut;
        port laserPort : LaserOut;
        port commandPort : GimbalCommand;
        port feedbackPort : GimbalFeedback;

        connection eoImageConnection connect eoCamera.imagePort to imagePort;
        connection irThermalConnection connect irSensor.thermalPort to thermalPort;
        connection laserRangeConnection connect laserUnit.rangePort to rangePort;
        connection laserPulseConnection connect laserUnit.laserPort to laserPort;
        connection gimbalCommandConnection connect commandPort to gimbal.commandPort;
        connection gimbalFeedbackConnection connect gimbal.feedbackPort to feedbackPort;
    }

    part def NavigationUnit {
        attribute positionAccuracy : Distance = 2.0 [m];
        attribute updateRate : Frequency = 10 [Hz];
        port geoPort : GeoOut;
        attribute powerDraw : Power = 5.0 [W];

        action def ComputePosition {
            out coordinate : GeoCoordinate;
        }

        perform action compute : ComputePosition;
    }

    part def TargetProcessingUnit {
        attribute fusionLatency : Time = 0.05 [s];
        attribute classificationThreshold : Confidence = 0.85;
        attribute threatThreshold : ThreatLevel = ThreatLevel::high;
        port imageIn : ImageOut;
        port thermalIn : ThermalOut;
        port rangeIn : RangeOut;
        port geoIn : GeoOut;
        port gimbalCommandOut : GimbalCommand;
        port gimbalFeedbackIn : GimbalFeedback;
        port laserCommandOut : LaserMode;
        port trackOut : TrackOut;
        attribute powerDraw : Power = 60.0 [W];

        attribute currentTrack : TargetTrack;
        attribute trackList : TargetTrack[0..*];

        action def FuseSensorData {
            in image : ImageFrame;
            in thermal : ThermalFrame;
            in range : RangeMeasurement;
            in ownPosition : GeoCoordinate;
            out track : TargetTrack;
        }

        action def ClassifyTarget {
            in track : TargetTrack;
            out classified : TargetTrack;
        }

        action def AssessThreat {
            in track : TargetTrack;
            out assessed : TargetTrack;
        }

        action def PrioritizeTargets {
            in tracks : TargetTrack[0..*];
            out prioritized : TargetTrack[0..*];
        }

        action def DecideEngagement {
            in track : TargetTrack;
            in engagementAuthorized : Boolean;
            out designate : Boolean;
        }

        perform action fuse : FuseSensorData;
        perform action classify : ClassifyTarget;
        perform action assess : AssessThreat;
        perform action prioritize : PrioritizeTargets;
        perform action decide : DecideEngagement;
    }

    part def CommunicationsSubsystem {
        attribute transmitFrequency : Frequency = 2.4e9 [Hz];
        attribute maxDataRate : DataRate = 10e6 [bit/s];
        attribute maxRange : Distance = 50000 [m];
        attribute encryptionEnabled : Boolean = true;
        port commandPort : CommandIn;
        port telemetryPort : TelemetryOut;
        port reportPort : ReportOut;
        attribute powerDraw : Power = 15.0 [W];

        action def Transmit {
            in telemetry : TelemetryMessage;
            in report : TargetReport;
        }

        action def Receive {
            out command : CommandMessage;
        }

        perform action transmit : Transmit;
        perform action receive : Receive;
    }

    part def PowerManagementUnit {
        attribute batteryCapacity : Energy = 500 [Wh];
        attribute batteryLevel : Energy = 500 [Wh];
        attribute solarPanelOutput : Power = 80 [W];
        attribute activeSource : PowerSource = PowerSource::battery;
        port powerPort : PowerOut;
        attribute powerDraw : Power = 2.0 [W];

        action def ManagePower {
            in load : Power;
            out supply : PowerFlow;
        }

        action def ChargeFromSolar {
            out chargeRate : Power;
        }

        perform action manage : ManagePower;
        perform action charge : ChargeFromSolar;
    }

    part def CommandCenter {
        port commandOut : CommandIn;
        port telemetryIn : TelemetryOut;
        port reportIn : ReportOut;

        action def IssueCommand {
            out command : CommandMessage;
        }

        action def ReceiveReport {
            in report : TargetReport;
            in telemetry : TelemetryMessage;
        }

        perform action issue : IssueCommand;
        perform action receive : ReceiveReport;
    }

    // ---- Top-Level System ----
    part def LORROS {
        part sensorSuite : SensorSuite;
        part processingUnit : TargetProcessingUnit;
        part comms : CommunicationsSubsystem;
        part navigation : NavigationUnit;
        part power : PowerManagementUnit;

        port externalCommand : CommandIn;
        port externalTelemetry : TelemetryOut;
        port externalReport : ReportOut;
        port externalLaser : LaserOut;

        attribute missionPhase : MissionPhase = MissionPhase::idle;
        attribute engagementAuthorized : Boolean = false;
        attribute searchAreaCenter : GeoCoordinate;
        attribute searchRadius : Distance = 5000 [m];

        // Power distribution
        connection powerToSensorSuite connect power.powerPort to sensorSuite.gimbal.commandPort;
        connection powerToProcessing connect power.powerPort to processingUnit.geoIn;
        connection powerToComms connect power.powerPort to comms.commandPort;
        connection powerToNav connect power.powerPort to navigation.geoPort;

        // Sensor data to processing unit
        connection eoToProcessing connect sensorSuite.imagePort to processingUnit.imageIn;
        connection irToProcessing connect sensorSuite.thermalPort to processingUnit.thermalIn;
        connection rangeToProcessing connect sensorSuite.rangePort to processingUnit.rangeIn;
        connection navToProcessing connect navigation.geoPort to processingUnit.geoIn;

        // Gimbal control loop
        connection gimbalCommandToSuite connect processingUnit.gimbalCommandOut to sensorSuite.commandPort;
        connection gimbalFeedbackToProcessing connect sensorSuite.feedbackPort to processingUnit.gimbalFeedbackIn;

        // Laser command
        connection laserCommandToSuite connect processingUnit.laserCommandOut to sensorSuite.laserPort;

        // Track output to comms
        connection trackToComms connect processingUnit.trackOut to comms.reportPort;

        // External interfaces
        connection commandToComms connect externalCommand to comms.commandPort;
        connection telemetryFromComms connect comms.telemetryPort to externalTelemetry;
        connection reportFromComms connect comms.reportPort to externalReport;
        connection laserFromSuite connect sensorSuite.laserPort to externalLaser;

        // ---- Mission State Machine ----
        state def MissionStateMachine {
            entry action initialize {
                missionPhase := MissionPhase::idle;
            }

            state idle {
                entry action awaitCommand {
                    // Wait for command from command center
                }
                transition awaitCommandTransition
                    first idle
                    accept CommandMessage
                    then searching;
            }

            state searching {
                entry action beginSearchPattern {
                    missionPhase := MissionPhase::searching;
                    // Command gimbal to sweep search area
                }
                do action sweepArea {
                    // Perform raster scan of designated area
                }
                transition targetDetected
                    first searching
                    accept TargetTrack
                    then tracking;
            }

            state tracking {
                entry action lockOn {
                    missionPhase := MissionPhase::tracking;
                    // Maintain gimbal pointing at target
                }
                do action maintainTrack {
                    // Continuously update track from fused sensor data
                }
                transition trackStable
                    first tracking
                    when processingUnit.currentTrack.confidence >= processingUnit.classificationThreshold
                    then identifying;
                transition targetLost
                    first tracking
                    when processingUnit.currentTrack.confidence < 0.3
                    then searching;
            }

            state identifying {
                entry action classify {
                    missionPhase := MissionPhase::identifying;
                    // Run classification and threat assessment
                }
                do action assess {
                    // Fuse EO/IR/range data to classify target
                }
                transition identificationComplete
                    first identifying
                    when processingUnit.currentTrack.classification != TargetClass::unknown
                    then deciding;
            }

            state deciding {
                entry action evaluateRules {
                    missionPhase := MissionPhase::reporting;
                    // Decide whether to report or designate
                }
                do action decide {
                    // Apply rules of engagement
                }
                transition designateTarget
                    first deciding
                    when engagementAuthorized and processingUnit.currentTrack.threat >= ThreatLevel::high
                    then designating;
                transition reportOnly
                    first deciding
                    when not (engagementAuthorized and processingUnit.currentTrack.threat >= ThreatLevel::high)
                    then reporting;
            }

            state designating {
                entry action activateDesignator {
                    missionPhase := MissionPhase::designating;
                    // Activate laser in designator mode
                }
                do action paintTarget {
                    // Continuously illuminate target with coded laser
                }
                transition designationComplete
                    first designating
                    accept TargetReport
                    then reporting;
            }

            state reporting {
                entry action sendReport {
                    missionPhase := MissionPhase::reporting;
                    // Transmit target report and telemetry
                }
                do action transmit {
                    // Send report to command center
                }
                transition reportSent
                    first reporting
                    accept TargetReport
                    then searching;
                transition missionComplete
                    first reporting
                    accept CommandMessage
                    then idle;
            }
        }

        perform missionStateMachine : MissionStateMachine;
    }

    // ---- Requirements ----
    requirement def LongRangeCapability {
        subject lorros : LORROS;
        attribute requiredRange : Distance = 20000 [m];
        requirement {
            subject lorros;
            objective {
                doc /* The system shall detect, track, and identify targets at ranges up to 20 km. */
            }
        }
    }

    requirement def EnduranceCapability {
        subject lorros : LORROS;
        attribute requiredEndurance : Time = 72 [h];
        requirement {
            subject lorros;
            objective {
                doc /* The system shall operate autonomously for at least 72 hours on battery and solar power. */
            }
        }
    }

    requirement def StabilizationAccuracy {
        subject gimbal : Gimbal;
        attribute requiredAccuracy : Angle = 1e-5 [deg];
        requirement {
            subject gimbal;
            objective {
                doc /* The gimbal shall maintain pointing accuracy of 10 micro-degrees under platform vibration. */
            }
        }
    }

    requirement def AutonomousTargeting {
        subject lorros : LORROS;
        requirement {
            subject lorros;
            objective {
                doc /* The system shall autonomously detect, track, classify, and prioritize targets without operator intervention. */
            }
        }
    }

    requirement def SecureCommunications {
        subject comms : CommunicationsSubsystem;
        attribute requiredRange : Distance = 50000 [m];
        requirement {
            subject comms;
            objective {
                doc /* The communications subsystem shall transmit encrypted target data and telemetry up to 50 km. */
            }
        }
    }

    requirement def LaserDesignation {
        subject laser : LaserUnit;
        attribute requiredDesignationRange : Distance = 15000 [m];
        requirement {
            subject laser;
            objective {
                doc /* The laser unit shall designate targets with a coded beam at ranges up to 15 km for precision-guided munitions. */
            }
        }
    }

    requirement def NavigationAccuracy {
        subject nav : NavigationUnit;
        attribute requiredAccuracy : Distance = 5.0 [m];
        requirement {
            subject nav;
            objective {
                doc /* The navigation unit shall provide system position with accuracy of 5 m or better. */
            }
        }
    }

    requirement def SensorFusion {
        subject tpu : TargetProcessingUnit;
        requirement {
            subject tpu;
            objective {
                doc /* The target processing unit shall fuse EO, IR, and laser range data to produce a single target track with classification and threat assessment. */
            }
        }
    }

    requirement def RulesOfEngagement {
        subject lorros : LORROS;
        requirement {
            subject lorros;
            objective {
                doc /* The system shall only designate targets when engagement is authorized and target threat level is high or above. */
            }
        }
    }

    // ---- Verification ----
    verification def VerifyLongRange {
        subject lorros : LORROS;
        objective {
            doc /* Test detection and tracking at 20 km range. */
        }
    }

    verification def VerifyEndurance {
        subject lorros : LORROS;
        objective {
            doc /* Test continuous operation for 72 hours. */
        }
    }

    verification def VerifyStabilization {
        subject gimbal : Gimbal;
        objective {
            doc /* Measure pointing stability under vibration. */
        }
    }

    verification def VerifySecureComms {
        subject comms : CommunicationsSubsystem;
        objective {
            doc /* Test encrypted link at 50 km. */
        }
    }

    // ---- System Instantiation ----
    part lorrosInstance : LORROS {
        // Satisfies requirements
        satisfy LongRangeCapability;
        satisfy EnduranceCapability;
        satisfy AutonomousTargeting;
        satisfy RulesOfEngagement;
    }

    part commandCenterInstance : CommandCenter;

    connection lorrosToCommandCenterCommand connect commandCenterInstance.commandOut to lorrosInstance.externalCommand;
    connection commandCenterToLorrosTelemetry connect lorrosInstance.externalTelemetry to commandCenterInstance.telemetryIn;
    connection commandCenterToLorrosReport connect lorrosInstance.externalReport to commandCenterInstance.reportIn;
}
