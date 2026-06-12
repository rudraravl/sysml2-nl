package OmniviewTechnologySystem {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Percentage : Real {
        unit = "%";
        range = 0.0 .. 100.0;
    }

    attribute def Degrees : Real {
        unit = "deg";
    }

    attribute def FramesPerSecond : Real {
        unit = "Hz";
    }

    attribute def Meters : Real {
        unit = "m";
    }

    attribute def Milliseconds : Real {
        unit = "ms";
    }

    attribute def Watts : Real {
        unit = "W";
    }

    attribute def Pixels : Integer;

    attribute def ConfidenceScore : Real {
        range = 0.0 .. 1.0;
    }

    item def PhotonStream {
        attribute spectralBand : String;
        attribute intensity : Real;
        attribute arrivalAngle : Degrees;
    }

    item def RawFrame {
        attribute frameId : Integer;
        attribute width : Pixels;
        attribute height : Pixels;
        attribute timestampMs : Milliseconds;
        attribute exposureMs : Milliseconds;
    }

    item def CalibratedFrame {
        attribute frameId : Integer;
        attribute opticalCenterX : Pixels;
        attribute opticalCenterY : Pixels;
        attribute lensDistortionCorrected : Boolean;
        attribute timestampMs : Milliseconds;
    }

    item def PanoramicScene {
        attribute horizontalCoverage : Degrees;
        attribute verticalCoverage : Degrees;
        attribute resolutionWidth : Pixels;
        attribute resolutionHeight : Pixels;
        attribute latencyMs : Milliseconds;
        attribute confidence : ConfidenceScore;
    }

    item def ObjectTrack {
        attribute trackId : Integer;
        attribute classification : String;
        attribute bearing : Degrees;
        attribute elevation : Degrees;
        attribute rangeEstimate : Meters;
        attribute confidence : ConfidenceScore;
    }

    item def OperatorCommand {
        attribute commandId : Integer;
        attribute commandType : String;
        attribute requestedZoom : Real;
        attribute requestedBearing : Degrees;
    }

    item def HealthReport {
        attribute temperatureNominal : Boolean;
        attribute sensorsOnline : Integer;
        attribute processorLoad : Percentage;
        attribute degradedMode : Boolean;
    }

    port def OpticalInputPort {
        in item photons : PhotonStream;
    }

    port def FramePort {
        out item rawFrame : RawFrame;
    }

    port def CalibratedFramePort {
        in item inputFrame : RawFrame;
        out item outputFrame : CalibratedFrame;
    }

    port def ScenePort {
        out item scene : PanoramicScene;
    }

    port def TrackPort {
        out item track : ObjectTrack;
    }

    port def CommandPort {
        in item command : OperatorCommand;
    }

    port def DisplayPort {
        in item scene : PanoramicScene;
        in item track : ObjectTrack;
    }

    port def HealthPort {
        out item health : HealthReport;
    }

    action def CaptureImage {
        in item incomingLight : PhotonStream;
        out item frame : RawFrame;
    }

    action def CalibrateImage {
        in item frame : RawFrame;
        out item calibrated : CalibratedFrame;
    }

    action def FuseViews {
        in item front : CalibratedFrame;
        in item rear : CalibratedFrame;
        in item left : CalibratedFrame;
        in item right : CalibratedFrame;
        out item scene : PanoramicScene;
    }

    action def DetectAndTrackObjects {
        in item scene : PanoramicScene;
        out item track : ObjectTrack;
    }

    action def RenderOmniview {
        in item scene : PanoramicScene;
        in item track : ObjectTrack;
    }

    action def RunHealthMonitoring {
        out item health : HealthReport;
    }

    part def WideAngleCamera {
        attribute fieldOfViewHorizontal : Degrees = 190.0;
        attribute fieldOfViewVertical : Degrees = 120.0;
        attribute frameRate : FramesPerSecond = 60.0;
        attribute resolutionWidth : Pixels = 3840;
        attribute resolutionHeight : Pixels = 2160;
        attribute powerDraw : Watts = 8.0;

        port opticalIn : OpticalInputPort;
        port frameOut : FramePort;

        perform action capture : CaptureImage {
            in incomingLight = opticalIn.photons;
            out frame = frameOut.rawFrame;
        }
    }

    part def ImageCalibrationUnit {
        attribute maxCalibrationLatency : Milliseconds = 8.0;

        port frameInOut : CalibratedFramePort;

        perform action calibrate : CalibrateImage {
            in frame = frameInOut.inputFrame;
            out calibrated = frameInOut.outputFrame;
        }
    }

    part def OmniviewFusionProcessor {
        attribute processorPowerDraw : Watts = 65.0;
        attribute targetFusionLatency : Milliseconds = 25.0;
        attribute panoramicHorizontalCoverage : Degrees = 360.0;
        attribute panoramicVerticalCoverage : Degrees = 180.0;
        attribute minimumSceneConfidence : ConfidenceScore = 0.90;

        port frontIn : CalibratedFramePort;
        port rearIn : CalibratedFramePort;
        port leftIn : CalibratedFramePort;
        port rightIn : CalibratedFramePort;
        port sceneOut : ScenePort;
        port trackOut : TrackPort;
        port healthOut : HealthPort;

        perform action fuse : FuseViews {
            in front = frontIn.outputFrame;
            in rear = rearIn.outputFrame;
            in left = leftIn.outputFrame;
            in right = rightIn.outputFrame;
            out scene = sceneOut.scene;
        }

        perform action detect : DetectAndTrackObjects {
            in scene = sceneOut.scene;
            out track = trackOut.track;
        }

        perform action monitor : RunHealthMonitoring {
            out health = healthOut.health;
        }
    }

    part def OperatorDisplay {
        attribute displayWidth : Pixels = 5120;
        attribute displayHeight : Pixels = 1440;
        attribute refreshRate : FramesPerSecond = 60.0;
        attribute displayLatencyBudget : Milliseconds = 16.0;

        port visualizationIn : DisplayPort;
        port commandIn : CommandPort;

        perform action render : RenderOmniview {
            in scene = visualizationIn.scene;
            in track = visualizationIn.track;
        }
    }

    part def PowerController {
        attribute nominalVoltage : Real = 28.0;
        attribute maximumSystemPower : Watts = 180.0;
        attribute availablePower : Watts = 160.0;
    }

    part def OmniviewSystem {
        attribute primaryFunction : String = "Provide a fused real-time 360-degree panoramic view of the surrounding environment for situational awareness, navigation support, and object detection.";
        attribute endToEndLatencyBudget : Milliseconds = 75.0;
        attribute requiredHorizontalCoverage : Degrees = 360.0;
        attribute requiredVerticalCoverage : Degrees = 160.0;
        attribute operationalRange : Meters = 250.0;
        attribute systemAvailability : Percentage = 99.5;

        part frontCamera : WideAngleCamera;
        part rearCamera : WideAngleCamera;
        part leftCamera : WideAngleCamera;
        part rightCamera : WideAngleCamera;

        part frontCalibration : ImageCalibrationUnit;
        part rearCalibration : ImageCalibrationUnit;
        part leftCalibration : ImageCalibrationUnit;
        part rightCalibration : ImageCalibrationUnit;

        part fusionProcessor : OmniviewFusionProcessor;
        part operatorDisplay : OperatorDisplay;
        part powerController : PowerController;

        port frontOptics : OpticalInputPort;
        port rearOptics : OpticalInputPort;
        port leftOptics : OpticalInputPort;
        port rightOptics : OpticalInputPort;
        port operatorCommands : CommandPort;
        port displayedScene : DisplayPort;
        port systemHealth : HealthPort;

        connect frontOptics to frontCamera.opticalIn;
        connect rearOptics to rearCamera.opticalIn;
        connect leftOptics to leftCamera.opticalIn;
        connect rightOptics to rightCamera.opticalIn;

        connect frontCamera.frameOut.rawFrame to frontCalibration.frameInOut.inputFrame;
        connect rearCamera.frameOut.rawFrame to rearCalibration.frameInOut.inputFrame;
        connect leftCamera.frameOut.rawFrame to leftCalibration.frameInOut.inputFrame;
        connect rightCamera.frameOut.rawFrame to rightCalibration.frameInOut.inputFrame;

        connect frontCalibration.frameInOut.outputFrame to fusionProcessor.frontIn.outputFrame;
        connect rearCalibration.frameInOut.outputFrame to fusionProcessor.rearIn.outputFrame;
        connect leftCalibration.frameInOut.outputFrame to fusionProcessor.leftIn.outputFrame;
        connect rightCalibration.frameInOut.outputFrame to fusionProcessor.rightIn.outputFrame;

        connect fusionProcessor.sceneOut.scene to operatorDisplay.visualizationIn.scene;
        connect fusionProcessor.trackOut.track to operatorDisplay.visualizationIn.track;
        connect operatorCommands to operatorDisplay.commandIn;
        connect operatorDisplay.visualizationIn to displayedScene;
        connect fusionProcessor.healthOut to systemHealth;

        state def OmniviewOperationalStateMachine {
            state off;
            state initializing;
            state calibrating;
            state operating;
            state degraded;
            state faulted;
            state shutdown;

            initial then off;

            transition powerOn first off then initializing;
            transition initializationComplete first initializing then calibrating;
            transition calibrationComplete first calibrating then operating;
            transition sensorLoss first operating then degraded;
            transition sensorRecovered first degraded then operating;
            transition criticalFault first operating then faulted;
            transition degradedCriticalFault first degraded then faulted;
            transition resetFault first faulted then initializing;
            transition powerDownFromOperating first operating then shutdown;
            transition powerDownFromDegraded first degraded then shutdown;
            transition shutdownComplete first shutdown then off;

            entry action initializing {
                perform fusionProcessor.monitor;
            }

            entry action calibrating {
                perform frontCalibration.calibrate;
                perform rearCalibration.calibrate;
                perform leftCalibration.calibrate;
                perform rightCalibration.calibrate;
            }

            do action operating {
                perform frontCamera.capture;
                perform rearCamera.capture;
                perform leftCamera.capture;
                perform rightCamera.capture;
                perform fusionProcessor.fuse;
                perform fusionProcessor.detect;
                perform operatorDisplay.render;
                perform fusionProcessor.monitor;
            }

            do action degraded {
                perform fusionProcessor.fuse;
                perform fusionProcessor.detect;
                perform operatorDisplay.render;
                perform fusionProcessor.monitor;
            }
        }
    }

    requirement def HighLevelPrimaryFunctionRequirement {
        subject system : OmniviewSystem;
        require constraint {
            system.requiredHorizontalCoverage >= 360.0 and
            system.requiredVerticalCoverage >= 160.0 and
            system.endToEndLatencyBudget <= 75.0
        }
    }

    requirement def RealTimeFusionRequirement {
        subject processor : OmniviewFusionProcessor;
        require constraint {
            processor.targetFusionLatency <= 25.0 and
            processor.minimumSceneConfidence >= 0.90
        }
    }

    requirement def CameraCoverageRequirement {
        subject camera : WideAngleCamera;
        require constraint {
            camera.fieldOfViewHorizontal >= 180.0 and
            camera.frameRate >= 60.0 and
            camera.resolutionWidth >= 3840 and
            camera.resolutionHeight >= 2160
        }
    }

    requirement def DisplayResponsivenessRequirement {
        subject display : OperatorDisplay;
        require constraint {
            display.refreshRate >= 60.0 and
            display.displayLatencyBudget <= 16.0
        }
    }

    requirement def PowerBudgetRequirement {
        subject system : OmniviewSystem;
        require constraint {
            system.powerController.availablePower <= system.powerController.maximumSystemPower
        }
    }

    requirement def HealthMonitoringRequirement {
        subject system : OmniviewSystem;
        require constraint {
            system.systemAvailability >= 99.5
        }
    }

    satisfy HighLevelPrimaryFunctionRequirement by OmniviewSystem;
    satisfy RealTimeFusionRequirement by OmniviewFusionProcessor;
    satisfy CameraCoverageRequirement by WideAngleCamera;
    satisfy DisplayResponsivenessRequirement by OperatorDisplay;
    satisfy PowerBudgetRequirement by OmniviewSystem;
    satisfy HealthMonitoringRequirement by OmniviewSystem;

    part omniviewTechnologySystem : OmniviewSystem;
}