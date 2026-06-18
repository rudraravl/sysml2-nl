package EthernetBasedCommunicationSystemModel {

	import ScalarValues::*;

	enum def DuplexMode {
		enum half;
		enum full;
	}

	enum def LinkStatus {
		enum down;
		enum detecting;
		enum autoNegotiating;
		enum up;
		enum degraded;
		enum faulted;
	}

	enum def EtherType {
		enum ipv4;
		enum ipv6;
		enum arp;
		enum ptp;
		enum diagnostic;
		enum management;
	}

	enum def FrameDisposition {
		enum forwardUnicast;
		enum floodBroadcast;
		enum discardInvalid;
		enum discardFiltered;
	}

	enum def CableCategory {
		enum cat5e;
		enum cat6;
		enum cat6a;
	}

	attribute def DataRate {
		attribute value : Real;
		attribute unit : String = "Mbit/s";
	}

	attribute def TimeDuration {
		attribute value : Real;
		attribute unit : String = "us";
	}

	attribute def Length {
		attribute value : Real;
		attribute unit : String = "m";
	}

	attribute def Voltage {
		attribute value : Real;
		attribute unit : String = "V";
	}

	attribute def Temperature {
		attribute value : Real;
		attribute unit : String = "degC";
	}

	attribute def Percentage {
		attribute value : Real;
		attribute unit : String = "%";
	}

	attribute def ByteCount {
		attribute value : Integer;
		attribute unit : String = "byte";
	}

	attribute def FrameRate {
		attribute value : Real;
		attribute unit : String = "frame/s";
	}

	attribute def MACAddress {
		attribute octet1 : Integer;
		attribute octet2 : Integer;
		attribute octet3 : Integer;
		attribute octet4 : Integer;
		attribute octet5 : Integer;
		attribute octet6 : Integer;
	}

	attribute def IPv4Address {
		attribute octet1 : Integer;
		attribute octet2 : Integer;
		attribute octet3 : Integer;
		attribute octet4 : Integer;
	}

	item def PayloadBytes {
		attribute size : ByteCount {
			:>> value = 512;
			:>> unit = "byte";
		}
	}

	item def ApplicationPacket {
		attribute sourceIp : IPv4Address;
		attribute destinationIp : IPv4Address;
		attribute payloadSize : ByteCount {
			:>> value = 256;
			:>> unit = "byte";
		}
		attribute priorityCodePoint : Integer = 0;
		item payload : PayloadBytes;
	}

	item def EthernetFrame {
		attribute preambleSize : ByteCount {
			:>> value = 7;
			:>> unit = "byte";
		}
		attribute startFrameDelimiterSize : ByteCount {
			:>> value = 1;
			:>> unit = "byte";
		}
		attribute destinationMac : MACAddress;
		attribute sourceMac : MACAddress;
		attribute vlanId : Integer = 10;
		attribute priorityCodePoint : Integer = 0;
		attribute etherType : EtherType = ipv4;
		attribute payloadSize : ByteCount {
			:>> value = 512;
			:>> unit = "byte";
		}
		attribute frameCheckSequenceSize : ByteCount {
			:>> value = 4;
			:>> unit = "byte";
		}
		attribute totalFrameSize : ByteCount {
			:>> value = 554;
			:>> unit = "byte";
		}
		item payload : PayloadBytes;
	}

	item def ManagementMessage {
		attribute commandCode : Integer;
		attribute targetPortId : Integer;
		attribute requestedVlanId : Integer;
	}

	item def LinkPulse {
		attribute pulseVoltage : Voltage {
			:>> value = 2.5;
			:>> unit = "V";
		}
		attribute interval : TimeDuration {
			:>> value = 16.0;
			:>> unit = "ms";
		}
	}

	port def EthernetPort {
		in item rxFrame : EthernetFrame;
		out item txFrame : EthernetFrame;
		in item linkPulseIn : LinkPulse;
		out item linkPulseOut : LinkPulse;
		attribute macAddress : MACAddress;
		attribute nominalRate : DataRate {
			:>> value = 1000.0;
			:>> unit = "Mbit/s";
		}
		attribute duplex : DuplexMode = full;
		attribute status : LinkStatus = down;
		attribute maximumFrameSize : ByteCount {
			:>> value = 1522;
			:>> unit = "byte";
		}
	}

	port def ApplicationServicePort {
		in item receivedPacket : ApplicationPacket;
		out item packetToTransmit : ApplicationPacket;
		attribute serviceRate : DataRate {
			:>> value = 100.0;
			:>> unit = "Mbit/s";
		}
	}

	port def ManagementPort {
		in item command : ManagementMessage;
		out item response : ManagementMessage;
		attribute managementRate : DataRate {
			:>> value = 10.0;
			:>> unit = "Mbit/s";
		}
	}

	interface def FullDuplexEthernetInterface {
		end port a : EthernetPort;
		end port b : EthernetPort;
		flow a.txFrame to b.rxFrame;
		flow b.txFrame to a.rxFrame;
		flow a.linkPulseOut to b.linkPulseIn;
		flow b.linkPulseOut to a.linkPulseIn;
	}

	connection def CopperEthernetLink {
		end port endA : EthernetPort;
		end port endB : EthernetPort;
		attribute length : Length {
			:>> value = 20.0;
			:>> unit = "m";
		}
		attribute category : CableCategory = cat6;
		attribute supportedRate : DataRate {
			:>> value = 1000.0;
			:>> unit = "Mbit/s";
		}
		attribute propagationDelay : TimeDuration {
			:>> value = 0.10;
			:>> unit = "us";
		}
		interface : FullDuplexEthernetInterface connect endA to endB;
	}

	action def EncapsulatePacket {
		in item packetIn : ApplicationPacket;
		out item frameOut : EthernetFrame;
		attribute maximumEncapsulationLatency : TimeDuration {
			:>> value = 5.0;
			:>> unit = "us";
		}
	}

	action def DecapsulateFrame {
		in item frameIn : EthernetFrame;
		out item packetOut : ApplicationPacket;
		attribute maximumDecapsulationLatency : TimeDuration {
			:>> value = 5.0;
			:>> unit = "us";
		}
	}

	action def ValidateFrameCheckSequence {
		in item receivedFrame : EthernetFrame;
		out attribute valid : Boolean;
		attribute maximumValidationLatency : TimeDuration {
			:>> value = 2.0;
			:>> unit = "us";
		}
	}

	action def LearnSourceAddress {
		in item receivedFrame : EthernetFrame;
		in attribute ingressPortId : Integer;
		out attribute learned : Boolean;
		attribute maximumLearningLatency : TimeDuration {
			:>> value = 3.0;
			:>> unit = "us";
		}
	}

	action def LookupDestinationAddress {
		in item receivedFrame : EthernetFrame;
		out attribute egressPortId : Integer;
		out attribute knownDestination : Boolean;
		attribute maximumLookupLatency : TimeDuration {
			:>> value = 4.0;
			:>> unit = "us";
		}
	}

	action def ForwardEthernetFrame {
		in item ingressFrame : EthernetFrame;
		in attribute ingressPortId : Integer;
		out item egressFrame : EthernetFrame;
		out attribute egressPortId : Integer;
		out attribute disposition : FrameDisposition;
		attribute maximumSwitchingLatency : TimeDuration {
			:>> value = 20.0;
			:>> unit = "us";
		}

		action validate : ValidateFrameCheckSequence;
		action learn : LearnSourceAddress;
		action lookup : LookupDestinationAddress;

		flow ingressFrame to validate.receivedFrame;
		flow ingressFrame to learn.receivedFrame;
		flow ingressPortId to learn.ingressPortId;
		flow ingressFrame to lookup.receivedFrame;
	}

	action def TransmitApplicationTraffic {
		in item applicationPacket : ApplicationPacket;
		out item deliveredPacket : ApplicationPacket;
		attribute endToEndLatencyBudget : TimeDuration {
			:>> value = 1000.0;
			:>> unit = "us";
		}

		action encapsulate : EncapsulatePacket;
		action switchForward : ForwardEthernetFrame;
		action decapsulate : DecapsulateFrame;

		flow applicationPacket to encapsulate.packetIn;
		flow encapsulate.frameOut to switchForward.ingressFrame;
		flow switchForward.egressFrame to decapsulate.frameIn;
		flow decapsulate.packetOut to deliveredPacket;
	}

	state def EthernetPortLifecycle {
		attribute portStatus : LinkStatus = down;

		state Down;
		state Detecting;
		state AutoNegotiating;
		state Up;
		state Degraded;
		state Faulted;

		transition initial then Down;
		transition linkPulseDetected first Down then Detecting;
		transition startNegotiation first Detecting then AutoNegotiating;
		transition negotiationSuccessful first AutoNegotiating then Up;
		transition excessiveErrors first Up then Degraded;
		transition errorsCleared first Degraded then Up;
		transition physicalFault first Detecting then Faulted;
		transition negotiationFault first AutoNegotiating then Faulted;
		transition operationalFault first Up then Faulted;
		transition resetFault first Faulted then Down;
		transition cableRemoved first Up then Down;
		transition degradedCableRemoved first Degraded then Down;
	}

	state def SwitchLifecycle {
		state PoweredOff;
		state Booting;
		state SelfTest;
		state Operational;
		state Maintenance;
		state Fault;

		transition initial then PoweredOff;
		transition powerApplied first PoweredOff then Booting;
		transition firmwareLoaded first Booting then SelfTest;
		transition selfTestPassed first SelfTest then Operational;
		transition managementRequested first Operational then Maintenance;
		transition maintenanceComplete first Maintenance then Operational;
		transition selfTestFailed first SelfTest then Fault;
		transition criticalFaultDetected first Operational then Fault;
		transition faultReset first Fault then Booting;
		transition powerRemoved first Operational then PoweredOff;
	}

	part def EthernetPHY {
		port line : EthernetPort;
		port macSide : EthernetPort;
		attribute receiveSensitivity : Voltage {
			:>> value = 0.10;
			:>> unit = "V";
		}
		attribute transmitAmplitude : Voltage {
			:>> value = 2.5;
			:>> unit = "V";
		}
		attribute linkStatus : LinkStatus = down;
		perform state portLifecycle : EthernetPortLifecycle;
	}

	part def EthernetMAC {
		port upperService : ApplicationServicePort;
		port mediaAccess : EthernetPort;
		attribute localAddress : MACAddress;
		attribute maximumTransmissionUnit : ByteCount {
			:>> value = 1500;
			:>> unit = "byte";
		}
		attribute interFrameGap : TimeDuration {
			:>> value = 0.096;
			:>> unit = "us";
		}
		perform action encapsulation : EncapsulatePacket;
		perform action decapsulation : DecapsulateFrame;
	}

	part def NetworkInterfaceCard {
		port hostService : ApplicationServicePort;
		port lan : EthernetPort;
		part mac : EthernetMAC;
		part phy : EthernetPHY;
		connect hostService to mac.upperService;
		connect mac.mediaAccess to phy.macSide;
		connect phy.line to lan;
	}

	part def EthernetEndStation {
		port application : ApplicationServicePort;
		port lan : EthernetPort;
		attribute stationName : String;
		attribute ipAddress : IPv4Address;
		attribute offeredLoad : DataRate {
			:>> value = 50.0;
			:>> unit = "Mbit/s";
		}
		part nic : NetworkInterfaceCard;
		connect application to nic.hostService;
		connect nic.lan to lan;
		perform action sendAndReceive : TransmitApplicationTraffic;
	}

	part def MACAddressTable {
		attribute maximumEntries : Integer = 8192;
		attribute agingTime : TimeDuration {
			:>> value = 300.0;
			:>> unit = "s";
		}
	}

	part def SwitchingFabric {
		port fabricPort1 : EthernetPort;
		port fabricPort2 : EthernetPort;
		port fabricPort3 : EthernetPort;
		port fabricPort4 : EthernetPort;
		port fabricPort5 : EthernetPort;
		port fabricPort6 : EthernetPort;
		port fabricPort7 : EthernetPort;
		port fabricPort8 : EthernetPort;

		attribute capacity : DataRate {
			:>> value = 16000.0;
			:>> unit = "Mbit/s";
		}
		attribute maximumFrameLatency : TimeDuration {
			:>> value = 20.0;
			:>> unit = "us";
		}
		attribute frameLossRatio : Percentage {
			:>> value = 0.001;
			:>> unit = "%";
		}

		perform action forwarding : ForwardEthernetFrame;
	}

	part def ManagedEthernetSwitch {
		port port1 : EthernetPort;
		port port2 : EthernetPort;
		port port3 : EthernetPort;
		port port4 : EthernetPort;
		port port5 : EthernetPort;
		port port6 : EthernetPort;
		port port7 : EthernetPort;
		port port8 : EthernetPort;
		port management : ManagementPort;

		attribute switchName : String = "CoreManagedEthernetSwitch";
		attribute operatingTemperature : Temperature {
			:>> value = 35.0;
			:>> unit = "degC";
		}
		attribute forwardingRate : FrameRate {
			:>> value = 1488000.0;
			:>> unit = "frame/s";
		}
		attribute switchingLatency : TimeDuration {
			:>> value = 20.0;
			:>> unit = "us";
		}

		part addressTable : MACAddressTable;
		part fabric : SwitchingFabric;

		connect port1 to fabric.fabricPort1;
		connect port2 to fabric.fabricPort2;
		connect port3 to fabric.fabricPort3;
		connect port4 to fabric.fabricPort4;
		connect port5 to fabric.fabricPort5;
		connect port6 to fabric.fabricPort6;
		connect port7 to fabric.fabricPort7;
		connect port8 to fabric.fabricPort8;

		perform state lifecycle : SwitchLifecycle;
		perform action frameForwarding : ForwardEthernetFrame;
	}

	part def NetworkManagementConsole {
		port management : ManagementPort;
		attribute consoleIp : IPv4Address;
		attribute pollingInterval : TimeDuration {
			:>> value = 5.0;
			:>> unit = "s";
		}
	}

	part def EthernetCommunicationSystem {
		doc /* Primary high-level function: provide wired Ethernet communication among attached devices by accepting application packets from end stations, encapsulating them as Ethernet frames, transporting frames across full-duplex copper links through a managed switch, forwarding each valid frame to the appropriate destination port using learned MAC addresses, and delivering the recovered packet to the intended receiving application within bounded latency and loss. */

		port engineeringAccess : ManagementPort;

		attribute systemName : String = "OfficeAutomationEthernetLAN";
		attribute aggregateOfferedLoad : DataRate {
			:>> value = 250.0;
			:>> unit = "Mbit/s";
		}
		attribute maximumEndToEndLatency : TimeDuration {
			:>> value = 1000.0;
			:>> unit = "us";
		}
		attribute minimumAvailability : Percentage {
			:>> value = 99.9;
			:>> unit = "%";
		}

		part switch : ManagedEthernetSwitch;

		part controller : EthernetEndStation {
			:>> stationName = "AutomationController";
			:>> offeredLoad {
				:>> value = 80.0;
				:>> unit = "Mbit/s";
			}
		}

		part hmiPanel : EthernetEndStation {
			:>> stationName = "HumanMachineInterface";
			:>> offeredLoad {
				:>> value = 40.0;
				:>> unit = "Mbit/s";
			}
		}

		part sensorGateway : EthernetEndStation {
			:>> stationName = "SensorGateway";
			:>> offeredLoad {
				:>> value = 60.0;
				:>> unit = "Mbit/s";
			}
		}

		part dataServer : EthernetEndStation {
			:>> stationName = "DataServer";
			:>> offeredLoad {
				:>> value = 70.0;
				:>> unit = "Mbit/s";
			}
		}

		part managementConsole : NetworkManagementConsole;

		connection controllerLink : CopperEthernetLink connect controller.lan to switch.port1 {
			:>> length {
				:>> value = 12.0;
				:>> unit = "m";
			}
			:>> category = cat6;
		}

		connection hmiLink : CopperEthernetLink connect hmiPanel.lan to switch.port2 {
			:>> length {
				:>> value = 18.0;
				:>> unit = "m";
			}
			:>> category = cat6;
		}

		connection sensorGatewayLink : CopperEthernetLink connect sensorGateway.lan to switch.port3 {
			:>> length {
				:>> value = 32.0;
				:>> unit = "m";
			}
			:>> category = cat6;
		}

		connection serverLink : CopperEthernetLink connect dataServer.lan to switch.port4 {
			:>> length {
				:>> value = 8.0;
				:>> unit = "m";
			}
			:>> category = cat6a;
		}

		connect managementConsole.management to switch.management;
		connect engineeringAccess to switch.management;

		perform action primaryCommunication : TransmitApplicationTraffic;
	}

	constraint def OfferedLoadWithinSwitchCapacity {
		in offeredLoad : DataRate;
		in capacity : DataRate;
		constraint { offeredLoad.value <= capacity.value }
	}

	constraint def EndToEndLatencyWithinBudget {
		in actualLatency : TimeDuration;
		in requiredLatency : TimeDuration;
		constraint { actualLatency.value <= requiredLatency.value }
	}

	constraint def EthernetFrameSizeWithinMTU {
		in frameSize : ByteCount;
		in maximumFrameSize : ByteCount;
		constraint { frameSize.value <= maximumFrameSize.value }
	}

	constraint def LinkLengthWithinCopperEthernetLimit {
		in linkLength : Length;
		constraint { linkLength.value <= 100.0 }
	}

	requirement def PrimaryEthernetFunctionRequirement {
		subject system : EthernetCommunicationSystem;
		doc /* The Ethernet communication system shall provide packet-based wired connectivity between all connected end stations through a switched full-duplex Ethernet LAN. */
		require constraint {
			system.aggregateOfferedLoad.value <= system.switch.fabric.capacity.value
		}
	}

	requirement def FrameForwardingRequirement {
		subject switch : ManagedEthernetSwitch;
		doc /* The managed switch shall validate received Ethernet frames, learn source MAC addresses, determine the destination egress port, and forward valid frames without modifying payload data. */
		require constraint {
			switch.switchingLatency.value <= 20.0
		}
	}

	requirement def EndToEndLatencyRequirement {
		subject system : EthernetCommunicationSystem;
		doc /* Any application packet exchanged between two connected end stations shall be delivered within the system end-to-end latency budget under the specified aggregate offered load. */
		require constraint {
			system.maximumEndToEndLatency.value <= 1000.0
		}
	}

	requirement def LinkRateRequirement {
		subject system : EthernetCommunicationSystem;
		doc /* Each access link shall support full-duplex 1000 Mbit/s Ethernet operation. */
		require constraint {
			system.switch.port1.nominalRate.value >= 1000.0 and
			system.switch.port2.nominalRate.value >= 1000.0 and
			system.switch.port3.nominalRate.value >= 1000.0 and
			system.switch.port4.nominalRate.value >= 1000.0
		}
	}

	requirement def CableLengthRequirement {
		subject system : EthernetCommunicationSystem;
		doc /* Each copper Ethernet link shall be no longer than 100 m. */
		require constraint {
			system.controllerLink.length.value <= 100.0 and
			system.hmiLink.length.value <= 100.0 and
			system.sensorGatewayLink.length.value <= 100.0 and
			system.serverLink.length.value <= 100.0
		}
	}

	requirement def AvailabilityRequirement {
		subject system : EthernetCommunicationSystem;
		doc /* The Ethernet communication system shall provide at least 99.9 percent operational availability for its primary communication function. */
		require constraint {
			system.minimumAvailability.value >= 99.9
		}
	}

	part ethernetLAN : EthernetCommunicationSystem;

}
