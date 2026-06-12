package BluetoothHighLevelSystem {
    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def Time_s :> ISQ::time {
        :>> unit = SI::second;
    }

    attribute def Frequency_MHz {
        attribute value : Real;
        attribute unit : String = "MHz";
    }

    attribute def Power_dBm {
        attribute value : Real;
        attribute unit : String = "dBm";
    }

    attribute def DataRate_Mbps {
        attribute value : Real;
        attribute unit : String = "Mbit/s";
    }

    attribute def Distance_m :> ISQ::length {
        :>> unit = SI::metre;
    }

    item def ApplicationPayload {
        attribute payloadBytes : Integer;
        attribute checksum : Integer;
    }

    item def AdvertisementPacket {
        attribute deviceName : String;
        attribute serviceUuid : String;
        attribute connectable : Boolean;
    }

    item def PairingRequest {
        attribute initiatorAddress : String;
        attribute requestedSecurityLevel : Integer;
    }

    item def PairingKey {
        attribute keyId : String;
        attribute encrypted : Boolean;
    }

    item def BluetoothDataFrame {
        attribute sequenceNumber : Integer;
        attribute encrypted : Boolean;
        item payload : ApplicationPayload;
    }

    item def Acknowledgement {
        attribute acceptedSequenceNumber : Integer;
        attribute linkQualityPercent : Real;
    }

    port def BluetoothRadioPort {
        out item advertisement : AdvertisementPacket;
        in item pairingRequest : PairingRequest;
        out item pairingKey : PairingKey;
        out item txFrame : BluetoothDataFrame;
        in item rxFrame : BluetoothDataFrame;
        in item ack : Acknowledgement;
    }

    port def ApplicationServicePort {
        in item outboundPayload : ApplicationPayload;
        out item inboundPayload : ApplicationPayload;
    }

    part def Antenna {
        attribute tunedFrequency : Frequency_MHz = (value = 2402.0);
        attribute range : Distance_m = 30.0;
        port radioFeed : BluetoothRadioPort;
    }

    part def BluetoothController {
        attribute lowChannelFrequency : Frequency_MHz = (value = 2402.0);
        attribute highChannelFrequency : Frequency_MHz = (value = 2480.0);
        attribute nominalDataRate : DataRate_Mbps = (value = 2.0);
        attribute transmitPower : Power_dBm = (value = 4.0);
        attribute connected : Boolean = false;
        port radio : BluetoothRadioPort;
        port host : ApplicationServicePort;
    }

    part def PairingManager {
        attribute meanPairingTime : Time_s = 3.0;
        attribute maximumPairingTime : Time_s = 10.0;
        attribute authenticated : Boolean = false;
        port securityExchange : BluetoothRadioPort;
    }

    part def ApplicationProcessor {
        attribute samplePeriod : Time_s = 1.0;
        attribute active : Boolean = true;
        port service : ApplicationServicePort;
    }

    part def PowerManager {
        attribute advertisingInterval : Time_s = 0.1;
        attribute idleTimeout : Time_s = 30.0;
        attribute sleepCurrentMilliampere : Real = 0.8;
        attribute activeCurrentMilliampere : Real = 18.0;
    }

    action def AdvertiseAvailability {
        out item packet : AdvertisementPacket;
    }

    action def EstablishSecureConnection {
        in item request : PairingRequest;
        out item key : PairingKey;
    }

    action def TransferApplicationData {
        in item outboundPayload : ApplicationPayload;
        out item frame : BluetoothDataFrame;
        in item acknowledgement : Acknowledgement;
    }

    state def BluetoothLinkLifecycle {
        state PoweredOff;
        state Advertising;
        state Pairing;
        state Connected;
        state TransferringData;
        state LowPowerIdle;

        transition initial then PoweredOff;
        transition PoweredOff then Advertising;
        transition Advertising then Pairing
            accept PairingRequest;
        transition Pairing then Connected
            if authenticated == true;
        transition Connected then TransferringData
            accept ApplicationPayload;
        transition TransferringData then Connected
            accept Acknowledgement;
        transition Connected then LowPowerIdle;
        transition LowPowerIdle then Advertising;
    }

    part def BluetoothBasedSystem {
        doc /* Primary function: provide a short-range wireless Bluetooth link that advertises availability, pairs securely with a nearby device, and exchanges application data without a wired connection. */

        part controller : BluetoothController;
        part antenna : Antenna;
        part pairingManager : PairingManager;
        part processor : ApplicationProcessor;
        part powerManager : PowerManager;

        port bluetoothAirInterface : BluetoothRadioPort;
        port applicationInterface : ApplicationServicePort;

        connect controller.radio to antenna.radioFeed;
        connect antenna.radioFeed to bluetoothAirInterface;
        connect controller.host to processor.service;
        connect processor.service to applicationInterface;
        connect pairingManager.securityExchange to controller.radio;

        perform action advertise : AdvertiseAvailability;
        perform action pair : EstablishSecureConnection;
        perform action transfer : TransferApplicationData;

        exhibit state linkLifecycle : BluetoothLinkLifecycle;
    }

    requirement def PrimaryFunctionRequirement {
        subject system : BluetoothBasedSystem;
        doc /* The system shall support high-level Bluetooth wireless communication by advertising, pairing, maintaining a secure connection, and transferring application payloads over the 2.402 GHz to 2.480 GHz band. */
    }

    requirement def WirelessRangeRequirement {
        subject system : BluetoothBasedSystem;
        require constraint {
            system.antenna.range >= 10.0
        }
    }

    requirement def PairingTimeRequirement {
        subject system : BluetoothBasedSystem;
        require constraint {
            system.pairingManager.maximumPairingTime <= 10.0
        }
    }

    requirement def DataRateRequirement {
        subject system : BluetoothBasedSystem;
        require constraint {
            system.controller.nominalDataRate.value >= 1.0
        }
    }

    requirement def SecurityRequirement {
        subject system : BluetoothBasedSystem;
        require constraint {
            system.pairingManager.authenticated == true implies system.controller.connected == true
        }
    }

    part bluetoothSystem : BluetoothBasedSystem;

    satisfy PrimaryFunctionRequirement by bluetoothSystem;
    satisfy WirelessRangeRequirement by bluetoothSystem;
    satisfy PairingTimeRequirement by bluetoothSystem;
    satisfy DataRateRequirement by bluetoothSystem;
    satisfy SecurityRequirement by bluetoothSystem;
}