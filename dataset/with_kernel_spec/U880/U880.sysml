package SPADSystem {
    private import SI::*;
    private import ISQ::*;
    private import ScalarValues::*;

    attribute def VoltageValue :> ISQ::ElectricPotentialValue;
    attribute def CurrentValue :> ISQ::ElectricCurrentValue;
    attribute def TimeValue :> ISQ::DurationValue;
    attribute def TempValue :> ISQ::ThermodynamicTemperatureValue;

    item def Photon;
    item def ElectronHolePair;
    item def AvalancheCurrent {
        attribute magnitude : CurrentValue;
        attribute duration : TimeValue;
    }
    item def DigitalPulse {
        attribute timestamp : TimeValue;
        attribute pulseWidth : TimeValue;
        attribute logicLevel : Boolean;
    }
    item def BiasVoltage {
        attribute voltage : VoltageValue;
    }
    item def TempControl {
        attribute setpoint : TempValue;
    }

    attribute def PhotonArrival;
    attribute def AvalancheStart;
    attribute def QuenchComplete;
    attribute def ResetComplete;

    part def SPADDiode {
        in item photon : Photon;
        in item bias : BiasVoltage;
        in item temp : TempControl;
        out item avalanche : AvalancheCurrent;
        attribute breakdownVoltage : VoltageValue := 25 [V];
        attribute operatingVoltage : VoltageValue := 27 [V];
        attribute isReady : Boolean := true;
        attribute isAvalanching : Boolean := false;
        attribute darkCountRate : Integer := 100;
        attribute temperature : TempValue := 250 [K];

        action absorbPhoton {
            in p : Photon;
            out pair : ElectronHolePair;
        }
        action triggerAvalanche {
            in pair : ElectronHolePair;
            out current : AvalancheCurrent;
            assign isAvalanching := true;
            assign isReady := false;
        }
    }

    part def BiasSupply {
        out item bias : BiasVoltage;
        attribute targetVoltage : VoltageValue := 27 [V];
        attribute overvoltage : VoltageValue := 2 [V];
        action maintainBias;
    }

    part def CoolingSystem {
        out item temp : TempControl;
        attribute targetTemp : TempValue := 250 [K];
        attribute currentTemp : TempValue := 250 [K];
        action regulateTemperature;
    }

    part def PassiveQuenchingCircuit {
        in item avalanche : AvalancheCurrent;
        attribute quenchVoltage : VoltageValue := 5 [V];
        attribute resetVoltage : VoltageValue := 27 [V];
        attribute deadTime : TimeValue := 50e-9 [s];
        attribute isQuenching : Boolean := false;
        attribute isResetting : Boolean := false;

        action quenchAvalanche {
            in current : AvalancheCurrent;
            assign isQuenching := true;
        }
        action resetDiode {
            assign isResetting := true;
        }
    }

    part def DiscriminatorCircuit {
        in item pulse : AvalancheCurrent;
        out item digitalPulse : DigitalPulse;
        attribute threshold : CurrentValue := 1e-3 [A];
        attribute outputPulseWidth : TimeValue := 10e-9 [s];
        attribute detectionTime : TimeValue;

        action discriminate {
            in current : AvalancheCurrent;
            out pulse : DigitalPulse;
        }
    }

    part def SPADSystem {
        in item photonInput : Photon;
        out item digitalOutput : DigitalPulse;

        part biasSupply : BiasSupply;
        part coolingSystem : CoolingSystem;
        part spadDiode : SPADDiode;
        part quenchingCircuit : PassiveQuenchingCircuit;
        part discriminator : DiscriminatorCircuit;

        flow photonInput to spadDiode.photon;
        flow biasSupply.bias to spadDiode.bias;
        flow coolingSystem.temp to spadDiode.temp;
        flow spadDiode.avalanche to quenchingCircuit.avalanche;
        flow spadDiode.avalanche to discriminator.pulse;
        flow discriminator.digitalPulse to digitalOutput;
    }

    state def SPADOperation {
        part spadDiode : SPADDiode;
        part quenchingCircuit : PassiveQuenchingCircuit;
        part discriminator : DiscriminatorCircuit;

        entry;
        then ready;

        state ready {
            entry action {
                assign spadDiode.isReady := true;
                assign spadDiode.isAvalanching := false;
            }
        }

        transition ready_to_avalanche
            first ready
            accept PhotonArrival
            then avalanche;

        state avalanche {
            do action {
                assign spadDiode.isAvalanching := true;
                assign spadDiode.isReady := false;
            }
        }

        transition avalanche_to_quenching
            first avalanche
            accept AvalancheStart
            then quenching;

        state quenching {
            do action {
                assign quenchingCircuit.isQuenching := true;
                assign spadDiode.operatingVoltage := quenchingCircuit.quenchVoltage;
            }
        }

        transition quenching_to_resetting
            first quenching
            accept QuenchComplete
            then resetting;

        state resetting {
            do action {
                assign quenchingCircuit.isResetting := true;
                assign spadDiode.operatingVoltage := quenchingCircuit.resetVoltage;
            }
        }

        transition resetting_to_ready
            first resetting
            accept ResetComplete
            then ready;
    }

    action def DetectPhoton {
        in photon : Photon;
        out pulse : DigitalPulse;

        action absorb {
            in p : Photon;
            out pair : ElectronHolePair;
        }
        flow absorb.pair to avalanche.pair;

        action avalanche {
            in pair : ElectronHolePair;
            out current : AvalancheCurrent;
        }
        flow avalanche.current to quench.current;
        flow avalanche.current to discriminate.current;

        action quench {
            in current : AvalancheCurrent;
            out loweredVoltage : BiasVoltage;
        }
        flow quench.loweredVoltage to reset.loweredVoltage;

        action reset {
            in loweredVoltage : BiasVoltage;
            out restoredVoltage : BiasVoltage;
        }

        action discriminate {
            in current : AvalancheCurrent;
            out digitalPulse : DigitalPulse;
        }
        assign pulse := discriminate.digitalPulse;
    }

    requirement def SinglePhotonDetection {
        doc /* The system shall detect individual photons and produce a corresponding digital pulse. */
        subject spadSystem : SPADSystem;
    }

    requirement def LowDarkCount {
        doc /* The system shall maintain a dark count rate below a specified maximum. */
        subject spadSystem : SPADSystem;
        attribute maxDarkCountRate : Integer := 1000;
    }

    requirement def TimingAccuracy {
        doc /* The system shall assign a precise timestamp to each detected photon. */
        subject spadSystem : SPADSystem;
        attribute requiredJitter : TimeValue := 50e-12 [s];
    }

    requirement def DeadTimeSpec {
        doc /* The system shall quench and reset within a specified dead time. */
        subject spadSystem : SPADSystem;
        attribute maxDeadTime : TimeValue := 100e-9 [s];
    }

    requirement spadDetectsSinglePhoton : SinglePhotonDetection;
    requirement spadLowDarkCount : LowDarkCount;
    requirement spadTimingAccuracy : TimingAccuracy;
    requirement spadDeadTime : DeadTimeSpec;
}
