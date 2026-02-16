package DigitalSubscriberLineSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def DataRate :> ISQ::PowerValue {
		doc /* Rate of data transmission measured in bits per second */
	}
	
	attribute def SignalToNoiseRatio :> Real {
		doc /* Ratio of signal power to noise power in decibels */
	}
	
	attribute def LineAttenuation :> Real {
		doc /* Signal loss over transmission line in decibels */
	}
	
	attribute def FrequencyBand :> ISQ::PowerValue {
		doc /* Frequency range used for signal transmission */
	}
	
	item def DigitalData {
		attribute dataRate : DataRate;
		attribute payload : String;
	}
	
	item def AnalogSignal {
		attribute frequency : FrequencyBand;
		attribute amplitude : Real;
		attribute snr : SignalToNoiseRatio;
	}
	
	item def PowerOnSignal;
	item def InitCompleteSignal;
	item def TrainingCompleteSignal;
	item def PowerOffSignal;
	
	port def SubscriberLinePort {
		attribute lineQuality : SignalToNoiseRatio;
		out item digitalOut : DigitalData;
		in item digitalIn : DigitalData;
		out item analogOut : AnalogSignal;
		in item analogIn : AnalogSignal;
	}
	
	port def CentralOfficePort {
		attribute lineQuality : SignalToNoiseRatio;
		in item digitalIn : DigitalData;
		out item digitalOut : DigitalData;
		in item analogIn : AnalogSignal;
		out item analogOut : AnalogSignal;
	}
	
	port def NetworkPort {
		in item dataIn : DigitalData;
		out item dataOut : DigitalData;
	}
	
	part def DSLModem {
		doc /* Customer premises equipment that modulates and demodulates signals */
		
		port subscriberSide : SubscriberLinePort;
		port customerSide : NetworkPort;
		
		attribute maxDownstreamRate : DataRate;
		attribute maxUpstreamRate : DataRate;
		attribute currentSNR : SignalToNoiseRatio;
		
		part modulator {
			doc /* Converts digital data to analog signal */
			in digitalInput : DigitalData;
			out analogOutput : AnalogSignal;
		}
		
		part demodulator {
			doc /* Converts analog signal to digital data */
			in analogInput : AnalogSignal;
			out digitalOutput : DigitalData;
		}
		
		part errorCorrection {
			doc /* Forward error correction for data integrity */
		}
		
		exhibit state modemStateMachine {
			entry; then powerOff;
			
			state powerOff;
			transition powerOff_to_initialization
				first powerOff
				accept PowerOnSignal
				then initialization;
			
			state initialization {
				doc /* Modem startup and self-test */
			}
			transition initialization_to_training
				first initialization
				accept InitCompleteSignal
				then training;
			
			state training {
				doc /* Line training and parameter negotiation */
			}
			transition training_to_showtime
				first training
				accept TrainingCompleteSignal
				then showtime;
			
			state showtime {
				doc /* Normal data transmission mode */
			}
			transition showtime_to_powerOff
				first showtime
				accept PowerOffSignal
				then powerOff;
		}
	}
	
	part def DSLAM {
		doc /* Digital Subscriber Line Access Multiplexer at central office */
		
		port coSide : CentralOfficePort;
		port backboneSide : NetworkPort;
		
		attribute aggregatedCapacity : DataRate;
		attribute numberOfLines : Integer;
		
		part multiplexer {
			doc /* Combines multiple DSL connections */
		}
		
		part demultiplexer {
			doc /* Separates individual DSL connections */
		}
		
		part lineCard[*] {
			doc /* Individual line interface cards */
		}
	}
	
	part def TwistedPairCable {
		doc /* Copper telephone line used for DSL transmission */
		
		attribute length : ISQ::LengthValue;
		attribute attenuation : LineAttenuation;
		attribute gauge : Real;
		
		port subscriberEnd : SubscriberLinePort;
		port centralOfficeEnd : CentralOfficePort;
	}
	
	part def NetworkBackbone {
		doc /* High-speed network infrastructure connecting to Internet */
		
		port edgePort : NetworkPort;
		attribute backboneCapacity : DataRate;
	}
	
	action def EstablishConnection {
		in subscriberModem : DSLModem;
		in centralOfficeEquipment : DSLAM;
		in transmissionLine : TwistedPairCable;
		out connectionEstablished : Boolean;
		
		first start;
		then action initiateHandshake {
			doc /* Begin DSL handshake protocol */
		}
		then action trainLine {
			doc /* Perform line training and parameter negotiation */
			in lineLength : ISQ::LengthValue;
			in lineNoise : SignalToNoiseRatio;
			out optimalRate : DataRate;
		}
		then action synchronize {
			doc /* Achieve frame and symbol synchronization */
		}
		then decide;
			if synchronizationSuccessful then establishDataPath;
			if synchronizationFailed then retryConnection;
		
		action establishDataPath {
			doc /* Set up bidirectional data transmission */
		}
		then done;
		
		action retryConnection {
			doc /* Attempt connection again after failure */
		}
		then trainLine;
	}
	
	action def TransmitData {
		in inputData : DigitalData;
		in lineParameters : SignalToNoiseRatio;
		out transmittedData : DigitalData;
		
		first start;
		then action encodeData {
			in rawData : DigitalData;
			out encodedData : DigitalData;
			doc /* Apply error correction coding */
		}
		then action modulateSignal {
			in encodedData : DigitalData;
			out modulatedSignal : AnalogSignal;
			doc /* Convert digital data to analog signal using DMT */
		}
		then action transmitOnLine {
			in signal : AnalogSignal;
			doc /* Send modulated signal over twisted pair */
		}
		then action receiveSignal {
			out receivedSignal : AnalogSignal;
			doc /* Receive attenuated signal at far end */
		}
		then action demodulateSignal {
			in receivedSignal : AnalogSignal;
			out demodulatedData : DigitalData;
			doc /* Convert analog signal back to digital data */
		}
		then action decodeData {
			in demodulatedData : DigitalData;
			out finalData : DigitalData;
			doc /* Apply error correction and recover original data */
		}
		then done;
	}
	
	requirement def DSLPerformanceRequirement {
		doc /* Requirements for DSL system performance */
		
		require constraint downstreamRateRequirement {
			doc /* Minimum downstream data rate shall be 1 Mbps */
		}
		
		require constraint upstreamRateRequirement {
			doc /* Minimum upstream data rate shall be 256 kbps */
		}
		
		require constraint maximumRangeRequirement {
			doc /* System shall operate over twisted pair up to 5.5 km */
		}
		
		require constraint bitErrorRateRequirement {
			doc /* Bit error rate shall be less than 1e-7 */
		}
	}
	
	requirement def DSLReliabilityRequirement {
		doc /* Requirements for DSL system reliability */
		
		require constraint availabilityRequirement {
			doc /* System availability shall exceed 99.9 percent */
		}
		
		require constraint reconnectionTimeRequirement {
			doc /* Automatic reconnection shall occur within 30 seconds */
		}
	}
	
	part def DSLSystem {
		doc /* Primary function: Enable bidirectional high-speed digital data transmission over existing copper telephone lines by modulating data onto frequency bands above voice frequencies */
	}
	
	requirement <'DSL-SYS-001'> dslSystemRequirements {
		doc /* Top-level requirements for DSL system */
		
		subject dslSystem : DSLSystem;
		
		require dslPerformance : DSLPerformanceRequirement;
		require dslReliability : DSLReliabilityRequirement;
	}
	
	action transmitData : TransmitData {
		doc /* Core action representing the primary function of transmitting data over DSL */
	}
	
	part dslSystem : DSLSystem {
		doc /* Complete Digital Subscriber Line system providing high-speed data transmission over existing telephone infrastructure */
		
		perform action provideHighSpeedInternet[*] ordered references transmitData;
		
		part customerModem : DSLModem {
			perform provideHighSpeedInternet.encodeData;
			perform provideHighSpeedInternet.modulateSignal;
			perform provideHighSpeedInternet.demodulateSignal;
			perform provideHighSpeedInternet.decodeData;
		}
		
		part localLoop : TwistedPairCable {
			perform provideHighSpeedInternet.transmitOnLine;
			perform provideHighSpeedInternet.receiveSignal;
		}
		
		part centralOffice : DSLAM {
			perform provideHighSpeedInternet.receiveSignal;
			perform provideHighSpeedInternet.transmitOnLine;
		}
		
		part backbone : NetworkBackbone;
		
		connection subscriberConnection connect 
			customerModem.subscriberSide to localLoop.subscriberEnd;
			
		connection centralOfficeConnection connect 
			localLoop.centralOfficeEnd to centralOffice.coSide;
			
		connection backboneConnection connect
			centralOffice.backboneSide to backbone.edgePort;
		
		satisfy dslSystemRequirements;
	}
}
