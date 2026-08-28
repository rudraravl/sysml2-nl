package SecuritySystem {
    import ISQ::*;
    import ScalarValues::*;

    // ---------- Value Types ----------
    def def LengthUnit = mm;
    value def Length :> Real { unit = "m"; }
    value def Duration :> Real { unit = "s"; }
    value def Frequency :> Real { unit = "Hz"; }
    value def Probability :> Real { unit = "1"; }
    value def Voltage :> Real { unit = "V"; }
    value def Current :> Real { unit = "A"; }
    value def Decibel :> Real { unit = "dB"; }

    // ---------- Enumerations ----------
    enum ThreatLevel { minor, serious, critical }
    enum SystemMode { disarmed, armed, monitoring, alert }
    enum SensorState { idle, triggered, fault }
    enum CameraMode { idle, recording, streaming }
    enum LockState { unlocked, locked }
    enum AlertChannel { owner, securityCompany, authorities }

    // ---------- Item Types ----------
    item def SensorReading {
        attribute sensorId : String;
        attribute state : SensorState;
        attribute timestamp : String;
    }
    item def VideoFeed {
        attribute cameraId : String;
        attribute resolution : String;
        attribute frameRate : Frequency;
        attribute timestamp : String;
    }
    item def ThreatAssessment {
        attribute level : ThreatLevel;
        attribute confidence : Probability;
        attribute sourceSensor : String;
        attribute sourceCamera : String;
        attribute timestamp : String;
    }
    item def AlertNotification {
        attribute recipient : AlertChannel;
        attribute message : String;
        attribute level : ThreatLevel;
        attribute timestamp : String;
    }
    item def IncidentLog {
        attribute incidentId : String;
        attribute level : ThreatLevel;
        attribute description : String;
        attribute timestamp : String;
    }

    // ---------- Port Definitions ----------
    port def SensorPort {
        out reading : SensorReading;
    }
    port def VideoPort {
        out feed : VideoFeed;
    }
    port def CommandPort {
        in command : String;
    }
    port def AlertPort {
        out notification : AlertNotification;
    }
    port def ControlPanelPort {
        in userCommand : String;
        out status : SystemMode;
    }
    port def LockControlPort {
        in lockCommand : LockState;
    }
    port def SirenControlPort {
        in activate : Boolean;
    }

    // ---------- Interfaces ----------
    interface def SensorToController {
        end supplier : SensorPort;
        end consumer : SensorPort;
    }
    interface def VideoToController {
        end supplier : VideoPort;
        end consumer : VideoPort;
    }
    interface def ControllerToSiren {
        end supplier : SirenControlPort;
        end consumer : SirenControlPort;
    }
    interface def ControllerToLock {
        end supplier : LockControlPort;
        end consumer : LockControlPort;
    }
    interface def ControllerToAlert {
        end supplier : AlertPort;
        end consumer : AlertPort;
    }
    interface def PanelToController {
        end supplier : ControlPanelPort;
        end consumer : ControlPanelPort;
    }

    // ---------- Requirements ----------
    requirement def SecurityRequirement {
        attribute id : String;
        attribute text : String;
    }

    requirement ComprehensiveProtection {
        doc /* The system shall provide comprehensive protection through surveillance, intrusion detection, and graduated automated response. */
    }

    requirement CentralControlRequirement :> SecurityRequirement {
        attribute id = "REQ-001";
        attribute text = "The system shall use a central controller to process information from all components.";
    }

    requirement SensorMonitoringRequirement :> SecurityRequirement {
        attribute id = "REQ-002";
        attribute text = "The system shall continuously monitor motion detectors and door/window sensors when armed.";
    }

    requirement VideoSurveillanceRequirement :> SecurityRequirement {
        attribute id = "REQ-003";
        attribute text = "The system shall provide constant video surveillance from front, rear, and interior cameras.";
    }

    requirement UserInteractionRequirement :> SecurityRequirement {
        attribute id = "REQ-004";
        attribute text = "The system shall allow users to arm and disarm via a control panel.";
    }

    requirement ThreatAssessmentRequirement :> SecurityRequirement {
        attribute id = "REQ-005";
        attribute text = "The controller shall assess threat severity and confidence using sensor and video data.";
    }

    requirement GraduatedResponseRequirement :> SecurityRequirement {
        attribute id = "REQ-006";
        attribute text = "The system shall respond according to threat level: minor logs and records; serious activates sirens and alerts; critical activates all countermeasures and notifies authorities.";
    }

    requirement RapidResponseRequirement :> SecurityRequirement {
        attribute id = "REQ-007";
        attribute text = "The system shall transition from detection to response within 2 seconds.";
        attribute maxLatency : Duration = 2.0;
    }

    requirement StateTransitionRequirement :> SecurityRequirement {
        attribute id = "REQ-008";
        attribute text = "The system shall operate in clear states: disarmed, armed/monitoring, and alert.";
    }

    // ---------- Part Definitions ----------

    part def MotionDetector {
        attribute sensorId : String;
        attribute detectionRange : Length = 12.0;
        attribute power : Voltage = 12.0;
        port sensorOut : SensorPort;
        attribute currentState : SensorState = SensorState::idle;

        action def DetectMotion {
            in signal : Boolean;
            out reading : SensorReading;
        }
    }

    part def DoorWindowSensor {
        attribute sensorId : String;
        attribute location : String;
        attribute power : Voltage = 3.0;
        port sensorOut : SensorPort;
        attribute currentState : SensorState = SensorState::idle;

        action def DetectOpen {
            in isOpen : Boolean;
            out reading : SensorReading;
        }
    }

    part def Camera {
        attribute cameraId : String;
        attribute location : String;
        attribute resolution : String = "1080p";
        attribute frameRate : Frequency = 30.0;
        attribute power : Voltage = 12.0;
        port videoOut : VideoPort;
        attribute mode : CameraMode = CameraMode::idle;

        action def CaptureVideo {
            out feed : VideoFeed;
        }
    }

    part def ControlPanel {
        attribute panelId : String;
        attribute location : String = "Entry Hall";
        port panelPort : ControlPanelPort;
        attribute currentMode : SystemMode = SystemMode::disarmed;

        action def AcceptUserInput {
            in input : String;
            out command : String;
        }
    }

    part def Siren {
        attribute sirenId : String;
        attribute location : String;
        attribute maxVolume : Decibel = 110.0;
        attribute power : Voltage = 12.0;
        port sirenIn : SirenControlPort;
        attribute isActive : Boolean = false;

        action def SoundAlarm {
            in activate : Boolean;
        }
    }

    part def ElectronicLock {
        attribute lockId : String;
        attribute location : String;
        attribute power : Voltage = 12.0;
        port lockIn : LockControlPort;
        attribute state : LockState = LockState::unlocked;

        action def EngageLock {
            in command : LockState;
        }
    }

    part def NotificationService {
        attribute serviceId : String;
        port alertIn : AlertPort;
        attribute recipients : AlertChannel[1..*];

        action def SendAlert {
            in notification : AlertNotification;
        }
    }

    part def CentralController {
        attribute controllerId : String;
        attribute processingSpeed : Frequency = 1000.0;
        attribute maxResponseTime : Duration = 2.0;

        port sensorIn : SensorPort[1..*];
        port videoIn : VideoPort[1..*];
        port panelIn : ControlPanelPort;
        port sirenOut : SirenControlPort[1..*];
        port lockOut : LockControlPort[1..*];
        port alertOut : AlertPort;

        attribute currentMode : SystemMode = SystemMode::disarmed;
        attribute lastAssessment : ThreatAssessment;

        // State machine for the controller
        state def ControllerBehavior {
            entry action { /* initialize system */ }

            state disarmed {
                entry action { /* system passive, no monitoring */ }
                transition armed_transition
                    first disarmed
                    accept ControlPanelPort.userCommand ? "arm"
                    then monitoring;
            }

            state monitoring {
                entry action { /* active surveillance of all sensors and cameras */ }
                transition alert_transition
                    first monitoring
                    accept SensorPort.reading ? (r : SensorReading) => r.state == SensorState::triggered
                    then alert;
                transition disarm_transition
                    first monitoring
                    accept ControlPanelPort.userCommand ? "disarm"
                    then disarmed;
            }

            state alert {
                entry action { /* assess threat and execute response */ }

                do action AssessThreat {
                    in readings : SensorReading[*];
                    in feeds : VideoFeed[*];
                    out assessment : ThreatAssessment;
                }

                do action ExecuteResponse {
                    in assessment : ThreatAssessment;
                }

                transition return_to_monitoring
                    first alert
                    accept ExecuteResponse
                    then monitoring;
            }
        }

        action def AssessThreat {
            in readings : SensorReading[*];
            in feeds : VideoFeed[*];
            out assessment : ThreatAssessment;

            // Determine level based on number and type of triggered sensors
            perform {
                if (readings->size() == 1) {
                    assessment.level := ThreatLevel::minor;
                    assessment.confidence := 0.6;
                } else if (readings->size() == 2) {
                    assessment.level := ThreatLevel::serious;
                    assessment.confidence := 0.8;
                } else {
                    assessment.level := ThreatLevel::critical;
                    assessment.confidence := 0.95;
                }
            }
        }

        action def ExecuteResponse {
            in assessment : ThreatAssessment;

            perform {
                // Always log incident and record video
                allocate LogIncident(assessment);
                allocate RecordVideo(assessment);

                if (assessment.level == ThreatLevel::serious || assessment.level == ThreatLevel::critical) {
                    allocate ActivateSirens();
                    allocate SendAlerts(assessment);
                }

                if (assessment.level == ThreatLevel::critical) {
                    allocate EngageAllLocks();
                    allocate NotifyAuthorities(assessment);
                }
            }
        }

        action def LogIncident {
            in assessment : ThreatAssessment;
            out log : IncidentLog;
        }

        action def RecordVideo {
            in assessment : ThreatAssessment;
        }

        action def ActivateSirens {
            out activate : Boolean = true;
        }

        action def SendAlerts {
            in assessment : ThreatAssessment;
            out notifications : AlertNotification[*];
        }

        action def EngageAllLocks {
            out command : LockState = LockState::locked;
        }

        action def NotifyAuthorities {
            in assessment : ThreatAssessment;
            out notification : AlertNotification;
        }

        exhibit state ControllerBehavior;
    }

    // ---------- Top-level System ----------
    part def SecuritySystem {
        satisfy ComprehensiveProtection;
        satisfy CentralControlRequirement;
        satisfy SensorMonitoringRequirement;
        satisfy VideoSurveillanceRequirement;
        satisfy UserInteractionRequirement;
        satisfy ThreatAssessmentRequirement;
        satisfy GraduatedResponseRequirement;
        satisfy RapidResponseRequirement;
        satisfy StateTransitionRequirement;

        part controller : CentralController {
            attribute controllerId = "CTRL-001";
        }

        part motionDetectorFront : MotionDetector {
            attribute sensorId = "MOT-FRONT";
            attribute detectionRange = 12.0;
        }
        part motionDetectorRear : MotionDetector {
            attribute sensorId = "MOT-REAR";
            attribute detectionRange = 12.0;
        }
        part motionDetectorInterior : MotionDetector {
            attribute sensorId = "MOT-INT";
            attribute detectionRange = 8.0;
        }

        part frontDoorSensor : DoorWindowSensor {
            attribute sensorId = "DWS-FRONT-DOOR";
            attribute location = "Front Door";
        }
        part backDoorSensor : DoorWindowSensor {
            attribute sensorId = "DWS-BACK-DOOR";
            attribute location = "Back Door";
        }
        part windowSensor1 : DoorWindowSensor {
            attribute sensorId = "DWS-WIN-01";
            attribute location = "Living Room Window";
        }
        part windowSensor2 : DoorWindowSensor {
            attribute sensorId = "DWS-WIN-02";
            attribute location = "Bedroom Window";
        }

        part frontCamera : Camera {
            attribute cameraId = "CAM-FRONT";
            attribute location = "Front Entrance";
        }
        part rearCamera : Camera {
            attribute cameraId = "CAM-REAR";
            attribute location = "Rear Entrance";
        }
        part interiorCamera : Camera {
            attribute cameraId = "CAM-INT";
            attribute location = "Main Hallway";
        }

        part controlPanel : ControlPanel {
            attribute panelId = "PANEL-001";
            attribute location = "Entry Hall";
        }

        part interiorSiren : Siren {
            attribute sirenId = "SIR-INT";
            attribute location = "Main Hallway";
            attribute maxVolume = 100.0;
        }
        part exteriorSiren : Siren {
            attribute sirenId = "SIR-EXT";
            attribute location = "Front Exterior";
            attribute maxVolume = 110.0;
        }

        part frontDoorLock : ElectronicLock {
            attribute lockId = "LOCK-FRONT";
            attribute location = "Front Door";
        }
        part backDoorLock : ElectronicLock {
            attribute lockId = "LOCK-BACK";
            attribute location = "Back Door";
        }

        part notificationService : NotificationService {
            attribute serviceId = "NOTIF-001";
            attribute recipients = (AlertChannel::owner, AlertChannel::securityCompany, AlertChannel::authorities);
        }

        // Connections: Sensors to Controller
        connection motionFrontToController : SensorToController
            connect motionDetectorFront.sensorOut to controller.sensorIn[1];
        connection motionRearToController : SensorToController
            connect motionDetectorRear.sensorOut to controller.sensorIn[2];
        connection motionIntToController : SensorToController
            connect motionDetectorInterior.sensorOut to controller.sensorIn[3];
        connection frontDoorToController : SensorToController
            connect frontDoorSensor.sensorOut to controller.sensorIn[4];
        connection backDoorToController : SensorToController
            connect backDoorSensor.sensorOut to controller.sensorIn[5];
        connection window1ToController : SensorToController
            connect windowSensor1.sensorOut to controller.sensorIn[6];
        connection window2ToController : SensorToController
            connect windowSensor2.sensorOut to controller.sensorIn[7];

        // Connections: Cameras to Controller
        connection frontCamToController : VideoToController
            connect frontCamera.videoOut to controller.videoIn[1];
        connection rearCamToController : VideoToController
            connect rearCamera.videoOut to controller.videoIn[2];
        connection intCamToController : VideoToController
            connect interiorCamera.videoOut to controller.videoIn[3];

        // Connection: Control Panel to Controller
        connection panelToController : PanelToController
            connect controlPanel.panelPort to controller.panelIn;

        // Connections: Controller to Sirens
        connection controllerToIntSiren : ControllerToSiren
            connect controller.sirenOut[1] to interiorSiren.sirenIn;
        connection controllerToExtSiren : ControllerToSiren
            connect controller.sirenOut[2] to exteriorSiren.sirenIn;

        // Connections: Controller to Locks
        connection controllerToFrontLock : ControllerToLock
            connect controller.lockOut[1] to frontDoorLock.lockIn;
        connection controllerToBackLock : ControllerToLock
            connect controller.lockOut[2] to backDoorLock.lockIn;

        // Connection: Controller to Notification Service
        connection controllerToNotification : ControllerToAlert
            connect controller.alertOut to notificationService.alertIn;
    }
}
