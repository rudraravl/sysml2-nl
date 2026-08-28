package UltrasonicProximitySensor {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	item def TriggerCommand;
	item def PulseCommand;
	item def Pulse {
		attribute frequency : ISQ::FrequencyValue = 40 [SI::kHz];
	}
	item def EchoSignal {
		attribute timeOfFlight : ISQ::DurationValue;
	}
	item def Measurement {
		attribute distance : ISQ::LengthValue;
		attribute confidence : ScalarValues::Real;
	}
	item def PowerReady;

	port def TriggerPort {
		in cmd : TriggerCommand;
	}
	port def DataOutPort {
		out data : Measurement;
	}
	port def DataInPort {
		in data : Measurement;
	}
	port def TransducerCtrlPort {
		out cmd : PulseCommand;
	}
	port def TransducerCtrlInPort {
		in cmd : PulseCommand;
	}
	port def TransducerWavePort {
		out pulse : Pulse;
		in echo : EchoSignal;
	}
	port def EchoOutPort {
		out echo : EchoSignal;
	}
	port def EchoInPort {
		in echo : EchoSignal;
	}
	port def PowerOutPort {
		out voltage : ScalarValues::Real;
	}
	port def PowerInPort {
		in voltage : ScalarValues::Real;
	}

	part def PowerSupply {
		port powerOut : PowerOutPort;
		attribute supplyVoltage : ScalarValues::Real := 5.0 [SI::V];
		
		state PowerStates {
			entry; then on;
			state on {
				do send new PowerReady() via powerOut;
			}
		}
	}

	part def UltrasonicTransducer {
		port powerIn : PowerInPort;
		port ctrlIn : TransducerCtrlInPort;
		port wavePort : TransducerWavePort;
		port echoOut : EchoOutPort;

		state TransducerStates {
			entry; then idle;
			state idle;
			transition onPulseCmd
				first idle
				accept cmd : PulseCommand via ctrlIn
				do send new Pulse() via wavePort
				then listening;
			state listening;
			transition echoReceived
				first listening
				accept echo : EchoSignal via wavePort
				do send echo via echoOut
				then idle;
			transition timeout
				first listening
				accept after 50 [SI::ms]
				then idle;
		}
	}

	part def SignalProcessor {
		port powerIn : PowerInPort;
		port echoIn : EchoInPort;
		port dataOut : DataOutPort;

		attribute speedOfSound : ISQ::SpeedValue = 343.0 [SI::m/s];

		action calcDistance {
			in echo : EchoSignal;
			attribute dist : ISQ::LengthValue;
			attribute conf : ScalarValues::Real;
			assign dist := (echo.timeOfFlight * speedOfSound) / 2.0;
			assign conf := 0.95;
			do send new Measurement(dist, conf) via dataOut;
		}

		state ProcessorStates {
			entry; then ready;
			state ready;
			transition processEchoT
				first ready
				accept echo : EchoSignal via echoIn
				do action calcDistance(echo)
				then ready;
		}
	}

	part def ControlUnit {
		port powerIn : PowerInPort;
		port cmdIn : TriggerPort;
		port transducerCtrl : TransducerCtrlPort;
		port echoIn : EchoInPort;
		port processorEchoOut : EchoOutPort;
		port processorDataIn : DataInPort;
		port dataOut : DataOutPort;

		state ControlStates {
			entry; then idle;
			state idle;
			transition onTrigger
				first idle
				accept trigger : TriggerCommand via cmdIn
				do send new PulseCommand() via transducerCtrl
				then measuring;
			state measuring;
			transition measureDone
				first measuring
				accept after 2 [SI::ms]
				then listening;
			state listening;
			transition echoDetected
				first listening
				accept echo : EchoSignal via echoIn
				do send echo via processorEchoOut
				then processing;
			transition listenTimeout
				first listening
				accept after 30 [SI::ms]
				then idle;
			state processing;
			transition dataReady
				first processing
				accept measurement : Measurement via processorDataIn
				do send measurement via dataOut
				then idle;
		}
	}

	part def ProximitySensingUnit {
		port cmdIn : TriggerPort;
		port dataOut : DataOutPort;

		part powerSupply : PowerSupply;
		part transducer : UltrasonicTransducer;
		part signalProcessor : SignalProcessor;
		part controlUnit : ControlUnit;

		connect powerSupply.powerOut to transducer.powerIn;
		connect powerSupply.powerOut to signalProcessor.powerIn;
		connect powerSupply.powerOut to controlUnit.powerIn;

		connect cmdIn to controlUnit.cmdIn;
		connect controlUnit.dataOut to dataOut;

		connect controlUnit.transducerCtrl to transducer.ctrlIn;
		connect transducer.echoOut to controlUnit.echoIn;
		connect controlUnit.processorEchoOut to signalProcessor.echoIn;
		connect signalProcessor.dataOut to controlUnit.processorDataIn;
	}

	requirement def CycleTimeRequirement {
		doc /* The complete measurement cycle, from receiving a trigger command to sending the final measurement or timing out, shall complete within 100 milliseconds. */
		attribute maxCycleTime : ISQ::DurationValue = 100 [SI::ms];
	}
	
	requirement def OperatingFrequencyRequirement {
		doc /* The ultrasonic transducer shall transmit and receive ultrasonic pulses at a frequency of 40 kHz. */
		attribute targetFrequency : ISQ::FrequencyValue = 40 [SI::kHz];
	}
	
	requirement def PowerSupplyRequirement {
		doc /* The internal power supply shall provide the correct voltage to the transducer, processor, and control unit. */
		attribute requiredVoltage : ScalarValues::Real = 5.0 [SI::V];
	}
}
