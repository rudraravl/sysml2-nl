package OneNet {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    package Definitions {
        item def DataMessage {
            attribute sourceAddress : Integer;
            attribute destinationAddress : Integer;
            attribute sequenceNumber : Integer;
            attribute payload : String;
            attribute timestamp : TimeValue;
        }

        item def ControlCommand {
            attribute commandType : String;
            attribute targetNode : Integer;
            attribute parameter : String;
        }

        item def PerformanceMetrics {
            attribute latency : TimeValue;
            attribute throughput : Real;
            attribute errorRate : Real;
            attribute packetLossRate : Real;
        }

        item def RFSignal {
            attribute carrierFrequency : FrequencyValue;
            attribute encodedData : String;
        }

        item def RoutingEntry {
            attribute destinationAddress : Integer;
            attribute portIndex : Integer;
        }

        item def RoutingTable {
            item entries : RoutingEntry[0..*];
        }

        attribute def SelfTestPassed;
        attribute def SelfTestFailed;
        attribute def FaultDetected;
        attribute def ResetCommand;
        attribute def MessageProcessed;
        attribute def TransmissionComplete;
        attribute def ReceptionComplete;
        attribute def RouteFound;
        attribute def DestinationUnknown;
        attribute def ForwardComplete;
        attribute def DropComplete;
        attribute def MetricsCollected;
        attribute def OptimizationNeeded;
        attribute def OptimizationComplete;
        attribute def NetworkReconfigured;
        attribute def SystemReady;
        attribute def TransmitCmd;
        attribute def ReceiveCmd;
        attribute def Done;

        port def NetPort {
            in item incoming : DataMessage;
            out item outgoing : DataMessage;
        }

        port def MgmtPort {
            out item cmd : ControlCommand;
            in item metrics : PerformanceMetrics;
        }

        port def RadioPort {
            out item rfOut : RFSignal;
            in item rfIn : RFSignal;
        }

        action def PerformSelfTest;
        action def ProcessMessage;
        action def TransmitSignal;
        action def ReceiveSignal;
        action def LookupRoute;
        action def ForwardMessage;
        action def DropMessage;
        action def CollectMetrics;
        action def OptimizeNetwork;
        action def ReconfigureNetwork;
        action def HandleTraffic;
        action def MonitorHealth;

        state def TransceiverStates {
            entry; then standby;
            state standby;
            accept TransmitCmd then transmit;
            accept ReceiveCmd then receive;
            state transmit {
                do action tx : TransmitSignal;
            }
            accept TransmissionComplete then standby;
            state receive {
                do action rx : ReceiveSignal;
            }
            accept ReceptionComplete then standby;
        }

        state def NodeStates {
            entry; then init;
            state init {
                do action st : PerformSelfTest;
            }
            accept SelfTestPassed then ready;
            accept SelfTestFailed then fault;
            state ready;
            accept msg : DataMessage then active;
            state active {
                do action pm : ProcessMessage;
            }
            accept MessageProcessed then ready;
            accept FaultDetected then fault;
            state fault;
            accept ResetCommand then init;
        }

        state def HubStates {
            entry; then idle;
            state idle;
            accept msg : DataMessage then routing;
            state routing {
                do action lr : LookupRoute;
            }
            accept RouteFound then forwarding;
            accept DestinationUnknown then dropping;
            state forwarding {
                do action fm : ForwardMessage;
            }
            accept ForwardComplete then idle;
            state dropping {
                do action dm : DropMessage;
            }
            accept DropComplete then idle;
        }

        state def CoordinatorStates {
            entry; then monitoring;
            state monitoring {
                do action cm : CollectMetrics;
            }
            accept MetricsCollected then analyzing;
            accept FaultDetected then recovery;
            state analyzing;
            accept OptimizationNeeded then optimizing;
            accept Done then monitoring;
            state optimizing {
                do action opt : OptimizeNetwork;
            }
            accept OptimizationComplete then monitoring;
            accept FaultDetected then recovery;
            state recovery {
                do action rn : ReconfigureNetwork;
            }
            accept NetworkReconfigured then monitoring;
        }

        state def OneNetLifecycle {
            entry; then initialization;
            state initialization {
                do action st : PerformSelfTest;
            }
            accept SystemReady then operational;
            state operational parallel {
                state trafficHandling {
                    do action ht : HandleTraffic;
                }
                state healthMonitoring {
                    do action mh : MonitorHealth;
                }
            }
            accept FaultDetected then recovery;
            state recovery {
                do action rn : ReconfigureNetwork;
            }
            accept NetworkReconfigured then operational;
        }

        part def Transceiver {
            attribute carrierFrequency : FrequencyValue = 2.4[SI::GHz];
            port digitalPort : NetPort;
            port radioPort : RadioPort;
            exhibit state transceiverState : TransceiverStates;
        }

        part def NetworkNode {
            attribute nodeId : Integer;
            port hubPort : ~NetPort;
            port mgmtPort : ~MgmtPort;
            part transceiver : Transceiver;
            connect hubPort to transceiver.digitalPort;
            exhibit state nodeState : NodeStates;
        }

        part def NetworkHub {
            port nodePorts[8..32] : NetPort;
            port mgmtPort : ~MgmtPort;
            item routingTable : RoutingTable;
            exhibit state hubState : HubStates;
        }

        part def NetworkCoordinator {
            port nodeMgmtPorts[8..32] : MgmtPort;
            port hubMgmtPort : MgmtPort;
            item metrics : PerformanceMetrics;
            exhibit state coordinatorState : CoordinatorStates;
        }

        part def OneNet {
            part nodes[8..32] : NetworkNode;
            part hub : NetworkHub;
            part coordinator : NetworkCoordinator;
            connect nodes.hubPort to hub.nodePorts;
            connect nodes.mgmtPort to coordinator.nodeMgmtPorts;
            connect hub.mgmtPort to coordinator.hubMgmtPort;
            exhibit state lifecycle : OneNetLifecycle;
        }
    }

    package Requirements {
        private import ScalarValues::*;
        private import ISQ::*;
        private import SI::*;

        requirement def HighUptime {
            attribute minUptime : Real = 99.99;
        }

        requirement def HighDeliveryRate {
            attribute minDeliveryRate : Real = 99.9;
        }

        requirement def LowLatency {
            attribute maxLatency : TimeValue = 10[SI::ms];
        }

        requirement def Scalability {
            attribute minNodes : Integer = 8;
            attribute maxNodes : Integer = 32;
        }
    }

    package Usages {
        private import Definitions::*;
        private import Requirements::*;

        requirement highUptime : HighUptime;
        requirement highDeliveryRate : HighDeliveryRate;
        requirement lowLatency : LowLatency;
        requirement scalability : Scalability;

        part oneNet : OneNet;

        satisfy highUptime by oneNet;
        satisfy highDeliveryRate by oneNet;
        satisfy lowLatency by oneNet;
        satisfy scalability by oneNet;
    }
}
