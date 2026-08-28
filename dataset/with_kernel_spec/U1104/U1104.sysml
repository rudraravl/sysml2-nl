package InsteonHomeAutomation {
    // Value types
    attribute def Frequency :> ScalarValues::Real;
    attribute def Voltage :> ScalarValues::Real;
    attribute def Power :> ScalarValues::Real;
    attribute def Energy :> ScalarValues::Real;
    attribute def Temperature :> ScalarValues::Real;
    attribute def Illuminance :> ScalarValues::Real;
    attribute def Time :> ScalarValues::Real;
    attribute def Percentage :> ScalarValues::Real;
    attribute def SignalStrength :> ScalarValues::Real;

    // Enumerations
    enum def HVACMode {
        Off;
        Heat;
        Cool;
        Auto;
    }

    // Item definitions
    item def InsteonAddress {
        attribute address : ScalarValues::String;
    }

    item def Command {
        attribute source : InsteonAddress;
        attribute target : InsteonAddress;
        attribute commandId : ScalarValues::Integer;
        attribute hopCount : ScalarValues::Integer = 0;
        attribute maxHops : ScalarValues::Integer = 3;
    }

    item def OnOffCommand :> Command {
        attribute state : ScalarValues::Boolean;
    }

    item def DimCommand :> Command {
        attribute level : Percentage;
        attribute rampRate : Time;
    }

    item def SceneCommand :> Command {
        attribute sceneId : ScalarValues::Integer;
    }

    item def StatusReport :> Command {
        attribute deviceState : ScalarValues::String;
        attribute value : ScalarValues::Real;
    }

    item def MotionReport :> Command {
        attribute motionDetected : ScalarValues::Boolean;
        attribute ambientLight : Illuminance;
    }

    item def EnergyReport :> Command {
        attribute instantaneousPower : Power;
        attribute cumulativeEnergy : Energy;
    }

    item def ThermostatCommand :> Command {
        attribute setpoint : Temperature;
        attribute mode : HVACMode;
    }

    item def HVACControlSignal {
        attribute mode : HVACMode;
        attribute fanEnabled : ScalarValues::Boolean;
    }

    item def HVACStatus {
        attribute running : ScalarValues::Boolean;
        attribute currentMode : HVACMode;
    }

    item def InternetPacket {
        attribute payload : ScalarValues::String;
        attribute timestamp : Time;
    }

    // Port definitions
    port def PowerlinePort {
        in item cmdIn : Command;
        out item cmdOut : Command;
        attribute carrierFrequency : Frequency;
        attribute lineVoltage : Voltage;
    }

    port def RFPort {
        in item cmdIn : Command;
        out item cmdOut : Command;
        attribute rfFrequency : Frequency;
        attribute signalStrength : SignalStrength;
    }

    port def LoadPort {
        out item powerLevel : Percentage;
        in item loadStatus : ScalarValues::Boolean;
    }

    port def SensorPort {
        out item motionData : MotionReport;
    }

    port def HVACPort {
        out item control : HVACControlSignal;
        in item status : HVACStatus;
    }

    port def OutletPort {
        out item switched : ScalarValues::Boolean;
        in item powerDraw : Power;
    }

    port def InternetPort {
        in item dataIn : InternetPacket;
        out item dataOut : InternetPacket;
    }

    port def UserInputPort {
        in item buttonPress : Command;
    }

    // Interface definitions
    interface def PowerlineLink {
        end portA : PowerlinePort;
        end portB : ~PowerlinePort;
        flow of Command from portA.cmdOut to portB.cmdIn;
        flow of Command from portB.cmdOut to portA.cmdIn;
    }

    interface def RFLink {
        end portA : RFPort;
        end portB : ~RFPort;
        flow of Command from portA.cmdOut to portB.cmdIn;
        flow of Command from portB.cmdOut to portA.cmdIn;
    }

    // Base device definition
    part def InsteonDevice {
        attribute deviceAddress : InsteonAddress;
        attribute isRepeater : ScalarValues::Boolean = true;
        attribute firmwareVersion : ScalarValues::String;

        port powerline : PowerlinePort;
        port rf : RFPort;

        state def DeviceBehavior {
            state Idle;
            state Receiving;
            state Processing;
            state Executing;
            state Repeating;

            transition Idle -> Receiving accept powerline.cmdIn;
            transition Receiving -> Processing;
            transition Processing -> Executing;
            transition Processing -> Repeating when isRepeater;
            transition Executing -> Idle;
            transition Repeating -> Idle;
        }

        perform action ProcessCommand {
            in cmd : Command;
            out status : StatusReport;
        }

        perform action RepeatMessage {
            in cmd : Command;
            out repeated : Command;
        }
    }

    // Insteon Hub
    part def InsteonHub :> InsteonDevice {
        port internet : InternetPort;
        attribute connectedDeviceCount : ScalarValues::Integer;
        attribute networkId : ScalarValues::String;

        state def HubBehavior :> DeviceBehavior {
            state Routing;
            state Bridging;

            transition Processing -> Routing;
            transition Routing -> Idle;
            transition Idle -> Bridging accept internet.dataIn;
            transition Bridging -> Idle;
        }

        perform action RouteMessage {
            in cmd : Command;
            out broadcast : Command;
        }

        perform action BridgeInternet {
            in packet : InternetPacket;
            out cmd : Command;
        }
    }

    // Dimmable Switch
    part def DimmableSwitch :> InsteonDevice {
        port load : LoadPort;
        attribute brightness : Percentage = 0;
        attribute rampRate : Time = 0.5;
        attribute sceneCapable : ScalarValues::Boolean = true;

        state def SwitchBehavior :> DeviceBehavior {
            state Off;
            state On;
            state Dimming;

            transition Off -> On accept powerline.cmdIn;
            transition On -> Off accept powerline.cmdIn;
            transition On -> Dimming accept powerline.cmdIn;
            transition Dimming -> Off accept powerline.cmdIn;
            transition Dimming -> On when brightness >= 100;
        }

        perform action SetBrightness {
            in level : Percentage;
            out powerLevel : Percentage;
        }
    }

    // Motion Sensor
    part def MotionSensor :> InsteonDevice {
        port sensor : SensorPort;
        attribute motionDetected : ScalarValues::Boolean = false;
        attribute ambientLight : Illuminance;
        attribute detectionThreshold : Illuminance;
        attribute batteryLevel : Percentage;

        state def SensorBehavior :> DeviceBehavior {
            state Idle;
            state Detecting;
            state Reporting;

            transition Idle -> Detecting when motionDetected;
            transition Detecting -> Idle when motionDetected == false;
            transition Detecting -> Reporting;
            transition Reporting -> Idle;
        }

        perform action DetectMotion {
            out data : MotionReport;
        }
    }

    // Thermostat
    part def Thermostat :> InsteonDevice {
        port hvac : HVACPort;
        attribute currentTemperature : Temperature;
        attribute setpoint : Temperature;
        attribute mode : HVACMode = HVACMode::Off;
        attribute deadband : Temperature = 0.5;

        state def ThermostatBehavior :> DeviceBehavior {
            state Idle;
            state Heating;
            state Cooling;

            transition Idle -> Heating when currentTemperature < setpoint - deadband;
            transition Idle -> Cooling when currentTemperature > setpoint + deadband;
            transition Heating -> Idle when currentTemperature >= setpoint;
            transition Cooling -> Idle when currentTemperature <= setpoint;
            transition Idle -> Idle accept powerline.cmdIn;
        }

        perform action ControlClimate {
            in target : Temperature;
            in hvacMode : HVACMode;
            out signal : HVACControlSignal;
        }
    }

    // Smart Outlet
    part def SmartOutlet :> InsteonDevice {
        port outlet : OutletPort;
        attribute isOn : ScalarValues::Boolean = false;
        attribute instantaneousPower : Power;
        attribute cumulativeEnergy : Energy;
        attribute reportingInterval : Time = 60;

        state def OutletBehavior :> DeviceBehavior {
            state Off;
            state On;
            state Monitoring;

            transition Off -> On accept powerline.cmdIn;
            transition On -> Off accept powerline.cmdIn;
            transition On -> Monitoring;
            transition Monitoring -> On;
        }

        perform action MonitorEnergy {
            out data : EnergyReport;
        }

        perform action ControlOutlet {
            in state : ScalarValues::Boolean;
            out switched : ScalarValues::Boolean;
        }
    }

    // Insteon Controller
    part def InsteonController :> InsteonDevice {
        port userInput : UserInputPort;
        attribute buttonCount : ScalarValues::Integer;
        attribute keypadLayout : ScalarValues::String;

        state def ControllerBehavior :> DeviceBehavior {
            state Idle;
            state Sending;

            transition Idle -> Sending accept userInput.buttonPress;
            transition Sending -> Idle;
        }

        perform action SendCommand {
            in target : InsteonAddress;
            in cmdType : ScalarValues::String;
            out cmd : Command;
        }
    }

    // Requirements
    requirement def DualBandReliabilityReq {
        doc /* The system shall use both powerline and RF communication paths to ensure command delivery even if one path is obstructed. */
        attribute powerlineActive : ScalarValues::Boolean;
        attribute rfActive : ScalarValues::Boolean;
        attribute messageDeliverySuccess : Percentage;
        require constraint {
            powerlineActive == true and
            rfActive == true and
            messageDeliverySuccess >= 99.9
        }
    }

    requirement def MeshRepeaterReq {
        doc /* Every device in the network shall act as a repeater to extend range and ensure command delivery. */
        attribute repeaterEnabled : ScalarValues::Boolean;
        attribute maxHops : ScalarValues::Integer;
        require constraint {
            repeaterEnabled == true and
            maxHops >= 3
        }
    }

    requirement def PeerToPeerOperationReq {
        doc /* Basic device-to-device commands shall operate without requiring the hub or cloud connection. */
        attribute hubDependency : ScalarValues::Boolean;
        attribute cloudDependency : ScalarValues::Boolean;
        require constraint {
            hubDependency == false and
            cloudDependency == false
        }
    }

    requirement def ResponseTimeReq {
        doc /* The system shall respond to commands within 200 milliseconds for basic peer-to-peer operations. */
        attribute responseTime : Time;
        attribute maxResponseTime : Time = 0.2;
        require constraint { responseTime <= maxResponseTime }
    }

    requirement def EnergyMonitoringReq {
        doc /* Smart outlets shall monitor and report energy consumption of connected devices with at least 95% accuracy. */
        attribute reportedPower : Power;
        attribute actualPower : Power;
        attribute reportingInterval : Time;
        attribute maxReportingInterval : Time = 60;
        require constraint {
            abs(reportedPower - actualPower) / actualPower <= 0.05 and
            reportingInterval <= maxReportingInterval
        }
    }

    requirement def RemoteControlReq {
        doc /* The Insteon Hub shall provide internet connectivity for remote smartphone control. */
        attribute internetConnected : ScalarValues::Boolean;
        require constraint { internetConnected == true }
    }

    requirement def SceneAutomationReq {
        doc /* Devices shall support automated scenes triggered by sensors, schedules, or user commands. */
        attribute sceneSupport : ScalarValues::Boolean;
        attribute maxSceneDevices : ScalarValues::Integer;
        require constraint {
            sceneSupport == true and
            maxSceneDevices >= 10
        }
    }

    requirement def MotionTriggerReq {
        doc /* Motion sensors shall trigger other devices such as lights when motion is detected in low ambient light. */
        attribute motionTriggerEnabled : ScalarValues::Boolean;
        attribute ambientLightThreshold : Illuminance;
        require constraint { motionTriggerEnabled == true }
    }

    // System assembly
    part insteonSystem {
        part hub : InsteonHub;
        part hallwaySwitch : DimmableSwitch;
        part livingRoomSwitch : DimmableSwitch;
        part hallwaySensor : MotionSensor;
        part thermostat : Thermostat;
        part kitchenOutlet : SmartOutlet;
        part livingRoomOutlet : SmartOutlet;
        part keypad : InsteonController;

        interface : PowerlineLink connect hallwaySensor::powerline to hallwaySwitch::powerline;
        interface : RFLink connect hallwaySensor::rf to hallwaySwitch::rf;

        interface : PowerlineLink connect keypad::powerline to livingRoomSwitch::powerline;
        interface : RFLink connect keypad::rf to livingRoomSwitch::rf;

        interface : PowerlineLink connect hub::powerline to thermostat::powerline;
        interface : RFLink connect hub::rf to thermostat::rf;

        satisfy DualBandReliabilityReq by hub;
        satisfy MeshRepeaterReq by hub;
        satisfy PeerToPeerOperationReq by hallwaySwitch;
        satisfy ResponseTimeReq by hallwaySwitch;
        satisfy EnergyMonitoringReq by kitchenOutlet;
        satisfy RemoteControlReq by hub;
        satisfy SceneAutomationReq by livingRoomSwitch;
        satisfy MotionTriggerReq by hallwaySensor;
    }
}
