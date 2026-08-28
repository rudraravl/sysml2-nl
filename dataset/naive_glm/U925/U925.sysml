package TriDAR_Navigation_System {

    // ---- Value Types with Units ----
    value type MassUnit :> Real { unit = "kg"; }
    value type PowerUnit :> Real { unit = "W"; }
    value type LengthUnit :> Real { unit = "m"; }
    value type AngleUnit :> Real { unit = "rad"; }
    value type FrequencyUnit :> Real { unit = "Hz"; }
    value type VoltageUnit :> Real { unit = "V"; }
    value type CurrentUnit :> Real { unit = "A"; }
    value type TimeUnit :> Real { unit = "s"; }

    // ---- Item Definitions ----
    item def PointCloud {
        attribute pointCount : Integer;
        attribute resolution : LengthUnit;
        attribute fieldOfView : AngleUnit;
    }

    item def Image {
        attribute width : Integer;
        attribute height : Integer;
        attribute pixelDepth : Integer;
    }

    item def StereoImage {
        attribute leftImage : Image;
        attribute rightImage : Image;
        attribute timestamp : TimeUnit;
        attribute baseline : LengthUnit;
    }

    item def PoseEstimate {
        attribute positionX : LengthUnit;
        attribute positionY : LengthUnit;
        attribute positionZ : LengthUnit;
        attribute quaternionW : Real;
        attribute quaternionX : Real;
        attribute quaternionY : Real;
        attribute quaternionZ : Real;
        attribute confidence : Real;
        attribute timestamp : TimeUnit;
    }

    item def PowerInput {
        attribute voltage : VoltageUnit;
        attribute current : CurrentUnit;
    }

    item def RegulatedPower {
        attribute voltage : VoltageUnit;
        attribute current : CurrentUnit;
    }

    item def LaserPulse {
        attribute wavelength : LengthUnit;
        attribute intensity : Real;
        attribute pulseDuration : TimeUnit;
    }

    item def NavigationSolution {
        attribute pose : PoseEstimate;
        attribute updateRate : FrequencyUnit;
        attribute valid : Boolean;
    }

    // ---- Requirements ----
    requirement def MassConstraint {
        doc { The total system mass shall be under 8.5 kg. }
        subject mass : MassUnit;
        constraint { mass <= 8.5 }
    }

    requirement def PowerConstraint {
        doc { The total system power consumption shall be under 85 W. }
        subject power : PowerUnit;
        constraint { power <= 85.0 }
    }

    requirement def RangeConstraint {
        doc { The system shall operate at ranges up to 50 meters. }
        subject range : LengthUnit;
        constraint { range <= 50.0 }
    }

    requirement def DistanceAccuracyConstraint {
        doc { Distance measurement accuracy shall be within 1 cm. }
        subject distanceError : LengthUnit;
        constraint { distanceError <= 0.01 }
    }

    requirement def PoseAccuracyConstraint {
        doc { Pose estimation accuracy shall be within 2 cm. }
        subject poseError : LengthUnit;
        constraint { poseError <= 0.02 }
    }

    requirement def OutputRateConstraint {
        doc { Navigation solution shall be output at 15 Hz. }
        subject rate : FrequencyUnit;
        constraint { rate >= 15.0 }
    }

    requirement def SynchronizationConstraint {
        doc { LIDAR and stereo camera data shall be temporally synchronized within 1 ms. }
        subject syncError : TimeUnit;
        constraint { syncError <= 0.001 }
    }

    // ---- Part Definitions ----

    part def LIDARScanner {
        port laserOut : LaserPulse;
        port cloudOut : PointCloud;
        port powerIn : RegulatedPower;
        attribute scanRange : LengthUnit = 50.0;
        attribute accuracy : LengthUnit = 0.01;
        attribute mass : MassUnit = 2.5;
        attribute power : PowerUnit = 25.0;
        attribute scanRate : FrequencyUnit = 15.0;
        attribute fieldOfView : AngleUnit = 0.785;

        action scanEnvironment {
            out pointCloud : PointCloud;
            doc { Emit laser pulses and measure time of flight to build 3D point cloud. }
        }

        action calibrateRange {
            out calibrationOffset : LengthUnit;
            doc { Perform internal range calibration to maintain 1 cm accuracy. }
        }

        state def LIDARStateMachine {
            initial Off;
            state Idle;
            state Scanning;
            state Calibrating;
            state Fault;

            transition Off -> Idle when powerOn;
            transition Idle -> Scanning when startScan;
            transition Idle -> Calibrating when calibrationDue;
            transition Scanning -> Idle when scanComplete;
            transition Calibrating -> Idle when calibrationComplete;
            transition Scanning -> Fault when errorDetected;
            transition Fault -> Idle when faultCleared;
        }
    }

    part def Camera {
        attribute resolution : Integer;
        attribute frameRate : FrequencyUnit;
        port imageOut : Image;
        port powerIn : RegulatedPower;
        attribute mass : MassUnit = 0.75;
        attribute power : PowerUnit = 7.5;
    }

    part def StereoCameraSystem {
        part leftCamera : Camera {
            attribute resolution = 1920;
            attribute frameRate = 15.0;
        }
        part rightCamera : Camera {
            attribute resolution = 1920;
            attribute frameRate = 15.0;
        }
        attribute baseline : LengthUnit = 0.15;
        attribute mass : MassUnit = 1.5;
        attribute power : PowerUnit = 15.0;
        port imageOut : StereoImage;
        port powerIn : RegulatedPower;

        action captureStereoImages {
            out stereoImage : StereoImage;
            doc { Capture synchronized images from both cameras for depth perception. }
        }

        action detectFeatures {
            in stereoImage : StereoImage;
            out featureCount : Integer;
            doc { Identify visual features on the target from stereo image pair. }
        }

        state def CameraStateMachine {
            initial Off;
            state Idle;
            state Capturing;
            state Processing;
            state Fault;

            transition Off -> Idle when powerOn;
            transition Idle -> Capturing when startCapture;
            transition Capturing -> Processing when captureComplete;
            transition Processing -> Idle when processingComplete;
            transition Capturing -> Fault when errorDetected;
            transition Fault -> Idle when faultCleared;
        }
    }

    part def DataProcessingUnit {
        port cloudIn : PointCloud;
        port imageIn : StereoImage;
        port poseOut : PoseEstimate;
        port solutionOut : NavigationSolution;
        port powerIn : RegulatedPower;
        attribute processingRate : FrequencyUnit = 15.0;
        attribute mass : MassUnit = 2.0;
        attribute power : PowerUnit = 20.0;
        attribute poseAccuracy : LengthUnit = 0.02;

        action fuseData {
            in pointCloud : PointCloud;
            in stereoImage : StereoImage;
            out poseEstimate : PoseEstimate;
            doc { Fuse LIDAR point cloud range accuracy with stereo camera visual detail to produce pose estimate. }
        }

        action validatePose {
            in poseEstimate : PoseEstimate;
            out validatedPose : PoseEstimate;
            doc { Validate the fused pose estimate for reliability and confidence scoring. }
        }

        action outputSolution {
            in validatedPose : PoseEstimate;
            out navigationSolution : NavigationSolution;
            doc { Package validated pose into navigation solution at 15 Hz output rate. }
        }

        state def ProcessingStateMachine {
            initial Off;
            state Idle;
            state Receiving;
            state Fusing;
            state Validating;
            state Outputting;
            state Fault;

            transition Off -> Idle when powerOn;
            transition Idle -> Receiving when dataReceived;
            transition Receiving -> Fusing when dataComplete;
            transition Fusing -> Validating when fusionComplete;
            transition Validating -> Outputting when validationComplete;
            transition Outputting -> Idle when outputComplete;
            transition Receiving -> Fault when errorDetected;
            transition Fusing -> Fault when errorDetected;
            transition Validating -> Fault when errorDetected;
            transition Fault -> Idle when faultCleared;
        }
    }

    part def PowerManagementUnit {
        port mainPowerIn : PowerInput;
        port lidarPowerOut : RegulatedPower;
        port cameraPowerOut : RegulatedPower;
        port processorPowerOut : RegulatedPower;
        attribute lidarVoltage : VoltageUnit = 12.0;
        attribute lidarCurrent : CurrentUnit = 2.1;
        attribute cameraVoltage : VoltageUnit = 5.0;
        attribute cameraCurrent : CurrentUnit = 3.0;
        attribute processorVoltage : VoltageUnit = 12.0;
        attribute processorCurrent : CurrentUnit = 1.7;
        attribute mass : MassUnit = 1.0;
        attribute power : PowerUnit = 5.0;

        action regulatePower {
            in mainPower : PowerInput;
            out lidarPower : RegulatedPower;
            out cameraPower : RegulatedPower;
            out processorPower : RegulatedPower;
            doc { Regulate main power input to required voltages and currents for each subsystem. }
        }

        action monitorPower {
            in lidarPower : RegulatedPower;
            in cameraPower : RegulatedPower;
            in processorPower : RegulatedPower;
            out status : Boolean;
            doc { Monitor power rails for overcurrent or undervoltage conditions. }
        }

        state def PowerStateMachine {
            initial Off;
            state Standby;
            state Distributing;
            state Protected;
            state Fault;

            transition Off -> Standby when powerOn;
            transition Standby -> Distributing when enableOutputs;
            transition Distributing -> Standby when disableOutputs;
            transition Distributing -> Protected when overcurrentDetected;
            transition Protected -> Distributing when currentRestored;
            transition Protected -> Fault when persistentFault;
            transition Fault -> Standby when faultCleared;
        }
    }

    // ---- Top-level TriDAR Navigation System ----

    part def TriDARNavigationSystem {
        attribute totalMass : MassUnit = 7.0;
        attribute totalPower : PowerUnit = 65.0;
        attribute operatingRange : LengthUnit = 50.0;
        attribute poseAccuracy : LengthUnit = 0.02;
        attribute outputRate : FrequencyUnit = 15.0;
        attribute syncTolerance : TimeUnit = 0.001;

        part lidarScanner : LIDARScanner;
        part stereoCameras : StereoCameraSystem;
        part dataProcessor : DataProcessingUnit;
        part powerManager : PowerManagementUnit;

        port mainPower : PowerInput;
        port navigationSolution : NavigationSolution;

        // Power distribution connections
        connection mainPower to powerManager.mainPowerIn;
        connection powerManager.lidarPowerOut to lidarScanner.powerIn;
        connection powerManager.cameraPowerOut to stereoCameras.powerIn;
        connection powerManager.processorPowerOut to dataProcessor.powerIn;

        // Data flow connections
        connection lidarScanner.cloudOut to dataProcessor.cloudIn;
        connection stereoCameras.imageOut to dataProcessor.imageIn;
        connection dataProcessor.solutionOut to navigationSolution;

        // Requirement satisfaction
        satisfy MassConstraint {
            subject mass = totalMass;
        }

        satisfy PowerConstraint {
            subject power = totalPower;
        }

        satisfy RangeConstraint {
            subject range = operatingRange;
        }

        satisfy DistanceAccuracyConstraint {
            subject distanceError = lidarScanner.accuracy;
        }

        satisfy PoseAccuracyConstraint {
            subject poseError = poseAccuracy;
        }

        satisfy OutputRateConstraint {
            subject rate = outputRate;
        }

        satisfy SynchronizationConstraint {
            subject syncError = syncTolerance;
        }

        // Main operational behavior
        action operate {
            doc { Continuously gather synchronized LIDAR and stereo data, fuse, validate, and output navigation solution at 15 Hz. }

            parallel {
                action lidarScan {
                    out pointCloud : PointCloud;
                    doc { LIDAR scanning in parallel with stereo capture. }
                }
                action stereoCapture {
                    out stereoImage : StereoImage;
                    doc { Stereo image capture in parallel with LIDAR scanning. }
                }
            }

            action fuse {
                in pointCloud : PointCloud;
                in stereoImage : StereoImage;
                out poseEstimate : PoseEstimate;
                doc { Fuse LIDAR range data with stereo visual features. }
            }

            action validate {
                in poseEstimate : PoseEstimate;
                out validatedPose : PoseEstimate;
                doc { Validate fused pose for reliability. }
            }

            action output {
                in validatedPose : PoseEstimate;
                out solution : NavigationSolution;
                doc { Output navigation solution at 15 Hz for spacecraft guidance. }
            }
        }

        // System-level state machine
        state def SystemStateMachine {
            initial PoweredOff;
            state Initializing;
            state Operational;
            state Standby;
            state Fault;

            transition PoweredOff -> Initializing when powerApplied;
            transition Initializing -> Operational when initializationComplete;
            transition Operational -> Standby when standbyCommand;
            transition Standby -> Operational when resumeCommand;
            transition Operational -> Fault when faultDetected;
            transition Standby -> Fault when faultDetected;
            transition Fault -> Initializing when resetCommand;
        }
    }
}
