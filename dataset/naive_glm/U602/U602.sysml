package AFM {
    import ScalarValues::*;
    import ISQ::*;

    value type Length_nm > Real { unit "nm"; }
    value type Force_nN > Real { unit "nN"; }
    value type Voltage_V > Real { unit "V"; }
    value type Current_uA > Real { unit "uA"; }
    value type Frequency_kHz > Real { unit "kHz"; }
    value type Deflection_nm > Real { unit "nm"; }
    value type Coordinate_nm > Real { unit "nm"; }
    value type Time_s > Real { unit "s"; }
    value type Power_mW > Real { unit "mW"; }

    enum OperatingMode { contact, tapping, nonContact }
    enum SystemState { idle, initializing, scanning, paused, complete }

    item def LaserBeam {
        attribute power : Power_mW;
        attribute wavelength : Length_nm;
    }

    item def ReflectedBeam {
        attribute intensity : Power_mW;
        attribute spotPosition : Real;
    }

    item def DeflectionSignal {
        attribute verticalDeflection : Deflection_nm;
        attribute lateralDeflection : Deflection_nm;
        attribute timestamp : Time_s;
    }

    item def ControlSignal {
        attribute zAdjustment : Length_nm;
        attribute timestamp : Time_s;
    }

    item def HeightDataPoint {
        attribute x : Coordinate_nm;
        attribute y : Coordinate_nm;
        attribute z : Length_nm;
        attribute measuredForce : Force_nN;
        attribute timestamp : Time_s;
    }

    item def SurfaceImage {
        attribute xResolution : Integer;
        attribute yResolution : Integer;
        attribute scanArea : Length_nm;
        attribute pixelGrid : HeightDataPoint[0..*];
    }

    item def ForceMap {
        attribute xResolution : Integer;
        attribute yResolution : Integer;
        attribute forceGrid : HeightDataPoint[0..*];
    }

    port def LaserOutPort { out beam : LaserBeam; }
    port def ReflectedBeamPort { out reflected : ReflectedBeam; }
    port def DeflectionOutPort { out signal : DeflectionSignal; }
    port def ControlOutPort { out control : ControlSignal; }
    port def HeightDataOutPort { out data : HeightDataPoint; }
    port def ImageOutPort { out image : SurfaceImage; out forceMap : ForceMap; }

    part def Cantilever {
        attribute tipRadius : Length_nm = 10;
        attribute springConstant : Real = 0.5;
        attribute resonanceFrequency : Frequency_kHz = 300;
        attribute length : Length_nm = 200;
        attribute width : Length_nm = 40;
        port beamIn : LaserOutPort;
        port reflectedOut : ReflectedBeamPort;
        attribute currentDeflection : Deflection_nm;
    }

    part def PiezoScanner {
        attribute xRange : Length_nm = 90000;
        attribute yRange : Length_nm = 90000;
        attribute zRange : Length_nm = 10000;
        attribute xyResolution : Length_nm = 0.1;
        attribute zResolution : Length_nm = 0.05;
        port controlIn : ControlOutPort;
        attribute currentX : Coordinate_nm;
        attribute currentY : Coordinate_nm;
        attribute currentZ : Length_nm;
    }

    part def LaserSystem {
        attribute power : Power_mW = 5;
        attribute wavelength : Length_nm = 670;
        port beamOut : LaserOutPort;
    }

    part def Photodetector {
        attribute quadrants : Integer = 4;
        attribute sensitivity : Real = 0.1;
        port beamIn : ReflectedBeamPort;
        port signalOut : DeflectionOutPort;
    }

    part def FeedbackController {
        attribute setpoint : Deflection_nm = 0.5;
        attribute proportionalGain : Real = 10.0;
        attribute integralGain : Real = 0.5;
        attribute derivativeGain : Real = 1.0;
        attribute mode : OperatingMode = OperatingMode::contact;
        port signalIn : DeflectionOutPort;
        port controlOut : ControlOutPort;
        attribute error : Deflection_nm;
        attribute integralTerm : Deflection_nm;
        attribute derivativeTerm : Deflection_nm;
    }

    part def DataAcquisition {
        attribute samplingRate : Frequency_kHz = 100;
        port controlIn : ControlOutPort;
        port dataOut : HeightDataOutPort;
        attribute buffer : HeightDataPoint[0..*];
    }

    part def ImageProcessor {
        port dataIn : HeightDataOutPort;
        port imageOut : ImageOutPort;
        attribute currentImage : SurfaceImage;
        attribute currentForceMap : ForceMap;
    }

    part def Sample {
        attribute surfaceRoughness : Length_nm;
        attribute material : String;
        attribute size : Length_nm;
    }

    part def AFMSystem {
        attribute operatingMode : OperatingMode = OperatingMode::contact;
        attribute scanRate : Frequency_kHz = 1;
        attribute scanArea : Length_nm = 5000;
        attribute setpoint : Deflection_nm = 0.5;
        attribute state : SystemState = SystemState::idle;

        part cantilever : Cantilever;
        part scanner : PiezoScanner;
        part laser : LaserSystem;
        part detector : Photodetector;
        part controller : FeedbackController;
        part daq : DataAcquisition;
        part processor : ImageProcessor;
        part sample : Sample;

        connection laserToCantilever connect laser.beamOut to cantilever.beamIn;
        connection cantileverToDetector connect cantilever.reflectedOut to detector.beamIn;
        connection detectorToController connect detector.signalOut to controller.signalIn;
        connection controllerToScanner connect controller.controlOut to scanner.controlIn;
        connection controllerToDAQ connect controller.controlOut to daq.controlIn;
        connection daqToProcessor connect daq.dataOut to processor.dataIn;

        action def PerformRasterScan {
            in scanArea : Length_nm;
            in scanRate : Frequency_kHz;
            out dataPoints : HeightDataPoint[0..*];
            attribute xStep : Length_nm = 1.0;
            attribute yStep : Length_nm = 1.0;
            start;
            then scanLine;
            action scanLine {
                attribute currentX : Coordinate_nm;
            }
            then scanNext;
            action scanNext {
                attribute currentY : Coordinate_nm;
            }
            then checkComplete;
            action checkComplete;
            then done scanLine if (currentY >= scanArea);
            then scanLine if (currentY < scanArea);
        }

        action def FeedbackControlLoop {
            in measuredDeflection : DeflectionSignal;
            in setpoint : Deflection_nm;
            out controlSignal : ControlSignal;
            start;
            then computeError;
            action computeError {
                attribute error : Deflection_nm = measuredDeflection.verticalDeflection - setpoint;
            }
            then computePID;
            action computePID {
                attribute pTerm : Deflection_nm;
                attribute iTerm : Deflection_nm;
                attribute dTerm : Deflection_nm;
            }
            then generateControl;
            action generateControl;
            then done;
        }

        state def AFMStateMachine {
            attribute activeMode : OperatingMode;
            entry; then idle;
            state idle;
            transition idle to initializing when startCommand;
            state initializing {
                entry action { controller.setpoint = setpoint; }
                do action { laser.power = 5; }
            }
            transition initializing to scanning when readySignal;
            state scanning {
                entry action { state = SystemState::scanning; }
                do PerformRasterScan;
                state feedbackActive {
                    do FeedbackControlLoop;
                }
            }
            transition scanning to paused when pauseCommand;
            transition paused to scanning when resumeCommand;
            transition scanning to complete when scanComplete;
            state complete {
                entry action { processor.currentImage = SurfaceImage{ xResolution = 512; yResolution = 512; scanArea = scanArea; }; }
            }
            transition complete to idle when resetCommand;
        }

        requirement def ResolutionRequirement {
            subject afmSystem : AFMSystem;
            objective {
                doc /* The AFM shall achieve sub-nanometer vertical resolution. */
                afmSystem.scanner.zResolution <= 0.5
            }
        }

        requirement def TopographyRequirement {
            subject afmSystem : AFMSystem;
            objective {
                doc /* The AFM shall generate 3D topographical maps of sample surfaces. */
                afmSystem.processor.currentImage.xResolution >= 256 and
                afmSystem.processor.currentImage.yResolution >= 256
            }
        }

        requirement def ForceMeasurementRequirement {
            subject afmSystem : AFMSystem;
            objective {
                doc /* The AFM shall measure mechanical properties by analyzing tip-sample forces. */
                afmSystem.processor.currentForceMap.forceGrid->size() > 0
            }
        }

        requirement def FeedbackRequirement {
            subject afmSystem : AFMSystem;
            objective {
                doc /* The feedback controller shall maintain constant gentle force between tip and sample. */
                afmSystem.controller.setpoint <= 1.0
            }
        }

        requirement def ModeConfigurabilityRequirement {
            subject afmSystem : AFMSystem;
            objective {
                doc /* The AFM shall be configurable for contact, tapping, or non-contact modes. */
                afmSystem.operatingMode in {OperatingMode::contact, OperatingMode::tapping, OperatingMode::nonContact}
            }
        }

        part resolutionReq : ResolutionRequirement { subject = AFMSystem; }
        part topographyReq : TopographyRequirement { subject = AFMSystem; }
        part forceReq : ForceMeasurementRequirement { subject = AFMSystem; }
        part feedbackReq : FeedbackRequirement { subject = AFMSystem; }
        part modeReq : ModeConfigurabilityRequirement { subject = AFMSystem; }
    }
}
