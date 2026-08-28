package WiFi_Network_System {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def SSID :> String;
    attribute def Password :> String;
    attribute def MACAddress :> String;
    attribute def DataRate :> Real;
    attribute def FrequencyValue :> Real;
    attribute def PowerValue :> Real;

    enum def WiFiStandard {
        WiFi4;
        WiFi5;
        WiFi6;
    }

    enum def SecurityProtocol {
        WPA2;
        WPA3;
    }

    item def DataPacket {
        attribute payload: String;
        attribute sourceMAC: MACAddress;
        attribute destMAC: MACAddress;
    }

    item def EncryptedData {
        attribute payload: String;
    }

    item def RadioSignal {
        attribute ssid: SSID;
        attribute payload: EncryptedData;
        attribute frequency: FrequencyValue;
        attribute strength: PowerValue;
    }

    item def AuthRequest {
        attribute clientMAC: MACAddress;
        attribute ssid: SSID;
        attribute password: Password;
    }

    item def AuthResponse {
        attribute success: Boolean;
        attribute sessionKey: String;
    }

    port def WirelessPort {
        in item rxSignal: RadioSignal;
        out item txSignal: RadioSignal;
        in item authReq: AuthRequest;
        out item authResp: AuthResponse;
    }

    port def EthernetPort {
        in item rxData: DataPacket;
        out item txData: DataPacket;
    }

    action def EncryptData {
        in data: DataPacket;
        out encrypted: EncryptedData;
    }

    action def DecryptData {
        in encrypted: EncryptedData;
        out data: DataPacket;
    }

    action def TransmitSignal {
        in encrypted: EncryptedData;
        out signal: RadioSignal;
    }

    action def ReceiveSignal {
        in signal: RadioSignal;
        out encrypted: EncryptedData;
    }

    part def Antenna {
        attribute gain: PowerValue;
        port rfInterface: WirelessPort;
    }

    part def RadioTransceiver {
        attribute supportedStandard: WiFiStandard;
        attribute maxDataRate: DataRate;
        attribute operatingFrequency: FrequencyValue;
        port rfInterface: WirelessPort;
        port dataInterface: WirelessPort;
    }

    part def SecurityEngine {
        attribute protocol: SecurityProtocol;
        port secInterface: WirelessPort;
    }

    part def EthernetBackbone {
        port ethPort: EthernetPort;
    }

    state def APBehavior {
        state Broadcasting;
        state Authenticating;
        state Connected;

        transition from Broadcasting to Authenticating;
        transition from Authenticating to Connected;
        transition from Connected to Broadcasting;
    }

    state def ClientBehavior {
        state Disconnected;
        state Scanning;
        state Authenticating;
        state Connected;

        transition from Disconnected to Scanning;
        transition from Scanning to Authenticating;
        transition from Authenticating to Connected;
        transition from Connected to Disconnected;
    }

    part def AccessPoint {
        attribute ssid: SSID = "CorporateNetwork";
        attribute maxClients: Integer = 50;
        attribute supportedStandard: WiFiStandard = WiFiStandard::WiFi6;
        attribute securityProtocol: SecurityProtocol = SecurityProtocol::WPA3;

        port wirelessPort: WirelessPort;
        port ethernetPort: EthernetPort;

        part radioTransceiver: RadioTransceiver;
        part txAntenna: Antenna;
        part rxAntenna: Antenna;
        part securityModule: SecurityEngine;

        connect radioTransceiver.rfInterface to txAntenna.rfInterface;
        connect radioTransceiver.rfInterface to rxAntenna.rfInterface;
        connect radioTransceiver.dataInterface to wirelessPort;
        connect securityModule.secInterface to wirelessPort;

        state machine :>> APBehavior;

        action processUplink {
            in signal: RadioSignal;
            out data: DataPacket;

            action receive : ReceiveSignal;
            action decrypt : DecryptData;

            flow signal to receive.signal;
            flow receive.encrypted to decrypt.encrypted;
            flow decrypt.data to data;
        }

        action processDownlink {
            in data: DataPacket;
            out signal: RadioSignal;

            action encrypt : EncryptData;
            action transmit : TransmitSignal;

            flow data to encrypt.data;
            flow encrypt.encrypted to transmit.encrypted;
            flow transmit.signal to signal;
        }
    }

    part def ClientStation {
        attribute macAddress: MACAddress;

        port wirelessPort: WirelessPort;

        part antenna: Antenna;
        part radio: RadioTransceiver;
        part securityEngine: SecurityEngine;

        connect radio.rfInterface to antenna.rfInterface;
        connect radio.dataInterface to wirelessPort;
        connect securityEngine.secInterface to wirelessPort;

        state machine :>> ClientBehavior;

        action sendData {
            in data: DataPacket;
            out signal: RadioSignal;

            action encrypt : EncryptData;
            action transmit : TransmitSignal;

            flow data to encrypt.data;
            flow encrypt.encrypted to transmit.encrypted;
            flow transmit.signal to signal;
        }

        action receiveData {
            in signal: RadioSignal;
            out data: DataPacket;

            action receive : ReceiveSignal;
            action decrypt : DecryptData;

            flow signal to receive.signal;
            flow receive.encrypted to decrypt.encrypted;
            flow decrypt.data to data;
        }
    }

    part def WiFiNetwork {
        part accessPoint: AccessPoint;
        part clients: ClientStation[0..50];
        part backbone: EthernetBackbone;

        connect accessPoint.wirelessPort to clients.wirelessPort;
        connect accessPoint.ethernetPort to backbone.ethPort;
    }

    requirement def SecureConnectivity {
        subject network: WiFiNetwork;
        requirement {
            doc /* The network shall use WPA3 for secure authentication. */
            constraint { network.accessPoint.securityProtocol == SecurityProtocol::WPA3 }
        }
    }

    requirement def HighSpeedData {
        subject network: WiFiNetwork;
        requirement {
            doc /* The network shall support WiFi 6 for high data rates. */
            constraint { network.accessPoint.supportedStandard == WiFiStandard::WiFi6 }
        }
    }

    requirement def ClientCapacity {
        subject network: WiFiNetwork;
        requirement {
            doc /* The AP shall handle up to 50 clients. */
            constraint { network.accessPoint.maxClients == 50 }
        }
    }
}
