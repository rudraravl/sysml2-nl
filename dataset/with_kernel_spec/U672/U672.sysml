package FaradayCupSystemModel {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;

    item def ChargedParticle {
        attribute charge : ElectricChargeValue;
    }

    item def ParticleBeam {
        item particles : ChargedParticle[0..*];
        attribute beamCurrent : ElectricCurrentValue;
    }

    port def BeamInputPort {
        in item beam : ParticleBeam;
    }

    port def BiasVoltageInPort {
        in attribute biasVoltage : ElectricPotentialValue;
    }

    port def BiasVoltageOutPort {
        out attribute biasVoltage : ElectricPotentialValue;
    }

    port def CurrentInPort {
        in attribute current : ElectricCurrentValue;
    }

    port def CurrentOutPort {
        out attribute current : ElectricCurrentValue;
    }

    part def CollectorCup {
        attribute material : String = "Copper";
        attribute collectedCurrent : ElectricCurrentValue;

        port beamIn : BeamInputPort;
        port biasIn : BiasVoltageInPort;
        port currentOut : CurrentOutPort;

        action collectParticles {
            in beam : ParticleBeam;
            in bias : ElectricPotentialValue;
            out current : ElectricCurrentValue;
        }
    }

    part def BiasSupply {
        attribute outputVoltage : ElectricPotentialValue = -100 [SI::V];

        port biasOut : BiasVoltageOutPort;

        action applyBias {
            out voltage : ElectricPotentialValue = outputVoltage;
        }
    }

    part def CurrentAmplifier {
        attribute gain : Real = 10000;
        attribute amplifiedCurrent : ElectricCurrentValue;

        port signalIn : CurrentInPort;
        port signalOut : CurrentOutPort;

        action amplify {
            in inputCurrent : ElectricCurrentValue;
            out outputCurrent : ElectricCurrentValue;
        }
    }

    part def VacuumEnclosure {
        attribute internalPressure : PressureValue = 1e-6 [SI::Pa];
        attribute targetPressure : PressureValue = 1e-6 [SI::Pa];

        action maintainVacuum {
            out pressure : PressureValue = targetPressure;
        }
    }

    part def ElectromagneticShield {
        attribute shieldingEffectiveness : Real = 0.99;

        action shieldElectronics {
            doc /* Isolates measurement electronics from external electromagnetic noise. */
        }
    }

    action def BeamDetected;
    action def SignalStabilized;
    action def IntegrationComplete;
    action def BeamLost;
    action def MeasurementComplete;

    state def FaradayCupOperation {
        entry;
        then idle;

        state idle {
            doc /* Waiting for a particle beam to be detected. */
        }

        transition idle_to_measuring
            first idle
            accept BeamDetected
            then measuring;

        state measuring {
            doc /* Continuously collecting charged particles and measuring the resulting current. */
        }

        transition measuring_to_integrating
            first measuring
            accept SignalStabilized
            then integrating;

        state integrating {
            doc /* Integrating the current over a specific period to determine total charge. */
        }

        transition integrating_to_reporting
            first integrating
            accept IntegrationComplete
            then reporting;

        state reporting {
            doc /* Reporting the final measurement results. */
        }

        transition reporting_to_idle
            first reporting
            accept MeasurementComplete
            then idle;

        transition measuring_to_idle
            first measuring
            accept BeamLost
            then idle;

        transition integrating_to_idle
            first integrating
            accept BeamLost
            then idle;
    }

    requirement def CurrentMeasurementAccuracy {
        doc /* The Faraday cup system shall accurately measure the electric current of a charged particle beam. */
        subject faradayCupSystem : FaradayCupSystem;
    }

    requirement def VacuumIntegrityRequirement {
        doc /* The vacuum enclosure shall maintain a high-vacuum environment to prevent beam particle scattering. */
        subject vacuumEnclosure : VacuumEnclosure;
    }

    requirement def BiasVoltageRequirement {
        doc /* The bias supply shall apply a negative voltage to suppress secondary electron emission from the collector cup. */
        subject biasSupply : BiasSupply;
    }

    requirement def AmplificationRequirement {
        doc /* The current amplifier shall provide sufficient gain to amplify the faint beam current to a readable level. */
        subject currentAmplifier : CurrentAmplifier;
    }

    requirement def ShieldingRequirement {
        doc /* The electromagnetic shield shall isolate measurement electronics from external electrical noise. */
        subject electromagneticShield : ElectromagneticShield;
    }

    part def FaradayCupSystem {
        port beamInput : BeamInputPort;
        port dataOutput : CurrentOutPort;

        attribute measuredCurrent : ElectricCurrentValue;
        attribute integratedCharge : ElectricChargeValue;
        attribute integrationPeriod : TimeValue = 1 [SI::s];

        part collectorCup : CollectorCup;
        part biasSupply : BiasSupply;
        part currentAmplifier : CurrentAmplifier;
        part vacuumEnclosure : VacuumEnclosure;
        part electromagneticShield : ElectromagneticShield;

        state faradayCupOperation : FaradayCupOperation;
        exhibit faradayCupOperation;

        connection beamToCup connect beamInput to collectorCup.beamIn;
        connection biasToCup connect biasSupply.biasOut to collectorCup.biasIn;
        connection cupToAmplifier connect collectorCup.currentOut to currentAmplifier.signalIn;
        connection amplifierToOutput connect currentAmplifier.signalOut to dataOutput;
    }

    individual def TestFaradayCupSystem :> FaradayCupSystem;

    individual testFaradayCupSystem : TestFaradayCupSystem {
        timeslice firstMeasurement {
            doc /* Measuring a low-intensity beam at 2.5 nA. */
            attribute :>> measuredCurrent = 2.5e-9 [SI::A];
            attribute :>> integratedCharge = 2.5e-9 [SI::C];
        }
        then timeslice secondMeasurement {
            doc /* Measuring a higher-intensity beam at 5.0 nA. */
            attribute :>> measuredCurrent = 5.0e-9 [SI::A];
            attribute :>> integratedCharge = 5.0e-9 [SI::C];
        }
    }
}
