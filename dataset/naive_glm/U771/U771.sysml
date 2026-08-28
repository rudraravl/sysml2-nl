package ThermalImagingSystem {
    import ScalarValues::*;
    
    // ---- Units ----
    unit kelvin;
    unit hertz;
    unit ohm;
    unit volt;
    unit watt;
    unit millimeter;
    
    // ---- Value Types ----
    value type Temperature :> Real { unit kelvin; }
    value type TemperatureDifference :> Real { unit kelvin; }
    value type FrameRate :> Real { unit hertz; }
    value type Resistance :> Real { unit ohm; }
    value type Voltage :> Real { unit volt; }
    value type Power :> Real { unit watt; }
    value type Length :> Real { unit millimeter; }
    value type DigitalCount :> Integer;
    
    // ---- Item Types ----
    item def InfraredRadiation;
    
    item def RawDigitalFrame {
        attribute pixelValues : DigitalCount[0..*];
        attribute frameIndex : Integer;
    }
    
    item def ProcessedThermalImage {
        attribute pixelTemperatures : Temperature[0..*];
        attribute frameIndex : Integer;
    }
    
    item def DisplaySignal {
        attribute videoData : DigitalCount[0..*];
        attribute resolution : String;
    }
    
    // ---- Port Definitions ----
    port def IRPort {
        out ir : InfraredRadiation;
    }
    port def SensorPort {
        out resistance : Resistance;
    }
    port def CoolingPort {
        out coolantTemp : Temperature;
    }
    port def RawDataPort {
        out frame : RawDigitalFrame;
    }
    port def ImagePort {
        out image : ProcessedThermalImage;
    }
    port def DisplayPort {
        out signal : DisplaySignal;
    }
    
    // ---- Part Definitions ----
    part def OpticalSystem {
        out port irOut : IRPort;
        attribute focalLength : Length = 25;
        attribute aperture : Length = 12;
    }
    
    part def MicrobolometerFocalPlaneArray {
        in port irIn : IRPort;
        in port coolingIn : CoolingPort;
        out port sensorOut : SensorPort;
        attribute resolutionX : Integer = 640;
        attribute resolutionY : Integer = 480;
        attribute operatingTemperature : Temperature = 293.15;
        attribute NETD : TemperatureDifference = 0.05;
        attribute pixelPitch : Length = 0.017;
    }
    
    part def ThermoelectricCooler {
        out port coolingOut : CoolingPort;
        attribute targetTemperature : Temperature = 293.15;
        attribute maxCoolingPower : Power = 5.0;
        attribute currentPower : Power = 2.0;
    }
    
    part def ReadoutIntegratedCircuit {
        in port sensorIn : SensorPort;
        out port rawOut : RawDataPort;
        attribute frameRate : FrameRate = 30;
        attribute gain : Real = 1.0;
        attribute adcResolution : Integer = 14;
    }
    
    part def SignalProcessingUnit {
        in port rawIn : RawDataPort;
        out port imageOut : ImagePort;
        attribute frameRate : FrameRate = 30;
        attribute calibrationTable : DigitalCount[0..*];
        
        action def ProcessFrame {
            in raw : RawDigitalFrame;
            out image : ProcessedThermalImage;
            
            action NonUniformityCorrection {
                in rawIn : RawDigitalFrame;
                out corrected : RawDigitalFrame;
            }
            action BadPixelReplacement {
                in correctedIn : RawDigitalFrame;
                out replaced : RawDigitalFrame;
            }
            action TemperatureCalibration {
                in replacedIn : RawDigitalFrame;
                out imageOut : ProcessedThermalImage;
            }
            
            flow from NonUniformityCorrection.corrected to BadPixelReplacement.correctedIn;
            flow from BadPixelReplacement.replaced to TemperatureCalibration.replacedIn;
            flow from TemperatureCalibration.imageOut to image;
        }
        
        action processFrame : ProcessFrame {
            in raw = rawIn.frame;
            out image = imageOut.image;
        }
    }
    
    part def DisplayInterface {
        in port imageIn : ImagePort;
        out port displayOut : DisplayPort;
        attribute outputResolution : String = "640x480";
        attribute refreshRate : FrameRate = 30;
    }
    
    // ---- System Definition ----
    part def ThermalCamera {
        part opticalSystem : OpticalSystem;
        part fpa : MicrobolometerFocalPlaneArray;
        part cooler : ThermoelectricCooler;
        part roic : ReadoutIntegratedCircuit;
        part spu : SignalProcessingUnit;
        part display : DisplayInterface;
        
        connection irFlow connect opticalSystem.irOut to fpa.irIn;
        connection coolingFlow connect cooler.coolingOut to fpa.coolingIn;
        connection sensorFlow connect fpa.sensorOut to roic.sensorIn;
        connection rawFlow connect roic.rawOut to spu.rawIn;
        connection imageFlow connect spu.imageOut to display.imageIn;
        
        attribute powerOn : Boolean = false;
        attribute calibrationComplete : Boolean = false;
        attribute standbyCommand : Boolean = false;
        attribute wakeCommand : Boolean = false;
        attribute errorDetected : Boolean = false;
        attribute powerOff : Boolean = false;
        
        state def CameraStates {
            entry; exit;
            
            state Off {
                entry action { /* power off */ }
            }
            state WarmUpCalibration {
                entry action { /* initialize sensors and run calibration */ }
            }
            state Ready {
                entry action { /* active imaging */ }
            }
            state Standby {
                entry action { /* low power mode */ }
            }
            state Fault {
                entry action { /* log error and safe state */ }
            }
            
            transition from Off to WarmUpCalibration when powerOn == true;
            transition from WarmUpCalibration to Ready when calibrationComplete == true;
            transition from WarmUpCalibration to Fault when errorDetected == true;
            transition from Ready to Standby when standbyCommand == true;
            transition from Standby to Ready when wakeCommand == true;
            transition from Ready to Fault when errorDetected == true;
            transition from Standby to Fault when errorDetected == true;
            transition from Fault to Off when powerOff == true;
        }
        
        state machine cameraStates : CameraStates;
    }
    
    // ---- Requirements ----
    requirement def TemperatureSensitivityRequirement {
        subject camera : ThermalCamera;
        requirement camera.fpa.NETD <= 0.05 [kelvin];
    }
    
    requirement def FrameRateRequirement {
        subject camera : ThermalCamera;
        requirement camera.roic.frameRate >= 30 [hertz];
    }
    
    requirement def ResolutionRequirement {
        subject camera : ThermalCamera;
        requirement camera.fpa.resolutionX == 640;
        requirement camera.fpa.resolutionY == 480;
    }
    
    requirement def CoolingStabilityRequirement {
        subject camera : ThermalCamera;
        requirement abs(camera.fpa.operatingTemperature - camera.cooler.targetTemperature) <= 0.1 [kelvin];
    }
    
    requirement def WarmUpCalibrationRequirement {
        subject camera : ThermalCamera;
        requirement camera.cameraStates.WarmUpCalibration.entry.occurs;
    }
}
