package StrainRateImagingSystem {
    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types with Units =====
    value type FrequencyUnit > Real {
        unit "Hz";
    }
    value type FrameRateUnit > Real {
        unit "fps";
    }
    value type AcousticPressureUnit > Real {
        unit "MPa";
    }
    value type MechanicalIndexUnit > Real {
        unit "MI";
    }
    value type VelocityUnit > Real {
        unit "m/s";
    }
    value type StrainRateUnit > Real {
        unit "1/s";
    }
    value type DisplacementUnit > Real {
        unit "mm";
    }
    value type TimeUnit > Real {
        unit "s";
    }
    value type TemperatureUnit > Real {
        unit "degC";
    }
    value type PowerUnit > Real {
        unit "W";
    }
    value type PixelUnit > Integer {
        unit "px";
    }

    // ===== Item Definitions =====
    item def AcousticPulse {
        attribute frequency : FrequencyUnit;
        attribute amplitude : AcousticPressureUnit;
        attribute duration : TimeUnit;
    }
    item def EchoSignal {
        attribute rawAmplitude : Real;
        attribute timestamp : TimeUnit;
        attribute channelCount : Integer;
    }
    item def BeamformedFrame {
        attribute width : PixelUnit;
        attribute height : PixelUnit;
        attribute depth : DisplacementUnit;
        attribute timestamp : TimeUnit;
        attribute pixelData : Real[0..*];
    }
    item def DisplacementField {
        attribute frameIndex : Integer;
        attribute displacements : DisplacementUnit[0..*];
        attribute timestamp : TimeUnit;
    }
    item def VelocityField {
        attribute frameIndex : Integer;
        attribute velocities : VelocityUnit[0..*];
        attribute timestamp : TimeUnit;
    }
    item def StrainRateMap {
        attribute frameIndex : Integer;
        attribute strainRates : StrainRateUnit[0..*];
        attribute timestamp : TimeUnit;
        attribute regionCount : Integer;
    }
    item def RenderedImage {
        attribute width : PixelUnit;
        attribute height : PixelUnit;
        attribute colorOverlay : Boolean;
        attribute timestamp : TimeUnit;
    }
    item def ImagingParameters {
        attribute frameRate : FrameRateUnit;
        attribute scanDepth : DisplacementUnit;
        attribute scanWidth : DisplacementUnit;
        attribute focusDepth : DisplacementUnit;
        attribute acousticOutput : AcousticPressureUnit;
    }
    item def ControlCommand {
        attribute commandType : String;
        attribute parameterName : String;
        attribute parameterValue : Real;
    }
    item def CalibrationData {
        attribute probeId : String;
        attribute calibrationTime : TimeUnit;
        attribute referenceVelocity : VelocityUnit;
        attribute geometricCorrection : Real[0..*];
    }

    // ===== Port Definitions =====
    port def AcousticOutPort {
        out pulse : AcousticPulse;
    }
    port def AcousticInPort {
        in echo : EchoSignal;
    }
    port def EchoOutPort {
        out echo : EchoSignal;
    }
    port def EchoInPort {
        in echo : EchoSignal;
    }
    port def FrameOutPort {
        out frame : BeamformedFrame;
    }
    port def FrameInPort {
        in frame : BeamformedFrame;
    }
    port def DisplacementOutPort {
        out displacement : DisplacementField;
    }
    port def DisplacementInPort {
        in displacement : DisplacementField;
    }
    port def VelocityOutPort {
        out velocity : VelocityField;
    }
    port def VelocityInPort {
        in velocity : VelocityField;
    }
    port def StrainRateOutPort {
        out strainRate : StrainRateMap;
    }
    port def StrainRateInPort {
        in strainRate : StrainRateMap;
    }
    port def ImageOutPort {
        out image : RenderedImage;
    }
    port def ImageInPort {
        in image : RenderedImage;
    }
    port def ControlOutPort {
        out command : ControlCommand;
        out parameters : ImagingParameters;
    }
    port def ControlInPort {
        in command : ControlCommand;
        in parameters : ImagingParameters;
    }
    port def CalibrationOutPort {
        out calibration : CalibrationData;
    }
    port def CalibrationInPort {
        in calibration : CalibrationData;
    }

    // ===== Requirements =====
    requirement def HighFrameRateRequirement {
        doc "The system shall achieve a frame rate of at least 50 fps to accurately capture rapid cardiac motion."
        attribute minFrameRate : FrameRateUnit = 50;
        subject system : StrainRateImagingSystem;
        require system.measuredFrameRate >= minFrameRate;
    }
    requirement def AcousticSafetyRequirement {
        doc "The system shall adhere to diagnostic medical device acoustic safety standards, with mechanical index below 1.9 and thermal index below 1.0."
        attribute maxMechanicalIndex : MechanicalIndexUnit = 1.9;
        attribute maxThermalIndex : Real = 1.0;
        subject system : StrainRateImagingSystem;
        require system.mechanicalIndex <= maxMechanicalIndex;
        require system.thermalIndex <= maxThermalIndex;
    }
    requirement def RealTimeProcessingRequirement {
        doc "The system shall process and display strain rate data within 40 milliseconds of echo acquisition."
        attribute maxLatency : TimeUnit = 0.040;
        subject system : StrainRateImagingSystem;
        require system.processingLatency <= maxLatency;
    }
    requirement def NonInvasiveAssessmentRequirement {
        doc "The system shall non-invasively assess myocardial function through transthoracic ultrasound."
        subject system : StrainRateImagingSystem;
        require system.invasive == false;
    }
    requirement def RegionalStrainAccuracyRequirement {
        doc "The system shall provide regional strain rate measurements with spatial resolution of at least 2 mm."
        attribute minSpatialResolution : DisplacementUnit = 2;
        subject system : StrainRateImagingSystem;
        require system.spatialResolution <= minSpatialResolution;
    }
    requirement def CalibrationRequirement {
        doc "The system shall perform an initial calibration phase before entering the imaging loop."
        subject system : StrainRateImagingSystem;
        require system.calibrationCompleted == true;
    }

    // ===== Part Definitions =====
    part def Transducer {
        port acousticOut : AcousticOutPort;
        port echoIn : AcousticInPort;
        port echoOut : EchoOutPort;
        port controlIn : ControlInPort;

        attribute operatingFrequency : FrequencyUnit = 5000000;
        attribute maxAcousticPressure : AcousticPressureUnit = 1.9;
        attribute elementCount : Integer = 128;
        attribute currentParameters : ImagingParameters;

        attribute mechanicalIndex : MechanicalIndexUnit;
        attribute thermalIndex : Real;

        action def TransmitPulses {
            in params : ImagingParameters;
            out pulse : AcousticPulse;
        }
        action def ReceiveEchoes {
            in echo : EchoSignal;
            out processedEcho : EchoSignal;
        }

        exhibit state def TransducerBehavior {
            entry;
            do { transmitPulses(currentParameters); }
            state Idle;
            state Transmitting {
                do { transmitPulses(currentParameters); }
            }
            state Receiving {
                do { receiveEchoes(); }
            }
            transition from Idle to Transmitting when controlIn.parameters?currentParameters;
            transition from Transmitting to Receiving when acousticOut.pulse?transmitted;
            transition from Receiving to Idle when echoOut.echo?sent;
        }
    }

    part def Beamformer {
        port echoIn : EchoInPort;
        port frameOut : FrameOutPort;
        port controlIn : ControlInPort;

        attribute focusDepth : DisplacementUnit;
        attribute channelCount : Integer = 128;
        attribute lineCount : Integer = 128;
        attribute samplesPerLine : Integer = 2048;

        action def FocusAndConstruct {
            in echo : EchoSignal;
            out frame : BeamformedFrame;
        }

        exhibit state def BeamformerBehavior {
            entry;
            state Waiting;
            state Beamforming {
                do { focusAndConstruct(echoIn.echo); }
            }
            transition from Waiting to Beamforming when echoIn.echo?received;
            transition from Beamforming to Waiting when frameOut.frame?sent;
        }
    }

    part def MotionTracker {
        port frameIn : FrameInPort;
        port displacementOut : DisplacementOutPort;
        port controlIn : ControlInPort;

        attribute kernelSize : PixelUnit = 21;
        attribute searchRegion : PixelUnit = 31;
        attribute trackingAlgorithm : String = "SpeckleTracking";

        action def TrackSpeckles {
            in currentFrame : BeamformedFrame;
            in previousFrame : BeamformedFrame;
            out displacement : DisplacementField;
        }

        exhibit state def MotionTrackerBehavior {
            entry;
            attribute previousFrame : BeamformedFrame;
            state WaitingForFrame;
            state Tracking {
                do { trackSpeckles(frameIn.frame, previousFrame); }
            }
            transition from WaitingForFrame to Tracking when frameIn.frame?received;
            transition from Tracking to WaitingForFrame when displacementOut.displacement?sent;
        }
    }

    part def VelocityEstimator {
        port displacementIn : DisplacementInPort;
        port velocityOut : VelocityOutPort;
        port controlIn : ControlInPort;

        attribute frameInterval : TimeUnit = 0.020;
        attribute smoothingFactor : Real = 0.5;

        action def EstimateVelocity {
            in displacement : DisplacementField;
            out velocity : VelocityField;
        }

        exhibit state def VelocityEstimatorBehavior {
            entry;
            state Waiting;
            state Estimating {
                do { estimateVelocity(displacementIn.displacement); }
            }
            transition from Waiting to Estimating when displacementIn.displacement?received;
            transition from Estimating to Waiting when velocityOut.velocity?sent;
        }
    }

    part def StrainRateProcessor {
        port velocityIn : VelocityInPort;
        port strainRateOut : StrainRateOutPort;
        port controlIn : ControlInPort;

        attribute spatialResolution : DisplacementUnit = 2;
        attribute regionCount : Integer = 18;
        attribute gradientMethod : String = "CentralDifference";

        action def ComputeSpatialGradient {
            in velocity : VelocityField;
            out strainRate : StrainRateMap;
        }

        exhibit state def StrainRateProcessorBehavior {
            entry;
            state Waiting;
            state Computing {
                do { computeSpatialGradient(velocityIn.velocity); }
            }
            transition from Waiting to Computing when velocityIn.velocity?received;
            transition from Computing to Waiting when strainRateOut.strainRate?sent;
        }
    }

    part def ImageRenderer {
        port strainRateIn : StrainRateInPort;
        port frameIn : FrameInPort;
        port imageOut : ImageOutPort;
        port controlIn : ControlInPort;

        attribute colorMap : String = "BipolarRedBlue";
        attribute overlayOpacity : Real = 0.6;
        attribute displayWidth : PixelUnit = 1024;
        attribute displayHeight : PixelUnit = 768;

        action def RenderOverlay {
            in strainRate : StrainRateMap;
            in frame : BeamformedFrame;
            out image : RenderedImage;
        }

        exhibit state def ImageRendererBehavior {
            entry;
            state Waiting;
            state Rendering {
                do { renderOverlay(strainRateIn.strainRate, frameIn.frame); }
            }
            transition from Waiting to Rendering when strainRateIn.strainRate?received;
            transition from Rendering to Waiting when imageOut.image?sent;
        }
    }

    part def Display {
        port imageIn : ImageInPort;
        port controlIn : ControlInPort;

        attribute screenWidth : PixelUnit = 1920;
        attribute screenHeight : PixelUnit = 1080;
        attribute refreshRate : FrameRateUnit = 60;

        action def ShowImage {
            in image : RenderedImage;
        }

        exhibit state def DisplayBehavior {
            entry;
            state Blank;
            state Displaying {
                do { showImage(imageIn.image); }
            }
            transition from Blank to Displaying when imageIn.image?received;
            transition from Displaying to Displaying when imageIn.image?received;
        }
    }

    part def SystemController {
        port controlOut : ControlOutPort;
        port controlIn : ControlInPort;
        port calibrationOut : CalibrationOutPort;

        attribute defaultFrameRate : FrameRateUnit = 60;
        attribute defaultScanDepth : DisplacementUnit = 160;
        attribute defaultScanWidth : DisplacementUnit = 120;
        attribute defaultFocusDepth : DisplacementUnit = 80;
        attribute defaultAcousticOutput : AcousticPressureUnit = 1.2;
        attribute currentParameters : ImagingParameters;
        attribute calibrationCompleted : Boolean = false;

        action def GenerateParameters {
            out params : ImagingParameters;
        }
        action def RunCalibration {
            out calibration : CalibrationData;
        }

        exhibit state def ControllerBehavior {
            entry;
            state PoweredOff;
            state Initializing {
                do { generateParameters(); }
            }
            state Calibrating {
                do { runCalibration(); }
            }
            state Imaging {
                do { generateParameters(); }
            }
            state Fault {
                do { logFault(); }
            }
            transition from PoweredOff to Initializing when powerOn;
            transition from Initializing to Calibrating when initializationComplete;
            transition from Calibrating to Imaging when calibrationOut.calibration?sent;
            transition from Imaging to Fault when faultDetected;
            transition from Fault to Initializing when resetCommand;
            transition from Imaging to PoweredOff when powerOff;
        }
    }

    // ===== Top-Level System =====
    part def StrainRateImagingSystem {
        port controlIn : ControlInPort;
        port imageOut : ImageOutPort;

        attribute measuredFrameRate : FrameRateUnit;
        attribute processingLatency : TimeUnit;
        attribute mechanicalIndex : MechanicalIndexUnit;
        attribute thermalIndex : Real;
        attribute spatialResolution : DisplacementUnit;
        attribute invasive : Boolean = false;
        attribute calibrationCompleted : Boolean;

        part transducer : Transducer;
        part beamformer : Beamformer;
        part motionTracker : MotionTracker;
        part velocityEstimator : VelocityEstimator;
        part strainRateProcessor : StrainRateProcessor;
        part imageRenderer : ImageRenderer;
        part display : Display;
        part controller : SystemController;

        // Acoustic path: controller -> transducer -> beamformer
        connection controller.controlOut to transducer.controlIn;
        connection transducer.echoOut to beamformer.echoIn;

        // Image frame path: beamformer -> motionTracker and imageRenderer
        connection beamformer.frameOut to motionTracker.frameIn;
        connection beamformer.frameOut to imageRenderer.frameIn;

        // Displacement path: motionTracker -> velocityEstimator
        connection motionTracker.displacementOut to velocityEstimator.displacementIn;

        // Velocity path: velocityEstimator -> strainRateProcessor
        connection velocityEstimator.velocityOut to strainRateProcessor.velocityIn;

        // Strain rate path: strainRateProcessor -> imageRenderer
        connection strainRateProcessor.strainRateOut to imageRenderer.strainRateIn;

        // Rendered image path: imageRenderer -> display
        connection imageRenderer.imageOut to display.imageIn;

        // Controller connections to all subsystems
        connection controller.controlOut to beamformer.controlIn;
        connection controller.controlOut to motionTracker.controlIn;
        connection controller.controlOut to velocityEstimator.controlIn;
        connection controller.controlOut to strainRateProcessor.controlIn;
        connection controller.controlOut to imageRenderer.controlIn;
        connection controller.controlOut to display.controlIn;

        // External image output
        connection display.imageIn to imageOut;

        // Requirements satisfaction
        satisfy HighFrameRateRequirement by system;
        satisfy AcousticSafetyRequirement by system;
        satisfy RealTimeProcessingRequirement by system;
        satisfy NonInvasiveAssessmentRequirement by system;
        satisfy RegionalStrainAccuracyRequirement by system;
        satisfy CalibrationRequirement by system;

        exhibit state def SystemStateMachine {
            entry;
            state Off;
            state PowerOn {
                entry;
            }
            state Calibration {
                do { controller.runCalibration(); }
            }
            state ImagingLoop {
                do {
                    transducer.transmitPulses(transducer.currentParameters);
                    beamformer.focusAndConstruct(beamformer.echoIn.echo);
                    motionTracker.trackSpeckles(motionTracker.frameIn.frame, motionTracker.previousFrame);
                    velocityEstimator.estimateVelocity(velocityEstimator.displacementIn.displacement);
                    strainRateProcessor.computeSpatialGradient(strainRateProcessor.velocityIn.velocity);
                    imageRenderer.renderOverlay(imageRenderer.strainRateIn.strainRate, imageRenderer.frameIn.frame);
                    display.showImage(display.imageIn.image);
                }
            }
            state Shutdown;
            transition from Off to PowerOn when powerOn;
            transition from PowerOn to Calibration when initializationComplete;
            transition from Calibration to ImagingLoop when calibrationCompleted == true;
            transition from ImagingLoop to ImagingLoop when frameComplete;
            transition from ImagingLoop to Shutdown when powerOff;
            transition from Shutdown to Off when shutdownComplete;
        }
    }
}
