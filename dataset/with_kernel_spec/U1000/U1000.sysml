package BluetoothCommunicationSystem {
    private import ScalarValues::*;
    
    // Event signal definitions for state machine transitions
    attribute def StartScanning;
    attribute def DeviceFound;
    attribute def PairingSuccessful;
    attribute def PairingFailed;
    attribute def DataReady;
    attribute def DataComplete;
    attribute def DisconnectReq;
    
    // Data items
    item def DataPacket {
        attribute sequenceNumber : Integer;
        attribute payloadSize : Integer;
    }
    item def RFSignal;
    
    // Attribute definitions
    attribute def Message;
    attribute def Command :> Message;
    attribute def Notification :> Message;
    attribute def MACAddress;
    attribute def DeviceName;
    attribute def DeviceType;
    
    attribute def PairedDevice {
        attribute mac : MACAddress;
        attribute name : DeviceName;
    }
    
    // Port definitions
    port def HostInterface {
        in item hostCommand : Message;
        out item hostNotification : Message;
    }
    port def RFInterface {
        out item txSignal : RFSignal;
        in item rxSignal : RFSignal;
    }
    port def BasebandDataInterface {
        out item txData : DataPacket;
        in item rxData : DataPacket;
    }
    port def LinkControlInterface {
        in item controlCommand : Message;
        out item statusUpdate : Message;
    }
    
    // RF Transceiver - physical radio for 2.4 GHz band
    part def RFTransceiver {
        attribute frequencyGHz : Real = 2.4;
        attribute maxRangeMeters : Real = 10;
        attribute maxDataRateMbps : Real = 3.0;
        port rfPort : RFInterface;
        port basebandPort : BasebandDataInterface;
    }
    
    // Baseband Controller - low-level communication brain
    part def BasebandController {
        attribute macAddress : MACAddress;
        attribute maxConnections : Integer = 7;
        port basebandPort : BasebandDataInterface;
        port linkPort : LinkControlInterface;
    }
    
    // Link Manager - manages connection status and paired devices
    part def LinkManager {
        attribute pairedDevices : PairedDevice[0..7];
        port hostPort : LinkControlInterface;
        port basebandPort : LinkControlInterface;
        exhibit state linkStates : BluetoothState;
    }
    
    // Host Controller - interface to host device OS
    part def HostController {
        attribute deviceName : DeviceName;
        attribute deviceType : DeviceType;
        port hostPort : HostInterface;
        port linkPort : LinkControlInterface;
    }
    
    // Bluetooth Module - complete system assembly
    part def BluetoothModule {
        attribute maxRangeMeters : Real = 10;
        attribute maxDataRateMbps : Real = 3.0;
        attribute maxConnections : Integer = 7;
        
        part rfTransceiver : RFTransceiver;
        part basebandController : BasebandController;
        part linkManager : LinkManager;
        part hostController : HostController;
        
        port hostPort : HostInterface;
        port rfPort : RFInterface;
        
        connect hostController.hostPort to hostPort;
        connect rfTransceiver.rfPort to rfPort;
        connect basebandController.basebandPort to rfTransceiver.basebandPort;
        connect linkManager.basebandPort to basebandController.linkPort;
        connect hostController.linkPort to linkManager.hostPort;
        
        exhibit state moduleStates : BluetoothState;
    }
    
    // State machine definition - lifecycle of a Bluetooth connection
    state def BluetoothState {
        entry; then idle;
        state idle;
        accept StartScanning then discovering;
        state discovering;
        accept DeviceFound then pairing;
        state pairing;
        accept PairingSuccessful then connected;
        accept PairingFailed then idle;
        state connected;
        accept DataReady then transmitting;
        state transmitting;
        accept DataComplete then connected;
        accept DisconnectReq then idle;
    }
    
    // Requirements
    requirement def RangeRequirement {
        doc /** The system shall maintain a reliable connection over at least 10 meters. **/;
        attribute requiredRangeMeters : Real = 10;
    }
    
    requirement def DataRateRequirement {
        doc /** The system shall support data rates up to 3 Mbps. **/;
        attribute requiredDataRateMbps : Real = 3.0;
    }
    
    requirement def ConnectionLimitRequirement {
        doc /** The baseband controller shall manage up to 7 simultaneous connections. **/;
        attribute requiredConnections : Integer = 7;
    }
    
    requirement def SecurityRequirement {
        doc /** All data transmissions shall be encrypted using AES-CCM. **/;
    }
}
