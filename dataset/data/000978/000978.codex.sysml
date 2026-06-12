package AtomicForceMicroscopySystem {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Nanometer :> LengthUnit {
        symbol = "nm";
        conversionFactor = 1.0e-9 [m];
    }

    attribute def Micrometer :> LengthUnit {
        symbol = "um";
        conversionFactor = 1.0e-6 [m];
    }

    attribute def Piconewton :> ForceUnit {
        symbol = "pN";
        conversionFactor = 1.0e-12 [N];
    }

    attribute def Nanonewton :> ForceUnit {
        symbol = "nN";
        conversionFactor = 1.0e-9 [N];
    }

    attribute def Kilohertz :> FrequencyUnit {
        symbol = "kHz";
        conversionFactor = 1000 [Hz];
    }

    value type SurfaceHeight :> Length {
        unit = Nanometer;
    }

    value type ScanPosition :> Length {
        unit = Micrometer;
    }

    value type CantileverDeflection :> Length {
        unit = Nanometer;
    }

    value type TipSampleForce :> Force {
        unit = Nanonewton;
    }

    value type FeedbackError :> Length {
        unit = Nanometer;
    }

    value type SamplingRate :> Frequency {
        unit = Kilohertz;
    }

    value type LaserPower :> Power {
        unit = mW;
    }

    value type ScannerVoltage :> ElectricPotential {
        unit = V;
    }

    item def SampleSurface {
        attribute material : String;
        attribute nominalSizeX : ScanPosition;
        attribute nominalSizeY : ScanPosition;
        attribute expectedRoughness : SurfaceHeight;
    }

    item def ProbeTip {
        attribute apexRadius : Length = 8 [nm];
        attribute coating : String = "silicon nitride";
        attribute springConstant : Real = 0.2;
    }

    item def LaserBeam {
        attribute opticalPower : LaserPower;
        attribute wavelength : Length = 635 [nm];
    }

    item def ReflectedBeam {
        attribute opticalPower : LaserPower;
        attribute angularDeviation : Real;
    }

    item def DeflectionSignal {
        attribute deflection : CantileverDeflection;
        attribute noiseRms : CantileverDeflection;
    }

    item def TopographyPixel {
        attribute x : ScanPosition;
        attribute y : ScanPosition;
        attribute z : SurfaceHeight;
        attribute deflectionError : FeedbackError;
    }

    item def TopographyMap {
        attribute pixelCountX : Integer;
        attribute pixelCountY : Integer;
        attribute scanSizeX : ScanPosition;
        attribute scanSizeY : ScanPosition;
        part pixel[1..*] : TopographyPixel;
    }

    item def ControlCommand {
        attribute xVoltage : ScannerVoltage;
        attribute yVoltage : ScannerVoltage;
        attribute zVoltage : ScannerVoltage;
    }

    item def UserScanRequest {
        attribute scanSizeX : ScanPosition;
        attribute scanSizeY : ScanPosition;
        attribute lineRate : Frequency;
        attribute setpointForce : TipSampleForce;
        attribute resolutionX : Integer;
        attribute resolutionY : Integer;
    }

    port def MechanicalProbePort {
        out tipForce : TipSampleForce;
        in surfaceHeight : SurfaceHeight;
    }

    port def OpticalEmitterPort {
        out emittedBeam : LaserBeam;
    }

    port def OpticalReceiverPort {
        in reflectedBeam : ReflectedBeam;
    }

    port def SignalPort {
        out deflectionSignal : DeflectionSignal;
    }

    port def ControlPort {
        in command : ControlCommand;
    }

    port def ImageDataPort {
        out map : TopographyMap;
    }

    port def UserCommandPort {
        in request : UserScanRequest;
    }

    part def CantileverProbe {
        attribute resonantFrequency : Frequency = 70 [kHz];
        attribute springConstant : Real = 0.2;
        attribute maximumDeflection : CantileverDeflection = 500 [nm];

        part tip : ProbeTip;

        port mechanical : MechanicalProbePort;
        port opticalInput : OpticalEmitterPort;
        port opticalOutput : OpticalReceiverPort;

        action def InteractWithSurface {
            in surface : SampleSurface;
            in setpointForce : TipSampleForce;
            out measuredDeflection : CantileverDeflection;
        }

        state def ProbeEngagementState {
            state retracted;
            state approaching;
            state engaged;
            state overloaded;
            state withdrawn;

            transition first retracted;
            transition retracted_to_approaching
                first retracted then approaching
                accept UserScanRequest;
            transition approaching_to_engaged
                first approaching then engaged
                if mechanical.tipForce <= 5 [nN];
            transition engaged_to_overloaded
                first engaged then overloaded
                if mechanical.tipForce > 20 [nN];
            transition overloaded_to_withdrawn
                first overloaded then withdrawn;
            transition engaged_to_withdrawn
                first engaged then withdrawn
                accept UserScanRequest;
        }
    }

    part def LaserAndPhotodetector {
        attribute laserPower : LaserPower = 0.8 [mW];
        attribute detectorBandwidth : Frequency = 500 [kHz];
        attribute deflectionSensitivity : Real = 50.0;

        port emitter : OpticalEmitterPort;
        port receiver : OpticalReceiverPort;
        port signalOut : SignalPort;

        action def MeasureCantileverDeflection {
            in reflectedBeam : ReflectedBeam;
            out signal : DeflectionSignal;
        }
    }

    part def PiezoelectricScanner {
        attribute travelX : ScanPosition = 100 [um];
        attribute travelY : ScanPosition = 100 [um];
        attribute travelZ : SurfaceHeight = 15000 [nm];
        attribute lateralResolution : Length = 0.1 [nm];
        attribute verticalResolution : Length = 0.02 [nm];

        port control : ControlPort;
        port probeInterface : MechanicalProbePort;

        action def RasterScan {
            in request : UserScanRequest;
            out positionX : ScanPosition;
            out positionY : ScanPosition;
        }

        action def AdjustHeight {
            in error : FeedbackError;
            out zCorrection : SurfaceHeight;
        }
    }

    part def FeedbackController {
        attribute proportionalGain : Real = 0.8;
        attribute integralGain : Real = 0.15;
        attribute derivativeGain : Real = 0.02;
        attribute samplingRate : SamplingRate = 100 [kHz];
        attribute setpointForce : TipSampleForce = 1.0 [nN];

        port signalIn : SignalPort;
        port commandOut : ControlPort;

        action def MaintainTipSampleInteraction {
            in deflection : DeflectionSignal;
            in setpoint : TipSampleForce;
            out command : ControlCommand;
            out error : FeedbackError;
        }
    }

    part def SampleStage {
        attribute flatness : SurfaceHeight = 10 [nm];
        attribute vibrationIsolationBandwidth : Frequency = 2 [Hz];

        part mountedSample : SampleSurface {
            attribute material = "calibration grating";
            attribute nominalSizeX = 20 [um];
            attribute nominalSizeY = 20 [um];
            attribute expectedRoughness = 5 [nm];
        }

        port surfaceInterface : MechanicalProbePort;
    }

    part def DataAcquisitionAndImaging {
        attribute adcResolutionBits : Integer = 24;
        attribute maximumPixelRate : SamplingRate = 50 [kHz];

        port signalIn : SignalPort;
        port imageOut : ImageDataPort;

        action def BuildTopographyMap {
            in request : UserScanRequest;
            in deflection : DeflectionSignal;
            in zCommand : ControlCommand;
            out map : TopographyMap;
        }
    }

    part def OperatorConsole {
        port commandOut : UserCommandPort;
        port imageIn : ImageDataPort;

        action def ConfigureScan {
            out request : UserScanRequest;
        }

        action def DisplayTopography {
            in map : TopographyMap;
        }
    }

    part def AtomicForceMicroscope {
        attribute primaryFunction : String =
            "Measure nanoscale surface topography by scanning a sharp probe across a sample and using feedback-controlled tip-sample interaction to reconstruct height information.";

        part probe : CantileverProbe;
        part opticalSensor : LaserAndPhotodetector;
        part scanner : PiezoelectricScanner;
        part controller : FeedbackController;
        part stage : SampleStage;
        part acquisition : DataAcquisitionAndImaging;
        part console : OperatorConsole;

        port userInput : UserCommandPort;
        port imageOutput : ImageDataPort;

        connect opticalSensor.emitter to probe.opticalInput;
        connect probe.opticalOutput to opticalSensor.receiver;
        connect opticalSensor.signalOut to controller.signalIn;
        connect opticalSensor.signalOut to acquisition.signalIn;
        connect controller.commandOut to scanner.control;
        connect scanner.probeInterface to probe.mechanical;
        connect probe.mechanical to stage.surfaceInterface;
        connect acquisition.imageOut to console.imageIn;
        connect console.commandOut to userInput;
        connect acquisition.imageOut to imageOutput;

        action def PerformAtomicForceMicroscopy {
            in request : UserScanRequest;
            out map : TopographyMap;

            first start;
            then configure;
            then approach;
            then scan;
            then regulate;
            then acquire;
            then render;
            then done;

            action configure : console.ConfigureScan;
            action approach : probe.InteractWithSurface;
            action scan : scanner.RasterScan;
            action regulate : controller.MaintainTipSampleInteraction;
            action acquire : acquisition.BuildTopographyMap;
            action render : console.DisplayTopography;
        }

        state def OperationalState {
            state poweredOff;
            state idle;
            state initializing;
            state aligningOptics;
            state loadingSample;
            state approachingSample;
            state scanning;
            state processingImage;
            state complete;
            state fault;

            transition first poweredOff;
            transition power_on first poweredOff then initializing;
            transition initialized first initializing then aligningOptics;
            transition optics_ready first aligningOptics then idle;
            transition sample_loaded first idle then loadingSample accept UserScanRequest;
            transition begin_approach first loadingSample then approachingSample;
            transition contact_detected first approachingSample then scanning;
            transition scan_finished first scanning then processingImage;
            transition image_ready first processingImage then complete;
            transition reset first complete then idle;
            transition force_limit_exceeded first scanning then fault if probe.mechanical.tipForce > 20 [nN];
            transition recover first fault then idle;
        }
    }

    requirement def PrimaryFunctionRequirement {
        doc
        /* The atomic force microscope shall determine nanoscale surface topography by raster scanning a sharp probe over a sample, sensing cantilever deflection, and controlling vertical scanner motion to maintain a specified tip-sample interaction setpoint. */

        subject afm : AtomicForceMicroscope;

        require constraint {
            afm.controller.setpointForce >= 0.05 [nN] and
            afm.controller.setpointForce <= 10 [nN]
        }
    }

    requirement def VerticalResolutionRequirement {
        doc
        /* The atomic force microscope shall resolve vertical height changes of 0.1 nm or smaller under nominal operating conditions. */

        subject afm : AtomicForceMicroscope;

        require constraint {
            afm.scanner.verticalResolution <= 0.1 [nm]
        }
    }

    requirement def ScanAreaRequirement {
        doc
        /* The atomic force microscope shall support imaging of sample areas up to at least 100 micrometers by 100 micrometers. */

        subject afm : AtomicForceMicroscope;

        require constraint {
            afm.scanner.travelX >= 100 [um] and
            afm.scanner.travelY >= 100 [um]
        }
    }

    requirement def ProbeSafetyRequirement {
        doc
        /* The atomic force microscope shall withdraw or stop scanning when the measured tip-sample force exceeds the overload threshold. */

        subject afm : AtomicForceMicroscope;

        require constraint {
            afm.probe.mechanical.tipForce <= 20 [nN]
        }
    }

    requirement def ImageOutputRequirement {
        doc
        /* The atomic force microscope shall output a topography map containing spatial coordinates and height values for each acquired pixel. */

        subject afm : AtomicForceMicroscope;

        require constraint {
            afm.acquisition.adcResolutionBits >= 16
        }
    }

    satisfy PrimaryFunctionRequirement by AtomicForceMicroscope;
    satisfy VerticalResolutionRequirement by AtomicForceMicroscope;
    satisfy ScanAreaRequirement by AtomicForceMicroscope;
    satisfy ProbeSafetyRequirement by AtomicForceMicroscope;
    satisfy ImageOutputRequirement by AtomicForceMicroscope;

    part afmSystem : AtomicForceMicroscope;

}