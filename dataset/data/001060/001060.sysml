package 'Frequency Domain Sensing Unit' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def FrequencyValue :> ISQ::FrequencyValue;
	
	attribute def AmplitudeValue :> ISQ::VoltageValue;
	
	attribute def PhaseValue {
		attribute magnitude : Real;
		attribute unit : AngleUnit;
	}
	
	attribute def AngleUnit;
	
	item def TimeDomainSignal {
		attribute samplingRate : FrequencyValue;
		attribute samples : Real[1..*] ordered;
		attribute duration : ISQ::TimeValue;
		attribute amplitude : AmplitudeValue;
	}
	
	item def FrequencySpectrum {
		attribute frequencies : FrequencyValue[1..*] ordered;
		attribute magnitudes : AmplitudeValue[1..*] ordered;
		attribute phases : PhaseValue[1..*] ordered;
		attribute dominantFrequency : FrequencyValue;
		attribute totalPower : ISQ::PowerValue;
	}
	
	port def SignalInputPort {
		in item physicalSignal : TimeDomainSignal;
	}
	
	port def SpectrumOutputPort {
		out item spectrum : FrequencySpectrum;
	}
	
	port def DataOutputPort {
		out attribute frequency : FrequencyValue;
		out attribute power : ISQ::PowerValue;
		out attribute quality : Real;
	}
	
	action def AcquireSignal {
		in item inputSignal : TimeDomainSignal;
		out item bufferedSignal : TimeDomainSignal;
	}
	
	action def ApplyWindow {
		in item signal : TimeDomainSignal;
		out item windowedSignal : TimeDomainSignal;
	}
	
	action def ComputeFFT {
		in item timeSignal : TimeDomainSignal;
		out item spectrum : FrequencySpectrum;
	}
	
	action def ExtractFeatures {
		in item spectrum : FrequencySpectrum;
		out attribute peakFrequency : FrequencyValue;
		out attribute signalPower : ISQ::PowerValue;
		out attribute signalQuality : Real;
	}
	
	action def FrequencyAnalysis {
		in item rawSignal : TimeDomainSignal;
		out item analyzedSpectrum : FrequencySpectrum;
		out attribute measuredFrequency : FrequencyValue;
		out attribute measuredPower : ISQ::PowerValue;
		out attribute qualityMetric : Real;
		
		bind acquire.inputSignal = rawSignal;
		
		action acquire : AcquireSignal {
			in inputSignal;
			out bufferedSignal;
		}
		
		then succession flow from acquire.bufferedSignal to window.signal;
		
		action window : ApplyWindow {
			in signal;
			out windowedSignal;
		}
		
		then succession flow from window.windowedSignal to fft.timeSignal;
		
		action fft : ComputeFFT {
			in timeSignal;
			out spectrum;
		}
		
		then succession flow from fft.spectrum to extract.spectrum;
		
		action extract : ExtractFeatures {
			in spectrum;
			out peakFrequency;
			out signalPower;
			out signalQuality;
		}
		
		bind fft.spectrum = analyzedSpectrum;
		bind extract.peakFrequency = measuredFrequency;
		bind extract.signalPower = measuredPower;
		bind extract.signalQuality = qualityMetric;
	}
	
	state def SensorOperationalStates {
		entry; then idle;
		
		state idle {
			entry action initializeSensor;
		}
		
		transition idle_to_ready
			first idle
			then ready;
		
		state ready;
		
		transition ready_to_acquiring
			first ready
			then acquiring;
		
		state acquiring {
			entry action beginAcquisition;
			do action captureData;
		}
		
		transition acquiring_to_processing
			first acquiring
			then processing;
		
		state processing {
			entry action startProcessing;
			do action performFFT;
			do action analyzeSpectrum;
		}
		
		transition processing_to_outputting
			first processing
			then outputting;
		
		state outputting {
			entry action prepareOutput;
			do action transmitResults;
		}
		
		transition outputting_to_ready
			first outputting
			then ready;
		
		state error {
			entry action logError;
		}
		
		transition error_to_idle
			first error
			then idle;
	}
	
	part def FrequencyDomainSensor {
		attribute sensorId : String;
		attribute samplingFrequency : FrequencyValue;
		attribute fftSize : Integer;
		attribute frequencyResolution : FrequencyValue;
		attribute measurementBandwidth : FrequencyValue[2];
		attribute sensitivity : AmplitudeValue;
		
		port signalInput : SignalInputPort;
		port spectrumOutput : SpectrumOutputPort;
		port dataOutput : DataOutputPort;
		
		part signalProcessor {
			perform analysis : FrequencyAnalysis;
		}
		
		part operationalController {
			exhibit states : SensorOperationalStates;
		}
		
		connection inputConnection
			connect signalInput.physicalSignal to signalProcessor.analysis.rawSignal;
		
		connection spectrumConnection
			connect signalProcessor.analysis.analyzedSpectrum to spectrumOutput.spectrum;
		
		connection frequencyConnection
			connect signalProcessor.analysis.measuredFrequency to dataOutput.frequency;
		
		connection powerConnection
			connect signalProcessor.analysis.measuredPower to dataOutput.power;
		
		connection qualityConnection
			connect signalProcessor.analysis.qualityMetric to dataOutput.quality;
	}
	
	part def AnalogFrontEnd {
		attribute inputImpedance : Real;
		attribute gain : Real;
		attribute bandwidth : FrequencyValue;
		
		port analogInput;
		port digitalOutput;
	}
	
	part def DigitalSignalProcessor {
		attribute clockFrequency : FrequencyValue;
		attribute memorySize : Integer;
		attribute processingPower : Real;
		
		port dataInput;
		port dataOutput;
	}
	
	part def PowerManagement {
		attribute inputVoltage : ISQ::VoltageValue;
		attribute outputVoltage : ISQ::VoltageValue;
		attribute efficiency : Real;
		
		port powerInput;
		port powerOutput;
	}
	
	part def CommunicationInterface {
		attribute protocol : String;
		attribute baudRate : Real;
		attribute bufferSize : Integer;
		
		port dataPort;
		port commPort;
	}
	
	part def SensingUnit {
		attribute unitId : String;
		attribute operatingTemperature : ISQ::TemperatureValue;
		attribute powerConsumption : ISQ::PowerValue;
		attribute calibrationDate : String;
		
		part sensor : FrequencyDomainSensor[1] {
			attribute :>> sensorId = "FDS-2024-001";
			attribute :>> fftSize = 4096;
		}
		
		part analogFrontEnd : AnalogFrontEnd[1] {
			attribute :>> inputImpedance = 1000000.0;
			attribute :>> gain = 100.0;
		}
		
		part dsp : DigitalSignalProcessor[1] {
			attribute :>> memorySize = 524288;
			attribute :>> processingPower = 1000.0;
		}
		
		part powerMgmt : PowerManagement[1] {
			attribute :>> efficiency = 0.85;
		}
		
		part commInterface : CommunicationInterface[1] {
			attribute :>> protocol = "SPI";
			attribute :>> baudRate = 10000000.0;
			attribute :>> bufferSize = 2048;
		}
		
		connection analogToDigital
			connect analogFrontEnd.digitalOutput to dsp.dataInput;
		
		connection dspToSensor
			connect dsp.dataOutput to sensor.signalInput;
		
		connection sensorToComm
			connect sensor.dataOutput to commInterface.dataPort;
		
		connection powerDistribution
			connect powerMgmt.powerOutput to sensor;
		
		connection powerToAnalog
			connect powerMgmt.powerOutput to analogFrontEnd;
		
		connection powerToDSP
			connect powerMgmt.powerOutput to dsp;
	}
	
	requirement def FrequencyAccuracyRequirement {
		doc /* The sensing unit shall measure frequency with high accuracy over the specified range. */
		
		subject unit : SensingUnit;
	}
	
	requirement def MeasurementRangeRequirement {
		doc /* The sensing unit shall measure frequencies from 10 Hz to 10 kHz with full accuracy. */
		
		subject unit : SensingUnit;
	}
	
	requirement def SamplingRateRequirement {
		doc /* The sensing unit shall sample at a rate sufficient for accurate FFT analysis. */
		
		subject unit : SensingUnit;
	}
	
	requirement def PowerConsumptionRequirement {
		doc /* The sensing unit shall consume no more than 10 watts during continuous operation. */
		
		subject unit : SensingUnit;
	}
	
	requirement def TemperatureRangeRequirement {
		doc /* The sensing unit shall operate reliably in temperatures from -20°C to +70°C. */
		
		subject unit : SensingUnit;
	}
	
	part sensingUnitInstance : SensingUnit {
		attribute :>> unitId = "SU-FD-2024-100";
		attribute :>> calibrationDate = "2024-01-15";
	}
	
	requirement frequencyAccuracy : FrequencyAccuracyRequirement {
		subject testUnit :>> unit = sensingUnitInstance;
	}
	
	requirement measurementRange : MeasurementRangeRequirement {
		subject testUnit :>> unit = sensingUnitInstance;
	}
	
	requirement samplingRate : SamplingRateRequirement {
		subject testUnit :>> unit = sensingUnitInstance;
	}
	
	requirement powerConsumption : PowerConsumptionRequirement {
		subject testUnit :>> unit = sensingUnitInstance;
	}
	
	requirement temperatureRange : TemperatureRangeRequirement {
		subject testUnit :>> unit = sensingUnitInstance;
	}
}
