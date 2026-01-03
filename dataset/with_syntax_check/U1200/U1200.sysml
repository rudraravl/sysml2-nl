package 'Security System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    package Definitions {
        attribute def SecurityLevel {
            attribute level : Integer;
        }
        
        attribute def ZoneID {
            attribute identifier : String;
        }
        
        attribute def AccessCode {
            attribute code : String;
        }
        
        item def IntrusionEvent {
            attribute timestamp : TimeValue;
            attribute zone : ZoneID;
            attribute severity : SecurityLevel;
        }
        
        item def AlarmSignal {
            attribute active : Boolean;
            attribute intensity : SoundPressureLevelValue;
        }
        
        item def VideoData {
            attribute resolution : String;
            attribute frameRate : Real;
        }
        
        item def SystemCommand {
            attribute commandType : String;
            attribute credentials : AccessCode;
        }
        
        port def SensorPort {
            out detectionStatus : Boolean;
            out eventData : IntrusionEvent;
        }
        
        port def ControlPort {
            in systemCommand : SystemCommand;
            out systemStatus : String;
        }
        
        port def AlarmPort {
            in activationSignal : Boolean;
            out alarmOutput : AlarmSignal;
        }
        
        port def CameraPort {
            out videoStream : VideoData;
            in recordingCommand : Boolean;
        }
        
        port def CommunicationPort {
            out alertMessage : String;
            in acknowledgment : Boolean;
        }
        
        part def MotionSensor {
            port sensorOutput : SensorPort;
            attribute detectionRange : LengthValue;
            attribute sensitivity : Real;
        }
        
        part def DoorSensor {
            port sensorOutput : SensorPort;
            attribute isOpen : Boolean;
        }
        
        part def WindowSensor {
            port sensorOutput : SensorPort;
            attribute isBreached : Boolean;
        }
        
        part def SurveillanceCamera {
            port cameraOutput : CameraPort;
            attribute fieldOfView : Real;
            attribute nightVision : Boolean;
        }
        
        part def Siren {
            port alarmInput : AlarmPort;
            attribute volumeLevel : SoundPressureLevelValue;
        }
        
        part def ControlPanel {
            port controlInterface : ControlPort;
            attribute systemArmed : Boolean;
            attribute validAccessCode : AccessCode;
        }
        
        part def CommunicationModule {
            port commInterface : CommunicationPort;
            attribute monitoringStationContact : String;
        }
        
        part def CentralController {
            attribute currentSecurityLevel : SecurityLevel;
            attribute systemState : String;
        }
        
        action def MonitorZone {
            in zoneIdentifier : ZoneID;
            out intrusion : IntrusionEvent;
        }
        
        action def AssessThreat {
            in detectedEvent : IntrusionEvent;
            out assessment : SecurityLevel;
        }
        
        action def ActivateAlarm {
            in threatLevel : SecurityLevel;
            out alarmTriggered : Boolean;
        }
        
        action def StartRecording {
            in zone : ZoneID;
            out recordingActive : Boolean;
        }
        
        action def NotifyMonitoring {
            in event : IntrusionEvent;
            out notificationSent : Boolean;
        }
        
        action def SecurePerimeter {
            in zoneList : ZoneID[*];
            out securityStatus : String;
            
            first start;
            then merge continuousMonitoring;
            
            action continuousMonitoring {
                action monitorAllZones : MonitorZone {
                    in zoneIdentifier = ZoneID { identifier = "MainPerimeter"; };
                    out intrusion : IntrusionEvent;
                }
                
                then decide;
                    if monitorAllZones.intrusion.severity.level > 0 then assessDetection;
                    if monitorAllZones.intrusion.severity.level == 0 then continuousMonitoring;
                
                action assessDetection : AssessThreat {
                    in detectedEvent = monitorAllZones.intrusion;
                    out assessment : SecurityLevel;
                }
                
                then decide;
                    if assessDetection.assessment.level >= 3 then criticalResponse;
                    if assessDetection.assessment.level > 0 and assessDetection.assessment.level < 3 then standardResponse;
                
                action criticalResponse {
                    action activateAlarm : ActivateAlarm {
                        in threatLevel = assessDetection.assessment;
                        out alarmTriggered : Boolean;
                    }
                    
                    flow activateAlarm.alarmTriggered to startRecording.recordingActive;
                    
                    action startRecording : StartRecording {
                        in zone = monitorAllZones.intrusion.zone;
                        out recordingActive : Boolean;
                    }
                    
                    flow startRecording.recordingActive to notifyMonitoring.notificationSent;
                    
                    action notifyMonitoring : NotifyMonitoring {
                        in event = monitorAllZones.intrusion;
                        out notificationSent : Boolean;
                    }
                }
                
                then continuousMonitoring;
                
                action standardResponse {
                    action logEvent {
                        in event = monitorAllZones.intrusion;
                        out logged : Boolean;
                    }
                    
                    action recordIncident : StartRecording {
                        in zone = monitorAllZones.intrusion.zone;
                        out recordingActive : Boolean;
                    }
                }
                
                then continuousMonitoring;
            }
            
            accept systemDisarm;
            then done;
        }
        
        part def SecuritySystem;
    }
    
    package Assembly {
        import Definitions::*;
        
        part securitySystem : SecuritySystem {
            part controller : CentralController;
            
            part controlPanel : ControlPanel {
                port control : ControlPort;
            }
            
            part frontDoorSensor : DoorSensor {
                port sensor1 : SensorPort;
            }
            
            part backDoorSensor : DoorSensor {
                port sensor2 : SensorPort;
            }
            
            part livingRoomMotion : MotionSensor {
                port sensor3 : SensorPort;
            }
            
            part hallwayMotion : MotionSensor {
                port sensor4 : SensorPort;
            }
            
            part window1Sensor : WindowSensor {
                port sensor5 : SensorPort;
            }
            
            part window2Sensor : WindowSensor {
                port sensor6 : SensorPort;
            }
            
            part entranceCamera : SurveillanceCamera {
                port camera1 : CameraPort;
            }
            
            part backyardCamera : SurveillanceCamera {
                port camera2 : CameraPort;
            }
            
            part mainSiren : Siren {
                port alarm1 : AlarmPort;
            }
            
            part backupSiren : Siren {
                port alarm2 : AlarmPort;
            }
            
            part commModule : CommunicationModule {
                port comm : CommunicationPort;
            }
            
            perform action secureProperty : SecurePerimeter {
                in zoneList = (
                    ZoneID { identifier = "FrontEntrance"; },
                    ZoneID { identifier = "BackEntrance"; },
                    ZoneID { identifier = "LivingArea"; },
                    ZoneID { identifier = "Hallway"; },
                    ZoneID { identifier = "Windows"; }
                );
                out securityStatus : String;
            }
        }
    }
    
    package Requirements {
        import Assembly::*;
        
        requirement def SecuritySystemRequirement;
        
        requirement <'REQ-001'> primaryFunction : SecuritySystemRequirement {
            doc /* The security system shall continuously monitor all protected zones for unauthorized intrusion, 
                   automatically detect security breaches through integrated sensors, activate audible alarms, 
                   initiate video recording, and notify the monitoring station when threats are identified. */
            
            subject securitySystem;
        }
        
        requirement <'REQ-002'> detectionCapability : SecuritySystemRequirement {
            doc /* The system shall detect intrusions through motion sensors, door/window sensors, 
                   and provide real-time status updates. */
            
            subject securitySystem;
            
            require constraint sensorCoverage {
                doc /* All entry points and critical zones must have active sensor coverage. */
            }
        }
        
        requirement <'REQ-003'> responseTime : SecuritySystemRequirement {
            doc /* The system shall activate alarms within 2 seconds of confirmed intrusion detection. */
            
            subject securitySystem;
        }
        
        requirement <'REQ-004'> videoRecording : SecuritySystemRequirement {
            doc /* Surveillance cameras shall begin recording immediately upon intrusion detection 
                   and continue for minimum 5 minutes. */
            
            subject securitySystem;
        }
        
        requirement <'REQ-005'> communicationReliability : SecuritySystemRequirement {
            doc /* The system shall successfully transmit alerts to the monitoring station 
                   with 99.9% reliability. */
            
            subject securitySystem;
        }
        
        requirement <'REQ-006'> accessControl : SecuritySystemRequirement {
            doc /* System arming and disarming shall require valid access code authentication. */
            
            subject securitySystem;
            
            require constraint authenticationRequired {
                doc /* All control commands must be authenticated before execution. */
            }
        }
        
        requirement <'REQ-007'> powerResilience : SecuritySystemRequirement {
            doc /* The system shall maintain full operation for minimum 24 hours on backup power 
                   in case of main power failure. */
            
            subject securitySystem;
        }
    }
}
