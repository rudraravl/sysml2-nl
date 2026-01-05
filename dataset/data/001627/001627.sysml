package 'WiFi Wireless Network System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def MACAddress {
		attribute bytes : String[6];
	}
	
	attribute def SSID {
		attribute name : String;
	}
	
	attribute def ChannelNumber {
		attribute channel : Integer;
	}
	
	attribute def SignalStrength :> ISQ::PowerValue;
	
	attribute def DataRate :> ISQ::FrequencyValue;
	
	attribute def EncryptionKey {
		attribute key : String;
	}
	
	enum def WiFiStandard {
		enum WiFi4_80211n;
		enum WiFi5_80211ac;
		enum WiFi6_80211ax;
	}
	
	enum def SecurityProtocol {
		enum WPA2;
		enum WPA3;
	}
	
	enum def ConnectionStatus {
		enum idle;
		enum scanning;
		enum authenticating;
		enum associated;
		enum connected;
		enum transmitting;
		enum receiving;
		enum disconnected;
	}
	
	item def DataPacket {
		attribute sourceAddress : MACAddress;
		attribute destinationAddress : MACAddress;
		attribute payload : String;
		attribute size : ISQ::LengthValue;
		attribute timestamp : ISQ::TimeValue;
	}
	
	port def WiFiRadioPort {
		out item txPacket : DataPacket;
		in item rxPacket : DataPacket;
		attribute frequency : ISQ::FrequencyValue;
		attribute power : SignalStrength;
	}
	
	port def NetworkPort {
		out item dataOut : DataPacket;
		in item dataIn : DataPacket;
	}
	
	part def RadioTransceiver {
		attribute operatingFrequency : ISQ::FrequencyValue;
		attribute transmitPower : SignalStrength;
		attribute channel : ChannelNumber;
		port radioInterface : WiFiRadioPort;
		
		action def Transmit {
			in packet : DataPacket;
			in power : SignalStrength;
			in freq : ISQ::FrequencyValue;
			out transmittedPacket : DataPacket;
		}
		
		action def Receive {
			in freq : ISQ::FrequencyValue;
			out receivedPacket : DataPacket;
			out rssi : SignalStrength;
		}
		
		action def TuneChannel {
			in targetChannel : ChannelNumber;
			out tuned : Boolean;
		}
	}
	
	part def MACController {
		attribute address : MACAddress;
		attribute status : ConnectionStatus;
		port upperLayer : NetworkPort;
		port lowerLayer : WiFiRadioPort;
		
		action def EncapsulateFrame {
			in data : String;
			in destMAC : MACAddress;
			in srcMAC : MACAddress;
			out frame : DataPacket;
		}
		
		action def DecapsulateFrame {
			in frame : DataPacket;
			out data : String;
		}
		
		action def ChannelAccess {
			in channel : ChannelNumber;
			out accessGranted : Boolean;
		}
		
		action def AcknowledgeFrame {
			in receivedFrame : DataPacket;
			out ackFrame : DataPacket;
		}
	}
	
	part def SecurityEngine {
		attribute protocol : SecurityProtocol;
		attribute key : EncryptionKey;
		
		action def Authenticate {
			in credentials : String;
			in ssid : SSID;
			out authenticated : Boolean;
			out sessionKey : EncryptionKey;
		}
		
		action def Encrypt {
			in plaintext : String;
			in encKey : EncryptionKey;
			out ciphertext : String;
		}
		
		action def Decrypt {
			in ciphertext : String;
			in encKey : EncryptionKey;
			out plaintext : String;
		}
	}
	
	part def Antenna {
		attribute gain : Real;
		attribute frequency : ISQ::FrequencyValue;
		attribute polarization : String;
		port rfPort : WiFiRadioPort;
	}
	
	part def AccessPoint {
		attribute ssid : SSID;
		attribute macAddress : MACAddress;
		attribute standard : WiFiStandard;
		attribute operatingChannel : ChannelNumber;
		attribute maxClients : Integer;
		
		port wirelessPort : WiFiRadioPort;
		port ethernetPort : NetworkPort;
		
		part radio : RadioTransceiver {
			attribute operatingFrequency = 2.4e9[Hz];
			attribute transmitPower = 20.0[dBm];
			port radioInterface;
		}
		
		part macLayer : MACController {
			port upperLayer;
			port lowerLayer;
		}
		
		part security : SecurityEngine {
			attribute protocol = SecurityProtocol::WPA3;
		}
		
		part txAntenna : Antenna {
			attribute gain = 5.0;
			attribute frequency = 2.4e9[Hz];
			port rfPort;
		}
		
		part rxAntenna : Antenna {
			attribute gain = 5.0;
			attribute frequency = 2.4e9[Hz];
			port rfPort;
		}
		
		connect radio.radioInterface to macLayer.lowerLayer;
		connect txAntenna.rfPort to radio.radioInterface;
		connect rxAntenna.rfPort to radio.radioInterface;
		connect macLayer.upperLayer to ethernetPort;
	}
	
	part def ClientStation {
		attribute macAddress : MACAddress;
		attribute status : ConnectionStatus;
		
		port wirelessPort : WiFiRadioPort;
		port applicationPort : NetworkPort;
		
		part radio : RadioTransceiver {
			attribute operatingFrequency = 2.4e9[Hz];
			attribute transmitPower = 15.0[dBm];
			port radioInterface;
		}
		
		part macLayer : MACController {
			port upperLayer;
			port lowerLayer;
		}
		
		part security : SecurityEngine {
			attribute protocol = SecurityProtocol::WPA3;
		}
		
		part antenna : Antenna {
			attribute gain = 2.0;
			attribute frequency = 2.4e9[Hz];
			port rfPort;
		}
		
		connect radio.radioInterface to macLayer.lowerLayer;
		connect antenna.rfPort to radio.radioInterface;
		connect macLayer.upperLayer to applicationPort;
	}
	
	action def ScanNetworks {
		in channels : ChannelNumber[*];
		out detectedNetworks : SSID[*];
		out signalLevels : SignalStrength[*];
		
		first start;
		for channel in channels {
			action tuneRadio : RadioTransceiver::TuneChannel {
				in targetChannel = channel;
				out tuned;
			}
			then action listenForBeacons {
				out beaconSSID : SSID;
				out beaconRSSI : SignalStrength;
			}
			then assign detectedNetworks := detectedNetworks->including(listenForBeacons.beaconSSID);
			then assign signalLevels := signalLevels->including(listenForBeacons.beaconRSSI);
		}
		then done;
	}
	
	action def ConnectToNetwork {
		in targetSSID : SSID;
		in password : String;
		out connected : Boolean;
		
		first start;
		then action scanForTarget : ScanNetworks {
			out detectedNetworks;
		}
		then decide;
			if scanForTarget.detectedNetworks->includes(targetSSID) then authenticate;
			if not scanForTarget.detectedNetworks->includes(targetSSID) then failed;
		
		action authenticate {
			action performAuth : SecurityEngine::Authenticate {
				in credentials = password;
				in ssid = targetSSID;
				out authenticated;
				out sessionKey;
			}
			then decide;
				if performAuth.authenticated then associate;
				if not performAuth.authenticated then failed;
		}
		
		action associate {
			then assign connected := true;
			then success;
		}
		
		action success;
		then done;
		
		action failed {
			then assign connected := false;
			then done;
		}
	}
	
	action def TransmitDataPacket {
		in sourceData : String;
		in destMAC : MACAddress;
		in srcMAC : MACAddress;
		out transmitted : Boolean;
		
		first start;
		then action encapsulate : MACController::EncapsulateFrame {
			in data = sourceData;
			in destMAC;
			in srcMAC;
			out frame;
		}
		then action checkAccess : MACController::ChannelAccess {
			out accessGranted;
		}
		then decide;
			if checkAccess.accessGranted then transmit;
			if not checkAccess.accessGranted then waitAndRetry;
		
		action waitAndRetry {
			then checkAccess;
		}
		
		action transmit : RadioTransceiver::Transmit {
			in packet = encapsulate.frame;
			out transmittedPacket;
		}
		then assign transmitted := true;
		then done;
	}
	
	action def ReceiveDataPacket {
		out receivedData : String;
		out received : Boolean;
		
		first start;
		then action receiveFrame : RadioTransceiver::Receive {
			out receivedPacket;
			out rssi;
		}
		then action sendAck : MACController::AcknowledgeFrame {
			in receivedFrame = receiveFrame.receivedPacket;
			out ackFrame;
		}
		then action decapsulate : MACController::DecapsulateFrame {
			in frame = receiveFrame.receivedPacket;
			out data;
		}
		then assign receivedData := decapsulate.data;
		then assign received := true;
		then done;
	}
	
	action def ManageWiFiCommunication {
		in clientMAC : MACAddress;
		in apSSID : SSID;
		in networkPassword : String;
		in outgoingData : String;
		out incomingData : String;
		
		first start;
		then action establishConnection : ConnectToNetwork {
			in targetSSID = apSSID;
			in password = networkPassword;
			out connected;
		}
		then decide;
			if establishConnection.connected then activeSession;
			if not establishConnection.connected then terminate;
		
		merge activeSession;
		then decide;
			if outgoingData != "" then sendData;
			else receiveData;
		
		action sendData : TransmitDataPacket {
			in sourceData = outgoingData;
			out transmitted;
		}
		then activeSession;
		
		action receiveData : ReceiveDataPacket {
			out receivedData;
			out received;
		}
		then assign incomingData := receiveData.receivedData;
		then activeSession;
		
		action terminate;
		then done;
	}
	
	part wifiNetworkSystem {
		part ap : AccessPoint {
			attribute ssid = SSID { name = "CorporateNetwork"; };
			attribute macAddress = MACAddress { bytes = "00:1A:2B:3C:4D:5E"; };
			attribute standard = WiFiStandard::WiFi6_80211ax;
			attribute operatingChannel = ChannelNumber { channel = 6; };
			attribute maxClients = 50;
			
			port wirelessPort;
			port ethernetPort;
		}
		
		part client1 : ClientStation {
			attribute macAddress = MACAddress { bytes = "AA:BB:CC:DD:EE:01"; };
			attribute status = ConnectionStatus::idle;
			
			port wirelessPort;
			port applicationPort;
			
			perform action session : ManageWiFiCommunication {
				in apSSID = ap.ssid;
				in networkPassword = "SecurePass123";
			}
		}
		
		part client2 : ClientStation {
			attribute macAddress = MACAddress { bytes = "AA:BB:CC:DD:EE:02"; };
			attribute status = ConnectionStatus::idle;
			
			port wirelessPort;
			port applicationPort;
		}
		
		connect client1.wirelessPort to ap.wirelessPort;
		connect client2.wirelessPort to ap.wirelessPort;
	}
	
	requirement def <'REQ-001'> WiFiNetworkFunctionRequirement {
		doc /* The WiFi system shall provide wireless network connectivity enabling 
		     multiple client devices to communicate with each other and access 
		     external networks through a central access point using IEEE 802.11 protocols. */
		
		require constraint minimumDataRate {
			doc /* The system shall support minimum data rates of 600 Mbps for WiFi 6. */
		}
		
		require constraint coverageArea {
			doc /* The access point shall provide coverage within a radius of at least 100 meters outdoors. */
		}
		
		require constraint securityStandard {
			doc /* All wireless communications shall be encrypted using WPA3 security protocol. */
		}
	}
	
	requirement def <'REQ-002'> ConnectionPerformanceRequirement {
		doc /* The system shall establish authenticated connections within 3 seconds 
		     from initiation of association request. */
	}
	
	requirement def <'REQ-003'> ConcurrentClientRequirement {
		doc /* The access point shall support at least 50 concurrent client connections 
		     without degradation of service quality. */
	}
	
	requirement def <'REQ-004'> ReliabilityRequirement {
		doc /* The system shall maintain packet delivery ratio above 95% under normal 
		     operating conditions with signal strength above -70 dBm. */
	}
	
	requirement <'SYS-REQ-001'> systemRequirements : WiFiNetworkFunctionRequirement {
		subject wifiNetworkSystem;
		
		assume constraint operatingEnvironment {
			doc /* System operates in 2.4 GHz and 5 GHz ISM bands with minimal interference. */
		}
		
		assume constraint powerAvailability {
			doc /* Access point has continuous power supply available. */
		}
		
		require WiFiNetworkFunctionRequirement;
		require ConnectionPerformanceRequirement;
		require ConcurrentClientRequirement;
		require ReliabilityRequirement;
	}
}
