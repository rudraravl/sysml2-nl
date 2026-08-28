package OmnidirectionalCameraSystem {

    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types =====

    value def Voltage :> Real { unit 'V'; }
    value def Current :> Real { unit 'A'; }
    value def Power :> Real { unit 'W'; }
    value def Resolution :> Integer;
    value def FieldOfViewDegrees :> Real { unit 'deg'; }
    value def FrameRate :> Real { unit 'fps'; }
    value def StorageCapacity :> Integer { unit 'GB'; }
    value def PixelCount :> Integer;
    value def Timestamp :> Real { unit 's'; }

    // ===== Item Types =====

    item def RawImage {
        attribute sensorId : String;
        attribute resolution : Resolution;
        attribute timestamp : Timestamp;
        attribute direction : String;
    }

    item def PanoramicImage {
        attribute resolution : Resolution := 7680;
        attribute timestamp : Timestamp;
        attribute horizontalFOV : FieldOfViewDegrees := 360.0;
        attribute verticalFOV : FieldOfViewDegrees := 180.0;
    }

    item def VideoStream {
        attribute frameRate : FrameRate;
        attribute panoramicFrames : PanoramicImage[0..*];
    }

    item def CalibrationData {
        attribute lensDistortionParams : Real[0..*];
        attribute sensorAlignmentMatrix : Real[0..*];
        attribute colorCorrectionCoeffs : Real[0..*];
        attribute valid : Boolean;
    }

    item def CaptureCommand {
        attribute commandId : String;
        attribute captureMode : CaptureMode;
    }

    enum def CaptureMode {
        singleImage;
        continuousVideo;
        selfCalibration;
    }

    item def StatusReport {
        attribute systemState : String;
        attribute storageAvailable : StorageCapacity;
        attribute sensorHealth : Boolean[6];
        attribute timestamp : Timestamp;
    }

    item def PowerInput {
        attribute inputVoltage : Voltage;
        attribute inputCurrent : Current;
    }

    // ===== Port Definitions =====

    port def PowerPort {
        attribute voltage : Voltage;
        attribute current : Current;
        out item power : PowerInput;
    }

    port def RawImagePort {
        out item rawImage : RawImage;
    }

    port def CalibrationPort {
        out item calibrationData : CalibrationData;
    }

    port def PanoramicOutputPort {
        out item panoramicImage : PanoramicImage;
        out item videoStream : VideoStream;
    }

    port def ControlPort {
        in item captureCommand : CaptureCommand;
        out item statusReport : StatusReport;
    }

    port def StorageDataPort {
        in item panoramicImage : PanoramicImage;
        in item videoStream : VideoStream;
    }

    // ===== Part Definitions =====

    part def ImageSensor {
        attribute sensorId : String;
        attribute direction : String;
        attribute resolution : Resolution := 4096;
        attribute fieldOfView : FieldOfViewDegrees := 90.0;
        attribute powerRequirement : Power := 2.5;
        attribute operationalVoltage : Voltage := 3.3;
        attribute operationalCurrent : Current := 0.76;

        port powerIn : PowerPort;
        port imageOut : RawImagePort;

        action def CaptureAction {
            in sensorId : String;
            in direction : String;
            out rawImage : RawImage;
        }

        action capture : CaptureAction {
            in sensorId = ImageSensor::sensorId;
            in direction = ImageSensor::direction;
            out rawImage = imageOut.rawImage;
        }
    }

    part def CalibrationModule {
        attribute calibrationValid : Boolean := false;
        attribute lastCalibrationTimestamp : Timestamp;

        port calibrationOut : CalibrationPort;

        action def PerformCalibration {
            out calibrationData : CalibrationData;
        }

        action calibrate : PerformCalibration {
            out calibrationData = calibrationOut.calibrationData;
        }

        action def ValidateCalibration {
            in data : CalibrationData;
            out valid : Boolean;
        }
    }

    part def ImageProcessor {
        attribute processingClockRate : Real { unit 'GHz'; } := 2.0;
        attribute powerRequirement : Power := 10.0;
        attribute operationalVoltage : Voltage := 5.0;
        attribute operationalCurrent : Current := 2.0;

        port powerIn : PowerPort;
        port rawImageIn : RawImagePort[6];
        port calibrationIn : CalibrationPort;
        port panoramicOut : PanoramicOutputPort;

        action def StitchAction {
            in rawImages : RawImage[6];
            in calibration : CalibrationData;
            out panoramic : PanoramicImage;
        }

        action stitch : StitchAction {
            in rawImages = rawImageIn.rawImage;
            in calibration = calibrationIn.calibrationData;
            out panoramic = panoramicOut.panoramicImage;
        }
    }

    part def StorageUnit {
        attribute capacity : StorageCapacity := 2000;
        attribute usedSpace : StorageCapacity := 0;
        attribute writeSpeed : Real { unit 'MB/s'; } := 500;
        attribute powerRequirement : Power := 3.0;
        attribute operationalVoltage : Voltage := 5.0;
        attribute operationalCurrent : Current := 0.6;

        port powerIn : PowerPort;
        port dataIn : StorageDataPort;

        action def StoreImage {
            in image : PanoramicImage;
        }

        action def StoreVideo {
            in video : VideoStream;
        }

        action storeImage : StoreImage {
            in image = dataIn.panoramicImage;
        }

        action storeVideo : StoreVideo {
            in video = dataIn.videoStream;
        }
    }

    part def PowerManagementUnit {
        attribute inputVoltage : Voltage := 12.0;
        attribute inputCurrent : Current := 5.0;
        attribute efficiency : Real := 0.92;
        attribute totalOutputPower : Power;

        port powerInput : PowerPort;
        port sensorPowerOut : PowerPort[6];
        port processorPowerOut : PowerPort;
        port storagePowerOut : PowerPort;
        port calibrationPowerOut : PowerPort;

        action def DistributePower {
            in input : PowerInput;
            out sensorPower : PowerInput[6];
            out processorPower : PowerInput;
            out storagePower : PowerInput;
            out calibrationPower : PowerInput;
        }

        action distribute : DistributePower {
            in input = powerInput.power;
            out sensorPower = sensorPowerOut.power;
            out processorPower = processorPowerOut.power;
            out storagePower = storagePowerOut.power;
            out calibrationPower = calibrationPowerOut.power;
        }
    }

    // ===== Main System =====

    part def OmnidirectionalCameraSystem {
        attribute systemId : String;
        attribute manufacturer : String;
        attribute modelVersion : String;

        port externalPower : PowerPort;
        port controlInterface : ControlPort;
        port panoramicOutput : PanoramicOutputPort;

        part frontSensor : ImageSensor {
            attribute sensorId := "sensor_front";
            attribute direction := "front";
        }

        part backSensor : ImageSensor {
            attribute sensorId := "sensor_back";
            attribute direction := "back";
        }

        part leftSensor : ImageSensor {
            attribute sensorId := "sensor_left";
            attribute direction := "left";
        }

        part rightSensor : ImageSensor {
            attribute sensorId := "sensor_right";
            attribute direction := "right";
        }

        part topSensor : ImageSensor {
            attribute sensorId := "sensor_top";
            attribute direction := "top";
        }

        part bottomSensor : ImageSensor {
            attribute sensorId := "sensor_bottom";
            attribute direction := "bottom";
        }

        part processor : ImageProcessor;
        part calibrationModule : CalibrationModule;
        part storage : StorageUnit;
        part powerManager : PowerManagementUnit;

        // Power connections
        connection powerInputConn connect externalPower to powerManager.powerInput;
        connection frontPowerConn connect powerManager.sensorPowerOut[1] to frontSensor.powerIn;
        connection backPowerConn connect powerManager.sensorPowerOut[2] to backSensor.powerIn;
        connection leftPowerConn connect powerManager.sensorPowerOut[3] to leftSensor.powerIn;
        connection rightPowerConn connect powerManager.sensorPowerOut[4] to rightSensor.powerIn;
        connection topPowerConn connect powerManager.sensorPowerOut[5] to topSensor.powerIn;
        connection bottomPowerConn connect powerManager.sensorPowerOut[6] to bottomSensor.powerIn;
        connection processorPowerConn connect powerManager.processorPowerOut to processor.powerIn;
        connection storagePowerConn connect powerManager.storagePowerOut to storage.powerIn;
        connection calibrationPowerConn connect powerManager.calibrationPowerOut to calibrationModule.calibrationOut;

        // Raw image connections
        connection frontImageConn connect frontSensor.imageOut to processor.rawImageIn[1];
        connection backImageConn connect backSensor.imageOut to processor.rawImageIn[2];
        connection leftImageConn connect leftSensor.imageOut to processor.rawImageIn[3];
        connection rightImageConn connect rightSensor.imageOut to processor.rawImageIn[4];
        connection topImageConn connect topSensor.imageOut to processor.rawImageIn[5];
        connection bottomImageConn connect bottomSensor.imageOut to processor.rawImageIn[6];

        // Calibration connection
        connection calibrationConn connect calibrationModule.calibrationOut to processor.calibrationIn;

        // Panoramic output connections
        connection processorOutputConn connect processor.panoramicOut to panoramicOutput;
        connection storageDataConn connect processor.panoramicOut to storage.dataIn;

        // ===== State Machine =====

        state def CameraStateMachine {
            entry action initializeSystem {
                // Power on all components and verify health
            }

            state idle {
                entry action enterIdle {
                    // Reduce power to standby levels
                }
                exit action exitIdle {
                    // Prepare for active operation
                }
            }

            state selfCalibration {
                entry action startCalibration {
                    // Trigger calibration module
                    perform calibrationModule.calibrate;
                }

                do action validateCalibration {
                    // Validate calibration data
                }

                exit action finishCalibration {
                    // Store calibration results
                }
            }

            state activeCaptureCycle {
                entry action enterCaptureCycle;

                state capturing {
                    entry action startCapture {
                        // Trigger all six sensors simultaneously
                        perform frontSensor.capture;
                        perform backSensor.capture;
                        perform leftSensor.capture;
                        perform rightSensor.capture;
                        perform topSensor.capture;
                        perform bottomSensor.capture;
                    }
                }

                state processing {
                    entry action startProcessing {
                        // Stitch raw images using calibration data
                        perform processor.stitch;
                    }
                }

                state storing {
                    entry action startStoring {
                        // Save panoramic image to storage
                        perform storage.storeImage;
                    }
                }

                transition captureToProcess first capturing then processing;
                transition processToStore first processing then storing;
                transition storeToCapture first storing then capturing
                    if controlInterface.captureCommand.captureMode == CaptureMode::continuousVideo;
            }

            transition idleToCalibration first idle then selfCalibration
                if controlInterface.captureCommand.captureMode == CaptureMode::selfCalibration;

            transition calibrationToIdle first selfCalibration then idle
                when selfCalibration.validateCalibration.valid == true;

            transition idleToCapture first idle then activeCaptureCycle
                if controlInterface.captureCommand.captureMode == CaptureMode::singleImage
                or controlInterface.captureCommand.captureMode == CaptureMode::continuousVideo;

            transition captureToIdle first activeCaptureCycle then idle
                if controlInterface.captureCommand.captureMode == CaptureMode::singleImage
                when storing.complete == true;

            transition initialToIdle first initial then idle;
        }

        part behavior : CameraStateMachine;

        // ===== Requirements =====

        requirement def FullSphericalCoverage {
            subject : OmnidirectionalCameraSystem;
            objective {
                /* The system shall capture a complete 360-degree horizontal by 180-degree vertical spherical view using six image sensors positioned to cover front, back, left, right, top, and bottom directions without blind spots. */
            }
        }

        requirement def SimultaneousCapture {
            subject : OmnidirectionalCameraSystem;
            objective {
                /* All six image sensors shall capture raw high-resolution images simultaneously upon receiving a capture command. */
            }
        }

        requirement def SeamlessStitching {
            subject : OmnidirectionalCameraSystem;
            objective {
                /* The image processor shall stitch the six raw images into a single unified panoramic image using calibration data for lens distortion, sensor alignment, and color correction, producing no visible seams. */
            }
        }

        requirement def CalibrationSupport {
            subject : OmnidirectionalCameraSystem;
            objective {
                /* The system shall include a calibration module that provides lens distortion parameters, sensor alignment matrices, and color correction coefficients to the image processor. */
            }
        }

        requirement def InternalStorage {
            subject : OmnidirectionalCameraSystem;
            objective {
                /* The system shall include an internal storage unit for saving final panoramic images and video streams. */
            }
        }

        requirement def PowerDistribution {
            subject : OmnidirectionalCameraSystem;
            objective {
                /* The power management unit shall accept a single power input and distribute the correct voltage and current to all six sensors, the processor, the calibration module, and the storage unit. */
            }
        }

        requirement def UserControlInterface {
            subject : OmnidirectionalCameraSystem;
            objective {
                /* The system shall provide a dedicated control port through which an external user can issue capture commands and retrieve system status reports. */
            }
        }

        requirement def PanoramicOutput {
            subject : OmnidirectionalCameraSystem;
            objective {
                /* The system shall provide the final panoramic image through an output port for real-time viewing or further processing. */
            }
        }

        requirement def OperationalStates {
            subject : OmnidirectionalCameraSystem;
            objective {
                /* The system shall support idle, self-calibration, and active capture cycle states, transitioning between them based on user commands and internal completion events. */
            }
        }

        // Requirement satisfaction
        satisfy FullSphericalCoverage by frontSensor, backSensor, leftSensor, rightSensor, topSensor, bottomSensor;
        satisfy SimultaneousCapture by frontSensor, backSensor, leftSensor, rightSensor, topSensor, bottomSensor;
        satisfy SeamlessStitching by processor;
        satisfy CalibrationSupport by calibrationModule;
        satisfy InternalStorage by storage;
        satisfy PowerDistribution by powerManager;
        satisfy UserControlInterface by controlInterface;
        satisfy PanoramicOutput by panoramicOutput;
        satisfy OperationalStates by behavior;
    }

}
