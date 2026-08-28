package StrainRateImaging {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;
    private import SequenceFunctions::*;

    item def EchoSignal {
        attribute amplitude : Real;
        attribute timeOfFlight : TimeValue;
        attribute centerFrequency : FrequencyValue;
    }

    item def UltrasoundImage {
        attribute frameId : Integer;
        attribute timestamp : TimeValue;
        attribute width : LengthValue;
        attribute height : LengthValue;
        attribute brightness : Real;
    }

    item def DisplacementData {
        attribute dx : LengthValue;
        attribute dy : LengthValue;
        attribute frameId : Integer;
    }

    item def VelocityData {
        attribute vx : SpeedValue;
        attribute vy : SpeedValue;
        attribute frameId : Integer;
    }

    item def StrainRateData {
        attribute strainRate : FrequencyValue;
        attribute xCoord : LengthValue;
        attribute yCoord : LengthValue;
        attribute frameId : Integer;
    }

    item def DisplayImage {
        item baseImage : UltrasoundImage;
        item overlay : StrainRateData;
    }

    item def ControlCommand {
        attribute frameRate : FrequencyValue;
        attribute scanDepth : LengthValue;
        attribute acousticPower : PowerValue;
    }

    item def SystemStatus {
        attribute calibrationComplete : Boolean;
        attribute currentFrameRate : FrequencyValue;
        attribute errorCode : Integer;
    }

    attribute def StartSignal;
    attribute def StopSignal;
    attribute def CalibrationCompleteSignal;

    port def EchoOutPort { out item echo : EchoSignal; }
    port def EchoInPort { in item echo : EchoSignal; }
    port def ImageOutPort { out item image : UltrasoundImage; }
    port def ImageInPort { in item image : UltrasoundImage; }
    port def DispOutPort { out item disp : DisplacementData; }
    port def DispInPort { in item disp : DisplacementData; }
    port def VelOutPort { out item vel : VelocityData; }
    port def VelInPort { in item vel : VelocityData; }
    port def SROutPort { out item sr : StrainRateData; }
    port def SRInPort { in item sr : StrainRateData; }
    port def DisplayOutPort { out item img : DisplayImage; }
    port def DisplayInPort { in item img : DisplayImage; }
    port def ControlOutPort { out item cmd : ControlCommand; }
    port def ControlInPort { in item cmd : ControlCommand; }
    port def StatusOutPort { out item status : SystemStatus; }
    port def StatusInPort { in item status : SystemStatus; }

    calc def SpatialGradient {
        in v1 : SpeedValue;
        in v2 : SpeedValue;
        in dx : LengthValue;
        return : FrequencyValue = (v2 - v1) / dx;
    }

    action def AcquireFrameAction {
        in frameRate : FrequencyValue;
        in acousticPower : PowerValue;
        out echo : EchoSignal;
    }

    action def BeamformAction {
        in echo : EchoSignal;
        out image : UltrasoundImage;
    }

    action def TrackSpecklesAction {
        in currentImage : UltrasoundImage;
        in previousImage : UltrasoundImage;
        out disp : DisplacementData;
    }

    action def EstimateVelocityAction {
        in disp : DisplacementData;
        in dt : TimeValue;
        out vel : VelocityData;
    }

    action def ComputeStrainRateAction {
        in vel : VelocityData;
        out sr : StrainRateData;
    }

    action def RenderImageAction {
        in base : UltrasoundImage;
        in sr : StrainRateData;
        out img : DisplayImage;
    }

    action def CalibrateAction {
        out status : SystemStatus;
    }

    action def ProcessFrameAction {
        in attribute frameRate : FrequencyValue;
        in attribute acousticPower : PowerValue;
        in attribute dt : TimeValue;
        out item img : DisplayImage;

        perform action acquire : AcquireFrameAction {
            in frameRate = frameRate;
            in acousticPower = acousticPower;
            out echo;
        }
        then perform action beamform : BeamformAction {
            in echo = acquire.echo;
            out image;
        }
        then perform action track : TrackSpecklesAction {
            in currentImage = beamform.image;
            in previousImage = beamform.image;
            out disp;
        }
        then perform action estimate : EstimateVelocityAction {
            in disp = track.disp;
            in dt = dt;
            out vel;
        }
        then perform action compute : ComputeStrainRateAction {
            in vel = estimate.vel;
            out sr;
        }
        then perform action renderImg : RenderImageAction {
            in base = beamform.image;
            in sr = compute.sr;
            out img;
        }
        then assign img := renderImg.img;
    }

    action def ImagingLoopAction {
        in attribute frameRate : FrequencyValue;
        in attribute acousticPower : PowerValue;
        in attribute scanDepth : LengthValue;
        in attribute dt : TimeValue;
        out item img : DisplayImage;
        private attribute frameCount := 100;

        for i in 1..frameCount {
            perform action process : ProcessFrameAction {
                in frameRate = frameRate;
                in acousticPower = acousticPower;
                in dt = dt;
                out img;
            }
            then assign img := process.img;
        }
    }

    part def Transducer {
        in port controlIn : ControlInPort;
        out port echoOut : EchoOutPort;
        out port statusOut : StatusOutPort;
        attribute centerFrequency : FrequencyValue = 2500000 [Hz];
        attribute elementCount : Integer = 128;
        attribute maxAcousticPower : PowerValue = 0.1 [W];
    }

    part def Beamformer {
        in port echoIn : EchoInPort;
        in port controlIn : ControlInPort;
        out port imageOut : ImageOutPort;
    }

    part def MotionTracker {
        in port imageIn : ImageInPort;
        out port dispOut : DispOutPort;
    }

    part def VelocityEstimator {
        in port dispIn : DispInPort;
        out port velOut : VelOutPort;
        attribute deltaTime : TimeValue = 0.02 [s];
    }

    part def StrainRateProcessor {
        in port velIn : VelInPort;
        out port srOut : SROutPort;
    }

    part def ImageRenderer {
        in port baseImageIn : ImageInPort;
        in port srIn : SRInPort;
        out port displayOut : DisplayOutPort;
    }

    part def Display {
        in port displayIn : DisplayInPort;
        attribute resolution : Integer[2];
    }

    state def ControllerStateMachine {
        attribute frameRate : FrequencyValue = 50 [Hz];
        attribute acousticPower : PowerValue = 0.05 [W];
        attribute scanDepth : LengthValue = 0.15 [m];
        attribute dt : TimeValue = 0.02 [s];

        entry; then Idle;

        state Idle {
            do action standby;
        }
        transition first Idle accept StartSignal then Calibrating;

        state Calibrating {
            do action calibrate : CalibrateAction;
        }
        transition first Calibrating accept CalibrationCompleteSignal then Imaging;

        state Imaging {
            do action imaging : ImagingLoopAction {
                in frameRate = frameRate;
                in acousticPower = acousticPower;
                in scanDepth = scanDepth;
                in dt = dt;
            }
        }
        transition first Imaging accept StopSignal then Idle;

        exit action shutdown;
    }

    part def SystemController {
        in port statusIn : StatusInPort;
        in port operatorCmd : ControlInPort;
        out port controlOut : ControlOutPort;
        attribute frameRate : FrequencyValue = 50 [Hz];
        attribute scanDepth : LengthValue = 0.15 [m];
        attribute acousticPower : PowerValue = 0.05 [W];
    }

    part def StrainRateImagingSystem {
        part transducer : Transducer;
        part beamformer : Beamformer;
        part motionTracker : MotionTracker;
        part velocityEstimator : VelocityEstimator;
        part strainRateProc : StrainRateProcessor;
        part imageRenderer : ImageRenderer;
        part display : Display;
        part controller : SystemController;

        connect controller.controlOut to transducer.controlIn;
        connect controller.controlOut to beamformer.controlIn;
        connect transducer.echoOut to beamformer.echoIn;
        connect beamformer.imageOut to motionTracker.imageIn;
        connect beamformer.imageOut to imageRenderer.baseImageIn;
        connect motionTracker.dispOut to velocityEstimator.dispIn;
        connect velocityEstimator.velOut to strainRateProc.velIn;
        connect strainRateProc.srOut to imageRenderer.srIn;
        connect imageRenderer.displayOut to display.displayIn;
        connect transducer.statusOut to controller.statusIn;
    }

    requirement def HighFrameRateRequirement {
        attribute minimumFrameRate : FrequencyValue = 50 [Hz];
    }

    requirement def AcousticSafetyRequirement {
        attribute maximumMechanicalIndex : Real = 1.9;
        attribute maximumThermalIndex : Real = 6.0;
        attribute maximumAcousticPower : PowerValue = 0.1 [W];
    }

    requirement def RealTimeDisplayRequirement {
        attribute maximumLatency : TimeValue = 0.05 [s];
    }

    requirement highFrameRate : HighFrameRateRequirement;
    requirement acousticSafety : AcousticSafetyRequirement;
    requirement realTimeDisplay : RealTimeDisplayRequirement;

    part imagingSystem : StrainRateImagingSystem {
        satisfy highFrameRate;
        satisfy acousticSafety;
        satisfy realTimeDisplay;
    }
}
