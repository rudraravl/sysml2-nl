package QuantizationSystemModel {
    import ScalarValues::*;
    import ISQ::*;

    attribute def SampleRate :> frequency;
    attribute def BitDepth :> Integer;
    attribute def QuantizationStep :> real;
    attribute def SignalAmplitude :> real;
    attribute def ErrorMagnitude :> real;
    attribute def CodeWord :> Integer;
    attribute def TimeStamp :> time;

    item def AnalogSample {
        attribute amplitude : SignalAmplitude;
        attribute capturedAt : TimeStamp;
    }

    item def NormalizedSample {
        attribute value : Real;
        attribute capturedAt : TimeStamp;
    }

    item def QuantizedSample {
        attribute levelIndex : CodeWord;
        attribute reconstructedValue : SignalAmplitude;
        attribute quantizationError : ErrorMagnitude;
        attribute capturedAt : TimeStamp;
    }

    item def DigitalCodeStream {
        attribute wordWidth : BitDepth;
        attribute frameRate : SampleRate;
        attribute payload : CodeWord[0..*];
    }

    port def AnalogInputPort {
        in item sample : AnalogSample;
    }

    port def SamplePort {
        out item sample : AnalogSample;
    }

    port def NormalizedSamplePort {
        out item sample : NormalizedSample;
    }

    port def QuantizedSamplePort {
        out item sample : QuantizedSample;
    }

    port def DigitalOutputPort {
        out item stream : DigitalCodeStream;
    }

    port def ControlPort {
        in attribute enable : Boolean;
        in attribute reset : Boolean;
        out attribute ready : Boolean;
        out attribute fault : Boolean;
    }

    part def QuantizationController {
        port control : ControlPort;

        attribute enabled : Boolean = false;
        attribute ready : Boolean = false;
        attribute faulted : Boolean = false;

        state def ControllerStates {
            entry action initialize {
                then enabled = false;
                then ready = false;
                then faulted = false;
            }

            state Idle;
            state Armed;
            state Quantizing;
            state Fault;

            transition first Idle;
            transition Idle_to_Armed
                first Idle
                then Armed
                if control.enable and not control.reset;

            transition Armed_to_Quantizing
                first Armed
                then Quantizing
                if ready;

            transition Quantizing_to_Idle
                first Quantizing
                then Idle
                if not control.enable;

            transition Any_to_Fault
                first Idle
                then Fault
                if faulted;

            transition Fault_to_Idle
                first Fault
                then Idle
                if control.reset;
        }

        perform behavior ControllerStates;
    }

    part def AntiAliasFilter {
        port analogIn : AnalogInputPort;
        port filteredOut : SamplePort;

        attribute cutoffFrequency : frequency = 20000 [Hz];
        attribute passbandRipple : Real = 0.1;
        attribute stopbandAttenuation : Real = 80.0;

        action filterSample {
            in item raw : AnalogSample;
            out item filtered : AnalogSample;

            constraint cutoffLimit {
                raw.amplitude <= filtered.amplitude + 0.000001;
            }
        }
    }

    part def Sampler {
        port filteredIn : AnalogInputPort;
        port sampledOut : SamplePort;

        attribute sampleRate : SampleRate = 48000 [Hz];
        attribute apertureTime : time = 2.0e-6 [s];
        attribute sampleClockJitter : time = 50.0e-12 [s];

        action capture {
            in item filtered : AnalogSample;
            out item sampled : AnalogSample;

            then sampled.amplitude = filtered.amplitude;
            then sampled.capturedAt = filtered.capturedAt;
        }
    }

    part def RangeNormalizer {
        port sampledIn : AnalogInputPort;
        port normalizedOut : NormalizedSamplePort;

        attribute inputMinimum : SignalAmplitude = -1.0;
        attribute inputMaximum : SignalAmplitude = 1.0;

        action normalize {
            in item sampled : AnalogSample;
            out item normalized : NormalizedSample;

            then normalized.value =
                ((sampled.amplitude - inputMinimum) /
                (inputMaximum - inputMinimum)) * 2.0 - 1.0;
            then normalized.capturedAt = sampled.capturedAt;
        }
    }

    part def UniformQuantizer {
        port normalizedIn : NormalizedSamplePort;
        port quantizedOut : QuantizedSamplePort;

        attribute bitDepth : BitDepth = 12;
        attribute numberOfLevels : Integer = 4096;
        attribute minimumValue : Real = -1.0;
        attribute maximumValue : Real = 1.0;
        attribute stepSize : QuantizationStep = 0.00048828125;

        action quantize {
            in item normalized : NormalizedSample;
            out item quantized : QuantizedSample;

            then quantized.levelIndex =
                round((normalized.value - minimumValue) / stepSize);
            then quantized.reconstructedValue =
                minimumValue + quantized.levelIndex * stepSize;
            then quantized.quantizationError =
                abs(normalized.value - quantized.reconstructedValue);
            then quantized.capturedAt = normalized.capturedAt;
        }

        constraint validLevelRange {
            numberOfLevels == 2 ^ bitDepth;
            stepSize == (maximumValue - minimumValue) / numberOfLevels;
        }

        constraint boundedQuantizationError {
            quantizedOut.sample.quantizationError <= stepSize / 2.0;
        }
    }

    part def CodeEncoder {
        port quantizedIn : QuantizedSamplePort;
        port digitalOut : DigitalOutputPort;

        attribute outputWordWidth : BitDepth = 12;
        attribute signedRepresentation : Boolean = false;

        action encode {
            in item quantized : QuantizedSample;
            out item stream : DigitalCodeStream;

            then stream.wordWidth = outputWordWidth;
            then stream.payload = quantized.levelIndex;
        }
    }

    part def ErrorMonitor {
        port observedQuantizedIn : QuantizedSamplePort;
        port status : ControlPort;

        attribute maximumAllowedError : ErrorMagnitude = 0.000244140625;
        attribute overloadDetected : Boolean = false;
        attribute clippingDetected : Boolean = false;

        action evaluateError {
            in item quantized : QuantizedSample;
            out attribute fault : Boolean;

            then fault = quantized.quantizationError > maximumAllowedError;
        }
    }

    part def QuantizationSystem {
        port analogInput : AnalogInputPort;
        port digitalOutput : DigitalOutputPort;
        port control : ControlPort;

        attribute primaryFunction : String =
            "Convert a continuous-amplitude input signal into a bounded-error digital representation by sampling, normalizing, mapping each sample to one of a finite set of quantization levels, and encoding the selected level as a digital code word.";

        attribute nominalSampleRate : SampleRate = 48000 [Hz];
        attribute nominalBitDepth : BitDepth = 12;
        attribute nominalLevels : Integer = 4096;
        attribute nominalInputMinimum : SignalAmplitude = -1.0;
        attribute nominalInputMaximum : SignalAmplitude = 1.0;
        attribute nominalStepSize : QuantizationStep = 0.00048828125;
        attribute maximumQuantizationError : ErrorMagnitude = 0.000244140625;

        part controller : QuantizationController;
        part antiAliasFilter : AntiAliasFilter;
        part sampler : Sampler;
        part normalizer : RangeNormalizer;
        part quantizer : UniformQuantizer;
        part encoder : CodeEncoder;
        part monitor : ErrorMonitor;

        connect analogInput to antiAliasFilter.analogIn;
        connect antiAliasFilter.filteredOut to sampler.filteredIn;
        connect sampler.sampledOut to normalizer.sampledIn;
        connect normalizer.normalizedOut to quantizer.normalizedIn;
        connect quantizer.quantizedOut to encoder.quantizedIn;
        connect encoder.digitalOut to digitalOutput;
        connect quantizer.quantizedOut to monitor.observedQuantizedIn;
        connect control to controller.control;
        connect control to monitor.status;

        action executeQuantizationCycle {
            in item inputSample : AnalogSample;
            out item outputStream : DigitalCodeStream;

            first antiAliasFilter.filterSample;
            then sampler.capture;
            then normalizer.normalize;
            then quantizer.quantize;
            then encoder.encode;
            then monitor.evaluateError;
        }

        state def OperatingStates {
            state PoweredOff;
            state Initializing;
            state Ready;
            state Acquiring;
            state Quantizing;
            state Encoding;
            state Outputting;
            state Faulted;

            transition initial PoweredOff;
            transition powerOn
                first PoweredOff
                then Initializing
                if control.enable;

            transition initialized
                first Initializing
                then Ready
                if controller.ready;

            transition acquireSample
                first Ready
                then Acquiring;

            transition sampleCaptured
                first Acquiring
                then Quantizing;

            transition levelSelected
                first Quantizing
                then Encoding;

            transition codeGenerated
                first Encoding
                then Outputting;

            transition outputComplete
                first Outputting
                then Ready;

            transition faultDetected
                first Quantizing
                then Faulted
                if control.fault;

            transition resetFault
                first Faulted
                then Initializing
                if control.reset;
        }

        perform behavior OperatingStates;

        constraint configuredResolution {
            nominalLevels == 2 ^ nominalBitDepth;
            nominalStepSize ==
                (nominalInputMaximum - nominalInputMinimum) / nominalLevels;
        }

        constraint boundedSystemError {
            maximumQuantizationError <= nominalStepSize / 2.0;
        }
    }

    requirement def PrimaryFunctionRequirement {
        doc
        /* The system shall transform each valid continuous-amplitude input sample into a digital code word representing the nearest available quantization level. */
    }

    requirement def ResolutionRequirement {
        attribute requiredBitDepth : BitDepth = 12;
        doc
        /* The quantizer shall provide at least 12 bits of output resolution. */
    }

    requirement def ErrorBoundRequirement {
        attribute allowedError : ErrorMagnitude = 0.000244140625;
        doc
        /* The absolute quantization error for any in-range normalized sample shall not exceed one half of one quantization step. */
    }

    requirement def ThroughputRequirement {
        attribute requiredSampleRate : SampleRate = 48000 [Hz];
        doc
        /* The system shall process input samples at a sustained rate of at least 48000 samples per second. */
    }

    requirement def OutputFormatRequirement {
        attribute outputWidth : BitDepth = 12;
        doc
        /* The system shall emit one fixed-width digital code word for each quantized input sample. */
    }

    part quantizationSystem : QuantizationSystem;

    requirement primaryFunction : PrimaryFunctionRequirement;
    requirement resolution : ResolutionRequirement;
    requirement errorBound : ErrorBoundRequirement;
    requirement throughput : ThroughputRequirement;
    requirement outputFormat : OutputFormatRequirement;

    satisfy primaryFunction by quantizationSystem;
    satisfy resolution by quantizationSystem.quantizer;
    satisfy errorBound by quantizationSystem.quantizer;
    satisfy throughput by quantizationSystem.sampler;
    satisfy outputFormat by quantizationSystem.encoder;
}