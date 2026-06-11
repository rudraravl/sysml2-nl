package LaserSpeckleContrastImagingSystem {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Wavelength :> Real {
        unit = "nm";
    }

    attribute def OpticalPower :> Real {
        unit = "mW";
    }

    attribute def ExposureTime :> Real {
        unit = "ms";
    }

    attribute def FrameRate :> Real {
        unit = "Hz";
    }

    attribute def PixelResolution :> Real {
        unit = "um/pixel";
    }

    attribute def SpeckleContrast :> Real {
        unit = "1";
    }

    attribute def PerfusionIndex :> Real {
        unit = "a.u.";
    }

    attribute def Temperature :> Real {
        unit = "degC";
    }

    attribute def Voltage :> Real {
        unit = "V";
    }

    attribute def DataRate :> Real {
        unit = "MB/s";
    }

    item def CoherentLaserBeam {
        attribute wavelength : Wavelength;
        attribute opticalPower : OpticalPower;
        attribute coherenceLength : Real;
    }

    item def IlluminatedTissueRegion {
        attribute area : Real;
        attribute reflectance : Real;
        attribute safetyExposureLimit : OpticalPower;
    }

    item def SpeckleImageFrame {
        attribute exposure : ExposureTime;
        attribute frameRate : FrameRate;
        attribute resolutionX : Integer;
        attribute resolutionY : Integer;
        attribute timestamp : Real;
    }

    item def ContrastMap {
        attribute windowSizePixels : Integer;
        attribute meanContrast : SpeckleContrast;
        attribute spatialResolution : PixelResolution;
    }

    item def PerfusionMap {
        attribute meanPerfusion : PerfusionIndex;
        attribute maximumPerfusion : PerfusionIndex;
        attribute minimumPerfusion : PerfusionIndex;
    }

    item def SystemCommand {
        attribute commandId : Integer;
        attribute requestedExposure : ExposureTime;
        attribute requestedLaserPower : OpticalPower;
    }

    item def SystemStatus {
        attribute laserEnabled : Boolean;
        attribute cameraStreaming : Boolean;
        attribute processingActive : Boolean;
        attribute safetyInterlockClosed : Boolean;
        attribute internalTemperature : Temperature;
    }

    port def OpticalOutputPort {
        out item beam : CoherentLaserBeam;
    }

    port def OpticalInputPort {
        in item beam : CoherentLaserBeam;
    }

    port def ImageOutputPort {
        out item frame : SpeckleImageFrame;
    }

    port def ImageInputPort {
        in item frame : SpeckleImageFrame;
    }

    port def ContrastOutputPort {
        out item contrast : ContrastMap;
    }

    port def ContrastInputPort {
        in item contrast : ContrastMap;
    }

    port def PerfusionOutputPort {
        out item perfusion : PerfusionMap;
    }

    port def PerfusionInputPort {
        in item perfusion : PerfusionMap;
    }

    port def CommandInputPort {
        in item command : SystemCommand;
    }

    port def StatusOutputPort {
        out item status : SystemStatus;
    }

    port def ElectricalPowerPort {
        in attribute supplyVoltage : Voltage;
        in attribute maximumCurrent : Real;
    }

    part def LaserDiodeModule {
        port powerIn : ElectricalPowerPort;
        port opticalOut : OpticalOutputPort;
        port commandIn : CommandInputPort;
        port statusOut : StatusOutputPort;

        attribute nominalWavelength : Wavelength = 785.0;
        attribute maximumPower : OpticalPower = 80.0;
        attribute operatingPower : OpticalPower = 35.0;
        attribute warmupTime : Real = 2.0;
        attribute enabled : Boolean = false;

        state def LaserOperatingState {
            entry action initializeLaser;
            state off;
            state warming;
            state emitting;
            state fault;

            transition first off;
            transition off_to_warming
                first off
                then warming
                accept SystemCommand
                if command.requestedLaserPower > 0.0;

            transition warming_to_emitting
                first warming
                then emitting
                if enabled == true;

            transition emitting_to_off
                first emitting
                then off
                accept SystemCommand
                if command.requestedLaserPower == 0.0;

            transition any_to_fault
                first off
                then fault
                if operatingPower > maximumPower;
        }

        action initializeLaser {
            out status : SystemStatus;
        }

        action regulateOpticalPower {
            in requestedPower : OpticalPower;
            out deliveredBeam : CoherentLaserBeam;
        }
    }

    part def BeamDeliveryOptics {
        port opticalIn : OpticalInputPort;
        port opticalOut : OpticalOutputPort;

        attribute diffuserEnabled : Boolean = true;
        attribute beamDiameter : Real = 30.0;
        attribute incidenceAngle : Real = 20.0;
        attribute transmissionEfficiency : Real = 0.82;

        action homogenizeIllumination {
            in inputBeam : CoherentLaserBeam;
            out outputBeam : CoherentLaserBeam;
        }
    }

    part def TissueInterface {
        port illuminationIn : OpticalInputPort;
        port scatteredOut : OpticalOutputPort;

        attribute illuminatedArea : Real = 6.25;
        attribute maximumPermittedExposure : OpticalPower = 45.0;
        attribute workingDistance : Real = 150.0;

        action generateDynamicSpeckle {
            in illumination : CoherentLaserBeam;
            out scatteredField : CoherentLaserBeam;
            out region : IlluminatedTissueRegion;
        }
    }

    part def ImagingOptics {
        port opticalIn : OpticalInputPort;
        port opticalOut : OpticalOutputPort;

        attribute apertureFNumber : Real = 8.0;
        attribute magnification : Real = 0.5;
        attribute fieldOfViewX : Real = 20.0;
        attribute fieldOfViewY : Real = 20.0;

        action focusSpecklePattern {
            in scatteredField : CoherentLaserBeam;
            out imagePlaneField : CoherentLaserBeam;
        }
    }

    part def CameraSensor {
        port opticalIn : OpticalInputPort;
        port imageOut : ImageOutputPort;
        port commandIn : CommandInputPort;
        port statusOut : StatusOutputPort;

        attribute sensorWidthPixels : Integer = 2048;
        attribute sensorHeightPixels : Integer = 2048;
        attribute exposureTime : ExposureTime = 5.0;
        attribute frameRate : FrameRate = 60.0;
        attribute pixelSize : PixelResolution = 5.5;
        attribute quantumEfficiency : Real = 0.72;

        action acquireSpeckleFrame {
            in imagePlaneField : CoherentLaserBeam;
            out rawFrame : SpeckleImageFrame;
        }

        state def CameraState {
            state idle;
            state exposing;
            state streaming;
            state saturated;
            state fault;

            transition first idle;
            transition idle_to_streaming
                first idle
                then streaming
                accept SystemCommand;

            transition streaming_to_exposing
                first streaming
                then exposing;

            transition exposing_to_streaming
                first exposing
                then streaming;

            transition exposing_to_saturated
                first exposing
                then saturated
                if exposureTime > 20.0;

            transition saturated_to_streaming
                first saturated
                then streaming
                if exposureTime <= 20.0;
        }
    }

    part def ImageProcessor {
        port imageIn : ImageInputPort;
        port contrastOut : ContrastOutputPort;
        port statusOut : StatusOutputPort;

        attribute processingFrameRate : FrameRate = 60.0;
        attribute contrastWindowSize : Integer = 7;
        attribute darkFrameCorrectionEnabled : Boolean = true;
        attribute flatFieldCorrectionEnabled : Boolean = true;

        action preprocessFrame {
            in rawFrame : SpeckleImageFrame;
            out correctedFrame : SpeckleImageFrame;
        }

        action computeSpeckleContrast {
            in correctedFrame : SpeckleImageFrame;
            out contrastMap : ContrastMap;
        }
    }

    part def PerfusionEstimator {
        port contrastIn : ContrastInputPort;
        port perfusionOut : PerfusionOutputPort;

        attribute calibrationCoefficient : Real = 1.35;
        attribute minimumValidContrast : SpeckleContrast = 0.02;
        attribute maximumValidContrast : SpeckleContrast = 1.0;

        action estimatePerfusion {
            in contrastMap : ContrastMap;
            out perfusionMap : PerfusionMap;
        }
    }

    part def VisualizationConsole {
        port perfusionIn : PerfusionInputPort;
        port statusIn : StatusOutputPort;
        port commandOut : CommandInputPort;

        attribute displayRefreshRate : FrameRate = 30.0;
        attribute falseColorEnabled : Boolean = true;
        attribute recordingEnabled : Boolean = false;

        action renderPerfusionImage {
            in perfusionMap : PerfusionMap;
        }

        action issueAcquisitionCommand {
            out command : SystemCommand;
        }
    }

    part def SafetyController {
        port commandIn : CommandInputPort;
        port commandOut : CommandInputPort;
        port statusOut : StatusOutputPort;

        attribute enclosureClosed : Boolean = true;
        attribute eyeSafetyLimit : OpticalPower = 45.0;
        attribute maximumInternalTemperature : Temperature = 50.0;
        attribute shutdownRequested : Boolean = false;

        action validateCommand {
            in requestedCommand : SystemCommand;
            out permittedCommand : SystemCommand;
        }

        action emergencyShutdown {
            out safeCommand : SystemCommand;
        }

        state def SafetyState {
            state safe;
            state monitoring;
            state inhibited;
            state emergencyStop;

            transition first safe;
            transition safe_to_monitoring
                first safe
                then monitoring;

            transition monitoring_to_inhibited
                first monitoring
                then inhibited
                if enclosureClosed == false;

            transition monitoring_to_emergencyStop
                first monitoring
                then emergencyStop
                if shutdownRequested == true;

            transition inhibited_to_monitoring
                first inhibited
                then monitoring
                if enclosureClosed == true;

            transition emergencyStop_to_safe
                first emergencyStop
                then safe
                if shutdownRequested == false;
        }
    }

    part def DataRecorder {
        port imageIn : ImageInputPort;
        port contrastIn : ContrastInputPort;
        port perfusionIn : PerfusionInputPort;

        attribute storageDataRate : DataRate = 250.0;
        attribute compressionEnabled : Boolean = true;
        attribute retainedFrameCount : Integer = 18000;

        action storeAcquisitionData {
            in frame : SpeckleImageFrame;
            in contrastMap : ContrastMap;
            in perfusionMap : PerfusionMap;
        }
    }

    part def LSCI_System {
        port externalCommandIn : CommandInputPort;
        port externalStatusOut : StatusOutputPort;
        port clinicalPerfusionOut : PerfusionOutputPort;

        part laser : LaserDiodeModule;
        part deliveryOptics : BeamDeliveryOptics;
        part tissue : TissueInterface;
        part imagingOptics : ImagingOptics;
        part camera : CameraSensor;
        part processor : ImageProcessor;
        part estimator : PerfusionEstimator;
        part console : VisualizationConsole;
        part safety : SafetyController;
        part recorder : DataRecorder;

        attribute systemFrameRate : FrameRate = 60.0;
        attribute nominalLaserWavelength : Wavelength = 785.0;
        attribute nominalExposureTime : ExposureTime = 5.0;
        attribute primaryFunction : String =
            "Illuminate biological tissue with coherent laser light, capture time-varying speckle patterns, compute speckle contrast, and transform contrast into high-level perfusion maps representing relative microvascular blood flow.";

        connect externalCommandIn to safety.commandIn;
        connect safety.commandOut to laser.commandIn;
        connect safety.commandOut to camera.commandIn;
        connect laser.opticalOut to deliveryOptics.opticalIn;
        connect deliveryOptics.opticalOut to tissue.illuminationIn;
        connect tissue.scatteredOut to imagingOptics.opticalIn;
        connect imagingOptics.opticalOut to camera.opticalIn;
        connect camera.imageOut to processor.imageIn;
        connect camera.imageOut to recorder.imageIn;
        connect processor.contrastOut to estimator.contrastIn;
        connect processor.contrastOut to recorder.contrastIn;
        connect estimator.perfusionOut to console.perfusionIn;
        connect estimator.perfusionOut to recorder.perfusionIn;
        connect estimator.perfusionOut to clinicalPerfusionOut;
        connect safety.statusOut to externalStatusOut;
        connect laser.statusOut to externalStatusOut;
        connect camera.statusOut to externalStatusOut;
        connect processor.statusOut to externalStatusOut;

        action performLSCIAcquisition {
            in command : SystemCommand;
            out status : SystemStatus;
            out perfusionMap : PerfusionMap;

            action validate : safety.validateCommand;
            action regulate : laser.regulateOpticalPower;
            action shapeBeam : deliveryOptics.homogenizeIllumination;
            action scatter : tissue.generateDynamicSpeckle;
            action focus : imagingOptics.focusSpecklePattern;
            action acquire : camera.acquireSpeckleFrame;
            action preprocess : processor.preprocessFrame;
            action contrast : processor.computeSpeckleContrast;
            action perfusion : estimator.estimatePerfusion;
            action render : console.renderPerfusionImage;
        }
    }

    requirement def PrimaryFunctionRequirement {
        subject system : LSCI_System;
        require constraint {
            system.primaryFunction ==
            "Illuminate biological tissue with coherent laser light, capture time-varying speckle patterns, compute speckle contrast, and transform contrast into high-level perfusion maps representing relative microvascular blood flow."
        }
    }

    requirement def LaserSafetyRequirement {
        subject system : LSCI_System;
        require constraint {
            system.laser.operatingPower <= system.safety.eyeSafetyLimit
        }
    }

    requirement def RealTimeImagingRequirement {
        subject system : LSCI_System;
        require constraint {
            system.camera.frameRate >= 30.0 and
            system.processor.processingFrameRate >= system.camera.frameRate
        }
    }

    requirement def SpeckleContrastComputationRequirement {
        subject system : LSCI_System;
        require constraint {
            system.processor.contrastWindowSize >= 5 and
            system.processor.contrastWindowSize <= 15
        }
    }

    requirement def ExposureControlRequirement {
        subject system : LSCI_System;
        require constraint {
            system.camera.exposureTime >= 1.0 and
            system.camera.exposureTime <= 20.0
        }
    }

    requirement def PerfusionOutputRequirement {
        subject system : LSCI_System;
        require constraint {
            system.estimator.minimumValidContrast > 0.0 and
            system.estimator.maximumValidContrast <= 1.0
        }
    }

    requirement def DataRecordingRequirement {
        subject system : LSCI_System;
        require constraint {
            system.recorder.storageDataRate >= 150.0
        }
    }

    requirement def ThermalSafetyRequirement {
        subject system : LSCI_System;
        require constraint {
            system.safety.maximumInternalTemperature <= 50.0
        }
    }

    satisfy PrimaryFunctionRequirement by LSCI_System;
    satisfy LaserSafetyRequirement by SafetyController;
    satisfy RealTimeImagingRequirement by CameraSensor;
    satisfy SpeckleContrastComputationRequirement by ImageProcessor;
    satisfy ExposureControlRequirement by CameraSensor;
    satisfy PerfusionOutputRequirement by PerfusionEstimator;
    satisfy DataRecordingRequirement by DataRecorder;
    satisfy ThermalSafetyRequirement by SafetyController;

}