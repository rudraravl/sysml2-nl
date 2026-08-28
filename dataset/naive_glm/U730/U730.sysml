package IR_Sensing_Unit {

    import ScalarValues::*;
    import ISQ::*;

    // ---- Units ----
    unit kelvin;
    unit celsius;
    unit millivolt;
    unit watt_per_m2;
    unit degree;
    unit second;
    unit hertz;
    unit micrometer;
    unit millimeter;
    unit volt;

    // ---- Value Types ----
    value type TemperatureValue > Real {
        unit kelvin;
    }

    value type CelsiusValue > Real {
        unit celsius;
    }

    value type VoltageValue > Real {
        unit millivolt;
    }

    value type IrradianceValue > Real {
        unit watt_per_m2;
    }

    value type EmissivityValue > Real {
        min = 0.0;
        max = 1.0;
    }

    value type DigitalCount > Integer {
        min = 0;
        max = 65535;
    }

    value type AngleValue > Real {
        unit degree;
    }

    value type TimeValue > Real {
        unit second;
    }

    value type FrequencyValue > Real {
        unit hertz;
    }

    value type LengthValue > Real {
        unit millimeter;
    }

    value type WavelengthValue > Real {
        unit micrometer;
    }

    value type AccuracyValue > Real {
        unit kelvin;
    }

    // ---- Item Definitions ----
    item def InfraredRadiation {
        attribute irradiance : IrradianceValue;
        attribute wavelength : WavelengthValue;
    }

    item def AnalogSignal {
        attribute voltage : VoltageValue;
    }

    item def DigitalSample {
        attribute count : DigitalCount;
        attribute timestamp : TimeValue;
    }

    item def TemperatureReading {
        attribute value : TemperatureValue;
        attribute timestamp : TimeValue;
        attribute valid : Boolean;
    }

    item def CalibrationData {
        attribute offset : VoltageValue;
        attribute gainFactor : Real;
        attribute referenceTemperature : TemperatureValue;
    }

    // ---- Port Definitions ----
    port def OpticalInputPort {
        in item radiation : InfraredRadiation;
    }

    port def FocusedRadiationPort {
        out item radiation : InfraredRadiation;
    }

    port def DetectorInputPort {
        in item radiation : InfraredRadiation;
    }

    port def RawSignalPort {
        out item signal : AnalogSignal;
    }

    port def ConditionedSignalPort {
        out item signal : AnalogSignal;
    }

    port def DigitalSamplePort {
        out item sample : DigitalSample;
    }

    port def TemperatureOutputPort {
        out item reading : TemperatureReading;
    }

    // ---- Component Definitions ----
    part def OpticalSystem {
        doc /* Gathers infrared radiation from the target and focuses it onto the detector. */
        attribute fieldOfView : AngleValue = 5.0 [degree];
        attribute focalLength : LengthValue = 15.0 [millimeter];
        attribute spotSizeAtOneMeter : LengthValue = 8.7 [millimeter];

        port opticalIn : OpticalInputPort;
        port focusedOut : FocusedRadiationPort;

        action def FocusRadiation {
            in radiation : InfraredRadiation;
            out focused : InfraredRadiation;
        }

        action focus : FocusRadiation {
            in radiation = opticalIn.radiation;
            out focused = focusedOut.radiation;
        }
    }

    part def InfraredDetector {
        doc /* Thermopile-based detector sensitive to long-wave infrared. Converts thermal energy to weak voltage. */
        attribute sensitivityRangeMin : WavelengthValue = 8.0 [micrometer];
        attribute sensitivityRangeMax : WavelengthValue = 14.0 [micrometer];
        attribute responsivity : Real = 50.0; // V/W
        attribute noiseFloor : VoltageValue = 0.005 [millivolt];

        port detectorIn : DetectorInputPort;
        port rawOut : RawSignalPort;

        action def ConvertRadiationToVoltage {
            in radiation : InfraredRadiation;
            out signal : AnalogSignal;
        }

        action convert : ConvertRadiationToVoltage {
            in radiation = detectorIn.radiation;
            out signal = rawOut.signal;
        }
    }

    part def SignalConditioner {
        doc /* Amplifies, filters, and offset-corrects the weak detector signal. */
        attribute gain : Real = 1000.0;
        attribute offsetCorrection : VoltageValue = 0.0 [millivolt];
        attribute filterCutoff : FrequencyValue = 10.0 [hertz];

        port signalIn : RawSignalPort;
        port conditionedOut : ConditionedSignalPort;

        action def ConditionSignal {
            in raw : AnalogSignal;
            out conditioned : AnalogSignal;
        }

        action condition : ConditionSignal {
            in raw = signalIn.signal;
            out conditioned = conditionedOut.signal;
        }
    }

    part def AnalogToDigitalConverter {
        doc /* Converts the conditioned analog signal into a digital number. */
        attribute resolutionBits : Integer = 16;
        attribute samplingRate : FrequencyValue = 100.0 [hertz];
        attribute referenceVoltage : Real = 3.3 [volt];

        port analogIn : ConditionedSignalPort;
        port digitalOut : DigitalSamplePort;

        action def ConvertAnalogToDigital {
            in signal : AnalogSignal;
            out sample : DigitalSample;
        }

        action convert : ConvertAnalogToDigital {
            in signal = analogIn.signal;
            out sample = digitalOut.sample;
        }
    }

    part def TemperatureProcessor {
        doc /* Computes final temperature from digital sample using calibration data, emissivity, and ambient temperature. */
        attribute calibration : CalibrationData;
        attribute emissivity : EmissivityValue = 0.95;
        attribute ambientTemperature : TemperatureValue = 298.15 [kelvin];
        attribute measurementRangeMin : CelsiusValue = -40.0 [celsius];
        attribute measurementRangeMax : CelsiusValue = 500.0 [celsius];

        port sampleIn : DigitalSamplePort;
        port tempOut : TemperatureOutputPort;

        action def ComputeTemperature {
            in sample : DigitalSample;
            in emissivity : EmissivityValue;
            in ambient : TemperatureValue;
            in calib : CalibrationData;
            out reading : TemperatureReading;
        }

        action compute : ComputeTemperature {
            in sample = sampleIn.sample;
            in emissivity = emissivity;
            in ambient = ambientTemperature;
            in calib = calibration;
            out reading = tempOut.reading;
        }
    }

    // ---- Main Sensing Unit ----
    part def IRSensingUnit {
        doc /* High-precision non-contact infrared temperature sensing unit. */
        attribute accuracy : AccuracyValue = 0.5 [kelvin];
        attribute responseTime : TimeValue = 0.1 [second];
        attribute measurementRangeMin : CelsiusValue = -40.0 [celsius];
        attribute measurementRangeMax : CelsiusValue = 500.0 [celsius];

        port opticalInput : OpticalInputPort;
        port temperatureOutput : TemperatureOutputPort;

        part opticalSystem : OpticalSystem;
        part detector : InfraredDetector;
        part signalConditioner : SignalConditioner;
        part adc : AnalogToDigitalConverter;
        part processor : TemperatureProcessor;

        // Internal connections
        connect opticalSystem.focusedOut to detector.detectorIn;
        connect detector.rawOut to signalConditioner.signalIn;
        connect signalConditioner.conditionedOut to adc.analogIn;
        connect adc.digitalOut to processor.sampleIn;

        // External interface connections
        connect opticalInput to opticalSystem.opticalIn;
        connect processor.tempOut to temperatureOutput;

        // Operational state machine
        state def OperationalStates {
            state standby {
                doc /* Low-power idle mode awaiting command. */
                entry action { /* disable measurement pipeline */ }
            }

            state warmUp {
                doc /* Detector stabilization phase before active measurement. */
                attribute warmUpDuration : TimeValue = 2.0 [second];
                entry action { /* power detector and conditioner, wait for stability */ }
            }

            state continuousMeasurement {
                doc /* Active measurement cycle producing temperature readings. */
                entry action { /* enable ADC sampling and processor computation */ }
            }

            state calibration {
                doc /* Calibration mode using reference source. */
                entry action { /* run calibration routine against known reference */ }
            }

            state faultDetected {
                doc /* Diagnostic state entered when a fault is detected. */
                entry action { /* report fault code, halt output */ }
            }

            transition standby to warmUp
                when powerOn;
            transition warmUp to continuousMeasurement
                when warmUpComplete;
            transition continuousMeasurement to calibration
                when calibrationRequested;
            transition calibration to continuousMeasurement
                when calibrationComplete;
            transition continuousMeasurement to faultDetected
                when faultDetected;
            transition faultDetected to standby
                when faultCleared;
            transition continuousMeasurement to standby
                when standbyRequested;
        }

        attribute mode : OperationalStates;

        // Measurement action sequence
        action def MeasurementCycle {
            in radiation : InfraredRadiation;
            out reading : TemperatureReading;

            action focus : OpticalSystem::FocusRadiation {
                in radiation = radiation;
            }
            action detect : InfraredDetector::ConvertRadiationToVoltage {
                in radiation = focus.focused;
            }
            action condition : SignalConditioner::ConditionSignal {
                in raw = detect.signal;
            }
            action digitize : AnalogToDigitalConverter::ConvertAnalogToDigital {
                in signal = condition.conditioned;
            }
            action compute : TemperatureProcessor::ComputeTemperature {
                in sample = digitize.sample;
            }
            then assign reading = compute.reading;
        }
    }

    // ---- Requirements ----
    requirement def NonContactMeasurementRequirement {
        doc /* The unit shall measure object temperature without physical contact by detecting infrared radiation. */
    }

    requirement def HighAccuracyRequirement {
        doc /* The unit shall measure temperature with accuracy within ±0.5 K across the operating range. */
        constraint { accuracy <= 0.5 [kelvin] }
    }

    requirement def WideRangeRequirement {
        doc /* The unit shall measure temperatures from -40°C to 500°C. */
        constraint { measurementRangeMin <= -40.0 [celsius] }
        constraint { measurementRangeMax >= 500.0 [celsius] }
    }

    requirement def FastResponseRequirement {
        doc /* The unit shall provide a temperature reading within 0.1 seconds. */
        constraint { responseTime <= 0.1 [second] }
    }

    requirement def NarrowFieldOfViewRequirement {
        doc /* The optical system shall have a narrow field of view to measure a specific small spot. */
        constraint { fieldOfView <= 10.0 [degree] }
    }

    requirement def OperationalModesRequirement {
        doc /* The unit shall support standby, continuous measurement, and calibration modes. */
    }

    requirement def WarmUpRequirement {
        doc /* The unit shall perform a warm-up phase to ensure detector stability before measurement. */
    }

    requirement def FaultDetectionRequirement {
        doc /* The unit shall include fault detection for diagnostics. */
    }

    requirement def SignalConditioningRequirement {
        doc /* The signal conditioner shall amplify, filter, and offset-correct the detector signal. */
    }

    requirement def DigitalProcessingRequirement {
        doc /* The temperature processor shall compute final temperature using calibration data, emissivity, and ambient temperature. */
    }

    // ---- Instantiation and Satisfaction ----
    part sensingUnit : IRSensingUnit {
        satisfy NonContactMeasurementRequirement;
        satisfy HighAccuracyRequirement;
        satisfy WideRangeRequirement;
        satisfy FastResponseRequirement;
        satisfy NarrowFieldOfViewRequirement;
        satisfy OperationalModesRequirement;
        satisfy WarmUpRequirement;
        satisfy FaultDetectionRequirement;
        satisfy SignalConditioningRequirement;
        satisfy DigitalProcessingRequirement;
    }

}
