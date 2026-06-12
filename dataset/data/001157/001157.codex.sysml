package NitrogenOxideSensingUnitModel {

    import ScalarValues::*;
    import SI::*;

    attribute def Concentration {
        :> scalarValues::Real;
        unit = "ppm";
    }

    attribute def TemperatureCelsius {
        :> scalarValues::Real;
        unit = "degC";
    }

    attribute def RelativeHumidity {
        :> scalarValues::Real;
        unit = "%";
    }

    attribute def Voltage {
        :> scalarValues::Real;
        unit = "V";
    }

    attribute def Current {
        :> scalarValues::Real;
        unit = "mA";
    }

    attribute def TimeSeconds {
        :> scalarValues::Real;
        unit = "s";
    }

    attribute def DigitalCount {
        :> scalarValues::Integer;
        unit = "count";
    }

    attribute def Percent {
        :> scalarValues::Real;
        unit = "%";
    }

    item def GasSample {
        attribute noConcentration : Concentration;
        attribute no2Concentration : Concentration;
        attribute temperature : TemperatureCelsius;
        attribute relativeHumidity : RelativeHumidity;
        attribute pressure : PressureValue;
    }

    item def RawSensorSignal {
        attribute workingElectrodeVoltage : Voltage;
        attribute auxiliaryElectrodeVoltage : Voltage;
        attribute heaterCurrent : Current;
        attribute adcCount : DigitalCount;
        attribute sampleAge : TimeSeconds;
    }

    item def NitrogenOxideMeasurement {
        attribute noConcentration : Concentration;
        attribute no2Concentration : Concentration;
        attribute totalNOxConcentration : Concentration;
        attribute temperatureCompensated : Boolean;
        attribute humidityCompensated : Boolean;
        attribute measurementUncertainty : Concentration;
        attribute timestamp : TimeSeconds;
        attribute validity : Boolean;
    }

    item def DiagnosticReport {
        attribute sensorHealthy : Boolean;
        attribute heaterHealthy : Boolean;
        attribute calibrationValid : Boolean;
        attribute faultCode : DigitalCount;
        attribute remainingSensorLife : Percent;
    }

    port def GasInletPort {
        in item gas : GasSample;
    }

    port def MeasurementOutputPort {
        out item measurement : NitrogenOxideMeasurement;
    }

    port def DiagnosticOutputPort {
        out item diagnostic : DiagnosticReport;
    }

    port def ElectricalPowerPort {
        in attribute supplyVoltage : Voltage;
        in attribute supplyCurrentLimit : Current;
    }

    port def DigitalControlPort {
        in attribute enable : Boolean;
        in attribute calibrationCommand : Boolean;
        in attribute resetFaults : Boolean;
        out attribute ready : Boolean;
        out attribute faultPresent : Boolean;
    }

    port def InternalSignalPort {
        out item rawSignal : RawSensorSignal;
    }

    part def SampleConditioner {
        port gasIn : GasInletPort;
        port conditionedGasOut : GasInletPort;

        attribute filterEfficiency : Percent = 95.0;
        attribute flowStabilizationTime : TimeSeconds = 2.0;
        attribute maximumParticleIngress : Concentration = 0.01;
    }

    part def NitrogenOxideSensor {
        port gasExposure : GasInletPort;
        port power : ElectricalPowerPort;
        port rawSignalOut : InternalSignalPort;

        attribute noSensitivity : Real = 0.82;
        attribute no2Sensitivity : Real = 1.14;
        attribute lowerDetectionLimit : Concentration = 0.02;
        attribute upperMeasurementLimit : Concentration = 500.0;
        attribute responseTimeT90 : TimeSeconds = 15.0;
        attribute heaterSetpoint : TemperatureCelsius = 320.0;
        attribute nominalHeaterCurrent : Current = 120.0;
        attribute zeroOffset : Voltage = 0.0;
        attribute spanDriftPerMonth : Percent = 2.0;
    }

    part def AnalogFrontEnd {
        port rawInput : InternalSignalPort;
        port power : ElectricalPowerPort;
        port digitizedOutput : InternalSignalPort;

        attribute gain : Real = 64.0;
        attribute adcResolution : DigitalCount = 4096;
        attribute referenceVoltage : Voltage = 3.3;
        attribute inputNoise : Voltage = 0.0005;
        attribute samplePeriod : TimeSeconds = 0.25;
    }

    part def CompensationProcessor {
        port digitizedInput : InternalSignalPort;
        port gasContext : GasInletPort;
        port measurementOut : MeasurementOutputPort;
        port diagnosticOut : DiagnosticOutputPort;
        port control : DigitalControlPort;

        attribute noTemperatureCoefficient : Real = -0.006;
        attribute no2TemperatureCoefficient : Real = 0.004;
        attribute humidityCoefficient : Real = 0.003;
        attribute calibrationInterval : TimeSeconds = 2592000.0;
        attribute measurementPeriod : TimeSeconds = 1.0;
        attribute faultThreshold : Percent = 15.0;
    }

    part def Enclosure {
        attribute ingressProtectionRating : String = "IP54";
        attribute operatingTemperatureMinimum : TemperatureCelsius = -20.0;
        attribute operatingTemperatureMaximum : TemperatureCelsius = 55.0;
        attribute condensationAllowed : Boolean = false;
    }

    action def ConditionGasSample {
        in item inletGas : GasSample;
        out item conditionedGas : GasSample;

        action removeParticles;
        action stabilizeFlow;
        action exposeToSensor;
    }

    action def SenseNitrogenOxides {
        in item conditionedGas : GasSample;
        in attribute heaterTemperature : TemperatureCelsius;
        out item rawSignal : RawSensorSignal;

        action maintainHeaterTemperature;
        action generateElectrochemicalCurrent;
        action convertCurrentToVoltage;
    }

    action def DigitizeSensorSignal {
        in item rawSignal : RawSensorSignal;
        out item digitizedSignal : RawSensorSignal;

        action amplifyWorkingElectrodeSignal;
        action subtractAuxiliaryElectrodeSignal;
        action sampleWithAdc;
    }

    action def ComputeNOxMeasurement {
        in item digitizedSignal : RawSensorSignal;
        in item gasContext : GasSample;
        out item measurement : NitrogenOxideMeasurement;

        action removeZeroOffset;
        action applySpanCalibration;
        action compensateTemperature;
        action compensateHumidity;
        action calculateTotalNOx;
        action estimateUncertainty;
        action validateRange;
    }

    action def GenerateDiagnostics {
        in item rawSignal : RawSensorSignal;
        in item measurement : NitrogenOxideMeasurement;
        out item diagnostic : DiagnosticReport;

        action evaluateHeaterCurrent;
        action detectSensorDrift;
        action verifyCalibrationAge;
        action estimateSensorLife;
        action assignFaultCode;
    }

    state def SensingUnitOperatingState {
        state off;
        state warmUp;
        state measuring;
        state calibrating;
        state fault;

        transition first off;

        transition powerEnabled
            first off
            then warmUp;

        transition warmUpComplete
            first warmUp
            then measuring;

        transition calibrationRequested
            first measuring
            then calibrating;

        transition calibrationComplete
            first calibrating
            then measuring;

        transition faultDetectedFromWarmUp
            first warmUp
            then fault;

        transition faultDetectedFromMeasuring
            first measuring
            then fault;

        transition faultDetectedFromCalibration
            first calibrating
            then fault;

        transition resetAccepted
            first fault
            then warmUp;

        transition powerDisabled
            first measuring
            then off;
    }

    part def NitrogenOxideSensingUnit {
        port gasIn : GasInletPort;
        port measurementOut : MeasurementOutputPort;
        port diagnosticOut : DiagnosticOutputPort;
        port power : ElectricalPowerPort;
        port control : DigitalControlPort;

        part conditioner : SampleConditioner;
        part sensor : NitrogenOxideSensor;
        part frontEnd : AnalogFrontEnd;
        part processor : CompensationProcessor;
        part enclosure : Enclosure;

        attribute supplyVoltageNominal : Voltage = 5.0;
        attribute maximumSupplyCurrent : Current = 250.0;
        attribute noMeasurementRangeMinimum : Concentration = 0.02;
        attribute noMeasurementRangeMaximum : Concentration = 500.0;
        attribute no2MeasurementRangeMinimum : Concentration = 0.02;
        attribute no2MeasurementRangeMaximum : Concentration = 500.0;
        attribute totalNOxMeasurementRangeMaximum : Concentration = 1000.0;
        attribute measurementUpdatePeriod : TimeSeconds = 1.0;
        attribute warmUpDuration : TimeSeconds = 60.0;
        attribute requiredAccuracy : Concentration = 2.0;
        attribute expectedServiceLife : TimeSeconds = 157680000.0;

        connection gasToConditioner connect gasIn to conditioner.gasIn;
        connection conditionerToSensor connect conditioner.conditionedGasOut to sensor.gasExposure;
        connection sensorRawToFrontEnd connect sensor.rawSignalOut to frontEnd.rawInput;
        connection frontEndToProcessor connect frontEnd.digitizedOutput to processor.digitizedInput;
        connection gasContextToProcessor connect conditioner.conditionedGasOut to processor.gasContext;
        connection measurementToExternal connect processor.measurementOut to measurementOut;
        connection diagnosticToExternal connect processor.diagnosticOut to diagnosticOut;
        connection powerToSensor connect power to sensor.power;
        connection powerToFrontEnd connect power to frontEnd.power;
        connection controlToProcessor connect control to processor.control;

        perform action conditionGas : ConditionGasSample {
            in inletGas = gasIn.gas;
            out conditionedGas = conditioner.conditionedGasOut.gas;
        }

        perform action senseNOx : SenseNitrogenOxides {
            in conditionedGas = conditioner.conditionedGasOut.gas;
            in heaterTemperature = sensor.heaterSetpoint;
            out rawSignal = sensor.rawSignalOut.rawSignal;
        }

        perform action digitizeSignal : DigitizeSensorSignal {
            in rawSignal = sensor.rawSignalOut.rawSignal;
            out digitizedSignal = frontEnd.digitizedOutput.rawSignal;
        }

        perform action computeMeasurement : ComputeNOxMeasurement {
            in digitizedSignal = frontEnd.digitizedOutput.rawSignal;
            in gasContext = conditioner.conditionedGasOut.gas;
            out measurement = measurementOut.measurement;
        }

        perform action generateDiagnostics : GenerateDiagnostics {
            in rawSignal = frontEnd.digitizedOutput.rawSignal;
            in measurement = measurementOut.measurement;
            out diagnostic = diagnosticOut.diagnostic;
        }

        exhibit state operatingState : SensingUnitOperatingState;
    }

    requirement def MeasureNitrogenOxidesRequirement {
        subject sensingUnit : NitrogenOxideSensingUnit;

        require constraint {
            sensingUnit.noMeasurementRangeMinimum <= 0.02 and
            sensingUnit.noMeasurementRangeMaximum >= 500.0 and
            sensingUnit.no2MeasurementRangeMinimum <= 0.02 and
            sensingUnit.no2MeasurementRangeMaximum >= 500.0
        }

        doc /* The sensing unit shall measure nitric oxide and nitrogen dioxide concentrations using a nitrogen oxide sensor. */
    }

    requirement def MeasurementAccuracyRequirement {
        subject sensingUnit : NitrogenOxideSensingUnit;

        require constraint {
            sensingUnit.requiredAccuracy <= 2.0
        }

        doc /* The sensing unit shall report compensated NO, NO2, and total NOx concentration with uncertainty not exceeding 2 ppm over the specified measurement range. */
    }

    requirement def MeasurementUpdateRequirement {
        subject sensingUnit : NitrogenOxideSensingUnit;

        require constraint {
            sensingUnit.measurementUpdatePeriod <= 1.0
        }

        doc /* The sensing unit shall publish a valid nitrogen oxide measurement at least once per second after warm-up. */
    }

    requirement def WarmUpRequirement {
        subject sensingUnit : NitrogenOxideSensingUnit;

        require constraint {
            sensingUnit.warmUpDuration <= 60.0
        }

        doc /* The sensing unit shall enter the measuring state within 60 seconds after power and enable are applied. */
    }

    requirement def DiagnosticRequirement {
        subject sensingUnit : NitrogenOxideSensingUnit;

        require constraint {
            sensingUnit.processor.faultThreshold <= 15.0
        }

        doc /* The sensing unit shall provide diagnostics for heater health, sensor health, calibration validity, fault state, and remaining sensor life. */
    }

    requirement def EnvironmentalRequirement {
        subject sensingUnit : NitrogenOxideSensingUnit;

        require constraint {
            sensingUnit.enclosure.operatingTemperatureMinimum <= -20.0 and
            sensingUnit.enclosure.operatingTemperatureMaximum >= 55.0 and
            sensingUnit.enclosure.condensationAllowed == false
        }

        doc /* The sensing unit shall operate in non-condensing ambient gas environments from -20 degC to 55 degC. */
    }

    requirement def PowerRequirement {
        subject sensingUnit : NitrogenOxideSensingUnit;

        require constraint {
            sensingUnit.supplyVoltageNominal == 5.0 and
            sensingUnit.maximumSupplyCurrent <= 250.0
        }

        doc /* The sensing unit shall operate from a nominal 5 V electrical supply while drawing no more than 250 mA. */
    }

    satisfy MeasureNitrogenOxidesRequirement by NitrogenOxideSensingUnit;
    satisfy MeasurementAccuracyRequirement by NitrogenOxideSensingUnit;
    satisfy MeasurementUpdateRequirement by NitrogenOxideSensingUnit;
    satisfy WarmUpRequirement by NitrogenOxideSensingUnit;
    satisfy DiagnosticRequirement by NitrogenOxideSensingUnit;
    satisfy EnvironmentalRequirement by NitrogenOxideSensingUnit;
    satisfy PowerRequirement by NitrogenOxideSensingUnit;

    part sensingUnit : NitrogenOxideSensingUnit;

}