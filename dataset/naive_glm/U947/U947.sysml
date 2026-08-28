package WheelSpeedSensingSystem {
    import ISQ::*;
    import ScalarValues::*;

    value type Voltage :> Real { unit "V"; }
    value type Frequency :> Real { unit "Hz"; }
    value type AngularVelocity :> Real { unit "rad/s"; }
    value type LinearSpeed :> Real { unit "m/s"; }
    value type Temperature :> Real { unit "degC"; }
    value type QualityScore :> Real { unit "1"; }
    value type ToothCount :> Integer { unit "1"; }
    value type FaultCode :> Integer { unit "1"; }

    item def RawSignal {
        attribute voltage : Voltage;
        attribute frequency : Frequency;
    }

    item def CleanSignal {
        attribute voltage : Voltage;
        attribute frequency : Frequency;
    }

    item def SpeedDataPackage {
        attribute speed : LinearSpeed;
        attribute angularVelocity : AngularVelocity;
        attribute timestamp : Time;
        attribute quality : QualityScore;
    }

    item def DiagnosticData {
        attribute status : String;
        attribute faultCode : FaultCode;
        attribute temperature : Temperature;
    }

    port def MagneticFieldPort {
        out fieldVariation : Boolean;
    }

    port def RawSignalPort {
        out signal : RawSignal;
    }

    port def CleanSignalPort {
        out signal : CleanSignal;
    }

    port def SpeedDataPort {
        out data : SpeedDataPackage;
    }

    port def DiagnosticPort {
        out data : DiagnosticData;
    }

    part def ToneRing {
        attribute teethCount : ToothCount;
        attribute radius : Length;
        port magneticFieldPort : MagneticFieldPort;
    }

    part def SensingElement {
        port magneticInput : MagneticFieldPort;
        port rawOutput : RawSignalPort;
    }

    part def SignalConditioner {
        port rawInput : RawSignalPort;
        port cleanOutput : CleanSignalPort;
    }

    part def SpeedCalculator {
        port cleanInput : CleanSignalPort;
        port speedOutput : SpeedDataPort;
        port diagOutput : DiagnosticPort;
        
        attribute wheelRadius : Length;
        attribute toneRingTeeth : ToothCount;
    }

    part def Casing {
        attribute material : String = "Stainless Steel";
        attribute rating : String = "IP67";
    }

    part def WheelSpeedSensor {
        part casing : Casing;
        part sensingElement : SensingElement;
        part signalConditioner : SignalConditioner;
        part speedCalculator : SpeedCalculator;
        
        port magneticInputPort : MagneticFieldPort;
        port speedDataPort : SpeedDataPort;
        port diagnosticPort : DiagnosticPort;
        
        connection magneticConn connect magneticInputPort to sensingElement.magneticInput;
        connection rawConn connect sensingElement.rawOutput to signalConditioner.rawInput;
        connection cleanConn connect signalConditioner.cleanOutput to speedCalculator.cleanInput;
        connection speedOutConn connect speedCalculator.speedOutput to speedDataPort;
        connection diagOutConn connect speedCalculator.diagOutput to diagnosticPort;
        
        action def doInit { }
        action def doSelfCheck { }
        action def doMeasure { }
        action def doReportFault { }
        action def doRecover { }
        
        attribute checkPassed : Boolean;
        attribute faultDetected : Boolean;
        attribute recoveryAttempted : Boolean;
        attribute recoverySuccessful : Boolean;
        
        state def SensorStates {
            state Initializing {
                entry action doInit();
            }
            state SelfCheck {
                entry action doSelfCheck();
            }
            state Operational {
                entry action doMeasure();
            }
            state Fault {
                entry action doReportFault();
            }
            state Recovery {
                entry action doRecover();
            }
            
            transition init_to_check 
                first Initializing 
                then SelfCheck;
                
            transition check_to_op 
                first SelfCheck 
                then Operational 
                if checkPassed;
                
            transition check_to_fault 
                first SelfCheck 
                then Fault 
                if !checkPassed;
                
            transition op_to_fault 
                first Operational 
                then Fault 
                if faultDetected;
                
            transition fault_to_rec 
                first Fault 
                then Recovery 
                if recoveryAttempted;
                
            transition rec_to_op 
                first Recovery 
                then Operational 
                if recoverySuccessful;
                
            transition rec_to_fault 
                first Recovery 
                then Fault 
                if !recoverySuccessful;
        }
        
        exhibit stateMachine : SensorStates;
    }

    part def WheelSpeedSensingSystem {
        part toneRing : ToneRing {
            attribute teethCount : ToothCount = 48;
            attribute radius : Length = 0.3 [m];
        }
        part sensor : WheelSpeedSensor;
        
        connection magneticLink connect toneRing.magneticFieldPort to sensor.magneticInputPort;
    }

    requirement def MeasureWheelSpeed {
        subject system : WheelSpeedSensingSystem;
        objective {
            doc "The system shall accurately measure the rotational speed of a vehicle's wheel."
        }
    }

    requirement def EnvironmentalProtection {
        subject sensor : WheelSpeedSensor;
        objective {
            doc "The sensor shall be housed in an IP67-rated stainless steel casing."
        }
    }

    requirement def SelfDiagnostics {
        subject sensor : WheelSpeedSensor;
        objective {
            doc "The sensor shall continuously perform self-diagnostics checking power supply, signal quality, and internal temperature."
        }
    }

    requirement def DataOutput {
        subject sensor : WheelSpeedSensor;
        objective {
            doc "The sensor shall output a structured data package containing calculated speed, timestamp, and quality score."
        }
    }
}
