package DigitalForceGaugeSystem {
    import ScalarValues::*;
    
    // Value Types (Units)
    attribute def ForceN :> Real; // Newtons
    attribute def VoltageV :> Real; // Volts
    attribute def Hertz :> Real; // Hz
    attribute def Amps :> Real; // Amperes
    
    // Items
    item def MechanicalForce;
    item def AnalogSignal;
    item def DigitalData;
    item def DisplayData;
    item def ElectricPower;
    item def CalibrationReferenceForce;
    
    // Ports
    port def ForceInPort { in item MechanicalForce; }
    port def AnalogOutPort { out item AnalogSignal; }
    port def AnalogInPort { in item AnalogSignal; }
    port def DigitalOutPort { out item DigitalData; }
    port def DigitalInPort { in item DigitalData; }
    port def DisplayOutPort { out item DisplayData; }
    port def DisplayInPort { in item DisplayData; }
    port def PowerOutPort { out item ElectricPower; }
    port def PowerInPort { in item ElectricPower; }
    port def CalibrationInPort { in item CalibrationReferenceForce; }
    
    // Events for state machine
    occurrence def StartMeasurementEvent;
    occurrence def StopMeasurementEvent;
    occurrence def StartCalibrationEvent;
    occurrence def CalibrationCompleteEvent;
    
    // Component Definitions
    part def StrainGaugeSensor {
        port forceIn : ForceInPort;
        port voltageOut : AnalogOutPort;
        port powerIn : PowerInPort;
        
        attribute maxCapacity : ForceN = 5000;
        attribute sensitivity : Real = 0.002; // V/N
    }
    
    part def SignalAmplifier {
        port voltageIn : AnalogInPort;
        port voltageOut : AnalogOutPort;
        port powerIn : PowerInPort;
        
        attribute gain : Real = 1000;
    }
    
    part def AnalogToDigitalConverter {
        port voltageIn : AnalogInPort;
        port digitalOut : DigitalOutPort;
        port powerIn : PowerInPort;
        
        attribute samplingRate : Hertz = 1000;
        attribute resolutionBits : Integer = 16;
    }
    
    part def Microprocessor {
        port dataIn : DigitalInPort;
        port displayOut : DisplayOutPort;
        port powerIn : PowerInPort;
        port calibrationIn : CalibrationInPort;
        
        attribute calibrationFactor : Real = 1.0;
        attribute zeroOffset : Integer = 0;
        attribute currentReading : ForceN;
        
        state operatingState {
            state idle;
            state measuring;
            state calibrating;
            
            transition initial to idle;
            transition from idle to measuring accept StartMeasurementEvent;
            transition from measuring to idle accept StopMeasurementEvent;
            transition from idle to calibrating accept StartCalibrationEvent;
            transition from calibrating to idle accept CalibrationCompleteEvent;
        }
        
        action calculateForce {
            in rawDigital : Integer;
            out forceValue : ForceN;
        }
        
        action performCalibration {
            in referenceForce : ForceN;
            in rawDigital : Integer;
            out newCalibrationFactor : Real;
            out newZeroOffset : Integer;
        }
    }
    
    part def DisplayUnit {
        port dataIn : DisplayInPort;
        port powerIn : PowerInPort;
        
        attribute refreshRate : Hertz = 60;
    }
    
    part def PowerSupply {
        port powerIn : PowerInPort;
        port powerOut : PowerOutPort;
        
        attribute outputVoltage : VoltageV = 5.0;
        attribute maxCurrent : Amps = 2.0;
    }
    
    // Requirements
    requirement maxCapacityReq {
        doc "The gauge shall measure forces up to 5000 Newtons.";
        constraint { maxCapacity >= 5000 }
    }
    
    requirement accuracyReq {
        doc "The gauge shall have an accuracy of at least 1%.";
        constraint { errorPercentage <= 1.0 }
    }
    
    requirement calibrationReq {
        doc "The user shall be able to initiate a calibration sequence applying a known reference force, and the system shall automatically adjust internal factors.";
    }
    
    requirement displayRefreshReq {
        doc "The display shall refresh at a rate fast enough for real-time monitoring.";
        constraint { refreshRate >= 30 }
    }
    
    // System Assembly
    part def DigitalForceGauge {
        port mechanicalInput : ForceInPort;
        port externalPowerInput : PowerInPort;
        port calibrationInput : CalibrationInPort;
        
        part strainGauge : StrainGaugeSensor;
        part amplifier : SignalAmplifier;
        part adc : AnalogToDigitalConverter;
        part microprocessor : Microprocessor;
        part display : DisplayUnit;
        part powerSupply : PowerSupply;
        
        attribute maxCapacity : ForceN = 5000;
        attribute errorPercentage : Real = 1.0;
        attribute refreshRate : Hertz = 60;
        
        satisfy maxCapacityReq;
        satisfy accuracyReq;
        satisfy calibrationReq;
        satisfy displayRefreshReq;
        
        connection mechConn from mechanicalInput to strainGauge.forceIn;
        connection amp1Conn from strainGauge.voltageOut to amplifier.voltageIn;
        connection adcConn from amplifier.voltageOut to adc.voltageIn;
        connection procConn from adc.digitalOut to microprocessor.dataIn;
        connection dispConn from microprocessor.displayOut to display.dataIn;
        connection calibConn from calibrationInput to microprocessor.calibrationIn;
        
        connection powerInConn from externalPowerInput to powerSupply.powerIn;
        connection power1 from powerSupply.powerOut to strainGauge.powerIn;
        connection power2 from powerSupply.powerOut to amplifier.powerIn;
        connection power3 from powerSupply.powerOut to adc.powerIn;
        connection power4 from powerSupply.powerOut to microprocessor.powerIn;
        connection power5 from powerSupply.powerOut to display.powerIn;
    }
}
