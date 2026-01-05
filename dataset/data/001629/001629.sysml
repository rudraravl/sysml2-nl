package WirelessCommunicationSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def PowerLevel :> ISQ::PowerValue;
	attribute def Frequency :> ISQ::FrequencyValue;
	attribute def DataRate :> Real;
	attribute def SignalStrength :> Real;
	
	item def DataFrame {
		attribute payload : String;
		attribute size : Real;
		attribute timestamp : ISQ::TimeValue;
		attribute sourceAddress : String;
		attribute destinationAddress : String;
	}
	
	attribute def ConnectionRequest;
	attribute def ConnectionAcknowledge;
	attribute def DisconnectRequest;
	attribute def DataTransmit;
	attribute def DataReceive;
	
	port def WirelessPort {
		out txSignal : SignalStrength;
		in rxSignal : SignalStrength;
		out txData : DataFrame;
		in rxData : DataFrame;
	}
	
	port def NetworkPort {
		in dataIn : DataFrame;
		out dataOut : DataFrame;
	}
	
	part def Antenna {
		port rfPort : WirelessPort;
		attribute gain : Real;
		attribute efficiency : Real;
		attribute operatingFrequency : Frequency;
	}
	
	part def RadioTransceiver {
		port antennaPort : WirelessPort;
		port baseband : NetworkPort;
		attribute transmitPower : PowerLevel;
		attribute receiveSensitivity : SignalStrength;
		attribute carrierFrequency : Frequency;
		attribute bandwidth : Frequency;
	}
	
	part def SignalProcessor {
		port inputPort : NetworkPort;
		port outputPort : NetworkPort;
		attribute modulationType : String;
		attribute codingScheme : String;
		attribute processingDelay : ISQ::TimeValue;
	}
	
	part def MediaAccessControl {
		port upperLayer : NetworkPort;
		port lowerLayer : NetworkPort;
		attribute maxRetransmissions : Integer;
		attribute backoffInterval : ISQ::TimeValue;
		attribute channelAccessMethod : String;
	}
	
	part def BaseStation {
		port wirelessInterface : WirelessPort;
		port backhaul : NetworkPort;
		attribute coverageRadius : ISQ::LengthValue;
		attribute maxConnectedDevices : Integer;
		attribute operatingBand : Frequency;
		
		part antenna : Antenna {
			port rfPort redefines wirelessInterface;
			attribute gain = 8.0;
			attribute efficiency = 0.9;
		}
		
		part transceiver : RadioTransceiver {
			attribute transmitPower : PowerLevel;
			attribute carrierFrequency = operatingBand;
		}
		
		part processor : SignalProcessor {
			attribute modulationType = "OFDM";
			attribute codingScheme = "LDPC";
		}
		
		part mac : MediaAccessControl {
			attribute maxRetransmissions = 5;
			attribute channelAccessMethod = "CSMA/CA";
		}
		
		connect antenna.rfPort to transceiver.antennaPort;
		connect transceiver.baseband to processor.inputPort;
		connect processor.outputPort to mac.lowerLayer;
		connect mac.upperLayer to backhaul;
		
		exhibit state operationalState {
			entry; then idle;
			
			state idle;
			state active;
			state transmitting;
			state receiving;
			state error;
			
			transition idleToActive
				first idle
				accept connectionReq : ConnectionRequest
				then active;
			
			transition activeToTransmit
				first active
				accept txCmd : DataTransmit
				then transmitting;
			
			transition transmitToActive
				first transmitting
				then active;
			
			transition activeToReceive
				first active
				accept rxCmd : DataReceive
				then receiving;
			
			transition receiveToActive
				first receiving
				then active;
			
			transition activeToIdle
				first active
				accept disconnectReq : DisconnectRequest
				then idle;
			
			transition toError
				first active
				then error;
			
			transition errorToIdle
				first error
				then idle;
		}
	}
	
	part def WirelessDevice {
		port wirelessInterface : WirelessPort;
		port applicationInterface : NetworkPort;
		attribute deviceId : String;
		attribute batteryLevel : PowerLevel;
		
		part antenna : Antenna {
			port rfPort redefines wirelessInterface;
			attribute gain = 2.0;
			attribute efficiency = 0.75;
		}
		
		part transceiver : RadioTransceiver;
		part processor : SignalProcessor;
		part mac : MediaAccessControl;
		
		connect antenna.rfPort to transceiver.antennaPort;
		connect transceiver.baseband to processor.inputPort;
		connect processor.outputPort to mac.lowerLayer;
		connect mac.upperLayer to applicationInterface;
	}
	
	action def EstablishConnection {
		in request : ConnectionRequest;
		in frequency : Frequency;
		out acknowledged : Boolean;
		out sessionId : String;
	}
	
	action def ModulateSignal {
		in dataFrame : DataFrame;
		in carrierFreq : Frequency;
		out modulatedSignal : SignalStrength;
	}
	
	action def DemodulateSignal {
		in receivedSignal : SignalStrength;
		in carrierFreq : Frequency;
		out dataFrame : DataFrame;
	}
	
	action def TransmitData {
		in frame : DataFrame;
		in power : PowerLevel;
		out transmitted : Boolean;
	}
	
	action def ReceiveData {
		in signal : SignalStrength;
		out frame : DataFrame;
		out valid : Boolean;
	}
	
	action def TerminateConnection {
		in sessionId : String;
		out released : Boolean;
	}
	
	action def WirelessCommunication {
		in attribute framesToTransmit : DataFrame[*];
		in attribute operatingFrequency : Frequency;
		in attribute txPower : PowerLevel;
		out attribute receivedFrames : DataFrame[*] := ();
		out attribute transmittedFrames : DataFrame[*] := ();
		
		private attribute connected : Boolean := false;
		private attribute currentSession : String := "";
		
		first start;
		then merge connectionLoop;
		
		accept connReq : ConnectionRequest;
		then action establish : EstablishConnection {
			in request = connReq;
			in frequency = operatingFrequency;
			out acknowledged;
			out sessionId;
		}
		
		then decide;
			if establish.acknowledged then setConnected;
			if not establish.acknowledged then connectionLoop;
		
		action setConnected {
			then assign connected := true;
			then assign currentSession := establish.sessionId;
		}
		
		then merge dataLoop;
		
		then decide operation;
			if operation then transmitPath;
			if operation then receivePath;
		
		action transmitPath {
			for frame in framesToTransmit {
				action modulate : ModulateSignal {
					in dataFrame = frame;
					in carrierFreq = operatingFrequency;
					out modulatedSignal;
				}
				
				then action transmit : TransmitData {
					in frame = frame;
					in power = txPower;
					out transmitted;
				}
				
				then decide;
					if transmit.transmitted then recordTransmit;
					if not transmit.transmitted then retransmit;
				
				action recordTransmit {
					then assign transmittedFrames := transmittedFrames->including(frame);
				}
				then dataLoop;
				
				action retransmit;
				then dataLoop;
			}
		}
		
		action receivePath {
			accept rxSignal : SignalStrength;
			
			then action demodulate : DemodulateSignal {
				in receivedSignal = rxSignal;
				in carrierFreq = operatingFrequency;
				out dataFrame;
			}
			
			then action receive : ReceiveData {
				in signal = rxSignal;
				out frame;
				out valid;
			}
			
			then decide;
				if receive.valid then storeFrame;
				if not receive.valid then discardFrame;
			
			action storeFrame {
				then assign receivedFrames := receivedFrames->including(receive.frame);
			}
			then dataLoop;
			
			action discardFrame;
			then dataLoop;
		}
		
		accept discReq : DisconnectRequest;
		then action terminate : TerminateConnection {
			in sessionId = currentSession;
			out released;
		}
		
		then assign connected := false;
		then done;
	}
	
	requirement def CoverageRequirement {
		doc /* The wireless system shall provide coverage within a specified radius with minimum signal strength. */
	}
	
	requirement def DataThroughputRequirement {
		doc /* The wireless system shall support a minimum data throughput rate. */
	}
	
	requirement def ReliabilityRequirement {
		doc /* The wireless system shall maintain connection reliability with maximum packet loss rate. */
	}
	
	requirement def LatencyRequirement {
		doc /* The wireless system shall maintain end-to-end latency below specified threshold. */
	}
	
	requirement <'WS-REQ-001'> wirelessSystemRequirement {
		doc /* The wireless communication system shall provide reliable bidirectional data transmission between base stations and wireless devices over radio frequency channels. */
		
		subject wirelessNetwork;
		
		require CoverageRequirement;
		require DataThroughputRequirement;
		require ReliabilityRequirement;
		require LatencyRequirement;
	}
	
	part wirelessNetwork {
		part baseStation1 : BaseStation {
			attribute coverageRadius : ISQ::LengthValue;
			attribute maxConnectedDevices = 100;
			attribute operatingBand : Frequency;
		}
		
		part device1 : WirelessDevice {
			attribute deviceId = "DEV001";
		}
		
		part device2 : WirelessDevice {
			attribute deviceId = "DEV002";
		}
		
		interface wirelessLink1 
			connect baseStation1.wirelessInterface to device1.wirelessInterface;
		
		interface wirelessLink2 
			connect baseStation1.wirelessInterface to device2.wirelessInterface;
		
		perform action communicate : WirelessCommunication;
	}
}
