package PositionSensitiveDeviceSystem {
    import ScalarValues::*;
    
    // Value Types
    value def Power :> Real { unit = "W"; }
    value def Length :> Real { unit = "mm"; }
    value def Current :> Real { unit = "uA"; }
    value def Voltage :> Real { unit = "V"; }
    value def Temperature :> Real { unit = "degC"; }
    value def Probability :> Real { unit = "1"; }
    value def Frequency :> Real { unit = "kHz"; }
    value def DigitalCode :> Integer;
    value def TimeStamp :> Real { unit = "ms"; }
    
    // Items
    item def LightBeam {
        attribute power : Power;
        attribute wavelength : Length;
    }
    
    item def CurrentSignal {
        attribute magnitude : Current;
        attribute timestamp : TimeStamp;
    }
    
    item def VoltageSignal {
        attribute magnitude : Voltage;
        attribute timestamp : TimeStamp;
    }
    
    item def DigitalSignal {
        attribute code : DigitalCode;
        attribute timestamp : TimeStamp;
    }
    
    item def PositionData {
        attribute x : Length;
        attribute y : Length;
        attribute confidence : Probability;
        attribute timestamp : TimeStamp;
    }
    
    // Ports
    port def OpticalIn {
        in item light : LightBeam;
    }
    
    port def BiasVoltageIn {
        in item bias : VoltageSignal;
    }
    
    port def CurrentOut {
        out item current : CurrentSignal;
    }
    
    port def CurrentIn {
        in item current : CurrentSignal;
    }
    
    port def VoltageOut {
        out item voltage : VoltageSignal;
    }
    
    port def VoltageIn {
        in item voltage : VoltageSignal;
    }
    
    port def DigitalOut {
        out item data : DigitalSignal;
    }
    
    port def DigitalIn {
        in item data : DigitalSignal;
    }
    
    port def PositionOut {
        out item measurement : PositionData;
    }
    
    port def EnvironmentIn {
        in item temp : Temperature;
    }
    
    port def BiasVoltageOut {
        out item bias : VoltageSignal;
    }
    
    // Requirements
    requirement def PositionDetectionRequirement {
        doc "The system shall continuously detect and report the exact two-dimensional (X-Y) position of an incident light beam.";
    }
    
    requirement def HighPrecisionRequirement {
        doc "The system shall provide high accuracy and low latency for dynamic optical measurement.";
        attribute maxLatency : TimeStamp = 1.0 [ms];
        attribute maxError : Length = 0.01 [mm];
    }
    
    requirement def DriftCompensationRequirement {
        doc "The system shall automatically adjust the photodetector bias voltage to compensate for performance drifts caused by temperature changes.";
    }
    
    // Parts
    part def PhotodetectorArray {
        port opticalInput : OpticalIn;
        port biasInput : BiasVoltageIn;
        port currentOutput : CurrentOut;
        attribute activeWidth : Length = 10.0 [mm];
        attribute activeHeight : Length = 10.0 [mm];
        
        action def GenerateCurrent {
            in light : LightBeam;
            in bias : VoltageSignal;
            out current : CurrentSignal;
        }
    }
    
    part def TransimpedanceAmplifier {
        port currentInput : CurrentIn;
        port voltageOutput : VoltageOut;
        attribute gain : Real = 100.0; // kV/uA
        
        action def AmplifyCurrent {
            in current : CurrentSignal;
            out voltage : VoltageSignal;
        }
    }
    
    part def AnalogToDigitalConverter {
        port voltageInput : VoltageIn;
        port digitalOutput : DigitalOut;
        attribute samplingRate : Frequency = 100.0 [kHz];
        attribute resolution : DigitalCode = 16;
        
        action def ConvertSignal {
            in voltage : VoltageSignal;
            out data : DigitalSignal;
        }
    }
    
    part def PositionCalculator {
        port digitalInput : DigitalIn;
        port measurementOutput : PositionOut;
        attribute calibrationScale : Real = 1.0;
        attribute sensorWidth : Length = 10.0 [mm];
        attribute sensorHeight : Length = 10.0 [mm];
        
        action def ComputeCoordinates {
            in data : DigitalSignal;
            out measurement : PositionData;
        }
    }
    
    part def BiasController {
        port envInput : EnvironmentIn;
        port biasOutput : BiasVoltageOut;
        attribute nominalVoltage : Voltage = 5.0 [V];
        
        action def RegulateBias {
            in temp : Temperature;
            out bias : VoltageSignal;
        }
    }
    
    part def PositionSensitiveDevice {
        requirement positionReq : PositionDetectionRequirement;
        requirement precisionReq : HighPrecisionRequirement;
        requirement driftReq : DriftCompensationRequirement;
        
        port lightInput : OpticalIn;
        port dataOutput : PositionOut;
        port envInput : EnvironmentIn;
        
        part detector : PhotodetectorArray;
        part amplifier : TransimpedanceAmplifier;
        part adc : AnalogToDigitalConverter;
        part calculator : PositionCalculator;
        part biasController : BiasController;
        
        connection lightToDetector connect lightInput to detector.opticalInput;
        connection biasToDetector connect biasController.biasOutput to detector.biasInput;
        connection currentToAmp connect detector.currentOutput to amplifier.currentInput;
        connection ampToADC connect amplifier.voltageOutput to adc.voltageInput;
        connection adcToCalc connect adc.digitalOutput to calculator.digitalInput;
        connection calcToOutput connect calculator.measurementOutput to dataOutput;
        connection envToBias connect envInput to biasController.envInput;
        
        attribute systemTemp : Temperature = 25.0 [degC];
        attribute isFault : Boolean = false;
        attribute isInitialized : Boolean = false;
        
        state OperationalState {
            initial Init;
            state Initializing;
            state Tracking;
            state Compensating;
            state Fault;
            
            transition Init to Initializing;
            transition Initializing to Tracking when isInitialized == true;
            transition Tracking to Compensating when systemTemp > 60.0 [degC];
            transition Compensating to Tracking when systemTemp <= 60.0 [degC];
            transition Tracking to Fault when isFault == true;
            transition Compensating to Fault when isFault == true;
        }
    }
}
