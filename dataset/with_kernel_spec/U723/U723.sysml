package ImpactSensingUnitModel {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;

    attribute def AccelerationValue :> ISQ::acceleration;
    attribute def FrequencyValue :> ISQ::frequency;
    attribute def TimeValue :> ISQ::time;
    attribute def DirectionValue :> ScalarValues::Real;

    item def RawAcceleration {
        attribute value : AccelerationValue[3];
    }
    item def RefinedAcceleration {
        attribute value : AccelerationValue[3];
    }
    item def ImpactEvent {
        attribute magnitude : AccelerationValue;
        attribute direction : DirectionValue[3];
        attribute timestamp : TimeValue;
    }
    item def Power {
        attribute voltage : ScalarValues::Real;
        attribute current : ScalarValues::Real;
    }

    item def StartSignal;
    item def StopSignal;
    item def ImpactDetected;
    item def RecordingComplete;

    port def RawAccelerationOutPort {
        out rawAcc : RawAcceleration;
    }
    port def RawAccelerationInPort {
        in rawAcc : RawAcceleration;
    }
    port def RefinedAccelerationOutPort {
        out refAcc : RefinedAcceleration;
    }
    port def RefinedAccelerationInPort {
        in refAcc : RefinedAcceleration;
    }
    port def ImpactEventOutPort {
        out impactEvt : ImpactEvent;
        out continuousAcc : RefinedAcceleration;
    }
    port def ImpactEventInPort {
        in impactEvt : ImpactEvent;
        in continuousAcc : RefinedAcceleration;
    }
    port def PowerOutPort {
        out power : Power;
    }
    port def PowerInPort {
        in power : Power;
    }
    port def ExternalDataPort {
        out impactEvt : ImpactEvent;
        out continuousAcc : RefinedAcceleration;
    }

    action def MeasureAcceleration {
        out raw : RawAcceleration;
    }
    action def ProcessSignal {
        in raw : RawAcceleration;
        out refined : RefinedAcceleration;
    }
    action def DetectImpact {
        in refined : RefinedAcceleration;
        out impactEvt : ImpactEvent;
    }
    action def LogData {
        in impactEvt : ImpactEvent;
        in continuousAcc : RefinedAcceleration;
    }

    state def UnitStates {
        entry; then idle;
        state idle;
        transition idle_to_sensing
            first idle
            accept StartSignal
            then sensing;
        state sensing {
            entry; then monitoring;
            state monitoring;
            transition monitoring_to_recording
                first monitoring
                accept ImpactDetected
                then recording;
            state recording;
            transition recording_to_monitoring
                first recording
                accept RecordingComplete
                then monitoring;
        }
        transition sensing_to_idle
            first sensing
            accept StopSignal
            then idle;
    }

    part def Accelerometer {
        port rawPort : RawAccelerationOutPort;
        perform MeasureAcceleration;
    }

    part def SignalProcessor {
        port rawPort : RawAccelerationInPort;
        port refinedPort : RefinedAccelerationOutPort;
        perform ProcessSignal;
    }

    part def ImpactDetector {
        port refinedPort : RefinedAccelerationInPort;
        port eventPort : ImpactEventOutPort;
        attribute threshold : AccelerationValue;
        perform DetectImpact;
    }

    part def ImpactSensor {
        part accelerometer : Accelerometer;
        part signalProcessor : SignalProcessor;
        part impactDetector : ImpactDetector;

        port powerPort : PowerInPort;
        port eventPort : ImpactEventOutPort;

        flow rawFlow of RawAcceleration
            from accelerometer.rawPort.rawAcc to signalProcessor.rawPort.rawAcc;
        flow refinedFlow of RefinedAcceleration
            from signalProcessor.refinedPort.refAcc to impactDetector.refinedPort.refAcc;

        bind eventPort.impactEvt = impactDetector.eventPort.impactEvt;
        bind eventPort.continuousAcc = impactDetector.eventPort.continuousAcc;
    }

    part def PowerSupply {
        port powerPort : PowerOutPort;
    }

    part def DataLogger {
        port eventPort : ImpactEventInPort;
        port powerPort : PowerInPort;
        perform LogData;
    }

    part def ImpactSensingUnit {
        exhibit state unitStates : UnitStates;
        part impactSensor : ImpactSensor;
        part powerSupply : PowerSupply;
        part dataLogger : DataLogger;
        port externalPort : ExternalDataPort;

        flow powerFlow1 of Power
            from powerSupply.powerPort.power to impactSensor.powerPort.power;
        flow powerFlow2 of Power
            from powerSupply.powerPort.power to dataLogger.powerPort.power;

        flow eventFlow of ImpactEvent
            from impactSensor.eventPort.impactEvt to dataLogger.eventPort.impactEvt;
        flow continuousFlow of RefinedAcceleration
            from impactSensor.eventPort.continuousAcc to dataLogger.eventPort.continuousAcc;

        bind externalPort.impactEvt = impactSensor.eventPort.impactEvt;
        bind externalPort.continuousAcc = impactSensor.eventPort.continuousAcc;
    }

    requirement def PerformanceRequirements {
        requirement samplingRateRequirement {
            doc /* The system shall sample acceleration at a rate of at least 1000 Hz. */
            attribute minSamplingRate : FrequencyValue;
        }
        requirement impactThresholdRequirement {
            doc /* The system shall register an impact event if acceleration exceeds 50 m/s^2. */
            attribute threshold : AccelerationValue;
        }
        requirement responseTimeRequirement {
            doc /* The system shall record an impact event within 10 milliseconds of occurrence. */
            attribute maxResponseTime : TimeValue;
        }
    }

    part impactSensingUnit : ImpactSensingUnit;

    requirement performanceRequirements : PerformanceRequirements;

    satisfy performanceRequirements by impactSensingUnit;
}
