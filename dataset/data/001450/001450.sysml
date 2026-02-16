package 'Home Network System' {
    private import ScalarValues::*;
    private import ISQ::*;
    
    attribute def MACAddress :> String;
    attribute def IPAddress :> String;
    attribute def SSID :> String;
    attribute def EncryptionKey :> String;
    
    attribute def DataRate :> Real;
    
    attribute def SignalStrength :> Real;
    
    attribute def SignalStrengthUnit;
    attribute dBm : SignalStrengthUnit;
    
    item def DataPacket {
        attribute sourceIP : IPAddress;
        attribute destinationIP : IPAddress;
        attribute sourceMAC : MACAddress;
        attribute destinationMAC : MACAddress;
        attribute payloadSize : ISQ::MassValue;
        attribute timestamp : ISQ::TimeValue;
    }
    
    port def EthernetPort {
        attribute macAddress : MACAddress;
        attribute linkSpeed : DataRate;
        in item rxData : DataPacket[*];
        out item txData : DataPacket[*];
    }
    
    port def WiFiPort {
        attribute macAddress : MACAddress;
        attribute channel : Integer;
        attribute signalStrength : SignalStrength;
        in item rxData : DataPacket[*];
        out item txData : DataPacket[*];
    }
    
    port def WANPort :> EthernetPort {
        attribute publicIP : IPAddress;
    }
    
    part def InternetServiceProvider {
        port customerPort : WANPort;
        
        action def ProvideInternetAccess {
            in request : DataPacket;
            out response : DataPacket;
        }
    }
    
    part def Router {
        attribute deviceName : String;
        attribute firmwareVersion : String;
        
        port wanPort : WANPort;
        port lanPort1 : EthernetPort;
        port lanPort2 : EthernetPort;
        port lanPort3 : EthernetPort;
        port lanPort4 : EthernetPort;
        port wifiPort : WiFiPort;
        
        part firewall {
            action def FilterTraffic {
                in incomingPacket : DataPacket;
                out allowed : Boolean;
            }
        }
        
        part dhcpServer {
            action def AssignIPAddress {
                in deviceMAC : MACAddress;
                out assignedIP : IPAddress;
            }
        }
        
        perform action routePackets : RouteNetworkTraffic;
    }
    
    part def NetworkSwitch {
        attribute deviceName : String;
        attribute portCount : Integer;
        
        port uplinkPort : EthernetPort;
        port port1 : EthernetPort;
        port port2 : EthernetPort;
        port port3 : EthernetPort;
        port port4 : EthernetPort;
        port port5 : EthernetPort;
        port port6 : EthernetPort;
        port port7 : EthernetPort;
        port port8 : EthernetPort;
        
        perform action switchTraffic : SwitchPackets;
    }
    
    part def WirelessAccessPoint {
        attribute deviceName : String;
        attribute ssid : SSID;
        attribute encryptionKey : EncryptionKey;
        attribute maxClients : Integer;
        
        port uplinkPort : EthernetPort;
        port wirelessPort : WiFiPort;
        
        perform action broadcastWiFi : ManageWirelessConnections;
    }
    
    part def NetworkDevice {
        attribute deviceName : String;
        attribute ipAddress : IPAddress;
        attribute macAddress : MACAddress;
        
        port networkPort : EthernetPort;
        
        perform action communicateOverNetwork : TransmitReceiveData;
    }
    
    part def WirelessDevice {
        attribute deviceName : String;
        attribute ipAddress : IPAddress;
        attribute macAddress : MACAddress;
        
        port wifiPort : WiFiPort;
        
        perform action communicateOverWiFi : TransmitReceiveData;
    }
    
    part def Desktop :> NetworkDevice {
        attribute operatingSystem : String;
    }
    
    part def SmartTV :> NetworkDevice {
        attribute screenSize : ISQ::LengthValue;
        
        perform action streamMedia : StreamVideo;
    }
    
    part def Laptop :> WirelessDevice {
        attribute operatingSystem : String;
        attribute batteryLevel : Real;
    }
    
    part def Smartphone :> WirelessDevice {
        attribute mobileOS : String;
        
        perform action syncData : SynchronizeCloudData;
    }
    
    part def SmartThermostat :> WirelessDevice {
        attribute currentTemperature : ISQ::ThermodynamicTemperatureValue;
        attribute targetTemperature : ISQ::ThermodynamicTemperatureValue;
        
        perform action reportStatus : SendSensorData;
    }
    
    part def SecurityCamera :> NetworkDevice {
        attribute resolution : String;
        attribute recordingEnabled : Boolean;
        
        perform action streamVideo : TransmitVideoFeed;
    }
    
    action def RouteNetworkTraffic {
        in incomingPacket : DataPacket;
        out outgoingPacket : DataPacket;
        
        first start;
        
        then action inspectPacket {
            in packet : DataPacket;
            out destination : IPAddress;
        }
        
        then action checkFirewall {
            in packet : DataPacket;
            out permitted : Boolean;
        }
        
        then decide;
            if checkFirewall.permitted == true then forwardPacket;
            if checkFirewall.permitted == false then dropPacket;
        
        action forwardPacket {
            in packet : DataPacket;
            out routed : DataPacket;
        }
        
        action dropPacket;
        
        then done;
    }
    
    action def SwitchPackets {
        in receivedPacket : DataPacket;
        out forwardedPacket : DataPacket;
        
        action learnMACAddress {
            in packet : DataPacket;
            out macTable : MACAddress[*];
        }
        
        action lookupDestination {
            in destinationMAC : MACAddress;
            out outputPort : Integer;
        }
        
        action forwardToPort {
            in packet : DataPacket;
            in portNumber : Integer;
            out switched : DataPacket;
        }
    }
    
    action def ManageWirelessConnections {
        in ssid : SSID;
        in encryptionKey : EncryptionKey;
        out activeConnections : Integer;
        
        action authenticateClient {
            in clientMAC : MACAddress;
            in providedKey : EncryptionKey;
            out authenticated : Boolean;
        }
        
        action bridgeToWired {
            in wirelessPacket : DataPacket;
            out wiredPacket : DataPacket;
        }
    }
    
    action def TransmitReceiveData {
        in outgoingData : DataPacket[*];
        out incomingData : DataPacket[*];
        
        action sendPacket {
            in data : DataPacket;
            out transmitted : DataPacket;
        }
        
        action receivePacket {
            in received : DataPacket;
            out processed : DataPacket;
        }
    }
    
    action def StreamVideo :> TransmitReceiveData {
        in videoRequest : DataPacket;
        out videoStream : DataPacket[*];
        
        action bufferContent {
            in streamData : DataPacket[*];
            out buffered : DataPacket[*];
        }
    }
    
    action def SynchronizeCloudData :> TransmitReceiveData {
        in localData : DataPacket[*];
        out syncedData : DataPacket[*];
    }
    
    action def SendSensorData :> TransmitReceiveData {
        in sensorReading : Real;
        out dataPacket : DataPacket;
    }
    
    action def TransmitVideoFeed :> TransmitReceiveData {
        in videoFrame : DataPacket[*];
        out streamPacket : DataPacket[*];
    }
    
    state def NetworkOperationalStates {
        entry; then Initializing;
        
        state Initializing;
        
        state Operational;
        
        state Degraded;
        
        state Offline;
        
        transition first initToOperational
            first Initializing
            then Operational;
            
        transition operationalToDegraded
            first Operational
            then Degraded;
            
        transition degradedToOperational
            first Degraded
            then Operational;
            
        transition anyToOffline
            first Operational
            then Offline;
            
        transition offlineToInit
            first Offline
            then Initializing;
    }
    
    requirement def ConnectivityRequirement {
        doc /* The home network shall provide reliable connectivity to all authorized devices. */
    }
    
    requirement def PerformanceRequirement {
        doc /* The home network shall support minimum data throughput for concurrent device usage. */
        
        require constraint minimumThroughput {
            doc /* Wired connections shall support at least 1 Gbps data rate. */
        }
        
        require constraint wirelessThroughput {
            doc /* Wireless connections shall support at least 300 Mbps data rate. */
        }
    }
    
    requirement def SecurityRequirement {
        doc /* The home network shall protect against unauthorized access and malicious traffic. */
        
        require constraint encryptedWiFi {
            doc /* All wireless traffic shall be encrypted using WPA3 or equivalent. */
        }
        
        require constraint firewallProtection {
            doc /* All incoming traffic from WAN shall be filtered by firewall rules. */
        }
    }
    
    requirement def ReliabilityRequirement {
        doc /* The home network shall maintain high availability and automatic recovery. */
        
        require constraint uptime {
            doc /* Network uptime shall be at least 99.5% over any 30-day period. */
        }
    }
    
    connection def WiredConnection {
        end port sourcePort : EthernetPort;
        end port targetPort : EthernetPort;
    }
    
    connection def WirelessConnection {
        end port apPort : WiFiPort;
        end port devicePort : WiFiPort;
    }
    
    connection def WANConnection {
        end port routerWAN : WANPort;
        end port ispPort : WANPort;
    }
    
    action def ProvideHomeNetworkConnectivity {
        doc /* 
            Primary function: Enable seamless communication between all connected devices
            and provide secure internet access through centralized routing, switching,
            and wireless access point management.
        */
        
        first start;
        
        then action initializeInfrastructure {
            action powerOnRouter {
                out routerReady : Boolean;
            }
            
            action establishWANConnection {
                out internetConnected : Boolean;
            }
            
            action activateWiFi {
                out wifiActive : Boolean;
            }
            
            action startDHCP {
                out dhcpRunning : Boolean;
            }
        }
        
        then merge operationalLoop;
        
        then action manageNetworkOperations {
            action detectNewDevice {
                out newDeviceMAC : MACAddress[0..1];
            }
            
            action assignIPToDevice {
                in deviceMAC : MACAddress;
                out assignedIP : IPAddress;
            }
            
            action routeTrafficBetweenDevices {
                in traffic : DataPacket[*];
                out routed : DataPacket[*];
            }
            
            action monitorNetworkHealth {
                out connectedDevices : Integer;
                out totalThroughput : DataRate;
                out wanStatus : Boolean;
            }
        }
        
        then decide;
            if manageNetworkOperations.monitorNetworkHealth.connectedDevices > 0 
                then operationalLoop;
            if shutdownRequested then shutdownNetwork;
        
        action shutdownNetwork {
            action disconnectAllDevices;
            action disableWiFi;
            action closeWANConnection;
            action powerOffRouter;
        }
        
        then done;
        
        attribute shutdownRequested : Boolean;
    }
    
    part homeNetworkSystem : HomeNetworkSystem {
        doc /* 
            A residential home network system that provides internet connectivity
            and local network services to multiple wired and wireless devices.
            The system enables device-to-device communication, internet access,
            media streaming, smart home automation, and security monitoring.
        */
        
        part isp : InternetServiceProvider;
        
        part mainRouter : Router {
            attribute :>> deviceName = "Main Router";
            attribute :>> firmwareVersion = "2.4.1";
        }
        
        part livingRoomSwitch : NetworkSwitch {
            attribute :>> deviceName = "Living Room Switch";
            attribute :>> portCount = 8;
        }
        
        part bedroomAP : WirelessAccessPoint {
            attribute :>> deviceName = "Bedroom AP";
            attribute :>> ssid = "HomeNetwork_Bedroom";
            attribute :>> maxClients = 20;
        }
        
        part officeDesktop : Desktop {
            attribute :>> deviceName = "Office Desktop";
            attribute :>> ipAddress = "192.168.1.10";
            attribute :>> operatingSystem = "Linux";
        }
        
        part livingRoomTV : SmartTV {
            attribute :>> deviceName = "Living Room TV";
            attribute :>> ipAddress = "192.168.1.20";
        }
        
        part securityCam1 : SecurityCamera {
            attribute :>> deviceName = "Front Door Camera";
            attribute :>> ipAddress = "192.168.1.30";
            attribute :>> resolution = "1080p";
            attribute :>> recordingEnabled = true;
        }
        
        part securityCam2 : SecurityCamera {
            attribute :>> deviceName = "Backyard Camera";
            attribute :>> ipAddress = "192.168.1.31";
            attribute :>> resolution = "1080p";
            attribute :>> recordingEnabled = true;
        }
        
        part workLaptop : Laptop {
            attribute :>> deviceName = "Work Laptop";
            attribute :>> ipAddress = "192.168.1.40";
            attribute :>> operatingSystem = "Windows";
        }
        
        part personalLaptop : Laptop {
            attribute :>> deviceName = "Personal Laptop";
            attribute :>> ipAddress = "192.168.1.41";
            attribute :>> operatingSystem = "macOS";
        }
        
        part phone1 : Smartphone {
            attribute :>> deviceName = "Primary Phone";
            attribute :>> ipAddress = "192.168.1.50";
            attribute :>> mobileOS = "Android";
        }
        
        part phone2 : Smartphone {
            attribute :>> deviceName = "Secondary Phone";
            attribute :>> ipAddress = "192.168.1.51";
            attribute :>> mobileOS = "iOS";
        }
        
        part thermostat : SmartThermostat {
            attribute :>> deviceName = "Smart Thermostat";
            attribute :>> ipAddress = "192.168.1.60";
        }
        
        connection wanLink : WANConnection connect 
            mainRouter.wanPort to isp.customerPort;
        
        connection routerToSwitch : WiredConnection connect 
            mainRouter.lanPort1 to livingRoomSwitch.uplinkPort;
        
        connection routerToAP : WiredConnection connect 
            mainRouter.lanPort2 to bedroomAP.uplinkPort;
        
        connection switchToDesktop : WiredConnection connect 
            livingRoomSwitch.port1 to officeDesktop.networkPort;
        
        connection switchToTV : WiredConnection connect 
            livingRoomSwitch.port2 to livingRoomTV.networkPort;
        
        connection switchToCam1 : WiredConnection connect 
            livingRoomSwitch.port3 to securityCam1.networkPort;
        
        connection switchToCam2 : WiredConnection connect 
            livingRoomSwitch.port4 to securityCam2.networkPort;
        
        connection wifiToWorkLaptop : WirelessConnection connect 
            mainRouter.wifiPort to workLaptop.wifiPort;
        
        connection wifiToPersonalLaptop : WirelessConnection connect 
            bedroomAP.wirelessPort to personalLaptop.wifiPort;
        
        connection wifiToPhone1 : WirelessConnection connect 
            mainRouter.wifiPort to phone1.wifiPort;
        
        connection wifiToPhone2 : WirelessConnection connect 
            bedroomAP.wirelessPort to phone2.wifiPort;
        
        connection wifiToThermostat : WirelessConnection connect 
            mainRouter.wifiPort to thermostat.wifiPort;
        
        perform action provideConnectivity : ProvideHomeNetworkConnectivity;
    }
    
    part def HomeNetworkSystem {
        satisfy connectivityReq : ConnectivityRequirement;
        satisfy performanceReq : PerformanceRequirement;
        satisfy securityReq : SecurityRequirement;
        satisfy reliabilityReq : ReliabilityRequirement;
    }
}
