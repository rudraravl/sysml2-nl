package LSCI_System {
    import ISQ::*;
    
    item def Electricity;
    item def LaserBeam {
        attribute wavelength : LengthValue;
    }
    item def ExpandedBeam;
    item def ScatteredLight;
    item def FocusedSpecklePattern;
    item def RawImageData {
        attribute exposureTime : TimeValue;
    }
    item def SpeckleContrastData;
    item def PerfusionMap;
    
    part def PowerSupply {
        out port electricityOut : Electricity;
    }
    
    part def CoherentLaserSource {
        in port electricityIn : Electricity;
        out port laserBeamOut : LaserBeam;
    }
    
    part def IlluminationOptics {
        in port laserBeamIn : LaserBeam;
        out port expandedBeamOut : ExpandedBeam;
    }
    
    part def Tissue {
        in port illuminationIn : ExpandedBeam;
        out port scatteredLightOut : ScatteredLight;
    }
    
    part def CollectionOptics {
        in port scatteredLightIn : ScatteredLight;
        out port focusedPatternOut : FocusedSpecklePattern;
    }
    
    part def HighSpeedCamera {
        in port electricityIn : Electricity;
        in port focusedPatternIn : FocusedSpecklePattern;
        out port rawImageOut : RawImageData;
        attribute exposureTime : TimeValue;
    }
    
    part def ContrastAnalysisProcessor {
        in port electricityIn : Electricity;
        in port rawImageIn : RawImageData;
        out port contrastDataOut : SpeckleContrastData;
    }
    
    part def FlowCalculationUnit {
        in port electricityIn : Electricity;
        in port contrastDataIn : SpeckleContrastData;
        out port perfusionMapOut : PerfusionMap;
    }
    
    part def VisualizationDisplay {
        in port electricityIn : Electricity;
        in port perfusionMapIn : PerfusionMap;
    }
    
    action def IlluminateTissue {
        in item laserBeam : LaserBeam;
        out item scatteredLight : ScatteredLight;
    }
    
    action def CaptureSpecklePattern {
        in item scatteredLight : ScatteredLight;
        out item rawImage : RawImageData;
    }
    
    action def AnalyzeContrast {
        in item rawImage : RawImageData;
        out item contrastData : SpeckleContrastData;
    }
    
    action def CalculatePerfusion {
        in item contrastData : SpeckleContrastData;
        out item perfusionMap : PerfusionMap;
    }
    
    action def PerformLSCIImaging {
        in item laserBeam : LaserBeam;
        out item perfusionMap : PerfusionMap;
        
        action illuminate : IlluminateTissue {
            in item laserBeam = PerformLSCIImaging::laserBeam;
            out item scatteredLight;
        }
        flow from illuminate.scatteredLight to capture.scatteredLight;
        action capture : CaptureSpecklePattern {
            in item scatteredLight;
            out item rawImage;
        }
        flow from capture.rawImage to analyze.rawImage;
        action analyze : AnalyzeContrast {
            in item rawImage;
            out item contrastData;
        }
        flow from analyze.contrastData to calculate.contrastData;
        action calculate : CalculatePerfusion {
            in item contrastData;
            out item perfusionMap = PerformLSCIImaging::perfusionMap;
        }
    }
    
    part def LSCISystem {
        part powerSupply : PowerSupply;
        part laserSource : CoherentLaserSource;
        part illuminationOptics : IlluminationOptics;
        part tissue : Tissue;
        part collectionOptics : CollectionOptics;
        part camera : HighSpeedCamera;
        part processor : ContrastAnalysisProcessor;
        part flowUnit : FlowCalculationUnit;
        part display : VisualizationDisplay;
        
        flow powerSupply.electricityOut to laserSource.electricityIn;
        flow powerSupply.electricityOut to camera.electricityIn;
        flow powerSupply.electricityOut to processor.electricityIn;
        flow powerSupply.electricityOut to flowUnit.electricityIn;
        flow powerSupply.electricityOut to display.electricityIn;
        
        flow laserSource.laserBeamOut to illuminationOptics.laserBeamIn;
        flow illuminationOptics.expandedBeamOut to tissue.illuminationIn;
        flow tissue.scatteredLightOut to collectionOptics.scatteredLightIn;
        flow collectionOptics.focusedPatternOut to camera.focusedPatternIn;
        flow camera.rawImageOut to processor.rawImageIn;
        flow processor.contrastDataOut to flowUnit.contrastDataIn;
        flow flowUnit.perfusionMapOut to display.perfusionMapIn;
        
        action imagingProcess : PerformLSCIImaging {
            in item laserBeam;
            out item perfusionMap;
        }
    }
    
    requirement def LSCI_System_Requirement {
        text "The LSCI system shall visualize and measure blood flow in microscopic vessels non-invasively by illuminating tissue with a coherent laser, capturing speckle patterns with a high-speed camera, calculating speckle contrast, converting it to a perfusion map, and displaying it in real-time.";
        derivedRequirement Power_Requirement {
            text "The Power Supply shall provide stable electrical energy to all active components.";
        }
        derivedRequirement Optical_Requirement {
            text "Illumination and Collection Optics shall expand the laser beam and focus scattered light onto the camera sensor.";
        }
        derivedRequirement Processing_Requirement {
            text "The Contrast Analysis Processor and Flow Calculation Unit shall compute speckle contrast and generate a quantitative perfusion map.";
        }
    }
}
