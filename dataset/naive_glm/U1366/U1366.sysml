package WakeOnLAN {
    import ScalarValues::*;

    item def MACAddress {
        attribute value : String;
    }

    item def MagicPacket {
        attribute syncHeader : String = "FFFFFFFFFFFF";
        attribute targetMAC : MACAddress;
        attribute repetitions : Integer = 16;
    }

    enum def PowerState {
        off;
        standby;
        awake;
    }

    value def Watt;
    value def Power {
        :>> unit = Watt;
    }

    port def NetworkPort {
        out item txPacket : MagicPacket;
        in item rxPacket : MagicPacket;
    }

    port def WakeSignalPort {
        out item wakeSignal : Boolean;
        in item wakeSignalIn : Boolean;
    }

    part def TargetComputer {
        attribute powerState : PowerState = PowerState::off;
        
        part def NIC {
            attribute macAddress : MACAddress;
            port networkPort : NetworkPort;
            port wakePort : WakeSignalPort;
            
            action receivePacket {
                in rxPacket : MagicPacket;
                out isValid : Boolean;
            }
            
            state machine NICStateMachine {
                state Listening;
                state Validating;
                state TriggeringWake;
                
                transition Listening to Validating when networkPort.rxPacket != null;
                transition Validating to TriggeringWake when receivePacket.isValid == true;
                transition Validating to Listening when receivePacket.isValid == false;
                transition TriggeringWake to Listening;
            }
        }
        
        part def PowerManagementController {
            port wakePort : WakeSignalPort;
            
            action restorePower {
                in wakeSignal : Boolean;
            }
        }
        
        part def MainProcessor {
            attribute powerConsumption : Power;
        }
        
        part nic : NIC;
        part pmc : PowerManagementController;
        part cpu : MainProcessor;
        
        connection nic.wakePort to pmc.wakePort;
        
        state machine ComputerPowerStateMachine {
            state Off;
            state Standby {
                constraint { cpu.powerConsumption < 5 [W] }
            }
            state Awake;
            
            transition Off to Standby;
            transition Standby to Awake when pmc.restorePower.wakeSignal == true;
        }
    }

    part def Initiator {
        attribute targetMAC : MACAddress;
        port networkPort : NetworkPort;
        
        action constructMagicPacket {
            out packet : MagicPacket;
        }
        
        action transmitPacket {
            in packet : MagicPacket;
        }
    }

    part def NetworkSwitch {
        port port1 : NetworkPort;
        port port2 : NetworkPort;
        
        action broadcastPacket {
            in packet : MagicPacket;
        }
    }

    part def WakeOnLANSystem {
        part targetComputer : TargetComputer;
        part initiator : Initiator;
        part networkSwitch : NetworkSwitch;
        
        connection initiator.networkPort to networkSwitch.port1;
        connection networkSwitch.port2 to targetComputer.nic.networkPort;
    }

    requirement def WakeOnLANRequirements {
        subject system : WakeOnLANSystem;
        
        requirement StandbyPowerRequirement {
            doc /* The target computer in standby mode must consume less than 5 watts. */
            constraint { system.targetComputer.powerState == PowerState::standby implies system.targetComputer.cpu.powerConsumption < 5 [W] }
        }
        
        requirement MagicPacketRequirement {
            doc /* The initiator must construct a Magic Packet with 16 repetitions of the target MAC address. */
            constraint { system.initiator.constructMagicPacket.packet.repetitions == 16 }
        }
    }
}
