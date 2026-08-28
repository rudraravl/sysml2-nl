package IoT6LoWPANNetwork {
    private import ScalarValues::*;
    
    attribute def TemperatureValue :> Real {
        doc /* Temperature measurement in degrees Celsius */
    }
    attribute def HumidityValue :> Real {
        doc /* Relative humidity as a percentage (0-100) */
    }
    attribute def VoltageValue :> Real {
        doc /* Battery voltage in volts */
    }
    
    attribute def SensorReading {
        attribute temperature : TemperatureValue;
        attribute humidity : HumidityValue;
        attribute timestamp : Real;
    }
    
    item def IPv6Packet {
        attribute header : String;
        attribute payload : SensorReading;
        attribute nodeID : Integer;
    }
    
    item def FragmentedPacket {
        attribute fragmentID : Integer;
        attribute offset : Integer;
        attribute moreFragments : Boolean;
        attribute data : String;
        attribute nodeID : Integer;
    }
    
    port def WirelessMeshPort {
        in item incomingFragment : FragmentedPacket;
        out item outgoingFragment : FragmentedPacket;
    }
    
    port def InternetPort {
        in item incomingPacket : IPv6Packet;
        out item outgoingPacket : IPv6Packet;
    }
    
    part def SensorNode {
        attribute batteryVoltage : VoltageValue;
        attribute sleepDuration : Real = 60.0;
        attribute nodeID : Integer;
        
        port meshPort : WirelessMeshPort;
        
        action wakeNode;
        action readSensor;
        action compressHeader;
        action fragmentPacket;
        action sendFragments;
        
        exhibit state sensorLifecycle {
            entry; then Sleeping;
            
            state Sleeping {
                doc /* Low-power sleep state to conserve battery energy */
            }
            
            transition wake
                first Sleeping
                do wakeNode
                then Waking;
            
            state Waking;
            
            transition read
                first Waking
                do readSensor
                then Compressing;
            
            state Compressing;
            
            transition compress
                first Compressing
                do compressHeader
                then Fragmenting;
            
            state Fragmenting;
            
            transition fragment
                first Fragmenting
                do fragmentPacket
                then Transmitting;
            
            state Transmitting;
            
            transition transmit
                first Transmitting
                do sendFragments
                then Sleeping;
        }
    }
    
    part def BorderRouter {
        port meshPort : WirelessMeshPort;
        port internetPort : InternetPort;
        
        action reassemble;
        action decompress;
        action forward;
        
        exhibit state routerBehavior {
            entry; then Idle;
            
            state Idle;
            
            transition receive
                first Idle
                accept frag : FragmentedPacket via meshPort
                then Reassembling;
            
            state Reassembling;
            
            transition reassemblePkt
                first Reassembling
                do reassemble
                then Decompressing;
            
            state Decompressing;
            
            transition decompressPkt
                first Decompressing
                do decompress
                then Forwarding;
            
            state Forwarding;
            
            transition forwardPkt
                first Forwarding
                do forward
                then Idle;
        }
    }
    
    part def CloudServer {
        port internetPort : InternetPort;
        
        action storeData;
        action analyze;
        
        exhibit state serverBehavior {
            entry; then Receiving;
            
            state Receiving;
            
            transition receive
                first Receiving
                accept pkt : IPv6Packet via internetPort
                then Storing;
            
            state Storing;
            
            transition store
                first Storing
                do storeData
                then Analyzing;
            
            state Analyzing;
            
            transition analyzeData
                first Analyzing
                do analyze
                then Receiving;
        }
    }
    
    part def IoT6LoWPANSystem {
        part nodes : SensorNode[1..*];
        part router : BorderRouter;
        part cloud : CloudServer;
        
        interface nodes.meshPort to router.meshPort;
        interface router.internetPort to cloud.internetPort;
    }
    
    part network : IoT6LoWPANSystem;
    
    requirement def LowPowerOperation {
        doc /* Sensor nodes shall spend at least 90% of time in sleep state to conserve battery. */
        attribute minSleepPercentage : Real = 90.0;
    }
    
    requirement def HeaderCompression {
        doc /* The system shall compress IPv6 headers using 6LoWPAN IPHC compression. */
    }
    
    requirement def FragmentationReassembly {
        doc /* The system shall support fragmentation of IPv6 packets and reassembly at the border router. */
    }
    
    requirement def DataIntegrity {
        doc /* The system shall ensure sensor data is delivered without corruption from sensor to cloud. */
    }
    
    requirement lowPowerReq : LowPowerOperation {
        subject sensorNodes : SensorNode[1..*];
    }
    
    requirement compressionReq : HeaderCompression {
        subject sensorNodes : SensorNode[1..*];
    }
    
    requirement fragmentationReq : FragmentationReassembly {
        subject router : BorderRouter;
    }
    
    requirement integrityReq : DataIntegrity {
        subject sys : IoT6LoWPANSystem;
    }
    
    satisfy lowPowerReq by network.nodes;
    satisfy compressionReq by network.nodes;
    satisfy fragmentationReq by network.router;
    satisfy integrityReq by network;
}
