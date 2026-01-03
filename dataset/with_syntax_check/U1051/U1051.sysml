package EthernetCommunicationSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def MACAddress {
		attribute octet1 : String;
		attribute octet2 : String;
		attribute octet3 : String;
		attribute octet4 : String;
		attribute octet5 : String;
		attribute octet6 : String;
	}
	
	enum def FrameType {
		data;
		control;
		management;
	}
	
	item def EthernetFrame {
		attribute preamble : Integer;
		attribute destinationMAC : MACAddress;
		attribute sourceMAC : MACAddress;
		attribute etherType : Integer;
		attribute payload : String;
		attribute frameCheckSequence : Integer;
		attribute frameLength : ISQ::LengthValue;
	}
	
	attribute def DataRateMbps :> ISQ::FrequencyValue {
		attribute :>> num : Real;
	}
	
	port def EthernetPort {
		attribute portMAC : MACAddress;
		attribute linkSpeed : DataRateMbps;
		attribute duplexMode : String;
		in item rxFrames : EthernetFrame[*];
		out item txFrames : EthernetFrame[*];
	}
	
	part def PhysicalLayer {
		attribute signalLevel : Real;
		attribute encodingScheme : String;
		
		action def EncodeFrame {
			in frame : EthernetFrame;
			out encodedSignal : String;
		}
		
		action def DecodeSignal {
			in signal : String;
			out decodedFrame : EthernetFrame;
		}
	}
	
	part def MACLayer {
		attribute maxFrameSize : ISQ::LengthValue;
		attribute minFrameSize : ISQ::LengthValue;
		
		action def BuildFrame {
			in payloadData : String;
			in destMAC : MACAddress;
			in srcMAC : MACAddress;
			out frame : EthernetFrame;
		}
		
		action def ValidateFrame {
			in frame : EthernetFrame;
			out isValid : Boolean;
		}
		
		action def ExtractPayload {
			in frame : EthernetFrame;
			out payload : String;
		}
	}
	
	part def EthernetSwitch {
		port switchPorts : EthernetPort[8];
		attribute macTable : MACAddress[*];
		attribute forwardingDelay : ISQ::TimeValue;
		
		action def UpdateMACTable {
			in sourceMAC : MACAddress;
			in ingressPort : Integer;
		}
		
		action def LookupDestination {
			in destMAC : MACAddress;
			out egressPort : Integer;
		}
		
		action def BroadcastFrame {
			in frame : EthernetFrame;
			in ingressPort : Integer;
		}
		
		state def SwitchOperationState {
			entry; then idle;
			
			state idle;
			accept at idle then learning;
			
			state learning {
				do action learn : UpdateMACTable;
			}
			accept at learning then forwarding;
			
			state forwarding {
				do action forward : LookupDestination;
			}
			accept at forwarding then idle;
		}
	}
	
	part def NetworkInterfaceCard {
		port ethPort : EthernetPort;
		part phy : PhysicalLayer;
		part mac : MACLayer;
		attribute cardMAC : MACAddress;
		
		state def NICState {
			entry; then linkDown;
			
			state linkDown;
			accept at linkDown then linkUp;
			
			state linkUp;
			accept at linkUp then ready;
			
			state ready;
			accept at ready then transmitting;
			accept at ready then receiving;
			
			state transmitting {
				do action tx : PhysicalLayer::EncodeFrame;
			}
			accept at transmitting then ready;
			
			state receiving {
				do action rx : PhysicalLayer::DecodeSignal;
			}
			accept at receiving then ready;
		}
	}
	
	part def NetworkHost {
		attribute hostMAC : MACAddress;
		attribute hostName : String;
		port networkPort : EthernetPort;
		part nic : NetworkInterfaceCard;
		
		action def SendMessage {
			in messageData : String;
			in targetMAC : MACAddress;
			out sentFrame : EthernetFrame;
		}
		
		action def ReceiveMessage {
			in receivedFrame : EthernetFrame;
			out messageData : String;
		}
	}
	
	requirement def EthernetSystemRequirements {
		doc /* Requirements for Ethernet-based communication system */
		
		requirement <'REQ-001'> frameTransmissionReq {
			doc /* The system shall transmit Ethernet frames between connected network hosts */
			subject ethernetNetwork;
		}
		
		requirement <'REQ-002'> errorDetectionReq {
			doc /* All frames shall include frame check sequence for error detection */
			subject ethernetNetwork;
		}
		
		requirement <'REQ-003'> switchingPerformanceReq {
			doc /* The switch shall forward frames with latency less than 10 microseconds */
			subject ethernetNetwork.centralSwitch;
			assume constraint { 
				ethernetNetwork.centralSwitch.forwardingDelay.num < 10.0e-6
			}
		}
		
		requirement <'REQ-004'> linkSpeedReq {
			doc /* Network interfaces shall support 100 Mbps or 1000 Mbps operation */
			subject ethernetNetwork;
		}
		
		requirement <'REQ-005'> uniqueMACReq {
			doc /* Each network interface shall have a globally unique MAC address */
			subject ethernetNetwork;
		}
	}
	
	action def TransmitEthernetData {
		first start;
		then action preparePayload {
			in sourceData : String;
			in destination : MACAddress;
			in source : MACAddress;
			out readyData : String;
		}
		then action buildFrame : MACLayer::BuildFrame {
			in payloadData = preparePayload.readyData;
			in destMAC = preparePayload.destination;
			in srcMAC = preparePayload.source;
			out frame;
		}
		then action encode : PhysicalLayer::EncodeFrame {
			in frame = buildFrame.frame;
			out encodedSignal;
		}
		then action transmitSignal {
			in signal : String = encode.encodedSignal;
		}
		then done;
	}
	
	action def ReceiveEthernetData {
		first start;
		then action receiveSignal {
			in incomingSignal : String;
			out signal : String;
		}
		then action decode : PhysicalLayer::DecodeSignal {
			in signal = receiveSignal.signal;
			out decodedFrame;
		}
		then action validate : MACLayer::ValidateFrame {
			in frame = decode.decodedFrame;
			out isValid;
		}
		then decide;
			if validate.isValid then extractData;
			if not validate.isValid then dropFrame;
		action extractData : MACLayer::ExtractPayload {
			in frame = decode.decodedFrame;
			out payload;
		}
		then processPayload;
		action dropFrame;
		then done;
		action processPayload {
			in data : String = extractData.payload;
		}
		then done;
	}
	
	action def SwitchForwardingOperation {
		first start;
		then merge awaitFrame;
		then action receiveAtPort {
			in incomingFrame : EthernetFrame;
			in portNumber : Integer;
			out frame : EthernetFrame;
			out port : Integer;
		}
		then action updateTable : EthernetSwitch::UpdateMACTable {
			in sourceMAC = receiveAtPort.frame.sourceMAC;
			in ingressPort = receiveAtPort.port;
		}
		then action lookupPort : EthernetSwitch::LookupDestination {
			in destMAC = receiveAtPort.frame.destinationMAC;
			out egressPort;
		}
		then decide;
			if lookupPort.egressPort > 0 then forwardUnicast;
			if lookupPort.egressPort == 0 then forwardBroadcast;
		action forwardUnicast {
			in frame : EthernetFrame = receiveAtPort.frame;
			in targetPort : Integer = lookupPort.egressPort;
		}
		then awaitFrame;
		action forwardBroadcast : EthernetSwitch::BroadcastFrame {
			in frame = receiveAtPort.frame;
			in ingressPort = receiveAtPort.port;
		}
		then awaitFrame;
	}
	
	part ethernetNetwork {
		doc /*
		This Ethernet-based communication system enables reliable data exchange between multiple 
		network hosts through a central switching infrastructure.
		
		The primary function is to transmit data frames between connected hosts using the Ethernet 
		protocol. Each host is equipped with a network interface card (NIC) that has a unique MAC 
		address for identification on the network.
		
		When a host needs to send data, its MAC layer encapsulates the data into an Ethernet frame 
		containing source and destination MAC addresses, payload data, and a frame check sequence 
		for error detection. The physical layer then encodes this frame into electrical signals 
		transmitted over the network cable.
		
		The central Ethernet switch receives frames on its ports and performs intelligent forwarding. 
		It maintains a MAC address table that maps each known MAC address to the port where that 
		device is connected. When a frame arrives, the switch learns the source MAC address and 
		updates its table. It then looks up the destination MAC address to determine the correct 
		egress port. If the destination is known, the frame is forwarded only to that specific port, 
		reducing unnecessary network traffic. If the destination is unknown, the frame is broadcast 
		to all ports except the ingress port.
		
		At the receiving host, the physical layer decodes the incoming signal back into a frame. 
		The MAC layer validates the frame's integrity using the frame check sequence. If valid, 
		it extracts the payload data for processing by the host application. Invalid frames are 
		discarded to maintain data integrity.
		
		This architecture provides efficient, scalable network communication with error detection, 
		enabling multiple devices to share network resources while maintaining independent 
		point-to-point communication paths.
		*/
		
		part centralSwitch : EthernetSwitch {
			attribute :>> forwardingDelay = ISQ::TimeValue { num = 5.0e-6; }
			port :>> switchPorts;
		}
		
		part hostA : NetworkHost {
			attribute :>> hostName = "WorkstationA";
			attribute :>> hostMAC {
				attribute :>> octet1 = "00";
				attribute :>> octet2 = "1B";
				attribute :>> octet3 = "44";
				attribute :>> octet4 = "11";
				attribute :>> octet5 = "3A";
				attribute :>> octet6 = "B7";
			}
			perform action sendData[*] references TransmitEthernetData;
			perform action receiveData[*] references ReceiveEthernetData;
		}
		
		part hostB : NetworkHost {
			attribute :>> hostName = "WorkstationB";
			attribute :>> hostMAC {
				attribute :>> octet1 = "00";
				attribute :>> octet2 = "1B";
				attribute :>> octet3 = "44";
				attribute :>> octet4 = "11";
				attribute :>> octet5 = "3A";
				attribute :>> octet6 = "B8";
			}
			perform action sendData[*] references TransmitEthernetData;
			perform action receiveData[*] references ReceiveEthernetData;
		}
		
		part hostC : NetworkHost {
			attribute :>> hostName = "ServerC";
			attribute :>> hostMAC {
				attribute :>> octet1 = "00";
				attribute :>> octet2 = "1B";
				attribute :>> octet3 = "44";
				attribute :>> octet4 = "11";
				attribute :>> octet5 = "3A";
				attribute :>> octet6 = "B9";
			}
			perform action sendData[*] references TransmitEthernetData;
			perform action receiveData[*] references ReceiveEthernetData;
		}
		
		part hostD : NetworkHost {
			attribute :>> hostName = "PrinterD";
			attribute :>> hostMAC {
				attribute :>> octet1 = "00";
				attribute :>> octet2 = "1B";
				attribute :>> octet3 = "44";
				attribute :>> octet4 = "11";
				attribute :>> octet5 = "3A";
				attribute :>> octet6 = "BA";
			}
			perform action sendData[*] references TransmitEthernetData;
			perform action receiveData[*] references ReceiveEthernetData;
		}
		
		connect hostA.networkPort to centralSwitch.switchPorts[1];
		connect hostB.networkPort to centralSwitch.switchPorts[2];
		connect hostC.networkPort to centralSwitch.switchPorts[3];
		connect hostD.networkPort to centralSwitch.switchPorts[4];
		
		perform action switchingOperation : SwitchForwardingOperation;
		
		satisfy EthernetSystemRequirements::frameTransmissionReq;
		satisfy EthernetSystemRequirements::errorDetectionReq;
		satisfy EthernetSystemRequirements::switchingPerformanceReq;
		satisfy EthernetSystemRequirements::linkSpeedReq;
		satisfy EthernetSystemRequirements::uniqueMACReq;
	}
}
