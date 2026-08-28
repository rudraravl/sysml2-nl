package MagneticSensingUnit {
    import SI::*;
    import ScalarValues::*;

    // ===== Value Types =====
    value type MagneticFieldStrength :> Real { unit 'T'; }
    value type Voltage :> Real { unit 'V'; }
    value type Current :> Real { unit 'A'; }
    value type Temperature :> Real { unit '°C'; }
    value type Power :> Real { unit 'W'; }
    value type Frequency :> Real { unit 'Hz'; }
    value type TimeValue :> Real { unit 's'; }
    value type DigitalCode :> Integer;
    value type UncertaintyValue :> Real { unit 'T'; }
    value type GainFactor :> Real;
    value type SNR :> Real { unit 'dB'; }
    value type Sensitivity :> Real { unit 'V/T'; }
    value type Resistance :> Real { unit 'Ω'; }

    // ===== Item Definitions =====
    item def RawAnalogSignal {
        attribute voltage : Voltage;
        attribute noiseLevel : Voltage;
    }

    item def ConditionedAnalogSignal {
        attribute voltage : Voltage;
        attribute snr : SNR;
    }

    item def DigitalSample {
        attribute code : DigitalCode;
        attribute timestamp : TimeValue;
    }

    item def CalibrationEntry {
        attribute rawCode : DigitalCode;
        attribute correctedField : MagneticFieldStrength;
        attribute refTemp : Temperature;
    }

    item def CalibrationTable {
        attribute entries : CalibrationEntry[0..*];
        attribute validUntil : TimeValue;
    }

    item def CalibratedMeasurement {
        attribute fieldStrength : MagneticFieldStrength;
        attribute uncertainty : UncertaintyValue;
        attribute temperature : Temperature;
        attribute timestamp : TimeValue;
    }

    item def StatusReport {
        attribute status : String;
        attribute errorCode : Integer;
        attribute timestamp : TimeValue;
    }

    item def CommandMessage {
        attribute commandId : Integer;
        attribute payload : String;
    }

    // ===== Port Definitions =====
    port def MagneticFieldPort {
        out fieldStrength : MagneticFieldStrength;
        out ambientTemp : Temperature;
    }

    port def RawAnalogPort {
        out signal : RawAnalogSignal;
    }

    port def ConditionedAnalogPort {
        out signal : ConditionedAnalogSignal;
    }

    port def DigitalDataPort {
        out sample : DigitalSample;
    }

    port def MeasurementPort {
        out measurement : CalibratedMeasurement;
        out status : StatusReport;
        in command : CommandMessage;
    }

    port def PowerPort {
        out supplyVoltage : Voltage;
        out supplyCurrent : Current;
    }

    // ===== Part: Hall Effect Sensor =====
    part def HallEffectSensor {
        port magneticIn : ~MagneticFieldPort;
        port analogOut : RawAnalogPort;
        port powerIn : ~PowerPort;

        attribute sensitivity : Sensitivity = 0.025;
        attribute zeroFieldOffset : Voltage = 1.25;
        attribute minOperatingTemp : Temperature = -40;
        attribute maxOperatingTemp : Temperature = 125;
        attribute linearRange : MagneticFieldStrength = 0.1;
        attribute supplyVoltage : Voltage = 5.0;

        action def SenseField {
            in field : MagneticFieldStrength;
            in temp : Temperature;
            out signal : RawAnalogSignal;
        }

        action def Update {
            in field : MagneticFieldStrength;
            in temp : Temperature;
            out signal : RawAnalogSignal;
            perform SenseField;
        }
    }

    // ===== Part: Signal Conditioner =====
    part def SignalConditioner {
        port analogIn : ~RawAnalogPort;
        port analogOut : ConditionedAnalogPort;
        port powerIn : ~PowerPort;

        attribute gain : GainFactor = 100.0;
        attribute cutoffFreq : Frequency = 1000;
        attribute filterOrder : Integer = 4;
        attribute inputImpedance : Resistance = 1000000;
        attribute outputImpedance : Resistance = 50;

        action def Amplify {
            in raw : RawAnalogSignal;
            out amplified : RawAnalogSignal;
        }

        action def LowPassFilter {
            in noisy : RawAnalogSignal;
            out clean : ConditionedAnalogSignal;
        }

        action def Condition {
            in raw : RawAnalogSignal;
            out conditioned : ConditionedAnalogSignal;
            perform Amplify;
            perform LowPassFilter;
        }
    }

    // ===== Part: Analog-to-Digital Converter =====
    part def AnalogToDigitalConverter {
        port analogIn : ~ConditionedAnalogPort;
        port digitalOut : DigitalDataPort;
        port powerIn : ~PowerPort;

        attribute resolution : Integer = 16;
        attribute sampleRate : Frequency = 1000;
        attribute refVoltage : Voltage = 5.0;
        attribute lsbVoltage : Voltage = 0.000076;
        attribute conversionTime : TimeValue = 0.0001;

        action def Sample {
            in analog : ConditionedAnalogSignal;
            out digital : DigitalSample;
        }

        action def Convert {
            in analog : ConditionedAnalogSignal;
            out digital : DigitalSample;
            perform Sample;
        }
    }

    // ===== Part: Microcontroller =====
    part def Microcontroller {
        port digitalIn : ~DigitalDataPort;
        port measurementOut : MeasurementPort;
        port powerIn : ~PowerPort;

        attribute clockSpeed : Frequency = 16000000;
        attribute memorySize : Integer = 65536;
        attribute calibrationTable : CalibrationTable;
        attribute currentTemperature : Temperature;
        attribute firmwareVersion : String = "2.1.0";
        attribute selfTestPassed : Boolean = false;
        attribute calibrationDone : Boolean = false;
        attribute commandReceived : Boolean = false;
        attribute sampleReady : Boolean = false;
        attribute measurementComputed : Boolean = false;
        attribute reportSent : Boolean = false;
        attribute faultDetected : Boolean = false;
        attribute recoverySuccessful : Boolean = false;
        attribute criticalFailure : Boolean = false;
        attribute errorCount : Integer = 0;
        attribute maxErrors : Integer = 5;

        action def ApplyCalibration {
            in raw : DigitalSample;
            in table : CalibrationTable;
            in temp : Temperature;
            out measurement : CalibratedMeasurement;
        }

        action def ComputeUncertainty {
            in measurement : CalibratedMeasurement;
            out uncertainty : UncertaintyValue;
        }

        action def ProcessData {
            in sample : DigitalSample;
            out measurement : CalibratedMeasurement;
            perform ApplyCalibration;
            perform ComputeUncertainty;
        }

        action def GenerateStatus {
            in measurement : CalibratedMeasurement;
            out status : StatusReport;
        }

        action def Report {
            in measurement : CalibratedMeasurement;
            in status : StatusReport;
        }

        action def SelfTest {
            out passed : Boolean;
        }

        action def AutoCalibrate {
            out table : CalibrationTable;
        }

        action def ErrorRecovery {
            out recovered : Boolean;
        }

        action def SafeShutdownProcedure {
        }

        action def WaitForCommand {
        }

        action def AcquireSamples {
        }

        state def OperationalStates {
            state Initializing {
                entry action { perform SelfTest; }
                do action { perform AutoCalibrate; }
            }

            state Idle {
                entry action { perform WaitForCommand; }
            }

            state Measuring {
                entry action { perform AcquireSamples; }
                do action { perform AcquireSamples; }
            }

            state Processing {
                entry action { perform ProcessData; }
                do action { perform GenerateStatus; }
            }

            state Reporting {
                entry action { perform Report; }
            }

            state ErrorHandling {
                entry action { /* log error code */ }
                do action { perform ErrorRecovery; }
            }

            state SafeShutdown {
                entry action { perform SafeShutdownProcedure; }
            }

            transition Initializing -> Idle
                if { selfTestPassed and calibrationDone };

            transition Idle -> Measuring
                if { commandReceived };

            transition Measuring -> Processing
                if { sampleReady };

            transition Processing -> Reporting
                if { measurementComputed };

            transition Reporting -> Idle
                if { reportSent };

            transition any -> ErrorHandling
                if { faultDetected };

            transition ErrorHandling -> Idle
                if { recoverySuccessful };

            transition ErrorHandling -> SafeShutdown
                if { criticalFailure };
        }

        exhibit OperationalStates;
    }

    // ===== Part: Power Supply =====
    part def PowerSupply {
        port powerIn : ~PowerPort;
        port powerOut : PowerPort;

        attribute outputVoltage : Voltage = 5.0;
        attribute maxCurrent : Current = 2.0;
        attribute efficiency : Real = 0.9;
        attribute rippleVoltage : Voltage = 0.05;
        attribute thermalShutdownTemp : Temperature = 150;

        action def Regulate {
            out voltage : Voltage;
            out current : Current;
        }

        action def MonitorThermal {
            out temp : Temperature;
        }
    }

    // ===== Top-level Assembly: Magnetic Sensing Unit =====
    part def MagneticSensingUnit {
        port externalMagneticInput : MagneticFieldPort;
        port externalOutput : ~MeasurementPort;
        port externalPower : PowerPort;

        part hallSensor : HallEffectSensor;
        part conditioner : SignalConditioner;
        part adc : AnalogToDigitalConverter;
        part controller : Microcontroller;
        part powerSupply : PowerSupply;

        // Signal chain connections
        connect externalMagneticInput to hallSensor.magneticIn;
        connect hallSensor.analogOut to conditioner.analogIn;
        connect conditioner.analogOut to adc.analogIn;
        connect adc.digitalOut to controller.digitalIn;
        connect controller.measurementOut to externalOutput;

        // External power input
        connect externalPower to powerSupply.powerIn;

        // Power distribution to all internal components
        connect powerSupply.powerOut to hallSensor.powerIn;
        connect powerSupply.powerOut to conditioner.powerIn;
        connect powerSupply.powerOut to adc.powerIn;
        connect powerSupply.powerOut to controller.powerIn;
    }

    // ===== Requirement Definitions =====
    requirement def MeasurementAccuracyRequirement {
        doc /* The sensor shall measure magnetic field strength with accuracy better than 0.1 mT over the range 0 to 100 mT. */
        subject sensor : MagneticSensingUnit;
        attribute accuracyThreshold : MagneticFieldStrength = 0.0001;
        attribute measurementRange : MagneticFieldStrength = 0.1;
    }

    requirement def ResponseTimeRequirement {
        doc /* The sensor shall report a measurement within 10 ms of a detected field change. */
        subject sensor : MagneticSensingUnit;
        attribute maxResponseTime : TimeValue = 0.01;
    }

    requirement def SelfTestRequirement {
        doc /* The sensor shall perform a self-test and automatic calibration routine upon power-up before entering normal operation. */
        subject sensor : MagneticSensingUnit;
    }

    requirement def ErrorHandlingRequirement {
        doc /* The sensor shall detect operational faults, attempt recovery, and perform a safe shutdown upon critical failure. */
        subject sensor : MagneticSensingUnit;
    }

    requirement def PowerRequirement {
        doc /* The sensor shall operate from a single external 5V power supply drawing less than 1W total. */
        subject sensor : MagneticSensingUnit;
        attribute supplyVoltage : Voltage = 5.0;
        attribute maxPower : Power = 1.0;
    }

    requirement def TemperatureCompensationRequirement {
        doc /* The sensor shall compensate for operating temperature variations from -40 to 125 degrees Celsius using stored calibration data. */
        subject sensor : MagneticSensingUnit;
        attribute minTemp : Temperature = -40;
        attribute maxTemp : Temperature = 125;
    }

    requirement def UncertaintyReportingRequirement {
        doc /* Each reported measurement shall include a calibrated field strength value, an uncertainty value, and a timestamp. */
        subject sensor : MagneticSensingUnit;
    }

    requirement def CalibrationRequirement {
        doc /* The sensor shall use a stored calibration table to correct raw measurements for known sensor inaccuracies. */
        subject sensor : MagneticSensingUnit;
    }

    requirement def SignalConditioningRequirement {
        doc /* The raw Hall sensor signal shall be amplified and filtered before analog-to-digital conversion. */
        subject sensor : MagneticSensingUnit;
    }

    requirement def LifecycleRequirement {
        doc /* The sensor shall cycle through states of initialization, idle, measuring, processing, and reporting during normal operation. */
        subject sensor : MagneticSensingUnit;
    }

    // ===== Requirement Usages =====
    requirement MeasurementAccuracyReq : MeasurementAccuracyRequirement {
        subject :>> sensor;
    }

    requirement ResponseTimeReq : ResponseTimeRequirement {
        subject :>> sensor;
    }

    requirement SelfTestReq : SelfTestRequirement {
        subject :>> sensor;
    }

    requirement ErrorHandlingReq : ErrorHandlingRequirement {
        subject :>> sensor;
    }

    requirement PowerReq : PowerRequirement {
        subject :>> sensor;
    }

    requirement TemperatureCompensationReq : TemperatureCompensationRequirement {
        subject :>> sensor;
    }

    requirement UncertaintyReportingReq : UncertaintyReportingRequirement {
        subject :>> sensor;
    }

    requirement CalibrationReq : CalibrationRequirement {
        subject :>> sensor;
    }

    requirement SignalConditioningReq : SignalConditioningRequirement {
        subject :>> sensor;
    }

    requirement LifecycleReq : LifecycleRequirement {
        subject :>> sensor;
    }

    // ===== Satisfaction Relationships =====
    satisfaction MeasurementAccuracyReq by hallSensor.sensitivity;
    satisfaction MeasurementAccuracyReq by controller.calibrationTable;
    satisfaction ResponseTimeReq by adc.sampleRate;
    satisfaction ResponseTimeReq by controller.clockSpeed;
    satisfaction SelfTestReq by controller.SelfTest;
    satisfaction SelfTestReq by controller.AutoCalibrate;
    satisfaction ErrorHandlingReq by controller.OperationalStates;
    satisfaction PowerReq by powerSupply.outputVoltage;
    satisfaction PowerReq by powerSupply.maxCurrent;
    satisfaction TemperatureCompensationReq by controller.ApplyCalibration;
    satisfaction UncertaintyReportingReq by controller.ProcessData;
    satisfaction UncertaintyReportingReq by controller.GenerateStatus;
    satisfaction CalibrationReq by controller.calibrationTable;
    satisfaction CalibrationReq by controller.ApplyCalibration;
    satisfaction SignalConditioningReq by conditioner.Condition;
    satisfaction LifecycleReq by controller.OperationalStates;
}
