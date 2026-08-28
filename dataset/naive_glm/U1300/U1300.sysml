package MarataVisionSystem {
    import ScalarValues::*;

    // ===== Units =====
    unit pixel;
    unit fps;
    unit ms;
    unit fstop;
    unit m;
    unit percent;
    unit frame;

    // ===== Value Types =====
    value type ResolutionWidth :> Integer { unit pixel; }
    value type ResolutionHeight :> Integer { unit pixel; }
    value type FrameRateValue :> Real { unit fps; }
    value type ExposureTime :> Real { unit ms; }
    value type ApertureSetting :> Real { unit fstop; }
    value type FocusDistanceValue :> Real { unit m; }
    value type LoadPercent :> Real { unit percent; }
    value type FrameCountValue :> Integer { unit frame; }
    value type StorageCapacityValue :> Integer { unit frame; }
    value type ProcessingLatencyValue :> Real { unit ms; }
    value type TimestampValue :> Real { unit ms; }

    // ===== Item Definitions =====
    item def RawFrame {
        attribute width : ResolutionWidth = 3840;
        attribute height : ResolutionHeight = 2160;
        attribute frameNumber : Integer;
        attribute timestamp : TimestampValue;
        attribute pixelData : String;
    }

    item def BoundingBox {
        attribute x : Integer;
        attribute y : Integer;
        attribute width : Integer;
        attribute height : Integer;
    }

    item def DetectedObject {
        attribute objectId : String;
        attribute objectClass : String;
        attribute boundingBox : BoundingBox;
        attribute confidence : Real;
        attribute trackingId : String;
    }

    item def MotionVector {
        attribute startX : Integer;
        attribute startY : Integer;
        attribute deltaX : Real;
        attribute deltaY : Real;
        attribute magnitude : Real;
    }

    item def ProcessedFrame {
        attribute frameNumber : Integer;
        attribute timestamp : TimestampValue;
        attribute edgeMapData : String;
        attribute colorCorrected : Boolean;
        attribute detectedObjects : DetectedObject[0..*];
        attribute motionVectors : MotionVector[0..*];
        attribute processingLatency : ProcessingLatencyValue;
    }

    item def DisplayFrame {
        attribute frameNumber : Integer;
        attribute width : ResolutionWidth = 3840;
        attribute height : ResolutionHeight = 2160;
        attribute overlayEnabled : Boolean;
        attribute annotatedObjects : DetectedObject[0..*];
        attribute pixelData : String;
    }

    item def ArchivedFrame {
        attribute frameNumber : Integer;
        attribute processedFrame : ProcessedFrame;
        attribute archiveTimestamp : TimestampValue;
    }

    item def CameraSettings {
        attribute exposure : ExposureTime = 16.0;
        attribute aperture : ApertureSetting = 2.8;
        attribute focus : FocusDistanceValue = 5.0;
        attribute targetFrameRate : FrameRateValue = 60.0;
    }

    item def ProcessingMode {
        attribute edgeDetectionEnabled : Boolean = true;
        attribute objectTrackingEnabled : Boolean = true;
        attribute motionVectorEnabled : Boolean = true;
        attribute colorCorrectionEnabled : Boolean = true;
    }

    item def SystemCommand {
        attribute commandId : String;
        attribute commandType : String;
        attribute targetFrameRate : FrameRateValue;
        attribute processingMode : ProcessingMode;
        attribute cameraSettings : CameraSettings;
    }

    item def StatusReport {
        attribute operationalState : String;
        attribute performanceLoad : LoadPercent;
        attribute errorCode : Integer;
        attribute errorMessage : String;
        attribute currentFrameRate : FrameRateValue;
    }

    // ===== Port Definitions =====
    port def RawVideoOutPort {
        out rawFrame : RawFrame;
    }

    port def RawVideoInPort {
        in rawFrame : RawFrame;
    }

    port def ProcessedVideoOutPort {
        out processedFrame : ProcessedFrame;
    }

    port def ProcessedVideoInPort {
        in processedFrame : ProcessedFrame;
    }

    port def DisplayOutPort {
        out displayFrame : DisplayFrame;
    }

    port def CommandInPort {
        in command : SystemCommand;
    }

    port def ControlOutPort {
        out cameraSettings : CameraSettings;
        out processingMode : ProcessingMode;
        out targetFrameRate : FrameRateValue;
    }

    port def ControlInPort {
        in cameraSettings : CameraSettings;
        in processingMode : ProcessingMode;
        in targetFrameRate : FrameRateValue;
    }

    port def StatusOutPort {
        out status : StatusReport;
    }

    port def StatusInPort {
        in status : StatusReport;
    }

    // ===== Action Definitions =====
    action def CaptureFrameAction {
        in settings : CameraSettings;
        out frame : RawFrame;
    }

    action def DetectEdgesAction {
        in raw : RawFrame;
        out edgeMapData : String;
    }

    action def TrackObjectsAction {
        in raw : RawFrame;
        in previousObjects : DetectedObject[0..*];
        out detectedObjects : DetectedObject[0..*];
    }

    action def CalculateMotionVectorsAction {
        in current : RawFrame;
        in previous : RawFrame;
        out motionVectors : MotionVector[0..*];
    }

    action def ApplyColorCorrectionAction {
        in raw : RawFrame;
        out correctedData : String;
    }

    action def AnalyzeFrameAction {
        in raw : RawFrame;
        in mode : ProcessingMode;
        in previousFrame : RawFrame;
        in previousObjects : DetectedObject[0..*];
        out processed : ProcessedFrame;
    }

    action def RenderFrameAction {
        in processed : ProcessedFrame;
        out display : DisplayFrame;
    }

    action def ArchiveFrameAction {
        in processed : ProcessedFrame;
        out archived : ArchivedFrame;
    }

    action def ProcessCommandAction {
        in command : SystemCommand;
        out cameraSettings : CameraSettings;
        out processingMode : ProcessingMode;
        out targetFrameRate : FrameRateValue;
    }

    action def GenerateStatusAction {
        in sensorStatus : StatusReport;
        in ipuStatus : StatusReport;
        in storageStatus : StatusReport;
        out aggregatedStatus : StatusReport;
    }

    // ===== Part Definitions =====
    part def OpticalSensor {
        attribute maxResolutionWidth : ResolutionWidth = 3840;
        attribute maxResolutionHeight : ResolutionHeight = 2160;
        attribute maxFrameRate : FrameRateValue = 120.0;
        attribute currentSettings : CameraSettings;
        attribute isCalibrated : Boolean = false;

        port rawVideoOut : RawVideoOutPort;
        port controlIn : ControlInPort;

        action capture : CaptureFrameAction;

        state sensorState {
            state idle;
            state active;
            state adjusting;
            transition first idle then active when currentSettings.targetFrameRate > 0;
            transition first active then adjusting when controlIn.cameraSettings.exposure != currentSettings.exposure;
            transition first adjusting then active when isCalibrated;
        }
    }

    part def ImageProcessingUnit {
        attribute processingLatency : ProcessingLatencyValue = 5.0;
        attribute currentMode : ProcessingMode;
        attribute currentLoad : LoadPercent = 0.0;
        attribute previousFrame : RawFrame;
        attribute previousObjects : DetectedObject[0..*];

        port videoIn : RawVideoInPort;
        port controlIn : ControlInPort;
        port processedVideoOut : ProcessedVideoOutPort;
        port statusOut : StatusOutPort;

        action analyze : AnalyzeFrameAction;

        action detectEdges : DetectEdgesAction;
        action trackObjects : TrackObjectsAction;
        action calculateMotionVectors : CalculateMotionVectorsAction;
        action applyColorCorrection : ApplyColorCorrectionAction;

        succession first detectEdges then trackObjects;
        succession first trackObjects then calculateMotionVectors;
        succession first calculateMotionVectors then applyColorCorrection;
    }

    part def SystemController {
        attribute currentTargetFrameRate : FrameRateValue = 60.0;
        attribute currentProcessingMode : ProcessingMode;
        attribute currentCameraSettings : CameraSettings;
        attribute systemStatus : StatusReport;

        port commandIn : CommandInPort;
        port controlOut : ControlOutPort;
        port statusOut : StatusOutPort;
        port monitorIn : StatusInPort;

        action processCommand : ProcessCommandAction;
        action generateStatus : GenerateStatusAction;
    }

    part def DisplayController {
        attribute outputWidth : ResolutionWidth = 3840;
        attribute outputHeight : ResolutionHeight = 2160;
        attribute overlayEnabled : Boolean = true;
        attribute refreshRate : FrameRateValue = 60.0;

        port videoIn : ProcessedVideoInPort;
        port displayOut : DisplayOutPort;

        action render : RenderFrameAction;
    }

    part def DataStorageUnit {
        attribute capacity : StorageCapacityValue = 1000;
        attribute storedFrameCount : FrameCountValue = 0;
        attribute archivedFrames : ArchivedFrame[0..*];
        attribute isFull : Boolean = false;

        port storageIn : ProcessedVideoInPort;

        action archive : ArchiveFrameAction;

        state storageState {
            state accepting;
            state full;
            transition first accepting then full when storedFrameCount >= capacity;
            transition first full then accepting when archivedFrames.size == 0;
        }
    }

    // ===== System Part Definition =====
    part def MarataVisionSystem {
        attribute systemName : String = "Marata Vision System";
        attribute systemVersion : String = "1.0";
        attribute currentState : String = "standby";

        part opticalSensor : OpticalSensor {
            port rawVideoOut : RawVideoOutPort;
            port controlIn : ControlInPort;
        }

        part imageProcessingUnit : ImageProcessingUnit {
            port videoIn : RawVideoInPort;
            port controlIn : ControlInPort;
            port processedVideoOut : ProcessedVideoOutPort;
            port statusOut : StatusOutPort;
        }

        part systemController : SystemController {
            port commandIn : CommandInPort;
            port controlOut : ControlOutPort;
            port statusOut : StatusOutPort;
            port monitorIn : StatusInPort;
        }

        part displayController : DisplayController {
            port videoIn : ProcessedVideoInPort;
            port displayOut : DisplayOutPort;
        }

        part dataStorageUnit : DataStorageUnit {
            port storageIn : ProcessedVideoInPort;
        }

        // ===== Connections =====
        connection rawVideoFeed connect opticalSensor.rawVideoOut to imageProcessingUnit.videoIn;
        connection processedVideoToDisplay connect imageProcessingUnit.processedVideoOut to displayController.videoIn;
        connection processedVideoToStorage connect imageProcessingUnit.processedVideoOut to dataStorageUnit.storageIn;
        connection sensorControl connect systemController.controlOut to opticalSensor.controlIn;
        connection ipuControl connect systemController.controlOut to imageProcessingUnit.controlIn;
        connection ipuStatusToController connect imageProcessingUnit.statusOut to systemController.monitorIn;

        // ===== State Machine =====
        state def SystemStateMachine {
            state standby {
                entry action enterStandbyMode {
                    attribute systemController.currentState = "standby";
                }
            }

            state initializing {
                entry action performInitialization {
                    action calibrateSensor;
                    action loadProcessingMode;
                    action verifyStorage;
                    succession first calibrateSensor then loadProcessingMode;
                    succession first loadProcessingMode then verifyStorage;
                }
            }

            state operational {
                entry action startProcessing {
                    attribute systemController.currentState = "operational";
                }

                do action processFrameLoop {
                    action captureFrame : CaptureFrameAction;
                    action analyzeFrame : AnalyzeFrameAction;
                    action renderFrame : RenderFrameAction;
                    action archiveFrame : ArchiveFrameAction;

                    succession first captureFrame then analyzeFrame;
                    succession first analyzeFrame then renderFrame;
                    succession first analyzeFrame then archiveFrame;

                    flow captureFrame.frame to analyzeFrame.raw;
                    flow analyzeFrame.processed to renderFrame.processed;
                    flow analyzeFrame.processed to archiveFrame.processed;
                }
            }

            state paused {
                entry action pauseProcessing {
                    attribute systemController.currentState = "paused";
                }
            }

            state shutdown {
                entry action performShutdown {
                    action flushStorage;
                    action powerDownSensor;
                    succession first flushStorage then powerDownSensor;
                }
            }

            transition first standby then initializing
                accept commandReceived
                when commandIn.command.commandType == "start";

            transition first initializing then operational
                accept initializationComplete
                when opticalSensor.isCalibrated == true;

            transition first operational then paused
                accept commandReceived
                when commandIn.command.commandType == "pause";

            transition first paused then operational
                accept commandReceived
                when commandIn.command.commandType == "resume";

            transition first operational then shutdown
                accept commandReceived
                when commandIn.command.commandType == "shutdown";

            transition first paused then shutdown
                accept commandReceived
                when commandIn.command.commandType == "shutdown";

            transition first standby then shutdown
                accept commandReceived
                when commandIn.command.commandType == "shutdown";
        }

        // ===== Requirements =====
        requirement def ResolutionRequirement {
            doc "The system shall capture video at 4K resolution (3840x2160).";
            attribute requiredWidth : ResolutionWidth = 3840;
            attribute requiredHeight : ResolutionHeight = 2160;
        }

        requirement def FrameRateRequirement {
            doc "The system shall capture video at up to 120 frames per second.";
            attribute maxFrameRate : FrameRateValue = 120.0;
        }

        requirement def CameraControlRequirement {
            doc "The optical sensor shall have adjustable exposure, aperture, and focus controls.";
            attribute adjustableExposure : Boolean = true;
            attribute adjustableAperture : Boolean = true;
            attribute adjustableFocus : Boolean = true;
        }

        requirement def EdgeDetectionRequirement {
            doc "The IPU shall detect edges in the video feed.";
        }

        requirement def ObjectTrackingRequirement {
            doc "The IPU shall track multiple moving objects across frames.";
        }

        requirement def MotionVectorRequirement {
            doc "The IPU shall calculate motion vectors between consecutive frames.";
        }

        requirement def ColorCorrectionRequirement {
            doc "The IPU shall apply color correction to enhance the image.";
        }

        requirement def SystemControlRequirement {
            doc "The system controller shall receive external commands to change system behavior and monitor system status.";
        }

        requirement def DisplayOutputRequirement {
            doc "The display controller shall output processed video to a 4K display.";
            attribute outputWidth : ResolutionWidth = 3840;
            attribute outputHeight : ResolutionHeight = 2160;
        }

        requirement def StorageCapacityRequirement {
            doc "The data storage unit shall store at least 1000 processed frames with associated analysis data.";
            attribute minCapacity : StorageCapacityValue = 1000;
        }

        requirement def RealTimeProcessingRequirement {
            doc "The system shall process frames in real-time with minimal latency.";
            attribute maxLatency : ProcessingLatencyValue = 8.33;
        }

        requirement def SystemStatesRequirement {
            doc "The system shall operate in standby, initializing, operational, paused, and shutdown states.";
            attribute requiredStates : String[5] = ["standby", "initializing", "operational", "paused", "shutdown"];
        }

        requirement def ContinuousLoopRequirement {
            doc "When operational, the system shall continuously capture, analyze, display, and archive frames.";
        }

        // ===== Requirement Satisfaction =====
        satisfy ResolutionRequirement by opticalSensor.maxResolutionWidth;
        satisfy FrameRateRequirement by opticalSensor.maxFrameRate;
        satisfy CameraControlRequirement by opticalSensor.currentSettings;
        satisfy EdgeDetectionRequirement by imageProcessingUnit.detectEdges;
        satisfy ObjectTrackingRequirement by imageProcessingUnit.trackObjects;
        satisfy MotionVectorRequirement by imageProcessingUnit.calculateMotionVectors;
        satisfy ColorCorrectionRequirement by imageProcessingUnit.applyColorCorrection;
        satisfy SystemControlRequirement by systemController;
        satisfy DisplayOutputRequirement by displayController.outputWidth;
        satisfy StorageCapacityRequirement by dataStorageUnit.capacity;
        satisfy RealTimeProcessingRequirement by imageProcessingUnit.processingLatency;
        satisfy SystemStatesRequirement by SystemStateMachine;
        satisfy ContinuousLoopRequirement by SystemStateMachine::operational::processFrameLoop;
    }
}
