package PowerTransmissionSystem {

    import ScalarValues::*;

    // ---- Value types with units ----
    value def VoltageValue :> Real { unit "V"; }
    value def PowerValue :> Real { unit "MW"; }
    value def FrequencyValue :> Real { unit "Hz"; }
    value def DistanceValue :> Real { unit "km"; }
    value def CurrentValue :> Real { unit "A"; }
    value def ResistanceValue :> Real { unit "ohm"; }
    value def TimeValue :> Real { unit "ms"; }

    // ---- Item types ----
    item def ElectricPower {
        attribute voltage : VoltageValue;
        attribute power : PowerValue;
        attribute frequency : FrequencyValue;
        attribute current : CurrentValue;
    }

    item def FaultSignal {
        attribute detected : Boolean;
        attribute location : String;
        attribute severity : Real;
    }

    // ---- Port definitions ----
    port def ElectricFlowPort {
        attribute voltage : VoltageValue;
        attribute power : PowerValue;
        attribute frequency : FrequencyValue;
        in item flow : ElectricPower;
    }

    port def MonitoringPort {
        attribute sensedVoltage : VoltageValue;
        attribute sensedCurrent : CurrentValue;
        in item sensedPower : ElectricPower;
        out item faultCommand : FaultSignal;
    }

    // ---- Power Plant ----
    part def PowerPlant {
        attribute ratedPower : PowerValue = 800 [MW];
        attribute ratedVoltage : VoltageValue = 22000 [V];
        attribute ratedFrequency : FrequencyValue = 60 [Hz];

        port generationPort : ElectricFlowPort {
            voltage = 22000 [V];
            power = 800 [MW];
            frequency = 60 [Hz];
        }

        action def GenerateElectricity {
            in fuel : Real;
            out generated : ElectricPower {
                voltage = 22000 [V];
                power = 800 [MW];
                frequency = 60 [Hz];
            }
        }

        perform generate : GenerateElectricity;
    }

    // ---- Step-Up Transformer ----
    part def StepUpTransformer {
        attribute inputVoltage : VoltageValue = 22000 [V];
        attribute outputVoltage : VoltageValue = 345000 [V];
        attribute turnsRatio : Real = 345000.0 / 22000.0;
        attribute efficiency : Real = 0.995;

        port primaryPort : ElectricFlowPort {
            voltage = 22000 [V];
        }
        port secondaryPort : ElectricFlowPort {
            voltage = 345000 [V];
        }

        action def StepUp {
            in input : ElectricPower;
            out output : ElectricPower {
                voltage = 345000 [V];
                power = input.power * efficiency;
                frequency = input.frequency;
            }
        }

        perform stepUp : StepUp;
    }

    // ---- Transmission Line ----
    part def TransmissionLine {
        attribute length : DistanceValue = 250 [km];
        attribute lineResistance : ResistanceValue = 2.5 [ohm];
        attribute lineReactance : ResistanceValue = 8.0 [ohm];
        attribute powerLoss : PowerValue;

        port sendingPort : ElectricFlowPort {
            voltage = 345000 [V];
        }
        port receivingPort : ElectricFlowPort {
            voltage = 345000 [V];
        }

        action def Transmit {
            in input : ElectricPower;
            out output : ElectricPower {
                voltage = input.voltage;
                power = input.power - powerLoss;
                frequency = input.frequency;
            }
        }

        perform transmit : Transmit;
    }

    // ---- Step-Down Transformer ----
    part def StepDownTransformer {
        attribute inputVoltage : VoltageValue = 345000 [V];
        attribute outputVoltage : VoltageValue = 34500 [V];
        attribute turnsRatio : Real = 345000.0 / 34500.0;
        attribute efficiency : Real = 0.995;

        port primaryPort : ElectricFlowPort {
            voltage = 345000 [V];
        }
        port secondaryPort : ElectricFlowPort {
            voltage = 34500 [V];
        }

        action def StepDown {
            in input : ElectricPower;
            out output : ElectricPower {
                voltage = 34500 [V];
                power = input.power * efficiency;
                frequency = input.frequency;
            }
        }

        perform stepDown : StepDown;
    }

    // ---- Distribution Substation ----
    part def DistributionSubstation {
        attribute feederCount : Integer = 8;
        attribute outputVoltage : VoltageValue = 34500 [V];

        port incomingPort : ElectricFlowPort {
            voltage = 34500 [V];
        }
        port feederPorts[8] : ElectricFlowPort {
            voltage = 34500 [V];
        }

        action def Distribute {
            in input : ElectricPower;
            out outputs[8] : ElectricPower {
                voltage = 34500 [V];
                power = input.power / 8;
                frequency = input.frequency;
            }
        }

        perform distribute : Distribute;
    }

    // ---- Protection System ----
    part def ProtectionSystem {
        attribute maxResponseTime : TimeValue = 80 [ms];
        attribute faultThresholdCurrent : CurrentValue = 5000 [A];
        attribute faultThresholdVoltageDrop : VoltageValue = 20000 [V];
        attribute faultDetected : Boolean = false;
        attribute isolatedSection : String;

        port monitorPort : MonitoringPort;

        action def MonitorGrid {
            in sensedVoltage : VoltageValue;
            in sensedCurrent : CurrentValue;
            out faultFlag : Boolean;
        }

        action def IsolateFault {
            in fault : FaultSignal;
            out command : FaultSignal;
        }

        action def ClearFault {
            out restored : Boolean;
        }

        state machine ProtectionStateMachine {
            entry;

            state NormalOperation {
                entry;
                do monitorGrid : MonitorGrid;
                transition to FaultDetected
                    when monitorPort.sensedCurrent > faultThresholdCurrent
                        or monitorPort.sensedVoltage < (345000 [V] - faultThresholdVoltageDrop);
            }

            state FaultDetected {
                entry;
                do isolateFault : IsolateFault;
                transition to FaultIsolation
                    when faultDetected == true;
            }

            state FaultIsolation {
                entry;
                attribute isolationTime : TimeValue = 80 [ms];
                transition to Restoration
                    when faultDetected == false;
            }

            state Restoration {
                entry;
                do clearFault : ClearFault;
                transition to NormalOperation
                    when clearFault.restored == true;
            }
        }

        perform protectionBehavior : ProtectionStateMachine;
    }

    // ---- Top-level System ----
    part powerTransmissionSystem {

        part powerPlant : PowerPlant;
        part stepUpTransformer : StepUpTransformer;
        part transmissionLine : TransmissionLine;
        part stepDownTransformer : StepDownTransformer;
        part distributionSubstation : DistributionSubstation;
        part protectionSystem : ProtectionSystem;

        connection powerFlow1 connect powerPlant.generationPort
            to stepUpTransformer.primaryPort;
        connection powerFlow2 connect stepUpTransformer.secondaryPort
            to transmissionLine.sendingPort;
        connection powerFlow3 connect transmissionLine.receivingPort
            to stepDownTransformer.primaryPort;
        connection powerFlow4 connect stepDownTransformer.secondaryPort
            to distributionSubstation.incomingPort;

        connection monitoringLink connect transmissionLine.receivingPort
            to protectionSystem.monitorPort;

        connection feederDistribution[8] connect distributionSubstation.feederPorts
            to external distributionFeeders[8] : ElectricFlowPort;
    }

    // ---- Requirements ----
    requirement def PowerGenerationRequirement {
        subject plant : PowerPlant;
        require plant.ratedPower == 800 [MW];
        require plant.ratedVoltage == 22000 [V];
        require plant.ratedFrequency == 60 [Hz];
    }

    requirement def StepUpTransformationRequirement {
        subject transformer : StepUpTransformer;
        require transformer.inputVoltage == 22000 [V];
        require transformer.outputVoltage == 345000 [V];
        require transformer.turnsRatio == 345000.0 / 22000.0;
    }

    requirement def TransmissionLineRequirement {
        subject line : TransmissionLine;
        require line.length == 250 [km];
        require line.powerLoss < 10 [MW];
        require line.lineResistance > 0 [ohm];
    }

    requirement def StepDownTransformationRequirement {
        subject transformer : StepDownTransformer;
        require transformer.inputVoltage == 345000 [V];
        require transformer.outputVoltage == 34500 [V];
        require transformer.turnsRatio == 345000.0 / 34500.0;
    }

    requirement def DistributionRequirement {
        subject substation : DistributionSubstation;
        require substation.feederCount == 8;
        require substation.outputVoltage == 34500 [V];
    }

    requirement def ProtectionResponseRequirement {
        subject protection : ProtectionSystem;
        require protection.maxResponseTime <= 80 [ms];
        require protection.faultDetected == true implies
            protection.protectionBehavior.isActive(FaultIsolation);
    }

    requirement def GridStabilityRequirement {
        subject system : powerTransmissionSystem;
        require system.transmissionLine.powerLoss < 10 [MW];
        require system.protectionSystem.maxResponseTime <= 80 [ms];
        require system.stepUpTransformer.outputVoltage == 345000 [V];
        require system.stepDownTransformer.outputVoltage == 34500 [V];
    }

    // ---- Requirement satisfactions ----
    satisfaction powerGenSat : PowerGenerationRequirement {
        subject powerPlant;
    }

    satisfaction stepUpSat : StepUpTransformationRequirement {
        subject stepUpTransformer;
    }

    satisfaction transmissionSat : TransmissionLineRequirement {
        subject transmissionLine;
    }

    satisfaction stepDownSat : StepDownTransformationRequirement {
        subject stepDownTransformer;
    }

    satisfaction distributionSat : DistributionRequirement {
        subject distributionSubstation;
    }

    satisfaction protectionSat : ProtectionResponseRequirement {
        subject protectionSystem;
    }

    satisfaction gridSat : GridStabilityRequirement {
        subject powerTransmissionSystem;
    }

}
