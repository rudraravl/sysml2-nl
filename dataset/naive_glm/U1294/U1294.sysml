package IEEE802_15_4_WSN {

    // ---------- Value Types ----------
    value type FrequencyValue :> ScalarValue {
        in unit :> ISQ::Frequency;
        attribute redef unit = Hz;
    }
    value type PowerValue :> ScalarValue {
        in unit :> ISQ::Power;
        attribute redef unit = mW;
    }
    value type DataRateValue :> ScalarValue {
        in unit :> ISQ::DataRate;
        attribute redef unit = kbps;
    }
    value type DurationValue :> ScalarValue {
        in unit :> ISQ::Time;
        attribute redef unit = s;
    }
    value type EnergyValue :> ScalarValue {
        in unit :> ISQ::Energy;
        attribute redef unit = mJ;
    }
    value type RSSIValue :> ScalarValue {
        in unit :> ISQ::Power;
        attribute redef unit = dBm;
    }
    value type NodeAddressValue :> ScalarValue {
        attribute unit = "uint16";
    }
    value type PanIDValue :> ScalarValue {
        attribute unit = "uint16";
    }
    value type SequenceNumberValue :> ScalarValue {
        attribute unit = "uint8";
    }

    // ---------- Enumerations ----------
    enum PacketType {
        beacon,
        data,
        ack,
        associationRequest,
        associationResponse,
    }
    enum NodeState {
        scanning,
        associated,
        active,
        sleeping,
    }
    enum ChannelState {
        idle,
        busy,
    }
    enum TxStatus {
        success,
        noAck,
        channelBusy,
    }

    // ---------- Item Types ----------
    item def Packet {
        attribute type : PacketType;
        attribute srcAddr : NodeAddressValue;
        attribute destAddr : NodeAddressValue;
        attribute panID : PanIDValue;
        attribute seqNum : SequenceNumberValue;
        attribute payload : String;
        attribute rssi : RSSIValue;
        attribute crcValid : Boolean;
    }
    item def BeaconFrame :> Packet {
        attribute beaconType = PacketType::beacon;
        attribute panID : PanIDValue;
        attribute coordinatorAddr : NodeAddressValue;
        attribute allowJoin : Boolean;
        attribute beaconInterval : DurationValue;
    }
    item def DataFrame :> Packet {
        attribute dataType = PacketType::data;
        attribute sensorReading : Real;
    }
    item def AckFrame :> Packet {
        attribute ackType = PacketType::ack;
        attribute ackedSeqNum : SequenceNumberValue;
    }
    item def AssociationRequest :> Packet {
        attribute reqType = PacketType::associationRequest;
    }
    item def AssociationResponse :> Packet {
        attribute respType = PacketType::associationResponse;
        attribute assignedAddr : NodeAddressValue;
        attribute accepted : Boolean;
    }

    item def SensorReading {
        attribute temperature : Real; // degC
        attribute humidity : Real; // %
        attribute timestamp : DurationValue;
    }

    // ---------- Port Definitions ----------
    port def RadioPort {
        out txPacket : Packet;
        in rxPacket : Packet;
        out channelState : ChannelState;
    }

    // ---------- Physical Layer ----------
    part def PhysicalLayer {
        attribute operatingFrequency : FrequencyValue = 2.4e9 [Hz];
        attribute txPower : PowerValue = 0.0 [mW];
        attribute dataRate : DataRateValue = 250.0 [kbps];
        attribute modulation : String = "O-QPSK";

        port radioIf : RadioPort;

        in digitalData : String;
        out receivedData : String;

        exhibit state radioBehavior {
            entry action { }
            state Idle;
            state Transmitting {
                entry action {
                    // Modulate digital data into radio waves
                }
                do action modulateAction {
                    // Perform modulation
                }
            }
            state Receiving {
                entry action {
                    // Demodulate incoming signals
                }
                do action demodulateAction {
                    // Perform demodulation and CRC check
                }
            }
            transition from Idle to Transmitting when radioIf.txPacket is sent;
            transition from Transmitting to Idle when true;
            transition from Idle to Receiving when radioIf.rxPacket is received;
            transition from Receiving to Idle when true;
        }

        action def transmit {
            in data : String;
            out packet : Packet;
        }
        action def receive {
            in signal : Packet;
            out data : String;
            out crcValid : Boolean;
        }
        action def performCRC {
            in packet : Packet;
            out valid : Boolean;
        }
    }

    // ---------- MAC Layer ----------
    part def MACLayer {
        attribute shortAddress : NodeAddressValue;
        attribute panID : PanIDValue;
        attribute maxRetries : Integer = 3;
        attribute backoffPeriod : DurationValue = 0.01 [s];
        attribute currentSeqNum : SequenceNumberValue;

        port macToPhy : RadioPort;
        port macToUpper : RadioPort;

        exhibit state macBehavior {
            state Idle;
            state CSMA_CA {
                entry action {
                    // Listen before talk: check channel
                }
                do action listenBeforeTalk {
                    // Check if channel is clear
                }
            }
            state Transmitting;
            state WaitingForAck {
                entry action {
                    // Start ACK timer
                }
            }
            state Retransmitting;

            transition from Idle to CSMA_CA when macToUpper.txPacket is sent;
            transition from CSMA_CA to Transmitting when macToPhy.channelState == ChannelState::idle;
            transition from CSMA_CA to CSMA_CA when macToPhy.channelState == ChannelState::busy;
            transition from Transmitting to WaitingForAck when true;
            transition from WaitingForAck to Idle when macToPhy.rxPacket.type == PacketType::ack;
            transition from WaitingForAck to Retransmitting when ackTimeout;
            transition from Retransmitting to CSMA_CA when retryCount < maxRetries;
        }

        action def csmaCA {
            in channel : ChannelState;
            out canTransmit : Boolean;
        }
        action def constructPacket {
            in payload : String;
            in srcAddr : NodeAddressValue;
            in destAddr : NodeAddressValue;
            out packet : Packet;
        }
        action def processAck {
            in ack : AckFrame;
            out status : TxStatus;
        }
        action def retransmit {
            in packet : Packet;
            out retryCount : Integer;
        }
    }

    // ---------- Coordinator Node ----------
    part def CoordinatorNode {
        attribute panID : PanIDValue = 0x1A2B;
        attribute coordinatorAddr : NodeAddressValue = 0x0000;
        attribute beaconInterval : DurationValue = 0.064 [s];
        attribute allowJoin : Boolean = true;
        attribute maxEndDevices : Integer = 20;

        port coordinatorRadio : RadioPort;

        part phy : PhysicalLayer {
            redef radioIf : RadioPort;
        }
        part mac : MACLayer {
            redef shortAddress = 0x0000 [uint16];
            redef panID = 0x1A2B [uint16];
        }

        connection phy.radioIf to mac.macToPhy;
        connection mac.macToUpper to coordinatorRadio;

        exhibit state coordinatorBehavior {
            entry action {
                // Establish PAN and assign network ID
            }
            state PAN_Establishment {
                entry action {
                    // Initialize PAN, set channel, assign PAN ID
                }
                do action establishPAN {
                    out panID : PanIDValue;
                }
            }
            state BeaconBroadcast {
                do action broadcastBeacon {
                    out beacon : BeaconFrame;
                }
            }
            state ManagingAssociations {
                do action handleAssociation {
                    in request : AssociationRequest;
                    out response : AssociationResponse;
                }
            }
            state ReceivingData {
                do action receiveSensorData {
                    in data : DataFrame;
                    out ack : AckFrame;
                }
            }
            state ForwardingData {
                do action forwardData {
                    in data : DataFrame;
                    out routed : DataFrame;
                }
            }

            transition from PAN_Establishment to BeaconBroadcast when panEstablished;
            transition from BeaconBroadcast to ManagingAssociations when associationRequestReceived;
            transition from ManagingAssociations to BeaconBroadcast when associationHandled;
            transition from BeaconBroadcast to ReceivingData when dataReceived;
            transition from ReceivingData to BeaconBroadcast when dataProcessed;
            transition from ReceivingData to ForwardingData when forwardingNeeded;
            transition from ForwardingData to BeaconBroadcast when forwardingComplete;
        }

        action def establishPAN {
            out panID : PanIDValue;
            out channel : FrequencyValue;
        }
        action def broadcastBeacon {
            out beacon : BeaconFrame;
        }
        action def handleAssociation {
            in request : AssociationRequest;
            out response : AssociationResponse;
        }
        action def receiveSensorData {
            in data : DataFrame;
            out ack : AckFrame;
        }
        action def forwardData {
            in data : DataFrame;
            out routed : DataFrame;
        }
    }

    // ---------- End Device Node ----------
    part def EndDeviceNode {
        attribute deviceAddr : NodeAddressValue;
        attribute batteryLevel : PowerValue = 100.0 [mW];
        attribute sleepDuration : DurationValue = 30.0 [s];
        attribute activeDuration : DurationValue = 2.0 [s];
        attribute sensorType : String = "temperature";

        port endDeviceRadio : RadioPort;

        part phy : PhysicalLayer {
            redef radioIf : RadioPort;
            redef txPower = 0.0 [mW];
        }
        part mac : MACLayer {
            redef shortAddress : NodeAddressValue;
            redef panID : PanIDValue;
        }

        connection phy.radioIf to mac.macToPhy;
        connection mac.macToUpper to endDeviceRadio;

        exhibit state endDeviceBehavior {
            entry action {
                // Power on, initialize
            }
            state Scanning {
                entry action {
                    // Scan for coordinator beacon
                }
                do action scanForBeacon {
                    out beacon : BeaconFrame;
                }
            }
            state Associating {
                do action associate {
                    in beacon : BeaconFrame;
                    out request : AssociationRequest;
                    in response : AssociationResponse;
                }
            }
            state GatheringData {
                do action gatherSensorData {
                    out reading : SensorReading;
                }
            }
            state TransmittingData {
                do action transmitData {
                    in reading : SensorReading;
                    out dataFrame : DataFrame;
                    out status : TxStatus;
                }
            }
            state Sleeping {
                entry action {
                    // Enter low-power mode
                }
                do action sleepAction {
                    out wakeUp : Boolean;
                }
            }

            transition initial to Scanning;
            transition from Scanning to Associating when beaconFound;
            transition from Associating to GatheringData when associated;
            transition from GatheringData to TransmittingData when dataReady;
            transition from TransmittingData to Sleeping when txStatus == TxStatus::success;
            transition from TransmittingData to TransmittingData when txStatus == TxStatus::noAck;
            transition from Sleeping to GatheringData when wakeUpTimerExpired;
        }

        action def scanForBeacon {
            out beacon : BeaconFrame;
        }
        action def associate {
            in beacon : BeaconFrame;
            out request : AssociationRequest;
            in response : AssociationResponse;
        }
        action def gatherSensorData {
            out reading : SensorReading;
        }
        action def transmitData {
            in reading : SensorReading;
            out dataFrame : DataFrame;
            out status : TxStatus;
        }
        action def sleepAction {
            out wakeUp : Boolean;
        }
    }

    // ---------- Network System ----------
    part def WSNSystem {
        attribute topology : String = "star";
        attribute standard : String = "IEEE 802.15.4";
        attribute numEndDevices : Integer = 5;

        part coordinator : CoordinatorNode;

        part endDevices[n] : EndDeviceNode[5];

        // Star topology connections: each end device connects to coordinator
        connection endDevices.radio to coordinator.coordinatorRadio;

        exhibit state systemBehavior {
            state NetworkOperational;
            state NetworkIdle;
            transition initial to NetworkOperational;
            transition from NetworkOperational to NetworkIdle when noDataTraffic;
            transition from NetworkIdle to NetworkOperational when dataTrafficDetected;
        }
    }

    // ---------- Requirements ----------
    requirement def PANManagementRequirement {
        doc /* The Coordinator Node shall establish a Personal Area Network (PAN),
               assign a unique network ID, and manage device associations. */
        subject coordinator : CoordinatorNode;
        attribute requiredPanID : PanIDValue;
        constraint { coordinator.panID == requiredPanID }
        constraint { coordinator.coordinatorAddr == 0x0000 }
    }

    requirement def BeaconBroadcastRequirement {
        doc /* The Coordinator Node shall periodically broadcast beacon signals
               to allow devices to discover and join the network. */
        subject coordinator : CoordinatorNode;
        constraint { coordinator.beaconInterval <= 0.1 [s] }
    }

    requirement def EndDeviceLifecycleRequirement {
        doc /* End Device Nodes shall scan for beacons, associate, gather sensor data,
               transmit to coordinator, and enter low-power sleep mode cyclically. */
        subject endDevice : EndDeviceNode;
        constraint { endDevice.sleepDuration >= 10.0 [s] }
        constraint { endDevice.activeDuration <= 5.0 [s] }
    }

    requirement def PhysicalLayerRequirement {
        doc /* The Physical Layer shall operate in the 2.4 GHz band and perform
               modulation/demodulation with error checking. */
        subject phy : PhysicalLayer;
        constraint { phy.operatingFrequency == 2.4e9 [Hz] }
        constraint { phy.dataRate == 250.0 [kbps] }
    }

    requirement def MACLayerRequirement {
        doc /* The MAC Layer shall use CSMA/CA for channel access, construct
               addressed packets, and retransmit on missing acknowledgments. */
        subject mac : MACLayer;
        constraint { mac.maxRetries == 3 }
        constraint { mac.backoffPeriod >= 0.001 [s] }
    }

    requirement def StarTopologyRequirement {
        doc /* All end devices shall communicate directly with the central coordinator
               in a star topology. */
        subject system : WSNSystem;
        constraint { system.topology == "star" }
        constraint { system.numEndDevices >= 1 }
    }

    requirement def BatteryEfficiencyRequirement {
        doc /* End devices shall be designed for long operational life through
               low-power sleep modes. */
        subject endDevice : EndDeviceNode;
        constraint { endDevice.batteryLevel > 0.0 [mW] }
    }

    requirement panReq : PANManagementRequirement {
        subject coordinator : CoordinatorNode;
        attribute requiredPanID = 0x1A2B [uint16];
    }
    requirement beaconReq : BeaconBroadcastRequirement {
        subject coordinator : CoordinatorNode;
    }
    requirement lifecycleReq : EndDeviceLifecycleRequirement {
        subject endDevice : EndDeviceNode;
    }
    requirement phyReq : PhysicalLayerRequirement {
        subject phy : PhysicalLayer;
    }
    requirement macReq : MACLayerRequirement {
        subject mac : MACLayer;
    }
    requirement topologyReq : StarTopologyRequirement {
        subject system : WSNSystem;
    }
    requirement batteryReq : BatteryEfficiencyRequirement {
        subject endDevice : EndDeviceNode;
    }

    // ---------- System Instance ----------
    part wsnSystem : WSNSystem {
        satisfy topologyReq;
        part coordinator : CoordinatorNode {
            satisfy panReq;
            satisfy beaconReq;
        }
        part endDevices : EndDeviceNode[5] {
            satisfy lifecycleReq;
            satisfy batteryReq;
        }
    }

}
