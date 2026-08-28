package KineticInductanceDetectorSystem {
    private import SI::*;
    private import ISQ::*;
    private import ScalarValues::*;

    item def Photon {
        attribute energy : EnergyValue;
        attribute arrivalTime : TimeValue;
    }

    item def MicrowaveSignal {
        attribute frequency : FrequencyValue;
        attribute phase : PlaneAngleValue;
        attribute amplitude : Real;
    }

    item def BasebandSignal {
        attribute phaseShift : PlaneAngleValue;
        attribute amplitudeShift : Real;
        attribute timestamp : TimeValue;
    }

    item def CalibrationData {
        attribute phaseSensitivity : Real = 1.0e-19;
        attribute amplitudeSensitivity : Real = 1.0e-18;
    }

    item def DetectionEvent {
        attribute photonEnergy : Real;
        attribute arrivalTime : TimeValue;
        attribute phaseShift : PlaneAngleValue;
        attribute amplitudeShift : Real;
    }

    port def ThermalPort {
        attribute temp : TemperatureValue;
    }

    port def MicrowavePort {
        in item probe : MicrowaveSignal;
        out item response : MicrowaveSignal;
    }

    port def DataPort {
        out item event : DetectionEvent;
    }

    port def PhotonPort {
        in item photon : Photon;
    }

    calc def CalculatePhotonEnergy {
        in phaseShift : PlaneAngleValue;
        in amplitudeShift : Real;
        in calibration : CalibrationData;
        return energy : Real = calibration.phaseSensitivity * phaseShift.num + calibration.amplitudeSensitivity * amplitudeShift;
    }

    part def CryogenicSystem {
        attribute setPointTemperature : TemperatureValue = 0.1 [K];
        attribute coolingPower : Real = 1.0e-3;
        out port coolingPort : ThermalPort;
    }

    part def SuperconductingResonator {
        attribute material : String = "Titanium Nitride";
        attribute kineticInductance : InductanceValue = 1.0e-9 [H];
        attribute resonantFrequency : FrequencyValue = 5.0e9 [Hz];
        attribute temperature : TemperatureValue;
        attribute isSuperconducting : Boolean = false;
        attribute cooperPairCount : Integer = 1000000;

        in port thermalPort : ThermalPort;
        port microwavePort : MicrowavePort;
        in port photonPort : PhotonPort;
    }

    part def MicrowaveReadoutElectronics {
        attribute probeFrequency : FrequencyValue = 5.0e9 [Hz];
        attribute probePhase : PlaneAngleValue = 0.0 [rad];
        attribute probeAmplitude : Real = 1.0;

        port resonatorPort : MicrowavePort;
        out port dataPort : DataPort;
    }

    part def SignalProcessingUnit {
        attribute calibration : CalibrationData;
        in port readoutPort : DataPort;
        out port eventPort : DataPort;
    }

    part def KIDSystem {
        part cryostat : CryogenicSystem;
        part resonator : SuperconductingResonator;
        part readout : MicrowaveReadoutElectronics;
        part processor : SignalProcessingUnit;

        in port photonInput : PhotonPort;
        out port systemOutput : DataPort;

        attribute currentPhoton : Photon;
        attribute currentBaseband : BasebandSignal;
        attribute currentEvent : DetectionEvent;

        connect cryostat.coolingPort to resonator.thermalPort;
        connect readout.resonatorPort to resonator.microwavePort;
        connect readout.dataPort to processor.readoutPort;
        connect photonInput to resonator.photonPort;
        connect processor.eventPort to systemOutput;

        state detection {
            entry assign resonator.temperature := cryostat.setPointTemperature;
            then state waiting;

            state waiting {
                accept photon : Photon via photonInput
                    do assign currentPhoton := photon
                then absorbing;
            }

            state absorbing {
                do assign resonator.cooperPairCount := resonator.cooperPairCount - 1;
                do assign resonator.kineticInductance := resonator.kineticInductance + currentPhoton.energy.num * 1.0e-15 [H];
                then reading;
            }

            state reading {
                do assign currentBaseband.phaseShift := 0.5 [rad];
                do assign currentBaseband.amplitudeShift := 0.1;
                do assign currentBaseband.timestamp := currentPhoton.arrivalTime;
                then processing;
            }

            state processing {
                do assign currentEvent.photonEnergy := CalculatePhotonEnergy(currentBaseband.phaseShift, currentBaseband.amplitudeShift, processor.calibration);
                do assign currentEvent.arrivalTime := currentPhoton.arrivalTime;
                do assign currentEvent.phaseShift := currentBaseband.phaseShift;
                do assign currentEvent.amplitudeShift := currentBaseband.amplitudeShift;
                do assign systemOutput.event := currentEvent;
                then waiting;
            }
        }
    }

    requirement def CryogenicOperatingTemperatureRequirement {
        doc /* The superconducting resonator shall be cooled to 0.1 Kelvin by the cryogenic system. */
        subject resonator : SuperconductingResonator;
        attribute requiredTemperature : TemperatureValue = 0.1 [K];
        constraint { resonator.temperature <= requiredTemperature }
    }

    requirement def PhotonEnergyMeasurementRequirement {
        doc /* The system shall detect individual photons and record their energy and arrival time as a detection event. */
        subject system : KIDSystem;
        constraint { system.systemOutput.event.photonEnergy > 0 }
        constraint { system.systemOutput.event.arrivalTime >= 0 [s] }
    }

    requirement def MicrowaveProbeStabilityRequirement {
        doc /* The microwave readout electronics shall provide a stable probe signal at the resonator's resonant frequency. */
        subject readout : MicrowaveReadoutElectronics;
        attribute frequencyTolerance : FrequencyValue = 1.0e3 [Hz];
        constraint { readout.probeFrequency == 5.0e9 [Hz] }
    }

    requirement def KineticInductanceShiftRequirement {
        doc /* Absorption of a photon shall increase the kinetic inductance of the resonator, causing a measurable frequency shift. */
        subject resonator : SuperconductingResonator;
        constraint { resonator.kineticInductance > 1.0e-9 [H] }
    }
}
