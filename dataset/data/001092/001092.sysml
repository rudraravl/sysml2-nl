package HyperspectralImagingSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def SpectralBand {
        attribute centerWavelength : LengthValue;
        attribute bandwidth : LengthValue;
    }
    
    attribute def ImageResolution {
        attribute spatialResolution : LengthValue;
        attribute spectralResolution : LengthValue;
        attribute swathWidth : LengthValue;
    }
    
    item def OpticalRadiation {
        attribute wavelength : LengthValue;
        attribute radiance : Real;
        attribute incidenceAngle : Real;
    }
    
    item def SpectralDataCube {
        attribute spatialDimensionX : Integer;
        attribute spatialDimensionY : Integer;
        attribute spectralChannels : Integer;
        attribute pixelData : Real;
        attribute wavelengthMap : LengthValue;
        attribute acquisitionTime : TimeValue;
    }
    
    item def ProcessedSpectralData {
        attribute materialSignatures : Real;
        attribute classificationMap : Integer;
        attribute confidenceLevel : Real;
    }
    
    item def CalibrationCoefficients {
        attribute darkCurrent : Real;
        attribute flatField : Real;
        attribute spectralResponse : Real;
    }
    
    port def OpticalPort {
        in item radiation : OpticalRadiation;
    }
    
    port def SpectralDataPort {
        out item spectralCube : SpectralDataCube;
    }
    
    port def ProcessedDataPort {
        out item processedData : ProcessedSpectralData;
    }
    
    port def ControlCommandPort {
        in attribute scanCommand : Boolean;
        in attribute calibrationRequest : Boolean;
        out attribute systemStatus : Integer;
        out attribute dataReadyFlag : Boolean;
    }
    
    part def ForeopticAssembly {
        port opticalInput : OpticalPort;
        port opticalOutput : OpticalPort;
        
        attribute apertureDiameter : LengthValue;
        attribute focalLength : LengthValue;
        attribute fieldOfView : Real;
        
        perform action collectRadiation {
            in incomingLight : OpticalRadiation;
            out focusedLight : OpticalRadiation;
        }
    }
    
    part def SpectralDispersionUnit {
        port disperserInput : OpticalPort;
        port disperserOutput : OpticalPort;
        
        attribute gratingDensity : Real;
        attribute dispersionCoefficient : Real;
        attribute spectralRange : SpectralBand;
        
        perform action disperseSpectrum {
            in polychromaticLight : OpticalRadiation;
            out dispersedSpectrum : OpticalRadiation;
        }
    }
    
    part def FocalPlaneArray {
        port opticalInterface : OpticalPort;
        port dataInterface : SpectralDataPort;
        
        attribute detectorRows : Integer;
        attribute detectorColumns : Integer;
        attribute pixelSize : LengthValue;
        attribute quantumEfficiency : Real;
        attribute integrationTime : TimeValue;
        
        perform action detectPhotons {
            in spectralRadiation : OpticalRadiation;
            out rawCube : SpectralDataCube;
        }
    }
    
    part def ScanMirrorAssembly {
        port controlInterface : ControlCommandPort;
        
        attribute scanAngle : Real;
        attribute scanRate : FrequencyValue;
        attribute positionAccuracy : Real;
        
        perform action executeScan {
            in scanEnable : Boolean;
            out scanPosition : Real;
            out scanComplete : Boolean;
        }
    }
    
    part def SignalProcessingUnit {
        port rawDataInput : SpectralDataPort;
        port calibrationInput;
        port processedDataOutput : ProcessedDataPort;
        port controlInterface : ControlCommandPort;
        
        attribute processingRate : FrequencyValue;
        attribute bufferSize : Integer;
        
        perform action processSpectralCube {
            in rawSpectralCube : SpectralDataCube;
            in calibration : CalibrationCoefficients;
            out processedOutput : ProcessedSpectralData;
            
            first start;
            then action applyDarkCurrentCorrection {
                in rawData : SpectralDataCube;
                in darkCoefficients : Real;
                out correctedData : SpectralDataCube;
            }
            then action applyFlatFieldCorrection {
                in inputData : SpectralDataCube;
                in flatCoefficients : Real;
                out normalizedData : SpectralDataCube;
            }
            then action performAtmosphericCorrection {
                in normalizedInput : SpectralDataCube;
                out atmosphereCorrected : SpectralDataCube;
            }
            then action extractSpectralSignatures {
                in correctedCube : SpectralDataCube;
                out signatures : Real;
            }
            then action classifyMaterials {
                in spectralSignatures : Real;
                out materialClassification : ProcessedSpectralData;
            }
            then done;
        }
    }
    
    part def CalibrationUnit {
        port controlInterface : ControlCommandPort;
        port calibrationOutput;
        
        attribute referenceSource : Real;
        attribute calibrationFrequency : FrequencyValue;
        
        perform action generateCalibration {
            in calibrationMode : Boolean;
            out coefficients : CalibrationCoefficients;
        }
    }
    
    part def DataStorageUnit {
        port dataInput : ProcessedDataPort;
        
        attribute storageCapacity : Real;
        attribute writeSpeed : Real;
        
        perform action storeData {
            in processedCube : ProcessedSpectralData;
        }
    }
    
    part hyperspectralImager {
        attribute operatingSpectralRange : SpectralBand {
            attribute centerWavelength = 1200.0 [nm];
            attribute bandwidth = 2000.0 [nm];
        }
        
        attribute systemResolution : ImageResolution {
            attribute spatialResolution = 0.5 [m];
            attribute spectralResolution = 8.0 [nm];
            attribute swathWidth = 5000.0 [m];
        }
        
        attribute numberOfBands : Integer = 250;
        attribute dataRate : Real = 100.0;
        
        port sceneInput : OpticalPort;
        port dataOutput : ProcessedDataPort;
        port commandInterface : ControlCommandPort;
        
        part foreoptics : ForeopticAssembly {
            attribute :>> apertureDiameter = 150.0 [mm];
            attribute :>> focalLength = 500.0 [mm];
            attribute :>> fieldOfView = 45.0;
        }
        
        part scanMirror : ScanMirrorAssembly {
            attribute :>> scanAngle = 30.0;
            attribute :>> scanRate = 5.0 [Hz];
            attribute :>> positionAccuracy = 0.01;
        }
        
        part disperser : SpectralDispersionUnit {
            attribute :>> gratingDensity = 600.0;
            attribute :>> dispersionCoefficient = 2.5;
        }
        
        part detector : FocalPlaneArray {
            attribute :>> detectorRows = 512;
            attribute :>> detectorColumns = 640;
            attribute :>> pixelSize = 20.0 [um];
            attribute :>> quantumEfficiency = 0.75;
            attribute :>> integrationTime = 10.0 [ms];
        }
        
        part processor : SignalProcessingUnit {
            attribute :>> processingRate = 50.0 [Hz];
            attribute :>> bufferSize = 1024;
        }
        
        part calibrator : CalibrationUnit {
            attribute :>> calibrationFrequency = 0.1 [Hz];
        }
        
        part storage : DataStorageUnit {
            attribute :>> storageCapacity = 1000.0;
            attribute :>> writeSpeed = 500.0;
        }
        
        connection opticalPath1 connect sceneInput to foreoptics.opticalInput;
        connection opticalPath2 connect foreoptics.opticalOutput to disperser.disperserInput;
        connection opticalPath3 connect disperser.disperserOutput to detector.opticalInterface;
        connection dataPath1 connect detector.dataInterface to processor.rawDataInput;
        connection calibrationPath connect calibrator.calibrationOutput to processor.calibrationInput;
        connection processedPath1 connect processor.processedDataOutput to dataOutput;
        connection processedPath2 connect processor.processedDataOutput to storage.dataInput;
        connection controlPath1 connect commandInterface to scanMirror.controlInterface;
        connection controlPath2 connect commandInterface to processor.controlInterface;
        connection controlPath3 connect commandInterface to calibrator.controlInterface;
        
        perform action acquireHyperspectralImagery {
            in targetScene : OpticalRadiation;
            out spectralProduct : ProcessedSpectralData;
            
            first start;
            then merge imagingCycle;
            
            action initializeSystem {
                action performCalibration : CalibrationUnit::generateCalibration {
                    in calibrationMode = true;
                    out coefficients : CalibrationCoefficients;
                }
                action initiateScan : ScanMirrorAssembly::executeScan {
                    in scanEnable = true;
                    out scanPosition : Real;
                    out scanComplete : Boolean;
                }
            }
            
            then imagingCycle;
            
            action collectLight : ForeopticAssembly::collectRadiation {
                in incomingLight = targetScene;
                out focusedLight : OpticalRadiation;
            }
            
            then action separateSpectrum : SpectralDispersionUnit::disperseSpectrum {
                in polychromaticLight = collectLight.focusedLight;
                out dispersedSpectrum : OpticalRadiation;
            }
            
            then action captureData : FocalPlaneArray::detectPhotons {
                in spectralRadiation = separateSpectrum.dispersedSpectrum;
                out rawCube : SpectralDataCube;
            }
            
            then action processData : SignalProcessingUnit::processSpectralCube {
                in rawSpectralCube = captureData.rawCube;
                in calibration = initializeSystem.performCalibration.coefficients;
                out processedOutput : ProcessedSpectralData;
            }
            
            then decide;
                if processData.processedOutput.confidenceLevel >= 0.85 then storeResult;
                if processData.processedOutput.confidenceLevel < 0.85 then imagingCycle;
            
            action storeResult : DataStorageUnit::storeData {
                in processedCube = processData.processedOutput;
            }
            
            then done;
        }
    }
    
    requirement def SpectralPerformanceRequirement {
        doc /* The system shall achieve specified spectral resolution across the operating wavelength range. */
        
        subject imager : HyperspectralImagingSystem::hyperspectralImager;
        
        require constraint spectralResolutionConstraint {
            imager.systemResolution.spectralResolution <= 10.0 [nm]
        }
    }
    
    requirement def SpatialPerformanceRequirement {
        doc /* The system shall achieve specified spatial resolution from operational altitude. */
        
        subject imager : HyperspectralImagingSystem::hyperspectralImager;
        
        require constraint spatialResolutionConstraint {
            imager.systemResolution.spatialResolution <= 1.0 [m]
        }
    }
    
    requirement def SpectralCoverageRequirement {
        doc /* The system shall operate across visible to shortwave infrared spectrum. */
        
        subject imager : HyperspectralImagingSystem::hyperspectralImager;
        
        require constraint coverageConstraint {
            imager.operatingSpectralRange.centerWavelength - 
                imager.operatingSpectralRange.bandwidth / 2.0 >= 400.0 [nm] and
            imager.operatingSpectralRange.centerWavelength + 
                imager.operatingSpectralRange.bandwidth / 2.0 <= 2500.0 [nm]
        }
    }
    
    requirement def DataQualityRequirement {
        doc /* The system shall produce spectral data products with minimum confidence threshold. */
        
        require constraint qualityThreshold {
            doc /* Processed spectral data confidence must exceed 0.85. */
        }
    }
    
    requirement def PrimaryMissionRequirement {
        doc /* The hyperspectral imaging system shall acquire electromagnetic radiation across 
                multiple contiguous spectral bands, process the data into calibrated spectral cubes, 
                and enable material identification and classification through spectral signature analysis. */
        
        require SpectralPerformanceRequirement;
        require SpatialPerformanceRequirement;
        require SpectralCoverageRequirement;
        require DataQualityRequirement;
    }
}
