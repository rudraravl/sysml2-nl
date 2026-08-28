package BluetoothCommunicationSystem {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;
    import ISQBase::*;

    // ============================================================
    // Value Types with Units
    // ============================================================
    value def Distance :> Real { unit 'm'; }
    value def DataRate :> Real { unit 'Mb/s'; }
    value def FrequencyValue :> Real { unit 'GHz'; }
    value def PowerValue :> Real { unit 'dBm'; }
    value def RSSI :> Real { unit 'dBm'; }
    value def PacketID :> Integer;
    value def SequenceNumber :> Integer;

    // ============================================================
    // Enumerations
    // ============================================================
    enum def DeviceType {
        smartphone;
        laptop;
        headset;
        speaker;
        wearable;
        computer;
    }

    enum def HostCommand {
        startScan;
        stopScan;
        pair;
        connect;
        disconnect;
        sendData;
        receiveData;
        setDeviceName;
    }

    enum def Notification {
        deviceFound;
        scanComplete;
        pairingComplete;
        pairingFailed;
        connectionEstablished;
        connectionLost;
        dataReceived;
        dataSent;
        encryptionEnabled;
    }

    enum def LinkState {
        idle;
        discovering;
        pairing;
        connected;
        transmitting;
    }

    // ============================================================
    // Item Types
    // ============================================================
    item def MACAddress :> String;

    item def DeviceName :> String;

    item def DataPacket {
        attribute id : PacketID;
        attribute sequenceNumber : SequenceNumber;
        attribute payload : String;
        attribute encrypted : Boolean = false;
        attribute checksum : Integer;
    }

    item def RFSignal {
        attribute frequency : FrequencyValue = 2.4;
        attribute txPower : PowerValue;
        attribute rssi : RSSI;
        attribute carriedPacket : DataPacket;
    }

    item def PairedDevice {
        attribute macAddress : MACAddress;
        attribute name : DeviceName;
        attribute type : DeviceType;
        attribute trusted : Boolean = true;
        attribute linkKey : String;
    }

    // ============================================================
    // Requirements
    // ============================================================
    requirement def CommunicationRange {
        doc "The Bluetooth system shall support wireless communication over a range of at least 10 meters.";
        attribute minRange : Distance = 10 ['m'];
        subject range : Distance;
        require range >= minRange;
    }

    requirement def MaxDataRate {
        doc "The Bluetooth system shall support data rates up to 3 Mbps.";
        attribute maxRate : DataRate = 3 ['Mb/s'];
        subject dataRate : DataRate;
        require dataRate <= maxRate;
    }

    requirement def LinkSecurity {
        doc "All data exchanged over the wireless link shall be encrypted.";
        subject encryptionEnabled : Boolean;
        require encryptionEnabled == true;
    }

    requirement def ConnectionCapacity {
        doc "The baseband controller shall support simultaneous connections with up to seven devices.";
        attribute maxConnections : Integer = 7;
        subject activeConnections : Integer;
        require activeConnections <= maxConnections;
    }

    requirement def FrequencyBand {
        doc "The RF transceiver shall operate in the 2.4 GHz ISM band.";
        attribute nominalFrequency : FrequencyValue = 2.4;
        subject operatingFrequency : FrequencyValue;
        require operatingFrequency == nominalFrequency;
    }

    requirement def BluetoothSystemRequirements {
        doc "Aggregated requirements for the Bluetooth communication system.";
        satisfy CommunicationRange;
        satisfy MaxDataRate;
        satisfy LinkSecurity;
        satisfy ConnectionCapacity;
        satisfy FrequencyBand;
    }

    // ============================================================
    // RF Transceiver
    // ============================================================
    part def RFTransceiver {
        doc "Physical radio responsible for transmitting and receiving RF signals in the 2.4 GHz band.";
        attribute frequencyBand : FrequencyValue = 2.4;
        attribute maxTxPower : PowerValue = 10 ['dBm'];
        attribute supportedRate : DataRate = 3 ['Mb/s'];
        attribute operatingRange : Distance = 10 ['m'];
        attribute channel : Integer;

        in port digitalIn : DataPacket;
        out port digitalOut : DataPacket;
        out port rfOut : RFSignal;
        in port rfIn : RFSignal;

        action transmit {
            in packet : DataPacket;
            then produce rfOut;
        }

        action receive {
            in signal : RFSignal;
            then produce digitalOut;
        }

        action modulate {
            in data : DataPacket;
            return signal : RFSignal;
        }

        action demodulate {
            in signal : RFSignal;
            return data : DataPacket;
        }
    }

    // ============================================================
    // Baseband Controller
    // ============================================================
    part def BasebandController {
        doc "Low-level controller managing encryption, MAC addressing, and connection scheduling.";
        attribute macAddress : MACAddress;
        attribute maxConnections : Integer = 7;
        attribute activeConnections : Integer = 0;
        attribute encryptionEnabled : Boolean = true;
        attribute encryptionKey : String;
        attribute supportedRate : DataRate = 3 ['Mb/s'];

        in port controlIn : HostCommand;
        out port statusOut : Notification;
        in port rfDataIn : DataPacket;
        out port rfDataOut : DataPacket;
        in port appDataIn : DataPacket;
        out port appDataOut : DataPacket;

        action encrypt {
            in packet : DataPacket;
            return encryptedPacket : DataPacket;
        }

        action decrypt {
            in packet : DataPacket;
            return decryptedPacket : DataPacket;
        }

        action manageConnections {
            doc "Schedules traffic across up to seven simultaneous active connections.";
        }

        action generateMAC {
            return address : MACAddress;
        }
    }

    // ============================================================
    // Link Manager
    // ============================================================
    part def LinkManager {
        doc "Manages link state, pairing, and connection lifecycle.";
        attribute pairedDevices : PairedDevice[0..*];
        attribute currentState : LinkState = LinkState::idle;
        attribute targetDevice : PairedDevice;
        attribute trigger : HostCommand;
        attribute linkEstablished : Boolean = false;

        in port commandIn : HostCommand;
        out port notificationOut : Notification;
        out port controlOut : HostCommand;
        in port statusIn : Notification;

        action startDiscovery {
            then send notificationOut;
        }

        action performPairing {
            in device : PairedDevice;
            then send notificationOut;
        }

        action establishConnection {
            then send notificationOut;
        }

        action terminateConnection {
            then send notificationOut;
        }

        state machine LinkControl {
            state idle;
            state discovering;
            state pairing;
            state connected;
            state transmitting;

            transition init first idle;

            transition idle_to_discovering
                from idle to discovering
                if trigger == HostCommand::startScan;

            transition discovering_to_idle
                from discovering to idle
                if trigger == HostCommand::stopScan;

            transition discovering_to_pairing
                from discovering to pairing
                if trigger == HostCommand::pair;

            transition pairing_to_connected
                from pairing to connected
                if linkEstablished == true;

            transition pairing_to_idle
                from pairing to idle
                if linkEstablished == false;

            transition connected_to_transmitting
                from connected to transmitting
                if trigger == HostCommand::sendData;

            transition transmitting_to_connected
                from transmitting to connected
                if trigger != HostCommand::sendData;

            transition connected_to_idle
                from connected to idle
                if trigger == HostCommand::disconnect;

            transition transmitting_to_idle
                from transmitting to idle
                if trigger == HostCommand::disconnect;
        }
    }

    // ============================================================
    // Host Controller
    // ============================================================
    part def HostController {
        doc "Interface between the Bluetooth module and the host device operating system.";
        attribute deviceName : DeviceName = "BT_Device";
        attribute deviceType : DeviceType = DeviceType::smartphone;
        attribute publicIdentity : String;

        in port hostCommandIn : HostCommand;
        out port hostNotificationOut : Notification;
        out port linkCommandOut : HostCommand;
        in port linkNotificationIn : Notification;
        out port appDataOut : DataPacket;
        in port appDataIn : DataPacket;

        action processHostCommand {
            in cmd : HostCommand;
            then send linkCommandOut;
        }

        action sendNotification {
            in notif : Notification;
            then send hostNotificationOut;
        }

        action defineIdentity {
            in name : DeviceName;
            in type : DeviceType;
        }
    }

    // ============================================================
    // Top-level Bluetooth Module
    // ============================================================
    part def BluetoothModule {
        doc "Complete Bluetooth communication system module for embedded use in host devices.";
        attribute deviceName : DeviceName;
        attribute deviceType : DeviceType;
        attribute dataRate : DataRate = 3 ['Mb/s'];
        attribute operatingRange : Distance = 10 ['m'];
        attribute encryptionEnabled : Boolean = true;
        attribute activeConnections : Integer = 0;
        attribute operatingFrequency : FrequencyValue = 2.4;

        satisfy BluetoothSystemRequirements;

        part rfTransceiver : RFTransceiver {
            attribute frequencyBand = 2.4;
            attribute maxTxPower = 10 ['dBm'];
            attribute supportedRate = 3 ['Mb/s'];
            attribute operatingRange = 10 ['m'];
        }

        part basebandController : BasebandController {
            attribute maxConnections = 7;
            attribute encryptionEnabled = true;
        }

        part linkManager : LinkManager;

        part hostController : HostController {
            attribute deviceName = "BT_Module";
            attribute deviceType = DeviceType::smartphone;
        }

        // External interface ports
        out port antennaTx : RFSignal;
        in port antennaRx : RFSignal;
        in port hostCmdPort : HostCommand;
        out port hostNotifPort : Notification;
        in port hostDataIn : DataPacket;
        out port hostDataOut : DataPacket;

        // RF front-end connections
        connection rfTxToAntenna connect rfTransceiver.rfOut to antennaTx;
        connection antennaToRfRx connect antennaRx to rfTransceiver.rfIn;

        // Baseband <-> RF Transceiver data path
        connection basebandToRfTx connect basebandController.rfDataOut to rfTransceiver.digitalIn;
        connection rfToBaseband connect rfTransceiver.digitalOut to basebandController.rfDataIn;

        // Host interface connections
        connection hostCmdToHostCtrl connect hostCmdPort to hostController.hostCommandIn;
        connection hostCtrlNotifToHost connect hostController.hostNotificationOut to hostNotifPort;

        // Host Controller <-> Link Manager control path
        connection hostCtrlToLinkMgr connect hostController.linkCommandOut to linkManager.commandIn;
        connection linkMgrToHostCtrl connect linkManager.notificationOut to hostController.linkNotificationIn;

        // Link Manager <-> Baseband Controller control path
        connection linkMgrToBaseband connect linkManager.controlOut to basebandController.controlIn;
        connection basebandToLinkMgr connect basebandController.statusOut to linkManager.statusIn;

        // Host Controller <-> Baseband Controller application data path
        connection hostCtrlToBasebandData connect hostController.appDataOut to basebandController.appDataIn;
        connection basebandToHostCtrlData connect basebandController.appDataOut to hostController.appDataIn;

        // Host data ports to host controller
        connection hostDataInToCtrl connect hostDataIn to hostController.appDataOut;
        connection ctrlDataToHostOut connect hostController.appDataIn to hostDataOut;
    }
}
