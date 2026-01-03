package MoireDeflectometrySystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;

    attribute def WavelengthValue :> LengthValue;
    attribute def FrequencyValue :> Real;
    attribute def AngleValue :> Real;
    attribute def PixelCountValue :> Integer;
    attribute def ContrastValue :> Real;

    enum def MeasurementMode {
        enum staticMeasurement;
        enum dynamicMeasurement;
        enum phaseShifted;
    }

    enum def SystemState {
        enum idle;
        enum calibrating;
        enum measuring;
        enum processing;
        enum complete;
        enum fault;
    }

    item def OpticalWavefront {
        attribute phase : AngleValue;
        attribute amplitude : Real;
        attribute wavelength : WavelengthValue;
    }

    item def MoirePattern {
        attribute fringeSpacing : LengthValue;
        attribute fringeOrientation : AngleValue;
        attribute contrast : ContrastValue;
        attribute visibility : Real;
    }

    item def DeflectionMap {
        attribute deflectionX : AngleValue;
        attribute deflectionY : AngleValue;
        attribute spatialResolution : LengthValue;
        attribute measurementTime : TimeValue;
    }

    port def OpticalInputPort {
        in item wavefront : OpticalWavefront;
    }

    port def OpticalOutputPort {
        out item wavefront : OpticalWavefront;
    }

    port def DataOutputPort {
        out item data;
    }

    port def DataInputPort {
        in item data;
    }

    part def CoherentLightSource {
        attribute wavelength : WavelengthValue;
        attribute outputPower : PowerValue;
        attribute coherenceLength : LengthValue;
        attribute beamDiameter : LengthValue;

        port lightOut : OpticalOutputPort;

        action EmitCoherentLight {
            out emittedWave : OpticalWavefront;
        }
    }

    part def BeamExpander {
        attribute magnification : Real;
        attribute inputAperture : LengthValue;
        attribute outputAperture : LengthValue;

        port opticalIn : OpticalInputPort;
        port opticalOut : OpticalOutputPort;

        action ExpandBeam {
            in incidentWave : OpticalWavefront;
            out expandedWave : OpticalWavefront;
        }
    }

    part def ReferenceGrating {
        attribute gratingPitch : LengthValue;
        attribute gratingFrequency : FrequencyValue;
        attribute orientation : AngleValue;
        attribute transmittance : Real;
        attribute gratingType : String;

        port opticalIn : OpticalInputPort;
        port opticalOut : OpticalOutputPort;

        action ModulateWavefront {
            in incidentWave : OpticalWavefront;
            out modulatedWave : OpticalWavefront;
        }
    }

    part def TestGrating {
        attribute gratingPitch : LengthValue;
        attribute gratingFrequency : FrequencyValue;
        attribute orientation : AngleValue;
        attribute distanceFromReference : LengthValue;

        port opticalIn : OpticalInputPort;
        port opticalOut : OpticalOutputPort;
        port specimenInterface;

        action InteractWithSpecimen {
            in incidentWave : OpticalWavefront;
            in specimenDeflection;
            out deflectedWave : OpticalWavefront;
        }
    }

    part def ImagingSystem {
        attribute focalLength : LengthValue;
        attribute numericalAperture : Real;
        attribute magnification : Real;

        port opticalIn : OpticalInputPort;
        port opticalOut : OpticalOutputPort;

        action FormImage {
            in moirePattern : MoirePattern;
            out imageData;
        }
    }

    part def DigitalCamera {
        attribute resolutionX : PixelCountValue;
        attribute resolutionY : PixelCountValue;
        attribute pixelPitch : LengthValue;
        attribute bitDepth : Integer;
        attribute frameRate : FrequencyValue;
        attribute quantumEfficiency : Real;

        port opticalIn : OpticalInputPort;
        port dataOut : DataOutputPort;

        action CaptureImage {
            in moirePattern : MoirePattern;
            out imageData;
        }
    }

    part def ImageProcessor {
        attribute processingSpeed : FrequencyValue;
        attribute memoryCapacity : Real;
        attribute algorithmType : String;

        port dataIn : DataInputPort;
        port dataOut : DataOutputPort;

        action ProcessMoirePattern {
            in rawImageData;
            out deflectionData : DeflectionMap;
        }

        action PerformFourierAnalysis {
            in imageData;
            out frequencyData;
        }

        action ExtractPhase {
            in frequencyData;
            out phaseMap;
        }

        action CalculateDeflection {
            in phaseMap;
            out deflectionAngles;
        }
    }

    part def CalibrationUnit {
        attribute referenceDeflection : AngleValue;
        attribute calibrationAccuracy : Real;

        action PerformCalibration {
            in systemParameters;
            out calibrationCoefficients;
        }
    }

    part def MechanicalMount {
        attribute stability : Real;
        attribute adjustmentRange : LengthValue;
        attribute positionAccuracy : LengthValue;

        action AdjustPosition {
            in targetPosition : LengthValue;
            out actualPosition : LengthValue;
        }
    }

    action def InitializeSystem {
        out systemReady : Boolean;
    }

    action def CalibrateSystem {
        in referenceData;
        out calibrationParameters;
    }

    action def AcquireMoirePattern {
        in illuminationWave : OpticalWavefront;
        out moirePattern : MoirePattern;
    }

    action def AnalyzeDeflection {
        in moirePattern : MoirePattern;
        out deflectionMap : DeflectionMap;
    }

    action def ValidateResults {
        in deflectionMap : DeflectionMap;
        out validationStatus : Boolean;
    }

    action def PerformMoireDeflectometryMeasurement {
        first start;
        then action initialize : InitializeSystem;
        then action calibrate : CalibrateSystem;
        then merge measurementCycle;

        action emitLight : CoherentLightSource::EmitCoherentLight {
            out coherentWave : OpticalWavefront;
        }
        then action expandBeam : BeamExpander::ExpandBeam {
            in incidentWave = emitLight.coherentWave;
            out collimatedWave : OpticalWavefront;
        }
        then action modulateReference : ReferenceGrating::ModulateWavefront {
            in incidentWave = expandBeam.collimatedWave;
            out refModulated : OpticalWavefront;
        }
        then action interactTest : TestGrating::InteractWithSpecimen {
            in incidentWave = expandBeam.collimatedWave;
            out testModulated : OpticalWavefront;
        }
        then action acquirePattern : AcquireMoirePattern {
            in illuminationWave = modulateReference.refModulated;
            out pattern : MoirePattern;
        }
        then action captureImage : DigitalCamera::CaptureImage {
            in moirePattern = acquirePattern.pattern;
            out rawData;
        }
        then action processData : ImageProcessor::ProcessMoirePattern {
            in rawImageData = captureImage.rawData;
            out results : DeflectionMap;
        }
        then action analyzeDeflection : AnalyzeDeflection {
            in moirePattern = acquirePattern.pattern;
            out deflectionResults : DeflectionMap;
        }
        then action validateResults : ValidateResults {
            in deflectionMap = analyzeDeflection.deflectionResults;
            out isValid : Boolean;
        }
        then decide;
            if validateResults.isValid then finalizeMeasurement;
            if !validateResults.isValid then measurementCycle;

        action finalizeMeasurement;
        then done;
    }

    state def MoireDeflectometryControl {
        entry; then idle;

        state idle;
        accept StartCalibration
        then calibrating;

        state calibrating {
            do action calibrationAction : CalibrateSystem;
        }
        accept CalibrationComplete
        then measuring;

        state measuring {
            do action measurementAction : PerformMoireDeflectometryMeasurement;
        }
        accept MeasurementComplete
        then processing;

        state processing {
            do action processingAction : ImageProcessor::ProcessMoirePattern;
        }
        accept ProcessingComplete
        then complete;

        state complete;
        accept ResetSystem
        then idle;

        accept FaultDetected
        then fault;

        state fault;
        accept FaultCleared
        then idle;
    }

    constraint def FringeSpacingConstraint {
        in gratingPitch1 : LengthValue;
        in gratingPitch2 : LengthValue;
        in gratingAngle : AngleValue;
        out fringeSpacing : LengthValue;
        fringeSpacing == gratingPitch1 * gratingPitch2 / (gratingPitch1 - gratingPitch2 * cos(gratingAngle))
    }

    constraint def DeflectionSensitivityConstraint {
        in fringeSpacing : LengthValue;
        in gratingDistance : LengthValue;
        out sensitivity : Real;
        sensitivity == fringeSpacing / gratingDistance
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The Moire deflectometry system shall measure the angular deflection
             * of light rays passing through or reflecting from a test specimen
             * by analyzing interference patterns formed between two gratings.
             */
        subject system;
    }

    requirement def MeasurementAccuracyRequirement {
        doc /* The system shall achieve specified measurement accuracy
             * for deflection angle determination.
             */
        subject measurementSystem;
    }

    requirement def OpticalQualityRequirement {
        doc /* The optical components shall maintain sufficient quality
             * to produce analyzable Moire patterns.
             */
        subject opticalSystem;
    }

    requirement <'REQ-MD-001'> primaryFunction : PrimaryFunctionRequirement {
        doc /* The system shall measure wavefront deflections using Moire fringe analysis. */
        subject system :>> moireDeflectometer;
    }

    requirement <'REQ-MD-002'> deflectionSensitivity : MeasurementAccuracyRequirement {
        doc /* The system shall detect deflection angles with sensitivity better than 0.01 degrees. */
        subject system :>> moireDeflectometer;
        require constraint {
            system.processor.algorithmType == "Fourier Transform"
        }
    }

    requirement <'REQ-MD-003'> spatialResolution : MeasurementAccuracyRequirement {
        doc /* The system shall achieve spatial resolution better than 50 micrometers. */
        subject system :>> moireDeflectometer;
        require constraint {
            system.camera.pixelPitch <= 5.0 [um]
        }
    }

    requirement <'REQ-MD-004'> gratingAlignment : OpticalQualityRequirement {
        doc /* The reference and test gratings shall be aligned within 0.05 degrees. */
        subject system :>> moireDeflectometer;
        require constraint {
            abs(system.referenceGrating.orientation - system.testGrating.orientation) <= 0.05
        }
    }

    requirement <'REQ-MD-005'> measurementSpeed : MeasurementAccuracyRequirement {
        doc /* The system shall complete a measurement cycle in less than 3 seconds. */
        subject system :>> moireDeflectometer;
        require constraint {
            system.camera.frameRate >= 30.0
        }
    }

    requirement <'REQ-MD-006'> fringeContrast : OpticalQualityRequirement {
        doc /* The Moire pattern shall exhibit contrast ratio greater than 0.7. */
        subject system :>> moireDeflectometer;
        require constraint {
            system.referenceGrating.transmittance >= 0.8
        }
    }

    part def MoireDeflectometer {
        doc /* A Moire deflectometry system measures wavefront deflections and surface gradients
             * by analyzing interference patterns generated between a reference grating and a test grating.
             * The system illuminates both gratings with coherent light, and the resulting Moire fringes
             * encode information about the angular deflection of light rays caused by the test specimen.
             */

        attribute gratingDistance : LengthValue;
        attribute measurementArea : AreaValue;
        attribute operatingMode : MeasurementMode;
        attribute systemState : SystemState;
        attribute minimumDetectableAngle : AngleValue;

        part lightSource : CoherentLightSource {
            attribute :>> wavelength : WavelengthValue = 632.8 [nm];
            attribute :>> outputPower : PowerValue = 10.0 [mW];
            attribute :>> coherenceLength : LengthValue = 0.5 [m];
            attribute :>> beamDiameter : LengthValue = 2.0 [mm];
        }

        part beamExpander : BeamExpander {
            attribute :>> magnification : Real = 10.0;
            attribute :>> inputAperture : LengthValue = 2.0 [mm];
            attribute :>> outputAperture : LengthValue = 20.0 [mm];
        }

        part referenceGrating : ReferenceGrating {
            attribute :>> gratingPitch : LengthValue = 0.1 [mm];
            attribute :>> gratingFrequency : FrequencyValue = 10.0;
            attribute :>> orientation : AngleValue = 0.0;
            attribute :>> transmittance : Real = 0.85;
            attribute :>> gratingType : String = "Ronchi";
        }

        part testGrating : TestGrating {
            attribute :>> gratingPitch : LengthValue = 0.1 [mm];
            attribute :>> gratingFrequency : FrequencyValue = 10.0;
            attribute :>> orientation : AngleValue = 0.02;
            attribute :>> distanceFromReference : LengthValue = 100.0 [mm];
        }

        part imagingSystem : ImagingSystem {
            attribute :>> focalLength : LengthValue = 50.0 [mm];
            attribute :>> numericalAperture : Real = 0.25;
            attribute :>> magnification : Real = 1.0;
        }

        part camera : DigitalCamera {
            attribute :>> resolutionX : PixelCountValue = 2048;
            attribute :>> resolutionY : PixelCountValue = 2048;
            attribute :>> pixelPitch : LengthValue = 3.45 [um];
            attribute :>> bitDepth : Integer = 12;
            attribute :>> frameRate : FrequencyValue = 60.0;
            attribute :>> quantumEfficiency : Real = 0.75;
        }

        part processor : ImageProcessor {
            attribute :>> processingSpeed : FrequencyValue = 100.0;
            attribute :>> memoryCapacity : Real = 32.0;
            attribute :>> algorithmType : String = "Fourier Transform";
        }

        part calibrationUnit : CalibrationUnit {
            attribute :>> referenceDeflection : AngleValue = 0.0;
            attribute :>> calibrationAccuracy : Real = 0.001;
        }

        part mount : MechanicalMount {
            attribute :>> stability : Real = 0.98;
            attribute :>> adjustmentRange : LengthValue = 10.0 [mm];
            attribute :>> positionAccuracy : LengthValue = 0.5 [um];
        }

        connection opticalPath1 connect lightSource.lightOut to beamExpander.opticalIn;
        connection opticalPath2 connect beamExpander.opticalOut to referenceGrating.opticalIn;
        connection opticalPath3 connect beamExpander.opticalOut to testGrating.opticalIn;
        connection opticalPath4 connect referenceGrating.opticalOut to imagingSystem.opticalIn;
        connection opticalPath5 connect testGrating.opticalOut to imagingSystem.opticalIn;
        connection opticalPath6 connect imagingSystem.opticalOut to camera.opticalIn;
        connection dataPath1 connect camera.dataOut to processor.dataIn;

        assert constraint fringeSpacing : FringeSpacingConstraint {
            in gratingPitch1 = referenceGrating.gratingPitch;
            in gratingPitch2 = testGrating.gratingPitch;
            in gratingAngle = testGrating.orientation;
        }

        assert constraint sensitivity : DeflectionSensitivityConstraint {
            in fringeSpacing = fringeSpacing.fringeSpacing;
            in gratingDistance = testGrating.distanceFromReference;
        }

        perform action measureDeflection : PerformMoireDeflectometryMeasurement;
        exhibit state systemControl : MoireDeflectometryControl;
    }

    part moireDeflectometer : MoireDeflectometer {
        attribute :>> gratingDistance : LengthValue = 100.0 [mm];
        attribute :>> measurementArea : AreaValue = 100.0 [mm^2];
        attribute :>> operatingMode : MeasurementMode = MeasurementMode::staticMeasurement;
        attribute :>> systemState : SystemState = SystemState::idle;
        attribute :>> minimumDetectableAngle : AngleValue = 0.005;
    }

    satisfy primaryFunction by moireDeflectometer;
    satisfy deflectionSensitivity by moireDeflectometer;
    satisfy spatialResolution by moireDeflectometer;
    satisfy gratingAlignment by moireDeflectometer;
    satisfy measurementSpeed by moireDeflectometer;
    satisfy fringeContrast by moireDeflectometer;
}
