package XenobotSystem {
    import ScalarValues::*;
    import ISQ::*;
    
    // ===== Value Types =====
    
    value def Concentration :> Real {
        :>> unit = mol/L;
    }
    
    value def ConcentrationGradient :> Real {
        :>> unit = mol/(L*m);
    }
    
    value def Mass :> Real {
        :>> unit = g;
    }
    
    value def Force :> Real {
        :>> unit = N;
    }
    
    value def Velocity :> Real {
        :>> unit = m/s;
    }
    
    value def Distance :> Real {
        :>> unit = m;
    }
    
    value def Energy :> Real {
        :>> unit = J;
    }
    
    value def Time :> Real {
        :>> unit = s;
    }
    
    value def Temperature :> Real {
        :>> unit = K;
    }
    
    value def Volume :> Real {
        :>> unit = L;
    }
    
    // ===== Item Types =====
    
    item def ChemicalSignal {
        attribute concentration : Concentration;
        attribute gradient : ConcentrationGradient;
        attribute sourceId : String;
    }
    
    item def TherapeuticDrug {
        attribute mass : Mass;
        attribute name : String;
        attribute potency : Real;
    }
    
    item def BiologicalFluid {
        attribute viscosity : Real;
        attribute temperature : Temperature;
        attribute volume : Volume;
    }
    
    item def ReleaseTrigger {
        attribute triggerId : String;
    }
    
    // ===== Port Definitions =====
    
    port def ChemicalSensingPort {
        in chemicalSignal : ChemicalSignal;
    }
    
    port def LocomotionCommandPort {
        out propulsionCommand : PropulsionCommand;
    }
    
    port def PayloadReleasePort {
        out releasedDrug : TherapeuticDrug;
    }
    
    port def EnergyPort {
        out energyLevel : Energy;
    }
    
    // ===== Signal Definitions =====
    
    item def PropulsionCommand {
        attribute direction : Real; // angle in radians
        attribute magnitude : Force;
        attribute active : Boolean;
    }
    
    item def NavigationCommand {
        attribute targetGradient : ConcentrationGradient;
        attribute heading : Real;
    }
    
    // ===== Requirements =====
    
    requirement def BiocompatibilityRequirement {
        doc /* The Xenobot must be constructed from biocompatible materials. */
        subject xenobot : Xenobot;
        constraint { xenobot.biocompatible == true }
    }
    
    requirement def BiodegradabilityRequirement {
        doc /* The Xenobot must degrade naturally after mission completion. */
        subject xenobot : Xenobot;
        constraint { xenobot.biodegradable == true }
    }
    
    requirement def ChemotaxisSensingRequirement {
        doc /* The sensor must detect chemical gradients above a threshold. */
        subject sensor : ChemotaxisSensor;
        constraint { sensor.detectionThreshold.value <= 0.001 [mol/(L*m)] }
    }
    
    requirement def PayloadCapacityRequirement {
        doc /* The payload carrier must hold at least 1 microgram of drug. */
        subject carrier : PayloadCarrier;
        constraint { carrier.maxPayload.value >= 0.000001 [g] }
    }
    
    requirement def EnergyEnduranceRequirement {
        doc /* The Xenobot must operate for at least 24 hours on internal energy. */
        subject xenobot : Xenobot;
        constraint { xenobot.initialEnergy.value >= 0.001 [J] }
    }
    
    requirement def TargetedDeliveryRequirement {
        doc /* Drug must be released only at target location. */
        subject xenobot : Xenobot;
        constraint { xenobot.payloadCarrier.released == true implies xenobot.atTarget == true }
    }
    
    // ===== Cell Definitions =====
    
    part def BiologicalCell {
        attribute biocompatible : Boolean = true;
        attribute biodegradable : Boolean = true;
        attribute energyConsumption : Energy;
    }
    
    part def ContractileCell :> BiologicalCell {
        attribute contractionForce : Force;
        attribute pulseRate : Real;
        
        action def contract {
            in intensity : Real;
            out generatedForce : Force;
        }
        
        perform contract;
    }
    
    part def CiliatedCell :> BiologicalCell {
        attribute ciliaCount : Integer;
        attribute beatFrequency : Real;
        attribute propulsiveForce : Force;
        
        action def beat {
            in frequency : Real;
            out propulsion : Force;
        }
        
        perform beat;
    }
    
    // ===== Functional Components =====
    
    part def ChemotaxisSensor {
        attribute detectionThreshold : ConcentrationGradient = 0.0005 [mol/(L*m)];
        attribute sensitivity : Real;
        attribute currentGradient : ConcentrationGradient;
        attribute signalDetected : Boolean = false;
        
        port sensingPort : ChemicalSensingPort;
        port commandPort : LocomotionCommandPort;
        
        action def detectChemicalGradient {
            in signal : ChemicalSignal;
            out detected : Boolean;
            out gradient : ConcentrationGradient;
            
            if signal.gradient >= detectionThreshold {
                assign detected = true;
                assign gradient = signal.gradient;
            } else {
                assign detected = false;
                assign gradient = 0 [mol/(L*m)];
            }
        }
        
        action def generateCommand {
            in gradient : ConcentrationGradient;
            out command : PropulsionCommand;
            
            assign command.direction = 0.0;
            assign command.magnitude = 1e-9 [N];
            assign command.active = true;
        }
        
        perform detectChemicalGradient then generateCommand;
    }
    
    part def LocomotionModule {
        part contractileCells : ContractileCell[4] {
            :>> contractionForce = 5e-10 [N];
            :>> pulseRate = 1.0;
            :>> energyConsumption = 1e-7 [J];
        }
        
        part ciliatedCells : CiliatedCell[20] {
            :>> ciliaCount = 200;
            :>> beatFrequency = 15.0;
            :>> propulsiveForce = 2e-10 [N];
            :>> energyConsumption = 5e-8 [J];
        }
        
        port commandPort : LocomotionCommandPort;
        
        attribute totalPropulsiveForce : Force;
        attribute currentVelocity : Velocity;
        
        action def generatePropulsion {
            in command : PropulsionCommand;
            out force : Force;
            
            var contractileForce : Force = 0 [N];
            var ciliaryForce : Force = 0 [N];
            
            if command.active == true {
                assign contractileForce = 4 * 5e-10 [N];
                assign ciliaryForce = 20 * 2e-10 [N];
                assign force = contractileForce + ciliaryForce;
            } else {
                assign force = 0 [N];
            }
        }
        
        action def move {
            in force : Force;
            out velocity : Velocity;
            
            assign velocity = force * 1000.0 [m/N/s];
        }
        
        perform generatePropulsion then move;
    }
    
    part def PayloadCarrier {
        attribute maxPayload : Mass = 0.00001 [g];
        attribute currentPayload : Mass;
        attribute released : Boolean = false;
        attribute drug : TherapeuticDrug;
        
        port releasePort : PayloadReleasePort;
        
        action def loadPayload {
            in drug : TherapeuticDrug;
            out loaded : Boolean;
            
            if drug.mass <= maxPayload {
                assign currentPayload = drug.mass;
                assign loaded = true;
            } else {
                assign loaded = false;
            }
        }
        
        action def releasePayload {
            in trigger : ReleaseTrigger;
            out releasedDrug : TherapeuticDrug;
            
            assign released = true;
            assign releasedDrug = drug;
            assign currentPayload = 0 [g];
        }
        
        perform loadPayload;
    }
    
    part def EnergySupply {
        attribute initialEnergy : Energy = 0.005 [J];
        attribute currentEnergy : Energy;
        attribute depleted : Boolean = false;
        
        port energyPort : EnergyPort;
        
        action def consumeEnergy {
            in amount : Energy;
            out remaining : Energy;
            out depleted : Boolean;
            
            if currentEnergy - amount <= 0 [J] {
                assign remaining = 0 [J];
                assign depleted = true;
            } else {
                assign remaining = currentEnergy - amount;
                assign depleted = false;
            }
        }
        
        action def monitorEnergy {
            out level : Energy;
            out isDepleted : Boolean;
            
            assign level = currentEnergy;
            assign isDepleted = depleted;
        }
        
        perform monitorEnergy;
    }
    
    // ===== State Machine =====
    
    state def XenobotLifecycle {
        entry; then searching;
        
        state searching {
            entry;
            do detectChemicalSignal;
            exit;
        }
        
        transition from searching to navigating
            when sensor.signalDetected == true;
        
        state navigating {
            entry;
            do propelTowardTarget;
            exit;
        }
        
        transition from navigating to delivering
            when atTarget == true;
        
        state delivering {
            entry;
            do releasePayloadAtTarget;
            exit;
        }
        
        transition from delivering to searching
            when payloadCarrier.released == true
            and energySupply.depleted == false;
        
        transition from searching to depleted
            when energySupply.depleted == true;
        
        transition from navigating to depleted
            when energySupply.depleted == true;
        
        transition from delivering to depleted
            when energySupply.depleted == true;
        
        state depleted {
            entry;
            do initiateBiodegradation;
        }
    }
    
    // ===== Actions =====
    
    action def detectChemicalSignal {
        in fluid : BiologicalFluid;
        out signal : ChemicalSignal;
        out detected : Boolean;
    }
    
    action def propelTowardTarget {
        in command : PropulsionCommand;
        out velocity : Velocity;
    }
    
    action def releasePayloadAtTarget {
        in trigger : ReleaseTrigger;
        out drug : TherapeuticDrug;
    }
    
    action def initiateBiodegradation {
        out degraded : Boolean;
    }
    
    // ===== Top-Level Xenobot =====
    
    part def Xenobot {
        attribute biocompatible : Boolean = true;
        attribute biodegradable : Boolean = true;
        attribute atTarget : Boolean = false;
        attribute size : Distance = 0.001 [m];
        
        port sensingPort : ChemicalSensingPort;
        port releasePort : PayloadReleasePort;
        port energyPort : EnergyPort;
        
        part sensor : ChemotaxisSensor {
            :>> detectionThreshold = 0.0005 [mol/(L*m)];
            :>> sensitivity = 0.95;
        }
        
        part motor : LocomotionModule;
        
        part payloadCarrier : PayloadCarrier {
            :>> maxPayload = 0.00001 [g];
            :>> drug : TherapeuticDrug {
                :>> mass = 0.000005 [g];
                :>> name = "TherapeuticAgent";
                :>> potency = 0.8;
            }
        }
        
        part energySupply : EnergySupply {
            :>> initialEnergy = 0.005 [J];
            :>> currentEnergy = 0.005 [J];
        }
        
        // Connections
        connection sensor.commandPort to motor.commandPort;
        connection energySupply.energyPort to energyPort;
        connection sensor.sensingPort to sensingPort;
        connection payloadCarrier.releasePort to releasePort;
        
        // Requirements satisfaction
        satisfy BiocompatibilityRequirement by biocompatible;
        satisfy BiodegradabilityRequirement by biodegradable;
        satisfy ChemotaxisSensingRequirement by sensor;
        satisfy PayloadCapacityRequirement by payloadCarrier;
        satisfy EnergyEnduranceRequirement by energySupply;
        satisfy TargetedDeliveryRequirement by self;
        
        exhibit XenobotLifecycle;
    }
    
    // ===== Environment =====
    
    part def BiologicalEnvironment {
        attribute temperature : Temperature = 310 [K];
        attribute viscosity : Real = 0.0035;
        
        part fluid : BiologicalFluid {
            :>> temperature = 310 [K];
            :>> viscosity = 0.0035;
            :>> volume = 0.005 [L];
        }
        
        part target : DiseaseSite {
            attribute chemicalSignal : ChemicalSignal {
                :>> concentration = 0.01 [mol/L];
                :>> gradient = 0.002 [mol/(L*m)];
                :>> sourceId = "TumorSite_001";
            }
        }
    }
    
    part def DiseaseSite {
        attribute location : Distance;
        attribute chemicalSignal : ChemicalSignal;
        attribute releaseTrigger : ReleaseTrigger {
            :>> triggerId = "TargetArrival_001";
        }
    }
    
    // ===== System Configuration =====
    
    part xenobotInstance : Xenobot {
        :>> size = 0.0008 [m];
    }
    
    part environmentInstance : BiologicalEnvironment {
        :>> temperature = 310 [K];
    }
    
    connection xenobotInstance.sensingPort to environmentInstance.target.chemicalSignal;
    
}
