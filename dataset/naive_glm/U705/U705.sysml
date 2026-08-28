package HallProbeMagnetometer {

    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types with Units =====

    value def MagneticFluxDensityValue :> Real {
        unit tesla;
    }

    value def VoltageValue :> Real {
        unit volt;
    }

    value def CurrentValue :> Real {
        unit ampere;
    }

    value def TemperatureValue :> Real {
        unit kelvin;
    }

    value def DigitalCode :> Integer;

    value def FrequencyValue :> Real {
        unit hertz;
    }

    value def GainValue :> Real;

    value def ResolutionValue :> Real {
        unit volt;
    }

    // ===== Item Definitions =====

    item def MagneticField {
        value strength : MagneticFluxDensityValue;
    }

    item def AnalogSignal {
        value voltage : VoltageValue;
    }

    item def DigitalSample {
        value code : DigitalCode;
        value timestamp : Real;
    }

    item def CalibratedReading {
        value fieldStrength : MagneticFluxDensityValue;
        value temperature : TemperatureValue;
        value timestamp : Real;
        value confidence : Real;
    }

    item def CalibrationTable {
        value coefficients : Real[0..*];
        value offset : MagneticFluxDensityValue;
        value scale : Real;
    }

    item def DisplayMessage {
        value text : String;
        value numericValue : MagneticFluxDensityValue;
    }

    // ===== Port Definitions =====

    port def MagneticFieldPort {
        out field : MagneticField;
    }

    port def AnalogInputPort {
        in signal : AnalogSignal;
    }

    port def AnalogOutputPort {
        out signal : AnalogSignal;
    }

    port def DigitalInputPort {
        in sample : DigitalSample;
    }

    port def DigitalOutputPort {
        out sample : DigitalSample;
    }

    port def CurrentOutputPort {
        out biasCurrent : CurrentValue;
    }

    port def CurrentInputPort {
        in biasCurrent : CurrentValue;
    }

    port def TemperatureOutputPort {
        out temperature : TemperatureValue;
    }

    port def TemperatureInputPort {
        in temperature : TemperatureValue;
    }

    port def DisplayOutputPort {
        out message : DisplayMessage;
    }

    // ===== Requirements =====

    requirement def MeasurementRangeRequirement {
        doc /* The magnetometer shall measure magnetic fields within the specified range. */
        subject magnetometer : HallProbeMagnetometerSystem;
        requirement {
            subject magnetometer;
            constraint { magnetometer.measurementRange.min >= -2.0 [tesla] }
            constraint { magnetometer.measurementRange.max <= 2.0 [tesla] }
        }
    }

    requirement def AccuracyRequirement {
        doc /* The magnetometer shall achieve high accuracy over the full range. */
        subject magnetometer : HallProbeMagnetometerSystem;
        attribute maxError : MagneticFluxDensityValue = 0.001 [tesla];
        constraint { magnetometer.maxAbsoluteError <= maxError }
    }

    requirement def ResolutionRequirement {
        doc /* The magnetometer shall resolve small changes in magnetic field. */
        subject magnetometer : HallProbeMagnetometerSystem;
        attribute minResolution : MagneticFluxDensityValue = 0.0001 [tesla];
        constraint { magnetometer.resolution <= minResolution }
    }

    requirement def TemperatureCompensationRequirement {
        doc /* The system shall compensate for temperature-induced drift. */
        subject magnetometer : HallProbeMagnetometerSystem;
        attribute operatingRange : TemperatureValue = 253.15 [K];
        constraint { magnetometer.temperatureCompensationEnabled == true }
    }

    requirement def ContinuousOperationRequirement {
        doc /* The system shall provide continuous readings. */
        subject magnetometer : HallProbeMagnetometerSystem;
        attribute minUpdateRate : FrequencyValue = 10 [Hz];
        constraint { magnetometer.updateRate >= minUpdateRate }
    }

    // ===== Component Part Definitions =====

    part def BiasCurrentSource {
        attribute nominalCurrent : CurrentValue = 0.001 [A];
        attribute stability : Real = 0.0001;
        port currentOut : CurrentOutputPort;
        attribute outputCurrent : CurrentValue;

        action def generateCurrent {
            in target : CurrentValue = nominalCurrent;
            out current : CurrentValue;
        }

        perform generateCurrent {
            in target = nominalCurrent;
            out current = outputCurrent;
        }

        flow currentOut.biasCurrent of CurrentValue = outputCurrent;
    }

    part def HallElement {
        attribute sensitivity : Real = 0.1; // V/(A*T)
        attribute biasCurrent : CurrentValue;
        attribute exposedField : MagneticFluxDensityValue;
        attribute outputVoltage : VoltageValue;
        port currentIn : CurrentInputPort;
        port fieldIn : MagneticFieldPort;
        port voltageOut : AnalogOutputPort;

        action def transduce {
            in current : CurrentValue;
            in field : MagneticFluxDensityValue;
            out voltage : VoltageValue;
        }

        perform transduce {
            in current = biasCurrent;
            in field = exposedField;
            out voltage = outputVoltage;
        }

        flow currentIn.biasCurrent of CurrentValue = biasCurrent;
        flow fieldIn.field.strength of MagneticFluxDensityValue = exposedField;
        flow voltageOut.signal.voltage of VoltageValue = outputVoltage;
    }

    part def SignalAmplifier {
        attribute gain : GainValue = 1000.0;
        attribute inputVoltage : VoltageValue;
        attribute outputVoltage : VoltageValue;
        port signalIn : AnalogInputPort;
        port signalOut : AnalogOutputPort;

        action def amplify {
            in input : VoltageValue;
            in gainValue : GainValue = gain;
            out output : VoltageValue;
        }

        perform amplify {
            in input = inputVoltage;
            in gainValue = gain;
            out output = outputVoltage;
        }

        flow signalIn.signal.voltage of VoltageValue = inputVoltage;
        flow signalOut.signal.voltage of VoltageValue = outputVoltage;
    }

    part def NoiseFilter {
        attribute cutoffFrequency : FrequencyValue = 1000 [Hz];
        attribute order : Integer = 4;
        attribute inputVoltage : VoltageValue;
        attribute outputVoltage : VoltageValue;
        port signalIn : AnalogInputPort;
        port signalOut : AnalogOutputPort;

        action def filterSignal {
            in input : VoltageValue;
            in cutoff : FrequencyValue = cutoffFrequency;
            out output : VoltageValue;
        }

        perform filterSignal {
            in input = inputVoltage;
            in cutoff = cutoffFrequency;
            out output = outputVoltage;
        }

        flow signalIn.signal.voltage of VoltageValue = inputVoltage;
        flow signalOut.signal.voltage of VoltageValue = outputVoltage;
    }

    part def AnalogToDigitalConverter {
        attribute resolutionBits : Integer = 24;
        attribute referenceVoltage : VoltageValue = 5.0 [V];
        attribute samplingRate : FrequencyValue = 100 [Hz];
        attribute inputVoltage : VoltageValue;
        attribute outputCode : DigitalCode;
        port signalIn : AnalogInputPort;
        port sampleOut : DigitalOutputPort;

        action def convert {
            in input : VoltageValue;
            in refVoltage : VoltageValue = referenceVoltage;
            in bits : Integer = resolutionBits;
            out code : DigitalCode;
        }

        perform convert {
            in input = inputVoltage;
            in refVoltage = referenceVoltage;
            in bits = resolutionBits;
            out code = outputCode;
        }

        flow signalIn.signal.voltage of VoltageValue = inputVoltage;
        flow sampleOut.sample.code of DigitalCode = outputCode;
    }

    part def TemperatureSensor {
        attribute measuredTemperature : TemperatureValue = 293.15 [K];
        attribute accuracy : TemperatureValue = 0.5 [K];
        port tempOut : TemperatureOutputPort;

        action def measureTemperature {
            out temperature : TemperatureValue;
        }

        perform measureTemperature {
            out temperature = measuredTemperature;
        }

        flow tempOut.temperature of TemperatureValue = measuredTemperature;
    }

    part def MicroprocessorUnit {
        attribute calibration : CalibrationTable;
        attribute inputCode : DigitalCode;
        attribute currentTemperature : TemperatureValue;
        attribute correctedField : MagneticFluxDensityValue;
        attribute updateRate : FrequencyValue = 20 [Hz];
        port sampleIn : DigitalInputPort;
        port tempIn : TemperatureInputPort;
        port displayOut : DisplayOutputPort;

        action def processSample {
            in code : DigitalCode;
            in temperature : TemperatureValue;
            in calib : CalibrationTable;
            out field : MagneticFluxDensityValue;
        }

        action def applyCalibration {
            in code : DigitalCode;
            in calib : CalibrationTable;
            out rawField : MagneticFluxDensityValue;
        }

        action def compensateTemperature {
            in rawField : MagneticFluxDensityValue;
            in temperature : TemperatureValue;
            out compensatedField : MagneticFluxDensityValue;
        }

        perform processSample {
            in code = inputCode;
            in temperature = currentTemperature;
            in calib = calibration;
            out field = correctedField;

            then applyCalibration {
                in code = inputCode;
                in calib = calibration;
                out rawField;
            }

            then compensateTemperature {
                in rawField;
                in temperature = currentTemperature;
                out compensatedField = correctedField;
            }
        }

        flow sampleIn.sample.code of DigitalCode = inputCode;
        flow tempIn.temperature of TemperatureValue = currentTemperature;
        flow displayOut.message.numericValue of MagneticFluxDensityValue = correctedField;
    }

    part def DisplayInterface {
        attribute currentValue : MagneticFluxDensityValue;
        attribute unitLabel : String = "T";
        attribute refreshRate : FrequencyValue = 10 [Hz];
        port displayIn : DisplayOutputPort;

        state def DisplayBehavior {
            entry; then Idle;
            state Idle;
            transition from Idle to Updating
                when displayIn.message.numericValue changed;
            state Updating {
                entry { currentValue = displayIn.message.numericValue; }
                do { updateScreen(currentValue); }
            }
            transition from Updating to Idle
                when done;
        }

        action def updateScreen {
            in value : MagneticFluxDensityValue;
        }

        exhibit DisplayBehavior;
    }

    // ===== System Definition =====

    part def HallProbeMagnetometerSystem {
        attribute measurementRange :> Real[2] = [-2.0, 2.0];
        attribute maxAbsoluteError : MagneticFluxDensityValue = 0.001 [T];
        attribute resolution : MagneticFluxDensityValue = 0.0001 [T];
        attribute updateRate : FrequencyValue = 20 [Hz];
        attribute temperatureCompensationEnabled : Boolean = true;

        part biasCurrentSource : BiasCurrentSource;
        part hallElement : HallElement;
        part amplifier : SignalAmplifier;
        part filter : NoiseFilter;
        part adc : AnalogToDigitalConverter;
        part temperatureSensor : TemperatureSensor;
        part mpu : MicroprocessorUnit;
        part display : DisplayInterface;

        // External magnetic field input
        port externalField : MagneticFieldPort;

        // Connections
        connection biasCurrentSource.currentOut to hallElement.currentIn;
        connection externalField to hallElement.fieldIn;
        connection hallElement.voltageOut to amplifier.signalIn;
        connection amplifier.signalOut to filter.signalIn;
        connection filter.signalOut to adc.signalIn;
        connection adc.sampleOut to mpu.sampleIn;
        connection temperatureSensor.tempOut to mpu.tempIn;
        connection mpu.displayOut to display.displayIn;

        // System-level state machine
        state def OperatingMode {
            entry; then PowerUp;
            state PowerUp {
                entry { initializeComponents(); }
                do { performSelfTest(); }
            }
            transition from PowerUp to Measuring
                when selfTestPassed;
            state Measuring {
                do { continuouslyMeasure(); }
            }
            transition from Measuring to Calibrating
                when calibrationRequested;
            state Calibrating {
                do { runCalibrationSequence(); }
            }
            transition from Calibrating to Measuring
                when calibrationComplete;
            transition from Measuring to Shutdown
                when powerOffRequested;
            state Shutdown {
                entry { safeShutdown(); }
            }
        }

        action def initializeComponents;
        action def performSelfTest {
            out result : Boolean;
        }
        action def continuouslyMeasure;
        action def runCalibrationSequence;
        action def safeShutdown;

        attribute selfTestPassed : Boolean;
        attribute calibrationRequested : Boolean;
        attribute calibrationComplete : Boolean;
        attribute powerOffRequested : Boolean;

        exhibit OperatingMode;

        satisfy MeasurementRangeRequirement;
        satisfy AccuracyRequirement;
        satisfy ResolutionRequirement;
        satisfy TemperatureCompensationRequirement;
        satisfy ContinuousOperationRequirement;
    }

    // ===== Top-level instance =====

    part magnetometerInstance : HallProbeMagnetometerSystem {
        attribute serialNumber : String = "HPM-2024-001";
        attribute firmwareVersion : String = "1.2.0";
    }

}
