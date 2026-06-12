package AngularRateSensingUnitModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def SampleRate :> frequency;
    attribute def TimeConstant :> time;
    attribute def AngularRate :> angularVelocity;
    attribute def AngularAcceleration :> angularAcceleration;
    attribute def Angle :> planeAngle;
    attribute def Voltage :> electricPotential;
    attribute def Current :> electricCurrent;
    attribute def Power :> power;
    attribute def Temperature :> thermodynamicTemperature;
    attribute def NoiseDensity :> scalar;
    attribute def BiasInstability :> angularVelocity;
    attribute def ScaleFactor :> scalar;
    attribute def Resolution :> angularVelocity;

    enum def AxisKind {
        enum x;
        enum y;
        enum z;
    }

    enum def SensorHealthKind {
        enum initializing;
        enum nominal;
        enum degraded;
        enum failed;
    }

    enum def MeasurementValidityKind {
        enum valid;
        enum suspect;
        enum invalid;
    }

    item def MechanicalRotation {
        attribute axis : AxisKind;
        attribute angularRate : AngularRate;
        attribute angularAcceleration : AngularAcceleration;
        attribute temperature : Temperature;
    }

    item def RawAngularRateSample {
        attribute axis : AxisKind;
        attribute timestamp : time;
        attribute rawRate : AngularRate;
        attribute dieTemperature : Temperature;
        attribute sensorHealth : SensorHealthKind;
    }

    item def CalibratedAngularRateSample {
        attribute axis : AxisKind;
        attribute timestamp : time;
        attribute angularRate : AngularRate;
        attribute uncertainty : AngularRate;
        attribute validity : MeasurementValidityKind;
    }

    item def PowerInput {
        attribute supplyVoltage : Voltage;
        attribute supplyCurrent : Current;
    }

    item def DiagnosticReport {
        attribute timestamp : time;
        attribute health : SensorHealthKind;
        attribute biasEstimate : AngularRate;
        attribute temperature : Temperature;
        attribute saturationDetected : Boolean;
        attribute communicationFault : Boolean;
    }

    port def RotationInputPort {
        in item rotation : MechanicalRotation;
    }

    port def ElectricalPowerPort {
        in item powerInput : PowerInput;
    }

    port def RateSampleOutputPort {
        out item rateSample : CalibratedAngularRateSample;
    }

    port def DiagnosticOutputPort {
        out item diagnostic : DiagnosticReport;
    }

    port def RawSensorPort {
        out item rawSample : RawAngularRateSample;
    }

    port def SensorControlPort {
        in attribute enable : Boolean;
        in attribute reset : Boolean;
        out attribute ready : Boolean;
    }

    part def AngularRateSensor {
        attribute measuredAxis : AxisKind;
        attribute measurementRange : AngularRate = 34.9066 [rad/s];
        attribute bandwidth : frequency = 250 [Hz];
        attribute sampleRate : SampleRate = 1000 [Hz];
        attribute noiseDensity : NoiseDensity = 0.004 [1];
        attribute biasInstability : BiasInstability = 0.000349 [rad/s];
        attribute scaleFactorError : ScaleFactor = 0.005;
        attribute resolution : Resolution = 0.0000873 [rad/s];
        attribute operatingTemperatureMin : Temperature = 233.15 [K];
        attribute operatingTemperatureMax : Temperature = 358.15 [K];
        attribute supplyVoltageNominal : Voltage = 3.3 [V];
        attribute supplyCurrentMax : Current = 0.012 [A];

        port rotationIn : RotationInputPort;
        port power : ElectricalPowerPort;
        port rawOut : RawSensorPort;
        port control : SensorControlPort;

        state machine sensorLifecycle {
            state off;
            state initializing;
            state measuring;
            state saturated;
            state fault;

            entry action initializeSensor {
                control.ready = false;
            }

            transition off_to_initializing
                first off
                then initializing
                if control.enable;

            transition initializing_to_measuring
                first initializing
                then measuring
                if control.enable;

            transition measuring_to_saturated
                first measuring
                then saturated
                if abs(rotationIn.rotation.angularRate) > measurementRange;

            transition saturated_to_measuring
                first saturated
                then measuring
                if abs(rotationIn.rotation.angularRate) <= measurementRange;

            transition any_to_fault
                first measuring
                then fault
                if power.powerInput.supplyVoltage < 3.0 [V] or power.powerInput.supplyVoltage > 3.6 [V];

            transition fault_to_initializing
                first fault
                then initializing
                if control.reset;
        }

        action senseAngularRate {
            in item appliedRotation : MechanicalRotation;
            out item rawSample : RawAngularRateSample;

            rawSample.axis = measuredAxis;
            rawSample.rawRate = appliedRotation.angularRate;
            rawSample.dieTemperature = appliedRotation.temperature;
            rawSample.sensorHealth = SensorHealthKind::nominal;
        }
    }

    part def SignalConditioner {
        attribute antiAliasCutoff : frequency = 200 [Hz];
        attribute filterTimeConstant : TimeConstant = 0.002 [s];
        attribute maximumInputRate : AngularRate = 34.9066 [rad/s];

        port rawIn {
            in item rawSample : RawAngularRateSample;
        }

        port conditionedOut {
            out item conditionedSample : RawAngularRateSample;
        }

        action lowPassFilter {
            in item unfiltered : RawAngularRateSample;
            out item filtered : RawAngularRateSample;

            filtered.axis = unfiltered.axis;
            filtered.timestamp = unfiltered.timestamp;
            filtered.rawRate = unfiltered.rawRate;
            filtered.dieTemperature = unfiltered.dieTemperature;
            filtered.sensorHealth = unfiltered.sensorHealth;
        }
    }

    part def CalibrationProcessor {
        attribute biasOffset : AngularRate = 0.0 [rad/s];
        attribute scaleFactor : ScaleFactor = 1.0;
        attribute temperatureCoefficient : scalar = 0.0002;
        attribute referenceTemperature : Temperature = 298.15 [K];
        attribute outputUncertainty : AngularRate = 0.00175 [rad/s];

        port conditionedIn {
            in item conditionedSample : RawAngularRateSample;
        }

        port calibratedOut : RateSampleOutputPort;

        action calibrateAngularRate {
            in item raw : RawAngularRateSample;
            out item calibrated : CalibratedAngularRateSample;

            calibrated.axis = raw.axis;
            calibrated.timestamp = raw.timestamp;
            calibrated.angularRate = (raw.rawRate - biasOffset) * scaleFactor;
            calibrated.uncertainty = outputUncertainty;
            calibrated.validity = MeasurementValidityKind::valid;
        }
    }

    part def HealthMonitor {
        attribute minimumSupplyVoltage : Voltage = 3.0 [V];
        attribute maximumSupplyVoltage : Voltage = 3.6 [V];
        attribute maximumTemperature : Temperature = 358.15 [K];
        attribute minimumTemperature : Temperature = 233.15 [K];
        attribute maximumAllowedBias : AngularRate = 0.01745 [rad/s];

        port powerIn : ElectricalPowerPort;

        port sampleIn {
            in item sample : CalibratedAngularRateSample;
        }

        port diagnosticOut : DiagnosticOutputPort;

        action evaluateHealth {
            in item sample : CalibratedAngularRateSample;
            in item powerInput : PowerInput;
            out item diagnostic : DiagnosticReport;

            diagnostic.timestamp = sample.timestamp;
            diagnostic.biasEstimate = 0.0 [rad/s];
            diagnostic.saturationDetected = abs(sample.angularRate) > 34.9066 [rad/s];
            diagnostic.communicationFault = false;
            diagnostic.health = SensorHealthKind::nominal;
        }

        state machine healthLifecycle {
            state starting;
            state healthy;
            state degraded;
            state failed;

            transition starting_to_healthy
                first starting
                then healthy;

            transition healthy_to_degraded
                first healthy
                then degraded
                if diagnosticOut.diagnostic.saturationDetected;

            transition degraded_to_healthy
                first degraded
                then healthy
                if not diagnosticOut.diagnostic.saturationDetected;

            transition healthy_to_failed
                first healthy
                then failed
                if powerIn.powerInput.supplyVoltage < minimumSupplyVoltage or powerIn.powerInput.supplyVoltage > maximumSupplyVoltage;
        }
    }

    part def AngularRateSensingUnit {
        attribute mass : mass = 0.025 [kg];
        attribute nominalPower : Power = 0.0396 [W];
        attribute outputSampleRate : SampleRate = 1000 [Hz];
        attribute startupTime : time = 0.050 [s];
        attribute totalMeasurementUncertainty : AngularRate = 0.00262 [rad/s];

        port rotationInput : RotationInputPort;
        port electricalPower : ElectricalPowerPort;
        port angularRateOutput : RateSampleOutputPort;
        port diagnostics : DiagnosticOutputPort;
        port control : SensorControlPort;

        part sensor : AngularRateSensor {
            measuredAxis = AxisKind::z;
        }

        part conditioner : SignalConditioner;
        part calibration : CalibrationProcessor;
        part monitor : HealthMonitor;

        connect rotationInput.rotation to sensor.rotationIn.rotation;
        connect electricalPower.powerInput to sensor.power.powerInput;
        connect electricalPower.powerInput to monitor.powerIn.powerInput;
        connect control.enable to sensor.control.enable;
        connect control.reset to sensor.control.reset;
        connect sensor.control.ready to control.ready;
        connect sensor.rawOut.rawSample to conditioner.rawIn.rawSample;
        connect conditioner.conditionedOut.conditionedSample to calibration.conditionedIn.conditionedSample;
        connect calibration.calibratedOut.rateSample to angularRateOutput.rateSample;
        connect calibration.calibratedOut.rateSample to monitor.sampleIn.sample;
        connect monitor.diagnosticOut.diagnostic to diagnostics.diagnostic;

        action measureRelevantQuantity {
            in item appliedRotation : MechanicalRotation;
            in item suppliedPower : PowerInput;
            out item measuredRate : CalibratedAngularRateSample;
            out item diagnostic : DiagnosticReport;

            first startSensor;
            then acquireRawRate;
            then conditionSignal;
            then compensateBiasAndScale;
            then publishMeasurement;
            then evaluateDiagnostic;
        }

        action startSensor;
        action acquireRawRate;
        action conditionSignal;
        action compensateBiasAndScale;
        action publishMeasurement;
        action evaluateDiagnostic;
    }

    requirement def AngularRateMeasurementRequirement {
        subject unit : AngularRateSensingUnit;

        require constraint {
            unit.angularRateOutput.rateSample.validity == MeasurementValidityKind::valid
        }

        require constraint {
            unit.totalMeasurementUncertainty <= 0.0035 [rad/s]
        }

        require constraint {
            unit.outputSampleRate >= 500 [Hz]
        }
    }

    requirement def AngularRateSensorUseRequirement {
        subject unit : AngularRateSensingUnit;

        require constraint {
            unit.sensor.measurementRange >= 17.4533 [rad/s]
        }

        require constraint {
            unit.sensor.sampleRate >= unit.outputSampleRate
        }
    }

    requirement def PowerCompatibilityRequirement {
        subject unit : AngularRateSensingUnit;

        require constraint {
            unit.nominalPower <= 0.050 [W]
        }

        require constraint {
            unit.sensor.supplyVoltageNominal == 3.3 [V]
        }
    }

    requirement def DiagnosticRequirement {
        subject unit : AngularRateSensingUnit;

        require constraint {
            unit.diagnostics.diagnostic.communicationFault == false
        }

        require constraint {
            unit.diagnostics.diagnostic.health != SensorHealthKind::failed
        }
    }

    requirement angularRateSensingUnitRequirement : AngularRateMeasurementRequirement {
        subject unit = angularRateSensingUnit;
    }

    requirement angularRateSensorUseRequirement : AngularRateSensorUseRequirement {
        subject unit = angularRateSensingUnit;
    }

    requirement angularRatePowerRequirement : PowerCompatibilityRequirement {
        subject unit = angularRateSensingUnit;
    }

    requirement angularRateDiagnosticRequirement : DiagnosticRequirement {
        subject unit = angularRateSensingUnit;
    }

    part angularRateSensingUnit : AngularRateSensingUnit;

}