package VivintSmartHomeSecuritySystem {
    private import ISQ::*;
    private import ScalarValues::*;

    package Definitions {
        item def Power;
        item def VideoStream;
        item def AlertSignal;
        item def SensorTrigger;
        item def LockCommand;
        item def SystemCommand;
        item def UserNotification;

        port def WirelessPort {
            in item trigger: SensorTrigger;
            out item alert: AlertSignal;
            out item video: VideoStream;
            out item lockCmd: LockCommand;
        }
        port def CloudPort {
            in item alert: AlertSignal;
            in item video: VideoStream;
            out item command: SystemCommand;
            out item notification: UserNotification;
        }
        port def PowerPort {
            out item power: Power;
        }

        action def EvaluateThreat;
        action def ActivateSirens;
        action def StartRecording;
        action def SendAlert;
        action def MonitorSensors;
        action def LockAllDoors;

        part def BackupBattery {
            attribute capacity :> ISQ::energy;
            port powerOut: PowerPort;
        }

        part def CentralHub {
            attribute backupBatteryCapacity :> ISQ::energy;
            port wirelessPort: WirelessPort;
            port cloudPort: CloudPort;
            port powerPort: PowerPort;
            
            exhibit state systemModes {
                entry; then Disarmed;
                state Disarmed;
                state Armed {
                    entry lockAllDoors;
                    do monitorSensors;
                }
                state AlarmTriggered {
                    entry {
                        activateSirens;
                        startRecording;
                    }
                    do sendAlert;
                }
                transition Disarmed_to_Armed
                    first Disarmed
                    accept SystemCommand
                    then Armed;
                transition Armed_to_Disarmed
                    first Armed
                    accept SystemCommand
                    then Disarmed;
                transition Armed_to_AlarmTriggered
                    first Armed
                    accept SensorTrigger
                    do evaluateThreat
                    then AlarmTriggered;
                transition AlarmTriggered_to_Disarmed
                    first AlarmTriggered
                    accept SystemCommand
                    then Disarmed;
            }
            perform action evaluateThreat: EvaluateThreat;
            perform action activateSirens: ActivateSirens;
            perform action startRecording: StartRecording;
            perform action sendAlert: SendAlert;
            perform action monitorSensors: MonitorSensors;
            perform action lockAllDoors: LockAllDoors;
            
            part backupBattery : BackupBattery;
        }
        
        part def ContactSensor {
            port wirelessPort: ~WirelessPort;
            attribute location : String;
        }
        
        part def MotionSensor {
            port wirelessPort: ~WirelessPort;
            attribute location : String;
        }
        
        part def SmartCamera {
            port wirelessPort: ~WirelessPort;
            attribute hasNightVision : Boolean;
            perform action recordVideo;
        }
        
        part def SmartDoorbell {
            port wirelessPort: ~WirelessPort;
            perform action streamVideo;
        }
        
        part def Siren {
            port wirelessPort: ~WirelessPort;
            attribute hasStrobe : Boolean;
            perform action soundAlarm;
        }
        
        part def SmartLock {
            port wirelessPort: ~WirelessPort;
            perform action lock;
            perform action unlock;
        }
        
        part def ControlPanel {
            port wirelessPort: ~WirelessPort;
            attribute isTouchscreen : Boolean;
        }
        
        part def CloudService {
            port cloudPort: ~CloudPort;
            perform action sendNotification;
            perform action storeData;
        }
        
        part def MobileDevice {
            port cloudPort: ~CloudPort;
            perform action receiveNotification;
        }
    }
    
    package Usages {
        private import Definitions::*;
        
        part vivintSystem {
            part hub : CentralHub;
            part panel : ControlPanel {
                :>> isTouchscreen = true;
            }
            part cloud : CloudService;
            part mobile : MobileDevice;
            
            part sensors {
                part frontDoorContact : ContactSensor { :>> location = "Front Door"; }
                part backDoorContact : ContactSensor { :>> location = "Back Door"; }
                part garageDoorContact : ContactSensor { :>> location = "Garage Door"; }
                part windowContact : ContactSensor { :>> location = "Window"; }
                part livingRoomMotion : MotionSensor { :>> location = "Living Room"; }
                part hallwayMotion : MotionSensor { :>> location = "Hallway"; }
                part basementMotion : MotionSensor { :>> location = "Basement"; }
            }
            
            part cameras {
                part outdoorCamera : SmartCamera { :>> hasNightVision = true; }
                part doorbellCamera : SmartDoorbell;
            }
            
            part sirens {
                part indoorSiren : Siren { :>> hasStrobe = true; }
                part outdoorSiren : Siren { :>> hasStrobe = true; }
            }
            
            part locks {
                part frontDoorLock : SmartLock;
                part backDoorLock : SmartLock;
                part garageDoorLock : SmartLock;
            }
            
            connect hub.wirelessPort to panel.wirelessPort;
            connect hub.wirelessPort to sensors.frontDoorContact.wirelessPort;
            connect hub.wirelessPort to sensors.backDoorContact.wirelessPort;
            connect hub.wirelessPort to sensors.garageDoorContact.wirelessPort;
            connect hub.wirelessPort to sensors.windowContact.wirelessPort;
            connect hub.wirelessPort to sensors.livingRoomMotion.wirelessPort;
            connect hub.wirelessPort to sensors.hallwayMotion.wirelessPort;
            connect hub.wirelessPort to sensors.basementMotion.wirelessPort;
            connect hub.wirelessPort to cameras.outdoorCamera.wirelessPort;
            connect hub.wirelessPort to cameras.doorbellCamera.wirelessPort;
            connect hub.wirelessPort to sirens.indoorSiren.wirelessPort;
            connect hub.wirelessPort to sirens.outdoorSiren.wirelessPort;
            connect hub.wirelessPort to locks.frontDoorLock.wirelessPort;
            connect hub.wirelessPort to locks.backDoorLock.wirelessPort;
            connect hub.wirelessPort to locks.garageDoorLock.wirelessPort;
            connect hub.cloudPort to cloud.cloudPort;
            connect cloud.cloudPort to mobile.cloudPort;
            connect hub.backupBattery.powerOut to hub.powerPort;
        }
    }
    
    package Requirements {
        private import Definitions::*;
        private import Usages::*;
        
        requirement def SecurityRequirement {
            subject system : CentralHub;
            doc "The system shall monitor sensors and trigger alarms when armed.";
        }
        
        requirement def RemoteAccessRequirement {
            subject cloud : CloudService;
            doc "Users shall be able to arm/disarm the system, view live video, and receive notifications via the cloud service.";
        }
        
        requirement def BackupPowerRequirement {
            subject battery : BackupBattery;
            doc "The central hub shall maintain full operation for at least 24 hours during a power outage using its backup battery.";
        }
        
        requirement securityReq : SecurityRequirement;
        requirement remoteAccessReq : RemoteAccessRequirement;
        requirement backupPowerReq : BackupPowerRequirement;
    }
}
