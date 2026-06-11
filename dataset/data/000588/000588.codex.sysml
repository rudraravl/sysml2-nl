package DopplerEchocardiographySystem {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;
    import Time::*;

    attribute def Frequency :> ISQ::frequency {
        unit = SI::hertz;
    }

    attribute def AcousticPower :> ISQ::power {
        unit = SI::watt;
    }

    attribute def Pressure :> ISQ::pressure {
        unit = SI::pascal;
    }

    attribute def Velocity :> ISQ::speed {
        unit = SI::metrePerSecond;
    }

    attribute def Distance :> ISQ::length {
        unit = SI::metre;
    }

    attribute def Angle :> ISQ::planeAngle {
        unit = SI::radian;
    }

    attribute def TimeDuration :> ISQ::duration {
        unit = SI::second;
    }

    attribute def Voltage :> ISQ::electricPotential {
        unit = SI::volt;
    }

    attribute def SampleRate :> ISQ::frequency {
        unit = SI::hertz;
    }

    attribute def DataRate {
        unit = "bit/s";
    }

    enum def ImagingMode {
        enum BMode;
        enum ColorDoppler;
        enum PulsedWaveDoppler;
        enum ContinuousWaveDoppler;
        enum TissueDoppler;
    }

    enum def ExamState {
        enum Off;
        enum Standby;
        enum ProbeReady;
        enum Imaging;
        enum DopplerMeasuring;
        enum Frozen;
        enum ReportReady;
        enum Fault;
    }

    item def ElectricalPower {
        attribute supplyVoltage : Voltage;
        attribute maxCurrent {
            unit = SI::ampere;
        }
    }

    item def UltrasoundPulse {
        attribute centerFrequency : Frequency;
        attribute acousticPower : AcousticPower;
        attribute pulseDuration : TimeDuration;
        attribute beamAngle : Angle;
        attribute focalDepth : Distance;
    }

    item def BackscatterEcho {
        attribute receiveFrequency : Frequency;
        attribute amplitude : Pressure;
        attribute timeOfFlight : TimeDuration;
        attribute phaseShift : Angle;
        attribute signalToNoiseRatio {
            unit = "dB";
        }
    }

    item def DopplerSpectrum {
        attribute peakVelocity : Velocity;
        attribute meanVelocity : Velocity;
        attribute velocityTimeIntegral : Distance;
        attribute spectralEnvelopeQuality {
            unit = "percent";
        }
        attribute sampleVolumeDepth : Distance;
        attribute insonationAngle : Angle;
    }

    item def ColorFlowMap {
        attribute frameRate : Frequency;
        attribute maxAliasingVelocity : Velocity;
        attribute regionWidth : Distance;
        attribute regionDepth : Distance;
    }

    item def CardiacMeasurementSet {
        attribute transmitralEVelocity : Velocity;
        attribute transmitralAVelocity : Velocity;
        attribute eToARatio;
        attribute leftVentricularOutflowPeakVelocity : Velocity;
        attribute pressureGradient : Pressure;
        attribute heartRate : Frequency;
    }

    item def PatientDemographics {
        attribute patientId;
        attribute age {
            unit = "yr";
        }
        attribute height : Distance;
        attribute mass {
            unit = SI::kilogram;
        }
    }

    item def OperatorCommand {
        attribute selectedMode : ImagingMode;
        attribute requestedDepth : Distance;
        attribute requestedGain {
            unit = "dB";
        }
        attribute freezeRequested : Boolean;
        attribute saveRequested : Boolean;
    }

    item def DisplayImageFrame {
        attribute frameRate : Frequency;
        attribute dynamicRange {
            unit = "dB";
        }
        attribute pixelWidth;
        attribute pixelHeight;
    }

    item def DiagnosticReport {
        attribute patientId;
        attribute examTimestamp;
        attribute summaryText;
        attribute abnormalFlowDetected : Boolean;
        attribute measurementConfidence {
            unit = "percent";
        }
    }

    port def PowerInputPort {
        in item power : ElectricalPower;
    }

    port def AcousticTransmitPort {
        out item pulse : UltrasoundPulse;
    }

    port def AcousticReceivePort {
        in item echo : BackscatterEcho;
    }

    port def ProbeDataPort {
        out item echoStream : BackscatterEcho;
        in item transmitPulse : UltrasoundPulse;
    }

    port def ControlPort {
        in item command : OperatorCommand;
    }

    port def ImageOutputPort {
        out item image : DisplayImageFrame;
        out item colorMap : ColorFlowMap;
        out item spectrum : DopplerSpectrum;
    }

    port def ReportOutputPort {
        out item report : DiagnosticReport;
    }

    port def MeasurementPort {
        out item measurements : CardiacMeasurementSet;
    }

    part def PhasedArrayTransducer {
        attribute elementCount = 128;
        attribute nominalCenterFrequency : Frequency = 3.5 [SI::megahertz];
        attribute bandwidth : Frequency = 2.0 [SI::megahertz];
        attribute maximumAcousticPower : AcousticPower = 0.72 [SI::watt];
        attribute apertureWidth : Distance = 0.022 [SI::metre];

        port powerPort : PowerInputPort;
        port acousticOut : AcousticTransmitPort;
        port acousticIn : AcousticReceivePort;
        port dataPort : ProbeDataPort;

        action def TransmitFocusedPulse {
            in attribute mode : ImagingMode;
            in attribute focusDepth : Distance;
            in attribute steeringAngle : Angle;
            out item emittedPulse : UltrasoundPulse;

            first start;
            then configureArray;
            then excitePiezoElements;
            then emitAcousticWave;
            then done;

            action configureArray;
            action excitePiezoElements;
            action emitAcousticWave;
        }

        action def ReceiveEcho {
            in item returningEcho : BackscatterEcho;
            out item digitizableEcho : BackscatterEcho;

            first start;
            then convertPressureToVoltage;
            then preAmplifySignal;
            then done;

            action convertPressureToVoltage;
            action preAmplifySignal;
        }
    }

    part def Beamformer {
        attribute transmitDelayResolution : TimeDuration = 5.0e-9 [SI::second];
        attribute receiveChannelCount = 128;
        attribute maxSteeringAngle : Angle = 0.52 [SI::radian];

        port probePort : ProbeDataPort;

        action def FormTransmitBeam {
            in item requestedPulse : UltrasoundPulse;
            out item focusedPulse : UltrasoundPulse;

            first start;
            then computeElementDelays;
            then applyApodization;
            then outputFocusedPulse;
            then done;

            action computeElementDelays;
            action applyApodization;
            action outputFocusedPulse;
        }

        action def FormReceiveBeam {
            in item rawEcho : BackscatterEcho;
            out item beamformedEcho : BackscatterEcho;

            first start;
            then applyDynamicFocusing;
            then sumReceiveChannels;
            then rejectOffAxisEchoes;
            then done;

            action applyDynamicFocusing;
            action sumReceiveChannels;
            action rejectOffAxisEchoes;
        }
    }

    part def AnalogFrontEnd {
        attribute receiveGain {
            unit = "dB";
        } = 42;
        attribute noiseFloor {
            unit = "dBV";
        } = -118;
        attribute antiAliasCutoff : Frequency = 12 [SI::megahertz];

        action def ConditionEchoSignal {
            in item beamformedEcho : BackscatterEcho;
            out item conditionedEcho : BackscatterEcho;

            first start;
            then timeGainCompensation;
            then bandpassFilter;
            then limitSaturation;
            then done;

            action timeGainCompensation;
            action bandpassFilter;
            action limitSaturation;
        }
    }

    part def Digitizer {
        attribute sampleRate : SampleRate = 60 [SI::megahertz];
        attribute adcResolution {
            unit = "bit";
        } = 14;
        attribute inputRange : Voltage = 2.0 [SI::volt];

        action def ConvertEchoToSamples {
            in item analogEcho : BackscatterEcho;
            out item sampledEcho : BackscatterEcho;

            first start;
            then sampleAndHold;
            then quantizeAmplitude;
            then timestampSamples;
            then done;

            action sampleAndHold;
            action quantizeAmplitude;
            action timestampSamples;
        }
    }

    part def DopplerProcessor {
        attribute pulseRepetitionFrequency : Frequency = 5.0 [SI::kilohertz];
        attribute wallFilterCutoff : Frequency = 100 [SI::hertz];
        attribute dopplerAngleCorrection : Angle = 0.35 [SI::radian];
        attribute maxMeasurableVelocity : Velocity = 2.5 [SI::metrePerSecond];

        port measurementsOut : MeasurementPort;

        action def EstimateBloodVelocity {
            in item sampledEcho : BackscatterEcho;
            in attribute transmitFrequency : Frequency;
            in attribute insonationAngle : Angle;
            out item spectrum : DopplerSpectrum;

            first start;
            then removeStationaryTissueSignal;
            then computeFrequencyShift;
            then correctForBeamAngle;
            then generateSpectralEnvelope;
            then done;

            action removeStationaryTissueSignal;
            action computeFrequencyShift;
            action correctForBeamAngle;
            action generateSpectralEnvelope;
        }

        action def CreateColorFlowMap {
            in item sampledEcho : BackscatterEcho;
            out item flowMap : ColorFlowMap;

            first start;
            then estimateAutocorrelationPhaseShift;
            then assignVelocityAndVariance;
            then overlayFlowDirectionColor;
            then done;

            action estimateAutocorrelationPhaseShift;
            action assignVelocityAndVariance;
            action overlayFlowDirectionColor;
        }
    }

    part def ImageProcessor {
        attribute bModeFrameRate : Frequency = 60 [SI::hertz];
        attribute dopplerFrameRate : Frequency = 25 [SI::hertz];
        attribute dynamicRange {
            unit = "dB";
        } = 72;

        port imageOut : ImageOutputPort;

        action def BuildDisplayFrame {
            in item sampledEcho : BackscatterEcho;
            in item spectrum : DopplerSpectrum;
            in item flowMap : ColorFlowMap;
            out item frame : DisplayImageFrame;

            first start;
            then reconstructAnatomicalImage;
            then registerDopplerOverlay;
            then scaleGrayAndColorMaps;
            then composeDisplayFrame;
            then done;

            action reconstructAnatomicalImage;
            action registerDopplerOverlay;
            action scaleGrayAndColorMaps;
            action composeDisplayFrame;
        }
    }

    part def MeasurementEngine {
        attribute minimumConfidence {
            unit = "percent";
        } = 85;
        attribute maxAllowedAngleCorrection : Angle = 1.05 [SI::radian];

        port measurementPort : MeasurementPort;

        action def DeriveCardiacMeasurements {
            in item spectrum : DopplerSpectrum;
            out item measurementSet : CardiacMeasurementSet;

            first start;
            then traceSpectralEnvelope;
            then calculatePeakAndMeanVelocities;
            then calculatePressureGradient;
            then calculateVelocityTimeIntegral;
            then validateMeasurementConfidence;
            then done;

            action traceSpectralEnvelope;
            action calculatePeakAndMeanVelocities;
            action calculatePressureGradient;
            action calculateVelocityTimeIntegral;
            action validateMeasurementConfidence;
        }
    }

    part def UserInterface {
        attribute brightness {
            unit = "cd/m^2";
        } = 450;
        attribute screenDiagonal : Distance = 0.61 [SI::metre];

        port controlIn : ControlPort;
        port imageIn : ImageOutputPort;
        port reportOut : ReportOutputPort;

        action def PresentExamView {
            in item displayFrame : DisplayImageFrame;
            in item spectrum : DopplerSpectrum;
            in item flowMap : ColorFlowMap;

            first start;
            then renderBModeImage;
            then renderColorFlowOverlay;
            then renderDopplerSpectrum;
            then done;

            action renderBModeImage;
            action renderColorFlowOverlay;
            action renderDopplerSpectrum;
        }

        action def CaptureOperatorCommand {
            out item command : OperatorCommand;

            first start;
            then readModeSelection;
            then readGainDepthAndSampleVolume;
            then publishCommand;
            then done;

            action readModeSelection;
            action readGainDepthAndSampleVolume;
            action publishCommand;
        }
    }

    part def ReportGenerator {
        attribute reportFormat = "DICOM-SR";
        attribute retentionPeriod {
            unit = "yr";
        } = 7;

        port measurementIn : MeasurementPort;
        port reportOut : ReportOutputPort;

        action def GenerateDiagnosticReport {
            in item patient : PatientDemographics;
            in item measurements : CardiacMeasurementSet;
            out item report : DiagnosticReport;

            first start;
            then assemblePatientContext;
            then insertDopplerMeasurements;
            then classifyFlowPattern;
            then assignConfidence;
            then produceReport;
            then done;

            action assemblePatientContext;
            action insertDopplerMeasurements;
            action classifyFlowPattern;
            action assignConfidence;
            action produceReport;
        }
    }

    part def DopplerEchocardiographySystem {
        attribute primaryFunction = "Acquire ultrasound echoes from the heart, detect Doppler frequency shifts caused by moving blood and tissue, estimate cardiovascular flow velocities, and present anatomical images, flow overlays, spectra, and measurements for clinical interpretation.";

        attribute supportedModes : ImagingMode[5] = (ImagingMode::BMode, ImagingMode::ColorDoppler, ImagingMode::PulsedWaveDoppler, ImagingMode::ContinuousWaveDoppler, ImagingMode::TissueDoppler);
        attribute acousticOutputLimit : AcousticPower = 0.72 [SI::watt];
        attribute maximumImagingDepth : Distance = 0.24 [SI::metre];
        attribute velocityAccuracy : Velocity = 0.08 [SI::metrePerSecond];
        attribute bootTime : TimeDuration = 18 [SI::second];

        port mainsPower : PowerInputPort;
        port operatorControl : ControlPort;
        port clinicalOutput : ReportOutputPort;

        part transducer : PhasedArrayTransducer;
        part beamformer : Beamformer;
        part analogFrontEnd : AnalogFrontEnd;
        part digitizer : Digitizer;
        part dopplerProcessor : DopplerProcessor;
        part imageProcessor : ImageProcessor;
        part measurementEngine : MeasurementEngine;
        part userInterface : UserInterface;
        part reportGenerator : ReportGenerator;

        connect mainsPower to transducer.powerPort;
        connect transducer.dataPort to beamformer.probePort;
        connect dopplerProcessor.measurementsOut to measurementEngine.measurementPort;
        connect imageProcessor.imageOut to userInterface.imageIn;
        connect measurementEngine.measurementPort to reportGenerator.measurementIn;
        connect reportGenerator.reportOut to clinicalOutput;
        connect operatorControl to userInterface.controlIn;

        state def ExamControl {
            entry action initializeHardware;

            state off;
            state standby;
            state probeReady;
            state imaging;
            state dopplerMeasuring;
            state frozen;
            state reportReady;
            state fault;

            transition first off;
            transition off_to_standby
                first off
                then standby
                accept powerApplied;

            transition standby_to_probeReady
                first standby
                then probeReady
                accept probeConnected;

            transition probeReady_to_imaging
                first probeReady
                then imaging
                accept imagingModeSelected
                do configureBeamformer;

            transition imaging_to_doppler
                first imaging
                then dopplerMeasuring
                accept dopplerModeSelected
                do enableDopplerProcessing;

            transition doppler_to_imaging
                first dopplerMeasuring
                then imaging
                accept bModeSelected
                do disableDopplerProcessing;

            transition imaging_to_frozen
                first imaging
                then frozen
                accept freezeRequested
                do freezeDisplayBuffer;

            transition doppler_to_frozen
                first dopplerMeasuring
                then frozen
                accept freezeRequested
                do freezeDisplayBuffer;

            transition frozen_to_imaging
                first frozen
                then imaging
                accept unfreezeRequested
                do resumeAcquisition;

            transition frozen_to_reportReady
                first frozen
                then reportReady
                accept saveRequested
                do generateExamReport;

            transition any_to_fault
                first standby
                then fault
                accept hardwareFaultDetected
                do stopAcousticOutput;

            transition fault_to_standby
                first fault
                then standby
                accept faultCleared
                do reinitializeHardware;

            action initializeHardware;
            action configureBeamformer;
            action enableDopplerProcessing;
            action disableDopplerProcessing;
            action freezeDisplayBuffer;
            action resumeAcquisition;
            action generateExamReport;
            action stopAcousticOutput;
            action reinitializeHardware;
        }

        perform action AcquisitionAndProcessingLoop {
            in item command : OperatorCommand;
            in item patient : PatientDemographics;
            out item report : DiagnosticReport;

            first start;
            then captureCommand;
            then transmitPulse;
            then receiveEcho;
            then formBeam;
            then conditionSignal;
            then digitizeEcho;
            then processDoppler;
            then createImage;
            then deriveMeasurements;
            then displayResults;
            then generateReport;
            then done;

            action captureCommand : UserInterface::CaptureOperatorCommand;
            action transmitPulse : PhasedArrayTransducer::TransmitFocusedPulse;
            action receiveEcho : PhasedArrayTransducer::ReceiveEcho;
            action formBeam : Beamformer::FormReceiveBeam;
            action conditionSignal : AnalogFrontEnd::ConditionEchoSignal;
            action digitizeEcho : Digitizer::ConvertEchoToSamples;
            action processDoppler : DopplerProcessor::EstimateBloodVelocity;
            action createImage : ImageProcessor::BuildDisplayFrame;
            action deriveMeasurements : MeasurementEngine::DeriveCardiacMeasurements;
            action displayResults : UserInterface::PresentExamView;
            action generateReport : ReportGenerator::GenerateDiagnosticReport;
        }
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The system shall use Doppler echocardiography to noninvasively assess cardiac structure and blood-flow dynamics by transmitting ultrasound into the chest, receiving cardiac echoes, estimating Doppler frequency shifts, calculating flow velocities, and presenting clinically useful images, spectra, and measurements. */

        subject system : DopplerEchocardiographySystem;

        require constraint {
            system.maximumImagingDepth >= 0.18 [SI::metre]
        }

        require constraint {
            system.velocityAccuracy <= 0.10 [SI::metrePerSecond]
        }
    }

    requirement def AcousticSafetyRequirement {
        doc /* The system shall limit acoustic transmit output during all Doppler modes to reduce patient exposure while preserving diagnostic signal quality. */

        subject system : DopplerEchocardiographySystem;

        require constraint {
            system.acousticOutputLimit <= 0.72 [SI::watt]
        }
    }

    requirement def DopplerMeasurementRequirement {
        doc /* The system shall estimate blood-flow velocity from Doppler frequency shift using transmit frequency, received frequency, speed of sound in tissue, and insonation angle correction. */

        subject processor : DopplerProcessor;

        attribute nominalSpeedOfSound : Velocity = 1540 [SI::metrePerSecond];

        require constraint {
            processor.maxMeasurableVelocity >= 2.0 [SI::metrePerSecond]
        }

        require constraint {
            processor.dopplerAngleCorrection <= 1.05 [SI::radian]
        }
    }

    requirement def DisplayRequirement {
        doc /* The system shall display anatomical heart images, color flow direction, velocity variance, spectral Doppler waveform, and derived cardiac measurements during an examination. */

        subject imageProcessor : ImageProcessor;

        require constraint {
            imageProcessor.dopplerFrameRate >= 20 [SI::hertz]
        }

        require constraint {
            imageProcessor.dynamicRange >= 60
        }
    }

    requirement def ReportRequirement {
        doc /* The system shall produce a diagnostic exam report containing patient identity, Doppler measurements, confidence indication, abnormal-flow indication, and exam timestamp. */

        subject reportGenerator : ReportGenerator;

        require constraint {
            reportGenerator.retentionPeriod >= 7
        }
    }

    satisfy PrimaryFunctionRequirement by DopplerEchocardiographySystem;
    satisfy AcousticSafetyRequirement by DopplerEchocardiographySystem;
    satisfy DopplerMeasurementRequirement by DopplerProcessor;
    satisfy DisplayRequirement by ImageProcessor;
    satisfy ReportRequirement by ReportGenerator;
}