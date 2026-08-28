package TactileSensingUnit {
    import ScalarValues::*;
    import ISQ::*;
    import ISQSpace::*;
    import ISQTime::*;
    import ISQThermodynamics::*;
    import ISQForce::*;
    import ISQPressure::*;

    // ---- Value types ----
    attribute def Voltage :> Real { unit 'V'; }
    attribute def DigitalCount :> Integer;
    attribute def ForceValue :> Real { unit 'N'; }
    attribute def PressureValue :> Real { unit 'Pa'; }
    attribute def TemperatureValue :> Real { unit 'K'; }
    attribute def AreaValue :> Real { unit 'm2'; }
    attribute def TimeStampValue :> Real { unit 's'; }
    attribute def CalibrationFactor :> Real;

    // ---- Item definitions ----
    item def AnalogSignal {
        attribute voltage : Voltage;
    }

    item def DigitalSample {
        attribute rawCount : DigitalCount;
        attribute sampledAt : TimeStampValue;
    }

    item def TactileMeasurement {
        attribute pressure : PressureValue;
        attribute force : ForceValue;
        attribute contactArea : AreaValue;
        attribute temperature : TemperatureValue;
        attribute timeStamp : TimeStampValue;
    }

    item def CalibrationParameters {
        attribute pressureOffset : PressureValue;
        attribute forceScale : CalibrationFactor;
        attribute temperatureOffset : TemperatureValue;
        attribute areaScale : CalibrationFactor;
    }

    // ---- Port definitions ----
    port def AnalogPort {
        out item : AnalogSignal;
    }

    port def DigitalSamplePort {
        out item : DigitalSample;
    }

    port def MeasurementPort {
        out item : TactileMeasurement;
    }

    port def CalibrationPort {
        in item params : CalibrationParameters;
    }

    // ---- Tactile Sensor ----
    part def TactileSensor {
        attribute sensitivity : CalibrationFactor = 0.45; // V/N
        attribute temperatureSensitivity : CalibrationFactor = 0.01; // V/K

        port rawOut : AnalogPort;
        port calibIn : CalibrationPort;

        action def GenerateSignal {
            in appliedForce : ForceValue;
            in ambientTemp : TemperatureValue;
            out signal : AnalogSignal;
        }

        action generate : GenerateSignal {
            in appliedForce : ForceValue;
            in ambientTemp : TemperatureValue;
            out signal : AnalogSignal;
        }
    }

    // ---- Signal Amplifier ----
    part def SignalAmplifier {
        attribute gain : CalibrationFactor = 100.0;
        attribute bandwidth : Real = 5000; // Hz

        port ampIn : AnalogPort { in item : AnalogSignal; }
        port ampOut : AnalogPort;

        action def Amplify {
            in input : AnalogSignal;
            out output : AnalogSignal;
        }

        action amplify : Amplify {
            in input : AnalogSignal;
            out output : AnalogSignal;
        }
    }

    // ---- ADC ----
    part def AnalogToDigitalConverter {
        attribute resolutionBits : Integer = 16;
        attribute samplingRate : Real = 1000; // samples/s
        attribute referenceVoltage : Voltage = 3.3;

        port adcIn : AnalogPort { in item : AnalogSignal; }
        port adcOut : DigitalSamplePort;

        action def Convert {
            in input : AnalogSignal;
            out sample : DigitalSample;
        }

        action convert : Convert {
            in input : AnalogSignal;
            out sample : DigitalSample;
        }
    }

    // ---- Signal Processor ----
    part def SignalProcessor {
        attribute pressureCalib : CalibrationFactor = 1.0;
        attribute forceCalib : CalibrationFactor = 1.0;
        attribute temperatureCalib : CalibrationFactor = 1.0;
        attribute filterCutoff : Real = 200; // Hz

        port procIn : DigitalSamplePort { in item : DigitalSample; }
        port procOut : MeasurementPort;
        port calibIn : CalibrationPort;

        action def Process {
            in sample : DigitalSample;
            in params : CalibrationParameters;
            out measurement : TactileMeasurement;
        }

        action process : Process {
            in sample : DigitalSample;
            in params : CalibrationParameters;
            out measurement : TactileMeasurement;
        }
    }

    // ---- Data Logger ----
    part def DataLogger {
        attribute storageCapacity : Integer = 100000;
        attribute recordCount : Integer = 0;

        port logIn : MeasurementPort { in item : TactileMeasurement; }

        action def LogMeasurement {
            in measurement : TactileMeasurement;
        }

        action log : LogMeasurement {
            in measurement : TactileMeasurement;
        }
    }

    // ---- System state machine ----
    state def TactileUnitStates {
        entry; then idle;

        state idle;
        state calibrating;
        state ready;
        state acquiring;
        state processing;
        state outputting;
        state error;

        transition idle_to_calibrating
            first idle
            accept CalibrateCommand
            then calibrating;

        transition calibrating_to_ready
            first calibrating
            accept CalibrationComplete
            then ready;

        transition ready_to_acquiring
            first ready
            accept TriggerCommand
            then acquiring;

        transition acquiring_to_processing
            first acquiring
            accept SampleAcquired
            then processing;

        transition processing_to_outputting
            first processing
            accept ProcessingComplete
            then outputting;

        transition outputting_to_ready
            first outputting
            accept OutputComplete
            then ready;

        transition any_to_error
            first idle, calibrating, ready, acquiring, processing, outputting
            accept FaultDetected
            then error;

        transition error_to_idle
            first error
            accept ResetCommand
            then idle;
    }

    // ---- Top-level Tactile Sensing Unit ----
    part def TactileSensingUnit {
        port externalOutput : MeasurementPort;
        port calibPort : CalibrationPort;
        port commandPort;

        part sensor : TactileSensor {
            port rawOut : AnalogPort;
            port calibIn : CalibrationPort;
        }

        part amplifier : SignalAmplifier {
            port ampIn : AnalogPort { in item : AnalogSignal; }
            port ampOut : AnalogPort;
        }

        part adc : AnalogToDigitalConverter {
            port adcIn : AnalogPort { in item : AnalogSignal; }
            port adcOut : DigitalSamplePort;
        }

        part processor : SignalProcessor {
            port procIn : DigitalSamplePort { in item : DigitalSample; }
            port procOut : MeasurementPort;
            port calibIn : CalibrationPort;
        }

        part logger : DataLogger {
            port logIn : MeasurementPort { in item : TactileMeasurement; }
        }

        // Connections
        connection sensorToAmplifier connect sensor.rawOut to amplifier.ampIn;
        connection amplifierToADC connect amplifier.ampOut to adc.adcIn;
        connection adcToProcessor connect adc.adcOut to processor.procIn;
        connection processorToExternal connect processor.procOut to externalOutput;
        connection processorToLogger connect processor.procOut to logger.logIn;
        connection calibToSensor connect calibPort to sensor.calibIn;
        connection calibToProcessor connect calibPort to processor.calibIn;

        // Behavior
        exhibit state behavior : TactileUnitStates;
    }

    // ---- Requirements ----
    requirement def MeasurementAccuracyRequirement {
        doc /* The tactile sensing unit shall measure pressure, force, contact area, and temperature with specified accuracy. */
        attribute pressureAccuracy : PressureValue = 500.0; // Pa
        attribute forceAccuracy : ForceValue = 0.05; // N
        attribute temperatureAccuracy : TemperatureValue = 0.5; // K
        attribute areaAccuracy : AreaValue = 0.0001; // m2
    }

    requirement def SamplingRateRequirement {
        doc /* The unit shall sample tactile data at a minimum rate of 1000 samples per second. */
        attribute minSamplingRate : Real = 1000; // samples/s
    }

    requirement def ResponseTimeRequirement {
        doc /* The unit shall complete a full measurement cycle within 10 milliseconds. */
        attribute maxCycleTime : TimeStampValue = 0.01; // s
    }

    requirement def StorageRequirement {
        doc /* The onboard data logger shall store at least 100000 measurement records. */
        attribute minStorage : Integer = 100000;
    }

    requirement def ReliabilityRequirement {
        doc /* The unit shall enter an error state upon detecting a fault and allow reset to idle. */
    }

    requirement def TactileSensingUnitRequirements {
        requirement accReq : MeasurementAccuracyRequirement;
        requirement rateReq : SamplingRateRequirement;
        requirement responseReq : ResponseTimeRequirement;
        requirement storageReq : StorageRequirement;
        requirement reliabilityReq : ReliabilityRequirement;
    }

    // ---- Verification actions ----
    action def VerifyAccuracy {
        in unit : TactileSensingUnit;
        in req : MeasurementAccuracyRequirement;
        out pass : Boolean;
    }

    action def VerifySamplingRate {
        in unit : TactileSensingUnit;
        in req : SamplingRateRequirement;
        out pass : Boolean;
    }

    action def VerifyResponseTime {
        in unit : TactileSensingUnit;
        in req : ResponseTimeRequirement;
        out pass : Boolean;
    }

    action def VerifyStorage {
        in unit : TactileSensingUnit;
        in req : StorageRequirement;
        out pass : Boolean;
    }

    // ---- Satisfy relationships ----
    satisfy TactileSensingUnitRequirements::accReq by TactileSensingUnit::sensor;
    satisfy TactileSensingUnitRequirements::rateReq by TactileSensingUnit::adc;
    satisfy TactileSensingUnitRequirements::responseReq by TactileSensingUnit;
    satisfy TactileSensingUnitRequirements::storageReq by TactileSensingUnit::logger;
    satisfy TactileSensingUnitRequirements::reliabilityReq by TactileSensingUnit;
}
