package SecuritySystemModel {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import ModelingMetadata::*;
    
    attribute def ThreatLevel {
        attribute severity : Integer;
        attribute confidence : Real;
    }
    
    attribute def AlarmCommand;
    attribute def LockCommand;
    attribute def ArmingCommand;
    attribute def VideoCommand;
    
    item def SensorReading {
        attribute timestamp : String;
        attribute sensorId : String;
        attribute value : Real;
    }
    
    item def IntrusionEvent {
        attribute location : String;
        attribute timestamp : String;
        attribute threatLevel : ThreatLevel;
        attribute eventType : String;
    }
    
    item def VideoFrame {
        attribute timestamp : String;
        attribute cameraId : String;
        attribute resolution : String;
    }
    
    item def AlertNotification {
        attribute notificationMessage : String;
        attribute priority : Integer;
        attribute recipients : String[*];
    }
    
    port def SensorPort {
        out reading : SensorReading;
    }
    
    port def AlarmPort {
        in command : AlarmCommand;
    }
    
    port def LockPort {
        in command : LockCommand;
    }
    
    port def VideoPort {
        out videoFrame : VideoFrame;
    }
    
    port def ControlPort {
        in armingCmd : ArmingCommand;
        out systemStatus : String;
    }
    
    port def NotificationPort {
        out alert : AlertNotification;
    }
    
    part def MotionSensor {
        port output : SensorPort;
        attribute sensitivity : Real;
        attribute detectionRange : LengthValue;
        attribute active : Boolean;
    }
    
    part def DoorSensor {
        port output : SensorPort;
        attribute sensorState : String;
        attribute active : Boolean;
    }
    
    part def WindowSensor {
        port output : SensorPort;
        attribute sensorState : String;
        attribute active : Boolean;
    }
    
    part def Camera {
        port videoOutput : VideoPort;
        attribute resolution : String;
        attribute fieldOfView : Real;
        attribute recording : Boolean;
    }
    
    part def Siren {
        port input : AlarmPort;
        attribute volumeLevel : Real;
        attribute active : Boolean;
    }
    
    part def DoorLock {
        port input : LockPort;
        attribute locked : Boolean;
    }
    
    part def ControlPanel {
        port control : ControlPort;
        attribute armed : Boolean;
        attribute accessCode : String;
    }
    
    part def CentralController {
        attribute systemArmed : Boolean;
        attribute currentThreatLevel : ThreatLevel;
    }
    
    part def NotificationService {
        port output : NotificationPort;
        attribute recipients : String[*];
    }
    
    action def MonitorSensors {
        in sensorData : SensorReading;
        out event : IntrusionEvent;
    }
    
    action def AnalyzeThreat {
        in event : IntrusionEvent;
        in videoData : VideoFrame;
        out threat : ThreatLevel;
    }
    
    action def ActivateAlarm {
        in threat : ThreatLevel;
        out alarmCmd : AlarmCommand;
    }
    
    action def SecureLocks {
        in threat : ThreatLevel;
        out lockCmd : LockCommand;
    }
    
    action def RecordEvidence {
        in event : IntrusionEvent;
        in videoData : VideoFrame;
    }
    
    action def NotifyAuthorities {
        in threat : ThreatLevel;
        in event : IntrusionEvent;
        out notification : AlertNotification;
    }
    
    action def ProtectPremises {
        in sensorInputs : SensorReading[*];
        in videoInputs : VideoFrame[*];
        in systemArmed : Boolean;
        out alarmCmd : AlarmCommand;
        out lockCmd : LockCommand;
        out notification : AlertNotification;
        
        first start;
        then merge continuousMonitoring;
        
        then action monitorActivity : MonitorSensors {
            in sensorData : SensorReading;
            out detectedEvent : IntrusionEvent;
        }
        
        then decide;
            if systemArmed and monitorActivity.detectedEvent.threatLevel.severity > 0 then analyzeThreat;
            if not systemArmed or monitorActivity.detectedEvent.threatLevel.severity == 0 then continuousMonitoring;
        
        action analyzeThreat : AnalyzeThreat {
            in event = monitorActivity.detectedEvent;
            in videoData : VideoFrame;
            out assessedThreat : ThreatLevel;
        }
        
        then decide;
            if analyzeThreat.assessedThreat.severity >= 8 then criticalResponse;
            if analyzeThreat.assessedThreat.severity >= 5 and analyzeThreat.assessedThreat.severity < 8 then moderateResponse;
            if analyzeThreat.assessedThreat.severity < 5 then minimalResponse;
        
        action criticalResponse {
            first action activateAlarm : ActivateAlarm {
                in threat = analyzeThreat.assessedThreat;
                out alarmCmd : AlarmCommand;
            }
            then action secureLocks : SecureLocks {
                in threat = analyzeThreat.assessedThreat;
                out lockCmd : LockCommand;
            }
            then action recordEvidence : RecordEvidence {
                in event = monitorActivity.detectedEvent;
                in videoData : VideoFrame;
            }
            then action notifyAuthorities : NotifyAuthorities {
                in threat = analyzeThreat.assessedThreat;
                in event = monitorActivity.detectedEvent;
                out notification : AlertNotification;
            }
        }
        then continuousMonitoring;
        
        action moderateResponse {
            first action activateAlarm : ActivateAlarm {
                in threat = analyzeThreat.assessedThreat;
                out alarmCmd : AlarmCommand;
            }
            then action recordEvidence : RecordEvidence {
                in event = monitorActivity.detectedEvent;
                in videoData : VideoFrame;
            }
            then action notifyAuthorities : NotifyAuthorities {
                in threat = analyzeThreat.assessedThreat;
                in event = monitorActivity.detectedEvent;
                out notification : AlertNotification;
            }
        }
        then continuousMonitoring;
        
        action minimalResponse {
            action recordEvidence : RecordEvidence {
                in event = monitorActivity.detectedEvent;
                in videoData : VideoFrame;
            }
        }
        then continuousMonitoring;
    }
    
    state def SecuritySystemStates {
        entry; then disarmed;
        
        state disarmed {
            doc /* System is not actively monitoring for threats */
        }
        
        transition disarmedToArmed
            first disarmed
            accept ArmingCommand
            then armed;
        
        state armed {
            doc /* System is actively monitoring all sensors */
            entry; then monitoring;
            
            state monitoring {
                doc /* Continuous surveillance of all entry points */
            }
            
            transition monitoringToAlert
                first monitoring
                accept IntrusionEvent
                then alert;
            
            state alert {
                doc /* Threat detected, executing response protocol */
                entry; then assessingThreat;
                
                state assessingThreat {
                    doc /* Analyzing threat severity */
                }
                
                transition assessingToResponding
                    first assessingThreat
                    then responding;
                
                state responding {
                    doc /* Executing countermeasures */
                    entry; then activeAlarm;
                    
                    state activeAlarm {
                        doc /* Alarm sounding */
                    }
                    
                    state locksEngaged {
                        doc /* All locks secured */
                    }
                    
                    state recordingEvidence {
                        doc /* Capturing video evidence */
                    }
                    
                    state notificationSent {
                        doc /* Authorities notified */
                    }
                }
            }
            
            transition alertToMonitoring
                first alert
                accept ThreatCleared
                then monitoring;
        }
        
        transition armedToDisarmed
            first armed
            accept ArmingCommand
            then disarmed;
    }
    
    requirement def SecuritySystemRequirement {
        doc /* Top-level security system requirements */
        subject system : SecuritySystem;
    }
    
    requirement <'SEC-REQ-001'> intrusionDetection : SecuritySystemRequirement {
        doc /* The security system shall detect unauthorized entry attempts 
             through all monitored entry points with 99% accuracy within 2 seconds */
        
        @StatusInfo {
            status = StatusKind::approved;
            originator = "Security Team";
            owner = "System Architect";
        }
        
        assume constraint {
            doc /* All sensors are properly installed and calibrated */
        }
        
        require constraint {
            doc /* Detection latency shall not exceed 2 seconds */
        }
    }
    
    requirement <'SEC-REQ-002'> alarmActivation : SecuritySystemRequirement {
        doc /* The system shall activate audible and visual alarms within 
             3 seconds of confirmed threat detection */
        
        @StatusInfo {
            status = StatusKind::approved;
            originator = "Security Team";
            owner = "System Architect";
        }
    }
    
    requirement <'SEC-REQ-003'> evidenceRecording : SecuritySystemRequirement {
        doc /* All security events shall be recorded with video evidence 
             and stored for minimum 90 days */
        
        @StatusInfo {
            status = StatusKind::approved;
            originator = "Compliance Officer";
            owner = "Data Manager";
        }
    }
    
    requirement <'SEC-REQ-004'> notificationDelivery : SecuritySystemRequirement {
        doc /* The system shall deliver notifications to designated contacts 
             within 5 seconds of threat confirmation */
        
        @StatusInfo {
            status = StatusKind::inReview;
            originator = "Operations Manager";
            owner = "Communications Lead";
        }
    }
    
    requirement <'SEC-REQ-005'> lockSecurity : SecuritySystemRequirement {
        doc /* All entry point locks shall engage automatically when 
             critical threat level is detected */
        
        @StatusInfo {
            status = StatusKind::approved;
            originator = "Security Team";
            owner = "System Architect";
        }
    }
    
    part def SecuritySystem {
        doc /* 
        This security system provides comprehensive protection for residential 
        and commercial premises through integrated surveillance, intrusion detection, 
        and automated response capabilities.
        
        The system's primary function is to continuously monitor all entry points 
        and protected areas, detect unauthorized access attempts or suspicious activity, 
        assess the severity of detected threats, and execute appropriate countermeasures 
        to protect the premises and its occupants.
        
        Operation begins when the system is armed through the control panel. Multiple 
        sensors including motion detectors, door and window sensors continuously monitor 
        the protected perimeter. Surveillance cameras provide visual confirmation and 
        evidence recording. When any sensor detects unusual activity, the central 
        controller receives the sensor data and correlates it with video feeds to 
        determine the threat level.
        
        Based on threat severity, the system executes graduated responses: critical 
        threats trigger immediate alarm activation, automatic lock engagement, video 
        recording, and notification to authorities. Moderate threats activate alarms 
        and notifications while recording evidence. Minor events are logged for review.
        
        The system maintains continuous operation in armed mode, cycling through 
        monitoring, threat assessment, and response phases until threats are cleared 
        or the system is disarmed by authorized personnel. All events are recorded 
        with timestamps and video evidence for security analysis and compliance.
        */
        
        part frontMotionSensor : MotionSensor {
            port sensorOut : SensorPort;
        }
        
        part rearMotionSensor : MotionSensor {
            port sensorOut : SensorPort;
        }
        
        part mainDoorSensor : DoorSensor {
            port sensorOut : SensorPort;
        }
        
        part backDoorSensor : DoorSensor {
            port sensorOut : SensorPort;
        }
        
        part window1Sensor : WindowSensor {
            port sensorOut : SensorPort;
        }
        
        part window2Sensor : WindowSensor {
            port sensorOut : SensorPort;
        }
        
        part window3Sensor : WindowSensor {
            port sensorOut : SensorPort;
        }
        
        part frontCamera : Camera {
            port videoOut : VideoPort;
        }
        
        part rearCamera : Camera {
            port videoOut : VideoPort;
        }
        
        part interiorCamera : Camera {
            port videoOut : VideoPort;
        }
        
        part mainSiren : Siren {
            port alarmIn : AlarmPort;
        }
        
        part exteriorSiren : Siren {
            port alarmIn : AlarmPort;
        }
        
        part mainDoorLock : DoorLock {
            port lockIn : LockPort;
        }
        
        part backDoorLock : DoorLock {
            port lockIn : LockPort;
        }
        
        part controlPanel : ControlPanel {
            port controlIf : ControlPort;
        }
        
        part controller : CentralController;
        
        part notificationService : NotificationService {
            port notifyOut : NotificationPort;
        }
        
        perform action protectPremises : ProtectPremises;
        
        state systemState : SecuritySystemStates;
    }
    
    part securitySystem : SecuritySystem {
        satisfy intrusionDetection;
        satisfy alarmActivation;
        satisfy evidenceRecording;
        satisfy notificationDelivery;
        satisfy lockSecurity;
    }
}
