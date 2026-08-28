package MmWaveSecurityScanner {

    import ScalarValues::*;

    // ===== Value Types with Units =====

    value def Power :> Real {
        doc "Electrical power in milliwatts (mW)";
    }

    value def Frequency :> Real {
        doc "Electromagnetic frequency in gigahertz (GHz)";
    }

    value def Duration :> Real {
        doc "Time duration in seconds (s)";
    }

    value def Distance :> Real {
        doc "Spatial distance in meters (m)";
    }

    value def Angle :> Real {
        doc "Angular measurement in degrees (deg)";
    }

    value def Confidence :> Real {
        doc "Confidence score bounded in the range [0, 1]";
    }

    // ===== Item Definitions =====

    item def MmWaveSignal {
        doc "Transmitted millimeter-wave signal";
        attribute frequency : Frequency;
        attribute power : Power;
        attribute phase : Angle;
        attribute pulseId : Integer;
    }

    item def ReflectedSignal {
        doc "Reflected millimeter-wave return from a single antenna element";
        attribute frequency : Frequency;
        attribute amplitude : Real;
        attribute phaseShift : Angle;
        attribute timeOfFlight : Duration;
        attribute elementId : Integer;
        attribute pulseId : Integer;
    }

    item def RawScanData {
        doc "Aggregated reflection data from one complete scan pass";
        attribute reflections : ReflectedSignal[0..*];
        attribute elementCount : Integer;
        attribute scanId : String;
        attribute acquiredAt : Duration;
    }

    item def VolumetricImage {
        doc "Reconstructed three-dimensional image of the scanned subject";
        attribute resolution : Distance;
        attribute lateralField : Real[0..*];
        attribute depthField : Distance[0..*];
        attribute amplitudeField : Real[0..*];
        attribute phaseField : Angle[0..*];
        attribute scanId : String;
    }

    item def ThreatIndicator {
        doc "A single detected anomaly within the volumetric image";
        attribute regionLabel : String;
        attribute shapeClass : String;
        attribute densityEstimate : Real;
        attribute centerDepth : Distance;
        attribute lateralPosition : Real;
        attribute threatLevel : String;
    }

    item def ThreatAssessment {
        doc "Complete threat evaluation of a volumetric image";
        attribute indicators : ThreatIndicator[0..*];
        attribute overallConfidence : Confidence;
        attribute scanId : String;
        attribute evaluatedAt : Duration;
    }

    item def ScanCommand {
        doc "Operator-issued command to initiate a scan";
        attribute targetId : String;
        attribute operatorId : String;
        attribute priority : Integer;
        attribute issuedAt : Duration;
    }

    item def DisplayResult {
        doc "Image and assessment combined for operator presentation";
        attribute image : VolumetricImage;
        attribute assessment : ThreatAssessment;
        attribute scanId : String;
        attribute readyAt : Duration;
    }

    item def SystemStatus {
        doc "Current operational state of the scanner";
        attribute stateName : String;
        attribute ready : Boolean;
        attribute lastScanId : String;
    }

    // ===== Port Definitions =====

    port def MmWaveTxPort {
        out signal : MmWaveSignal;
    }

    port def MmWaveRxPort {
        in signal : MmWaveSignal;
    }

    port def ReflectedOutPort {
        out reflection : ReflectedSignal;
    }

    port def ReflectedInPort {
        in reflection : ReflectedSignal;
    }

    port def RawDataOutPort {
        out data : RawScanData;
    }

    port def RawDataInPort {
        in data : RawScanData;
    }

    port def ImageOutPort {
        out image : VolumetricImage;
    }

    port def ImageInPort {
        in image : VolumetricImage;
    }

    port def AssessmentOutPort {
        out assessment : ThreatAssessment;
    }

    port def AssessmentInPort {
        in assessment : ThreatAssessment;
    }

    port def CommandOutPort {
        out command : ScanCommand;
    }

    port def CommandInPort {
        in command : ScanCommand;
    }

    // ===== Action Definitions =====

    action def initializeSystem {
        doc "Bring the scanner into a known ready configuration";
        out status : SystemStatus;
    }

    action def markReady {
        doc "Mark the scanner as ready for the next subject";
        out status : SystemStatus;
    }

    action def waitForCommand {
        doc "Wait for the operator to issue a scan command";
        in command : ScanCommand;
    }

    action def beginTransmission {
        doc "Energize the transmitter and antenna array";
        out signal : MmWaveSignal;
    }

    action def captureReflections {
        doc "Collect reflected signals from the antenna array";
        out reflections : ReflectedSignal[0..*];
    }

    action def ceaseTransmission {
        doc "Stop signal emission at the end of a scan pass";
    }

    action def ingestRawData {
        doc "Transfer raw reflection data to the processing unit";
        in data : RawScanData;
    }

    action def reconstructImage {
        doc "Compute a volumetric image from raw reflection data";
        in data : RawScanData;
        out image : VolumetricImage;
    }

    action def publishImage {
        doc "Lock and distribute the reconstructed image";
        out image : VolumetricImage;
    }

    action def startThreatAnalysis {
        doc "Route the volumetric image to the threat detection module";
        in image : VolumetricImage;
    }

    action def detectAnomalies {
        doc "Identify shapes and densities inconsistent with the human body";
        in image : VolumetricImage;
        out indicators : ThreatIndicator[0..*];
    }

    action def compileAssessment {
        doc "Aggregate detected indicators into a complete assessment";
        in indicators : ThreatIndicator[0..*];
        out assessment : ThreatAssessment;
    }

    action def renderResults {
        doc "Display the image and assessment to the operator";
        in image : VolumetricImage;
        in assessment : ThreatAssessment;
        out result : DisplayResult;
    }

    action def awaitOperatorAcknowledgement {
        doc "Pause while the operator reviews the displayed results";
    }

    action def resetDisplay {
        doc "Clear the display for the next subject";
    }

    // ===== State Machine =====

    state def ScannerStates {
        doc "Operational state machine for the millimeter-wave scanner";
        entry / initializeSystem();
        state idle {
            doc "Idle and ready for the next subject";
            entry / markReady();
            do / waitForCommand();
        }
        state scanning {
            doc "Active scanning in progress";
            entry / beginTransmission();
            do / captureReflections();
            exit / ceaseTransmission();
        }
        state processing {
            doc "Reconstructing the volumetric image from raw reflection data";
            entry / ingestRawData();
            do / reconstructImage();
            exit / publishImage();
        }
        state analyzing {
            doc "Analyzing the image for concealed threats";
            entry / startThreatAnalysis();
            do / detectAnomalies();
            exit / compileAssessment();
        }
        state displaying {
            doc "Presenting results to the operator";
            entry / renderResults();
            do / awaitOperatorAcknowledgement();
            exit / resetDisplay();
        }
        transition idle to scanning when commandReceived;
        transition scanning to processing when scanComplete;
        transition processing to analyzing when imageReady;
        transition analyzing to displaying when assessmentReady;
        transition displaying to idle when displayAcknowledged;
    }

    // ===== Component Part Definitions =====

    part def Transmitter {
        doc "Generates very low-power millimeter-wave signals for the antenna array";
        attribute nominalPower : Power = 0.01;
        attribute operatingFrequency : Frequency = 77.0;
        attribute pulseWidth : Duration = 0.0005;
        attribute pulseCount : Integer = 1024;
        port txOut : MmWaveTxPort;
    }

    part def AntennaArray {
        doc "Phased array of millimeter-wave radiating elements for transmission and reception";
        attribute elementCount : Integer = 256;
        attribute beamWidth : Angle = 5.0;
        attribute aperture : Distance = 0.6;
        attribute dutyCycle : Real = 0.05;
        port txIn : MmWaveRxPort;
        port reflectedOut : ReflectedOutPort;
    }

    part def Receiver {
        doc "Acquires, amplifies, and digitizes reflected signals captured by the antenna array";
        attribute gain : Real = 32.0;
        attribute noiseFloor : Power = 0.000005;
        attribute dynamicRange : Real = 80.0;
        port rxIn : ReflectedInPort;
        port dataOut : RawDataOutPort;
    }

    part def SignalProcessingUnit {
        doc "Reconstructs a three-dimensional volumetric image from raw reflection data";
        attribute targetResolution : Distance = 0.005;
        attribute processingLatency : Duration = 0.5;
        attribute depthRange : Distance = 0.3;
        port dataIn : RawDataInPort;
        port imageOut : ImageOutPort;
    }

    part def ThreatDetectionModule {
        doc "Automated analysis of volumetric images for concealed threats";
        attribute sensitivity : Confidence = 0.95;
        attribute falsePositiveRate : Real = 0.05;
        attribute minFeatureSize : Distance = 0.02;
        port imageIn : ImageInPort;
        port assessmentOut : AssessmentOutPort;
    }

    part def OperatorConsole {
        doc "Operator interface for issuing commands and viewing results";
        attribute operatorId : String;
        attribute displaySize : Distance = 0.5;
        attribute refreshRate : Frequency = 60.0;
        port commandOut : CommandOutPort;
        port imageIn : ImageInPort;
        port assessmentIn : AssessmentInPort;
    }

    // ===== Top-Level System =====

    part def MmWaveScannerSystem {
        doc "Complete millimeter-wave personnel security scanner";

        attribute scanId : String;
        attribute commandReceived : Boolean = false;
        attribute scanComplete : Boolean = false;
        attribute imageReady : Boolean = false;
        attribute assessmentReady : Boolean = false;
        attribute displayAcknowledged : Boolean = false;
        attribute maxStandoff : Distance = 1.0;

        part transmitter : Transmitter;
        part antennaArray : AntennaArray;
        part receiver : Receiver;
        part signalProcessingUnit : SignalProcessingUnit;
        part threatDetectionModule : ThreatDetectionModule;
        part operatorConsole : OperatorConsole;

        port commandIn : CommandInPort;

        state machine operation : ScannerStates;

        connection transmitter.txOut to antennaArray.txIn;
        connection antennaArray.reflectedOut to receiver.rxIn;
        connection receiver.dataOut to signalProcessingUnit.dataIn;
        connection signalProcessingUnit.imageOut to threatDetectionModule.imageIn;
        connection signalProcessingUnit.imageOut to operatorConsole.imageIn;
        connection threatDetectionModule.assessmentOut to operatorConsole.assessmentIn;
        connection operatorConsole.commandOut to commandIn;
    }

    // ===== Requirements =====

    requirement def NonContactScanningRequirement {
        doc "The scanner shall detect concealed objects without physical contact with the subject";
        subject scanner : MmWaveScannerSystem;
        attribute requiredStandoff : Distance = 1.0;
    }

    requirement def LowPowerEmissionRequirement {
        doc "The scanner shall emit millimeter-wave power below human safety limits";
        subject scanner : MmWaveScannerSystem;
        attribute maxEirp : Power = 0.1;
    }

    requirement def ImageResolutionRequirement {
        doc "The reconstructed image shall achieve a target spatial resolution";
        subject scanner : MmWaveScannerSystem;
        attribute lateralResolution : Distance = 0.005;
        attribute depthResolution : Distance = 0.005;
    }

    requirement def ThreatDetectionRequirement {
        doc "The system shall flag shapes and densities inconsistent with the human body as potential threats";
        subject scanner : MmWaveScannerSystem;
        attribute minConfidence : Confidence = 0.9;
        attribute maxFalsePositiveRate : Real = 0.05;
    }

    requirement def OperatorDisplayRequirement {
        doc "The operator console shall present the image and threat assessment simultaneously";
        subject scanner : MmWaveScannerSystem;
    }

    requirement def OperationalFlowRequirement {
        doc "The scanner shall cycle through idle, scanning, processing, analyzing, and displaying states";
        subject scanner : MmWaveScannerSystem;
    }

    requirement def DetectionDepthRequirement {
        doc "The scanner shall detect concealed objects beneath typical clothing";
        subject scanner : MmWaveScannerSystem;
        attribute maxDetectionDepth : Distance = 0.05;
    }

    // ===== Requirement Usages =====

    requirement nonContactReq : NonContactScanningRequirement;
    requirement lowPowerReq : LowPowerEmissionRequirement;
    requirement imageResReq : ImageResolutionRequirement;
    requirement threatDetReq : ThreatDetectionRequirement;
    requirement opDisplayReq : OperatorDisplayRequirement;
    requirement opFlowReq : OperationalFlowRequirement;
    requirement detDepthReq : DetectionDepthRequirement;
}
