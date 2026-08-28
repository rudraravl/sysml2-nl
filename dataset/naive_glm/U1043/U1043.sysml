package PowerDistributionGrid {

    import ScalarValues::*;

    // ===== Value Types =====
    value type Voltage :> Real { unit "V"; }
    value type Current :> Real { unit "A"; }
    value type Power :> Real { unit "W"; }
    value type ApparentPower :> Real { unit "VA"; }
    value type Frequency :> Real { unit "Hz"; }
    value type Resistance :> Real { unit "ohm"; }
    value type PowerFactor :> Real;
    value type Distance :> Real { unit "m"; }
    value type Duration :> Real { unit "s"; }
    value type Percentage :> Real;

    // ===== Item Types =====
    item def PowerFlow {
        attribute voltage : Voltage;
        attribute current : Current;
        attribute frequency : Frequency;
        attribute activePower : Power;
        attribute reactivePower : Power;
        attribute powerFactor : PowerFactor;
    }

    item def FaultSignal {
        attribute faultType : String;
        attribute location : String;
        attribute severity : Real;
        attribute timestamp : Duration;
    }

    item def ControlCommand {
        attribute commandType : String;
        attribute target : String;
        attribute parameter : Real;
    }

    item def StatusReport {
        attribute componentId : String;
        attribute operationalState : String;
        attribute loadLevel : Percentage;
        attribute voltageLevel : Voltage;
    }

    item def LoadDemand {
        attribute totalDemand : Power;
        attribute feederDemands[4] : Power;
        attribute timestamp : Duration;
    }

    // ===== Port Definitions =====
    port def PowerPort {
        out powerFlow : PowerFlow;
    }

    port def BidirectionalPowerPort {
        in flowIn : PowerFlow;
        out flowOut : PowerFlow;
    }

    port def ControlPort {
        in command : ControlCommand;
        out status : StatusReport;
    }

    port def MonitoringPort {
        out measurement : PowerFlow;
        out faultSignal : FaultSignal;
        in controlCommand : ControlCommand;
    }

    // ===== Part Definitions =====

    part def PowerGenerator {
        port powerOut : PowerPort;
        port control : ControlPort;
        attribute ratedCapacity : Power = 500000000 [W];
        attribute outputVoltage : Voltage = 22000 [V];
        attribute outputFrequency : Frequency = 60 [Hz];
        attribute efficiency : Real = 0.98;
        attribute operationalState : String = "Running";

        action def generatePower {
            in mechanicalInput : Power;
            out electricalOutput : PowerFlow;
        }

        perform generatePower;
    }

    part def StepUpTransformer {
        port powerIn : PowerPort;
        port powerOut : PowerPort;
        attribute inputVoltage : Voltage = 22000 [V];
        attribute outputVoltage : Voltage = 345000 [V];
        attribute turnsRatio : Real = 15.68;
        attribute efficiency : Real = 0.995;
        attribute ratedCapacity : ApparentPower = 500000000 [VA];
    }

    part def TransmissionLine {
        port powerIn : BidirectionalPowerPort;
        port powerOut : BidirectionalPowerPort;
        port monitoring : MonitoringPort;
        attribute length : Distance = 150000 [m];
        attribute lineResistance : Resistance = 2.5 [ohm];
        attribute ratedVoltage : Voltage = 345000 [V];
        attribute ratedCapacity : Power = 500000000 [W];
        attribute conductorType : String = "ACSR-500";
    }

    part def StepDownTransformer {
        port powerIn : PowerPort;
        port powerOut : PowerPort;
        attribute inputVoltage : Voltage = 345000 [V];
        attribute outputVoltage : Voltage = 13800 [V];
        attribute turnsRatio : Real = 25.0;
        attribute efficiency : Real = 0.992;
        attribute ratedCapacity : ApparentPower = 150000000 [VA];
    }

    part def CircuitBreaker {
        port powerIn : PowerPort;
        port powerOut : PowerPort;
        port control : ControlPort;
        attribute ratedVoltage : Voltage = 13800 [V];
        attribute ratedCurrent : Current = 1200 [A];
        attribute interruptingCapacity : Current = 25000 [A];
        attribute isOpen : Boolean = false;
        attribute tripTime : Duration = 0.05 [s];

        action def trip {
            in trigger : FaultSignal;
            out state : String;
        }

        action def close {
            in command : ControlCommand;
            out state : String;
        }

        perform trip;
        perform close;
    }

    part def ProtectionRelay {
        port monitoring : MonitoringPort;
        port control : ControlPort;
        attribute overcurrentThreshold : Current = 1500 [A];
        attribute undervoltageThreshold : Voltage = 12000 [V];
        attribute overvoltageThreshold : Voltage = 15000 [V];
        attribute faultDetected : Boolean = false;
        attribute lastFault : FaultSignal;

        action def monitor {
            in measurement : PowerFlow;
            out fault : FaultSignal;
        }

        action def evaluateCondition {
            in measurement : PowerFlow;
            in overcurrentSet : Current;
            in undervoltageSet : Voltage;
            in overvoltageSet : Voltage;
            out faultDetected : Boolean;
            out fault : FaultSignal;
        }

        perform monitor;
        perform evaluateCondition;

        state def ProtectionRelayBehavior {
            entry; then Monitoring;

            state Monitoring {
                entry action monitor;
            }
            state FaultDetected;
            state Tripping;
            state Isolated;
            state AwaitingReconfiguration;
            state Restored;

            transition from Monitoring to FaultDetected when faultDetected;
            transition from FaultDetected to Tripping when true;
            transition from Tripping to Isolated when true;
            transition from Isolated to AwaitingReconfiguration when true;
            transition from AwaitingReconfiguration to Restored when true;
            transition from Restored to Monitoring when true;
        }

        exhibit ProtectionRelayBehavior;
    }

    part def VoltageRegulator {
        port powerIn : PowerPort;
        port powerOut : PowerPort;
        port control : ControlPort;
        attribute inputVoltage : Voltage = 13800 [V];
        attribute outputVoltage : Voltage = 13800 [V];
        attribute regulationRange : Voltage = 1000 [V];
        attribute tapPosition : Integer = 0;
        attribute targetVoltage : Voltage = 13800 [V];

        action def regulate {
            in measurement : PowerFlow;
            in target : Voltage;
            out adjustedFlow : PowerFlow;
        }

        perform regulate;
    }

    part def DistributionFeeder {
        port powerIn : PowerPort;
        port powerOut : PowerPort;
        port monitoring : MonitoringPort;
        attribute length : Distance = 8000 [m];
        attribute lineResistance : Resistance = 0.8 [ohm];
        attribute ratedVoltage : Voltage = 13800 [V];
        attribute ratedCapacity : Power = 10000000 [W];
        attribute currentLoad : Power = 0 [W];
        attribute feederId : String;
    }

    part def ServiceTransformer {
        port powerIn : PowerPort;
        port powerOut : PowerPort;
        attribute inputVoltage : Voltage = 13800 [V];
        attribute outputVoltage : Voltage = 240 [V];
        attribute turnsRatio : Real = 57.5;
        attribute ratedCapacity : ApparentPower = 75000 [VA];
        attribute efficiency : Real = 0.97;
        attribute installationType : String;
    }

    part def LoadCenter {
        port powerIn : PowerPort;
        port control : ControlPort;
        attribute loadType : String;
        attribute demand : Power;
        attribute ratedVoltage : Voltage = 240 [V];
        attribute numberOfCustomers : Integer;
        attribute priority : Integer;

        action def consumePower {
            in supply : PowerFlow;
            out demand : Power;
        }

        perform consumePower;
    }

    part def DistributionSubstation {
        port powerIn : PowerPort;
        port feederOut[4] : PowerPort;
        port control : ControlPort;

        part stepDownTransformer : StepDownTransformer;
        part mainBreaker : CircuitBreaker;
        part feederBreakers[4] : CircuitBreaker;
        part protectionRelays[4] : ProtectionRelay;
        part voltageRegulator : VoltageRegulator;

        attribute busVoltage : Voltage = 13800 [V];
        attribute numberOfFeeders : Integer = 4;
        attribute substationId : String = "Substation-01";

        connect powerIn to mainBreaker.powerIn;
        connect mainBreaker.powerOut to stepDownTransformer.powerIn;
        connect stepDownTransformer.powerOut to voltageRegulator.powerIn;
        connect voltageRegulator.powerOut to feederBreakers[1].powerIn;
        connect voltageRegulator.powerOut to feederBreakers[2].powerIn;
        connect voltageRegulator.powerOut to feederBreakers[3].powerIn;
        connect voltageRegulator.powerOut to feederBreakers[4].powerIn;
        connect feederBreakers[1].powerOut to feederOut[1];
        connect feederBreakers[2].powerOut to feederOut[2];
        connect feederBreakers[3].powerOut to feederOut[3];
        connect feederBreakers[4].powerOut to feederOut[4];

        connect protectionRelays[1].control to feederBreakers[1].control;
        connect protectionRelays[2].control to feederBreakers[2].control;
        connect protectionRelays[3].control to feederBreakers[3].control;
        connect protectionRelays[4].control to feederBreakers[4].control;
    }

    part def GridControlSystem {
        port controlPorts[6] : ControlPort;
        port monitoringPorts[6] : MonitoringPort;
        attribute totalDemand : Power = 0 [W];
        attribute gridFrequency : Frequency = 60 [Hz];
        attribute stabilityIndex : Real = 1.0;
        attribute activeFaults : Integer = 0;
        attribute reconfigurationEnabled : Boolean = true;

        action def monitorStability {
            in measurements[6] : PowerFlow;
            out stability : Real;
        }

        action def calculateTotalDemand {
            in feederLoads[4] : Power;
            out totalDemand : Power;
        }

        action def balanceLoad {
            in demands[4] : Power;
            in capacities[4] : Power;
            out rebalanced[4] : Power;
        }

        action def detectFault {
            in measurements[6] : PowerFlow;
            out fault : FaultSignal;
        }

        action def isolateSection {
            in fault : FaultSignal;
            out commands[4] : ControlCommand;
        }

        action def reconfigureNetwork {
            in fault : FaultSignal;
            in currentTopology : String;
            out newTopology : String;
            out commands[4] : ControlCommand;
        }

        perform monitorStability;
        perform calculateTotalDemand;
        perform balanceLoad;
        perform detectFault;
        perform isolateSection;
        perform reconfigureNetwork;

        state def GridControlBehavior {
            entry; then NormalOperation;

            state NormalOperation {
                entry action monitorStability;
                do action calculateTotalDemand;
                do action balanceLoad;
            }
            state FaultDetected;
            state IsolatingFault {
                entry action isolateSection;
            }
            state Reconfiguring {
                entry action reconfigureNetwork;
            }
            state ServiceRestored;
            state EmergencyShutdown;

            transition from NormalOperation to FaultDetected when activeFaults > 0;
            transition from FaultDetected to IsolatingFault when true;
            transition from IsolatingFault to Reconfiguring when reconfigurationEnabled;
            transition from Reconfiguring to ServiceRestored when true;
            transition from ServiceRestored to NormalOperation when stabilityIndex > 0.95;
            transition from FaultDetected to EmergencyShutdown when activeFaults > 2;
        }

        exhibit GridControlBehavior;
    }

    // ===== Top-Level System =====
    part def RegionalPowerGrid {
        part generator : PowerGenerator;
        part stepUpTransformer : StepUpTransformer;
        part transmissionLine : TransmissionLine;
        part substation : DistributionSubstation;
        part feeder1 : DistributionFeeder { attribute feederId = "Feeder-01"; }
        part feeder2 : DistributionFeeder { attribute feederId = "Feeder-02"; }
        part feeder3 : DistributionFeeder { attribute feederId = "Feeder-03"; }
        part feeder4 : DistributionFeeder { attribute feederId = "Feeder-04"; }
        part serviceTransformer1 : ServiceTransformer { attribute installationType = "Pole-mounted"; }
        part serviceTransformer2 : ServiceTransformer { attribute installationType = "Pad-mounted"; }
        part serviceTransformer3 : ServiceTransformer { attribute installationType = "Pole-mounted"; }
        part serviceTransformer4 : ServiceTransformer { attribute installationType = "Pad-mounted"; }
        part industrialLoad : LoadCenter {
            attribute loadType = "Industrial";
            attribute demand = 2000000 [W];
            attribute numberOfCustomers = 5;
            attribute priority = 1;
        }
        part commercialLoad : LoadCenter {
            attribute loadType = "Commercial";
            attribute demand = 800000 [W];
            attribute numberOfCustomers = 50;
            attribute priority = 2;
        }
        part residentialLoad1 : LoadCenter {
            attribute loadType = "Residential";
            attribute demand = 400000 [W];
            attribute numberOfCustomers = 200;
            attribute priority = 3;
        }
        part residentialLoad2 : LoadCenter {
            attribute loadType = "Residential";
            attribute demand = 350000 [W];
            attribute numberOfCustomers = 180;
            attribute priority = 3;
        }
        part controlSystem : GridControlSystem;

        // Power flow connections
        connect generator.powerOut to stepUpTransformer.powerIn;
        connect stepUpTransformer.powerOut to transmissionLine.powerIn;
        connect transmissionLine.powerOut to substation.powerIn;
        connect substation.feederOut[1] to feeder1.powerIn;
        connect substation.feederOut[2] to feeder2.powerIn;
        connect substation.feederOut[3] to feeder3.powerIn;
        connect substation.feederOut[4] to feeder4.powerIn;
        connect feeder1.powerOut to serviceTransformer1.powerIn;
        connect feeder2.powerOut to serviceTransformer2.powerIn;
        connect feeder3.powerOut to serviceTransformer3.powerIn;
        connect feeder4.powerOut to serviceTransformer4.powerIn;
        connect serviceTransformer1.powerOut to industrialLoad.powerIn;
        connect serviceTransformer2.powerOut to commercialLoad.powerIn;
        connect serviceTransformer3.powerOut to residentialLoad1.powerIn;
        connect serviceTransformer4.powerOut to residentialLoad2.powerIn;

        // Control and monitoring connections
        connect controlSystem.controlPorts[1] to generator.control;
        connect controlSystem.controlPorts[2] to substation.control;
        connect controlSystem.controlPorts[3] to substation.feederBreakers[1].control;
        connect controlSystem.controlPorts[4] to substation.feederBreakers[2].control;
        connect controlSystem.controlPorts[5] to substation.feederBreakers[3].control;
        connect controlSystem.controlPorts[6] to substation.feederBreakers[4].control;
        connect transmissionLine.monitoring to controlSystem.monitoringPorts[1];
        connect feeder1.monitoring to controlSystem.monitoringPorts[2];
        connect feeder2.monitoring to controlSystem.monitoringPorts[3];
        connect feeder3.monitoring to controlSystem.monitoringPorts[4];
        connect feeder4.monitoring to controlSystem.monitoringPorts[5];
        connect substation.voltageRegulator.control to controlSystem.monitoringPorts[6];
    }

    // ===== Requirements =====
    requirement def PowerDeliveryRequirement {
        doc /* The grid shall deliver electricity from the generator to all load centers. */
        subject grid : RegionalPowerGrid;
        objective deliverPower {
            doc /* Ensure continuous power delivery to all connected load centers. */
        }
    }

    requirement def VoltageRegulationRequirement {
        doc /* Voltage at load centers shall remain within acceptable tolerance. */
        subject regulator : VoltageRegulator;
        attribute nominalVoltage : Voltage = 240 [V];
        attribute tolerance : Percentage = 5.0;
        constraint { abs(regulator.outputVoltage - nominalVoltage) / nominalVoltage * 100 <= tolerance }
    }

    requirement def FaultIsolationRequirement {
        doc /* The system shall isolate faulted sections within 100 milliseconds of detection. */
        subject relay : ProtectionRelay;
        attribute maxIsolationTime : Duration = 0.1 [s];
        constraint { relay.tripTime <= maxIsolationTime }
    }

    requirement def LoadBalancingRequirement {
        doc /* The control system shall balance load across all feeders. */
        subject control : GridControlSystem;
        attribute maxImbalance : Percentage = 10.0;
        constraint { control.perform balanceLoad; }
    }

    requirement def ServiceRestorationRequirement {
        doc /* After a fault, the system shall reconfigure to restore service to unaffected customers. */
        subject control : GridControlSystem;
        attribute maxRestorationTime : Duration = 300 [s];
        objective restoreService {
            doc /* Reroute power to restore service to maximum customers. */
        }
    }

    requirement def SafetyRequirement {
        doc /* Circuit breakers shall automatically disconnect faulted sections. */
        subject breaker : CircuitBreaker;
        attribute interruptingCapacity : Current = 25000 [A];
        constraint { breaker.interruptingCapacity >= 25000 [A] }
    }

    requirement def MonitoringRequirement {
        doc /* The control system shall continuously monitor grid stability and demand. */
        subject control : GridControlSystem;
        attribute monitoringInterval : Duration = 1 [s];
        objective continuousMonitoring {
            doc /* Monitor stability, calculate demand, and balance load continuously. */
        }
    }

    // ===== Requirement Satisfaction =====
    part gridSystem : RegionalPowerGrid {
        satisfy PowerDeliveryRequirement;
        satisfy MonitoringRequirement;
    }

    part regulatorUsage : VoltageRegulator {
        satisfy VoltageRegulationRequirement;
    }

    part relayUsage : ProtectionRelay {
        satisfy FaultIsolationRequirement;
    }

    part breakerUsage : CircuitBreaker {
        satisfy SafetyRequirement;
    }

    part controlUsage : GridControlSystem {
        satisfy LoadBalancingRequirement;
        satisfy ServiceRestorationRequirement;
    }

}
