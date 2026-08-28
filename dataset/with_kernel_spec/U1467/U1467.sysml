package PiezoelectricEnergyHarvestingSystem {
    private import SI::*;
    private import ISQ::*;
    private import ScalarValues::*;

    item def VibrationSignal {
        attribute frequency :> ISQ::frequency;
        attribute amplitude : Real;
    }
    item def ACPower {
        attribute voltage :> ISQ::voltage;
        attribute current :> ISQ::electricCurrent;
        attribute frequency :> ISQ::frequency;
    }
    item def DCPower {
        attribute voltage :> ISQ::voltage;
        attribute current :> ISQ::electricCurrent;
    }
    item def RegulatedPower {
        attribute voltage :> ISQ::voltage = 5 [V];
        attribute current :> ISQ::electricCurrent;
    }

    port def VibrationPort {
        out item vibration : VibrationSignal;
    }
    port def ACPort {
        out item acPower : ACPower;
    }
    port def DCPort {
        out item dcPower : DCPower;
    }
    port def RegulatedPort {
        out item regulatedPower : RegulatedPower;
    }

    part def PiezoelectricCrystal {
        port vibrationIn : ~VibrationPort;
        port acOut : ACPort;
        attribute minFreq :> ISQ::frequency = 20 [Hz];
        attribute maxFreq :> ISQ::frequency = 500 [Hz];
    }
    part def BridgeRectifier {
        port acIn : ~ACPort;
        port dcOut : DCPort;
    }
    part def VoltageRegulator {
        port dcIn : ~DCPort;
        port regOut : RegulatedPort;
        attribute targetVoltage :> ISQ::voltage = 5 [V];
    }
    part def StorageCapacitor {
        port chargeIn : ~DCPort;
        port supplyOut : DCPort;
        attribute storedEnergy :> ISQ::energy = 0 [J];
        attribute maxEnergy :> ISQ::energy = 10 [J];
        attribute chargeThreshold :> ISQ::energy = 5 [J];
        attribute lowThreshold :> ISQ::energy = 1 [J];
    }
    part def LoadDevice {
        port powerIn : ~RegulatedPort;
        attribute maxPower :> ISQ::power = 0.5 [W];
        attribute connected : Boolean;
    }

    action def DetectVibration {
        out vibrationDetected : Boolean;
        out vibration : VibrationSignal;
    }
    action def GenerateAC {
        in vibration : VibrationSignal;
        out acPower : ACPower;
    }
    action def RectifyAC {
        in acPower : ACPower;
        out dcPower : DCPower;
    }
    action def StoreEnergy {
        in dcPower : DCPower;
        out energyStored : Boolean;
    }
    action def RegulateVoltage {
        in dcPower : DCPower;
        out regulatedPower : RegulatedPower;
    }
    action def DeliverPower {
        in regulatedPower : RegulatedPower;
        out loadPower : RegulatedPower;
    }

    state def HarvestingStateMachine {
        attribute vibrationActive : Boolean;
        attribute energySufficient : Boolean;
        attribute energyLow : Boolean;
        attribute loadConnected : Boolean;

        state idle;
        state harvesting;
        state delivering;
        state recharging;

        transition t1 first idle then harvesting guard vibrationActive;
        transition t2 first harvesting then delivering guard energySufficient;
        transition t3 first harvesting then idle guard not vibrationActive;
        transition t4 first delivering then recharging guard energyLow;
        transition t5 first delivering then idle guard not loadConnected;
        transition t6 first recharging then delivering guard energySufficient;
        transition t7 first recharging then idle guard not vibrationActive;
    }

    requirement def HarvestVibrationEnergy {
        text "The system shall harvest energy from vibrations in the 20 Hz to 500 Hz frequency range.";
        attribute minFreq :> ISQ::frequency = 20 [Hz];
        attribute maxFreq :> ISQ::frequency = 500 [Hz];
    }
    requirement def ProvideStableOutput {
        text "The system shall provide a stable 5V DC output.";
        attribute outputVoltage :> ISQ::voltage = 5 [V];
        attribute maxLoadPower :> ISQ::power = 0.5 [W];
    }
    requirement def ContinuousPowerSupply {
        text "The system shall provide continuous power using a storage capacitor with up to 10 J capacity.";
        attribute capacitorEnergy :> ISQ::energy = 10 [J];
    }

    part def PiezoelectricEnergyHarvester {
        port mechPort : VibrationPort;
        port loadPort : RegulatedPort;

        attribute operatingFreqMin :> ISQ::frequency = 20 [Hz];
        attribute operatingFreqMax :> ISQ::frequency = 500 [Hz];
        attribute outputVoltage :> ISQ::voltage = 5 [V];
        attribute maxLoadPower :> ISQ::power = 0.5 [W];

        part crystal : PiezoelectricCrystal;
        part rectifier : BridgeRectifier;
        part regulator : VoltageRegulator;
        part capacitor : StorageCapacitor;
        part load : LoadDevice;

        connect mechPort to crystal.vibrationIn;
        connect crystal.acOut to rectifier.acIn;
        connect rectifier.dcOut to capacitor.chargeIn;
        connect capacitor.supplyOut to regulator.dcIn;
        connect regulator.regOut to load.powerIn;
        connect regulator.regOut to loadPort;

        state harvestingBehavior : HarvestingStateMachine;

        action harvestEnergy {
            first start;
            then action detect : DetectVibration {
                out vibrationDetected;
                out vibration;
            }
            then action generate : GenerateAC {
                in vibration = detect.vibration;
                out acPower;
            }
            then action rectify : RectifyAC {
                in acPower = generate.acPower;
                out dcPower;
            }
            then action store : StoreEnergy {
                in dcPower = rectify.dcPower;
                out energyStored;
            }
            then action regulate : RegulateVoltage {
                in dcPower = rectify.dcPower;
                out regulatedPower;
            }
            then action deliver : DeliverPower {
                in regulatedPower = regulate.regulatedPower;
                out loadPower;
            }
            then done;
        }

        satisfy req1 : HarvestVibrationEnergy;
        satisfy req2 : ProvideStableOutput;
        satisfy req3 : ContinuousPowerSupply;
    }
}
