package UPBHomeAutomation {

    import ScalarValues::*;
    import ISQ::*;

    // ---------- Value Types ----------

    value type Voltage :> Real { 
        attribute unit : String = "V"; 
    }
    value type Frequency :> Real { 
        attribute unit : String = "Hz"; 
    }
    value type Power :> Real { 
        attribute unit : String = "W"; 
    }
    value type BrightnessLevel :> Real { 
        attribute unit : String = "%"; 
        attribute min : Real = 0.0; 
        attribute max : Real = 100.0; 
    }
    value type UPBAddress :> Integer { 
        attribute min : Integer = 1; 
        attribute max : Integer = 250; 
    }
    value type CarrierAmplitude :> Real { 
        attribute unit : String = "V"; 
    }

    // ---------- Enumerations ----------

    enum CommandType {
        TURN_ON;
        TURN_OFF;
        SET_LEVEL;
        REPORT_STATUS;
        GOTO_STATE;
    }

    enum DeviceState {
        OFF;
        ON;
        DIMMED;
        FAULT;
    }

    enum PowerlineStatus {
        ACTIVE;
        NOISE_DETECTED;
        SIGNAL_LOSS;
    }

    // ---------- Item Types ----------

    item def UPBPacket {
        attribute targetAddress : UPBAddress;
        attribute sourceAddress : UPBAddress;
        attribute command : CommandType;
        attribute level : BrightnessLevel[0..1];
        attribute sequenceId : Integer;
        attribute checksum : Integer;
    }

    item def StatusReport {
        attribute deviceAddress : UPBAddress;
        attribute currentState : DeviceState;
        attribute currentLevel : BrightnessLevel[0..1];
        attribute currentPower : Power;
    }

    item def ACLinePower {
        attribute nominalVoltage : Voltage = 120 [V];
        attribute nominalFrequency : Frequency = 60 [Hz];
    }

    item def UPBCarrierSignal {
        attribute carrierFrequency : Frequency = 120 [kHz];
        attribute amplitude : CarrierAmplitude;
        attribute encodedPacket : UPBPacket;
    }

    // ---------- Port Definitions ----------

    port def PowerlinePort {
        out item power : ACLinePower;
        out item upbSignal : UPBCarrierSignal;
        in item statusReport : StatusReport;
    }

    port def ControllerCommandPort {
        out item commandPacket : UPBPacket;
        in item deviceStatus : StatusReport;
    }

    // ---------- Interfaces ----------

    interface def PowerlineCommunication {
        end supplier : PowerlinePort;
        end consumer : PowerlinePort;
    }

    // ---------- Block Definitions ----------

    part def UPBController {
        attribute controllerAddress : UPBAddress = 1;
        attribute registeredDevices : UPBAddress[0..*];
        attribute packetSequenceCounter : Integer = 0;

        port commandOut : ControllerCommandPort;
        port powerlineInterface : PowerlinePort;

        operation sendCommand(in targetAddr : UPBAddress, in cmd : CommandType, in level : BrightnessLevel[0..1]) {
            out packet : UPBPacket;
        }

        operation receiveStatus(in report : StatusReport);

        action sendCommandAction {
            in targetAddr : UPBAddress;
            in cmd : CommandType;
            in level : BrightnessLevel[0..1];
            out packet : UPBPacket;
            
            // Create packet with target address and instruction
            action createPacket {
                out createdPacket : UPBPacket = UPBPacket {
                    targetAddress = targetAddr;
                    sourceAddress = 1;
                    command = cmd;
                    level = if cmd == CommandType::SET_LEVEL then level else null;
                    sequenceId = packetSequenceCounter + 1;
                    checksum = 0;
                };
            }
            action modulateOntoCarrier {
                in packet : UPBPacket;
                out carrier : UPBCarrierSignal;
            }
            flow createPacket.createdPacket -> modulateOntoCarrier.packet;
        }

        state controllerBehavior {
            entry action { "Initialize controller, load device registry"; }
            
            state Idle {
                entry action { "Waiting for user input or scheduled command"; }
                transition to CommandProcessing on commandOut.commandPacket;
            }
            
            state CommandProcessing {
                entry action { "Create and transmit UPB packet"; }
                transition to AwaitingAck on commandOut.commandPacket;
            }
            
            state AwaitingAck {
                entry action { "Wait for status report from target device"; }
                transition to Idle on powerlineInterface.statusReport;
                transition to CommandRetry on timeout;
            }
            
            state CommandRetry {
                entry action { "Retransmit command, increment retry counter"; }
                transition to AwaitingAck on commandOut.commandPacket;
                transition to FaultState on maxRetriesExceeded;
            }
            
            state FaultState {
                entry action { "Log fault, notify user interface"; }
                transition to Idle on reset;
            }
        }
    }

    part def UPBSmartDevice {
        attribute deviceAddress : UPBAddress;
        attribute deviceState : DeviceState = DeviceState::OFF;
        attribute brightnessLevel : BrightnessLevel = 0.0;
        attribute nominalPower : Power;
        attribute currentPower : Power = 0 [W];

        port powerlinePort : PowerlinePort;

        operation receiveCommand(in packet : UPBPacket);
        operation executeCommand(in cmd : CommandType, in level : BrightnessLevel[0..1]);
        operation reportStatus();

        action processIncomingPacket {
            in packet : UPBPacket;
            
            action checkAddress {
                in pkt : UPBPacket;
                out isMatch : Boolean = (pkt.targetAddress == deviceAddress);
            }
            action validateChecksum {
                in pkt : UPBPacket;
                out isValid : Boolean;
            }
            action executeIfMatch {
                in isMatch : Boolean;
                in isValid : Boolean;
                in pkt : UPBPacket;
            }
            flow packet -> checkAddress.pkt;
            flow packet -> validateChecksum.pkt;
            flow checkAddress.isMatch -> executeIfMatch.isMatch;
            flow validateChecksum.isValid -> executeIfMatch.isValid;
            flow packet -> executeIfMatch.pkt;
        }

        state deviceStateMachine {
            entry action { "Initialize device, set to OFF"; }
            
            state Off {
                entry action { "Device off, currentPower = 0 W"; }
                transition to On on receiveCommand.command == CommandType::TURN_ON;
                transition to Dimmed on receiveCommand.command == CommandType::SET_LEVEL;
            }
            
            state On {
                entry action { "Device on, currentPower = nominalPower"; }
                transition to Off on receiveCommand.command == CommandType::TURN_OFF;
                transition to Dimmed on receiveCommand.command == CommandType::SET_LEVEL;
            }
            
            state Dimmed {
                entry action { "Device dimmed, currentPower = nominalPower * brightnessLevel / 100"; }
                transition to Off on receiveCommand.command == CommandType::TURN_OFF;
                transition to On on receiveCommand.command == CommandType::TURN_ON;
                transition to Dimmed on receiveCommand.command == CommandType::SET_LEVEL;
            }
            
            state Fault {
                entry action { "Device in fault, report status to controller"; }
                transition to Off on reset;
            }
        }
    }

    part def DimmableLight :> UPBSmartDevice {
        attribute nominalPower : Power = 60 [W];
        attribute minDimLevel : BrightnessLevel = 10.0;
        attribute maxDimLevel : BrightnessLevel = 100.0;

        override action processIncomingPacket {
            in packet : UPBPacket;
            
            action checkAddress {
                in pkt : UPBPacket;
                out isMatch : Boolean = (pkt.targetAddress == deviceAddress);
            }
            action validateChecksum {
                in pkt : UPBPacket;
                out isValid : Boolean;
            }
            action setBrightness {
                in level : BrightnessLevel;
                out adjustedLevel : BrightnessLevel = 
                    if level < minDimLevel then minDimLevel 
                    else if level > maxDimLevel then maxDimLevel 
                    else level;
            }
            action executeDimming {
                in adjustedLevel : BrightnessLevel;
                out newPower : Power = nominalPower * adjustedLevel / 100.0;
            }
            action reportStatusAction {
                out report : StatusReport = StatusReport {
                    deviceAddress = deviceAddress;
                    currentState = deviceState;
                    currentLevel = brightnessLevel;
                    currentPower = currentPower;
                };
            }
        }
    }

    part def SwitchedOutlet :> UPBSmartDevice {
        attribute nominalPower : Power = 1800 [W];
        attribute overloadThreshold : Power = 1500 [W];

        override action processIncomingPacket {
            in packet : UPBPacket;
            
            action checkAddress {
                in pkt : UPBPacket;
                out isMatch : Boolean = (pkt.targetAddress == deviceAddress);
            }
            action validateChecksum {
                in pkt : UPBPacket;
                out isValid : Boolean;
            }
            action toggleOutlet {
                in cmd : CommandType;
                out newState : DeviceState;
            }
            action checkOverload {
                in measuredPower : Power;
                out overloadDetected : Boolean = (measuredPower > overloadThreshold);
            }
            action reportStatusAction {
                out report : StatusReport = StatusReport {
                    deviceAddress = deviceAddress;
                    currentState = deviceState;
                    currentLevel = null;
                    currentPower = currentPower;
                };
            }
        }
    }

    part def PowerlineBus {
        attribute lineVoltage : Voltage = 120 [V];
        attribute lineFrequency : Frequency = 60 [Hz];
        attribute carrierFrequency : Frequency = 120 [kHz];
        attribute signalAttenuation : Real = 0.5;
        attribute noiseFloor : Real = 0.1;
        attribute status : PowerlineStatus = PowerlineStatus::ACTIVE;

        port powerlineConnection : PowerlinePort;

        operation broadcastPacket(in packet : UPBPacket);
        operation detectNoise() : Boolean;
    }

    part def UPBNetwork {
        attribute networkId : Integer;
        attribute encryptionEnabled : Boolean = false;
        
        part controller : UPBController {
            attribute controllerAddress : UPBAddress = 1;
        }
        
        part powerline : PowerlineBus;
        
        part devices : UPBSmartDevice[0..*];
        
        connection controllerToPowerline : PowerlineCommunication 
            connect controller.powerlineInterface to powerline.powerlineConnection;
        
        connection powerlineToDevices : PowerlineCommunication 
            connect powerline.powerlineConnection to devices.powerlinePort;
        
        connection deviceStatusToController : PowerlineCommunication 
            connect devices.powerlinePort to controller.powerlineInterface;
    }

    // ---------- Requirements ----------

    requirement def UPBCommunicationRequirement {
        doc "The system shall modulate digital command packets onto a high-frequency carrier signal superimposed on the 120V/60Hz AC power line.";
        attribute carrierFrequency : Frequency = 120 [kHz];
        attribute lineVoltage : Voltage = 120 [V];
        attribute lineFrequency : Frequency = 60 [Hz];
        
        satisfy by PowerlineBus;
    }

    requirement def AddressMatchingRequirement {
        doc "Each UPB device shall have a unique network address and shall only respond to packets whose target address matches its own.";
        attribute addressRange : UPBAddress = 1..250;
        
        satisfy by UPBSmartDevice;
    }

    requirement def CommandExecutionRequirement {
        doc "Upon receiving a valid command packet, the addressed device shall execute the instruction and update its state and power consumption accordingly.";
        
        satisfy by UPBSmartDevice;
    }

    requirement def StatusReportingRequirement {
        doc "Devices shall report their current state, level, and power consumption back to the controller using the same powerline communication method.";
        
        satisfy by UPBSmartDevice;
    }

    requirement def CentralizedControlRequirement {
        doc "The central controller shall create and transmit command instructions to control lighting, outlets, and other connected appliances.";
        
        satisfy by UPBController;
    }

    requirement def NoDedicatedWiringRequirement {
        doc "The system shall use the building's existing AC power lines as the communication bus, eliminating the need for dedicated control wiring.";
        
        satisfy by UPBNetwork;
    }

    // ---------- Concrete Configuration ----------

    part def HomeAutomationSystem {
        part upbNetwork : UPBNetwork {
            part controller : UPBController {
                attribute controllerAddress : UPBAddress = 1;
                attribute registeredDevices : UPBAddress = (2, 3, 4, 5);
            }
            
            part powerline : PowerlineBus {
                attribute lineVoltage : Voltage = 120 [V];
                attribute lineFrequency : Frequency = 60 [Hz];
            }
            
            part livingRoomLight : DimmableLight {
                attribute deviceAddress : UPBAddress = 2;
                attribute nominalPower : Power = 60 [W];
            }
            
            part bedroomLight : DimmableLight {
                attribute deviceAddress : UPBAddress = 3;
                attribute nominalPower : Power = 75 [W];
            }
            
            part kitchenOutlet : SwitchedOutlet {
                attribute deviceAddress : UPBAddress = 4;
                attribute nominalPower : Power = 1800 [W];
            }
            
            part garageOutlet : SwitchedOutlet {
                attribute deviceAddress : UPBAddress = 5;
                attribute nominalPower : Power = 1800 [W];
            }
            
            connection controllerToBus : PowerlineCommunication 
                connect controller.powerlineInterface to powerline.powerlineConnection;
            
            connection busToLivingRoomLight : PowerlineCommunication 
                connect powerline.powerlineConnection to livingRoomLight.powerlinePort;
            
            connection busToBedroomLight : PowerlineCommunication 
                connect powerline.powerlineConnection to bedroomLight.powerlinePort;
            
            connection busToKitchenOutlet : PowerlineCommunication 
                connect powerline.powerlineConnection to kitchenOutlet.powerlinePort;
            
            connection busToGarageOutlet : PowerlineCommunication 
                connect powerline.powerlineConnection to garageOutlet.powerlinePort;
            
            connection livingRoomLightStatus : PowerlineCommunication 
                connect livingRoomLight.powerlinePort to controller.powerlineInterface;
            
            connection bedroomLightStatus : PowerlineCommunication 
                connect bedroomLight.powerlinePort to controller.powerlineInterface;
            
            connection kitchenOutletStatus : PowerlineCommunication 
                connect kitchenOutlet.powerlinePort to controller.powerlineInterface;
            
            connection garageOutletStatus : PowerlineCommunication 
                connect garageOutlet.powerlinePort to controller.powerlineInterface;
        }
        
        satisfy UPBCommunicationRequirement;
        satisfy AddressMatchingRequirement;
        satisfy CommandExecutionRequirement;
        satisfy StatusReportingRequirement;
        satisfy CentralizedControlRequirement;
        satisfy NoDedicatedWiringRequirement;
    }

}
