package ElectroOpticalSensingUnitModel {
    import ScalarValues::*;
    
    // Value Types
    value type IrradianceValue :> Real { unit = "W/m^2"; }
    value type WavelengthValue :> Real { unit = "nm"; }
    value type CurrentValue :> Real { unit = "A"; }
    value type VoltageValue :> Real { unit = "V"; }
    value type DigitalValue :> Integer;
    value type ConfidenceScore :> Real { unit = "%"; }
    value type TimestampValue :> Real { unit = "s"; }
    
    // Item Types
    item def Light {
        attribute irradiance : IrradianceValue;
        attribute minWavelength : WavelengthValue = 400;
        attribute maxWavelength : WavelengthValue = 1100;
    }
    item def ElectricalCurrent {
        attribute value : CurrentValue;
    }
    item def AnalogVoltage {
        attribute value : VoltageValue;
    }
    item def DigitalData {
        attribute rawValue : DigitalValue;
    }
    item def Power {
        attribute voltage : VoltageValue = 5.0;
    }
    item def MeasurementResult {
        attribute irradiance : IrradianceValue;
        attribute confidence : ConfidenceScore;
        attribute timestamp : TimestampValue;
    }
    
    // Port Definitions
    port def OpticalPort {
        attribute light : Light;
    }
    port def CurrentPort {
        attribute current : ElectricalCurrent;
    }
    port def VoltagePort {
        attribute voltage : AnalogVoltage;
    }
    port def DigitalPort {
        attribute data : DigitalData;
    }
    port def PowerPort {
        attribute power : Power;
    }
    port def MeasurementPort {
        attribute result : MeasurementResult;
    }
    
    // Component Definitions
    part def OpticalWindow {
        attribute ipRating : String = "IP67";
        attribute antiReflectiveCoated : Boolean = true;
        port opticalIn : OpticalPort;
        port opticalOut : OpticalPort;
    }
    
    part def Photodetector {
        attribute spectralRangeMin : WavelengthValue = 400;
        attribute spectralRangeMax : WavelengthValue = 1100;
        port opticalIn : OpticalPort;
        port currentOut : CurrentPort;
    }
    
    part def TransimpedanceAmplifier {
        port currentIn : CurrentPort;
        port voltageOut : VoltagePort;
        port powerIn : PowerPort;
    }
    
    part def AnalogToDigitalConverter {
        attribute resolution : Integer = 24;
        port voltageIn : VoltagePort;
        port dataOut : DigitalPort;
        port powerIn : PowerPort;
    }
    
    part def SignalProcessingUnit {
        port dataIn : DigitalPort;
        port measurementOut : MeasurementPort;
        port powerIn : PowerPort;
        
        action def CalibrateAction;
        action def ValidateAction;
    }
    
    part def ExternalPowerSupply {
        port powerOut : PowerPort;
    }
    
    // Main System Definition
    part def ElectroOpticalSensingUnit {
        port opticalInput : OpticalPort;
        port measurementOutput : MeasurementPort;
        port powerInput : PowerPort;
        
        part window : OpticalWindow;
        part detector : Photodetector;
        part tia : TransimpedanceAmplifier;
        part adc : AnalogToDigitalConverter;
        part spu : SignalProcessingUnit;
        
        connection opticalPath1 : OpticalPort connect opticalInput to window.opticalIn;
        connection opticalPath2 : OpticalPort connect window.opticalOut to detector.opticalIn;
        connection currentPath : CurrentPort connect detector.currentOut to tia.currentIn;
        connection voltagePath : VoltagePort connect tia.voltageOut to adc.voltageIn;
        connection dataPath : DigitalPort connect adc.dataOut to spu.dataIn;
        connection measurementPath : MeasurementPort connect spu.measurementOut to measurementOutput;
        
        connection powerTIA : PowerPort connect powerInput to tia.powerIn;
        connection powerADC : PowerPort connect powerInput to adc.powerIn;
        connection powerSPU : PowerPort connect powerInput to spu.powerIn;
        
        // State Machine
        state machine Lifecycle {
            state initialization {
                entry action selfTest;
                do action calibrate;
            }
            state standby;
            state measuring {
                state acquire;
                state process;
                state validate;
                state output;
                
                transition first acquire then process;
                transition first process then validate;
                transition first validate then output;
            }
            
            transition first initialization then standby;
            transition first standby then measuring when trigger;
            transition first measuring then standby;
        }
        
        // Requirements
        requirement def IrradianceMeasurementRequirement {
            doc "The sensing unit shall measure optical irradiance and output a calibrated digital measurement."
        }
        requirement def ComponentInterfaceRequirement {
            doc "The sensing unit shall consist of an Optical Window, Photodetector, TIA, 24-bit ADC, and Signal Processing Unit."
        }
        requirement def LifecycleRequirement {
            doc "The sensing unit shall follow the lifecycle: initialization, standby, measuring."
        }
        requirement def OutputFormatRequirement {
            doc "The output shall be a digital data stream providing measured irradiance, confidence score, and timestamp."
        }
        
        requirement irradianceMeasurementReq : IrradianceMeasurementRequirement;
        requirement componentInterfaceReq : ComponentInterfaceRequirement;
        requirement lifecycleReq : LifecycleRequirement;
        requirement outputFormatReq : OutputFormatRequirement;
    }
}
