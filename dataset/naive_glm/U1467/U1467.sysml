package PiezoelectricEnergyHarvestingSystem {
    import ScalarValues::*;
    import ISQ::*;

    // ---- Value types with units ----
    value def Frequency :> Real { unit "Hz"; }
    value def Voltage :> Real { unit "V"; }
    value def Current :> Real { unit "A"; }
    value def Power :> Real { unit "W"; }
    value def Capacitance :> Real { unit "F"; }
    value def Energy :> Real { unit "J"; }
    value def Stress :> Real { unit "Pa"; }
    value def Efficiency :> Real { unit "1"; }

    // ---- Item types ----
    item def AC_Power {
        attribute voltage : Voltage;
        attribute frequency : Frequency;
        attribute current : Current;
    }

    item def DC_Power {
        attribute voltage : Voltage;
        attribute current : Current;
    }

    item def VibrationSignal {
        attribute stress : Stress;
        attribute frequency : Frequency;
    }

    // ---- Ports ----
    port def MechanicalPort {
        in vibration : VibrationSignal;
    }

    port def ACPort {
        out acPower : AC_Power;
        in acPower : AC_Power;
    }

    port def DCPort {
        out dcPower : DC_Power;
        in dcPower : DC_Power;
    }

    port def ControlPort {
        out energyLevel : Real;
        out loadConnected : Boolean;
        out vibrationDetected : Boolean;
    }

    // ---- Piezoelectric Crystal ----
    part def PiezoelectricCrystal {
        port mechanicalIn : MechanicalPort;
        port acOut : ACPort;

        attribute resonantFrequency : Frequency = 200 [Hz];
        attribute openCircuitVoltage : Voltage = 3.0 [V];
        attribute couplingCoefficient : Real = 0.35;

        action def generateAC {
            in vibration : VibrationSignal;
            out ac : AC_Power;
        }

        perform generateAC {
            in vibration = mechanicalIn.vibration;
            out ac = acOut.acPower;
        }
    }

    // ---- Bridge Rectifier ----
    part def BridgeRectifier {
        port acIn : ACPort;
        port dcOut : DCPort;

        attribute forwardVoltageDrop : Voltage = 0.7 [V];
        attribute conversionEfficiency : Efficiency = 0.9;

        action def rectify {
            in ac : AC_Power;
            out dc : DC_Power;
        }

        perform rectify {
            in ac = acIn.acPower;
            out dc = dcOut.dcPower;
        }
    }

    // ---- Voltage Regulator ----
    part def VoltageRegulator {
        port dcIn : DCPort;
        port dcOut : DCPort;

        attribute regulatedOutputVoltage : Voltage = 5.0 [V];
        attribute maxOutputPower : Power = 0.5 [W];
        attribute dropoutVoltage : Voltage = 0.5 [V];
        attribute lineRegulation : Real = 0.01;

        action def regulate {
            in dcIn : DC_Power;
            out dcOut : DC_Power;
        }

        perform regulate {
            in dcIn = dcIn.dcPower;
            out dcOut = dcOut.dcPower;
        }
    }

    // ---- Storage Capacitor ----
    part def StorageCapacitor {
        port chargeIn : DCPort;
        port dischargeOut : DCPort;

        attribute capacitance : Capacitance = 0.01 [F];
        attribute storedEnergy : Energy = 0 [J];
        attribute maxEnergy : Energy = 0.125 [J];
        attribute chargeThresholdFraction : Real = 0.8;
        attribute lowEnergyThresholdFraction : Real = 0.2;
        attribute chargeThreshold : Energy = 0.1 [J];
        attribute lowEnergyThreshold : Energy = 0.025 [J];

        action def charge {
            in dc : DC_Power;
            update storedEnergy;
        }

        action def discharge {
            out dc : DC_Power;
            update storedEnergy;
        }

        perform charge {
            in dc = chargeIn.dcPower;
        }

        perform discharge {
            out dc = dischargeOut.dcPower;
        }
    }

    // ---- Load Device ----
    part def LoadDevice {
        port powerIn : DCPort;

        attribute nominalPowerConsumption : Power = 0.5 [W];
        attribute connected : Boolean = true;
        attribute operatingVoltage : Voltage = 5.0 [V];
    }

    // ---- Controller ----
    part def Controller {
        port monitorIn : DCPort;
        port controlOut : ControlPort;

        attribute vibrationDetected : Boolean = false;
        attribute loadConnected : Boolean = true;
        attribute energyLevel : Real = 0.0;
        attribute chargeThreshold : Real = 0.8;
        attribute lowEnergyThreshold : Real = 0.2;

        state def ControllerStates {
            entry;

            state idle {
                entry;
                transition idle_to_harvesting
                    if vibrationDetected and energyLevel < chargeThreshold
                    then harvesting;
            }

            state harvesting {
                entry;
                transition harvesting_to_delivering
                    if energyLevel >= chargeThreshold and loadConnected
                    then delivering;
                transition harvesting_to_idle
                    if not vibrationDetected and energyLevel < lowEnergyThreshold
                    then idle;
            }

            state delivering {
                entry;
                transition delivering_to_harvesting
                    if energyLevel < lowEnergyThreshold or not loadConnected
                    then harvesting;
                transition delivering_to_idle
                    if not vibrationDetected and not loadConnected and energyLevel < lowEnergyThreshold
                    then idle;
            }
        }

        exhibit ControllerStates;
    }

    // ---- Top-level System ----
    part def PiezoelectricEnergyHarvester {
        port vibrationInput : MechanicalPort;
        port loadOutput : DCPort;

        attribute operatingFrequencyMin : Frequency = 20 [Hz];
        attribute operatingFrequencyMax : Frequency = 500 [Hz];
        attribute maxLoadPower : Power = 0.5 [W];
        attribute regulatedOutputVoltage : Voltage = 5.0 [V];

        part crystal : PiezoelectricCrystal;
        part rectifier : BridgeRectifier;
        part regulator : VoltageRegulator;
        part capacitor : StorageCapacitor;
        part load : LoadDevice;
        part controller : Controller;

        connection mechanicalConnection connect vibrationInput to crystal.mechanicalIn;
        connection acConnection connect crystal.acOut to rectifier.acIn;
        connection rectifierToCapacitor connect rectifier.dcOut to capacitor.chargeIn;
        connection rectifierToRegulator connect rectifier.dcOut to regulator.dcIn;
        connection capacitorToRegulator connect capacitor.dischargeOut to regulator.dcIn;
        connection regulatorToLoad connect regulator.dcOut to load.powerIn;
        connection regulatorToOutput connect regulator.dcOut to loadOutput;
        connection monitorConnection connect regulator.dcOut to controller.monitorIn;
    }

    // ---- Requirements ----
    requirement def HarvestVibrationEnergy {
        subject harvester : PiezoelectricEnergyHarvester;
        requirement :>> The harvester shall capture energy from ambient mechanical vibrations in the 20 Hz to 500 Hz frequency range;
    }

    requirement def ConvertToStableDC {
        subject harvester : PiezoelectricEnergyHarvester;
        requirement :>> The harvester shall convert raw AC power from the piezoelectric crystal into stable 5 V DC power through a bridge rectifier and voltage regulator;
    }

    requirement def StoreEnergyForContinuity {
        subject harvester : PiezoelectricEnergyHarvester;
        requirement :>> The harvester shall include a storage capacitor that accumulates harvested energy to provide continuous power during intermittent vibrations;
    }

    requirement def PowerLoadDevice {
        subject harvester : PiezoelectricEnergyHarvester;
        requirement :>> The harvester shall deliver up to 0.5 W of regulated 5 V power to a connected load device;
    }

    requirement def IntelligentStateOperation {
        subject harvester : PiezoelectricEnergyHarvester;
        requirement :>> The harvester shall operate through idle, harvesting, and delivering states based on vibration detection, stored energy level, and load connection status;
    }

    requirement def LowEnergyRecovery {
        subject harvester : PiezoelectricEnergyHarvester;
        requirement :>> When stored energy falls below the low-energy threshold or the load is disconnected, the harvester shall prioritize recharging or return to idle mode;
    }

    requirement def VibrationFrequencyRange {
        subject harvester : PiezoelectricEnergyHarvester;
        requirement :>> The harvester shall effectively operate with ambient vibrations in the 20 Hz to 500 Hz frequency range;
    }

    // ---- Requirement satisfaction ----
    satisfaction harvestReq : HarvestVibrationEnergy {
        subject = PiezoelectricEnergyHarvester;
    }

    satisfaction convertReq : ConvertToStableDC {
        subject = PiezoelectricEnergyHarvester;
    }

    satisfaction storeReq : StoreEnergyForContinuity {
        subject = PiezoelectricEnergyHarvester;
    }

    satisfaction powerReq : PowerLoadDevice {
        subject = PiezoelectricEnergyHarvester;
    }

    satisfaction stateReq : IntelligentStateOperation {
        subject = PiezoelectricEnergyHarvester;
    }

    satisfaction recoveryReq : LowEnergyRecovery {
        subject = PiezoelectricEnergyHarvester;
    }

    satisfaction freqReq : VibrationFrequencyRange {
        subject = PiezoelectricEnergyHarvester;
    }
}
