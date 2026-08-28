package WiFiNetworkSystem {
    import ScalarValues::*;
    
    // ============================================
    // Value Types
    // ============================================
    
    value type SSID :> String;
    value type MACAddress :> String;
    value type Password :> String;
    value type DataRate :> Real;
    value type Frequency :> Real;
    value type Power :> Real;
    value type ClientCount :> Integer;
    value type PacketSize :> Integer;
    value type ChannelNumber :> Integer;
    value type SignalStrength :> Real;
    value type AntennaGain :> Real;
    value type EthernetSpeed :> Real;
    value type SecurityProtocol :> String;
    value type WiFiStandard :> String;
    value type DeviceType :> String;
    
    // ============================================
    // Item Types
    // ============================================
    
    item def DataPacket {
        attribute size : PacketSize;
        attribute source : MACAddress;
        attribute destination : MACAddress;
        attribute payload : String;
        attribute encrypted : Boolean = false;
    }
    
    item def RadioFrame {
        attribute frequency : Frequency;
        attribute signalStrength : SignalStrength;
        attribute payload : DataPacket[0..*];
    }
    
    item def Credentials {
        attribute ssid : SSID;
        attribute password : Password;
        attribute macAddress : MACAddress;
    }
    
    item def BeaconFrame {
        attribute ssid : SSID;
        attribute security : SecurityProtocol;
        attribute channel : ChannelNumber;
        attribute standard : WiFiStandard;
    }
    
    // ============================================
    // Port Definitions
    // ============================================
    
    port def WirelessPort {
        attribute frequency : Frequency;
        attribute channel : ChannelNumber;
        attribute standard : WiFiStandard;
        in item radioIn : RadioFrame;
        out item radioOut : RadioFrame;
    }
    
    port def EthernetPort {
        attribute speed : EthernetSpeed;
        in item ethIn : DataPacket;
        out item ethOut : DataPacket;
    }
    
    // ============================================
    // Component Part Definitions
    // ============================================
    
    part def Antenna {
        attribute gain : AntennaGain;
        port wirelessIf : WirelessPort;
        
        action transmit {
            in frameIn : RadioFrame;
            out frameOut : RadioFrame;
        }
        
        action receive {
            in signalIn : RadioFrame;
            out frameOut : RadioFrame;
        }
    }
    
    part def RadioTransceiver {
        attribute maxDataRate : DataRate;
        attribute operatingFrequency : Frequency;
        attribute transmitPower : Power;
        attribute supportedStandard : WiFiStandard;
        attribute activeChannel : ChannelNumber;
        attribute channelBusy : Boolean = false;
        
        port txPort : WirelessPort;
        port rxPort : WirelessPort;
        
        action modulate {
            in packet : DataPacket;
            out frame : RadioFrame;
        }
        
        action demodulate {
            in frame : RadioFrame;
            out packet : DataPacket;
        }
        
        action channelAccessControl {
            in packet : DataPacket;
            in busy : Boolean;
            out frame : RadioFrame;
        }
    }
    
    part def SecurityEngine {
        attribute protocol : SecurityProtocol;
        attribute encryptionEnabled : Boolean = true;
        
        action authenticate {
            in credentials : Credentials;
            out authenticated : Boolean;
        }
        
        action encrypt {
            in plain : DataPacket;
            out cipher : DataPacket;
        }
        
        action decrypt {
            in cipher : DataPacket;
            out plain : DataPacket;
        }
        
        state securityState {
            state Unauthenticated;
            state Authenticating;
            state Authenticated;
            
            transition Unauthenticated -> Authenticating on authRequest;
            transition Authenticating -> Authenticated when authSuccess;
            transition Authenticating -> Unauthenticated when authFailure;
        }
    }
    
    part def EthernetBridge {
        attribute bridgeEnabled : Boolean = true;
        
        port upstream : EthernetPort;
        port downstream : EthernetPort;
        
        action bridgeForward {
            in inPacket : DataPacket;
            out outPacket : DataPacket;
        }
    }
    
    // ============================================
    // Access Point Definition
    // ============================================
    
    part def AccessPoint {
        attribute ssid : SSID = "CorporateNetwork";
        attribute securityProtocol : SecurityProtocol = "WPA3";
        attribute wifiStandard : WiFiStandard = "WiFi6";
        attribute maxClients : ClientCount = 50;
        attribute activeClients : ClientCount = 0;
        attribute maxDataRate : DataRate = 9600;
        attribute operatingFrequency : Frequency = 5.0;
        attribute channel : ChannelNumber = 36;
        
        part antennaTx : Antenna {
            attribute gain : AntennaGain = 5;
        }
        part antennaRx : Antenna {
            attribute gain : AntennaGain = 5;
        }
        part radio : RadioTransceiver {
            attribute maxDataRate : DataRate = 9600;
            attribute operatingFrequency : Frequency = 5.0;
            attribute transmitPower : Power = 1000;
            attribute supportedStandard : WiFiStandard = "WiFi6";
            attribute activeChannel : ChannelNumber = 36;
        }
        part security : SecurityEngine {
            attribute protocol : SecurityProtocol = "WPA3";
            attribute encryptionEnabled : Boolean = true;
        }
        part ethernetBridge : EthernetBridge {
            attribute bridgeEnabled : Boolean = true;
        }
        
        port wirelessIf : WirelessPort;
        port wiredIf : EthernetPort;
        
        // Internal connections
        connection txPath connect radio.txPort to antennaTx.wirelessIf;
        connection rxPath connect antennaRx.wirelessIf to radio.rxPort;
        connection apBridgeUp connect ethernetBridge.upstream to wiredIf;
        
        // Actions
        action broadcastBeacon {
            out beacon : BeaconFrame;
        }
        
        action processAssociation {
            in macAddress : MACAddress;
            in credentials : Credentials;
            out accepted : Boolean;
        }
        
        action forwardUpstream {
            in inputPacket : DataPacket;
            out outputPacket : DataPacket;
        }
        
        action forwardDownstream {
            in inputPacket : DataPacket;
            out outputPacket : DataPacket;
        }
        
        action manageClientList {
            in macAddress : MACAddress;
            in addClient : Boolean;
            out updatedCount : ClientCount;
        }
        
        // State Machine
        state apStateMachine {
            state Idle;
            state Broadcasting;
            state HandlingAssociation;
            state ForwardingData;
            
            transition Idle -> Broadcasting on powerOn;
            transition Broadcasting -> HandlingAssociation on associationRequest;
            transition HandlingAssociation -> Broadcasting when associationComplete;
            transition Broadcasting -> ForwardingData on dataPacketReceived;
            transition ForwardingData -> Broadcasting when forwardingComplete;
            transition ForwardingData -> HandlingAssociation on associationRequest;
        }
    }
    
    // ============================================
    // Client Station Definition
    // ============================================
    
    part def ClientStation {
        attribute macAddress : MACAddress;
        attribute deviceType : DeviceType;
        attribute supportedStandard : WiFiStandard;
        attribute connectionStatus : String = "disconnected";
        attribute associatedSSID : SSID;
        
        part antenna : Antenna {
            attribute gain : AntennaGain = 2;
        }
        part radio : RadioTransceiver;
        part security : SecurityEngine;
        
        port wirelessIf : WirelessPort;
        
        // Internal connections
        connection clientTxPath connect radio.txPort to antenna.wirelessIf;
        connection clientRxPath connect antenna.wirelessIf to radio.rxPort;
        
        // Actions
        action scanNetworks {
            out beacons : BeaconFrame[0..*];
        }
        
        action selectNetwork {
            in ssid : SSID;
            in password : Password;
            out credentials : Credentials;
        }
        
        action associate {
            in credentials : Credentials;
            out associated : Boolean;
        }
        
        action sendData {
            in data : String;
            out packet : DataPacket;
        }
        
        action receiveData {
            in packet : DataPacket;
            out data : String;
        }
        
        action disconnect {
            out status : String;
        }
        
        // State Machine
        state clientStateMachine {
            state Disconnected;
            state Scanning;
            state Authenticating;
            state Connected;
            state Transmitting;
            state Receiving;
            
            transition Disconnected -> Scanning on userInitiatesScan;
            transition Scanning -> Authenticating on networkSelected;
            transition Authenticating -> Connected when authenticationSuccess;
            transition Authenticating -> Disconnected when authenticationFailure;
            transition Connected -> Transmitting on sendData;
            transition Transmitting -> Connected when transmissionComplete;
            transition Connected -> Receiving on dataReceived;
            transition Receiving -> Connected when receptionComplete;
            transition Connected -> Disconnected on disconnect;
        }
    }
    
    // ============================================
    // WiFi Network System Composition
    // ============================================
    
    part def WiFiNetwork {
        attribute systemSSID : SSID = "CorporateNetwork";
        attribute systemStandard : WiFiStandard = "WiFi6";
        attribute systemSecurity : SecurityProtocol = "WPA3";
        attribute totalActiveClients : ClientCount = 0;
        
        part accessPoint : AccessPoint;
        part stations : ClientStation[0..50];
        
        connection wirelessLinks connect accessPoint.wirelessIf to stations.wirelessIf;
    }
    
    // ============================================
    // Requirements
    // ============================================
    
    requirement def SecurityRequirement {
        doc 'The system shall use WPA3 security protocol to encrypt all wireless communications between the Access Point and Client Stations.';
    }
    
    requirement def CapacityRequirement {
        doc 'The Access Point shall support simultaneous connections from up to 50 Client Stations.';
        attribute maxClientLimit : ClientCount = 50;
    }
    
    requirement def DataRateRequirement {
        doc 'The system shall support the WiFi 6 standard to provide high-speed wireless data rates up to 9600 Mb/s.';
        attribute minimumDataRate : DataRate = 9600;
    }
    
    requirement def AuthenticationRequirement {
        doc 'All Client Stations shall undergo a secure authentication process using WPA3 before being associated with the Access Point.';
    }
    
    requirement def CoverageRequirement {
        doc 'The Access Point shall be equipped with dedicated transmitting and receiving antennas to provide wide and reliable wireless coverage.';
    }
    
    requirement def EthernetBridgingRequirement {
        doc 'The Access Point shall include an Ethernet port to bridge the wireless network to a wired backbone for internet access.';
    }
    
    requirement def AssociationRequirement {
        doc 'Upon successful authentication, a Client Station shall be associated with the Access Point and its status shall change to connected.';
    }
    
    requirement def PacketizationRequirement {
        doc 'Client data shall be broken into packets, encrypted, addressed, and transmitted as radio signals through the wireless medium.';
    }
    
    requirement def ChannelEfficiencyRequirement {
        doc 'The system shall manage the wireless channel to ensure devices share it efficiently and reliably.';
    }
    
    // ============================================
    // Satisfaction
    // ============================================
    
    satisfy SecurityRequirement by WiFiNetwork;
    satisfy CapacityRequirement by AccessPoint;
    satisfy DataRateRequirement by WiFiNetwork;
    satisfy AuthenticationRequirement by WiFiNetwork;
    satisfy CoverageRequirement by AccessPoint;
    satisfy EthernetBridgingRequirement by AccessPoint;
    satisfy AssociationRequirement by ClientStation;
    satisfy PacketizationRequirement by WiFiNetwork;
    satisfy ChannelEfficiencyRequirement by WiFiNetwork;
    
    // ============================================
    // System Instance
    // ============================================
    
    part WiFiNetworkInstance : WiFiNetwork;
}
