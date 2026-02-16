package QuantizationSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    
    attribute def VoltageValue :> ISQ::VoltageValue;
    attribute def BitDepthValue :> ScalarValues::Integer;
    attribute def QuantizationStepValue :> ScalarValues::Real;
    attribute def SampleRateValue :> ISQ::FrequencyValue;
    
    item def ContinuousSignal {
        attribute amplitude : VoltageValue;
        attribute timestamp : ISQ::TimeValue;
    }
    
    item def QuantizedSample {
        attribute digitalCode : ScalarValues::Integer;
        attribute quantizationLevel : ScalarValues::Integer;
        attribute timestamp : ISQ::TimeValue;
        attribute error : VoltageValue;
    }
    
    port def AnalogInputPort {
        in item signal : ContinuousSignal;
    }
    
    port def DigitalOutputPort {
        out item sample : QuantizedSample;
    }
    
    part def SignalSource {
        port analogOut : AnalogInputPort;
        attribute signalAmplitude : VoltageValue;
        attribute signalFrequency : ISQ::FrequencyValue;
    }
    
    part def AntiAliasingFilter {
        port analogIn : AnalogInputPort;
        port analogOut : AnalogInputPort;
        attribute cutoffFrequency : ISQ::FrequencyValue;
        
        action def FilterSignal {
            in inputSignal : ContinuousSignal;
            out filteredSignal : ContinuousSignal;
        }
    }
    
    part def SampleAndHold {
        port analogIn : AnalogInputPort;
        port analogOut : AnalogInputPort;
        attribute samplingRate : SampleRateValue;
        attribute aperture : ISQ::TimeValue;
        
        action def CaptureSample {
            in continuousInput : ContinuousSignal;
            out heldSample : ContinuousSignal;
            
            first start;
            then assign heldSample.amplitude := continuousInput.amplitude;
            then assign heldSample.timestamp := continuousInput.timestamp;
            then done;
        }
    }
    
    part def Quantizer {
        port analogIn : AnalogInputPort;
        port digitalOut : DigitalOutputPort;
        
        attribute bitDepth : BitDepthValue;
        attribute referenceVoltage : VoltageValue;
        attribute numberOfLevels : ScalarValues::Integer;
        attribute stepSize : QuantizationStepValue;
        
        action def ComputeQuantization {
            in analogValue : VoltageValue;
            in refVoltage : VoltageValue;
            in resolution : BitDepthValue;
            out quantizedCode : ScalarValues::Integer;
            out quantizationError : VoltageValue;
            
            private attribute levels : ScalarValues::Integer;
            private attribute step : ScalarValues::Real;
            private attribute normalizedValue : ScalarValues::Real;
            private attribute rawCode : ScalarValues::Real;
            private attribute clampedCode : ScalarValues::Integer;
            
            first start;
            then assign levels := 2 ** resolution;
            then assign step := refVoltage / (levels - 1);
            then assign normalizedValue := analogValue / step;
            then assign rawCode := normalizedValue;
            then decide;
                if rawCode < 0.0 then assign clampedCode := 0;
                if rawCode >= 0.0 and rawCode < levels then assign clampedCode := rawCode;
                if rawCode >= levels then assign clampedCode := levels - 1;
            then assign quantizedCode := clampedCode;
            then assign quantizationError := analogValue - (clampedCode * step);
            then done;
        }
        
        perform action quantizationProcess : ComputeQuantization;
    }
    
    part def DigitalEncoder {
        port digitalIn : DigitalOutputPort;
        port digitalOut : DigitalOutputPort;
        attribute encodingScheme : ScalarValues::String;
        
        action def EncodeData {
            in rawCode : ScalarValues::Integer;
            in scheme : ScalarValues::String;
            out encodedSample : QuantizedSample;
            
            first start;
            then assign encodedSample.digitalCode := rawCode;
            then assign encodedSample.quantizationLevel := rawCode;
            then done;
        }
    }
    
    part def DigitalProcessor {
        port dataIn : DigitalOutputPort;
        attribute processingRate : ISQ::FrequencyValue;
    }
    
    state def QuantizationStateMachine {
        entry; then idle;
        
        state idle;
        accept at idle
            then acquiring
            when SignalPresent;
        
        state acquiring {
            entry action captureInput : SampleAndHold::CaptureSample;
        }
        then converting;
        
        state converting {
            entry action performQuantization : Quantizer::ComputeQuantization;
        }
        then encoding;
        
        state encoding {
            entry action encodeOutput : DigitalEncoder::EncodeData;
        }
        then transmitting;
        
        state transmitting;
        accept at transmitting
            then idle
            when TransmissionComplete;
    }
    
    action def QuantizationProcess {
        in continuousInput : ContinuousSignal;
        in bitResolution : BitDepthValue;
        in vReference : VoltageValue;
        in sampleRate : SampleRateValue;
        out digitalOutput : QuantizedSample;
        out totalError : VoltageValue;
        
        first start;
        then action filterInput : AntiAliasingFilter::FilterSignal {
            in inputSignal = continuousInput;
            out filteredSignal;
        }
        then action sampleInput : SampleAndHold::CaptureSample {
            in continuousInput = filterInput.filteredSignal;
            out heldSample;
        }
        then action quantizeValue : Quantizer::ComputeQuantization {
            in analogValue = sampleInput.heldSample.amplitude;
            in refVoltage = vReference;
            in resolution = bitResolution;
            out quantizedCode;
            out quantizationError;
        }
        then action encodeResult : DigitalEncoder::EncodeData {
            in rawCode = quantizeValue.quantizedCode;
            in scheme = "binary";
            out encodedSample;
        }
        then assign digitalOutput := encodeResult.encodedSample;
        then assign totalError := quantizeValue.quantizationError;
        then done;
    }
    
    part quantizationSystem : QuantizationSystem {
        doc /* 
        A quantization system that converts continuous analog signals into discrete 
        digital representations. The system samples the input signal at a specified 
        rate, maps each sample to the nearest quantization level based on bit depth 
        and reference voltage, and outputs encoded digital samples with bounded error.
        */
        
        attribute systemBitDepth : BitDepthValue = 12;
        attribute systemReferenceVoltage : VoltageValue = 3.3;
        attribute systemSamplingRate : SampleRateValue = 48000.0;
        attribute systemCutoffFrequency : ISQ::FrequencyValue = 20000.0;
        
        part source : SignalSource {
            signalAmplitude = 2.5;
            signalFrequency = 1000.0;
        }
        
        part filter : AntiAliasingFilter {
            cutoffFrequency = quantizationSystem.systemCutoffFrequency;
        }
        
        part sampler : SampleAndHold {
            samplingRate = quantizationSystem.systemSamplingRate;
            aperture = 100.0;
        }
        
        part quantizer : Quantizer {
            bitDepth = quantizationSystem.systemBitDepth;
            referenceVoltage = quantizationSystem.systemReferenceVoltage;
            numberOfLevels = 4096;
            stepSize = 0.000805;
        }
        
        part encoder : DigitalEncoder {
            encodingScheme = "twos_complement";
        }
        
        part processor : DigitalProcessor {
            processingRate = 48000.0;
        }
        
        connect source.analogOut to filter.analogIn;
        connect filter.analogOut to sampler.analogIn;
        connect sampler.analogOut to quantizer.analogIn;
        connect quantizer.digitalOut to encoder.digitalIn;
        connect encoder.digitalOut to processor.dataIn;
        
        perform behavior systemStateMachine : QuantizationStateMachine;
        
        perform action mainProcess : QuantizationProcess {
            in bitResolution = systemBitDepth;
            in vReference = systemReferenceVoltage;
            in sampleRate = systemSamplingRate;
        }
    }
    
    requirement def QuantizationAccuracyRequirement {
        doc /* 
        The quantization error shall not exceed plus or minus one half of the 
        quantization step size to ensure signal fidelity.
        */
        
        subject quantizer : Quantizer;
        
        require constraint {
            quantizer.stepSize == quantizer.referenceVoltage / (quantizer.numberOfLevels - 1)
        }
    }
    
    requirement def NyquistSamplingRequirement {
        doc /* 
        The sampling rate shall be at least twice the maximum signal frequency 
        to prevent aliasing according to the Nyquist-Shannon theorem.
        */
        
        subject sampler : SampleAndHold;
        
        attribute maxSignalFrequency : ISQ::FrequencyValue;
        
        require constraint {
            sampler.samplingRate >= 2.0 * maxSignalFrequency
        }
    }
    
    requirement def BitDepthRequirement {
        doc /* 
        The quantizer shall support a minimum bit depth of 8 bits to provide 
        adequate dynamic range for typical signal processing applications.
        */
        
        subject quantizer : Quantizer;
        
        require constraint {
            quantizer.bitDepth >= 8
        }
    }
    
    requirement def SystemPerformanceRequirement {
        doc /* 
        The quantization system shall convert analog signals to digital samples 
        with specified accuracy, sampling rate compliance, and bit depth.
        */
        
        subject system : QuantizationSystem;
        
        require accuracyCompliance : QuantizationAccuracyRequirement;
        require samplingCompliance : NyquistSamplingRequirement;
        require resolutionCompliance : BitDepthRequirement;
        
        require constraint {
            system.systemBitDepth >= 8 and
            system.systemSamplingRate > 0.0 and
            system.systemReferenceVoltage > 0.0
        }
    }
}
