package OCT_System {
    private import ScalarValues::*;

    attribute def Wavelength : Real;
    attribute def OpticalPower : Real;
    attribute def ElectricalVoltage : Real;
    attribute def Frequency : Real;
    attribute def Depth : Real;
    attribute def ScanAngle : Real;
    attribute def PixelIntensity : Real;

    item def LightBeam {
        attribute wavelength : Wavelength;
        attribute power : OpticalPower;
    }

    item def InterferencePattern {
        attribute intensity : OpticalPower;
    }

    item def ElectricalSignal {
        attribute voltage : ElectricalVoltage;
        attribute frequency : Frequency;
    }

    item def DigitalData {
        attribute samples : Real[*];
    }

    item def AScan {
        attribute depthProfile : PixelIntensity[*];
    }

    item def TomographicImage;

    item def BScanImage :> TomographicImage {
        attribute pixels : PixelIntensity[*];
    }

    item def VolumetricImage :> TomographicImage {
        attribute voxels : PixelIntensity[*];
    }

    item def ScanParameters {
        attribute mode : String;
        attribute depth : Depth;
    }

    enum def SystemState {
        enum idle;
        enum calibrating;
        enum scanning;
        enum processing;
        enum fault;
    }

    port def LightPort {
        out light : LightBeam;
    }

    port def InterferencePort {
        out pattern : InterferencePattern;
    }

    port def ElectricalPort {
        out signal : ElectricalSignal;
    }

    port def DigitalDataPort {
        out data : DigitalData;
    }

    port def ImagePort {
        out image : TomographicImage;
    }

    port def ControlPort {
        out parameters : ScanParameters;
        in status : SystemState;
    }

    part def LowCoherenceSource {
        port lightOut : LightPort;
        perform emitLight {
            out light : LightBeam = lightOut.light;
        }
    }

    part def MichelsonInterferometer {
        port lightIn : ~LightPort;
        port referenceOut : LightPort;
        port sampleOut : LightPort;
        port sampleReturnIn : ~LightPort;
        port interferenceOut : InterferencePort;

        perform splitAndRecombine {
            in incomingLight : LightBeam = lightIn.light;
            out referenceBeam : LightBeam = referenceOut.light;
            out sampleBeam : LightBeam = sampleOut.light;
            in returningSample : LightBeam = sampleReturnIn.light;
            out interference : InterferencePattern = interferenceOut.pattern;
        }
    }

    part def ScanningSubsystem {
        port beamIn : ~LightPort;
        port beamOut : LightPort;
        port controlIn : ~ControlPort;

        perform steerAndFocus {
            in beam : LightBeam = beamIn.light;
            in angle : ScanAngle;
            out focusedBeam : LightBeam = beamOut.light;
        }
    }

    part def TissueSample {
        port lightIn : ~LightPort;
        port scatteredLightOut : LightPort;

        perform scatterLight {
            in incidentBeam : LightBeam = lightIn.light;
            out scatteredBeam : LightBeam = scatteredLightOut.light;
        }
    }

    part def BalancedPhotodetector {
        port interferenceIn : ~InterferencePort;
        port signalOut : ElectricalPort;

        perform detectInterference {
            in pattern : InterferencePattern = interferenceIn.pattern;
            out signal : ElectricalSignal = signalOut.signal;
        }
    }

    part def SignalAcquisitionUnit {
        port signalIn : ~ElectricalPort;
        port dataOut : DigitalDataPort;

        perform digitize {
            in analogSignal : ElectricalSignal = signalIn.signal;
            out digitalData : DigitalData = dataOut.data;
        }
    }

    part def ImageProcessingUnit {
        port dataIn : ~DigitalDataPort;
        port imageOut : ImagePort;
        port controlIn : ~ControlPort;

        perform processImage {
            in rawData : DigitalData = dataIn.data;
            in params : ScanParameters = controlIn.parameters;
            out image : TomographicImage = imageOut.image;
        }
    }

    part def ControlAndDisplayUnit {
        port controlOut : ControlPort;
        port imageIn : ~ImagePort;

        attribute currentState : SystemState = SystemState::idle;

        perform manageSystem {
            out parameters : ScanParameters = controlOut.parameters;
            in status : SystemState = controlOut.status;
            in image : TomographicImage = imageIn.image;
        }
    }

    state machine def OCTSystemState {
        state idle;
        state calibrating;
        state scanning;
        state processing;
        state fault;

        transition from idle to calibrating;
        transition from calibrating to scanning;
        transition from scanning to processing;
        transition from processing to idle;
        transition from idle to fault;
        transition from calibrating to fault;
        transition from scanning to fault;
        transition from processing to fault;
        transition from fault to idle;
    }

    part octSystem {
        part source : LowCoherenceSource;
        part interferometer : MichelsonInterferometer;
        part scanner : ScanningSubsystem;
        part sample : TissueSample;
        part detector : BalancedPhotodetector;
        part acquisition : SignalAcquisitionUnit;
        part processor : ImageProcessingUnit;
        part controller : ControlAndDisplayUnit;

        perform octStateMachine : OCTSystemState;

        connect source.lightOut to interferometer.lightIn;
        connect interferometer.sampleOut to scanner.beamIn;
        connect scanner.beamOut to sample.lightIn;
        connect sample.scatteredLightOut to interferometer.sampleReturnIn;
        connect interferometer.interferenceOut to detector.interferenceIn;
        connect detector.signalOut to acquisition.signalIn;
        connect acquisition.dataOut to processor.dataIn;
        connect processor.imageOut to controller.imageIn;
        connect controller.controlOut to scanner.controlIn;
        connect controller.controlOut to processor.controlIn;

        requirement imagingResolution {
            doc /* The system shall achieve an axial resolution of at least 10 micrometers in tissue. */
            attribute minAxialResolution : Depth = 0.01;
        }

        requirement scanSpeed {
            doc /* The system shall acquire at least 100,000 A-scans per second. */
            attribute minScanRate : Frequency = 100000.0;
        }

        requirement safetyInterlock {
            doc /* The system shall automatically transition to fault state if optical power exceeds safe limits. */
        }

        satisfy imagingResolution by processor;
        satisfy scanSpeed by acquisition;
        satisfy safetyInterlock by controller;
    }
}
