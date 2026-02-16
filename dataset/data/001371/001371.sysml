package BluetoothLowEnergySystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def MACAddress :> String;
    attribute def UUID :> String;
    attribute def RSSI :> Real;
    
    enum def BLERole {
        central;
        peripheral;
    }
    
    enum def ConnectionState {
        disconnected;
        advertising;
        scanning;
        connecting;
        connected;
    }
    
    enum def SecurityLevel {
        none;
        unauthenticated;
        authenticated;
        secureConnections;
    }
    
    item def BLEPacket {
        attribute preamble : Integer;
        attribute accessAddress : Integer;
        attribute header : Integer;
        attribute payload : Real[0..255];
        attribute crc : Integer;
    }
    
    item def AdvertisingData {
        attribute deviceName : String;
        attribute serviceUUIDs : UUID[0..*];
        attribute manufacturerData : Real[0..31];
        attribute txPowerLevel : PowerValue;
    }
    
    item def SensorData {
        attribute timestamp : DurationValue;
        attribute temperature : Real;
        attribute humidity : Real;
        attribute batteryLevel : Real;
    }
    
    port def BLERadioPort {
        attribute transmitPower : PowerValue;
        attribute receiveSignalStrength : RSSI;
        attribute operatingFrequency : FrequencyValue;
    }
    
    port def ApplicationDataPort {
        attribute status : String;
    }
    
    part def BLEPhysicalLayer {
        attribute centerFrequency : FrequencyValue;
        attribute channelSpacing : FrequencyValue;
        attribute channelCount : Integer = 40;
        attribute modulationType : String = "GFSK";
        
        port radioPort : BLERadioPort;
    }
    
    part def BLELinkLayer {
        attribute deviceAddress : MACAddress;
        attribute advertisingInterval : DurationValue;
        attribute scanInterval : DurationValue;
        attribute connectionInterval : DurationValue;
        attribute slaveLatency : Integer;
        attribute supervisionTimeout : DurationValue;
        
        part packetProcessor {
            attribute maxPayloadSize : Integer = 251;
        }
        
        part channelManager {
            attribute advertisingChannels : Integer[3] = (37, 38, 39);
            attribute dataChannels : Integer[37];
        }
    }
    
    part def BLEHostController {
        attribute maxConnections : Integer = 7;
        attribute dataBufferSize : Integer = 4096;
        
        part commandInterface {
            attribute commandQueueDepth : Integer = 16;
        }
        
        part eventHandler {
            attribute eventQueueDepth : Integer = 32;
        }
    }
    
    part def GATTServer {
        attribute serviceCount : Integer;
        attribute characteristicCount : Integer;
        
        part serviceDatabase {
            attribute maxServices : Integer = 10;
            attribute maxCharacteristics : Integer = 50;
        }
        
        part notificationManager {
            attribute maxNotifications : Integer = 20;
        }
    }
    
    part def GAPController {
        attribute role : BLERole;
        attribute connectionState : ConnectionState;
        
        part advertisingManager {
            attribute advertisingData : AdvertisingData;
            attribute scanResponseData : AdvertisingData;
        }
        
        part scanningManager {
            attribute scanWindow : DurationValue;
            attribute scanType : String;
        }
    }
    
    part def SecurityManager {
        attribute securityLevel : SecurityLevel;
        attribute pairingEnabled : Boolean;
        attribute bondingEnabled : Boolean;
        
        part encryptionEngine {
            attribute keySize : Integer = 128;
            attribute algorithm : String = "AES-CCM";
        }
    }
    
    action def AdvertiseDevice {
        in advertisingInterval : DurationValue;
        in advertisingData : AdvertisingData;
        in txPower : PowerValue;
        out advertisingPacket : BLEPacket;
    }
    
    action def ScanForDevices {
        in scanInterval : DurationValue;
        in scanWindow : DurationValue;
        out discoveredDevices : MACAddress[0..*];
        out rssiValues : RSSI[0..*];
    }
    
    action def InitiateConnection {
        in targetAddress : MACAddress;
        in connectionParameters : Real;
        out connectionHandle : Integer;
        out connectionStatus : ConnectionState;
    }
    
    action def TransmitData {
        in data : SensorData;
        in connectionHandle : Integer;
        out packet : BLEPacket;
        out transmitSuccess : Boolean;
    }
    
    action def ReceiveData {
        in packet : BLEPacket;
        in connectionHandle : Integer;
        out data : SensorData;
        out receiveSuccess : Boolean;
    }
    
    action def ManageConnection {
        in handle : Integer;
        in parameters : Real;
        out state : ConnectionState;
    }
    
    action def BLEOperationalCycle {
        in deviceRole : BLERole;
        
        first start;
        then merge checkRole;
        
        then decide;
            if deviceRole == BLERole::peripheral then peripheralMode;
            if deviceRole == BLERole::central then centralMode;
        
        action peripheralMode {
            action advertise : AdvertiseDevice {
                in advertisingInterval : DurationValue;
                in advertisingData : AdvertisingData;
                in txPower : PowerValue;
                out advertisingPacket : BLEPacket;
            }
            then action waitConnection;
            then decide;
                if waitConnection.connectionReceived then establishConnection;
                if waitConnection.timeout then advertise;
            
            action establishConnection : InitiateConnection {
                in targetAddress : MACAddress;
                in connectionParameters : Real;
                out connectionHandle : Integer;
                out connectionStatus : ConnectionState;
            }
            then dataTransferLoop;
        }
        
        action centralMode {
            action scan : ScanForDevices {
                in scanInterval : DurationValue;
                in scanWindow : DurationValue;
                out discoveredDevices : MACAddress[0..*];
                out rssiValues : RSSI[0..*];
            }
            then decide;
                if scan.discoveredDevices[0] != null then connect;
                else scan;
            
            action connect : InitiateConnection {
                in targetAddress : MACAddress;
                in connectionParameters : Real;
                out connectionHandle : Integer;
                out connectionStatus : ConnectionState;
            }
            then dataTransferLoop;
        }
        
        action dataTransferLoop {
            loop {
                action transmit : TransmitData {
                    in data : SensorData;
                    in connectionHandle : Integer;
                    out packet : BLEPacket;
                    out transmitSuccess : Boolean;
                }
                then action receive : ReceiveData {
                    in packet : BLEPacket;
                    in connectionHandle : Integer;
                    out data : SensorData;
                    out receiveSuccess : Boolean;
                }
                then action manage : ManageConnection {
                    in handle : Integer;
                    in parameters : Real;
                    out state : ConnectionState;
                }
                then decide;
                    if manage.state == ConnectionState::connected then transmit;
                    if manage.state == ConnectionState::disconnected then checkRole;
            }
        }
        
        then done;
    }
    
    part def BLEDevice {
        attribute deviceName : String;
        attribute macAddress : MACAddress;
        attribute role : BLERole;
        attribute maxTransmitPower : PowerValue;
        attribute averagePowerConsumption : PowerValue;
        attribute batteryCapacity : EnergyValue;
        
        part physicalLayer : BLEPhysicalLayer {
            attribute :>> centerFrequency = 2400[MHz];
            attribute :>> channelSpacing = 2[MHz];
        }
        
        part linkLayer : BLELinkLayer {
            attribute :>> deviceAddress = macAddress;
            attribute :>> advertisingInterval = 100[ms];
            attribute :>> connectionInterval = 50[ms];
        }
        
        part hostController : BLEHostController {
            attribute :>> maxConnections = 7;
        }
        
        part gattServer : GATTServer {
            attribute :>> serviceCount = 5;
            attribute :>> characteristicCount = 20;
        }
        
        part gapController : GAPController {
            attribute :>> role = BLEDevice::role;
            attribute :>> connectionState = ConnectionState::disconnected;
        }
        
        part securityManager : SecurityManager {
            attribute :>> securityLevel = SecurityLevel::authenticated;
            attribute :>> pairingEnabled = true;
        }
        
        port radioPort : BLERadioPort;
        port appPort : ApplicationDataPort;
        
        connection physicalToLink connect physicalLayer.radioPort to linkLayer;
        connection linkToHost connect linkLayer to hostController;
        connection hostToGatt connect hostController to gattServer;
        connection gattToGap connect gattServer to gapController;
        connection gapToSecurity connect gapController to securityManager;
    }
    
    part peripheralDevice : BLEDevice {
        attribute :>> deviceName = "BLE_Sensor_Node";
        attribute :>> role = BLERole::peripheral;
        attribute :>> maxTransmitPower = 4[dBm];
        attribute :>> averagePowerConsumption = 12[mW];
        attribute :>> batteryCapacity = 1000[mW*h];
        
        assert constraint lowPowerConstraint {
            averagePowerConsumption <= 20[mW]
        }
        
        assert constraint batteryLifeConstraint {
            batteryCapacity / averagePowerConsumption >= 80[h]
        }
    }
    
    part centralDevice : BLEDevice {
        attribute :>> deviceName = "BLE_Gateway";
        attribute :>> role = BLERole::central;
        attribute :>> maxTransmitPower = 10[dBm];
        attribute :>> averagePowerConsumption = 30[mW];
        attribute :>> batteryCapacity = 5000[mW*h];
        
        assert constraint powerConstraint {
            averagePowerConsumption <= 100[mW]
        }
    }
    
    part bleNetwork {
        part peripheral : BLEDevice {
            attribute :>> role = BLERole::peripheral;
            attribute :>> maxTransmitPower = 4[dBm];
        }
        
        part central : BLEDevice {
            attribute :>> role = BLERole::central;
            attribute :>> maxTransmitPower = 10[dBm];
        }
        
        connection wirelessLink connect peripheral.radioPort to central.radioPort;
    }
    
    requirement <'REQ-BLE-001'> primaryFunction {
        doc /* The Bluetooth Low Energy system shall provide wireless communication
             * between devices for data exchange with minimal power consumption,
             * enabling battery-powered sensor networks and IoT applications.
             */
        subject system : bleNetwork;
    }
    
    requirement <'REQ-BLE-002'> lowPowerOperation {
        doc /* The BLE peripheral device shall operate with average power consumption
             * not exceeding 20 mW to enable extended battery life.
             */
        subject device : BLEDevice;
        
        require constraint {
            device.averagePowerConsumption <= 20[mW]
        }
    }
    
    requirement <'REQ-BLE-003'> wirelessRange {
        doc /* The BLE system shall maintain reliable communication at distances
             * up to 10 meters in typical indoor environments.
             */
        subject network : bleNetwork;
    }
    
    requirement <'REQ-BLE-004'> dataTransferRate {
        doc /* The BLE system shall support data transfer rates up to 1 Mbps
             * for efficient sensor data transmission.
             */
        subject phy : BLEPhysicalLayer;
    }
    
    requirement <'REQ-BLE-005'> frequencyBand {
        doc /* The BLE system shall operate in the 2.4 GHz ISM band
             * with 40 channels for reliable wireless communication.
             */
        subject phy : BLEPhysicalLayer;
        
        require constraint {
            phy.centerFrequency == 2400[MHz] and
            phy.channelCount == 40
        }
    }
    
    requirement <'REQ-BLE-006'> multipleConnections {
        doc /* The BLE central device shall support simultaneous connections
             * to multiple peripheral devices for network coordination.
             */
        subject controller : BLEHostController;
        
        require constraint {
            controller.maxConnections >= 7
        }
    }
    
    requirement <'REQ-BLE-007'> securityFeatures {
        doc /* The BLE system shall provide authenticated pairing and
             * encrypted communication for secure data exchange.
             */
        subject security : SecurityManager;
        
        require constraint {
            security.pairingEnabled == true and
            security.securityLevel >= SecurityLevel::authenticated
        }
    }
    
    satisfy primaryFunction by bleNetwork;
    satisfy lowPowerOperation by peripheralDevice;
    satisfy wirelessRange by bleNetwork;
    satisfy dataTransferRate by peripheralDevice.physicalLayer;
    satisfy frequencyBand by peripheralDevice.physicalLayer;
    satisfy multipleConnections by centralDevice.hostController;
    satisfy securityFeatures by peripheralDevice.securityManager;
}
