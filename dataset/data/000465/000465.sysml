package 'Laser Speckle Contrast Imaging System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def WavelengthValue :> LengthValue;
    attribute def LaserPowerValue :> PowerValue;
    attribute def ExposureTimeValue :> DurationValue;
    attribute def FrameRateValue :> FrequencyValue;
    attribute def SpeckleContrastValue :> Real;
    attribute def BloodFlowIndexValue :> Real;
    attribute def IntensityValue :> Real;
    
    item def LaserBeam {
        attribute wavelength: WavelengthValue;
        attribute power: LaserPowerValue;
        attribute coherenceLength: LengthValue;
    }
    
    item def ScatteredLight {
        attribute specklePattern: IntensityValue;
        attribute meanIntensity: IntensityValue;
    }
    
    item def RawSpeckleImage {
        attribute pixelData: IntensityValue;
        attribute exposureTime: ExposureTimeValue;
        attribute timestamp: TimeValue;
        attribute frameIndex: Integer;
    }
    
    item def ContrastMap {
        attribute contrastValues: SpeckleContrastValue;
        attribute spatialResolution: LengthValue;
        attribute windowSize: Integer;
    }
    
    item def PerfusionMap {
        attribute flowIndices: BloodFlowIndexValue;
        attribute timestamp: TimeValue;
        attribute calibrationFactor: Real;
    }
    
    item def ElectricalPower;
    
    port def PowerPort {
        in power: ElectricalPower;
    }
    
    port def OpticalOutputPort {
        out beam: LaserBeam;
    }
    
    port def OpticalInputPort {
        in light: ScatteredLight;
    }
    
    port def ImageDataPort {
        out imageData: RawSpeckleImage;
    }
    
    port def ContrastDataPort {
        out contrastData: ContrastMap;
    }
    
    port def PerfusionDataPort {
        out perfusionData: PerfusionMap;
    }
    
    part def PowerSupply {
        attribute outputVoltage: ISQ::ElectricPotentialValue;
        attribute maxCurrent: ISQ::ElectricCurrentValue;
        port powerOut: PowerPort;
    }
    
    part def CoherentLaserSource {
        attribute operatingWavelength: WavelengthValue;
        attribute outputPower: LaserPowerValue;
        attribute coherenceLength: LengthValue;
        attribute stability: Real;
        port powerIn: ~PowerPort;
        port opticalOut: OpticalOutputPort;
    }
    
    part def IlluminationOptics {
        attribute beamExpansionRatio: Real;
        attribute illuminationArea: AreaValue;
        attribute uniformity: Real;
        port laserIn: ~OpticalOutputPort;
        port tissueOut: OpticalOutputPort;
    }
    
    part def TissueSample {
        attribute surfaceArea: AreaValue;
        attribute scatteringCoefficient: Real;
        port illuminationIn: ~OpticalOutputPort;
        port scatteredOut: OpticalInputPort;
    }
    
    part def CollectionOptics {
        attribute numericalAperture: Real;
        attribute magnification: Real;
        attribute transmissionEfficiency: Real;
        port scatteredIn: ~OpticalInputPort;
        port cameraOut: OpticalInputPort;
    }
    
    part def HighSpeedCamera {
        attribute pixelCount: Integer;
        attribute pixelSize: LengthValue;
        attribute bitDepth: Integer;
        attribute maxFrameRate: FrameRateValue;
        attribute exposureTime: ExposureTimeValue;
        attribute quantumEfficiency: Real;
        port powerIn: ~PowerPort;
        port opticalIn: ~OpticalInputPort;
        port dataOut: ImageDataPort;
    }
    
    part def ContrastAnalysisProcessor {
        attribute processingWindowSize: Integer;
        attribute computationThreads: Integer;
        port powerIn: ~PowerPort;
        port imageIn: ~ImageDataPort;
        port contrastOut: ContrastDataPort;
    }
    
    part def FlowCalculationUnit {
        attribute correlationTime: TimeValue;
        attribute calibrationFactor: Real;
        attribute algorithmType: String;
        port powerIn: ~PowerPort;
        port contrastIn: ~ContrastDataPort;
        port perfusionOut: PerfusionDataPort;
    }
    
    part def VisualizationDisplay {
        attribute displayResolution: Integer;
        attribute colorDepth: Integer;
        attribute refreshRate: FrequencyValue;
        port powerIn: ~PowerPort;
        port perfusionIn: ~PerfusionDataPort;
    }
    
    action def EmitCoherentLight {
        in powerLevel: LaserPowerValue;
        in wavelength: WavelengthValue;
        out laserBeam: LaserBeam;
    }
    
    action def IlluminateTissue {
        in laserBeam: LaserBeam;
        in targetArea: AreaValue;
        out illuminatedRegion: LaserBeam;
    }
    
    action def GenerateSpecklePattern {
        in illumination: LaserBeam;
        in tissueProperties: Real;
        out speckleField: ScatteredLight;
    }
    
    action def AcquireSpeckleImage {
        in speckleField: ScatteredLight;
        in exposureTime: ExposureTimeValue;
        in frameNumber: Integer;
        out rawImage: RawSpeckleImage;
    }
    
    action def ComputeSpeckleContrast {
        in rawImage: RawSpeckleImage;
        in windowSize: Integer;
        out contrastMap: ContrastMap;
    }
    
    action def CalculateBloodFlow {
        in contrastMap: ContrastMap;
        in exposureTime: ExposureTimeValue;
        in wavelength: WavelengthValue;
        out perfusionMap: PerfusionMap;
    }
    
    action def DisplayPerfusion {
        in perfusionMap: PerfusionMap;
        in colorMapping: String;
    }
    
    action def PerformLSCIImaging {
        in attribute systemWavelength: WavelengthValue;
        in attribute systemPower: LaserPowerValue;
        in attribute acquisitionExposure: ExposureTimeValue;
        in attribute analysisWindow: Integer;
        in attribute numberOfFrames: Integer;
        out attribute finalPerfusionMap: PerfusionMap;
        
        private attribute frameCounter: Integer := 1;
        private attribute currentContrast: ContrastMap;
        
        first start;
        then action emitLight: EmitCoherentLight {
            in powerLevel = systemPower;
            in wavelength = systemWavelength;
            out laserBeam;
        }
        then action illuminateSample: IlluminateTissue {
            in laserBeam = emitLight.laserBeam;
            in targetArea;
            out illuminatedRegion;
        }
        then merge imagingLoop;
        
        action imagingLoop {
            decide;
                if frameCounter <= numberOfFrames then acquireAndAnalyze;
                if frameCounter > numberOfFrames then finishImaging;
        }
        
        action acquireAndAnalyze {
            action generateSpeckle: GenerateSpecklePattern {
                in illumination = illuminateSample.illuminatedRegion;
                in tissueProperties = 1.0;
                out speckleField;
            }
            then action captureImage: AcquireSpeckleImage {
                in speckleField = generateSpeckle.speckleField;
                in exposureTime = acquisitionExposure;
                in frameNumber = frameCounter;
                out rawImage;
            }
            then action analyzeContrast: ComputeSpeckleContrast {
                in rawImage = captureImage.rawImage;
                in windowSize = analysisWindow;
                out contrastMap;
            }
            then action computeFlow: CalculateBloodFlow {
                in contrastMap = analyzeContrast.contrastMap;
                in exposureTime = acquisitionExposure;
                in wavelength = systemWavelength;
                out perfusionMap;
            }
            then assign currentContrast := analyzeContrast.contrastMap;
            then assign frameCounter := frameCounter + 1;
        }
        then imagingLoop;
        
        action finishImaging {
            action displayResults: DisplayPerfusion {
                in perfusionMap = finalPerfusionMap;
                in colorMapping = "jet";
            }
        }
        then done;
    }
    
    part def LSCISystem {
        doc /* 
         * A Laser Speckle Contrast Imaging (LSCI) system that non-invasively
         * measures and visualizes microvascular blood flow in biological tissue.
         * The system illuminates tissue with coherent laser light, captures the
         * resulting dynamic speckle patterns, computes spatial contrast variations,
         * and derives quantitative blood flow maps in real-time.
         */
        
        attribute systemWavelength: WavelengthValue;
        attribute systemPower: LaserPowerValue;
        attribute systemFrameRate: FrameRateValue;
        attribute systemExposure: ExposureTimeValue;
        attribute contrastWindowSize: Integer;
        
        part powerSupply: PowerSupply;
        part laser: CoherentLaserSource;
        part illuminationOptics: IlluminationOptics;
        part tissue: TissueSample;
        part collectionOptics: CollectionOptics;
        part camera: HighSpeedCamera;
        part contrastProcessor: ContrastAnalysisProcessor;
        part flowCalculator: FlowCalculationUnit;
        part display: VisualizationDisplay;
    }
    
    part lsciSystem: LSCISystem {
        :>> systemWavelength = 785.0 [SI::nm];
        :>> systemPower = 50.0 [SI::mW];
        :>> systemFrameRate = 30.0 [SI::Hz];
        :>> systemExposure = 5.0 [SI::ms];
        :>> contrastWindowSize = 7;
        
        part :>> powerSupply {
            :>> outputVoltage = 12.0 [SI::V];
            :>> maxCurrent = 5.0 [SI::A];
        }
        
        part :>> laser {
            :>> operatingWavelength = lsciSystem.systemWavelength;
            :>> outputPower = lsciSystem.systemPower;
            :>> coherenceLength = 100.0 [SI::μm];
            :>> stability = 0.99;
        }
        
        part :>> illuminationOptics {
            :>> beamExpansionRatio = 10.0;
            :>> illuminationArea = 100.0 [SI::mm2];
            :>> uniformity = 0.95;
        }
        
        part :>> tissue {
            :>> surfaceArea = 100.0 [SI::mm2];
            :>> scatteringCoefficient = 1.2;
        }
        
        part :>> collectionOptics {
            :>> numericalAperture = 0.25;
            :>> magnification = 1.0;
            :>> transmissionEfficiency = 0.85;
        }
        
        part :>> camera {
            :>> pixelCount = 1048576;
            :>> pixelSize = 5.5 [SI::μm];
            :>> bitDepth = 12;
            :>> maxFrameRate = lsciSystem.systemFrameRate;
            :>> exposureTime = lsciSystem.systemExposure;
            :>> quantumEfficiency = 0.6;
        }
        
        part :>> contrastProcessor {
            :>> processingWindowSize = lsciSystem.contrastWindowSize;
            :>> computationThreads = 8;
        }
        
        part :>> flowCalculator {
            :>> correlationTime = 1.0 [SI::ms];
            :>> calibrationFactor = 1.0;
            :>> algorithmType = "spatial";
        }
        
        part :>> display {
            :>> displayResolution = 1920;
            :>> colorDepth = 24;
            :>> refreshRate = 60.0 [SI::Hz];
        }
        
        connect powerSupply.powerOut to laser.powerIn;
        connect powerSupply.powerOut to camera.powerIn;
        connect powerSupply.powerOut to contrastProcessor.powerIn;
        connect powerSupply.powerOut to flowCalculator.powerIn;
        connect powerSupply.powerOut to display.powerIn;
        
        connect laser.opticalOut to illuminationOptics.laserIn;
        connect illuminationOptics.tissueOut to tissue.illuminationIn;
        connect tissue.scatteredOut to collectionOptics.scatteredIn;
        connect collectionOptics.cameraOut to camera.opticalIn;
        connect camera.dataOut to contrastProcessor.imageIn;
        connect contrastProcessor.contrastOut to flowCalculator.contrastIn;
        connect flowCalculator.perfusionOut to display.perfusionIn;
        
        perform action lsciOperation: PerformLSCIImaging {
            in systemWavelength = lsciSystem.systemWavelength;
            in systemPower = lsciSystem.systemPower;
            in acquisitionExposure = lsciSystem.systemExposure;
            in analysisWindow = lsciSystem.contrastWindowSize;
            in numberOfFrames = 100;
            out finalPerfusionMap;
        }
    }
    
    requirement def PrimaryFunctionRequirement {
        doc /* 
         * The LSCI system shall provide real-time, non-invasive visualization
         * of microvascular blood flow by analyzing laser speckle contrast patterns.
         */
    }
    
    requirement def SpatialResolutionRequirement {
        doc /* 
         * The system shall achieve spatial resolution better than 50 micrometers
         * to resolve individual microvascular structures.
         */
    }
    
    requirement def TemporalResolutionRequirement {
        doc /* 
         * The system shall acquire and process images at minimum 10 frames per second
         * to capture dynamic blood flow changes.
         */
    }
    
    requirement def ContrastSensitivityRequirement {
        doc /* 
         * The system shall detect speckle contrast variations of at least 5 percent
         * to distinguish between different flow states.
         */
    }
    
    requirement def SafetyRequirement {
        doc /* 
         * The laser power density on tissue shall not exceed maximum permissible
         * exposure limits for the operating wavelength to ensure subject safety.
         */
    }
    
    requirement <'LSCI-REQ-001'> primaryFunction: PrimaryFunctionRequirement {
        subject system: LSCISystem;
        
        satisfy lsciSystem.lsciOperation;
    }
    
    requirement <'LSCI-REQ-002'> spatialResolution: SpatialResolutionRequirement {
        subject system: LSCISystem;
        
        assume constraint {
            system.camera.pixelSize < 10.0 [SI::μm]
        }
        
        require constraint {
            system.collectionOptics.magnification * system.camera.pixelSize < 50.0 [SI::μm]
        }
    }
    
    requirement <'LSCI-REQ-003'> temporalResolution: TemporalResolutionRequirement {
        subject system: LSCISystem;
        
        require constraint {
            system.systemFrameRate >= 10.0 [SI::Hz]
        }
    }
    
    requirement <'LSCI-REQ-004'> contrastSensitivity: ContrastSensitivityRequirement {
        subject system: LSCISystem;
        
        assume constraint {
            system.camera.quantumEfficiency > 0.5 and
            system.camera.bitDepth >= 12
        }
        
        require constraint {
            system.systemExposure >= 1.0 [SI::ms] and
            system.systemExposure <= 20.0 [SI::ms]
        }
    }
    
    requirement <'LSCI-REQ-005'> laserSafety: SafetyRequirement {
        subject system: LSCISystem;
        
        require constraint {
            system.systemPower / system.illuminationOptics.illuminationArea < 0.5 [SI::mW] / 1.0 [SI::mm2]
        }
    }
}
