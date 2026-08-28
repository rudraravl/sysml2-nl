package DigitalQuantizationSystem {
    import ScalarValues::*;
    import ISQ::*;

    attribute def Voltage :> Real { unit "V" }
    attribute def Frequency :> Real { unit "Hz" }
    attribute def Time :> Real { unit "s" }
    attribute def BitDepth :> Integer;
    attribute def DigitalLevel :> Integer;

    item def AnalogSignal {
        attribute amplitude : Voltage;
        attribute frequency : Frequency;
    }

    item def FilteredSignal :> AnalogSignal;

    item def AnalogSample {
        attribute voltage : Voltage;
        attribute timestamp : Time;
    }

    item def RawDigitalValue {
        attribute level : DigitalLevel;
    }

    item def EncodedSample {
        attribute binaryValue : String;
        attribute bitDepth : BitDepth;
    }

    port def AnalogPort {
        out item signal : AnalogSignal;
    }

    port def FilteredPort {
        out item signal : FilteredSignal;
    }

    port def SamplePort {
        out item sample : AnalogSample;
    }

    port def RawDigitalPort {
        out item value : RawDigitalValue;
    }

    port def EncodedPort {
        out item sample : EncodedSample;
    }

    part def SignalSource {
        out port analogOut : AnalogPort;
        attribute maxFrequency : Frequency = 20000 [Hz];
        
        action def generateSignal {
            out signal : AnalogSignal;
        }
    }

    part def AntiAliasingFilter {
        in port analogIn : ~AnalogPort;
        out port filteredOut : FilteredPort;
        attribute cutoffFrequency : Frequency = 20000 [Hz];
        
        action def filterSignal {
            in signal : AnalogSignal;
            out filtered : FilteredSignal;
        }
    }

    part def SampleAndHold {
        in port filteredIn : ~FilteredPort;
        out port sampleOut : SamplePort;
        attribute samplingRate : Frequency = 44100 [Hz];
        attribute samplePeriod : Time = 1 / samplingRate;
        
        action def captureSample {
            in signal : FilteredSignal;
            out sample : AnalogSample;
        }
    }

    part def Quantizer {
        in port sampleIn : ~SamplePort;
        out port digitalOut : RawDigitalPort;
        attribute bitDepth : BitDepth = 12;
        attribute referenceVoltage : Voltage = 5.0 [V];
        attribute numLevels : Integer = 2^bitDepth;
        
        action def quantize {
            in sample : AnalogSample;
            out value : RawDigitalValue;
        }
    }

    part def DigitalEncoder {
        in port rawIn : ~RawDigitalPort;
        out port encodedOut : EncodedPort;
        attribute encodingFormat : String = "Binary";
        
        action def encode {
            in value : RawDigitalValue;
            out sample : EncodedSample;
        }
    }

    part def DigitalProcessor {
        in port dataIn : ~EncodedPort;
        attribute buffer : EncodedSample[0..*];
        
        action def processData {
            in sample : EncodedSample;
        }
    }

    part def ADCSystem {
        part source : SignalSource;
        part filter : AntiAliasingFilter;
        part sampler : SampleAndHold;
        part quantizer : Quantizer;
        part encoder : DigitalEncoder;
        part processor : DigitalProcessor;

        connection source.analogOut to filter.analogIn;
        connection filter.filteredOut to sampler.filteredIn;
        connection sampler.sampleOut to quantizer.sampleIn;
        connection quantizer.digitalOut to encoder.rawIn;
        connection encoder.encodedOut to processor.dataIn;

        state machine ADCStateMachine {
            state idle;
            state acquiring {
                entry action capture : sampler.captureSample;
            }
            state converting {
                entry action quantize : quantizer.quantize;
            }
            state encoding {
                entry action encode : encoder.encode;
            }
            state transmitting {
                entry action process : processor.processData;
            }

            transition idle -> acquiring when true;
            transition acquiring -> converting when true;
            transition converting -> encoding when true;
            transition encoding -> transmitting when true;
            transition transmitting -> idle when true;
        }
    }

    requirement def SystemRequirements {
        requirement SamplingRateRequirement {
            doc "The sampling rate must be at least twice the maximum signal frequency to prevent aliasing."
            attribute minSamplingRate : Frequency = 40000 [Hz];
        }
        requirement QuantizationResolutionRequirement {
            doc "The quantizer must support at least 12 bits of resolution."
            attribute minBitDepth : BitDepth = 12;
        }
        requirement SignalFidelityRequirement {
            doc "The system must minimize quantization error to maintain signal fidelity."
        }
    }
}
