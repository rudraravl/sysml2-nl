package SmartHomeAutomation {

    import ScalarValues::*;
    import ISQ::*;
    import ISQ::Time::*;
    import ISQ::Temperature::*;
    import ISQ::Power::*;
    import ISQ::Length::*;

    // ===== Value Types =====

    value def Humidity :> Real {
        doc "Relative humidity percentage";
        unit %;
    }

    value def BrightnessLevel :> Real {
        doc "Brightness as percentage 0..100";
        unit %;
    }

    value def NetworkDelay :> Real {
        doc "Network communication delay";
        unit ms;
    }

    value def PowerConsumption :> Real {
        doc "Power consumption";
        unit W;
    }

    value def DeviceCount :> Integer;

    value def MotionRange :> Real {
        doc "Detection range for motion sensors";
        unit m;
    }

    // ===== Item Types =====

    item def TemperatureData {
        attribute temperature : TemperatureValue;
        attribute timestamp : TimeValue;
    }

    item def HumidityData {
        attribute humidity : Humidity;
        attribute timestamp : TimeValue;
    }

    item def MotionData {
        attribute detected : Boolean;
        attribute timestamp : TimeValue;
    }

    item def LightCommand {
        attribute on : Boolean;
        attribute brightness : BrightnessLevel;
    }

    item def DeviceRegistration {
        attribute deviceId : String;
        attribute deviceType : String;
        attribute location : String;
    }

    item def CoAPMessage {
        attribute payload : String;
        attribute source : String;
        attribute destination : String;
    }

    // ===== Port Definitions =====

    port def CoAPPort {
        in item msgIn : CoAPMessage;
        out item msgOut : CoAPMessage;
    }

    port def SensorDataPort {
        out item tempData : TemperatureData;
        out item humData : HumidityData;
        out item motionData : MotionData;
    }

    port def ActuatorCommandPort {
        in item lightCmd : LightCommand;
    }

    port def RegistrationPort {
        out item registration : DeviceRegistration;
    }

    // ===== Interfaces =====

    interface def CoAPCommunication {
        end sender : CoAPPort;
        end receiver : CoAPPort;
        flow msgOut from sender to receiver.msgIn;
    }

    interface def SensorToGateway {
        end sensor : SensorDataPort;
        end gateway : CoAPPort;
    }

    interface def GatewayToActuator {
        end gateway : CoAPPort;
        end actuator : ActuatorCommandPort;
    }

    // ===== Device Base =====

    part def SmartDevice {
        attribute deviceId : String;
        attribute deviceType : String;
        attribute location : String;
        attribute powerDraw : PowerConsumption;
        port registrationPort : RegistrationPort;
        port coapPort : CoAPPort;

        state def LifecycleBehavior {
            entry;
            then Initializing;
            state Initializing {
                entry { send DeviceRegistration(deviceId, deviceType, location) to registrationPort; }
            }
            then Discovering;
            state Discovering {
                doc "Device discovers the IoTivity network and available services.";
            }
            then Registering;
            state Registering {
                doc "Device registers with the central server via the gateway.";
            }
            then Operational;
            state Operational {
                doc "Device is operational and participating in monitoring/control loop.";
            }
        }
        exhibit state LifecycleBehavior;
    }

    // ===== Sensors =====

    part def TemperatureHumiditySensor :> SmartDevice {
        attribute samplingInterval : TimeValue = 5 [s];
        port sensorDataPort : SensorDataPort;
        attribute currentTemperature : TemperatureValue;
        attribute currentHumidity : Humidity;

        action def SampleEnvironment {
            in sensorRef : TemperatureHumiditySensor;
            out tempData : TemperatureData;
            out humData : HumidityData;
        }

        perform action sample : SampleEnvironment {
            in sensorRef = self;
            out tempData = sensorDataPort.tempData;
            out humData = sensorDataPort.humData;
        }
    }

    part def MotionSensor :> SmartDevice {
        attribute detectionRange : MotionRange = 5 [m];
        port sensorDataPort : SensorDataPort;
        attribute motionDetected : Boolean = false;

        action def DetectMotion {
            in sensorRef : MotionSensor;
            out motionData : MotionData;
        }

        perform action detect : DetectMotion {
            in sensorRef = self;
            out motionData = sensorDataPort.motionData;
        }
    }

    // ===== Actuators =====

    part def SmartLightActuator :> SmartDevice {
        attribute isOn : Boolean = false;
        attribute brightness : BrightnessLevel = 0 [%];
        port commandPort : ActuatorCommandPort;

        action def ApplyCommand {
            in cmd : LightCommand;
            update self.isOn = cmd.on;
            update self.brightness = cmd.brightness;
        }

        perform action applyCmd : ApplyCommand {
            in cmd = commandPort.lightCmd;
        }
    }

    // ===== Gateway =====

    part def NetworkGateway {
        attribute protocol : String = "CoAP";
        attribute maxLatency : NetworkDelay = 200 [ms];
        port serverPort : CoAPPort;
        port devicePort : CoAPPort;

        action def RelayMessage {
            in msgIn : CoAPMessage;
            out msgOut : CoAPMessage;
        }

        perform action relay : RelayMessage {
            in msgIn = serverPort.msgIn;
            out msgOut = devicePort.msgOut;
        }

        perform action relayUp : RelayMessage {
            in msgIn = devicePort.msgIn;
            out msgOut = serverPort.msgOut;
        }
    }

    // ===== Central Server =====

    part def CentralServer {
        attribute maxDevices : DeviceCount = 100;
        attribute registeredDevices : DeviceCount = 0;
        attribute totalPowerBudget : PowerConsumption = 50 [W];
        attribute currentPowerConsumption : PowerConsumption = 0 [W];
        port gatewayPort : CoAPPort;

        action def ProcessSensorData {
            in tempData : TemperatureData;
            in humData : HumidityData;
            in motionData : MotionData;
            out lightCmd : LightCommand;
        }

        action def EvaluateTemperatureRule {
            in temp : TemperatureValue;
            out cmd : LightCommand;
            if temp > 26 [°C] {
                then send LightCommand(true, 80 [%]) to out cmd;
            } else {
                then send LightCommand(false, 0 [%]) to out cmd;
            }
        }

        perform action process : ProcessSensorData {
            in tempData = gatewayPort.msgIn;
            out lightCmd = gatewayPort.msgOut;
        }

        state def ServerOperation {
            entry;
            then Idle;
            state Idle;
            transition Idle -> Processing
                when gatewayPort.msgIn'received;
            state Processing {
                perform action process : ProcessSensorData;
            }
            transition Processing -> Idle
                when process'done;
        }
        exhibit state ServerOperation;
    }

    // ===== System Assembly =====

    part def SmartHomeSystem {
        part server : CentralServer;
        part gateway : NetworkGateway;
        part livingRoomTempSensor : TemperatureHumiditySensor {
            attribute deviceId = "THS-LR-001";
            attribute deviceType = "TemperatureHumiditySensor";
            attribute location = "LivingRoom";
            attribute powerDraw = 0.5 [W];
        }
        part bedroomTempSensor : TemperatureHumiditySensor {
            attribute deviceId = "THS-BR-001";
            attribute deviceType = "TemperatureHumiditySensor";
            attribute location = "Bedroom";
            attribute powerDraw = 0.5 [W];
        }
        part entranceMotionSensor : MotionSensor {
            attribute deviceId = "MS-ENT-001";
            attribute deviceType = "MotionSensor";
            attribute location = "Entrance";
            attribute powerDraw = 0.3 [W];
        }
        part livingRoomLight : SmartLightActuator {
            attribute deviceId = "SL-LR-001";
            attribute deviceType = "SmartLightActuator";
            attribute location = "LivingRoom";
            attribute powerDraw = 10 [W];
        }
        part bedroomLight : SmartLightActuator {
            attribute deviceId = "SL-BR-001";
            attribute deviceType = "SmartLightActuator";
            attribute location = "Bedroom";
            attribute powerDraw = 10 [W];
        }

        interface serverGateway : CoAPCommunication connect server.gatewayPort to gateway.serverPort;
        interface gatewayLivingRoomTemp : SensorToGateway connect livingRoomTempSensor.sensorDataPort to gateway.devicePort;
        interface gatewayBedroomTemp : SensorToGateway connect bedroomTempSensor.sensorDataPort to gateway.devicePort;
        interface gatewayEntranceMotion : SensorToGateway connect entranceMotionSensor.sensorDataPort to gateway.devicePort;
        interface gatewayLivingRoomLight : GatewayToActuator connect gateway.devicePort to livingRoomLight.commandPort;
        interface gatewayBedroomLight : GatewayToActuator connect gateway.devicePort to bedroomLight.commandPort;

        attribute systemPowerConsumption : PowerConsumption = 
            livingRoomTempSensor.powerDraw + bedroomTempSensor.powerDraw + 
            entranceMotionSensor.powerDraw + livingRoomLight.powerDraw + 
            bedroomLight.powerDraw + server.currentPowerConsumption;
    }

    // ===== Requirements =====

    requirement def DeviceManagementRequirement {
        subject server : CentralServer;
        requirement server shall manage up to 100 connected devices {
            require server.maxDevices == 100;
        }
    }

    requirement def CommunicationLatencyRequirement {
        subject gateway : NetworkGateway;
        requirement network communication delays shall be under 200 milliseconds {
            require gateway.maxLatency <= 200 [ms];
        }
    }

    requirement def PowerEfficiencyRequirement {
        subject system : SmartHomeSystem;
        requirement total operational consumption shall be less than 50 watts {
            require system.systemPowerConsumption < 50 [W];
        }
    }

    requirement def MotionDetectionRequirement {
        subject sensor : MotionSensor;
        requirement motion sensors shall detect movement within a five-meter range {
            require sensor.detectionRange >= 5 [m];
        }
    }

    requirement def DeviceLifecycleRequirement {
        subject device : SmartDevice;
        requirement when a new device is powered on it shall initialize, discover the network, and register with the central server {
            require device.LifecycleBehavior.Initializing'exists;
            require device.LifecycleBehavior.Discovering'exists;
            require device.LifecycleBehavior.Registering'exists;
        }
    }

    requirement def AutomatedControlRequirement {
        subject server : CentralServer;
        requirement the system shall automatically send commands to actuators based on sensor data criteria {
            require server.ProcessSensorData'exists;
        }
    }

    requirement def SmartHomeSystemRequirements {
        requirement deviceManagement : DeviceManagementRequirement;
        requirement communicationLatency : CommunicationLatencyRequirement;
        requirement powerEfficiency : PowerEfficiencyRequirement;
        requirement motionDetection : MotionDetectionRequirement;
        requirement deviceLifecycle : DeviceLifecycleRequirement;
        requirement automatedControl : AutomatedControlRequirement;
    }

    // ===== Verification =====

    verification def VerifyLatency {
        subject gateway : NetworkGateway;
        objective check gateway.maxLatency <= 200 [ms];
    }

    verification def VerifyPower {
        subject system : SmartHomeSystem;
        objective check system.systemPowerConsumption < 50 [W];
    }

    verification def VerifyDeviceCount {
        subject server : CentralServer;
        objective check server.maxDevices == 100;
    }

    verification def VerifyMotionRange {
        subject sensor : MotionSensor;
        objective check sensor.detectionRange >= 5 [m];
    }

}
