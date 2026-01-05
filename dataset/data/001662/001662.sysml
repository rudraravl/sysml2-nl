package 'IEEE802154WirelessSensorNetwork' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def MACAddress {
        attribute shortAddr : Integer;
        attribute extendedAddr : String;
    }
    
    attribute def ChannelNumber :> Integer {
        assert constraint validChannel { 11 <= ChannelNumber and ChannelNumber <= 26 }
    }
    
    attribute def PANIdentifier :> Integer;
    
    attribute def FrameSequenceNumber :> Integer;
    
    item def MACFrame {
        attribute frameControl : Integer;
        attribute sequenceNum : FrameSequenceNumber;
        attribute destPAN : PANIdentifier;
        attribute destAddr : MACAddress;
        attribute srcAddr : MACAddress;
        attribute payloadLength : Integer;
        attribute payload : String;
        attribute fcs : Integer;
    }
    
    item def BeaconFrame {
        attribute frameControl : Integer;
        attribute sequenceNum : FrameSequenceNumber;
        attribute srcPAN : PANIdentifier;
        attribute srcAddr : MACAddress;
        attribute superframeSpec : Integer;
        attribute beaconPayload : String;
    }
    
    item def AckFrame {
        attribute frameControl : Integer;
        attribute sequenceNum : FrameSequenceNumber;
    }
    
    port def RFPort {
        out item txSignal : MACFrame;
        in item rxSignal : MACFrame;
        attribute channel : ChannelNumber;
        attribute txPower : ISQ::PowerValue;
    }
    
    port def DataPort {
        in item dataIn : String;
        out item dataOut : String;
    }
    
    part def PhysicalLayer {
        port rfInterface : RFPort;
        
        attribute operatingFrequency : ISQ::FrequencyValue;
        attribute dataRate : ISQ::PowerValue;
        attribute sensitivity : ISQ::PowerValue;
        
        action def TransmitFrame {
            in frame : MACFrame;
            in txPower : ISQ::PowerValue;
            in channel : ChannelNumber;
            
            first start;
            then action applyDSSS {
                doc /* Apply Direct Sequence Spread Spectrum */
            }
            then action modulateOQPSK {
                doc /* Apply Offset Quadrature Phase Shift Keying modulation */
            }
            then action transmitRF {
                doc /* Transmit RF signal on specified channel */
            }
            then done;
        }
        
        action def ReceiveFrame {
            out frame : MACFrame;
            
            first start;
            then action detectPreamble {
                doc /* Detect synchronization preamble */
            }
            then action demodulateSignal {
                doc /* Demodulate O-QPSK signal */
            }
            then action despreadSignal {
                doc /* Despread DSSS signal */
            }
            then action validateFCS {
                doc /* Validate Frame Check Sequence */
            }
            then done;
        }
    }
    
    part def MACLayer {
        attribute macAddr : MACAddress;
        attribute panID : PANIdentifier;
        attribute beaconOrder : Integer;
        attribute superframeOrder : Integer;
        attribute sequenceCounter : FrameSequenceNumber;
        
        action def CSMACAChannelAccess {
            in dataFrame : MACFrame;
            out accessGranted : Boolean;
            
            first start;
            then merge backoffLoop;
            then action performCCA {
                doc /* Clear Channel Assessment */
                out channelIdle : Boolean;
            }
            then decide;
                if performCCA.channelIdle then grantAccess;
                if not performCCA.channelIdle then randomBackoff;
            action randomBackoff {
                doc /* Execute random backoff period */
            }
            then backoffLoop;
            action grantAccess {
                doc /* Channel access granted */
            }
            then done;
        }
        
        action def TransmitWithAck {
            in payload : String;
            in destAddr : MACAddress;
            out success : Boolean;
            
            first start;
            then action buildFrame {
                doc /* Construct MAC frame with addressing */
                out frame : MACFrame;
            }
            then action channelAccess : CSMACAChannelAccess {
                in dataFrame = buildFrame.frame;
            }
            then action transmit {
                doc /* Transmit frame via physical layer */
            }
            then action waitAck {
                doc /* Wait for acknowledgment frame */
                out ackReceived : Boolean;
            }
            then decide;
                if waitAck.ackReceived then confirmSuccess;
                if not waitAck.ackReceived then retransmit;
            action retransmit {
                doc /* Retransmit after timeout */
            }
            then channelAccess;
            action confirmSuccess {
                doc /* Transmission confirmed successful */
            }
            then done;
        }
        
        action def GenerateBeacon {
            out beacon : BeaconFrame;
            
            first start;
            then action constructBeacon {
                doc /* Build beacon frame with network information */
            }
            then action scheduleTransmission {
                doc /* Schedule beacon at superframe boundary */
            }
            then done;
        }
    }
    
    part def CoordinatorNode {
        port dataInterface : DataPort;
        
        part phy : PhysicalLayer {
            :>> operatingFrequency = 2400 [MHz];
            :>> dataRate = 250 [W];
            :>> sensitivity = -85 [W];
        }
        
        part mac : MACLayer {
            :>> beaconOrder = 6;
            :>> superframeOrder = 4;
        }
        
        connection phyMacLink connect phy.rfInterface to mac;
        
        attribute isPANCoordinator : Boolean = true;
        attribute associatedDevices : MACAddress[0..255];
        
        action def CoordinateNetwork {
            first start;
            then action initializePAN {
                doc /* Initialize Personal Area Network with PAN ID */
            }
            then merge networkOperation;
            then action broadcastBeacon : mac.GenerateBeacon;
            then action handleAssociationRequests {
                doc /* Process device association requests */
            }
            then action assignShortAddresses {
                doc /* Allocate short addresses to associated devices */
            }
            then action manageDataTransfers {
                doc /* Coordinate data transfers between devices */
            }
            then networkOperation;
        }
        
        perform action coordinatorBehavior : CoordinateNetwork;
    }
    
    part def EndDeviceNode {
        port dataInterface : DataPort;
        
        part phy : PhysicalLayer {
            :>> operatingFrequency = 2400 [MHz];
            :>> dataRate = 250 [W];
            :>> sensitivity = -85 [W];
        }
        
        part mac : MACLayer;
        
        connection phyMacLink connect phy.rfInterface to mac;
        
        attribute isAssociated : Boolean = false;
        attribute coordinatorAddr : MACAddress;
        attribute assignedShortAddr : Integer;
        
        action def OperateEndDevice {
            first start;
            then action scanForNetworks {
                doc /* Scan channels for available PANs */
            }
            then action selectNetwork {
                doc /* Select PAN based on beacon information */
            }
            then action sendAssociationRequest {
                doc /* Request association with coordinator */
            }
            then action waitAssociationResponse {
                doc /* Wait for association response with short address */
            }
            then merge dataOperation;
            then action senseData {
                doc /* Acquire sensor data */
                out sensorData : String;
            }
            then action transmitToCoordinator : mac.TransmitWithAck {
                in payload = senseData.sensorData;
                in destAddr = coordinatorAddr;
            }
            then action enterSleepMode {
                doc /* Enter low-power sleep mode */
            }
            then action wakeOnTimer {
                doc /* Wake after sleep period */
            }
            then dataOperation;
        }
        
        perform action deviceBehavior : OperateEndDevice;
    }
    
    part wirelessSensorNetwork {
        part panCoordinator : CoordinatorNode {
            mac.panID = 0x1234;
            mac.macAddr.shortAddr = 0x0000;
        }
        
        part sensorNode1 : EndDeviceNode {
            mac.panID = 0x1234;
            :>> coordinatorAddr.shortAddr = 0x0000;
        }
        
        part sensorNode2 : EndDeviceNode {
            mac.panID = 0x1234;
            :>> coordinatorAddr.shortAddr = 0x0000;
        }
        
        part sensorNode3 : EndDeviceNode {
            mac.panID = 0x1234;
            :>> coordinatorAddr.shortAddr = 0x0000;
        }
        
        item flow wirelessChannel1 of MACFrame 
            from sensorNode1.phy.rfInterface.txSignal 
            to panCoordinator.phy.rfInterface.rxSignal;
            
        item flow wirelessChannel2 of MACFrame 
            from sensorNode2.phy.rfInterface.txSignal 
            to panCoordinator.phy.rfInterface.rxSignal;
            
        item flow wirelessChannel3 of MACFrame 
            from sensorNode3.phy.rfInterface.txSignal 
            to panCoordinator.phy.rfInterface.rxSignal;
            
        item flow downlinkChannel1 of MACFrame 
            from panCoordinator.phy.rfInterface.txSignal 
            to sensorNode1.phy.rfInterface.rxSignal;
            
        item flow downlinkChannel2 of MACFrame 
            from panCoordinator.phy.rfInterface.txSignal 
            to sensorNode2.phy.rfInterface.rxSignal;
            
        item flow downlinkChannel3 of MACFrame 
            from panCoordinator.phy.rfInterface.txSignal 
            to sensorNode3.phy.rfInterface.rxSignal;
    }
    
    requirement def StandardCompliance {
        doc /* System shall comply with IEEE 802.15.4 standard for physical and MAC layers */
        
        require physicalLayerReq {
            doc /* Physical layer shall operate in 2.4 GHz ISM band with O-QPSK modulation and 250 kbps data rate */
        }
        
        require macLayerReq {
            doc /* MAC layer shall implement CSMA/CA channel access mechanism */
        }
        
        require frameFormatReq {
            doc /* Frame formats shall conform to IEEE 802.15.4 specification */
        }
    }
    
    requirement def LowPowerOperation {
        doc /* System shall support low-power operation for battery-powered devices */
        
        attribute maxActiveCurrent : ISQ::ElectricCurrentValue;
        attribute maxSleepCurrent : ISQ::ElectricCurrentValue;
        
        require sleepModeReq {
            doc /* End devices shall support sleep mode with current consumption below 15 microamperes */
        }
        
        require dutyCycleReq {
            doc /* End devices shall operate with configurable duty cycle to minimize power consumption */
        }
    }
    
    requirement def ReliableCommunication {
        doc /* System shall provide reliable wireless data transmission */
        
        attribute minPacketDeliveryRatio : Real;
        attribute maxRetransmissions : Integer;
        
        require acknowledgmentReq {
            doc /* System shall support acknowledgment frames for confirmed delivery */
        }
        
        require retransmissionReq {
            doc /* Failed transmissions shall be retried up to maximum retransmission limit */
        }
        
        require errorDetectionReq {
            doc /* All frames shall include Frame Check Sequence for error detection */
        }
    }
    
    requirement def NetworkCapacity {
        doc /* System shall support multiple end devices in star topology */
        
        attribute maxDevices : Integer = 255;
        
        require addressingReq {
            doc /* System shall support both 16-bit short addresses and 64-bit extended addresses */
        }
        
        require associationReq {
            doc /* Coordinator shall manage device association and address assignment */
        }
    }
    
    requirement systemRequirements {
        doc /* 
            The IEEE 802.15.4 wireless sensor network system shall provide low-power, 
            reliable wireless communication between distributed sensor nodes and a central 
            coordinator. The system enables battery-powered sensor devices to periodically 
            transmit collected data to the coordinator using standardized physical and MAC 
            layer protocols operating in the 2.4 GHz ISM band.
        */
        
        require StandardCompliance;
        require LowPowerOperation;
        require ReliableCommunication;
        require NetworkCapacity;
        
        require rangeReq {
            doc /* System shall support communication range of at least 10 meters indoors */
        }
        
        require topologyReq {
            doc /* System shall operate in star topology with one coordinator and multiple end devices */
        }
    }
}
