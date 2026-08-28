package HomeLinkSystem {
    import ScalarValues::*;
    import ISQ::*;
    import ISQSpace::*;
    import ISQTime::*;

    // ---- Value types with units ----
    value def Voltage :> Real { unit 'V'; }
    value def Frequency :> Real { unit 'MHz'; }
    value def Distance :> Real { unit 'm'; }
    value def Power :> Real { unit 'W'; }
    value def Duration :> Real { unit 's'; }
    value def SignalStrength :> Real { unit 'dBm'; }

    // ---- Enumerations ----
    enum def DoorState { OPEN; CLOSED; MOVING; STOPPED; }
    enum def ButtonState { PRESSED; RELEASED; }
    enum def ModuleMode { NORMAL; LEARNING; }
    enum def CommandKind { OPEN; CLOSE; STOP; TOGGLE; }
    enum def AuthResult { VALID; INVALID; REPLAY_DETECTED; }

    // ---- Item definitions ----
    item def DeviceCode {
        attribute manufacturerId : Integer;
        attribute deviceId : Integer;
        attribute slotId : Integer;
    }

    item def RollingCode {
        attribute sequenceNumber : Integer;
        attribute seed : Integer;
        attribute encryptedValue : Integer;
    }

    item def RFSignal {
        attribute carrierFrequency : Frequency;
        attribute code : RollingCode;
        attribute deviceCode : DeviceCode;
        attribute strength : SignalStrength;
    }

    item def ActivationCommand {
        attribute kind : CommandKind;
        attribute targetDeviceId : Integer;
    }

    item def ButtonPress {
        attribute buttonId : Integer;
        attribute timestamp : Duration;
    }

    item def RemoteSignal {
        attribute manufacturerId : Integer;
        attribute deviceId : Integer;
        attribute capturedCode : RollingCode;
    }

    // ---- Port definitions ----
    port def PowerPort {
        attribute voltage : Voltage;
        in item electricPower : Power;
    }

    port def RFAntennaPort {
        out item outgoingSignal : RFSignal;
        in item incomingSignal : RFSignal;
    }

    port def ButtonEventPort {
        out item press : ButtonPress;
    }

    port def ProcessorMemoryPort {
        out item readRequest : Integer;
        in item readData : DeviceCode;
        in item writeRequest : DeviceCode;
    }

    port def ProcessorDataPort {
        out item txPayload : RFSignal;
        in item rxPayload : RFSignal;
    }

    port def ActivationPort {
        out item command : ActivationCommand;
    }

    port def DoorStatusPort {
        out attribute state : DoorState;
    }

    // ---- Requirements ----
    requirement def HomeLinkRequirements {
        subject system : HomeLinkSystem;

        requirement PowerRequirement {
            subject module : TransmitterModule;
            doc /* The transmitter module shall be powered by the vehicle's 12V electrical system. */
            attribute supplyVoltage : Voltage = 12 [V];
        }

        requirement ButtonCountRequirement {
            subject module : TransmitterModule;
            doc /* The module shall feature three programmable buttons. */
            attribute buttonCount : Integer = 3;
        }

        requirement OperatingRangeRequirement {
            subject system : HomeLinkSystem;
            doc /* The system shall have a reliable operating range of at least 30 meters. */
            attribute minRange : Distance = 30 [m];
        }

        requirement FrequencyRequirement {
            subject transceiver : RFTransceiver;
            doc /* The transceiver shall transmit on the 315 MHz frequency band. */
            attribute carrierFrequency : Frequency = 315 [MHz];
        }

        requirement RollingCodeRequirement {
            subject module : TransmitterModule;
            doc /* The module shall use a rolling code system to prevent unauthorized replay attacks. */
        }

        requirement MemorySlotRequirement {
            subject memory : MemoryUnit;
            doc /* The memory unit shall store up to three device codes. */
            attribute slotCount : Integer = 3;
        }

        requirement LearningModeRequirement {
            subject module : TransmitterModule;
            doc /* The module shall support a learning mode to capture signals from existing handheld remotes. */
        }

        requirement AuthenticationRequirement {
            subject receiver : ReceiverSystem;
            doc /* The receiver shall authenticate the rolling code before activating the door mechanism. */
        }
    }

    // ---- Part definitions ----
    part def HomeLinkSystem {
        part transmitter : TransmitterModule;
        part receiver : ReceiverSystem;
        part garageDoor : GarageDoor;

        connection vehiclePower : PowerPort connect transmitter.powerIn to receiver.powerIn;
        connection rfChannel : RFAntennaPort connect transmitter.antennaPort to receiver.antennaPort;
        connection activationLink : ActivationPort connect receiver.activationPort to garageDoor.activationPort;
        connection statusFeedback : DoorStatusPort connect garageDoor.statusPort to receiver.statusPort;
    }

    part def TransmitterModule {
        port powerIn : PowerPort { voltage = 12 [V]; }
        port antennaPort : RFAntennaPort;
        port buttonInterface : ButtonEventPort;

        attribute mode : ModuleMode = ModuleMode::NORMAL;
        attribute supplyVoltage : Voltage = 12 [V];
        attribute carrierFrequency : Frequency = 315 [MHz];
        attribute operatingRange : Distance = 30 [m];

        part processor : Processor;
        part memory : MemoryUnit;
        part transceiver : RFTransceiver;
        part buttons[3] : ProgrammableButton;

        connection powerToProcessor : PowerPort connect powerIn to processor.powerIn;
        connection powerToMemory : PowerPort connect powerIn to memory.powerIn;
        connection powerToTransceiver : PowerPort connect powerIn to transceiver.powerIn;
        connection powerToButtons : PowerPort connect powerIn to buttons.powerIn;

        connection buttonToProcessor : ButtonEventPort connect buttons.eventPort to processor.buttonInput;
        connection processorMemoryLink : ProcessorMemoryPort connect processor.memoryPort to memory.accessPort;
        connection processorTransceiverLink : ProcessorDataPort connect processor.dataPort to transceiver.dataPort;
        connection transceiverAntennaLink : RFAntennaPort connect transceiver.antennaPort to antennaPort;

        exhibit state def TransmitterBehavior {
            entry action { mode := ModuleMode::NORMAL; }

            state normalMode {
                entry action { mode := ModuleMode::NORMAL; }
                on buttonInterface.press do {
                    if mode == ModuleMode::NORMAL {
                        // Processor retrieves device code, generates rolling code, transmits.
                    }
                }
            }

            state learningMode {
                entry action { mode := ModuleMode::LEARNING; }
                // Module listens for an existing handheld remote signal and stores it.
            }

            transition enterLearning normalMode to learningMode
                when buttonInterface.press.buttonId == 0;
            transition exitLearning learningMode to normalMode
                when memory.accessPort.writeRequest.slotId >= 0;
        }
    }

    part def Processor {
        port powerIn : PowerPort;
        port buttonInput : ButtonEventPort;
        port memoryPort : ProcessorMemoryPort;
        port dataPort : ProcessorDataPort;

        attribute currentSequence : Integer = 0;
        attribute encryptionSeed : Integer;

        action def GenerateRollingCode {
            in deviceCode : DeviceCode;
            out signal : RFSignal;
            perform {
                currentSequence := currentSequence + 1;
                signal.code.sequenceNumber := currentSequence;
                signal.code.seed := encryptionSeed;
                signal.code.encryptedValue := currentSequence * encryptionSeed + deviceCode.deviceId;
                signal.deviceCode := deviceCode;
                signal.carrierFrequency := 315 [MHz];
            }
        }

        action def LearnRemote {
            in captured : RemoteSignal;
            out stored : DeviceCode;
            perform {
                stored.manufacturerId := captured.manufacturerId;
                stored.deviceId := captured.deviceId;
                stored.slotId := 0;
            }
        }
    }

    part def MemoryUnit {
        port powerIn : PowerPort;
        port accessPort : ProcessorMemoryPort;

        attribute slotCount : Integer = 3;
        attribute storedCodes[3] : DeviceCode;

        action def ReadSlot {
            in slotId : Integer;
            out code : DeviceCode;
            perform { code := storedCodes[slotId]; }
        }

        action def WriteSlot {
            in code : DeviceCode;
            perform { storedCodes[code.slotId] := code; }
        }
    }

    part def RFTransceiver {
        port powerIn : PowerPort;
        port dataPort : ProcessorDataPort;
        port antennaPort : RFAntennaPort;

        attribute carrierFrequency : Frequency = 315 [MHz];
        attribute transmitPower : Power = 0.01 [W];

        action def Transmit {
            in payload : RFSignal;
            out emitted : RFSignal;
            perform {
                emitted := payload;
                emitted.carrierFrequency := carrierFrequency;
                emitted.strength := 10.0 [dBm];
            }
        }

        action def Receive {
            in incoming : RFSignal;
            out payload : RFSignal;
            perform { payload := incoming; }
        }
    }

    part def ProgrammableButton {
        port powerIn : PowerPort;
        port eventPort : ButtonEventPort;

        attribute buttonId : Integer;
        attribute state : ButtonState = ButtonState::RELEASED;

        action def Press {
            out press : ButtonPress;
            perform {
                state := ButtonState::PRESSED;
                press.buttonId := buttonId;
            }
        }

        action def Release {
            perform { state := ButtonState::RELEASED; }
        }
    }

    part def ReceiverSystem {
        port powerIn : PowerPort;
        port antennaPort : RFAntennaPort;
        port activationPort : ActivationPort;
        port statusPort : DoorStatusPort;

        part receiverProcessor : ReceiverProcessor;
        part authenticator : RollingCodeAuthenticator;
        part actuator : DoorActuator;

        connection powerToReceiverProcessor : PowerPort connect powerIn to receiverProcessor.powerIn;
        connection powerToAuthenticator : PowerPort connect powerIn to authenticator.powerIn;
        connection powerToActuator : PowerPort connect powerIn to actuator.powerIn;

        connection antennaToProcessor : RFAntennaPort connect antennaPort to receiverProcessor.antennaPort;
        connection processorToAuthenticator : >> AuthLink connect receiverProcessor.authPort to authenticator.verifyPort;
        connection authenticatorToProcessor : >> AuthResultLink connect authenticator.resultPort to receiverProcessor.resultPort;
        connection processorToActuator : ActivationPort connect receiverProcessor.commandPort to actuator.commandPort;
        connection actuatorToActivation : ActivationPort connect actuator.outputPort to activationPort;

        exhibit state def ReceiverBehavior {
            state idle {
                on antennaPort.incomingSignal do {
                    // Forward signal to authenticator for verification.
                }
            }
            state authenticating {
                // Wait for authentication result.
            }
            state activating {
                // Send activation command to door actuator.
            }
            transition idleToAuth idle to authenticating
                when antennaPort.incomingSignal.code.sequenceNumber > 0;
            transition authToActivating authenticating to activating
                when authenticator.resultPort.out.result == AuthResult::VALID;
            transition authToIdle authenticating to idle
                when authenticator.resultPort.out.result == AuthResult::INVALID;
            transition activatingToIdle activating to idle
                when statusPort.out.state == DoorState::MOVING;
        }
    }

    port def AuthLink {
        out item candidate : RFSignal;
    }

    port def AuthResultLink {
        out item result : AuthResult;
    }

    part def ReceiverProcessor {
        port powerIn : PowerPort;
        port antennaPort : RFAntennaPort;
        port authPort : AuthLink;
        port resultPort : AuthResultLink;
        port commandPort : ActivationPort;

        action def ProcessSignal {
            in signal : RFSignal;
            out command : ActivationCommand;
            perform {
                command.kind := CommandKind::TOGGLE;
                command.targetDeviceId := signal.deviceCode.deviceId;
            }
        }
    }

    part def RollingCodeAuthenticator {
        port powerIn : PowerPort;
        port verifyPort : AuthLink;
        port resultPort : AuthResultLink;

        attribute lastSequence : Integer = 0;
        attribute expectedSeed : Integer;

        action def Verify {
            in candidate : RFSignal;
            out result : AuthResult;
            perform {
                if candidate.code.sequenceNumber <= lastSequence {
                    result := AuthResult::REPLAY_DETECTED;
                } else if candidate.code.seed != expectedSeed {
                    result := AuthResult::INVALID;
                } else {
                    result := AuthResult::VALID;
                    lastSequence := candidate.code.sequenceNumber;
                }
            }
        }
    }

    part def DoorActuator {
        port powerIn : PowerPort;
        port commandPort : ActivationPort;
        port outputPort : ActivationPort;

        action def Actuate {
            in command : ActivationCommand;
            out emitted : ActivationCommand;
            perform { emitted := command; }
        }
    }

    part def GarageDoor {
        port activationPort : ActivationPort;
        port statusPort : DoorStatusPort;

        attribute doorState : DoorState = DoorState::CLOSED;

        exhibit state def DoorBehavior {
            state closed {
                entry action { doorState := DoorState::CLOSED; }
            }
            state moving {
                entry action { doorState := DoorState::MOVING; }
            }
            state open {
                entry action { doorState := DoorState::OPEN; }
            }
            transition closedToMoving closed to moving
                when activationPort.command.kind == CommandKind::OPEN
                or activationPort.command.kind == CommandKind::TOGGLE;
            transition movingToOpen moving to open
                when doorState == DoorState::MOVING;
            transition openToMoving open to moving
                when activationPort.command.kind == CommandKind::CLOSE
                or activationPort.command.kind == CommandKind::TOGGLE;
            transition movingToClosed moving to closed
                when doorState == DoorState::MOVING;
        }
    }

    // ---- Satisfaction bindings ----
    satisfaction PowerRequirement satisfy transmitter.supplyVoltage;
    satisfaction ButtonCountRequirement satisfy transmitter.buttons.size;
    satisfaction OperatingRangeRequirement satisfy transmitter.operatingRange;
    satisfaction FrequencyRequirement satisfy transmitter.transceiver.carrierFrequency;
    satisfaction MemorySlotRequirement satisfy transmitter.memory.slotCount;
}
