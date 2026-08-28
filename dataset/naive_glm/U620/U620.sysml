package BrakeFluidPressureSensingUnit {
    import ISQ::*;
    import SI::*;
    import ScalarValues::*;

    enum DiagnosticStatus {
        normal;
        degraded;
        fault;
    }

    enum OperatingMode {
        initializing;
        calibrating;
        normalOperation;
        degradedOperation;
        faulted;
        reset;
    }

    value type PressureValue :> Real {
        unit 'Pa';
    }
    value type TemperatureValue :> Real {
        unit 'degC';
    }
    value type VoltageValue :> Real {
        unit 'V';
    }
    value type FrequencyValue :> Real {
        unit 'Hz';
    }
    value type DigitalCount :> Integer {
        unit 'count';
    }
    value type TimeValue :> Real {
        unit 's';
    }

    item def BrakeFluid;
    item def RawPressureSignal {
        value pressure : PressureValue;
    }
    item def CompensatedPressureSignal {
        value pressure : PressureValue;
        value temperature : TemperatureValue;
    }
    item def ConditionedAnalogSignal {
        value voltage : VoltageValue;
    }
    item def DigitalPressureData {
        value pressure : PressureValue;
        value digitalCount : DigitalCount;
        value status : DiagnosticStatus;
        value timestamp : TimeValue;
    }
    item def DiagnosticMessage {
        value status : DiagnosticStatus;
        value faultCode : Integer;
        value description : String;
    }
    item def CalibrationParameters {
        value zeroOffset : VoltageValue;
        value fullScaleSpan : VoltageValue;
        value temperatureCoeff : Real;
    }

    part def SensingElement {
        attribute sensitivity : Real = 1.0e-6; // V per Pa
        attribute maxPressure : PressureValue = 25000000 [Pa];
        port fluidIn : BrakeFluid;
        port rawPressureOut : PressureValue;
        port temperatureOut : TemperatureValue;
        attribute rawPressure : PressureValue;
        attribute elementTemperature : TemperatureValue = 25 [degC];

        action def sensePressure {
            in fluid : BrakeFluid;
            out raw : PressureValue;
            out temp : TemperatureValue;
        }
    }

    part def TemperatureCompensationUnit {
        attribute compensationCoeff : Real = 0.0;
        attribute referenceTemperature : TemperatureValue = 25 [degC];
        port rawPressureIn : PressureValue;
        port temperatureIn : TemperatureValue;
        port compensatedOut : PressureValue;
        attribute compensatedPressure : PressureValue;

        action def compensate {
            in raw : PressureValue;
            in temp : TemperatureValue;
            out comp : PressureValue;
        }
    }

    part def SignalConditioningCircuit {
        attribute gain : Real = 100.0;
        attribute offset : VoltageValue = 0.5 [V];
        attribute bandwidth : FrequencyValue = 10000 [Hz];
        port compensatedIn : PressureValue;
        port analogOut : VoltageValue;
        port conditionedInternal : VoltageValue;
        attribute outputVoltage : VoltageValue;

        action def condition {
            in comp : PressureValue;
            out voltage : VoltageValue;
        }
    }

    part def AnalogToDigitalConverter {
        attribute resolutionBits : Integer = 16;
        attribute referenceVoltage : VoltageValue = 5.0 [V];
        attribute samplingRate : FrequencyValue = 1000 [Hz];
        port analogIn : VoltageValue;
        port digitalOut : DigitalPressureData;
        attribute digitalCount : DigitalCount;

        action def convert {
            in voltage : VoltageValue;
            out digital : DigitalPressureData;
        }
    }

    part def DiagnosticController {
        attribute status : DiagnosticStatus = normal;
        attribute minRange : PressureValue = 0 [Pa];
        attribute maxRange : PressureValue = 25000000 [Pa];
        attribute degradedThresholdLow : PressureValue = -500000 [Pa];
        attribute degradedThresholdHigh : PressureValue = 25500000 [Pa];
        attribute faultCode : Integer = 0;
        port digitalIn : DigitalPressureData;
        port diagOut : DiagnosticMessage;
        port statusOut : DiagnosticStatus;

        action def monitor {
            in data : DigitalPressureData;
            out diag : DiagnosticMessage;
        }
    }

    part def InternalTemperatureSensor {
        port tempOut : TemperatureValue;
        attribute currentTemp : TemperatureValue = 25 [degC];
        attribute accuracy : TemperatureValue = 1 [degC];

        action def measureTemperature {
            out temp : TemperatureValue;
        }
    }

    part def BrakeFluidPressureSensor {
        port fluidPort : BrakeFluid;
        port analogOutput : VoltageValue;
        port digitalOutput : DigitalPressureData;
        port diagnosticOutput : DiagnosticMessage;
        port statusOutput : DiagnosticStatus;
        port resetInput : Boolean;

        attribute operatingMode : OperatingMode = initializing;
        attribute supplyVoltage : VoltageValue = 12.0 [V];
        attribute operatingTemperatureRangeMin : TemperatureValue = -40 [degC];
        attribute operatingTemperatureRangeMax : TemperatureValue = 125 [degC];
        attribute pressureRangeMin : PressureValue = 0 [Pa];
        attribute pressureRangeMax : PressureValue = 25000000 [Pa];
        attribute samplingRate : FrequencyValue = 1000 [Hz];
        attribute responseTime : TimeValue = 0.001 [s];
        attribute calibrationComplete : Boolean = false;
        attribute internalErrorDetected : Boolean = false;
        attribute outOfRangeDetected : Boolean = false;
        attribute rangeRestored : Boolean = false;
        attribute resetCommandReceived : Boolean = false;

        part sensingElement : SensingElement;
        part tempCompUnit : TemperatureCompensationUnit;
        part signalConditioning : SignalConditioningCircuit;
        part adc : AnalogToDigitalConverter;
        part diagController : DiagnosticController;
        part internalTempSensor : InternalTemperatureSensor;

        connection fluidConnection connect fluidPort to sensingElement.fluidIn;
        connection rawPressureConnection connect sensingElement.rawPressureOut to tempCompUnit.rawPressureIn;
        connection temperatureConnection connect internalTempSensor.tempOut to tempCompUnit.temperatureIn;
        connection compensatedConnection connect tempCompUnit.compensatedOut to signalConditioning.compensatedIn;
        connection conditionedInternalConnection connect signalConditioning.conditionedInternal to adc.analogIn;
        connection analogOutputConnection connect signalConditioning.analogOut to analogOutput;
        connection digitalConnection connect adc.digitalOut to diagController.digitalIn;
        connection diagnosticOutputConnection connect diagController.diagOut to diagnosticOutput;
        connection statusOutputConnection connect diagController.statusOut to statusOutput;
        connection digitalFinalConnection connect adc.digitalOut to digitalOutput;

        action def performInitialization {
            out calibParams : CalibrationParameters;
        }
        action def performCalibration {
            in params : CalibrationParameters;
            out complete : Boolean;
        }
        action def providePressureData {
            out data : DigitalPressureData;
        }
        action def provideDegradedData {
            out data : DigitalPressureData;
        }
        action def withholdData {
        }
        action def performReset {
            out cleared : Boolean;
        }

        state machine SensorStateMachine {
            state initializing {
                entry action { operatingMode = initializing; }
                do action performInitialization;
                transition to calibrating;
            }
            state calibrating {
                entry action { operatingMode = calibrating; }
                do action performCalibration;
                transition to normalOperation when calibrationComplete;
            }
            state normalOperation {
                entry action { operatingMode = normalOperation; }
                do action providePressureData;
                transition to faulted when internalErrorDetected;
                transition to degradedOperation when outOfRangeDetected;
                transition to reset when resetCommandReceived;
            }
            state degradedOperation {
                entry action { operatingMode = degradedOperation; }
                do action provideDegradedData;
                transition to faulted when internalErrorDetected;
                transition to normalOperation when rangeRestored;
                transition to reset when resetCommandReceived;
            }
            state faulted {
                entry action { operatingMode = faulted; }
                do action withholdData;
                transition to reset when resetCommandReceived;
            }
            state reset {
                entry action { operatingMode = reset; }
                do action performReset;
                transition to initializing;
            }
        }
    }

    requirement def PressureMeasurementAccuracy {
        subject sensor : BrakeFluidPressureSensor;
        attribute maxErrorPercent : Real = 1.0;
        doc /* The sensor shall measure brake fluid pressure within maxErrorPercent of full scale across the operating range. */
    }

    requirement def DualOutputProvision {
        subject sensor : BrakeFluidPressureSensor;
        doc /* The sensor shall provide both an analog voltage output and a digital pressure output to vehicle control systems. */
    }

    requirement def TemperatureCompensationRequirement {
        subject sensor : BrakeFluidPressureSensor;
        attribute operatingTempMin : TemperatureValue = -40 [degC];
        attribute operatingTempMax : TemperatureValue = 125 [degC];
        doc /* The sensor shall compensate raw pressure readings for temperature variation across the operating temperature range. */
    }

    requirement def DiagnosticSelfMonitoring {
        subject sensor : BrakeFluidPressureSensor;
        doc /* The sensor shall continuously monitor its health and assign a diagnostic status of normal, degraded, or fault. */
    }

    requirement def StateBehaviorRequirement {
        subject sensor : BrakeFluidPressureSensor;
        doc /* The sensor shall operate in initializing, calibrating, normalOperation, degradedOperation, faulted, and reset states. */
    }

    requirement def FaultedStateDataWithholding {
        subject sensor : BrakeFluidPressureSensor;
        doc /* In the faulted state, the sensor shall withhold pressure data to prevent sending incorrect information. */
    }

    requirement def DegradedOperationAlert {
        subject sensor : BrakeFluidPressureSensor;
        doc /* In degraded operation, the sensor shall alert the vehicle controller that data may be unreliable. */
    }

    requirement def ResetCapability {
        subject sensor : BrakeFluidPressureSensor;
        doc /* The sensor shall support a reset command to clear faults and re-initialize. */
    }

    requirement def DigitalResolutionRequirement {
        subject sensor : BrakeFluidPressureSensor;
        attribute minResolutionBits : Integer = 12;
        doc /* The ADC shall provide digital output with at least minResolutionBits of resolution. */
    }

    requirement def SamplingRateRequirement {
        subject sensor : BrakeFluidPressureSensor;
        attribute minSamplingRate : FrequencyValue = 500 [Hz];
        doc /* The sensor shall sample pressure at no less than minSamplingRate. */
    }

    requirement def StartupInitializationRequirement {
        subject sensor : BrakeFluidPressureSensor;
        doc /* Upon startup, the sensor shall undergo initialization and calibration before providing pressure data. */
    }

    requirement def OutOfRangeDetectionRequirement {
        subject sensor : BrakeFluidPressureSensor;
        doc /* The sensor shall detect readings beyond its specified range and switch to degraded operation mode. */
    }

    requirement def ABS_ESC_InterfaceRequirement {
        subject sensor : BrakeFluidPressureSensor;
        doc /* The sensor digital output shall be suitable for use by Anti-lock Braking System and Electronic Stability Control controllers. */
    }
}
