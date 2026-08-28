package OCTSystem {
    import ScalarValues::*;

    // ===== Units =====
    unit mm;
    unit nm;
    unit um;
    unit mW;
    unit MHz;
    unit kHz;
    unit ms;
    unit mV;
    unit Hz;

    // ===== Value Types =====
    value type Length :> Real { unit mm; }
    value type Wavelength :> Real { unit nm; }
    value type MicrometerLength :> Real { unit um; }
    value type OpticalPower :> Real { unit mW; }
    value type Frequency :> Real { unit MHz; }
    value type ScanRate :> Real { unit kHz; }
    value type TimeDuration :> Real { unit ms; }
    value type Voltage :> Real { unit mV; }
    value type Angle :> Real;
    value type NumericalAperture :> Real;
    value type Reflectivity :> Real;

    // ===== Item Definitions =====
    item def OpticalBeam {
        attribute wavelength : Wavelength;
        attribute power : OpticalPower;
        attribute coherenceLength : Length;
    }

    item def ReferenceBeam :> OpticalBeam;
    item def SampleBeam :> OpticalBeam;
    item def BackscatteredLight :> OpticalBeam;

    item def InterferencePattern {
        attribute amplitude : Voltage;
        attribute phase : Real;
        attribute fringeVisibility : Real;
    }

    item def AnalogSignal {
        attribute amplitude : Voltage;
        attribute bandwidth : Frequency;
    }

    item def DigitalSamples {
        attribute sampleRate : Frequency;
        attribute bitDepth : Integer;
        attribute sampleCount : Integer;
    }

    item def AScan {
        attribute depthResolution : MicrometerLength;
        attribute maxDepth : Length;
        attribute pixelCount : Integer;
    }

    item def BScan {
        attribute width : Integer;
        attribute depth : Integer;
        attribute aScanCount : Integer;
    }

    item def VolumetricImage {
        attribute width : Integer;
        attribute height : Integer;
        attribute depth : Integer;
        attribute bScanCount : Integer;
    }

    item def TomographicImage {
        attribute mode : String;
        attribute bScan : BScan[0..1];
        attribute volume : VolumetricImage[0..1];
    }

    // ===== Port Definitions =====
    port def OpticalOutPort {
        out beam : OpticalBeam;
    }

    port def OpticalInPort {
        in beam : OpticalBeam;
    }

    port def AnalogOutPort {
        out signal : AnalogSignal;
    }

    port def AnalogInPort {
        in signal : AnalogSignal;
    }

    port def DigitalOutPort {
        out data : DigitalSamples;
    }

    port def DigitalInPort {
        in data : DigitalSamples;
    }

    port def AScanOutPort {
        out aScan : AScan;
    }

    port def ImageOutPort {
        out image : TomographicImage;
    }

    port def ImageInPort {
        in image : TomographicImage;
    }

    port def CommandPort {
        in command : String;
        out status : String;
    }

    // ===== Part Definitions =====
    part def LowCoherenceLightSource {
        port opticalOut : OpticalOutPort;

        attribute centerWavelength : Wavelength = 840;
        attribute outputPower : OpticalPower = 5.0;
        attribute coherenceLength : Length = 0.008;
        attribute spectralBandwidth : Wavelength = 50;
        attribute sourceType : String = "Superluminescent Diode";

        action generateBeam {
            // Produce broadband low-coherence optical beam
        }
    }

    part def BeamSplitter {
        attribute splittingRatio : Real = 0.5;
        attribute insertionLoss : Real = 0.1;
    }

    part def ReferenceMirror {
        port opticalIn : OpticalInPort;
        port opticalOut : OpticalOutPort;

        attribute reflectivity : Reflectivity = 0.99;
        attribute position : Length = 10.0;

        action reflect {
            // Reflect reference beam back toward beam splitter
        }
    }

    part def MichelsonInterferometer {
        port inputPort : OpticalInPort;
        port sampleOut : OpticalOutPort;
        port sampleIn : OpticalInPort;
        port outputPort : OpticalOutPort;

        part beamSplitter : BeamSplitter;
        part referenceMirror : ReferenceMirror {
            redefines position = 10.0;
        }

        attribute beamSplitterRatio : Real = 0.5;
        attribute referenceArmLength : Length = 10.0;
        attribute sampleArmLength : Length = 10.0;

        action splitBeam {
            // Split incoming beam into reference and sample paths
        }

        action recombineBeams {
            // Recombine reference and backscattered sample light
        }
    }

    part def GalvanometerMirror {
        attribute scanAngle : Angle;
        attribute maxScanAngle : Angle = 20.0;
        attribute scanRate : ScanRate = 1.0;
        attribute currentPosition : Angle = 0.0;

        action steer {
            // Rotate mirror to steer beam across tissue
        }
    }

    part def FocusingOptics {
        attribute focalLength : Length = 25.0;
        attribute numericalAperture : NumericalAperture = 0.05;
        attribute workingDistance : Length = 25.0;

        action focus {
            // Focus beam to desired depth within tissue
        }
    }

    part def ScanningSubsystem {
        port opticalIn : OpticalInPort;
        port opticalOut : OpticalOutPort;

        part xGalvo : GalvanometerMirror {
            redefines scanRate = 1.0;
        }
        part yGalvo : GalvanometerMirror {
            redefines scanRate = 1.0;
        }
        part focusingOptics : FocusingOptics;

        attribute scanDepth : Length = 2.0;
        attribute imagingMode : String = "2D";
        attribute lateralResolution : MicrometerLength = 15.0;

        action scanPattern {
            // Steer beam across tissue surface in raster pattern
        }

        action collectBackscattered {
            // Collect returning light from tissue
        }
    }

    part def BalancedPhotodetector {
        port opticalIn : OpticalInPort;
        port electricalOut : AnalogOutPort;

        attribute sensitivity : Real = 0.9;
        attribute bandwidth : Frequency = 100;
        attribute noiseEquivalentPower : Real = 1.0e-12;

        action detectInterference {
            // Convert optical interference pattern to electrical signal
        }
    }

    part def SignalAcquisitionUnit {
        port electricalIn : AnalogInPort;
        port digitalOut : DigitalOutPort;

        attribute sampleRate : Frequency = 100;
        attribute bitDepth : Integer = 16;
        attribute inputRange : Voltage = 1000;

        action digitize {
            // High-speed analog-to-digital conversion
        }
    }

    part def ImageProcessingUnit {
        port digitalIn : DigitalInPort;
        port aScanOut : AScanOutPort;
        port imageOut : ImageOutPort;

        attribute processingMode : String = "FFT";
        attribute fourierTransformType : String = "Fast Fourier Transform";

        action performFFT {
            // Apply Fourier transform to interference fringe signal
        }

        action reconstructAScan {
            // Calculate depth profile at single point from spectral data
        }

        action reconstructBScan {
            // Assemble A-scans into 2D cross-sectional image
        }

        action reconstructVolume {
            // Assemble B-scans into 3D volumetric image
        }
    }

    part def ControlAndDisplayUnit {
        port commandPort : CommandPort;
        port imageIn : ImageInPort;

        attribute scanDepth : Length = 2.0;
        attribute imagingMode : String = "2D";
        attribute displayResolution : String = "1920x1080";
        attribute monitorSize : String = "24 inch";

        action setImagingParameters {
            // Operator sets scan depth and imaging mode
        }

        action initiateScan {
            // Start the scanning process
        }

        action displayImage {
            // Display final tomographic image on monitor
        }
    }

    // ===== State Machine Definition =====
    state def OperationalStates {
        entry; then idle;

        state idle {
            entry {
                // System ready, waiting for operator command
            }
        }

        state calibrating {
            entry {
                // Calibrate interferometer reference arm and align optics
            }
        }

        state scanning {
            entry {
                // Perform galvanometer scan and acquire interference data
            }
        }

        state processing {
            entry {
                // Fourier transform and image reconstruction
            }
        }

        state fault {
            entry {
                // Handle fault condition, ensure safe shutdown
            }
        }

        transition idle_to_calibrating
            first idle
            accept StartCalibration
            then calibrating;

        transition calibrating_to_scanning
            first calibrating
            accept CalibrationComplete
            then scanning;

        transition scanning_to_processing
            first scanning
            accept ScanComplete
            then processing;

        transition processing_to_idle
            first processing
            accept ProcessingComplete
            then idle;

        transition idle_to_fault
            first idle
            accept FaultDetected
            then fault;

        transition calibrating_to_fault
            first calibrating
            accept FaultDetected
            then fault;

        transition scanning_to_fault
            first scanning
            accept FaultDetected
            then fault;

        transition processing_to_fault
            first processing
            accept FaultDetected
            then fault;

        transition fault_to_idle
            first fault
            accept FaultCleared
            then idle;
    }

    // ===== Top-Level OCT System =====
    part def OpticalCoherenceTomographySystem {
        port operatorInterface : ~CommandPort;

        part lightSource : LowCoherenceLightSource;
        part interferometer : MichelsonInterferometer;
        part scanner : ScanningSubsystem;
        part detector : BalancedPhotodetector;
        part acquisition : SignalAcquisitionUnit;
        part processor : ImageProcessingUnit;
        part controller : ControlAndDisplayUnit;

        connection beamToInterferometer
            connect lightSource.opticalOut to interferometer.inputPort;

        connection sampleBeamToScanner
            connect interferometer.sampleOut to scanner.opticalIn;

        connection backscatteredToInterferometer
            connect scanner.opticalOut to interferometer.sampleIn;

        connection recombinedToDetector
            connect interferometer.outputPort to detector.opticalIn;

        connection detectorToAcquisition
            connect detector.electricalOut to acquisition.electricalIn;

        connection acquisitionToProcessor
            connect acquisition.digitalOut to processor.digitalIn;

        connection processorToController
            connect processor.imageOut to controller.imageIn;

        connection controllerToOperator
            connect controller.commandPort to operatorInterface;

        perform operationalStates : OperationalStates;
    }

    // ===== Requirements =====
    requirement def ImagingRequirement {
        doc /* The OCT system shall generate non-invasive, high-resolution, cross-sectional images of biological tissue. */
    }

    requirement def AxialResolutionRequirement {
        doc /* The system shall achieve axial resolution better than 10 micrometers. */
        attribute maxAxialResolution : MicrometerLength = 10.0;
    }

    requirement def ScanDepthRequirement {
        doc /* The system shall support configurable scan depth up to 3 mm. */
        attribute maxScanDepth : Length = 3.0;
    }

    requirement def NonInvasiveRequirement {
        doc /* The system shall perform non-invasive imaging using low-coherence light. */
    }

    requirement def ImagingModeRequirement {
        doc /* The system shall support both 2D cross-sectional B-scan and 3D volumetric imaging modes. */
    }

    requirement def StateMachineRequirement {
        doc /* The system shall cycle through idle, calibrating, scanning, processing, and fault operational states. */
    }

    requirement def AcquisitionRateRequirement {
        doc /* The signal acquisition unit shall digitize the interference signal at a minimum sample rate of 100 MHz. */
        attribute minSampleRate : Frequency = 100;
    }

    requirement def SafetyRequirement {
        doc /* The system shall enter fault state upon detection of any abnormal operating condition. */
    }

    requirement def LightSourceRequirement {
        doc /* The system shall use a superluminescent diode as the low-coherence light source. */
    }

    requirement def InterferometerRequirement {
        doc /* The system shall use a Michelson interferometer to split and recombine the reference and sample beams. */
    }

    requirement def GalvanometerRequirement {
        doc /* The scanning subsystem shall use a pair of galvanometer mirrors to steer the beam across the tissue. */
    }

    requirement def FourierTransformRequirement {
        doc /* The image processing unit shall use Fourier transforms to calculate depth profiles from interference signals. */
    }

    // ===== Satisfy Relationships =====
    satisfy ImagingRequirement by OpticalCoherenceTomographySystem;
    satisfy AxialResolutionRequirement by OpticalCoherenceTomographySystem::processor;
    satisfy ScanDepthRequirement by OpticalCoherenceTomographySystem::controller;
    satisfy NonInvasiveRequirement by OpticalCoherenceTomographySystem::lightSource;
    satisfy ImagingModeRequirement by OpticalCoherenceTomographySystem::controller;
    satisfy StateMachineRequirement by OpticalCoherenceTomographySystem;
    satisfy AcquisitionRateRequirement by OpticalCoherenceTomographySystem::acquisition;
    satisfy SafetyRequirement by OpticalCoherenceTomographySystem;
    satisfy LightSourceRequirement by OpticalCoherenceTomographySystem::lightSource;
    satisfy InterferometerRequirement by OpticalCoherenceTomographySystem::interferometer;
    satisfy GalvanometerRequirement by OpticalCoherenceTomographySystem::scanner;
    satisfy FourierTransformRequirement by OpticalCoherenceTomographySystem::processor;
}
