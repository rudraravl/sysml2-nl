package pHMeasurementSystem {
    import ISQ::*;
    import ISQBase::*;
    import ScalarValues::*;

    // ---- Value Types ----
    value type Voltage :> Real {
        :>> unit = "mV";
    }
    value type pHValue :> Real {
        :>> unit = "pH";
    }
    value type Temperature :> Real {
        :>> unit = "degC";
    }
    value type Resistance :> Real {
        :>> unit = "ohm";
    }
    value type DigitalCode :> Integer {
        :>> unit = "count";
    }
    value type Slope :> Real {
        :>> unit = "mV/pH";
    }
    value type Intercept :> Real {
        :>> unit = "mV";
    }

    // ---- Items ----
    item def SolutionSample;
    item def BufferSolution {
        attribute nominalpH : pHValue;
    }
    item def StorageSolution;
    item def RinseSolution;

    // ---- Port definitions ----
    port def ElectrodePotentialPort {
        attribute potential : Voltage;
    }
    port def AnalogVoltagePort {
        attribute voltage : Voltage;
    }
    port def DigitalSignalPort {
        attribute code : DigitalCode;
    }
    port def TemperaturePort {
        attribute temperature : Temperature;
    }
    port def pHOutputPort {
        attribute pH : pHValue;
    }
    port def SolutionPort {
        out item sample : SolutionSample;
    }

    // ---- Part definitions ----
    part def GlassMembrane {
        attribute sourceResistance : Resistance = 100e6 [ohm];
        port surfacePotential : ElectrodePotentialPort;
        attribute developedPotential : Voltage;
    }

    part def InternalReferenceElement {
        attribute buffer : BufferSolution { :>> nominalpH = 7.00 [pH]; }
        port referencePotential : ElectrodePotentialPort;
        attribute stablePotential : Voltage = 0.0 [mV];
    }

    part def ExternalReferenceElectrode {
        port externalPotential : ElectrodePotentialPort;
        attribute baselinePotential : Voltage = 0.0 [mV];
    }

    part def CombinationGlassElectrode {
        part glassMembrane : GlassMembrane;
        part internalReference : InternalReferenceElement;
        part externalReference : ExternalReferenceElectrode;
        port rawSignal : AnalogVoltagePort;
        port solutionInterface : SolutionPort;
        connection glassToInternal connect glassMembrane.surfacePotential to internalReference.referencePotential;
        connection rawOutput connect glassMembrane.surfacePotential to rawSignal;
        attribute rawVoltage : Voltage;
    }

    part def HighImpedanceAmplifier {
        attribute inputResistance : Resistance = 1e12 [ohm];
        attribute gain : Real = 1.0;
        port analogIn : AnalogVoltagePort;
        port analogOut : AnalogVoltagePort;
        action amplify {
            in vin : Voltage;
            out vout : Voltage;
        }
    }

    part def TemperatureSensor {
        port tempOut : TemperaturePort;
        attribute measuredTemp : Temperature;
    }

    part def TemperatureCompensator {
        part sensor : TemperatureSensor;
        port analogIn : AnalogVoltagePort;
        port tempIn : TemperaturePort;
        port analogOut : AnalogVoltagePort;
        attribute compensationFactor : Real;
        action compensate {
            in vin : Voltage;
            in temp : Temperature;
            out vout : Voltage;
        }
    }

    part def AnalogToDigitalConverter {
        attribute resolutionBits : Integer = 16;
        attribute referenceVoltage : Voltage = 1000.0 [mV];
        port analogIn : AnalogVoltagePort;
        port digitalOut : DigitalSignalPort;
        action convert {
            in vin : Voltage;
            out code : DigitalCode;
        }
    }

    part def SignalProcessor {
        attribute slope : Slope = -59.16 [mV/pH];
        attribute intercept : Intercept = 0.0 [mV];
        port digitalIn : DigitalSignalPort;
        port pHOut : pHOutputPort;
        action compute {
            in code : DigitalCode;
            out pH : pHValue;
        }
    }

    part def Display {
        port pHIn : pHOutputPort;
        attribute displayedpH : pHValue;
        action show {
            in pH : pHValue;
        }
    }

    part def DigitalPHMeasurementSystem {
        part electrode : CombinationGlassElectrode;
        part amplifier : HighImpedanceAmplifier;
        part compensator : TemperatureCompensator;
        part adc : AnalogToDigitalConverter;
        part processor : SignalProcessor;
        part display : Display;

        port solutionInterface : SolutionPort;
        port pHOutput : pHOutputPort;

        connection electrodeToAmplifier connect electrode.rawSignal to amplifier.analogIn;
        connection amplifierToCompensator connect amplifier.analogOut to compensator.analogIn;
        connection tempSensorToCompensator connect compensator.sensor.tempOut to compensator.tempIn;
        connection compensatorToADC connect compensator.analogOut to adc.analogIn;
        connection adcToProcessor connect adc.digitalOut to processor.digitalIn;
        connection processorToDisplay connect processor.pHOut to display.pHIn;
        connection solutionToElectrode connect solutionInterface to electrode.solutionInterface;
        connection outputRelay connect processor.pHOut to pHOutput;

        // State machine for system lifecycle
        part stateController {
            exhibit state lifecycle {
                entry; then storage;
                state storage;
                transition storage to preparation
                    when electrode.removedFromStorage;
                state preparation;
                transition preparation to calibration
                    when electrode.rinsed;
                state calibration {
                    entry; then calibrateLow;
                    state calibrateLow;
                    transition calibrateLow to calibrateHigh
                        when lowBufferAccepted;
                    state calibrateHigh;
                    transition calibrateHigh to ready
                        when highBufferAccepted;
                }
                state ready;
                transition ready to measurement
                    when measurementRequested;
                state measurement {
                    entry; then waitForStable;
                    state waitForStable;
                    transition waitForStable to takeReading
                        when signalStable;
                    state takeReading;
                    transition takeReading to ready
                        when readingComplete;
                }
                transition ready to maintenance
                    when maintenanceRequested;
                state maintenance;
                transition maintenance to storage
                    when maintenanceComplete;
                transition any to fault
                    when faultDetected;
                state fault;
                transition fault to maintenance
                    when faultAcknowledged;
            }
        }
    }

    // ---- Requirements ----
    requirement def MeasurementAccuracyRequirement {
        attribute maxError : pHValue = 0.02 [pH];
        subject system : DigitalPHMeasurementSystem;
        objective {
            doc "The system shall measure pH within +/- 0.02 pH of the true value across the range 0 to 14 pH."
        }
    }

    requirement def TemperatureCompensationRequirement {
        attribute tempRangeMin : Temperature = 0.0 [degC];
        attribute tempRangeMax : Temperature = 80.0 [degC];
        subject system : DigitalPHMeasurementSystem;
        objective {
            doc "The system shall compensate for temperature variations between 0 and 80 degC to maintain accuracy."
        }
    }

    requirement def HighImpedanceRequirement {
        attribute minInputResistance : Resistance = 1e12 [ohm];
        subject amplifier : HighImpedanceAmplifier;
        objective {
            doc "The amplifier shall have input resistance of at least 1e12 ohm to avoid loading the electrode."
        }
    }

    requirement def CalibrationRequirement {
        attribute lowBufferpH : pHValue = 4.01 [pH];
        attribute highBufferpH : pHValue = 7.00 [pH];
        subject system : DigitalPHMeasurementSystem;
        objective {
            doc "The system shall be calibrated using standard buffer solutions of pH 4.01 and 7.00 before measurement."
        }
    }

    requirement def LifecycleRequirement {
        subject system : DigitalPHMeasurementSystem;
        objective {
            doc "The system shall support states: storage, preparation, calibration, ready, measurement, maintenance, and fault."
        }
    }

    requirement phMeasurementSystemRequirements {
        satisfy MeasurementAccuracyRequirement;
        satisfy TemperatureCompensationRequirement;
        satisfy HighImpedanceRequirement;
        satisfy CalibrationRequirement;
        satisfy LifecycleRequirement;
    }
}
