package MyriaNed {
    import ISQ::*;
    import ScalarValues::*;
    import ISQ::TimeUnit::*;
    import ISQ::DataRateUnit::*;
    import ISQ::FrequencyUnit::*;

    // ============================================================
    // Value Types
    // ============================================================
    attribute def NodeAddress :> Natural {
        doc "Unique address identifying a compute node within the cluster.";
    }

    attribute def SwitchId :> Natural {
        doc "Unique identifier for a switch in the cluster fabric.";
    }

    attribute def ProcessingCapacity :> Real {
        doc "Computational capacity of a node expressed in GFLOPS.";
    }

    attribute def PriorityLevel :> Integer {
        doc "Message priority (0 = lowest, 7 = highest).";
    }

    attribute def MessageSequenceNumber :> Natural {
        doc "Monotonic sequence number used for ordering and loss detection.";
    }

    attribute def PayloadSize :> Integer {
        doc "Size of the message payload in bytes.";
    }

    attribute def LossRate :> Real {
        doc "Fraction of packets lost (0..1).";
    }

    // ============================================================
    // Items
    // ============================================================
    item def DataPayload :> String {
        doc "Opaque byte sequence transported by a NetworkMessage.";
    }

    item def NetworkMessage {
        doc "Unit of data exchanged between compute nodes via switches.";
        attribute source : NodeAddress;
        attribute destination : NodeAddress;
        attribute priority : PriorityLevel = 4;
        attribute sequenceNumber : MessageSequenceNumber;
        attribute payload : DataPayload;
        attribute payloadSize : PayloadSize = 0;
        attribute timestamp : Time = 0 [s];

        constraint priorityBounds { priority >= 0 and priority <= 7; }
        constraint nonNegativePayload { payloadSize >= 0; }
        constraint selfAddressed { source != destination; }
    }

    // ============================================================
    // Ports
    // ============================================================
    port def NetworkLinkPort {
        in rx : NetworkMessage;
        out tx : NetworkMessage;
    }

    // ============================================================
    // Routing Engine
    // ============================================================
    part def RoutingEngine {
        doc "Engine that computes the next hop for a NetworkMessage.";
        attribute routingTable : NodeAddress[0..*] = ();
        attribute localSwitchId : SwitchId;

        action def ResolveNextHop {
            in destination : NodeAddress;
            in currentSwitchId : SwitchId;
            out nextPortIndex : Natural;
        }

        action def UpdateRoutingTable {
            in newTable : NodeAddress[0..*];
        }

        action route {
            in msg : NetworkMessage;
            out nextPortIndex : Natural;
        }
    }

    // ============================================================
    // Network Monitor
    // ============================================================
    part def NetworkMonitor {
        doc "Continuously tracks performance metrics for the cluster fabric.";

        attribute measuredThroughput : DataRate = 0 [Gbit/s];
        attribute avgLatency : Time = 0 [ms];
        attribute packetLossRate : LossRate = 0.0;
        attribute latencyThreshold : Time = 5 [ms];
        attribute lossThreshold : LossRate = 0.01;
        attribute minThroughput : DataRate = 1 [Gbit/s];

        action def CollectMetrics {
            in throughput : DataRate;
            in latency : Time;
            in loss : LossRate;
        }

        action def Reset {
            doc "Reset monitored statistics after a reconfiguration.";
        }

        calc def IsHealthy : Boolean {
            return (avgLatency <= latencyThreshold)
                and (packetLossRate <= lossThreshold)
                and (measuredThroughput >= minThroughput);
        }

        stateMachine MonitoringLifecycle {
            initial state Idle;
            state Sampling;
            state Alerting;

            transition from Idle to Sampling;
            transition from Sampling to Alerting
                when avgLatency > latencyThreshold
                or packetLossRate > lossThreshold
                or measuredThroughput < minThroughput;
            transition from Alerting to Sampling;
            transition from Sampling to Idle;
        }
    }

    // ============================================================
    // Optimization Controller
    // ============================================================
    part def OptimizationController {
        doc "Adaptive controller that reacts to monitoring alerts.";

        part monitor : NetworkMonitor;

        action def OptimizeRouting {
            doc "Recompute routing tables to balance load across the fabric.";
        }

        action def ReconfigureTopology {
            doc "Re-wire inter-switch links to relieve congestion.";
        }

        action def UpdateSwitchTables {
            in newTable : NodeAddress[0..*];
        }

        stateMachine AdaptiveManagement {
            initial state Operational;
            state Degraded;
            state Optimizing;
            state Reconfiguring;

            transition from Operational to Degraded
                when monitor.avgLatency > monitor.latencyThreshold
                or monitor.packetLossRate > monitor.lossThreshold
                or monitor.measuredThroughput < monitor.minThroughput;

            transition from Degraded to Optimizing
                when monitor.avgLatency > monitor.latencyThreshold;

            transition from Degraded to Reconfiguring
                when monitor.packetLossRate > monitor.lossThreshold;

            transition from Optimizing to Operational
                when monitor.avgLatency <= monitor.latencyThreshold;

            transition from Reconfiguring to Operational
                when monitor.packetLossRate <= monitor.lossThreshold;
        }
    }

    // ============================================================
    // Compute Node
    // ============================================================
    part def ComputeNode {
        doc "A single computer that runs application workloads and exchanges NetworkMessages.";

        attribute nodeAddress : NodeAddress;
        attribute processingCapacity : ProcessingCapacity;
        attribute portCount : Natural = 4;

        port netPorts[4] : NetworkLinkPort;

        item sendBuffer : NetworkMessage;
        item receiveBuffer : NetworkMessage;
        attribute seqCounter : MessageSequenceNumber = 0;

        action def Compute {
            doc "Perform a quantum of application-level computation on local data.";
        }

        action def SendMessage {
            in destination : NodeAddress;
            in payload : DataPayload;
            in priority : PriorityLevel = 4;
            out msg : NetworkMessage;
        }

        action def ReceiveMessage {
            in msg : NetworkMessage;
            out processedPayload : DataPayload;
        }

        action def EnqueueForTransmission {
            in msg : NetworkMessage;
        }

        stateMachine NodeOperation {
            initial state Idle;
            state Computing;
            state Sending;
            state Receiving;

            transition from Idle to Computing;
            transition from Computing to Sending
                when sendBuffer != null;
            transition from Sending to Receiving;
            transition from Receiving to Idle;
        }
    }

    // ============================================================
    // Network Switch
    // ============================================================
    part def NetworkSwitch {
        doc "High-capacity switch that forwards NetworkMessages using its internal RoutingEngine.";

        attribute switchId : SwitchId;
        attribute portCount : Natural = 16;

        port netPorts[16] : NetworkLinkPort;

        part routingEngine : RoutingEngine {
            :>> localSwitchId = switchId;
        }

        item forwardingQueue : NetworkMessage[0..*];

        action def Inspect {
            in msg : NetworkMessage;
            out nextPortIndex : Natural;
        }

        action def Forward {
            in msg : NetworkMessage;
            in outPortIndex : Natural;
        }

        action def UpdateRouting {
            in newTable : NodeAddress[0..*];
        }

        stateMachine SwitchState {
            initial state Listening;
            state Forwarding;
            state Idle;

            transition from Listening to Forwarding;
            transition from Forwarding to Idle;
            transition from Idle to Listening;
        }
    }

    // ============================================================
    // MyriaNed Network System
    // ============================================================
    part def MyriaNedNetworkSystem {
        doc "Cluster-wide interconnection system composing compute nodes, switches, monitoring, and adaptation.";

        part computeNodes[0..*] : ComputeNode;
        part localSwitches[0..*] : NetworkSwitch;
        part backboneSwitches[0..*] : NetworkSwitch;

        part monitor : NetworkMonitor;
        part optimizer : OptimizationController {
            :>> monitor = monitor;
        }

        connection def NodeToSwitchLink {
            end nodeSide : NetworkLinkPort;
            end switchSide : NetworkLinkPort;
        }

        connection def SwitchToSwitchLink {
            end a : NetworkLinkPort;
            end b : NetworkLinkPort;
        }

        connection nodeToSwitch[*] : NodeToSwitchLink
            connect computeNodes.netPorts to localSwitches.netPorts;

        connection localToBackbone[*] : SwitchToSwitchLink
            connect localSwitches.netPorts to backboneSwitches.netPorts;

        connection backboneToBackbone[*] : SwitchToSwitchLink
            connect backboneSwitches.netPorts to backboneSwitches.netPorts;

        stateMachine SystemAdaptiveControl {
            initial state Stable;
            state Congested;
            state Recovering;

            transition from Stable to Congested
                when monitor.avgLatency > monitor.latencyThreshold
                or monitor.packetLossRate > monitor.lossThreshold
                or monitor.measuredThroughput < monitor.minThroughput;

            transition from Congested to Recovering;
            transition from Recovering to Stable
                when monitor.avgLatency <= monitor.latencyThreshold
                and monitor.packetLossRate <= monitor.lossThreshold
                and monitor.measuredThroughput >= monitor.minThroughput;
        }
    }

    // ============================================================
    // Requirements
    // ============================================================
    requirement def NetworkPerformanceRequirement {
        doc "The MyriaNed network shall sustain low-latency, high-throughput, reliable inter-node communication.";

        subject sys : MyriaNedNetworkSystem;
        attribute minThroughput : DataRate = 10 [Gbit/s];
        attribute maxLatency : Time = 5 [ms];
        attribute maxPacketLoss : LossRate = 0.01;

        constraint throughputConstraint { sys.monitor.measuredThroughput >= minThroughput; }
        constraint latencyConstraint { sys.monitor.avgLatency <= maxLatency; }
        constraint lossConstraint { sys.monitor.packetLossRate <= maxPacketLoss; }
    }

    requirement def ComputeNodeRequirement {
        doc "Each compute node shall have a unique address, positive processing capacity, and exactly four network ports.";

        subject node : ComputeNode;
        constraint portCountConstraint { node.portCount == 4; }
        constraint capacityConstraint { node.processingCapacity > 0; }
        constraint addressUniqueConstraint { node.nodeAddress >= 0; }
    }

    requirement def SwitchRequirement {
        doc "Each switch shall provide sixteen ports and route using its internal RoutingEngine.";

        subject sw : NetworkSwitch;
        constraint switchPortCount { sw.portCount == 16; }
        constraint hasRoutingEngine { sw.routingEngine != null; }
    }

    requirement def MessageFormatRequirement {
        doc "Every NetworkMessage shall carry source, destination, priority, sequence number, and payload.";

        subject msg : NetworkMessage;
        constraint hasSource { msg.source >= 0; }
        constraint hasDestination { msg.destination >= 0; }
        constraint priorityInRange { msg.priority >= 0 and msg.priority <= 7; }
        constraint hasPayload { msg.payload != null; }
    }

    requirement def AdaptiveManagementRequirement {
        doc "The system shall continuously monitor performance and adaptively optimize routing or reconfigure topology.";

        subject sys : MyriaNedNetworkSystem;
        constraint hasMonitor { sys.monitor != null; }
        constraint hasOptimizer { sys.optimizer != null; }
        constraint thresholdsDefined { sys.monitor.latencyThreshold > 0 [ms]
            and sys.monitor.lossThreshold > 0.0
            and sys.monitor.minThroughput > 0 [Gbit/s]; }
    }

    // ============================================================
    // Satisfaction
    // ============================================================
    satisfaction satisfy NetworkPerformanceRequirement by MyriaNedNetworkSystem;
    satisfaction satisfy AdaptiveManagementRequirement by MyriaNedNetworkSystem;
    satisfaction satisfy ComputeNodeRequirement by ComputeNode;
    satisfaction satisfy SwitchRequirement by NetworkSwitch;
    satisfaction satisfy MessageFormatRequirement by NetworkMessage;
}
