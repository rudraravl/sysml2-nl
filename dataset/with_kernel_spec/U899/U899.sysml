package SuddenMotionSensingUnitModel {
    private import ScalarValues::*;
    private import ISQ::*;
    private import Time::*;

    package Definitions {
        attribute def AccelerationValue :> ISQ::acceleration;
        attribute def VoltageValue :> ISQ::electricPotential;
        attribute def TimeValue :> ISQ::time;
        attribute def PowerValue :> ISQ::power;

        item def Acceleration3D {
            attribute x : AccelerationValue;
            attribute y : AccelerationValue;
            attribute z : AccelerationValue;
        }
        item def AnalogSignal {
            attribute voltage : VoltageValue;
        }
        item def DigitalData {
            attribute x : Integer;
            attribute y : Integer;
            attribute z : Integer;
        }
        item def MotionEvent {
            attribute timestamp : Time::DateTime;
            attribute severity : AccelerationValue;
        }

        attribute def ActivateCommand;
        attribute def DeactivateCommand;
        attribute def InitializationComplete;
        attribute def MotionDetected;
        attribute def EventReported;

        port def AnalogOutPort {
            out signal : AnalogSignal;
        }
        port def AnalogInPort {
            in signal : AnalogSignal;
        }
        port def DigitalOutPort {
            out data : DigitalData;
        }
        port def DigitalInPort {
            in data : DigitalData;
        }
        port def CalibratedOutPort {
            out data : Acceleration3D;
        }
        port def CalibratedInPort {
            in data : Acceleration3D;
        }
        port def EventOutPort {
            out motionEvent : MotionEvent;
        }
        port def CommandInPort {
            in activate : ActivateCommand;
            in deactivate : DeactivateCommand;
        }

        action def MeasureRawAcceleration {
            out rawSignal : AnalogSignal;
        }
        action def ConditionSignal {
            in rawSignal : AnalogSignal;
            out conditionedSignal : AnalogSignal;
        }
        action def ConvertToDigital {
            in analogSignal : AnalogSignal;
            out digitalData : DigitalData;
        }
        action def ApplyCalibration {
            in rawData : DigitalData;
            out calibratedData : Acceleration3D;
        }
        action def AnalyzeMotion {
            in data : Acceleration3D;
            in threshold : AccelerationValue;
            out motionEvent : MotionEvent;
            out detected : MotionDetected;
        }
        action def PerformSelfCheck {
            out initializationComplete : InitializationComplete;
        }
        action def EnterLowPowerMode;
        action def ReportEvent {
            out eventReported : EventReported;
        }
        action def PerformSensingCycle;

        part def MemsAccelerometer {
            port rawOut : AnalogOutPort;
            perform action measureRawAcceleration : MeasureRawAcceleration;
        }
        part def SignalConditioner {
            port rawIn : AnalogInPort;
            port conditionedOut : AnalogOutPort;
            perform action condition : ConditionSignal;
        }
        part def AnalogToDigitalConverter {
            port analogIn : AnalogInPort;
            port digitalOut : DigitalOutPort;
            perform action convert : ConvertToDigital;
        }
        part def DataProcessor {
            port digitalIn : DigitalInPort;
            port calibratedOut : CalibratedOutPort;
            perform action calibrate : ApplyCalibration;
        }
        part def EventAnalyzer {
            port dataIn : CalibratedInPort;
            attribute threshold : AccelerationValue;
            port eventOut : EventOutPort;
            perform action analyze : AnalyzeMotion;
        }
        part def SensorAssembly {
            part accelerometer : MemsAccelerometer;
            part conditioner : SignalConditioner;
            part adc : AnalogToDigitalConverter;
            connect accelerometer.rawOut to conditioner.rawIn;
            connect conditioner.conditionedOut to adc.analogIn;
        }
        part def SuddenMotionSensingUnit {
            port commandPort : CommandInPort;
            port eventPort : EventOutPort;
            attribute threshold : AccelerationValue;
            part sensorAssembly : SensorAssembly;
            part processor : DataProcessor;
            part analyzer : EventAnalyzer;
            connect sensorAssembly.adc.digitalOut to processor.digitalIn;
            connect processor.calibratedOut to analyzer.dataIn;
            connect analyzer.eventOut to eventPort;
            perform action selfCheck : PerformSelfCheck;
            perform action enterLowPowerMode : EnterLowPowerMode;
            perform action sensingCycle : PerformSensingCycle;
            perform action reportEvent : ReportEvent;
            exhibit state unitStates : UnitStates;
        }

        state def UnitStates {
            entry; then initialization;
            state initialization {
                entry PerformSelfCheck;
                accept InitializationComplete then standby;
            }
            state standby {
                entry EnterLowPowerMode;
                accept ActivateCommand then active;
            }
            state active {
                do PerformSensingCycle;
                accept MotionDetected then alert;
                accept DeactivateCommand then standby;
            }
            state alert {
                entry ReportEvent;
                accept EventReported then active;
            }
        }

        requirement def ResponseTimeRequirement {
            doc /* The sensing unit shall detect and report a sudden motion event within 5 milliseconds. */
            attribute maxResponseTime : TimeValue;
        }
        requirement def StandbyPowerRequirement {
            doc /* The sensing unit shall consume no more than 10 milliwatts in standby mode. */
            attribute maxStandbyPower : PowerValue;
        }
        requirement def DetectionThresholdRequirement {
            doc /* The sensing unit shall report an event when the measured acceleration exceeds the configured threshold. */
            attribute threshold : AccelerationValue;
        }
    }

    package Usages {
        private import Definitions::*;

        part smsUnit : SuddenMotionSensingUnit {
            attribute threshold : AccelerationValue = 20.0 [m/s^2];
        }

        requirement responseTimeReq : ResponseTimeRequirement {
            attribute redefines maxResponseTime = 5 [ms];
        }
        requirement standbyPowerReq : StandbyPowerRequirement {
            attribute redefines maxStandbyPower = 10 [mW];
        }
        requirement detectionThresholdReq : DetectionThresholdRequirement {
            attribute redefines threshold = smsUnit.threshold;
        }
        satisfy responseTimeReq by smsUnit;
        satisfy standbyPowerReq by smsUnit;
        satisfy detectionThresholdReq by smsUnit;
    }
}
