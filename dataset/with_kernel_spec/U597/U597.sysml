package SignalAnalysisSystem {
    private import SI::Hz;
    private import SI::s;
    private import ISQ::*;
    private import ScalarValues::Real;
    private import ScalarValues::Integer;

    item def RawSignal {
        attribute sampleRate : ISQ::frequency;
        attribute samples : Real[0..*];
    }
    item def CleanedSignal {
        attribute sampleRate : ISQ::frequency;
        attribute samples : Real[0..*];
    }
    item def FrequencyAnalysisResult {
        attribute dominantFrequency : ISQ::frequency;
        attribute peakAmplitude : Real;
    }
    item def NoiseEstimateResult {
        attribute noiseLevel : Real;
    }
    item def QualityMetrics {
        attribute snr : Real;
        attribute qualityIndex : Real;
    }
    item def AnalysisReport {
        attribute dominantFrequency : ISQ::frequency;
        attribute peakAmplitude : Real;
        attribute snr : Real;
        attribute qualityIndex : Real;
    }
    item def ConfigSettings {
        attribute cutoffFrequency : ISQ::frequency;
        attribute filterOrder : Integer;
    }
    item def ExitCommand;

    port def RawSignalIn {
        in item rawSignal : RawSignal;
    }
    port def CleanedSignalOut {
        out item cleanedSignal : CleanedSignal;
    }
    port def CleanedSignalIn {
        in item cleanedSignal : CleanedSignal;
    }
    port def FreqAnalysisOut {
        out item freqResult : FrequencyAnalysisResult;
    }
    port def NoiseEstimateOut {
        out item noiseResult : NoiseEstimateResult;
    }
    port def FreqAnalysisIn {
        in item freqResult : FrequencyAnalysisResult;
    }
    port def NoiseEstimateIn {
        in item noiseResult : NoiseEstimateResult;
    }
    port def QualityMetricsOut {
        out item qualityMetrics : QualityMetrics;
    }
    port def QualityMetricsIn {
        in item qualityMetrics : QualityMetrics;
    }
    port def FreqAggIn {
        in item freqResult : FrequencyAnalysisResult;
    }
    port def QualityAggIn {
        in item qualityMetrics : QualityMetrics;
    }
    port def ReportOutPort {
        out item report : AnalysisReport;
    }
    port def ConfigInPort {
        in item config : ConfigSettings;
    }

    calc def FilterSignal {
        in rawSignal : RawSignal;
        in cutoffFreq : ISQ::frequency;
        in filterOrder : Integer;
        return cleaned : CleanedSignal;
    }
    calc def AnalyzeFrequency {
        in cleanedSignal : CleanedSignal;
        return result : FrequencyAnalysisResult;
    }
    calc def EstimateNoise {
        in cleanedSignal : CleanedSignal;
        return estimate : NoiseEstimateResult;
    }
    calc def AssessQuality {
        in peakAmplitude : Real;
        in noiseLevel : Real;
        return metrics : QualityMetrics;
    }
    calc def AggregateReport {
        in freqResult : FrequencyAnalysisResult;
        in qualityMetrics : QualityMetrics;
        return report : AnalysisReport;
    }

    part def SignalConditioner {
        port configPort : ConfigInPort;
        port signalIn : RawSignalIn;
        port signalOut : CleanedSignalOut;
        attribute cutoffFrequency : ISQ::frequency = 1000 [Hz];
        attribute filterOrder : Integer = 4;
    }
    part def FrequencyAnalyzer {
        port signalIn : CleanedSignalIn;
        port analysisOut : FreqAnalysisOut;
    }
    part def NoiseEstimator {
        port signalIn : CleanedSignalIn;
        port estimateOut : NoiseEstimateOut;
    }
    part def QualityAssessor {
        port freqIn : FreqAnalysisIn;
        port noiseIn : NoiseEstimateIn;
        port metricsOut : QualityMetricsOut;
    }
    part def DataAggregator {
        port freqIn : FreqAggIn;
        port metricsIn : QualityAggIn;
        port reportOut : ReportOutPort;
    }

    part def SignalAnalysisSystem {
        port rawSignalIn : RawSignalIn;
        port configPort : ConfigInPort;
        port reportOut : ReportOutPort;

        attribute processingTime : ISQ::duration;
        attribute maxProcessingTime : ISQ::duration = 0.1 [s];

        part conditioner : SignalConditioner;
        part freqAnalyzer : FrequencyAnalyzer;
        part noiseEstimator : NoiseEstimator;
        part qualityAssessor : QualityAssessor;
        part dataAggregator : DataAggregator;

        connect rawSignalIn to conditioner.signalIn;
        connect configPort to conditioner.configPort;
        connect conditioner.signalOut to freqAnalyzer.signalIn;
        connect conditioner.signalOut to noiseEstimator.signalIn;
        connect freqAnalyzer.analysisOut to qualityAssessor.freqIn;
        connect noiseEstimator.estimateOut to qualityAssessor.noiseIn;
        connect freqAnalyzer.analysisOut to dataAggregator.freqIn;
        connect qualityAssessor.metricsOut to dataAggregator.metricsIn;
        connect dataAggregator.reportOut to reportOut;

        action powerOnAction;
        action loadConfig;
        action outputReport;

        action processSignal {
            action condition {
                out cleaned;
            }
            then splitFlow;
            fork splitFlow {
                in cleaned;
                out toFreq;
                out toNoise;
            }
            flow condition.cleaned to splitFlow.cleaned;
            then analyzeFreq;
            then estimateNoise;
            flow splitFlow.toFreq to analyzeFreq.cleanedSignal;
            flow splitFlow.toNoise to estimateNoise.cleanedSignal;
            action analyzeFreq {
                in cleanedSignal;
                out freqResult;
            }
            then joinResults;
            action estimateNoise {
                in cleanedSignal;
                out noiseResult;
            }
            then joinResults;
            join joinResults;
            then assess;
            flow analyzeFreq.freqResult to assess.freqResult;
            flow estimateNoise.noiseResult to assess.noiseResult;
            action assess {
                in freqResult;
                in noiseResult;
                out qualityResult;
            }
            then aggregate;
            flow analyzeFreq.freqResult to aggregate.freqResult;
            flow assess.qualityResult to aggregate.qualityResult;
            action aggregate {
                in freqResult;
                in qualityResult;
                out report;
            }
        }

        state systemState {
            entry; then PowerOn;
            state PowerOn {
                do action powerOnAction;
            }
            state Initialize {
                do action loadConfig;
            }
            state Ready;
            state Processing {
                do action processSignal;
            }
            state Outputting {
                do action outputReport;
            }
            transition first PowerOn then Initialize;
            transition first Initialize then Ready;
            transition first Ready accept signal : RawSignal then Processing;
            transition first Processing then Outputting;
            transition first Outputting then Ready;
            accept cmd : ExitCommand then done;
        }
    }

    requirement def ProcessingPerformanceRequirement {
        doc /* The system shall process each incoming signal and produce an analysis report in under 100 milliseconds. */
        attribute maxProcessingTime : ISQ::duration = 0.1 [s];
    }
    requirement def FrequencyAccuracyRequirement {
        doc /* The Frequency Analyzer shall identify the dominant frequency with an accuracy of at least 99 percent. */
        attribute minAccuracy : Real = 0.99;
    }
    requirement def NoiseEstimationAccuracyRequirement {
        doc /* The Noise Estimator shall estimate the background noise level with an accuracy of at least 95 percent. */
        attribute minAccuracy : Real = 0.95;
    }
    requirement def ContinuousOperationRequirement {
        doc /* The system shall continuously monitor the incoming data stream and process signals in a looped manner. */
    }
    requirement def ReportCompletenessRequirement {
        doc /* The Data Aggregator shall produce a report containing dominant frequency, peak amplitude, SNR, and quality index. */
    }

    requirement processingPerformance : ProcessingPerformanceRequirement;
    requirement frequencyAccuracy : FrequencyAccuracyRequirement;
    requirement noiseEstimationAccuracy : NoiseEstimationAccuracyRequirement;
    requirement continuousOperation : ContinuousOperationRequirement;
    requirement reportCompleteness : ReportCompletenessRequirement;

    part signalAnalysisSystem : SignalAnalysisSystem {
        satisfy processingPerformance;
        satisfy continuousOperation;
        satisfy reportCompleteness;

        part :>> conditioner {
            attribute :>> cutoffFrequency = 2000 [Hz];
            attribute :>> filterOrder = 4;
        }
        part :>> freqAnalyzer {
            satisfy frequencyAccuracy;
        }
        part :>> noiseEstimator {
            satisfy noiseEstimationAccuracy;
        }
    }
}
