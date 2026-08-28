package FaradayCupSystem {
    import ScalarValues::*;
    import ISQ::*;

    // ---- Value Types with Units ----
    value def Voltage :> Real { unit "V"; }
    value def Current :> Real { unit "A"; }
    value def Charge :> Real { unit "C"; }
    value def Pressure :> Real { unit "Pa"; }
    value def Duration :> Real { unit "s"; }
    value def Gain :> Real { unit "dimensionless"; }
    value def ShieldingEffectiveness :> Real { unit "dB"; }

    // ---- Item Definitions ----
    item def ChargedParticle {
        attr charge : Real;
        attr energy : Real;
    }

    item def ParticleBeam {
        attr flux : ChargedParticle[*];
        attr nominalCurrent : Current;
    }

    item def MeasurementResult {
        attr measuredCurrent : Current;
        attr integratedCharge : Charge;
        attr integrationTime : Duration;
        attr stable : Boolean;
    }

    // ---- Port Definitions ----
    port def BeamPort {
        out item beam : ParticleBeam;
    }

    port def CurrentSignalPort {
        out item current : Current;
    }

    port def VoltageSupplyPort {
        out item voltage : Voltage;
    }

    port def DataPort {
        out item result : MeasurementResult;
    }

    // ---- Interfaces ----
    interface def BeamDeliveryInterface {
        end supplier : BeamPort;
        end consumer : BeamPort;
    }

    interface def CurrentSignalInterface {
        end source : CurrentSignalPort;
        end sink : CurrentSignalPort;
    }

    interface def BiasSupplyInterface {
        end supply : VoltageSupplyPort;
        end load : VoltageSupplyPort;
    }

    interface def DataInterface {
        end producer : DataPort;
        end consumer : DataPort;
    }

    // ---- Requirements ----
    requirement def MeasureCurrentRequirement {
        doc /* The system shall measure the charged particle beam current with an accuracy better than 1% of the nominal value. */
        subject faradayCup : FaradayCupSystem;
        attribute nominalCurrent : Current = 1e-9 [A];
        constraint { abs(faradayCup.reportedCurrent - nominalCurrent) <= 0.01 * nominalCurrent }
    }

    requirement def BiasVoltageRequirement {
        doc /* The BiasSupply shall apply a negative voltage to the CollectorCup to suppress secondary electron emission. */
        subject biasSupply : BiasSupply;
        attribute minBias : Voltage = -50 [V];
        attribute maxBias : Voltage = -200 [V];
        constraint { biasSupply.outputVoltage >= maxBias and biasSupply.outputVoltage <= minBias }
    }

    requirement def VacuumRequirement {
        doc /* The VacuumEnclosure shall maintain a high-vacuum environment to prevent beam scattering. */
        subject enclosure : VacuumEnclosure;
        attribute maxPressure : Pressure = 1e-5 [Pa];
        constraint { enclosure.internalPressure <= maxPressure }
    }

    requirement def ShieldingRequirement {
        doc /* The ElectromagneticShield shall isolate measurement electronics from external electromagnetic noise. */
        subject shield : ElectromagneticShield;
        attribute minEffectiveness : ShieldingEffectiveness = 60 [dB];
        constraint { shield.effectiveness >= minEffectiveness }
    }

    requirement def IntegrationRequirement {
        doc /* The system shall integrate the measured current over a specified period to determine total collected charge. */
        subject controller : Controller;
        attribute integrationPeriod : Duration = 1 [s];
        constraint { controller.integrationTime == integrationPeriod }
    }

    // ---- Part Definitions ----
    part def CollectorCup {
        attribute material : String = "Copper";
        attribute secondaryEmissionCoefficient : Real = 0.1;
        attribute collectedCurrent : Current;

        port beamIn : BeamPort;
        port biasIn : VoltageSupplyPort;
        port currentOut : CurrentSignalPort;

        action def CollectParticles {
            in beam : ParticleBeam;
            in bias : Voltage;
            out current : Current;
            doc /* Intercept charged particles and convert accumulated charge to current. */
        }

        action collect : CollectParticles {
            in beam = beamIn.beam;
            in bias = biasIn.voltage;
            out current = currentOut.current;
        }
    }

    part def BiasSupply {
        attribute outputVoltage : Voltage = -100 [V];
        attribute ripple : Voltage = 0.01 [V];

        port biasOut : VoltageSupplyPort;

        action def RegulateVoltage {
            out voltage : Voltage;
        }

        action regulate : RegulateVoltage {
            out voltage = biasOut.voltage;
        }
    }

    part def CurrentAmplifier {
        attribute gain : Gain = 1e6;
        attribute bandwidth : Real = 1000;
        attribute inputCurrent : Current;
        attribute outputCurrent : Current;

        port signalIn : CurrentSignalPort;
        port signalOut : CurrentSignalPort;

        action def Amplify {
            in input : Current;
            out output : Current;
        }

        action amplify : Amplify {
            in input = signalIn.current;
            out output = signalOut.current;
        }
    }

    part def VacuumEnclosure {
        attribute internalPressure : Pressure = 1e-6 [Pa];
        attribute volume : Real = 0.01;
        attribute pumpSpeed : Real = 100;

        port beamFeedthrough : BeamPort;

        action def MaintainVacuum {
            out pressure : Pressure;
        }

        action maintain : MaintainVacuum {
            out pressure = internalPressure;
        }
    }

    part def ElectromagneticShield {
        attribute effectiveness : ShieldingEffectiveness = 80 [dB];
        attribute material : String = "Mu-metal";
        attribute grounded : Boolean = true;
    }

    part def BeamDetector {
        attribute beamPresent : Boolean = false;
        attribute threshold : Current = 1e-12 [A];

        port beamIn : BeamPort;
        port detectionOut : DataPort;

        action def DetectBeam {
            in beam : ParticleBeam;
            out present : Boolean;
        }

        action detect : DetectBeam {
            in beam = beamIn.beam;
            out present = beamPresent;
        }
    }

    part def Controller {
        attribute reportedCurrent : Current;
        attribute integratedCharge : Charge;
        attribute integrationTime : Duration = 1 [s];
        attribute signalStable : Boolean = false;
        attribute stabilityThreshold : Real = 0.001;

        port signalIn : CurrentSignalPort;
        port detectorIn : DataPort;
        port dataOut : DataPort;

        action def EvaluateStability {
            in current : Current;
            out stable : Boolean;
        }

        action def IntegrateCurrent {
            in current : Current;
            in period : Duration;
            out charge : Charge;
        }

        action def ReportResult {
            in current : Current;
            in charge : Charge;
            in period : Duration;
            out result : MeasurementResult;
        }

        state machine MeasurementStateMachine {
            entry action { /* initialize subsystems */ }

            state idle {
                entry action { reportedCurrent = 0 [A]; signalStable = false; }
                do action { /* wait for beam detection */ }
                transition to measuring
                    when detectorIn.result != null and beamPresent == true
                    do action { /* enable bias and amplifier */ };
            }

            state measuring {
                entry action { /* begin continuous current sampling */ }
                do action { reportedCurrent = signalIn.current; }
                transition to integrating
                    when signalStable == true
                    do action { /* prepare integration buffer */ };
                transition to idle
                    when beamPresent == false
                    do action { /* reset measurement */ };
            }

            state integrating {
                entry action { integratedCharge = 0 [C]; }
                do action {
                    /* accumulate charge over integrationTime */
                    integratedCharge = reportedCurrent * integrationTime;
                }
                transition to reporting
                    when integrationTime >= 1 [s];
                transition to idle
                    when beamPresent == false;
            }

            state reporting {
                entry action {
                    /* emit final measurement result */
                    dataOut.result = MeasurementResult {
                        measuredCurrent = reportedCurrent,
                        integratedCharge = integratedCharge,
                        integrationTime = integrationTime,
                        stable = signalStable
                    };
                }
                transition to idle
                    when reporting.done;
            }
        }
    }

    // ---- Top-Level System ----
    part def FaradayCupSystem {
        attribute reportedCurrent : Current;
        attribute systemActive : Boolean = false;

        port beamInput : BeamPort;
        port dataOutput : DataPort;

        part cup : CollectorCup {
            port beamIn : BeamPort;
            port biasIn : VoltageSupplyPort;
            port currentOut : CurrentSignalPort;
        }

        part biasSupply : BiasSupply {
            port biasOut : VoltageSupplyPort;
        }

        part amplifier : CurrentAmplifier {
            port signalIn : CurrentSignalPort;
            port signalOut : CurrentSignalPort;
        }

        part enclosure : VacuumEnclosure {
            port beamFeedthrough : BeamPort;
        }

        part shield : ElectromagneticShield;

        part detector : BeamDetector {
            port beamIn : BeamPort;
            port detectionOut : DataPort;
        }

        part controller : Controller {
            port signalIn : CurrentSignalPort;
            port detectorIn : DataPort;
            port dataOut : DataPort;
        }

        // ---- Connections ----
        connection beamToEnclosure : BeamDeliveryInterface
            connect beamInput to enclosure.beamFeedthrough;

        connection enclosureToDetector : BeamDeliveryInterface
            connect enclosure.beamFeedthrough to detector.beamIn;

        connection detectorToCup : BeamDeliveryInterface
            connect detector.beamIn to cup.beamIn;

        connection biasToCup : BiasSupplyInterface
            connect biasSupply.biasOut to cup.biasIn;

        connection cupToAmplifier : CurrentSignalInterface
            connect cup.currentOut to amplifier.signalIn;

        connection amplifierToController : CurrentSignalInterface
            connect amplifier.signalOut to controller.signalIn;

        connection detectorToController : DataInterface
            connect detector.detectionOut to controller.detectorIn;

        connection controllerToOutput : DataInterface
            connect controller.dataOut to dataOutput;

        // ---- Requirements Satisfaction ----
        satisfy MeasureCurrentRequirement by faradayCup;
        satisfy BiasVoltageRequirement by biasSupply;
        satisfy VacuumRequirement by enclosure;
        satisfy ShieldingRequirement by shield;
        satisfy IntegrationRequirement by controller;
    }
}
