package SensingUnitModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def RealValue {
        attribute value : Real;
    }

    value def MeasurementUpdateRate : Real {
        unit = "Hz";
        quantityKind = "frequency";
    }

    value def TemperatureValue : Real {
        unit = "degC";
        quantityKind = "thermodynamic temperature";
    }

    value def VoltageValue : Real {
        unit = "V";
        quantityKind = "electric potential";
    }

    value def CurrentValue : Real {
        unit = "mA";
        quantityKind = "electric current";
    }

    value def TimeValue : Real {
        unit = "s";
        quantityKind = "time";
    }

    value def PercentValue : Real {
        unit = "%";
        quantityKind = "ratio";
    }

    value def DigitalCount : Integer {
        unit = "count";
    }

    item def PhysicalQuantity {
        attribute quantityName : String;
        attribute measuredValue : TemperatureValue;
        attribute timestamp : TimeValue;
    }

    item def RawSensorSignal {
        attribute signalVoltage : VoltageValue;
        attribute adcCount : DigitalCount;
        attribute sampleTime : TimeValue;
    }

    item def CalibratedMeasurement {
        attribute quantityName : String = "ambientTemperature";
        attribute value : TemperatureValue;
        attribute uncertainty : TemperatureValue;
        attribute quality : PercentValue;
        attribute measurementTime : TimeValue;
    }

    item def MeasurementReport {
        attribute reportId : String;
        attribute measuredQuantity : String = "ambientTemperature";
        attribute measuredValue : TemperatureValue;
        attribute uncertainty : TemperatureValue;
        attribute status : MeasurementStatus;
        attribute reportTime : TimeValue;
    }

    enum def MeasurementStatus {
        enum idle;
        enum warmingUp;
        enum valid;
        enum degraded;
        enum invalid;
        enum faulted;
    }

    enum def SensorHealth {
        enum unknown;
        enum nominal;
        enum outOfRange;
        enum disconnected;
        enum saturated;
        enum failedSelfTest;
    }

    port def PhysicalSensingPort {
        in item sensedQuantity : PhysicalQuantity;
    }

    port def AnalogSignalPort {
        out item rawSignal : RawSensorSignal;
    }

    port def MeasurementOutputPort {
        out item report : MeasurementReport;
    }

    port def PowerInputPort {
        in attribute supplyVoltage : VoltageValue;
        in attribute supplyCurrentLimit : CurrentValue;
    }

    port def DiagnosticPort {
        out attribute health : SensorHealth;
        out attribute status : MeasurementStatus;
        out attribute lastErrorCode : String;
    }

    action def SensePhysicalQuantity {
        in item environmentQuantity : PhysicalQuantity;
        out item rawSignal : RawSensorSignal;

        attribute sensitivity : VoltageValue = 0.010;
        attribute offsetVoltage : VoltageValue = 0.500;

        action convertQuantityToVoltage {
            in item q : PhysicalQuantity = environmentQuantity;
            out attribute v : VoltageValue;
        }

        action digitizeVoltage {
            in attribute v : VoltageValue;
            out attribute count : DigitalCount;
        }

        bind rawSignal.signalVoltage = convertQuantityToVoltage.v;
        bind rawSignal.adcCount = digitizeVoltage.count;
        bind rawSignal.sampleTime = environmentQuantity.timestamp;
    }

    action def CalibrateRawSignal {
        in item rawSignal : RawSensorSignal;
        out item calibratedMeasurement : CalibratedMeasurement;

        attribute calibrationSlope : TemperatureValue = 100.0;
        attribute calibrationOffset : TemperatureValue = -50.0;
        attribute nominalUncertainty : TemperatureValue = 0.2;

        action applyCalibrationCurve {
            in item raw : RawSensorSignal = rawSignal;
            out attribute calibratedValue : TemperatureValue;
        }

        action estimateQuality {
            in item raw : RawSensorSignal = rawSignal;
            out attribute qualityValue : PercentValue;
        }

        bind calibratedMeasurement.value = applyCalibrationCurve.calibratedValue;
        bind calibratedMeasurement.uncertainty = nominalUncertainty;
        bind calibratedMeasurement.quality = estimateQuality.qualityValue;
        bind calibratedMeasurement.measurementTime = rawSignal.sampleTime;
    }

    action def ValidateMeasurement {
        in item measurement : CalibratedMeasurement;
        out attribute status : MeasurementStatus;

        attribute minimumValidTemperature : TemperatureValue = -40.0;
        attribute maximumValidTemperature : TemperatureValue = 125.0;
        attribute minimumQuality : PercentValue = 80.0;
    }

    action def PublishMeasurementReport {
        in item measurement : CalibratedMeasurement;
        in attribute status : MeasurementStatus;
        out item report : MeasurementReport;

        bind report.measuredValue = measurement.value;
        bind report.uncertainty = measurement.uncertainty;
        bind report.status = status;
        bind report.reportTime = measurement.measurementTime;
    }

    state def SensingUnitLifecycle {
        entry action initializeElectronics;
        exit action preserveLastMeasurement;

        state poweredOff;
        state initializing;
        state selfTesting;
        state measuring;
        state degradedOperation;
        state fault;

        transition first poweredOff;

        transition powerApplied
            first poweredOff
            then initializing;

        transition initializationComplete
            first initializing
            then selfTesting;

        transition selfTestPassed
            first selfTesting
            then measuring;

        transition selfTestFailed
            first selfTesting
            then fault;

        transition signalQualityLow
            first measuring
            then degradedOperation;

        transition signalQualityRecovered
            first degradedOperation
            then measuring;

        transition unrecoverableSensorFault
            first measuring
            then fault;

        transition degradedFault
            first degradedOperation
            then fault;

        transition powerRemovedFromMeasuring
            first measuring
            then poweredOff;

        transition powerRemovedFromFault
            first fault
            then poweredOff;
    }

    part def Sensor {
        attribute sensorId : String;
        attribute measurableQuantity : String = "ambientTemperature";
        attribute minimumRange : TemperatureValue = -40.0;
        attribute maximumRange : TemperatureValue = 125.0;
        attribute accuracy : TemperatureValue = 0.5;
        attribute responseTime : TimeValue = 0.100;
        attribute health : SensorHealth = SensorHealth::unknown;

        port sensingPort : PhysicalSensingPort;
        port signalPort : AnalogSignalPort;
        port powerPort : PowerInputPort;
        port diagnosticPort : DiagnosticPort;

        perform action sense : SensePhysicalQuantity {
            in environmentQuantity = sensingPort.sensedQuantity;
            out rawSignal = signalPort.rawSignal;
        }
    }

    part def SignalConditioner {
        attribute amplifierGain : Real = 2.0;
        attribute lowPassCutoffFrequency : MeasurementUpdateRate = 20.0;
        attribute biasVoltage : VoltageValue = 1.650;

        port inputSignal : AnalogSignalPort;
        port conditionedSignal : AnalogSignalPort;
        port powerPort : PowerInputPort;
    }

    part def MeasurementProcessor {
        attribute sampleRate : MeasurementUpdateRate = 10.0;
        attribute resolutionBits : Integer = 12;
        attribute status : MeasurementStatus = MeasurementStatus::idle;

        port rawInput : AnalogSignalPort;
        port measurementOutput : MeasurementOutputPort;
        port diagnosticPort : DiagnosticPort;

        perform action calibrate : CalibrateRawSignal {
            in rawSignal = rawInput.rawSignal;
        }

        perform action validate : ValidateMeasurement {
            in measurement = calibrate.calibratedMeasurement;
        }

        perform action publish : PublishMeasurementReport {
            in measurement = calibrate.calibratedMeasurement;
            in status = validate.status;
            out report = measurementOutput.report;
        }
    }

    part def SensingUnit {
        attribute unitId : String;
        attribute measuredQuantity : String = "ambientTemperature";
        attribute updateRate : MeasurementUpdateRate = 10.0;
        attribute warmupTime : TimeValue = 2.0;
        attribute operatingStatus : MeasurementStatus = MeasurementStatus::idle;

        port sensedQuantityInput : PhysicalSensingPort;
        port measurementOutput : MeasurementOutputPort;
        port powerInput : PowerInputPort;
        port diagnosticOutput : DiagnosticPort;

        part sensor : Sensor {
            sensorId = "TEMP-SENSOR-001";
        }

        part conditioner : SignalConditioner;
        part processor : MeasurementProcessor;

        connection sensedQuantityToSensor
            connect sensedQuantityInput to sensor.sensingPort;

        connection sensorToConditioner
            connect sensor.signalPort to conditioner.inputSignal;

        connection conditionerToProcessor
            connect conditioner.conditionedSignal to processor.rawInput;

        connection processorToUnitOutput
            connect processor.measurementOutput to measurementOutput;

        connection unitPowerToSensor
            connect powerInput to sensor.powerPort;

        connection unitPowerToConditioner
            connect powerInput to conditioner.powerPort;

        connection sensorDiagnostics
            connect sensor.diagnosticPort to diagnosticOutput;

        connection processorDiagnostics
            connect processor.diagnosticPort to diagnosticOutput;

        exhibit state lifecycle : SensingUnitLifecycle;
    }

    requirement def MeasureRelevantQuantityRequirement {
        subject sensingUnit : SensingUnit;

        require constraint {
            sensingUnit.measuredQuantity == "ambientTemperature"
        }

        require constraint {
            sensingUnit.sensor.measurableQuantity == sensingUnit.measuredQuantity
        }
    }

    requirement def SensorUsageRequirement {
        subject sensingUnit : SensingUnit;

        require constraint {
            sensingUnit.sensor.accuracy <= 0.5 [degC]
        }

        doc /* The sensing unit shall measure the relevant physical quantity using its Sensor part as the primary sensing element. */
    }

    requirement def MeasurementRangeRequirement {
        subject sensingUnit : SensingUnit;

        require constraint {
            sensingUnit.sensor.minimumRange <= -40.0 [degC]
        }

        require constraint {
            sensingUnit.sensor.maximumRange >= 125.0 [degC]
        }
    }

    requirement def MeasurementOutputRequirement {
        subject sensingUnit : SensingUnit;

        require constraint {
            sensingUnit.updateRate >= 1.0 [Hz]
        }

        require constraint {
            sensingUnit.processor.resolutionBits >= 12
        }

        doc /* The sensing unit shall produce a calibrated measurement report containing value, uncertainty, status, and timestamp. */
    }

    requirement def FaultReportingRequirement {
        subject sensingUnit : SensingUnit;

        doc /* The sensing unit shall report invalid, degraded, and faulted measurement conditions through its diagnostic output. */
    }

    part sensingUnit : SensingUnit {
        unitId = "SU-AMB-TEMP-001";
    }

    satisfy MeasureRelevantQuantityRequirement by sensingUnit;
    satisfy SensorUsageRequirement by sensingUnit;
    satisfy MeasurementRangeRequirement by sensingUnit;
    satisfy MeasurementOutputRequirement by sensingUnit;
    satisfy FaultReportingRequirement by sensingUnit;
}