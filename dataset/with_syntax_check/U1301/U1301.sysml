package MiWiWirelessSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def NodeAddress :> Integer;
	attribute def ChannelNumber :> Integer;
	attribute def PANID :> Integer;
	
	attribute def DataRate :> Real {
		doc /* Data transmission rate in kbps */
	}
	
	attribute def SignalStrength :> Real {
		doc /* Signal strength in dBm */
	}
	
	item def MiWiPacket {
		attribute sourceAddress : NodeAddress;
		attribute destinationAddress : NodeAddress;
		attribute payloadLength : Integer;
		attribute payload : String;
		attribute sequenceNumber : Integer;
		attribute acknowledgmentRequired : Boolean;
	}
	
	port def RFPort {
		attribute operatingChannel : ChannelNumber;
		attribute signalStrength : SignalStrength;
		out item transmittedPackets : MiWiPacket[*];
		in item receivedPackets : MiWiPacket[*];
	}
	
	port def DataPort {
		out item dataOut : MiWiPacket[*];
		in item dataIn : MiWiPacket[*];
	}
	
	part def RFTransceiver {
		port rfInterface : RFPort;
		attribute transmitPower : ISQ::PowerValue;
		attribute receiveSensitivity : SignalStrength;
		attribute frequency : ISQ::FrequencyValue;
		attribute dataRate : DataRate;
		
		action transmit {
			in packet : MiWiPacket;
			out transmitted : Boolean;
		}
		
		action receive {
			out packet : MiWiPacket;
			out rssi : SignalStrength;
		}
	}
	
	part def MicrocontrollerUnit {
		attribute clockSpeed : ISQ::FrequencyValue;
		attribute ramSize : Integer;
		attribute flashSize : Integer;
		
		action processPacket {
			in rawPacket : MiWiPacket;
			out processedPacket : MiWiPacket;
		}
		
		action executeProtocolStack {
			in command : String;
			out status : Boolean;
		}
	}
	
	part def NetworkCoordinator {
		attribute panID : PANID;
		attribute nodeAddress : NodeAddress;
		attribute maxConnectedDevices : Integer;
		attribute currentConnectedDevices : Integer;
		
		action formNetwork {
			in channel : ChannelNumber;
			in panIdentifier : PANID;
			out networkFormed : Boolean;
		}
		
		action permitJoin {
			in duration : ISQ::TimeValue;
			out joinEnabled : Boolean;
		}
		
		action routePacket {
			in packet : MiWiPacket;
			out nextHop : NodeAddress;
		}
	}
	
	part def EndDevice {
		attribute nodeAddress : NodeAddress;
		attribute parentAddress : NodeAddress;
		attribute isJoined : Boolean;
		attribute sleepEnabled : Boolean;
		
		action scanNetworks {
			out availableNetworks : PANID[*];
		}
		
		action joinNetwork {
			in targetPAN : PANID;
			in coordinatorAddress : NodeAddress;
			out joined : Boolean;
		}
		
		action transmitSensorData {
			in sensorValue : Real;
			out packet : MiWiPacket;
		}
	}
	
	state def MiWiNodeStateMachine {
		entry; then initialization;
		
		state initialization {
			entry action initHw {
				out initialized : Boolean;
			}
		}
		
		transition initialization_to_idle
			first initialization
			if initialization.initHw.initialized == true
			then idle;
		
		state idle;
		
		transition idle_to_scanning
			first idle
			accept scanCommand : String
			then scanning;
		
		state scanning {
			entry action scanNets {
				out networksFound : Integer;
			}
		}
		
		transition scanning_to_joining
			first scanning
			if scanning.scanNets.networksFound > 0
			then joining;
		
		transition scanning_to_idle
			first scanning
			if scanning.scanNets.networksFound == 0
			then idle;
		
		state joining {
			entry action tryJoin {
				in targetNetwork : PANID;
				out joinSuccess : Boolean;
			}
		}
		
		transition joining_to_connected
			first joining
			if joining.tryJoin.joinSuccess == true
			then connected;
		
		transition joining_to_idle
			first joining
			if joining.tryJoin.joinSuccess == false
			then idle;
		
		state connected {
			entry; then active;
			
			state active {
				entry action maintainLink {
					out linkActive : Boolean;
				}
			}
			
			state transmitting {
				entry action txData {
					in data : MiWiPacket;
					out sent : Boolean;
				}
			}
			
			state receiving {
				entry action receiveData {
					out data : MiWiPacket;
				}
			}
			
			state sleeping {
				entry action enterSleep {
					in sleepDuration : ISQ::TimeValue;
				}
			}
			
			transition active_to_transmitting
				first active
				accept txRequest : MiWiPacket
				then transmitting;
			
			transition transmitting_to_active
				first transmitting
				if transmitting.txData.sent == true
				then active;
			
			transition active_to_receiving
				first active
				accept rxIndication : String
				then receiving;
			
			transition receiving_to_active
				first receiving
				then active;
			
			transition active_to_sleeping
				first active
				accept sleepRequest : String
				then sleeping;
			
			transition sleeping_to_active
				first sleeping
				accept wakeupEvent : String
				then active;
		}
		
		transition connected_to_idle
			first connected
			accept leaveNetwork : String
			then idle;
	}
	
	action def EstablishMiWiNetwork {
		in coordinator : NetworkCoordinator;
		in operatingChannel : ChannelNumber;
		in panIdentifier : PANID;
		out networkActive : Boolean;
		
		first start;
		then action formNet {
			in channel : ChannelNumber = operatingChannel;
			in panIdentifier : PANID = panIdentifier;
			out networkFormed : Boolean;
		}
		then action enableJoin {
			in duration : ISQ::TimeValue = 60.0[SI::s];
			out joinEnabled : Boolean;
		}
		then assign networkActive := formNet.networkFormed and enableJoin.joinEnabled;
		then done;
	}
	
	action def TransmitDataReliably {
		in sourceDevice : EndDevice;
		in destinationAddress : NodeAddress;
		in payloadData : String;
		out deliveryConfirmed : Boolean;
		
		first start;
		then merge retryLoop;
		then action buildPacket {
			in src : NodeAddress;
			in dest : NodeAddress;
			in data : String;
			out packet : MiWiPacket;
		}
		then action transmitPacket {
			in packet : MiWiPacket;
			out transmitted : Boolean;
		}
		then action waitForAck {
			in timeout : ISQ::TimeValue;
			out ackReceived : Boolean;
		}
		then decide;
			if waitForAck.ackReceived == true then confirmDelivery;
			if waitForAck.ackReceived == false then retryLoop;
		action confirmDelivery {
			assign deliveryConfirmed := true;
		}
		then done;
	}
	
	action def RouteThroughMesh {
		in packet : MiWiPacket;
		in routingTable : NodeAddress[*];
		out forwarded : Boolean;
		
		first start;
		then action determineNextHop {
			in destination : NodeAddress;
			in table : NodeAddress[*];
			out nextHop : NodeAddress;
		}
		then action forwardPacket {
			in packet : MiWiPacket;
			in nextHop : NodeAddress;
			out success : Boolean;
		}
		then assign forwarded := forwardPacket.success;
		then done;
	}
	
	requirement def WirelessConnectivityRequirement {
		doc /* 
		The MiWi system shall provide reliable low-power wireless mesh networking 
		capability for embedded devices to communicate over short to medium range distances.
		*/
		
		require constraint communicationRange {
			doc /* The system shall support communication range of at least 50 meters 
			in open space conditions. */
		}
		
		require constraint dataReliability {
			doc /* The system shall achieve packet delivery success rate greater than 
			95% under normal operating conditions. */
		}
		
		require constraint powerConsumption {
			doc /* End devices shall operate with average power consumption below 
			100 mW during active transmission periods. */
		}
	}
	
	requirement def NetworkScalabilityRequirement {
		doc /* 
		The MiWi network shall support multiple nodes with efficient mesh routing 
		and network management capabilities.
		*/
		
		require constraint nodeCapacity {
			doc /* A single coordinator shall support at least 64 end devices 
			in a star or mesh topology. */
		}
		
		require constraint meshRouting {
			doc /* The system shall support multi-hop routing with automatic 
			route discovery and maintenance. */
		}
		
		require constraint channelAccess {
			doc /* CSMA/CA collision avoidance mechanism shall be implemented 
			for shared channel access. */
		}
	}
	
	requirement def InteroperabilityRequirement {
		doc /* 
		The MiWi system shall comply with IEEE 802.15.4 PHY/MAC layer specifications 
		for 2.4 GHz operation.
		*/
		
		require constraint frequencyBand {
			doc /* The system shall operate in the 2.4 GHz ISM band using 
			IEEE 802.15.4 compliant channels. */
		}
		
		require constraint dataRate {
			doc /* The system shall support data rates of 250 kbps for 
			2.4 GHz operation. */
		}
	}
	
	part miwiCoordinatorNode : NetworkCoordinator {
		attribute :>> panID = 4660;
		attribute :>> nodeAddress = 0;
		attribute :>> maxConnectedDevices = 64;
		attribute :>> currentConnectedDevices = 0;
		
		part transceiver : RFTransceiver {
			attribute :>> transmitPower = 3.0[SI::W];
			attribute :>> frequency = 2.45e9[SI::Hz];
			attribute :>> dataRate = 250.0;
		}
		
		part mcu : MicrocontrollerUnit {
			attribute :>> clockSpeed = 16.0e6[SI::Hz];
			attribute :>> ramSize = 8192;
			attribute :>> flashSize = 65536;
		}
		
		port dataInterface : DataPort;
		
		perform action networkSetup : EstablishMiWiNetwork {
			in coordinator = miwiCoordinatorNode;
			in operatingChannel = 15;
			in panIdentifier = 4660;
			out networkActive;
		}
	}
	
	part miwiEndDeviceNode : EndDevice {
		attribute :>> nodeAddress = 1;
		attribute :>> isJoined = false;
		attribute :>> sleepEnabled = true;
		
		part transceiver : RFTransceiver {
			attribute :>> transmitPower = 1.0[SI::W];
			attribute :>> frequency = 2.45e9[SI::Hz];
			attribute :>> dataRate = 250.0;
		}
		
		part mcu : MicrocontrollerUnit {
			attribute :>> clockSpeed = 8.0e6[SI::Hz];
			attribute :>> ramSize = 2048;
			attribute :>> flashSize = 32768;
		}
		
		port dataInterface : DataPort;
		
		exhibit state deviceStateMachine : MiWiNodeStateMachine;
		
		perform action dataTransmission[*] : TransmitDataReliably {
			in sourceDevice = miwiEndDeviceNode;
			in destinationAddress = miwiEndDeviceNode.parentAddress;
			in payloadData : String;
			out deliveryConfirmed;
		}
	}
	
	part miwiWirelessNetwork {
		doc /* 
		This model describes a MiWi wireless networking system designed for 
		low-power, short-range communication between embedded devices.
		
		The system's primary function is to enable reliable peer-to-peer and 
		mesh wireless communication using a proprietary protocol based on 
		IEEE 802.15.4 PHY/MAC layers. It operates in the 2.4 GHz ISM band 
		and supports star, peer-to-peer, and mesh network topologies.
		
		The network consists of coordinator nodes that establish and manage 
		the network infrastructure, and end devices that join the network to 
		exchange sensor data and control commands. The system implements 
		CSMA/CA for channel access, automatic acknowledgments for reliability, 
		and supports sleeping modes for power efficiency.
		
		Communication flows from end devices through RF transceivers operating 
		at 2.4 GHz, which modulate data packets onto radio frequency carriers. 
		Microcontroller units handle the MiWi protocol stack, packet routing, 
		network management, and application-level data processing. The coordinator 
		maintains network topology, manages device associations, and provides 
		routing services for multi-hop mesh communication.
		
		The system enables applications such as wireless sensor networks, 
		home automation, industrial monitoring, and IoT device connectivity 
		where low power consumption and simple deployment are critical requirements.
		*/
		
		part coordinator : NetworkCoordinator :> miwiCoordinatorNode;
		
		part endDevice1 : EndDevice :> miwiEndDeviceNode {
			attribute :>> nodeAddress = 1;
			attribute :>> parentAddress = 0;
		}
		
		part endDevice2 : EndDevice :> miwiEndDeviceNode {
			attribute :>> nodeAddress = 2;
			attribute :>> parentAddress = 0;
		}
		
		part endDevice3 : EndDevice :> miwiEndDeviceNode {
			attribute :>> nodeAddress = 3;
			attribute :>> parentAddress = 1;
		}
		
		part endDevice4 : EndDevice :> miwiEndDeviceNode {
			attribute :>> nodeAddress = 4;
			attribute :>> parentAddress = 1;
		}
		
		connection wirelessLink1 : RFPort connect 
			coordinator.transceiver.rfInterface to 
			endDevice1.transceiver.rfInterface;
		
		connection wirelessLink2 : RFPort connect 
			coordinator.transceiver.rfInterface to 
			endDevice2.transceiver.rfInterface;
		
		connection wirelessLink3 : RFPort connect 
			endDevice1.transceiver.rfInterface to 
			endDevice3.transceiver.rfInterface;
		
		connection wirelessLink4 : RFPort connect 
			endDevice1.transceiver.rfInterface to 
			endDevice4.transceiver.rfInterface;
		
		satisfy requirement wirelessConnReq : WirelessConnectivityRequirement;
		satisfy requirement networkScalabilityReq : NetworkScalabilityRequirement;
		satisfy requirement interopReq : InteroperabilityRequirement;
	}
}
