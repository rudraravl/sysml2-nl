package PhotoelasticityAnalysisSystem {

    // ===== Units =====
    unit def nm { shortname "nm"; }
    unit def N { shortname "N"; }
    unit def Pa { shortname "Pa"; }
    unit def deg { shortname "deg"; }
    unit def mm { shortname "mm"; }
    unit def s { shortname "s"; }
    unit def cd { shortname "cd"; }

    // ===== Value Types =====
    value def Wavelength :> Real { unit nm; }
    value def ForceValue :> Real { unit N; }
    value def StressValue :> Real { unit Pa; }
    value def AngleValue :> Real { unit deg; }
    value def Thickness :> Real { unit mm; }
    value def Duration :> Real { unit s; }
    value def LuminousIntensity :> Real { unit cd; }
    value def PixelCount :> Integer;
    value def StressOpticCoeff :> Real { unit "Pa^-1 m^-1"; }

    // ===== Item Definitions =====
    item def LightBeam {
        attribute wavelength : Wavelength;
        attribute intensity : LuminousIntensity;
        attribute polarizationState : String;
    }

    item def UnpolarizedLight :> LightBeam {
        redefinition polarizationState = "unpolarized";
    }

    item def LinearlyPolarizedLight :> LightBeam {
        redefinition polarizationState = "linear";
        attribute axisAngle : AngleValue;
    }

    item def CircularlyPolarizedLight :> LightBeam {
        redefinition polarizationState = "circular";
        attribute handedness : String;
    }

    item def StressModifiedLight :> LightBeam {
        redefinition polarizationState = "stress-modified";
        attribute phaseShift : Real;
    }

    item def FringePatternImage {
        attribute width : PixelCount;
        attribute height : PixelCount;
        attribute pixelData : Integer[*];
        attribute captureTimestamp : Duration;
    }

    item def StressMap {
        attribute stressValues : StressValue[*];
        attribute colorCoding : String;
        attribute spatialResolution : PixelCount;
    }

    item def LoadCommand {
        attribute targetForce : ForceValue;
    }

    item def StatusReport {
        attribute currentForce : ForceValue;
        attribute currentStress : StressValue;
        attribute state : String;
    }

    // ===== Port Definitions =====
    port def OpticalOutPort {
        out item beam : LightBeam;
    }

    port def OpticalInOutPort {
        in item inBeam : LightBeam;
        out item outBeam : LightBeam;
    }

    port def ImageOutPort {
        out item image : FringePatternImage;
    }

    port def ImageInPort {
        in item image : FringePatternImage;
    }

    port def StressMapOutPort {
        out item map : StressMap;
    }

    port def StressMapInPort {
        in item map : StressMap;
    }

    port def LoadControlPort {
        in item command : LoadCommand;
        out item status : StatusReport;
    }

    // ===== Part Definitions =====

    part def MonochromaticLightSource {
        attribute emittedWavelength : Wavelength = 589.0;
        attribute outputIntensity : LuminousIntensity = 100.0;
        port outOptical : OpticalOutPort;

        action def EmitLight {
            out beam : UnpolarizedLight;
        }

        perform action emit : EmitLight {
            out beam = outOptical.beam;
        }
    }

    part def Polarizer {
        attribute transmissionAxis : AngleValue = 0.0;
        port optical : OpticalInOutPort;

        action def Polarize {
            in beam : LightBeam;
            out polarizedBeam : LinearlyPolarizedLight;
        }

        perform action polarize : Polarize {
            in beam = optical.inBeam;
            out polarizedBeam = optical.outBeam;
        }
    }

    part def QuarterWavePlate {
        attribute fastAxis : AngleValue;
        attribute retardationWavelength : Wavelength = 589.0;
        port optical : OpticalInOutPort;

        action def ConvertToCircular {
            in beam : LinearlyPolarizedLight;
            out circularBeam : CircularlyPolarizedLight;
        }

        action def ConvertToLinear {
            in beam : StressModifiedLight;
            out linearBeam : LinearlyPolarizedLight;
        }
    }

    part def PhotoelasticSpecimen {
        attribute materialType : String;
        attribute specimenThickness : Thickness;
        attribute stressOpticCoefficient : StressOpticCoeff;
        attribute currentStress : StressValue;
        port optical : OpticalInOutPort;

        action def DevelopStress {
            in appliedForce : ForceValue;
            out inducedStress : StressValue;
        }

        action def ModifyLight {
            in beam : CircularlyPolarizedLight;
            out modifiedBeam : StressModifiedLight;
        }
    }

    part def LoadingFrame {
        attribute maxForce : ForceValue = 50000.0;
        attribute currentForce : ForceValue = 0.0;
        attribute loadIncrement : ForceValue = 5000.0;
        port controlPort : LoadControlPort;

        action def ApplyLoad {
            in targetForce : ForceValue;
            out appliedForce : ForceValue;
        }

        action def ReleaseLoad {
            out releasedForce : ForceValue;
        }
    }

    part def Analyzer {
        attribute transmissionAxis : AngleValue = 90.0;
        port optical : OpticalInOutPort;

        action def AnalyzeLight {
            in beam : LinearlyPolarizedLight;
            out analyzedBeam : LightBeam;
        }
    }

    part def DigitalCamera {
        attribute resolutionWidth : PixelCount = 2048;
        attribute resolutionHeight : PixelCount = 2048;
        attribute frameRate : Real = 30.0;
        port inOptical : OpticalInOutPort;
        port outImage : ImageOutPort;

        action def CaptureImage {
            in beam : LightBeam;
            out image : FringePatternImage;
        }
    }

    part def ImageProcessor {
        attribute algorithm : String = "phase-shifting";
        attribute processingTime : Duration;
        port inImage : ImageInPort;
        port outMap : StressMapOutPort;
        port controlPort : LoadControlPort;

        action def ProcessFringePattern {
            in image : FringePatternImage;
            out map : StressMap;
        }

        action def CalculateStressField {
            in image : FringePatternImage;
            out stressValues : StressValue[*];
        }
    }

    part def DisplayUnit {
        attribute screenSize : String;
        port inMap : StressMapInPort;

        action def RenderStressMap {
            in map : StressMap;
        }

        action def DisplayResults {
            in map : StressMap;
        }
    }

    // ===== System Assembly =====

    part def PhotoelasticitySystem {
        attribute systemName : String = "Photoelasticity Analysis Laboratory System";
        attribute predefinedLoadLimit : ForceValue = 50000.0;

        part lightSource : MonochromaticLightSource {
            attribute emittedWavelength = 589.0;
        }

        part polarizer : Polarizer {
            attribute transmissionAxis = 0.0;
        }

        part firstQuarterWavePlate : QuarterWavePlate {
            attribute fastAxis = 45.0;
        }

        part specimen : PhotoelasticSpecimen {
            attribute materialType = "polycarbonate";
            attribute specimenThickness = 6.0;
            attribute stressOpticCoefficient = 8.0e-12;
        }

        part loadingFrame : LoadingFrame {
            attribute maxForce = 50000.0;
            attribute loadIncrement = 5000.0;
        }

        part secondQuarterWavePlate : QuarterWavePlate {
            attribute fastAxis = -45.0;
        }

        part analyzer : Analyzer {
            attribute transmissionAxis = 90.0;
        }

        part camera : DigitalCamera {
            attribute resolutionWidth = 2048;
            attribute resolutionHeight = 2048;
        }

        part processor : ImageProcessor {
            attribute algorithm = "phase-shifting";
        }

        part display : DisplayUnit {
            attribute screenSize = "27 inch";
        }

        // Optical path connections
        connection lightToPolarizer connect lightSource.outOptical.beam to polarizer.optical.inBeam;
        connection polarizerToQWP1 connect polarizer.optical.outBeam to firstQuarterWavePlate.optical.inBeam;
        connection qwp1ToSpecimen connect firstQuarterWavePlate.optical.outBeam to specimen.optical.inBeam;
        connection specimenToQWP2 connect specimen.optical.outBeam to secondQuarterWavePlate.optical.inBeam;
        connection qwp2ToAnalyzer connect secondQuarterWavePlate.optical.outBeam to analyzer.optical.inBeam;
        connection analyzerToCamera connect analyzer.optical.outBeam to camera.inOptical.inBeam;

        // Data path connections
        connection cameraToProcessor connect camera.outImage.image to processor.inImage.image;
        connection processorToDisplay connect processor.outMap.map to display.inMap.map;

        // Control connection
        connection processorToLoader connect processor.controlPort.status to loadingFrame.controlPort.status;
        connection loaderToProcessor connect loadingFrame.controlPort.status to processor.controlPort.status;

        // ===== Experiment State Machine =====
        state def ExperimentState {
            entry action;
            exit action;
        }

        state machine ExperimentExecution {
            state Idle;
            state Calibrating {
                entry action calibrateSystem;
                do action verifyZeroLoad;
                exit action recordBaseline;
            }
            state ApplyingLoad {
                entry action incrementLoad;
                do action stabilizeLoad;
            }
            state Capturing {
                entry action triggerCamera;
                do action acquireImage;
                exit action validateImage;
            }
            state Processing {
                entry action runPhaseShiftAlgorithm;
                do action computeStressField;
                exit action generateStressMap;
            }
            state Displaying {
                entry action renderMap;
                do action presentToUser;
                exit action logResults;
            }
            state ExperimentComplete {
                entry action releaseLoad;
                do action archiveData;
            }

            transition init from Idle to Calibrating {
                trigger by start;
            }

            transition calDone from Calibrating to ApplyingLoad {
                guard calibrationSuccessful;
            }

            transition loadApplied from ApplyingLoad to Capturing {
                guard loadStable;
            }

            transition imageCaptured from Capturing to Processing {
                guard imageValid;
            }

            transition processingDone from Processing to Displaying {
                guard stressMapReady;
            }

            transition continueExperiment from Displaying to ApplyingLoad {
                guard currentForce < predefinedLoadLimit;
            }

            transition finishExperiment from Displaying to ExperimentComplete {
                guard currentForce >= predefinedLoadLimit;
            }
        }

        // ===== Experiment Action Flow =====
        action def RunExperimentSequence {
            attribute totalSteps : Integer = 10;

            action calibrate : PerformCalibration {
                out baselineImage : FringePatternImage;
            }

            action applyLoad : ApplyIncrementalLoad {
                in currentForce : ForceValue;
                out nextForce : ForceValue;
            }

            action captureFringe : CaptureFringePattern {
                in appliedForce : ForceValue;
                out fringeImage : FringePatternImage;
            }

            action processStress : ComputeStressDistribution {
                in fringeImage : FringePatternImage;
                out stressMap : StressMap;
            }

            action displayResults : ShowStressMap {
                in stressMap : StressMap;
            }

            action checkLimit : EvaluateLoadLimit {
                in currentForce : ForceValue;
                out limitReached : Boolean;
            }

            flow calibrate.baselineImage to processStress.fringeImage;
            flow applyLoad.nextForce to captureFringe.appliedForce;
            flow captureFringe.fringeImage to processStress.fringeImage;
            flow processStress.stressMap to displayResults.stressMap;
            flow applyLoad.nextForce to checkLimit.currentForce;

            then calibrate;
            then applyLoad;
            then captureFringe;
            then processStress;
            then displayResults;
            then checkLimit;
        }

        action def PerformCalibration {
            out baselineImage : FringePatternImage;
        }

        action def ApplyIncrementalLoad {
            in currentForce : ForceValue;
            out nextForce : ForceValue;
        }

        action def CaptureFringePattern {
            in appliedForce : ForceValue;
            out fringeImage : FringePatternImage;
        }

        action def ComputeStressDistribution {
            in fringeImage : FringePatternImage;
            out stressMap : StressMap;
        }

        action def ShowStressMap {
            in stressMap : StressMap;
        }

        action def EvaluateLoadLimit {
            in currentForce : ForceValue;
            out limitReached : Boolean;
        }

        perform runExperiment : RunExperimentSequence;
    }

    // ===== Requirements =====

    requirement def OpticalPathRequirements {
        subject system : PhotoelasticitySystem;

        requirement EmitMonochromaticLight {
            subject source : MonochromaticLightSource;
            doc "The light source shall emit monochromatic sodium yellow light at 589 nm wavelength."
            constraint { source.emittedWavelength == 589.0 }
        }

        requirement ProduceCircularPolarization {
            doc "The polarizer and first quarter-wave plate shall produce circularly polarized light for specimen illumination."
            constraint { polarizer.transmissionAxis == 0.0 and firstQuarterWavePlate.fastAxis == 45.0 }
        }

        requirement CrossedAnalyzerOrientation {
            doc "The analyzer shall be oriented at 90 degrees relative to the polarizer to produce the fringe pattern."
            constraint { analyzer.transmissionAxis == 90.0 and polarizer.transmissionAxis == 0.0 }
        }
    }

    requirement def MechanicalLoadingRequirements {
        subject frame : LoadingFrame;

        requirement MaxLoadCapacity {
            doc "The loading frame shall be capable of applying up to 50,000 N of controlled force."
            constraint { frame.maxForce >= 50000.0 }
        }

        requirement IncrementalLoading {
            doc "The loading frame shall apply force incrementally to allow dynamic observation of stress development."
            constraint { frame.loadIncrement > 0.0 }
        }

        requirement ControlledForceApplication {
            doc "The loading frame shall apply force in a controlled manner with measurable feedback."
            constraint { frame.currentForce >= 0.0 and frame.currentForce <= frame.maxForce }
        }
    }

    requirement def ImagingRequirements {
        subject camera : DigitalCamera;

        requirement MinimumResolution {
            doc "The digital camera shall have a minimum resolution of 2048x2048 pixels."
            constraint { camera.resolutionWidth >= 2048 and camera.resolutionHeight >= 2048 }
        }

        requirement PreciseFringeCapture {
            doc "The camera shall capture precise images of the fringe pattern at each load increment."
        }
    }

    requirement def DataProcessingRequirements {
        subject processor : ImageProcessor;

        requirement PhaseShiftingAlgorithm {
            doc "The image processor shall use a phase-shifting algorithm to analyze the fringe pattern."
            constraint { processor.algorithm == "phase-shifting" }
        }

        requirement StressFieldCalculation {
            doc "The processor shall calculate precise stress values across the entire specimen from the fringe pattern."
        }

        requirement ColorCodedStressMap {
            doc "The processor shall generate a color-coded stress map as the final result."
        }
    }

    requirement def DisplayRequirements {
        subject display : DisplayUnit;

        requirement DisplayStressMap {
            doc "The display unit shall show the color-coded stress map for interpretation by an engineer or scientist."
        }
    }

    requirement def ExperimentSequenceRequirements {
        subject system : PhotoelasticitySystem;

        requirement CalibrationBeforeLoading {
            doc "The system shall be calibrated without any applied load before beginning the experiment."
        }

        requirement IncrementalCaptureAndProcess {
            doc "At each load increment, the camera shall capture the fringe pattern and the processor shall calculate the corresponding stress."
        }

        requirement PredefinedLoadLimit {
            doc "The experiment shall continue until the predefined load limit is reached."
            constraint { system.predefinedLoadLimit <= 50000.0 }
        }

        requirement DynamicStressObservation {
            doc "The system shall allow dynamic observation of how stress builds and distributes within the material."
        }
    }

    // ===== Requirement Satisfaction =====
    satisfaction opticalPathReq : OpticalPathRequirements {
        subject system : PhotoelasticitySystem;
    }

    satisfaction loadingReq : MechanicalLoadingRequirements {
        subject frame : LoadingFrame;
    }

    satisfaction imagingReq : ImagingRequirements {
        subject camera : DigitalCamera;
    }

    satisfaction processingReq : DataProcessingRequirements {
        subject processor : ImageProcessor;
    }

    satisfaction displayReq : DisplayRequirements {
        subject display : DisplayUnit;
    }

    satisfaction experimentReq : ExperimentSequenceRequirements {
        subject system : PhotoelasticitySystem;
    }
}
