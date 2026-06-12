package TiltSensingUnitModel {

    import ScalarValues::*;
    import SI::*;

    attribute def Angle {
        :>> num : Real;
        unit = "deg";
    }

    attribute def AngularRate {
        :>> num : Real;
        unit = "deg/s";
    }

    attribute def Voltage {
        :>> num : Real;
        unit = "V";
    }

    attribute def Current {
        :>> num : Real;
        unit = "mA";
    }

    attribute def Temperature {
        :>> num : Real;
        unit = "degC";
    }

    attribute def Time {
        :>> num : Real;
        unit = "ms";
    }

    attribute def Frequency {
        :>> num : Real;
        unit = "Hz";
    }

    attribute def Percent {
        :>> num : Real;
        unit = "%";
    }

    item def TiltAngleSample {
        attribute rollAngle : Angle;
        attribute pitchAngle : Angle;
        attribute angularRate : AngularRate;
        attribute sampleTime : Time;
        attribute sensorTemperature : Temperature;
        attribute quality : Percent;
    }

    item def RawTiltSignal {
        attribute xAxisVoltage : Voltage;
        attribute yAxisVoltage : Voltage;
        attribute zAxisVoltage : Voltage;
        attribute sensorTemperature : Temperature;
        attribute acquisitionTime : Time;
    }

    item def DigitalTiltFrame {
        attribute rollAngle : Angle;
        attribute pitchAngle : Angle;
        attribute statusCode : Integer;
        attribute checksum : Integer;
        attribute frameTime : Time;
    }

    item def Power {
        attribute supplyVoltage : Voltage;
        attribute loadCurrent : Current;
    }

    item def DiagnosticStatus {
        attribute sensorHealthy : Boolean;
        attribute calibrationValid : Boolean;
        attribute signalSaturated : Boolean;
        attribute communicationHealthy : Boolean;
        attribute faultCode : Integer;
    }

    port def PowerInputPort {
        in item powerIn : Power;
    }

    port def TiltDataOutputPort {
        out item measuredTilt : TiltAngleSample;
    }

    port def DiagnosticOutputPort {
        out item diagnostic : DiagnosticStatus;
    }

    port def RawSignalPort {
        out item rawSignal : RawTiltSignal;
    }

    port def DigitalFramePort {
        out item tiltFrame : DigitalTiltFrame;
    }

    part def TiltSensor {
        attribute measurementRange : Angle = 90 [unit = "deg"];
        attribute resolution : Angle = 0.1 [unit = "deg"];
        attribute accuracy : Angle = 1.0 [unit = "deg"];
        attribute updateRate : Frequency = 100 [unit = "Hz"];
        attribute operatingTemperatureMin : Temperature = -40 [unit = "degC"];
        attribute operatingTemperatureMax : Temperature = 85 [unit = "degC"];
        attribute supplyVoltageNominal : Voltage = 3.3 [unit = "V"];
        attribute currentConsumption : Current = 8 [unit = "mA"];

        port powerPort : PowerInputPort;
        port rawOutputPort : RawSignalPort;
        port diagnosticPort : DiagnosticOutputPort;

        action senseTilt {
            in item excitationPower : Power;
            out item rawTilt : RawTiltSignal;
            out item sensorStatus : DiagnosticStatus;

            first start;
            then acquireAxisVoltages;
            then checkSignalRange;
            then measureDieTemperature;
            then publishRawSignal;
            then done;

            action acquireAxisVoltages;
            action checkSignalRange;
            action measureDieTemperature;
            action publishRawSignal;
        }

        state sensorOperatingState {
            state unpowered;
            state initializing;
            state measuring;
            state degraded;
            state faulted;

            initial then unpowered;

            transition unpowered_to_initializing
                first unpowered
                accept PowerApplied
                then initializing;

            transition initializing_to_measuring
                first initializing
                accept InitializationComplete
                then measuring;

            transition measuring_to_degraded
                first measuring
                accept CalibrationWarning
                then degraded;

            transition degraded_to_measuring
                first degraded
                accept CalibrationRecovered
                then measuring;

            transition measuring_to_faulted
                first measuring
                accept SensorFaultDetected
                then faulted;

            transition degraded_to_faulted
                first degraded
                accept SensorFaultDetected
                then faulted;

            transition faulted_to_initializing
                first faulted
                accept ResetCommanded
                then initializing;
        }
    }

    part def SignalConditioner {
        attribute inputImpedance : Real = 1000000;
        attribute antiAliasCutoffFrequency : Frequency = 25 [unit = "Hz"];
        attribute gain : Real = 1.0;
        attribute offsetVoltage : Voltage = 1.65 [unit = "V"];

        port rawInputPort : RawSignalPort;
        port conditionedOutputPort : RawSignalPort;

        action conditionSignal {
            in item rawTilt : RawTiltSignal;
            out item conditionedTilt : RawTiltSignal;

            first start;
            then removeOffset;
            then applyGain;
            then filterNoise;
            then outputConditionedSignal;
            then done;

            action removeOffset;
            action applyGain;
            action filterNoise;
            action outputConditionedSignal;
        }
    }

    part def TiltProcessor {
        attribute samplePeriod : Time = 10 [unit = "ms"];
        attribute movingAverageWindow : Integer = 8;
        attribute maxValidRoll : Angle = 90 [unit = "deg"];
        attribute maxValidPitch : Angle = 90 [unit = "deg"];
        attribute minimumQuality : Percent = 95 [unit = "%"];

        port conditionedInputPort : RawSignalPort;
        port processedOutputPort : TiltDataOutputPort;
        port diagnosticPort : DiagnosticOutputPort;

        action computeTilt {
            in item conditionedSignal : RawTiltSignal;
            out item tiltSample : TiltAngleSample;
            out item processorStatus : DiagnosticStatus;

            first start;
            then convertVoltageToAccelerationVector;
            then calculateRollAngle;
            then calculatePitchAngle;
            then estimateAngularRate;
            then compensateTemperatureDrift;
            then validateMeasurementQuality;
            then publishTiltSample;
            then done;

            action convertVoltageToAccelerationVector;
            action calculateRollAngle;
            action calculatePitchAngle;
            action estimateAngularRate;
            action compensateTemperatureDrift;
            action validateMeasurementQuality;
            action publishTiltSample;
        }

        state processingState {
            state idle;
            state sampling;
            state filtering;
            state publishing;
            state invalidMeasurement;

            initial then idle;

            transition idle_to_sampling
                first idle
                accept SampleTimerElapsed
                then sampling;

            transition sampling_to_filtering
                first sampling
                accept RawSignalAvailable
                then filtering;

            transition filtering_to_publishing
                first filtering
                accept MeasurementValid
                then publishing;

            transition filtering_to_invalidMeasurement
                first filtering
                accept MeasurementInvalid
                then invalidMeasurement;

            transition publishing_to_idle
                first publishing
                accept OutputFrameSent
                then idle;

            transition invalidMeasurement_to_idle
                first invalidMeasurement
                accept FaultReported
                then idle;
        }
    }

    part def DataInterface {
        attribute frameRate : Frequency = 100 [unit = "Hz"];
        attribute checksumEnabled : Boolean = true;
        attribute interfaceBaudRate : Integer = 115200;

        port tiltInputPort : TiltDataOutputPort;
        port diagnosticInputPort : DiagnosticOutputPort;
        port frameOutputPort : DigitalFramePort;

        action encodeTiltFrame {
            in item tiltSample : TiltAngleSample;
            in item status : DiagnosticStatus;
            out item frame : DigitalTiltFrame;

            first start;
            then scaleAngles;
            then encodeStatus;
            then calculateChecksum;
            then transmitFrame;
            then done;

            action scaleAngles;
            action encodeStatus;
            action calculateChecksum;
            action transmitFrame;
        }
    }

    part def PowerRegulator {
        attribute inputVoltageMin : Voltage = 4.5 [unit = "V"];
        attribute inputVoltageMax : Voltage = 28 [unit = "V"];
        attribute outputVoltage : Voltage = 3.3 [unit = "V"];
        attribute outputCurrentLimit : Current = 100 [unit = "mA"];
        attribute efficiency : Percent = 88 [unit = "%"];

        port externalPowerPort : PowerInputPort;
        port regulatedPowerPort : PowerInputPort;

        action regulatePower {
            in item externalPower : Power;
            out item regulatedPower : Power;

            first start;
            then verifyInputRange;
            then convertVoltage;
            then limitCurrent;
            then supplyRegulatedPower;
            then done;

            action verifyInputRange;
            action convertVoltage;
            action limitCurrent;
            action supplyRegulatedPower;
        }
    }

    part def TiltSensingUnit {
        attribute rollMeasurementRange : Angle = 90 [unit = "deg"];
        attribute pitchMeasurementRange : Angle = 90 [unit = "deg"];
        attribute rollAccuracy : Angle = 1.5 [unit = "deg"];
        attribute pitchAccuracy : Angle = 1.5 [unit = "deg"];
        attribute outputUpdateRate : Frequency = 100 [unit = "Hz"];
        attribute startupTime : Time = 250 [unit = "ms"];
        attribute nominalSupplyVoltage : Voltage = 12 [unit = "V"];
        attribute maximumSupplyCurrent : Current = 50 [unit = "mA"];

        port powerInput : PowerInputPort;
        port tiltOutput : TiltDataOutputPort;
        port diagnosticOutput : DiagnosticOutputPort;
        port digitalOutput : DigitalFramePort;

        part regulator : PowerRegulator;
        part sensor : TiltSensor;
        part conditioner : SignalConditioner;
        part processor : TiltProcessor;
        part interface : DataInterface;

        connect powerInput to regulator.externalPowerPort;
        connect regulator.regulatedPowerPort to sensor.powerPort;
        connect sensor.rawOutputPort to conditioner.rawInputPort;
        connect conditioner.conditionedOutputPort to processor.conditionedInputPort;
        connect processor.processedOutputPort to tiltOutput;
        connect processor.processedOutputPort to interface.tiltInputPort;
        connect sensor.diagnosticPort to diagnosticOutput;
        connect processor.diagnosticPort to diagnosticOutput;
        connect processor.diagnosticPort to interface.diagnosticInputPort;
        connect interface.frameOutputPort to digitalOutput;

        action measureRelevantQuantityUsingTiltSensor {
            in item suppliedPower : Power;
            out item measuredTilt : TiltAngleSample;
            out item diagnostic : DiagnosticStatus;
            out item digitalFrame : DigitalTiltFrame;

            first start;
            then regulateInputPower;
            then exciteTiltSensor;
            then acquireRawTiltSignal;
            then conditionRawSignal;
            then computeRollAndPitch;
            then validateTiltMeasurement;
            then encodeDigitalOutput;
            then publishOutputs;
            then done;

            action regulateInputPower;
            action exciteTiltSensor;
            action acquireRawTiltSignal;
            action conditionRawSignal;
            action computeRollAndPitch;
            action validateTiltMeasurement;
            action encodeDigitalOutput;
            action publishOutputs;
        }

        state unitState {
            state off;
            state powerOnSelfTest;
            state calibrating;
            state operational;
            state degraded;
            state failed;

            initial then off;

            transition off_to_powerOnSelfTest
                first off
                accept PowerApplied
                then powerOnSelfTest;

            transition powerOnSelfTest_to_calibrating
                first powerOnSelfTest
                accept SelfTestPassed
                then calibrating;

            transition calibrating_to_operational
                first calibrating
                accept CalibrationComplete
                then operational;

            transition operational_to_degraded
                first operational
                accept MeasurementQualityLow
                then degraded;

            transition degraded_to_operational
                first degraded
                accept MeasurementQualityRecovered
                then operational;

            transition operational_to_failed
                first operational
                accept CriticalFaultDetected
                then failed;

            transition degraded_to_failed
                first degraded
                accept CriticalFaultDetected
                then failed;

            transition failed_to_powerOnSelfTest
                first failed
                accept ResetCommanded
                then powerOnSelfTest;

            transition operational_to_off
                first operational
                accept PowerRemoved
                then off;

            transition degraded_to_off
                first degraded
                accept PowerRemoved
                then off;

            transition failed_to_off
                first failed
                accept PowerRemoved
                then off;
        }
    }

    requirement def MeasureTiltRequirement {
        subject unit : TiltSensingUnit;

        require constraint {
            unit.rollMeasurementRange >= 90 [unit = "deg"] and
            unit.pitchMeasurementRange >= 90 [unit = "deg"]
        }
    }

    requirement def AccuracyRequirement {
        subject unit : TiltSensingUnit;

        require constraint {
            unit.rollAccuracy <= 1.5 [unit = "deg"] and
            unit.pitchAccuracy <= 1.5 [unit = "deg"]
        }
    }

    requirement def UpdateRateRequirement {
        subject unit : TiltSensingUnit;

        require constraint {
            unit.outputUpdateRate >= 100 [unit = "Hz"]
        }
    }

    requirement def StartupRequirement {
        subject unit : TiltSensingUnit;

        require constraint {
            unit.startupTime <= 250 [unit = "ms"]
        }
    }

    requirement def PowerRequirement {
        subject unit : TiltSensingUnit;

        require constraint {
            unit.nominalSupplyVoltage == 12 [unit = "V"] and
            unit.maximumSupplyCurrent <= 50 [unit = "mA"]
        }
    }

    requirement def DiagnosticRequirement {
        subject status : DiagnosticStatus;

        require constraint {
            status.communicationHealthy == true and
            status.faultCode >= 0
        }
    }

    part sensingUnit : TiltSensingUnit;

    requirement measureTiltReq : MeasureTiltRequirement {
        subject unit = sensingUnit;
    }

    requirement accuracyReq : AccuracyRequirement {
        subject unit = sensingUnit;
    }

    requirement updateRateReq : UpdateRateRequirement {
        subject unit = sensingUnit;
    }

    requirement startupReq : StartupRequirement {
        subject unit = sensingUnit;
    }

    requirement powerReq : PowerRequirement {
        subject unit = sensingUnit;
    }

    satisfy measureTiltReq by sensingUnit;
    satisfy accuracyReq by sensingUnit;
    satisfy updateRateReq by sensingUnit;
    satisfy startupReq by sensingUnit;
    satisfy powerReq by sensingUnit;
}