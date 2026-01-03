package AnalyserSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def SignalData {
        attribute timestamp : ISQ::TimeValue;
        attribute amplitude : Real;
        attribute frequency : ISQ::FrequencyValue;
    }

    attribute def AnalysisResult {
        attribute peakAmplitude : Real;
        attribute dominantFrequency : ISQ::FrequencyValue;
        attribute signalToNoiseRatio : Real;
        attribute qualityIndex : Real;
    }

    attribute def ConfigurationParameters {
        attribute samplingRate : ISQ::FrequencyValue;
        attribute filterCutoff : ISQ::FrequencyValue;
        attribute analysisWindow : ISQ::TimeValue;
    }

    port def SignalInputPort {
        in attribute signalData : SignalData;
    }

    port def ResultOutputPort {
        out attribute result : AnalysisResult;
    }

    port def ConfigPort {
        in attribute config : ConfigurationParameters;
    }

    port def PowerPort {
        in attribute powerSupply : ISQ::PowerValue;
    }

    part def SignalConditioner {
        port signalIn : SignalInputPort;
        port signalOut : SignalInputPort;
        port power : PowerPort;

        action def FilterSignal {
            in rawSignal : SignalData;
            in cutoffFreq : ISQ::FrequencyValue;
            out filteredSignal : SignalData;
        }
    }

    part def FrequencyAnalyzer {
        port signalIn : SignalInputPort;
        port power : PowerPort;

        action def ComputeSpectrum {
            in signal : SignalData;
            out dominantFreq : ISQ::FrequencyValue;
            out peakAmp : Real;
        }
    }

    part def NoiseEstimator {
        port signalIn : SignalInputPort;
        port power : PowerPort;

        action def EstimateNoise {
            in signal : SignalData;
            out noiseLevel : Real;
        }
    }

    part def QualityAssessor {
        port power : PowerPort;

        action def CalculateQuality {
            in signalPower : Real;
            in noisePower : Real;
            out snr : Real;
            out quality : Real;
        }
    }

    part def DataAggregator {
        port resultOut : ResultOutputPort;
        port power : PowerPort;

        action def AssembleResult {
            in peakAmp : Real;
            in domFreq : ISQ::FrequencyValue;
            in snr : Real;
            in quality : Real;
            out finalResult : AnalysisResult;
        }
    }

    action def PerformSignalAnalysis {
        in inputSignal : SignalData;
        in configuration : ConfigurationParameters;
        out analysisOutput : AnalysisResult;

        first start;
        then action filterAction : SignalConditioner::FilterSignal {
            in rawSignal = inputSignal;
            in cutoffFreq = configuration.filterCutoff;
            out filteredSignal;
        }
        then fork;
        parallel action analyzeFreq : FrequencyAnalyzer::ComputeSpectrum {
            in signal = filterAction.filteredSignal;
            out dominantFreq;
            out peakAmp;
        }
        parallel action estimateNoise : NoiseEstimator::EstimateNoise {
            in signal = filterAction.filteredSignal;
            out noiseLevel;
        }
        then join;
        then action assessQuality : QualityAssessor::CalculateQuality {
            in signalPower = analyzeFreq.peakAmp;
            in noisePower = estimateNoise.noiseLevel;
            out snr;
            out quality;
        }
        then action aggregate : DataAggregator::AssembleResult {
            in peakAmp = analyzeFreq.peakAmp;
            in domFreq = analyzeFreq.dominantFreq;
            in snr = assessQuality.snr;
            in quality = assessQuality.quality;
            out finalResult;
        }
        then assign analysisOutput := aggregate.finalResult;
        then done;
    }

    state def AnalyserOperationalStates {
        entry; then idle;

        state idle {
            accept PowerOn;
            then initializing;
        }

        state initializing {
            do action loadConfig;
            accept InitComplete;
            then ready;
        }

        state ready {
            accept SignalReceived;
            then processing;
        }

        state processing {
            do action analyze : PerformSignalAnalysis;
            accept AnalysisComplete;
            then outputting;
        }

        state outputting {
            do action sendResult;
            accept ResultSent;
            then ready;
        }

        state ready {
            accept PowerOff;
            then shutdown;
        }

        state shutdown;
    }

    part def Analyser {
        doc /*
            The Analyser system receives continuous signal data streams and performs
            real-time spectral analysis to extract key characteristics including
            dominant frequency components, peak amplitudes, and signal quality metrics.
            It conditions incoming signals through filtering, applies frequency domain
            transformations, estimates noise levels, and computes signal-to-noise ratios
            to produce comprehensive analysis results for downstream processing or display.
        */

        port signalInput : SignalInputPort;
        port resultOutput : ResultOutputPort;
        port configuration : ConfigPort;
        port powerSupply : PowerPort;

        part conditioner : SignalConditioner;
        part freqAnalyzer : FrequencyAnalyzer;
        part noiseEstimator : NoiseEstimator;
        part qualityAssessor : QualityAssessor;
        part aggregator : DataAggregator;

        connection c1 connect signalInput to conditioner.signalIn;
        connection c2 connect conditioner.signalOut to freqAnalyzer.signalIn;
        connection c3 connect conditioner.signalOut to noiseEstimator.signalIn;
        connection c4 connect aggregator.resultOut to resultOutput;

        connection p1 connect powerSupply to conditioner.power;
        connection p2 connect powerSupply to freqAnalyzer.power;
        connection p3 connect powerSupply to noiseEstimator.power;
        connection p4 connect powerSupply to qualityAssessor.power;
        connection p5 connect powerSupply to aggregator.power;

        private attribute currentConfig : ConfigurationParameters;

        perform action continuousAnalysis[*] ordered {
            first start;
            then merge awaitSignal;
            accept signalArrival via signalInput {
                in receivedSignal : SignalData;
            }
            then action processSignal : PerformSignalAnalysis {
                in inputSignal = signalArrival.receivedSignal;
                in configuration = currentConfig;
                out analysisOutput;
            }
            then action deliverResult {
                assign resultOutput.result := processSignal.analysisOutput;
            }
            then awaitSignal;
        }

        exhibit state operationalBehavior : AnalyserOperationalStates;
    }

    part analyserSystem : Analyser;

    requirement def SignalProcessingRequirement {
        doc /*
            The Analyser shall process input signals with sampling rates up to 100 kHz
            and produce analysis results within 100 milliseconds of signal reception.
        */

        require constraint {
            doc /* Maximum processing latency shall not exceed 100 ms. */
        }
    }

    requirement def FrequencyAccuracyRequirement {
        doc /*
            The Analyser shall determine dominant frequency components with accuracy
            better than 0.1% of the measured frequency value.
        */

        require constraint {
            doc /* Frequency measurement error shall be less than 0.1%. */
        }
    }

    requirement def NoiseRejectionRequirement {
        doc /*
            The Analyser shall maintain signal-to-noise ratio measurements accurate
            to within 1 dB across the operating frequency range.
        */

        require constraint {
            doc /* SNR measurement accuracy shall be within ±1 dB. */
        }
    }

    requirement analyserSystemRequirements {
        doc /*
            Top-level requirements governing the Analyser system performance,
            accuracy, and operational characteristics.
        */

        require processingPerformance : SignalProcessingRequirement;
        require frequencyAccuracy : FrequencyAccuracyRequirement;
        require noiseRejection : NoiseRejectionRequirement;

        satisfy by analyserSystem;
    }
}
