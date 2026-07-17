package PiezoelectricEnergyHarvestingSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    
    attribute def StrainValue :> Real;
    attribute def ChargeValue :> Real;
    attribute def PiezoelectricCoefficientValue :> Real;
    
    item def MechanicalVibration {
        attribute frequency : FrequencyValue;
        attribute amplitude : LengthValue;
        attribute force : ForceValue;
    }
    
    item def ElectricalEnergy {
        attribute voltage : ElectricPotentialValue;
        attribute current : ElectricCurrentValue;
        attribute power : PowerValue;
    }
    
    port def MechanicalInputPort {
        in item vibration : MechanicalVibration;
    }
    
    port def ElectricalOutputPort {
        out item energy : ElectricalEnergy;
    }
    
    port def PowerDeliveryPort {
        inout attribute voltage : ElectricPotentialValue;
        inout attribute current : ElectricCurrentValue;
    }
    
    part def PiezoelectricCrystal {
        doc /* Converts mechanical strain into electrical charge through the piezoelectric effect. */
        
        attribute piezoCoefficient : PiezoelectricCoefficientValue = 3.74e-10;
        attribute crystalArea : AreaValue;
        attribute crystalThickness : LengthValue;
        attribute internalCapacitance : CapacitanceValue;
        
        port mechanicalInput : MechanicalInputPort;
        port electricalOutput : ElectricalOutputPort;
        
        perform action convertMechanicalToElectrical : PiezoelectricConversion;
    }
    
    part def BridgeRectifier {
        doc /* Converts AC voltage from piezoelectric crystal to DC voltage. */
        
        attribute efficiency : Real = 0.92;
        attribute forwardVoltageDrop : ElectricPotentialValue = 0.7 [V];
        
        port acInput : ElectricalOutputPort;
        port dcOutput : ElectricalOutputPort;
        
        perform action rectifyVoltage : ACToDCConversion;
    }
    
    part def VoltageRegulator {
        doc /* Regulates output voltage to stable level for load. */
        
        attribute targetVoltage : ElectricPotentialValue = 5.0 [V];
        attribute regulationAccuracy : Real = 0.02;
        attribute maxOutputCurrent : ElectricCurrentValue = 0.5 [A];
        
        port input : ElectricalOutputPort;
        port output : PowerDeliveryPort;
        
        perform action regulateVoltage : VoltageRegulation;
    }
    
    part def StorageCapacitor {
        doc /* Stores harvested electrical energy for continuous power delivery. */
        
        attribute capacitance : CapacitanceValue = 1000.0e-6 [F];
        attribute maxVoltage : ElectricPotentialValue = 10.0 [V];
        attribute storedCharge : ChargeValue;
        attribute energyStored : EnergyValue;
        
        port chargingPort : PowerDeliveryPort;
        port dischargingPort : PowerDeliveryPort;
        
        perform action manageEnergy : EnergyStorageManagement;
    }
    
    part def LoadDevice {
        doc /* Represents the electrical load powered by the harvesting system. */
        
        attribute operatingVoltage : ElectricPotentialValue = 5.0 [V];
        attribute powerConsumption : PowerValue = 0.5 [W];
        attribute operatingCurrent : ElectricCurrentValue;
        
        port powerInput : PowerDeliveryPort;
    }
    
    action def PiezoelectricConversion {
        in vibration : MechanicalVibration;
        in piezoCoeff : PiezoelectricCoefficientValue;
        in area : AreaValue;
        out generatedVoltage : ElectricPotentialValue;
        out generatedCurrent : ElectricCurrentValue;
    }
    
    action def ACToDCConversion {
        in acVoltage : ElectricPotentialValue;
        in acCurrent : ElectricCurrentValue;
        in efficiency : Real;
        out dcVoltage : ElectricPotentialValue;
        out dcCurrent : ElectricCurrentValue;
    }
    
    action def VoltageRegulation {
        in inputVoltage : ElectricPotentialValue;
        in targetVoltage : ElectricPotentialValue;
        out regulatedVoltage : ElectricPotentialValue;
        out regulatedCurrent : ElectricCurrentValue;
    }
    
    action def EnergyStorageManagement {
        in chargingVoltage : ElectricPotentialValue;
        in chargingCurrent : ElectricCurrentValue;
        in capacitance : CapacitanceValue;
        out storedEnergy : EnergyValue;
    }
    
    action def HarvestingCycle {
        in vibrationInput : MechanicalVibration;
        in piezoCoeffInput : PiezoelectricCoefficientValue;
        in areaInput : AreaValue;
        in efficiencyInput : Real;
        in targetVoltageInput : ElectricPotentialValue;
        in capacitanceInput : CapacitanceValue;
        out finalStoredEnergy : EnergyValue;
        
        first start;
        then merge continuousHarvesting;
        
        action captureVibration : PiezoelectricConversion {
            in vibration = vibrationInput;
            in piezoCoeff = piezoCoeffInput;
            in area = areaInput;
            out generatedVoltage;
            out generatedCurrent;
        }
        
        then convertToDC : ACToDCConversion {
            in acVoltage = captureVibration.generatedVoltage;
            in acCurrent = captureVibration.generatedCurrent;
            in efficiency = efficiencyInput;
            out dcVoltage;
            out dcCurrent;
        }
        
        then regulate : VoltageRegulation {
            in inputVoltage = convertToDC.dcVoltage;
            in targetVoltage = targetVoltageInput;
            out regulatedVoltage;
            out regulatedCurrent;
        }
        
        then storeEnergy : EnergyStorageManagement {
            in chargingVoltage = regulate.regulatedVoltage;
            in chargingCurrent = regulate.regulatedCurrent;
            in capacitance = capacitanceInput;
            out storedEnergy;
        }
        
        then decide;
            if storeEnergy.storedEnergy < 0.025 [J] then continuousHarvesting;
            if storeEnergy.storedEnergy >= 0.025 [J] then deliverPower;
        
        action deliverPower {
            out finalStoredEnergy = storeEnergy.storedEnergy;
        }
        
        then continuousHarvesting;
        then done;
    }
    
    state def HarvesterOperationalStates {
        entry; then idle;
        
        state idle {
            doc /* System is ready but not actively harvesting. */
        }
        
        transition idle_to_harvesting
            first idle
            accept when vibrationDetected
            then harvesting;
        
        state harvesting {
            doc /* Actively converting mechanical vibrations to electrical energy. */
            entry assign operationalMode = "Active Harvesting";
        }
        
        transition harvesting_to_storing
            first harvesting
            then storing;
        
        state storing {
            doc /* Accumulating energy in storage capacitor. */
            entry assign operationalMode = "Energy Storage";
        }
        
        transition storing_to_delivering
            first storing
            if capacitorCharge >= 0.8
            then delivering;
        
        transition storing_to_harvesting
            first storing
            if capacitorCharge < 0.8
            then harvesting;
        
        state delivering {
            doc /* Supplying regulated power to connected load. */
            entry assign operationalMode = "Power Delivery";
        }
        
        transition delivering_to_storing
            first delivering
            if capacitorCharge < 0.3
            then storing;
        
        transition delivering_to_idle
            first delivering
            if loadDisconnected
            then idle;
        
        attribute operationalMode : String;
        attribute capacitorCharge : Real;
        event vibrationDetected;
        event loadDisconnected;
    }
    
    part def PiezoelectricEnergyHarvester {
        doc /* Complete system that harvests electrical energy from mechanical vibrations 
             * using the piezoelectric effect and delivers regulated power to a load. */
        
        attribute systemEfficiency : Real;
        attribute averagePowerOutput : PowerValue;
        attribute operatingFrequencyRange : FrequencyValue[2];
        
        part crystal : PiezoelectricCrystal {
            attribute :>> crystalArea = 25.0e-4 [m^2];
            attribute :>> crystalThickness = 0.5e-3 [m];
            attribute :>> internalCapacitance = 2.2e-9 [F];
        }
        
        part rectifier : BridgeRectifier;
        
        part regulator : VoltageRegulator {
            attribute :>> targetVoltage = 5.0 [V];
            attribute :>> maxOutputCurrent = 0.5 [A];
        }
        
        part storage : StorageCapacitor {
            attribute :>> capacitance = 1000.0e-6 [F];
            attribute :>> maxVoltage = 10.0 [V];
        }
        
        part load : LoadDevice {
            attribute :>> operatingVoltage = 5.0 [V];
            attribute :>> powerConsumption = 0.5 [W];
        }
        
        connection crystalToRectifier connect 
            crystal.electricalOutput to rectifier.acInput;
        
        connection rectifierToRegulator connect 
            rectifier.dcOutput to regulator.input;
        
        connection regulatorToStorage connect 
            regulator.output to storage.chargingPort;
        
        connection storageToLoad connect 
            storage.dischargingPort to load.powerInput;
    }
    
    requirement def FunctionalRequirement;
    requirement def PerformanceRequirement;
    requirement def DesignConstraint;
    
    requirement <'REQ-PZ-001'> primaryFunction : FunctionalRequirement {
        doc /* The Piezoelectric Energy Harvesting System shall convert ambient mechanical 
             * vibrations into usable electrical energy through the piezoelectric effect and 
             * deliver regulated DC power to connected electrical loads. */
        subject harvester : PiezoelectricEnergyHarvester;
    }
    
    requirement <'REQ-PZ-002'> voltageOutput : PerformanceRequirement {
        doc /* The system shall provide a regulated output voltage of 5.0V ± 2%. */
        subject regulator : PiezoelectricEnergyHarvester::regulator;
        assert constraint {
            regulator.output.voltage >= 4.9 [V] and
            regulator.output.voltage <= 5.1 [V]
        }
    }
    
    requirement <'REQ-PZ-003'> powerDelivery : PerformanceRequirement {
        doc /* The system shall deliver a minimum continuous power of 0.5W to the load 
             * under normal operating conditions. */
        subject harvester : PiezoelectricEnergyHarvester;
        assert constraint {
            harvester.averagePowerOutput >= 0.5 [W]
        }
    }
    
    requirement <'REQ-PZ-004'> operatingFrequency : PerformanceRequirement {
        doc /* The system shall effectively harvest energy from mechanical vibrations 
             * in the frequency range of 20 Hz to 500 Hz. */
        subject harvester : PiezoelectricEnergyHarvester;
        assume constraint {
            harvester.operatingFrequencyRange[1] >= 20.0 [Hz] and
            harvester.operatingFrequencyRange[2] <= 500.0 [Hz]
        }
    }
    
    requirement <'REQ-PZ-005'> conversionEfficiency : PerformanceRequirement {
        doc /* The overall system efficiency from mechanical input to electrical output 
             * shall be at least 65%. */
        subject harvester : PiezoelectricEnergyHarvester;
        assert constraint {
            harvester.systemEfficiency >= 0.65
        }
    }
    
    requirement <'REQ-PZ-006'> energyStorage : DesignConstraint {
        doc /* The storage capacitor shall maintain sufficient energy to power the load 
             * for at least 0.5 seconds during periods without mechanical input. */
        subject storage : PiezoelectricEnergyHarvester::storage;
        subject load : PiezoelectricEnergyHarvester::load;
        assert constraint {
            storage.energyStored >= load.powerConsumption * 0.5 [s]
        }
    }
    
    part harvestingSystem : PiezoelectricEnergyHarvester {
        attribute :>> systemEfficiency = 0.68;
        attribute :>> averagePowerOutput = 0.55 [W];
        attribute :>> operatingFrequencyRange = (20.0 [Hz], 500.0 [Hz]);
    }
    
    satisfy primaryFunction by harvestingSystem;
    satisfy voltageOutput by harvestingSystem.regulator;
    satisfy powerDelivery by harvestingSystem;
    satisfy operatingFrequency by harvestingSystem;
    satisfy conversionEfficiency by harvestingSystem;
    satisfy energyStorage by harvestingSystem.storage;
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    private import PiezoelectricEnergyHarvestingSystem::*;

    part testSubject : PiezoelectricCrystal {
        exhibit state sm : HarvesterOperationalStates;
    }

    action orchestrator {
        item testVibration : MechanicalVibration {
            attribute frequency : FrequencyValue;
            attribute amplitude : LengthValue;
            attribute force : ForceValue;
        }
        attribute testPiezoCoeff : PiezoelectricCoefficientValue = 0.0;
        attribute testArea : AreaValue;
        action captureVibrationProbe : PiezoelectricConversion {
            in vibration = testVibration;
            in piezoCoeff = testPiezoCoeff;
            in area = testArea;
        }
        first captureVibrationProbe;
    }
}
