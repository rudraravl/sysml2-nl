package OmnidirectionalCameraSystem {
    private import ScalarValues::*;
    private import ISQ::*;

    enum def DirectionKind { front; back; left; right; top; bottom; }
    enum def CommandKind { startCalibration; startCapture; stop; statusRequest; }

    item def RawImage {
        attribute width : Integer;
        attribute height : Integer;
        attribute direction : DirectionKind;
    }

    item def PanoramicImage {
        attribute width : Integer;
        attribute height : Integer;
    }

    item def Video {
        attribute duration : Real;
        attribute frameCount : Integer;
    }

    item def CalibrationData {
        attribute lensDistortion : Real;
        attribute sensorAlignment : Real;
        attribute colorDifference : Real;
    }

    item def ControlCommand {
        attribute commandType : CommandKind;
    }

    item def SystemStatus {
        attribute currentState : String;
        attribute health : String;
    }

    attribute def VoltageValue :> Real;
    attribute def CurrentValue :> Real;
    attribute def PowerValue :> Real;

    port def PowerPort {
        in voltage : VoltageValue;
        in current : CurrentValue;
    }

    port def ControlPort {
        in command : ControlCommand;
        out status : SystemStatus;
    }

    port def RawImagePort {
        out image : RawImage;
    }

    port def PanoramicImagePort {
        out image : PanoramicImage;
    }

    port def CalibrationDataPort {
        out data : CalibrationData;
    }

    action def CaptureImage {
        out image : RawImage;
    }

    action def ProcessImages {
        in frontImage : RawImage;
        in backImage : RawImage;
        in leftImage : RawImage;
        in rightImage : RawImage;
        in topImage : RawImage;
        in bottomImage : RawImage;
        in calibration : CalibrationData;
        out panoramic : PanoramicImage;
    }

    action def StoreImage {
        in panoramic : PanoramicImage;
    }

    action def PerformCalibration {
        out calibrationData : CalibrationData;
    }

    part def ImageSensor {
        attribute direction : DirectionKind;
        attribute resolutionWidth : Integer = 4000;
        attribute resolutionHeight : Integer = 3000;
        port pwrIn : PowerPort;
        port rawOut : RawImagePort;
        perform action capture : CaptureImage;
    }

    part def CalibrationModule {
        port pwrIn : PowerPort;
        port calibOut : CalibrationDataPort;
        perform action calibrate : PerformCalibration;
    }

    part def ImageProcessor {
        port pwrIn : PowerPort;
        port frontIn : ~RawImagePort;
        port backIn : ~RawImagePort;
        port leftIn : ~RawImagePort;
        port rightIn : ~RawImagePort;
        port topIn : ~RawImagePort;
        port bottomIn : ~RawImagePort;
        port calibIn : ~CalibrationDataPort;
        port panoOut : PanoramicImagePort;
        perform action process : ProcessImages;
    }

    part def StorageUnit {
        port pwrIn : PowerPort;
        port panoIn : ~PanoramicImagePort;
        item storedImages : PanoramicImage[*];
        item storedVideos : Video[*];
        perform action store : StoreImage;
    }

    part def PowerManagementUnit {
        port mainPwrIn : PowerPort;
        port frontSensorPwr : ~PowerPort;
        port backSensorPwr : ~PowerPort;
        port leftSensorPwr : ~PowerPort;
        port rightSensorPwr : ~PowerPort;
        port topSensorPwr : ~PowerPort;
        port bottomSensorPwr : ~PowerPort;
        port processorPwr : ~PowerPort;
        port storagePwr : ~PowerPort;
        port calibrationPwr : ~PowerPort;
        attribute totalPower : PowerValue;
    }

    part def OmnidirectionalCamera {
        port mainPwr : PowerPort;
        port controlPort : ControlPort;
        port outputPort : PanoramicImagePort;

        part frontSensor : ImageSensor { :>> direction = DirectionKind::front; }
        part backSensor : ImageSensor { :>> direction = DirectionKind::back; }
        part leftSensor : ImageSensor { :>> direction = DirectionKind::left; }
        part rightSensor : ImageSensor { :>> direction = DirectionKind::right; }
        part topSensor : ImageSensor { :>> direction = DirectionKind::top; }
        part bottomSensor : ImageSensor { :>> direction = DirectionKind::bottom; }

        part calibrationModule : CalibrationModule;
        part imageProcessor : ImageProcessor;
        part storageUnit : StorageUnit;
        part powerManagement : PowerManagementUnit;

        perform action captureAll;

        connect mainPwr to powerManagement.mainPwrIn;
        connect powerManagement.frontSensorPwr to frontSensor.pwrIn;
        connect powerManagement.backSensorPwr to backSensor.pwrIn;
        connect powerManagement.leftSensorPwr to leftSensor.pwrIn;
        connect powerManagement.rightSensorPwr to rightSensor.pwrIn;
        connect powerManagement.topSensorPwr to topSensor.pwrIn;
        connect powerManagement.bottomSensorPwr to bottomSensor.pwrIn;
        connect powerManagement.processorPwr to imageProcessor.pwrIn;
        connect powerManagement.storagePwr to storageUnit.pwrIn;
        connect powerManagement.calibrationPwr to calibrationModule.pwrIn;

        connect frontSensor.rawOut to imageProcessor.frontIn;
        connect backSensor.rawOut to imageProcessor.backIn;
        connect leftSensor.rawOut to imageProcessor.leftIn;
        connect rightSensor.rawOut to imageProcessor.rightIn;
        connect topSensor.rawOut to imageProcessor.topIn;
        connect bottomSensor.rawOut to imageProcessor.bottomIn;

        connect calibrationModule.calibOut to imageProcessor.calibIn;

        connect imageProcessor.panoOut to storageUnit.panoIn;
        connect imageProcessor.panoOut to outputPort;

        exhibit state operationalStates {
            entry; then idle;

            state idle;
            transition idle_to_calibration
                first idle
                accept cmd : ControlCommand via controlPort
                    if cmd.commandType == CommandKind::startCalibration
                then selfCalibration;
            transition idle_to_capture
                first idle
                accept cmd : ControlCommand via controlPort
                    if cmd.commandType == CommandKind::startCapture
                then activeCycle;

            state selfCalibration {
                entry calibrationModule.calibrate;
            }
            transition selfCalibration_complete
                first selfCalibration
                then idle;

            state activeCycle {
                entry; then capturing;

                state capturing {
                    do captureAll;
                }
                transition capturing_to_processing
                    first capturing
                    then processing;

                state processing {
                    do imageProcessor.process;
                }
                transition processing_to_storing
                    first processing
                    then storing;

                state storing {
                    do storageUnit.store;
                }
            }
            transition activeCycle_complete
                first activeCycle
                then idle;
            transition activeCycle_stop
                first activeCycle
                accept cmd : ControlCommand via controlPort
                    if cmd.commandType == CommandKind::stop
                then idle;
        }
    }

    requirement def CompleteSphericalCoverage {
        subject camera : OmnidirectionalCamera;
        doc { The system shall capture a complete 360-degree horizontal and 180-degree vertical field of view using six directional sensors positioned front, back, left, right, top, and bottom. }
    }

    requirement def SeamlessStitching {
        subject camera : OmnidirectionalCamera;
        doc { The image processor shall produce a single unified panoramic image without visible seams or blind spots using calibration data for lens distortion, sensor alignment, and color difference correction. }
    }

    requirement def PowerDistribution {
        subject camera : OmnidirectionalCamera;
        doc { The power management unit shall distribute power from a single input to all six sensors, the processor, the calibration module, and the storage unit. }
    }

    requirement def HighResolutionCapture {
        subject camera : OmnidirectionalCamera;
        doc { Each image sensor shall capture raw images at a minimum resolution of 4000 by 3000 pixels. }
    }

    part surveillanceCamera : OmnidirectionalCamera {
        satisfy CompleteSphericalCoverage;
        satisfy SeamlessStitching;
        satisfy PowerDistribution;
        satisfy HighResolutionCapture;
    }
}
