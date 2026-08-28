package MagneticSensingUnit {
    private import ScalarValues::*;

    attribute def MagneticFluxDensityValue : Real;
    attribute def TemperatureValue : Real;
    attribute def VoltageValue : Real;
    attribute def CurrentValue : Real;

    item def AnalogVoltage {
        attribute value : Real;
        attribute noise : Real;
    }

    item def DigitalSample {
        attribute value : Real;
        attribute resolution : Real;
    }

    item def MagneticFieldReading {
        attribute fieldStrength : MagneticFluxDensityValue;
        attribute uncertainty : MagneticFluxDensityValue;
        attribute timestamp : Real;
    }

    item def HealthStatus {
        attribute nominal : Boolean;
        attribute faultCode : Integer;
        attribute temperature : TemperatureValue;
    }

    item def ElectricalPower {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
    }

    item def CalibrationTable {
        attribute gain : Real := 1.0;
        attribute offset : MagneticFluxDensityValue := 0.0;
        attribute referenceTemp : TemperatureValue := 298.15;
        attribute tempCoeff : Real := 0.0001;
    }

    attribute def PowerOnSignal;
    attribute def MeasureCommand;
    attribute def FaultDetected;
    attribute def ShutdownSignal;

    action def PerformSelfTest;
    action def PerformCalibration;
    action def MeasureField;
    action def ProcessData;
    action def ReportResult;
    action def AttemptRecovery;
    action def PerformSafeShutdown;

    action performSelfTest : PerformSelfTest;
    action performCalibration : PerformCalibration;
    action measureField : MeasureField;
    action processData : ProcessData;
    action reportResult : ReportResult;
    action attemptRecovery : AttemptRecovery;
    action performSafeShutdown : PerformSafeShutdown;

    port def ElectricalPowerInPort {
        in item power : ElectricalPower;
    }
    port def ElectricalPowerOutPort {
        out item power : ElectricalPower;
    }
    port def AnalogVoltageInPort {
        in item signal : AnalogVoltage;
    }
    port def AnalogVoltageOutPort {
        out item signal : AnalogVoltage;
    }
    port def DigitalSampleInPort {
        in item sample : DigitalSample;
    }
    port def DigitalSampleOutPort {
        out item sample : DigitalSample;
    }
    port def MagneticFluxDensityInPort {
        in item field : MagneticFluxDensityValue;
    }
    port def MagneticFieldReadingOutPort {
        out item reading : MagneticFieldReading;
    }
    port def HealthStatusOutPort {
        out item status : HealthStatus;
    }

    part def HallEffectSensor {
        in port powerIn : ElectricalPowerInPort;
        in port fieldIn : MagneticFluxDensityInPort;
        out port signalOut : AnalogVoltageOutPort;
        attribute sensitivity : Real := 0.005;

        action sense {
            in field : MagneticFluxDensityValue;
            out raw : AnalogVoltage;
            assign raw.value := sensitivity * field;
            assign raw.noise := 0.001;
        }
    }

    part def SignalConditioner {
        in port powerIn : ElectricalPowerInPort;
        in port signalIn : AnalogVoltageInPort;
        out port signalOut : AnalogVoltageOutPort;
        attribute gain : Real := 100.0;
        attribute filterFactor : Real := 0.1;

        action condition {
            in raw : AnalogVoltage;
            out conditioned : AnalogVoltage;
            assign conditioned.value := raw.value * gain;
            assign conditioned.noise := raw.noise * filterFactor;
        }
    }

    part def AnalogToDigitalConverter {
        in port powerIn : ElectricalPowerInPort;
        in port analogIn : AnalogVoltageInPort;
        out port digitalOut : DigitalSampleOutPort;
        attribute resolutionBits : Real := 1024.0;
        attribute referenceVoltage : VoltageValue := 3.3;

        action convert {
            in analog : AnalogVoltage;
            out digital : DigitalSample;
            assign digital.value := analog.value * resolutionBits / referenceVoltage;
            assign digital.resolution := resolutionBits;
        }
    }

    part def Microcontroller {
        in port powerIn : ElectricalPowerInPort;
        in port digitalIn : DigitalSampleInPort;
        out port readingOut : MagneticFieldReadingOutPort;
        out port healthOut : HealthStatusOutPort;
        attribute calibrationTable : CalibrationTable;
        attribute temperature : TemperatureValue := 298.15;

        action process {
            in sample : DigitalSample;
            in temp : TemperatureValue;
            in time : Real;
            out reading : MagneticFieldReading;
            attribute corrected : Real;
            assign corrected := ((sample.value * calibrationTable.gain) + calibrationTable.offset)
                * (1.0 + calibrationTable.tempCoeff * (temp - calibrationTable.referenceTemp));
            assign reading.fieldStrength := corrected;
            assign reading.uncertainty := 0.01 * corrected;
            assign reading.timestamp := time;
        }

        action selfTest {
            out ok : Boolean;
            assign ok := true;
        }

        action calibrate {
            out done : Boolean;
            assign done := true;
        }
    }

    part def PowerSupply {
        out port powerOut : ElectricalPowerOutPort;
        attribute nominalVoltage : VoltageValue := 3.3;
        attribute maxCurrent : CurrentValue := 0.5;

        action regulate {
            out power : ElectricalPower;
            assign power.voltage := nominalVoltage;
            assign power.current := maxCurrent;
        }
    }

    state def MSULifecycle {
        entry; then off;

        state off;
        accept PowerOnSignal then selfTest;

        state selfTest {
            do performSelfTest;
        }
        then calibrate;

        state calibrate {
            do performCalibration;
        }
        then idle;

        state idle;
        accept MeasureCommand then measuring;
        accept FaultDetected then faultHandling;
        accept ShutdownSignal then safeShutdown;

        state measuring {
            do measureField;
        }
        then processing;

        state processing {
            do processData;
        }
        then reporting;

        state reporting {
            do reportResult;
        }
        then idle;

        state faultHandling {
            do attemptRecovery;
        }
        accept ShutdownSignal then safeShutdown;
        then idle;

        state safeShutdown {
            do performSafeShutdown;
        }
    }

    part def MagneticSensingUnit {
        in port fieldInput : MagneticFluxDensityInPort;
        out port measurementOut : MagneticFieldReadingOutPort;
        out port healthStatusOut : HealthStatusOutPort;

        part powerSupply : PowerSupply;
        part hallSensor : HallEffectSensor;
        part conditioner : SignalConditioner;
        part adc : AnalogToDigitalConverter;
        part microcontroller : Microcontroller;

        binding fieldInput to hallSensor.fieldIn;
        connect powerSupply.powerOut to hallSensor.powerIn;
        connect powerSupply.powerOut to conditioner.powerIn;
        connect powerSupply.powerOut to adc.powerIn;
        connect powerSupply.powerOut to microcontroller.powerIn;
        connect hallSensor.signalOut to conditioner.signalIn;
        connect conditioner.signalOut to adc.analogIn;
        connect adc.digitalOut to microcontroller.digitalIn;
        binding microcontroller.readingOut to measurementOut;
        binding microcontroller.healthOut to healthStatusOut;

        exhibit state lifecycle : MSULifecycle;
    }

    requirement def MeasurementAccuracy {
        subject unit : MagneticSensingUnit;
        doc /* The Magnetic Sensing Unit shall measure magnetic field strength with a maximum uncertainty of 0.01 T. */
    }

    requirement def PowerUpSelfTest {
        subject unit : MagneticSensingUnit;
        doc /* The unit shall perform a self-test and automatic calibration upon power-up before entering normal operation. */
    }

    requirement def FaultHandlingCapability {
        subject unit : MagneticSensingUnit;
        doc /* The unit shall detect faults, attempt recovery, and perform a safe shutdown upon critical failure. */
    }
}
