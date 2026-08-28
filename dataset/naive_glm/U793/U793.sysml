package Omniview {
    import ScalarValues::*;

    // ===== Units =====
    unit fps;
    unit ms;
    unit s;
    unit day;
    unit percent;
    unit pixel;
    unit m;
    unit mps;

    // ===== Value Types =====
    value def FrameRate :> Real { unit = fps; }
    value def Delay :> Real { unit = ms; }
    value def RetentionPeriod :> Integer { unit = day; }
    value def Confidence :> Real { unit = percent; }
    value def PixelCount :> Integer { unit = pixel; }
    value def Coordinate :> Real { unit = m; }
    value def VelocityComponent :> Real { unit = mps; }
    value def ObjectCount :> Integer;
    value def SensorId :> Integer;
    value def TrackingId :> Integer;
    value def Timestamp :> Real { unit = s; }

    value def Resolution {
        attribute width : PixelCount;
        attribute height : PixelCount;
    }

    value def Position3D {
        attribute x : Coordinate;
        attribute y : Coordinate;
        attribute z : Coordinate;
    }

    value def Velocity3D {
        attribute vx : VelocityComponent;
        attribute vy : VelocityComponent;
        attribute vz : VelocityComponent;
    }

    // ===== Enumerations =====
    enum def SensorOrientation {
        literal front;
        literal back;
        literal left;
        literal right;
        literal top;
        literal bottom;
        literal frontLeftDiagonal;
        literal backRightDiagonal;
    }

    enum def ObjectTypeEnum {
        literal vehicle;
        literal person;
        literal animal;
        literal structure;
        literal unknown;
    }

    enum def SystemHealth {
        literal nominal;
        literal degraded;
        literal fault;
    }

    // ===== Item Types =====
    item def ImageData;

    item def RawImageFrame {
        attribute sensorId : SensorId;
        attribute timestamp : Timestamp;
        attribute resolution : Resolution;
        attribute data : ImageData;
    }

    item def PanoramicImage {
        attribute timestamp : Timestamp;
        attribute resolution : Resolution;
        attribute data : ImageData;
    }

    item def DetectedObject {
        attribute trackingId : TrackingId;
        attribute objectType : ObjectTypeEnum;
        attribute position : Position3D;
        attribute velocity : Velocity3D;
        attribute confidence : Confidence;
    }

    item def TrackedObjectList {
        attribute timestamp : Timestamp;
        attribute objects : DetectedObject[0..100];
    }

    item def OperatorCommand {
        attribute commandType : String;
        attribute parameter : String;
    }

    item def SystemStatusReport {
        attribute mode : String;
        attribute health : SystemHealth;
        attribute timestamp : Timestamp;
        attribute activeSensorCount : Integer;
        attribute trackedObjectCount : Integer;
    }

    // ===== Port Definitions =====
    port def RawImageOut {
        out item frame : RawImageFrame;
    }

    port def RawImageIn {
        in item frame : RawImageFrame;
    }

    port def PanoramicImageOut {
        out item image : PanoramicImage;
    }

    port def PanoramicImageIn {
        in item image : PanoramicImage;
    }

    port def TrackedObjectListOut {
        out item list : TrackedObjectList;
    }

    port def TrackedObjectListIn {
        in item list : TrackedObjectList;
    }

    port def CommandPort {
        in item command : OperatorCommand;
    }

    port def StatusPort {
        out item status : SystemStatusReport;
    }

    // ===== Part Definitions =====
    part def OpticalSensor {
        attribute sensorId : SensorId;
        attribute orientation : SensorOrientation;
        attribute resolution : Resolution = Resolution { width = 3840; height = 2160; };
        attribute frameRate : FrameRate = 30.0;
        attribute isOperational : Boolean = true;
        port rawImageOut : RawImageOut;

        action captureFrame {
            in trigger : Boolean;
            out frame : RawImageFrame;
        }

        perform action captureFrames : captureFrame {
            assign frame.sensorId = sensorId;
            assign frame.resolution = resolution;
        }
    }

    part def ImageStitchingProcessor {
        attribute maxStitchingDelay : Delay = 500.0;
        attribute currentDelay : Delay;
        attribute isProcessing : Boolean = false;
        port rawImageIn : RawImageIn[8];
        port panoramicOut : PanoramicImageOut;

        action stitchImages {
            in frames : RawImageFrame[8];
            out image : PanoramicImage;
        }

        perform action stitchingProcess : stitchImages {
            assign image.resolution = Resolution { width = 7680; height = 4320; };
        }
    }

    part def ObjectDetectionUnit {
        attribute maxTrackedObjects : ObjectCount = 100;
        attribute currentTrackedCount : ObjectCount;
        attribute detectionConfidenceThreshold : Confidence = 75.0;
        port panoramicIn : PanoramicImageIn;
        port trackedOut : TrackedObjectListOut;

        action detectAndTrack {
            in image : PanoramicImage;
            out list : TrackedObjectList;
        }

        perform action detectionProcess : detectAndTrack {
            assign list.objects.size <= maxTrackedObjects;
        }
    }

    part def SystemController {
        attribute currentCommand : String;
        attribute currentMode : String;
        attribute systemHealth : SystemHealth = SystemHealth::nominal;
        attribute activeSensorCount : Integer = 8;
        attribute trackedObjectCount : Integer;
        port commandIn : CommandPort;
        port statusOut : StatusPort;

        action processCommand {
            in command : OperatorCommand;
            assign currentCommand = command.commandType;
        }

        action generateStatus {
            out status : SystemStatusReport;
            assign status.mode = currentMode;
            assign status.health = systemHealth;
            assign status.activeSensorCount = activeSensorCount;
            assign status.trackedObjectCount = trackedObjectCount;
        }

        state controllerStateMachine {
            entry assign currentMode = "Standby";

            state Standby {
                entry assign currentMode = "Standby";
                entry assign systemHealth = SystemHealth::nominal;
            }
            state Initializing {
                entry assign currentMode = "Initializing";
            }
            state Calibrating {
                entry assign currentMode = "Calibrating";
            }
            state ActiveSurveillance {
                entry assign currentMode = "ActiveSurveillance";
            }

            transition first Standby -> Initializing when currentCommand == "start";
            transition Initializing -> Calibrating when currentCommand == "calibrate";
            transition Calibrating -> ActiveSurveillance when currentCommand == "activate";
            transition ActiveSurveillance -> Standby when currentCommand == "stop";
            transition Standby -> ActiveSurveillance when currentCommand == "activate";
        }
    }

    part def DataArchive {
        attribute retentionPeriod : RetentionPeriod = 30;
        attribute storageCapacityTB : Real = 10.0;
        attribute usedStorageTB : Real;
        port panoramicIn : PanoramicImageIn;
        port trackedIn : TrackedObjectListIn;

        action storePanoramicImage {
            in image : PanoramicImage;
        }

        action storeTrackedObjects {
            in list : TrackedObjectList;
        }

        action purgeExpiredData {
            doc /* Remove data older than retentionPeriod. */
        }

        perform action archivalProcess : storePanoramicImage;
        perform action trackingArchive : storeTrackedObjects;
    }

    part def PowerSupply {
        attribute inputVoltage : Real = 12.0;
        attribute isPowered : Boolean = true;
        attribute powerOutputWatts : Real = 150.0;

        action providePower {
            out voltage : Real;
            out isPowered : Boolean;
        }

        perform action powerDistribution : providePower {
            assign voltage = inputVoltage;
            assign isPowered = true;
        }
    }

    // ===== System Definition =====
    part def OmniviewSystem {
        doc /* The Omniview System provides real-time 360-degree surveillance with automatic object detection, tracking, and data archival. */
        attribute systemName : String = "Omniview";

        port operatorCommand : CommandPort;
        port systemStatus : StatusPort;

        part frontSensor : OpticalSensor {
            attribute sensorId = 1;
            attribute orientation = SensorOrientation::front;
        }
        part backSensor : OpticalSensor {
            attribute sensorId = 2;
            attribute orientation = SensorOrientation::back;
        }
        part leftSensor : OpticalSensor {
            attribute sensorId = 3;
            attribute orientation = SensorOrientation::left;
        }
        part rightSensor : OpticalSensor {
            attribute sensorId = 4;
            attribute orientation = SensorOrientation::right;
        }
        part topSensor : OpticalSensor {
            attribute sensorId = 5;
            attribute orientation = SensorOrientation::top;
        }
        part bottomSensor : OpticalSensor {
            attribute sensorId = 6;
            attribute orientation = SensorOrientation::bottom;
        }
        part frontLeftSensor : OpticalSensor {
            attribute sensorId = 7;
            attribute orientation = SensorOrientation::frontLeftDiagonal;
        }
        part backRightSensor : OpticalSensor {
            attribute sensorId = 8;
            attribute orientation = SensorOrientation::backRightDiagonal;
        }

        part stitchingProcessor : ImageStitchingProcessor;
        part objectDetection : ObjectDetectionUnit;
        part controller : SystemController;
        part archive : DataArchive;
        part power : PowerSupply;

        // Sensor feeds to stitching processor
        connection frontFeed connect frontSensor.rawImageOut to stitchingProcessor.rawImageIn;
        connection backFeed connect backSensor.rawImageOut to stitchingProcessor.rawImageIn;
        connection leftFeed connect leftSensor.rawImageOut to stitchingProcessor.rawImageIn;
        connection rightFeed connect rightSensor.rawImageOut to stitchingProcessor.rawImageIn;
        connection topFeed connect topSensor.rawImageOut to stitchingProcessor.rawImageIn;
        connection bottomFeed connect bottomSensor.rawImageOut to stitchingProcessor.rawImageIn;
        connection frontLeftFeed connect frontLeftSensor.rawImageOut to stitchingProcessor.rawImageIn;
        connection backRightFeed connect backRightSensor.rawImageOut to stitchingProcessor.rawImageIn;

        // Panoramic image to object detection
        connection panoramicToDetection connect stitchingProcessor.panoramicOut to objectDetection.panoramicIn;

        // Data to archive
        connection panoramicToArchive connect stitchingProcessor.panoramicOut to archive.panoramicIn;
        connection trackedToArchive connect objectDetection.trackedOut to archive.trackedIn;

        // Controller interfaces
        connection commandToController connect operatorCommand to controller.commandIn;
        connection statusFromController connect controller.statusOut to systemStatus;
    }

    // ===== Requirements =====
    requirement def PanoramicCoverageRequirement {
        doc /* The system shall provide complete 360-degree coverage using 8 optical sensors positioned at front, back, left, right, top, bottom, and diagonal corners with no blind spots. */
        subject system : OmniviewSystem;
        constraint { system.frontSensor.orientation == SensorOrientation::front }
        constraint { system.backSensor.orientation == SensorOrientation::back }
        constraint { system.leftSensor.orientation == SensorOrientation::left }
        constraint { system.rightSensor.orientation == SensorOrientation::right }
        constraint { system.topSensor.orientation == SensorOrientation::top }
        constraint { system.bottomSensor.orientation == SensorOrientation::bottom }
        constraint { system.frontLeftSensor.orientation == SensorOrientation::frontLeftDiagonal }
        constraint { system.backRightSensor.orientation == SensorOrientation::backRightDiagonal }
    }

    requirement def SensorResolutionRequirement {
        doc /* Each optical sensor shall capture video at 4K resolution (3840x2160 pixels) at 30 frames per second. */
        subject sensor : OpticalSensor;
        constraint { sensor.resolution.width == 3840 }
        constraint { sensor.resolution.height == 2160 }
        constraint { sensor.frameRate == 30.0 }
    }

    requirement def SensorDataTransmissionRequirement {
        doc /* Each sensor shall transmit raw image data with a timestamp and unique sensor ID to the central processor. */
        subject sensor : OpticalSensor;
        subject frame : RawImageFrame;
        constraint { frame.sensorId == sensor.sensorId }
        constraint { frame.timestamp > 0 }
        constraint { frame.data != null }
    }

    requirement def StitchingDelayRequirement {
        doc /* The image stitching processor shall combine all 8 sensor feeds into a single panoramic image with total delay less than 500 milliseconds. */
        subject processor : ImageStitchingProcessor;
        constraint { processor.maxStitchingDelay <= 500.0 }
    }

    requirement def ObjectDetectionRequirement {
        doc /* The object detection unit shall identify, classify, and track up to 100 objects simultaneously, recording 3D position, velocity, object type, confidence level, and unique tracking ID for each detected object. */
        subject detector : ObjectDetectionUnit;
        constraint { detector.maxTrackedObjects >= 100 }
    }

    requirement def DetectedObjectDataRequirement {
        doc /* Each detected object shall include a unique tracking ID, object type, 3D position, 3D velocity, and confidence level. */
        subject obj : DetectedObject;
        constraint { obj.trackingId > 0 }
        constraint { obj.objectType != null }
        constraint { obj.position != null }
        constraint { obj.velocity != null }
        constraint { obj.confidence >= 0.0 and obj.confidence <= 100.0 }
    }

    requirement def DataRetentionRequirement {
        doc /* The data archive shall retain all panoramic imagery and tracked object data for at least 30 days. */
        subject archive : DataArchive;
        constraint { archive.retentionPeriod >= 30 }
    }

    requirement def ContinuousOperationRequirement {
        doc /* The system shall operate continuously, powered by an external source. */
        subject power : PowerSupply;
        constraint { power.isPowered == true }
    }

    requirement def SystemModesRequirement {
        doc /* The system controller shall support Standby, Initializing, Calibrating, and Active Surveillance operating modes. */
        subject controller : SystemController;
        constraint { controller.currentMode == "Standby" or controller.currentMode == "Initializing" or controller.currentMode == "Calibrating" or controller.currentMode == "ActiveSurveillance" }
    }

    requirement def RealTimePanoramicViewRequirement {
        doc /* The system shall present a near real-time panoramic view by stitching all sensor feeds with less than half a second total delay. */
        subject system : OmniviewSystem;
        subject processor : ImageStitchingProcessor;
        constraint { processor.maxStitchingDelay < 500.0 }
    }

    // ===== Requirement Satisfaction =====
    satisfaction satisfy PanoramicCoverageRequirement by OmniviewSystem;
    satisfaction satisfy SensorResolutionRequirement by OpticalSensor;
    satisfaction satisfy StitchingDelayRequirement by ImageStitchingProcessor;
    satisfaction satisfy ObjectDetectionRequirement by ObjectDetectionUnit;
    satisfaction satisfy DataRetentionRequirement by DataArchive;
    satisfaction satisfy ContinuousOperationRequirement by PowerSupply;
    satisfaction satisfy SystemModesRequirement by SystemController;
}
