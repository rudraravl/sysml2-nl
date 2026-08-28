package HomeAutomationSystem {
    import ScalarValues::*;

    // ---- Value Types ----
    value type Voltage :> Real;
    value type Current :> Real;
    value type Power :> Real;
    value type Temperature :> Real;
    value type BrightnessPercent :> Real;
    value type BusAddress :> Integer;

    // ---- Item Definitions ----
    item def OpenWebNetMessage {
        attribute command : String;
        attribute targetAddress : BusAddress;
        attribute sourceAddress : BusAddress;
        attribute payload : String;
        attribute isValid : Boolean;
    }

    item def PowerSignal {
        attribute voltage : Voltage;
        attribute current : Current;
    }

    item def StatusReport {
        attribute deviceAddress : BusAddress;
        attribute deviceType : String;
        attribute stateValue : String;
    }

    // ---- Port Definitions ----
    port def BusPort {
        out item transmit : OpenWebNetMessage;
        in item receive : OpenWebNetMessage;
        in item power : PowerSignal;
    }

    port def EthernetPort {
        in item incoming : OpenWebNetMessage;
        out item outgoing : OpenWebNetMessage;
    }

    // ---- Requirements ----
    requirement def CentralizedControlRequirement {
        doc "The system shall provide centralized management of all connected smart devices via a shared communication bus.";
    }

    requirement def RemoteAccessRequirement {
        doc "The gateway shall bridge the internal device bus to a standard home network, enabling remote control from client applications.";
    }

    requirement def PowerDistributionRequirement {
        doc "The power supply unit shall convert household mains voltage to low-voltage DC and distribute both power and data signals over the same bus wires.";
    }

    requirement def LightingControlRequirement {
        doc "Each lighting actuator shall turn lights on and off and shall support dimming to a specified brightness level.";
    }

    requirement def ClimateControlRequirement {
        doc "The thermostat shall continuously monitor room temperature and activate heating or cooling to maintain the target temperature within a defined tolerance.";
    }

    requirement def ScenarioAutomationRequirement {
        doc "The scenario controller shall execute pre-programmed coordinated actions across multiple devices in response to a single trigger command.";
    }

    requirement def BusAddressingRequirement {
        doc "Every device on the bus shall be identified by a unique bus address used for message routing.";
    }

    // ---- Lighting Actuator ----
    part def LightingActuator {
        attribute address : BusAddress;
        attribute location : String;
        attribute maxBrightness : BrightnessPercent = 100;
        attribute currentBrightness : BrightnessPercent = 0;
        attribute isOn : Boolean = false;

        port busPort : BusPort;

        satisfy LightingControlRequirement;
        satisfy BusAddressingRequirement;

        state machine lightingState {
            state Off {
                entry { isOn = false; currentBrightness = 0; }
            }
            state On {
                entry { isOn = true; currentBrightness = maxBrightness; }
            }
            state Dimmed {
                entry { isOn = true; }
            }
            transition Off -> On when busPort.receive.command == "ON";
            transition On -> Off when busPort.receive.command == "OFF";
            transition On -> Dimmed when busPort.receive.command == "DIM";
            transition Dimmed -> Off when busPort.receive.command == "OFF";
            transition Dimmed -> On when busPort.receive.command == "ON";
        }

        action setBrightness(in level : BrightnessPercent) {
            currentBrightness = level;
        }

        action reportStatus {
            /* transmit current brightness and on/off state on bus */
        }
    }

    // ---- Thermostat ----
    part def Thermostat {
        attribute address : BusAddress;
        attribute location : String;
        attribute currentTemperature : Temperature = 22;
        attribute targetTemperature : Temperature = 21;
        attribute tolerance : Temperature = 1;
        attribute heatingActive : Boolean = false;
        attribute coolingActive : Boolean = false;

        port busPort : BusPort;

        satisfy ClimateControlRequirement;
        satisfy BusAddressingRequirement;

        state machine climateState {
            state Idle {
                entry { heatingActive = false; coolingActive = false; }
            }
            state Heating {
                entry { heatingActive = true; coolingActive = false; }
            }
            state Cooling {
                entry { heatingActive = false; coolingActive = true; }
            }
            transition Idle -> Heating when currentTemperature < (targetTemperature - tolerance);
            transition Idle -> Cooling when currentTemperature > (targetTemperature + tolerance);
            transition Heating -> Idle when currentTemperature >= targetTemperature;
            transition Cooling -> Idle when currentTemperature <= targetTemperature;
        }

        action readTemperature {
            /* read current room temperature from integrated sensor */
        }

        action setTargetTemperature(in target : Temperature) {
            targetTemperature = target;
        }

        action reportStatus {
            /* transmit current and target temperatures on bus */
        }
    }

    // ---- Power Supply Unit ----
    part def PowerSupplyUnit {
        attribute inputVoltage : Voltage = 230;
        attribute outputVoltage : Voltage = 27;
        attribute outputCurrent : Current = 2;
        attribute ratedPower : Power = 54;
        attribute isOperational : Boolean = true;

        port busPort : BusPort;

        satisfy PowerDistributionRequirement;

        action convertPower {
            /* convert 230V AC mains to 27V DC for bus power */
        }

        action distributePower {
            /* distribute DC power and data signals over shared bus wires */
        }

        action monitorOutput {
            /* verify output voltage and current remain within specification */
        }
    }

    // ---- Bus Gateway ----
    part def BusGateway {
        attribute ipAddress : String = "192.168.1.100";
        attribute macAddress : String = "00:1A:2B:3C:4D:5E";
        attribute connected : Boolean = false;
        attribute firmwareVersion : String = "2.4.1";

        port busPort : BusPort;
        port networkPort : EthernetPort;

        satisfy RemoteAccessRequirement;
        satisfy BusAddressingRequirement;

        state machine gatewayState {
            state Disconnected {
                entry { connected = false; }
            }
            state Connected {
                entry { connected = true; }
            }
            state Validating {
                /* validate incoming command format, address, and authorization */
            }
            state Routing {
                /* route validated command to target device on bus */
            }
            state ForwardingStatus {
                /* forward device status updates to network clients */
            }
            transition Disconnected -> Connected when networkPort.incoming.command == "CONNECT";
            transition Connected -> Disconnected when networkPort.incoming.command == "DISCONNECT";
            transition Connected -> Validating when networkPort.incoming.command != "";
            transition Validating -> Routing when networkPort.incoming.isValid == true;
            transition Validating -> Connected when networkPort.incoming.isValid == false;
            transition Routing -> Connected when true;
            transition Connected -> ForwardingStatus when busPort.receive.command == "STATUS";
            transition ForwardingStatus -> Connected when true;
        }

        action receiveExternalCommand {
            /* accept command from smartphone app or network client */
        }

        action validateCommand {
            /* verify command syntax, target address validity, and user authorization */
        }

        action routeToBus {
            /* transmit validated command onto the bus addressed to the target device */
        }

        action listenForStatus {
            /* poll or listen for unsolicited status updates from bus devices */
        }

        action sendStatusToNetwork {
            /* forward status reports to connected remote clients */
        }
    }

    // ---- Scenario Controller ----
    part def ScenarioController {
        attribute address : BusAddress;
        attribute activeScenario : String = "None";
        attribute eveningLivingRoomBrightness : BrightnessPercent = 30;
        attribute eveningBedroomBrightness : BrightnessPercent = 50;
        attribute eveningTargetTemp : Temperature = 19;
        attribute morningLivingRoomBrightness : BrightnessPercent = 100;
        attribute morningBedroomBrightness : BrightnessPercent = 0;
        attribute morningTargetTemp : Temperature = 21;

        port busPort : BusPort;

        satisfy ScenarioAutomationRequirement;
        satisfy BusAddressingRequirement;

        action executeEveningMode {
            /* dim living room lights, turn on bedroom light, lower thermostat target */
        }

        action executeMorningMode {
            /* brighten living room lights, turn off bedroom light, raise thermostat target */
        }

        action executeAwayMode {
            /* turn off all lights, set thermostat to energy-saving target */
        }

        action triggerScenario(in scenarioName : String) {
            if scenarioName == "Evening" { executeEveningMode(); }
            if scenarioName == "Morning" { executeMorningMode(); }
            if scenarioName == "Away" { executeAwayMode(); }
        }
    }

    // ---- Communication Bus ----
    part def CommunicationBus {
        attribute busVoltage : Voltage = 27;
        attribute maxDevices : Integer = 100;
        attribute connectedDeviceCount : Integer = 0;
        attribute protocol : String = "OpenWebNet";

        port busPort : BusPort;
    }

    // ---- Smartphone Application (Remote Client) ----
    part def SmartphoneApp {
        attribute appName : String = "HomeControl";
        attribute isConnected : Boolean = false;

        port networkPort : EthernetPort;

        action sendCommand(in cmd : OpenWebNetMessage) {
            /* transmit command to gateway over home network */
        }

        action receiveStatus {
            /* display device status updates received from gateway */
        }

        action triggerScenario(in scenarioName : String) {
            /* send scenario activation command to gateway */
        }
    }

    // ---- Top-Level Home Automation System ----
    part def HomeAutomationSystem {
        satisfy CentralizedControlRequirement;

        part gateway : BusGateway;
        part powerSupply : PowerSupplyUnit;
        part bus : CommunicationBus;
        part smartphoneApp : SmartphoneApp;

        part livingRoomLight : LightingActuator {
            attribute address = 1;
            attribute location = "Living Room";
        }
        part kitchenLight : LightingActuator {
            attribute address = 2;
            attribute location = "Kitchen";
        }
        part bedroomLight : LightingActuator {
            attribute address = 3;
            attribute location = "Bedroom";
        }
        part thermostat : Thermostat {
            attribute address = 10;
            attribute location = "Main Hall";
        }
        part scenarioController : ScenarioController {
            attribute address = 20;
        }

        // Bus connections — power and data over shared wires
        connection busGatewayLink connect gateway.busPort to bus.busPort;
        connection busPsuLink connect powerSupply.busPort to bus.busPort;
        connection busLivingRoomLink connect livingRoomLight.busPort to bus.busPort;
        connection busKitchenLink connect kitchenLight.busPort to bus.busPort;
        connection busBedroomLink connect bedroomLight.busPort to bus.busPort;
        connection busThermostatLink connect thermostat.busPort to bus.busPort;
        connection busScenarioLink connect scenarioController.busPort to bus.busPort;

        // Network connection — smartphone app to gateway
        connection networkLink connect smartphoneApp.networkPort to gateway.networkPort;
    }
}
