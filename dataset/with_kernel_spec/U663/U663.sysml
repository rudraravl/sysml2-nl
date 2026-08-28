package ElectronMultiplierSystem {
    private import SI::*;
    private import ISQ::*;
    private import ScalarValues::*;

    attribute def HighVoltage :> ISQ::electricPotential;
    attribute def SignalCurrent :> ISQ::electricCurrent;
    attribute def SignalVoltage :> ISQ::electricPotential;
    attribute def VacuumPressure :> ISQ::pressure;
    attribute def Impedance :> ISQ::resistance;

    item def Electron;

    port def ElectronInPort {
        in electron : Electron[*];
    }

    port def ElectronOutPort {
        out electron : Electron[*];
    }

    port def HVPort {
        out voltage : HighVoltage;
    }

    port def HVInputPort {
        in voltage : HighVoltage;
    }

    port def SignalOutPort {
        out current : SignalCurrent;
        out voltage : SignalVoltage;
    }

    part def HighVacuumChamber {
        attribute pressure : VacuumPressure;
    }

    part def HighVoltagePowerSupply {
        attribute outputVoltage : HighVoltage;
        port hvOut : HVPort;
    }

    part def Dynode {
        attribute index : Integer;
        attribute secondaryEmissionYield : Real;
        port electronIn : ElectronInPort;
        port electronOut : ElectronOutPort;
        port hvIn : HVInputPort;

        action amplify {
            in incoming : Electron[*];
            out outgoing : Electron[*];
        }

        state dynodeState {
            entry; then Idle;
            state Idle;
            accept e : Electron via electronIn
                then Emitting;
            state Emitting {
                do action amplify;
            }
            then Idle;
        }
    }

    part def Anode {
        port pulseIn : ElectronInPort;
        port signalOut : SignalOutPort;
        attribute loadImpedance : Impedance;
        attribute pulseCount : Integer;

        action convert {
            in pulse : Electron[*];
            out current : SignalCurrent;
            out voltage : SignalVoltage;
        }

        state anodeState {
            entry; then Idle;
            state Idle;
            accept e : Electron via pulseIn
                then Collecting;
            state Collecting {
                do action convert;
            }
            then Idle;
        }
    }

    part def ElectronMultiplier {
        port detectorIn : ElectronInPort;
        port signalOut : SignalOutPort;

        part chamber : HighVacuumChamber;
        part powerSupply : HighVoltagePowerSupply;

        part d1 : Dynode;
        part d2 : Dynode;
        part d3 : Dynode;
        part d4 : Dynode;
        part d5 : Dynode;
        part d6 : Dynode;
        part d7 : Dynode;
        part d8 : Dynode;
        part d9 : Dynode;
        part d10 : Dynode;

        part anode : Anode;

        connect detectorIn to d1.electronIn;
        connect d1.electronOut to d2.electronIn;
        connect d2.electronOut to d3.electronIn;
        connect d3.electronOut to d4.electronIn;
        connect d4.electronOut to d5.electronIn;
        connect d5.electronOut to d6.electronIn;
        connect d6.electronOut to d7.electronIn;
        connect d7.electronOut to d8.electronIn;
        connect d8.electronOut to d9.electronIn;
        connect d9.electronOut to d10.electronIn;
        connect d10.electronOut to anode.pulseIn;

        connect powerSupply.hvOut to d1.hvIn;
        connect powerSupply.hvOut to d2.hvIn;
        connect powerSupply.hvOut to d3.hvIn;
        connect powerSupply.hvOut to d4.hvIn;
        connect powerSupply.hvOut to d5.hvIn;
        connect powerSupply.hvOut to d6.hvIn;
        connect powerSupply.hvOut to d7.hvIn;
        connect powerSupply.hvOut to d8.hvIn;
        connect powerSupply.hvOut to d9.hvIn;
        connect powerSupply.hvOut to d10.hvIn;

        connect anode.signalOut to signalOut;
    }

    state def DetectionProcess {
        part multiplier : ElectronMultiplier;

        entry assign multiplier.powerSupply.outputVoltage := 2000 [V];
        then state Idle;
        accept e : Electron via multiplier.detectorIn
            then Amplifying;
        state Amplifying;
        then Collecting;
        state Collecting;
        then Idle;
    }

    requirement def AmplificationRequirement {
        doc /* The electron multiplier must amplify a single electron into a pulse of at least 1,000,000 electrons. */
        subject em : ElectronMultiplier;
        attribute minElectronCount : Integer = 1000000;
        require constraint { em.anode.pulseCount >= minElectronCount }
    }

    requirement def VacuumIntegrityRequirement {
        doc /* The system must maintain a high vacuum for electrons to travel freely without colliding with air molecules. */
        subject em : ElectronMultiplier;
        attribute maxPressure : VacuumPressure = 1e-5 [Pa];
        require constraint { em.chamber.pressure <= maxPressure }
    }

    requirement def GainRequirement {
        doc /* The total gain of the multiplier must be at least 1e6. */
        subject em : ElectronMultiplier;
        attribute requiredGain : Real = 1.0e6;
        attribute actualGain : Real;
        require constraint { actualGain >= requiredGain }
    }

    requirement def HighVoltageStabilityRequirement {
        doc /* The high-voltage power supply must provide a stable output to ensure consistent electric field between dynodes. */
        subject em : ElectronMultiplier;
        attribute nominalVoltage : HighVoltage = 2000 [V];
        attribute tolerance : Real = 0.01;
        require constraint { em.powerSupply.outputVoltage >= nominalVoltage * (1 - tolerance) }
        require constraint { em.powerSupply.outputVoltage <= nominalVoltage * (1 + tolerance) }
    }

    analysis def GainAnalysis {
        subject multiplier : ElectronMultiplier;
        requirement gainRequirement : GainRequirement;

        objective {
            doc /* Calculate the total gain of the electron multiplier across all ten dynode stages. */
        }

        return actualGain : Real;
    }

    analysis def VacuumAnalysis {
        subject multiplier : ElectronMultiplier;
        requirement vacuumRequirement : VacuumIntegrityRequirement;

        objective {
            doc /* Verify that the vacuum chamber pressure meets the required threshold for electron transport. */
        }

        return measuredPressure : VacuumPressure;
    }
}
