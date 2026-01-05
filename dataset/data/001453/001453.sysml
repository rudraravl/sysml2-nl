package 'Home Security System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def SecurityMode {
        attribute armed : Boolean;
        attribute entryDelay : TimeValue;
        attribute exitDelay : TimeValue;
    }
    
    attribute def SensorStatus {
        attribute triggered : Boolean;
        attribute location : String;
        attribute timestamp : Real;
    }
    
    attribute def AlarmState {
        attribute active : Boolean;
        attribute level : Integer;
        attribute duration : TimeValue;
    }
    
    item def ElectricalPower;
    item def AudioAlert;
    item def VideoFeed;
    item def NetworkData;
    item def UserCommand;
    
    port def PowerPort {
        in item power : ElectricalPower;
    }
    
    port def SensorDataPort {
        out status : SensorStatus;
    }
    
    port def AlarmControlPort {
        in trigger : Boolean;
        out alert : AudioAlert;
    }
    
    port def NetworkPort {
        out data : NetworkData;
        in command : UserCommand;
    }
    
    port def VideoPort {
        out feed : VideoFeed;
    }
    
    part def DoorSensor {
        port dataOut : SensorDataPort;
        port pwr : PowerPort;
        
        attribute isOpen : Boolean := false;
        attribute sensorLocation : String;
        
        action detectDoorState {
            out doorStatus : SensorStatus;
        }
    }
    
    part def WindowSensor {
        port dataOut : SensorDataPort;
        port pwr : PowerPort;
        
        attribute isOpen : Boolean := false;
        attribute sensorLocation : String;
        
        action detectWindowState {
            out windowStatus : SensorStatus;
        }
    }
    
    part def MotionDetector {
        port dataOut : SensorDataPort;
        port pwr : PowerPort;
        
        attribute detectionRange : LengthValue;
        attribute sensitivity : Real;
        attribute motionDetected : Boolean := false;
        
        action detectMotion {
            out motionStatus : SensorStatus;
        }
    }
    
    part def SurveillanceCamera {
        port videoOut : VideoPort;
        port pwr : PowerPort;
        
        attribute resolution : String;
        attribute frameRate : Real;
        attribute nightVision : Boolean;
        attribute recording : Boolean := false;
        
        action captureVideo {
            in startRecording : Boolean;
            out video : VideoFeed;
        }
    }
    
    part def Siren {
        port control : AlarmControlPort;
        port pwr : PowerPort;
        
        attribute soundLevel : ISQ::SoundPressureLevelValue;
        attribute frequency : Real;
        attribute isActive : Boolean := false;
        
        action activateSiren {
            in trigger : Boolean;
            out sound : AudioAlert;
        }
    }
    
    part def ControlHub {
        port pwr : PowerPort;
        port network : NetworkPort;
        port sensorInput1 : SensorDataPort;
        port sensorInput2 : SensorDataPort;
        port sensorInput3 : SensorDataPort;
        port sensorInput4 : SensorDataPort;
        port alarmControl : AlarmControlPort;
        
        attribute systemMode : SecurityMode;
        attribute accessCode : String;
        attribute intrusionDetected : Boolean := false;
        
        action processUserInput {
            in userCmd : UserCommand;
            out modeChange : SecurityMode;
        }
        
        action evaluateThreat {
            in sensor1 : SensorStatus;
            in sensor2 : SensorStatus;
            in sensor3 : SensorStatus;
            in sensor4 : SensorStatus;
            out threatLevel : Integer;
            out activateAlarm : Boolean;
        }
        
        action sendNotification {
            in alarmState : AlarmState;
            out notification : NetworkData;
        }
    }
    
    part def CommunicationModule {
        port network : NetworkPort;
        port pwr : PowerPort;
        
        attribute connectionType : String;
        attribute signalStrength : Real;
        
        action transmitAlert {
            in alertData : NetworkData;
            out transmitted : Boolean;
        }
        
        action receiveCommand {
            out command : UserCommand;
        }
    }
    
    part def PowerSupply {
        port mainPower : PowerPort;
        
        attribute voltage : ISQ::VoltageValue;
        attribute current : ISQ::CurrentValue;
        attribute batteryBackup : Boolean;
        attribute backupCapacity : ISQ::ElectricChargeValue;
    }
    
    action def MonitorPerimeter {
        in doorStatus : SensorStatus;
        in windowStatus : SensorStatus;
        in motionStatus : SensorStatus;
        out breachDetected : Boolean;
        out breachLocation : String;
    }
    
    action def ActivateAlarmSequence {
        in breachDetected : Boolean;
        in systemArmed : Boolean;
        out sirenActivated : Boolean;
        out cameraRecording : Boolean;
        out notificationSent : Boolean;
    }
    
    action def RecordEvidence {
        in trigger : Boolean;
        in videoFeed : VideoFeed;
        out evidenceStored : Boolean;
    }
    
    action def NotifyAuthorities {
        in alarmActive : Boolean;
        in location : String;
        out authoritiesContacted : Boolean;
    }
    
    part def HomeSecuritySystem {
        doc /* 
            A comprehensive home security system that protects residential property through 
            continuous monitoring and automated threat response.
            
            Primary Function:
            The system continuously monitors all entry points (doors and windows) and interior 
            spaces using multiple sensor types including contact sensors and motion detectors. 
            When the system is armed and unauthorized access or suspicious activity is detected, 
            it immediately executes a coordinated response: activating high-decibel audible alarms 
            to deter intruders, automatically recording video evidence from surveillance cameras, 
            and transmitting real-time notifications to homeowners and professional monitoring 
            services. The system operates 24/7 with battery backup to ensure uninterrupted 
            protection even during power outages, providing comprehensive security, rapid threat 
            detection, and peace of mind for homeowners.
        */
        
        attribute detectionResponseTime : Real;
        attribute alarmActivationTime : Real;
        attribute alarmSoundLevel : Real;
        attribute notificationTime : Real;
        attribute minimumRecordingDuration : Real;
        attribute backupOperationTime : Real;
    }
    
    requirement def SecuritySystemRequirement {
        doc /* Base requirement for home security system capabilities. */
    }
    
    requirement <'HSS-001'> intrusionDetectionRequirement : SecuritySystemRequirement {
        doc /* The system shall detect unauthorized entry through doors, windows, or motion within 1 second of occurrence. */
        
        subject securitySystem;
        
        require constraint {
            securitySystem.detectionResponseTime <= 1.0
        }
    }
    
    requirement <'HSS-002'> alarmActivationRequirement : SecuritySystemRequirement {
        doc /* The system shall activate audible alarm at minimum 100 dB within 3 seconds of intrusion detection when armed. */
        
        subject securitySystem;
        
        require constraint {
            securitySystem.alarmActivationTime <= 3.0 and
            securitySystem.alarmSoundLevel >= 100.0
        }
    }
    
    requirement <'HSS-003'> notificationRequirement : SecuritySystemRequirement {
        doc /* The system shall send notification to homeowner and monitoring service within 5 seconds of alarm activation. */
        
        subject securitySystem;
        
        require constraint {
            securitySystem.notificationTime <= 5.0
        }
    }
    
    requirement <'HSS-004'> videoRecordingRequirement : SecuritySystemRequirement {
        doc /* The system shall automatically begin recording video from all cameras upon intrusion detection and continue for minimum 5 minutes. */
        
        subject securitySystem;
        
        require constraint {
            securitySystem.minimumRecordingDuration >= 300.0
        }
    }
    
    requirement <'HSS-005'> powerBackupRequirement : SecuritySystemRequirement {
        doc /* The system shall maintain full operation for minimum 12 hours during power outage using battery backup. */
        
        subject securitySystem;
        
        require constraint {
            securitySystem.backupOperationTime >= 12.0
        }
    }
    
    part securitySystem : HomeSecuritySystem {
        attribute :>> detectionResponseTime = 0.5;
        attribute :>> alarmActivationTime = 2.0;
        attribute :>> alarmSoundLevel = 110.0;
        attribute :>> notificationTime = 3.0;
        attribute :>> minimumRecordingDuration = 300.0;
        attribute :>> backupOperationTime = 12.0;
        
        part frontDoor : DoorSensor {
            attribute :>> sensorLocation = "Front Entry";
        }
        
        part backDoor : DoorSensor {
            attribute :>> sensorLocation = "Rear Entry";
        }
        
        part livingRoomWindow : WindowSensor {
            attribute :>> sensorLocation = "Living Room";
        }
        
        part bedroomWindow : WindowSensor {
            attribute :>> sensorLocation = "Master Bedroom";
        }
        
        part hallwayMotion : MotionDetector {
            attribute :>> detectionRange = 10.0[m];
            attribute :>> sensitivity = 0.8;
        }
        
        part entryCamera : SurveillanceCamera {
            attribute :>> resolution = "1920x1080";
            attribute :>> frameRate = 30.0;
            attribute :>> nightVision = true;
        }
        
        part backyardCamera : SurveillanceCamera {
            attribute :>> resolution = "1920x1080";
            attribute :>> frameRate = 30.0;
            attribute :>> nightVision = true;
        }
        
        part mainSiren : Siren {
            attribute :>> soundLevel = 110.0[dB];
            attribute :>> frequency = 3000.0;
        }
        
        part hub : ControlHub {
            attribute :>> accessCode = "****";
        }
        
        part commModule : CommunicationModule {
            attribute :>> connectionType = "Cellular/WiFi";
            attribute :>> signalStrength = 0.95;
        }
        
        part powerUnit : PowerSupply {
            attribute :>> voltage = 12.0[V];
            attribute :>> current = 5.0[A];
            attribute :>> batteryBackup = true;
            attribute :>> backupCapacity = 50.0[A*h];
        }
        
        connection frontDoorConnection connect frontDoor.dataOut to hub.sensorInput1;
        connection backDoorConnection connect backDoor.dataOut to hub.sensorInput2;
        connection windowConnection connect livingRoomWindow.dataOut to hub.sensorInput3;
        connection motionConnection connect hallwayMotion.dataOut to hub.sensorInput4;
        connection sirenConnection connect hub.alarmControl to mainSiren.control;
        connection networkConnection connect hub.network to commModule.network;
        
        connection powerDistribution1 connect powerUnit.mainPower to hub.pwr;
        connection powerDistribution2 connect powerUnit.mainPower to frontDoor.pwr;
        connection powerDistribution3 connect powerUnit.mainPower to backDoor.pwr;
        connection powerDistribution4 connect powerUnit.mainPower to livingRoomWindow.pwr;
        connection powerDistribution5 connect powerUnit.mainPower to bedroomWindow.pwr;
        connection powerDistribution6 connect powerUnit.mainPower to hallwayMotion.pwr;
        connection powerDistribution7 connect powerUnit.mainPower to entryCamera.pwr;
        connection powerDistribution8 connect powerUnit.mainPower to backyardCamera.pwr;
        connection powerDistribution9 connect powerUnit.mainPower to mainSiren.pwr;
        connection powerDistribution10 connect powerUnit.mainPower to commModule.pwr;
        
        perform action protectHome {
            first start;
            then merge monitoringCycle;
            then action initializeSystem {
                action powerOnComponents;
                then action setInitialMode;
            }
            then monitoringCycle;
            action monitoringCycle {
                loop {
                    action collectSensorData;
                    then action analyzeSensorData : MonitorPerimeter {
                        in doorStatus;
                        in windowStatus;
                        in motionStatus;
                        out breachDetected;
                        out breachLocation;
                    }
                    then decide;
                        if analyzeSensorData.breachDetected then respondToIntrusion;
                    action respondToIntrusion {
                        action executeAlarmSequence : ActivateAlarmSequence {
                            in breachDetected = analyzeSensorData.breachDetected;
                            in systemArmed = true;
                            out sirenActivated;
                            out cameraRecording;
                            out notificationSent;
                        }
                        then action parallel {
                            action soundAlarm {
                                perform mainSiren.activateSiren;
                            }
                            action recordIncident {
                                perform entryCamera.captureVideo;
                                perform backyardCamera.captureVideo;
                            }
                            action alertStakeholders {
                                perform hub.sendNotification;
                            }
                        }
                    }
                }
            }
        }
    }
}
