package PLCBUSHomeAutomation {

    import ScalarValues::*;

    // ---- Value Types ----
    value type Voltage :> Real { unit "V"; }
    value type Frequency :> Real { unit "Hz"; }
    value type BrightnessLevel :> Real { unit "%"; }
    value type ElectricPower :> Real { unit "W"; }
    value type Current :> Real { unit "A"; }

    // ---- Enumerations ----
    enum def CommandKind {
        on;
        off;
        dim;
        bright;
        status_request;
        status_on;
        status_off;
    }

    // ---- Item Definitions ----
    item def Address {
        attribute homeCode : Integer[1..255];
        attribute unitCode : Integer[1..16];
    }

    item def PLCBUSMessage {
        attribute targetAddress : Address;
        attribute sourceAddress : Address;
        attribute command : CommandKind;
        attribute brightness : BrightnessLevel[0..1] = 0;
    }

    item def StatusReport {
        attribute address : Address;
        attribute isOn : Boolean;
        attribute brightness : BrightnessLevel[0..1] = 0;
    }

    // ---- Port Definitions ----
    port def PowerLinePort {
        in item rxMessage : PLCBUSMessage;
        out item txMessage : PLCBUSMessage;
        attribute lineVoltage : Voltage = 120 [V];
        attribute lineFrequency : Frequency = 60 [Hz];
    }

    port def DigitalPort {
        in item rxMessage : PLCBUSMessage;
        out item txMessage : PLCBUSMessage;
    }

    // ---- Interface Definitions ----
    interface def PowerLineInterface {
        end networkSide : PowerLinePort;
        end deviceSide : PowerLinePort;
        attribute carrierFrequency : Frequency = 131 [kHz];
    }

    interface def DigitalInterface {
        end transceiverSide : DigitalPort;
        end deviceSide : DigitalPort;
    }

    // ---- Action Definitions ----
    action def ModulateSignal {
        in message : PLCBUSMessage;
    }

    action def DemodulateSignal {
        out message : PLCBUSMessage;
    }

    action def ExecuteCommand {
        in command : PLCBUSMessage;
    }

    action def TransmitMessage {
        in message : PLCBUSMessage;
    }

    action def ReportStatus {
        in report : StatusReport;
    }

    // ---- Part Definitions ----

    part def PowerLineNetwork {
        attribute nominalVoltage : Voltage = 120 [V];
        attribute nominalFrequency : Frequency = 60 [Hz];
        attribute carrierFrequency : Frequency = 131 [kHz];
        port outlet1 : PowerLinePort;
        port outlet2 : PowerLinePort;
        port outlet3 : PowerLinePort;
        port outlet4 : PowerLinePort;
    }

    part def PLCBUSTransceiver {
        attribute carrierFrequency : Frequency = 131 [kHz];
        port lineSide : PowerLinePort;
        port digitalSide : DigitalPort;

        action modulate : ModulateSignal;
        action demodulate : DemodulateSignal;

        action transmit(in message : PLCBUSMessage) {
            // Modulate digital command onto 131 kHz carrier and emit via lineSide
            perform modulate(message);
        }

        action receive(out message : PLCBUSMessage) {
            // Demodulate incoming 131 kHz signal from lineSide into digital command
            perform demodulate(message);
        }

        state machine TransceiverStateMachine {
            state Idle;
            state Receiving;
            state Transmitting;
            transition from Idle to Receiving when lineSide.rxMessage != null;
            transition from Receiving to Idle;
            transition from Idle to Transmitting when digitalSide.txMessage != null;
            transition from Transmitting to Idle;
        }
    }

    part def Relay {
        attribute isClosed : Boolean = false;
        action close { assign isClosed = true; }
        action open { assign isClosed = false; }
    }

    part def DimmerCircuit {
        attribute brightness : BrightnessLevel = 0 [%];
        action setBrightness(in level : BrightnessLevel) {
            assign brightness = level;
        }
    }

    part def Button {
        attribute isPressed : Boolean = false;
        action press { assign isPressed = true; }
        action release { assign isPressed = false; }
    }

    part def DimmableLight {
        attribute address : Address;
        attribute isOn : Boolean = false;
        attribute brightness : BrightnessLevel = 0 [%];
        attribute maxPower : ElectricPower = 60 [W];

        part relay : Relay;
        part dimmer : DimmerCircuit;
        part transceiver : PLCBUSTransceiver;

        port linePort : PowerLinePort;

        connection : PowerLineInterface connect linePort to transceiver.lineSide;

        action executeCommand : ExecuteCommand {
            if (command.command == CommandKind::on) {
                assign isOn = true;
                assign brightness = 100;
                relay.close;
                dimmer.setBrightness(100);
            } else if (command.command == CommandKind::off) {
                assign isOn = false;
                assign brightness = 0;
                relay.open;
                dimmer.setBrightness(0);
            } else if (command.command == CommandKind::dim) {
                assign brightness = command.brightness;
                dimmer.setBrightness(command.brightness);
            } else if (command.command == CommandKind::status_request) {
                // Prepare status report for two-way communication
            }
        }

        state machine LightStateMachine {
            state Off {
                entry { assign isOn = false; assign brightness = 0; }
            }
            state On {
                entry { assign isOn = true; }
            }
            state Dimmed {
                entry { assign isOn = true; }
            }
            transition from Off to On when transceiver.digitalSide.rxMessage.command == CommandKind::on do { executeCommand(transceiver.digitalSide.rxMessage); };
            transition from On to Off when transceiver.digitalSide.rxMessage.command == CommandKind::off do { executeCommand(transceiver.digitalSide.rxMessage); };
            transition from On to Dimmed when transceiver.digitalSide.rxMessage.command == CommandKind::dim do { executeCommand(transceiver.digitalSide.rxMessage); };
            transition from Dimmed to Off when transceiver.digitalSide.rxMessage.command == CommandKind::off do { executeCommand(transceiver.digitalSide.rxMessage); };
            transition from Dimmed to On when transceiver.digitalSide.rxMessage.command == CommandKind::on do { executeCommand(transceiver.digitalSide.rxMessage); };
        }
    }

    part def SwitchedOutlet {
        attribute address : Address;
        attribute isOn : Boolean = false;
        attribute maxCurrent : Current = 15 [A];

        part relay : Relay;
        part transceiver : PLCBUSTransceiver;

        port linePort : PowerLinePort;

        connection : PowerLineInterface connect linePort to transceiver.lineSide;

        action executeCommand : ExecuteCommand {
            if (command.command == CommandKind::on) {
                assign isOn = true;
                relay.close;
            } else if (command.command == CommandKind::off) {
                assign isOn = false;
                relay.open;
            } else if (command.command == CommandKind::status_request) {
                // Prepare status report for two-way communication
            }
        }

        state machine OutletStateMachine {
            state Off {
                entry { assign isOn = false; }
            }
            state On {
                entry { assign isOn = true; }
            }
            transition from Off to On when transceiver.digitalSide.rxMessage.command == CommandKind::on do { executeCommand(transceiver.digitalSide.rxMessage); };
            transition from On to Off when transceiver.digitalSide.rxMessage.command == CommandKind::off do { executeCommand(transceiver.digitalSide.rxMessage); };
        }
    }

    part def WallSwitch {
        attribute address : Address;
        attribute targetAddress : Address;
        attribute commandToSend : CommandKind = CommandKind::on;

        part transceiver : PLCBUSTransceiver;
        part button : Button;

        port linePort : PowerLinePort;

        connection : PowerLineInterface connect linePort to transceiver.lineSide;

        action press {
            transceiver.transmit(PLCBUSMessage {
                targetAddress = targetAddress,
                sourceAddress = address,
                command = commandToSend,
                brightness = 0
            });
        }

        state machine SwitchStateMachine {
            state Idle;
            state Pressed;
            transition from Idle to Pressed when button.isPressed == true do { press; };
            transition from Pressed to Idle when button.isPressed == false;
        }
    }

    part def PLCBUSController {
        attribute address : Address;
        attribute supportsTwoWay : Boolean = true;
        attribute schedule : Integer[*];

        part transceiver : PLCBUSTransceiver;

        port linePort : PowerLinePort;

        connection : PowerLineInterface connect linePort to transceiver.lineSide;

        action sendCommand(in target : Address, in cmd : CommandKind, in level : BrightnessLevel) {
            transceiver.transmit(PLCBUSMessage {
                targetAddress = target,
                sourceAddress = address,
                command = cmd,
                brightness = level
            });
        }

        action receiveStatus(in report : StatusReport) {
            // Log and process status report from a remote device
        }

        state machine ControllerStateMachine {
            state Monitoring;
            state Scheduling;
            state Commanding;
            transition from Monitoring to Commanding when schedule.size > 0;
            transition from Commanding to Monitoring;
            transition from Monitoring to Scheduling when transceiver.digitalSide.rxMessage != null;
            transition from Scheduling to Monitoring;
        }
    }

    // ---- System Assembly ----
    part def HomeAutomationSystem {
        part powerLine : PowerLineNetwork;

        part livingRoomLight : DimmableLight {
            attribute address : Address = Address { homeCode = 1; unitCode = 1; };
        }

        part kitchenOutlet : SwitchedOutlet {
            attribute address : Address = Address { homeCode = 1; unitCode = 2; };
        }

        part hallwaySwitch : WallSwitch {
            attribute address : Address = Address { homeCode = 1; unitCode = 3; };
            attribute targetAddress : Address = Address { homeCode = 1; unitCode = 1; };
            attribute commandToSend : CommandKind = CommandKind::on;
        }

        part mainController : PLCBUSController {
            attribute address : Address = Address { homeCode = 1; unitCode = 4; };
        }

        connection : PowerLineInterface connect powerLine.outlet1 to livingRoomLight.linePort;
        connection : PowerLineInterface connect powerLine.outlet2 to kitchenOutlet.linePort;
        connection : PowerLineInterface connect powerLine.outlet3 to hallwaySwitch.linePort;
        connection : PowerLineInterface connect powerLine.outlet4 to mainController.linePort;
    }

    // ---- Requirements ----
    requirement def PLCBUSCommunicationRequirement {
        subject system : HomeAutomationSystem;
        doc /* The system shall transmit digital commands over the existing AC power wiring at a carrier frequency of approximately 131 kHz. */;
        require system.powerLine.carrierFrequency == 131 [kHz];
    }

    requirement def RemoteControlRequirement {
        subject system : HomeAutomationSystem;
        doc /* A wall switch shall broadcast a PLCBUS message containing the target device address and command when pressed. */;
        require system.hallwaySwitch.commandToSend != null;
    }

    requirement def AddressMatchingRequirement {
        subject system : HomeAutomationSystem;
        doc /* Only the device whose address matches the target address in a PLCBUS message shall execute the command. */;
        require system.livingRoomLight.address == system.hallwaySwitch.targetAddress;
    }

    requirement def TwoWayCommunicationRequirement {
        subject system : HomeAutomationSystem;
        doc /* The system shall support two-way communication allowing devices to report status back to the controller. */;
        require system.mainController.supportsTwoWay == true;
    }

    requirement def DimmingRequirement {
        subject system : HomeAutomationSystem;
        doc /* Dimmable lights shall support on, off, and brightness adjustment commands. */;
        require system.livingRoomLight.brightness >= 0 and system.livingRoomLight.brightness <= 100;
    }

    requirement def PowerLineMediumRequirement {
        subject system : HomeAutomationSystem;
        doc /* All intelligent devices shall connect to the power line network for both power and communication. */;
        require system.powerLine.nominalVoltage == 120 [V] and system.powerLine.nominalFrequency == 60 [Hz];
    }

}
