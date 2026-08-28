package AugustHomeSmartLock {
    private import ISQ::*;
    private import ScalarValues::*;

    package Definitions {
        enum def CommandKind { lock; unlock; }
        enum def CommandSource { mobileApp; geoFence; voiceAssistant; }
        enum def BoltStateKind { locked; unlocked; jammed; }
        enum def DoorStateKind { open; closed; ajar; }
        enum def AlertType { jammedBolt; lowBattery; authenticationFailed; }

        item def LockCommand {
            attribute command : CommandKind;
            attribute source : CommandSource;
            attribute token : String;
        }

        item def LockStatus {
            attribute boltState : BoltStateKind;
            attribute doorState : DoorStateKind;
            attribute batteryLevel : Real;
        }

        item def Alert {
            attribute alertType : AlertType;
            attribute alertText : String;
        }

        item def MotorSignal {
            attribute direction : CommandKind;
        }

        item def ActivityLogEntry {
            attribute timestamp : String;
            attribute actionName : String;
            attribute result : String;
        }

        port def CommandPort { in cmd : LockCommand; }
        port def StatusPort { out status : LockStatus; out alert : Alert; }
        port def BoltSensorPort { out boltState : BoltStateKind; }
        port def DoorSensorPort { out doorState : DoorStateKind; }
        port def MotorPort { out motorCmd : MotorSignal; }
        port def BatteryPort { out level : Real; }

        action def AuthenticateCommand;
        action def LogActivity;
        action def MonitorBattery;
        action def DriveMotor;
        action def SendAlert;

        part def SmartController {
            port cmdIn : CommandPort;
            port statusOut : StatusPort;
            port motorOut : MotorPort;
            port boltSensorIn : ~BoltSensorPort;
            port doorSensorIn : ~DoorSensorPort;
            port batteryIn : ~BatteryPort;
            port btIn : CommandPort;
            port wifiIn : CommandPort;
        }

        part def BluetoothModule {
            port btOut : ~CommandPort;
        }

        part def WiFiModule {
            port wifiOut : ~CommandPort;
        }

        part def Motor {
            port driveIn : ~MotorPort;
        }

        part def DeadboltAssembly {
            part motor : Motor;
            attribute boltState : BoltStateKind;
            port motorIn : ~MotorPort;
            port boltPosOut : BoltSensorPort;
        }

        part def BoltPositionSensor {
            attribute boltState : BoltStateKind;
            port readingOut : BoltSensorPort;
        }

        part def DoorPositionSensor {
            attribute doorState : DoorStateKind;
            port readingOut : DoorSensorPort;
        }

        part def BatteryPack {
            attribute currentLevel : Real = 100.0;
            port levelOut : BatteryPort;
        }

        part def UserSmartphone {
            port btPort : ~CommandPort;
        }

        part def HomeRouter {
            port wifiPort : ~CommandPort;
        }

        part def SmartLockUnit {
            part controller : SmartController;
            part bluetooth : BluetoothModule;
            part wifi : WiFiModule;
            part deadbolt : DeadboltAssembly;
            part battery : BatteryPack;
            part boltSensor : BoltPositionSensor;
            part doorSensor : DoorPositionSensor;

            port cmdPort : CommandPort;
            port statusPort : StatusPort;

            attribute activityLog : ActivityLogEntry[0..*];
            attribute lowBatteryThreshold : Real = 15.0;

            perform action authenticate : AuthenticateCommand;
            perform action logActivity : LogActivity;
            perform action monitorBattery : MonitorBattery;
            perform action driveMotor : DriveMotor;
            perform action sendAlert : SendAlert;

            connect bluetooth.btOut to controller.btIn;
            connect wifi.wifiOut to controller.wifiIn;
            connect controller.motorOut to deadbolt.motorIn;
            connect deadbolt.boltPosOut to controller.boltSensorIn;
            connect boltSensor.readingOut to controller.boltSensorIn;
            connect doorSensor.readingOut to controller.doorSensorIn;
            connect battery.levelOut to controller.batteryIn;
            connect controller.cmdIn to cmdPort;
            connect controller.statusOut to statusPort;

            exhibit state lockStates parallel {
                state operationalStates {
                    entry; then locked;
                    state locked;
                    accept cmd : LockCommand via cmdPort
                        if cmd.command == CommandKind::unlock
                        do authenticate
                        then unlocking;
                    state unlocking;
                    accept when boltSensor.boltState == BoltStateKind::unlocked
                        then unlocked;
                    accept when deadbolt.boltState == BoltStateKind::jammed
                        do sendAlert
                        then jammed;
                    state unlocked;
                    accept cmd : LockCommand via cmdPort
                        if cmd.command == CommandKind::lock
                        do authenticate
                        then locking;
                    accept when doorSensor.doorState == DoorStateKind::closed
                        then locking;
                    state locking;
                    accept when boltSensor.boltState == BoltStateKind::locked
                        then locked;
                    accept when deadbolt.boltState == BoltStateKind::jammed
                        do sendAlert
                        then jammed;
                    state jammed;
                    accept cmd : LockCommand via cmdPort
                        if cmd.command == CommandKind::unlock
                        do authenticate
                        then unlocking;
                }
                state healthStates {
                    entry; then normal;
                    state normal {
                        do monitorBattery;
                    }
                    accept when battery.currentLevel <= lowBatteryThreshold
                        do sendAlert
                        then lowBattery;
                    state lowBattery;
                    accept when battery.currentLevel > lowBatteryThreshold
                        then normal;
                }
            }
        }

        requirement def SecureKeylessAccess {
            doc /* The system shall provide secure, keyless access authenticated via token. */
        }

        requirement def AutoLockAfterDoorShut {
            doc /* The system shall automatically lock the deadbolt when the door is closed. */
        }

        requirement def JammedDetection {
            doc /* The system shall detect a jammed deadbolt and alert the user. */
        }

        requirement def BatteryMonitoring {
            doc /* The system shall monitor battery level and alert the user when below 15 percent threshold. */
        }

        requirement def ActivityLogging {
            doc /* The system shall log all lock and unlock events and state changes with timestamps. */
        }
    }

    package Usages {
        private import Definitions::*;

        part augustLock : SmartLockUnit;

        part userPhone : UserSmartphone;
        part homeRouter : HomeRouter;

        connect userPhone.btPort to augustLock.cmdPort;
        connect homeRouter.wifiPort to augustLock.cmdPort;

        satisfy SecureKeylessAccess by augustLock.authenticate;
        satisfy AutoLockAfterDoorShut by augustLock;
        satisfy JammedDetection by augustLock;
        satisfy BatteryMonitoring by augustLock.monitorBattery;
        satisfy ActivityLogging by augustLock.logActivity;
    }
}
