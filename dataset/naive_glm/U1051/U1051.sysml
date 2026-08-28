package LAN {
    import ScalarValues::*;
    import ISQ::*;

    attribute def MACAddress {
        doc "Globally unique 48-bit hardware identifier of a NIC.";
        attr value : String;
    }

    attribute def PortNumber {
        doc "Physical port index on the Ethernet switch (0..7).";
        attr value : Integer;
    }

    attribute def DataRate {
        doc "Nominal link data rate.";
        attr value : Integer;
        ref unit Mbps;
    }

    item def Payload {
        doc "Application data carried within an Ethernet frame.";
        attr data : String;
        attr length : Integer;
    }

    item def EthernetFrame {
        doc "Standard Ethernet frame transmitted between NICs via the switch.";
        attr sourceMAC : MACAddress;
        attr destinationMAC : MACAddress;
        attr payload : Payload;
        attr fcs : Integer;
        attr isValid : Boolean;
    }

    item def ElectricalSignal {
        doc "Physical layer representation of an Ethernet frame on the cable.";
        attr encodedFrame : EthernetFrame;
        attr signalStrength : Real;
    }

    port def EthernetPort {
        doc "Bidirectional Ethernet port carrying frames between devices.";
        in item frameRx : EthernetFrame;
        out item frameTx : EthernetFrame;
    }

    part def NIC {
        doc "Network Interface Card providing physical host-to-network connectivity.";
        port ethPort : EthernetPort;
        attr macAddress : MACAddress;
        attr linkUp : Boolean := false;
        attr linkRate : DataRate := DataRate{value = 1000};

        state machine NICBehavior {
            state linkDown {
                doc "No physical link established.";
            }
            state linkUp {
                doc "Physical link established and idle.";
            }
            state transmitting {
                doc "NIC is actively sending a frame.";
            }
            state receiving {
                doc "NIC is actively receiving a frame.";
            }

            transition down_to_up
                first linkDown
                then linkUp
                if linkUp == true;

            transition up_to_down
                from linkUp
                to linkDown
                if linkUp == false;

            transition begin_transmit
                from linkUp
                to transmitting
                when frameRequested;

            transition end_transmit
                from transmitting
                to linkUp
                when txComplete;

            transition begin_receive
                from linkUp
                to receiving
                when frameReceived;

            transition end_receive
                from receiving
                to linkUp
                when rxComplete;
        }

        action encapsulateFrame {
            doc "Wrap payload into an Ethernet frame with source/destination MAC and FCS.";
            in payload : Payload;
            in destMAC : MACAddress;
            out frame : EthernetFrame;
        }

        action encodeToSignal {
            doc "Convert a digital frame into an electrical signal for transmission.";
            in frame : EthernetFrame;
            out signal : ElectricalSignal;
        }

        action decodeFromSignal {
            doc "Convert an incoming electrical signal back into a digital frame.";
            in signal : ElectricalSignal;
            out frame : EthernetFrame;
        }

        action validateFrame {
            doc "Verify frame integrity using the Frame Check Sequence.";
            in frame : EthernetFrame;
            out valid : Boolean;
        }

        action extractPayload {
            doc "Extract the payload from a validated frame.";
            in frame : EthernetFrame;
            out payload : Payload;
        }

        perform action sendFrame {
            doc "Full transmit sequence: encapsulate, encode, and emit on ethPort.";
            in payload : Payload;
            in destMAC : MACAddress;
            first encapsulateFrame(in payload, in destMAC, out frame);
            then encodeToSignal(in frame, out signal);
            then send ethPort.frameTx := signal.encodedFrame;
        }

        perform action receiveFrame {
            doc "Full receive sequence: decode, validate, and extract payload.";
            first decodeFromSignal(in ethPort.frameRx, out frame);
            then validateFrame(in frame, out valid);
            then if valid then extractPayload(in frame, out payload);
        }
    }

    part def SwitchPort {
        doc "A single physical port on the Ethernet switch.";
        port ethPort : EthernetPort;
        attr portNumber : PortNumber;
        attr connectedMAC : MACAddress;
        attr active : Boolean := false;
    }

    part def EthernetSwitch {
        doc "Central eight-port intelligent Ethernet switch.";
        port switchPorts[8] : EthernetPort;
        part ports[8] : SwitchPort;
        attr macTable : MACAddress[0..*] := {};
        attr portMapping : PortNumber[0..*] := {};

        action learnMAC {
            doc "Learn the source MAC address of an incoming frame and map it to the ingress port.";
            in frame : EthernetFrame;
            in ingressPort : PortNumber;
            then if frame.sourceMAC not in macTable then {
                macTable := macTable.append(frame.sourceMAC);
                portMapping := portMapping.append(ingressPort);
            };
        }

        action lookupDestination {
            doc "Determine the egress port for a destination MAC address.";
            in destMAC : MACAddress;
            out egressPort : PortNumber;
            out found : Boolean;
        }

        action forwardFrame {
            doc "Forward a frame to the single egress port associated with the destination MAC.";
            in frame : EthernetFrame;
            in egressPort : PortNumber;
            then send switchPorts[egressPort.value].frameTx := frame;
        }

        action broadcastFrame {
            doc "Broadcast a frame to all ports except the ingress port.";
            in frame : EthernetFrame;
            in ingressPort : PortNumber;
            then for p in 0..7 {
                if p != ingressPort.value then send switchPorts[p].frameTx := frame;
            };
        }

        perform action processFrame {
            doc "Switch processing pipeline: learn, lookup, then forward or broadcast.";
            in frame : EthernetFrame;
            in ingressPort : PortNumber;
            first learnMAC(in frame, in ingressPort);
            then lookupDestination(in frame.destinationMAC, out egressPort, out found);
            then if found then forwardFrame(in frame, in egressPort)
                 else broadcastFrame(in frame, in ingressPort);
        }
    }

    part def Host {
        doc "A network host such as a workstation, server, or printer.";
        port hostPort : EthernetPort;
        part nic : NIC {
            port ethPort : EthernetPort;
        }
        attr hostName : String;
        attr hostType : String;

        action sendData {
            doc "Application-level request to send data to another host.";
            in payload : Payload;
            in destMAC : MACAddress;
            then nic.sendFrame(in payload, in destMAC);
        }

        action receiveData {
            doc "Application-level handler for received payload data.";
            in payload : Payload;
        }

        binding nic.ethPort = hostPort;
    }

    part def LAN {
        doc "Standard local area network composed of a switch and multiple hosts.";
        part switch : EthernetSwitch;
        part hosts[5] : Host;

        connection def HostToSwitchLink {
            doc "Ethernet link connecting a host NIC port to a switch port.";
            end hostEnd : EthernetPort;
            end switchEnd : EthernetPort;
        }

        connection hostLink0 : HostToSwitchLink connect hosts[0].hostPort to switch.switchPorts[0];
        connection hostLink1 : HostToSwitchLink connect hosts[1].hostPort to switch.switchPorts[1];
        connection hostLink2 : HostToSwitchLink connect hosts[2].hostPort to switch.switchPorts[2];
        connection hostLink3 : HostToSwitchLink connect hosts[3].hostPort to switch.switchPorts[3];
        connection hostLink4 : HostToSwitchLink connect hosts[4].hostPort to switch.switchPorts[4];
    }

    requirement def ReliableFrameTransmission {
        doc "The LAN shall reliably transmit Ethernet frames between connected hosts.";
        id "REQ-LAN-001";
        subject lan : LAN;
        require lan shall transmit Ethernet frames from any host NIC to any other host NIC via the central switch.
    }

    requirement def MACAddressUniqueness {
        doc "Each NIC shall have a globally unique MAC address.";
        id "REQ-LAN-002";
        subject nic : NIC;
        require nic.macAddress shall be globally unique across all NICs in the LAN.
    }

    requirement def SwitchLearning {
        doc "The switch shall learn source MAC addresses and map them to ingress ports.";
        id "REQ-LAN-003";
        subject sw : EthernetSwitch;
        require sw shall update its MAC table based on the source address of each incoming frame.
    }

    requirement def SelectiveForwarding {
        doc "The switch shall forward frames only to the port leading to the destination MAC when known.";
        id "REQ-LAN-004";
        subject sw : EthernetSwitch;
        require sw shall forward a frame to a single egress port when the destination MAC is known.
    }

    requirement def UnknownDestinationBroadcast {
        doc "The switch shall broadcast frames with unknown destination MAC addresses.";
        id "REQ-LAN-005";
        subject sw : EthernetSwitch;
        require sw shall broadcast a frame to all ports except the ingress port when the destination MAC is unknown.
    }

    requirement def FrameIntegrityValidation {
        doc "The receiving NIC shall validate frame integrity using the FCS and discard corrupted frames.";
        id "REQ-LAN-006";
        subject nic : NIC;
        require nic shall discard any received frame whose FCS validation fails.
    }

    requirement def NICLinkStates {
        doc "Each NIC shall operate through linkDown, linkUp, transmitting, and receiving states.";
        id "REQ-LAN-007";
        subject nic : NIC;
        require nic.NICBehavior shall include the states linkDown, linkUp, transmitting, and receiving.
    }

    requirement def EightPortSwitch {
        doc "The switch shall provide exactly eight Ethernet ports.";
        id "REQ-LAN-008";
        subject sw : EthernetSwitch;
        require sw.switchPorts shall have exactly eight instances.
    }

    satisfaction satisfyReliableFrame : ReliableFrameTransmission satisfy LAN;
    satisfaction satisfyMACUniqueness : MACAddressUniqueness satisfy NIC;
    satisfaction satisfySwitchLearning : SwitchLearning satisfy EthernetSwitch;
    satisfaction satisfySelectiveForwarding : SelectiveForwarding satisfy EthernetSwitch;
    satisfaction satisfyUnknownBroadcast : UnknownDestinationBroadcast satisfy EthernetSwitch;
    satisfaction satisfyFrameIntegrity : FrameIntegrityValidation satisfy NIC;
    satisfaction satisfyNICStates : NICLinkStates satisfy NIC;
    satisfaction satisfyEightPorts : EightPortSwitch satisfy EthernetSwitch;
}
