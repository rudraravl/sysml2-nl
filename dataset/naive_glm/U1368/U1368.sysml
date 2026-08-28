package XiaomiSmartHomeSystem {

    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types =====
    package ValueTypes {
        attribute def TemperatureValue :> Real { unit "°C"; }
        attribute def HumidityValue :> Real { unit "%"; }
        attribute def BrightnessValue :> Integer { unit "lumens"; min 0; max 1000; }
        attribute def PowerValue :> Real { unit "W"; }
        attribute def ColorRGB {
            attribute red : Integer { min 0; max 255; }
            attribute green : Integer { min 0; max 255; }
            attribute blue : Integer { min 0; max 255; }
        }
        attribute def BatteryLevel :> Integer { unit "%"; min 0; max 100; }
        attribute def SignalStrength :> Integer { unit "dBm"; }
        attribute def Timestamp :> Real { unit "s"; }
        attribute def MotionDetected :> Boolean;
        attribute def DoorWindowState :> Boolean; // true = open
        attribute def OnOffState :> Boolean; // true = on
        attribute def SecurityMode :> String;
    }

    // ===== Item Types =====
    package Items {
        item def SensorData {
            attribute deviceId : String;
            attribute timestamp : Timestamp;
        }
        item def TemperatureReading :> SensorData {
            attribute temperature : TemperatureValue;
        }
        item def HumidityReading :> SensorData {
            attribute humidity : HumidityValue;
        }
        item def MotionReading :> SensorData {
            attribute motionDetected : MotionDetected;
        }
        item def DoorWindowReading :> SensorData {
            attribute isOpen : DoorWindowState;
        }
        item def PowerReading :> SensorData {
            attribute power : PowerValue;
        }
        item def Command {
            attribute deviceId : String;
            attribute timestamp : Timestamp;
        }
        item def LightCommand :> Command {
            attribute on : OnOffState;
            attribute brightness : BrightnessValue;
            attribute color : ColorRGB;
        }
        item def PlugCommand :> Command {
            attribute on : OnOffState;
        }
        item def ACCommand :> Command {
            attribute on : OnOffState;
            attribute targetTemperature : TemperatureValue;
        }
        item def CameraCommand :> Command {
            attribute recording : Boolean;
        }
        item def Notification {
            attribute message : String;
            attribute timestamp : Timestamp;
            attribute severity : String;
        }
        item def AutomationRule {
            attribute ruleId : String;
            attribute name : String;
            attribute enabled : Boolean;
            attribute condition : String;
            attribute action : String;
        }
        item def VideoFrame {
            attribute timestamp : Timestamp;
            attribute resolution : String;
        }
    }

    // ===== Port Definitions =====
    package Ports {
        port def ZigbeePort {
            in item data : Items::SensorData;
            out item command : Items::Command;
        }
        port def WiFiPort {
            in item notification : Items::Notification;
            out item rule : Items::AutomationRule;
            out item video : Items::VideoFrame;
        }
        port def SensorOutPort {
            out item reading : Items::SensorData;
        }
        port def DeviceInPort {
            in item command : Items::Command;
            out item feedback : Items::SensorData;
        }
        port def PowerPort {
            out item power : Items::PowerReading;
        }
        port def VideoOutPort {
            out item frame : Items::VideoFrame;
        }
    }

    // ===== Sensor Parts =====
    package Sensors {
        part def WirelessSensor {
            attribute batteryLevel : BatteryLevel;
            attribute signal : SignalStrength;
            port sensorOut : Ports::SensorOutPort;
        }

        part def TemperatureHumiditySensor :> WirelessSensor {
            attribute temperature : TemperatureValue;
            attribute humidity : HumidityValue;
            port sensorOut : Ports::SensorOutPort {
                redefines out item reading : Items::SensorData = (temperature, humidity);
            }
            action def readEnvironment {
                in out temp : TemperatureValue;
                in out hum : HumidityValue;
            }
            perform readEnvironment;
        }

        part def MotionSensor :> WirelessSensor {
            attribute motionDetected : MotionDetected;
            port sensorOut : Ports::SensorOutPort {
                redefines out item reading : Items::SensorData = motionDetected;
            }
            action def detectMotion {
                out detected : MotionDetected;
            }
            perform detectMotion;
        }

        part def DoorWindowSensor :> WirelessSensor {
            attribute isOpen : DoorWindowState;
            port sensorOut : Ports::SensorOutPort {
                redefines out item reading : Items::SensorData = isOpen;
            }
            action def detectState {
                out open : DoorWindowState;
            }
            perform detectState;
        }
    }

    // ===== Smart Device Parts =====
    package SmartDevices {
        part def SmartDevice {
            attribute deviceId : String;
            port deviceIn : Ports::DeviceInPort;
        }

        part def SmartBulb :> SmartDevice {
            attribute on : OnOffState;
            attribute brightness : BrightnessValue;
            attribute color : ColorRGB;
            action def setLight {
                in cmd : Items::LightCommand;
                in out onState : OnOffState;
                in out bright : BrightnessValue;
                in out col : ColorRGB;
            }
            perform setLight;
        }

        part def SmartPlug :> SmartDevice {
            attribute on : OnOffState;
            attribute powerUsage : PowerValue;
            port powerOut : Ports::PowerPort;
            action def togglePlug {
                in cmd : Items::PlugCommand;
                in out onState : OnOffState;
                out power : PowerValue;
            }
            perform togglePlug;
        }

        part def AirConditioner :> SmartDevice {
            attribute on : OnOffState;
            attribute targetTemperature : TemperatureValue;
            attribute currentTemperature : TemperatureValue;
            action def setClimate {
                in cmd : Items::ACCommand;
                in out onState : OnOffState;
                in out targetTemp : TemperatureValue;
            }
            perform setClimate;
        }

        part def SecurityCamera :> SmartDevice {
            attribute recording : Boolean;
            attribute resolution : String;
            port videoOut : Ports::VideoOutPort;
            action def captureVideo {
                in cmd : Items::CameraCommand;
                in out rec : Boolean;
                out frame : Items::VideoFrame;
            }
            perform captureVideo;
        }
    }

    // ===== Mi Gateway =====
    package Gateway {
        part def MiGateway {
            attribute gatewayId : String;
            attribute connected : Boolean;
            attribute currentMode : ValueTypes::SecurityMode;
            attribute sunsetTime : Timestamp;

            port zigbeeIn : Ports::ZigbeePort;
            port wifiPort : Ports::WiFiPort;

            item store : Items::AutomationRule[*];
            item sensorDataBuffer : Items::SensorData[*];

            state def GatewayStateMachine {
                entry;
                then NormalMode;

                state NormalMode {
                    entry { currentMode = "normal"; }
                    on sensorDataBuffer->motionDetected == true
                        if currentMode == "normal" and timestamp > sunsetTime
                        then executeLivingRoomLight;
                    on sensorDataBuffer->temperature > 26.0
                        then executeACAdjust;
                    transition to SecurityArmed
                        if currentMode == "normal"
                        when wifiPort.rule.condition == "arm_away";
                }

                state SecurityArmed {
                    entry { currentMode = "armed_away"; }
                    on sensorDataBuffer->isOpen == true
                        then AlarmState;
                    on sensorDataBuffer->motionDetected == true
                        then AlarmState;
                    transition to NormalMode
                        when wifiPort.rule.condition == "disarm";
                }

                state AlarmState {
                    entry {
                        currentMode = "alarm";
                        executeCameraRecording;
                        executeUserNotification;
                    }
                    transition to SecurityArmed
                        when wifiPort.rule.condition == "acknowledge";
                }

                action executeLivingRoomLight {
                    out cmd : Items::LightCommand;
                }
                action executeACAdjust {
                    out cmd : Items::ACCommand;
                }
                action executeCameraRecording {
                    out cmd : Items::CameraCommand;
                }
                action executeUserNotification {
                    out notif : Items::Notification;
                }
            }

            exhibit GatewayStateMachine;
        }
    }

    // ===== System Assembly =====
    part def XiaomiSmartHomeSystem {
        attribute systemName : String = "Xiaomi Smart Home";

        part gateway : Gateway::MiGateway {
            port zigbeeIn : Ports::ZigbeePort;
            port wifiPort : Ports::WiFiPort;
        }

        // Sensors
        part livingRoomTempSensor : Sensors::TemperatureHumiditySensor;
        part bedroomTempSensor : Sensors::TemperatureHumiditySensor;
        part hallwayMotionSensor : Sensors::MotionSensor;
        part frontDoorSensor : Sensors::DoorWindowSensor;
        part backDoorSensor : Sensors::DoorWindowSensor;

        // Smart Devices
        part livingRoomBulb : SmartDevices::SmartBulb;
        part bedroomBulb : SmartDevices::SmartBulb;
        part livingRoomPlug : SmartDevices::SmartPlug;
        part bedroomAC : SmartDevices::AirConditioner;
        part securityCamera : SmartDevices::SecurityCamera;

        // Connections: Sensors to Gateway via Zigbee
        connection livingRoomTempToGateway connect livingRoomTempSensor.sensorOut to gateway.zigbeeIn;
        connection bedroomTempToGateway connect bedroomTempSensor.sensorOut to gateway.zigbeeIn;
        connection hallwayMotionToGateway connect hallwayMotionSensor.sensorOut to gateway.zigbeeIn;
        connection frontDoorToGateway connect frontDoorSensor.sensorOut to gateway.zigbeeIn;
        connection backDoorToGateway connect backDoorSensor.sensorOut to gateway.zigbeeIn;

        // Connections: Gateway to Smart Devices via Zigbee
        connection gatewayToLivingRoomBulb connect gateway.zigbeeIn to livingRoomBulb.deviceIn;
        connection gatewayToBedroomBulb connect gateway.zigbeeIn to bedroomBulb.deviceIn;
        connection gatewayToLivingRoomPlug connect gateway.zigbeeIn to livingRoomPlug.deviceIn;
        connection gatewayToBedroomAC connect gateway.zigbeeIn to bedroomAC.deviceIn;
        connection gatewayToSecurityCamera connect gateway.zigbeeIn to securityCamera.deviceIn;

        // Power feedback from plug
        connection plugPowerFeedback connect livingRoomPlug.powerOut to gateway.zigbeeIn;

        // Video from camera to gateway WiFi
        connection cameraVideoToGateway connect securityCamera.videoOut to gateway.wifiPort;

        // WiFi connection to cloud/app
        connection gatewayWiFi connect gateway.wifiPort to gateway.wifiPort;
    }

    // ===== Requirements =====
    package Requirements {
        requirement def SystemRequirement {
            attribute id : String;
            attribute text : String;
        }

        requirement IntegratedHomeAutomation :> SystemRequirement {
            id = "REQ-001";
            text = "The system shall provide integrated home automation through a central Mi Gateway coordinating sensors and smart devices.";
        }

        requirement WirelessConnectivity :> SystemRequirement {
            id = "REQ-002";
            text = "The Mi Gateway shall communicate with sensors and devices using Zigbee and connect to the internet via WiFi.";
        }

        requirement EnvironmentalMonitoring :> SystemRequirement {
            id = "REQ-003";
            text = "The system shall monitor temperature, humidity, motion, and door/window states using battery-powered wireless sensors.";
        }

        requirement DeviceControl :> SystemRequirement {
            id = "REQ-004";
            text = "The system shall control smart bulbs (brightness and color), smart plugs (on/off and power monitoring), air conditioner (target temperature), and security camera (recording).";
        }

        requirement AutomationRules :> SystemRequirement {
            id = "REQ-005";
            text = "The system shall execute user-defined automation rules, such as turning on lights when motion is detected after sunset, or adjusting AC temperature based on sensor readings.";
        }

        requirement SecurityMode :> SystemRequirement {
            id = "REQ-006";
            text = "The system shall support a security mode (armed away) where door or motion triggers cause an alarm state, activate camera recording, and notify the user.";
        }

        requirement EnergyEfficiency :> SystemRequirement {
            id = "REQ-007";
            text = "The system shall improve energy efficiency by monitoring power usage and automating device control.";
        }

        requirement ComfortEnhancement :> SystemRequirement {
            id = "REQ-008";
            text = "The system shall enhance comfort through intelligent climate and lighting control.";
        }

        satisfaction IntegratedHomeAutomationSatisfied by XiaomiSmartHomeSystem::gateway;
        satisfaction WirelessConnectivitySatisfied by Gateway::MiGateway::zigbeeIn;
        satisfaction EnvironmentalMonitoringSatisfied by Sensors::WirelessSensor;
        satisfaction DeviceControlSatisfied by SmartDevices::SmartDevice;
        satisfaction AutomationRulesSatisfied by Gateway::MiGateway::GatewayStateMachine;
        satisfaction SecurityModeSatisfied by Gateway::MiGateway::GatewayStateMachine::SecurityArmed;
    }
}
