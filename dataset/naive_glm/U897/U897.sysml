package StructuredLight3DScanner {

    import ScalarValues::*;
    import ISQ::*;

    // ============================================================
    // Value Types
    // ============================================================
    value type LengthMM :> Real { unit 'mm'; }
    value type DistanceCM :> Real { unit 'cm'; }
    value type AngleDeg :> Real { unit 'deg'; }
    value type FrameRate :> Real { unit 'fps'; }
    value type MemoryGB :> Integer { unit 'GB'; }
    value type ComputeGFLOPS :> Real { unit 'GFLOPS'; }
    value type Lumens :> Real { unit 'lm'; }
    value type PixelCount :> Integer;
    value type ResolutionWidth :> Integer;
    value type ResolutionHeight :> Integer;
    value type PatternIndex :> Integer;
    value type PointCount :> Integer;

    // ============================================================
    // Item Types
    // ============================================================
    item def StructuredLightPattern {
        attribute patternType : String; // "GrayCode" | "PhaseShift" | "Fringe"
        attribute patternIndex : PatternIndex;
        attribute width : ResolutionWidth;
        attribute height : ResolutionHeight;
        attribute encodedData : Any;
    }

    item def CapturedImage {
        attribute cameraId : String;
        attribute patternIndex : PatternIndex;
        attribute width : ResolutionWidth;
        attribute height : ResolutionHeight;
        attribute pixelData : Any;
        attribute timestamp : Real;
    }

    item def Point3D {
        attribute x : LengthMM;
        attribute y : LengthMM;
        attribute z : LengthMM;
    }

    item def PointCloud {
        attribute points : Point3D[0..*];
        attribute pointCount : PointCount;
    }

    item def CalibrationData {
        attribute intrinsicLeft : Any;
        attribute intrinsicRight : Any;
        attribute extrinsic : Any;
        attribute baseline : DistanceCM;
        attribute reprojectionError : LengthMM;
    }

    item def ScanParameters {
        attribute patternCount : PatternIndex;
        attribute exposureTime : Real;
        attribute gain : Real;
    }

    // ============================================================
    // Ports
    // ============================================================
    port def LightProjectionPort {
        out pattern : StructuredLightPattern;
    }

    port def ImageCapturePort {
        out image : CapturedImage;
    }

    port def ImageInputPort {
        in image : CapturedImage;
    }

    port def PatternCommandPort {
        in pattern : StructuredLightPattern;
    }

    port def PointCloudOutputPort {
        out cloud : PointCloud;
    }

    port def CalibrationOutputPort {
        out calibData : CalibrationData;
    }

    // ============================================================
    // Requirements
    // ============================================================
    requirement def DepthAccuracyRequirement {
        doc /* The scanner shall achieve a depth accuracy of 0.5 mm. */
        attribute requiredAccuracy : LengthMM = 0.5;
        constraint { accuracy <= requiredAccuracy }
    }

    requirement def ResolutionRequirement {
        doc /* The scanner shall support a resolution of 1920x1080. */
        attribute requiredWidth : ResolutionWidth = 1920;
        attribute requiredHeight : ResolutionHeight = 1080;
        constraint { width == requiredWidth and height == requiredHeight }
    }

    requirement def WorkingVolumeRequirement {
        doc /* The scanner shall scan objects within a 30cm x 30cm x 50cm volume. */
        attribute requiredWidth : DistanceCM = 30;
        attribute requiredDepth : DistanceCM = 30;
        attribute requiredHeight : DistanceCM = 50;
        constraint { volumeWidth == requiredWidth and volumeDepth == requiredDepth and volumeHeight == requiredHeight }
    }

    requirement def ScanDistanceRequirement {
        doc /* The scanner shall operate from a typical distance of 80 cm. */
        attribute nominalDistance : DistanceCM = 80;
        constraint { operatingDistance == nominalDistance }
    }

    requirement def ThroughputRequirement {
        doc /* The scanner shall complete a full scan cycle within 30 seconds. */
        attribute maxCycleTime : Real = 30;
        constraint { cycleTime <= maxCycleTime }
    }

    // ============================================================
    // Projector
    // ============================================================
    part def Projector {
        attribute resolutionWidth : ResolutionWidth = 1920;
        attribute resolutionHeight : ResolutionHeight = 1080;
        attribute brightness : Lumens = 3000;
        attribute throwRatio : Real = 1.2;
        attribute currentPatternIndex : PatternIndex;

        port projectionPort : LightProjectionPort;
        port commandPort : PatternCommandPort;

        action def EmitPattern {
            in pattern : StructuredLightPattern;
            out emitted : StructuredLightPattern;
            start;
            then done EmitPattern;
        }

        perform action emitPattern : EmitPattern;

        action def GenerateGrayCodeSequence {
            out patterns : StructuredLightPattern[0..*];
        }

        action def GeneratePhaseShiftSequence {
            out patterns : StructuredLightPattern[0..*];
        }
    }

    // ============================================================
    // Stereo Camera
    // ============================================================
    part def StereoCamera {
        attribute cameraId : String;
        attribute frameRate : FrameRate = 60;
        attribute resolutionWidth : ResolutionWidth = 1920;
        attribute resolutionHeight : ResolutionHeight = 1080;
        attribute sensorType : String = "CMOS";
        attribute fieldOfView : AngleDeg = 45;

        port capturePort : ImageCapturePort;

        action def CaptureFrame {
            in pattern : StructuredLightPattern;
            out image : CapturedImage;
            start;
            then done CaptureFrame;
        }

        perform action captureFrame : CaptureFrame;
    }

    // ============================================================
    // Processing Unit
    // ============================================================
    part def ProcessingUnit {
        attribute memory : MemoryGB = 32;
        attribute computePower : ComputeGFLOPS = 1000;
        attribute coreCount : Integer = 8;

        port imageInputLeft : ImageInputPort;
        port imageInputRight : ImageInputPort;
        port cloudOutput : PointCloudOutputPort;
        port calibOutput : CalibrationOutputPort;

        attribute calibrationData : CalibrationData;
        attribute accumulatedClouds : PointCloud[0..*];

        action def PerformCalibration {
            out calibData : CalibrationData;
            start;
            then done PerformCalibration;
        }

        action def DecodePattern {
            in leftImage : CapturedImage;
            in rightImage : CapturedImage;
            out leftCode : Any;
            out rightCode : Any;
            start;
            then done DecodePattern;
        }

        action def Triangulate {
            in leftImage : CapturedImage;
            in rightImage : CapturedImage;
            in calibData : CalibrationData;
            out partialCloud : PointCloud;
            start;
            then DecodePattern;
            then done Triangulate;
        }

        action def MergeClouds {
            in partialClouds : PointCloud[0..*];
            out finalCloud : PointCloud;
            start;
            then done MergeClouds;
        }

        action def ExportPointCloud {
            in cloud : PointCloud;
            out exportedCloud : PointCloud;
            start;
            then done ExportPointCloud;
        }

        perform action performCalibration : PerformCalibration;
        perform action triangulate : Triangulate;
        perform action mergeClouds : MergeClouds;
        perform action exportPointCloud : ExportPointCloud;
    }

    // ============================================================
    // Scanner System
    // ============================================================
    part def ScannerSystem {
        attribute operatingDistance : DistanceCM = 80;
        attribute volumeWidth : DistanceCM = 30;
        attribute volumeDepth : DistanceCM = 30;
        attribute volumeHeight : DistanceCM = 50;
        attribute accuracy : LengthMM = 0.5;
        attribute resolutionWidth : ResolutionWidth = 1920;
        attribute resolutionHeight : ResolutionHeight = 1080;
        attribute cycleTime : Real = 25;
        attribute baseline : DistanceCM = 15;

        satisfy DepthAccuracyRequirement by accuracy;
        satisfy ResolutionRequirement by resolutionWidth, resolutionHeight;
        satisfy WorkingVolumeRequirement by volumeWidth, volumeDepth, volumeHeight;
        satisfy ScanDistanceRequirement by operatingDistance;
        satisfy ThroughputRequirement by cycleTime;

        part projector : Projector {
            attribute resolutionWidth = 1920;
            attribute resolutionHeight = 1080;
            port projectionPort : LightProjectionPort;
            port commandPort : PatternCommandPort;
        }

        part leftCamera : StereoCamera {
            attribute cameraId = "left";
            attribute frameRate = 60;
            attribute resolutionWidth = 1920;
            attribute resolutionHeight = 1080;
            port capturePort : ImageCapturePort;
        }

        part rightCamera : StereoCamera {
            attribute cameraId = "right";
            attribute frameRate = 60;
            attribute resolutionWidth = 1920;
            attribute resolutionHeight = 1080;
            port capturePort : ImageCapturePort;
        }

        part processingUnit : ProcessingUnit {
            attribute memory = 32;
            attribute computePower = 1000;
            port imageInputLeft : ImageInputPort;
            port imageInputRight : ImageInputPort;
            port cloudOutput : PointCloudOutputPort;
            port calibOutput : CalibrationOutputPort;
        }

        // Connections
        connection projectorToProcessingCommand
            connect projector.commandPort to processingUnit.imageInputLeft;

        connection leftImageFlow
            connect leftCamera.capturePort to processingUnit.imageInputLeft;

        connection rightImageFlow
            connect rightCamera.capturePort to processingUnit.imageInputRight;

        connection cloudExport
            connect processingUnit.cloudOutput to self.cloudOutputPort;

        port cloudOutputPort : PointCloudOutputPort;

        // ============================================================
        // State Machine
        // ============================================================
        state def ScannerStates;

        state behavior ScannerStates {
            entry; then Off;

            state Off {
                entry action { /* System powered off */ }
                transition off_to_init
                    first Off
                    accept PowerOn
                    then Initializing;
            }

            state Initializing {
                entry action {
                    /* Initialize projector, cameras, and processing unit */
                    projector.currentPatternIndex = 0;
                }
                transition init_to_calib
                    first Initializing
                    accept InitComplete
                    then Calibrating;
            }

            state Calibrating {
                entry action {
                    /* Perform stereo calibration using calibration target */
                    processingUnit.performCalibration();
                }
                transition calib_to_ready
                    first Calibrating
                    accept CalibrationDone
                    then Ready;
            }

            state Ready {
                entry action { /* System ready to begin scanning */ }
                transition ready_to_scanning
                    first Ready
                    accept StartScan
                    then Scanning;
            }

            state Scanning {
                entry action { /* Begin scanning loop */ }

                state Projecting {
                    entry action {
                        /* Project next structured light pattern */
                        projector.emitPattern();
                    }
                    transition proj_to_capture
                        first Projecting
                        accept PatternProjected
                        then Capturing;
                }

                state Capturing {
                    entry action {
                        /* Both cameras capture simultaneously */
                        leftCamera.captureFrame();
                        rightCamera.captureFrame();
                    }
                    transition cap_to_process
                        first Capturing
                        accept ImagesCaptured
                        then Processing;
                }

                state Processing {
                    entry action {
                        /* Decode patterns and triangulate 3D points */
                        processingUnit.triangulate();
                    }
                    transition proc_to_check
                        first Processing
                        accept ProcessingDone
                        then CheckComplete;
                }

                state CheckComplete {
                    entry action {
                        /* Determine if sufficient data collected */
                    }
                    transition check_more
                        first CheckComplete
                        accept NeedMoreData
                        then Projecting;
                    transition check_done
                        first CheckComplete
                        accept ScanComplete
                        then Finalizing;
                }

                transition scanning_init
                    first Scanning#entry
                    then Projecting;
            }

            state Finalizing {
                entry action {
                    /* Merge partial point clouds and export */
                    processingUnit.mergeClouds();
                    processingUnit.exportPointCloud();
                }
                transition fin_to_ready
                    first Finalizing
                    accept OutputComplete
                    then Ready;
            }

            transition any_to_off
                first Ready, Scanning, Finalizing
                accept PowerOff
                then Off;
        }

        exhibit state behavior : ScannerStates;
    }

}
