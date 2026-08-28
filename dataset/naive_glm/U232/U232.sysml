package BoneFractureUltrasoundSystem {
    import ScalarValues::*;

    // ===== Units =====
    unit def Hz;
    unit def V;
    unit def A;
    unit def W;
    unit def m;
    unit def s;
    unit def percent;
    unit def dB;
    unit def degC;

    // ===== Value Types =====
    value def Frequency :> Real { unit Hz; }
    value def Voltage :> Real { unit V; }
    value def Current :> Real { unit A; }
    value def Power :> Real { unit W; }
    value def Length :> Real { unit m; }
    value def Duration :> Real { unit s; }
    value def Confidence :> Real { unit percent; }
    value def Gain :> Real { unit dB; }
    value def Temperature :> Real { unit degC; }

    // ===== Item Types =====
    item def SoundWave {
        attribute frequency : Frequency;
        attribute intensity : Real;
        attribute focusDepth : Length;
        attribute steeringAngle : Real;
    }

    item def EchoSignal {
        attribute amplitude : Real;
        attribute phase : Real;
        attribute depth : Length;
        attribute timestamp : Duration;
    }

    item def ProcessedSignal {
        attribute amplitude : Real;
        attribute tissueType : String;
        attribute depth : Length;
        attribute gain : Gain;
    }

    item def UltrasoundImage {
        attribute width : Integer;
        attribute height : Integer;
        attribute frameRate : Frequency;
        attribute pixelData : String;
    }

    item def DiagnosticReport {
        attribute fractureDetected : Boolean;
        attribute fractureLocation : String;
        attribute fractureSize : Length;
        attribute confidenceScore : Confidence;
        attribute timestamp : String;
        attribute notes : String;
    }

    item def ControlCommand {
        attribute commandType : String;
        attribute parameter : String;
    }

    item def ElectricalPower {
        attribute voltage : Voltage;
        attribute current : Current;
        attribute power : Power;
    }

    item def CalibrationData {
        attribute transducerGain : Gain;
        attribute noiseFloor : Real;
        attribute temperature : Temperature;
    }

    // ===== Port Definitions =====
    port def SoundPort {
        out sound : SoundWave;
        in echo : EchoSignal;
    }

    port def EchoDataPort {
        out echoData : EchoSignal;
    }

    port def ProcessedDataPort {
        out processedData : ProcessedSignal;
    }

    port def ImageDataPort {
        out imageData : UltrasoundImage;
    }

    port def ReportDataPort {
        out reportData : DiagnosticReport;
    }

    port def CommandPort {
        in command : ControlCommand;
    }

    port def PowerInPort {
        in power : ElectricalPower;
    }

    port def PowerOutPort {
        out power : ElectricalPower;
    }

    // ===== Part Definitions =====

    part def TransducerArray {
        attribute elementCount : Integer;
        attribute centerFrequency : Frequency;
        attribute bandwidth : Frequency;

        port soundPort : SoundPort;
        port echoOut : EchoDataPort;

        action generateSound {
            in freq : Frequency;
            out wave : SoundWave;
        }

        action receiveEcho {
            in echo : EchoSignal;
            out echoData : EchoSignal;
        }
    }

    part def UltrasoundProbe {
        attribute probeId : String;
        attribute weight : Real;

        part transducerArray : TransducerArray {
            attribute elementCount = 128;
            attribute centerFrequency = 5.0e6 [Hz];
            attribute bandwidth = 2.0e6 [Hz];
        }

        port soundPort : SoundPort;
        port echoOut : EchoDataPort;
        port powerIn : PowerInPort;
        port commandIn : CommandPort;

        connection transducerSound connect transducerArray.soundPort to soundPort;
        connection transducerEcho connect transducerArray.echoOut to echoOut;
    }

    part def BeamFormer {
        attribute focusDepth : Length;
        attribute steeringAngle : Real;
        attribute channelCount : Integer;

        port commandIn : CommandPort;
        port powerIn : PowerInPort;
        port soundOut : SoundPort;
        port echoIn : EchoDataPort;
        port echoOut : EchoDataPort;

        action focusBeam {
            in depth : Length;
            in angle : Real;
            out wave : SoundWave;
        }

        action steerBeam {
            in angle : Real;
            out wave : SoundWave;
        }

        action beamformEchoes {
            in echoes : EchoSignal[0..*];
            out beamformed : EchoSignal;
        }
    }

    part def SignalProcessingUnit {
        attribute filterFrequency : Frequency;
        attribute gain : Gain;

        port echoIn : EchoDataPort;
        port processedOut : ProcessedDataPort;
        port powerIn : PowerInPort;
        port commandIn : CommandPort;

        action filterSignal {
            in echo : EchoSignal;
            out filtered : EchoSignal;
        }

        action amplifySignal {
            in echo : EchoSignal;
            out amplified : EchoSignal;
        }

        action classifyTissue {
            in echo : EchoSignal;
            out processed : ProcessedSignal;
        }
    }

    part def ImageReconstructionEngine {
        attribute imageWidth : Integer;
        attribute imageHeight : Integer;
        attribute frameRate : Frequency;

        port processedIn : ProcessedDataPort;
        port imageOut : ImageDataPort;
        port powerIn : PowerInPort;
        port commandIn : CommandPort;

        action reconstructImage {
            in processed : ProcessedSignal[0..*];
            out image : UltrasoundImage;
        }

        action updateFrame {
            in image : UltrasoundImage;
            out updatedImage : UltrasoundImage;
        }
    }

    part def FractureDetectionAlgorithm {
        attribute modelVersion : String;
        attribute sensitivity : Real;
        attribute specificity : Real;

        port imageIn : ImageDataPort;
        port reportOut : ReportDataPort;
        port powerIn : PowerInPort;
        port commandIn : CommandPort;

        action analyzeImage {
            in image : UltrasoundImage;
            out report : DiagnosticReport;
        }

        action detectFracture {
            in image : UltrasoundImage;
            out fractureDetected : Boolean;
            out location : String;
            out size : Length;
        }

        action computeConfidence {
            in features : String;
            out confidence : Confidence;
        }
    }

    part def ControlConsole {
        attribute consoleId : String;

        port commandOut : CommandPort;
        port powerIn : PowerInPort;

        action initiateScan {
            out command : ControlCommand;
        }

        action adjustSettings {
            in parameter : String;
            in value : String;
            out command : ControlCommand;
        }

        action requestCalibration {
            out command : ControlCommand;
        }
    }

    part def DisplayMonitor {
        attribute resolution : String;
        attribute screenSize : Real;

        port imageIn : ImageDataPort;
        port reportIn : ReportDataPort;
        port powerIn : PowerInPort;

        action displayImage {
            in image : UltrasoundImage;
        }

        action displayReport {
            in report : DiagnosticReport;
        }
    }

    part def PowerManagementUnit {
        attribute inputVoltage : Voltage;
        attribute totalPower : Power;

        port powerIn : PowerInPort;
        port powerOut : PowerOutPort;

        action distributePower {
            in inputPower : ElectricalPower;
            out distributedPower : ElectricalPower[0..*];
        }

        action regulateVoltage {
            in input : ElectricalPower;
            out regulated : ElectricalPower;
        }
    }

    // ===== System Definition =====

    part def BoneFractureUltrasoundSystem {
        attribute systemId : String;
        attribute manufacturer : String;
        attribute model : String;

        part probe : UltrasoundProbe {
            attribute probeId = "PROBE-001";
        }

        part beamFormer : BeamFormer {
            attribute focusDepth = 0.05 [m];
            attribute steeringAngle = 0.0;
            attribute channelCount = 128;
        }

        part signalProcessor : SignalProcessingUnit {
            attribute filterFrequency = 5.0e6 [Hz];
            attribute gain = 60.0 [dB];
        }

        part imageEngine : ImageReconstructionEngine {
            attribute imageWidth = 512;
            attribute imageHeight = 512;
            attribute frameRate = 30.0 [Hz];
        }

        part fractureAI : FractureDetectionAlgorithm {
            attribute modelVersion = "AI-Bone-v2.1";
            attribute sensitivity = 0.92;
            attribute specificity = 0.88;
        }

        part controlConsole : ControlConsole {
            attribute consoleId = "CONSOLE-001";
        }

        part displayMonitor : DisplayMonitor {
            attribute resolution = "1920x1080";
            attribute screenSize = 15.6;
        }

        part powerManagement : PowerManagementUnit {
            attribute inputVoltage = 24.0 [V];
            attribute totalPower = 150.0 [W];
        }

        // Signal path connections
        connection beamToProbe connect beamFormer.soundOut to probe.soundPort;
        connection probeToBeamFormer connect probe.echoOut to beamFormer.echoIn;
        connection beamFormerToSignalProcessor connect beamFormer.echoOut to signalProcessor.echoIn;
        connection signalProcessorToImageEngine connect signalProcessor.processedOut to imageEngine.processedIn;
        connection imageEngineToFractureAI connect imageEngine.imageOut to fractureAI.imageIn;
        connection imageEngineToDisplay connect imageEngine.imageOut to displayMonitor.imageIn;
        connection fractureAIToDisplay connect fractureAI.reportOut to displayMonitor.reportIn;

        // Control connections
        connection controlToBeamFormer connect controlConsole.commandOut to beamFormer.commandIn;
        connection controlToSignalProcessor connect controlConsole.commandOut to signalProcessor.commandIn;
        connection controlToImageEngine connect controlConsole.commandOut to imageEngine.commandIn;
        connection controlToFractureAI connect controlConsole.commandOut to fractureAI.commandIn;

        // Power distribution connections
        connection powerToProbe connect powerManagement.powerOut to probe.powerIn;
        connection powerToBeamFormer connect powerManagement.powerOut to beamFormer.powerIn;
        connection powerToSignalProcessor connect powerManagement.powerOut to signalProcessor.powerIn;
        connection powerToImageEngine connect powerManagement.powerOut to imageEngine.powerIn;
        connection powerToFractureAI connect powerManagement.powerOut to fractureAI.powerIn;
        connection powerToControlConsole connect powerManagement.powerOut to controlConsole.powerIn;
        connection powerToDisplay connect powerManagement.powerOut to displayMonitor.powerIn;

        // State Machine
        state systemOperation {
            state standby {
                entry action {
                    /* System powered on, idle, awaiting operator command */
                }
            }

            state calibration {
                entry action {
                    /* Calibrate transducer array, signal path, and beam former */
                }

                do action {
                    /* Perform self-test and noise floor measurement */
                }
            }

            state activeScanning {
                entry action {
                    /* Begin continuous transmit and receive cycle */
                }

                do action {
                    /* Continuously transmit sound waves, receive echoes,
                       process data through signal processor, reconstruct
                       image, and update display in real time */
                }

                state transmitting {
                    entry action {
                        /* Generate and steer focused ultrasound beam */
                    }
                }

                state receiving {
                    entry action {
                        /* Capture returning echoes from tissue boundaries */
                    }
                }

                state processing {
                    entry action {
                        /* Filter, amplify, and classify echo signals */
                    }
                }

                state imaging {
                    entry action {
                        /* Reconstruct 2D image from processed scan lines */
                    }
                }

                transition txToRx from transmitting to receiving;
                transition rxToProc from receiving to processing;
                transition procToImg from processing to imaging;
                transition imgToTx from imaging to transmitting;
            }

            state dataAnalysis {
                entry action {
                    /* Run fracture detection algorithm on collected image data */
                }

                do action {
                    /* Analyze ultrasound images for fracture indicators,
                       determine location and size of potential breaks */
                }
            }

            state reportGeneration {
                entry action {
                    /* Compile diagnostic report with confidence score */
                }

                do action {
                    /* Format and transmit final diagnostic report to display */
                }
            }

            transition standbyToCalibration
                from standby
                to calibration
                accept ControlCommand;

            transition calibrationToActive
                from calibration
                to activeScanning
                accept ControlCommand;

            transition activeToAnalysis
                from activeScanning
                to dataAnalysis
                accept ControlCommand;

            transition analysisToReport
                from dataAnalysis
                to reportGeneration
                accept ControlCommand;

            transition reportToStandby
                from reportGeneration
                to standby
                accept ControlCommand;

            transition activeToStandby
                from activeScanning
                to standby
                accept ControlCommand;
        }

        // Requirement satisfactions
        satisfaction satisfyNonInvasive : NonInvasiveDetection by probe;
        satisfaction satisfyRapid : RapidDiagnosis by fractureAI;
        satisfaction satisfyRealTime : RealTimeImaging by imageEngine;
        satisfaction satisfyAccuracy : FractureDetectionAccuracy by fractureAI;
        satisfaction satisfyConfidence : ConfidenceReporting by fractureAI;
        satisfaction satisfyPower : PowerDistribution by powerManagement;
        satisfaction satisfyBeamSteering : BeamSteeringCapability by beamFormer;
        satisfaction satisfySignalClarity : SignalClarityEnhancement by signalProcessor;
        satisfaction satisfyImageReconstruction : ImageReconstructionCapability by imageEngine;
        satisfaction satisfyXRayAlt : XRayAlternative by BoneFractureUltrasoundSystem;
    }

    // ===== Requirements =====

    requirement def NonInvasiveDetection {
        doc /* The system shall provide non-invasive detection of bone fractures using ultrasound technology. */
    }

    requirement def RapidDiagnosis {
        doc /* The system shall provide diagnostic results within 60 seconds of scan initiation. */
    }

    requirement def PointOfCareOperation {
        doc /* The system shall be operable at the point of care without requiring specialized imaging facilities. */
    }

    requirement def RealTimeImaging {
        doc /* The system shall display real-time ultrasound images at a minimum of 30 frames per second. */
    }

    requirement def FractureDetectionAccuracy {
        doc /* The fracture detection algorithm shall achieve sensitivity of at least 90 percent and specificity of at least 85 percent. */
    }

    requirement def ConfidenceReporting {
        doc /* The system shall include a confidence score with each diagnostic report. */
    }

    requirement def PowerDistribution {
        doc /* The power management unit shall distribute electrical power to all system components. */
    }

    requirement def BeamSteeringCapability {
        doc /* The beam former shall electronically focus and steer sound waves to target the area of interest. */
    }

    requirement def SignalClarityEnhancement {
        doc /* The signal processing unit shall filter and amplify raw echo signals to improve clarity and extract tissue type information. */
    }

    requirement def ImageReconstructionCapability {
        doc /* The image reconstruction engine shall create real-time two-dimensional visual images of bone and surrounding tissues. */
    }

    requirement def XRayAlternative {
        doc /* The system shall serve as an alternative to traditional X-ray imaging for bone fracture detection. */
    }

    requirement def OperatorInterface {
        doc /* The control console shall allow the operator to adjust settings and initiate scans. */
    }

    requirement def DisplayOutput {
        doc /* The display monitor shall show both the live ultrasound image and the final diagnostic report. */
    }

    requirement def SystemStateManagement {
        doc /* The system shall transition through standby, calibration, active scanning, data analysis, and report generation states. */
    }
}
