package MoireDeflectometry {

    package Units {
        scalar value type Length :> Real { unit 'mm'; }
        scalar value type Angle :> Real { unit 'deg'; }
        scalar value type Power :> Real { unit 'mW'; }
        scalar value type Wavelength :> Real { unit 'nm'; }
        scalar value type Deflection :> Real { unit 'urad'; }
        scalar value type SpatialFrequency :> Real { unit 'lp/mm'; }
        scalar value type Duration :> Real { unit 's'; }
        scalar value type Temperature :> Real { unit 'K'; }
        scalar value type PixelCount :> Integer;
        scalar value type Frequency :> Real { unit 'Hz'; }
    }

    package Items {
        item def LightBeam {
            attribute wavelength : Wavelength;
            attribute power : Power;
            attribute beamDiameter : Length;
            attribute coherenceLength : Length;
        }

        item def MoirePattern {
            attribute fringeSpacing : Length;
            attribute contrast : Real;
            attribute distortionField : Deflection[0..*];
        }

        item def ImageData {
            attribute width : PixelCount;
            attribute height : PixelCount;
            attribute exposureTime : Duration;
            attribute pixelDepth : Integer;
        }

        item def DeflectionMap {
            attribute spatialResolution : Length;
            attribute maxDeflection : Deflection;
            attribute values : Deflection[0..*];
            attribute timestamp : Duration;
        }

        item def CalibrationData {
            attribute referenceAngle : Angle;
            attribute gratingAngle : Angle;
            attribute ambientTemperature : Temperature;
            attribute baselineFringeSpacing : Length;
        }

        item def ControlCommand {
            attribute command : String;
            attribute parameter : Real;
        }

        item def StatusReport {
            attribute state : String;
            attribute timestamp : Duration;
            attribute message : String;
        }
    }

    package Ports {
        port def LightOutPort {
            out beam : LightBeam;
        }

        port def LightInPort {
            in beam : LightBeam;
        }

        port def ImageOutPort {
            out image : ImageData;
        }

        port def ImageInPort {
            in image : ImageData;
        }

        port def MapOutPort {
            out map : DeflectionMap;
        }

        port def CommandPort {
            in command : ControlCommand;
        }

        port def StatusPort {
            out status : StatusReport;
        }

        port def CalibrationPort {
            inout calibration : CalibrationData;
        }
    }

    package Components {

        part def LaserSource {
            port lightOut : LightOutPort;
            port statusOut : StatusPort;

            attribute outputPower : Power = 50 [mW];
            attribute wavelength : Wavelength = 632.8 [nm];
            attribute beamDiameter : Length = 1.0 [mm];
            attribute coherenceLength : Length = 1000.0 [mm];
            attribute warmupTime : Duration = 30.0 [s];
            attribute enabled : Boolean = false;

            action def EmitBeam {
                out beam : LightBeam;
            }

            action emitBeam : EmitBeam {
                out beam.beamDiameter = beamDiameter;
                out beam.wavelength = wavelength;
                out beam.power = outputPower;
                out beam.coherenceLength = coherenceLength;
            }
        }

        part def BeamExpander {
            port lightIn : LightInPort;
            port lightOut : LightOutPort;

            attribute expansionRatio : Real = 10.0;
            attribute outputDiameter : Length = 10.0 [mm];
            attribute inputAperture : Length = 2.0 [mm];

            action expand {
                in incoming : LightBeam;
                out outgoing : LightBeam;
            }
        }

        part def Grating {
            port lightIn : LightInPort;
            port lightOut : LightOutPort;

            attribute spatialFrequency : SpatialFrequency = 100 [lp/mm];
            attribute orientation : Angle;
            attribute substrateDiameter : Length = 50.0 [mm];
            attribute lineDepth : Length = 0.0001 [mm];
            attribute efficiency : Real = 0.85;

            action diffract {
                in incoming : LightBeam;
                out outgoing : LightBeam;
            }
        }

        part def ReferenceGrating :> Grating {
            attribute orientation : Angle = 0.0 [deg];
        }

        part def TestGrating :> Grating {
            attribute orientation : Angle = 2.0 [deg];
        }

        part def TestSpecimen {
            port lightIn : LightInPort;
            port lightOut : LightOutPort;

            attribute description : String;
            attribute temperature : Temperature = 293.15 [K];
            attribute refractiveIndex : Real = 1.5;
            attribute thickness : Length = 10.0 [mm];

            action deflect {
                in incoming : LightBeam;
                out outgoing : LightBeam;
            }
        }

        part def ImagingLens {
            port lightIn : LightInPort;
            port lightOut : LightOutPort;

            attribute focalLength : Length = 100.0 [mm];
            attribute aperture : Length = 25.0 [mm];
            attribute magnification : Real = 1.0;

            action focus {
                in incoming : LightBeam;
                out focused : LightBeam;
            }
        }

        part def DigitalCamera {
            port lightIn : LightInPort;
            port imageOut : ImageOutPort;
            port triggerIn : CommandPort;

            attribute sensorWidth : PixelCount = 2048;
            attribute sensorHeight : PixelCount = 2048;
            attribute pixelSize : Length = 0.0055 [mm];
            attribute exposureTime : Duration = 0.01 [s];
            attribute frameRate : Frequency = 30.0 [Hz];
            attribute quantizationBits : Integer = 12;

            action def Capture {
                in incomingBeam : LightBeam;
                out capturedImage : ImageData;
            }

            action capture : Capture {
                in incomingBeam;
                out capturedImage.width = sensorWidth;
                out capturedImage.height = sensorHeight;
                out capturedImage.exposureTime = exposureTime;
                out capturedImage.pixelDepth = quantizationBits;
            }
        }

        part def ImageProcessor {
            port imageIn : ImageInPort;
            port mapOut : MapOutPort;
            port calibrationPort : CalibrationPort;

            attribute algorithm : String = "Fourier";
            attribute processingTime : Duration = 2.0 [s];
            attribute spatialResolution : Length = 0.05 [mm];
            attribute detectionLimit : Deflection = 0.5 [urad];

            action def Analyze {
                in image : ImageData;
                in calibration : CalibrationData;
                out deflectionMap : DeflectionMap;
            }

            action performFourierAnalysis : Analyze {
                in image;
                in calibration;
                out deflectionMap.spatialResolution = spatialResolution;
                out deflectionMap.timestamp = 0.0 [s];
            }
        }

        part def MechanicalFrame {
            attribute material : String = "Invar";
            attribute thermalStability : Temperature = 0.1 [K];
            attribute vibrationIsolation : Real = 0.95;
            attribute baseDimensions : Length = 800.0 [mm];
            attribute mass : Real = 25.0;
        }

        part def Controller {
            port commandIn : CommandPort;
            port statusOut : StatusPort;
            port laserEnable : CommandPort;
            port cameraTrigger : CommandPort;
            port calibrationPort : CalibrationPort;

            attribute currentState : String = "idle";
            attribute lastCalibration : Duration = 0.0 [s];
            attribute faultMessage : String;

            action def PerformCalibration {
                out calibration : CalibrationData;
            }

            action def ExecuteMeasurement {
                in calibration : CalibrationData;
                out result : DeflectionMap;
            }

            action performCalibration : PerformCalibration {
                out calibration.referenceAngle = 0.0 [deg];
                out calibration.gratingAngle = 2.0 [deg];
                out calibration.ambientTemperature = 293.15 [K];
                out calibration.baselineFringeSpacing = 5.0 [mm];
            }

            state machine ControllerStateMachine {

                state idle {
                    entry { currentState = "idle"; }
                    do { sendStatus("idle", "Awaiting command"); }
                }

                state calibrating {
                    entry { currentState = "calibrating"; }
                    do { performCalibration(); }
                    exit { lastCalibration = 0.0 [s]; }
                }

                state measuring {
                    entry { currentState = "measuring"; }
                    do { sendTriggerToCamera(); }
                }

                state processing {
                    entry { currentState = "processing"; }
                    do { waitForDeflectionMap(); }
                }

                state complete {
                    entry { currentState = "complete"; }
                    do { sendStatus("complete", "Measurement complete"); }
                }

                state fault {
                    entry { currentState = "fault"; }
                    do { sendStatus("fault", faultMessage); }
                }

                transition t_idle_to_calibrating
                    source idle
                    target calibrating
                    when commandIn.command.command == "start";

                transition t_calibrating_to_measuring
                    source calibrating
                    target measuring
                    when calibrationComplete;

                transition t_measuring_to_processing
                    source measuring
                    target processing
                    when imageCaptured;

                transition t_processing_to_complete
                    source processing
                    target complete
                    when deflectionMapReady;

                transition t_complete_to_idle
                    source complete
                    target idle
                    when commandIn.command.command == "reset";

                transition t_any_to_fault
                    source idle
                    target fault
                    when errorDetected;

                transition t_calibrating_to_fault
                    source calibrating
                    target fault
                    when errorDetected;

                transition t_measuring_to_fault
                    source measuring
                    target fault
                    when errorDetected;

                transition t_processing_to_fault
                    source processing
                    target fault
                    when errorDetected;

                transition t_fault_to_idle
                    source fault
                    target idle
                    when commandIn.command.command == "reset";
            }

            action sendStatus {
                in stateName : String;
                in message : String;
            }

            action sendTriggerToCamera;
            action waitForDeflectionMap;
        }
    }

    package System {

        part def MoireDeflectometer {
            port commandIn : CommandPort;
            port statusOut : StatusPort;
            port resultOut : MapOutPort;

            attribute systemName : String = "Moiré Deflectometer MD-1000";
            attribute precision : Deflection = 1.0 [urad];
            attribute operatingTemperature : Temperature = 293.15 [K];

            part frame : Components::MechanicalFrame {
                attribute material = "Invar";
            }

            part laser : Components::LaserSource;
            part expander : Components::BeamExpander;
            part referenceGrating : Components::ReferenceGrating;
            part testSpecimen : Components::TestSpecimen;
            part testGrating : Components::TestGrating;
            part imagingLens : Components::ImagingLens;
            part camera : Components::DigitalCamera;
            part processor : Components::ImageProcessor;
            part controller : Components::Controller;

            connection lightPath1 connect laser.lightOut to expander.lightIn;
            connection lightPath2 connect expander.lightOut to referenceGrating.lightIn;
            connection lightPath3 connect referenceGrating.lightOut to testSpecimen.lightIn;
            connection lightPath4 connect testSpecimen.lightOut to testGrating.lightIn;
            connection lightPath5 connect testGrating.lightOut to imagingLens.lightIn;
            connection lightPath6 connect imagingLens.lightOut to camera.lightIn;

            connection imageDataFlow connect camera.imageOut to processor.imageIn;
            connection resultFlow connect processor.mapOut to resultOut;

            connection commandFlow connect commandIn to controller.commandIn;
            connection statusFlow connect controller.statusOut to statusOut;
            connection laserControl connect controller.laserEnable to laser.statusOut;
            connection cameraControl connect controller.cameraTrigger to camera.triggerIn;
            connection calibrationLink connect controller.calibrationPort to processor.calibrationPort;

            flow lightPath1.lightBeam : Items::LightBeam;
            flow lightPath2.lightBeam : Items::LightBeam;
            flow lightPath3.lightBeam : Items::LightBeam;
            flow lightPath4.lightBeam : Items::LightBeam;
            flow lightPath5.lightBeam : Items::LightBeam;
            flow lightPath6.lightBeam : Items::LightBeam;
            flow imageDataFlow.image : Items::ImageData;
            flow resultFlow.map : Items::DeflectionMap;
            flow commandFlow.command : Items::ControlCommand;
            flow statusFlow.status : Items::StatusReport;
        }
    }

    package Requirements {

        requirement def PrecisionRequirement {
            subject deflectometer : System::MoireDeflectometer;
            doc /* The system shall measure light deflections with precision of 1 urad or better. */
            constraint { deflectometer.precision <= 1.0 [urad] }
        }

        requirement def WavelengthRequirement {
            subject source : Components::LaserSource;
            doc /* The light source shall produce coherent light with wavelength between 400 nm and 700 nm. */
            constraint { source.wavelength >= 400.0 [nm] }
            constraint { source.wavelength <= 700.0 [nm] }
        }

        requirement def BeamExpansionRequirement {
            subject expander : Components::BeamExpander;
            doc /* The beam expander shall widen the beam to at least 10 mm diameter. */
            constraint { expander.outputDiameter >= 10.0 [mm] }
        }

        requirement def GratingAngleRequirement {
            subject ref : Components::ReferenceGrating;
            subject test : Components::TestGrating;
            doc /* The two gratings shall be set at a relative angle between 0.5 deg and 5 deg. */
            constraint { (test.orientation - ref.orientation) >= 0.5 [deg] }
            constraint { (test.orientation - ref.orientation) <= 5.0 [deg] }
        }

        requirement def CameraResolutionRequirement {
            subject camera : Components::DigitalCamera;
            doc /* The camera shall have at least 2048x2048 pixel resolution. */
            constraint { camera.sensorWidth >= 2048 }
            constraint { camera.sensorHeight >= 2048 }
        }

        requirement def ProcessingTimeRequirement {
            subject processor : Components::ImageProcessor;
            doc /* The image processor shall complete analysis within 5 seconds. */
            constraint { processor.processingTime <= 5.0 [s] }
        }

        requirement def FrameStabilityRequirement {
            subject frame : Components::MechanicalFrame;
            doc /* The mechanical frame shall maintain thermal stability within 0.1 K. */
            constraint { frame.thermalStability <= 0.1 [K] }
        }

        requirement def StateMachineRequirement {
            subject controller : Components::Controller;
            doc /* The controller shall transition through idle, calibrating, measuring, processing, complete, and fault states. */
            constraint { controller.currentState in {"idle", "calibrating", "measuring", "processing", "complete", "fault"} }
        }

        requirement def DetectionLimitRequirement {
            subject processor : Components::ImageProcessor;
            doc /* The processor shall detect deflections as small as 0.5 urad. */
            constraint { processor.detectionLimit <= 0.5 [urad] }
        }

        requirement precisionReq : PrecisionRequirement;
        requirement wavelengthReq : WavelengthRequirement;
        requirement beamExpansionReq : BeamExpansionRequirement;
        requirement gratingAngleReq : GratingAngleRequirement;
        requirement cameraResolutionReq : CameraResolutionRequirement;
        requirement processingTimeReq : ProcessingTimeRequirement;
        requirement frameStabilityReq : FrameStabilityRequirement;
        requirement stateMachineReq : StateMachineRequirement;
        requirement detectionLimitReq : DetectionLimitRequirement;
    }

    package Verification {

        verification def VerifyPrecision {
            subject deflectometer : System::MoireDeflectometer;
            objective { satisfy Requirements::precisionReq; }
            method { compare measured deflection against known reference; }
        }

        verification def VerifyGratingAngle {
            subject ref : Components::ReferenceGrating;
            subject test : Components::TestGrating;
            objective { satisfy Requirements::gratingAngleReq; }
            method { measure relative angle with autocollimator; }
        }

        verification def VerifyProcessingTime {
            subject processor : Components::ImageProcessor;
            objective { satisfy Requirements::processingTimeReq; }
            method { time execution of analysis on standard image; }
        }

        verification def VerifyStateMachine {
            subject controller : Components::Controller;
            objective { satisfy Requirements::stateMachineReq; }
            method { exercise all transitions via test commands; }
        }

        verification verifyPrecision : VerifyPrecision;
        verification verifyGratingAngle : VerifyGratingAngle;
        verification verifyProcessingTime : VerifyProcessingTime;
        verification verifyStateMachine : VerifyStateMachine;
    }
}
