package 'SixLoWPAN_IoT_System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def MACAddress;
    attribute def IPv6Address;
    attribute def PanID;
    
    attribute def PacketSize :> ISQ::LengthValue;
    
    attribute def TransmissionPower :> ISQ::PowerValue;
    
    attribute def BatteryCapacity :> ISQ::EnergyValue;
    
    item def SensorData {
        attribute temperature : ISQ::ThermodynamicTemperatureValue;
        attribute humidity : Real;
        attribute timestamp : ISQ::TimeValue;
        attribute nodeId : MACAddress;
    }
    
    item def IPv6Packet {
        attribute sourceAddr : IPv6Address;
        attribute destAddr : IPv6Address;
        attribute payload : String;
        attribute packetSize : PacketSize;
        attribute hopLimit : Integer;
    }
    
    item def IEEE802154Frame {
        attribute srcMAC : MACAddress;
        attribute dstMAC : MACAddress;
        attribute panId : PanID;
        attribute framePayload : String;
        attribute frameSize : PacketSize;
    }
    
    port def WirelessPort {
        out item txFrame : IEEE802154Frame;
        in item rxFrame : IEEE802154Frame;
        attribute signalStrength : ISQ::PowerValue;
    }
    
    port def IPv6NetworkPort {
        out item ipv6Out : IPv6Packet;
        in item ipv6In : IPv6Packet;
    }
    
    port def SensorInterfacePort {
        in attribute tempReading : ISQ::ThermodynamicTemperatureValue;
        in attribute humidityReading : Real;
    }
    
    port def PowerPort {
        in attribute voltage : ISQ::ElectricPotentialValue;
        in attribute current : ISQ::ElectricCurrentValue;
    }
    
    part def HeaderCompressionEngine {
        attribute compressionRatio : Real;
        
        action def CompressIPv6Header {
            in fullPacket : IPv6Packet;
            out compressedPacket : IPv6Packet;
        }
        
        action def DecompressIPv6Header {
            in compressedPacket : IPv6Packet;
            out fullPacket : IPv6Packet;
        }
    }
    
    part def FragmentationEngine {
        attribute maxFragmentSize : PacketSize;
        
        action def FragmentPacket {
            in largePacket : IPv6Packet;
            out fragments : IEEE802154Frame[*];
        }
        
        action def ReassembleFragments {
            in fragments : IEEE802154Frame[*];
            out reassembledPacket : IPv6Packet;
        }
    }
    
    part def IEEE802154Radio {
        attribute channel : Integer;
        attribute txPower : TransmissionPower;
        attribute dataRate : ISQ::FrequencyValue;
        
        port rfPort : WirelessPort;
        
        action def TransmitFrame {
            in frame : IEEE802154Frame;
            in power : TransmissionPower;
        }
        
        action def ReceiveFrame {
            out frame : IEEE802154Frame;
            out rssi : ISQ::PowerValue;
        }
    }
    
    part def SensorNode {
        attribute nodeAddress : MACAddress;
        attribute ipv6Addr : IPv6Address;
        attribute panIdentifier : PanID;
        
        port sensorPort : SensorInterfacePort;
        port wirelessPort : WirelessPort;
        port powerPort : PowerPort;
        
        part battery {
            attribute capacity : BatteryCapacity;
            attribute remainingCharge : BatteryCapacity;
        }
        
        part radio : IEEE802154Radio;
        part compressor : HeaderCompressionEngine;
        part fragmenter : FragmentationEngine;
        
        action def CollectSensorData {
            out sensorData : SensorData;
        }
        
        action def CreateIPv6Packet {
            in data : SensorData;
            out packet : IPv6Packet;
        }
        
        state machine NodeOperation {
            initial state Sleeping;
            state Sensing;
            state Processing;
            state Transmitting;
            
            transition from Sleeping to Sensing;
            transition from Sensing to Processing;
            transition from Processing to Transmitting;
            transition from Transmitting to Sleeping;
            
            entry Sensing perform action collect : CollectSensorData;
            entry Processing perform action createPkt : CreateIPv6Packet;
            entry Processing perform action compress : compressor.CompressIPv6Header;
            entry Processing perform action fragment : fragmenter.FragmentPacket;
            entry Transmitting perform action transmit : radio.TransmitFrame;
        }
    }
    
    part def BorderRouter {
        attribute routerAddress : MACAddress;
        attribute ipv6Address : IPv6Address;
        attribute panId : PanID;
        
        port lowpanPort : WirelessPort;
        port internetPort : IPv6NetworkPort;
        port powerPort : PowerPort;
        
        part radio : IEEE802154Radio;
        part decompressor : HeaderCompressionEngine;
        part reassembler : FragmentationEngine;
        
        action def ReceiveFromLowpan {
            out frames : IEEE802154Frame[*];
        }
        
        action def ProcessAndRoute {
            in frames : IEEE802154Frame[*];
            out ipPacket : IPv6Packet;
        }
        
        action def ForwardToInternet {
            in packet : IPv6Packet;
        }
        
        state machine RouterOperation {
            initial state Idle;
            state Receiving;
            state Processing;
            state Forwarding;
            
            transition from Idle to Receiving;
            transition from Receiving to Processing;
            transition from Processing to Forwarding;
            transition from Forwarding to Idle;
            
            entry Receiving perform action receive : ReceiveFromLowpan;
            entry Processing perform action process : ProcessAndRoute;
            entry Forwarding perform action forward : ForwardToInternet;
        }
    }
    
    part def CloudServer {
        port networkPort : IPv6NetworkPort;
        
        action def ReceiveAndStore {
            in packet : IPv6Packet;
        }
        
        action def AnalyzeData {
            in data : SensorData;
        }
    }
    
    connection def WirelessMeshConnection {
        end source : WirelessPort;
        end target : WirelessPort;
    }
    
    connection def IPv6Connection {
        end source : IPv6NetworkPort;
        end target : IPv6NetworkPort;
    }
    
    part def SixLoWPANSystem {
        doc /* 
            A 6LoWPAN (IPv6 over Low-Power Wireless Personal Area Networks) system 
            enables IPv6 connectivity for resource-constrained wireless sensor networks.
            
            Primary Function:
            The system bridges battery-powered sensor nodes operating on IEEE 802.15.4 
            low-power wireless networks to the IPv6 internet. Sensor nodes periodically 
            collect environmental data (temperature, humidity) and encapsulate it in 
            IPv6 packets. Due to the 127-byte frame size limitation of IEEE 802.15.4, 
            the system performs header compression using 6LoWPAN adaptation layer 
            techniques to reduce IPv6 overhead from 40 bytes to approximately 2-16 bytes. 
            Large packets are fragmented into multiple IEEE 802.15.4 frames for 
            transmission across the wireless mesh network. A border router receives 
            these compressed and fragmented frames, reassembles them, decompresses 
            the IPv6 headers, and routes the full IPv6 packets to cloud servers via 
            standard internet infrastructure. This enables seamless integration of 
            low-power IoT devices with existing IPv6 networks while minimizing energy 
            consumption and maximizing battery life.
        */
    }
    
    part sixLoWPANSystem : SixLoWPANSystem {
        part borderRouter : BorderRouter {
            perform action routeTraffic references RouterOperation;
        }
        
        part sensorNodes[5] : SensorNode {
            perform action operateNode references NodeOperation;
        }
        
        part cloudServer : CloudServer;
        
        connection wirelessMesh : WirelessMeshConnection[5] 
            connect sensorNodes.wirelessPort to borderRouter.lowpanPort;
        
        connection internetLink : IPv6Connection 
            connect borderRouter.internetPort to cloudServer.networkPort;
    }
    
    requirement def LowPowerOperation {
        doc /* Sensor nodes shall operate for minimum 2 years on a single battery. */
        attribute maxAvgPower : ISQ::PowerValue;
    }
    
    requirement def HeaderCompressionEfficiency {
        doc /* IPv6 header compression shall reduce overhead by at least 75%. */
    }
    
    requirement def PacketFragmentation {
        doc /* System shall fragment IPv6 packets exceeding 127 bytes into IEEE 802.15.4 frames. */
    }
    
    requirement def IPv6Interoperability {
        doc /* System shall support standard IPv6 addressing and routing to internet infrastructure. */
    }
    
    requirement def MeshNetworkScalability {
        doc /* System shall support at least 100 sensor nodes in a single PAN. */
    }
    
    requirement systemRequirements {
        require lowPower : LowPowerOperation;
        require compression : HeaderCompressionEfficiency;
        require fragmentation : PacketFragmentation;
        require interop : IPv6Interoperability;
        require scalability : MeshNetworkScalability;
        
        satisfy lowPower by sixLoWPANSystem.sensorNodes;
        satisfy compression by sixLoWPANSystem.borderRouter;
        satisfy fragmentation by sixLoWPANSystem;
        satisfy interop by sixLoWPANSystem;
        satisfy scalability by sixLoWPANSystem;
    }
}
