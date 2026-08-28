package HomeSecuritySystem {
    private import ScalarValues::*;
    private import ISQ::*;

    package Definitions {
        package ItemDefinitions {
            item def SensorSignal {
                attribute sensorId : String;
                attribute triggered : Boolean;
            }
            item def AlarmCommand {
                attribute activate : Boolean;
            }
            item def CameraCommand {
                attribute record : Boolean;
            }
            item def Notification {
                attribute text : String;
                attribute priority : String;
            }
            item def VideoStream {
                attribute cameraId : String;
                attribute recording : Boolean;
            }
            item def Power {
                attribute voltage : Real;
                attribute fromBattery : Boolean;
            }
            item def ArmCommand {
                attribute armed : Boolean;
                attribute accessCode : String;
            }
            item def DisarmCommand {
                attribute accessCode : String;
            }
            item def RemoteCommand {
                attribute command : String;
                attribute accessCode : String;
            }
        }

        package PortDefinitions {
            private import ItemDefinitions::*;
            port def SensorPort {
                in item signal : SensorSignal;
            }
            port def CameraControlPort {
                out item command : CameraCommand;
                in item stream : VideoStream;
            }
            port def SirenPort {
                out item command : AlarmCommand;
            }
            port def CommPort {
                out item notification : Notification;
                in item remoteCommand : RemoteCommand;
            }
            port def PowerPort {
                out item power : Power;
            }
            port def UserInterfacePort {
                in item armCmd : ArmCommand;
                in item disarmCmd : DisarmCommand;
            }
        }

        package PartDefinitions {
            private import ItemDefinitions::*;
            private import PortDefinitions::*;

            action def TriggerAlarmSequence;

            part def ControlHub {
                port sensorPort1 : SensorPort;
                port sensorPort2 : SensorPort;
                port sensorPort3 : SensorPort;
                port sensorPort4 : SensorPort;
                port sensorPort5 : SensorPort;
                port cameraControlPort1 : CameraControlPort;
                port cameraControlPort2 : CameraControlPort;
                port sirenPort : SirenPort;
                port commPort : CommPort;
                port uiPort : UserInterfacePort;
                port powerPort : ~PowerPort;

                perform action triggerAlarm : TriggerAlarmSequence {
                    send new AlarmCommand(true) to sirenPort;
                    send new CameraCommand(true) to cameraControlPort1;
                    send new CameraCommand(true) to cameraControlPort2;
                    send new Notification("Intrusion detected", "high") to commPort;
                }

                exhibit state hubStates {
                    transition initial then disarmed;
                    state disarmed;
                    state armed;
                    state alarmTriggered {
                        entry triggerAlarm;
                    }
                    transition disarmed_to_armed
                        first disarmed
                        accept armCmd : ArmCommand via uiPort
                        if armCmd.armed == true and armCmd.accessCode == "1234"
                        then armed;
                    transition armed_to_disarmed
                        first armed
                        accept disarmCmd : DisarmCommand via uiPort
                        if disarmCmd.accessCode == "1234"
                        then disarmed;
                    transition armed_to_alarm1
                        first armed
                        accept sig : SensorSignal via sensorPort1
                        if sig.triggered == true
                        then alarmTriggered;
                    transition armed_to_alarm2
                        first armed
                        accept sig : SensorSignal via sensorPort2
                        if sig.triggered == true
                        then alarmTriggered;
                    transition armed_to_alarm3
                        first armed
                        accept sig : SensorSignal via sensorPort3
                        if sig.triggered == true
                        then alarmTriggered;
                    transition armed_to_alarm4
                        first armed
                        accept sig : SensorSignal via sensorPort4
                        if sig.triggered == true
                        then alarmTriggered;
                    transition armed_to_alarm5
                        first armed
                        accept sig : SensorSignal via sensorPort5
                        if sig.triggered == true
                        then alarmTriggered;
                    transition alarm_to_disarmed
                        first alarmTriggered
                        accept disarmCmd : DisarmCommand via uiPort
                        if disarmCmd.accessCode == "1234"
                        then disarmed;
                    transition alarm_remote_disarm
                        first alarmTriggered
                        accept rc : RemoteCommand via commPort
                        if rc.command == "disarm" and rc.accessCode == "1234"
                        then disarmed;
                }
            }

            part def ContactSensor {
                port sensorPort : ~SensorPort;
                port powerPort : ~PowerPort;
                attribute location : String;
                attribute sensorId : String;
            }

            part def MotionDetector {
                port sensorPort : ~SensorPort;
                port powerPort : ~PowerPort;
                attribute location : String;
                attribute sensorId : String;
            }

            part def Camera {
                port cameraControlPort : ~CameraControlPort;
                port powerPort : ~PowerPort;
                attribute hasNightVision : Boolean = true;
                attribute location : String;
                attribute cameraId : String;
                exhibit state cameraState {
                    transition initial then standby;
                    state standby;
                    state recording;
                    transition startRecord
                        first standby
                        accept cmd : CameraCommand via cameraControlPort
                        if cmd.record == true
                        then recording;
                    transition stopRecord
                        first recording
                        accept cmd : CameraCommand via cameraControlPort
                        if cmd.record == false
                        then standby;
                }
            }

            part def Siren {
                port sirenPort : ~SirenPort;
                port powerPort : ~PowerPort;
                attribute decibelLevel : Integer = 110;
                exhibit state sirenState {
                    transition initial then idle;
                    state idle;
                    state sounding;
                    transition startSiren
                        first idle
                        accept cmd : AlarmCommand via sirenPort
                        if cmd.activate == true
                        then sounding;
                    transition stopSiren
                        first sounding
                        accept cmd : AlarmCommand via sirenPort
                        if cmd.activate == false
                        then idle;
                }
            }

            part def CommunicationModule {
                port commPort : ~CommPort;
                port powerPort : ~PowerPort;
                attribute supportsWiFi : Boolean = true;
                attribute supportsCellular : Boolean = true;
                exhibit state commState {
                    transition initial then idle;
                    state idle;
                    state transmitting;
                    transition transmit
                        first idle
                        accept msg : Notification via commPort
                        then transmitting;
                    transition returnToIdle
                        first transmitting
                        then idle;
                }
            }

            part def PowerSupplyUnit {
                port powerPort : PowerPort;
                attribute mainVoltage : Real = 120.0;
                attribute batteryBackupHours : Integer = 24;
                attribute batteryLevel : Real = 100.0;
                exhibit state powerState {
                    transition initial then mainsPower;
                    state mainsPower;
                    state batteryPower;
                }
            }
        }
    }

    package Usages {
        private import Definitions::**;

        part homeSecuritySystem {
            part controlHub : ControlHub;

            part frontDoorSensor : ContactSensor {
                :>> location = "Front Door";
                :>> sensorId = "FD-001";
            }
            part backDoorSensor : ContactSensor {
                :>> location = "Back Door";
                :>> sensorId = "BD-001";
            }
            part livingRoomWindowSensor : ContactSensor {
                :>> location = "Living Room Window";
                :>> sensorId = "LRW-001";
            }
            part masterBedroomWindowSensor : ContactSensor {
                :>> location = "Master Bedroom Window";
                :>> sensorId = "MBW-001";
            }
            part hallwayMotionDetector : MotionDetector {
                :>> location = "Hallway";
                :>> sensorId = "MD-001";
            }

            part mainEntryCamera : Camera {
                :>> location = "Main Entry";
                :>> cameraId = "CAM-001";
                :>> hasNightVision = true;
            }
            part backyardCamera : Camera {
                :>> location = "Backyard";
                :>> cameraId = "CAM-002";
                :>> hasNightVision = true;
            }

            part siren : Siren;
            part communicationModule : CommunicationModule;
            part powerSupplyUnit : PowerSupplyUnit;

            connect frontDoorSensor.sensorPort to controlHub.sensorPort1;
            connect backDoorSensor.sensorPort to controlHub.sensorPort2;
            connect livingRoomWindowSensor.sensorPort to controlHub.sensorPort3;
            connect masterBedroomWindowSensor.sensorPort to controlHub.sensorPort4;
            connect hallwayMotionDetector.sensorPort to controlHub.sensorPort5;

            connect controlHub.cameraControlPort1 to mainEntryCamera.cameraControlPort;
            connect controlHub.cameraControlPort2 to backyardCamera.cameraControlPort;

            connect controlHub.sirenPort to siren.sirenPort;
            connect controlHub.commPort to communicationModule.commPort;

            connect powerSupplyUnit.powerPort to controlHub.powerPort;
            connect powerSupplyUnit.powerPort to siren.powerPort;
            connect powerSupplyUnit.powerPort to communicationModule.powerPort;
            connect powerSupplyUnit.powerPort to mainEntryCamera.powerPort;
            connect powerSupplyUnit.powerPort to backyardCamera.powerPort;
            connect powerSupplyUnit.powerPort to frontDoorSensor.powerPort;
            connect powerSupplyUnit.powerPort to backDoorSensor.powerPort;
            connect powerSupplyUnit.powerPort to livingRoomWindowSensor.powerPort;
            connect powerSupplyUnit.powerPort to masterBedroomWindowSensor.powerPort;
            connect powerSupplyUnit.powerPort to hallwayMotionDetector.powerPort;
        }
    }

    package Requirements {
        requirement def ContinuousMonitoring {
            doc /* The system shall continuously monitor all entry points and hallway for intrusions. */
        }
        requirement def AlarmResponse {
            doc /* Upon confirmed intrusion, the system shall activate the siren, start camera recording, and send notifications. */
        }
        requirement def BackupPower {
            doc /* The system shall operate on battery backup for at least 24 hours after a main power failure. */
        }
        requirement def UserArmDisarm {
            doc /* The user shall be able to arm or disarm the system using an access code or remote command. */
        }
        requirement def NightVisionSurveillance {
            doc /* All cameras shall support night vision for 24/7 monitoring capability. */
        }
    }
}
