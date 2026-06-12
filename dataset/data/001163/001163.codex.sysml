package OmnidirectionalCameraSystemModel {
    import ScalarValues::*;
    import SI::*;

    attribute def Degrees;
    attribute def Pixels;
    attribute def Bits;
    attribute def FramesPerSecond;
    attribute def BytesPerSecond;
    attribute def Watts;
    attribute def Volts;
    attribute def Celsius;
    attribute def Meters;
    attribute def Milliseconds;
    attribute def Percent;

    item def ElectricalPower {
        attribute voltage : Volts;
        attribute power : Watts;
    }

    item def LightField {
        attribute horizontalCoverage : Degrees;
        attribute verticalCoverage : Degrees;
        attribute illuminationLevel : Percent;
    }

    item def RawImageFrame {
        attribute width : Pixels;
        attribute height : Pixels;
        attribute bitDepth : Bits;
        attribute exposureTime : Milliseconds;
        attribute timestamp : Milliseconds;
        attribute sensorId : String;
    }

    item def PanoramicImageFrame {
        attribute width : Pixels;
        attribute height : Pixels;
        attribute horizontalFieldOfView : Degrees;
        attribute verticalFieldOfView : Degrees;
        attribute frameRate : FramesPerSecond;
        attribute timestamp : Milliseconds;
        attribute stitched : Boolean;
        attribute distortionCorrected : Boolean;
    }

    item def CameraHealthStatus {
        attribute temperature : Celsius;
        attribute storageAvailable : Percent;
        attribute processorLoad : Percent;
        attribute operational : Boolean;
        attribute faultCode : String;
    }

    item def CameraCommand {
        attribute commandName : String;
        attribute requestedFrameRate : FramesPerSecond;
        attribute enableRecording : Boolean;
        attribute enableStreaming : Boolean;
    }

    item def VideoStream {
        attribute encodedBitRate : BytesPerSecond;
        attribute frameRate : FramesPerSecond;
        attribute horizontalFieldOfView : Degrees;
        attribute verticalFieldOfView : Degrees;
        attribute latency : Milliseconds;
    }

    port def PowerInputPort {
        in item power : ElectricalPower;
    }

    port def OpticalInputPort {
        in item sceneLight : LightField;
    }

    port def RawFramePort {
        out item rawFrame : RawImageFrame;
    }

    port def CommandPort {
        in item command : CameraCommand;
    }

    port def StatusPort {
        out item status : CameraHealthStatus;
    }

    port def VideoOutputPort {
        out item stream : VideoStream;
        out item panoramicFrame : PanoramicImageFrame;
    }

    part def WideAngleLens {
        attribute focalLength : Meters;
        attribute horizontalFieldOfView : Degrees;
        attribute verticalFieldOfView : Degrees;
        attribute apertureNumber : Real;

        port opticalIn : OpticalInputPort;
        port opticalOut : RawFramePort;
    }

    part def ImageSensor {
        attribute activeWidth : Pixels;
        attribute activeHeight : Pixels;
        attribute bitDepth : Bits;
        attribute maximumFrameRate : FramesPerSecond;
        attribute exposureTime : Milliseconds;

        port opticalIn : OpticalInputPort;
        port rawOut : RawFramePort;
    }

    part def ImageSignalProcessor {
        attribute maximumInputFramesPerSecond : FramesPerSecond;
        attribute correctionLatency : Milliseconds;

        port rawIn : RawFramePort;
        port correctedOut : RawFramePort;
    }

    part def PanoramaStitcher {
        attribute outputWidth : Pixels;
        attribute outputHeight : Pixels;
        attribute stitchLatency : Milliseconds;
        attribute horizontalOutputCoverage : Degrees;
        attribute verticalOutputCoverage : Degrees;

        port correctedFrameIn : RawFramePort;
        port panoramaOut : VideoOutputPort;
    }

    part def VideoEncoder {
        attribute targetBitRate : BytesPerSecond;
        attribute encodingLatency : Milliseconds;
        attribute outputFrameRate : FramesPerSecond;

        port panoramaIn : VideoOutputPort;
        port encodedOut : VideoOutputPort;
    }

    part def ThermalController {
        attribute maximumSafeTemperature : Celsius;
        attribute currentTemperature : Celsius;
        attribute coolingPower : Watts;

        port statusOut : StatusPort;
    }

    part def ControlProcessor {
        attribute commandLatency : Milliseconds;
        attribute processorLoad : Percent;

        port commandIn : CommandPort;
        port statusOut : StatusPort;
    }

    part def OmnidirectionalCamera {
        attribute primaryFunction : String = "Capture light from all horizontal directions, correct lens distortion, stitch simultaneous images into a panoramic view, and provide a real-time omnidirectional video stream.";
        attribute horizontalCoverage : Degrees = 360;
        attribute verticalCoverage : Degrees = 180;
        attribute nominalFrameRate : FramesPerSecond = 30;
        attribute maximumLatency : Milliseconds = 120;
        attribute nominalPower : Watts = 18;
        attribute operatingVoltage : Volts = 12;

        port powerIn : PowerInputPort;
        port sceneInput : OpticalInputPort;
        port commandIn : CommandPort;
        port videoOut : VideoOutputPort;
        port statusOut : StatusPort;

        part frontLens : WideAngleLens {
            attribute horizontalFieldOfView = 210;
            attribute verticalFieldOfView = 190;
        }

        part rearLens : WideAngleLens {
            attribute horizontalFieldOfView = 210;
            attribute verticalFieldOfView = 190;
        }

        part frontSensor : ImageSensor {
            attribute activeWidth = 4096;
            attribute activeHeight = 4096;
            attribute bitDepth = 12;
            attribute maximumFrameRate = 60;
        }

        part rearSensor : ImageSensor {
            attribute activeWidth = 4096;
            attribute activeHeight = 4096;
            attribute bitDepth = 12;
            attribute maximumFrameRate = 60;
        }

        part imageProcessor : ImageSignalProcessor {
            attribute maximumInputFramesPerSecond = 120;
            attribute correctionLatency = 18;
        }

        part stitcher : PanoramaStitcher {
            attribute outputWidth = 8192;
            attribute outputHeight = 4096;
            attribute stitchLatency = 42;
            attribute horizontalOutputCoverage = 360;
            attribute verticalOutputCoverage = 180;
        }

        part encoder : VideoEncoder {
            attribute targetBitRate = 25000000;
            attribute encodingLatency = 28;
            attribute outputFrameRate = 30;
        }

        part controller : ControlProcessor {
            attribute commandLatency = 10;
            attribute processorLoad = 45;
        }

        part thermalManager : ThermalController {
            attribute maximumSafeTemperature = 75;
            attribute coolingPower = 4;
        }

        connect sceneInput to frontLens.opticalIn;
        connect sceneInput to rearLens.opticalIn;
        connect frontSensor.rawOut to imageProcessor.rawIn;
        connect rearSensor.rawOut to imageProcessor.rawIn;
        connect imageProcessor.correctedOut to stitcher.correctedFrameIn;
        connect stitcher.panoramaOut to encoder.panoramaIn;
        connect encoder.encodedOut to videoOut;
        connect commandIn to controller.commandIn;
        connect controller.statusOut to statusOut;
        connect thermalManager.statusOut to statusOut;
    }

    action def CaptureOmnidirectionalVideo {
        in item scene : LightField;
        in item command : CameraCommand;
        out item stream : VideoStream;

        action receiveLight;
        action exposeSensors;
        action correctLensDistortion;
        action synchronizeFrames;
        action stitchPanorama;
        action encodeVideo;
        action publishStream;

        first receiveLight;
        then exposeSensors;
        then correctLensDistortion;
        then synchronizeFrames;
        then stitchPanorama;
        then encodeVideo;
        then publishStream;
    }

    state def CameraOperatingStates {
        state Off;
        state Initializing;
        state Standby;
        state Capturing;
        state Streaming;
        state Fault;
        state Shutdown;

        transition PowerApplied first Off then Initializing;
        transition InitializationComplete first Initializing then Standby;
        transition CaptureCommandReceived first Standby then Capturing;
        transition StreamEnabled first Capturing then Streaming;
        transition StreamDisabled first Streaming then Capturing;
        transition CaptureStopped first Capturing then Standby;
        transition FaultDetected first Standby then Fault;
        transition StreamingFaultDetected first Streaming then Fault;
        transition FaultCleared first Fault then Initializing;
        transition PowerRemoved first Standby then Shutdown;
        transition ShutdownComplete first Shutdown then Off;
    }

    requirement def OmnidirectionalCoverageRequirement {
        subject camera : OmnidirectionalCamera;
        doc /* The camera shall provide continuous 360 degree horizontal scene coverage. */
        require constraint { camera.horizontalCoverage >= 360 }
    }

    requirement def PanoramicOutputRequirement {
        subject camera : OmnidirectionalCamera;
        doc /* The camera shall output stitched panoramic frames suitable for high-level situational awareness. */
        require constraint {
            camera.stitcher.horizontalOutputCoverage == 360 and
            camera.stitcher.verticalOutputCoverage >= 180 and
            camera.stitcher.outputWidth >= 7680 and
            camera.stitcher.outputHeight >= 3840
        }
    }

    requirement def RealTimeStreamingRequirement {
        subject camera : OmnidirectionalCamera;
        doc /* The camera shall provide real-time omnidirectional video with bounded end-to-end latency. */
        require constraint {
            camera.nominalFrameRate >= 30 and
            camera.maximumLatency <= 120
        }
    }

    requirement def SafeThermalOperationRequirement {
        subject camera : OmnidirectionalCamera;
        doc /* The camera shall monitor thermal state and report a fault before exceeding safe operating temperature. */
        require constraint {
            camera.thermalManager.maximumSafeTemperature <= 75
        }
    }

    part omnidirectionalCameraSystem : OmnidirectionalCamera;

    perform CaptureOmnidirectionalVideo by omnidirectionalCameraSystem;
}