package LSCI_System {
    import ScalarValues::*;
    import ISQ::*;

    value type VoltageUnit > Real { unit "V"; }
    value type CurrentUnit > Real { unit "A"; }
    value type PowerUnit > Real { unit "mW"; }
    value type LengthUnit > Real { unit "nm"; }
    value type AreaUnit > Real { unit "mm^2"; }
    value type ExposureTimeUnit > Real { unit "ms"; }
    value type FrameRateUnit > Real { unit "fps"; }
    value type ContrastValue > Real { min 0.0; max 1.0; }
    value type PerfusionIndex > Real { unit "PU"; }

    item def LaserBeam {
        attribute power : PowerUnit;
        attribute wavelength : LengthUnit;
    }
    item def IlluminatedArea {
        attribute area : AreaUnit;
    }
    item def ScatteredLight;
    item def SpeckleImage {
        attribute exposureTime : ExposureTimeUnit;
    }
    item def ContrastMap {
        attribute values : ContrastValue[0..*];
    }
    item def PerfusionMap {
        attribute indices : PerfusionIndex[0..*];
    }

    port def ElectricalPowerPort {
        out voltage : VoltageUnit;
        out current : CurrentUnit;
    }
    port def LaserOutputPort {
        out beam : LaserBeam;
    }
    port def IlluminationOutputPort {
        out light : IlluminatedArea;
    }
    port def ScatteredLightPort {
        out light : ScatteredLight;
    }
    port def FocusedLightPort {
        out light : ScatteredLight;
    }
    port def ImageDataPort {
        out image : SpeckleImage;
    }
    port def ContrastDataPort {
        out contrast : ContrastMap;
    }
    port def PerfusionDataPort {
        out perfusion : PerfusionMap;
    }

    part def PowerSupply {
        port powerOut : ElectricalPowerPort;
        attribute outputVoltage : VoltageUnit = 12;
        attribute maxCurrent : CurrentUnit = 10;
    }

    part def CoherentLaserSource {
        port powerIn : ElectricalPowerPort;
        port laserOut : LaserOutputPort;
        attribute wavelength : LengthUnit = 785;
        attribute outputPower : PowerUnit = 50;
    }

    part def IlluminationOptics {
        port laserIn : LaserOutputPort;
        port illuminationOut : IlluminationOutputPort;
        attribute beamDiameter : LengthUnit = 10;
    }

    part def TissueTarget {
        port illuminationIn : IlluminationOutputPort;
        port scatteredLightOut : ScatteredLightPort;
        attribute bloodFlowRate : Real;
    }

    part def CollectionOptics {
        port scatteredLightIn : ScatteredLightPort;
        port focusedLightOut : FocusedLightPort;
        attribute magnification : Real = 1.0;
    }

    part def HighSpeedCamera {
        port focusedLightIn : FocusedLightPort;
        port imageOut : ImageDataPort;
        attribute exposureTime : ExposureTimeUnit = 5;
        attribute frameRate : FrameRateUnit = 100;
    }

    action def AnalyzeContrast {
        in image : SpeckleImage;
        out contrast : ContrastMap;
        
        action calculateLocalStatistics {
            in img : SpeckleImage = image;
            out mean : Real;
            out stdDev : Real;
        }
        action computeContrast {
            in mean : Real = calculateLocalStatistics.mean;
            in stdDev : Real = calculateLocalStatistics.stdDev;
            out val : ContrastValue = stdDev / mean;
        }
        succession calculateLocalStatistics then computeContrast;
        flow from computeContrast.val to contrast.values;
    }

    action def CalculatePerfusion {
        in contrast : ContrastMap;
        out perfusion : PerfusionMap;
        
        action convertContrastToPerfusion {
            in c : ContrastValue = contrast.values;
            out p : PerfusionIndex = 1.0 / (c * c);
        }
        flow from convertContrastToPerfusion.p to perfusion.indices;
    }

    part def ContrastAnalysisProcessor {
        port imageIn : ImageDataPort;
        port contrastOut : ContrastDataPort;
        attribute windowSize : Integer = 7;
        
        state machine : ProcessorOperation {
            entry; then Idle;
            state Idle;
            accept imageIn.image then Processing;
            state Processing {
                do analyze : AnalyzeContrast {
                    in image = imageIn.image;
                    out contrast = contrastOut.contrast;
                }
            }
            transition from Processing to Idle;
        }
    }

    part def FlowCalculationUnit {
        port contrastIn : ContrastDataPort;
        port perfusionOut : PerfusionDataPort;
        attribute calibrationFactor : Real = 1.0;
        
        state machine : FlowOperation {
            entry; then Waiting;
            state Waiting;
            accept contrastIn.contrast then Calculating;
            state Calculating {
                do calc : CalculatePerfusion {
                    in contrast = contrastIn.contrast;
                    out perfusion = perfusionOut.perfusion;
                }
            }
            transition from Calculating to Waiting;
        }
    }

    part def VisualizationDisplay {
        port perfusionIn : PerfusionDataPort;
        attribute displayResolution : String = "1920x1080";
    }

    requirement def PowerStabilityReq {
        doc /* The power supply must provide stable voltage to the laser. */
        subject ps : PowerSupply;
        constraint { ps.outputVoltage == 12 }
    }
    requirement def LaserCoherenceReq {
        doc /* The laser must be coherent. */
        subject ls : CoherentLaserSource;
        constraint { ls.wavelength == 785 }
    }
    requirement def CameraExposureReq {
        doc /* The camera must support short exposure times. */
        subject cam : HighSpeedCamera;
        constraint { cam.exposureTime <= 5 }
    }
    requirement def RealTimeVisualizationReq {
        doc /* The system must display the perfusion map in real-time. */
        subject cam : HighSpeedCamera;
        constraint { cam.frameRate >= 30 }
    }

    part def LSCI_Device {
        part powerSupply : PowerSupply;
        part laserSource : CoherentLaserSource;
        part illumination : IlluminationOptics;
        part target : TissueTarget;
        part collection : CollectionOptics;
        part camera : HighSpeedCamera;
        part processor : ContrastAnalysisProcessor;
        part flowUnit : FlowCalculationUnit;
        part display : VisualizationDisplay;

        connect powerSupply.powerOut to laserSource.powerIn;
        connect laserSource.laserOut to illumination.laserIn;
        connect illumination.illuminationOut to target.illuminationIn;
        connect target.scatteredLightOut to collection.scatteredLightIn;
        connect collection.focusedLightOut to camera.focusedLightIn;
        connect camera.imageOut to processor.imageIn;
        connect processor.contrastOut to flowUnit.contrastIn;
        connect flowUnit.perfusionOut to display.perfusionIn;
        
        requirement powerStability : PowerStabilityReq {
            subject ps = powerSupply;
        }
        requirement laserCoherence : LaserCoherenceReq {
            subject ls = laserSource;
        }
        requirement cameraExposure : CameraExposureReq {
            subject cam = camera;
        }
        requirement realTimeVis : RealTimeVisualizationReq {
            subject cam = camera;
        }
    }
}
