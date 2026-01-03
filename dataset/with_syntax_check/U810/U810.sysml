package PhotoelasticityAnalysisSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    
    attribute def StressValue :> PressureValue;
    attribute def StrainValue :> Real;
    attribute def BirefringenceValue :> Real;
    attribute def FringeOrderValue :> Real;
    attribute def WavelengthValue :> LengthValue;
    attribute def IntensityValue :> Real;
    attribute def PixelCountValue :> Integer;
    
    enum def PolarizationMode {
        plane;
        circular;
    }
    
    enum def SpecimenMaterial {
        epoxy;
        polycarbonate;
        urethane;
        gelatin;
    }
    
    item def LightBeam {
        attribute wavelength : WavelengthValue;
        attribute intensity : IntensityValue;
        attribute polarizationAngle : Real;
    }
    
    item def FringePattern {
        attribute fringeOrder : FringeOrderValue;
        attribute imageWidth : PixelCountValue;
        attribute imageHeight : PixelCountValue;
    }
    
    port def OpticalPort {
        out beam : LightBeam;
    }
    
    port def LoadPort {
        in appliedForce : ForceValue;
    }
    
    port def DataPort {
        out pattern : FringePattern;
    }
    
    part def MonochromaticLightSource {
        attribute emissionWavelength : WavelengthValue;
        attribute outputPower : PowerValue;
        port lightOutput : OpticalPort;
    }
    
    part def Polarizer {
        attribute transmissionAxis : Real;
        attribute extinctionRatio : Real;
        port lightInput;
        port lightOutput : OpticalPort;
    }
    
    part def QuarterWavePlate {
        attribute fastAxisOrientation : Real;
        attribute retardation : Real;
        port lightInput;
        port lightOutput : OpticalPort;
    }
    
    part def PhotoelasticSpecimen {
        attribute material : SpecimenMaterial;
        attribute thickness : LengthValue;
        attribute width : LengthValue;
        attribute height : LengthValue;
        attribute stressOpticCoefficient : Real;
        attribute appliedStress : StressValue;
        attribute inducedBirefringence : BirefringenceValue;
        
        port opticalInput;
        port opticalOutput : OpticalPort;
        port mechanicalLoad : LoadPort;
        
        assert constraint stressOpticLaw {
            inducedBirefringence == stressOpticCoefficient * appliedStress
        }
    }
    
    part def Analyzer {
        attribute transmissionAxis : Real;
        attribute extinctionRatio : Real;
        port lightInput;
        port lightOutput : OpticalPort;
    }
    
    part def ImagingCamera {
        attribute sensorResolutionWidth : PixelCountValue;
        attribute sensorResolutionHeight : PixelCountValue;
        attribute bitDepth : Integer;
        attribute frameRate : Real;
        attribute exposureTime : DurationValue;
        port opticalInput;
        port imageOutput : DataPort;
    }
    
    part def LoadingFrame {
        attribute maximumLoad : ForceValue;
        attribute currentLoad : ForceValue;
        attribute loadingRate : Real;
        port mechanicalOutput;
        port controlInterface;
    }
    
    part def ImageProcessor {
        attribute processingAlgorithm : String;
        attribute calibrationFactor : Real;
        attribute computedStressField : StressValue;
        port imageInput;
        port resultsOutput;
    }
    
    part def DisplayUnit {
        attribute screenSize : LengthValue;
        attribute resolutionWidth : PixelCountValue;
        attribute resolutionHeight : PixelCountValue;
        port dataInput;
    }
    
    action def InitializeOpticalPath {
        out configuredSystem : Boolean;
    }
    
    action def ApplyLoad {
        in targetLoad : ForceValue;
        out actualLoad : ForceValue;
    }
    
    action def CaptureImage {
        in exposureDuration : DurationValue;
        out capturedPattern : FringePattern;
    }
    
    action def AnalyzeFringes {
        in fringeData : FringePattern;
        in specimenThickness : LengthValue;
        in materialCoefficient : Real;
        out stressDistribution : StressValue;
    }
    
    action def PhotoelasticAnalysis {
        first start;
        then action initialize : InitializeOpticalPath;
        then merge measurementCycle;
        then action applyMechanicalLoad : ApplyLoad;
        then action capturePattern : CaptureImage;
        then action processFringes : AnalyzeFringes {
            in fringeData = capturePattern.capturedPattern;
        }
        then decide;
            if processFringes.stressDistribution < targetStressLimit then incrementLoad;
            if processFringes.stressDistribution >= targetStressLimit then finalizeMeasurement;
        action incrementLoad;
        then measurementCycle;
        action finalizeMeasurement;
        then done;
        
        in targetStressLimit : StressValue;
    }
    
    state def SystemOperationalStates {
        entry; then idle;
        
        state idle {
            doc /* System is powered but not performing measurements. */
        }
        
        transition idle_to_calibration
            first idle
            accept at Time::Instant
            then calibration;
        
        state calibration {
            entry; then aligningOptics;
            
            state aligningOptics {
                doc /* Aligning polarizers and quarter-wave plates. */
            }
            
            state zeroingLoad {
                doc /* Establishing baseline with no applied load. */
            }
        }
        
        transition calibration_to_ready
            first calibration
            accept at Time::Instant
            then ready;
        
        state ready {
            doc /* System calibrated and ready for measurement. */
        }
        
        transition ready_to_measuring
            first ready
            accept at Time::Instant
            then measuring;
        
        state measuring {
            entry; then applyingLoad;
            
            state applyingLoad {
                doc /* Incrementally applying mechanical load to specimen. */
            }
            
            state imagingFringes {
                doc /* Capturing fringe pattern through camera. */
            }
            
            state processingData {
                doc /* Computing stress field from fringe orders. */
            }
        }
        
        transition measuring_to_ready
            first measuring
            accept at Time::Instant
            then ready;
        
        transition ready_to_idle
            first ready
            accept at Time::Instant
            then idle;
    }
    
    part def PhotoelasticitySystem {
        attribute operatingWavelength : WavelengthValue = 589.3 [nm];
        attribute maxStressMeasurement : StressValue = 100.0 [MPa];
        attribute measurementAccuracy : Real = 0.015;
        attribute polarizationConfiguration : PolarizationMode = PolarizationMode::circular;
        
        part lightSource : MonochromaticLightSource {
            attribute :>> emissionWavelength = operatingWavelength;
            attribute :>> outputPower = 150.0 [mW];
        }
        
        part firstPolarizer : Polarizer {
            attribute :>> transmissionAxis = 0.0;
            attribute :>> extinctionRatio = 1000.0;
        }
        
        part firstQuarterWave : QuarterWavePlate {
            attribute :>> fastAxisOrientation = 45.0;
            attribute :>> retardation = 90.0;
        }
        
        part specimen : PhotoelasticSpecimen {
            attribute :>> material = SpecimenMaterial::polycarbonate;
            attribute :>> thickness = 6.0 [mm];
            attribute :>> width = 100.0 [mm];
            attribute :>> height = 100.0 [mm];
            attribute :>> stressOpticCoefficient = 80.0e-12;
        }
        
        part secondQuarterWave : QuarterWavePlate {
            attribute :>> fastAxisOrientation = 135.0;
            attribute :>> retardation = 90.0;
        }
        
        part analyzer : Analyzer {
            attribute :>> transmissionAxis = 90.0;
            attribute :>> extinctionRatio = 1000.0;
        }
        
        part camera : ImagingCamera {
            attribute :>> sensorResolutionWidth = 2048;
            attribute :>> sensorResolutionHeight = 2048;
            attribute :>> bitDepth = 16;
            attribute :>> frameRate = 30.0;
            attribute :>> exposureTime = 0.02 [s];
        }
        
        part loadFrame : LoadingFrame {
            attribute :>> maximumLoad = 50000.0 [N];
            attribute :>> loadingRate = 500.0;
        }
        
        part processor : ImageProcessor {
            attribute :>> processingAlgorithm = "PhaseShifting";
            attribute :>> calibrationFactor = 1.0;
        }
        
        part display : DisplayUnit {
            attribute :>> screenSize = 0.6 [m];
            attribute :>> resolutionWidth = 1920;
            attribute :>> resolutionHeight = 1080;
        }
        
        connection optical1 connect lightSource.lightOutput to firstPolarizer.lightInput;
        connection optical2 connect firstPolarizer.lightOutput to firstQuarterWave.lightInput;
        connection optical3 connect firstQuarterWave.lightOutput to specimen.opticalInput;
        connection optical4 connect specimen.opticalOutput to secondQuarterWave.lightInput;
        connection optical5 connect secondQuarterWave.lightOutput to analyzer.lightInput;
        connection optical6 connect analyzer.lightOutput to camera.opticalInput;
        connection mechanical connect loadFrame.mechanicalOutput to specimen.mechanicalLoad;
        connection data1 connect camera.imageOutput to processor.imageInput;
        connection data2 connect processor.resultsOutput to display.dataInput;
        
        perform action analysis : PhotoelasticAnalysis;
        
        exhibit state behavior : SystemOperationalStates;
    }
    
    requirement <'REQ-PE-100'> primaryFunction {
        doc /* The photoelasticity system shall visualize and quantify internal 
             * stress distributions in transparent birefringent materials by 
             * analyzing optical fringe patterns generated when polarized light 
             * passes through the specimen under mechanical load.
             */
        subject system : PhotoelasticitySystem;
    }
    
    requirement <'REQ-PE-101'> stressMeasurementRange {
        doc /* The system shall measure stress values from 0 to 100 MPa 
             * across the specimen cross-section.
             */
        subject system : PhotoelasticitySystem;
        assert constraint {
            system.maxStressMeasurement >= 100.0 [MPa]
        }
    }
    
    requirement <'REQ-PE-102'> measurementAccuracy {
        doc /* The system shall achieve stress measurement accuracy 
             * better than 1.5% of the measured value.
             */
        subject system : PhotoelasticitySystem;
        assert constraint {
            system.measurementAccuracy <= 0.015
        }
    }
    
    requirement <'REQ-PE-103'> opticalConfiguration {
        doc /* The system shall employ circular polarization using crossed 
             * polarizers at 0 and 90 degrees with quarter-wave plates at 
             * 45 and 135 degrees to eliminate isoclinic fringes.
             */
        subject system : PhotoelasticitySystem;
        assert constraint {
            system.firstPolarizer.transmissionAxis == 0.0 and
            system.analyzer.transmissionAxis == 90.0 and
            system.firstQuarterWave.fastAxisOrientation == 45.0 and
            system.secondQuarterWave.fastAxisOrientation == 135.0
        }
    }
    
    requirement <'REQ-PE-104'> monochromaticIllumination {
        doc /* The system shall use monochromatic light source with 
             * wavelength of 589.3 nm (sodium D-line) to produce 
             * distinct isochromatic fringes.
             */
        subject lightSource : PhotoelasticitySystem::lightSource;
        assert constraint {
            lightSource.emissionWavelength == 589.3 [nm]
        }
    }
    
    requirement <'REQ-PE-105'> imageResolution {
        doc /* The imaging camera shall provide minimum resolution of 
             * 2048x2048 pixels to resolve fine fringe details.
             */
        subject camera : PhotoelasticitySystem::camera;
        assert constraint {
            camera.sensorResolutionWidth >= 2048 and
            camera.sensorResolutionHeight >= 2048
        }
    }
    
    requirement <'REQ-PE-106'> loadCapacity {
        doc /* The loading frame shall apply forces up to 50 kN 
             * to induce measurable stress in the specimen.
             */
        subject loadFrame : PhotoelasticitySystem::loadFrame;
        assert constraint {
            loadFrame.maximumLoad >= 50000.0 [N]
        }
    }
    
    requirement <'REQ-PE-107'> specimenCompatibility {
        doc /* The system shall accommodate photoelastic specimens 
             * with thickness between 3 mm and 25 mm.
             */
        subject specimen : PhotoelasticitySystem::specimen;
        assert constraint {
            specimen.thickness >= 3.0 [mm] and
            specimen.thickness <= 25.0 [mm]
        }
    }
    
    part photoelasticSystem : PhotoelasticitySystem;
    
    satisfy primaryFunction by photoelasticSystem;
    satisfy stressMeasurementRange by photoelasticSystem;
    satisfy measurementAccuracy by photoelasticSystem;
    satisfy opticalConfiguration by photoelasticSystem;
    satisfy monochromaticIllumination by photoelasticSystem.lightSource;
    satisfy imageResolution by photoelasticSystem.camera;
    satisfy loadCapacity by photoelasticSystem.loadFrame;
    satisfy specimenCompatibility by photoelasticSystem.specimen;
}
