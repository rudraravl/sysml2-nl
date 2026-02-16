package 'Fracture Sonography System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    
    attribute def UltrasoundFrequency :> ISQ::FrequencyValue;
    attribute def ImageResolution :> ISQ::LengthValue;
    attribute def PenetrationDepth :> ISQ::LengthValue;
    attribute def AcousticPower :> ISQ::PowerValue;
    attribute def EchoDelay :> ISQ::TimeValue;
    attribute def SignalIntensity :> Real;
    attribute def TissueType :> String;
    attribute def FractureConfidence :> Real;
    
    item def UltrasoundWave {
        attribute frequency : UltrasoundFrequency;
        attribute power : AcousticPower;
    }
    
    item def EchoSignal {
        attribute intensity : SignalIntensity;
        attribute delay : EchoDelay;
    }
    
    item def ImageData {
        attribute resolution : ImageResolution;
        attribute depth : PenetrationDepth;
        attribute pixelMatrix : Integer[*];
    }
    
    item def DiagnosticReport {
        attribute fractureDetected : Boolean;
        attribute fractureLocation : ISQ::LengthValue;
        attribute fractureWidth : ISQ::LengthValue;
        attribute confidence : FractureConfidence;
    }
    
    item def ElectricalPower;
    item def ControlCommand;
    
    port def AcousticTransmitPort {
        out ultrasoundOut : UltrasoundWave;
    }
    
    port def AcousticReceivePort {
        in echoIn : EchoSignal;
    }
    
    port def SignalDataPort {
        out signalData : EchoSignal;
    }
    
    port def ImageDataPort {
        out imageData : ImageData;
    }
    
    port def DiagnosticPort {
        out report : DiagnosticReport;
    }
    
    port def PowerInputPort {
        in power : ElectricalPower;
    }
    
    port def ControlPort {
        in command : ControlCommand;
    }
    
    part def UltrasoundProbe {
        doc /* Piezoelectric transducer array that generates and receives ultrasound waves */
        
        attribute operatingFrequency : UltrasoundFrequency;
        attribute transmitPower : AcousticPower;
        attribute elementCount : Integer;
        
        port transmitPort : AcousticTransmitPort;
        port receivePort : AcousticReceivePort;
        port signalOut : SignalDataPort;
        port powerIn : PowerInputPort;
        
        perform action transmitUltrasound : TransmitUltrasound;
        perform action receiveEcho : ReceiveEcho;
    }
    
    part def BeamFormer {
        doc /* Focuses and steers the ultrasound beam electronically */
        
        attribute beamAngle : Real;
        attribute focalDepth : PenetrationDepth;
        
        port controlIn : ControlPort;
        port powerIn : PowerInputPort;
    }
    
    part def SignalProcessingUnit {
        doc /* Processes raw echo signals to extract tissue information */
        
        attribute gainLevel : Real;
        attribute filterBandwidth : UltrasoundFrequency;
        
        port echoInput : SignalDataPort;
        port imageOutput : ImageDataPort;
        port powerIn : PowerInputPort;
        
        perform action processSignals : ProcessEchoSignals;
    }
    
    part def ImageReconstructionEngine {
        doc /* Reconstructs 2D/3D images from processed ultrasound data */
        
        attribute scanResolution : ImageResolution;
        attribute frameRate : Real;
        
        port dataInput : ImageDataPort;
        port imageOutput : ImageDataPort;
        port powerIn : PowerInputPort;
        
        perform action reconstructImage : ReconstructImage;
    }
    
    part def FractureDetectionAlgorithm {
        doc /* AI-based algorithm to detect and characterize bone fractures */
        
        attribute detectionThreshold : Real;
        attribute minimumFractureSize : ISQ::LengthValue;
        
        port imageInput : ImageDataPort;
        port diagnosticOutput : DiagnosticPort;
        port powerIn : PowerInputPort;
        
        perform action analyzeFracture : AnalyzeFracture;
    }
    
    part def DisplayMonitor {
        doc /* Real-time display of ultrasound images and diagnostic results */
        
        attribute screenResolution : Integer;
        attribute brightness : Real;
        
        port imageInput : ImageDataPort;
        port diagnosticInput : DiagnosticPort;
        port powerIn : PowerInputPort;
        
        perform action displayResults : DisplayResults;
    }
    
    part def ControlConsole {
        doc /* User interface for system operation and parameter adjustment */
        
        attribute scanMode : String;
        
        port commandOutput : ControlPort;
        port powerIn : PowerInputPort;
    }
    
    part def PowerManagementUnit {
        doc /* Distributes and regulates electrical power to all subsystems */
        
        attribute inputVoltage : Real;
        attribute totalPowerBudget : ISQ::PowerValue;
        
        port probePower : PowerInputPort;
        port beamformerPower : PowerInputPort;
        port processorPower : PowerInputPort;
        port reconstructorPower : PowerInputPort;
        port detectorPower : PowerInputPort;
        port displayPower : PowerInputPort;
        port consolePower : PowerInputPort;
    }
    
    action def TransmitUltrasound {
        in frequency : UltrasoundFrequency;
        in power : AcousticPower;
        out waveGenerated : UltrasoundWave;
    }
    
    action def ReceiveEcho {
        in targetDepth : PenetrationDepth;
        out echoSignal : EchoSignal;
    }
    
    action def ProcessEchoSignals {
        in rawEcho : EchoSignal;
        out filteredSignal : EchoSignal;
        out tissueCharacteristics : TissueType;
    }
    
    action def ReconstructImage {
        in echoData : EchoSignal[*];
        in scanDepth : PenetrationDepth;
        out imageMatrix : ImageData;
    }
    
    action def AnalyzeFracture {
        in imageData : ImageData;
        in tissueMap : TissueType[*];
        out fractureDetected : Boolean;
        out fractureLocation : ISQ::LengthValue;
        out fractureWidth : ISQ::LengthValue;
        out confidence : FractureConfidence;
    }
    
    action def DisplayResults {
        in imageData : ImageData;
        in diagnosticReport : DiagnosticReport;
    }
    
    action def PerformFractureScan {
        doc /* Complete workflow for fracture detection using ultrasound sonography */
        
        in scanFrequency : UltrasoundFrequency;
        in scanPower : AcousticPower;
        in maxDepth : PenetrationDepth;
        in numberOfFrames : Integer;
        out finalReport : DiagnosticReport;
        
        first start;
        then action initialize {
            doc /* Initialize system and verify all subsystems are ready */
        }
        then merge scanLoop;
        
        action scanLoop {
            doc /* Iterative scanning process for multiple frames */
        }
        
        then action transmit : TransmitUltrasound {
            in frequency = scanFrequency;
            in power = scanPower;
            out waveGenerated;
        }
        
        then action receive : ReceiveEcho {
            in targetDepth = maxDepth;
            out echoSignal;
        }
        
        then action process : ProcessEchoSignals {
            in rawEcho = receive.echoSignal;
            out filteredSignal;
            out tissueCharacteristics;
        }
        
        then action reconstruct : ReconstructImage {
            in echoData = (process.filteredSignal);
            in scanDepth = maxDepth;
            out imageMatrix;
        }
        
        then action analyze : AnalyzeFracture {
            in imageData = reconstruct.imageMatrix;
            in tissueMap = (process.tissueCharacteristics);
            out fractureDetected;
            out fractureLocation;
            out fractureWidth;
            out confidence;
        }
        
        then decide;
            if analyze.confidence >= 0.85 then generateReport;
            if analyze.confidence < 0.85 then scanLoop;
        
        action generateReport {
            doc /* Generate final diagnostic report */
        }
        
        then assign finalReport := DiagnosticReport {
            fractureDetected = analyze.fractureDetected;
            fractureLocation = analyze.fractureLocation;
            fractureWidth = analyze.fractureWidth;
            confidence = analyze.confidence;
        }
        
        then done;
    }
    
    part def FractureSonographySystem;
    
    part fractureSonographySystem : FractureSonographySystem {
        doc /* Integrated ultrasound imaging system for non-invasive bone fracture detection and characterization */
        
        attribute systemFrequency : UltrasoundFrequency = 7500000.0;
        attribute systemPower : AcousticPower = 0.15;
        attribute maxScanDepth : PenetrationDepth = 0.06;
        attribute targetResolution : ImageResolution = 0.0003;
        
        part probe : UltrasoundProbe {
            attribute :>> operatingFrequency = fractureSonographySystem::systemFrequency;
            attribute :>> transmitPower = fractureSonographySystem::systemPower;
            attribute :>> elementCount = 128;
        }
        
        part beamformer : BeamFormer {
            attribute :>> beamAngle = 0.0;
            attribute :>> focalDepth = 0.03;
        }
        
        part processor : SignalProcessingUnit {
            attribute :>> gainLevel = 50.0;
            attribute :>> filterBandwidth = 5000000.0;
        }
        
        part reconstructor : ImageReconstructionEngine {
            attribute :>> scanResolution = fractureSonographySystem::targetResolution;
            attribute :>> frameRate = 30.0;
        }
        
        part detector : FractureDetectionAlgorithm {
            attribute :>> detectionThreshold = 0.75;
            attribute :>> minimumFractureSize = 0.0005;
        }
        
        part display : DisplayMonitor {
            attribute :>> screenResolution = 1920;
            attribute :>> brightness = 350.0;
        }
        
        part console : ControlConsole {
            attribute :>> scanMode = "B-mode";
        }
        
        part powerUnit : PowerManagementUnit {
            attribute :>> inputVoltage = 230.0;
            attribute :>> totalPowerBudget = 500.0;
        }
        
        connect probe.signalOut to processor.echoInput;
        connect processor.imageOutput to reconstructor.dataInput;
        connect reconstructor.imageOutput to detector.imageInput;
        connect reconstructor.imageOutput to display.imageInput;
        connect detector.diagnosticOutput to display.diagnosticInput;
        connect console.commandOutput to beamformer.controlIn;
        
        connect powerUnit.probePower to probe.powerIn;
        connect powerUnit.beamformerPower to beamformer.powerIn;
        connect powerUnit.processorPower to processor.powerIn;
        connect powerUnit.reconstructorPower to reconstructor.powerIn;
        connect powerUnit.detectorPower to detector.powerIn;
        connect powerUnit.displayPower to display.powerIn;
        connect powerUnit.consolePower to console.powerIn;
        
        perform action diagnosticScan[*] ordered {
            action scanAction : PerformFractureScan {
                in scanFrequency = systemFrequency;
                in scanPower = systemPower;
                in maxDepth = maxScanDepth;
                in numberOfFrames = 10;
                out finalReport;
            }
        }
    }
    
    state def SonographyOperationalStates {
        doc /* State machine governing system operational modes */
        
        entry; then PowerOff;
        
        state PowerOff;
        
        state Standby {
            doc /* System powered but not actively scanning */
        }
        
        state Calibrating {
            doc /* System performing self-calibration and diagnostics */
        }
        
        state Ready {
            doc /* System ready to perform scans */
        }
        
        state Scanning {
            doc /* Active ultrasound scanning in progress */
            
            entry; then Transmitting;
            
            state Transmitting;
            state Receiving;
            state Processing;
            
            transition first Transmitting;
            then Receiving;
            then Processing;
            then done;
        }
        
        state Analyzing {
            doc /* Fracture detection algorithm analyzing image data */
        }
        
        state DisplayingResults {
            doc /* Presenting diagnostic results to operator */
        }
        
        state Fault {
            doc /* System error state requiring intervention */
        }
        
        transition powerOn first PowerOff;
        then Standby;
        
        transition startCalibration first Standby;
        then Calibrating;
        
        transition calibrationComplete first Calibrating;
        then Ready;
        
        transition beginScan first Ready;
        then Scanning;
        
        transition scanComplete first Scanning;
        then Analyzing;
        
        transition analysisComplete first Analyzing;
        then DisplayingResults;
        
        transition returnToReady first DisplayingResults;
        then Ready;
    }
    
    requirement <'FS-REQ-001'> primaryFunctionRequirement {
        doc /* The system shall detect and characterize bone fractures using high-frequency 
             ultrasound imaging to provide non-invasive diagnostic information to clinicians. */
        
        subject fractureSonographySystem;
    }
    
    requirement <'FS-REQ-002'> fractureDetectionCapability {
        doc /* The system shall detect bone fractures with minimum width of 0.5mm at depths 
             up to 60mm below the skin surface. */
        
        subject fractureSonographySystem;
        
        require constraint {
            fractureSonographySystem.detector.minimumFractureSize <= 0.0005
        }
        
        require constraint {
            fractureSonographySystem.maxScanDepth >= 0.06
        }
    }
    
    requirement <'FS-REQ-003'> diagnosticAccuracy {
        doc /* The system shall provide fracture diagnosis with confidence level of at least 85% 
             to ensure clinical reliability. */
        
        subject fractureSonographySystem;
    }
    
    requirement <'FS-REQ-004'> imagingResolution {
        doc /* The system shall achieve spatial resolution of 0.3mm or better to visualize 
             fine fracture details. */
        
        subject fractureSonographySystem;
        
        require constraint {
            fractureSonographySystem.targetResolution <= 0.0003
        }
    }
    
    requirement <'FS-REQ-005'> realTimePerformance {
        doc /* The system shall display ultrasound images at a minimum frame rate of 30 fps 
             for real-time visualization during examination. */
        
        subject fractureSonographySystem;
        
        require constraint {
            fractureSonographySystem.reconstructor.frameRate >= 30.0
        }
    }
    
    requirement <'FS-REQ-006'> acousticSafety {
        doc /* The system shall operate within safe acoustic power limits (< 0.2W) to prevent 
             tissue heating and ensure patient safety. */
        
        subject fractureSonographySystem;
        
        require constraint {
            fractureSonographySystem.systemPower < 0.2
        }
    }
    
    requirement <'FS-REQ-007'> operatingFrequency {
        doc /* The system shall operate at ultrasound frequency of 7.5 MHz to balance penetration 
             depth and resolution for musculoskeletal imaging. */
        
        subject fractureSonographySystem;
        
        require constraint {
            fractureSonographySystem.systemFrequency == 7500000.0
        }
    }
    
    requirement systemMissionRequirement {
        doc /* Primary mission: Provide rapid, non-invasive, point-of-care ultrasound imaging 
             for detection and characterization of bone fractures in emergency and clinical settings. */
        
        subject fractureSonographySystem;
        
        require primaryFunctionRequirement;
        require fractureDetectionCapability;
        require diagnosticAccuracy;
        require imagingResolution;
        require realTimePerformance;
        require acousticSafety;
        require operatingFrequency;
    }
}
