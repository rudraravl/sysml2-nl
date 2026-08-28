package 'Displacement Receiver System' {
    public import ScalarValues::*;

    attribute def Displacement :> Real;
    attribute def Voltage :> Real;
    attribute def Frequency :> Real;
    attribute def ResolutionBits :> Integer;
    attribute def Gain :> Real;
    attribute def Sensitivity :> Real;

    item def RawSignal {
        amplitude : Voltage;
    }
    item def ConditionedSignal {
        amplitude : Voltage;
    }
    item def DigitalSample {
        code : Integer;
    }
    item def PositionData {
        position : Displacement;
        valid : Boolean;
    }
    item def CalibrationData {
        offset : Displacement;
        gainMultiplier : Gain;
    }

    attribute def StartMeasurement;
    attribute def StopMeasurement;
    attribute def CalibrateCommand;
    attribute def ResetCommand;
    attribute def FaultDetected;
    attribute def SelfTestPassed;
    attribute def SelfTestFailed;
    attribute def RawSignalAcquired;
    attribute def ConditionedSignalAcquired;
    attribute def DigitalSampleAcquired;
    attribute def PositionComputed;
    attribute def CalibrationDone;

    port def DisplacementInPort {
        in displacement : Displacement;
    }
    port def RawSignalOutPort {
        out rawSignal : RawSignal;
    }
    port def RawSignalInPort {
        in rawSignal : RawSignal;
    }
    port def ConditionedSignalOutPort {
        out conditionedSignal : ConditionedSignal;
    }
    port def ConditionedSignalInPort {
        in conditionedSignal : ConditionedSignal;
    }
    port def DigitalSampleOutPort {
        out digitalSample : DigitalSample;
    }
    port def DigitalSampleInPort {
        in digitalSample : DigitalSample;
    }
    port def PositionDataOutPort {
        out positionData : PositionData;
    }

    action def PerformSelfTest {
        out passed : Boolean;
    }
    action def AcquireRawSignal {
        in displacement : Displacement;
        out rawSignal : RawSignal;
    }
    action def ConditionRawSignal {
        in rawSignal : RawSignal;
        out conditionedSignal : ConditionedSignal;
    }
    action def ConvertToDigital {
        in conditionedSignal : ConditionedSignal;
        out digitalSample : DigitalSample;
    }
    action def ComputePosition {
        in digitalSample : DigitalSample;
        in calibration : CalibrationData;
        out positionData : PositionData;
    }
    action def RunCalibration {
        in digitalSample : DigitalSample;
        out calibration : CalibrationData;
    }

    part def SensorCore {
        port displacementIn : DisplacementInPort;
        port rawSignalOut : RawSignalOutPort;
        attribute sensitivity : Sensitivity = 0.002;
        attribute linearRange : Displacement = 50.0;
    }

    part def SignalConditioner {
        port rawSignalIn : RawSignalInPort;
        port conditionedSignalOut : ConditionedSignalOutPort;
        attribute cutoffFrequency : Frequency = 10000.0;
        attribute gain : Gain = 10.0;
    }

    part def AnalogToDigitalConverter {
        port conditionedSignalIn : ConditionedSignalInPort;
        port digitalSampleOut : DigitalSampleOutPort;
        attribute samplingRate : Frequency = 1000.0;
        attribute resolutionBits : ResolutionBits = 16;
    }

    part def DataProcessor {
        port digitalSampleIn : DigitalSampleInPort;
        port positionDataOut : PositionDataOutPort;
        attribute calibration : CalibrationData;
    }

    state def ReceiverStates {
        entry; then initializing;

        state initializing;
        do action performSelfTest;
        accept SelfTestPassed then ready;
        accept SelfTestFailed then fault;

        state ready;
        accept StartMeasurement then sensing;
        accept CalibrateCommand then calibrating;

        state sensing;
        do action acquireRaw;
        accept RawSignalAcquired then conditioning;
        accept StopMeasurement then ready;

        state conditioning;
        do action conditionRaw;
        accept ConditionedSignalAcquired then digitizing;
        accept StopMeasurement then ready;

        state digitizing;
        do action convertDigital;
        accept DigitalSampleAcquired then processing;
        accept StopMeasurement then ready;

        state processing;
        do action computePos;
        accept PositionComputed then ready;
        accept StopMeasurement then ready;

        state calibrating;
        do action runCalib;
        accept CalibrationDone then ready;

        state fault;
        accept ResetCommand then initializing;
    }

    part def DisplacementReceiver {
        part sensor : SensorCore;
        part conditioner : SignalConditioner;
        part adc : AnalogToDigitalConverter;
        part processor : DataProcessor;

        port displacementInput : DisplacementInPort;
        port positionOutput : PositionDataOutPort;

        connect displacementInput to sensor.displacementIn;
        connect sensor.rawSignalOut to conditioner.rawSignalIn;
        connect conditioner.conditionedSignalOut to adc.conditionedSignalIn;
        connect adc.digitalSampleOut to processor.digitalSampleIn;
        connect processor.positionDataOut to positionOutput;

        exhibit ReceiverStates;
    }

    requirement def MeasurementRangeRequirement {
        attribute minDisplacement : Displacement;
        attribute maxDisplacement : Displacement;
    }

    requirement def AccuracyRequirement {
        attribute tolerance : Displacement;
    }

    requirement def RepeatabilityRequirement {
        attribute maxDeviation : Displacement;
    }

    requirement def SamplingRateRequirement {
        attribute minRate : Frequency;
    }

    requirement def ResolutionRequirement {
        attribute bits : ResolutionBits;
    }

    requirement systemMeasurementRange : MeasurementRangeRequirement {
        minDisplacement = 0.0;
        maxDisplacement = 50.0;
    }

    requirement systemAccuracy : AccuracyRequirement {
        tolerance = 0.01;
    }

    requirement systemRepeatability : RepeatabilityRequirement {
        maxDeviation = 0.005;
    }

    requirement systemSamplingRate : SamplingRateRequirement {
        minRate = 1000.0;
    }

    requirement systemResolution : ResolutionRequirement {
        bits = 16;
    }

    part displacementReceiver : DisplacementReceiver;
}
