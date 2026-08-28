package MedicalUltrasoundImagingSystem {
    import ScalarValues::*;

    // ===== Value Types with Units =====
    value type FrequencyMHz { unit "MHz"; }
    value type DepthMm { unit "mm"; }
    value type VoltageMv { unit "mV"; }
    value type TimeUs { unit "us"; }
    value type AcousticPowerMwPerCm2 { unit "mW/cm2"; }
    value type FrameRateFps { unit "fps"; }
    value type GainDb { unit "dB"; }
    value type AngleDeg { unit "deg"; }
    value type PixelCount { unit "px"; }

    // ===== Item Definitions =====
    item def UltrasoundPulse {
        attribute frequency : FrequencyMHz;
        attribute focalDepth : DepthMm;
        attribute steeringAngle : AngleDeg;
        attribute acousticPower : AcousticPowerMwPerCm2;
    }

    item def EchoSignal {
        attribute amplitude : VoltageMv;
        attribute depth : DepthMm;
        attribute timeOfFlight : TimeUs;
    }

    item def ElectricalExcitation {
        attribute voltage : VoltageMv;
        attribute delay : TimeUs;
        attribute channelCount : Integer;
    }

    item def ChannelSignal {
        attribute amplitude : VoltageMv;
        attribute delay : TimeUs;
        attribute channelIndex : Integer;
    }

    item def RFScanLine {
        attribute samples : Integer;
        attribute depthRange : DepthMm;
        attribute lineIndex : Integer;
    }

    item def ProcessedScanLine {
        attribute samples : Integer;
        attribute gainCompensation : GainDb;
        attribute lineIndex : Integer;
    }

    item def PolarImage {
        attribute lineCount : Integer;
        attribute angleRange : AngleDeg;
    }

    item def CartesianImage {
        attribute width : PixelCount;
        attribute height : PixelCount;
    }

    item def EnhancedImage {
        attribute width : PixelCount;
        attribute height : PixelCount;
        attribute speckleReductionLevel : GainDb;
    }

    item def DisplayFrame {
        attribute width : PixelCount;
        attribute height : PixelCount;
        attribute frameNumber : Integer;
    }

    item def OperatorCommand {
        attribute imagingMode : String;
        attribute scanFrequency : FrequencyMHz;
        attribute focalDepth : DepthMm;
        attribute gain : GainDb;
        attribute steeringAngle : AngleDeg;
    }

    // ===== Port Definitions =====
    port def ExcitationOutPort { out excitation : ElectricalExcitation; }
    port def ExcitationInPort { in excitation : ElectricalExcitation; }
    port def ChannelOutPort { out channelSignals : ChannelSignal[*]; }
    port def ChannelInPort { in channelSignals : ChannelSignal[*]; }
    port def RFLineOutPort { out rfLine : RFScanLine; }
    port def RFLineInPort { in rfLine : RFScanLine; }
    port def ProcessedLineOutPort { out processedLine : ProcessedScanLine; }
    port def ProcessedLineInPort { in processedLine : ProcessedScanLine; }
    port def PolarImageInPort { in polarImage : PolarImage; }
    port def CartesianOutPort { out cartesianImage : CartesianImage; }
    port def CartesianInPort { in cartesianImage : CartesianImage; }
    port def EnhancedOutPort { out enhancedImage : EnhancedImage; }
    port def EnhancedInPort { in enhancedImage : EnhancedImage; }
    port def DisplayInPort { in frame : DisplayFrame; }
    port def CommandOutPort { out command : OperatorCommand; }
    port def CommandInPort { in command : OperatorCommand; }
    port def PatientInterfacePort {
        out pulse : UltrasoundPulse;
        in echoes : EchoSignal[*];
    }

    // ===== Requirements =====
    requirement def ImageQualityRequirement {
        doc "The system shall produce images with sufficient resolution and penetration depth.";
        attribute minAxialResolution : DepthMm = 0.5;
        attribute maxPenetrationDepth : DepthMm = 200;
        attribute minFrameRate : FrameRateFps = 30;
    }

    requirement def SafetyRequirement {
        doc "The system shall limit acoustic energy delivered to the patient.";
        attribute maxAcousticPower : AcousticPowerMwPerCm2 = 720;
        attribute thermalIndexLimit : Real = 1.7;
        attribute mechanicalIndexLimit : Real = 1.9;
    }

    requirement def RealTimeRequirement {
        doc "The system shall complete the transmit-receive-display cycle at least 30 times per second.";
        attribute minFrameRate : FrameRateFps = 30;
    }

    requirement def BeamformingRequirement {
        doc "The transmit and receive beamformers shall steer and focus the ultrasound beam to the operator-specified focal depth.";
        attribute focalDepthRange : DepthMm = 10..200;
        attribute steeringAngleRange : AngleDeg = -45..45;
    }

    requirement def SignalProcessingRequirement {
        doc "The signal processing unit shall apply TGC, noise filtering, and dynamic range compression.";
        attribute tgcRange : GainDb = 0..80;
        attribute dynamicRange : GainDb = 60;
    }

    requirement ImagingPerformance : ImageQualityRequirement {
        doc "The system achieves at least the minimum frame rate and resolution for diagnostic imaging.";
    }

    requirement PatientSafety : SafetyRequirement {
        doc "Acoustic output remains below regulatory limits during all operating modes.";
    }

    requirement RealTimeImaging : RealTimeRequirement {
        doc "Live video is displayed at or above the minimum frame rate.";
    }

    requirement BeamformingPerformance : BeamformingRequirement {
        doc "Beam steering and focusing operate within specified ranges.";
    }

    requirement SignalProcessingPerformance : SignalProcessingRequirement {
        doc "Signal processing meets TGC and dynamic range specifications.";
    }

    // ===== Leaf Part Definitions =====
    part def PiezoElement {
        attribute index : Integer;
        attribute sensitivity : GainDb = 50;
        attribute centerFrequency : FrequencyMHz = 5.0;
    }

    part def TransducerProbe {
        doc "Handheld probe with piezoelectric array; converts electrical signals to ultrasound pulses and echoes back to electrical signals.";
        attribute elementCount : Integer = 128;
        attribute centerFrequency : FrequencyMHz = 5.0;
        attribute acousticOutputLimit : AcousticPowerMwPerCm2 = 720;
        attribute bandwidth : GainDb = 20;

        port patientSide : PatientInterfacePort;
        port excitationIn : ExcitationInPort;
        port channelOut : ChannelOutPort;

        part piezoElements : PiezoElement[elementCount];

        action transmitPulse {
            in excitation : ElectricalExcitation;
            out pulse : UltrasoundPulse;
        }

        action receiveEchoes {
            in pulse : UltrasoundPulse;
            out channelSignals : ChannelSignal[*];
        }
    }

    part def ControlConsole {
        doc "User interface for operator control of imaging parameters.";
        attribute selectedMode : String = "B-Mode";
        attribute scanFrequency : FrequencyMHz = 5.0;
        attribute focalDepth : DepthMm = 50;
        attribute gain : GainDb = 60;
        attribute steeringAngle : AngleDeg = 0;

        port commandOut : CommandOutPort;

        action selectMode { in mode : String; }
        action adjustFrequency { in freq : FrequencyMHz; }
        action setFocalDepth { in depth : DepthMm; }
        action setGain { in gainValue : GainDb; }
        action issueCommand { out command : OperatorCommand; }
    }

    part def TransmitBeamformer {
        doc "Generates phased excitation signals to steer and focus the outgoing ultrasound beam.";
        attribute apertureSize : Integer = 64;
        attribute focusDelayResolution : TimeUs = 0.01;
        attribute maxDelay : TimeUs = 10.0;

        port commandIn : CommandInPort;
        port excitationOut : ExcitationOutPort;

        action calculateDelays {
            in command : OperatorCommand;
            out delays : TimeUs[*];
        }

        action generateExcitation {
            in command : OperatorCommand;
            out excitation : ElectricalExcitation;
        }
    }

    part def ReceiveBeamformer {
        doc "Applies dynamic receive delays and sums element signals into a coherent scan line.";
        attribute channelCount : Integer = 128;
        attribute dynamicFocusEnabled : Boolean = true;
        attribute maxReceiveDepth : DepthMm = 200;

        port channelIn : ChannelInPort;
        port rfLineOut : RFLineOutPort;

        action applyDelays {
            in channelSignals : ChannelSignal[*];
            out delayedSignals : ChannelSignal[*];
        }

        action sumChannels {
            in delayedSignals : ChannelSignal[*];
            out rfLine : RFScanLine;
        }
    }

    part def SignalProcessingUnit {
        doc "Filters noise, applies Time Gain Compensation, and compresses dynamic range.";
        attribute tgcCurve : GainDb[10] = (0, 10, 20, 30, 40, 50, 55, 60, 65, 70);
        attribute dynamicRange : GainDb = 60;
        attribute noiseFloor : GainDb = -80;

        port rfLineIn : RFLineInPort;
        port processedLineOut : ProcessedLineOutPort;

        action filterNoise {
            in rfLine : RFScanLine;
            out filteredLine : RFScanLine;
        }

        action applyTGC {
            in filteredLine : RFScanLine;
            out compensatedLine : RFScanLine;
        }

        action compressDynamicRange {
            in compensatedLine : RFScanLine;
            out processedLine : ProcessedScanLine;
        }
    }

    part def ScanConverter {
        doc "Transforms polar scan-line data into a rectangular Cartesian image grid via interpolation.";
        attribute outputWidth : PixelCount = 640;
        attribute outputHeight : PixelCount = 480;
        attribute interpolationMethod : String = "bilinear";

        port polarImageIn : PolarImageInPort;
        port cartesianOut : CartesianOutPort;

        action interpolatePolarToCartesian {
            in polarImage : PolarImage;
            out cartesianImage : CartesianImage;
        }
    }

    part def ImageProcessor {
        doc "Applies speckle reduction and edge enhancement for diagnostic quality.";
        attribute speckleFilterStrength : GainDb = 6;
        attribute edgeEnhancement : GainDb = 3;

        port cartesianIn : CartesianInPort;
        port enhancedOut : EnhancedOutPort;

        action reduceSpeckle {
            in cartesianImage : CartesianImage;
            out denoisedImage : CartesianImage;
        }

        action sharpenEdges {
            in denoisedImage : CartesianImage;
            out enhancedImage : EnhancedImage;
        }
    }

    part def DisplayMonitor {
        doc "Displays live ultrasound video for clinical assessment and measurement.";
        attribute screenWidth : PixelCount = 1024;
        attribute screenHeight : PixelCount = 768;
        attribute refreshRate : FrameRateFps = 60;

        port displayIn : DisplayInPort;

        action renderFrame { in frame : DisplayFrame; }
        action allowMeasurements {
            in frame : DisplayFrame;
            out measurement : String;
        }
    }

    // ===== Action Definitions =====
    action def AcquireFrame {
        doc "One complete transmit-receive-display cycle.";
        in command : OperatorCommand;
        out frame : DisplayFrame;

        action generateExcitation {
            in cmd : OperatorCommand;
            out excitation : ElectricalExcitation;
        }
        action transmitPulse {
            in excitation : ElectricalExcitation;
            out pulse : UltrasoundPulse;
        }
        action receiveEchoes {
            in pulse : UltrasoundPulse;
            out channelSignals : ChannelSignal[*];
        }
        action beamformReceive {
            in channelSignals : ChannelSignal[*];
            out rfLine : RFScanLine;
        }
        action processSignal {
            in rfLine : RFScanLine;
            out processedLine : ProcessedScanLine;
        }
        action convertScan {
            in processedLine : ProcessedScanLine;
            out cartesianImage : CartesianImage;
        }
        action enhanceImage {
            in cartesianImage : CartesianImage;
            out enhancedImage : EnhancedImage;
        }
        action displayFrame {
            in enhancedImage : EnhancedImage;
            out frame : DisplayFrame;
        }

        flow generateExcitation.excitation to transmitPulse.excitation;
        flow transmitPulse.pulse to receiveEchoes.pulse;
        flow receiveEchoes.channelSignals to beamformReceive.channelSignals;
        flow beamformReceive.rfLine to processSignal.rfLine;
        flow processSignal.processedLine to convertScan.processedLine;
        flow convertScan.cartesianImage to enhanceImage.cartesianImage;
        flow enhanceImage.enhancedImage to displayFrame.enhancedImage;
    }

    // ===== State Machine Definition =====
    state machine def ImagingLifecycle {
        doc "Lifecycle of the ultrasound imaging system from power-off through live imaging.";

        entry; then Off;

        state Off {
            doc "System is powered off.";
            entry { powerOffSystem(); }
        }

        transition off_to_Standby
            first Off
            if powerOnRequested
            to Standby;

        state Standby {
            doc "System is powered on but not configured for imaging.";
            entry { initializeComponents(); }
            do { runSelfTest(); }
        }

        transition standby_to_Ready
            first Standby
            if selfTestPassed
            to Ready;

        state Ready {
            doc "System is configured and awaiting scan start command.";
            entry { loadOperatorSettings(); }
        }

        transition ready_to_Imaging
            first Ready
            if scanStartRequested
            to Imaging;

        state Imaging {
            doc "System is actively acquiring and displaying ultrasound frames.";
            entry { startAcquisition(); }
            do { acquireFrameLoop(); }
            exit { stopAcquisition(); }

            state AcquiringLine {
                entry { fireTransmit(); }
                do { collectEchoes(); }
            }
            state ProcessingLine {
                entry { beamformAndProcess(); }
            }
            state RenderingFrame {
                entry { convertAndDisplay(); }
            }

            transition acquire_to_process
                first AcquiringLine
                if lineDataReady
                to ProcessingLine;

            transition process_to_render
                first ProcessingLine
                if frameComplete
                to RenderingFrame;

            transition render_to_acquire
                first RenderingFrame
                if continueScanning
                to AcquiringLine;
        }

        transition imaging_to_Ready
            first Imaging
            if scanStopRequested
            to Ready;

        transition ready_to_Standby
            first Ready
            if idleTimeout
            to Standby;

        transition standby_to_Off
            first Standby
            if powerOffRequested
            to Off;
    }

    // ===== System Part Definition =====
    part def MedicalUltrasoundImagingSystem {
        doc "Complete medical ultrasound imaging system for real-time, non-invasive diagnostic imaging.";

        satisfy ImagingPerformance;
        satisfy PatientSafety;
        satisfy RealTimeImaging;
        satisfy BeamformingPerformance;
        satisfy SignalProcessingPerformance;

        attribute operationalFrameRate : FrameRateFps = 30;
        attribute maxAcousticOutput : AcousticPowerMwPerCm2 = 720;
        attribute systemMode : String = "B-Mode";

        port patientInterface : PatientInterfacePort;
        port operatorInterface : CommandInPort;
        port displayOutput : DisplayInPort;

        part transducerProbe : TransducerProbe {
            port patientSide : PatientInterfacePort;
            port excitationIn : ExcitationInPort;
            port channelOut : ChannelOutPort;
        }

        part controlConsole : ControlConsole {
            port commandOut : CommandOutPort;
        }

        part transmitBeamformer : TransmitBeamformer {
            port commandIn : CommandInPort;
            port excitationOut : ExcitationOutPort;
        }

        part receiveBeamformer : ReceiveBeamformer {
            port channelIn : ChannelInPort;
            port rfLineOut : RFLineOutPort;
        }

        part signalProcessingUnit : SignalProcessingUnit {
            port rfLineIn : RFLineInPort;
            port processedLineOut : ProcessedLineOutPort;
        }

        part scanConverter : ScanConverter {
            port polarImageIn : PolarImageInPort;
            port cartesianOut : CartesianOutPort;
        }

        part imageProcessor : ImageProcessor {
            port cartesianIn : CartesianInPort;
            port enhancedOut : EnhancedOutPort;
        }

        part displayMonitor : DisplayMonitor {
            port displayIn : DisplayInPort;
        }

        // ===== Connections =====
        connection operatorToTransmit
            connect controlConsole.commandOut to transmitBeamformer.commandIn;

        connection transmitToProbe
            connect transmitBeamformer.excitationOut to transducerProbe.excitationIn;

        connection probeToReceive
            connect transducerProbe.channelOut to receiveBeamformer.channelIn;

        connection receiveToProcessing
            connect receiveBeamformer.rfLineOut to signalProcessingUnit.rfLineIn;

        connection processingToScanConverter
            connect signalProcessingUnit.processedLineOut to scanConverter.polarImageIn;

        connection scanConverterToImageProcessor
            connect scanConverter.cartesianOut to imageProcessor.cartesianIn;

        connection imageProcessorToDisplay
            connect imageProcessor.enhancedOut to displayMonitor.displayIn;

        // System-level port delegation
        connection patientInterfaceDelegate
            connect patientInterface to transducerProbe.patientSide;

        connection operatorInterfaceDelegate
            connect operatorInterface to controlConsole.commandOut;

        connection displayOutputDelegate
            connect displayOutput to displayMonitor.displayIn;

        // ===== State Machine =====
        exhibit state machine : ImagingLifecycle;

        // ===== Frame Acquisition Action =====
        action acquireFrame : AcquireFrame {
            in command : OperatorCommand;
            out frame : DisplayFrame;
        }
    }
}
