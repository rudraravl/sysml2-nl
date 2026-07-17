package WakeOnLANSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;

    attribute def MACAddress :> String;
    attribute def IPAddress :> String;

    enum def PowerStateKind {
        off;
        standby;
        awake;
    }

    enum def PacketValidationResult {
        valid;
        invalidFormat;
        wrongTarget;
    }

    item def MagicPacket {
        attribute synchronizationBytes : String = "FFFFFFFFFFFF";
        attribute targetMAC : MACAddress;
        attribute macRepetitions : Integer = 16;
        attribute totalSize : Integer = 102;
    }

    item def NetworkFrame {
        attribute sourceMAC : MACAddress;
        attribute destinationMAC : MACAddress;
        attribute payload : MagicPacket[0..1];
    }

    port def EthernetPort {
        attribute macAddress : MACAddress;
        in item receivedFrame : NetworkFrame;
        out item transmittedFrame : NetworkFrame;
    }

    port def PowerControlPort {
        out item wakeSignal : Boolean;
        out item sleepSignal : Boolean;
    }

    part def NetworkInterfaceCard {
        attribute nicMAC : MACAddress;
        attribute standbyPowerConsumption : PowerValue;
        
        port ethPort : EthernetPort {
            attribute :>> macAddress = nicMAC;
        }
        
        port powerControl : PowerControlPort;
        
        action monitorIncomingFrames {
            in frame : NetworkFrame;
            out containsMagicPacket : Boolean;
        }
        
        action validateMagicPacket {
            in packet : MagicPacket;
            in localMAC : MACAddress;
            out validationResult : PacketValidationResult;
        }
        
        action triggerWakeup {
            out wakeupSignal : Boolean;
        }
    }

    part def PowerManagementController {
        attribute currentPowerState : PowerStateKind;
        attribute standbyVoltage : VoltageValue;
        
        port wakeupTrigger {
            in item wakeSignal : Boolean;
        }
        
        port systemPowerControl {
            out item powerSignal : Boolean;
        }
        
        state machine powerStateMachine {
            entry; then offState;
            
            state offState {
                entry; do assign currentPowerState = PowerStateKind::off;
            }
            
            state standbyState {
                entry; do assign currentPowerState = PowerStateKind::standby;
            }
            
            state awakeState {
                entry; do assign currentPowerState = PowerStateKind::awake;
            }
            
            transition offToStandby
                first offState
                accept powerOn
                then standbyState;
            
            transition standbyToAwake
                first standbyState
                accept wakeupTrigger.wakeSignal
                then awakeState;
            
            transition awakeToStandby
                first awakeState
                accept sleepCommand
                then standbyState;
            
            transition standbyToOff
                first standbyState
                accept shutdownCommand
                then offState;
        }
    }

    part def MainProcessor {
        attribute processorState : PowerStateKind;
        
        port bootTrigger {
            in item bootSignal : Boolean;
        }
        
        action bootSequence {
            out bootCompleted : Boolean;
        }
        
        action runOperatingSystem;
    }

    part def TargetComputer {
        attribute computerMAC : MACAddress;
        attribute computerIP : IPAddress;
        attribute maxStandbyPower : PowerValue;
        
        part nic : NetworkInterfaceCard {
            attribute :>> nicMAC = computerMAC;
            attribute :>> standbyPowerConsumption = 3.0 [W];
        }
        
        part pmc : PowerManagementController {
            attribute :>> standbyVoltage = 5.0 [V];
        }
        
        part cpu : MainProcessor;
        
        port networkInterface : EthernetPort :>> nic.ethPort;
        
        connection nicToPMC connect nic.powerControl to pmc.wakeupTrigger;
        connection pmcToCPU connect pmc.systemPowerControl to cpu.bootTrigger;
    }

    part def WakeOnLANInitiator {
        attribute initiatorMAC : MACAddress;
        attribute initiatorIP : IPAddress;
        
        port ethPort : EthernetPort;
        
        action constructMagicPacket {
            in targetMAC : MACAddress;
            out magicPacket : MagicPacket;
        }
        
        action encapsulateFrame {
            in packet : MagicPacket;
            in sourceMAC : MACAddress;
            in destMAC : MACAddress;
            out frame : NetworkFrame;
        }
        
        action transmitFrame {
            in frame : NetworkFrame;
            out transmitted : Boolean;
        }
    }

    part def NetworkSwitch {
        attribute numberOfPorts : Integer = 8;
        
        port switchPorts : EthernetPort[8];
        
        action forwardFrame {
            in incomingFrame : NetworkFrame;
            in ingressPort : Integer;
            out egressPorts : Integer[0..*];
        }
        
        action broadcastFrame {
            in frame : NetworkFrame;
        }
    }

    action def WakeOnLANSequence {
        first start;
        
        then action initiateWakeRequest {
            in targetMAC : MACAddress;
            out requestInitiated : Boolean;
        }
        
        then action createMagicPacket {
            in targetAddress : MACAddress = initiateWakeRequest.targetMAC;
            out packet : MagicPacket;
        }
        
        then action packageFrame {
            in magicPacket : MagicPacket = createMagicPacket.packet;
            out networkFrame : NetworkFrame;
        }
        
        then action sendOverNetwork {
            in frame : NetworkFrame = packageFrame.networkFrame;
            out sent : Boolean;
        }
        
        then action propagateViaSwitch {
            in frame : NetworkFrame = packageFrame.networkFrame;
            out forwarded : Boolean;
        }
        
        then action receiveAtNIC {
            in frame : NetworkFrame = packageFrame.networkFrame;
            out received : Boolean;
        }
        
        then action inspectPacket {
            in frame : NetworkFrame = packageFrame.networkFrame;
            out inspected : Boolean;
        }
        
        then action validatePacketContent {
            in frame : NetworkFrame = packageFrame.networkFrame;
            out validationResult : PacketValidationResult;
        }
        
        then decide;
            if validationResult == PacketValidationResult::valid then issueWakeSignal;
            if validationResult != PacketValidationResult::valid then rejectPacket;
        
        action issueWakeSignal {
            out wakeSignalIssued : Boolean;
        }
        
        then action transitionPowerState {
            out stateChanged : Boolean;
        }
        
        then action bootSystem {
            out systemBooted : Boolean;
        }
        
        then action startOperatingSystem {
            out osRunning : Boolean;
        }
        
        then done;
        
        action rejectPacket {
            out packetDiscarded : Boolean;
        }
        
        then done;
    }

    part wakeOnLANSystem {
        part initiator : WakeOnLANInitiator {
            attribute :>> initiatorMAC = "00:1A:2B:3C:4D:5E";
            attribute :>> initiatorIP = "192.168.1.100";
        }
        
        part switch : NetworkSwitch {
            attribute :>> numberOfPorts = 8;
        }
        
        part targetDevice : TargetComputer {
            attribute :>> computerMAC = "AA:BB:CC:DD:EE:FF";
            attribute :>> computerIP = "192.168.1.50";
            attribute :>> maxStandbyPower = 5.0 [W];
        }
        
        connection initiatorToSwitch connect initiator.ethPort to switch.switchPorts[1];
        connection switchToTarget connect switch.switchPorts[2] to targetDevice.networkInterface;
        
        perform action wakeSequence : WakeOnLANSequence;
    }

    requirement <'WOL-REQ-001'> primarySystemFunction {
        doc /* The Wake-on-LAN system shall enable remote power-on capability 
             * for networked computers by transmitting a specially formatted 
             * magic packet over the local area network to wake a target device 
             * from a low-power standby state to full operational state.
             */
        subject system :>> wakeOnLANSystem;
        
        require magicPacketTransmission;
        require targetDeviceWakeup;
        require lowPowerStandby;
    }

    requirement <'WOL-REQ-002'> magicPacketTransmission {
        doc /* The initiator shall construct and transmit a magic packet 
             * containing 6 bytes of 0xFF followed by 16 repetitions of the 
             * target device MAC address, totaling 102 bytes.
             */
        subject initiator :>> wakeOnLANSystem.initiator;
        
        assert constraint magicPacketStructure {
            in packet : MagicPacket;
            packet.synchronizationBytes == "FFFFFFFFFFFF" and
            packet.macRepetitions == 16 and
            packet.totalSize == 102
        }
    }

    requirement <'WOL-REQ-003'> targetDeviceWakeup {
        doc /* The target device network interface shall monitor incoming 
             * network traffic while in standby mode, validate received magic 
             * packets against its MAC address, and trigger system wakeup upon 
             * receiving a valid magic packet.
             */
        subject target :>> wakeOnLANSystem.targetDevice;
        
        assert constraint {
            target.nic.ethPort.macAddress == target.computerMAC
        }
    }

    requirement <'WOL-REQ-004'> lowPowerStandby {
        doc /* The target device shall maintain network monitoring capability 
             * in standby mode while consuming no more than 5 watts of power.
             */
        subject target :>> wakeOnLANSystem.targetDevice;
        
        assert constraint {
            target.maxStandbyPower <= 5.0 [W]
        }
    }

    requirement <'WOL-REQ-005'> packetValidation {
        doc /* The network interface card shall validate that received magic 
             * packets match the device MAC address before triggering wakeup.
             */
        subject nic :>> wakeOnLANSystem.targetDevice.nic;
    }

    satisfy primarySystemFunction by wakeOnLANSystem;
    satisfy magicPacketTransmission by wakeOnLANSystem.initiator;
    satisfy targetDeviceWakeup by wakeOnLANSystem.targetDevice;
    satisfy lowPowerStandby by wakeOnLANSystem.targetDevice;
    satisfy packetValidation by wakeOnLANSystem.targetDevice.nic;
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    private import WakeOnLANSystem::*;

    action orchestrator {
        attribute testTargetMAC : MACAddress = "";
        attribute testTargetAddress : MACAddress = "";
        item testMagicPacket : MagicPacket {
            attribute synchronizationBytes = "FFFFFFFFFFFF";
            attribute targetMAC : MACAddress = "";
            attribute macRepetitions = 16;
            attribute totalSize = 102;
        }
        action actionProbe : WakeOnLANSequence {
            in targetMAC = testTargetMAC;
            in targetAddress = testTargetAddress;
            in magicPacket = testMagicPacket;
            // TODO(human): unsupported input type for frame: NetworkFrame (unsupported structured payload members: payload)
            // TODO(human): unsupported input type for frame: NetworkFrame (unsupported structured payload members: payload)
            // TODO(human): unsupported input type for frame: NetworkFrame (unsupported structured payload members: payload)
            // TODO(human): unsupported input type for frame: NetworkFrame (unsupported structured payload members: payload)
            // TODO(human): unsupported input type for frame: NetworkFrame (unsupported structured payload members: payload)
        }
        first actionProbe;
    }
}
