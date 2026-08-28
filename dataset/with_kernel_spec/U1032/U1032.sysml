package DSLSystemModel {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import MeasurementReferences::*;

	item def DataPacket;
	item def AnalogSignal;
	item def SyncComplete;
	item def SignalLost;

	port def DataPort {
		out item dataOut : DataPacket;
		in item dataIn : DataPacket;
	}

	port def LinePort {
		out item signalOut : AnalogSignal;
		in item signalIn : AnalogSignal;
	}

	port def BackbonePort {
		out item backboneOut : DataPacket;
		in item backboneIn : DataPacket;
	}

	attribute def LineQuality {
		attribute length : LengthValue;
		attribute attenuation : Real;
		attribute signalToNoiseRatio : Real;
	}

	action def SelfTest;
	action def NegotiateSpeed {
		in lineSNR : Real;
		out downstreamRate : Real;
		out upstreamRate : Real;
	}
	action def TransmitData {
		in downstream : DataPacket;
		out upstream : DataPacket;
	}

	part def Modulator {
		in item digitalIn : DataPacket;
		out item analogOut : AnalogSignal;
	}

	part def Demodulator {
		in item analogIn : AnalogSignal;
		out item digitalOut : DataPacket;
	}

	part def ErrorCorrector {
		in item rawIn : DataPacket;
		out item correctedOut : DataPacket;
		attribute bitErrorRate : Real;
	}

	part def DSLModem {
		port customerPort : DataPort;
		port linePort : LinePort;
		attribute downstreamRate : Real;
		attribute upstreamRate : Real;
		attribute lineQuality : LineQuality;
		part modulator : Modulator;
		part demodulator : Demodulator;
		part errorCorrector : ErrorCorrector;
		connect customerPort.dataIn to modulator.digitalIn;
		connect modulator.analogOut to linePort.signalOut;
		connect linePort.signalIn to demodulator.analogIn;
		connect demodulator.digitalOut to errorCorrector.rawIn;
		connect errorCorrector.correctedOut to customerPort.dataOut;
		action selfTest : SelfTest;
		action negotiateSpeed : NegotiateSpeed;
		action transmitData : TransmitData;
		state ModemOperation {
			entry; then initialization;
			state initialization {
				do selfTest;
			}
			accept after 5 [SI::s]
				then training;
			state training {
				do negotiateSpeed;
			}
			accept SyncComplete
				then showtime;
			state showtime {
				do transmitData;
			}
			accept SignalLost
				then training;
		}
	}

	part def TwistedPairCable {
		port customerEnd : ~LinePort;
		port centralOfficeEnd : LinePort;
		attribute length : LengthValue;
		attribute attenuation : Real;
		attribute wireGauge : Real;
		connect customerEnd.signalOut to centralOfficeEnd.signalOut;
		connect centralOfficeEnd.signalIn to customerEnd.signalIn;
	}

	part def LineCard {
		port subscriberPort : ~LinePort;
		port backplanePort : DataPort;
		attribute subscriberId : String;
		connect subscriberPort.signalOut to backplanePort.dataOut;
		connect backplanePort.dataIn to subscriberPort.signalIn;
	}

	part def Multiplexer {
		port inPort : DataPort[1..*];
		port outPort : BackbonePort;
		connect inPort.dataIn to outPort.backboneOut;
		connect outPort.backboneIn to inPort.dataOut;
	}

	part def DSLAM {
		port backbonePort : BackbonePort;
		port subscriberPorts : LinePort[1..*];
		part lineCards : LineCard[1..*];
		part muxDemux : Multiplexer;
		connect subscriberPorts.signalIn to lineCards.subscriberPort.signalIn;
		connect lineCards.backplanePort.dataOut to muxDemux.inPort.dataIn;
		connect muxDemux.outPort.backboneOut to backbonePort.backboneOut;
		connect backbonePort.backboneIn to muxDemux.outPort.backboneIn;
		connect muxDemux.inPort.dataOut to lineCards.backplanePort.dataIn;
		connect lineCards.subscriberPort.signalOut to subscriberPorts.signalOut;
	}

	part def NetworkBackbone {
		port ispPort : ~BackbonePort;
		attribute capacity : Real;
	}

	package DSLRequirements {
		requirement def PerformanceRequirement {
			attribute actualDownstreamRate : Real;
			attribute requiredDownstreamRate : Real;
			attribute actualUpstreamRate : Real;
			attribute requiredUpstreamRate : Real;
			attribute actualDistance : LengthValue;
			attribute maxDistance : LengthValue;
			attribute actualBitErrorRate : Real;
			attribute maxBitErrorRate : Real;
			attribute actualAvailability : Real;
			attribute minAvailability : Real;
			attribute actualReconnectTime : TimeValue;
			attribute maxReconnectTime : TimeValue;
			require constraint { actualDownstreamRate >= requiredDownstreamRate }
			require constraint { actualUpstreamRate >= requiredUpstreamRate }
			require constraint { actualDistance <= maxDistance }
			require constraint { actualBitErrorRate <= maxBitErrorRate }
			require constraint { actualAvailability >= minAvailability }
			require constraint { actualReconnectTime <= maxReconnectTime }
		}
		requirement dslPerformanceRequirement : PerformanceRequirement {
			:>> requiredDownstreamRate = 25.0;
			:>> requiredUpstreamRate = 5.0;
			:>> maxDistance = 5.0 [km];
			:>> maxBitErrorRate = 1.0e-7;
			:>> minAvailability = 0.999;
			:>> maxReconnectTime = 30 [s];
		}
	}

	package DSLSystem {
		private import DSLRequirements::*;
		part dslModem : DSLModem {
			:>> downstreamRate = 25.0;
			:>> upstreamRate = 5.0;
		}
		part twistedPair : TwistedPairCable {
			:>> length = 3.5 [km];
			:>> attenuation = 35.0;
		}
		part dslam : DSLAM;
		part backbone : NetworkBackbone {
			:>> capacity = 10000.0;
		}
		flow of analogSignal : AnalogSignal
			from dslModem.linePort.signalOut to twistedPair.customerEnd.signalOut;
		flow of analogSignal : AnalogSignal
			from twistedPair.customerEnd.signalIn to dslModem.linePort.signalIn;
		flow of analogSignal : AnalogSignal
			from twistedPair.centralOfficeEnd.signalOut to dslam.subscriberPorts.signalIn;
		flow of analogSignal : AnalogSignal
			from dslam.subscriberPorts.signalOut to twistedPair.centralOfficeEnd.signalIn;
		flow of dataPacket : DataPacket
			from dslam.backbonePort.backboneOut to backbone.ispPort.backboneOut;
		flow of dataPacket : DataPacket
			from backbone.ispPort.backboneIn to dslam.backbonePort.backboneIn;
		requirement systemPerformance : PerformanceRequirement {
			:>> requiredDownstreamRate = 25.0;
			:>> requiredUpstreamRate = 5.0;
			:>> maxDistance = 5.0 [km];
			:>> maxBitErrorRate = 1.0e-7;
			:>> minAvailability = 0.999;
			:>> maxReconnectTime = 30 [s];
			:>> actualDownstreamRate = dslModem.downstreamRate;
			:>> actualUpstreamRate = dslModem.upstreamRate;
			:>> actualDistance = twistedPair.length;
			:>> actualBitErrorRate = dslModem.errorCorrector.bitErrorRate;
			:>> actualAvailability = 0.9995;
			:>> actualReconnectTime = 20 [s];
		}
	}
}
