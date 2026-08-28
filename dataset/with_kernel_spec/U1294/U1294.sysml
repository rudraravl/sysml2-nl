package IEEE802_15_4_WSN {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    item def SensorData {
        attribute temperature: ThermodynamicTemperatureValue;
    }
    item def Beacon {
        attribute panId: Integer;
    }
    item def Acknowledgment {
        attribute seqNum: Integer;
    }
    item def DataPacket {
        attribute srcAddr: Integer;
        attribute dstAddr: Integer;
        item payload: SensorData;
    }
    item def RadioSignal;
    
    port def WirelessPort {
        out item txData: DataPacket;
        in item rxData: DataPacket;
        out item txBeacon: Beacon;
        in item rxBeacon: Beacon;
        out item txAck: Acknowledgment;
        in item rxAck: Acknowledgment;
    }
    
    port def PhyMACPort {
        in item dataToPhy: DataPacket;
        out item dataFromPhy: DataPacket;
        in item beaconToPhy: Beacon;
        out item beaconFromPhy: Beacon;
        in item ackToPhy: Acknowledgment;
        out item ackFromPhy: Acknowledgment;
    }
    
    port def AppPort {
        in item sensorData: SensorData;
        out item receivedData: SensorData;
    }
    
    action def Modulate {
        in item digitalData: DataPacket;
        out item radioSignal: RadioSignal;
    }
    action def Demodulate {
        in item radioSignal: RadioSignal;
        out item digitalData: DataPacket;
    }
    action def CheckErrors {
        in item packet: DataPacket;
        out item validPacket: DataPacket;
    }
    action def CSMA_CA {
        out attribute channelClear: Boolean;
    }
    action def ConstructPacket {
        in item data: SensorData;
        in attribute destAddr: Integer;
        out item packet: DataPacket;
    }
    action def ReceivePacket {
        in item packet: DataPacket;
        out item data: SensorData;
        out item ack: Acknowledgment;
    }
    action def TransmitPacket {
        in item packet: DataPacket;
        out attribute ackReceived: Boolean;
    }
    action def RetransmitPacket {
        in item packet: DataPacket;
    }
    action def BroadcastBeacon {
        out item beacon: Beacon;
    }
    action def ManageJoin {
        in item joinRequest: DataPacket;
        out item joinResponse: DataPacket;
    }
    action def ReceiveData {
        in item dataPacket: DataPacket;
        out item sensorData: SensorData;
    }
    action def ScanForBeacon {
        out item beacon: Beacon;
    }
    action def JoinNetwork {
        in item beacon: Beacon;
        out item joinRequest: DataPacket;
    }
    action def GatherSensorData {
        out item data: SensorData;
    }
    action def TransmitData {
        in item data: SensorData;
        out item ack: Acknowledgment;
    }
    action def EnterSleep {
        attribute duration: TimeValue = 10.0 [s];
    }
    action def Measure {
        out item data: SensorData;
    }
    
    part def PhysicalLayer {
        attribute frequency: FrequencyValue = 2.4e9 [Hz];
        attribute txPower: PowerValue = 0.01 [W];
        
        port radioIF: PhyMACPort;
        port wirelessPort: WirelessPort;
        
        perform action modulate: Modulate;
        perform action demodulate: Demodulate;
        perform action checkErrors: CheckErrors;
    }
    
    part def MACLayer {
        attribute nodeAddress: Integer;
        attribute panId: Integer;
        
        port appIF: AppPort;
        port phyIF: ~PhyMACPort;
        
        perform action csma_ca: CSMA_CA;
        perform action constructPacket: ConstructPacket;
        perform action receivePacket: ReceivePacket;
        perform action transmitPacket: TransmitPacket;
        perform action retransmitPacket: RetransmitPacket;
    }
    
    part def Sensor {
        port sensorPort: ~AppPort;
        perform action measure: Measure;
    }
    
    part def CoordinatorNode {
        attribute panId: Integer;
        
        port wirelessPort: WirelessPort;
        port appPort: AppPort;
        
        part macLayer: MACLayer;
        part phyLayer: PhysicalLayer;
        
        connect macLayer.phyIF to phyLayer.radioIF;
        connect phyLayer.wirelessPort to wirelessPort;
        
        perform action broadcastBeacon: BroadcastBeacon;
        perform action manageJoin: ManageJoin;
        perform action receiveData: ReceiveData;
        
        exhibit state coordinatorStates {
            entry; then Broadcasting;
            state Broadcasting {
                do broadcastBeacon;
            }
            accept when true then Managing;
            state Managing {
                do manageJoin;
            }
            accept when true then Receiving;
            state Receiving {
                do receiveData;
            }
            accept when true then Broadcasting;
        }
    }
    
    part def EndDeviceNode {
        attribute nodeAddress: Integer;
        attribute batteryCapacity: ElectricChargeValue;
        
        port wirelessPort: WirelessPort;
        
        part macLayer: MACLayer;
        part phyLayer: PhysicalLayer;
        part sensor: Sensor;
        
        connect macLayer.phyIF to phyLayer.radioIF;
        connect phyLayer.wirelessPort to wirelessPort;
        connect sensor.sensorPort to macLayer.appIF;
        
        perform action scanForBeacon: ScanForBeacon;
        perform action joinNetwork: JoinNetwork;
        perform action gatherSensorData: GatherSensorData;
        perform action transmitData: TransmitData;
        perform action enterSleep: EnterSleep;
        
        exhibit state endDeviceStates {
            entry; then Scanning;
            state Scanning {
                do scanForBeacon;
            }
            accept when true then Joining;
            state Joining {
                do joinNetwork;
            }
            accept when true then Active;
            state Active {
                entry gatherSensorData;
                do transmitData;
            }
            accept when true then Sleeping;
            state Sleeping {
                do enterSleep;
            }
            accept after 10 [s] then Active;
        }
    }
    
    connection def WirelessLink {
        end coordinatorEnd: WirelessPort;
        end endDeviceEnd: WirelessPort;
    }
    
    requirement def IEEE802154Compliance {
        doc /* The system shall comply with IEEE 802.15.4 standard. */
        attribute standardVersion: String = "802.15.4-2020";
        subject system: CoordinatorNode;
    }
    requirement def LowPowerOperation {
        doc /* End devices shall utilize sleep modes to conserve battery. */
        subject endDevice: EndDeviceNode;
    }
    requirement def ReliableCommunication {
        doc /* MAC layer shall retransmit packets if acknowledgment is not received. */
        subject macLayer: MACLayer;
    }
    
    part wsnSystem {
        part coordinator: CoordinatorNode;
        part endDevices: EndDeviceNode[1..*];
        
        requirement ieee802154Compliance: IEEE802154Compliance;
        requirement lowPowerOperation: LowPowerOperation;
        requirement reliableCommunication: ReliableCommunication;
        
        connection : WirelessLink connect coordinator.wirelessPort to endDevices.wirelessPort;
        
        satisfy ieee802154Compliance by coordinator;
        satisfy lowPowerOperation by endDevices;
        satisfy reliableCommunication by coordinator.macLayer;
    }
}
