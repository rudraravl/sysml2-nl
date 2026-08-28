package XiaomiSmartHomeSystem {
    public import ISQ::*;
    public import ScalarValues::*;
    public import Time::*;

    package Definitions {
        public import ItemDefinitions::*;
        public import PortDefinitions::*;
        public import ActionDefinitions::*;
        public import PartDefinitions::*;
        public import RequirementDefinitions::*;

        package ItemDefinitions {
            public import ISQ::*;
            public import ScalarValues::*;
            public import Time::*;

            item def TemperatureHumidityData {
                attribute temperature :> ISQ::temperature;
                attribute humidity : Real;
                attribute timestamp : Time::DateTime;
            }
            item def MotionData {
                attribute detected : Boolean;
                attribute timestamp : Time::DateTime;
            }
            item def DoorWindowState {
                attribute isOpen : Boolean;
                attribute timestamp : Time::DateTime;
            }
            item def BrightnessCmd {
                attribute level : Real;
            }
            item def ColorCmd {
                attribute red : Real;
                attribute green : Real;
                attribute blue : Real;
            }
            item def PowerStateCmd {
                attribute on : Boolean;
            }
            item def TargetTempCmd {
                attribute target :> ISQ::temperature;
            }
            item def RecordCmd {
                attribute record : Boolean;
            }
            item def PowerUsageData {
                attribute usage :> ISQ::power;
                attribute timestamp : Time::DateTime;
            }
            item def VideoStream {
                attribute frameData : String;
                attribute timestamp : Time::DateTime;
            }
            item def NotificationMsg {
                attribute text : String;
                attribute severity : String;
                attribute timestamp : Time::DateTime;
            }
            item def AutomationRule {
                attribute name : String;
                attribute condition : String;
                attribute actionSpec : String;
                attribute enabled : Boolean;
            }
            item def IntrusionEvent {
                attribute source : String;
                attribute timestamp : Time::DateTime;
            }

            attribute def ArmAwaySignal;
            attribute def DisarmSignal;
            attribute def ResetSignal;
            attribute def IntrusionSignal;
        }

        package PortDefinitions {
            public import ItemDefinitions::*;

            port def ZigbeeSensorPort {
                out tempHumidityData : TemperatureHumidityData;
                out motionData : MotionData;
                out doorState : DoorWindowState;
            }
            port def ZigbeeActuatorPort {
                in brightnessCmd : BrightnessCmd;
                in colorCmd : ColorCmd;
                in powerStateCmd : PowerStateCmd;
                in targetTempCmd : TargetTempCmd;
                in recordCmd : RecordCmd;
                out powerUsage : PowerUsageData;
                out videoStream : VideoStream;
            }
            port def WiFiPort {
                in armAwaySignal : ArmAwaySignal;
                in disarmSignal : DisarmSignal;
                in resetSignal : ResetSignal;
                in automationRule : AutomationRule;
                out notification : NotificationMsg;
                out videoStream : VideoStream;
            }
        }

        package ActionDefinitions {
            public import ItemDefinitions::*;

            action def MonitorEnvironment {
                in sensorData : TemperatureHumidityData;
                in motionData : MotionData;
                in doorState : DoorWindowState;
                out intrusionDetected : Boolean;
            }
            action def ExecuteAutomation {
                in rules : AutomationRule[*];
                out brightnessCmd : BrightnessCmd;
                out powerStateCmd : PowerStateCmd;
                out targetTempCmd : TargetTempCmd;
            }
            action def TriggerAlarm {
                out alarmActive : Boolean;
            }
            action def NotifyUser {
                out message : NotificationMsg;
            }
            action def RecordVideo {
                out stream : VideoStream;
            }
            action def AdjustLighting {
                in brightnessCmd : BrightnessCmd;
                in colorCmd : ColorCmd;
            }
            action def ControlAppliance {
                in powerStateCmd : PowerStateCmd;
                out powerUsage : PowerUsageData;
            }
            action def RegulateClimate {
                in targetTempCmd : TargetTempCmd;
            }
            action def SenseClimate {
                out data : TemperatureHumidityData;
            }
            action def DetectMotion {
                out data : MotionData;
            }
            action def DetectState {
                out data : DoorWindowState;
            }
            action def SendArmCommand {
                out signal : ArmAwaySignal;
            }
            action def SendDisarmCommand {
                out signal : DisarmSignal;
            }
            action def DisplayNotification {
                in message : NotificationMsg;
            }
        }

        package PartDefinitions {
            public import ItemDefinitions::*;
            public import PortDefinitions::*;
            public import ActionDefinitions::*;

            part def MiGateway {
                port wifiPort : WiFiPort;
                port zigbeeSensorPort : ~ZigbeeSensorPort;
                port zigbeeActuatorPort : ~ZigbeeActuatorPort;
                attribute automationRules : AutomationRule[*];
                attribute currentMode : String;
                attribute location : String;

                perform action monitorEnvironment : MonitorEnvironment;
                perform action executeAutomation : ExecuteAutomation;
                perform action triggerAlarm : TriggerAlarm;
                perform action notifyUser : NotifyUser;
                perform action recordVideo : RecordVideo;

                exhibit state systemStates {
                    entry; then normal;
                    state normal {
                        do monitorEnvironment;
                        do executeAutomation;
                    }
                    transition normal_to_armedAway
                        first normal
                        accept ArmAwaySignal via wifiPort
                        then armedAway;
                    state armedAway {
                        do monitorEnvironment;
                    }
                    transition armedAway_to_alarm
                        first armedAway
                        accept IntrusionSignal
                        then alarm;
                    state alarm {
                        entry triggerAlarm;
                        do recordVideo;
                        do notifyUser;
                    }
                    transition alarm_to_normal
                        first alarm
                        accept DisarmSignal via wifiPort
                        then normal;
                    transition armedAway_to_normal
                        first armedAway
                        accept DisarmSignal via wifiPort
                        then normal;
                }
            }

            part def TemperatureHumiditySensor {
                port zigbeePort : ZigbeeSensorPort;
                attribute batteryLevel : Real;
                attribute location : String;
                perform action senseClimate : SenseClimate;
            }

            part def MotionSensor {
                port zigbeePort : ZigbeeSensorPort;
                attribute batteryLevel : Real;
                attribute location : String;
                perform action detectMotion : DetectMotion;
            }

            part def DoorWindowSensor {
                port zigbeePort : ZigbeeSensorPort;
                attribute batteryLevel : Real;
                attribute location : String;
                perform action detectState : DetectState;
            }

            part def SmartBulb {
                port zigbeePort : ZigbeeActuatorPort;
                attribute brightness : Real;
                attribute location : String;
                perform action adjustLighting : AdjustLighting;
            }

            part def SmartPlug {
                port zigbeePort : ZigbeeActuatorPort;
                attribute isOn : Boolean;
                attribute location : String;
                perform action controlAppliance : ControlAppliance;
            }

            part def AirConditioner {
                port zigbeePort : ZigbeeActuatorPort;
                attribute targetTemperature :> ISQ::temperature;
                attribute currentTemperature :> ISQ::temperature;
                attribute location : String;
                perform action regulateClimate : RegulateClimate;
            }

            part def SecurityCamera {
                port zigbeePort : ZigbeeActuatorPort;
                attribute isRecording : Boolean;
                attribute location : String;
                perform action recordVideo : RecordVideo;
            }

            part def UserApp {
                port wifiPort : ~WiFiPort;
                attribute userName : String;
                perform action sendArmCommand : SendArmCommand;
                perform action sendDisarmCommand : SendDisarmCommand;
                perform action displayNotification : DisplayNotification;
            }

            part def SmartHomeSystem {
                part gateway : MiGateway;
                part tempHumiditySensors : TemperatureHumiditySensor[*];
                part motionSensors : MotionSensor[*];
                part doorWindowSensors : DoorWindowSensor[*];
                part smartBulbs : SmartBulb[*];
                part smartPlugs : SmartPlug[*];
                part airConditioners : AirConditioner[*];
                part securityCameras : SecurityCamera[*];
                part userApp : UserApp;

                connect tempHumiditySensors.zigbeePort to gateway.zigbeeSensorPort;
                connect motionSensors.zigbeePort to gateway.zigbeeSensorPort;
                connect doorWindowSensors.zigbeePort to gateway.zigbeeSensorPort;
                connect gateway.zigbeeActuatorPort to smartBulbs.zigbeePort;
                connect gateway.zigbeeActuatorPort to smartPlugs.zigbeePort;
                connect gateway.zigbeeActuatorPort to airConditioners.zigbeePort;
                connect gateway.zigbeeActuatorPort to securityCameras.zigbeePort;
                connect gateway.wifiPort to userApp.wifiPort;

                flow tempHumidityFlow of TemperatureHumidityData
                    from tempHumiditySensors.zigbeePort.tempHumidityData
                    to gateway.zigbeeSensorPort.tempHumidityData;
                flow motionFlow of MotionData
                    from motionSensors.zigbeePort.motionData
                    to gateway.zigbeeSensorPort.motionData;
                flow doorStateFlow of DoorWindowState
                    from doorWindowSensors.zigbeePort.doorState
                    to gateway.zigbeeSensorPort.doorState;
                flow brightnessCmdFlow of BrightnessCmd
                    from gateway.zigbeeActuatorPort.brightnessCmd
                    to smartBulbs.zigbeePort.brightnessCmd;
                flow colorCmdFlow of ColorCmd
                    from gateway.zigbeeActuatorPort.colorCmd
                    to smartBulbs.zigbeePort.colorCmd;
                flow powerStateCmdFlow of PowerStateCmd
                    from gateway.zigbeeActuatorPort.powerStateCmd
                    to smartPlugs.zigbeePort.powerStateCmd;
                flow targetTempCmdFlow of TargetTempCmd
                    from gateway.zigbeeActuatorPort.targetTempCmd
                    to airConditioners.zigbeePort.targetTempCmd;
                flow recordCmdFlow of RecordCmd
                    from gateway.zigbeeActuatorPort.recordCmd
                    to securityCameras.zigbeePort.recordCmd;
                flow powerUsageFlow of PowerUsageData
                    from smartPlugs.zigbeePort.powerUsage
                    to gateway.zigbeeActuatorPort.powerUsage;
                flow videoStreamFlow of VideoStream
                    from securityCameras.zigbeePort.videoStream
                    to gateway.zigbeeActuatorPort.videoStream;
                flow notificationFlow of NotificationMsg
                    from gateway.wifiPort.notification
                    to userApp.wifiPort.notification;
                flow videoToAppFlow of VideoStream
                    from gateway.wifiPort.videoStream
                    to userApp.wifiPort.videoStream;
            }
        }

        package RequirementDefinitions {
            requirement def ComfortRequirement {
                doc /* The system shall enhance occupant comfort through automated climate and lighting control based on sensor readings. */
            }
            requirement def EnergyEfficiencyRequirement {
                doc /* The system shall improve energy efficiency by monitoring power usage and optimizing appliance operation. */
            }
            requirement def SecurityRequirement {
                doc /* The system shall provide security through intrusion detection, alarm activation, and video surveillance. */
            }
            requirement def AutomationRequirement {
                doc /* The system shall execute user-defined automation rules based on sensor events and time conditions. */
            }
        }
    }

    package Usages {
        private import Definitions::*;

        part xiaomiSmartHome : SmartHomeSystem {
            part :>> gateway;
            part :>> tempHumiditySensors[2];
            part :>> motionSensors[3];
            part :>> doorWindowSensors[4];
            part :>> smartBulbs[5];
            part :>> smartPlugs[4];
            part :>> airConditioners[2];
            part :>> securityCameras[2];
            part :>> userApp;

            satisfy ComfortRequirement by gateway;
            satisfy EnergyEfficiencyRequirement by smartPlugs;
            satisfy SecurityRequirement by securityCameras;
            satisfy AutomationRequirement by gateway;
        }
    }
}
