package ChemFET_Sensing_System {

    private import ScalarValues::Real;

    value type ConcentrationValue :> Real;
    value type VoltageValue :> Real;
    value type CurrentValue :> Real;
    value type FrequencyValue :> Real;
    value type TimeValue :> Real;

    item def Analyte;
    item def Solution {
        item analytes : Analyte[*];
        attribute concentration : ConcentrationValue;
    }

    attribute def CalibrateCommand;
    attribute def CalibrationComplete;
    attribute def ShutdownCommand;
    attribute def RecalibrateCommand;

    port def ChemicalPort {
        out item solution : Solution;
    }
    port def PotentialPort {
        out voltage : VoltageValue;
    }
    port def CurrentPort {
        out current : CurrentValue;
    }
    port def VoltageOutputPort {
        out voltage : VoltageValue;
    }

    action def SenseAnalyte {
        in solution : Solution;
        out voltage : VoltageValue;
    }
    action def ProvideBaseline {
        out voltage : VoltageValue;
    }
    action def Transduce {
        in gateVoltage : VoltageValue;
        in refVoltage : VoltageValue;
        out drainCurrent : CurrentValue;
    }
    action def ProcessSignal {
        in current : CurrentValue;
        out voltage : VoltageValue;
    }
    action def Calibrate {
        out baseline : VoltageValue;
    }
    action def Measure {
        in solution : Solution;
        in refVoltage : VoltageValue;
        out voltage : VoltageValue;

        action sense : SenseAnalyte {
            in solution = solution;
            out voltage;
        }
        action transduce : Transduce {
            in gateVoltage = sense.voltage;
            in refVoltage = refVoltage;
            out current;
        }
        action process : ProcessSignal {
            in current = transduce.current;
            out voltage = voltage;
        }
    }

    part def IonSelectiveMembrane {
        port chemicalInPort : ~ChemicalPort;
        port potentialOutPort : PotentialPort;
        attribute selectivityCoefficient : Real;
        attribute responseTime : TimeValue;
        attribute surfacePotential : VoltageValue;
    }

    part def ReferenceElectrode {
        port potentialOutPort : PotentialPort;
        attribute baselineVoltage : VoltageValue;
    }

    part def FETTransducer {
        port gatePort : ~PotentialPort;
        port referencePort : ~PotentialPort;
        port drainCurrentPort : CurrentPort;
        attribute transconductance : Real;
        attribute thresholdVoltage : VoltageValue;
    }

    part def ReadoutCircuit {
        port currentInPort : ~CurrentPort;
        port signalOutPort : VoltageOutputPort;
        attribute gain : Real;
        attribute cutoffFrequency : FrequencyValue;
        attribute noiseFloor : VoltageValue;
    }

    part def ChemFETSensor {
        port samplePort : ChemicalPort;
        port outputPort : VoltageOutputPort;

        part membrane : IonSelectiveMembrane {
            perform action senseAnalyte : SenseAnalyte {
                in solution = chemicalInPort.solution;
                out voltage = potentialOutPort.voltage;
            }
        }

        part referenceElectrode : ReferenceElectrode {
            perform action provideBaseline : ProvideBaseline {
                out voltage = potentialOutPort.voltage;
            }
        }

        part fet : FETTransducer {
            perform action transduce : Transduce {
                in gateVoltage = gatePort.voltage;
                in refVoltage = referencePort.voltage;
                out drainCurrent = drainCurrentPort.current;
            }
        }

        part readout : ReadoutCircuit {
            perform action processSignal : ProcessSignal {
                in current = currentInPort.current;
                out voltage = signalOutPort.voltage;
            }
        }

        flow samplePort.solution to membrane.chemicalInPort.solution;
        flow membrane.potentialOutPort.voltage to fet.gatePort.voltage;
        flow referenceElectrode.potentialOutPort.voltage to fet.referencePort.voltage;
        flow fet.drainCurrentPort.current to readout.currentInPort.current;
        flow readout.signalOutPort.voltage to outputPort.voltage;

        state sensorState {
            entry; then idle;

            state idle;
            accept CalibrateCommand then calibrating;

            state calibrating {
                do action calibrate : Calibrate;
            }
            accept CalibrationComplete then active;

            state active {
                do action measure : Measure {
                    in solution = samplePort.solution;
                    in refVoltage = referenceElectrode.baselineVoltage;
                    out voltage = outputPort.voltage;
                }
            }
            accept ShutdownCommand then done;
            accept RecalibrateCommand then calibrating;

            state done;
        }
    }

    requirement def SensitivityRequirement {
        /* The sensor shall produce a measurable output voltage change for small changes in analyte concentration. */
        subject sensor : ChemFETSensor;
    }

    requirement def SelectivityRequirement {
        /* The ion-selective membrane shall preferentially bind the target analyte over interferents. */
        subject membrane : IonSelectiveMembrane;
    }

    requirement def ResponseTimeRequirement {
        /* The sensor shall respond to changes in analyte concentration within 2 seconds. */
        subject sensor : ChemFETSensor;
    }

    requirement def NoiseRejectionRequirement {
        /* The readout circuit shall filter electronic noise to produce a stable output. */
        subject readout : ReadoutCircuit;
    }

    requirement sensitivityReq : SensitivityRequirement;
    requirement selectivityReq : SelectivityRequirement;
    requirement responseTimeReq : ResponseTimeRequirement;
    requirement noiseRejectionReq : NoiseRejectionRequirement;

    part sensorSystem : ChemFETSensor {
        satisfy sensitivityReq;
        satisfy selectivityReq by membrane;
        satisfy responseTimeReq;
        satisfy noiseRejectionReq by readout;
    }
}
