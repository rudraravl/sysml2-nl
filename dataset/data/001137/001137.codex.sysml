package MagneticSensingUnitModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def MagneticFluxDensity :> ISQ::magneticFluxDensity {
        unit = "T";
    }

    attribute def MagneticFieldStrength :> ISQ::magneticFieldStrength {
        unit = "A/m";
    }

    attribute def ElectricVoltage :> ISQ::electricPotential {
        unit = "V";
    }

    attribute def ElectricCurrent :> ISQ::electricCurrent {
        unit = "A";
    }

    attribute def Temperature :> ISQ::thermodynamicTemperature {
        unit = "K";
    }

    attribute def TimeDuration :> ISQ::time {
        unit = "s";
    }

    attribute def Frequency :> ISQ::frequency {
        unit = "Hz";
    }

    attribute def DigitalCount :> ScalarValues::Integer;

    attribute def Percent :> ScalarValues::Real {
        unit = "%";
    }

    item def MagneticFieldSignal {
        attribute fluxDensity : MagneticFluxDensity;
        attribute fieldStrength : MagneticFieldStrength;
        attribute timestamp : TimeDuration;
    }

    item def AnalogSensorSignal {
        attribute voltage : ElectricVoltage;
        attribute noiseRms : ElectricVoltage;
        attribute timestamp : TimeDuration;
    }

    item def DigitalSample {
        attribute rawCount : DigitalCount;
        attribute convertedFluxDensity : MagneticFluxDensity;
        attribute temperature : Temperature;
        attribute valid : Boolean;
        attribute timestamp : TimeDuration;
    }

    item def CalibratedMeasurement {
        attribute fluxDensity : MagneticFluxDensity;
        attribute uncertainty : MagneticFluxDensity;
        attribute confidence : Percent;
        attribute timestamp : TimeDuration;
    }

    item def Power {
        attribute voltage : ElectricVoltage;
        attribute currentLimit : ElectricCurrent;
    }

    item def DiagnosticStatus {
        attribute sensorConnected : Boolean;
        attribute adcHealthy : Boolean;
        attribute calibrationValid : Boolean;
        attribute temperatureInRange : Boolean;
        attribute faultCode : DigitalCount;
    }

    port def MagneticFieldInputPort {
        in item field : MagneticFieldSignal;
    }

    port def AnalogSignalPort {
        out item analogSignal : AnalogSensorSignal;
    }

    port def AnalogInputPort {
        in item analogSignal : AnalogSensorSignal;
    }

    port def DigitalSamplePort {
        out item sample : DigitalSample;
    }

    port def DigitalSampleInputPort {
        in item sample : DigitalSample;
    }

    port def MeasurementOutputPort {
        out item measurement : CalibratedMeasurement;
    }

    port def PowerInputPort {
        in item supply : Power;
    }

    port def DiagnosticOutputPort {
        out item status : DiagnosticStatus;
    }

    part def MagneticSensor {
        attribute sensitivity : Real = 0.045;
        attribute offsetVoltage : ElectricVoltage = 2.500 [V];
        attribute fullScaleRange : MagneticFluxDensity = 0.200 [T];
        attribute bandwidth : Frequency = 1000 [Hz];
        attribute operatingTemperatureMin : Temperature = 233.15 [K];
        attribute operatingTemperatureMax : Temperature = 398.15 [K];

        port magneticFieldIn : MagneticFieldInputPort;
        port analogOut : AnalogSignalPort;
        port powerIn : PowerInputPort;

        action convertMagneticFieldToVoltage {
            in item field : MagneticFieldSignal;
            out item analogSignal : AnalogSensorSignal;

            first start;
            then computeVoltage;
            then emitAnalogSignal;
            then done;

            action computeVoltage {
                in item field : MagneticFieldSignal;
                out attribute voltage : ElectricVoltage;
            }
        }
    }

    part def SignalConditioner {
        attribute gain : Real = 2.0;
        attribute lowPassCutoff : Frequency = 500 [Hz];
        attribute outputOffset : ElectricVoltage = 0.000 [V];

        port analogIn : AnalogInputPort;
        port conditionedOut : AnalogSignalPort;
        port powerIn : PowerInputPort;

        action filterAndAmplify {
            in item analogSignal : AnalogSensorSignal;
            out item conditionedSignal : AnalogSensorSignal;

            first receiveSignal;
            then applyLowPassFilter;
            then applyGain;
            then outputConditionedSignal;
            then done;
        }
    }

    part def AnalogToDigitalConverter {
        attribute resolutionBits : DigitalCount = 16;
        attribute referenceVoltage : ElectricVoltage = 3.300 [V];
        attribute samplingRate : Frequency = 2000 [Hz];
        attribute conversionLatency : TimeDuration = 0.0005 [s];

        port analogIn : AnalogInputPort;
        port sampleOut : DigitalSamplePort;
        port powerIn : PowerInputPort;

        action sampleAnalogVoltage {
            in item analogSignal : AnalogSensorSignal;
            out item digitalSample : DigitalSample;

            first acquire;
            then quantize;
            then assignTimestamp;
            then publishSample;
            then done;
        }
    }

    part def TemperatureSensor {
        attribute accuracy : Temperature = 1.0 [K];
        attribute sampleRate : Frequency = 10 [Hz];

        port powerIn : PowerInputPort;
        port sampleOut : DigitalSamplePort;

        action measureLocalTemperature {
            out item temperatureSample : DigitalSample;

            first sampleDieTemperature;
            then publishTemperature;
            then done;
        }
    }

    part def CalibrationProcessor {
        attribute offsetCorrection : MagneticFluxDensity = 0.000 [T];
        attribute scaleCorrection : Real = 1.000;
        attribute linearityErrorMax : Percent = 0.5 [%];
        attribute calibrationAgeLimit : TimeDuration = 31536000 [s];

        port rawSampleIn : DigitalSampleInputPort;
        port measurementOut : MeasurementOutputPort;
        port diagnosticOut : DiagnosticOutputPort;
        port powerIn : PowerInputPort;

        action calibrateMeasurement {
            in item sample : DigitalSample;
            out item measurement : CalibratedMeasurement;

            first validateSample;
            then subtractOffset;
            then applyScaleCorrection;
            then estimateUncertainty;
            then publishMeasurement;
            then done;
        }

        state def CalibrationProcessorStates {
            entry action initializeCalibration;
            state Uninitialized;
            state Ready;
            state Calibrating;
            state Faulted;

            transition first Uninitialized;
            transition Uninitialized_to_Ready
                first Uninitialized
                then Ready
                if calibrationDataLoaded;

            transition Ready_to_Calibrating
                first Ready
                then Calibrating
                if calibrationRequested;

            transition Calibrating_to_Ready
                first Calibrating
                then Ready
                if calibrationCompleted;

            transition Ready_to_Faulted
                first Ready
                then Faulted
                if calibrationInvalid;

            transition Faulted_to_Ready
                first Faulted
                then Ready
                if calibrationRestored;
        }
    }

    part def PowerRegulator {
        attribute inputVoltageNominal : ElectricVoltage = 12.000 [V];
        attribute regulatedVoltage : ElectricVoltage = 3.300 [V];
        attribute currentLimit : ElectricCurrent = 0.100 [A];
        attribute rippleMax : ElectricVoltage = 0.010 [V];

        port systemPowerIn : PowerInputPort;
        port sensorPowerOut : PowerInputPort;
        port electronicsPowerOut : PowerInputPort;

        action regulatePower {
            in item supply : Power;
            out item regulatedSupply : Power;

            first receiveInputPower;
            then rejectRipple;
            then limitCurrent;
            then distributeRegulatedPower;
            then done;
        }
    }

    part def MagneticSensingUnit {
        attribute measurementRange : MagneticFluxDensity = 0.200 [T];
        attribute measurementAccuracy : MagneticFluxDensity = 0.001 [T];
        attribute responseTime : TimeDuration = 0.010 [s];
        attribute outputRate : Frequency = 100 [Hz];

        port magneticFieldIn : MagneticFieldInputPort;
        port powerIn : PowerInputPort;
        port measurementOut : MeasurementOutputPort;
        port diagnosticOut : DiagnosticOutputPort;

        part sensor : MagneticSensor;
        part conditioner : SignalConditioner;
        part adc : AnalogToDigitalConverter;
        part temperatureSensor : TemperatureSensor;
        part processor : CalibrationProcessor;
        part powerRegulator : PowerRegulator;

        connect magneticFieldIn to sensor.magneticFieldIn;
        connect powerIn to powerRegulator.systemPowerIn;
        connect powerRegulator.sensorPowerOut to sensor.powerIn;
        connect powerRegulator.electronicsPowerOut to conditioner.powerIn;
        connect powerRegulator.electronicsPowerOut to adc.powerIn;
        connect powerRegulator.electronicsPowerOut to temperatureSensor.powerIn;
        connect powerRegulator.electronicsPowerOut to processor.powerIn;
        connect sensor.analogOut to conditioner.analogIn;
        connect conditioner.conditionedOut to adc.analogIn;
        connect adc.sampleOut to processor.rawSampleIn;
        connect processor.measurementOut to measurementOut;
        connect processor.diagnosticOut to diagnosticOut;

        action performMeasurementCycle {
            in item field : MagneticFieldSignal;
            out item measurement : CalibratedMeasurement;
            out item status : DiagnosticStatus;

            first powerStabilization;
            then acquireMagneticField;
            then conditionSensorSignal;
            then convertToDigitalSample;
            then compensateForTemperature;
            then calibrateAndValidate;
            then publishMeasurementAndStatus;
            then done;
        }

        state def OperatingStates {
            state Off;
            state PowerUp;
            state SelfTest;
            state Measuring;
            state Degraded;
            state Fault;

            transition first Off;

            transition Off_to_PowerUp
                first Off
                then PowerUp
                if supplyVoltagePresent;

            transition PowerUp_to_SelfTest
                first PowerUp
                then SelfTest
                if regulatedPowerStable;

            transition SelfTest_to_Measuring
                first SelfTest
                then Measuring
                if selfTestPassed;

            transition SelfTest_to_Fault
                first SelfTest
                then Fault
                if selfTestFailed;

            transition Measuring_to_Degraded
                first Measuring
                then Degraded
                if temperatureWarning or calibrationNearExpiry;

            transition Degraded_to_Measuring
                first Degraded
                then Measuring
                if temperatureNominal and calibrationCurrent;

            transition Measuring_to_Fault
                first Measuring
                then Fault
                if sensorDisconnected or adcFault or supplyOutOfRange;

            transition Fault_to_SelfTest
                first Fault
                then SelfTest
                if resetCommanded;

            transition Measuring_to_Off
                first Measuring
                then Off
                if supplyVoltageAbsent;
        }
    }

    requirement def MeasureMagneticFieldRequirement {
        subject sensingUnit : MagneticSensingUnit;
        doc /* The sensing unit shall measure magnetic flux density using a magnetic sensor and provide a calibrated digital measurement. */
        require constraint {
            sensingUnit.measurementRange >= 0.200 [T]
        }
    }

    requirement def AccuracyRequirement {
        subject sensingUnit : MagneticSensingUnit;
        doc /* The sensing unit shall provide magnetic flux density measurements with maximum absolute error no greater than 0.001 tesla over the specified measurement range. */
        require constraint {
            sensingUnit.measurementAccuracy <= 0.001 [T]
        }
    }

    requirement def ResponseTimeRequirement {
        subject sensingUnit : MagneticSensingUnit;
        doc /* The sensing unit shall publish a valid calibrated measurement within 0.010 seconds after a magnetic field sample is acquired. */
        require constraint {
            sensingUnit.responseTime <= 0.010 [s]
        }
    }

    requirement def OutputRateRequirement {
        subject sensingUnit : MagneticSensingUnit;
        doc /* The sensing unit shall output calibrated measurements at a rate of at least 100 hertz during normal measuring operation. */
        require constraint {
            sensingUnit.outputRate >= 100 [Hz]
        }
    }

    requirement def MagneticSensorUsageRequirement {
        subject sensingUnit : MagneticSensingUnit;
        doc /* The sensing unit shall include a magnetic sensor as the primary sensing element. */
        require constraint {
            sensingUnit.sensor.fullScaleRange >= sensingUnit.measurementRange
        }
    }

    requirement def DiagnosticRequirement {
        subject sensingUnit : MagneticSensingUnit;
        doc /* The sensing unit shall report diagnostic status for sensor connectivity, converter health, calibration validity, and temperature range. */
    }

    satisfy MeasureMagneticFieldRequirement by MagneticSensingUnit;
    satisfy AccuracyRequirement by MagneticSensingUnit;
    satisfy ResponseTimeRequirement by MagneticSensingUnit;
    satisfy OutputRateRequirement by MagneticSensingUnit;
    satisfy MagneticSensorUsageRequirement by MagneticSensingUnit;
    satisfy DiagnosticRequirement by MagneticSensingUnit;

    part magneticSensingUnit : MagneticSensingUnit;

}