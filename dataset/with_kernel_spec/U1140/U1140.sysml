package MyriaNedNetworkSystem {
    private import ScalarValues::*;
    
    value def Address :> String;
    value def PriorityLevel :> Integer;
    value def SequenceNumber :> Integer;
    value def Payload :> String;
    
    value def DataRate :> Real;
    value def Latency :> Real;
    value def LossRate :> Real;
    
    item def NetworkMessage {
        attribute sourceAddress : Address;
        attribute destinationAddress : Address;
        attribute priority : PriorityLevel;
        attribute sequenceNumber : SequenceNumber;
        attribute payload : Payload;
    }
    
    port def NodePort {
        attribute address : Address;
        out item outgoingMessages : NetworkMessage[*];
        in item incomingMessages : NetworkMessage[*];
    }
    
    port def SwitchPort {
        attribute portId : Integer;
        in item incomingMessages : NetworkMessage[*];
        out item outgoingMessages : NetworkMessage[*];
    }
    
    action def CalculatePath {
        in source : Address;
        in destination : Address;
        out nextHopAddress : Address;
    }
    
    action def ForwardMessage {
        in incomingMsg : NetworkMessage;
        out nextHopAddress : Address;
    }
    
    action def OptimizeRouting;
    action def ReconfigureNetwork;
    
    part def ComputeNode {
        attribute nodeAddress : Address;
        attribute processingCapacity : DataRate;
        port networkPorts : NodePort[4];
    }
    
    part def RoutingEngine {
        action calculatePath : CalculatePath;
    }
    
    part def NetworkSwitch {
        attribute switchId : String;
        part routingEngine : RoutingEngine;
        port computeNodePorts : SwitchPort[8];
        port uplinkPorts : SwitchPort[8];
        action forwardMessage : ForwardMessage;
    }
    
    part def TrafficMonitor {
        attribute totalThroughput : DataRate;
        attribute averageLatency : Latency;
        attribute packetLossRate : LossRate;
    }
    
    part def AdaptiveController {
        action optimizeRouting : OptimizeRouting;
        action reconfigureNetwork : ReconfigureNetwork;
    }
    
    requirement def NetworkPerformanceRequirements {
        attribute maxLatency : Latency = 10;
        attribute maxPacketLossRate : LossRate = 0.01;
        attribute minThroughput : DataRate = 100;
        
        requirement LatencyRequirement {
            doc /* The average message latency must not exceed maxLatency. */
        }
        requirement PacketLossRequirement {
            doc /* The packet loss rate must not exceed maxPacketLossRate. */
        }
        requirement ThroughputRequirement {
            doc /* The total data throughput must be at least minThroughput. */
        }
    }
    
    connection def NodeToSwitchConnection {
        end nodePort : NodePort;
        end switchPort : SwitchPort;
    }
    
    connection def SwitchToSwitchConnection {
        end switch1 : SwitchPort;
        end switch2 : SwitchPort;
    }
    
    part def MyriaNedNetwork {
        part computeNodes : ComputeNode[*];
        part localSwitches : NetworkSwitch[*];
        part backboneSwitches : NetworkSwitch[*];
        
        part trafficMonitor : TrafficMonitor;
        part adaptiveController : AdaptiveController;
        
        attribute maxLatency : Latency = 10;
        attribute maxPacketLossRate : LossRate = 0.01;
        attribute minThroughput : DataRate = 100;
        
        action optimizeRouting : OptimizeRouting;
        action reconfigureNetwork : ReconfigureNetwork;
        
        state NetworkStates {
            state Operational;
            state Congested {
                entry / optimizeRouting;
                do / reconfigureNetwork;
            }
            transition from Operational to Congested when trafficMonitor.averageLatency > maxLatency or trafficMonitor.packetLossRate > maxPacketLossRate;
            transition from Congested to Operational when trafficMonitor.averageLatency <= maxLatency and trafficMonitor.packetLossRate <= maxPacketLossRate;
        }
        
        connection nodeToLocalSwitch : NodeToSwitchConnection connect computeNodes.networkPorts to localSwitches.computeNodePorts;
        connection localToBackbone : SwitchToSwitchConnection connect localSwitches.uplinkPorts to backboneSwitches.uplinkPorts;
        connection backboneInterconnect : SwitchToSwitchConnection connect backboneSwitches.uplinkPorts to backboneSwitches.uplinkPorts;
    }
    
    part myriaNedNetwork : MyriaNedNetwork;
    
    part satisfactionContext {
        ref :>> myriaNedNetwork;
        satisfy requirement perfReq : NetworkPerformanceRequirements by myriaNedNetwork;
    }
}
