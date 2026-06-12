package HomePlugPowerlineCommunicationSystem {

    import ScalarValues::*;
    import SI::*;

    attribute def Frequency :> Real {
        unit = "Hz";
    }

    attribute def DataRate :> Real {
        unit = "bit/s";
    }

    attribute def Voltage :> Real {
        unit = "V";
    }

    attribute def Current :> Real {
        unit = "A";
    }

    attribute def Power :> Real {
        unit = "W";
    }

    attribute def Temperature :> Real {
        unit = "degC";
    }

    attribute def SignalLevel :> Real {
        unit = "dBm";
    }

    attribute def TimeDuration :> Real {
        unit = "s";
    }

    attribute def Percent :> Real {
        unit = "%";
    }

    item def EthernetFrame {
        attribute destinationMac : String;
        attribute sourceMac : String;
        attribute etherType : Integer;
        attribute payloadLength : Integer;
        attribute payloadChecksum : Integer;
    }

    item def PowerlineFrame {
        attribute networkId : String;
        attribute sourceNodeId : String;
        attribute destinationNodeId : String;
        attribute modulationProfile : String;
        attribute encryptedPayloadLength : Integer;
        attribute forwardErrorCorrectionCode : Integer;
    }

    item def AcPower {
        attribute rmsVoltage : Voltage;
        attribute rmsCurrent : Current;
        attribute frequency : Frequency;
        attribute apparentPower : Power;
    }

    item def ManagementMessage {
        attribute messageType : String;
        attribute sequenceNumber : Integer;
        attribute requestingNodeId : String;
        attribute targetNodeId : String;
    }

    item def SecurityCredential {
        attribute networkMembershipKeyId : String;
        attribute encryptedNetworkKey : String;
        attribute authenticationNonce : String;
    }

    port def EthernetPort {
        in item receivedFrame : EthernetFrame;
        out item transmittedFrame : EthernetFrame;
    }

    port def PowerlineCarrierPort {
        in item inboundCarrierFrame : PowerlineFrame;
        out item outboundCarrierFrame : PowerlineFrame;
        in item suppliedPower : AcPower;
    }

    port def AcMainsPlugPort {
        in item branchCircuitPower : AcPower;
        out item injectedCarrierFrame : PowerlineFrame;
        in item sensedCarrierFrame : PowerlineFrame;
    }

    port def ManagementPort {
        in item command : ManagementMessage;
        out item status : ManagementMessage;
        in item credential : SecurityCredential;
    }

    part def EthernetPhysicalInterface {
        attribute linkSpeed : DataRate = 1000000000;
        attribute linkUp : Boolean;
        attribute receiveErrorRate : Percent;
        port lanPort : EthernetPort;

        action negotiateEthernetLink {
            in requestedRate : DataRate;
            out selectedRate : DataRate;
            out linkEstablished : Boolean;
        }

        action receiveEthernetFrame {
            in frameFromLan : EthernetFrame;
            out frameForBridge : EthernetFrame;
        }

        action transmitEthernetFrame {
            in frameFromBridge : EthernetFrame;
            out frameToLan : EthernetFrame;
        }
    }

    part def PowerlineAnalogFrontEnd {
        attribute carrierBandLow : Frequency = 2000000;
        attribute carrierBandHigh : Frequency = 86000000;
        attribute transmitPowerSpectralLimit : SignalLevel = -50;
        attribute receiveSensitivity : SignalLevel = -85;
        attribute lineImpedanceEstimate : Real;
        port mainsCoupler : AcMainsPlugPort;
        port modemCarrier : PowerlineCarrierPort;

        action injectCarrier {
            in frameForLine : PowerlineFrame;
            out frameOnLine : PowerlineFrame;
        }

        action senseCarrier {
            in frameOnLine : PowerlineFrame;
            out frameForModem : PowerlineFrame;
        }

        action estimateLineCondition {
            out noiseFloor : SignalLevel;
            out attenuation : SignalLevel;
            out usableBandPercent : Percent;
        }
    }

    part def OfdmPowerlineModem {
        attribute maximumPhyRate : DataRate = 1200000000;
        attribute activePhyRate : DataRate;
        attribute carrierFrequencyLow : Frequency = 2000000;
        attribute carrierFrequencyHigh : Frequency = 86000000;
        attribute channelNoiseFloor : SignalLevel;
        attribute synchronizationLocked : Boolean;
        port carrierPort : PowerlineCarrierPort;

        action encodeFrame {
            in ethernetFrame : EthernetFrame;
            in networkKey : SecurityCredential;
            out encodedFrame : PowerlineFrame;
        }

        action decodeFrame {
            in encodedFrame : PowerlineFrame;
            in networkKey : SecurityCredential;
            out ethernetFrame : EthernetFrame;
        }

        action adaptModulation {
            in measuredNoise : SignalLevel;
            in measuredAttenuation : SignalLevel;
            out selectedProfile : String;
            out resultingRate : DataRate;
        }

        state def ModemOperatingState {
            entry action initializeReceiver;
            state Unlocked;
            state Synchronizing;
            state Linked;
            state Degraded;
            state Faulted;

            transition first Unlocked;
            transition Unlocked_to_Synchronizing
                first Unlocked
                then Synchronizing;

            transition Synchronizing_to_Linked
                first Synchronizing
                then Linked
                if synchronizationLocked == true;

            transition Linked_to_Degraded
                first Linked
                then Degraded
                if channelNoiseFloor > -60;

            transition Degraded_to_Linked
                first Degraded
                then Linked
                if channelNoiseFloor <= -65;

            transition Linked_to_Faulted
                first Linked
                then Faulted
                if activePhyRate < 10000000;

            transition Faulted_to_Synchronizing
                first Faulted
                then Synchronizing
                after 5;
        }
    }

    part def SecurityEngine {
        attribute encryptionAlgorithm : String = "AES-128-CCM";
        attribute authenticated : Boolean;
        attribute networkMembershipKeyId : String;
        attribute replayProtectionWindow : Integer = 64;

        action authenticatePeer {
            in credential : SecurityCredential;
            out accepted : Boolean;
        }

        action encryptPayload {
            in clearFrame : EthernetFrame;
            in credential : SecurityCredential;
            out protectedFrame : PowerlineFrame;
        }

        action decryptPayload {
            in protectedFrame : PowerlineFrame;
            in credential : SecurityCredential;
            out clearFrame : EthernetFrame;
            out integrityValid : Boolean;
        }
    }

    part def PacketBridge {
        attribute learnedMacCount : Integer;
        attribute maximumLearnedMacCount : Integer = 128;
        attribute forwardingLatency : TimeDuration;
        port localEthernet : EthernetPort;
        port powerlineNetwork : PowerlineCarrierPort;

        action learnSourceAddress {
            in frame : EthernetFrame;
            out tableUpdated : Boolean;
        }

        action forwardLanToPowerline {
            in lanFrame : EthernetFrame;
            out powerlineFrameRequest : EthernetFrame;
        }

        action forwardPowerlineToLan {
            in lanFrame : EthernetFrame;
            out ethernetFrameRequest : EthernetFrame;
        }

        action filterLocalTraffic {
            in frame : EthernetFrame;
            out shouldForward : Boolean;
        }
    }

    part def PowerSupply {
        attribute inputVoltageMinimum : Voltage = 90;
        attribute inputVoltageMaximum : Voltage = 264;
        attribute inputFrequencyMinimum : Frequency = 47;
        attribute inputFrequencyMaximum : Frequency = 63;
        attribute regulatedDcVoltage : Voltage = 12;
        attribute maximumOutputPower : Power = 8;
        attribute efficiency : Percent = 85;
        port acInput : AcMainsPlugPort;

        action convertAcToDc {
            in acPower : AcPower;
            out dcVoltage : Voltage;
            out availablePower : Power;
        }

        action protectAgainstSurge {
            in surgeVoltage : Voltage;
            out protected : Boolean;
        }
    }

    part def ThermalMonitor {
        attribute boardTemperature : Temperature;
        attribute warningThreshold : Temperature = 80;
        attribute shutdownThreshold : Temperature = 95;
        attribute throttlingActive : Boolean;

        action sampleTemperature {
            out measuredTemperature : Temperature;
        }

        action applyThermalPolicy {
            in measuredTemperature : Temperature;
            out allowTransmit : Boolean;
            out reducedTransmitPower : Boolean;
        }
    }

    part def UserStatusInterface {
        attribute powerLedOn : Boolean;
        attribute ethernetLedOn : Boolean;
        attribute powerlineLedOn : Boolean;
        attribute securityLedOn : Boolean;

        action updateIndicators {
            in powered : Boolean;
            in ethernetLinked : Boolean;
            in powerlineLinked : Boolean;
            in secure : Boolean;
        }
    }

    part def HomePlugAdapter {
        attribute nodeId : String;
        attribute networkName : String;
        attribute standbyPowerConsumption : Power = 1.2;
        attribute activePowerConsumption : Power = 5.5;
        attribute operatingTemperatureMinimum : Temperature = 0;
        attribute operatingTemperatureMaximum : Temperature = 40;

        port acPlug : AcMainsPlugPort;
        port ethernetJack : EthernetPort;
        port management : ManagementPort;

        part ethernetPhy : EthernetPhysicalInterface;
        part analogFrontEnd : PowerlineAnalogFrontEnd;
        part modem : OfdmPowerlineModem;
        part security : SecurityEngine;
        part bridge : PacketBridge;
        part powerSupply : PowerSupply;
        part thermalMonitor : ThermalMonitor;
        part indicators : UserStatusInterface;

        connect ethernetJack to ethernetPhy.lanPort;
        connect ethernetPhy.lanPort to bridge.localEthernet;
        connect bridge.powerlineNetwork to modem.carrierPort;
        connect modem.carrierPort to analogFrontEnd.modemCarrier;
        connect acPlug to analogFrontEnd.mainsCoupler;
        connect acPlug to powerSupply.acInput;

        action startAdapter {
            out ready : Boolean;
        }

        action joinSecurePowerlineNetwork {
            in credential : SecurityCredential;
            out joined : Boolean;
        }

        action bridgeEthernetOverPowerline {
            in lanFrame : EthernetFrame;
            out lineFrame : PowerlineFrame;
        }

        action bridgePowerlineToEthernet {
            in lineFrame : PowerlineFrame;
            out lanFrame : EthernetFrame;
        }

        state def AdapterState {
            state Off;
            state Booting;
            state WaitingForEthernet;
            state Pairing;
            state Operational;
            state PowerSave;
            state ThermalThrottle;
            state Fault;

            transition initial_to_Off
                first Off;

            transition Off_to_Booting
                first Off
                then Booting
                if acPlug.branchCircuitPower.rmsVoltage >= 90;

            transition Booting_to_WaitingForEthernet
                first Booting
                then WaitingForEthernet
                after 3;

            transition WaitingForEthernet_to_Pairing
                first WaitingForEthernet
                then Pairing
                if ethernetPhy.linkUp == true and security.authenticated == false;

            transition Pairing_to_Operational
                first Pairing
                then Operational
                if security.authenticated == true and modem.synchronizationLocked == true;

            transition Operational_to_PowerSave
                first Operational
                then PowerSave
                if ethernetPhy.linkUp == false;

            transition PowerSave_to_WaitingForEthernet
                first PowerSave
                then WaitingForEthernet
                if ethernetPhy.linkUp == true;

            transition Operational_to_ThermalThrottle
                first Operational
                then ThermalThrottle
                if thermalMonitor.boardTemperature >= thermalMonitor.warningThreshold;

            transition ThermalThrottle_to_Operational
                first ThermalThrottle
                then Operational
                if thermalMonitor.boardTemperature < 75;

            transition ThermalThrottle_to_Fault
                first ThermalThrottle
                then Fault
                if thermalMonitor.boardTemperature >= thermalMonitor.shutdownThreshold;
        }
    }

    part def ResidentialPowerlineNetwork {
        attribute nominalMainsVoltage : Voltage = 120;
        attribute nominalMainsFrequency : Frequency = 60;
        attribute maximumBranchLength : Real = 100;
        attribute maximumAdapters : Integer = 16;
        attribute sharedNetworkName : String;

        port wallOutletA : AcMainsPlugPort;
        port wallOutletB : AcMainsPlugPort;

        part adapterA : HomePlugAdapter {
            attribute nodeId = "HPAV-Node-A";
            attribute networkName = sharedNetworkName;
        }

        part adapterB : HomePlugAdapter {
            attribute nodeId = "HPAV-Node-B";
            attribute networkName = sharedNetworkName;
        }

        connect wallOutletA to adapterA.acPlug;
        connect wallOutletB to adapterB.acPlug;

        connection powerlineCarrierPath connect adapterA.analogFrontEnd.mainsCoupler to adapterB.analogFrontEnd.mainsCoupler;

        action transportEthernetFramesAcrossMains {
            in sourceFrame : EthernetFrame;
            out deliveredFrame : EthernetFrame;
        }
    }

    requirement def HighLevelPrimaryFunctionRequirement {
        doc /* The HomePlug-based system shall use existing residential AC power wiring as a communication medium to extend an Ethernet local area network between wall outlets without installing dedicated data cabling. */
        subject system : ResidentialPowerlineNetwork;
        require constraint {
            system.adapterA.modem.synchronizationLocked == true and
            system.adapterB.modem.synchronizationLocked == true
        }
    }

    requirement def EthernetBridgeRequirement {
        doc /* Each HomePlug adapter shall transparently bridge Ethernet frames between its RJ45 Ethernet port and the powerline carrier interface while preserving source address, destination address, EtherType, and payload checksum. */
        subject adapter : HomePlugAdapter;
        require constraint {
            adapter.bridge.maximumLearnedMacCount >= 128
        }
    }

    requirement def ThroughputRequirement {
        doc /* The system shall support at least 100 Mbit/s effective user data throughput under normal residential wiring conditions. */
        subject adapter : HomePlugAdapter;
        require constraint {
            adapter.modem.activePhyRate >= 100000000
        }
    }

    requirement def SecureNetworkRequirement {
        doc /* The system shall admit only authenticated adapters that possess the configured HomePlug network credential and shall encrypt user traffic on the powerline medium. */
        subject adapter : HomePlugAdapter;
        require constraint {
            adapter.security.authenticated == true and
            adapter.security.encryptionAlgorithm == "AES-128-CCM"
        }
    }

    requirement def AcCompatibilityRequirement {
        doc /* The adapter shall operate from standard residential AC mains power while simultaneously coupling high-frequency communication carriers onto the same wiring. */
        subject adapter : HomePlugAdapter;
        require constraint {
            adapter.powerSupply.inputVoltageMinimum <= 120 and
            adapter.powerSupply.inputVoltageMaximum >= 120 and
            adapter.powerSupply.inputFrequencyMinimum <= 60 and
            adapter.powerSupply.inputFrequencyMaximum >= 60
        }
    }

    requirement def CarrierBandRequirement {
        doc /* The powerline modem and analog front end shall use a high-frequency carrier band above the 60 Hz mains frequency so that data communication is separated from power delivery. */
        subject adapter : HomePlugAdapter;
        require constraint {
            adapter.analogFrontEnd.carrierBandLow >= 2000000 and
            adapter.analogFrontEnd.carrierBandHigh <= 86000000
        }
    }

    requirement def ThermalProtectionRequirement {
        doc /* The adapter shall reduce transmission activity or enter a fault state when internal temperature exceeds defined thermal limits. */
        subject adapter : HomePlugAdapter;
        require constraint {
            adapter.thermalMonitor.warningThreshold < adapter.thermalMonitor.shutdownThreshold
        }
    }

    satisfy HighLevelPrimaryFunctionRequirement by ResidentialPowerlineNetwork;
    satisfy EthernetBridgeRequirement by HomePlugAdapter;
    satisfy ThroughputRequirement by OfdmPowerlineModem;
    satisfy SecureNetworkRequirement by SecurityEngine;
    satisfy AcCompatibilityRequirement by PowerSupply;
    satisfy CarrierBandRequirement by PowerlineAnalogFrontEnd;
    satisfy ThermalProtectionRequirement by ThermalMonitor;

    part homePlugInstallation : ResidentialPowerlineNetwork {
        attribute sharedNetworkName = "HomePlug-Secure-LAN";
        attribute nominalMainsVoltage = 120;
        attribute nominalMainsFrequency = 60;
    }
}