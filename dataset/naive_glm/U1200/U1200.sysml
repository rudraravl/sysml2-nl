package PropertySecuritySystem {
    import SI::*;
    import ScalarValues::*;
    
    // ===== Value Types =====
    
    valuetype Voltage :> Real { unit 'V' "volt"; }
    valuetype Current :> Real { unit 'A' "ampere"; }
    valuetype Power :> Real { unit 'W' "watt"; }
    valuetype Duration :> Real { unit 's' "second"; }
    valuetype Frequency :> Real { unit 'Hz' "hertz"; }
    valuetype Distance :> Real { unit 'm' "meter"; }
    valuetype Temperature :> Real { unit 'degC' "degree Celsius"; }
    valuetype Decibel :> Real { unit 'dB' "decibel"; }
    valuetype Luminance :> Real { unit 'lux' "lux"; }
    valuetype Percentage :> Real { unit '%' "percent"; }
    
    // ===== Enumerations =====
    
    enum ArmState { unarmed; arming; armed; }
    enum SeverityLevel { minor; moderate; critical; }
    enum DoorWindowState { closed; open; breached; }
    enum CameraMode { idle; recording; streaming; nightVision; }
    enum ThreatStatus { nominal; suspicious; confirmedIntrusion; }
    enum AlertChannel { none; sirens; cameras; monitoringStation; all; }
    
    // ===== Item Definitions =====
    
    item def SensorEvent {
        attribute sourceId : String;
        attribute timestamp : Time;
        attribute severity : SeverityLevel;
    }
    
    item def AlertMessage {
        attribute systemId : String;
        attribute incidentTimestamp : Time;
        attribute severity : SeverityLevel;
        attribute location : String;
        attribute cameraClipId : String optional;
    }
    
    item def CameraFeed {
        attribute cameraId : String;
        attribute mode : CameraMode;
        attribute frameRate : Frequency;
        attribute resolution : String;
    }
    
    item def AccessCredential {
        attribute codeHash : String;
        attribute valid : Boolean;
    }
    
    item def PowerStatus {
        attribute voltage : Voltage;
        attribute backupActive : Boolean;
        attribute batteryPercent : Percentage;
    }
    
    // ===== Port Definitions =====
    
    port def SensorDataPort {
        attribute protocol : String = "wired-bus";
        out attribute events : SensorEvent[0..*];
    }
    
    port def CommandPort {
        in attribute commands : String[0..*];
        out attribute ack : String[0..*];
    }
    
    port def VideoPort {
        out attribute feed : CameraFeed[0..*];
    }
    
    port def AlertCommsPort {
        out attribute messages : AlertMessage[0..*];
        in attribute acknowledgements : String[0..*];
    }
    
    port def PanelInterfacePort {
        in attribute userCommands : String[0..*];
        out attribute panelFeedback : String[0..*];
    }
    
    port def PowerPort {
        in attribute supply : PowerStatus;
    }
    
    // ===== Requirements =====
    
    requirement def ContinuityRequirement {
        doc
        /* The system shall remain operational during primary power loss for at least 8 hours. */
        attribute minBackupDuration : Duration = 28800;
        subject backupSupply;
    }
    
    requirement def RedundantSirenRequirement {
        doc
        /* At least two independent sirens shall be installed such that failure of one does not
           prevent audible deterrence. */
        attribute minimumSirenCount : Integer = 2;
    }
    
    requirement def ArmDisarmRequirement {
        doc
        /* The system shall only transition between armed and unarmed states upon entry of a
           valid access code via the control panel. */
    }
    
    requirement def ThreatResponseRequirement {
        doc
        /* For critical threats the controller shall activate sirens, command cameras to record,
           and dispatch an alert to the external monitoring station within 10 seconds of detection. */
        attribute maxResponseTime : Duration = 10;
    }
    
    requirement def CameraNightVisionRequirement {
        doc
        /* All cameras shall be capable of night vision operation below 1 lux ambient luminance. */
        attribute nightVisionThreshold : Luminance = 1.0;
    }
    
    requirement def SensorCoverageRequirement {
        doc
        /* Door and window sensors shall be installed on every perimeter opening and motion
           sensors shall be installed in all common areas including living rooms and hallways. */
    }
    
    requirement def LoggingRequirement {
        doc
        /* All sensor events and user interactions shall be logged with timestamp and severity. */
    }
    
    // ===== Sensor Abstractions =====
    
    abstract part def Sensor {
        attribute id : String;
        attribute location : String;
        attribute sensitivityLevel : Percentage = 70;
        port sensorOut : SensorDataPort;
        attribute samplePeriod : Duration = 1.0;
        exhibit state monitoring {
            entry :> Sensor::sample;
        }
        action def sample;
    }
    
    part def DoorWindowSensor :> Sensor {
        attribute monitoredOpeningState : DoorWindowState = closed;
        attribute tamperDetected : Boolean = false;
        override action def sample {
            /* Read reed switch and tamper circuit; emit SensorEvent on state change. */
        }
        exhibit state openingMonitor {
            state closed;
            state open {
                /* Emit minor severity event. */
            }
            state breached {
                /* Emit critical severity event. */
            }
            transition closed to open when monitoredOpeningState == DoorWindowState::open;
            transition closed to breached when tamperDetected;
            transition open to closed when monitoredOpeningState == DoorWindowState::closed;
        }
    }
    
    part def MotionSensor :> Sensor {
        attribute detectionRange : Distance = 12.0;
        attribute petImmunity : Boolean = true;
        override action def sample {
            /* Sample PIR detector; if motion above threshold emit event with location. */
        }
        exhibit state motionDetection {
            state idle;
            state motionDetected {
                /* Emit moderate severity SensorEvent. */
            }
            transition idle to motionDetected;
            transition motionDetected to idle after 3.0;
        }
    }
    
    // ===== Cameras =====
    
    part def SurveillanceCamera {
        attribute id : String;
        attribute location : String;
        attribute mode : CameraMode = idle;
        attribute hasNightVision : Boolean = true;
        attribute minIllumination : Luminance = 0.5;
        attribute resolution : String = "1080p";
        port commandIn : CommandPort;
        port videoOut : VideoPort;
        exhibit state cameraOperation {
            state idle;
            state recording {
                entry { /* Start writing to NVR storage. */ }
            }
            state nightVisionMode {
                entry { /* Enable IR illuminators. */ }
            }
            transition idle to recording when commandIn.commands->includes("record");
            transition idle to nightVisionMode when ambientLuminance < minIllumination;
            transition recording to idle when commandIn.commands->includes("stopRecord");
            transition nightVisionMode to recording when commandIn.commands->includes("record");
        }
        private attribute ambientLuminance : Luminance = 10.0;
    }
    
    // ===== Siren =====
    
    part def Siren {
        attribute id : String;
        attribute location : String;
        attribute maxSoundLevel : Decibel = 110.0;
        attribute isPrimary : Boolean;
        port commandIn : CommandPort;
        attribute active : Boolean = false;
        exhibit state sirenState {
            state silent;
            state sounding {
                entry { /* Energize piezo driver at maxSoundLevel. */ }
                exit { /* De-energize driver. */ }
            }
            transition silent to sounding when commandIn.commands->includes("activate");
            transition sounding to silent when commandIn.commands->includes("deactivate");
        }
    }
    
    // ===== Control Panel =====
    
    part def ControlPanel {
        attribute id : String;
        attribute location : String = "main-entry";
        port panelInterface : PanelInterfacePort;
        port commandOut : CommandPort;
        attribute currentArmState : ArmState = unarmed;
        exhibit state panelState {
            state idle;
            state awaitingCode {
                entry { /* Display prompt for access code. */ }
            }
            state armed;
            state alarmInProgress;
            transition idle to awaitingCode when panelInterface.userCommands->includes("armRequested");
            transition awaitingCode to armed when validateCode(panelInterface.userCommands);
            transition awaitingCode to idle when panelInterface.userCommands->includes("cancel");
            transition armed to awaitingCode when panelInterface.userCommands->includes("disarmRequested");
            transition armed to alarmInProgress when panelInterface.userCommands->includes("intrusionDetected");
            transition alarmInProgress to awaitingCode when panelInterface.userCommands->includes("disarmRequested");
        }
        action def validateCode(cmds : String[0..*]) : Boolean {
            /* Compare entered code hash against stored AccessCredential.codeHash. */
        }
    }
    
    // ===== Communication Module =====
    
    part def CommunicationModule {
        attribute id : String;
        attribute protocol : String = "cellular";
        attribute primaryEndpoint : String = "monitoring-station";
        port alertOut : AlertCommsPort;
        port commandIn : CommandPort;
        attribute lastTransmission : Duration = 0.0;
        exhibit state commsState {
            state idle;
            state transmitting {
                entry { /* Send AlertMessage over primaryEndpoint. */ }
            }
            state retry;
            transition idle to transmitting when commandIn.commands->includes("sendAlert");
            transition transmitting to idle when alertOut.acknowledgements->includes("ack");
            transition transmitting to retry when transmissionFails;
            transition retry to transmitting after 5.0;
        }
        private attribute transmissionFails : Boolean = false;
    }
    
    // ===== Backup Power Supply =====
    
    part def BackupPowerSupply {
        attribute id : String;
        attribute batteryCapacityAh : Real = 18.0;
        attribute nominalVoltage : Voltage = 12.0;
        attribute chargePercent : Percentage = 100.0;
        attribute estimatedRuntime : Duration = 28800.0;
        port powerOut : PowerPort;
        attribute onBattery : Boolean = false;
        exhibit state powerState {
            state mainsPowered;
            state batteryPowered {
                entry { /* Cut over to battery, signal controller. */ }
            }
            transition mainsPowered to batteryPowered when mainsLost;
            transition batteryPowered to mainsPowered when mainsRestored;
        }
        private attribute mainsLost : Boolean = false;
        private attribute mainsRestored : Boolean = false;
    }
    
    // ===== Central Controller =====
    
    part def CentralController {
        attribute id : String;
        attribute systemState : ArmState = unarmed;
        attribute currentThreat : ThreatStatus = ThreatStatus::nominal;
        attribute lastIncidentId : String;
        
        port sensorBus : SensorDataPort;
        port cameraCommands : CommandPort;
        port sirenCommands : CommandPort;
        port panelLink : PanelInterfacePort;
        port commsLink : AlertCommsPort;
        port powerIn : PowerPort;
        
        exhibit state controllerStateMachine {
            state offline;
            state initializing {
                entry { /* Run self-test of sensors, cameras, sirens, comms. */ }
            }
            state unarmedMode;
            state armedMode;
            state assessingThreat;
            state minorResponse;
            state criticalResponse;
            state alarmActive;
            
            transition offline to initializing when powerOn;
            transition initializing to unarmedMode when initComplete;
            transition unarmedMode to armedMode when panelLink.userCommands->includes("armConfirmed");
            transition armedMode to assessingThreat when sensorBus.events->notEmpty();
            transition assessingThreat to minorResponse when evaluateSeverity() == SeverityLevel::minor;
            transition assessingThreat to criticalResponse when evaluateSeverity() == SeverityLevel::critical;
            transition minorResponse to armedMode when panelLink.userCommands->includes("acknowledge");
            transition criticalResponse to alarmActive;
            transition alarmActive to unarmedMode when panelLink.userCommands->includes("disarmConfirmed");
        }
        
        private action def evaluateSeverity() : SeverityLevel {
            /* Examine most recent SensorEvent; combine sensor type and location to classify. */
        }
        
        private action def logIncident(ev : SensorEvent) {
            /* Persist event with timestamp and severity to audit log. */
        }
        
        private action def dispatchAlert(ev : SensorEvent) {
            /* Build AlertMessage and forward via commsLink.messages. */
        }
        
        private attribute powerOn : Boolean = false;
        private attribute initComplete : Boolean = false;
    }
    
    // ===== Top-level System =====
    
    part def PropertySecuritySystem {
        attribute systemId : String = "PSS-001";
        attribute installationDate : String;
        attribute activeArmState : ArmState = unarmed;
        
        requirement ref sec : ContinuityRequirement;
        requirement ref red : RedundantSirenRequirement;
        requirement ref arm : ArmDisarmRequirement;
        requirement ref threat : ThreatResponseRequirement;
        requirement ref cam : CameraNightVisionRequirement;
        requirement ref cover : SensorCoverageRequirement;
        requirement ref log : LoggingRequirement;
        
        part controller : CentralController {
            attribute id : String = "CTRL-01";
        }
        
        part controlPanel : ControlPanel {
            attribute id : String = "PANEL-01";
        }
        
        part sensors {
            part frontDoorSensor : DoorWindowSensor {
                attribute id : String = "DW-FRONT";
                attribute location : String = "front-door";
            }
            part backDoorSensor : DoorWindowSensor {
                attribute id : String = "DW-BACK";
                attribute location : String = "back-door";
            }
            part livingRoomWindowSensor : DoorWindowSensor {
                attribute id : String = "DW-LR-WIN";
                attribute location : String = "living-room-window";
            }
            part livingRoomMotion : MotionSensor {
                attribute id : String = "MOTION-LR";
                attribute location : String = "living-room";
            }
            part hallwayMotion : MotionSensor {
                attribute id : String = "MOTION-HALL";
                attribute location : String = "hallway";
            }
            part garageMotion : MotionSensor {
                attribute id : String = "MOTION-GARAGE";
                attribute location : String = "garage";
            }
        }
        
        part cameras {
            part frontEntranceCamera : SurveillanceCamera {
                attribute id : String = "CAM-FRONT";
                attribute location : String = "front-entrance";
            }
            part backyardCamera : SurveillanceCamera {
                attribute id : String = "CAM-BACK";
                attribute location : String = "backyard";
            }
            part sideEntranceCamera : SurveillanceCamera {
                attribute id : String = "CAM-SIDE";
                attribute location : String = "side-entrance";
            }
        }
        
        part sirens {
            part primarySiren : Siren {
                attribute id : String = "SIREN-1";
                attribute location : String = "roof-north";
                attribute isPrimary : Boolean = true;
            }
            part secondarySiren : Siren {
                attribute id : String = "SIREN-2";
                attribute location : String = "roof-south";
                attribute isPrimary : Boolean = false;
            }
        }
        
        part comms : CommunicationModule {
            attribute id : String = "COMM-01";
        }
        
        part backup : BackupPowerSupply {
            attribute id : String = "BPS-01";
        }
        
        // ===== Connections =====
        
        connection sensorBusWiring connect controller.sensorBus to sensors.frontDoorSensor.sensorOut;
        connection connect controller.sensorBus to sensors.backDoorSensor.sensorOut;
        connection connect controller.sensorBus to sensors.livingRoomWindowSensor.sensorOut;
        connection connect controller.sensorBus to sensors.livingRoomMotion.sensorOut;
        connection connect controller.sensorBus to sensors.hallwayMotion.sensorOut;
        connection connect controller.sensorBus to sensors.garageMotion.sensorOut;
        
        connection cameraCommandBus connect controller.cameraCommands to cameras.frontEntranceCamera.commandIn;
        connection connect controller.cameraCommands to cameras.backyardCamera.commandIn;
        connection connect controller.cameraCommands to cameras.sideEntranceCamera.commandIn;
        
        connection videoAggregate connect cameras.frontEntranceCamera.videoOut to controller.sensorBus;
        connection connect cameras.backyardCamera.videoOut to controller.sensorBus;
        connection connect cameras.sideEntranceCamera.videoOut to controller.sensorBus;
        
        connection sirenControlLink connect controller.sirenCommands to sirens.primarySiren.commandIn;
        connection connect controller.sirenCommands to sirens.secondarySiren.commandIn;
        
        connection panelLink connect controlPanel.commandOut to controller.panelLink;
        connection panelFeedback connect controller.panelLink to controlPanel.panelInterface;
        
        connection commsLink connect controller.commsLink to comms.alertOut;
        connection commsCommand connect controller.commsLink to comms.commandIn;
        
        connection backupPower connect backup.powerOut to controller.powerIn;
        
        // ===== Requirements satisfaction =====
        
        satisfaction red by sirens {
            doc
            /* Two independent sirens are provided, satisfying RedundantSirenRequirement.minimumSirenCount = 2. */
        }
        satisfaction sec by backup {
            doc
            /* BackupPowerSupply provides estimated runtime meeting ContinuityRequirement.minBackupDuration. */
        }
        satisfaction cam by cameras.frontEntranceCamera, cameras.backyardCamera, cameras.sideEntranceCamera {
            doc
            /* Each camera has hasNightVision = true and minIllumination below 1 lux. */
        }
        satisfaction cover by sensors {
            doc
            /* Perimeter openings and common-area motion covered per SensorCoverageRequirement. */
        }
        satisfaction arm by controlPanel {
            doc
            /* Panel state machine only transitions armed/unarmed on validateCode success. */
        }
        satisfaction threat by controller {
            doc
            /* Controller state machine implements assess and full response flow. */
        }
        satisfaction log by controller {
            doc
            /* logIncident action records all events per LoggingRequirement. */
        }
    }
    
    // ===== Action-level behavior for incident response =====
    
    action def respondToCriticalThreat {
        in ev : SensorEvent;
        local controller : CentralController;
        local sirens : Siren[2];
        local cameras : SurveillanceCamera[3];
        local comms : CommunicationModule;
        
        action activateSirens {
            out commands : String[*] = ["activate"];
        }
        action startRecording1 {
            out commands : String[*] = ["record"];
        }
        action startRecording2 {
            out commands : String[*] = ["record"];
        }
        action startRecording3 {
            out commands : String[*] = ["record"];
        }
        action sendAlert {
            in incident : SensorEvent = ev;
            out alertMsg : AlertMessage;
        }
        
        flow activateSirens.commands to sirens.commandIn;
        flow startRecording1.commands to cameras.frontEntranceCamera.commandIn;
        flow startRecording2.commands to cameras.backyardCamera.commandIn;
        flow startRecording3.commands to cameras.sideEntranceCamera.commandIn;
        flow sendAlert.alertMsg to comms.alertOut.messages;
        
        constraint responseWindow : Duration { :> sendAlert.duration; <= 10.0; }
    }
    
    // ===== Component-level test cases =====
    
    test def BackupEnduranceTest {
        objective { /* Verify backup supply sustains controller for at least 8 hours under load. */
        subject backup : BackupPowerSupply;
        requirement ref : ContinuityRequirement;
    }
    
    test def SirenFailoverTest {
        objective { /* Verify alarm audible when primary siren fails. */
        subject sirens : Siren[2];
        requirement ref : RedundantSirenRequirement;
    }
    
    test def ArmDisarmAccessTest {
        objective { /* Verify arming requires valid AccessCredential. */
        subject controlPanel : ControlPanel;
        requirement ref : ArmDisarmRequirement;
    }
    
    test def CriticalResponseLatencyTest {
        objective { /* Verify critical threat response within 10 seconds. */
        subject controller : CentralController;
        requirement ref : ThreatResponseRequirement;
    }
    
    test def NightVisionActivationTest {
        objective { /* Verify camera enters nightVisionMode below 1 lux. */
        subject cameras.frontEntranceCamera : SurveillanceCamera;
        requirement ref : CameraNightVisionRequirement;
    }
}
}
