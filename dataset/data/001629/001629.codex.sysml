package WirelessCommunicationSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Frequency :> real {
        unit = "Hz";
    }

    attribute def DataRate :> real {
        unit = "bit/s";
    }

    attribute def Power :> real {
        unit = "W";
    }

    attribute def Energy :> real {
        unit = "J";
    }

    attribute def Distance :> real {
        unit = "m";
    }

    attribute def Percentage :> real {
        unit = "%";
    }

    attribute def Latency :> real {
        unit = "s";
    }

    attribute def SignalStrength :> real {
        unit = "dBm";
    }

    item def UserDataPacket {
        attribute payloadSize : DataRate;
        attribute priority : Integer;
        attribute encrypted : Boolean;
    }

    item def RadioSignal {
        attribute carrierFrequency : Frequency;
        attribute bandwidth : Frequency;
        attribute transmitPower : Power;
        attribute receivedSignalStrength : SignalStrength;
        attribute modulationScheme : String;
    }

    item def ControlMessage {
        attribute messageType : String;
        attribute sequenceNumber : Integer;
        attribute acknowledged : Boolean;
    }

    item def SecurityCredential {
        attribute credentialId : String;
        attribute valid : Boolean;
        attribute encryptionAlgorithm : String;
    }

    port def DataPort {
        out item outgoingPacket : UserDataPacket;
        in item incomingPacket : UserDataPacket;
    }

    port def RadioPort {
        out item transmittedSignal : RadioSignal;
        in item receivedSignal : RadioSignal;
    }

    port def ControlPort {
        out item outgoingControl : ControlMessage;
        in item incomingControl : ControlMessage;
    }

    port def SecurityPort {
        in item credential : SecurityCredential;
        out item securityStatus : ControlMessage;
    }

    part def WirelessDevice {
        attribute deviceId : String;
        attribute batteryEnergy : Energy;
        attribute operatingFrequency : Frequency;
        attribute maximumTransmitPower : Power;
        attribute supportedDataRate : DataRate;
        attribute communicationRange : Distance;

        port userData : DataPort;
        port radio : RadioPort;
        port control : ControlPort;
        port security : SecurityPort;

        part antenna {
            attribute gain : real;
            attribute impedance : real;
            port rf : RadioPort;
        }

        part radioTransceiver {
            attribute receiveSensitivity : SignalStrength;
            attribute transmitPowerSetting : Power;
            attribute activeChannel : Frequency;
            port rf : RadioPort;
            port baseband : DataPort;
            port controlInterface : ControlPort;
        }

        part basebandProcessor {
            attribute codingRate : real;
            attribute packetErrorRate : Percentage;
            port dataInterface : DataPort;
            port radioInterface : DataPort;
            port controlInterface : ControlPort;
        }

        part securityModule {
            attribute authenticationEnabled : Boolean;
            attribute encryptionEnabled : Boolean;
            port credentialInput : SecurityPort;
            port secureData : DataPort;
        }

        part powerManager {
            attribute remainingCharge : Percentage;
            attribute sleepPower : Power;
            attribute activePower : Power;
            port controlInterface : ControlPort;
        }

        connect radio to antenna.rf;
        connect antenna.rf to radioTransceiver.rf;
        connect radioTransceiver.baseband to basebandProcessor.radioInterface;
        connect basebandProcessor.dataInterface to securityModule.secureData;
        connect securityModule.secureData to userData;
        connect control to radioTransceiver.controlInterface;
        connect control to basebandProcessor.controlInterface;
        connect control to powerManager.controlInterface;
        connect security to securityModule.credentialInput;
    }

    part def WirelessAccessPoint {
        attribute accessPointId : String;
        attribute serviceSetIdentifier : String;
        attribute coverageRadius : Distance;
        attribute maximumClientCount : Integer;
        attribute backhaulDataRate : DataRate;

        port wirelessRadio : RadioPort;
        port clientData : DataPort;
        port networkControl : ControlPort;

        part multiBandRadio {
            attribute lowBandFrequency : Frequency = 2400000000.0;
            attribute highBandFrequency : Frequency = 5000000000.0;
            attribute channelBandwidth : Frequency = 20000000.0;
            port rf : RadioPort;
            port baseband : DataPort;
        }

        part scheduler {
            attribute connectedClientCount : Integer;
            attribute averageLatency : Latency;
            port data : DataPort;
            port control : ControlPort;
        }

        part gatewayProcessor {
            attribute routingTableEntries : Integer;
            attribute firewallEnabled : Boolean;
            port localData : DataPort;
            port management : ControlPort;
        }

        connect wirelessRadio to multiBandRadio.rf;
        connect multiBandRadio.baseband to scheduler.data;
        connect scheduler.data to gatewayProcessor.localData;
        connect clientData to gatewayProcessor.localData;
        connect networkControl to scheduler.control;
        connect networkControl to gatewayProcessor.management;
    }

    part def WirelessCommunicationSystem {
        attribute systemName : String = "Wireless Communication System";
        attribute primaryFunction : String = "Provide bidirectional wireless exchange of digital data between mobile devices and a network access point without a physical communication cable.";
        attribute nominalCarrierFrequency : Frequency = 2400000000.0;
        attribute minimumUsableDataRate : DataRate = 1000000.0;
        attribute maximumEndToEndLatency : Latency = 0.050;
        attribute minimumCoverageRadius : Distance = 30.0;
        attribute minimumLinkReliability : Percentage = 99.0;

        port externalUserData : DataPort;
        port radioEnvironment : RadioPort;
        port managementInterface : ControlPort;

        part mobileDevice : WirelessDevice {
            attribute deviceId = "WD-001";
            attribute batteryEnergy = 36000.0;
            attribute operatingFrequency = 2400000000.0;
            attribute maximumTransmitPower = 0.1;
            attribute supportedDataRate = 54000000.0;
            attribute communicationRange = 50.0;
        }

        part accessPoint : WirelessAccessPoint {
            attribute accessPointId = "AP-001";
            attribute serviceSetIdentifier = "Wireless-Network";
            attribute coverageRadius = 60.0;
            attribute maximumClientCount = 64;
            attribute backhaulDataRate = 1000000000.0;
        }

        part wirelessChannel {
            attribute pathLength : Distance = 20.0;
            attribute interferencePower : Power = 0.000001;
            attribute packetLossRate : Percentage = 0.5;
            port deviceSide : RadioPort;
            port accessPointSide : RadioPort;
        }

        connect externalUserData to mobileDevice.userData;
        connect mobileDevice.radio to wirelessChannel.deviceSide;
        connect wirelessChannel.accessPointSide to accessPoint.wirelessRadio;
        connect accessPoint.clientData to externalUserData;
        connect managementInterface to mobileDevice.control;
        connect managementInterface to accessPoint.networkControl;
        connect radioEnvironment to wirelessChannel.deviceSide;
    }

    action def AuthenticateDevice {
        in item credential : SecurityCredential;
        out item result : ControlMessage;

        first start;
        then validateCredential;
        then generateAuthenticationStatus;
        then done;

        action validateCredential {
            in item credential : SecurityCredential;
            out validCredential : Boolean;
        }

        action generateAuthenticationStatus {
            in validCredential : Boolean;
            out item result : ControlMessage;
        }
    }

    action def EncodeAndTransmitPacket {
        in item packet : UserDataPacket;
        in carrier : Frequency;
        in txPower : Power;
        out item signal : RadioSignal;

        first receivePacket;
        then applyEncryption;
        then encodeBaseband;
        then modulateCarrier;
        then transmitRadioSignal;
        then done;

        action receivePacket {
            in item packet : UserDataPacket;
        }

        action applyEncryption {
            in item packet : UserDataPacket;
            out item encryptedPacket : UserDataPacket;
        }

        action encodeBaseband {
            in item encryptedPacket : UserDataPacket;
            out item codedPacket : UserDataPacket;
        }

        action modulateCarrier {
            in item codedPacket : UserDataPacket;
            in carrier : Frequency;
            out item modulatedSignal : RadioSignal;
        }

        action transmitRadioSignal {
            in item modulatedSignal : RadioSignal;
            in txPower : Power;
            out item signal : RadioSignal;
        }
    }

    action def ReceiveAndDecodePacket {
        in item signal : RadioSignal;
        out item packet : UserDataPacket;

        first detectSignal;
        then demodulateCarrier;
        then decodeBaseband;
        then decryptPayload;
        then deliverPacket;
        then done;

        action detectSignal {
            in item signal : RadioSignal;
            out signalDetected : Boolean;
        }

        action demodulateCarrier {
            in item signal : RadioSignal;
            out item codedPacket : UserDataPacket;
        }

        action decodeBaseband {
            in item codedPacket : UserDataPacket;
            out item encryptedPacket : UserDataPacket;
        }

        action decryptPayload {
            in item encryptedPacket : UserDataPacket;
            out item clearPacket : UserDataPacket;
        }

        action deliverPacket {
            in item clearPacket : UserDataPacket;
            out item packet : UserDataPacket;
        }
    }

    state def WirelessLinkStateMachine {
        entry action initializeRadio;

        state Off;
        state Scanning;
        state Authenticating;
        state Associated;
        state Transmitting;
        state Receiving;
        state PowerSave;
        state Fault;

        transition first Off;

        transition Off_to_Scanning
            first Off
            accept ControlMessage
            then Scanning;

        transition Scanning_to_Authenticating
            first Scanning
            accept RadioSignal
            then Authenticating;

        transition Authenticating_to_Associated
            first Authenticating
            accept SecurityCredential
            if credential.valid
            then Associated;

        transition Authenticating_to_Fault
            first Authenticating
            accept SecurityCredential
            if not credential.valid
            then Fault;

        transition Associated_to_Transmitting
            first Associated
            accept UserDataPacket
            then Transmitting;

        transition Associated_to_Receiving
            first Associated
            accept RadioSignal
            then Receiving;

        transition Transmitting_to_Associated
            first Transmitting
            accept ControlMessage
            then Associated;

        transition Receiving_to_Associated
            first Receiving
            accept UserDataPacket
            then Associated;

        transition Associated_to_PowerSave
            first Associated
            accept ControlMessage
            then PowerSave;

        transition PowerSave_to_Associated
            first PowerSave
            accept ControlMessage
            then Associated;

        transition Fault_to_Scanning
            first Fault
            accept ControlMessage
            then Scanning;
    }

    requirement def PrimaryWirelessFunctionRequirement {
        subject system : WirelessCommunicationSystem;

        require constraint {
            system.minimumUsableDataRate >= 1000000.0 and
            system.minimumCoverageRadius >= 30.0 and
            system.maximumEndToEndLatency <= 0.050
        }

        doc /* The wireless system shall provide bidirectional digital communication between a wireless device and an access point using radio-frequency signaling without requiring a physical data cable. */
    }

    requirement def SecureCommunicationRequirement {
        subject device : WirelessDevice;

        require constraint {
            device.securityModule.authenticationEnabled == true and
            device.securityModule.encryptionEnabled == true
        }

        doc /* The wireless device shall authenticate before association and shall encrypt user data packets before transmission over the radio channel. */
    }

    requirement def CoverageRequirement {
        subject system : WirelessCommunicationSystem;

        require constraint {
            system.accessPoint.coverageRadius >= system.minimumCoverageRadius and
            system.mobileDevice.communicationRange >= system.minimumCoverageRadius
        }

        doc /* The wireless system shall maintain usable radio communication across the required coverage area. */
    }

    requirement def ReliabilityRequirement {
        subject system : WirelessCommunicationSystem;

        require constraint {
            system.minimumLinkReliability >= 99.0 and
            system.wirelessChannel.packetLossRate <= 1.0
        }

        doc /* The wireless link shall deliver packets with sufficient reliability for normal user data exchange. */
    }

    requirement def PowerManagementRequirement {
        subject device : WirelessDevice;

        require constraint {
            device.powerManager.remainingCharge >= 5.0 and
            device.powerManager.sleepPower < device.powerManager.activePower
        }

        doc /* The wireless device shall manage operating modes to reduce power consumption when active communication is not required. */
    }

    satisfy PrimaryWirelessFunctionRequirement by WirelessCommunicationSystem;
    satisfy SecureCommunicationRequirement by WirelessDevice;
    satisfy CoverageRequirement by WirelessCommunicationSystem;
    satisfy ReliabilityRequirement by WirelessCommunicationSystem;
    satisfy PowerManagementRequirement by WirelessDevice;
}