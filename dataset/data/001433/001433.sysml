package GeneralPacketRadioService {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;

    attribute def DataRateValue {
        attribute num : Real;
        attribute unit : DataRateUnit;
    }

    attribute def DataRateUnit;

    attribute def FrequencyValue {
        attribute num : Real;
        attribute unit : FrequencyUnit;
    }

    attribute def FrequencyUnit;

    attribute def PowerValue {
        attribute num : Real;
        attribute unit : PowerUnit;
    }

    attribute def PowerUnit;

    enum def SessionState {
        idle;
        attaching;
        attached;
        activating;
        active;
        transferring;
        releasing;
    }

    enum def PacketPriority {
        low;
        medium;
        high;
        critical;
    }

    item def DataPacket {
        attribute sourceAddress : String;
        attribute destinationAddress : String;
        attribute payload : String;
        attribute size : Integer;
        attribute priority : PacketPriority;
        attribute timestamp : Real;
    }

    port def RadioInterfacePort {
        attribute carrierFrequency : FrequencyValue;
        attribute transmitPower : PowerValue;
        attribute signalStrength : Real;
        inout packet : DataPacket;
    }

    port def NetworkInterfacePort {
        attribute ipAddress : String;
        attribute maxDataRate : DataRateValue;
        inout packet : DataPacket;
    }

    part def MobileStation {
        attribute imsi : String;
        attribute currentState : SessionState;
        attribute batteryLevel : Real;

        port airInterface : RadioInterfacePort {
            attribute :>> carrierFrequency : FrequencyValue;
            attribute :>> transmitPower : PowerValue;
        }

        part transceiver {
            attribute operatingFrequency : FrequencyValue;
            attribute maxPower : PowerValue;
        }

        part applicationLayer {
            attribute activeConnections : Integer;
        }
    }

    part def BaseStationSubsystem {
        attribute cellId : String;
        attribute coverageArea : Real;

        port airInterface : RadioInterfacePort {
            attribute :>> carrierFrequency : FrequencyValue;
            attribute :>> transmitPower : PowerValue;
        }

        port coreInterface : NetworkInterfacePort {
            attribute :>> ipAddress : String;
            attribute :>> maxDataRate : DataRateValue;
        }

        part baseTransceiverStation {
            attribute numberOfChannels : Integer;
            attribute transmitPower : PowerValue;
        }

        part baseStationController {
            attribute processingCapacity : Real;
            attribute connectedBTS : Integer;
        }
    }

    part def ServingGPRSNode {
        attribute nodeId : String;
        attribute serviceArea : String;

        port bssInterface : NetworkInterfacePort {
            attribute :>> ipAddress : String;
            attribute :>> maxDataRate : DataRateValue;
        }

        port ggsnInterface : NetworkInterfacePort {
            attribute :>> ipAddress : String;
            attribute :>> maxDataRate : DataRateValue;
        }

        part mobilityManagement {
            attribute registeredUsers : Integer;
            attribute locationUpdateRate : Real;
        }

        part sessionManagement {
            attribute activeSessions : Integer;
            attribute maxSessions : Integer;
        }

        part routingFunction {
            attribute routingTableSize : Integer;
        }
    }

    part def GatewayGPRSNode {
        attribute gatewayId : String;

        port sgsnInterface : NetworkInterfacePort {
            attribute :>> ipAddress : String;
            attribute :>> maxDataRate : DataRateValue;
        }

        port externalInterface : NetworkInterfacePort {
            attribute :>> ipAddress : String;
            attribute :>> maxDataRate : DataRateValue;
        }

        part pdpContextManager {
            attribute activeContexts : Integer;
            attribute maxContexts : Integer;
        }

        part ipRouter {
            attribute throughput : DataRateValue;
        }

        part firewallModule {
            attribute securityLevel : Integer;
        }
    }

    action def AttachToNetwork {
        in mobileId : String;
        out attachSuccess : Boolean;
        out assignedAddress : String;
    }

    action def ActivatePDPContext {
        in requestedQoS : Real;
        in apn : String;
        out contextId : String;
        out activationSuccess : Boolean;
    }

    action def TransmitPacket {
        in packet : DataPacket;
        in codingScheme : Integer;
        out transmissionSuccess : Boolean;
    }

    action def RoutePacket {
        in packet : DataPacket;
        in routingTable : String;
        out nextHop : String;
        out routingSuccess : Boolean;
    }

    action def DeactivatePDPContext {
        in contextId : String;
        out deactivationSuccess : Boolean;
    }

    action def DetachFromNetwork {
        in mobileId : String;
        out detachSuccess : Boolean;
    }

    action def GPRSPacketDataSession {
        in mobileIdentifier : String;
        in qualityOfService : Real;
        in accessPointName : String;
        in codingSchemeValue : Integer;
        in routingTableData : String;
        in moreDataFlag : Boolean;

        first start;
        then attachAction : AttachToNetwork {
            in mobileId = mobileIdentifier;
            out attachSuccess : Boolean;
            out assignedAddress : String;
        }
        then decide;
            if attachAction.attachSuccess then activateContext;
            if not attachAction.attachSuccess then retryAttach;

        action retryAttach;
        then attachAction;

        action activateContext : ActivatePDPContext {
            in requestedQoS = qualityOfService;
            in apn = accessPointName;
            out contextId : String;
            out activationSuccess : Boolean;
        }
        then decide;
            if activateContext.activationSuccess then merge continueTransfer;
            if not activateContext.activationSuccess then done;

        merge continueTransfer;
        then preparePacket;

        action preparePacket {
            out dataPacket : DataPacket;
        }
        then transmitAction : TransmitPacket {
            in packet = preparePacket.dataPacket;
            in codingScheme = codingSchemeValue;
            out transmissionSuccess : Boolean;
        }
        then decide;
            if transmitAction.transmissionSuccess then routeAction;
            if not transmitAction.transmissionSuccess then retransmit;

        action retransmit;
        then transmitAction;

        action routeAction : RoutePacket {
            in packet = preparePacket.dataPacket;
            in routingTable = routingTableData;
            out nextHop : String;
            out routingSuccess : Boolean;
        }
        then decide;
            if moreDataFlag then continueTransfer;
            if not moreDataFlag then deactivateContext;

        action deactivateContext : DeactivatePDPContext {
            in contextId = activateContext.contextId;
            out deactivationSuccess : Boolean;
        }
        then detachAction : DetachFromNetwork {
            in mobileId = attachAction.assignedAddress;
            out detachSuccess : Boolean;
        }
        then done;
    }

    state def GPRSSessionStateMachine {
        entry; then idleState;

        state idleState;
        transition idleToAttaching
            first idleState
            accept attachRequest
            then attachingState;

        state attachingState;
        transition attachingToAttached
            first attachingState
            accept attachConfirmed
            then attachedState;
        transition attachingToIdle
            first attachingState
            accept attachFailed
            then idleState;

        state attachedState;
        transition attachedToActivating
            first attachedState
            accept pdpActivationRequest
            then activatingState;

        state activatingState;
        transition activatingToActive
            first activatingState
            accept contextActivated
            then activeState;
        transition activatingToAttached
            first activatingState
            accept activationFailed
            then attachedState;

        state activeState;
        transition activeToTransferring
            first activeState
            accept dataAvailable
            then transferringState;
        transition activeToReleasing
            first activeState
            accept releaseRequest
            then releasingState;

        state transferringState {
            entry; then transmitting;
            state transmitting;
            transition transmittingToRouting
                first transmitting
                then routing;
            state routing;
            transition routingToAcknowledging
                first routing
                then acknowledging;
            state acknowledging;
        }
        transition transferringToActive
            first transferringState
            accept transferComplete
            then activeState;

        state releasingState;
        transition releasingToIdle
            first releasingState
            accept releaseConfirmed
            then idleState;
    }

    part gprsNetwork {
        attribute networkId : String;
        attribute operationalStatus : Boolean;

        part mobileStations : MobileStation[1..*] {
            attribute :>> imsi;
            attribute :>> currentState;
            attribute :>> batteryLevel;
        }

        part baseStations : BaseStationSubsystem[1..*] {
            attribute :>> cellId;
            attribute :>> coverageArea;
        }

        part sgsnNode : ServingGPRSNode {
            attribute :>> nodeId;
            attribute :>> serviceArea;
        }

        part ggsnNode : GatewayGPRSNode {
            attribute :>> gatewayId;
        }

        connection radioLink connect
            mobileStations.airInterface to baseStations.airInterface;

        connection backhaulLink connect
            baseStations.coreInterface to sgsnNode.bssInterface;

        connection backboneLink connect
            sgsnNode.ggsnInterface to ggsnNode.sgsnInterface;

        perform action sessionBehavior : GPRSPacketDataSession {
            in mobileIdentifier = "IMSI-001";
            in qualityOfService = 1.0;
            in accessPointName = "internet";
            in codingSchemeValue = 2;
            in routingTableData = "default";
            in moreDataFlag = false;
        }
    }

    requirement <'GPRS-REQ-001'> packetSwitchedDataService {
        doc /* The GPRS system shall provide packet-switched data services
             * enabling mobile stations to transmit and receive IP data packets
             * over the cellular radio network infrastructure.
             */
        subject network :> gprsNetwork;

        require networkAttachment;
        require pdpContextActivation;
        require packetTransmission;
        require packetRouting;
    }

    requirement <'GPRS-REQ-002'> networkAttachment {
        doc /* Mobile stations shall be able to attach to the GPRS network
             * and obtain network access credentials.
             */
        subject ms :> gprsNetwork.mobileStations;
        subject sgsn :> gprsNetwork.sgsnNode;
    }

    requirement <'GPRS-REQ-003'> pdpContextActivation {
        doc /* The system shall support activation of Packet Data Protocol contexts
             * to establish logical connections for data transfer.
             */
        subject sgsn :> gprsNetwork.sgsnNode;
        subject ggsn :> gprsNetwork.ggsnNode;

        assert constraint {
            sgsn.sessionManagement.activeSessions <= sgsn.sessionManagement.maxSessions
        }
    }

    requirement <'GPRS-REQ-004'> packetTransmission {
        doc /* The system shall transmit data packets between mobile stations
             * and base stations using radio frequency communication.
             */
        subject ms :> gprsNetwork.mobileStations;
        subject bss :> gprsNetwork.baseStations;

        assert constraint {
            ms.airInterface.carrierFrequency.num >= 890.0 and
            ms.airInterface.carrierFrequency.num <= 960.0
        }
    }

    requirement <'GPRS-REQ-005'> packetRouting {
        doc /* The SGSN and GGSN shall route data packets between mobile stations
             * and external packet data networks.
             */
        subject sgsn :> gprsNetwork.sgsnNode;
        subject ggsn :> gprsNetwork.ggsnNode;

        assert constraint {
            ggsn.pdpContextManager.activeContexts <= ggsn.pdpContextManager.maxContexts
        }
    }

    requirement <'GPRS-REQ-006'> dataRateCapability {
        doc /* The system shall support data transmission rates suitable
             * for GPRS service classes.
             */
        subject network :> gprsNetwork;

        assert constraint {
            gprsNetwork.baseStations.coreInterface.maxDataRate.num >= 9.6 and
            gprsNetwork.baseStations.coreInterface.maxDataRate.num <= 171.2
        }
    }

    satisfy packetSwitchedDataService by gprsNetwork;
}
