package FineGuidanceSensor {

    unit deg;
    unit deg_per_s;
    unit K;
    unit pixel;
    unit DN;
    unit nm;
    unit Hz;
    unit W;
    unit s;

    value type AngleValue > Real { unit deg; }
    value type AngularRateValue > Real { unit deg_per_s; }
    value type TemperatureValue > Real { unit K; }
    value type PixelValue > Real { unit pixel; }
    value type SignalValue > Real { unit DN; }
    value type WavelengthValue > Real { unit nm; }
    value type FrequencyValue > Real { unit Hz; }
    value type PowerValue > Real { unit W; }
    value type TimeValue > Real { unit s; }

    item def Starlight {
        attribute wavelength : WavelengthValue;
        attribute intensity : Real;
    }

    item def RawImage {
        attribute pixelData : Real[*];
        attribute exposureTime : TimeValue;
        attribute temperature : TemperatureValue;
    }

    item def CleanedImage {
        attribute pixelData : Real[*];
        attribute noiseLevel : Real;
    }

    item def CentroidData {
        attribute x : PixelValue;
        attribute y : PixelValue;
        attribute confidence : Real;
        attribute timestamp : TimeValue;
    }

    item def GuidanceData {
        attribute angle : AngleValue;
        attribute rate : AngularRateValue;
        attribute timestamp : TimeValue;
        attribute quality : Real;
    }

    item def ModeCommand {
        attribute requestedMode : String;
    }

    item def ThermalCommand {
        attribute targetTemperature : TemperatureValue;
    }

    item def CalibrationCommand {
        attribute routine : String;
    }

    item def ReferenceStar {
        attribute id : String;
        attribute rightAscension : AngleValue;
        attribute declination : AngleValue;
        attribute magnitude : Real;
    }

    item def FaultEvent {
        attribute code : Integer;
        attribute description : String;
    }

    item def CorrectionParameters {
        attribute opticalDistortion : Real[*];
        attribute electronicOffset : Real[*];
    }

    port def StarlightIn {
        in starlight : Starlight;
    }

    port def FocusedLightOut {
        out focusedLight : Starlight;
    }

    port def RawImageOut {
        out rawImage : RawImage;
    }

    port def CleanedImageOut {
        out cleanedImage : CleanedImage;
    }

    port def CentroidOut {
        out centroid : CentroidData;
    }

    port def GuidanceOut {
        out guidance : GuidanceData;
    }

    port def CommandIn {
        in command : ModeCommand;
    }

    port def ThermalPort {
        in thermalCommand : ThermalCommand;
        out currentTemperature : TemperatureValue;
    }

    port def CalibrationPort {
        in calibrationCommand : CalibrationCommand;
        out referenceStars : ReferenceStar[*];
    }

    port def FaultPort {
        out fault : FaultEvent;
    }

    port def CalibrationDataOut {
        out referenceStars : ReferenceStar[*];
        out corrections : CorrectionParameters;
    }

    port def CalibrationDataIn {
        in referenceStars : ReferenceStar[*];
        in corrections : CorrectionParameters;
    }

    action def FocusLight {
        in light : Starlight;
        out focused : Starlight;
        assign focused.wavelength = light.wavelength;
        assign focused.intensity = light.intensity * 0.9;
    }

    action def CaptureImage {
        in light : Starlight;
        out image : RawImage;
        assign image.exposureTime = 0.1 [s];
        assign image.temperature = 250 [K];
    }

    action def Denoise {
        in raw : RawImage;
        out cleaned : CleanedImage;
        assign cleaned.noiseLevel = 0.01;
    }

    action def ComputeCentroid {
        in image : CleanedImage;
        out centroid : CentroidData;
        assign centroid.x = 512.0 [pixel];
        assign centroid.y = 512.0 [pixel];
        assign centroid.confidence = 0.98;
        assign centroid.timestamp = 0.0 [s];
    }

    action def TrackMotion {
        in centroid : CentroidData;
        out guidance : GuidanceData;
        assign guidance.angle = 0.0 [deg];
        assign guidance.rate = 0.0 [deg/s];
        assign guidance.timestamp = centroid.timestamp;
        assign guidance.quality = centroid.confidence;
    }

    action def SelfCalibrate {
    }

    action def RegulateTemperature {
        in target : TemperatureValue;
        out current : TemperatureValue;
        assign current = target;
    }

    action def SelectWavelength {
        in wavelength : WavelengthValue;
        ref currentWavelength : WavelengthValue;
        assign currentWavelength = wavelength;
    }

    part def OpticalAssembly {
        attribute focalLength : Real = 500.0;
        attribute aperture : Real = 0.1;
        port starlightIn : StarlightIn;
        port focusedLightOut : FocusedLightOut;
        part filterWheel {
            attribute currentWavelength : WavelengthValue = 550 [nm];
            attribute availableWavelengths : WavelengthValue[*];
            action selectWavelength : SelectWavelength;
        }
        part primaryMirror;
        part secondaryMirror;
        action focus : FocusLight;
    }

    part def PhotoDetector {
        attribute operatingTemperature : TemperatureValue = 250 [K];
        port lightIn : StarlightIn;
        port rawOut : RawImageOut;
        action capture : CaptureImage;
    }

    part def SignalProcessor {
        port rawIn : RawImageOut;
        port guidanceOut : GuidanceOut;
        port calibDataIn : CalibrationDataIn;
        part centroidEngine {
            action compute : ComputeCentroid;
        }
        part motionTracker {
            action track : TrackMotion;
        }
        action denoise : Denoise;
    }

    part def CalibrationUnit {
        port calibPort : CalibrationPort;
        port calibDataOut : CalibrationDataOut;
        attribute referenceStars : ReferenceStar[*];
        action selfCalibrate : SelfCalibrate;
    }

    part def ControlUnit {
        port commandIn : CommandIn;
        port thermalPort : ThermalPort;
        port faultPort : FaultPort;
        part thermalController {
            attribute currentTemperature : TemperatureValue = 250 [K];
            action regulate : RegulateTemperature;
        }
        part modeController {
            attribute requestedMode : String;
            attribute starFound : Boolean = false;
            attribute lockStable : Boolean = false;
            attribute lockLost : Boolean = false;
            attribute calibrationComplete : Boolean = false;
            attribute faultDetected : Boolean = false;
            attribute faultCleared : Boolean = false;
            state machine modeStateMachine : FGSModeStateMachine;
        }
    }

    state def FGSModeStateMachine {
        state standby;
        state acquiring;
        state tracking;
        state measuring;
        state selfCalibration;
        state fault;

        transition standby -> acquiring when requestedMode == "acquire";
        transition acquiring -> tracking when starFound;
        transition tracking -> measuring when lockStable;
        transition measuring -> tracking when lockLost;
        transition standby -> selfCalibration when requestedMode == "calibrate";
        transition selfCalibration -> standby when calibrationComplete;
        transition standby -> fault when faultDetected;
        transition acquiring -> fault when faultDetected;
        transition tracking -> fault when faultDetected;
        transition measuring -> fault when faultDetected;
        transition selfCalibration -> fault when faultDetected;
        transition fault -> standby when faultCleared;
    }

    part def FineGuidanceSensor {
        attribute acquisitionTime : TimeValue = 30 [s];
        attribute trackingAccuracy : AngleValue = 0.001 [deg];
        port starlightIn : StarlightIn;
        port guidanceOut : GuidanceOut;
        port commandIn : CommandIn;
        port thermalPort : ThermalPort;
        port calibPort : CalibrationPort;
        port faultPort : FaultPort;

        part opticalAssembly : OpticalAssembly;
        part photoDetector : PhotoDetector;
        part signalProcessor : SignalProcessor;
        part calibrationUnit : CalibrationUnit;
        part controlUnit : ControlUnit;

        connect starlightIn to opticalAssembly.starlightIn;
        connect opticalAssembly.focusedLightOut to photoDetector.lightIn;
        connect photoDetector.rawOut to signalProcessor.rawIn;
        connect signalProcessor.guidanceOut to guidanceOut;
        connect calibrationUnit.calibDataOut to signalProcessor.calibDataIn;
        connect commandIn to controlUnit.commandIn;
        connect thermalPort to controlUnit.thermalPort;
        connect calibPort to calibrationUnit.calibPort;
        connect controlUnit.faultPort to faultPort;
    }

    requirement def GuidanceAccuracyRequirement {
        doc /The FGS shall provide angular position data with accuracy better than 0.001 deg./
        subject sensor : FineGuidanceSensor;
        requirement {
            sensor.guidanceOut.guidance.angle <= 0.001 [deg];
        }
    }

    requirement def RateAccuracyRequirement {
        doc /The FGS shall provide angular rate data with accuracy better than 0.0001 deg/s./
        subject sensor : FineGuidanceSensor;
        requirement {
            sensor.guidanceOut.guidance.rate <= 0.0001 [deg/s];
        }
    }

    requirement def ThermalStabilityRequirement {
        doc /The FGS shall maintain detector temperature within 0.1 K of 250 K./
        subject sensor : FineGuidanceSensor;
        requirement {
            sensor.photoDetector.operatingTemperature >= 249.9 [K];
            sensor.photoDetector.operatingTemperature <= 250.1 [K];
        }
    }

    requirement def AcquisitionTimeRequirement {
        doc /The FGS shall acquire a guide star within 30 seconds./
        subject sensor : FineGuidanceSensor;
        requirement {
            sensor.acquisitionTime <= 30 [s];
        }
    }

    requirement def SelfCalibrationRequirement {
        doc /The FGS shall perform self-calibration to correct optical and electronic imperfections./
        subject sensor : FineGuidanceSensor;
        requirement {
            sensor.calibrationUnit.selfCalibrate;
        }
    }

    requirement def ModeAvailabilityRequirement {
        doc /The FGS shall support standby, acquiring, tracking, measuring, self-calibration, and fault modes./
        subject sensor : FineGuidanceSensor;
        requirement {
            sensor.controlUnit.modeController.modeStateMachine.standby;
            sensor.controlUnit.modeController.modeStateMachine.acquiring;
            sensor.controlUnit.modeController.modeStateMachine.tracking;
            sensor.controlUnit.modeController.modeStateMachine.measuring;
            sensor.controlUnit.modeController.modeStateMachine.selfCalibration;
            sensor.controlUnit.modeController.modeStateMachine.fault;
        }
    }

}
