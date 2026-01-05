package ScanningLaserOphthalmoscopySystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def LaserWavelength :> ISQ::LengthValue;
    attribute def ScanFrequency :> ISQ::FrequencyValue;
    attribute def OpticalPower :> ISQ::PowerValue;
    attribute def ScanAngle :> ISQ::PlaneAngleValue;
    attribute def IntensityValue :> ScalarValues::Real;
    attribute def PixelCoordinate {
        attribute x : Integer;
        attribute y : Integer;
    }
    attribute def ImageResolution {
        attribute width : Integer;
        attribute height : Integer;
    }

    item def LaserBeam {
        attribute wavelength : LaserWavelength;
        attribute power : OpticalPower;
        attribute beamDiameter : ISQ::LengthValue;
    }

    item def ReflectedLight {
        attribute intensity : IntensityValue;
        attribute wavelength : LaserWavelength;
    }

    item def RetinalImage {
        attribute resolution : ImageResolution;
        attribute pixelData : IntensityValue[*];
        attribute acquisitionTime : ISQ::TimeValue;
    }

    attribute def ScanCommand {
        attribute horizontalAngle : ScanAngle;
        attribute verticalAngle : ScanAngle;
    }

    attribute def DetectorSignal {
        attribute voltage : ISQ::ElectricPotentialValue;
        attribute timestamp : ISQ::TimeValue;
    }

    port def LaserOutputPort {
        out beam : LaserBeam;
    }

    port def LaserInputPort {
        in beam : LaserBeam;
    }

    port def ScanControlPort {
        in scanCmd : ScanCommand;
    }

    port def OpticalOutputPort {
        out scannedBeam : LaserBeam;
    }

    port def LightDetectionPort {
        in reflectedLight : ReflectedLight;
        out signal : DetectorSignal;
    }

    port def ImageOutputPort {
        out image : RetinalImage;
    }

    part def LaserSource {
        doc /* Generates coherent laser light at specified wavelength and power */
        attribute operatingWavelength : LaserWavelength = 785.0 [nm];
        attribute outputPower : OpticalPower = 1.5 [mW];
        attribute beamQuality : Real;
        port laserOut : LaserOutputPort;
    }

    part def ScanningMirrorSystem {
        doc /* Deflects laser beam in raster pattern across retinal surface */
        attribute horizontalScanRate : ScanFrequency = 16000.0 [Hz];
        attribute verticalScanRate : ScanFrequency = 30.0 [Hz];
        attribute maxScanAngle : ScanAngle = 20.0 [deg];
        port beamIn : LaserInputPort;
        port scanControl : ScanControlPort;
        port beamOut : OpticalOutputPort;
    }

    part def OpticalSystem {
        doc /* Focuses and relays laser beam to retina and collects reflected light */
        attribute focalLength : ISQ::LengthValue = 50.0 [mm];
        attribute numericalAperture : Real = 0.3;
        attribute magnification : Real = 1.0;
        port incidentBeam : LaserInputPort;
        port focusedBeamOut : LaserOutputPort;
        port reflectedLightIn : LaserInputPort;
        port collectedLightOut : LaserOutputPort;
    }

    part def ConfocalAperture {
        doc /* Spatial filter to reject out-of-focus light */
        attribute apertureDiameter : ISQ::LengthValue = 50.0 [μm];
        port lightIn : LaserInputPort;
        port filteredLightOut : LaserOutputPort;
    }

    part def Photodetector {
        doc /* Converts optical signal to electrical signal */
        attribute responsivity : Real = 0.6;
        attribute bandwidth : ScanFrequency = 100.0 [kHz];
        port detection : LightDetectionPort;
    }

    part def SignalProcessor {
        doc /* Digitizes and processes detector signals into image */
        attribute samplingRate : ScanFrequency = 200.0 [kHz];
        attribute bitDepth : Integer = 12;
        attribute imageWidth : Integer = 512;
        attribute imageHeight : Integer = 512;
        port signalIn : LightDetectionPort;
        port imageOut : ImageOutputPort;
    }

    part def ScanController {
        doc /* Generates synchronized scan patterns for mirror system */
        attribute scanPattern : ImageResolution {
            attribute width = 512;
            attribute height = 512;
        }
        port scanCommandOut : ScanControlPort;
    }

    state def ScanningStateMachine {
        entry; then idle;
        
        state idle;
        accept StartAcquisition then initializing;
        
        state initializing;
        accept SystemReady then aligning;
        
        state aligning;
        accept AlignmentComplete then scanning;
        
        state scanning;
        accept ScanComplete then processingImage;
        
        state processingImage;
        accept ImageProcessed then imageReady;
        
        state imageReady;
        accept ImageRetrieved then idle;
    }

    action def GenerateLaserBeam {
        in powerSetting : OpticalPower;
        out laserBeam : LaserBeam;
    }

    action def DeflectBeam {
        in inputBeam : LaserBeam;
        in scanPosition : ScanCommand;
        out deflectedBeam : LaserBeam;
    }

    action def FocusBeamOnRetina {
        in collimatedBeam : LaserBeam;
        out focusedBeam : LaserBeam;
    }

    action def CollectReflectedLight {
        in incidentBeam : LaserBeam;
        out reflectedLight : ReflectedLight;
    }

    action def FilterLight {
        in unfilteredLight : ReflectedLight;
        out filteredLight : ReflectedLight;
    }

    action def DetectLight {
        in lightSignal : ReflectedLight;
        out electricalSignal : DetectorSignal;
    }

    action def DigitizeSignal {
        in analogSignal : DetectorSignal;
        in scanPosition : PixelCoordinate;
        out pixelValue : IntensityValue;
    }

    action def AssembleImage {
        in pixelStream : IntensityValue[*];
        in resolution : ImageResolution;
        out retinalImage : RetinalImage;
    }

    action def AcquireRetinalImage {
        doc /* Main imaging workflow: scan laser across retina and build image from reflected light */
        in scanResolution : ImageResolution;
        out finalImage : RetinalImage;

        private attribute currentPixel : PixelCoordinate;
        private attribute pixelBuffer : IntensityValue[*] := ();
        private attribute totalPixels : Integer := scanResolution.width * scanResolution.height;
        private attribute pixelCount : Integer := 0;

        first start;
        then action initLaser : GenerateLaserBeam {
            in powerSetting = 1.5 [mW];
            out laserBeam;
        }
        then merge scanLoop;

        action scanLoop {
            action generateScanPosition {
                out position : ScanCommand;
            }
            then action deflect : DeflectBeam {
                in inputBeam = initLaser.laserBeam;
                in scanPosition = generateScanPosition.position;
                out deflectedBeam;
            }
            then action focus : FocusBeamOnRetina {
                in collimatedBeam = deflect.deflectedBeam;
                out focusedBeam;
            }
            then action collect : CollectReflectedLight {
                in incidentBeam = focus.focusedBeam;
                out reflectedLight;
            }
            then action filter : FilterLight {
                in unfilteredLight = collect.reflectedLight;
                out filteredLight;
            }
            then action detect : DetectLight {
                in lightSignal = filter.filteredLight;
                out electricalSignal;
            }
            then action digitize : DigitizeSignal {
                in analogSignal = detect.electricalSignal;
                in scanPosition = currentPixel;
                out pixelValue;
            }
            then assign pixelBuffer := pixelBuffer->including(digitize.pixelValue);
            then assign pixelCount := pixelCount + 1;
            then decide;
                if pixelCount < totalPixels then continueScanning;
                if pixelCount >= totalPixels then completeImage;

            action continueScanning;
            then scanLoop;

            action completeImage : AssembleImage {
                in pixelStream = pixelBuffer;
                in resolution = scanResolution;
                out retinalImage;
            }
            then done;
        }
    }

    part def ScanningLaserOphthalmoscope {
        doc /* 
            A scanning laser ophthalmoscope (SLO) generates high-resolution images of the retina
            by raster-scanning a focused laser beam across the retinal surface and detecting
            the reflected light point-by-point through a confocal aperture. This confocal
            configuration provides optical sectioning and enhanced contrast by rejecting
            out-of-focus scattered light.
        */

        attribute systemWavelength : LaserWavelength = 785.0 [nm];
        attribute imagingResolution : ImageResolution {
            attribute width = 512;
            attribute height = 512;
        }
        attribute fieldOfView : ScanAngle = 20.0 [deg];
        attribute frameRate : ScanFrequency = 30.0 [Hz];

        part laser : LaserSource {
            attribute operatingWavelength = systemWavelength;
        }

        part scanController : ScanController {
            attribute scanPattern = imagingResolution;
        }

        part scanMirrors : ScanningMirrorSystem {
            attribute maxScanAngle = fieldOfView;
        }

        part optics : OpticalSystem;

        part aperture : ConfocalAperture;

        part detector : Photodetector;

        part processor : SignalProcessor {
            attribute imageWidth = imagingResolution.width;
            attribute imageHeight = imagingResolution.height;
        }

        state systemState : ScanningStateMachine;

        connect laser.laserOut to scanMirrors.beamIn;
        connect scanController.scanCommandOut to scanMirrors.scanControl;
        connect scanMirrors.beamOut to optics.incidentBeam;
        connect optics.focusedBeamOut to optics.reflectedLightIn;
        connect optics.collectedLightOut to aperture.lightIn;
        connect aperture.filteredLightOut to detector.detection;
        connect detector.detection to processor.signalIn;

        perform action imaging : AcquireRetinalImage {
            in scanResolution = imagingResolution;
            out finalImage;
        }
    }

    requirement def FunctionalRequirement;
    requirement def PerformanceRequirement;
    requirement def SafetyRequirement;
    requirement def OpticalRequirement;

    requirement <'SLO-REQ-001'> primaryFunction : FunctionalRequirement {
        doc /* 
            The scanning laser ophthalmoscope shall generate high-resolution, real-time
            images of the retina by raster-scanning a focused laser beam across the
            retinal surface and detecting the reflected light through a confocal aperture
            to provide optical sectioning and enhanced image contrast.
        */
        subject slo : ScanningLaserOphthalmoscope;
    }

    requirement <'SLO-REQ-002'> imageResolution : PerformanceRequirement {
        doc /* The system shall produce retinal images with minimum resolution of 512x512 pixels */
        subject slo : ScanningLaserOphthalmoscope;
        require constraint {
            slo.imagingResolution.width >= 512 and slo.imagingResolution.height >= 512
        }
    }

    requirement <'SLO-REQ-003'> frameRateReq : PerformanceRequirement {
        doc /* The system shall acquire images at minimum 30 frames per second for real-time viewing */
        subject slo : ScanningLaserOphthalmoscope;
        require constraint {
            slo.frameRate >= 30.0 [Hz]
        }
    }

    requirement <'SLO-REQ-004'> laserSafety : SafetyRequirement {
        doc /* Laser power shall not exceed maximum permissible exposure for retinal safety */
        subject slo : ScanningLaserOphthalmoscope;
        require constraint {
            slo.laser.outputPower <= 2.0 [mW]
        }
    }

    requirement <'SLO-REQ-005'> confocalImaging : OpticalRequirement {
        doc /* System shall use confocal detection to reject out-of-focus light */
        subject slo : ScanningLaserOphthalmoscope;
        require constraint {
            slo.aperture.apertureDiameter <= 100.0 [μm]
        }
    }

    requirement <'SLO-REQ-006'> fieldOfViewReq : OpticalRequirement {
        doc /* System shall provide minimum 20 degree field of view */
        subject slo : ScanningLaserOphthalmoscope;
        require constraint {
            slo.fieldOfView >= 20.0 [deg]
        }
    }

    requirement <'SLO-SYS-001'> systemRequirements {
        doc /* 
            Overall system requirements for scanning laser ophthalmoscope
            to enable clinical retinal imaging with high resolution and safety
        */
        require primaryFunction;
        require imageResolution;
        require frameRateReq;
        require laserSafety;
        require confocalImaging;
        require fieldOfViewReq;
    }

    part sloSystem : ScanningLaserOphthalmoscope;
}
