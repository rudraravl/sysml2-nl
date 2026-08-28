package TissueDopplerEchocardiography {
    import ScalarValues::*;

    value def Velocity :> Real { unit = "m/s"; }
    value def Frequency :> Real { unit = "Hz"; }
    value def Depth :> Real { unit = "m"; }
    value def Gain :> Real { unit = "dB"; }
    value def AcousticPressure :> Real { unit = "Pa"; }
    value def Angle :> Real { unit = "rad"; }
    value def Power :> Real { unit = "W"; }
    value def Duration :> Real { unit = "s"; }
    value def FrameRate :> Real { unit = "Hz"; }

    enum def OperatingMode { standby; imaging; frozen; review; }
    enum def FlowDirection { toward; away; stationary; }

    item def UltrasoundPulse {
        attribute centerFrequency : Frequency;
        attribute pulseDuration : Duration;
        attribute acousticAmplitude : AcousticPressure;
        attribute focalDepth : Depth;
        attribute steeringAngle : Angle;
    }

    item def EchoSignal {
        attribute amplitude : AcousticPressure;
        attribute carrierFrequency : Frequency;
        attribute depthOfOrigin : Depth;
        attribute timeOfFlight : Duration;
    }

    item def BeamformedSignal {
        attribute amplitude : AcousticPressure;
        attribute carrierFrequency : Frequency;
        attribute targetDepth : Depth;
    }

    item def ProcessedEchoSignal {
        attribute amplitude : AcousticPressure;
        attribute carrierFrequency : Frequency;
        attribute depthOfOrigin : Depth;
        attribute gainApplied : Gain;
    }

    item def DopplerShiftData {
        attribute frequencyShift : Frequency;
        attribute depth : Depth;
        attribute lateralPosition : Real;
    }

    item def VelocityData {
        attribute tissueVelocity : Velocity;
        attribute depth : Depth;
        attribute lateralPosition : Real;
        attribute direction : FlowDirection;
    }

    item def ColorPixel {
        attribute red : Integer;
        attribute green : Integer;
        attribute blue : Integer;
        attribute x : Integer;
        attribute y : Integer;
    }

    item def ColorImage {
        attribute pixels : ColorPixel[0..*];
        attribute frameRate : FrameRate;
        attribute timestamp : Duration;
    }

    item def ControlCommand {
        attribute targetMode : OperatingMode;
        attribute focalDepthSetting : Depth;
        attribute gainSetting : Gain;
        attribute wallFilterCutoff : Frequency;
        attribute steeringAngleSetting : Angle;
    }

    part def TransducerArray {
        attribute numElements : Integer = 128;
        attribute elementPitch : Real = 0.0003;
        attribute centerFrequency : Frequency = 4000000.0;

        port pulseInPort : UltrasoundPulse;
        port pulseOutPort : UltrasoundPulse;
        port echoInPort : EchoSignal;
        port echoOutPort : EchoSignal;

        action transmitPulse {
            in pulse : UltrasoundPulse;
            doc "Converts electrical excitation into acoustic ultrasound pulse directed into patient chest wall.";
        }

        action receiveEcho {
            out echo : EchoSignal;
            doc "Converts returning acoustic echoes from moving myocardium into electrical signal.";
        }
    }

    part def BeamformingUnit {
        attribute maxFocalDepth : Depth = 0.20;
        attribute numChannels : Integer = 128;
        attribute apertureSize : Real = 0.0384;

        port controlInPort : ControlCommand;
        port pulseOutPort : UltrasoundPulse;
        port echoInPort : EchoSignal;
        port beamformedOutPort : BeamformedSignal;

        action steerAndFocus {
            in focalDepth : Depth;
            in steeringAngle : Angle;
            out pulse : UltrasoundPulse;
            doc "Electronically delays excitation of individual transducer elements to steer and focus the ultrasound beam to a specific depth and location within the heart.";
        }

        action combineEchoes {
            in echoes : EchoSignal[0..*];
            out beamformed : BeamformedSignal;
            doc "Applies receive focusing delays to combine echoes from multiple transducer elements into a coherent high-quality signal from the target region.";
        }
    }

    part def SignalProcessor {
        attribute gain : Gain = 30.0;
        attribute bandwidth : Frequency = 2000000.0;
        attribute noiseFigure : Real = 2.0;

        port beamformedInPort : BeamformedSignal;
        port processedOutPort : ProcessedEchoSignal;

        action amplify {
            in signal : BeamformedSignal;
            out amplified : ProcessedEchoSignal;
            doc "Amplifies weak echo signals from deep tissue to usable voltage levels.";
        }

        action filter {
            in signal : ProcessedEchoSignal;
            out filtered : ProcessedEchoSignal;
            doc "Applies bandpass filter centered on the carrier frequency to remove out-of-band noise and clutter.";
        }

        action depthCompensate {
            in signal : ProcessedEchoSignal;
            out compensated : ProcessedEchoSignal;
            doc "Applies time-gain compensation to boost deeper tissue echoes that have attenuated more during round-trip propagation.";
        }
    }

    part def DopplerAnalyzer {
        attribute wallFilterCutoff : Frequency = 0.5;
        attribute carrierFrequency : Frequency = 4000000.0;
        attribute speedOfSound : Velocity = 1540.0;
        attribute prf : Frequency = 5000.0;

        port processedInPort : ProcessedEchoSignal;
        port velocityOutPort : VelocityData;

        action computeDopplerShift {
            in signal : ProcessedEchoSignal;
            out shift : DopplerShiftData;
            doc "Calculates the frequency difference between the transmitted carrier and the received echo caused by myocardial tissue motion using quadrature demodulation.";
        }

        action applyWallFilter {
            in shift : DopplerShiftData;
            out filtered : DopplerShiftData;
            doc "Rejects low-frequency Doppler shifts corresponding to large slow movements of the entire heart wall, isolating the more subtle contraction velocities of the myocardium itself.";
        }

        action computeVelocity {
            in shift : DopplerShiftData;
            out velocity : VelocityData;
            doc "Converts the Doppler frequency shift to tissue velocity using the Doppler equation v = (fd * c) / (2 * f0 * cos(theta)).";
        }
    }

    part def ImageGenerator {
        attribute frameRate : FrameRate = 30.0;
        attribute colorScaleMax : Velocity = 0.30;
        attribute colorScaleMin : Velocity = -0.30;

        port velocityInPort : VelocityData;
        port imageOutPort : ColorImage;

        action mapVelocityToColor {
            in velocity : VelocityData;
            out pixel : ColorPixel;
            doc "Maps tissue velocity magnitude and direction to a color: red shades for movement toward the probe, blue shades for movement away, green for near-zero velocity.";
        }

        action composeFrame {
            in pixels : ColorPixel[0..*];
            out image : ColorImage;
            doc "Assembles the full set of color-coded pixels into a complete image frame annotated with timestamp and frame rate metadata.";
        }
    }

    part def Display {
        attribute resolutionWidth : Integer = 1920;
        attribute resolutionHeight : Integer = 1080;
        attribute refreshRate : FrameRate = 60.0;
        attribute diagonalSize : Real = 0.559;

        port imageInPort : ColorImage;

        action renderFrame {
            in image : ColorImage;
            doc "Renders the color-coded velocity map on the high-resolution display for clinician interpretation.";
        }
    }

    part def SystemControllerAndDisplay {
        attribute currentMode : OperatingMode = OperatingMode::standby;
        attribute recordedFrames : ColorImage[0..*];
        attribute maxRecordedFrames : Integer = 600;

        port controlOutPort : ControlCommand;
        port imageInPort : ColorImage;

        part display : Display;

        connection delegateImageToDisplay
            connect imageInPort to display.imageInPort;

        action synchronize {
            out command : ControlCommand;
            doc "Generates synchronization commands to coordinate all subsystems during each imaging cycle, ensuring proper transmit-receive sequencing.";
        }

        action switchMode {
            in newMode : OperatingMode;
            doc "Transitions the system between standby, imaging, frozen, and review modes based on operator input.";
        }

        action recordFrame {
            in image : ColorImage;
            doc "Stores the current image frame in the recorded frames buffer for later review playback.";
        }

        action playbackRecorded {
            out image : ColorImage;
            doc "Retrieves and outputs previously recorded frames for clinician review.";
        }

        state ControllerStateMachine {
            entry; then standby;

            state standby {
                doc "System is powered on but not actively imaging; transducer is idle.";
            }

            transition standby_to_imaging
                first standby
                then imaging
                accept StartImaging;

            state imaging {
                doc "System is actively transmitting pulses, receiving echoes, processing Doppler shifts, computing velocities, and displaying the real-time color-coded map.";
            }

            transition imaging_to_frozen
                first imaging
                then frozen
                accept Freeze;

            transition imaging_to_standby
                first imaging
                then standby
                accept PowerDown;

            state frozen {
                doc "Imaging is halted; the current frame is held on the display for detailed measurement and analysis.";
            }

            transition frozen_to_imaging
                first frozen
                then imaging
                accept Resume;

            transition frozen_to_review
                first frozen
                then review
                accept EnterReview;

            state review {
                doc "Previously recorded imaging frames are played back on the display for retrospective analysis.";
            }

            transition review_to_imaging
                first review
                then imaging
                accept Resume;

            transition review_to_standby
                first review
                then standby
                accept PowerDown;
        }
    }

    part def TissueDopplerEchocardiographySystem {
        attribute systemId : String;
        attribute manufacturer : String = "CardioEcho Inc.";
        attribute modelNumber : String;
        attribute maxImagingDepth : Depth = 0.20;

        part transducer : TransducerArray;
        part beamformer : BeamformingUnit;
        part signalProcessor : SignalProcessor;
        part dopplerAnalyzer : DopplerAnalyzer;
        part imageGenerator : ImageGenerator;
        part controller : SystemControllerAndDisplay;

        connection controlToBeamformer
            connect controller.controlOutPort to beamformer.controlInPort;

        connection beamformerToTransducerTx
            connect beamformer.pulseOutPort to transducer.pulseInPort;

        connection transducerToBeamformerRx
            connect transducer.echoOutPort to beamformer.echoInPort;

        connection beamformerToProcessor
            connect beamformer.beamformedOutPort to signalProcessor.beamformedInPort;

        connection processorToAnalyzer
            connect signalProcessor.processedOutPort to dopplerAnalyzer.processedInPort;

        connection analyzerToImageGen
            connect dopplerAnalyzer.velocityOutPort to imageGenerator.velocityInPort;

        connection imageGenToController
            connect imageGenerator.imageOutPort to controller.imageInPort;

        action imagingCycle {
            doc "One complete cycle of pulse transmit, echo acquire, signal process, Doppler analyze, velocity compute, and image update.";

            action transmit {
                doc "Beamformer steers and focuses; transducer emits ultrasound pulse into chest.";
            }
            action acquire {
                doc "Transducer detects returning echoes; beamformer combines into coherent signal.";
            }
            action process {
                doc "Signal processor amplifies, filters, and applies time-gain compensation.";
            }
            action analyze {
                doc "Doppler analyzer computes frequency shift, applies wall filter, and calculates tissue velocity.";
            }
            action generate {
                doc "Image generator maps velocity to color and composes a complete image frame.";
            }
            action update {
                doc "Controller routes image to display for real-time rendering.";
            }

            succession seq1 first transmit then acquire;
            succession seq2 first acquire then process;
            succession seq3 first process then analyze;
            succession seq4 first analyze then generate;
            succession seq5 first generate then update;
        }
    }

    requirement def ShallMeasureTissueVelocity {
        subject system : TissueDopplerEchocardiographySystem;
        attribute requiredAccuracy : Velocity = 0.02;
        attribute measurementRange : Velocity = 0.30;
        objective {
            doc "The system shall measure myocardial tissue velocity with an accuracy of plus or minus 0.02 m/s over a range of plus or minus 0.30 m/s.";
        }
    }

    requirement def ShallProvideColorMap {
        subject system : TissueDopplerEchocardiographySystem;
        attribute minFrameRate : FrameRate = 30.0;
        objective {
            doc "The system shall display a real-time color-coded velocity map at a frame rate of at least 30 Hz, using red for motion toward the probe and blue for motion away.";
        }
    }

    requirement def ShallFilterWallMotion {
        subject system : TissueDopplerEchocardiographySystem;
        attribute wallFilterCutoff : Frequency = 0.5;
        objective {
            doc "The system shall apply a wall filter with a configurable cutoff to reject large slow movements of the entire heart, isolating the subtle contraction velocities of the myocardium.";
        }
    }

    requirement def ShallSupportOperatingModes {
        subject system : TissueDopplerEchocardiographySystem;
        objective {
            doc "The system shall support standby, imaging, frozen, and review operating modes with seamless transitions controlled by the operator.";
        }
    }

    requirement def ShallFocusUltrasound {
        subject system : TissueDopplerEchocardiographySystem;
        attribute maxDepth : Depth = 0.20;
        objective {
            doc "The beamforming unit shall electronically steer and focus the ultrasound beam to depths up to 0.20 m within the heart to target specific myocardial regions.";
        }
    }

    requirement def ShallNonInvasivelyAssess {
        subject system : TissueDopplerEchocardiographySystem;
        objective {
            doc "The system shall non-invasively assess cardiac function by transmitting ultrasound through the chest wall without ionizing radiation or invasive procedures.";
        }
    }

    requirement def ShallDepthCompensate {
        subject system : TissueDopplerEchocardiographySystem;
        objective {
            doc "The signal processor shall apply time-gain compensation to compensate for signal attenuation at deeper tissue depths, ensuring a clean signal for Doppler analysis.";
        }
    }

    requirement def ShallSynchronizeComponents {
        subject system : TissueDopplerEchocardiographySystem;
        objective {
            doc "The system controller shall synchronize the transducer, beamformer, signal processor, Doppler analyzer, and image generator to complete each imaging cycle within 33 milliseconds.";
        }
    }

    requirement def ShallRecordForReview {
        subject system : TissueDopplerEchocardiographySystem;
        attribute maxRecordedFrames : Integer = 600;
        objective {
            doc "The system shall record at least 600 image frames during active imaging for later playback in review mode.";
        }
    }
}
