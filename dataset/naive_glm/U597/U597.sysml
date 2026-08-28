package SignalAnalysisSystem {

    import ScalarValues::*;

    /* =========================================================
       Value Types with Units
       ========================================================= */

    value type FrequencyHz :> Real {
        doc /* Frequency measured in Hertz (Hz) */;
    }

    value type AmplitudeV :> Real {
        doc /* Signal amplitude measured in Volts (V) */;
    }

    value type NoiseLevelDb :> Real {
        doc /* Noise level measured in decibels (dB) */;
    }

    value type SNRDb :> Real {
        doc /* Signal-to-noise ratio measured in decibels (dB) */;
    }

    value type QualityIndexScore :> Real {
        doc /* Quality index, normalized score from 0.0 to 1.0 */;
    }

    value type DurationMs :> Real {
        doc /* Duration measured in milliseconds (ms) */;
    }

    value type TimeSeconds :> Real {
        doc /* Time measured in seconds (s) */;
    }

    /* =========================================================
       Item Definitions
       ========================================================= */

    item def SignalSample {
        :>> value : Real;
        :>> timestamp : TimeSeconds;
    }

    item def RawSignal {
        :>> samples : SignalSample[0..*] ordered;
        :>> sampleRate : FrequencyHz;
        :>> signalId : String;
    }

    item def CleanedSignal {
        :>> samples : SignalSample[0..*] ordered;
        :>> sampleRate : FrequencyHz;
        :>> signalId : String;
    }

    item def FrequencyResult {
        :>> dominantFrequency : FrequencyHz;
        :>> peakAmplitude : AmplitudeV;
        :>> signalId : String;
    }

    item def NoiseResult {
        :>> noiseLevel : NoiseLevelDb;
        :>> signalId : String;
    }

    item def QualityMetrics {
        :>> snr : SNRDb;
        :>> qualityIndex : QualityIndexScore;
        :>> signalId : String;
    }

    item def AnalysisReport {
        :>> dominantFrequency : FrequencyHz;
        :>> peakAmplitude : AmplitudeV;
        :>> snr : SNRDb;
        :>> qualityIndex : QualityIndexScore;
        :>> noiseLevel : NoiseLevelDb;
        :>> timestamp : TimeSeconds;
        :>> processingDuration : DurationMs;
        :>> signalId : String;
    }

    item def ConfigParameters {
        :>> cutoffFrequency : FrequencyHz;
        :>> sampleRate : FrequencyHz;
        :>> fftSize : Integer;
    }

    /* =========================================================
       Port Definitions
       ========================================================= */

    port def RawSignalInPort {
        in rawSignal : RawSignal;
    }

    port def CleanedSignalOutPort {
        out cleanedSignal : CleanedSignal;
    }

    port def CleanedSignalInPort {
        in cleanedSignal : CleanedSignal;
    }

    port def FreqResultOutPort {
        out freqResult : FrequencyResult;
    }

    port def FreqResultInPort {
        in freqResult : FrequencyResult;
    }

    port def NoiseResultOutPort {
        out noiseResult : NoiseResult;
    }

    port def NoiseResultInPort {
        in noiseResult : NoiseResult;
    }

    port def QualityMetricsOutPort {
        out qualityMetrics : QualityMetrics;
    }

    port def QualityMetricsInPort {
        in qualityMetrics : QualityMetrics;
    }

    port def ReportOutPort {
        out report : AnalysisReport;
    }

    port def ConfigInPort {
        in config : ConfigParameters;
    }

    /* =========================================================
       Component Definitions
       ========================================================= */

    part def SignalConditioner {
        doc /* Cleans raw signal by applying a low-pass filter at the configured cutoff frequency, removing unwanted noise components. */;

        port configIn : ConfigInPort;
        port rawIn : RawSignalInPort;
        port cleanedOut : CleanedSignalOutPort;

        attribute cutoffFrequency : FrequencyHz;
        attribute rawSignalAvailable : Boolean = false;
        attribute filteringComplete : Boolean = false;

        exhibit state machine ConditioningBehavior {

            state idle {
                entry { rawSignalAvailable = false; }
                do { /* Waiting for raw signal arrival on rawIn port */ }
            }

            state filtering {
                entry { filteringComplete = false; }
                do {
                    /* Read raw signal samples from rawIn */
                    /* Apply digital low-pass filter at cutoffFrequency to each sample */
                    /* Attenuate frequency components above cutoffFrequency */
                    /* Construct CleanedSignal with filtered samples */
                    /* Emit CleanedSignal on cleanedOut port */
                }
                exit { filteringComplete = true; }
            }

            transition receiveSignal
                from idle to filtering
                [rawSignalAvailable];

            transition emitSignal
                from filtering to idle
                [filteringComplete];
        }
    }

    part def FrequencyAnalyzer {
        doc /* Analyzes the cleaned signal to identify the dominant frequency and its corresponding peak amplitude using spectral analysis. */;

        port cleanedIn : CleanedSignalInPort;
        port freqOut : FreqResultOutPort;

        attribute signalAvailable : Boolean = false;
        attribute analysisComplete : Boolean = false;
        attribute configuredFftSize : Integer;

        exhibit state machine FrequencyAnalysisBehavior {

            state idle {
                entry { signalAvailable = false; }
                do { /* Waiting for cleaned signal on cleanedIn port */ }
            }

            state analyzing {
                entry { analysisComplete = false; }
                do {
                    /* Receive CleanedSignal from cleanedIn */
                    /* Apply window function to signal samples */
                    /* Compute Fast Fourier Transform (FFT) of windowed samples */
                    /* Find frequency bin with maximum spectral magnitude */
                    /* Convert bin index to dominant frequency using sample rate */
                    /* Record peak amplitude at dominant frequency */
                    /* Construct FrequencyResult with dominantFrequency and peakAmplitude */
                    /* Emit FrequencyResult on freqOut port */
                }
                exit { analysisComplete = true; }
            }

            transition startAnalysis
                from idle to analyzing
                [signalAvailable];

            transition completeAnalysis
                from analyzing to idle
                [analysisComplete];
        }
    }

    part def NoiseEstimator {
        doc /* Estimates the background noise level present in the cleaned signal by analyzing non-dominant spectral components. */;

        port cleanedIn : CleanedSignalInPort;
        port noiseOut : NoiseResultOutPort;

        attribute signalAvailable : Boolean = false;
        attribute estimationComplete : Boolean = false;

        exhibit state machine NoiseEstimationBehavior {

            state idle {
                entry { signalAvailable = false; }
                do { /* Waiting for cleaned signal on cleanedIn port */ }
            }

            state estimating {
                entry { estimationComplete = false; }
                do {
                    /* Receive CleanedSignal from cleanedIn */
                    /* Compute power spectral density of signal */
                    /* Exclude dominant frequency region from noise computation */
                    /* Average power across remaining spectral bins */
                    /* Convert average noise power to decibel scale */
                    /* Construct NoiseResult with noiseLevel in dB */
                    /* Emit NoiseResult on noiseOut port */
                }
                exit { estimationComplete = true; }
            }

            transition startEstimation
                from idle to estimating
                [signalAvailable];

            transition completeEstimation
                from estimating to idle
                [estimationComplete];
        }
    }

    part def QualityAssessor {
        doc /* Computes the signal-to-noise ratio (SNR) and an overall quality index from the frequency analysis and noise estimation results. */;

        port freqIn : FreqResultInPort;
        port noiseIn : NoiseResultInPort;
        port qualityOut : QualityMetricsOutPort;

        attribute freqResultAvailable : Boolean = false;
        attribute noiseResultAvailable : Boolean = false;
        attribute calculationComplete : Boolean = false;

        exhibit state machine QualityAssessmentBehavior {

            state idle {
                entry {
                    freqResultAvailable = false;
                    noiseResultAvailable = false;
                }
                do { /* Waiting for both frequency and noise results */ }
            }

            state calculating {
                entry { calculationComplete = false; }
                do {
                    /* Receive FrequencyResult from freqIn */
                    /* Receive NoiseResult from noiseIn */
                    /* Compute SNR = 20 * log10(peakAmplitude / noiseLevel) in dB */
                    /* Compute qualityIndex using sigmoid normalization of SNR */
                    /* qualityIndex = 1.0 / (1.0 + exp(-(snr - snrThreshold) / scale)) */
                    /* Construct QualityMetrics with snr and qualityIndex */
                    /* Emit QualityMetrics on qualityOut port */
                }
                exit { calculationComplete = true; }
            }

            transition startCalculation
                from idle to calculating
                [freqResultAvailable & noiseResultAvailable];

            transition completeCalculation
                from calculating to idle
                [calculationComplete];
        }
    }

    part def DataAggregator {
        doc /* Collects all individual analysis results and assembles them into a single comprehensive AnalysisReport for output. */;

        port freqIn : FreqResultInPort;
        port noiseIn : NoiseResultInPort;
        port qualityIn : QualityMetricsInPort;
        port reportOut : ReportOutPort;

        attribute freqResultAvailable : Boolean = false;
        attribute noiseResultAvailable : Boolean = false;
        attribute qualityMetricsAvailable : Boolean = false;
        attribute aggregationComplete : Boolean = false;

        exhibit state machine AggregationBehavior {

            state idle {
                entry {
                    freqResultAvailable = false;
                    noiseResultAvailable = false;
                    qualityMetricsAvailable = false;
                }
                do { /* Waiting for all three result inputs */ }
            }

            state assembling {
                entry { aggregationComplete = false; }
                do {
                    /* Receive FrequencyResult from freqIn */
                    /* Receive NoiseResult from noiseIn */
                    /* Receive QualityMetrics from qualityIn */
                    /* Extract dominantFrequency and peakAmplitude from FrequencyResult */
                    /* Extract noiseLevel from NoiseResult */
                    /* Extract snr and qualityIndex from QualityMetrics */
                    /* Record current timestamp */
                    /* Compute total processingDuration from signal receipt time */
                    /* Construct AnalysisReport with all collected fields */
                    /* Emit AnalysisReport on reportOut port */
                }
                exit { aggregationComplete = true; }
            }

            transition startAggregation
                from idle to assembling
                [freqResultAvailable & noiseResultAvailable & qualityMetricsAvailable];

            transition completeAggregation
                from assembling to idle
                [aggregationComplete];
        }
    }

    /* =========================================================
       Top-Level System Definition
       ========================================================= */

    part def SignalAnalysisSystem {
        doc /* Real-time signal analysis system for continuous monitoring, spectral analysis, and quality reporting of an incoming data stream. */;

        port rawInput : RawSignalInPort;
        port reportOutput : ReportOutPort;
        port configInput : ConfigInPort;

        attribute systemInitialized : Boolean = false;
        attribute signalReceivedFlag : Boolean = false;
        attribute processingCompleteFlag : Boolean = false;
        attribute reportTransmittedFlag : Boolean = false;
        attribute lastProcessingDuration : DurationMs;
        attribute maxProcessingDuration : DurationMs = 100.0;

        part conditioner : SignalConditioner;
        part freqAnalyzer : FrequencyAnalyzer;
        part noiseEstimator : NoiseEstimator;
        part qualityAssessor : QualityAssessor;
        part dataAggregator : DataAggregator;

        /* Port delegations between system boundary and internal components */
        connection delegateConfig connect configInput to conditioner.configIn;
        connection delegateRawInput connect rawInput to conditioner.rawIn;
        connection delegateReportOutput connect dataAggregator.reportOut to reportOutput;

        /* Internal signal flow connections */
        connection cleanedToFreqAnalyzer connect conditioner.cleanedOut to freqAnalyzer.cleanedIn;
        connection cleanedToNoiseEstimator connect conditioner.cleanedOut to noiseEstimator.cleanedIn;
        connection freqToQualityAssessor connect freqAnalyzer.freqOut to qualityAssessor.freqIn;
        connection noiseToQualityAssessor connect noiseEstimator.noiseOut to qualityAssessor.noiseIn;
        connection freqToDataAggregator connect freqAnalyzer.freqOut to dataAggregator.freqIn;
        connection noiseToDataAggregator connect noiseEstimator.noiseOut to dataAggregator.noiseIn;
        connection qualityToDataAggregator connect qualityAssessor.qualityOut to dataAggregator.qualityIn;

        /* System-level state machine governing overall operation */
        exhibit state machine SystemOperation {

            state off {
                entry {
                    systemInitialized = false;
                    signalReceivedFlag = false;
                }
                do { /* System powered off; no activity */ }
            }

            state initializing {
                entry { systemInitialized = false; }
                do {
                    /* Load ConfigParameters from configInput port */
                    /* Propagate cutoffFrequency to signal conditioner */
                    /* Propagate sampleRate and fftSize to frequency analyzer */
                    /* Initialize noise estimator parameters */
                    /* Perform self-test and calibration of all components */
                    /* Verify all component state machines are in idle state */
                }
                exit { systemInitialized = true; }
            }

            state ready {
                entry { signalReceivedFlag = false; }
                do {
                    /* System idle, waiting for next raw signal on rawInput port */
                    /* Upon signal arrival, set signalReceivedFlag to true */
                }
            }

            state processing {
                entry { processingCompleteFlag = false; }
                do {
                    /* Signal conditioner receives raw signal and applies low-pass filter */
                    /* Cleaned signal routed to frequency analyzer and noise estimator in parallel */
                    /* Frequency analyzer computes dominant frequency and peak amplitude */
                    /* Noise estimator computes background noise level */
                    /* Quality assessor receives both results and computes SNR and quality index */
                    /* Data aggregator waits for all three inputs before assembling report */
                    /* Upon completion, set processingCompleteFlag to true */
                }
                exit { processingCompleteFlag = true; }
            }

            state outputting {
                entry { reportTransmittedFlag = false; }
                do {
                    /* Data aggregator assembles comprehensive AnalysisReport */
                    /* Report containing dominant frequency, peak amplitude, SNR, quality index, noise level, and duration */
                    /* Report transmitted on reportOutput port */
                    /* Record lastProcessingDuration for this cycle */
                    /* Upon successful transmission, set reportTransmittedFlag to true */
                }
                exit { reportTransmittedFlag = true; }
            }

            transition powerOn
                from off to initializing;

            transition initializationComplete
                from initializing to ready
                [systemInitialized];

            transition newSignalReceived
                from ready to processing
                [signalReceivedFlag];

            transition processingComplete
                from processing to outputting
                [processingCompleteFlag];

            transition reportComplete
                from outputting to ready
                [reportTransmittedFlag];
        }
    }

    /* =========================================================
       Requirements
       ========================================================= */

    requirement def SignalAnalysisSystemRequirement {
        doc /* Base requirement definition for the real-time signal analysis system. */;
    }

    requirement processingTimeRequirement : SignalAnalysisSystemRequirement {
        doc
            /* The system shall process each incoming signal and produce a complete
               analysis report within 100 milliseconds of signal reception. */;
        subject analysisSystem : SignalAnalysisSystem;
        constraint processingTimeConstraint {
            analysisSystem.lastProcessingDuration <= analysisSystem.maxProcessingDuration
        }
    }

    requirement frequencyAccuracyRequirement : SignalAnalysisSystemRequirement {
        doc
            /* The frequency analyzer shall identify the dominant frequency with
               an accuracy of 1 Hz or better relative to the true signal frequency. */;
        subject freqAnalyzer : FrequencyAnalyzer;
        constraint frequencyAccuracyConstraint {
            /* Dominant frequency measurement error shall not exceed 1 Hz */
        }
    }

    requirement noiseAccuracyRequirement : SignalAnalysisSystemRequirement {
        doc
            /* The noise estimator shall estimate the background noise level with
               an accuracy of 1 dB or better relative to the true noise level. */;
        subject noiseEstimator : NoiseEstimator;
        constraint noiseAccuracyConstraint {
            /* Noise level estimation error shall not exceed 1 dB */
        }
    }

    requirement continuousOperationRequirement : SignalAnalysisSystemRequirement {
        doc
            /* The system shall continuously process incoming signals in a loop,
               returning to the ready state after each signal is processed and
               its analysis report is output, enabling ongoing data stream analysis. */;
        subject analysisSystem : SignalAnalysisSystem;
        constraint continuousOperationConstraint {
            /* System state machine shall transition from outputting back to ready */
            /* No terminal state shall exist after the ready state */
        }
    }

    requirement snrComputationRequirement : SignalAnalysisSystemRequirement {
        doc
            /* The quality assessor shall compute the signal-to-noise ratio (SNR)
               in decibels from the peak amplitude and the estimated noise level,
               and derive a normalized quality index score between 0.0 and 1.0. */;
        subject qualityAssessor : QualityAssessor;
        constraint snrComputationConstraint {
            /* SNR = 20 * log10(peakAmplitude / noiseLevel) expressed in dB */
            /* qualityIndex shall be normalized to the range [0.0, 1.0] */
        }
    }

    requirement reportContentRequirement : SignalAnalysisSystemRequirement {
        doc
            /* The data aggregator shall produce a comprehensive analysis report
               containing the dominant frequency, peak amplitude, SNR, quality index,
               noise level, timestamp, and processing duration for each signal processed. */;
        subject dataAggregator : DataAggregator;
        constraint reportContentConstraint {
            /* Report shall include: dominantFrequency, peakAmplitude, snr,
               qualityIndex, noiseLevel, timestamp, processingDuration, signalId */
        }
    }

    requirement filteringConfigurationRequirement : SignalAnalysisSystemRequirement {
        doc
            /* The signal conditioner shall filter the raw signal using a configurable
               cutoff frequency provided through the configuration parameters,
               attenuating noise components above the cutoff frequency. */;
        subject conditioner : SignalConditioner;
        constraint filteringConfigConstraint {
            /* Low-pass filter shall be applied at the cutoff frequency
               specified in the ConfigParameters */
        }
    }

    requirement parallelProcessingRequirement : SignalAnalysisSystemRequirement {
        doc
            /* The frequency analyzer and noise estimator shall process the cleaned
               signal in parallel to minimize overall processing latency and meet
               the 100-millisecond processing time requirement. */;
        subject analysisSystem : SignalAnalysisSystem;
        constraint parallelProcessingConstraint {
            /* Frequency analysis and noise estimation shall execute concurrently
               on the same cleaned signal input */
        }
    }

    requirement initializationRequirement : SignalAnalysisSystemRequirement {
        doc
            /* The system shall initialize all components with configuration parameters
               upon power-on before entering the ready state for signal processing. */;
        subject analysisSystem : SignalAnalysisSystem;
        constraint initializationConstraint {
            /* System shall pass through initializing state and load
               ConfigParameters before reaching ready state */
        }
    }

    requirement signalConditioningOutputRequirement : SignalAnalysisSystemRequirement {
        doc
            /* The signal conditioner shall output a CleanedSignal that preserves the
               signal content below the cutoff frequency while attenuating noise above it. */;
        subject conditioner : SignalConditioner;
        constraint conditioningOutputConstraint {
            /* CleanedSignal shall contain signal components below cutoffFrequency
               and attenuated components above cutoffFrequency */
        }
    }

    /* =========================================================
       Requirement Satisfaction
       ========================================================= */

    satisfaction satisfyProcessingTime : processingTimeRequirement {
        subject analysisSystem : SignalAnalysisSystem;
        /* Verified by timing measurement of processing cycle duration */
    }

    satisfaction satisfyFrequencyAccuracy : frequencyAccuracyRequirement {
        subject freqAnalyzer : FrequencyAnalyzer;
        /* Verified by comparison of measured dominant frequency to known test signal */
    }

    satisfaction satisfyNoiseAccuracy : noiseAccuracyRequirement {
        subject noiseEstimator : NoiseEstimator;
        /* Verified by comparison of estimated noise level to calibrated noise source */
    }

    satisfaction satisfyContinuousOperation : continuousOperationRequirement {
        subject analysisSystem : SignalAnalysisSystem;
        /* Verified by observing state machine cycling through ready, processing, outputting states */
    }
}
