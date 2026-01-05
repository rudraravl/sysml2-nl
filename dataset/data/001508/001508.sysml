package MyriaNedNetworkSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def NodeAddress :> Integer;
	attribute def MessagePriority :> Integer;
	
	item def NetworkMessage {
		attribute sourceAddress : NodeAddress;
		attribute destinationAddress : NodeAddress;
		attribute priority : MessagePriority;
		attribute payload : String;
		attribute timestamp : TimeValue;
		attribute sequenceNumber : Integer;
	}
	
	item def RoutingInfo {
		attribute hopCount : Integer;
		attribute pathCost : Real;
		attribute nextHop : NodeAddress;
	}
	
	item def AcknowledgmentMessage {
		attribute ackSequenceNumber : Integer;
		attribute receiverAddress : NodeAddress;
	}
	
	attribute def DataRateValue :> Real;
	
	attribute def PacketLossRateValue :> Real;
	
	port def NetworkInterfacePort {
		in item receivedMessages : NetworkMessage[*];
		out item transmittedMessages : NetworkMessage[*];
		attribute linkBandwidth : DataRateValue;
		attribute linkLatency : TimeValue;
	}
	
	part def MessageBuffer {
		attribute capacity : Integer;
		attribute currentSize : Integer;
		attribute bufferUtilization : Real;
		
		action def EnqueueMessage {
			in msg : NetworkMessage;
			out success : Boolean;
		}
		
		action def DequeueMessage {
			out msg : NetworkMessage;
		}
	}
	
	part def RoutingEngine {
		attribute routingTableSize : Integer;
		ref part routingTable : RoutingInfo[*];
		
		action def ComputeRoute {
			in destination : NodeAddress;
			in currentNode : NodeAddress;
			out route : RoutingInfo;
		}
		
		action def UpdateRoutingTable {
			in neighborInfo : RoutingInfo[*];
		}
	}
	
	part def MyriaNedNode {
		attribute nodeAddress : NodeAddress;
		attribute processingCapacity : PowerValue;
		attribute energyRemaining : EnergyValue;
		
		port networkPorts : NetworkInterfacePort[4];
		
		part messageBuffer : MessageBuffer {
			attribute :>> capacity = 128;
		}
		
		part routingEngine : RoutingEngine;
		
		action def OperateNode {
			first start;
			then action initializeNode;
			then merge idle;
			
			action idle;
			then decide;
				if true then receiving;
			
			action receiving {
				in incomingMessage : NetworkMessage;
			}
			then action bufferMessage {
				in msg = receiving.incomingMessage;
				out success : Boolean;
			}
			then action processing;
			
			action processing {
				out isForwarding : Boolean;
				out isLocalDelivery : Boolean;
			}
			then decide;
				if processing.isForwarding then forwarding;
				if processing.isLocalDelivery then delivering;
			
			action forwarding {
				action selectOutputPort;
				then action transmitMessage;
			}
			then idle;
			
			action delivering {
				action deliverToApplication;
				then action sendAcknowledgment;
			}
			then idle;
		}
		
		perform action operateNode : OperateNode;
	}
	
	part def MyriaNedSwitch {
		attribute switchAddress : NodeAddress;
		attribute switchingCapacity : DataRateValue;
		attribute portCount : Integer;
		
		port switchPorts : NetworkInterfacePort[16];
		
		part inputBuffers : MessageBuffer[16] {
			attribute :>> capacity = 256;
		}
		
		part outputBuffers : MessageBuffer[16] {
			attribute :>> capacity = 256;
		}
		
		part switchRoutingEngine : RoutingEngine;
		
		action def SwitchMessages {
			in messages : NetworkMessage[*];
			out forwardedMessages : NetworkMessage[*];
			
			first start;
			then merge continueSwitching;
			
			for msg in messages {
				action routeMsg {
					in destination = msg.destinationAddress;
					in currentNode = switchAddress;
					out route : RoutingInfo;
				}
				then action forwardMsg {
					in message = msg;
					in routingInfo = routeMsg.route;
					out forwarded : NetworkMessage;
				}
				then assign forwardedMessages := forwardedMessages->including(forwardMsg.forwarded);
			}
			then continueSwitching;
		}
		
		perform action switchOperation : SwitchMessages;
	}
	
	part def MyriaNedNetwork {
		part computeNodes : MyriaNedNode[8];
		part switches : MyriaNedSwitch[4];
		
		private attribute networkTopology : String;
		private attribute totalThroughput : DataRateValue;
		private attribute averageLatency : TimeValue;
		private attribute packetLossRate : PacketLossRateValue;
		
		connection node1ToSwitch1 : NetworkInterfacePort
			connect computeNodes[1].networkPorts[1] to switches[1].switchPorts[1];
		connection node2ToSwitch1 : NetworkInterfacePort
			connect computeNodes[2].networkPorts[1] to switches[1].switchPorts[2];
		connection node3ToSwitch2 : NetworkInterfacePort
			connect computeNodes[3].networkPorts[1] to switches[2].switchPorts[1];
		connection node4ToSwitch2 : NetworkInterfacePort
			connect computeNodes[4].networkPorts[1] to switches[2].switchPorts[2];
		connection node5ToSwitch3 : NetworkInterfacePort
			connect computeNodes[5].networkPorts[1] to switches[3].switchPorts[1];
		connection node6ToSwitch3 : NetworkInterfacePort
			connect computeNodes[6].networkPorts[1] to switches[3].switchPorts[2];
		connection node7ToSwitch4 : NetworkInterfacePort
			connect computeNodes[7].networkPorts[1] to switches[4].switchPorts[1];
		connection node8ToSwitch4 : NetworkInterfacePort
			connect computeNodes[8].networkPorts[1] to switches[4].switchPorts[2];
		
		connection switch1ToSwitch2 : NetworkInterfacePort
			connect switches[1].switchPorts[9] to switches[2].switchPorts[9];
		connection switch2ToSwitch3 : NetworkInterfacePort
			connect switches[2].switchPorts[10] to switches[3].switchPorts[9];
		connection switch3ToSwitch4 : NetworkInterfacePort
			connect switches[3].switchPorts[10] to switches[4].switchPorts[9];
		connection switch4ToSwitch1 : NetworkInterfacePort
			connect switches[4].switchPorts[10] to switches[1].switchPorts[10];
		
		perform action networkOperation : ManageNetworkTraffic;
	}
	
	action def ManageNetworkTraffic {
		first start;
		then action initializeNetwork {
			out initialTopology : String;
			out initialRoutes : RoutingInfo[*];
		}
		then merge continuousOperation;
		
		action routeMessages {
			in messages : NetworkMessage[*];
			in routes : RoutingInfo[*] = initializeNetwork.initialRoutes;
			out routedMessages : NetworkMessage[*];
		}
		then continuousOperation;
		
		action monitorPerformance {
			out throughput : DataRateValue;
			out latency : TimeValue;
			out lossRate : PacketLossRateValue;
		}
		then decide;
			if monitorPerformance.latency > 5.0 then optimizeRouting;
			if monitorPerformance.lossRate > 0.01 then reconfigureNetwork;
			else continuousOperation;
		
		action optimizeRouting {
			in currentLatency = monitorPerformance.latency;
		}
		then continuousOperation;
		
		action reconfigureNetwork {
			in currentLossRate = monitorPerformance.lossRate;
		}
		then continuousOperation;
	}
	
	part myriaNedSystem : MyriaNedNetwork {
		perform action networkOperation : ManageNetworkTraffic;
		
		part :>> computeNodes[1] {
			attribute :>> nodeAddress = 1;
		}
		
		part :>> switches[1] {
			attribute :>> switchAddress = 101;
			perform action :>> switchOperation;
		}
	}
	
	requirement def HighPerformanceRequirement {
		doc /* The MyriaNed network shall provide high-speed, low-latency message passing 
		       between distributed compute nodes with aggregate throughput exceeding 10 Gbps. */
		
		subject myriaNedSystem;
		
		require constraint {
			myriaNedSystem.totalThroughput >= 10000.0
		}
	}
	
	requirement def LowLatencyRequirement {
		doc /* The network shall maintain average end-to-end message latency below 5 milliseconds 
		       under normal operating conditions. */
		
		subject myriaNedSystem;
		
		require constraint {
			myriaNedSystem.averageLatency < 5.0
		}
	}
	
	requirement def ReliabilityRequirement {
		doc /* The network shall maintain packet loss rate below 0.01% through adaptive routing 
		       and error recovery mechanisms. */
		
		subject myriaNedSystem;
		
		require constraint {
			myriaNedSystem.packetLossRate < 0.0001
		}
	}
	
	requirement def ScalabilityRequirement {
		doc /* The network architecture shall support at least 8 compute nodes with full mesh 
		       connectivity through hierarchical switching fabric. */
		
		subject myriaNedSystem;
		
		require constraint {
			myriaNedSystem.computeNodes->size() >= 8 and
			myriaNedSystem.switches->size() >= 4
		}
	}
	
	requirement <'MYRIANET-SYS-001'> myriaNedSystemRequirements {
		doc /* 
			The MyriaNed network system shall provide a high-performance, low-latency 
			interconnection network for distributed parallel computing applications.
			The system enables efficient message passing between compute nodes through
			intelligent routing, adaptive traffic management, and hierarchical switching
			to support scalable cluster computing workloads.
		*/
		
		require highPerformance : HighPerformanceRequirement;
		require lowLatency : LowLatencyRequirement;
		require reliability : ReliabilityRequirement;
		require scalability : ScalabilityRequirement;
	}
}
