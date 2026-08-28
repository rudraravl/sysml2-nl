package HyperspectralImagingSystem {
    private import ScalarValues::*;
    
    // Units
    unit nm;
    unit deg;
    unit percent;
    
    // Value types
    value def Wavelength :> Real;
    value def Radiance :> Real;
    value def ConfidenceLevel :> Real;
    value def Angle :> Real;
    
    // Item types
    item def Scene;
    item def Light;
    item def FocusedLight;
    item def DispersedSpectrum;
    item def SpectralDataCube;
    item def CalibrationData;
    item def CorrectedDataCube;
    item def SpectralSignature;
    item def ClassificationMap;
    
    item def Command {
        attribute commandType : String;
        attribute parameters : Real[*];
    }
    
    item def StatusReport {
        attribute systemStatus : String;
        attribute currentConfidence : ConfidenceLevel;
    }
    
    // Port definitions
    port def LightOutPort { out light : Light; }
    port def LightInPort { in light : Light; }
    port def FocusedLightOutPort { out focusedLight : FocusedLight; }
    port def FocusedLightInPort { in focusedLight : FocusedLight; }
    port def SpectrumOutPort { out spectrum : DispersedSpectrum; }
    port def SpectrumInPort { in spectrum : DispersedSpectrum; }
    port def DataCubeOutPort { out dataCube : SpectralDataCube; }
    port def DataCubeInPort { in dataCube : SpectralDataCube; }
    port def CalibrationOutPort { out calData : CalibrationData; }
    port def CalibrationInPort { in calData : CalibrationData; }
    port def CorrectedDataOutPort { out correctedCube : CorrectedDataCube; }
    port def ClassificationOutPort { out classMap : ClassificationMap; }
    port def ClassificationInPort { in classMap : ClassificationMap; }
    port def CommandInPort { in cmd : Command; }
    port def StatusOutPort { out stat : StatusReport; }
    
    // Action definitions
    action def Scan {
        in scene : Scene;
        in scanAngle : Angle;
        out light : Light;
    }
    
    action def Focus {
        in light : Light;
        out focused : FocusedLight;
    }
    
    action def Disperse {
        in focused : FocusedLight;
        out spectrum : DispersedSpectrum;
    }
    
    action def Capture {
        in spectrum : DispersedSpectrum;
        out dataCube : SpectralDataCube;
    }
    
    action def Calibrate {
        out calData : CalibrationData;
    }
    
    action def ProcessData {
        in rawCube : SpectralDataCube;
        in calData : CalibrationData;
        out correctedCube : CorrectedDataCube;
        out signatures : SpectralSignature[*];
        out classMap : ClassificationMap;
        out confidence : ConfidenceLevel;
        
        action cleanData {
            in rawCube = ProcessData::rawCube;
            in calData = ProcessData::calData;
            out correctedCube;
        }
        then action classify {
            in correctedCube = cleanData.correctedCube;
            out signatures;
            out classMap = ProcessData::classMap;
            out confidence = ProcessData::confidence;
        }
    }
    
    action def StoreData {
        in classMap : ClassificationMap;
    }
    
    action def ProduceStatus {
        in confidence : ConfidenceLevel;
        out status : StatusReport;
    }
    
    // Part definitions
    part def ScanMirrorAssembly {
        port inCommand : CommandInPort;
        port outLight : LightOutPort;
        attribute currentAngle : Angle;
        
        perform action scan : Scan {
            in scanAngle = currentAngle;
            out light;
        }
        
        state def ScanControl {
            state idle;
            state sweeping;
            transition from idle to sweeping;
            transition from sweeping to idle;
        }
    }
    
    part def ForeopticAssembly {
        port inLight : LightInPort;
        port outFocused : FocusedLightOutPort;
        
        perform action focus : Focus {
            in light;
            out focused;
        }
    }
    
    part def SpectralDispersionUnit {
        port inFocused : FocusedLightInPort;
        port outSpectrum : SpectrumOutPort;
        
        perform action disperse : Disperse {
            in focused;
            out spectrum;
        }
    }
    
    part def FocalPlaneArray {
        port inSpectrum : SpectrumInPort;
        port outDataCube : DataCubeOutPort;
        
        perform action capture : Capture {
            in spectrum;
            out dataCube;
        }
    }
    
    part def CalibrationUnit {
        port outCalData : CalibrationOutPort;
        port inCommand : CommandInPort;
        
        perform action calibrate : Calibrate {
            out calData;
        }
        
        state def CalibrationControl {
            state idle;
            state calibrating;
            transition from idle to calibrating;
            transition from calibrating to idle;
        }
    }
    
    part def SignalProcessingUnit {
        port inRawCube : DataCubeInPort;
        port inCalData : CalibrationInPort;
        port outCorrectedCube : CorrectedDataOutPort;
        port outClassification : ClassificationOutPort;
        port inCommand : CommandInPort;
        port outStatus : StatusOutPort;
        
        attribute confidenceThreshold : ConfidenceLevel = 90.0;
        
        perform action process : ProcessData {
            in rawCube;
            in calData;
            out correctedCube;
            out signatures;
            out classMap;
            out confidence;
        }
        
        state def ProcessingControl {
            state idle;
            state processing;
            transition from idle to processing;
            transition from processing to idle;
        }
    }
    
    part def DataStorageUnit {
        port inClassMap : ClassificationInPort;
        port inCommand : CommandInPort;
        
        perform action store : StoreData {
            in classMap;
        }
        
        state def StorageControl {
            state idle;
            state storing;
            transition from idle to storing;
            transition from storing to idle;
        }
    }
    
    // Top-level system composition
    part def HyperspectralImager {
        part scanMirror : ScanMirrorAssembly;
        part foreoptic : ForeopticAssembly;
        part dispersion : SpectralDispersionUnit;
        part focalPlane : FocalPlaneArray;
        part calibration : CalibrationUnit;
        part processor : SignalProcessingUnit;
        part storage : DataStorageUnit;
        
        // Light path connections
        connect scanMirror.outLight to foreoptic.inLight;
        connect foreoptic.outFocused to dispersion.inFocused;
        connect dispersion.outSpectrum to focalPlane.inSpectrum;
        
        // Data path connections
        connect focalPlane.outDataCube to processor.inRawCube;
        connect calibration.outCalData to processor.inCalData;
        connect processor.outClassification to storage.inClassMap;
        
        // Command and status distribution
        port sysCommand : CommandInPort;
        port sysStatus : StatusOutPort;
        connect sysCommand to scanMirror.inCommand;
        connect sysCommand to calibration.inCommand;
        connect sysCommand to processor.inCommand;
        connect sysCommand to storage.inCommand;
        connect processor.outStatus to sysStatus;
        
        // Overall system behavior
        perform action acquireAndProcess {
            in item scene : Scene;
            out item finalClassMap : ClassificationMap;
            out item status : StatusReport;
            
            action scanStep : Scan {
                in scene = acquireAndProcess::scene;
                in scanAngle = scanMirror.currentAngle;
                out light;
            }
            then action focusStep : Focus {
                in light = scanStep.light;
                out focused;
            }
            then action disperseStep : Disperse {
                in focused = focusStep.focused;
                out spectrum;
            }
            then action captureStep : Capture {
                in spectrum = disperseStep.spectrum;
                out dataCube;
            }
            then action calibrateStep : Calibrate {
                out calData;
            }
            then action processStep : ProcessData {
                in rawCube = captureStep.dataCube;
                in calData = calibrateStep.calData;
                out correctedCube;
                out signatures;
                out classMap;
                out confidence;
            }
            then action storeStep : StoreData {
                in classMap = processStep.classMap;
            }
            then action reportStatus : ProduceStatus {
                in confidence = processStep.confidence;
                out status = acquireAndProcess::status;
            }
            
            bind finalClassMap = processStep.classMap;
        }
    }
    
    // Requirements
    requirement def SpectralResolution {
        doc /* The system shall capture at least 200 spectral bands in the range 400-2500 nm. */
    }
    
    requirement def MaterialIdentification {
        doc /* The system shall identify materials with a confidence level above 90% under clear sky conditions. */
    }
    
    requirement def DataStorage {
        doc /* The system shall store classification maps only when confidence exceeds 90%. */
    }
    
    // Satisfaction links
    satisfy SpectralResolution by HyperspectralImager::dispersion;
    satisfy MaterialIdentification by HyperspectralImager::processor;
    satisfy DataStorage by HyperspectralImager::storage;
}
