package PiezoelectricPowerSystem {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    item def MechanicalVibration {
        attribute frequency : Frequency;
        attribute acceleration : Acceleration;
        attribute displacement : Length;
        attribute force : Force;
    }

    item def AlternatingElectricalPower {
        attribute voltageRms : ElectricPotential;
        attribute currentRms : ElectricCurrent;
        attribute frequency : Frequency;
        attribute power : Power;
    }

    item def DirectElectricalPower {
        attribute voltage : ElectricPotential;
        attribute current : ElectricCurrent;
        attribute power : Power;
    }

    item def StoredElectricalEnergy {
        attribute energy : Energy;
        attribute stateOfCharge : Real;
    }

    item def PowerStatus {
        attribute availablePower : Power;
        attribute storageVoltage : ElectricPotential;
        attribute loadEnabled : Boolean;
    }

    port def MechanicalInputPort {
        in item vibration : MechanicalVibration;
    }

    port def AcPowerPort {
        out item acPower : AlternatingElectricalPower;
    }

    port def DcPowerPort {
        out item dcPower : DirectElectricalPower;
    }

    port def DcInputPort {
        in item dcPower : DirectElectricalPower;
    }

    port def StatusPort {
        out item status : PowerStatus;
    }

    part def PiezoelectricTransducer {
        port mechanicalIn : MechanicalInputPort;
        port electricalOut : AcPowerPort;

        attribute piezoMaterial : String = "PZT-5H";
        attribute resonantFrequency : Frequency = 120.0 [Hz];
        attribute capacitance : Capacitance = 470.0 [nF];
        attribute openCircuitVoltageLimit : ElectricPotential = 42.0 [V];
        attribute conversionEfficiency : Real = 0.32;

        action convertMechanicalStrainToCharge {
            in item vibration : MechanicalVibration;
            out item generatedPower : AlternatingElectricalPower;
        }
    }

    part def BridgeRectifier {
        port acIn : AcPowerPort;
        port dcOut : DcPowerPort;

        attribute diodeForwardDrop : ElectricPotential = 0.28 [V];
        attribute maximumInputVoltage : ElectricPotential = 50.0 [V];
        attribute rectificationEfficiency : Real = 0.88;

        action rectifyAcPower {
            in item acPower : AlternatingElectricalPower;
            out item pulsedDcPower : DirectElectricalPower;
        }
    }

    part def EnergyStorageModule {
        port chargingIn : DcInputPort;
        port regulatedOut : DcPowerPort;
        port statusOut : StatusPort;

        attribute storageCapacitance : Capacitance = 10.0 [mF];
        attribute minimumOperatingVoltage : ElectricPotential = 2.7 [V];
        attribute maximumStorageVoltage : ElectricPotential = 5.5 [V];
        attribute storedEnergy : Energy = 0.0 [J];
        attribute stateOfCharge : Real = 0.0;

        action storeEnergy {
            in item inputPower : DirectElectricalPower;
            out item stored : StoredElectricalEnergy;
        }

        action releaseEnergy {
            in item demandPower : DirectElectricalPower;
            out item suppliedPower : DirectElectricalPower;
        }
    }

    part def DcDcRegulator {
        port unregulatedIn : DcInputPort;
        port regulatedOut : DcPowerPort;

        attribute outputVoltageSetpoint : ElectricPotential = 3.3 [V];
        attribute minimumStartupVoltage : ElectricPotential = 2.7 [V];
        attribute peakEfficiency : Real = 0.91;
        attribute maximumOutputCurrent : ElectricCurrent = 80.0 [mA];

        action regulateVoltage {
            in item variableDcPower : DirectElectricalPower;
            out item regulatedDcPower : DirectElectricalPower;
        }
    }

    part def WirelessSensorLoad {
        port powerIn : DcInputPort;
        port statusIn : StatusPort;

        attribute sleepPower : Power = 25.0 [uW];
        attribute samplingPower : Power = 8.0 [mW];
        attribute transmitPower : Power = 60.0 [mW];
        attribute nominalSupplyVoltage : ElectricPotential = 3.3 [V];

        action measureEnvironment {
            out attribute temperature : Real;
            out attribute vibrationLevel : Real;
        }

        action transmitMeasurement {
            in attribute temperature : Real;
            in attribute vibrationLevel : Real;
        }
    }

    action def HarvestPiezoelectricEnergy {
        in item ambientVibration : MechanicalVibration;
        out item usableElectricalPower : DirectElectricalPower;

        first start;
        then convert;
        then rectify;
        then store;
        then regulate;
        then deliver;
        then done;

        action start;
        action convert;
        action rectify;
        action store;
        action regulate;
        action deliver;
        action done;
    }

    state def HarvesterOperatingState {
        state Dormant;
        state Harvesting;
        state ChargingStorage;
        state SupplyingLoad;
        state OverVoltageProtection;
        state LowEnergyShutdown;

        transition initial then Dormant;

        transition Dormant_to_Harvesting
            first Dormant
            then Harvesting;

        transition Harvesting_to_ChargingStorage
            first Harvesting
            then ChargingStorage;

        transition ChargingStorage_to_SupplyingLoad
            first ChargingStorage
            then SupplyingLoad;

        transition SupplyingLoad_to_LowEnergyShutdown
            first SupplyingLoad
            then LowEnergyShutdown;

        transition ChargingStorage_to_OverVoltageProtection
            first ChargingStorage
            then OverVoltageProtection;

        transition OverVoltageProtection_to_Harvesting
            first OverVoltageProtection
            then Harvesting;

        transition LowEnergyShutdown_to_Harvesting
            first LowEnergyShutdown
            then Harvesting;
    }

    part def PiezoelectricEnergyHarvesterSystem {
        doc /* Primary high-level function: convert ambient mechanical vibration into regulated low-power electrical energy for a wireless sensor load without requiring a battery as the primary energy source. */

        port vibrationInput : MechanicalInputPort;
        port regulatedPowerOutput : DcPowerPort;
        port systemStatus : StatusPort;

        part transducer : PiezoelectricTransducer;
        part rectifier : BridgeRectifier;
        part storage : EnergyStorageModule;
        part regulator : DcDcRegulator;
        part sensorLoad : WirelessSensorLoad;

        perform action energyHarvesting : HarvestPiezoelectricEnergy;

        exhibit state operatingState : HarvesterOperatingState;

        connect vibrationInput to transducer.mechanicalIn;
        connect transducer.electricalOut to rectifier.acIn;
        connect rectifier.dcOut to storage.chargingIn;
        connect storage.regulatedOut to regulator.unregulatedIn;
        connect regulator.regulatedOut to regulatedPowerOutput;
        connect regulator.regulatedOut to sensorLoad.powerIn;
        connect storage.statusOut to systemStatus;
        connect storage.statusOut to sensorLoad.statusIn;

        attribute requiredStartupAcceleration : Acceleration = 0.35 [m / s^2];
        attribute targetOutputVoltage : ElectricPotential = 3.3 [V];
        attribute minimumContinuousOutputPower : Power = 2.0 [mW];
        attribute burstOutputPower : Power = 50.0 [mW];
        attribute expectedServiceLife : Time = 10.0 [yr];
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The system shall harvest ambient vibration through a piezoelectric transducer and provide regulated direct-current electrical power to a low-power sensor load. */
        subject harvester : PiezoelectricEnergyHarvesterSystem;
    }

    requirement def StartupRequirement {
        doc /* The harvester shall begin storing usable energy when vibration acceleration is at least 0.35 m/s^2 near the transducer resonant frequency. */
        subject harvester : PiezoelectricEnergyHarvesterSystem;
        require constraint {
            harvester.requiredStartupAcceleration <= 0.35 [m / s^2]
        }
    }

    requirement def OutputVoltageRequirement {
        doc /* The regulated power output shall maintain a nominal 3.3 V DC supply for the sensor load. */
        subject harvester : PiezoelectricEnergyHarvesterSystem;
        require constraint {
            harvester.targetOutputVoltage == 3.3 [V]
        }
    }

    requirement def StorageProtectionRequirement {
        doc /* The energy storage module shall prevent storage voltage from exceeding 5.5 V. */
        subject storage : EnergyStorageModule;
        require constraint {
            storage.maximumStorageVoltage <= 5.5 [V]
        }
    }

    requirement def PowerAvailabilityRequirement {
        doc /* The system shall provide at least 2 mW continuous regulated output power under qualified vibration input. */
        subject harvester : PiezoelectricEnergyHarvesterSystem;
        require constraint {
            harvester.minimumContinuousOutputPower >= 2.0 [mW]
        }
    }

    requirement def BurstLoadRequirement {
        doc /* The system shall support short sensor transmission bursts up to 50 mW using stored piezoelectric energy. */
        subject harvester : PiezoelectricEnergyHarvesterSystem;
        require constraint {
            harvester.burstOutputPower >= 50.0 [mW]
        }
    }

    satisfy PrimaryFunctionRequirement by PiezoelectricEnergyHarvesterSystem;
    satisfy StartupRequirement by PiezoelectricEnergyHarvesterSystem;
    satisfy OutputVoltageRequirement by DcDcRegulator;
    satisfy StorageProtectionRequirement by EnergyStorageModule;
    satisfy PowerAvailabilityRequirement by PiezoelectricEnergyHarvesterSystem;
    satisfy BurstLoadRequirement by EnergyStorageModule;
}