package UltrasonicSensingUnitModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Percent :> Real {
        unit = "%";
    }

    attribute def Millisecond :> Real {
        unit = "ms";
    }

    attribute def Microsecond :> Real {
        unit = "us";
    }

    attribute def MeterPerSecond :> Real {
        unit = "m/s";
    }

    attribute def Volt :> Real {
        unit = "V";
    }

    attribute def Milliampere :> Real {
        unit = "mA";
    }

    attribute def DegreeCelsius :> Real {
        unit = "degC";
    }

    attribute def DistanceValue :> Real {
        unit = "m";
    }

    attribute def TimeOfFlightValue :> Real {
        unit = "us";
    }

    attribute def EchoAmplitudeValue :> Real {
        unit = "%";
    }

    item def TriggerPulse {
        attribute pulseWidth : Millisecond;
        attribute voltageLevel : Volt;
    }

    item def UltrasonicBurst {
        attribute carrierFrequency : FrequencyValue;
        attribute burstCycles : Integer;
        attribute acousticPressureLevel : Real;
    }

    item def EchoSignal {
        attribute timeOfFlight : TimeOfFlightValue;
        attribute amplitude : EchoAmplitudeValue;
        attribute valid : Boolean;
    }

    item def DistanceMeasurement {
        attribute distance : DistanceValue;
        attribute confidence : Percent;
        attribute timestamp : TimeValue;
        attribute status : MeasurementStatus;
    }

    item def TemperatureSample {
        attribute ambientTemperature : DegreeCelsius;
        attribute timestamp : TimeValue;
    }

    item def PowerInput {
        attribute supplyVoltage : Volt;
        attribute supplyCurrent : Milliampere;
    }

    item def HealthReport {
        attribute sensorReady : Boolean;
        attribute transducerFault : Boolean;
        attribute echoTimeout : Boolean;
        attribute temperatureFault : Boolean;
    }

    enum def MeasurementStatus {
        enum ok;
        enum noEcho;
        enum outOfRange;
        enum saturatedEcho;
        enum sensorFault;
    }

    port def ElectricalPowerPort {
        in item power : PowerInput;
    }

    port def MeasurementOutputPort {
        out item measurement : DistanceMeasurement;
        out item health : HealthReport;
    }

    port def TriggerPort {
        out item trigger : TriggerPulse;
    }

    port def EchoPort {
        in item echo : EchoSignal;
    }

    port def AcousticTransmitPort {
        out item burst : UltrasonicBurst;
    }

    port def AcousticReceivePort {
        in item reflectedEcho : EchoSignal;
    }

    port def TemperaturePort {
        out item temperature : TemperatureSample;
    }

    action def EmitUltrasonicBurst {
        in item trigger : TriggerPulse;
        out item burst : UltrasonicBurst;

        attribute nominalFrequency : FrequencyValue = 40000 [Hz];
        attribute burstCycles : Integer = 8;
    }

    action def ReceiveEcho {
        in item reflectedEcho : EchoSignal;
        out item echo : EchoSignal;

        attribute blankingTime : Microsecond = 250 [us];
        attribute maxEchoWait : Millisecond = 38 [ms];
    }

    action def MeasureAmbientTemperature {
        out item temperature : TemperatureSample;

        attribute samplingPeriod : Millisecond = 100 [ms];
        attribute validTemperatureMin : DegreeCelsius = -20 [degC];
        attribute validTemperatureMax : DegreeCelsius = 70 [degC];
    }

    action def ComputeSpeedOfSound {
        in item temperature : TemperatureSample;
        out speedOfSound : MeterPerSecond;

        attribute speedAtZeroCelsius : MeterPerSecond = 331.3 [m/s];
        attribute temperatureCoefficient : MeterPerSecond = 0.606 [m/s];
    }

    action def ComputeDistance {
        in item echo : EchoSignal;
        in speedOfSound : MeterPerSecond;
        out item measurement : DistanceMeasurement;

        attribute minimumDistance : DistanceValue = 0.02 [m];
        attribute maximumDistance : DistanceValue = 4.00 [m];
        attribute distanceResolution : DistanceValue = 0.003 [m];
    }

    action def PublishMeasurement {
        in item measurement : DistanceMeasurement;
        out item publishedMeasurement : DistanceMeasurement;
    }

    state def SensingUnitOperationalStates {
        entry; then Initializing;

        state Initializing;
        state Idle;
        state Triggering;
        state Listening;
        state Calculating;
        state Publishing;
        state Fault;

        transition first Initializing
            then Idle;

        transition Idle_to_Triggering
            first Idle
            accept triggerMeasurement
            then Triggering;

        transition Triggering_to_Listening
            first Triggering
            accept burstEmitted
            then Listening;

        transition Listening_to_Calculating
            first Listening
            accept echoDetected
            then Calculating;

        transition Listening_to_Fault
            first Listening
            accept echoTimeout
            then Fault;

        transition Calculating_to_Publishing
            first Calculating
            accept distanceComputed
            then Publishing;

        transition Publishing_to_Idle
            first Publishing
            accept measurementPublished
            then Idle;

        transition Fault_to_Idle
            first Fault
            accept faultCleared
            then Idle;
    }

    part def UltrasonicTransducer {
        port acousticTx : AcousticTransmitPort;
        port acousticRx : AcousticReceivePort;

        attribute carrierFrequency : FrequencyValue = 40000 [Hz];
        attribute beamAngle : PlaneAngleValue = 15 [deg];
        attribute ringDownTime : Microsecond = 220 [us];
        attribute maximumRange : DistanceValue = 4.00 [m];
        attribute minimumRange : DistanceValue = 0.02 [m];

        perform action emit : EmitUltrasonicBurst;
        perform action receive : ReceiveEcho;
    }

    part def TriggerDriver {
        port triggerOut : TriggerPort;

        attribute triggerVoltage : Volt = 5.0 [V];
        attribute triggerPulseWidth : Millisecond = 0.010 [ms];
        attribute repetitionPeriod : Millisecond = 60 [ms];
    }

    part def EchoConditioner {
        port echoIn : EchoPort;

        attribute gain : Real = 48.0;
        attribute detectionThreshold : Percent = 18 [%];
        attribute saturationThreshold : Percent = 95 [%];
        attribute timeout : Millisecond = 38 [ms];
    }

    part def TemperatureSensor {
        port temperatureOut : TemperaturePort;

        attribute accuracy : DegreeCelsius = 1.0 [degC];
        attribute updatePeriod : Millisecond = 100 [ms];

        perform action sampleTemperature : MeasureAmbientTemperature;
    }

    part def MeasurementProcessor {
        port echoInput : EchoPort;
        port temperatureInput : TemperaturePort;
        port measurementOutput : MeasurementOutputPort;

        attribute configuredMinimumDistance : DistanceValue = 0.02 [m];
        attribute configuredMaximumDistance : DistanceValue = 4.00 [m];
        attribute samplePeriod : Millisecond = 60 [ms];
        attribute nominalSpeedOfSound : MeterPerSecond = 343.0 [m/s];

        perform action computeSoundSpeed : ComputeSpeedOfSound;
        perform action computeDistance : ComputeDistance;
        perform action publish : PublishMeasurement;

        state operationalState : SensingUnitOperationalStates;
    }

    part def PowerRegulator {
        port powerIn : ElectricalPowerPort;

        attribute inputVoltageMin : Volt = 4.5 [V];
        attribute inputVoltageMax : Volt = 5.5 [V];
        attribute regulatedVoltage : Volt = 3.3 [V];
        attribute maximumCurrent : Milliampere = 80 [mA];
        attribute rippleLimit : Volt = 0.050 [V];
    }

    part def UltrasonicSensingUnit {
        port power : ElectricalPowerPort;
        port output : MeasurementOutputPort;

        part regulator : PowerRegulator;
        part triggerDriver : TriggerDriver;
        part transducer : UltrasonicTransducer;
        part echoConditioner : EchoConditioner;
        part temperatureSensor : TemperatureSensor;
        part processor : MeasurementProcessor;

        attribute measuredQuantity : String = "distance to nearest reflective target";
        attribute measurementRate : FrequencyValue = 16.7 [Hz];
        attribute operatingVoltage : Volt = 5.0 [V];
        attribute typicalCurrent : Milliampere = 25 [mA];
        attribute standbyCurrent : Milliampere = 2 [mA];
        attribute distanceAccuracy : DistanceValue = 0.01 [m];
        attribute distanceResolution : DistanceValue = 0.003 [m];
        attribute fieldOfView : PlaneAngleValue = 15 [deg];

        connect power.power to regulator.powerIn.power;
        connect triggerDriver.triggerOut.trigger to transducer.acousticTx.burst;
        connect transducer.acousticRx.reflectedEcho to echoConditioner.echoIn.echo;
        connect echoConditioner.echoIn.echo to processor.echoInput.echo;
        connect temperatureSensor.temperatureOut.temperature to processor.temperatureInput.temperature;
        connect processor.measurementOutput.measurement to output.measurement;
        connect processor.measurementOutput.health to output.health;
    }

    requirement def RelevantQuantityMeasurementRequirement {
        subject unit : UltrasonicSensingUnit;

        require constraint {
            unit.measuredQuantity == "distance to nearest reflective target"
        }
    }

    requirement def UltrasonicPrincipleRequirement {
        subject unit : UltrasonicSensingUnit;

        require constraint {
            unit.transducer.carrierFrequency >= 39000 [Hz] and
            unit.transducer.carrierFrequency <= 41000 [Hz]
        }
    }

    requirement def RangeRequirement {
        subject unit : UltrasonicSensingUnit;

        require constraint {
            unit.processor.configuredMinimumDistance <= 0.02 [m] and
            unit.processor.configuredMaximumDistance >= 4.00 [m]
        }
    }

    requirement def AccuracyRequirement {
        subject unit : UltrasonicSensingUnit;

        require constraint {
            unit.distanceAccuracy <= 0.01 [m]
        }
    }

    requirement def UpdateRateRequirement {
        subject unit : UltrasonicSensingUnit;

        require constraint {
            unit.measurementRate >= 10 [Hz]
        }
    }

    requirement def EchoTimeoutRequirement {
        subject unit : UltrasonicSensingUnit;

        require constraint {
            unit.echoConditioner.timeout <= 40 [ms]
        }
    }

    requirement def PowerRequirement {
        subject unit : UltrasonicSensingUnit;

        require constraint {
            unit.operatingVoltage >= 4.5 [V] and
            unit.operatingVoltage <= 5.5 [V] and
            unit.typicalCurrent <= 30 [mA]
        }
    }

    requirement def TemperatureCompensationRequirement {
        subject unit : UltrasonicSensingUnit;

        require constraint {
            unit.temperatureSensor.accuracy <= 1.0 [degC]
        }
    }

    satisfy RelevantQuantityMeasurementRequirement by UltrasonicSensingUnit;
    satisfy UltrasonicPrincipleRequirement by UltrasonicSensingUnit;
    satisfy RangeRequirement by UltrasonicSensingUnit;
    satisfy AccuracyRequirement by UltrasonicSensingUnit;
    satisfy UpdateRateRequirement by UltrasonicSensingUnit;
    satisfy EchoTimeoutRequirement by UltrasonicSensingUnit;
    satisfy PowerRequirement by UltrasonicSensingUnit;
    satisfy TemperatureCompensationRequirement by UltrasonicSensingUnit;

    part sensingUnit : UltrasonicSensingUnit;

}