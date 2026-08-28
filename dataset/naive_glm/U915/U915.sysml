package ThrottlePositionSensingUnit {
    import ScalarValues::*;
    
    unit deg;
    unit V;
    unit percent;
    unit ms;
    
    def AngleValue :> RealValue { unit = deg; }
    def VoltageValue :> RealValue { unit = V; }
    def PercentageValue :> RealValue { unit = percent; }
    def TimeValue :> RealValue { unit = ms; }

    item def RawSignal {
        attribute angle : AngleValue;
        attribute voltage : VoltageValue;
        attribute openPercentage : PercentageValue;
    }
    
    item def ProcessedSignal {
        attribute angle : AngleValue;
        attribute voltage : VoltageValue;
        attribute openPercentage : PercentageValue;
    }

    requirement def AccuracyRequirement {
        attribute accuracy : PercentageValue = 0.5;
        doc /* The system shall measure throttle position with an accuracy of +/- 0.5%. */
    }
    
    requirement def ResponseTimeRequirement {
        attribute responseTime : TimeValue = 10;
        doc /* The system shall respond to throttle changes in under 10 milliseconds. */
    }

    part def ThrottleShaft {
        attribute currentAngle : AngleValue;
    }

    part def ThrottlePositionSensor {
        port out rawSignalOut : RawSignal;
        attribute minVoltage : VoltageValue = 0.5;
        attribute maxVoltage : VoltageValue = 4.5;
        
        action def MeasureAngle {
            in shaftAngle : AngleValue;
            out signal : RawSignal;
        }
    }

    part def SignalProcessor {
        port in rawSignalIn : RawSignal;
        port out processedSignalOut : ProcessedSignal;
        
        action def ProcessSignal {
            in raw : RawSignal;
            out processed : ProcessedSignal;
        }
    }

    part def ControlModule {
        port in processedSignalIn : ProcessedSignal;
        
        action def MakeDecisions {
            in signal : ProcessedSignal;
        }
    }

    part def ThrottlePositionSensingSystem {
        part throttleShaft : ThrottleShaft;
        part tps : ThrottlePositionSensor;
        part signalProcessor : SignalProcessor;
        part controlModule : ControlModule;
        
        connection mechLink from tps to throttleShaft;
        connection rawFlow from tps.rawSignalOut to signalProcessor.rawSignalIn;
        connection processedFlow from signalProcessor.processedSignalOut to controlModule.processedSignalIn;
        
        requirement accuracy : AccuracyRequirement;
        requirement responseTime : ResponseTimeRequirement;
        
        action def SelfTest;
        action def Calibrate;
        action def ContinuousMeasurement;
        action def LogError;
        action def RunDiagnostics;
        
        state def SystemStates {
            attribute isPoweredOn : Boolean;
            attribute isInitialized : Boolean;
            attribute faultDetected : Boolean;
            attribute faultCleared : Boolean;

            state PoweredOff;
            state Initializing {
                entry { action selfTest : SelfTest; }
                do { action calibrate : Calibrate; }
            }
            state Measuring {
                do { action continuousMeasurement : ContinuousMeasurement; }
            }
            state Fault {
                entry { action logError : LogError; }
                do { action runDiagnostics : RunDiagnostics; }
            }
            
            transition from PoweredOff to Initializing when isPoweredOn;
            transition from Initializing to Measuring when isInitialized;
            transition from Measuring to Fault when faultDetected;
            transition from Fault to Measuring when faultCleared;
        }
        
        state systemBehavior : SystemStates;
    }
}
