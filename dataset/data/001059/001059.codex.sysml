package FreeFallSensingUnitModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Probability :> Real {
        :>> range = "0..1";
    }

    attribute def Confidence :> Probability;

    attribute def AccelerationMagnitude :> Real {
        unit = "m/s^2";
    }

    attribute def AngularRateMagnitude :> Real {
        unit = "rad/s";
    }

    attribute def TimeDuration :> Real {
        unit = "s";
    }

    attribute def Voltage :> Real {
        unit = "V";
    }

    attribute def ElectricCurrent :> Real {
        unit = "mA";
    }

    attribute def Temperature :> Real {
        unit = "degC";
    }

    attribute def SampleRate :> Real {
        unit = "Hz";
    }

    attribute def InformationRate :> Real {
        unit = "bit/s";
    }

    enum def SensorHealthKind {
        enum ok;
        enum degraded;
        enum failed;
        enum calibrating;
    }

    enum def FreeFallStateKind {
        enum stationary;
        enum normalMotion;
        enum freeFallCandidate;
        enum confirmedFreeFall;
        enum impactDetected;
        enum fault;
    }

    enum def AlertPriorityKind {
        enum advisory;
        enum warning;
        enum critical;
    }

    item def RawAccelerationSample {
        attribute ax : AccelerationMagnitude;
        attribute ay : AccelerationMagnitude;
        attribute az : AccelerationMagnitude;
        attribute sampleTime : TimeDuration;
        attribute sensorTemperature : Temperature;
    }

    item def RawGyroSample {
        attribute wx : AngularRateMagnitude;
        attribute wy : AngularRateMagnitude;
        attribute wz : AngularRateMagnitude;
        attribute sampleTime : TimeDuration;
    }

    item def FreeFallMeasurement {
        attribute accelerationMagnitude : AccelerationMagnitude;
        attribute durationBelowThreshold : TimeDuration;
        attribute confidence : Confidence;
        attribute detectedState : FreeFallStateKind;
        attribute measurementTime : TimeDuration;
    }

    item def FreeFallAlert {
        attribute priority : AlertPriorityKind;
        attribute confidence : Confidence;
        attribute eventStartTime : TimeDuration;
        attribute elapsedFreeFallTime : TimeDuration;
        attribute impactLikely : Boolean;
    }

    item def SensorStatus {
        attribute health : SensorHealthKind;
        attribute supplyVoltage : Voltage;
        attribute supplyCurrent : ElectricCurrent;
        attribute temperature : Temperature;
        attribute sampleRate : SampleRate;
        attribute lastSelfTestPassed : Boolean;
    }

    item def ConfigurationCommand {
        attribute lowGThreshold : AccelerationMagnitude;
        attribute impactThreshold : AccelerationMagnitude;
        attribute minimumFreeFallDuration : TimeDuration;
        attribute sampleRate : SampleRate;
        attribute alertConfidenceThreshold : Confidence;
        attribute enableSelfTest : Boolean;
    }

    port def PowerInputPort {
        in item supplyVoltage : Voltage;
        in item supplyCurrentLimit : ElectricCurrent;
    }

    port def MotionSamplePort {
        out item acceleration : RawAccelerationSample;
        out item angularRate : RawGyroSample;
    }

    port def ConfigurationPort {
        in item command : ConfigurationCommand;
        out item status : SensorStatus;
    }

    port def MeasurementPort {
        out item measurement : FreeFallMeasurement;
    }

    port def AlertPort {
        out item alert : FreeFallAlert;
    }

    port def DiagnosticPort {
        out item status : SensorStatus;
    }

    action def AcquireInertialSamples {
        in item accelerationSample : RawAccelerationSample;
        in item gyroSample : RawGyroSample;
        out item filteredAccelerationMagnitude : AccelerationMagnitude;
        out item angularRateMagnitude : AngularRateMagnitude;
    }

    action def EvaluateFreeFallCondition {
        in item accelerationMagnitude : AccelerationMagnitude;
        in item angularRateMagnitude : AngularRateMagnitude;
        in item lowGThreshold : AccelerationMagnitude;
        in item minimumDuration : TimeDuration;
        in item elapsedBelowThreshold : TimeDuration;
        out item freeFallCandidate : Boolean;
        out item confidence : Confidence;
    }

    action def PublishMeasurement {
        in item accelerationMagnitude : AccelerationMagnitude;
        in item elapsedBelowThreshold : TimeDuration;
        in item confidence : Confidence;
        in item state : FreeFallStateKind;
        out item measurement : FreeFallMeasurement;
    }

    action def PublishAlert {
        in item confidence : Confidence;
        in item eventStartTime : TimeDuration;
        in item elapsedFreeFallTime : TimeDuration;
        in item impactLikely : Boolean;
        out item alert : FreeFallAlert;
    }

    state def FreeFallDetectionStateMachine {
        in item accelerationMagnitude : AccelerationMagnitude;
        in item lowGThreshold : AccelerationMagnitude;
        in item impactThreshold : AccelerationMagnitude;
        in item minimumFreeFallDuration : TimeDuration;
        in item confidence : Confidence;
        in item health : SensorHealthKind;
        out item state : FreeFallStateKind;
        out item alertRequired : Boolean;
        out item impactLikely : Boolean;

        state idle;
        state monitoring;
        state candidate;
        state confirmed;
        state impact;
        state fault;

        entry; then idle;

        transition idle_to_monitoring
            first idle
            then monitoring
            effect send state = FreeFallStateKind::normalMotion;

        transition monitoring_to_candidate
            first monitoring
            if accelerationMagnitude < lowGThreshold
            then candidate
            effect send state = FreeFallStateKind::freeFallCandidate;

        transition candidate_to_monitoring
            first candidate
            if accelerationMagnitude >= lowGThreshold and accelerationMagnitude < impactThreshold
            then monitoring
            effect send state = FreeFallStateKind::normalMotion;

        transition candidate_to_confirmed
            first candidate
            if accelerationMagnitude < lowGThreshold and minimumFreeFallDuration <= minimumFreeFallDuration
            then confirmed
            effect send state = FreeFallStateKind::confirmedFreeFall;

        transition confirmed_to_impact
            first confirmed
            if accelerationMagnitude >= impactThreshold
            then impact
            effect send impactLikely = true;

        transition confirmed_to_monitoring
            first confirmed
            if accelerationMagnitude >= lowGThreshold and accelerationMagnitude < impactThreshold
            then monitoring
            effect send alertRequired = true;

        transition impact_to_monitoring
            first impact
            then monitoring
            effect send alertRequired = true;

        transition any_to_fault_from_monitoring
            first monitoring
            if health == SensorHealthKind::failed
            then fault
            effect send state = FreeFallStateKind::fault;

        transition any_to_fault_from_candidate
            first candidate
            if health == SensorHealthKind::failed
            then fault
            effect send state = FreeFallStateKind::fault;

        transition fault_to_monitoring
            first fault
            if health == SensorHealthKind::ok
            then monitoring
            effect send state = FreeFallStateKind::normalMotion;
    }

    part def ThreeAxisAccelerometer {
        attribute measurementRange : AccelerationMagnitude = 156.96;
        attribute noiseDensity : Real = 0.002;
        attribute sampleRate : SampleRate = 400.0;
        attribute biasStability : AccelerationMagnitude = 0.049;
        attribute operatingTemperatureMin : Temperature = -40.0;
        attribute operatingTemperatureMax : Temperature = 85.0;

        port power : PowerInputPort;
        port samples : MotionSamplePort;
        port diagnostics : DiagnosticPort;
    }

    part def FreeFallSensor {
        attribute lowGThreshold : AccelerationMagnitude = 2.45;
        attribute impactThreshold : AccelerationMagnitude = 24.53;
        attribute minimumFreeFallDuration : TimeDuration = 0.120;
        attribute maximumDetectionLatency : TimeDuration = 0.050;
        attribute confidenceThreshold : Confidence = 0.90;
        attribute sampleRate : SampleRate = 400.0;
        attribute health : SensorHealthKind = SensorHealthKind::ok;

        port power : PowerInputPort;
        port motionIn : MotionSamplePort;
        port config : ConfigurationPort;
        port measurementOut : MeasurementPort;
        port alertOut : AlertPort;
        port diagnosticOut : DiagnosticPort;

        perform action acquire : AcquireInertialSamples;
        perform action evaluate : EvaluateFreeFallCondition;
        perform action publishMeasurement : PublishMeasurement;
        perform action publishAlert : PublishAlert;
        exhibit state detection : FreeFallDetectionStateMachine;
    }

    part def SignalProcessor {
        attribute filterCutoffFrequency : SampleRate = 50.0;
        attribute processingLatency : TimeDuration = 0.008;
        attribute dataOutputRate : InformationRate = 64000.0;

        port motionIn : MotionSamplePort;
        port measurementOut : MeasurementPort;
        port alertOut : AlertPort;
        port diagnosticOut : DiagnosticPort;
    }

    part def SensingUnitController {
        attribute watchdogTimeout : TimeDuration = 0.250;
        attribute statusPeriod : TimeDuration = 1.000;
        attribute selfTestPeriod : TimeDuration = 3600.000;

        port config : ConfigurationPort;
        port measurementIn : MeasurementPort;
        port alertIn : AlertPort;
        port diagnosticIn : DiagnosticPort;
        port measurementOut : MeasurementPort;
        port alertOut : AlertPort;
        port statusOut : DiagnosticPort;
    }

    part def SensingUnitPowerRegulator {
        attribute inputVoltageMin : Voltage = 3.0;
        attribute inputVoltageMax : Voltage = 5.5;
        attribute regulatedVoltage : Voltage = 3.3;
        attribute maximumCurrent : ElectricCurrent = 25.0;

        port externalPower : PowerInputPort;
        port sensorPower : PowerInputPort;
        port processorPower : PowerInputPort;
    }

    part def FreeFallSensingUnit {
        attribute nominalSupplyVoltage : Voltage = 3.3;
        attribute maximumSupplyCurrent : ElectricCurrent = 20.0;
        attribute specifiedSampleRate : SampleRate = 400.0;
        attribute detectionLatencyLimit : TimeDuration = 0.050;
        attribute relevantMeasuredQuantity : String = "free-fall condition inferred from near-zero acceleration magnitude";

        port powerIn : PowerInputPort;
        port configuration : ConfigurationPort;
        port freeFallMeasurement : MeasurementPort;
        port freeFallAlert : AlertPort;
        port unitStatus : DiagnosticPort;

        part powerRegulator : SensingUnitPowerRegulator;
        part accelerometer : ThreeAxisAccelerometer;
        part freeFallSensor : FreeFallSensor;
        part processor : SignalProcessor;
        part controller : SensingUnitController;

        connect powerIn to powerRegulator.externalPower;
        connect powerRegulator.sensorPower to accelerometer.power;
        connect powerRegulator.processorPower to freeFallSensor.power;
        connect accelerometer.samples to freeFallSensor.motionIn;
        connect freeFallSensor.measurementOut to processor.measurementOut;
        connect freeFallSensor.alertOut to processor.alertOut;
        connect freeFallSensor.diagnosticOut to controller.diagnosticIn;
        connect configuration to freeFallSensor.config;
        connect configuration to controller.config;
        connect freeFallSensor.measurementOut to controller.measurementIn;
        connect freeFallSensor.alertOut to controller.alertIn;
        connect controller.measurementOut to freeFallMeasurement;
        connect controller.alertOut to freeFallAlert;
        connect controller.statusOut to unitStatus;
    }

    requirement def MeasureFreeFallRequirement {
        subject sensingUnit : FreeFallSensingUnit;

        require constraint {
            sensingUnit.freeFallSensor.lowGThreshold <= 2.45
        }

        require constraint {
            sensingUnit.freeFallSensor.minimumFreeFallDuration >= 0.100
        }

        require constraint {
            sensingUnit.freeFallSensor.maximumDetectionLatency <= sensingUnit.detectionLatencyLimit
        }

        require constraint {
            sensingUnit.freeFallSensor.confidenceThreshold >= 0.90
        }

        doc /* The sensing unit shall measure the relevant quantity as the free-fall condition using a Free fall sensor by detecting sustained acceleration magnitude below the configured low-g threshold and reporting a FreeFallMeasurement. */
    }

    requirement def AlertRequirement {
        subject sensingUnit : FreeFallSensingUnit;

        require constraint {
            sensingUnit.freeFallSensor.impactThreshold >= 19.62
        }

        require constraint {
            sensingUnit.freeFallSensor.confidenceThreshold >= 0.90
        }

        doc /* The sensing unit shall issue a critical free-fall alert when confirmed free fall is detected and shall indicate whether impact is likely after recovery acceleration exceeds the impact threshold. */
    }

    requirement def SamplingRequirement {
        subject sensingUnit : FreeFallSensingUnit;

        require constraint {
            sensingUnit.specifiedSampleRate >= 200.0
        }

        require constraint {
            sensingUnit.accelerometer.sampleRate >= sensingUnit.specifiedSampleRate
        }

        doc /* The sensing unit shall sample acceleration fast enough to detect free-fall events lasting at least 120 ms. */
    }

    requirement def HealthMonitoringRequirement {
        subject sensingUnit : FreeFallSensingUnit;

        require constraint {
            sensingUnit.controller.watchdogTimeout <= 0.250
        }

        doc /* The sensing unit shall report sensor health, supply voltage, current consumption, temperature, sample rate, and self-test result through the diagnostic port. */
    }

    satisfy MeasureFreeFallRequirement by FreeFallSensingUnit;
    satisfy AlertRequirement by FreeFallSensingUnit;
    satisfy SamplingRequirement by FreeFallSensingUnit;
    satisfy HealthMonitoringRequirement by FreeFallSensingUnit;

}