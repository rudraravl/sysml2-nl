package LAN_Ethernet_Model {
    private import ScalarValues::*;
    private import SI::*;

    package NetworkTypes {
        attribute def MACAddress :> String;
        attribute def PortNumber :> Integer;
        attribute def DataRate :> Real;

        item def EthernetFrame {
            attribute destinationMAC : MACAddress;
            attribute sourceMAC : MACAddress;
            attribute payload : String;
            attribute frameCheckSequence : Integer;
        }

        item def ValidFrame :> EthernetFrame;
        item def CorruptedFrame :> EthernetFrame;

        item def LinkUpSignal;
        item def LinkDownSignal;
    }

    package NetworkPorts {
        private import NetworkTypes::*;

        port def EthernetPort {
            in item frameIn : EthernetFrame;
            out item frameOut : EthernetFrame;
        }

        interface def EthernetLink {
            end source : ~EthernetPort;
            end target : EthernetPort;
            flow forwardFrame from source.frameIn to target.frameIn;
            flow returnFrame from target.frameOut to source.frameOut;
        }
    }

    package NetworkComponents {
        private import NetworkTypes::*;
        private import NetworkPorts::*;

        part def NetworkInterfaceCard {
            attribute macAddress : MACAddress;
            attribute linkSpeed : DataRate;
            port ethernetPort : EthernetPort;

            attribute connected : Boolean = false;

            exhibit state nicStates {
                entry; then linkDown;
                state linkDown;
                transition linkUpTransition
                    first linkDown
                    accept sig : LinkUpSignal
                    then linkUp;
                state linkUp;
                transition linkDownTransition
                    first linkUp
                    accept sig : LinkDownSignal
                    then linkDown;
            }

            perform action transmitFrame {
                action encodeFrame {
                    in payload : String;
                    in destMAC : MACAddress;
                    in macAddress : MACAddress;
                    out ref frame : EthernetFrame;
                }
            }

            perform action receiveFrame {
                action validateFrame {
                    in ref inputFrame : EthernetFrame;
                    out ref validFrame : ValidFrame;
                    out ref corruptedFrame : CorruptedFrame;
                }
                then action extractPayload {
                    in ref validFrame : ValidFrame;
                    out payload : String;
                }
            }
        }

        part def Host {
            attribute hostName : String;
            attribute hostType : String;
            part nic : NetworkInterfaceCard;

            perform action sendData {
                in payload : String;
                in destMAC : MACAddress;
            }

            perform action receiveData {
                out payload : String;
            }
        }

        part def Workstation :> Host {
            attribute workstationType : String;
        }

        part def Server :> Host {
            attribute serverRole : String;
        }

        part def Printer :> Host {
            attribute printerModel : String;
        }

        part def EthernetSwitch {
            attribute portCount : PortNumber = 8;
            attribute macTable : MACAddress[0..*];
            attribute portAssignments : PortNumber[0..*];

            port switchPorts : EthernetPort[8];

            perform action switchProcessing {
                action learnMacAddress {
                    in ref frame : EthernetFrame;
                    in sourcePort : PortNumber;
                    action updateTable {
                        in sourceMac : MACAddress;
                        in portId : PortNumber;
                    }
                }
                then action forwardFrame {
                    in ref frame : EthernetFrame;
                    in sourcePort : PortNumber;
                    action lookupDestination {
                        in destMac : MACAddress;
                        out destinationPort : PortNumber;
                    }
                    then action sendFrame {
                        in destPort : PortNumber;
                        in ref frameToForward : EthernetFrame;
                    }
                }
            }

            exhibit state switchStates {
                entry; then idle;
                state idle;
                transition startLearning
                    first idle
                    accept frame : EthernetFrame
                    then learning;
                state learning;
                transition completeLearning
                    first learning
                    then forwarding;
                state forwarding;
                transition completeForwarding
                    first forwarding
                    then idle;
            }
        }
    }

    package NetworkSystem {
        private import NetworkTypes::*;
        private import NetworkPorts::*;
        private import NetworkComponents::*;

        part def EthernetLAN {
            part switch : EthernetSwitch;
            part host1 : Workstation;
            part host2 : Workstation;
            part host3 : Server;
            part host4 : Printer;

            connect host1.nic.ethernetPort to switch.switchPorts[1] via EthernetLink;
            connect host2.nic.ethernetPort to switch.switchPorts[2] via EthernetLink;
            connect host3.nic.ethernetPort to switch.switchPorts[3] via EthernetLink;
            connect host4.nic.ethernetPort to switch.switchPorts[4] via EthernetLink;
        }

        part theLAN : EthernetLAN;
    }

    package NetworkRequirements {
        private import NetworkTypes::*;
        private import NetworkComponents::*;
        private import NetworkSystem.*;

        requirement def EthernetCommunicationRequirement {
            doc /** The LAN shall reliably transmit Ethernet frames between hosts via the switch. **/;
            subject lan : EthernetLAN;
            objective {
                doc /** Ensure frames are delivered from source to destination. **/;
            }
        }

        requirement def MacLearningRequirement {
            doc /** The switch shall learn MAC addresses from incoming frames. **/;
            subject switch : EthernetSwitch;
            objective {
                doc /** Switch updates MAC table on frame reception. **/;
            }
        }

        requirement def FrameValidationRequirement {
            doc /** NICs shall validate frames using FCS and discard corrupted frames. **/;
            subject nic : NetworkInterfaceCard;
            objective {
                doc /** Only valid frames are passed to hosts. **/;
            }
        }

        requirement def UniqueMacRequirement {
            doc /** Each NIC shall have a globally unique MAC address. **/;
            subject nic : NetworkInterfaceCard;
            objective {
                doc /** MAC addresses are unique within the LAN. **/;
            }
        }

        requirement lanRequirement : EthernetCommunicationRequirement {
            subject :>> lan = theLAN;
        }

        requirement macLearningRequirement : MacLearningRequirement {
            subject :>> switch = theLAN.switch;
        }

        requirement frameValidationRequirement : FrameValidationRequirement {
            subject :>> nic = theLAN.host1.nic;
        }

        requirement uniqueMacRequirement : UniqueMacRequirement {
            subject :>> nic = theLAN.host1.nic;
        }
    }
}
