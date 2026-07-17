package 'Capacitor Energy Storage System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def ChargeCommand;
    attribute def DischargeCommand;
    attribute def ResetCommand;
    
    port def ElectricalPort {
        attribute potential : ISQ::VoltageValue;
        attribute current : ISQ::ElectricCurrentValue;
    }
    
    part def VoltageSource {
        attribute suppliedVoltage : ISQ::VoltageValue;
        port positive : ElectricalPort;
        port negative : ElectricalPort;
    }
    
    part def ChargingResistor {
        attribute resistance : ISQ::ResistanceValue;
        port terminal1 : ElectricalPort;
        port terminal2 : ElectricalPort;
    }
    
    part def Capacitor {
        attribute capacitance : ISQ::CapacitanceValue;
        attribute maxVoltage : ISQ::VoltageValue;
        attribute currentVoltage : ISQ::VoltageValue;
        attribute storedCharge : ISQ::ElectricChargeValue;
        attribute storedEnergy : ISQ::EnergyValue;
        port positive : ElectricalPort;
        port negative : ElectricalPort;
    }
    
    part def LoadResistor {
        attribute resistance : ISQ::ResistanceValue;
        port terminal1 : ElectricalPort;
        port terminal2 : ElectricalPort;
    }
    
    action def ChargeCapacitor {
        in sourceVoltage : ISQ::VoltageValue;
        in seriesResistance : ISQ::ResistanceValue;
        in capacitance : ISQ::CapacitanceValue;
        in initialVoltage : ISQ::VoltageValue;
        in timeStep : ISQ::TimeValue;
        out finalVoltage : ISQ::VoltageValue;
        out chargingCurrent : ISQ::ElectricCurrentValue;
    }
    
    action def DischargeCapacitor {
        in loadResistance : ISQ::ResistanceValue;
        in capacitance : ISQ::CapacitanceValue;
        in initialVoltage : ISQ::VoltageValue;
        in timeStep : ISQ::TimeValue;
        out finalVoltage : ISQ::VoltageValue;
        out dischargeCurrent : ISQ::ElectricCurrentValue;
    }
    
    action def CalculateStoredEnergy {
        in capacitance : ISQ::CapacitanceValue;
        in voltage : ISQ::VoltageValue;
        out energy : ISQ::EnergyValue;
    }
    
    action def CalculateStoredCharge {
        in capacitance : ISQ::CapacitanceValue;
        in voltage : ISQ::VoltageValue;
        out charge : ISQ::ElectricChargeValue;
    }
    
    action def MonitorCapacitorState {
        in voltage : ISQ::VoltageValue;
        in maxVoltage : ISQ::VoltageValue;
        out isFullyCharged : Boolean;
        out isFullyDischarged : Boolean;
    }
    
    action def ManageEnergyStorage {
        in capacitorCapacitance : ISQ::CapacitanceValue;
        in chargingResistance : ISQ::ResistanceValue;
        in dischargingResistance : ISQ::ResistanceValue;
        in supplyVoltage : ISQ::VoltageValue;
        in targetVoltage : ISQ::VoltageValue;
        in operationTimeStep : ISQ::TimeValue;
        out finalVoltage : ISQ::VoltageValue;
        out totalEnergyStored : ISQ::EnergyValue;
        
        private attribute currentVoltage : ISQ::VoltageValue := 0.0[SI::V];
        
        first start;
        then merge chargingLoop;
        
        then action monitor : MonitorCapacitorState {
            in voltage = currentVoltage;
            in maxVoltage = targetVoltage;
            out isFullyCharged;
            out isFullyDischarged;
        }
        
        then decide;
            if monitor.isFullyCharged then calculateEnergy;
            if not monitor.isFullyCharged then chargeStep;
        
        action chargeStep : ChargeCapacitor {
            in sourceVoltage = supplyVoltage;
            in seriesResistance = chargingResistance;
            in capacitance = capacitorCapacitance;
            in initialVoltage = currentVoltage;
            in timeStep = operationTimeStep;
            out finalVoltage;
            out chargingCurrent;
        }
        then assign currentVoltage := chargeStep.finalVoltage;
        then chargingLoop;
        
        action calculateEnergy : CalculateStoredEnergy {
            in capacitance = capacitorCapacitance;
            in voltage = currentVoltage;
            out energy;
        }
        then assign totalEnergyStored := calculateEnergy.energy;
        then assign finalVoltage := currentVoltage;
        then done;
    }
    
    requirement def EnergyStorageRequirement {
        doc /* The capacitor system shall store electrical energy by accumulating electric charge 
               on conductive plates separated by a dielectric material. The stored energy is 
               proportional to the square of the voltage and the capacitance value. */
        
        require constraint {
            storedEnergy == 0.5 * capacitance * voltage * voltage
        }
        
        attribute capacitance : ISQ::CapacitanceValue;
        attribute voltage : ISQ::VoltageValue;
        attribute storedEnergy : ISQ::EnergyValue;
    }
    
    requirement def VoltageRatingRequirement {
        doc /* The capacitor operating voltage shall not exceed the maximum rated voltage 
               to prevent dielectric breakdown and component failure. */
        
        require constraint {
            operatingVoltage <= maxRatedVoltage
        }
        
        attribute operatingVoltage : ISQ::VoltageValue;
        attribute maxRatedVoltage : ISQ::VoltageValue;
    }
    
    requirement def ChargeStorageRequirement {
        doc /* The capacitor shall store electric charge proportional to the applied voltage 
               and its capacitance value according to Q = C * V. */
        
        require constraint {
            storedCharge == capacitance * voltage
        }
        
        attribute storedCharge : ISQ::ElectricChargeValue;
        attribute capacitance : ISQ::CapacitanceValue;
        attribute voltage : ISQ::VoltageValue;
    }
    
    requirement def EnergyDeliveryRequirement {
        doc /* The capacitor system shall deliver stored electrical energy to a connected load 
               through controlled discharge when commanded. */
        
        subject system : CapacitorEnergyStorageSystem;
    }
    
    requirement <'CAP-SYS-001'> capacitorSystemRequirement {
        doc /* The capacitor system shall provide temporary energy storage by charging from a 
               voltage source through a series resistor and discharging through a load resistor 
               in a controlled manner. The system shall manage the charge and discharge cycles 
               to maintain safe operating conditions and maximize energy storage efficiency. */
        
        subject capacitorSystem : CapacitorEnergyStorageSystem;
        
        assume constraint validCapacitance {
            capacitorSystem.capacitor.capacitance > 0.0[SI::F]
        }
        
        assume constraint validResistances {
            capacitorSystem.chargingResistor.resistance > 0.0[SI::Ω] and
            capacitorSystem.loadResistor.resistance > 0.0[SI::Ω]
        }
        
        require energyStorageReq : EnergyStorageRequirement {
            capacitance = capacitorSystem.capacitor.capacitance;
            voltage = capacitorSystem.capacitor.currentVoltage;
            storedEnergy = capacitorSystem.capacitor.storedEnergy;
        }
        
        require voltageRatingReq : VoltageRatingRequirement {
            operatingVoltage = capacitorSystem.capacitor.currentVoltage;
            maxRatedVoltage = capacitorSystem.capacitor.maxVoltage;
        }
        
        require chargeStorageReq : ChargeStorageRequirement {
            storedCharge = capacitorSystem.capacitor.storedCharge;
            capacitance = capacitorSystem.capacitor.capacitance;
            voltage = capacitorSystem.capacitor.currentVoltage;
        }
        
        require energyDeliveryReq : EnergyDeliveryRequirement {
            system = capacitorSystem;
        }
    }
    
    part def CapacitorEnergyStorageSystem {
        part source : VoltageSource;
        part chargingResistor : ChargingResistor;
        part capacitor : Capacitor;
        part loadResistor : LoadResistor;
        
        connect source.positive to chargingResistor.terminal1;
        connect chargingResistor.terminal2 to capacitor.positive;
        connect capacitor.positive to loadResistor.terminal1;
        connect loadResistor.terminal2 to capacitor.negative;
        connect capacitor.negative to source.negative;
        
        action manageEnergy : ManageEnergyStorage {
            in capacitorCapacitance : ISQ::CapacitanceValue = capacitor.capacitance;
            in chargingResistance : ISQ::ResistanceValue = chargingResistor.resistance;
            in dischargingResistance : ISQ::ResistanceValue = loadResistor.resistance;
            in supplyVoltage : ISQ::VoltageValue = source.suppliedVoltage;
            in targetVoltage : ISQ::VoltageValue = capacitor.maxVoltage * 0.95;
            in operationTimeStep : ISQ::TimeValue = 0.001[SI::s];
            out finalVoltage : ISQ::VoltageValue;
            out totalEnergyStored : ISQ::EnergyValue;
        }
    }
    
    part capacitorSystem : CapacitorEnergyStorageSystem {
        perform action storeAndReleaseEnergy[*] ordered references manageEnergy;
        
        part :>> source : VoltageSource {
            attribute :>> suppliedVoltage = 12.0[SI::V];
        }
        
        part :>> chargingResistor : ChargingResistor {
            attribute :>> resistance = 1000.0[SI::Ω];
        }
        
        part :>> capacitor : Capacitor {
            attribute :>> capacitance = 100.0e-6[SI::F];
            attribute :>> maxVoltage = 16.0[SI::V];
            attribute :>> currentVoltage = 0.0[SI::V];
            attribute :>> storedCharge = 0.0[SI::C];
            attribute :>> storedEnergy = 0.0[SI::J];
        }
        
        part :>> loadResistor : LoadResistor {
            attribute :>> resistance = 2200.0[SI::Ω];
        }
    }
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import 'Capacitor Energy Storage System'::*;

    action orchestrator {
        attribute testSourceVoltage : ISQ::VoltageValue;
        attribute testSeriesResistance : ISQ::ResistanceValue;
        attribute testCapacitance : ISQ::CapacitanceValue;
        attribute testInitialVoltage : ISQ::VoltageValue;
        attribute testTimeStep : ISQ::TimeValue;
        action chargeStepProbe : ChargeCapacitor {
            in sourceVoltage = testSourceVoltage;
            in seriesResistance = testSeriesResistance;
            in capacitance = testCapacitance;
            in initialVoltage = testInitialVoltage;
            in timeStep = testTimeStep;
        }
        first chargeStepProbe;
    }
}
