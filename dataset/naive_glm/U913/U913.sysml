package ThermopileLaserSensingUnitModel {
    import ScalarValues::*;
    import ISQ::*;
    import ISQBase::*;

    // ---- Value Types with Units ----
    value type Voltage :> Real { unit "V"; }
    value type Power :> Real { unit "W"; }
    value type Temperature :> Real { unit "K"; }
    value type Duration :> Real { unit "s"; }
    value type SampleRate :> Real { unit "1/s"; }
    value type Gain :> Real;
    value type CalibrationFactor :> Real;
    value type OffsetCount :> Integer;
    value type DigitalCount :> Integer;

    // ---- Item Types ----
    item def LaserBeam {
        attribute power : Power;
        attribute wavelength : Real; // nm
    }

    item def AnalogSignal {
        attribute voltage : Voltage;
    }

    item def DigitalSample {
        attribute count : DigitalCount;
        attribute timestamp : Duration;
    }

    item def PowerMeasurement {
        attribute value : Power;
        attribute timestamp : Duration;
        attribute status : String;
    }

    // ---- Port Definitions ----
    port def OpticalInputPort {
        out beam : LaserBeam;
    }

    port def AnalogSignalPort {
        out signal : AnalogSignal;
    }

    port def DigitalDataPort {
        out sample : DigitalSample;
    }

    port def DataOutputPort {
        out measurement : PowerMeasurement;
    }

    // ---- Thermopile Sensor ----
    part def ThermopileSensor {
        attribute sensitivity : Voltage = 0.05 [V/W]; // V per W
        attribute activeArea : Real = 1.0; // cm^2
        attribute absorptivity : Real = 0.95;

        port opticalIn : OpticalInputPort;
        port voltageOut : AnalogSignalPort;

        action def GenerateVoltage {
            in incidentBeam : LaserBeam;
            out generatedSignal : AnalogSignal;
        }

        action generateVoltage : GenerateVoltage {
            in incidentBeam <- opticalIn.beam;
            out generatedSignal -> voltageOut.signal;
        }
    }

    // ---- Signal Amplifier ----
    part def SignalAmplifier {
        attribute gain : Gain = 1000.0;
        attribute inputImpedance : Real = 1.0e6; // ohms
        attribute bandwidth : Real = 10.0e3; // Hz

        port ampIn : AnalogSignalPort;
        port ampOut : AnalogSignalPort;

        action def Amplify {
            in inputSignal : AnalogSignal;
            out outputSignal : AnalogSignal;
        }

        action amplify : Amplify {
            in inputSignal <- ampIn.signal;
            out outputSignal -> ampOut.signal;
        }
    }

    // ---- Analog-to-Digital Converter ----
    part def ADC {
        attribute sampleRate : SampleRate = 10000.0 [1/s];
        attribute resolutionBits : Integer = 16;
        attribute referenceVoltage : Voltage = 5.0 [V];
        attribute fullScaleCount : DigitalCount = 65535;

        port adcIn : AnalogSignalPort;
        port adcOut : DigitalDataPort;

        action def Convert {
            in inputSignal : AnalogSignal;
            out digitalSample : DigitalSample;
        }

        action convert : Convert {
            in inputSignal <- adcIn.signal;
            out digitalSample -> adcOut.sample;
        }
    }

    // ---- Signal Processor ----
    part def SignalProcessor {
        attribute offset : OffsetCount = 0;
        attribute calibrationFactor : CalibrationFactor = 1.0;
        attribute averagingWindow : Integer = 16;

        port procIn : DigitalDataPort;
        port procOut : DataOutputPort;

        action def Process {
            in rawSample : DigitalSample;
            out measurement : PowerMeasurement;
        }

        action process : Process {
            in rawSample <- procIn.sample;
            out measurement -> procOut.measurement;
        }
    }

    // ---- Top-Level Thermopile Laser Sensing Unit ----
    part def ThermopileLaserSensingUnit {
        attribute minPower : Power = 0.001 [W];
        attribute maxPower : Power = 10.0 [W];
        attribute accuracy : Real = 0.03; // ±3%
        attribute responseTime : Duration = 1.0 [s];

        port opticalInput : OpticalInputPort;
        port dataOutput : DataOutputPort;

        part sensor : ThermopileSensor;
        part amplifier : SignalAmplifier;
        part adc : ADC;
        part processor : SignalProcessor;

        // Internal connections
        connect opticalInput to sensor.opticalIn;
        connect sensor.voltageOut to amplifier.ampIn;
        connect amplifier.ampOut to adc.adcIn;
        connect adc.adcOut to processor.procIn;
        connect processor.procOut to dataOutput;

        // Item flows
        flow beamFlow of LaserBeam from opticalInput.beam to sensor.opticalIn.beam;
        flow voltageFlow of AnalogSignal from sensor.voltageOut.signal to amplifier.ampIn.signal;
        flow amplifiedFlow of AnalogSignal from amplifier.ampOut.signal to adc.adcIn.signal;
        flow digitalFlow of DigitalSample from adc.adcOut.sample to processor.procIn.sample;
        flow measurementFlow of PowerMeasurement from processor.procOut.measurement to dataOutput.measurement;

        // Control attributes
        attribute powerOn : Boolean = false;
        attribute warmupComplete : Boolean = false;
        attribute measureCommand : Boolean = false;
        attribute measurementComplete : Boolean = false;
        attribute warmupDuration : Duration = 0.5 [s];
        attribute elapsedWarmup : Duration = 0.0 [s];

        // State Machine
        state def UnitStateMachine {
            entry; then idle;

            state idle {
                entry action { powerOn = true; }
                transition to warmup
                    when (powerOn == true);
            }

            state warmup {
                entry action { elapsedWarmup = 0.0 [s]; }
                do action {
                    while (elapsedWarmup < warmupDuration) {
                        elapsedWarmup = elapsedWarmup + 0.01 [s];
                    }
                    warmupComplete = true;
                }
                transition to ready
                    when (warmupComplete == true);
            }

            state ready {
                entry action { measurementComplete = false; }
                transition to measuring
                    when (measureCommand == true);
            }

            state measuring {
                entry action { measurementComplete = false; }
                do action {
                    // Trigger measurement chain
                    sensor.generateVoltage;
                    amplifier.amplify;
                    adc.convert;
                    processor.process;
                    measurementComplete = true;
                }
                transition to ready
                    when (measurementComplete == true);
            }
        }

        state machine : UnitStateMachine;

        // Operational actions
        action def PerformMeasurement {
            in incidentBeam : LaserBeam;
            out result : PowerMeasurement;
        }

        action performMeasurement : PerformMeasurement {
            in incidentBeam <- opticalInput.beam;
            out result -> dataOutput.measurement;
        }
    }

    // ---- Requirements ----
    requirement def PowerRangeRequirement {
        attribute minPower : Power = 0.001 [W];
        attribute maxPower : Power = 10.0 [W];
        doc /* The unit shall measure laser power from 1 milliwatt up to 10 watts. */
    }

    requirement def AccuracyRequirement {
        attribute maxErrorFraction : Real = 0.03;
        doc /* The unit shall provide measurements with accuracy of at least ±3%. */
    }

    requirement def ResponseTimeRequirement {
        attribute maxResponseTime : Duration = 1.0 [s];
        doc /* The unit shall provide a stable reading in under one second. */
    }

    requirement def SelfContainedRequirement {
        doc /* The unit shall function as a complete, self-contained measurement system. */
    }

    requirement def OutputRequirement {
        doc /* The unit shall output a final power measurement in Watts with a timestamp through its data output port. */
    }

    requirement ThermopileUnitRequirements {
        subject unit : ThermopileLaserSensingUnit;

        satisfy PowerRangeRequirement {
            subject unit;
        }

        satisfy AccuracyRequirement {
            subject unit;
        }

        satisfy ResponseTimeRequirement {
            subject unit;
        }

        satisfy SelfContainedRequirement {
            subject unit;
        }

        satisfy OutputRequirement {
            subject unit;
        }
    }

    // ---- Verification ----
    verification def VerifyPowerRange {
        subject unit : ThermopileLaserSensingUnit;
        objective {
            assert unit.minPower == 0.001 [W] and unit.maxPower == 10.0 [W];
        }
    }

    verification def VerifyAccuracy {
        subject unit : ThermopileLaserSensingUnit;
        objective {
            assert unit.accuracy <= 0.03;
        }
    }

    verification def VerifyResponseTime {
        subject unit : ThermopileLaserSensingUnit;
        objective {
            assert unit.responseTime <= 1.0 [s];
        }
    }
}
