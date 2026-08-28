package MoireDeflectometrySystem {
    public import ScalarValues::*;
    public import ISQ::*;

    item def LightBeam {
        attribute wavelength :> ISQ::length;
        attribute intensity :> ISQ::power;
    }

    item def ExpandedLightBeam :> LightBeam {
        attribute beamDiameter :> ISQ::length;
    }

    item def MoirePattern {
        attribute fringeSpacing :> ISQ::length;
        attribute distortion :> ISQ::planeAngle;
    }

    item def ImageData {
        attribute resolutionX : Integer;
        attribute resolutionY : Integer;
        attribute pixelDepth : Integer;
    }

    item def DeflectionMap {
        attribute spatialResolution :> ISQ::length;
        attribute angularResolution :> ISQ::planeAngle;
    }

    item def ControlCommand {
        attribute command : String;
        attribute parameter : String;
    }

    item def FaultSignal {
        attribute code : Integer;
        attribute msg : String;
    }

    item def CalibrationParameters {
        attribute gratingAngle :> ISQ::planeAngle;
        attribute gratingPitch :> ISQ::length;
    }

    port def OpticalPort {
        in beam : LightBeam;
    }

    port def ExpandedOpticalPort {
        in beam : ExpandedLightBeam;
    }

    port def DataPort {
        in image : ImageData;
    }

    port def ResultPort {
        in map : DeflectionMap;
    }

    port def ControlPort {
        in command : ControlCommand;
        out status : String;
    }

    port def FaultPort {
        in fault : FaultSignal;
    }

    part def MechanicalFrame {
        attribute mass :> ISQ::mass = 25 [kg];
        attribute stiffness : Real = 1.0e7 [N/m];
        attribute thermalStability :> ISQ::temperature;
    }

    part def CoherentLightSource {
        attribute power :> ISQ::power = 0.05 [W];
        attribute wavelength :> ISQ::length = 632.8 [nm];
        port opticalOut : ~OpticalPort;
        perform action emitLight;
    }

    part def BeamExpander {
        attribute expansionRatio : Real = 20.0;
        port opticalIn : OpticalPort;
        port opticalOut : ~ExpandedOpticalPort;
        perform action expandBeam;
    }

    part def Grating {
        attribute pitch :> ISQ::length = 50.0 [um];
        attribute orientation :> ISQ::planeAngle;
        attribute lineDensity : Real;
        port opticalIn : OpticalPort;
        port opticalOut : ~OpticalPort;
        perform action diffractLight;
    }

    part def ImagingLens {
        attribute focalLength :> ISQ::length = 100.0 [mm];
        attribute aperture :> ISQ::length = 25.0 [mm];
        port opticalIn : OpticalPort;
        port opticalOut : ~OpticalPort;
        perform action focusPattern;
    }

    part def DigitalCamera {
        attribute sensorWidth :> ISQ::length = 36.0 [mm];
        attribute sensorHeight :> ISQ::length = 24.0 [mm];
        attribute pixelSize :> ISQ::length = 5.5 [um];
        attribute frameRate :> ISQ::frequency = 30.0 [Hz];
        port opticalIn : OpticalPort;
        port dataOut : ~DataPort;
        perform action captureImage;
    }

    part def ImageProcessor {
        attribute processingSpeed :> ISQ::frequency = 3.0 [GHz];
        attribute algorithm : String = "FourierTransform";
        port dataIn : DataPort;
        port resultOut : ~ResultPort;
        perform action analyzePattern;
    }

    part def MoireDeflectometer {
        attribute operationalTemperature :> ISQ::temperature;
        port controlPort : ControlPort;
        port faultPort : FaultPort;
        port resultPort : ~ResultPort;

        part mechFrame : MechanicalFrame;
        part lightSource : CoherentLightSource;
        part beamExpander : BeamExpander;
        part referenceGrating : Grating {
            attribute orientation = 0.0 [deg];
            attribute lineDensity = 20000.0;
        }
        part testGrating : Grating {
            attribute orientation = 2.0 [deg];
            attribute lineDensity = 20000.0;
        }
        part imagingLens : ImagingLens;
        part camera : DigitalCamera;
        part processor : ImageProcessor;

        connection lightSourceToExpander connect lightSource.opticalOut to beamExpander.opticalIn;
        connection expanderToReference connect beamExpander.opticalOut to referenceGrating.opticalIn;
        connection referenceToTest connect referenceGrating.opticalOut to testGrating.opticalIn;
        connection testToLens connect testGrating.opticalOut to imagingLens.opticalIn;
        connection lensToCamera connect imagingLens.opticalOut to camera.opticalIn;
        connection cameraToProcessor connect camera.dataOut to processor.dataIn;
        connection processorToResult connect processor.resultOut to resultPort;

        perform action MeasurementProcess;

        exhibit state systemStates {
            entry; then idle;
            state idle;
            state calibration;
            state measurement;
            state processing;
            state completed;
            state fault;

            transition idle_to_calibration
                first idle
                accept command : ControlCommand via controlPort
                    if command.command == "calibrate"
                then calibration;
            transition calibration_to_measurement
                first calibration
                accept command : ControlCommand via controlPort
                    if command.command == "measure"
                then measurement;
            transition measurement_to_processing
                first measurement
                accept command : ControlCommand via controlPort
                    if command.command == "process"
                then processing;
            transition processing_to_completed
                first processing
                accept command : ControlCommand via controlPort
                    if command.command == "complete"
                then completed;
            transition completed_to_idle
                first completed
                accept command : ControlCommand via controlPort
                    if command.command == "reset"
                then idle;
            transition idle_to_fault
                first idle
                accept faultSignal : FaultSignal via faultPort
                then fault;
            transition calibration_to_fault
                first calibration
                accept faultSignal : FaultSignal via faultPort
                then fault;
            transition measurement_to_fault
                first measurement
                accept faultSignal : FaultSignal via faultPort
                then fault;
            transition processing_to_fault
                first processing
                accept faultSignal : FaultSignal via faultPort
                then fault;
            transition fault_to_idle
                first fault
                accept command : ControlCommand via controlPort
                    if command.command == "reset"
                then idle;
        }
    }

    action def MeasurementProcess {
        action emitLight {
            out beam : LightBeam;
        }
        then expandBeam;
        action expandBeam {
            in inputBeam : LightBeam;
            out outputBeam : ExpandedLightBeam;
        }
        then passThroughReference;
        action passThroughReference {
            in inputBeam : LightBeam;
            out outputBeam : LightBeam;
        }
        then passThroughTest;
        action passThroughTest {
            in inputBeam : LightBeam;
            out outputBeam : LightBeam;
        }
        then focusPattern;
        action focusPattern {
            in inputBeam : LightBeam;
            out outputBeam : LightBeam;
        }
        then captureImage;
        action captureImage {
            in inputBeam : LightBeam;
            out outputImage : ImageData;
        }
        then analyzePattern;
        action analyzePattern {
            in inputImage : ImageData;
            out result : DeflectionMap;
        }
        flow emitLight.beam to expandBeam.inputBeam;
        flow expandBeam.outputBeam to passThroughReference.inputBeam;
        flow passThroughReference.outputBeam to passThroughTest.inputBeam;
        flow passThroughTest.outputBeam to focusPattern.inputBeam;
        flow focusPattern.outputBeam to captureImage.inputBeam;
        flow captureImage.outputImage to analyzePattern.inputImage;
    }

    requirement def MeasurementPrecision {
        doc
        /*
         * The system shall measure light deflections with sufficient
         * precision for quality control of optical components.
         */
        attribute minDetectableDeflection :> ISQ::planeAngle = 1.0 [urad];
        attribute maxMeasurableDeflection :> ISQ::planeAngle = 10.0 [mrad];
        constraint {
            minDetectableDeflection <= maxMeasurableDeflection
        }
    }

    requirement def SpatialResolution {
        doc
        /*
         * The imaging system shall provide spatial resolution adequate
         * to resolve Moiré fringes across the entire field of view.
         */
        attribute requiredPixelResolution :> ISQ::length = 5.5 [um];
        attribute fieldOfViewWidth :> ISQ::length = 36.0 [mm];
        constraint {
            requiredPixelResolution <= fieldOfViewWidth / 1000.0
        }
    }

    requirement def FrameStability {
        doc
        /*
         * The mechanical frame shall maintain optical alignment under
         * thermal and vibrational disturbances.
         */
        attribute maxDisplacement :> ISQ::length = 1.0 [um];
        attribute thermalStabilityRange :> ISQ::temperature = 2.0 [K];
        constraint {
            maxDisplacement <= 1.0 [um]
        }
    }

    requirement def ProcessingTime {
        doc
        /*
         * The image processor shall complete analysis of a single
         * captured image within an acceptable time frame.
         */
        attribute maxProcessingTime :> ISQ::time = 5.0 [s];
        constraint {
            maxProcessingTime <= 5.0 [s]
        }
    }
}
