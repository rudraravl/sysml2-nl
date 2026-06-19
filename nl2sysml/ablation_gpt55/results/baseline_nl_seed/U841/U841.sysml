package QuantizationBasedSystem {
	private import ScalarValues::*;

	unit def V;
	unit def Hz;
	unit def s;
	unit def bit;
	unit def LSB;

	attribute def VoltageValue :> Real;
	attribute def FrequencyValue :> Real;
	attribute def TimeValue :> Real;
	attribute def InformationValue :> Integer;
	attribute def ErrorValueInLSB :> Real;

	item def AnalogSignalFrame {
		attribute frameDuration : TimeValue = 0.001 [s];
		attribute fullScaleRange : VoltageValue = 10.0 [V];
		attribute maximumAmplitude : VoltageValue = 5.0 [V];
		attribute bandwidth : FrequencyValue = 20000.0 [Hz];
	}

	item def ConditionedAnalogFrame {
		attribute frameDuration : TimeValue = 0.001 [s];
		attribute fullScaleRange : VoltageValue = 10.0 [V];
		attribute maximumAmplitude : VoltageValue = 5.0 [V];
		attribute bandwidth : FrequencyValue = 20000.0 [Hz];
		attribute maximumNoiseAmplitude : VoltageValue = 0.001 [V];
	}

	item def SampledSignalFrame {
		attribute frameDuration : TimeValue = 0.001 [s];
		attribute samplingFrequency : FrequencyValue = 48000.0 [Hz];
		attribute sampleCount : Integer = 48;
		attribute fullScaleRange : VoltageValue = 10.0 [V];
	}

	item def QuantizationConfiguration {
		attribute resolutionBits : InformationValue = 12 [bit];
		attribute levelCount : Integer = 4096;
		attribute samplingFrequency : FrequencyValue = 48000.0 [Hz];
		attribute fullScaleRange : VoltageValue = 10.0 [V];
		attribute quantizationStep : VoltageValue = 0.00244140625 [V];
		attribute maximumPermittedError : ErrorValueInLSB = 0.5 [LSB];
	}

	item def QuantizedFrame {
		attribute frameSampleCount : Integer = 48;
		attribute wordLength : InformationValue = 12 [bit];
		attribute minimumCodeValue : Integer = 0;
		attribute maximumCodeValue : Integer = 4095;
		attribute representedFullScaleRange : VoltageValue = 10.0 [V];
	}

	item def QuantizationReport {
		attribute processedSampleCount : Integer = 48;
		attribute maximumObservedError : ErrorValueInLSB = 0.5 [LSB];
		attribute clippingDetected : Boolean = false;
		attribute overloadDetected : Boolean = false;
		attribute latency : TimeValue = 0.00025 [s];
	}

	item def SystemCommand {
		attribute enableQuantization : Boolean = true;
		attribute requestCalibration : Boolean = false;
		attribute resetFault : Boolean = false;
	}

	item def SystemStatus {
		attribute ready : Boolean = true;
		attribute quantizing : Boolean = false;
		attribute faultPresent : Boolean = false;
		attribute activeResolution : InformationValue = 12 [bit];
		attribute activeSamplingFrequency : FrequencyValue = 48000.0 [Hz];
	}

	item def ClockTick {
		attribute frequency : FrequencyValue = 48000.0 [Hz];
		attribute period : TimeValue = 0.000020833333 [s];
	}

	item def PowerOnCommand;
	item def PowerOffCommand;
	item def QuantizeEnableCommand;
	item def QuantizeDisableCommand;
	item def FaultDetectedEvent;
	item def FaultClearedEvent;

	port def AnalogSignalInputPort {
		in item signal : AnalogSignalFrame;
	}

	port def ConditionedAnalogInputPort {
		in item signal : ConditionedAnalogFrame;
	}

	port def ConditionedAnalogOutputPort {
		out item signal : ConditionedAnalogFrame;
	}

	port def SampledFrameInputPort {
		in item samples : SampledSignalFrame;
	}

	port def SampledFrameOutputPort {
		out item samples : SampledSignalFrame;
	}

	port def QuantizedFrameInputPort {
		in item frame : QuantizedFrame;
	}

	port def QuantizedFrameOutputPort {
		out item frame : QuantizedFrame;
	}

	port def ConfigurationInputPort {
		in item configuration : QuantizationConfiguration;
	}

	port def ConfigurationOutputPort {
		out item configuration : QuantizationConfiguration;
	}

	port def ReportInputPort {
		in item report : QuantizationReport;
	}

	port def ReportOutputPort {
		out item report : QuantizationReport;
	}

	port def CommandInputPort {
		in item command : SystemCommand;
	}

	port def StatusOutputPort {
		out item status : SystemStatus;
	}

	port def ClockInputPort {
		in item tick : ClockTick;
	}

	port def ClockOutputPort {
		out item tick : ClockTick;
	}

	action def ValidateQuantizationConfiguration {
		in item configuration : QuantizationConfiguration;
		out item validConfiguration : QuantizationConfiguration;
	}

	action def ConditionAnalogInput {
		in item rawFrame : AnalogSignalFrame;
		out item conditionedFrame : ConditionedAnalogFrame;
	}

	action def SampleWaveform {
		in item conditionedFrame : ConditionedAnalogFrame;
		in item configuration : QuantizationConfiguration;
		out item sampledFrame : SampledSignalFrame;
	}

	action def AssignUniformQuantizationLevels {
		in item sampledFrame : SampledSignalFrame;
		in item configuration : QuantizationConfiguration;
		out item quantizedFrame : QuantizedFrame;
		out item report : QuantizationReport;
	}

	action def EncodeQuantizedCodes {
		in item quantizedFrame : QuantizedFrame;
		in item configuration : QuantizationConfiguration;
		out item encodedFrame : QuantizedFrame;
	}

	action def PublishQuantizationStatus {
		in item report : QuantizationReport;
		out item status : SystemStatus;
	}

	action def QuantizeAnalogSignal {
		doc /* Primary high-level function: transform a continuous-valued analog input frame into a finite-resolution digital frame by conditioning the input, sampling it at the configured sampling frequency, assigning each sample to the nearest uniform quantization level, encoding the level indices as fixed-width digital words, and reporting quantization error and health status. */

		in item analogInput : AnalogSignalFrame;
		in item configuration : QuantizationConfiguration;
		out item quantizedOutput : QuantizedFrame;
		out item status : SystemStatus;

		action validate : ValidateQuantizationConfiguration;
		action condition : ConditionAnalogInput;
		action sample : SampleWaveform;
		action assignLevels : AssignUniformQuantizationLevels;
		action encode : EncodeQuantizedCodes;
		action publishStatus : PublishQuantizationStatus;

		flow configuration to validate.configuration;
		flow validate.validConfiguration to sample.configuration;
		flow validate.validConfiguration to assignLevels.configuration;
		flow validate.validConfiguration to encode.configuration;
		flow analogInput to condition.rawFrame;
		flow condition.conditionedFrame to sample.conditionedFrame;
		flow sample.sampledFrame to assignLevels.sampledFrame;
		flow assignLevels.quantizedFrame to encode.quantizedFrame;
		flow assignLevels.report to publishStatus.report;
		flow encode.encodedFrame to quantizedOutput;
		flow publishStatus.status to status;
	}

	state def QuantizerOperatingMode {
		entry; then off;

		state off;
		state initializing;
		state ready;
		state quantizing;
		state calibrating;
		state faulted;

		transition offToInitializing
			first off
			accept PowerOnCommand
			then initializing;

		transition initializationComplete
			first initializing
			then ready;

		transition readyToQuantizing
			first ready
			accept QuantizeEnableCommand
			then quantizing;

		transition quantizingToReady
			first quantizing
			accept QuantizeDisableCommand
			then ready;

		transition readyToCalibrating
			first ready
			accept SystemCommand
			then calibrating;

		transition calibrationComplete
			first calibrating
			then ready;

		transition anyReadyFault
			first ready
			accept FaultDetectedEvent
			then faulted;

		transition anyQuantizingFault
			first quantizing
			accept FaultDetectedEvent
			then faulted;

		transition faultCleared
			first faulted
			accept FaultClearedEvent
			then ready;

		transition poweredDown
			first ready
			accept PowerOffCommand
			then off;
	}

	part def InputProtection {
		port externalAnalogIn : AnalogSignalInputPort;
		port protectedAnalogOut : AnalogSignalInputPort;

		attribute maximumInputVoltage : VoltageValue = 12.0 [V];
		attribute inputImpedance : Real = 1000000.0;
		attribute surgeClampVoltage : VoltageValue = 12.5 [V];
	}

	part def AntiAliasingFilter {
		port analogIn : AnalogSignalInputPort;
		port filteredOut : ConditionedAnalogOutputPort;

		attribute cutoffFrequency : FrequencyValue = 22000.0 [Hz];
		attribute stopbandStartFrequency : FrequencyValue = 24000.0 [Hz];
		attribute attenuationAtNyquist : Real = 80.0;
		attribute groupDelay : TimeValue = 0.000050 [s];
	}

	part def SamplingClock {
		port tickOut : ClockOutputPort;

		attribute nominalFrequency : FrequencyValue = 48000.0 [Hz];
		attribute maximumJitter : TimeValue = 0.000000020 [s];
	}

	part def TrackAndHoldSampler {
		port clockIn : ClockInputPort;
		port analogIn : ConditionedAnalogInputPort;
		port sampleOut : SampledFrameOutputPort;
		port configIn : ConfigurationInputPort;

		attribute apertureTime : TimeValue = 0.000000100 [s];
		attribute samplingFrequency : FrequencyValue = 48000.0 [Hz];
		attribute samplesPerFrame : Integer = 48;
	}

	part def UniformQuantizerCore {
		port samplesIn : SampledFrameInputPort;
		port configIn : ConfigurationInputPort;
		port quantizedOut : QuantizedFrameOutputPort;
		port reportOut : ReportOutputPort;

		attribute resolutionBits : InformationValue = 12 [bit];
		attribute levelCount : Integer = 4096;
		attribute fullScaleRange : VoltageValue = 10.0 [V];
		attribute stepSize : VoltageValue = 0.00244140625 [V];
		attribute maximumIdealError : ErrorValueInLSB = 0.5 [LSB];
	}

	part def FixedWordCodeEncoder {
		port quantizedIn : QuantizedFrameInputPort;
		port configIn : ConfigurationInputPort;
		port encodedOut : QuantizedFrameOutputPort;

		attribute outputWordLength : InformationValue = 12 [bit];
		attribute minimumCodeValue : Integer = 0;
		attribute maximumCodeValue : Integer = 4095;
	}

	part def OutputFrameBuffer {
		port frameIn : QuantizedFrameInputPort;
		port frameOut : QuantizedFrameOutputPort;

		attribute bufferDepthFrames : Integer = 4;
		attribute maximumBufferLatency : TimeValue = 0.000050 [s];
	}

	part def QuantizationController {
		port commandIn : CommandInputPort;
		port configOut : ConfigurationOutputPort;
		port reportIn : ReportInputPort;
		port statusOut : StatusOutputPort;

		attribute configuredResolution : InformationValue = 12 [bit];
		attribute configuredSamplingFrequency : FrequencyValue = 48000.0 [Hz];
		attribute configuredFullScaleRange : VoltageValue = 10.0 [V];
		attribute faultRecoveryTime : TimeValue = 0.010 [s];

		exhibit state mode : QuantizerOperatingMode;
	}

	part def QuantizationProcessorSystem {
		doc /* System based on quantization: accepts a bounded analog signal and provides a finite set of digital code words that approximate the signal amplitude at discrete sampling instants. */

		port analogInput : AnalogSignalInputPort;
		port commandInput : CommandInputPort;
		port digitalOutput : QuantizedFrameOutputPort;
		port statusOutput : StatusOutputPort;

		attribute fullScaleInputRange : VoltageValue = 10.0 [V];
		attribute maximumInputBandwidth : FrequencyValue = 20000.0 [Hz];
		attribute configuredSamplingFrequency : FrequencyValue = 48000.0 [Hz];
		attribute resolutionBits : InformationValue = 12 [bit];
		attribute quantizationLevelCount : Integer = 4096;
		attribute quantizationStep : VoltageValue = 0.00244140625 [V];
		attribute maximumQuantizationError : ErrorValueInLSB = 0.5 [LSB];
		attribute maximumEndToEndLatency : TimeValue = 0.00025 [s];

		part inputProtection : InputProtection;
		part antiAliasingFilter : AntiAliasingFilter;
		part samplingClock : SamplingClock;
		part sampler : TrackAndHoldSampler;
		part quantizerCore : UniformQuantizerCore;
		part encoder : FixedWordCodeEncoder;
		part outputBuffer : OutputFrameBuffer;
		part controller : QuantizationController;

		connect analogInput to inputProtection.externalAnalogIn;
		connect inputProtection.protectedAnalogOut to antiAliasingFilter.analogIn;
		connect antiAliasingFilter.filteredOut to sampler.analogIn;
		connect samplingClock.tickOut to sampler.clockIn;
		connect sampler.sampleOut to quantizerCore.samplesIn;
		connect quantizerCore.quantizedOut to encoder.quantizedIn;
		connect encoder.encodedOut to outputBuffer.frameIn;
		connect outputBuffer.frameOut to digitalOutput;
		connect commandInput to controller.commandIn;
		connect controller.configOut to sampler.configIn;
		connect controller.configOut to quantizerCore.configIn;
		connect controller.configOut to encoder.configIn;
		connect quantizerCore.reportOut to controller.reportIn;
		connect controller.statusOut to statusOutput;

		perform action primaryFunction : QuantizeAnalogSignal;

		exhibit state operatingMode : QuantizerOperatingMode;
	}

	requirement def PrimaryQuantizationFunctionRequirement {
		doc /* The system shall perform high-level quantization by converting each bounded analog input frame into a digital output frame containing finite-resolution code words representing sampled amplitudes. */

		subject system : QuantizationProcessorSystem;

		require constraint {
			system.resolutionBits >= 12 [bit]
		}

		require constraint {
			system.quantizationLevelCount == 4096
		}

		require constraint {
			system.configuredSamplingFrequency >= 2.0 * system.maximumInputBandwidth
		}
	}

	requirement def QuantizationAccuracyRequirement {
		doc /* The ideal uniform quantizer shall keep quantization error within one half of one least significant quantization interval for unclipped samples. */

		subject system : QuantizationProcessorSystem;

		require constraint {
			system.maximumQuantizationError <= 0.5 [LSB]
		}
	}

	requirement def QuantizationLatencyRequirement {
		doc /* The system shall complete conditioning, sampling, level assignment, code encoding, and buffering within the specified end-to-end latency. */

		subject system : QuantizationProcessorSystem;

		require constraint {
			system.maximumEndToEndLatency <= 0.00025 [s]
		}
	}

	requirement def InputRangeRequirement {
		doc /* The system shall support a symmetric analog full-scale input range suitable for uniform quantization. */

		subject system : QuantizationProcessorSystem;

		require constraint {
			system.fullScaleInputRange == 10.0 [V]
		}
	}

	part quantizationProcessor : QuantizationProcessorSystem;

	requirement primaryFunctionRequirement : PrimaryQuantizationFunctionRequirement {
		subject system = quantizationProcessor;
	}

	requirement accuracyRequirement : QuantizationAccuracyRequirement {
		subject system = quantizationProcessor;
	}

	requirement latencyRequirement : QuantizationLatencyRequirement {
		subject system = quantizationProcessor;
	}

	requirement inputRangeRequirement : InputRangeRequirement {
		subject system = quantizationProcessor;
	}

	satisfy primaryFunctionRequirement by quantizationProcessor;
	satisfy accuracyRequirement by quantizationProcessor;
	satisfy latencyRequirement by quantizationProcessor;
	satisfy inputRangeRequirement by quantizationProcessor;
}
