package HomeSecuritySystem {
    import ScalarValues::*;

    item def SensorSignal;
    item def VideoStream;
    item def Notification;
    item def ArmCommand;
    item def Power;

    unit decibel {
        symbol = "dB";
    }
    unit hour {
        symbol = "h";
    }

    value def SoundLevel :> Real {
        unit decibel;
    }
    value def Duration :> Real {
        unit hour;
    }

    part def Sensor {
        port out sensorSignalOut : SensorSignal;
        attribute triggered : Boolean;
    }

    part def ContactSensor :> Sensor {
        attribute location : String;
    }

    part def MotionDetector :> Sensor {
        attribute location : String;
    }

    part def Camera {
        port in recordingTriggerIn : Boolean;
        port out videoStreamOut : VideoStream;
        attribute hasNightVision : Boolean;
    }

    part def Siren {
        port in triggerIn : Boolean;
        attribute soundLevel : SoundLevel;
    }

    part def CommunicationModule {
        port in notificationIn : Notification;
        port out notificationOut : Notification;
        attribute supportedNetworks : String;
    }

    part def PowerSupplyUnit {
        port out powerOut : Power;
        attribute hasBatteryBackup : Boolean;
        attribute backupDuration : Duration;
    }

    part def ControlHub {
        port in sensorSignalIn : SensorSignal;
        port in cameraStreamIn : VideoStream;
        port in armCommandIn : ArmCommand;
        port out sirenTriggerOut : Boolean;
        port out cameraTriggerOut : Boolean;
        port out notificationOut : Notification;
        port in powerIn : Power;

        attribute isArmed : Boolean;
        attribute accessCode : String;

        state ControlHubBehavior {
            state Disarmed {
                entry { isArmed = false; }
                transition to Armed
                    accept ArmCommand via armCommandIn;
            }
            state Armed {
                entry { isArmed = true; }
                transition to AlarmTriggered
                    accept SensorSignal via sensorSignalIn;
            }
            state AlarmTriggered {
                entry {
                    send true to sirenTriggerOut;
                    send true to cameraTriggerOut;
                    send Notification to notificationOut;
                }
                transition to Disarmed
                    accept ArmCommand via armCommandIn;
            }
        }
    }

    part def HomeSecuritySystem {
        part controlHub : ControlHub;
        part frontDoorSensor : ContactSensor;
        part backDoorSensor : ContactSensor;
        part livingRoomWindowSensor : ContactSensor;
        part masterBedroomWindowSensor : ContactSensor;
        part hallwayMotionDetector : MotionDetector;
        part mainEntryCamera : Camera;
        part backyardCamera : Camera;
        part siren : Siren;
        part commModule : CommunicationModule;
        part powerSupply : PowerSupplyUnit;

        connect controlHub.powerIn to powerSupply.powerOut;
        connect frontDoorSensor.sensorSignalOut to controlHub.sensorSignalIn;
        connect backDoorSensor.sensorSignalOut to controlHub.sensorSignalIn;
        connect livingRoomWindowSensor.sensorSignalOut to controlHub.sensorSignalIn;
        connect masterBedroomWindowSensor.sensorSignalOut to controlHub.sensorSignalIn;
        connect hallwayMotionDetector.sensorSignalOut to controlHub.sensorSignalIn;
        connect mainEntryCamera.videoStreamOut to controlHub.cameraStreamIn;
        connect backyardCamera.videoStreamOut to controlHub.cameraStreamIn;
        connect controlHub.sirenTriggerOut to siren.triggerIn;
        connect controlHub.cameraTriggerOut to mainEntryCamera.recordingTriggerIn;
        connect controlHub.cameraTriggerOut to backyardCamera.recordingTriggerIn;
        connect controlHub.notificationOut to commModule.notificationIn;
    }

    requirement def SystemRequirements {
        requirement powerBackupRequirement {
            doc /* The system shall maintain protection for many hours during a power outage. */
            subject powerSupply : PowerSupplyUnit;
            constraint { powerSupply.backupDuration >= 8 }
        }
        requirement sirenRequirement {
            doc /* The siren shall be high-decibel. */
            subject siren : Siren;
            constraint { siren.soundLevel >= 110 }
        }
        requirement communicationRequirement {
            doc /* The communication module shall operate on WiFi and cellular networks. */
            subject commModule : CommunicationModule;
            constraint { commModule.supportedNetworks == "WiFi, Cellular" }
        }
    }
}
