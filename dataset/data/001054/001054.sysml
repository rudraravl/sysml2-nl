package 'FlatPanelDetectorSystem' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def PixelResolution {
        attribute width : Integer;
        attribute height : Integer;
    }
    
    attribute def DetectorStatus {
        attribute isReady : Boolean;
        attribute isExposing : Boolean;
        attribute isReadingOut : Boolean;
        attribute currentTemperature : ThermodynamicTemperatureValue;
    }
    
    attribute def ExposureParameters {
        attribute xrayEnergy : EnergyValue;
        attribute exposureDuration : TimeValue;
        attribute doseLevel : PowerValue;
    }
    
    item def RawImageData {
        attribute pixelValues : Integer;
        attribute bitDepth : Integer;
        attribute acquisitionTimestamp : TimeValue;
    }
    
    item def ProcessedImageData {
        attribute correctedPixels : Integer;
        attribute qualityMetrics : Real;
    }
    
    port def PowerSupplyPort {
        in voltage : ElectricPotentialValue;
        in current : ElectricCurrentValue;
    }
    
    port def DataOutputPort {
        out imageData : ProcessedImageData;
    }
    
    port def XRayInputPort {
        in radiationIntensity : PowerValue;
        in photonEnergy : EnergyValue;
    }
    
    port def ControlPort {
        in exposureCommand : ExposureParameters;
        out statusFeedback : DetectorStatus;
    }
    
    part def ScintillatorPanel {
        attribute materialType : String;
        attribute thickness : LengthValue;
        attribute conversionEfficiency : Real;
        
        action convertXRayToLight {
            in xrayPhotons : PowerValue;
            in photonEnergy : EnergyValue;
            out visibleLightIntensity : PowerValue;
        }
    }
    
    part def PhotodiodeMatrix {
        attribute pixelPitch : LengthValue;
        attribute matrixSize : PixelResolution;
        attribute fillFactor : Real;
        
        action captureOpticalSignal {
            in lightIntensity : PowerValue;
            out electricalCharge : ElectricChargeValue;
        }
    }
    
    part def ReadoutCircuitry {
        attribute amplifierGain : Real;
        attribute noiseFloor : ElectricPotentialValue;
        attribute readoutSpeed : FrequencyValue;
        
        action digitizeSignal {
            in analogCharge : ElectricChargeValue;
            out digitalValue : Integer;
        }
        
        action scanMatrix {
            in matrixSize : PixelResolution;
            out rawImageFrame : RawImageData;
        }
    }
    
    part def ImageProcessingUnit {
        attribute processorSpeed : FrequencyValue;
        attribute bufferSize : Integer;
        
        action applyDarkFieldCorrection {
            in rawImage : RawImageData;
            in darkReference : RawImageData;
            out correctedImage : RawImageData;
        }
        
        action applyFlatFieldCorrection {
            in image : RawImageData;
            in flatReference : RawImageData;
            out normalizedImage : RawImageData;
        }
        
        action enhanceImage {
            in inputImage : RawImageData;
            out enhancedImage : ProcessedImageData;
        }
    }
    
    part def ThermalManagementSystem {
        attribute targetTemperature : ThermodynamicTemperatureValue;
        attribute coolingCapacity : PowerValue;
        
        action regulateTemperature {
            in currentTemp : ThermodynamicTemperatureValue;
            in heatLoad : PowerValue;
            out coolingPower : PowerValue;
        }
    }
    
    part def ControllerModule {
        attribute firmwareVersion : String;
        
        action coordinateExposure {
            in exposureParams : ExposureParameters;
            out triggerSignal : Boolean;
            out timingControl : TimeValue;
        }
        
        action monitorStatus {
            in sensorReadings : DetectorStatus;
            out systemStatus : DetectorStatus;
        }
    }
    
    part def FlatPanelDetector {
        attribute detectorDimensions : LengthValue;
        attribute operationalStatus : DetectorStatus;
        
        port powerInput : PowerSupplyPort;
        port dataOutput : DataOutputPort;
        port xrayInput : XRayInputPort;
        port controlInterface : ControlPort;
        
        part scintillator : ScintillatorPanel {
            attribute materialType = "CsI:Tl";
            attribute thickness = 600.0 [um];
            attribute conversionEfficiency = 0.75;
        }
        
        part photodiodeArray : PhotodiodeMatrix {
            attribute pixelPitch = 140.0 [um];
            attribute fillFactor = 0.80;
        }
        
        part readoutElectronics : ReadoutCircuitry {
            attribute amplifierGain = 150.0;
            attribute noiseFloor = 1.5 [mV];
            attribute readoutSpeed = 50.0 [MHz];
        }
        
        part imageProcessor : ImageProcessingUnit {
            attribute processorSpeed = 200.0 [MHz];
            attribute bufferSize = 8192;
        }
        
        part thermalSystem : ThermalManagementSystem {
            attribute targetTemperature = 293.15 [K];
            attribute coolingCapacity = 75.0 [W];
        }
        
        part controller : ControllerModule {
            attribute firmwareVersion = "v2.4.1";
        }
        
        connection scintillatorToPhotodiodes connect 
            scintillator.convertXRayToLight.visibleLightIntensity to 
            photodiodeArray.captureOpticalSignal.lightIntensity;
            
        connection photodiodestoReadout connect 
            photodiodeArray.captureOpticalSignal.electricalCharge to 
            readoutElectronics.digitizeSignal.analogCharge;
            
        connection readoutToProcessor connect 
            readoutElectronics.scanMatrix.rawImageFrame to 
            imageProcessor.applyDarkFieldCorrection.rawImage;
    }
    
    state def DetectorOperationalStates {
        in attribute status : DetectorStatus;
        
        entry; then standby;
        
        state standby {
            entry assign status.isReady := true;
            entry assign status.isExposing := false;
            entry assign status.isReadingOut := false;
        }
        
        transition standby_to_initialization
            first standby
            accept exposureRequest : ExposureParameters
            then initialization;
            
        state initialization {
            entry assign status.isReady := false;
            do action prepareDetector;
            do action verifyTemperature;
        }
        
        transition initialization_to_exposure
            first initialization
            if status.currentTemperature <= 298.15 [K]
            then exposure;
            
        state exposure {
            entry assign status.isExposing := true;
            do action captureXRayRadiation;
            do action accumulateCharge;
        }
        
        transition exposure_to_readout
            first exposure
            accept exposureComplete : Boolean
            then readout;
            
        state readout {
            entry assign status.isExposing := false;
            entry assign status.isReadingOut := true;
            do action scanDetectorMatrix;
            do action transferRawData;
        }
        
        transition readout_to_processing
            first readout
            then processing;
            
        state processing {
            entry assign status.isReadingOut := false;
            do action correctImageData;
            do action enhanceImageQuality;
        }
        
        transition processing_to_standby
            first processing
            then standby;
    }
    
    action def AcquireRadiographicImage {
        in exposureSettings : ExposureParameters;
        out finalImage : ProcessedImageData;
        
        first start;
        
        then action initializeAcquisition {
            action powerUpComponents;
            then action stabilizeOperatingTemperature;
            then action loadCalibrationData;
        }
        
        then action waitForExposureTrigger {
            accept xrayExposureInitiated : Boolean;
        }
        
        then action executeExposure {
            action convertIncidentRadiation {
                in radiationInput = exposureSettings.xrayEnergy;
                in doseInput = exposureSettings.doseLevel;
                out opticalOutput : PowerValue;
            }
            
            flow convertIncidentRadiation.opticalOutput to captureOpticalSignal.lightInput;
            
            action captureOpticalSignal {
                in lightInput : PowerValue;
                in integrationTime = exposureSettings.exposureDuration;
                out chargeDistribution : ElectricChargeValue;
            }
            
            flow captureOpticalSignal.chargeDistribution to digitizeChargePattern.chargeInput;
            
            action digitizeChargePattern {
                in chargeInput : ElectricChargeValue;
                out rawImageMatrix : RawImageData;
            }
        }
        
        then action performImageCorrection {
            action applyDarkCorrection {
                in rawData = executeExposure.digitizeChargePattern.rawImageMatrix;
                in darkFrame : RawImageData;
                out darkCorrected : RawImageData;
            }
            
            flow applyDarkCorrection.darkCorrected to applyFlatCorrection.inputData;
            
            action applyFlatCorrection {
                in inputData : RawImageData;
                in flatFrame : RawImageData;
                out flatCorrected : RawImageData;
            }
            
            flow applyFlatCorrection.flatCorrected to enhanceQuality.correctedData;
            
            action enhanceQuality {
                in correctedData : RawImageData;
                out processedData : ProcessedImageData;
            }
        }
        
        then action transmitProcessedImage {
            in imageToTransmit = performImageCorrection.enhanceQuality.processedData;
            out transmittedImage = finalImage;
        }
        
        then done;
    }
    
    requirement def ImageQualityRequirement {
        doc /* The flat panel detector shall produce radiographic images meeting specified quality standards. */
        
        require constraint spatialResolutionRequirement {
            doc /* Spatial resolution shall be at least 3.6 line pairs per millimeter. */
        }
        
        require constraint detectorQuantumEfficiency {
            doc /* Detective quantum efficiency shall exceed 0.60 at 70 keV photon energy. */
        }
        
        require constraint dynamicRangeRequirement {
            doc /* The detector shall provide a dynamic range of at least 14 bits. */
        }
    }
    
    requirement def PerformanceRequirement {
        doc /* The detector system shall meet operational performance specifications. */
        
        require constraint frameRateRequirement {
            doc /* The detector shall support continuous acquisition at frame rates up to 30 frames per second. */
        }
        
        require constraint readoutTimeRequirement {
            doc /* Complete image readout shall be accomplished within 150 milliseconds. */
        }
        
        require constraint lagRequirement {
            doc /* Image lag after first frame shall be less than 2 percent. */
        }
    }
    
    requirement def ReliabilityRequirement {
        doc /* The detector system shall demonstrate long-term operational reliability. */
        
        require constraint operationalLifetime {
            doc /* The detector shall maintain performance specifications for minimum 100,000 exposures. */
        }
        
        require constraint thermalStability {
            doc /* Operating temperature shall be maintained within ±2 degrees Celsius of target. */
        }
    }
    
    requirement <'FPD-SYS-001'> flatPanelDetectorSystemRequirement {
        doc /* The flat panel detector system shall convert incident X-ray radiation into 
                high-quality digital radiographic images for medical diagnostic or industrial 
                inspection applications through efficient radiation detection, signal processing, 
                and image enhancement. */
        
        subject detectorSystem : FlatPanelDetector;
        
        assume constraint operatingEnvironmentAssumption {
            doc /* The detector operates in a controlled environment with ambient temperature 
                    between 18 and 28 degrees Celsius and relative humidity below 75 percent. */
        }
        
        assume constraint radiationSourceAssumption {
            doc /* X-ray source provides photon energies in the range of 40 to 150 keV with 
                    controlled dose rates appropriate for the imaging application. */
        }
        
        require imageQualityReq : ImageQualityRequirement;
        require performanceReq : PerformanceRequirement;
        require reliabilityReq : ReliabilityRequirement;
    }
    
    part flatPanelDetectorSystem : FlatPanelDetector {
        attribute detectorDimensions = 403.2 [mm];
        
        perform action imageAcquisition[*] ordered references acquireRadiographicImage;
        
        part scintillator : ScintillatorPanel {
            perform imageAcquisition.executeExposure.convertIncidentRadiation;
        }
        
        part photodiodeArray : PhotodiodeMatrix {
            perform imageAcquisition.executeExposure.captureOpticalSignal;
        }
        
        part readoutElectronics : ReadoutCircuitry {
            perform imageAcquisition.executeExposure.digitizeChargePattern;
        }
        
        part imageProcessor : ImageProcessingUnit {
            perform imageAcquisition.performImageCorrection.applyDarkCorrection;
            perform imageAcquisition.performImageCorrection.applyFlatCorrection;
            perform imageAcquisition.performImageCorrection.enhanceQuality;
        }
        
        part thermalSystem : ThermalManagementSystem {
            perform imageAcquisition.initializeAcquisition.stabilizeOperatingTemperature;
        }
        
        part controller : ControllerModule {
            perform imageAcquisition.initializeAcquisition.powerUpComponents;
            perform imageAcquisition.transmitProcessedImage;
        }
    }
    
    action acquireRadiographicImage : AcquireRadiographicImage {
        in exposureSettings : ExposureParameters {
            attribute xrayEnergy = 70.0 [keV];
            attribute exposureDuration = 0.5 [s];
            attribute doseLevel = 5.0 [mGy];
        }
        out finalImage : ProcessedImageData;
    }
}
