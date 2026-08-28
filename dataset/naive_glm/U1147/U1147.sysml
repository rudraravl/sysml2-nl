package OneNet {
    import ScalarValues::*;

    // ===== Value Types with Units =====
    value type Frequency :> Real { unit "Hz"; }
    value type Latency :> Real { unit "ms"; }
    value type Throughput :> Real { unit "Mbps"; }
    value type ErrorRate :> Real { unit "percent"; }
    value type Power :> Real { unit "dBm"; }
    value type DataRate :> Real { unit "bps"; }
    value type Duration :> Real { unit "s"; }
    value type Uptime :> Real { unit "percent"; }
    value type SuccessRate :> Real { unit "percent"; }
    value type Bandwidth :> Real { unit "MHz"; }

    // ===== Enumerations =====
    enum MessagePriority { low; normal; high; critical; }
    enum CoordinatorAction { adjustBandwidth; rebalanceLoad; updateRoutingTable; isolateNode; }
    enum SystemPhase { initializing; operational; recovery; shutdown; }
    enum TransceiverMode { standby; transmit; receive; }
    enum NodeState { initialization; selfTest; ready; active; fault; }

    // ===== Event Items =====
    item def InitComplete;
    item def TestPassed;
    item def TestFailed;
    item def Activate;
    item def Deactivate;
    item def ErrorCondition;
    item def Reset;
    item def TransmitComplete;
    item def ListenMode;
    item def RoutingComplete;
    item def UpdateComplete;
    item def MetricsCollected;
    item def OptimizationNeeded;
    item def NoActionNeeded;
    item def CommandIssued;
    item def FaultDetected;
    item def RecoveryComplete;
    item def SystemReady;
    item def SystemFault;
    item def ShutdownCommand;

    // ===== Item Definitions =====
    item def DataMessage {
        attribute messageId: String;
        attribute sourceId: Integer;
        attribute destinationId: Integer;
        attribute payload: String;
        attribute priority: MessagePriority default MessagePriority::normal;
        attribute sizeBytes: Integer;
        attribute timestamp: Duration;
    }

    item def ControlMessage {
        attribute messageId: String;
        attribute action: CoordinatorAction;
        attribute targetId: Integer;
        attribute parameters: String;
    }

    item def StatusReport {
        attribute nodeId: Integer;
        attribute nodeState: NodeState;
        attribute uptime: Duration;
        attribute messagesSent: Integer;
        attribute messagesReceived: Integer;
        attribute errorCount: Integer;
    }

    item def RoutingEntry {
        attribute nodeId: Integer;
        attribute portIndex: Integer;
    }

    item def RoutingTable {
        attribute entries: RoutingEntry[0..*];
    }

    item def PerformanceMetrics {
        attribute avgLatency: Latency;
        attribute throughput: Throughput;
        attribute errorRate: ErrorRate;
        attribute activeNodeCount: Integer;
        attribute timestamp: Duration;
    }

    item def RadioSignal {
        attribute frequency: Frequency;
        attribute power: Power;
        attribute encodedMessage: DataMessage;
    }

    // ===== Port Definitions =====
    port def RadioPort {
        out item transmitSignal: RadioSignal;
        in item receivedSignal: RadioSignal;
    }

    port def DataPort {
        out item outgoingMessage: DataMessage;
        in item incomingMessage: DataMessage;
    }

    port def ControlPort {
        out item command: ControlMessage;
        in item status: StatusReport;
    }

    port def ManagementPort {
        out item metrics: PerformanceMetrics;
        in item coordinatorCommand: ControlMessage;
    }

    // ===== Transceiver Unit =====
    part def TransceiverUnit {
        port radioPort: RadioPort;
        port dataPort: DataPort;

        attribute operatingFrequency: Frequency = 2400000000;
        attribute transmitPower: Power = 10.0;
        attribute maxDataRate: DataRate = 1000000;
        attribute currentMode: TransceiverMode default TransceiverMode::standby;

        action def EncodeMessage {
            in digitalMessage: DataMessage;
            out radioSignal: RadioSignal;
        }

        action def DecodeSignal {
            in radioSignal: RadioSignal;
            out digitalMessage: DataMessage;
        }

        state machine transceiverBehavior {
            state standby {
                entry { currentMode = TransceiverMode::standby; }
            }
            state transmit {
                entry { currentMode = TransceiverMode::transmit; }
                do { /* encode and emit radio signal */ }
            }
            state receive {
                entry { currentMode = TransceiverMode::receive; }
                do { /* listen for incoming radio signals */ }
            }

            transition standbyToTransmit
                first standby then accept DataMessage then transmit;
            transition transmitToStandby
                first transmit then accept TransmitComplete then standby;
            transition standbyToReceive
                first standby then accept ListenMode then receive;
            transition receiveToStandby
                first receive then accept RadioSignal then standby;
        }
    }

    // ===== Network Node =====
    part def NetworkNode {
        port dataPort: DataPort;
        port controlPort: ControlPort;

        attribute nodeId: Integer;
        attribute isFaulty: Boolean = false;
        attribute messagesGenerated: Integer = 0;
        attribute messagesReceived: Integer = 0;
        attribute messagesSent: Integer = 0;
        attribute errorCount: Integer = 0;

        part transceiver: TransceiverUnit;

        connection nodeDataToTransceiver connect dataPort to transceiver.dataPort;

        action def GenerateMessage {
            out message: DataMessage;
        }

        action def ProcessMessage {
            in message: DataMessage;
        }

        action def SendStatusReport {
            out report: StatusReport;
        }

        action def PerformSelfTest {
            out testResult: Boolean;
        }

        state machine nodeBehavior {
            state initialization {
                entry { /* boot up and load configuration */ }
            }
            state selfTest {
                entry { /* run hardware diagnostics */ }
                do { /* execute self-test procedures */ }
            }
            state ready {
                entry { /* ready to send and receive */ }
            }
            state active {
                entry { /* begin active message processing */ }
                do { /* process incoming and outgoing messages */ }
                exit { /* cease message processing */ }
            }
            state fault {
                entry { isFaulty = true; }
                do { /* await reset command from coordinator */ }
                exit { isFaulty = false; }
            }

            transition initToSelfTest
                first initialization then accept InitComplete then selfTest;
            transition selfTestToReady
                first selfTest then accept TestPassed then ready;
            transition selfTestToFault
                first selfTest then accept TestFailed then fault;
            transition readyToActive
                first ready then accept Activate then active;
            transition activeToReady
                first active then accept Deactivate then ready;
            transition activeToFault
                first active then accept ErrorCondition then fault;
            transition readyToFault
                first ready then accept ErrorCondition then fault;
            transition faultToInitialization
                first fault then accept Reset then initialization;
        }
    }

    // ===== Network Hub =====
    part def NetworkHub {
        port nodePorts: DataPort[8..32];
        port managementPort: ManagementPort;

        attribute routingTable: RoutingTable;
        attribute maxQueueSize: Integer = 256;
        attribute messagesRouted: Integer = 0;
        attribute messagesDropped: Integer = 0;
        attribute currentBandwidth: Bandwidth = 20.0;

        action def RouteMessage {
            in message: DataMessage;
            in table: RoutingTable;
            out forwardedMessage: DataMessage;
            out dropDecision: Boolean;
        }

        action def UpdateRoutingTable {
            in command: ControlMessage;
            out updatedTable: RoutingTable;
        }

        action def LookupDestination {
            in destinationId: Integer;
            in table: RoutingTable;
            out portIndex: Integer;
            out found: Boolean;
        }

        state machine hubBehavior {
            state idle;
            state routing {
                entry { /* process incoming messages */ }
                do { /* look up destination and forward or drop */ }
            }
            state updating {
                entry { /* update routing table from coordinator */ }
            }

            transition idleToRouting
                first idle then accept DataMessage then routing;
            transition routingToIdle
                first routing then accept RoutingComplete then idle;
            transition idleToUpdating
                first idle then accept ControlMessage then updating;
            transition updatingToIdle
                first updating then accept UpdateComplete then idle;
        }
    }

    // ===== Network Coordinator =====
    part def NetworkCoordinator {
        port nodeControlPorts: ControlPort[8..32];
        port hubManagementPort: ManagementPort;

        attribute collectedMetrics: PerformanceMetrics;
        attribute monitoringInterval: Duration = 5.0;
        attribute faultThreshold: ErrorRate = 5.0;
        attribute latencyThreshold: Latency = 50.0;
        attribute throughputTarget: Throughput = 100.0;

        action def CollectMetrics {
            in nodeStatus: StatusReport[0..*];
            in hubMetrics: PerformanceMetrics;
            out aggregatedMetrics: PerformanceMetrics;
        }

        action def AnalyzePerformance {
            in metrics: PerformanceMetrics;
            out actionType: CoordinatorAction;
            out requiresAction: Boolean;
        }

        action def IssueCommand {
            in actionType: CoordinatorAction;
            in targetId: Integer;
            out controlMsg: ControlMessage;
        }

        action def IdentifyFaultyNode {
            in statusReports: StatusReport[0..*];
            out faultyNodeId: Integer;
            out found: Boolean;
        }

        action def ReconfigureNetwork {
            in faultyNodeId: Integer;
            out routingUpdate: ControlMessage;
        }

        state machine coordinatorBehavior {
            state monitoring {
                entry { /* collect metrics from all nodes and hub */ }
                do { /* gather status reports and performance data */ }
            }
            state analyzing {
                entry { /* evaluate performance data */ }
                do { /* compare metrics against thresholds */ }
            }
            state commanding {
                entry { /* issue optimization commands */ }
                do { /* adjust bandwidth, rebalance loads, update routing */ }
            }
            state recovery {
                entry { /* identify and isolate faulty nodes */ }
                do { /* reconfigure network around isolated nodes */ }
            }

            transition monitoringToAnalyzing
                first monitoring then accept MetricsCollected then analyzing;
            transition analyzingToCommanding
                first analyzing then accept OptimizationNeeded then commanding;
            transition analyzingToMonitoring
                first analyzing then accept NoActionNeeded then monitoring;
            transition commandingToMonitoring
                first commanding then accept CommandIssued then monitoring;
            transition monitoringToRecovery
                first monitoring then accept FaultDetected then recovery;
            transition analyzingToRecovery
                first analyzing then accept FaultDetected then recovery;
            transition recoveryToMonitoring
                first recovery then accept RecoveryComplete then monitoring;
        }
    }

    // ===== OneNet System =====
    part def OneNetSystem {
        attribute systemPhase: SystemPhase default SystemPhase::initializing;
        attribute nodeCount: Integer = 16;
        attribute minNodes: Integer = 8;
        attribute maxNodes: Integer = 32;

        part coordinator: NetworkCoordinator;
        part hub: NetworkHub;
        part nodes: NetworkNode[8..32];

        // Star topology connections
        connection nodeDataToHub connect nodes.dataPort to hub.nodePorts;
        connection coordinatorToNodes connect coordinator.nodeControlPorts to nodes.controlPort;
        connection coordinatorToHub connect coordinator.hubManagementPort to hub.managementPort;

        state machine systemLifecycle {
            state initialization {
                entry { systemPhase = SystemPhase::initializing; }
                do { /* initialize all nodes, hub, and coordinator */ }
            }
            state operational {
                entry { systemPhase = SystemPhase::operational; }
                do { /* handle traffic and monitor network health */ }
            }
            state recovery {
                entry { systemPhase = SystemPhase::recovery; }
                do { /* identify and isolate faulty nodes, reconfigure */ }
            }
            state shutdown {
                entry { systemPhase = SystemPhase::shutdown; }
                do { /* graceful shutdown of all components */ }
            }

            transition initToOperational
                first initialization then accept SystemReady then operational;
            transition operationalToRecovery
                first operational then accept SystemFault then recovery;
            transition recoveryToOperational
                first recovery then accept RecoveryComplete then operational;
            transition operationalToShutdown
                first operational then accept ShutdownCommand then shutdown;
            transition recoveryToShutdown
                first recovery then accept ShutdownCommand then shutdown;
        }
    }

    // ===== Requirements =====
    requirement def HighUptimeRequirement {
        doc /* The system shall maintain high uptime availability. */
        attribute minUptime: Uptime = 99.95;
    }

    requirement def DeliverySuccessRequirement {
        doc /* The system shall achieve a very high message delivery success rate. */
        attribute minDeliveryRate: SuccessRate = 99.9;
    }

    requirement def LowLatencyRequirement {
        doc /* The system shall maintain low end-to-end message latency. */
        attribute maxLatency: Latency = 50.0;
    }

    requirement def ScalabilityRequirement {
        doc /* The system shall scale its number of nodes without degrading performance. */
        attribute minNodes: Integer = 8;
        attribute maxNodes: Integer = 32;
    }

    requirement def FrequencyRequirement {
        doc /* Transceiver units shall operate at 2.4 GHz frequency. */
        attribute requiredFrequency: Frequency = 2400000000;
    }

    requirement OneNetUptime : HighUptimeRequirement {
        subject system: OneNetSystem;
    }

    requirement OneNetDelivery : DeliverySuccessRequirement {
        subject system: OneNetSystem;
    }

    requirement OneNetLatency : LowLatencyRequirement {
        subject system: OneNetSystem;
    }

    requirement OneNetScalability : ScalabilityRequirement {
        subject system: OneNetSystem;
    }

    requirement OneNetFrequency : FrequencyRequirement {
        subject transceivers: TransceiverUnit;
    }
}
