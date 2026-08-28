package SLO {
    public import ScalarValues::*;
    public import SI::*;

    // ---- Value Types with Units ----
    value type Wavelength :> Real { unit "nm"; }
    value type OpticalPower :> Real { unit "mW"; }
    value type FrameRate :> Real { unit "fps"; }
    value type FieldOfView :> Real { unit "deg"; }
    value type Voltage :> Real { unit "V"; }
    value type Current :> Real { unit "uA"; }
    value type Duration :> Real { unit "s"; }
    value type Length :> Real { unit "um"; }
    value type PixelValue :> Integer;
    value type PixelCoordinate :> Integer;

    // ---- Item Definitions ----
    item def LaserBeam {
        attribute wavelength : Wavelength;
        attribute power : OpticalPower;
        attribute coherent : Boolean;
    }

    item def ScannedBeam {
        attribute wavelength : Wavelength;
        attribute power : OpticalPower;
        attribute x : PixelCoordinate;
        attribute y : PixelCoordinate;
    }

    item def RetinalSpot {
        attribute x : PixelCoordinate;
        attribute y : PixelCoordinate;
        attribute wavelength : Wavelength;
        attribute power : OpticalPower;
    }

    item def ReflectedLight {
        attribute intensity : OpticalPower;
        attribute inFocus : Boolean;
        attribute x : PixelCoordinate;
        attribute y : PixelCoordinate;
    }

    item def FilteredLight {
        attribute intensity : OpticalPower;
        attribute x : PixelCoordinate;
        attribute y : PixelCoordinate;
    }

    item def ScanControlSignal {
        attribute horizontalDrive : Voltage;
        attribute verticalDrive : Voltage;
        attribute x : PixelCoordinate;
        attribute y : PixelCoordinate;
    }

    item def AnalogSignal {
        attribute voltage : Voltage;
        attribute x : PixelCoordinate;
        attribute y : PixelCoordinate;
        attribute timestamp : Duration;
    }

    item def DigitalSample {
        attribute pixelValue : PixelValue;
        attribute x : PixelCoordinate;
        attribute y : PixelCoordinate;
    }

    item def DigitalImage {
        attribute width : Integer = 512;
        attribute height : Integer = 512;
        attribute frameNumber : Integer;
        attribute samples : DigitalSample[0..*];
    }

    // ---- Port Definitions ----
    port def LaserOutPort {
        out beam : LaserBeam;
    }

    port def LaserInPort {
        in beam : LaserBeam;
    }

    port def ScannedBeamOutPort {
        out beam : ScannedBeam;
    }

    port def ScannedBeamInPort {
        in beam : ScannedBeam;
    }

    port def ScanControlOutPort {
        out signal : ScanControlSignal;
    }

    port def ScanControlInPort {
        in signal : ScanControlSignal;
    }

    port def RetinalSpotOutPort {
        out spot : RetinalSpot;
    }

    port def RetinalSpotInPort {
        in spot : RetinalSpot;
    }

    port def ReflectedLightOutPort {
        out light : ReflectedLight;
    }

    port def ReflectedLightInPort {
        in light : ReflectedLight;
    }

    port def FilteredLightOutPort {
        out light : FilteredLight;
    }

    port def FilteredLightInPort {
        in light : FilteredLight;
    }

    port def AnalogSignalOutPort {
        out signal : AnalogSignal;
    }

    port def AnalogSignalInPort {
        in signal : AnalogSignal;
    }

    port def DigitalSampleOutPort {
        out sample : DigitalSample;
    }

    port def DigitalSampleInPort {
        in sample : DigitalSample;
    }

    port def DigitalImageOutPort {
        out image : DigitalImage;
    }

    // ---- Part Definitions ----
    part def LaserSource {
        attribute wavelength : Wavelength = 785;
        attribute nominalPower : OpticalPower = 0.5;
        attribute maxSafePower : OpticalPower = 1.0;
        attribute stable : Boolean = false;

        port laserOut : LaserOutPort;

        exhibit state behavior LaserSourceStates {
            entry; then Off;
            state Off;
            transition off_to_Warming
                first Off
                if powerApplied
                then Warming;
            state Warming;
            transition warming_to_Stable
                first Warming
                if stabilizationComplete
                then Stable;
            state Stable {
                entry {
                    self.stable := true;
                    send LaserBeam(
                        wavelength := self.wavelength,
                        power := self.nominalPower,
                        coherent := true
                    ) to laserOut;
                }
                do {
                    send LaserBeam(
                        wavelength := self.wavelength,
                        power := self.nominalPower,
                        coherent := true
                    ) to laserOut;
                }
            }
            transition stable_to_Off
                first Stable
                if shutdown
                then Off;
        }

        private powerApplied : Boolean;
        private stabilizationComplete : Boolean;
        private shutdown : Boolean;
    }

    part def ScanController {
        attribute frameRate : FrameRate = 30;
        attribute horizontalResolution : Integer = 512;
        attribute verticalResolution : Integer = 512;
        attribute fieldOfView : FieldOfView = 20;
        attribute currentX : PixelCoordinate = 0;
        attribute currentY : PixelCoordinate = 0;
        attribute currentFrame : Integer = 0;

        port scanControlOut : ScanControlOutPort;

        exhibit action generateRasterScan {
            perform {
                while currentFrame < 1 {
                    while currentY < verticalResolution {
                        while currentX < horizontalResolution {
                            send ScanControlSignal(
                                horizontalDrive := (currentX / horizontalResolution) * 10.0,
                                verticalDrive := (currentY / verticalResolution) * 10.0,
                                x := currentX,
                                y := currentY
                            ) to scanControlOut;
                            currentX := currentX + 1;
                        }
                        currentX := 0;
                        currentY := currentY + 1;
                    }
                    currentY := 0;
                    currentFrame := currentFrame + 1;
                }
            }
        }
    }

    part def ScanningMirrorSystem {
        attribute horizontalMirrorAngle : Real;
        attribute verticalMirrorAngle : Real;
        attribute horizontalResolution : Integer = 512;
        attribute verticalResolution : Integer = 512;

        port driveIn : ScanControlInPort;
        port laserIn : LaserInPort;
        port scannedBeamOut : ScannedBeamOutPort;

        exhibit action deflectBeam {
            in controlSignal : ScanControlSignal;
            in incomingBeam : LaserBeam;
            out outgoingBeam : ScannedBeam;
            perform {
                horizontalMirrorAngle := controlSignal.horizontalDrive;
                verticalMirrorAngle := controlSignal.verticalDrive;
                send ScannedBeam(
                    wavelength := incomingBeam.wavelength,
                    power := incomingBeam.power,
                    x := controlSignal.x,
                    y := controlSignal.y
                ) to scannedBeamOut;
            }
        }
    }

    part def OpticalSystem {
        attribute focalLength : Length = 25.0;
        attribute numericalAperture : Real = 0.2;

        port scannedBeamIn : ScannedBeamInPort;
        port retinalSpotOut : RetinalSpotOutPort;
        port reflectedLightIn : ReflectedLightInPort;
        port reflectedLightOut : ReflectedLightOutPort;

        exhibit action focusBeam {
            in scannedBeam : ScannedBeam;
            out retinalSpot : RetinalSpot;
            perform {
                send RetinalSpot(
                    x := scannedBeam.x,
                    y := scannedBeam.y,
                    wavelength := scannedBeam.wavelength,
                    power := scannedBeam.power * 0.9
                ) to retinalSpotOut;
            }
        }

        exhibit action collectReflectedLight {
            in spot : RetinalSpot;
            out reflected : ReflectedLight;
            perform {
                send ReflectedLight(
                    intensity := spot.power * 0.3,
                    inFocus := true,
                    x := spot.x,
                    y := spot.y
                ) to reflectedLightOut;
            }
        }
    }

    part def ConfocalAperture {
        attribute pinholeDiameter : Length = 50.0;
        attribute spatialFilterEnabled : Boolean = true;

        port lightIn : ReflectedLightInPort;
        port lightOut : FilteredLightOutPort;

        exhibit action filterLight {
            in reflected : ReflectedLight;
            out filtered : FilteredLight;
            perform {
                if reflected.inFocus {
                    send FilteredLight(
                        intensity := reflected.intensity * 0.8,
                        x := reflected.x,
                        y := reflected.y
                    ) to lightOut;
                } else {
                    send FilteredLight(
                        intensity := reflected.intensity * 0.05,
                        x := reflected.x,
                        y := reflected.y
                    ) to lightOut;
                }
            }
        }
    }

    part def Photodetector {
        attribute sensitivity : Real = 0.5; // V per mW
        attribute darkCurrent : Current = 0.001;
        attribute gain : Real = 100.0;

        port lightIn : FilteredLightInPort;
        port signalOut : AnalogSignalOutPort;

        exhibit action convertLightToSignal {
            in filtered : FilteredLight;
            out analog : AnalogSignal;
            perform {
                send AnalogSignal(
                    voltage := filtered.intensity * sensitivity * gain,
                    x := filtered.x,
                    y := filtered.y,
                    timestamp := 0.0
                ) to signalOut;
            }
        }
    }

    part def SignalProcessor {
        attribute adcResolution : Integer = 12;
        attribute maxPixelValue : PixelValue = 4095;
        attribute frameWidth : Integer = 512;
        attribute frameHeight : Integer = 512;
        attribute currentFrameNumber : Integer = 0;
        attribute collectedSamples : DigitalSample[0..*];

        port signalIn : AnalogSignalInPort;
        port sampleOut : DigitalSampleOutPort;
        port imageOut : DigitalImageOutPort;

        exhibit action digitizeSignal {
            in analog : AnalogSignal;
            out sample : DigitalSample;
            perform {
                send DigitalSample(
                    pixelValue := min(maxPixelValue, (analog.voltage * 400.0) as PixelValue),
                    x := analog.x,
                    y := analog.y
                ) to sampleOut;
            }
        }

        exhibit action assembleImage {
            in samples : DigitalSample[0..*];
            out image : DigitalImage;
            perform {
                send DigitalImage(
                    width := frameWidth,
                    height := frameHeight,
                    frameNumber := currentFrameNumber,
                    samples := samples
                ) to imageOut;
                currentFrameNumber := currentFrameNumber + 1;
            }
        }
    }

    part def SystemController {
        attribute frameRate : FrameRate = 30;
        attribute safetyInterlockEngaged : Boolean = false;
        attribute patientAligned : Boolean = false;
        attribute imageReady : Boolean = false;

        exhibit state behavior SystemStateMachine {
            entry; then Initializing;
            state Initializing {
                entry {
                    safetyInterlockEngaged := true;
                }
                do {
                    // perform self-test and calibration
                }
            }
            transition init_to_Aligning
                first Initializing
                if selfTestComplete
                then Aligning;
            state Aligning {
                entry {
                    patientAligned := false;
                }
                do {
                    // align optical axis with patient's eye
                }
            }
            transition align_to_Scanning
                first Aligning
                if patientAligned
                then ActiveScanning;
            state ActiveScanning {
                entry {
                    imageReady := false;
                }
                do {
                    // drive scan controller and acquire image data
                }
            }
            transition scan_to_Processing
                first ActiveScanning
                if scanComplete
                then Processing;
            state Processing {
                entry {
                    // digitize and assemble image
                }
            }
            transition process_to_ImageReady
                first Processing
                if processingComplete
                then ImageReady;
            state ImageReady {
                entry {
                    imageReady := true;
                }
            }
            transition ready_to_Scanning
                first ImageReady
                if requestNextFrame
                then ActiveScanning;
            transition any_to_SafetyShutdown
                first Initializing, Aligning, ActiveScanning, Processing, ImageReady
                if safetyViolation
                then SafetyShutdown;
            state SafetyShutdown {
                entry {
                    safetyInterlockEngaged := false;
                }
            }
        }

        private selfTestComplete : Boolean;
        private scanComplete : Boolean;
        private processingComplete : Boolean;
        private requestNextFrame : Boolean;
        private safetyViolation : Boolean;
    }

    // ---- Top-Level SLO Part ----
    part def ScanningLaserOphthalmoscope {
        attribute systemFrameRate : FrameRate = 30;
        attribute fieldOfView : FieldOfView = 20;
        attribute imageWidth : Integer = 512;
        attribute imageHeight : Integer = 512;
        attribute laserWavelength : Wavelength = 785;
        attribute maxLaserPower : OpticalPower = 1.0;

        part laserSource : LaserSource {
            attribute wavelength : Wavelength = 785;
            attribute nominalPower : OpticalPower = 0.5;
        }

        part scanController : ScanController {
            attribute frameRate : FrameRate = 30;
            attribute horizontalResolution : Integer = 512;
            attribute verticalResolution : Integer = 512;
            attribute fieldOfView : FieldOfView = 20;
        }

        part mirrorSystem : ScanningMirrorSystem {
            attribute horizontalResolution : Integer = 512;
            attribute verticalResolution : Integer = 512;
        }

        part opticalSystem : OpticalSystem {
            attribute focalLength : Length = 25.0;
        }

        part confocalAperture : ConfocalAperture {
            attribute pinholeDiameter : Length = 50.0;
        }

        part photodetector : Photodetector {
            attribute sensitivity : Real = 0.5;
            attribute gain : Real = 100.0;
        }

        part signalProcessor : SignalProcessor {
            attribute adcResolution : Integer = 12;
            attribute frameWidth : Integer = 512;
            attribute frameHeight : Integer = 512;
        }

        part systemController : SystemController {
            attribute frameRate : FrameRate = 30;
        }

        // Connections
        connection laserToMirrors connect laserSource.laserOut to mirrorSystem.laserIn;
        connection scanControlToMirrors connect scanController.scanControlOut to mirrorSystem.driveIn;
        connection mirrorsToOptics connect mirrorSystem.scannedBeamOut to opticalSystem.scannedBeamIn;
        connection opticsToRetina connect opticalSystem.retinalSpotOut to opticalSystem.reflectedLightIn;
        connection opticsToAperture connect opticalSystem.reflectedLightOut to confocalAperture.lightIn;
        connection apertureToDetector connect confocalAperture.lightOut to photodetector.lightIn;
        connection detectorToProcessor connect photodetector.signalOut to signalProcessor.signalIn;

        port imageOutput : DigitalImageOutPort;

        connection processorToOutput connect signalProcessor.imageOut to imageOutput;
    }

    // ---- Requirements ----
    requirement def LaserSafetyRequirement {
        doc "The SLO must adhere to strict laser safety standards to protect patient vision.";
        attribute maxRetinalExposure : OpticalPower = 1.0;
        subject slo : ScanningLaserOphthalmoscope;
        constraint { slo.laserSource.nominalPower <= maxRetinalExposure }
    }

    requirement def ResolutionRequirement {
        doc "The SLO must produce images with at least 512x512 pixel resolution.";
        attribute minWidth : Integer = 512;
        attribute minHeight : Integer = 512;
        subject image : DigitalImage;
        constraint { image.width >= minWidth and image.height >= minHeight }
    }

    requirement def FrameRateRequirement {
        doc "The SLO must operate at 30 frames per second for live viewing.";
        attribute minFrameRate : FrameRate = 30;
        subject slo : ScanningLaserOphthalmoscope;
        constraint { slo.systemFrameRate >= minFrameRate }
    }

    requirement def FieldOfViewRequirement {
        doc "The SLO must cover a 20-degree field of view on the retina.";
        attribute targetFOV : FieldOfView = 20;
        subject slo : ScanningLaserOphthalmoscope;
        constraint { slo.fieldOfView >= targetFOV }
    }

    requirement def WavelengthRequirement {
        doc "The laser source must emit at 785 nm wavelength.";
        attribute targetWavelength : Wavelength = 785;
        subject laser : LaserSource;
        constraint { laser.wavelength == targetWavelength }
    }

    requirement def ConfocalFilteringRequirement {
        doc "The confocal aperture must block out-of-focus light to produce sharp, high-contrast images.";
        subject aperture : ConfocalAperture;
        constraint { aperture.spatialFilterEnabled == true }
    }

    requirement def StateMachineRequirement {
        doc "The system controller must manage phases: initializing, aligning, active scanning, processing, and image ready.";
        subject controller : SystemController;
        constraint {
            controller.SystemStateMachine.Initializing.exists and
            controller.SystemStateMachine.Aligning.exists and
            controller.SystemStateMachine.ActiveScanning.exists and
            controller.SystemStateMachine.Processing.exists and
            controller.SystemStateMachine.ImageReady.exists
        }
    }

    // ---- Requirement Satisfaction ----
    satisfaction satisfyLaserSafety by ScanningLaserOphthalmoscope satisfies LaserSafetyRequirement;
    satisfaction satisfyResolution by DigitalImage satisfies ResolutionRequirement;
    satisfaction satisfyFrameRate by ScanningLaserOphthalmoscope satisfies FrameRateRequirement;
    satisfaction satisfyFOV by ScanningLaserOphthalmoscope satisfies FieldOfViewRequirement;
    satisfaction satisfyWavelength by LaserSource satisfies WavelengthRequirement;
    satisfaction satisfyConfocal by ConfocalAperture satisfies ConfocalFilteringRequirement;
    satisfaction satisfyStateMachine by SystemController satisfies StateMachineRequirement;
}
