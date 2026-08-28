package AngularRateSensingUnitModel {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;

    item def AnalogSignal {
        attribute value :> ISQ::angularVelocity;
    }
    item def DigitalData {
        attribute value :> ISQ::angularVelocity;
        attribute timestamp :> ISQ::time;
    }
    item def Power {
        attribute voltage :> ISQ::voltage;
    }

    attribute def PowerOn;
    attribute def WarmupComplete;
    attribute def CalibrationComplete;
    attribute def FaultDetected;
    attribute def SystemReset;

    port def PowerInPort {
        in item power : Power;
    }
    port def PowerOutPort {
        out item power : Power;
    }
    port def AnalogOutPort {
        out item signal : AnalogSignal;
    }
    port def AnalogInPort {
        in item signal : AnalogSignal;
    }
    port def DigitalOutPort {
        out item data : DigitalData;
    }
    port def DigitalInPort {
        in item data : DigitalData;
    }
    port def ControlPort {
        in attribute resetCmd : SystemReset;
        out attribute faultFlag : FaultDetected;
    }

    action def DetectRotation {
        out item rawSignal : AnalogSignal;
    }
    action def Amplify {
        in item inSignal : AnalogSignal;
        out item outSignal : AnalogSignal;
    }
    action def FilterSignal {
        in item inSignal : AnalogSignal;
        out item outSignal : AnalogSignal;
    }
    action def Convert {
        in item analogIn : AnalogSignal;
        out item digitalOut : DigitalData;
    }
    action def ProcessData {
        in item digitalIn : DigitalData;
        out item processedData : DigitalData;
    }
    action def PerformCalibration;
    action def EnterSafeMode;
    action def StabilizeComponents;

    action def MeasureCycle {
        action acquire : DetectRotation;
        action amplify : Amplify;
        action filterSig : FilterSignal;
        action convert : Convert;
        action outputData : ProcessData;
        flow acquire.rawSignal to amplify.inSignal;
        flow amplify.outSignal to filterSig.inSignal;
        flow filterSig.outSignal to convert.analogIn;
        flow convert.digitalOut to outputData.digitalIn;
    }

    part def GyroscopicElement {
        port rawOut : AnalogOutPort;
        perform action detectRotation : DetectRotation;
    }

    part def Amplifier {
        attribute gain : ScalarValues::Real = 10.0;
        port ampIn : AnalogInPort;
        port ampOut : AnalogOutPort;
        perform action amplify : Amplify;
    }

    part def LowPassFilter {
        attribute cutoffFrequency :> ISQ::frequency = 100 [Hz];
        port filterIn : AnalogInPort;
        port filterOut : AnalogOutPort;
        perform action filterSig : FilterSignal;
    }

    part def SignalProcessor {
        port rawIn : AnalogInPort;
        port processedOut : AnalogOutPort;

        part amplifier : Amplifier;
        part lowPassFilter : LowPassFilter;

        connect rawIn to amplifier.ampIn;
        connect amplifier.ampOut to lowPassFilter.filterIn;
        connect lowPassFilter.filterOut to processedOut;
    }

    part def AnalogToDigitalConverter {
        attribute samplingRate :> ISQ::frequency = 1000 [Hz];
        attribute bitResolution : ScalarValues::Integer = 16;
        port analogIn : AnalogInPort;
        port digitalOut : DigitalOutPort;
        perform action convert : Convert;
    }

    part def AngularRateSensor {
        port powerIn : PowerInPort;
        port analogOut : AnalogOutPort;
        port digitalOut : DigitalOutPort;

        part gyroElement : GyroscopicElement;
        part signalProcessor : SignalProcessor;
        part adc : AnalogToDigitalConverter;

        connect gyroElement.rawOut to signalProcessor.rawIn;
        connect signalProcessor.processedOut to analogOut;
        connect signalProcessor.processedOut to adc.analogIn;
        connect adc.digitalOut to digitalOut;
    }

    part def PowerSupplyModule {
        port mainPower : PowerInPort;
        port regulatedPower : PowerOutPort;
        attribute outputVoltage :> ISQ::voltage = 5 [V];
    }

    part def DataProcessor {
        port digitalIn : DigitalInPort;
        port processedOut : DigitalOutPort;
        perform action processData : ProcessData;
    }

    state def UnitStates {
        entry; then off;
        state off;
        transition 'off-warmup'
            first off
            accept PowerOn
            then warmup;
        state warmup;
        transition 'warmup-calibration'
            first warmup
            accept WarmupComplete
            then selfCalibration;
        state selfCalibration;
        transition 'calibration-measuring'
            first selfCalibration
            accept CalibrationComplete
            then measuring;
        state measuring;
        transition 'measuring-fault'
            first measuring
            accept FaultDetected
            then fault;
        state fault;
        transition 'fault-off'
            first fault
            accept SystemReset
            then off;
    }

    part def AngularRateSensingUnit {
        port mainPowerPort : PowerInPort;
        port analogOutputPort : AnalogOutPort;
        port digitalOutputPort : DigitalOutPort;
        port controlPort : ControlPort;

        attribute maxRate :> ISQ::angularVelocity = 500 [rad/s];
        attribute accuracy : ScalarValues::Real = 0.01;
        attribute trueAngularRate :> ISQ::angularVelocity;

        part powerSupply : PowerSupplyModule;
        part sensor : AngularRateSensor;
        part dataProcessor : DataProcessor;

        connect mainPowerPort to powerSupply.mainPower;
        connect powerSupply.regulatedPower to sensor.powerIn;
        connect sensor.analogOut to analogOutputPort;
        connect sensor.digitalOut to dataProcessor.digitalIn;
        connect dataProcessor.processedOut to digitalOutputPort;

        perform action measureCycle : MeasureCycle;
        exhibit state unitStates : UnitStates;
    }

    requirement def PerformanceSpec {
        doc /* Performance requirements for the Angular Rate Sensing Unit */
        subject unit : AngularRateSensingUnit;
        requirement maxRateReq {
            doc /* The unit shall measure rotation speeds up to 500 rad/s. */
            subject = unit;
            constraint {
                unit.maxRate >= 500 [rad/s]
            }
        }
        requirement accuracyReq {
            doc /* The unit shall have an accuracy of at least ±1%. */
            subject = unit;
            constraint {
                unit.accuracy <= 0.01
            }
        }
    }

    part angularRateUnit : AngularRateSensingUnit;

    requirement performance : PerformanceSpec {
        subject = angularRateUnit;
    }
}
