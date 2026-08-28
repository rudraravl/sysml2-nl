package SLO_System {
    private import ScalarValues::*;

    package Definitions {
        attribute def WavelengthValue :> Real;
        attribute def LaserPowerValue :> Real;
        attribute def VoltageValue :> Real;
        attribute def FrameRateValue :> Real;
        attribute def ScanAngleValue :> Real;
        attribute def SpotSizeValue :> Real;
        attribute def LightIntensityValue :> Real;

        attribute def 'Initialize Signal';
        attribute def 'Alignment Complete Signal';
        attribute def 'Start Scan Signal';
        attribute def 'Stop Scan Signal';
        attribute def 'Image Ready Signal';
        attribute def 'Emergency Stop Signal';

        attribute def ScanCommand {
            attribute horizontalOffset : Real;
            attribute verticalOffset : Real;
        }

        attribute def ScanDriveSignal {
            attribute horizontalDrive : VoltageValue;
            attribute verticalDrive : VoltageValue;
        }

        attribute def AnalogSignal {
            attribute voltage : VoltageValue;
        }

        attribute def PixelValue {
            attribute row : Integer;
            attribute column : Integer;
            attribute intensity : Integer;
        }

        item def LaserBeam {
            attribute wavelength : WavelengthValue = 785;
            attribute power : LaserPowerValue = 5.0;
            attribute isCoherent : Boolean = true;
        }

        item def ScannedBeam {
            ref item beam : LaserBeam;
            attribute horizontalAngle : ScanAngleValue;
            attribute verticalAngle : ScanAngleValue;
        }

        item def ReflectedLight {
            attribute intensity : LightIntensityValue;
            attribute isInFocus : Boolean;
        }

        item def FilteredLight {
            attribute intensity : LightIntensityValue;
        }

        item def RetinalImage {
            attribute width : Integer = 512;
            attribute height : Integer = 512;
            attribute frameRate : FrameRateValue = 30;
            attribute fieldOfView : ScanAngleValue = 20;
            attribute pixel : PixelValue[0..*];
        }

        action def 'Generate Laser Beam' {
            out laserBeam : LaserBeam;
        }

        action def 'Generate Scan Drive' {
            in scanCommand : ScanCommand;
            out scanDrive : ScanDriveSignal;
        }

        action def 'Deflect Beam' {
            in laserBeam : LaserBeam;
            in scanDrive : ScanDriveSignal;
            out scannedBeam : ScannedBeam;
        }

        action def 'Focus and Collect' {
            in scannedBeam : ScannedBeam;
            out reflectedLight : ReflectedLight;
        }

        action def 'Apply Confocal Aperture' {
            in reflectedLight : ReflectedLight;
            out filteredLight : FilteredLight;
        }

        action def 'Detect Light' {
            in filteredLight : FilteredLight;
            out analogSignal : AnalogSignal;
        }

        action def 'Digitize Signal' {
            in analogSignal : AnalogSignal;
            out pixelValue : PixelValue;
        }

        action def 'Assemble Image' {
            in pixelValues : PixelValue[0..*];
            out retinalImage : RetinalImage;
        }

        action def 'Perform Imaging Cycle' {
            in scanCommand : ScanCommand;
            out retinalImage : RetinalImage;
        }

        action def 'Initialize Hardware';
        action def 'Align with Eye';
        action def 'Process Image';
        action def 'Output Image';

        state def 'SLO States';

        part def LaserSource {
            out item beam : LaserBeam;
        }

        part def ScanController {
            out item scanDrive : ScanDriveSignal;
        }

        part def ScanningMirrorSystem {
            in item beam : LaserBeam;
            in item scanDrive : ScanDriveSignal;
            out item scannedBeam : ScannedBeam;
        }

        part def OpticalSystem {
            in item scannedBeam : ScannedBeam;
            out item reflectedLight : ReflectedLight;
        }

        part def ConfocalAperture {
            attribute pinholeDiameter : SpotSizeValue = 50;
            in item reflectedLight : ReflectedLight;
            out item filteredLight : FilteredLight;
        }

        part def Photodetector {
            in item filteredLight : FilteredLight;
            out item analogSignal : AnalogSignal;
        }

        part def SignalProcessor {
            in item analogSignal : AnalogSignal;
            out item retinalImage : RetinalImage;
        }

        part def SLOController {
            exhibit state 'slo states' : 'SLO States';
        }

        part def SLO {
            ref item patientEye;
            item images : RetinalImage[0..*];
            part laserSource : LaserSource;
            part scanController : ScanController;
            part scanningMirrorSystem : ScanningMirrorSystem;
            part opticalSystem : OpticalSystem;
            part confocalAperture : ConfocalAperture;
            part photodetector : Photodetector;
            part signalProcessor : SignalProcessor;
            part sloController : SLOController;
        }
    }

    package Usages {
        private import Definitions::*;

        action 'initialize hardware' : 'Initialize Hardware';
        action 'align with eye' : 'Align with Eye';
        action 'process image' : 'Process Image';
        action 'output image' : 'Output Image';

        action 'perform imaging cycle' : 'Perform Imaging Cycle' {
            in scanCommand : ScanCommand;
            out retinalImage : RetinalImage;

            action 'generate laser beam' : 'Generate Laser Beam' {
                out laserBeam : LaserBeam;
            }
            flow 'generate laser beam'.laserBeam to 'deflect beam'.laserBeam;

            action 'generate scan drive' : 'Generate Scan Drive' {
                in scanCommand = 'perform imaging cycle'::scanCommand;
                out scanDrive : ScanDriveSignal;
            }
            flow 'generate scan drive'.scanDrive to 'deflect beam'.scanDrive;

            action 'deflect beam' : 'Deflect Beam' {
                in laserBeam : LaserBeam;
                in scanDrive : ScanDriveSignal;
                out scannedBeam : ScannedBeam;
            }
            flow 'deflect beam'.scannedBeam to 'focus and collect'.scannedBeam;

            action 'focus and collect' : 'Focus and Collect' {
                in scannedBeam : ScannedBeam;
                out reflectedLight : ReflectedLight;
            }
            flow 'focus and collect'.reflectedLight to 'apply confocal aperture'.reflectedLight;

            action 'apply confocal aperture' : 'Apply Confocal Aperture' {
                in reflectedLight : ReflectedLight;
                out filteredLight : FilteredLight;
            }
            flow 'apply confocal aperture'.filteredLight to 'detect light'.filteredLight;

            action 'detect light' : 'Detect Light' {
                in filteredLight : FilteredLight;
                out analogSignal : AnalogSignal;
            }
            flow 'detect light'.analogSignal to 'digitize signal'.analogSignal;

            action 'digitize signal' : 'Digitize Signal' {
                in analogSignal : AnalogSignal;
                out pixelValue : PixelValue;
            }
            flow 'digitize signal'.pixelValue to 'assemble image'.pixelValues;

            action 'assemble image' : 'Assemble Image' {
                in pixelValues : PixelValue[0..*];
                out retinalImage : RetinalImage;
            }
        }

        state 'slo states' : 'SLO States' {
            entry; then initializing;
            state initializing {
                do 'initialize hardware';
            }
            accept 'Alignment Complete Signal'
                then aligning;
            state aligning {
                do 'align with eye';
            }
            accept 'Start Scan Signal'
                then 'active scanning';
            state 'active scanning' {
                do 'perform imaging cycle';
            }
            accept 'Stop Scan Signal'
                then processing;
            state processing {
                do 'process image';
            }
            accept 'Image Ready Signal'
                then 'image available';
            state 'image available' {
                do 'output image';
            }
            accept 'Initialize Signal'
                then initializing;
            accept 'Emergency Stop Signal'
                then emergencyOff;
            state emergencyOff;
            accept 'Initialize Signal'
                then initializing;
        }

        part slo : SLO {
            ref item patientEye;
            item images : RetinalImage[0..*];

            part laserSource : LaserSource;
            part scanController : ScanController;
            part scanningMirrorSystem : ScanningMirrorSystem;
            part opticalSystem : OpticalSystem;
            part confocalAperture : ConfocalAperture;
            part photodetector : Photodetector;
            part signalProcessor : SignalProcessor;
            part sloController : SLOController;

            flow laserSource.beam to scanningMirrorSystem.beam;
            flow scanController.scanDrive to scanningMirrorSystem.scanDrive;
            flow scanningMirrorSystem.scannedBeam to opticalSystem.scannedBeam;
            flow opticalSystem.reflectedLight to confocalAperture.reflectedLight;
            flow confocalAperture.filteredLight to photodetector.filteredLight;
            flow photodetector.analogSignal to signalProcessor.analogSignal;
            flow signalProcessor.retinalImage to images;
        }
    }

    package Requirements {
        private import Definitions::*;
        private import Usages::*;

        requirement def 'SLO Functional Requirement' {
            /* The SLO shall generate high-resolution real-time images of the human retina for clinical diagnosis and monitoring of eye diseases. */
            subject : SLO;
        }

        requirement def 'Laser Wavelength Requirement' {
            /* The laser source shall produce a coherent beam at 785 nm wavelength. */
            subject : LaserSource;
        }

        requirement def 'Laser Safety Requirement' {
            /* The laser power shall not exceed 5.0 mW to ensure patient eye safety. */
            subject : LaserSource;
        }

        requirement def 'Scan Resolution Requirement' {
            /* The scanning system shall produce a 512x512 pixel raster scan covering a 20-degree field of view. */
            subject : ScanningMirrorSystem;
        }

        requirement def 'Confocal Aperture Requirement' {
            /* The confocal aperture shall filter out-of-focus light to produce sharp high-contrast images of thin retinal layers. */
            subject : ConfocalAperture;
        }

        requirement def 'Frame Rate Requirement' {
            /* The system shall operate at 30 frames per second to provide a live view. */
            subject : SignalProcessor;
        }

        requirement 'slo functional req' : 'SLO Functional Requirement' {
            subject = slo;
        }
        requirement 'laser wavelength req' : 'Laser Wavelength Requirement' {
            subject = slo.laserSource;
        }
        requirement 'laser safety req' : 'Laser Safety Requirement' {
            subject = slo.laserSource;
        }
        requirement 'scan resolution req' : 'Scan Resolution Requirement' {
            subject = slo.scanningMirrorSystem;
        }
        requirement 'confocal aperture req' : 'Confocal Aperture Requirement' {
            subject = slo.confocalAperture;
        }
        requirement 'frame rate req' : 'Frame Rate Requirement' {
            subject = slo.signalProcessor;
        }

        satisfy 'slo functional req' by slo;
        satisfy 'laser wavelength req' by slo.laserSource;
        satisfy 'laser safety req' by slo.laserSource;
        satisfy 'scan resolution req' by slo.scanningMirrorSystem;
        satisfy 'confocal aperture req' by slo.confocalAperture;
        satisfy 'frame rate req' by slo.signalProcessor;
    }
}
