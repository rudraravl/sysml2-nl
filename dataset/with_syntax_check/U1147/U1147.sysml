package OneNetSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def NodeID;
	attribute def MessageID;
	
	item def NetworkMessage {
		attribute messageID : MessageID;
		attribute sourceID : NodeID;
		attribute destinationID : NodeID;
		attribute payload : String;
		attribute timestamp : TimeValue;
		attribute priority : Integer;
	}
	
	item def NetworkMetrics {
		attribute activeNodes : Integer;
		attribute messageLatency : TimeValue;
		attribute throughput : FrequencyValue;
		attribute errorRate : Real;
	}
	
	attribute def Bandwidth :> FrequencyValue;
	attribute def SignalPower :> PowerValue;
	
	port def CommunicationPort {
		out item txMessage : NetworkMessage;
		in item rxMessage : NetworkMessage;
	}
	
	port def ManagementPort {
		out item metricsReport : NetworkMetrics;
		in item configCommand;
	}
	
	item def ActivationSignal;
	item def DeactivationSignal;
	item def FaultDetected;
	item def ResetCommand;
	item def TransmitRequest;
	
	part def NetworkNode {
		attribute nodeID : NodeID;
		attribute operatingPower : PowerValue;
		attribute bandwidth : Bandwidth;
		
		port commPort : CommunicationPort;
		port mgmtPort : ManagementPort;
		
		state def NodeOperationalStates {
			entry; then initializing;
			
			state initializing {
				entry; then performSelfTest;
				action performSelfTest;
				then done;
			}
			transition init_to_ready
				first initializing
				then ready;
			
			state ready;
			transition ready_to_active
				first ready
				accept at activationSignal : ActivationSignal
				then active;
			
			state active {
				entry; then processMessages;
				action processMessages;
				then done;
			}
			transition active_to_ready
				first active
				accept at deactivationSignal : DeactivationSignal
				then ready;
			
			state fault;
			transition any_to_fault
				accept at faultDetected : FaultDetected
				then fault;
			transition fault_to_initializing
				first fault
				accept at resetCommand : ResetCommand
				then initializing;
		}
	}
	
	part def NetworkHub {
		attribute hubID : NodeID;
		attribute maxConnections : Integer;
		attribute routingTableSize : Integer;
		
		port commPorts : CommunicationPort[*];
		port mgmtPort : ManagementPort;
		
		action routeMessage {
			in incomingMsg : NetworkMessage;
			out outgoingMsg : NetworkMessage;
			out routingDecision : Boolean;
			
			first start;
			then action lookupDestination {
				in msg : NetworkMessage = incomingMsg;
				out destinationFound : Boolean;
				out targetPort : Integer;
			}
			then decide;
				if lookupDestination.destinationFound then forwardMessage;
				if not lookupDestination.destinationFound then dropMessage;
			
			action forwardMessage {
				then assign outgoingMsg := incomingMsg;
				then assign routingDecision := true;
			}
			then done;
			
			action dropMessage {
				then assign routingDecision := false;
			}
			then done;
		}
	}
	
	part def NetworkCoordinator {
		attribute coordinatorID : NodeID;
		attribute pollingInterval : TimeValue;
		attribute maxRetries : Integer;
		
		port mgmtPort : ManagementPort;
		
		action coordinateNetwork {
			in currentMetrics : NetworkMetrics;
			out optimizationCommand;
			
			first start;
			then merge monitoringLoop;
			then action analyzeMetrics {
				in metrics : NetworkMetrics = currentMetrics;
				out performanceLevel : Real;
			}
			then decide;
				if analyzeMetrics.performanceLevel >= 0.8 then maintainConfiguration;
				if analyzeMetrics.performanceLevel < 0.8 then optimizeNetwork;
			
			action maintainConfiguration;
			then monitoringLoop;
			
			action optimizeNetwork {
				then action adjustBandwidth;
				then action rebalanceLoad;
				then action updateRoutingTables;
			}
			then monitoringLoop;
		}
	}
	
	part def TransceiverUnit {
		attribute carrierFrequency : FrequencyValue;
		attribute transmitPower : SignalPower;
		attribute receiveThreshold : SignalPower;
		
		port signalOutput;
		port signalInput;
		
		state def TransceiverStates {
			entry; then standby;
			
			state standby;
			transition standby_to_transmit
				first standby
				accept at transmitRequest : TransmitRequest
				then transmit;
			
			state transmit {
				entry; then generateSignal;
				action generateSignal;
				then done;
			}
			transition transmit_to_receive
				first transmit
				then receive;
			
			state receive {
				entry; then captureSignal;
				action captureSignal;
				then processSignal;
				action processSignal;
				then done;
			}
			transition receive_to_standby
				first receive
				then standby;
		}
	}
	
	part def OneNetSystem {
		attribute systemID : NodeID;
		attribute networkTopology : String;
		attribute operationalFrequency : FrequencyValue;
		
		part hub : NetworkHub {
			attribute :>> hubID = "HUB-CENTRAL";
			attribute :>> maxConnections = 32;
			attribute :>> routingTableSize = 256;
		}
		
		part nodes : NetworkNode[8..32] {
			attribute :>> operatingPower = 2.5[SI::W];
			attribute :>> bandwidth = 1.0e6[SI::Hz];
		}
		
		part coordinator : NetworkCoordinator {
			attribute :>> coordinatorID = "COORD-MAIN";
			attribute :>> pollingInterval = 0.1[SI::s];
			attribute :>> maxRetries = 3;
		}
		
		part transceivers : TransceiverUnit[8..32] {
			attribute :>> carrierFrequency = 2.4e9[SI::Hz];
			attribute :>> transmitPower = 1.0[SI::W];
			attribute :>> receiveThreshold = 1.0e-9[SI::W];
		}
		
		connection nodeToHubConnections : NodeHubConnection[*]
			connect nodes.commPort to hub.commPorts;
		
		connection coordinatorToHubConnection : ManagementConnection
			connect coordinator.mgmtPort to hub.mgmtPort;
		
		connection nodeManagementConnections : ManagementConnection[*]
			connect coordinator.mgmtPort to nodes.mgmtPort;
		
		perform action executeOneNetOperation {
			first start;
			then action initializeSystem {
				action powerUpComponents;
				then action establishTopology;
				then action synchronizeNodes;
				then action loadRoutingTables;
			}
			then merge operationalCycle;
			then action handleTraffic {
				action receiveMessages;
				then action routeMessages;
				then action transmitMessages;
				then action updateMetrics;
			}
			then action monitorPerformance {
				action collectNodeStatus;
				then action aggregateMetrics;
				then action evaluateHealth;
			}
			then decide;
				if monitorPerformance.evaluateHealth then operationalCycle;
				if not monitorPerformance.evaluateHealth then recoverFromFailure;
			
			action recoverFromFailure {
				action identifyFailedNodes;
				then action isolateFailures;
				then action reconfigureTopology;
				then action restoreConnections;
			}
			then operationalCycle;
		}
	}
	
	connection def NodeHubConnection {
		end nodeEnd : CommunicationPort;
		end hubEnd : CommunicationPort;
	}
	
	connection def ManagementConnection {
		end controllerEnd : ManagementPort;
		end managedEnd : ManagementPort;
	}
	
	requirement def SystemReliability {
		doc /* The One-Net system shall maintain reliable communication across all connected nodes. */
		
		require constraint uptimeConstraint {
			doc /* System uptime shall exceed 99.5% over any operational period. */
		}
		
		require constraint messageDeliveryConstraint {
			doc /* Message delivery success rate shall exceed 99.9%. */
		}
	}
	
	requirement def PerformanceRequirement {
		doc /* The One-Net system shall meet specified performance criteria. */
		
		require constraint latencyConstraint {
			doc /* End-to-end message latency shall not exceed 50ms. */
		}
		
		require constraint throughputConstraint {
			doc /* System shall support minimum aggregate throughput of 10 Mbps. */
		}
	}
	
	requirement def ScalabilityRequirement {
		doc /* The One-Net system shall support dynamic scaling of network nodes. */
		
		require constraint nodeScalingConstraint {
			doc /* System shall support 8 to 32 nodes without performance degradation. */
		}
	}
	
	requirement <'ONENET-SYS-001'> oneNetPrimaryRequirement {
		doc /* The One-Net system shall provide unified, real-time communication infrastructure 
		       enabling distributed nodes to exchange messages through a centralized hub with 
		       coordinated network management, ensuring reliable data delivery, optimal routing, 
		       and adaptive performance optimization across the entire network topology. */
		
		subject oneNetSystem : OneNetSystem;
		
		require reliabilityReq : SystemReliability;
		require performanceReq : PerformanceRequirement;
		require scalabilityReq : ScalabilityRequirement;
		
		assume constraint environmentalConstraint {
			doc /* Network operates in controlled electromagnetic environment. */
		}
		
		assume constraint powerAvailabilityConstraint {
			doc /* Continuous power supply available to all system components. */
		}
	}
	
	action def TransmitMessageOverOneNet {
		in sourceNode : NetworkNode;
		in destinationNode : NetworkNode;
		in messageContent : String;
		out deliveryStatus : Boolean;
		out transmissionLatency : TimeValue;
		
		first start;
		then action composeMessage {
			in content : String = messageContent;
			in source : NodeID = sourceNode.nodeID;
			in destination : NodeID = destinationNode.nodeID;
			out msg : NetworkMessage;
		}
		then action transmitToHub {
			in message : NetworkMessage = composeMessage.msg;
			out transmitted : Boolean;
		}
		then action hubProcessing {
			in inMsg : NetworkMessage = composeMessage.msg;
			out routedMsg : NetworkMessage;
			out routingSuccess : Boolean;
		}
		then decide;
			if hubProcessing.routingSuccess then deliverMessage;
			if not hubProcessing.routingSuccess then retryTransmission;
		
		action deliverMessage {
			in finalMsg : NetworkMessage = hubProcessing.routedMsg;
			out delivered : Boolean;
			then assign deliveryStatus := delivered;
		}
		then done;
		
		action retryTransmission {
			then assign deliveryStatus := false;
		}
		then done;
	}
	
	part oneNetInstance : OneNetSystem {
		attribute :>> systemID = "ONENET-ALPHA-01";
		attribute :>> networkTopology = "star";
		attribute :>> operationalFrequency = 2.4e9[SI::Hz];
		
		perform action communicationSequence : TransmitMessageOverOneNet[*] {
			in sourceNode = oneNetInstance.nodes#(1);
			in destinationNode = oneNetInstance.nodes#(2);
			in messageContent = "System status update";
		}
	}
}
