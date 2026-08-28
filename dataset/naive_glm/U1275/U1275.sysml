package BticinoLightingControl {

    import ScalarValues::*;
    import ISQ::*;

    // ---------- Value Types ----------
    value type Voltage :> Real { unit 'V'; }
    value type Current :> Real { unit 'A'; }
    value type Power :> Real { unit 'W'; }
    value type BrightnessLevel :> Integer { min 0; max 100; }
    value type DeviceAddress :> Natural;

    item def SCSMessage {
        attribute source : DeviceAddress;
        attribute destination : DeviceAddress;
        attribute command : LightingCommand;
        attribute brightness : BrightnessLevel default 100;
    }

    enum def LightingCommand {
        turnOn;
        turnOff;
        dim;
        toggle;
    }

    enum def ScenarioName {
        welcome;
        goodnight;
        away;
    }

    // ---------- Ports ----------
    port def SCSBusPort {
        out message : SCSMessage;
        in incomingMessage : SCSMessage;
    }

    port def ACInputPort {
        in voltage : Voltage = 230 [V];
    }

    port def DCOutputPort {
        out voltage : Voltage = 27 [V];
        out current : Current;
    }

    port def LoadPort {
        out voltage : Voltage;
        out current : Current;
    }

    // ---------- Interfaces ----------
    interface def SCSBusInterface {
        end supplier : SCSBusPort;
        end consumer : SCSBusPort;
    }

    interface def PowerSupplyInterface {
        end supplier : DCOutputPort;
        end consumer : DCOutputPort;
    }

    // ---------- Abstract Base Device ----------
    part def BticinoDevice {
        attribute deviceAddress : DeviceAddress;
        port busPort : SCSBusPort;
        port powerPort : DCOutputPort;
    }

    // ---------- Power Supply Unit ----------
    part def PowerSupplyUnit :> BticinoDevice {
        attribute inputVoltage : Voltage = 230 [V];
        attribute outputVoltage : Voltage = 27 [V];
        attribute ratedPower : Power = 60 [W];
        attribute maxCurrent : Current = 2.2 [A];

        port acInput : ACInputPort;

        action def ConvertPower {
            in acIn : Voltage;
            out dcOut : Voltage;
        }

        perform convert : ConvertPower {
            in acIn = acInput.voltage;
            out dcOut = powerPort.voltage;
        }

        state def PowerSupplyStates;
        state behavior : PowerSupplyStates {
            entry; then Off;
            state Off;
            state On;
            transition off_to_on first Off then On
                when acInput.voltage > 0 [V];
            transition on_to_off first On then Off
                when acInput.voltage == 0 [V];
        }
    }

    // ---------- Light Actuator ----------
    part def LightActuator :> BticinoDevice {
        attribute room : String;
        attribute currentBrightness : BrightnessLevel = 0;
        attribute isOn : Boolean = false;

        port loadPort : LoadPort;

        action def ExecuteCommand {
            in msg : SCSMessage;
            out newBrightness : BrightnessLevel;
        }

        perform execute : ExecuteCommand {
            in msg = busPort.incomingMessage;
            out newBrightness = currentBrightness;
        }

        state def ActuatorStates;
        state behavior : ActuatorStates {
            entry; then LightsOff;
            state LightsOff {
                entry { currentBrightness = 0; isOn = false; }
            }
            state LightsOn {
                entry { isOn = true; }
            }
            state Dimmed {
                entry { isOn = true; }
            }
            transition off_to_on first LightsOff then LightsOn
                when busPort.incomingMessage.command == LightingCommand::turnOn
                and busPort.incomingMessage.destination == deviceAddress;
            transition on_to_off first LightsOn then LightsOff
                when busPort.incomingMessage.command == LightingCommand::turnOff
                and busPort.incomingMessage.destination == deviceAddress;
            transition on_to_dim first LightsOn then Dimmed
                when busPort.incomingMessage.command == LightingCommand::dim
                and busPort.incomingMessage.destination == deviceAddress;
            transition dim_to_dim first Dimmed then Dimmed
                when busPort.incomingMessage.command == LightingCommand::dim
                and busPort.incomingMessage.destination == deviceAddress;
            transition dim_to_off first Dimmed then LightsOff
                when busPort.incomingMessage.command == LightingCommand::turnOff
                and busPort.incomingMessage.destination == deviceAddress;
            transition dim_to_on first Dimmed then LightsOn
                when busPort.incomingMessage.command == LightingCommand::turnOn
                and busPort.incomingMessage.destination == deviceAddress;
        }
    }

    // ---------- Touch Sensor ----------
    part def TouchSensor :> BticinoDevice {
        attribute location : String;
        attribute associatedActuatorAddress : DeviceAddress;
        attribute associatedScenario : ScenarioName;

        action def GenerateCommand {
            in pressed : Boolean;
            out msg : SCSMessage;
        }

        perform generate : GenerateCommand {
            in pressed = true;
            out msg = busPort.message;
        }

        state def SensorStates;
        state behavior : SensorStates {
            entry; then Idle;
            state Idle;
            state Pressed {
                entry {
                    busPort.message.source = deviceAddress;
                    busPort.message.destination = associatedActuatorAddress;
                    busPort.message.command = LightingCommand::toggle;
                }
            }
            transition idle_to_pressed first Idle then Pressed
                when true;
            transition pressed_to_idle first Pressed then Idle
                when true;
        }
    }

    // ---------- Scenario Controller ----------
    part def ScenarioController :> BticinoDevice {
        attribute programmedScenarios : ScenarioName[0..*];

        action def ActivateScenario {
            in scenario : ScenarioName;
            out messages : SCSMessage[0..*];
        }

        perform activate : ActivateScenario {
            in scenario = busPort.incomingMessage.command as ScenarioName;
            out messages = busPort.message;
        }

        state def ControllerStates;
        state behavior : ControllerStates {
            entry; then Standby;
            state Standby;
            state ExecutingScenario;
            transition standby_to_exec first Standby then ExecutingScenario
                when busPort.incomingMessage.destination == deviceAddress;
            transition exec_to_standby first ExecutingScenario then Standby
                when activate.done;
        }
    }

    // ---------- SCS Bus ----------
    part def SCSBus {
        attribute busVoltage : Voltage = 27 [V];
        attribute maxDevices : Integer = 100;
        port busPorts : SCSBusPort[0..*];

        action def RouteMessage {
            in msg : SCSMessage;
            out routed : SCSMessage;
        }
    }

    // ---------- Light ----------
    part def Light {
        attribute room : String;
        attribute brightness : BrightnessLevel = 0;
        port powerInput : LoadPort;

        state def LightStates;
        state behavior : LightStates {
            entry; then Dark;
            state Dark;
            state Illuminated;
            transition dark_to_lit first Dark then Illuminated
                when powerInput.voltage > 0 [V];
            transition lit_to_dark first Illuminated then Dark
                when powerInput.voltage == 0 [V];
        }
    }

    // ---------- Requirements ----------
    requirement def PowerConversionRequirement {
        subject psu : PowerSupplyUnit;
        requirement {
            psu.outputVoltage == 27 [V];
        }
    }

    requirement def BusCommunicationRequirement {
        subject bus : SCSBus;
        requirement {
            bus.busVoltage == 27 [V];
        }
    }

    requirement def ActuatorCommandRequirement {
        subject actuator : LightActuator;
        requirement {
            actuator.busPort.incomingMessage.destination == actuator.deviceAddress
            implies actuator.execute.done;
        }
    }

    requirement def ScenarioExecutionRequirement {
        subject controller : ScenarioController;
        requirement {
            controller.activate.done implies controller.busPort.message.sent;
        }
    }

    // ---------- System Assembly ----------
    part BticinoHomeAutomationSystem {

        part powerSupply : PowerSupplyUnit {
            attribute deviceAddress = 1;
        }

        part scsBus : SCSBus;

        part livingRoomActuator : LightActuator {
            attribute deviceAddress = 10;
            attribute room = "Living Room";
        }

        part bedroomActuator : LightActuator {
            attribute deviceAddress = 11;
            attribute room = "Bedroom";
        }

        part kitchenActuator : LightActuator {
            attribute deviceAddress = 12;
            attribute room = "Kitchen";
        }

        part hallwayActuator : LightActuator {
            attribute deviceAddress = 13;
            attribute room = "Hallway";
        }

        part entranceSensor : TouchSensor {
            attribute deviceAddress = 20;
            attribute location = "Entrance";
            attribute associatedActuatorAddress = 13;
            attribute associatedScenario = ScenarioName::welcome;
        }

        part livingRoomSensor : TouchSensor {
            attribute deviceAddress = 21;
            attribute location = "Living Room";
            attribute associatedActuatorAddress = 10;
            attribute associatedScenario = ScenarioName::goodnight;
        }

        part bedroomSensor : TouchSensor {
            attribute deviceAddress = 22;
            attribute location = "Bedroom";
            attribute associatedActuatorAddress = 11;
            attribute associatedScenario = ScenarioName::goodnight;
        }

        part scenarioController : ScenarioController {
            attribute deviceAddress = 30;
            attribute programmedScenarios = (ScenarioName::welcome, ScenarioName::goodnight, ScenarioName::away);
        }

        part livingRoomLight : Light {
            attribute room = "Living Room";
        }
        part bedroomLight : Light {
            attribute room = "Bedroom";
        }
        part kitchenLight : Light {
            attribute room = "Kitchen";
        }
        part hallwayLight : Light {
            attribute room = "Hallway";
        }

        // Power connections
        connection powerToBus : PowerSupplyInterface connect powerSupply.powerPort to scsBus.busPorts[0];
        connection powerToLivingAct : PowerSupplyInterface connect powerSupply.powerPort to livingRoomActuator.powerPort;
        connection powerToBedroomAct : PowerSupplyInterface connect powerSupply.powerPort to bedroomActuator.powerPort;
        connection powerToKitchenAct : PowerSupplyInterface connect powerSupply.powerPort to kitchenActuator.powerPort;
        connection powerToHallwayAct : PowerSupplyInterface connect powerSupply.powerPort to hallwayActuator.powerPort;
        connection powerToEntranceSensor : PowerSupplyInterface connect powerSupply.powerPort to entranceSensor.powerPort;
        connection powerToLivingSensor : PowerSupplyInterface connect powerSupply.powerPort to livingRoomSensor.powerPort;
        connection powerToBedroomSensor : PowerSupplyInterface connect powerSupply.powerPort to bedroomSensor.powerPort;
        connection powerToController : PowerSupplyInterface connect powerSupply.powerPort to scenarioController.powerPort;

        // Bus connections
        connection busToPowerSupply : SCSBusInterface connect scsBus.busPorts[1] to powerSupply.busPort;
        connection busToLivingAct : SCSBusInterface connect scsBus.busPorts[2] to livingRoomActuator.busPort;
        connection busToBedroomAct : SCSBusInterface connect scsBus.busPorts[3] to bedroomActuator.busPort;
        connection busToKitchenAct : SCSBusInterface connect scsBus.busPorts[4] to kitchenActuator.busPort;
        connection busToHallwayAct : SCSBusInterface connect scsBus.busPorts[5] to hallwayActuator.busPort;
        connection busToEntranceSensor : SCSBusInterface connect scsBus.busPorts[6] to entranceSensor.busPort;
        connection busToLivingSensor : SCSBusInterface connect scsBus.busPorts[7] to livingRoomSensor.busPort;
        connection busToBedroomSensor : SCSBusInterface connect scsBus.busPorts[8] to bedroomSensor.busPort;
        connection busToController : SCSBusInterface connect scsBus.busPorts[9] to scenarioController.busPort;

        // Load connections
        connection livingActToLight : PowerSupplyInterface connect livingRoomActuator.loadPort to livingRoomLight.powerInput;
        connection bedroomActToLight : PowerSupplyInterface connect bedroomActuator.loadPort to bedroomLight.powerInput;
        connection kitchenActToLight : PowerSupplyInterface connect kitchenActuator.loadPort to kitchenLight.powerInput;
        connection hallwayActToLight : PowerSupplyInterface connect hallwayActuator.loadPort to hallwayLight.powerInput;

        // Requirements satisfaction
        satisfy psuReq : PowerConversionRequirement by powerSupply;
        satisfy busReq : BusCommunicationRequirement by scsBus;
        satisfy actReq1 : ActuatorCommandRequirement by livingRoomActuator;
        satisfy actReq2 : ActuatorCommandRequirement by bedroomActuator;
        satisfy actReq3 : ActuatorCommandRequirement by kitchenActuator;
        satisfy actReq4 : ActuatorCommandRequirement by hallwayActuator;
        satisfy scenarioReq : ScenarioExecutionRequirement by scenarioController;
    }
}
