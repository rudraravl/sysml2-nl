package ADC_Quantization_System {
	public import Definitions::*;
	public import Usages::*;

	package Definitions {
		private import ScalarValues::*;
		private import ISQ::*;

		attribute def Voltage :> Real;
		attribute def DigitalValue :> Integer;
		attribute def BitDepth :> Integer;
		attribute def SampleRate :> Real;

		item def AnalogSignal {
			attribute voltage : Voltage;
		}
		item def FilteredSignal {
			attribute voltage : Voltage;
		}
		item def AnalogSample {
			attribute voltage : Voltage;
		}
		item def DigitalSample {
			attribute value : DigitalValue;
		}
		item def EncodedSample {
			attribute binary : String;
		}

		port def AnalogOutPort { out analogSignal : AnalogSignal; }
		port def AnalogInPort { in analogSignal : AnalogSignal; }
		port def FilteredOutPort { out filteredSignal : FilteredSignal; }
		port def FilteredInPort { in filteredSignal : FilteredSignal; }
		port def SampleOutPort { out analogSample : AnalogSample; }
		port def SampleInPort { in analogSample : AnalogSample; }
		port def DigitalOutPort { out digitalSample : DigitalSample; }
		port def DigitalInPort { in digitalSample : DigitalSample; }
		port def EncodedOutPort { out encodedSample : EncodedSample; }
		port def EncodedInPort { in encodedSample : EncodedSample; }

		action def GenerateSignal {
			out analogSignal : AnalogSignal;
		}
		action def FilterSignal {
			in analogSignal : AnalogSignal;
			out filteredSignal : FilteredSignal;
		}
		action def SampleSignal {
			in filteredSignal : FilteredSignal;
			out analogSample : AnalogSample;
		}
		action def QuantizeSample {
			in analogSample : AnalogSample;
			out digitalSample : DigitalSample;
		}
		action def EncodeSample {
			in digitalSample : DigitalSample;
			out encodedSample : EncodedSample;
		}
		action def ProcessSample {
			in encodedSample : EncodedSample;
		}

		part def SignalSource {
			port analogOut : AnalogOutPort;
		}
		part def AntiAliasingFilter {
			port analogIn : AnalogInPort;
			port filteredOut : FilteredOutPort;
		}
		part def SampleAndHold {
			port filteredIn : FilteredInPort;
			port sampleOut : SampleOutPort;
			attribute samplingRate : SampleRate := 44100.0;
		}
		part def Quantizer {
			port sampleIn : SampleInPort;
			port digitalOut : DigitalOutPort;
			attribute bitDepth : BitDepth := 12;
			attribute referenceVoltage : Voltage := 5.0;
		}
		part def DigitalEncoder {
			port digitalIn : DigitalInPort;
			port encodedOut : EncodedOutPort;
		}
		part def DigitalProcessor {
			port encodedIn : EncodedInPort;
		}

		attribute def Start;
		attribute def Done;

		state def ADCOperation {
			then state idle;
			accept Start
				then acquire;
			state acquire;
			then convert;
			state convert;
			then encode;
			state encode;
			then transmit;
			state transmit;
			then idle;
		}

		requirement def SamplingRateRequirement {
			attribute minSampleRate : SampleRate = 2000.0;
			attribute maxSignalFrequency : SampleRate = 1000.0;
			doc /* The sampling rate must be at least twice the maximum signal frequency to prevent aliasing. */
			constraint { minSampleRate >= 2.0 * maxSignalFrequency }
		}
		requirement def QuantizationErrorRequirement {
			attribute maxQuantizationError : Voltage = 0.001;
			attribute referenceVoltage : Voltage = 5.0;
			attribute bitDepth : BitDepth = 12;
			doc /* The quantization error must not exceed half the voltage step size determined by the reference voltage and bit depth. */
			constraint { maxQuantizationError <= referenceVoltage / (2.0 ^ bitDepth) }
		}
	}

	package Usages {
		part ADCSystem {
			part signalSource : SignalSource;
			part antiAliasingFilter : AntiAliasingFilter;
			part sampleAndHold : SampleAndHold;
			part quantizer : Quantizer;
			part digitalEncoder : DigitalEncoder;
			part digitalProcessor : DigitalProcessor;

			flow signalSource.analogOut.analogSignal to antiAliasingFilter.analogIn.analogSignal;
			flow antiAliasingFilter.filteredOut.filteredSignal to sampleAndHold.filteredIn.filteredSignal;
			flow sampleAndHold.sampleOut.analogSample to quantizer.sampleIn.analogSample;
			flow quantizer.digitalOut.digitalSample to digitalEncoder.digitalIn.digitalSample;
			flow digitalEncoder.encodedOut.encodedSample to digitalProcessor.encodedIn.encodedSample;

			action adcPipeline {
				action generateSignal : GenerateSignal;
				flow generateSignal.analogSignal to filterSignal.analogSignal;
				action filterSignal : FilterSignal;
				flow filterSignal.filteredSignal to sampleSignal.filteredSignal;
				action sampleSignal : SampleSignal;
				flow sampleSignal.analogSample to quantizeSample.analogSample;
				action quantizeSample : QuantizeSample;
				flow quantizeSample.digitalSample to encodeSample.digitalSample;
				action encodeSample : EncodeSample;
				flow encodeSample.encodedSample to processSample.encodedSample;
				action processSample : ProcessSample;
			}

			state adcOperation : ADCOperation;

			requirement samplingRateReq : SamplingRateRequirement;
			requirement quantizationErrorReq : QuantizationErrorRequirement;
		}
	}
}
