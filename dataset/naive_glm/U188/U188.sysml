package CEUS_System {

    import ScalarValues::*;
    import ISQ::*;

    // ========== Value Types ==========

    attribute def MechanicalIndex :> Real {
        doc /* Dimensionless acoustic mechanical index */
    }

    attribute def FrameRate :> Real {
        doc /* Imaging frame rate in frames per second */
    }

    attribute def UltrasoundFrequency :> Real {
        doc /* Ultrasound frequency in MHz */
    }

    attribute def AcousticPower :> Real {
        doc /* Acoustic power in milliwatts */
    }

    attribute def ContrastDose :> Real {
        doc /* Contrast agent dose in milliliters */
    }

    attribute def ContrastConcentration :> Real {
        doc /* Microbubble concentration per mL */
    }

    attribute def SignalAmplitude :> Real {
        doc /* Echo signal amplitude in volts */
    }

    attribute def InjectionRate :> Real {
        doc /* Injection flow rate in mL/s */
    }

    // ========== Enumerations ==========

    enum def ShellType {
        lipid;
        albumin;
        polymer;
    }

    enum def EchoSource {
        tissue;
        microbubble;
        noise;
    }

    enum def ImagingMode {
        BMode;
        ContrastMode;
        DualMode;
    }

    enum def SystemPowerState {
        poweredOff;
        initializing;
        ready;
        imaging;
        reviewing;
        shuttingDown;
    }

    // ========== Item Definitions ==========

    item def MicrobubbleContrastAgent {
        doc /* Microscopic bubble contrast agent injected into the bloodstream */
        attribute diameter : LengthValue = 2.5 [um];
        attribute shellType : ShellType = ShellType::lipid;
        attribute gasCore : String = "perfluorocarbon";
        attribute concentration : ContrastConcentration;
        attribute stabilityDuration : TimeValue = 300 [s];
    }

    item def UltrasoundPulse {
        doc /* Low-power high-frequency ultrasound pulse transmitted into the body */
        attribute frequency : UltrasoundFrequency;
        attribute power : AcousticPower;
        attribute mechanicalIndex : MechanicalIndex;
        attribute pulseDuration : TimeValue;
        attribute cycleCount : Integer;
    }

    item def EchoSignal {
        doc /* Returning echo signal from tissue and microbubbles */
        attribute amplitude : SignalAmplitude;
        attribute frequency : UltrasoundFrequency;
        attribute phase : Real;
        attribute source : EchoSource;
        attribute depth : LengthValue;
        attribute timestamp : TimeValue;
    }

    item def ProcessedMicrobubbleData {
        doc /* Spatially mapped microbubble data after signal processing */
        attribute xCoordinate : LengthValue;
        attribute yCoordinate : LengthValue;
        attribute intensity : Real;
        attribute timestamp : TimeValue;
        attribute confidenceLevel : Real;
    }

    item def ImageFrame {
        doc /* Reconstructed diagnostic image frame */
        attribute pixelData : Real[0..*];
        attribute frameNumber : Integer;
        attribute timestamp : TimeValue;
        attribute resolution : LengthValue;
        attribute mode : ImagingMode;
    }

    item def OperatorCommand {
        doc /* Command issued by the medical professional operator */
        attribute commandType : String;
        attribute dose : ContrastDose;
        attribute imagingMode : ImagingMode;
        attribute targetRegion : String;
        attribute timestamp : TimeValue;
    }

    item def DisplayOutput {
        doc /* Rendered display output for the operator */
        attribute frames : ImageFrame[0..*];
        attribute annotations : String[0..*];
        attribute patientId : String;
    }

    // ========== Port Definitions ==========

    port def CommandOutPort {
        out command : OperatorCommand;
    }

    port def CommandInPort {
        in command : OperatorCommand;
    }

    port def ContrastOutPort {
        out agent : MicrobubbleContrastAgent;
    }

    port def ContrastInPort {
        in agent : MicrobubbleContrastAgent;
    }

    port def PulseOutPort {
        out pulse : UltrasoundPulse;
    }

    port def PulseInPort {
        in pulse : UltrasoundPulse;
    }

    port def EchoOutPort {
        out echo : EchoSignal;
    }

    port def EchoInPort {
        in echo : EchoSignal;
    }

    port def DataOutPort {
        out data : ProcessedMicrobubbleData;
    }

    port def DataInPort {
        in data : ProcessedMicrobubbleData;
    }

    port def ImageOutPort {
        out frame : ImageFrame;
    }

    port def ImageInPort {
        in frame : ImageFrame;
    }

    // ========== Connection Definitions ==========

    connection def CommandConnection {
        end source : CommandOutPort;
        end target : CommandInPort;
    }

    connection def ContrastDeliveryConnection {
        end source : ContrastOutPort;
        end target : ContrastInPort;
    }

    connection def PulseTransmissionConnection {
        end source : PulseOutPort;
        end target : PulseInPort;
    }

    connection def EchoReturnConnection {
        end source : EchoOutPort;
        end target : EchoInPort;
    }

    connection def ProcessedDataConnection {
        end source : DataOutPort;
        end target : DataInPort;
    }

    connection def ImageDisplayConnection {
        end source : ImageOutPort;
        end target : ImageInPort;
    }

    // ========== Part Definitions ==========

    part def ContrastInjector {
        doc /* Device that precisely injects a controlled dose of microbubble contrast agent into the patient bloodstream */

        port commandIn : CommandInPort;
        port injectionOut : ContrastOutPort;

        attribute maxDose : ContrastDose = 5.0;
        attribute injectionRate : InjectionRate = 1.0;
        attribute reservoirLevel : ContrastDose = 10.0;
        attribute currentDose : ContrastDose = 0.0;
        attribute doseAccuracy : Real = 0.98;

        part syringePump {
            attribute syringeVolume : ContrastDose = 10.0;
            attribute plungerPosition : Real = 0.0;
            attribute motorSpeed : Real = 0.0;
            attribute motorTorque : Real = 0.0;
            attribute stepResolution : Real = 0.01;
        }

        part contrastReservoir {
            attribute volume : ContrastDose = 10.0;
            attribute agent : MicrobubbleContrastAgent;
            attribute temperature : Real = 20.0;
            attribute pressure : Real = 101.3;
        }

        part injectionCatheter {
            attribute gauge : Integer = 20;
            attribute length : LengthValue = 100 [mm];
            attribute innerDiameter : LengthValue = 0.6 [mm];
            attribute sterilityVerified : Boolean = true;
        }

        part valveAssembly {
            attribute valveState : String = "closed";
            attribute flowDirection : String = "forward";
        }

        action def PrimeInjectionLine {
            in reservoirVolume : ContrastDose;
            out primed : Boolean;
        }

        action def DeliverContrastAgent {
            in dose : ContrastDose;
            in agent : MicrobubbleContrastAgent;
            out injectedAgent : MicrobubbleContrastAgent;
        }

        action def FlushInjectionLine {
            in flushVolume : ContrastDose;
            out flushed : Boolean;
        }

        action def VerifyDoseAccuracy {
            in targetDose : ContrastDose;
            in deliveredDose : ContrastDose;
            out accuracyVerified : Boolean;
        }

        state injectorBehavior {
            entry action { reservoirLevel = 10.0; }

            initial Idle;
            state Idle {
                entry action { currentDose = 0.0; }
            }
            state Priming {
                do PrimeInjectionLine;
            }
            state Injecting {
                do DeliverContrastAgent;
            }
            state Verifying {
                do VerifyDoseAccuracy;
            }
            state Flushing {
                do FlushInjectionLine;
            }
            state Complete {
                entry action { /* log injection completion */ }
            }

            transition first Idle then Priming
                when commandIn.command.commandType == "inject";

            transition first Priming then Injecting
                when primingDone == true;

            transition first Injecting then Verifying
                when currentDose >= commandIn.command.dose;

            transition first Verifying then Flushing
                when doseVerified == true;

            transition first Flushing then Complete
                when flushDone == true;

            transition first Complete then Idle
                when resetRequested == true;
        }

        attribute primingDone : Boolean = false;
        attribute doseVerified : Boolean = false;
        attribute flushDone : Boolean = false;
        attribute resetRequested : Boolean = false;
    }

    part def UltrasoundTransducer {
        doc /* Handheld device placed on patient skin that transmits ultrasound pulses and receives returning echoes */

        port pulseOut : PulseOutPort;
        port echoIn : EchoInPort;
        port echoOut : EchoOutPort;

        attribute centerFrequency : UltrasoundFrequency = 5.0;
        attribute bandwidth : UltrasoundFrequency = 2.0;
        attribute elementCount : Integer = 128;
        attribute mechanicalIndex : MechanicalIndex = 0.3;
        attribute acousticPower : AcousticPower = 50.0;
        attribute focusDepth : LengthValue = 40 [mm];
        attribute pulseRepetitionRate : Real = 4000.0;

        part transducerArray {
            attribute elementCount : Integer = 128;
            attribute pitch : LengthValue = 0.3 [mm];
            attribute elevation : LengthValue = 10 [mm];
            attribute kerf : LengthValue = 0.05 [mm];
            attribute elementWidth : LengthValue = 0.25 [mm];
        }

        part beamformer {
            attribute focusDepth : LengthValue = 40 [mm];
            attribute apertureSize : Integer = 64;
            attribute delayResolution : TimeValue = 5 [ns];
            attribute channelCount : Integer = 128;
        }

        part acousticLens {
            attribute material : String = "silicone";
            attribute focalLength : LengthValue = 30 [mm];
            attribute radiusOfCurvature : LengthValue = 15 [mm];
        }

        part matchingLayer {
            attribute acousticImpedance : Real = 2.0;
            attribute thickness : LengthValue = 0.2 [mm];
            attribute layerCount : Integer = 2;
        }

        part backingMaterial {
            attribute impedance : Real = 3.5;
            attribute attenuation : Real = 12.0;
        }

        action def GeneratePulse {
            in frequency : UltrasoundFrequency;
            in power : AcousticPower;
            in mi : MechanicalIndex;
            out pulse : UltrasoundPulse;
        }

        action def ReceiveEcho {
            in incomingEcho : EchoSignal;
            out receivedEcho : EchoSignal;
        }

        action def BeamformSignal {
            in rawEchoes : EchoSignal[0..*];
            out beamformedEcho : EchoSignal;
        }

        action def AmplifyEcho {
            in echo : EchoSignal;
            out amplifiedEcho : EchoSignal;
        }

        action def TimeGainCompensate {
            in echo : EchoSignal;
            out compensatedEcho : EchoSignal;
        }

        state transducerBehavior {
            initial Idle;
            state Idle;
            state Transmitting {
                do GeneratePulse;
            }
            state Receiving {
                do ReceiveEcho;
            }
            state Beamforming {
                do BeamformSignal;
            }
            state Compensating {
                do TimeGainCompensate;
            }
            state Amplifying {
                do AmplifyEcho;
            }

            transition first Idle then Transmitting
                when imagingActive == true;

            transition first Transmitting then Receiving
                after 0.0001 [s];

            transition first Receiving then Beamforming
                when echoReceived == true;

            transition first Beamforming then Compensating
                when beamformComplete == true;

            transition first Compensating then Amplifying
                when compensationComplete == true;

            transition first Amplifying then Transmitting
                when imagingActive == true;

            transition first Amplifying then Idle
                when imagingActive == false;
        }

        attribute imagingActive : Boolean = false;
        attribute echoReceived : Boolean = false;
        attribute beamformComplete : Boolean = false;
        attribute compensationComplete : Boolean = false;
    }

    part def SignalProcessor {
        doc /* Filters echo signals and isolates unique acoustic signatures of resonating microbubbles from tissue background */

        port echoIn : EchoInPort;
        port dataOut : DataOutPort;

        attribute samplingRate : Real = 40.0;
        attribute dynamicRange : Real = 60.0;
        attribute filterBandwidth : UltrasoundFrequency = 2.0;
        attribute harmonicOrder : Integer = 2;
        attribute detectionThreshold : Real = 0.05;
        attribute processingLatency : TimeValue = 5 [ms];

        part analogFrontEnd {
            attribute gain : Real = 40.0;
            attribute noiseFigure : Real = 3.0;
            attribute inputImpedance : Real = 50.0;
            attribute bandwidth : UltrasoundFrequency = 10.0;
        }

    part analogToDigitalConverter {
            attribute resolutionBits : Integer = 14;
            attribute samplingRate : Real = 40.0;
            attribute inputRange : Real = 2.0;
            attribute snr : Real = 75.0;
        }

        part digitalFilter {
            attribute cutoffLow : UltrasoundFrequency = 2.0;
            attribute cutoffHigh : UltrasoundFrequency = 10.0;
            attribute filterOrder : Integer = 64;
            attribute filterType : String = "FIR";
            attribute ripple : Real = 0.1;
        }

        part microbubbleDetector {
            attribute detectionThreshold : Real = 0.05;
            attribute harmonicOrder : Integer = 2;
            attribute sensitivity : Real = 0.95;
            attribute specificity : Real = 0.90;
            attribute minDetectableConcentration : ContrastConcentration = 0.01;
        }

        part tissueSuppressionModule {
            attribute suppressionLevel : Real = 30.0;
            attribute adaptiveFilterEnabled : Boolean = true;
            attribute cancellationDepth : Real = 40.0;
        }

        part pulseInversionModule {
            attribute pulsePairs : Integer = 2;
            attribute cancellationRatio : Real = 35.0;
        }

        action def AmplifySignal {
            in rawEcho : EchoSignal;
            out amplifiedEcho : EchoSignal;
        }

        action def DigitizeSignal {
            in analogEcho : EchoSignal;
            out digitalEcho : EchoSignal;
        }

        action def ApplyBandpassFilter {
            in echo : EchoSignal;
            out filteredEcho : EchoSignal;
        }

        action def SuppressTissueSignal {
            in echo : EchoSignal;
            out suppressedEcho : EchoSignal;
        }

        action def ApplyPulseInversion {
            in echo1 : EchoSignal;
            in echo2 : EchoSignal;
            out invertedEcho : EchoSignal;
        }

        action def DetectMicrobubbleHarmonics {
            in echo : EchoSignal;
            out detectedData : ProcessedMicrobubbleData;
        }

        action def GenerateSpatialData {
            in echo : EchoSignal;
            out data : ProcessedMicrobubbleData;
        }

        state processorBehavior {
            initial Idle;
            state Idle;
            state Acquiring {
                do AmplifySignal;
            }
            state Digitizing {
                do DigitizeSignal;
            }
            state Filtering {
                do ApplyBandpassFilter;
            }
            state Suppressing {
                do SuppressTissueSignal;
            }
            state Inverting {
                do ApplyPulseInversion;
            }
            state Detecting {
                do DetectMicrobubbleHarmonics;
            }
            state Generating {
                do GenerateSpatialData;
            }

            transition first Idle then Acquiring
                when echoAvailable == true;

            transition first Acquiring then Digitizing
                when signalAcquired == true;

            transition first Digitizing then Filtering
                when digitizationComplete == true;

            transition first Filtering then Suppressing
                when filteringComplete == true;

            transition first Suppressing then Inverting
                when suppressionComplete == true;

            transition first Inverting then Detecting
                when inversionComplete == true;

            transition first Detecting then Generating
                when detectionComplete == true;

            transition first Generating then Acquiring
                when echoAvailable == true;

            transition first Generating then Idle
                when echoAvailable == false;
        }

        attribute echoAvailable : Boolean = false;
        attribute signalAcquired : Boolean = false;
        attribute digitizationComplete : Boolean = false;
        attribute filteringComplete : Boolean = false;
        attribute suppressionComplete : Boolean = false;
        attribute inversionComplete : Boolean = false;
        attribute detectionComplete : Boolean = false;
    }

    part def ImageReconstructor {
        doc /* Builds final diagnostic images from processed microbubble data creating real-time video frames */

        port dataIn : DataInPort;
        port imageOut : ImageOutPort;

        attribute frameRate : FrameRate = 25.0;
        attribute spatialResolution : LengthValue = 0.4 [mm];
        attribute scanLines : Integer = 256;
        attribute pixelsPerLine : Integer = 512;
        attribute colorDepth : Integer = 8;
        attribute fieldOfView : LengthValue = 60 [mm];
        attribute depthRange : LengthValue = 80 [mm];
        attribute reconstructionLatency : TimeValue = 10 [ms];

        part scanConverter {
            attribute fieldOfView : LengthValue = 60 [mm];
            attribute depthRange : LengthValue = 80 [mm];
            attribute scanType : String = "sector";
            attribute sectorAngle : Real = 60.0;
            attribute lineDensity : Integer = 256;
        }

        part imageBuffer {
            attribute bufferSize : Integer = 3;
            attribute currentFrame : ImageFrame;
            attribute frameCounter : Integer = 0;
            attribute overflowCount : Integer = 0;
        }

        part displayRenderer {
            attribute colorMap : String = "contrast";
            attribute brightness : Real = 0.5;
            attribute contrast : Real = 0.7;
            attribute gamma : Real = 0.8;
            attribute overlayEnabled : Boolean = true;
        }

        part interpolationEngine {
            attribute method : String = "bilinear";
            attribute upsamplingFactor : Integer = 2;
            attribute kernelSize : Integer = 4;
        }

        part temporalFilter {
            attribute frameAveraging : Integer = 3;
            attribute persistenceFactor : Real = 0.7;
        }

        action def CollectDataPoints {
            in data : ProcessedMicrobubbleData;
            out collectedData : ProcessedMicrobubbleData[0..*];
        }

        action def AssembleFrame {
            in dataPoints : ProcessedMicrobubbleData[0..*];
            out rawFrame : ImageFrame;
        }

        action def InterpolatePixels {
            in rawFrame : ImageFrame;
            out interpolatedFrame : ImageFrame;
        }

        action def ApplyTemporalFilter {
            in frame : ImageFrame;
            out filteredFrame : ImageFrame;
        }

        action def EnhanceContrast {
            in frame : ImageFrame;
            out enhancedFrame : ImageFrame;
        }

        action def RenderFrame {
            in frame : ImageFrame;
            out displayFrame : ImageFrame;
        }

        state reconstructorBehavior {
            initial Idle;
            state Idle;
            state Collecting {
                do CollectDataPoints;
            }
            state Assembling {
                do AssembleFrame;
            }
            state Interpolating {
                do InterpolatePixels;
            }
            state TemporalFiltering {
                do ApplyTemporalFilter;
            }
            state Enhancing {
                do EnhanceContrast;
            }
            state Rendering {
                do RenderFrame;
            }

            transition first Idle then Collecting
                when dataAvailable == true;

            transition first Collecting then Assembling
                when dataCollected == true;

            transition first Assembling then Interpolating
                when frameAssembled == true;

            transition first Interpolating then TemporalFiltering
                when interpolationComplete == true;

            transition first TemporalFiltering then Enhancing
                when temporalFilterComplete == true;

            transition first Enhancing then Rendering
                when enhancementComplete == true;

            transition first Rendering then Collecting
                when dataAvailable == true;

            transition first Rendering then Idle
                when dataAvailable == false;
        }

        attribute dataAvailable : Boolean = false;
        attribute dataCollected : Boolean = false;
        attribute frameAssembled : Boolean = false;
        attribute interpolationComplete : Boolean = false;
        attribute temporalFilterComplete : Boolean = false;
        attribute enhancementComplete : Boolean = false;
    }

    part def OperatorConsole {
        doc /* Interface for the medical professional to operate the CEUS system and view diagnostic images */

        port commandOut : CommandOutPort;
        port imageIn : ImageInPort;

        attribute operatorId : String;
        attribute currentMode : ImagingMode = ImagingMode::ContrastMode;
        attribute systemStatus : String = "ready";
        attribute sessionStartTime : TimeValue;

        part display {
            attribute screenSize : LengthValue = 300 [mm];
            attribute pixelPitch : LengthValue = 0.2 [mm];
            attribute refreshRate : FrameRate = 60.0;
            attribute brightness : Real = 0.6;
        }

        part controlPanel {
            attribute buttonCount : Integer = 12;
            attribute joystickEnabled : Boolean = true;
            attribute trackballEnabled : Boolean = true;
            attribute footswitchConnected : Boolean = true;
        }

        part keyboard {
            attribute keyCount : Integer = 84;
            attribute backlightEnabled : Boolean = true;
        }

        part recordingUnit {
            attribute storageCapacity : Real = 500.0;
            attribute recordingFormat : String = "DICOM";
            attribute compressionEnabled : Boolean = true;
        }

        action def IssueCommand {
            in mode : ImagingMode;
            in dose : ContrastDose;
            in targetRegion : String;
            out command : OperatorCommand;
        }

        action def ViewImage {
            in frame : ImageFrame;
        }

        action def AdjustImagingSettings {
            in parameter : String;
            in value : Real;
        }

        action def SelectImagingMode {
            in mode : ImagingMode;
        }

        action def RecordSession {
            in frames : ImageFrame[0..*];
            out recordingPath : String;
        }

        state consoleBehavior {
            initial Standby;
            state Standby;
            state Ready;
            state Operating;
            state Reviewing;
            state Recording;

            transition first Standby then Ready
                when systemInitialized == true;

            transition first Ready then Operating
                when commandIssued == true;

            transition first Operating then Reviewing
                when imagingStopped == true;

            transition first Reviewing then Operating
                when commandIssued == true;

            transition first Operating then Recording
                when recordingRequested == true;

            transition first Recording then Operating
                when recordingStopped == true;

            transition first Reviewing then Standby
                when shutdownRequested == true;
        }

        attribute systemInitialized : Boolean = false;
        attribute commandIssued : Boolean = false;
        attribute imagingStopped : Boolean = false;
        attribute recordingRequested : Boolean = false;
        attribute recordingStopped : Boolean = false;
        attribute shutdownRequested : Boolean = false;
    }

    part def Patient {
        doc /* The patient receiving the CEUS examination containing the vascular system and target tissue */

        port injectionIn : ContrastInPort;
        port pulseIn : PulseInPort;
        port echoOut : EchoOutPort;

        attribute patientId : String;
        attribute bodyMassIndex : Real;
        attribute heartRate : Real = 72.0;

        part vascularSystem {
            attribute bloodVolume : Real = 5000.0;
            attribute cardiacOutput : Real = 5.0;
            attribute systolicPressure : Real = 120.0;
            attribute diastolicPressure : Real = 80.0;
            attribute vascularResistance : Real = 16.0;
        }

        part targetTissue {
            attribute tissueType : String = "liver";
            attribute depth : LengthValue = 50 [mm];
            attribute microvasculatureDensity : Real = 0.8;
            attribute perfusionRate : Real = 0.5;
            attribute acousticAttenuation : Real = 0.5;
        }

        part skin {
            attribute thickness : LengthValue = 2 [mm];
            attribute acousticImpedance : Real = 1.6;
            attribute soundSpeed : Real = 1540.0;
        }

        part microbubblesInCirculation {
            attribute count : Real = 0.0;
            attribute distributionDepth : LengthValue = 0 [mm];
            attribute degradationRate : Real = 0.01;
        }

        action def CirculateContrast {
            in agent : MicrobubbleContrastAgent;
            out circulatedAgent : MicrobubbleContrastAgent;
        }

        action def GenerateTissueEcho {
            in pulse : UltrasoundPulse;
            out echo : EchoSignal;
        }

        action def ResonateMicrobubbles {
            in pulse : UltrasoundPulse;
            in agent : MicrobubbleContrastAgent;
            out echo : EchoSignal;
        }

        action def AttenuateSignal {
            in incomingPulse : UltrasoundPulse;
            out attenuatedPulse : UltrasoundPulse;
        }
    }

    // ========== Top-Level System ==========

    part def CEUSSystem {
        doc /* Contrast-Enhanced Ultrasound System for creating detailed high-contrast images of blood flow and microvasculature using microbubble contrast agent */

        port systemCommandIn : CommandInPort;
        port systemImageOut : ImageOutPort;

        attribute systemId : String;
        attribute systemVersion : String = "1.0";
        attribute maxMechanicalIndex : MechanicalIndex = 0.5;
        attribute minSpatialResolution : LengthValue = 0.5 [mm];
        attribute minFrameRate : FrameRate = 20.0;
        attribute maxAcousticPower : AcousticPower = 100.0;
        attribute safetyCertified : Boolean = true;

        part operatorConsole : OperatorConsole;
        part contrastInjector : ContrastInjector;
        part ultrasoundTransducer : UltrasoundTransducer;
        part signalProcessor : SignalProcessor;
        part imageReconstructor : ImageReconstructor;
        part patient : Patient;

        connection commandLink : CommandConnection
            connect operatorConsole.commandOut to contrastInjector.commandIn;

        connection contrastDelivery : ContrastDeliveryConnection
            connect contrastInjector.injectionOut to patient.injectionIn;

        connection pulseTransmission : PulseTransmissionConnection
            connect ultrasoundTransducer.pulseOut to patient.pulseIn;

        connection echoReturn : EchoReturnConnection
            connect patient.echoOut to ultrasoundTransducer.echoIn;

        connection echoToProcessor : EchoReturnConnection
            connect ultrasoundTransducer.echoOut to signalProcessor.echoIn;

        connection processedDataLink : ProcessedDataConnection
            connect signalProcessor.dataOut to imageReconstructor.dataIn;

        connection imageToDisplay : ImageDisplayConnection
            connect imageReconstructor.imageOut to operatorConsole.imageIn;

        state systemBehavior {
            initial PoweredOff;
            state PoweredOff {
                entry action { /* system powered down */ }
            }
            state Initializing {
                entry action { /* running self-test and calibration */ }
            }
            state Ready {
                entry action { /* awaiting operator command */ }
            }
            state Imaging {
                entry action { /* active CEUS imaging in progress */ }
            }
            state Reviewing {
                entry action { /* reviewing captured diagnostic images */ }
            }
            state ShuttingDown {
                entry action { /* safe shutdown sequence */ }
            }

            transition first PoweredOff then Initializing
                when powerOn == true;

            transition first Initializing then Ready
                when initializationComplete == true;

            transition first Ready then Imaging
                when imagingCommandReceived == true;

            transition first Imaging then Reviewing
                when imagingStopped == true;

            transition first Reviewing then Imaging
                when imagingCommandReceived == true;

            transition first Reviewing then ShuttingDown
                when shutdownRequested == true;

            transition first Imaging then ShuttingDown
                when shutdownRequested == true;

            transition first ShuttingDown then PoweredOff
                when shutdownComplete == true;
        }

        attribute powerOn : Boolean = false;
        attribute initializationComplete : Boolean = false;
        attribute imagingCommandReceived : Boolean = false;
        attribute imagingStopped : Boolean = false;
        attribute shutdownRequested : Boolean = false;
        attribute shutdownComplete : Boolean = false;
    }

    // ========== Requirements ==========

    requirement def LowAcousticPowerRequirement {
        doc /* System must operate at low acoustic power with mechanical index below 0.5 to avoid damaging microbubbles or harming the patient */
        subject system : CEUSSystem;
        constraint { system.ultrasoundTransducer.mechanicalIndex < 0.5 }
    }

    requirement def MicrobubbleIntegrityRequirement {
        doc /* Acoustic power must not destroy microbubbles during imaging to maintain contrast enhancement throughout examination */
        subject system : CEUSSystem;
        constraint { system.ultrasoundTransducer.mechanicalIndex < 0.5 }
        constraint { system.ultrasoundTransducer.acousticPower < 100.0 }
    }

    requirement def SpatialResolutionRequirement {
        doc /* System must achieve high spatial resolution better than 0.5 mm to visualize microvasculature */
        subject system : CEUSSystem;
        constraint { system.imageReconstructor.spatialResolution < 0.5 [mm] }
    }

    requirement def FrameRateRequirement {
        doc /* System must maintain real-time imaging frame rate of at least 20 frames per second */
        subject system : CEUSSystem;
        constraint { system.imageReconstructor.frameRate >= 20.0 }
    }

    requirement def ContrastSensitivityRequirement {
        doc /* System must be sensitive enough to detect very low concentrations of contrast agent */
        subject system : CEUSSystem;
        constraint { system.signalProcessor.detectionThreshold < 0.1 }
        constraint { system.signalProcessor.microbubbleDetector.minDetectableConcentration < 0.05 }
    }

    requirement def ContrastInjectionRequirement {
        doc /* System must inject a controlled precise dose of microbubble contrast agent upon operator command */
        subject system : CEUSSystem;
        constraint { system.contrastInjector.maxDose <= 5.0 }
        constraint { system.contrastInjector.doseAccuracy > 0.95 }
    }

    requirement def UltrasoundTransmissionRequirement {
        doc /* System must transmit low-power high-frequency ultrasound pulses into the body via handheld transducer */
        subject system : CEUSSystem;
        constraint { system.ultrasoundTransducer.centerFrequency >= 2.0 }
        constraint { system.ultrasoundTransducer.mechanicalIndex < 0.5 }
    }

    requirement def SignalProcessingRequirement {
        doc /* System must filter signals and isolate unique acoustic signatures of resonating microbubbles separating them from tissue background noise */
        subject system : CEUSSystem;
        constraint { system.signalProcessor.microbubbleDetector.sensitivity > 0.9 }
        constraint { system.signalProcessor.microbubbleDetector.specificity > 0.85 }
    }

    requirement def ImageReconstructionRequirement {
        doc /* System must build real-time diagnostic images mapping blood flow and vessel structure for operator interpretation */
        subject system : CEUSSystem;
        constraint { system.imageReconstructor.frameRate >= 20.0 }
        constraint { system.imageReconstructor.spatialResolution < 0.5 [mm] }
    }

    requirement def PatientSafetyRequirement {
        doc /* Entire system must prioritize patient safety operating at low acoustic power to avoid harm */
        subject system : CEUSSystem;
        constraint { system.ultrasoundTransducer.mechanicalIndex < 0.5 }
        constraint { system.maxMechanicalIndex <= 0.5 }
        constraint { system.safetyCertified == true }
    }

    requirement def RealTimeImagingRequirement {
        doc /* System must provide real-time imaging with sufficient frame rate and low latency for clinical decision making */
        subject system : CEUSSystem;
        constraint { system.imageReconstructor.frameRate >= 20.0 }
        constraint { system.signalProcessor.processingLatency < 10 [ms] }
        constraint { system.imageReconstructor.reconstructionLatency < 15 [ms] }
    }

    requirement def CEUSSystemRequirements {
        doc /* Top-level requirements for the Contrast-Enhanced Ultrasound System */
        subject system : CEUSSystem;

        requirement safetyReq : PatientSafetyRequirement;
        requirement powerReq : LowAcousticPowerRequirement;
        requirement integrityReq : MicrobubbleIntegrityRequirement;
        requirement resolutionReq : SpatialResolutionRequirement;
        requirement frameRateReq : FrameRateRequirement;
        requirement sensitivityReq : ContrastSensitivityRequirement;
        requirement injectionReq : ContrastInjectionRequirement;
        requirement transmissionReq : UltrasoundTransmissionRequirement;
        requirement processingReq : SignalProcessingRequirement;
        requirement reconstructionReq : ImageReconstructionRequirement;
        requirement realTimeReq : RealTimeImagingRequirement;
    }

    // ========== Verification Actions ==========

    action def VerifyMechanicalIndex {
        doc /* Verify that the system operates at mechanical index below 0.5 */
        in system : CEUSSystem;
        out result : Boolean;
    }

    action def VerifySpatialResolution {
        doc /* Verify that the system achieves spatial resolution better than 0.5 mm using resolution test phantom */
        in system : CEUSSystem;
        out result : Boolean;
    }

    action def VerifyFrameRate {
        doc /* Verify that the system maintains frame rate of at least 20 fps during real-time imaging */
        in system : CEUSSystem;
        out result : Boolean;
    }

    action def VerifyContrastSensitivity {
        doc /* Verify that the system detects very low concentrations of contrast agent */
        in system : CEUSSystem;
        out result : Boolean;
    }

    action def VerifyContrastInjection {
        doc /* Verify that the system injects controlled dose of contrast agent with required accuracy */
        in system : CEUSSystem;
        out result : Boolean;
    }

    action def VerifyMicrobubbleIntegrity {
        doc /* Verify that acoustic power does not destroy microbubbles during imaging */
        in system : CEUSSystem;
        out result : Boolean;
    }

    action def VerifySignalProcessing {
        doc /* Verify that signal processor correctly isolates microbubble signatures from tissue */
        in system : CEUSSystem;
        out result : Boolean;
    }

    action def VerifyCompleteSystem {
        doc /* Complete system verification against all CEUS requirements */
        in system : CEUSSystem;
        out overallResult : Boolean;

        perform verifyMI : VerifyMechanicalIndex { in system = system; }
        perform verifySR : VerifySpatialResolution { in system = system; }
        perform verifyFR : VerifyFrameRate { in system = system; }
        perform verifyCS : VerifyContrastSensitivity { in system = system; }
        perform verifyCI : VerifyContrastInjection { in system = system; }
        perform verifyMBI : VerifyMicrobubbleIntegrity { in system = system; }
        perform verifySP : VerifySignalProcessing { in system = system; }
    }
}
