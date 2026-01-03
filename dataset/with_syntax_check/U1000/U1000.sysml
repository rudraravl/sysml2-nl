package BluetoothCommunicationSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    doc /* 
     * This model describes a Bluetooth wireless communication system that enables 
     * short-range data exchange between electronic devices. The system operates 
     * in the 2.4 GHz ISM band and provides secure, low-power wireless connectivity 
     * for pairing and data transfer between a master device and peripheral devices.
     */

    attribute def MACAddress {
        attribute bytes : String[6];
    }

    attribute def DeviceID :> String;

    enum def ConnectionState {
        enum idle;
        enum discovering;
        enum pairing;
        enum connected;
        enum transmitting;
        enum disconnected;
    }

    enum def DeviceClass {
        enum smartphone;
        enum laptop;
        enum headset;
        enum speaker;
        enum keyboard;
        enum mouse;
    }

    attribute def EncryptionKey {
        attribute keyLength : Integer;
        attribute keyData : String;
    }

    item def DataPacket {
        attribute payload : String;
        attribute packetSize : ISQ::LengthValue;
        attribute timestamp : ISQ::TimeValue;
        attribute sequenceNumber : Integer;
    }

    attribute def FrequencyValue :> ISQ::FrequencyValue;
    attribute def PowerValue :> ISQ::PowerValue;

    port def BluetoothRadioPort {
        attribute macAddress : MACAddress;
        attribute transmitPower : PowerValue;
        attribute receiveSignalStrength : PowerValue;
        out item txData : DataPacket[*];
        in item rxData : DataPacket[*];
    }

    port def HostInterfacePort {
        out item dataToHost : DataPacket[*];
        in item dataFromHost : DataPacket[*];
    }

    part def RFTransceiver {
        attribute operatingFrequency : FrequencyValue;
        attribute channelBandwidth : FrequencyValue;
        attribute transmitPower : PowerValue;
        attribute receiveSensitivity : PowerValue;

        port rfPort : BluetoothRadioPort;

        perform action transmit {
            in packet : DataPacket;
            out rfSignal : PowerValue;
        }

        perform action receive {
            in rfSignal : PowerValue;
            out packet : DataPacket;
        }
    }

    part def BasebandController {
        attribute deviceAddress : MACAddress;
        attribute supportedProfiles : String[*];
        attribute maxConnections : Integer;
        attribute encryptionKey : EncryptionKey;

        port controlPort : BluetoothRadioPort;

        perform action manageLink;
        perform action encryptData {
            in plainData : DataPacket;
            in key : EncryptionKey;
            out encryptedData : DataPacket;
        }
        perform action decryptData {
            in encryptedData : DataPacket;
            in key : EncryptionKey;
            out plainData : DataPacket;
        }
    }

    part def LinkManager {
        attribute currentState : ConnectionState;
        attribute pairedDevices : MACAddress[*];
        attribute activeConnections : Integer;

        perform action establishConnection;
        perform action maintainConnection;
        perform action terminateConnection;
    }

    part def HostController {
        attribute deviceName : DeviceID;
        attribute deviceClass : DeviceClass;

        port hostPort : HostInterfacePort;

        perform action processHostCommands;
        perform action sendHostNotifications;
    }

    action def DiscoverDevices {
        in scanDuration : ISQ::TimeValue;
        in scanPower : PowerValue;
        out discoveredDevices : MACAddress[*];
    }

    action def InitiatePairing {
        in targetDevice : MACAddress;
        in pairingMethod : String;
        out pairingKey : EncryptionKey;
        out pairingSuccess : Boolean;
    }

    action def EstablishConnection {
        in remoteDevice : MACAddress;
        in securityKey : EncryptionKey;
        out connectionHandle : Integer;
        out connectionSuccess : Boolean;
    }

    action def TransmitData {
        in dataPacket : DataPacket;
        in connectionHandle : Integer;
        out transmitSuccess : Boolean;
    }

    action def ReceiveData {
        in connectionHandle : Integer;
        out dataPacket : DataPacket;
    }

    action def DisconnectDevice {
        in connectionHandle : Integer;
        in reason : String;
    }

    action def ManageBluetoothCommunication {
        in operatingFreq : FrequencyValue;
        in txPower : PowerValue;
        out transmittedPackets : DataPacket[*] := ();

        first start;
        then merge idle;

        then action discover : DiscoverDevices {
            in scanDuration = 10.0[SI::s];
            in scanPower = txPower;
            out discoveredDevices;
        }
        then pair;

        action pair : InitiatePairing {
            in targetDevice : MACAddress;
            in pairingMethod = "SecureSimplePairing";
            out pairingKey;
            out pairingSuccess;
        }
        then decide;
            if pair.pairingSuccess then connect;
            if not pair.pairingSuccess then idle;

        action connect : EstablishConnection {
            in remoteDevice : MACAddress;
            in securityKey = pair.pairingKey;
            out connectionHandle;
            out connectionSuccess;
        }
        then decide;
            if connect.connectionSuccess then transmit;
            if not connect.connectionSuccess then idle;

        action transmit : TransmitData {
            in dataPacket : DataPacket;
            in connectionHandle = connect.connectionHandle;
            out transmitSuccess;
        }
        then assign transmittedPackets := transmittedPackets->including(transmit.dataPacket);
        then idle;
    }

    state def BluetoothConnectionLifecycle {
        entry; then powerOff;

        state powerOff;
        transition powerOff_to_idle
            first powerOff
            accept powerOn
            then idle;

        state idle;
        transition idle_to_discovering
            first idle
            accept startDiscovery
            then discovering;

        state discovering {
            do action scanDevices : DiscoverDevices;
        }
        transition discovering_to_pairing
            first discovering
            accept deviceFound
            then pairing;

        transition discovering_to_idle
            first discovering
            accept scanTimeout
            then idle;

        state pairing {
            do action performPairing : InitiatePairing;
        }
        transition pairing_to_connected
            first pairing
            accept pairingSuccess
            then connected;

        transition pairing_to_idle
            first pairing
            accept pairingFailure
            then idle;

        state connected;
        transition connected_to_transmitting
            first connected
            accept dataAvailable
            then transmitting;

        transition connected_to_idle
            first connected
            accept disconnectRequest
            then idle;

        state transmitting {
            do action transferData : TransmitData;
            do action receiveData : ReceiveData;
        }
        transition transmitting_to_connected
            first transmitting
            accept transferComplete
            then connected;

        transition transmitting_to_idle
            first transmitting
            accept connectionLost
            then idle;

        transition idle_to_powerOff
            first idle
            accept powerDown
            then powerOff;
    }

    part bluetoothSystem {
        doc /* 
         * Complete Bluetooth communication system integrating RF transceiver,
         * baseband processing, link management, and host interface components.
         */

        attribute systemFrequency : FrequencyValue = 2.4e9[SI::Hz];
        attribute systemPower : PowerValue = 0.0025[SI::W];

        part rfTransceiver : RFTransceiver {
            attribute :>> operatingFrequency : FrequencyValue = 2.4e9[SI::Hz];
            attribute :>> channelBandwidth : FrequencyValue = 1.0e6[SI::Hz];
            attribute :>> transmitPower : PowerValue = 0.0025[SI::W];
            attribute :>> receiveSensitivity : PowerValue = -0.09[SI::W];
        }

        part basebandController : BasebandController {
            attribute :>> deviceAddress : MACAddress;
            attribute :>> maxConnections = 7;
            attribute :>> encryptionKey : EncryptionKey {
                keyLength = 128;
                keyData = "AES128Key";
            }
        }

        part linkManager : LinkManager {
            attribute :>> currentState = ConnectionState::idle;
            attribute :>> activeConnections = 0;

            exhibit state lifecycle : BluetoothConnectionLifecycle;
        }

        part hostController : HostController {
            attribute :>> deviceName = "BluetoothDevice01";
            attribute :>> deviceClass = DeviceClass::smartphone;
        }

        perform action communicationBehavior[*] ordered 
            references ManageBluetoothCommunication {
            in operatingFreq = systemFrequency;
            in txPower = systemPower;
        }

        connection rfToBaseband connect 
            rfTransceiver.rfPort to basebandController.controlPort;

        connection basebandToHost connect 
            basebandController.controlPort to hostController.hostPort;
    }

    requirement <'BT-REQ-001'> wirelessCommunicationCapability {
        doc /* 
         * The Bluetooth system shall provide wireless short-range communication 
         * capability to exchange data between paired devices using radio frequency 
         * transmission in the 2.4 GHz ISM band.
         */

        subject bluetoothSystem;

        require constraint frequencyRange {
            bluetoothSystem.systemFrequency >= 2.4e9[SI::Hz] and
            bluetoothSystem.systemFrequency <= 2.4835e9[SI::Hz]
        }
    }

    requirement <'BT-REQ-002'> operatingRange {
        doc /* 
         * The Bluetooth system shall maintain reliable connectivity over a minimum 
         * range of 10 meters in open space conditions.
         */

        subject bluetoothSystem;

        require constraint minimumRange {
            doc /* Transmit power and sensitivity support 10m range. */
        }
    }

    requirement <'BT-REQ-003'> dataTransferRate {
        doc /* 
         * The Bluetooth system shall support data transmission rates up to 
         * 3 Mbps for Bluetooth Enhanced Data Rate (EDR).
         */

        subject bluetoothSystem;

        require constraint minimumDataRate {
            bluetoothSystem.rfTransceiver.channelBandwidth >= 1.0e6[SI::Hz]
        }
    }

    requirement <'BT-REQ-004'> secureConnection {
        doc /* 
         * The Bluetooth system shall establish secure pairing using encryption 
         * with a minimum key length of 128 bits before data transmission.
         */

        subject bluetoothSystem;

        require constraint encryptionStrength {
            bluetoothSystem.basebandController.encryptionKey.keyLength >= 128
        }
    }

    requirement <'BT-REQ-005'> multipleConnections {
        doc /* 
         * The Bluetooth system shall support simultaneous connections to up to 
         * 7 active peripheral devices in a piconet configuration.
         */

        subject bluetoothSystem;

        require constraint connectionLimit {
            bluetoothSystem.basebandController.maxConnections == 7
        }
    }

    requirement <'BT-REQ-006'> primarySystemFunction {
        doc /* 
         * The Bluetooth system shall enable wireless personal area networking 
         * by discovering nearby devices, establishing secure pairing, maintaining 
         * active connections, and reliably transmitting data packets between 
         * connected devices.
         */

        subject bluetoothSystem;

        assume constraint operationalEnvironment {
            doc /* 
             * System operates in standard indoor/outdoor environments with 
             * typical electromagnetic interference levels in the 2.4 GHz band.
             */
        }

        require wirelessCommunicationCapability;
        require operatingRange;
        require dataTransferRate;
        require secureConnection;
        require multipleConnections;
    }
}
