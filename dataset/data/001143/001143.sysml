package MicrobolometerThermalImagingSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def PixelResolution {
        attribute width : Integer;
        attribute height : Integer;
    }
    
    attribute def SpectralBand {
        attribute minWavelength : LengthValue;
        attribute maxWavelength : LengthValue;
    }
    
    item def InfraredRadiation {
        attribute wavelength : LengthValue;
        attribute radiantFlux : PowerValue;
        attribute incidentAngle : Real;
    }
    
    item def ThermalSignal {
        attribute resistanceChange : Real;
        attribute voltage : Real;
        attribute temperature : TemperatureValue;
    }
    
    item def RawImageData {
        attribute pixelValues : Real[*];
        attribute frameNumber : Integer;
        attribute captureTime : TimeValue;
    }
    
    item def ProcessedThermalImage {
        attribute calibratedPixels : TemperatureValue[*];
        attribute resolution : PixelResolution;
        attribute timestamp : TimeValue;
    }
    
    port def IRInputPort {
        in item irRadiation : InfraredRadiation;
    }
    
    port def ThermalSignalPort {
        out item signal : ThermalSignal;
    }
    
    port def RawDataPort {
        out item rawData : RawImageData;
    }
    
    port def ImageDataPort {
        out item imageData : ProcessedThermalImage;
    }
    
    port def PowerSupplyPort {
        in attribute voltage : Real;
        in attribute current : Real;
    }
    
    port def ControlPort {
        in attribute integrationTime : TimeValue;
        in attribute gain : Real;
        out attribute status : Integer;
    }
    
    part def MicrobolometerFocalPlaneArray {
        attribute arrayResolution : PixelResolution;
        attribute pixelPitch : LengthValue;
        attribute thermalTimeConstant : TimeValue;
        attribute temperatureCoefficientOfResistance : Real;
        
        port irInput : IRInputPort[*];
        port signalOutput : ThermalSignalPort[*];
        port power : PowerSupplyPort;
        
        action absorbInfraredRadiation {
            in radiation : InfraredRadiation;
            out temperatureChange : TemperatureValue;
        }
        
        action convertToResistanceChange {
            in tempChange : TemperatureValue;
            out resistanceChange : Real;
        }
    }
    
    part def ReadoutIntegratedCircuit {
        attribute biasVoltage : Real;
        attribute amplifierGain : Real;
        attribute samplingFrequency : FrequencyValue;
        
        port signalInput : ThermalSignalPort[*];
        port dataOutput : RawDataPort;
        port power : PowerSupplyPort;
        port control : ControlPort;
        
        action amplifySignal {
            in inputSignal : ThermalSignal;
            in gain : Real;
            out amplifiedSignal : Real;
        }
        
        action digitizeSignal {
            in analogSignal : Real;
            out digitalValue : Real;
        }
        
        action assembleFrame {
            in pixelData : Real[*];
            out frameData : RawImageData;
        }
    }
    
    part def SignalProcessingUnit {
        attribute nonUniformityCorrectionEnabled : Boolean;
        attribute badPixelReplacementEnabled : Boolean;
        attribute spatialFilteringEnabled : Boolean;
        
        port rawInput : RawDataPort;
        port imageOutput : ImageDataPort;
        port power : PowerSupplyPort;
        
        action applyNonUniformityCorrection {
            in rawPixels : Real[*];
            in gainCoefficients : Real[*];
            in offsetCoefficients : Real[*];
            out correctedPixels : Real[*];
        }
        
        action performBadPixelReplacement {
            in pixels : Real[*];
            in badPixelMap : Boolean[*];
            out repairedPixels : Real[*];
        }
        
        action convertToTemperature {
            in correctedPixels : Real[*];
            in calibrationCurve : Real[*];
            out temperatureMap : TemperatureValue[*];
        }
        
        action generateThermalImage {
            in tempMap : TemperatureValue[*];
            in resolution : PixelResolution;
            out thermalImage : ProcessedThermalImage;
        }
    }
    
    part def ThermoelectricCooler {
        attribute targetTemperature : TemperatureValue;
        attribute coolingPower : PowerValue;
        attribute stabilityTolerance : TemperatureValue;
        
        port power : PowerSupplyPort;
        
        action regulateTemperature {
            in currentTemp : TemperatureValue;
            in targetTemp : TemperatureValue;
            out coolingCurrent : Real;
        }
    }
    
    part def OpticalSystem {
        attribute focalLength : LengthValue;
        attribute apertureDiameter : LengthValue;
        attribute fieldOfView : Real;
        attribute transmittance : Real;
        
        port irInput : IRInputPort;
        port irOutput : IRInputPort;
        
        action focusRadiation {
            in incomingRadiation : InfraredRadiation;
            out focusedRadiation : InfraredRadiation;
        }
    }
    
    part def DisplayInterface {
        attribute displayResolution : PixelResolution;
        attribute refreshRate : FrequencyValue;
        
        port imageInput : ImageDataPort;
        port power : PowerSupplyPort;
        
        action renderThermalImage {
            in thermalImage : ProcessedThermalImage;
        }
    }
    
    action def DetectInfraredRadiation {
        in irRadiation : InfraredRadiation;
        out thermalSignal : ThermalSignal;
    }
    
    action def ProcessThermalSignal {
        in signal : ThermalSignal;
        out rawData : RawImageData;
    }
    
    action def GenerateThermalImage {
        in rawData : RawImageData;
        out processedImage : ProcessedThermalImage;
    }
    
    action def DisplayThermalImage {
        in image : ProcessedThermalImage;
    }
    
    action def CaptureThermalScene {
        in sceneRadiation : InfraredRadiation;
        out displayedImage : ProcessedThermalImage;
        
        first start;
        then merge continuousImaging;
        then action detect : DetectInfraredRadiation {
            in irRadiation = sceneRadiation;
            out thermalSignal;
        }
        flow detect.thermalSignal to process.signal;
        then action process : ProcessThermalSignal {
            in signal;
            out rawData;
        }
        flow process.rawData to generate.rawData;
        then action generate : GenerateThermalImage {
            in rawData;
            out processedImage;
        }
        flow generate.processedImage to display.image;
        then action display : DisplayThermalImage {
            in image;
        }
        then assign displayedImage := generate.processedImage;
        then continuousImaging;
    }
    
    state def ThermalCameraOperationalStates {
        entry; then idle;
        
        state idle;
        state warmingUp;
        state calibrating;
        state imaging;
        state standby;
        state fault;
        
        transition powerOn
            first idle
            then warmingUp;
            
        transition warmupComplete
            first warmingUp
            accept at warmingUp.done
            then calibrating;
            
        transition calibrationComplete
            first calibrating
            accept at calibrating.done
            then imaging;
            
        transition enterStandby
            first imaging
            then standby;
            
        transition resumeImaging
            first standby
            then imaging;
            
        transition errorDetected
            first imaging
            then fault;
            
        transition resetSystem
            first fault
            then idle;
    }
    
    part microbolometerCamera {
        attribute operatingSpectralBand : SpectralBand {
            :>> minWavelength = 8.0e-6 [m];
            :>> maxWavelength = 14.0e-6 [m];
        }
        attribute sensorResolution : PixelResolution {
            :>> width = 640;
            :>> height = 480;
        }
        attribute frameRate : FrequencyValue = 30.0 [Hz];
        attribute noiseEquivalentTemperatureDifference : TemperatureValue = 0.05 [K];
        
        part optics : OpticalSystem {
            :>> focalLength = 25.0e-3 [m];
            :>> apertureDiameter = 12.5e-3 [m];
            :>> fieldOfView = 30.0;
            :>> transmittance = 0.85;
        }
        
        part focalPlaneArray : MicrobolometerFocalPlaneArray {
            :>> arrayResolution = sensorResolution;
            :>> pixelPitch = 17.0e-6 [m];
            :>> thermalTimeConstant = 10.0e-3 [s];
            :>> temperatureCoefficientOfResistance = -0.02;
        }
        
        part readoutCircuit : ReadoutIntegratedCircuit {
            :>> biasVoltage = 3.3;
            :>> amplifierGain = 100.0;
            :>> samplingFrequency = frameRate;
        }
        
        part signalProcessor : SignalProcessingUnit {
            :>> nonUniformityCorrectionEnabled = true;
            :>> badPixelReplacementEnabled = true;
            :>> spatialFilteringEnabled = false;
        }
        
        part cooler : ThermoelectricCooler {
            :>> targetTemperature = 298.15 [K];
            :>> coolingPower = 2.0 [W];
            :>> stabilityTolerance = 0.1 [K];
        }
        
        part display : DisplayInterface {
            :>> displayResolution = sensorResolution;
            :>> refreshRate = frameRate;
        }
        
        connect optics.irOutput to focalPlaneArray.irInput;
        connect focalPlaneArray.signalOutput to readoutCircuit.signalInput;
        connect readoutCircuit.dataOutput to signalProcessor.rawInput;
        connect signalProcessor.imageOutput to display.imageInput;
        
        perform action thermalImaging : CaptureThermalScene {
            in sceneRadiation;
            out displayedImage;
        }
        
        perform optics.focusRadiation;
        perform focalPlaneArray.absorbInfraredRadiation;
        perform focalPlaneArray.convertToResistanceChange;
        perform readoutCircuit.amplifySignal;
        perform readoutCircuit.digitizeSignal;
        perform readoutCircuit.assembleFrame;
        perform signalProcessor.applyNonUniformityCorrection;
        perform signalProcessor.performBadPixelReplacement;
        perform signalProcessor.convertToTemperature;
        perform signalProcessor.generateThermalImage;
        perform cooler.regulateTemperature;
        perform display.renderThermalImage;
    }
    
    requirement def PrimaryFunctionRequirement {
        doc /* 
            The microbolometer-based thermal imaging system shall detect infrared radiation 
            emitted by objects in the scene, convert the thermal energy into electrical signals 
            through temperature-dependent resistance changes in the microbolometer array, 
            process these signals to compensate for sensor non-uniformities and noise, 
            and generate calibrated thermal images representing the temperature distribution 
            of the observed scene for display to the operator.
        */
    }
    
    requirement def SpectralRangeRequirement {
        doc /* The system shall operate in the long-wave infrared spectral band. */
        
        require constraint {
            microbolometerCamera.operatingSpectralBand.minWavelength >= 7.5e-6 [m] and
            microbolometerCamera.operatingSpectralBand.maxWavelength <= 14.5e-6 [m]
        }
    }
    
    requirement def SpatialResolutionRequirement {
        doc /* The system shall provide a minimum spatial resolution of 640x480 pixels. */
        
        require constraint {
            microbolometerCamera.sensorResolution.width >= 640 and
            microbolometerCamera.sensorResolution.height >= 480
        }
    }
    
    requirement def TemperatureSensitivityRequirement {
        doc /* The system shall achieve a noise equivalent temperature difference of 50 mK or better. */
        
        require constraint {
            microbolometerCamera.noiseEquivalentTemperatureDifference <= 0.05 [K]
        }
    }
    
    requirement def FrameRateRequirement {
        doc /* The system shall output thermal images at a minimum rate of 30 frames per second. */
        
        require constraint {
            microbolometerCamera.frameRate >= 30.0 [Hz]
        }
    }
    
    requirement def TemperatureStabilizationRequirement {
        doc /* The focal plane array temperature shall be stabilized within 0.1 K of the target temperature. */
        
        require constraint {
            microbolometerCamera.cooler.stabilityTolerance <= 0.1 [K]
        }
    }
    
    requirement systemRequirements {
        doc /* 
            The microbolometer thermal imaging system shall meet all functional and performance 
            requirements for detecting, processing, and displaying thermal radiation.
        */
        
        require PrimaryFunctionRequirement;
        require SpectralRangeRequirement;
        require SpatialResolutionRequirement;
        require TemperatureSensitivityRequirement;
        require FrameRateRequirement;
        require TemperatureStabilizationRequirement;
    }
}
