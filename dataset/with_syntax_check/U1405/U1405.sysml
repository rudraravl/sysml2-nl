package 'Electronics System Model' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def SignalQuality;
	attribute def OperatingMode;
	attribute def SampleComplete;
	attribute def ComputationComplete;
	attribute def TransmissionComplete;
	attribute def PowerOnComplete;
	attribute def SignalReceived;
	attribute def IdleTimeout;
	attribute def PowerOff;
	
	item def AnalogSignal {
		attribute voltage : ISQ::ElectricPotentialValue;
		attribute current : ISQ::ElectricCurrentValue;
		attribute frequency : ISQ::FrequencyValue;
		attribute amplitude : ISQ::ElectricPotentialValue;
	}
	
	item def DigitalSignal {
		attribute bitstream : Integer[*];
		attribute clockRate : ISQ::FrequencyValue;
		attribute logicLevel : ISQ::ElectricPotentialValue;
	}
	
	port def PowerInputPort {
		in attribute voltage : ISQ::ElectricPotentialValue;
		in attribute current : ISQ::ElectricCurrentValue;
	}
	
	port def AnalogInputPort {
		in item signal : AnalogSignal;
	}
	
	port def AnalogOutputPort {
		out item signal : AnalogSignal;
	}
	
	port def DigitalDataPort {
		in item inputData : DigitalSignal;
		out item outputData : DigitalSignal;
	}
	
	part def PowerRegulator {
		port powerIn : PowerInputPort;
		port powerOut : PowerInputPort;
		
		attribute inputVoltageRange : ISQ::ElectricPotentialValue[2];
		attribute outputVoltage : ISQ::ElectricPotentialValue;
		attribute maxCurrent : ISQ::ElectricCurrentValue;
		attribute efficiency : Real;
		
		action regulateVoltage {
			in inputV : ISQ::ElectricPotentialValue;
			in loadI : ISQ::ElectricCurrentValue;
			out regulatedV : ISQ::ElectricPotentialValue;
		}
	}
	
	part def Amplifier {
		port analogIn : AnalogInputPort;
		port analogOut : AnalogOutputPort;
		port power : PowerInputPort;
		
		attribute gain : Real;
		attribute bandwidth : ISQ::FrequencyValue;
		attribute inputImpedance : Real;
		attribute outputImpedance : Real;
		
		action amplifySignal {
			in inputSignal : AnalogSignal;
			out amplifiedSignal : AnalogSignal;
		}
	}
	
	part def Filter {
		port signalIn : AnalogInputPort;
		port signalOut : AnalogOutputPort;
		port power : PowerInputPort;
		
		attribute cutoffFrequency : ISQ::FrequencyValue;
		attribute filterOrder : Integer;
		attribute attenuation : Real;
		
		action filterSignal {
			in rawSignal : AnalogSignal;
			out filteredSignal : AnalogSignal;
		}
	}
	
	part def ADC {
		port analogIn : AnalogInputPort;
		port digitalOut : DigitalDataPort;
		port power : PowerInputPort;
		
		attribute resolution : Integer;
		attribute samplingRate : ISQ::FrequencyValue;
		attribute referenceVoltage : ISQ::ElectricPotentialValue;
		attribute conversionTime : ISQ::DurationValue;
		
		action convertToDigital {
			in analogInput : AnalogSignal;
			out digitalOutput : DigitalSignal;
		}
	}
	
	state def ControlStateMachine {
		entry; then initialization;
		
		state initialization;
		transition initialization_to_standby
			first initialization
			accept PowerOnComplete
			then standby;
		
		state standby;
		transition standby_to_active
			first standby
			accept SignalReceived
			then active;
		
		state active {
			state sampling;
			state computing;
			state transmitting;
			
			transition sampling_to_computing
				first sampling
				accept SampleComplete
				then computing;
			
			transition computing_to_transmitting
				first computing
				accept ComputationComplete
				then transmitting;
			
			transition transmitting_to_sampling
				first transmitting
				accept TransmissionComplete
				then sampling;
		}
		
		transition active_to_standby
			first active
			accept IdleTimeout
			then standby;
		
		transition standby_to_shutdown
			first standby
			accept PowerOff
			then shutdown;
		
		state shutdown;
		then done;
	}
	
	part def Microcontroller {
		port dataIn : DigitalDataPort;
		port dataOut : DigitalDataPort;
		port power : PowerInputPort;
		
		attribute clockFrequency : ISQ::FrequencyValue;
		attribute flashMemory : Real;
		attribute ramSize : Real;
		attribute processingPower : Real;
		
		action processData {
			in inputData : DigitalSignal;
			out processedData : DigitalSignal;
		}
	}
	
	part def DAC {
		port digitalIn : DigitalDataPort;
		port analogOut : AnalogOutputPort;
		port power : PowerInputPort;
		
		attribute resolution : Integer;
		attribute updateRate : ISQ::FrequencyValue;
		attribute settlingTime : ISQ::DurationValue;
		
		action convertToAnalog {
			in digitalInput : DigitalSignal;
			out analogOutput : AnalogSignal;
		}
	}
	
	part def OutputBuffer {
		port signalIn : AnalogInputPort;
		port signalOut : AnalogOutputPort;
		port power : PowerInputPort;
		
		attribute driveCapability : ISQ::ElectricCurrentValue;
		attribute outputRange : ISQ::ElectricPotentialValue[2];
		
		action bufferSignal {
			in inputSignal : AnalogSignal;
			out bufferedSignal : AnalogSignal;
		}
	}
	
	action def AcquireAndCondition {
		in externalSignal : AnalogSignal;
		out conditionedSignal : AnalogSignal;
	}
	
	action def Digitize {
		in analogSignal : AnalogSignal;
		out digitalData : DigitalSignal;
	}
	
	action def ComputeAndProcess {
		in rawData : DigitalSignal;
		out processedData : DigitalSignal;
	}
	
	action def ReconstructAndOutput {
		in digitalData : DigitalSignal;
		out outputSignal : AnalogSignal;
	}
	
	action def SignalProcessingCycle {
		in inputSignal : AnalogSignal;
		out outputSignal : AnalogSignal;
		
		first start;
		then action acquire : AcquireAndCondition {
			in externalSignal = inputSignal;
			out conditionedSignal;
		}
		then action digitize : Digitize {
			in analogSignal = acquire.conditionedSignal;
			out digitalData;
		}
		then action compute : ComputeAndProcess {
			in rawData = digitize.digitalData;
			out processedData;
		}
		then action reconstruct : ReconstructAndOutput {
			in digitalData = compute.processedData;
			out outputSignal;
		}
		then done;
	}
	
	part def ElectronicsSystem {
		doc /*
		 * An electronics system that acquires analog signals from sensors,
		 * conditions and amplifies them, converts to digital form for processing,
		 * performs computational analysis and filtering, then reconstructs
		 * analog output signals for actuators or display. The system operates
		 * in a continuous cycle, monitoring environmental inputs and generating
		 * appropriate control or measurement outputs based on embedded algorithms.
		 */
		
		port mainPowerIn : PowerInputPort;
		port sensorInput : AnalogInputPort;
		port actuatorOutput : AnalogOutputPort;
		
		part regulator : PowerRegulator {
			attribute :>> inputVoltageRange = (9.0[V], 15.0[V]);
			attribute :>> outputVoltage = 5.0[V];
			attribute :>> maxCurrent = 2.0[A];
			attribute :>> efficiency = 0.88;
		}
		
		part inputAmplifier : Amplifier {
			attribute :>> gain = 20.0;
			attribute :>> bandwidth = 100.0[kHz];
			attribute :>> inputImpedance = 1.0e6;
			attribute :>> outputImpedance = 50.0;
			perform processingCycle.acquire;
		}
		
		part antiAliasFilter : Filter {
			attribute :>> cutoffFrequency = 50.0[kHz];
			attribute :>> filterOrder = 4;
			attribute :>> attenuation = 40.0;
		}
		
		part analogToDigital : ADC {
			attribute :>> resolution = 16;
			attribute :>> samplingRate = 200.0[kHz];
			attribute :>> referenceVoltage = 5.0[V];
			attribute :>> conversionTime = 5.0[us];
			perform processingCycle.digitize;
		}
		
		part controller : Microcontroller {
			attribute :>> clockFrequency = 120.0[MHz];
			attribute :>> flashMemory = 512.0;
			attribute :>> ramSize = 128.0;
			attribute :>> processingPower = 150.0;
			perform processingCycle.compute;
		}
		
		part digitalToAnalog : DAC {
			attribute :>> resolution = 12;
			attribute :>> updateRate = 100.0[kHz];
			attribute :>> settlingTime = 10.0[us];
			perform processingCycle.reconstruct;
		}
		
		part outputBuffer : OutputBuffer {
			attribute :>> driveCapability = 0.5[A];
			attribute :>> outputRange = (0.0[V], 10.0[V]);
		}
		
		perform action processingCycle[*] ordered references SignalProcessingCycle;
		
		connection regulator.powerIn to mainPowerIn;
		connection regulator.powerOut to inputAmplifier.power;
		connection regulator.powerOut to antiAliasFilter.power;
		connection regulator.powerOut to analogToDigital.power;
		connection regulator.powerOut to controller.power;
		connection regulator.powerOut to digitalToAnalog.power;
		connection regulator.powerOut to outputBuffer.power;
		
		connection sensorInput to inputAmplifier.analogIn;
		connection inputAmplifier.analogOut to antiAliasFilter.signalIn;
		connection antiAliasFilter.signalOut to analogToDigital.analogIn;
		connection analogToDigital.digitalOut to controller.dataIn;
		connection controller.dataOut to digitalToAnalog.digitalIn;
		connection digitalToAnalog.analogOut to outputBuffer.signalIn;
		connection outputBuffer.signalOut to actuatorOutput;
		
		exhibit state controlBehavior : ControlStateMachine;
	}
	
	part electronicsSystem : ElectronicsSystem {
		attribute :>> mainPowerIn.voltage = 12.0[V];
		attribute :>> mainPowerIn.current = 1.5[A];
	}
	
	requirement def FunctionalRequirement {
		doc /* The electronics system shall acquire, process, and output signals continuously. */
		subject system : ElectronicsSystem;
	}
	
	requirement def PowerRequirement {
		doc /* The system shall operate from a 9-15V DC input with maximum current draw of 2A. */
		subject system : ElectronicsSystem;
		require constraint {
			system.regulator.inputVoltageRange#(1) >= 9.0[V] and
			system.regulator.inputVoltageRange#(2) <= 15.0[V] and
			system.regulator.maxCurrent <= 2.0[A]
		}
	}
	
	requirement def SignalFidelityRequirement {
		doc /* The system shall maintain signal integrity with minimum 14-bit effective resolution. */
		subject system : ElectronicsSystem;
		require constraint {
			system.analogToDigital.resolution >= 14
		}
	}
	
	requirement def ProcessingSpeedRequirement {
		doc /* The system shall process signals with maximum latency of 50 microseconds. */
		subject system : ElectronicsSystem;
		attribute maxLatency : ISQ::DurationValue = 50.0[us];
	}
	
	requirement systemRequirements {
		doc /* Top-level requirements for the electronics signal processing system. */
		
		require functional : FunctionalRequirement;
		require power : PowerRequirement;
		require fidelity : SignalFidelityRequirement;
		require speed : ProcessingSpeedRequirement;
		
		satisfy by electronicsSystem;
	}
}
