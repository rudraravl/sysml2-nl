package 'Millimeter Wave Scanner System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def FrequencyValue :> ISQ::FrequencyValue;
    attribute def PowerValue :> ISQ::PowerValue;
    attribute def LengthValue :> ISQ::LengthValue;
    attribute def TimeValue :> ISQ::TimeValue;
    attribute def PlaneAngleValue :> ISQ::PlaneAngleValue;

    item def MMWaveSignal {
        attribute frequency : FrequencyValue;
        attribute power : PowerValue;
        attribute phase : PlaneAngleValue;
    }

    item def ReflectionData {
        attribute amplitude : PowerValue;
        attribute phaseShift : PlaneAngleValue;
        attribute positionX : LengthValue;
        attribute positionY : LengthValue;
    }

    item def ScanImage {
        attribute resolution : LengthValue;
        attribute timestamp : TimeValue;
    }

    item def ThreatAssessment {
        attribute threatDetected : Boolean;
        attribute confidenceLevel : Real;
        attribute locationX : LengthValue;
        attribute locationY : LengthValue;
        attribute locationZ : LengthValue;
    }

    attribute def ScanStartCommand;
    attribute def ScanCompleteSignal;
    attribute def SystemReadySignal;

    port def TransmitPort {
        out signal : MMWaveSignal;
    }

    port def ReceivePort {
        in reflectedSignal : MMWaveSignal;
    }

    port def ControlPort {
        in command : ScanStartCommand;
        out status : SystemReadySignal;
    }

    port def ImagePort {
        out imageData : ScanImage;
    }

    port def ThreatPort {
        out assessment : ThreatAssessment;
    }

    part def MMWaveTransmitter {
        attribute operatingFrequency : FrequencyValue;
        attribute outputPower : PowerValue;
        port txPort : TransmitPort;
    }

    part def MMWaveReceiver {
        attribute sensitivity : PowerValue;
        attribute bandwidth : FrequencyValue;
        port rxPort : ReceivePort;
    }

    part def AntennaArray {
        attribute elementCount : Integer;
        attribute beamWidth : PlaneAngleValue;
        port transmitPort : TransmitPort;
        port receivePort : ReceivePort;
    }

    part def SignalProcessingUnit {
        attribute processingSpeed : Real;
        port dataIn : ReceivePort;
        port imageOut : ImagePort;
    }

    part def ThreatDetectionModule {
        attribute detectionThreshold : Real;
        port imageIn : ImagePort;
        port threatOut : ThreatPort;
    }

    part def OperatorConsole {
        port controlOut : ControlPort;
        port imageIn : ImagePort;
        port threatIn : ThreatPort;
    }

    action def TransmitMMWave {
        in frequency : FrequencyValue;
        in power : PowerValue;
        out transmittedSignal : MMWaveSignal;
    }

    action def ReceiveReflection {
        in reflectedSignal : MMWaveSignal;
        out reflectionData : ReflectionData;
    }

    action def ProcessReflections {
        in reflectionData : ReflectionData;
        out processedImage : ScanImage;
    }

    action def AnalyzeImage {
        in scanImage : ScanImage;
        out threatResult : ThreatAssessment;
    }

    action def DisplayResults {
        in scanImage : ScanImage;
        in threatResult : ThreatAssessment;
    }

    action def PerformSecurityScan {
        in startCommand : ScanStartCommand;
        out finalImage : ScanImage;
        out finalThreat : ThreatAssessment;

        first start;
        then action initialize {
            doc /* Initialize scanner subsystems and verify operational status */
        }
        then merge scanLoop;

        action scanSequence {
            first startScanAction;

            action startScanAction {
                doc /* Begin scan sequence */
            }

            then action transmit : TransmitMMWave {
                in frequency : FrequencyValue;
                in power : PowerValue;
                out transmittedSignal : MMWaveSignal;
            }

            then action receive : ReceiveReflection {
                in reflectedSignal : MMWaveSignal;
                out reflectionData : ReflectionData;
            }

            then action collectData {
                doc /* Accumulate reflection data from scan pattern */
            }

            then completeScanAction;
        }

        action completeScanAction {
            doc /* Complete data collection */
        }

        then action process : ProcessReflections {
            in reflectionData : ReflectionData;
            out processedImage : ScanImage;
        }

        then action analyze : AnalyzeImage {
            in scanImage = process.processedImage;
            out threatResult : ThreatAssessment;
        }

        then decide;
            if analyze.threatResult.threatDetected then alertOperator;
            if not analyze.threatResult.threatDetected then clearSubject;

        action alertOperator : DisplayResults {
            in scanImage = process.processedImage;
            in threatResult = analyze.threatResult;
        }
        then done;

        action clearSubject : DisplayResults {
            in scanImage = process.processedImage;
            in threatResult = analyze.threatResult;
        }
        then done;
    }

    state def ScannerOperationalStates {
        entry; then idle;

        state idle {
            doc /* Scanner is powered and ready but not actively scanning */
        }

        state scanning {
            doc /* Scanner is actively transmitting and receiving signals */
        }

        state processing {
            doc /* Scanner is processing collected data into image */
        }

        state analyzing {
            doc /* Threat detection algorithms are analyzing the image */
        }

        state displayingResults {
            doc /* Results are being presented to operator */
        }

        transition idle_to_scanning
            first idle
            accept scanCommand : ScanStartCommand
            then scanning;

        transition scanning_to_processing
            first scanning
            accept scanComplete : ScanCompleteSignal
            then processing;

        transition processing_to_analyzing
            first processing
            then analyzing;

        transition analyzing_to_displaying
            first analyzing
            then displayingResults;

        transition displaying_to_idle
            first displayingResults
            then idle;
    }

    part def MillimeterWaveScannerSystem {
        attribute operatingFrequency : FrequencyValue;
        attribute maxScanRange : LengthValue;
        attribute scanDuration : TimeValue;
        attribute imageResolution : LengthValue;

        part transmitter : MMWaveTransmitter;
        part receiver : MMWaveReceiver;
        part antennaArray : AntennaArray;
        part signalProcessor : SignalProcessingUnit;
        part threatDetector : ThreatDetectionModule;
        part console : OperatorConsole;
    }

    part mmwScanner : MillimeterWaveScannerSystem {
        doc /*
            Millimeter wave scanner system for security screening applications.
            Primary function: Detect concealed objects on personnel by transmitting
            millimeter wave electromagnetic radiation, receiving reflected signals,
            and processing the reflections to generate detailed images that reveal
            items hidden beneath clothing without physical contact.
        */

        attribute operatingFrequency = 30.0;
        attribute maxScanRange = 2.5;
        attribute scanDuration = 3.0;
        attribute imageResolution = 0.005;

        part transmitter : MMWaveTransmitter {
            attribute operatingFrequency = 30.0;
            attribute outputPower = 0.001;
        }

        part receiver : MMWaveReceiver {
            attribute sensitivity = 1.0e-12;
            attribute bandwidth = 5.0;
        }

        part antennaArray : AntennaArray {
            attribute elementCount = 256;
            attribute beamWidth = 2.0;
        }

        part signalProcessor : SignalProcessingUnit {
            attribute processingSpeed = 1000.0;
        }

        part threatDetector : ThreatDetectionModule {
            attribute detectionThreshold = 0.85;
        }

        part console : OperatorConsole;

        connect transmitter.txPort to antennaArray.transmitPort;
        connect antennaArray.receivePort to receiver.rxPort;
        connect receiver.rxPort to signalProcessor.dataIn;
        connect signalProcessor.imageOut to threatDetector.imageIn;
        connect signalProcessor.imageOut to console.imageIn;
        connect threatDetector.threatOut to console.threatIn;

        perform action scanOperation : PerformSecurityScan {
            in startCommand : ScanStartCommand;
            out finalImage : ScanImage;
            out finalThreat : ThreatAssessment;
        }

        exhibit state scannerStates : ScannerOperationalStates;
    }

    requirement def SafetyRequirement {
        doc /* Electromagnetic radiation exposure shall remain below regulatory safety limits */
        subject scanner : MillimeterWaveScannerSystem;
        require constraint {
            scanner.transmitter.outputPower <= 0.01
        }
    }

    requirement def PerformanceRequirement {
        doc /* System shall complete full body scan within maximum time limit */
        subject scanner : MillimeterWaveScannerSystem;
        require constraint {
            scanner.scanDuration <= 5.0
        }
    }

    requirement def DetectionRequirement {
        doc /* System shall detect concealed objects with minimum size and confidence */
        subject scanner : MillimeterWaveScannerSystem;
        require constraint {
            scanner.imageResolution <= 0.01 and
            scanner.threatDetector.detectionThreshold >= 0.80
        }
    }

    requirement def RangeRequirement {
        doc /* System shall operate effectively at specified standoff distance */
        subject scanner : MillimeterWaveScannerSystem;
        require constraint {
            scanner.maxScanRange >= 2.0
        }
    }

    requirement systemRequirements {
        doc /* Top-level requirements for millimeter wave scanner security system */

        require requirement safetyReq : SafetyRequirement;
        require requirement performanceReq : PerformanceRequirement;
        require requirement detectionReq : DetectionRequirement;
        require requirement rangeReq : RangeRequirement;
    }

    satisfy systemRequirements by mmwScanner;
}
