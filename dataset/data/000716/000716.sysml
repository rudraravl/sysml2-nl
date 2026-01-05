package OpticalCoherenceTomographySystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    
    attribute def WavelengthValue :> LengthValue;
    attribute def ResolutionValue :> LengthValue;
    attribute def ScanDepthValue :> LengthValue;
    attribute def ScanRateValue :> Real;
    attribute def CoherenceLengthValue :> LengthValue;
    
    enum def ImagingMode {
        enum aLineScan;
        enum bScan;
        enum volumetricScan;
    }
    
    enum def SystemState {
        enum idle;
        enum calibrating;
        enum scanning;
        enum processing;
        enum complete;
        enum fault;
    }
    
    item def OpticalBeam {
        attribute wavelength : WavelengthValue;
        attribute bandwidth : WavelengthValue;
        attribute power : PowerValue;
        attribute coherenceLength : CoherenceLengthValue;
    }
    
    item def InterferenceSignal {
        attribute amplitude : Real;
        attribute frequency : FrequencyValue;
    }
    
    item def DepthProfile {
        attribute axialData : Real[*];
        attribute depth : ScanDepthValue;
    }
    
    item def TomographicImage {
        attribute width : LengthValue;
        attribute height : LengthValue;
        attribute depth : ScanDepthValue;
        attribute resolution : ResolutionValue;
    }
    
    port def OpticalPort {
        out beam : OpticalBeam;
    }
    
    port def SignalPort {
        out signal : InterferenceSignal;
    }
    
    port def DataPort {
        out data : DepthProfile;
    }
    
    port def ImagePort {
        out image : TomographicImage;
    }
    
    part def LowCoherenceLightSource {
        attribute centerWavelength : WavelengthValue = 1310.0 [nm];
        attribute spectralBandwidth : WavelengthValue = 100.0 [nm];
        attribute outputPower : PowerValue = 0.015 [W];
        attribute coherenceLength : CoherenceLengthValue = 8.0e-6 [m];
        
        port opticalOutput : OpticalPort;
        
        part superluminescentDiode {
            attribute :>> centerWavelength = 1310.0 [nm];
            attribute :>> spectralBandwidth = 100.0 [nm];
        }
        
        part opticalIsolator {
            attribute isolationRatio : Real = 30.0;
        }
    }
    
    part def MichelsonInterferometer {
        attribute pathLengthDifference : LengthValue;
        attribute beamSplitRatio : Real = 0.5;
        
        port opticalInput : ~OpticalPort;
        port referenceOutput : OpticalPort;
        port sampleOutput : OpticalPort;
        port combinedOutput : OpticalPort;
        
        part beamSplitter {
            attribute :>> beamSplitRatio = 0.5;
            port input;
            port transmitted;
            port reflected;
        }
        
        part referenceMirror {
            attribute position : LengthValue;
            port reflectionPort;
        }
        
        part beamCombiner {
            port input1;
            port input2;
            port output;
        }
    }
    
    part def ScanningSubsystem {
        attribute scanRateX : ScanRateValue = 2000.0;
        attribute scanRateY : ScanRateValue = 200.0;
        attribute scanAngleX : Real;
        attribute scanAngleY : Real;
        
        port opticalInput : ~OpticalPort;
        port opticalOutput : OpticalPort;
        port controlInput;
        
        part galvanometerX {
            attribute :>> scanRateX = 2000.0;
            attribute maxAngle : Real = 15.0;
        }
        
        part galvanometerY {
            attribute :>> scanRateY = 200.0;
            attribute maxAngle : Real = 15.0;
        }
        
        part focusingOptics {
            attribute focalLength : LengthValue = 0.05 [m];
            attribute numericalAperture : Real = 0.25;
        }
    }
    
    part def BalancedPhotodetector {
        attribute sensitivity : Real = 0.95;
        attribute bandwidth : FrequencyValue = 100.0e6 [Hz];
        attribute noiseEquivalentPower : PowerValue = 1.0e-12 [W];
        
        port opticalInput1 : ~OpticalPort;
        port opticalInput2 : ~OpticalPort;
        port signalOutput : SignalPort;
        
        part photodiode1 {
            attribute responsivity : Real = 0.9;
        }
        
        part photodiode2 {
            attribute responsivity : Real = 0.9;
        }
        
        part differentialAmplifier {
            attribute gain : Real = 1000.0;
        }
    }
    
    part def SignalAcquisitionUnit {
        attribute samplingRate : FrequencyValue = 200.0e6 [Hz];
        attribute bitDepth : Real = 14.0;
        attribute inputRange : Real = 2.0;
        
        port signalInput : ~SignalPort;
        port dataOutput : DataPort;
        
        part analogToDigitalConverter {
            attribute :>> samplingRate = 200.0e6 [Hz];
            attribute :>> bitDepth = 14.0;
        }
        
        part signalConditioner {
            attribute filterCutoff : FrequencyValue = 80.0e6 [Hz];
        }
    }
    
    part def ImageProcessingUnit {
        attribute axialResolution : ResolutionValue = 7.0e-6 [m];
        attribute lateralResolution : ResolutionValue = 15.0e-6 [m];
        
        port dataInput : ~DataPort;
        port imageOutput : ImagePort;
        
        part fourierTransformProcessor {
            attribute fftSize : Real = 2048.0;
        }
        
        part imageReconstructor {
            attribute :>> axialResolution = 7.0e-6 [m];
            attribute :>> lateralResolution = 15.0e-6 [m];
        }
        
        part dispersionCompensator {
            attribute compensationOrder : Real = 3.0;
        }
    }
    
    part def ControlAndDisplayUnit {
        attribute currentMode : ImagingMode = ImagingMode::bScan;
        attribute scanDepth : ScanDepthValue = 0.003 [m];
        
        port imageInput : ~ImagePort;
        port scanControl;
        port userInterface;
        
        part systemController {
            attribute :>> currentMode = ImagingMode::bScan;
        }
        
        part displayMonitor {
            attribute refreshRate : FrequencyValue = 60.0 [Hz];
        }
    }
    
    action def InitializeOCTSystem {
        out systemReady : Boolean;
    }
    
    action def PerformCalibration {
        in referenceSignal : InterferenceSignal;
        out calibrationData : Real[*];
        out calibrationSuccess : Boolean;
    }
    
    action def ConfigureScanParameters {
        in mode : ImagingMode;
        in depth : ScanDepthValue;
        in scanArea : Real;
        out scanConfig;
    }
    
    action def EmitLowCoherenceLight {
        out beam : OpticalBeam;
    }
    
    action def SplitBeam {
        in inputBeam : OpticalBeam;
        out referenceBeam : OpticalBeam;
        out sampleBeam : OpticalBeam;
    }
    
    action def ScanSample {
        in beam : OpticalBeam;
        in scanPosition : Real;
        out backscatteredBeam : OpticalBeam;
    }
    
    action def CombineBeams {
        in referenceBeam : OpticalBeam;
        in sampleBeam : OpticalBeam;
        out interferencePattern : OpticalBeam;
    }
    
    action def DetectInterference {
        in interferencePattern : OpticalBeam;
        out electricalSignal : InterferenceSignal;
    }
    
    action def AcquireSignal {
        in signal : InterferenceSignal;
        out digitalData : Real[*];
    }
    
    action def ProcessDepthProfile {
        in rawData : Real[*];
        out depthProfile : DepthProfile;
    }
    
    action def ReconstructImage {
        in depthProfiles : DepthProfile[*];
        out tomographicImage : TomographicImage;
    }
    
    action def DisplayImage {
        in image : TomographicImage;
        out displayedImage;
    }
    
    action def PerformOCTImaging {
        first start;
        then action initialize : InitializeOCTSystem;
        then action calibrate : PerformCalibration;
        then action configure : ConfigureScanParameters;
        then merge scanLoop;
        
        action emit : EmitLowCoherenceLight;
        then action split : SplitBeam {
            in inputBeam = emit.beam;
        }
        then action scan : ScanSample {
            in beam = split.sampleBeam;
        }
        then action combine : CombineBeams {
            in referenceBeam = split.referenceBeam;
            in sampleBeam = scan.backscatteredBeam;
        }
        then action detect : DetectInterference {
            in interferencePattern = combine.interferencePattern;
        }
        then action acquire : AcquireSignal {
            in signal = detect.electricalSignal;
        }
        then action processDepth : ProcessDepthProfile {
            in rawData = acquire.digitalData;
        }
        then decide;
            if processDepth.depthProfile != null then scanLoop;
            if processDepth.depthProfile == null then reconstruct;
        
        action reconstruct : ReconstructImage;
        then action display : DisplayImage {
            in image = reconstruct.tomographicImage;
        }
        then done;
    }
    
    state def OCTSystemStateMachine {
        entry; then idle;
        
        state idle;
        accept StartCalibration
            then calibrating;
        
        state calibrating;
        accept CalibrationComplete
            if calibrationSuccessful
            then scanning;
        accept CalibrationFailed
            then fault;
        
        state scanning {
            entry; then acquiringData;
            
            state acquiringData;
            accept DataAcquired
                then processing;
            
            state processing;
            accept ProcessingComplete
                if moreScansRequired
                then acquiringData;
            accept ProcessingComplete
                if scanComplete
                then exit;
        }
        accept ScanComplete
            then complete;
        
        state complete;
        accept NewScanRequest
            then scanning;
        accept ReturnToIdle
            then idle;
        
        state fault;
        accept FaultCleared
            then idle;
    }
    
    requirement <'OCT-REQ-001'> primaryImagingFunction {
        doc /* The OCT system shall generate high-resolution, 
             * cross-sectional tomographic images of biological tissue 
             * by measuring backscattered light using low-coherence 
             * interferometry.
             */
        subject octSystem : OCTSystem;
    }
    
    requirement <'OCT-REQ-002'> axialResolutionRequirement {
        doc /* The system shall achieve axial resolution better than 
             * 10 micrometers in tissue.
             */
        subject octSystem : OCTSystem;
        require constraint {
            octSystem.processingUnit.axialResolution <= 10.0e-6 [m]
        }
    }
    
    requirement <'OCT-REQ-003'> lateralResolutionRequirement {
        doc /* The system shall achieve lateral resolution better than 
             * 20 micrometers.
             */
        subject octSystem : OCTSystem;
        require constraint {
            octSystem.processingUnit.lateralResolution <= 20.0e-6 [m]
        }
    }
    
    requirement <'OCT-REQ-004'> imagingDepthRequirement {
        doc /* The system shall provide imaging depth of at least 
             * 2 millimeters in tissue.
             */
        subject octSystem : OCTSystem;
        require constraint {
            octSystem.controlUnit.scanDepth >= 0.002 [m]
        }
    }
    
    requirement <'OCT-REQ-005'> scanRateRequirement {
        doc /* The system shall acquire A-scans at a rate of at least 
             * 50,000 per second for real-time imaging.
             */
        subject scanningSubsystem : ScanningSubsystem;
        require constraint {
            scanningSubsystem.scanRateX >= 50000.0
        }
    }
    
    requirement <'OCT-REQ-006'> opticalSafetyRequirement {
        doc /* The optical power delivered to the sample shall not 
             * exceed 750 microwatts to ensure eye safety.
             */
        subject lightSource : LowCoherenceLightSource;
        require constraint {
            lightSource.outputPower / 2.0 <= 0.00075 [W]
        }
    }
    
    part def OCTSystem {
        doc /* An optical coherence tomography system that performs 
             * non-invasive, high-resolution imaging of biological tissue 
             * by measuring the echo time delay and magnitude of 
             * backscattered light using low-coherence interferometry.
             * The system generates cross-sectional tomographic images 
             * with micrometer-scale resolution.
             */
        
        attribute systemState : SystemState = SystemState::idle;
        attribute imagingDepth : ScanDepthValue = 0.003 [m];
        
        part lightSource : LowCoherenceLightSource {
            attribute :>> centerWavelength = 1310.0 [nm];
            attribute :>> spectralBandwidth = 100.0 [nm];
            attribute :>> outputPower = 0.015 [W];
            attribute :>> coherenceLength = 8.0e-6 [m];
        }
        
        part interferometer : MichelsonInterferometer {
            attribute :>> beamSplitRatio = 0.5;
        }
        
        part scanningSubsystem : ScanningSubsystem {
            attribute :>> scanRateX = 70000.0;
            attribute :>> scanRateY = 200.0;
        }
        
        part detector : BalancedPhotodetector {
            attribute :>> sensitivity = 0.95;
            attribute :>> bandwidth = 100.0e6 [Hz];
        }
        
        part acquisitionUnit : SignalAcquisitionUnit {
            attribute :>> samplingRate = 200.0e6 [Hz];
            attribute :>> bitDepth = 14.0;
        }
        
        part processingUnit : ImageProcessingUnit {
            attribute :>> axialResolution = 7.0e-6 [m];
            attribute :>> lateralResolution = 15.0e-6 [m];
        }
        
        part controlUnit : ControlAndDisplayUnit {
            attribute :>> currentMode = ImagingMode::bScan;
            attribute :>> scanDepth = 0.003 [m];
        }
        
        connect lightSource.opticalOutput to interferometer.opticalInput;
        connect interferometer.sampleOutput to scanningSubsystem.opticalInput;
        connect scanningSubsystem.opticalOutput to interferometer.sampleOutput;
        connect interferometer.combinedOutput to detector.opticalInput1;
        connect detector.signalOutput to acquisitionUnit.signalInput;
        connect acquisitionUnit.dataOutput to processingUnit.dataInput;
        connect processingUnit.imageOutput to controlUnit.imageInput;
        connect controlUnit.scanControl to scanningSubsystem.controlInput;
        
        perform action octImaging : PerformOCTImaging {
            action :>> initialize {
                out :>> systemReady = true;
            }
            action :>> calibrate {
                out :>> calibrationSuccess = true;
            }
            action :>> configure {
                in mode = controlUnit.currentMode;
                in depth = controlUnit.scanDepth;
                in scanArea = 6.0;
            }
        }
        
        exhibit state systemStateMachine : OCTSystemStateMachine;
    }
    
    part octSystem : OCTSystem {
        :>> systemState = SystemState::idle;
        :>> imagingDepth = 0.003 [m];
        
        part :>> lightSource {
            attribute :>> centerWavelength = 1310.0 [nm];
            attribute :>> spectralBandwidth = 100.0 [nm];
            attribute :>> outputPower = 0.015 [W];
        }
        
        part :>> processingUnit {
            attribute :>> axialResolution = 7.0e-6 [m];
            attribute :>> lateralResolution = 15.0e-6 [m];
        }
        
        part :>> scanningSubsystem {
            attribute :>> scanRateX = 70000.0;
        }
        
        part :>> controlUnit {
            attribute :>> scanDepth = 0.003 [m];
        }
    }
    
    satisfy primaryImagingFunction by octSystem;
    satisfy axialResolutionRequirement by octSystem;
    satisfy lateralResolutionRequirement by octSystem;
    satisfy imagingDepthRequirement by octSystem;
    satisfy scanRateRequirement by octSystem.scanningSubsystem;
    satisfy opticalSafetyRequirement by octSystem.lightSource;
}
