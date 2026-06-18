package UMTS_PrimaryFunction_Model {

  import ScalarValues::*;

  attribute def FrequencyMHz {
    attribute value : Real;
    attribute unit : String = "MHz";
  }

  attribute def BandwidthMHz {
    attribute value : Real;
    attribute unit : String = "MHz";
  }

  attribute def PowerdBm {
    attribute value : Real;
    attribute unit : String = "dBm";
  }

  attribute def DataRateMbps {
    attribute value : Real;
    attribute unit : String = "Mbit/s";
  }

  attribute def Latencyms {
    attribute value : Real;
    attribute unit : String = "ms";
  }

  attribute def AvailabilityPercent {
    attribute value : Real;
    attribute unit : String = "%";
  }

  attribute def AreaKm2 {
    attribute value : Real;
    attribute unit : String = "km^2";
  }

  attribute def TimeSeconds {
    attribute value : Real;
    attribute unit : String = "s";
  }

  attribute def IMSI {
    attribute digits : String;
  }

  attribute def MSISDN {
    attribute digits : String;
  }

  attribute def CellIdentifier {
    attribute value : String;
  }

  attribute def LocationAreaIdentifier {
    attribute value : String;
  }

  enum def ServiceKind {
    enum voiceCall;
    enum circuitSwitchedVideo;
    enum packetData;
    enum shortMessage;
    enum emergencyCall;
    enum locationUpdate;
  }

  enum def BearerDomain {
    enum circuitSwitched;
    enum packetSwitched;
  }

  enum def RadioAccessMode {
    enum UTRAN_FDD;
    enum UTRAN_TDD;
  }

  enum def MobilityStateKind {
    enum detached;
    enum registeredIdle;
    enum connected;
    enum handover;
    enum serviceRelease;
  }

  enum def AuthenticationResultKind {
    enum accepted;
    enum rejected;
    enum retryRequired;
  }

  item def SubscriberIdentity {
    attribute imsi : IMSI;
    attribute msisdn : MSISDN;
  }

  item def ServiceRequest {
    attribute requestedService : ServiceKind;
    attribute requestedDomain : BearerDomain;
    attribute subscriber : SubscriberIdentity;
    attribute requestedMinimumRate : DataRateMbps;
    attribute maximumTolerableLatency : Latencyms;
  }

  item def ServiceAdmissionDecision {
    attribute accepted : Boolean;
    attribute assignedDomain : BearerDomain;
    attribute grantedRate : DataRateMbps;
    attribute reason : String;
  }

  item def ServiceSession {
    attribute service : ServiceKind;
    attribute domain : BearerDomain;
    attribute allocatedRate : DataRateMbps;
    attribute expectedLatency : Latencyms;
    attribute active : Boolean;
  }

  item def VoiceFrame {
    attribute codecName : String = "AMR";
    attribute codecRate : DataRateMbps;
    attribute framePeriod : TimeSeconds;
  }

  item def IPPacket {
    attribute sourceAddress : String;
    attribute destinationAddress : String;
    attribute payloadBytes : Integer;
    attribute qosClassIdentifier : String;
  }

  item def SMSMessage {
    attribute originator : MSISDN;
    attribute recipient : MSISDN;
    attribute payloadText : String;
  }

  item def AuthenticationVector {
    attribute randomChallenge : String;
    attribute expectedResponse : String;
    attribute cipherKey : String;
    attribute integrityKey : String;
  }

  item def AuthenticationResponse {
    attribute result : AuthenticationResultKind;
    attribute subscriber : SubscriberIdentity;
  }

  item def MobilityUpdate {
    attribute subscriber : SubscriberIdentity;
    attribute oldLocationArea : LocationAreaIdentifier;
    attribute newLocationArea : LocationAreaIdentifier;
  }

  item def RadioResourceControlMessage {
    attribute procedureName : String;
    attribute cellId : CellIdentifier;
    attribute accessMode : RadioAccessMode;
  }

  item def RadioBearer {
    attribute bearerId : String;
    attribute domain : BearerDomain;
    attribute guaranteedBitRate : DataRateMbps;
    attribute maximumLatency : Latencyms;
  }

  item def UplinkRadioBurst {
    attribute carrierFrequency : FrequencyMHz;
    attribute channelBandwidth : BandwidthMHz;
    attribute transmitPower : PowerdBm;
    attribute cell : CellIdentifier;
  }

  item def DownlinkRadioBurst {
    attribute carrierFrequency : FrequencyMHz;
    attribute channelBandwidth : BandwidthMHz;
    attribute transmitPower : PowerdBm;
    attribute cell : CellIdentifier;
  }

  item def CircuitSwitchedBearerFlow {
    attribute bearerId : String;
    attribute codec : String;
    attribute nominalRate : DataRateMbps;
  }

  item def PacketSwitchedBearerFlow {
    attribute bearerId : String;
    attribute aggregateRate : DataRateMbps;
    attribute apn : String;
  }

  item def ChargingRecord {
    attribute subscriber : SubscriberIdentity;
    attribute service : ServiceKind;
    attribute duration : TimeSeconds;
    attribute transferredBytes : Integer;
  }

  port def SubscriberServicePort {
    in item serviceRequest : ServiceRequest;
    out item serviceSession : ServiceSession;
    out item admissionDecision : ServiceAdmissionDecision;
    in item smsSubmit : SMSMessage;
    out item smsDeliver : SMSMessage;
  }

  port def UuRadioPort {
    in item uplinkBurst : UplinkRadioBurst;
    out item downlinkBurst : DownlinkRadioBurst;
    in item uplinkRrc : RadioResourceControlMessage;
    out item downlinkRrc : RadioResourceControlMessage;
    out item assignedBearer : RadioBearer;
  }

  port def IubTransportPort {
    in item nodeBRadioFlow : UplinkRadioBurst;
    out item rncRadioFlow : DownlinkRadioBurst;
    in item nodeBControl : RadioResourceControlMessage;
    out item rncControl : RadioResourceControlMessage;
  }

  port def IuCircuitCorePort {
    in item circuitUplink : CircuitSwitchedBearerFlow;
    out item circuitDownlink : CircuitSwitchedBearerFlow;
    in item circuitControl : ServiceRequest;
    out item circuitDecision : ServiceAdmissionDecision;
  }

  port def IuPacketCorePort {
    in item packetUplink : PacketSwitchedBearerFlow;
    out item packetDownlink : PacketSwitchedBearerFlow;
    in item packetControl : ServiceRequest;
    out item packetDecision : ServiceAdmissionDecision;
  }

  port def AuthenticationDatabasePort {
    in item identityRequest : SubscriberIdentity;
    out item authenticationVector : AuthenticationVector;
    in item authenticationResponse : AuthenticationResponse;
  }

  port def MobilityManagementPort {
    in item locationUpdate : MobilityUpdate;
    out item acceptedLocationUpdate : MobilityUpdate;
  }

  port def PSTNGatewayPort {
    in item outgoingVoice : CircuitSwitchedBearerFlow;
    out item incomingVoice : CircuitSwitchedBearerFlow;
  }

  port def InternetGatewayPort {
    in item outgoingPackets : IPPacket;
    out item incomingPackets : IPPacket;
  }

  port def ChargingPort {
    in item chargingRecord : ChargingRecord;
  }

  action def ReceiveSubscriberRequest {
    in item request : ServiceRequest;
    out item acceptedRequest : ServiceRequest;
  }

  action def AuthenticateSubscriber {
    in item subscriber : SubscriberIdentity;
    in item vector : AuthenticationVector;
    out item response : AuthenticationResponse;
  }

  action def RegisterSubscriberLocation {
    in item update : MobilityUpdate;
    out item confirmedUpdate : MobilityUpdate;
  }

  action def AllocateRadioAccessBearer {
    in item request : ServiceRequest;
    out item bearer : RadioBearer;
    out item decision : ServiceAdmissionDecision;
  }

  action def RouteCircuitSwitchedService {
    in item bearer : RadioBearer;
    in item voiceIn : VoiceFrame;
    out item circuitFlow : CircuitSwitchedBearerFlow;
  }

  action def RoutePacketSwitchedService {
    in item bearer : RadioBearer;
    in item packetIn : IPPacket;
    out item packetFlow : PacketSwitchedBearerFlow;
  }

  action def MaintainMobilityContinuity {
    in item activeBearer : RadioBearer;
    in item mobilityUpdate : MobilityUpdate;
    out item transferredBearer : RadioBearer;
  }

  action def ReleaseServiceSession {
    in item session : ServiceSession;
    out item chargingRecord : ChargingRecord;
  }

  action def ProvideUMTSMobileTelecommunications {
    in item subscriberRequest : ServiceRequest;
    out item establishedSession : ServiceSession;
    out item admissionDecision : ServiceAdmissionDecision;

    action receiveRequest : ReceiveSubscriberRequest;
    action authenticate : AuthenticateSubscriber;
    action registerLocation : RegisterSubscriberLocation;
    action allocateBearer : AllocateRadioAccessBearer;
    action maintainContinuity : MaintainMobilityContinuity;
    action releaseSession : ReleaseServiceSession;

    first receiveRequest;
    then authenticate;
    then registerLocation;
    then allocateBearer;
    then maintainContinuity;
    then releaseSession;
  }

  state def UserEquipmentConnectionState {
    state poweredOff;
    state searchingForCell;
    state campedIdle;
    state rrcConnected;
    state activeService;
    state handoverPreparation;
    state detached;

    transition powerOn first poweredOff then searchingForCell;
    transition cellSelected first searchingForCell then campedIdle;
    transition requestConnection first campedIdle then rrcConnected;
    transition bearerEstablished first rrcConnected then activeService;
    transition mobilityEvent first activeService then handoverPreparation;
    transition handoverComplete first handoverPreparation then activeService;
    transition releaseBearer first activeService then campedIdle;
    transition detach first campedIdle then detached;
  }

  state def UMTSNetworkOperationalState {
    state networkUnavailable;
    state broadcastingSystemInformation;
    state acceptingRegistrations;
    state servingTraffic;
    state congestionControlled;
    state degradedOperation;

    transition powerAndBackhaulAvailable first networkUnavailable then broadcastingSystemInformation;
    transition cellsOnAir first broadcastingSystemInformation then acceptingRegistrations;
    transition subscriberRegistered first acceptingRegistrations then servingTraffic;
    transition loadThresholdExceeded first servingTraffic then congestionControlled;
    transition loadRecovered first congestionControlled then servingTraffic;
    transition faultDetected first servingTraffic then degradedOperation;
    transition faultCleared first degradedOperation then servingTraffic;
  }

  part def UserEquipment {
    attribute subscriberIdentity : SubscriberIdentity;
    attribute supportedAccessMode : RadioAccessMode = RadioAccessMode::UTRAN_FDD;
    attribute maximumUplinkRate : DataRateMbps {
      attribute value : Real = 0.384;
      attribute unit : String = "Mbit/s";
    }
    attribute maximumDownlinkRate : DataRateMbps {
      attribute value : Real = 0.384;
      attribute unit : String = "Mbit/s";
    }

    port subscriberPort : SubscriberServicePort;
    port uu : UuRadioPort;

    exhibit state connectionState : UserEquipmentConnectionState;
  }

  part def NodeB {
    attribute cellId : CellIdentifier;
    attribute downlinkCarrier : FrequencyMHz {
      attribute value : Real = 2140.0;
      attribute unit : String = "MHz";
    }
    attribute uplinkCarrier : FrequencyMHz {
      attribute value : Real = 1950.0;
      attribute unit : String = "MHz";
    }
    attribute channelBandwidth : BandwidthMHz {
      attribute value : Real = 5.0;
      attribute unit : String = "MHz";
    }
    attribute nominalCellRadiusArea : AreaKm2 {
      attribute value : Real = 12.0;
      attribute unit : String = "km^2";
    }
    attribute maximumTransmitPower : PowerdBm {
      attribute value : Real = 43.0;
      attribute unit : String = "dBm";
    }

    port uu : UuRadioPort;
    port iub : IubTransportPort;
  }

  part def RadioNetworkController {
    attribute controllerId : String;
    attribute maximumManagedCells : Integer = 256;
    attribute targetRadioBearerSetupTime : Latencyms {
      attribute value : Real = 2000.0;
      attribute unit : String = "ms";
    }

    port iub : IubTransportPort;
    port iuCS : IuCircuitCorePort;
    port iuPS : IuPacketCorePort;

    perform action allocateBearer : AllocateRadioAccessBearer;
    perform action maintainMobility : MaintainMobilityContinuity;
  }

  part def UTRAN {
    attribute accessMode : RadioAccessMode = RadioAccessMode::UTRAN_FDD;
    attribute nominalCoverage : AreaKm2 {
      attribute value : Real = 120.0;
      attribute unit : String = "km^2";
    }

    port radioInterface : UuRadioPort;
    port iuCS : IuCircuitCorePort;
    port iuPS : IuPacketCorePort;

    part servingNodeB : NodeB;
    part servingRNC : RadioNetworkController;

    connection radioAccessLink connect radioInterface to servingNodeB.uu;
    connection iubInterface connect servingNodeB.iub to servingRNC.iub;
    connection csCoreInterface connect servingRNC.iuCS to iuCS;
    connection psCoreInterface connect servingRNC.iuPS to iuPS;
  }

  part def MobileSwitchingCenter {
    attribute mscId : String;
    attribute maximumConcurrentCalls : Integer = 100000;
    attribute targetCallSetupLatency : Latencyms {
      attribute value : Real = 4000.0;
      attribute unit : String = "ms";
    }

    port iuCS : IuCircuitCorePort;
    port pstn : PSTNGatewayPort;
    port mobility : MobilityManagementPort;
    port charging : ChargingPort;

    perform action routeVoice : RouteCircuitSwitchedService;
  }

  part def ServingGPRSSupportNode {
    attribute sgsnId : String;
    attribute maximumAttachedSubscribers : Integer = 500000;
    attribute targetPacketBearerSetupLatency : Latencyms {
      attribute value : Real = 3000.0;
      attribute unit : String = "ms";
    }

    port iuPS : IuPacketCorePort;
    port mobility : MobilityManagementPort;
    port authentication : AuthenticationDatabasePort;
    port charging : ChargingPort;
  }

  part def GatewayGPRSSupportNode {
    attribute ggsnId : String;
    attribute accessPointName : String = "internet.umts.operator";
    attribute sustainedThroughput : DataRateMbps {
      attribute value : Real = 1000.0;
      attribute unit : String = "Mbit/s";
    }

    port sgsnSide : IuPacketCorePort;
    port internet : InternetGatewayPort;

    perform action routePackets : RoutePacketSwitchedService;
  }

  part def HomeLocationRegister {
    attribute operatorCode : String;
    attribute storedSubscriberCapacity : Integer = 10000000;

    port authentication : AuthenticationDatabasePort;
    port mobility : MobilityManagementPort;
  }

  part def AuthenticationCenter {
    attribute algorithmFamily : String = "UMTS AKA";
    attribute vectorGenerationLatency : Latencyms {
      attribute value : Real = 50.0;
      attribute unit : String = "ms";
    }

    port authentication : AuthenticationDatabasePort;
  }

  part def CoreNetwork {
    attribute nominalServiceAvailability : AvailabilityPercent {
      attribute value : Real = 99.95;
      attribute unit : String = "%";
    }

    port iuCS : IuCircuitCorePort;
    port iuPS : IuPacketCorePort;
    port pstn : PSTNGatewayPort;
    port internet : InternetGatewayPort;

    part msc : MobileSwitchingCenter;
    part sgsn : ServingGPRSSupportNode;
    part ggsn : GatewayGPRSSupportNode;
    part hlr : HomeLocationRegister;
    part auc : AuthenticationCenter;

    connection csAccess connect iuCS to msc.iuCS;
    connection psAccess connect iuPS to sgsn.iuPS;
    connection pstnGateway connect msc.pstn to pstn;
    connection packetGateway connect ggsn.internet to internet;
    connection sgsnToGgsn connect sgsn.iuPS to ggsn.sgsnSide;
    connection sgsnToHlrAuthentication connect sgsn.authentication to hlr.authentication;
    connection hlrToAucAuthentication connect hlr.authentication to auc.authentication;
    connection mscToHlrMobility connect msc.mobility to hlr.mobility;
    connection sgsnToHlrMobility connect sgsn.mobility to hlr.mobility;
  }

  part def PublicSwitchedTelephoneNetwork {
    port voiceGateway : PSTNGatewayPort;
  }

  part def PublicInternet {
    port packetGateway : InternetGatewayPort;
  }

  part def UMTSSystem {
    doc /*
      The primary high-level function of this UMTS system is to provide wide-area mobile telecommunications by allowing a subscriber using user equipment to register with the network, be authenticated, obtain radio access, establish a circuit-switched or packet-switched bearer, and exchange voice, messaging, and data traffic with external communication networks while maintaining service continuity during mobility.
    */

    attribute systemName : String = "Universal Mobile Telecommunications System";
    attribute primaryFunction : String = "Provide authenticated mobile voice, messaging, and packet data service over UMTS radio access and core network infrastructure.";
    attribute supportedAccessMode : RadioAccessMode = RadioAccessMode::UTRAN_FDD;
    attribute endToEndVoiceAvailability : AvailabilityPercent {
      attribute value : Real = 99.0;
      attribute unit : String = "%";
    }
    attribute nominalUserPacketRate : DataRateMbps {
      attribute value : Real = 0.384;
      attribute unit : String = "Mbit/s";
    }
    attribute targetInteractiveLatency : Latencyms {
      attribute value : Real = 250.0;
      attribute unit : String = "ms";
    }

    port subscriberFacing : SubscriberServicePort;
    port publicVoiceNetwork : PSTNGatewayPort;
    port publicPacketNetwork : InternetGatewayPort;

    part userEquipment : UserEquipment;
    part radioAccessNetwork : UTRAN;
    part coreNetwork : CoreNetwork;
    part pstnEnvironment : PublicSwitchedTelephoneNetwork;
    part internetEnvironment : PublicInternet;

    connection subscriberToUE connect subscriberFacing to userEquipment.subscriberPort;
    connection uuAirInterface connect userEquipment.uu to radioAccessNetwork.radioInterface;
    connection iuCircuitInterface connect radioAccessNetwork.iuCS to coreNetwork.iuCS;
    connection iuPacketInterface connect radioAccessNetwork.iuPS to coreNetwork.iuPS;
    connection voiceExternalInterface connect coreNetwork.pstn to publicVoiceNetwork;
    connection packetExternalInterface connect coreNetwork.internet to publicPacketNetwork;
    connection pstnEnvironmentLink connect publicVoiceNetwork to pstnEnvironment.voiceGateway;
    connection internetEnvironmentLink connect publicPacketNetwork to internetEnvironment.packetGateway;

    perform action provideMobileTelecommunications : ProvideUMTSMobileTelecommunications;
    exhibit state operationalState : UMTSNetworkOperationalState;
  }

  constraint def MinimumAvailabilityConstraint {
    in attribute availability : AvailabilityPercent;
    in attribute minimum : AvailabilityPercent;
    availability.value >= minimum.value;
  }

  constraint def MaximumLatencyConstraint {
    in attribute latency : Latencyms;
    in attribute maximum : Latencyms;
    latency.value <= maximum.value;
  }

  constraint def MinimumPacketRateConstraint {
    in attribute grantedRate : DataRateMbps;
    in attribute minimumRate : DataRateMbps;
    grantedRate.value >= minimumRate.value;
  }

  requirement def PrimaryUMTSFunctionRequirement {
    doc /*
      The UMTS system shall provide the high-level primary function of authenticated wide-area mobile telecommunications, including subscriber access, radio bearer establishment, mobility support, circuit-switched voice connectivity, messaging support, and packet data connectivity to external networks.
    */
    subject system : UMTSSystem;
    require constraint {
      system.primaryFunction == "Provide authenticated mobile voice, messaging, and packet data service over UMTS radio access and core network infrastructure."
    }
  }

  requirement def AuthenticationRequirement {
    doc /*
      The UMTS system shall authenticate a subscriber before admitting normal voice, messaging, or packet data service.
    */
    subject system : UMTSSystem;
    require constraint {
      system.coreNetwork.auc.algorithmFamily == "UMTS AKA"
    }
  }

  requirement def RadioAccessBearerRequirement {
    doc /*
      The UMTS radio access network shall allocate a radio bearer for an admitted subscriber service request.
    */
    subject system : UMTSSystem;
    require constraint {
      system.radioAccessNetwork.servingRNC.targetRadioBearerSetupTime.value <= 2000.0
    }
  }

  requirement def PacketDataServiceRequirement {
    doc /*
      The UMTS system shall provide packet-switched data service through the serving GPRS support node and gateway GPRS support node to an external packet data network.
    */
    subject system : UMTSSystem;
    require constraint MinimumPacketRateConstraint {
      in grantedRate = system.nominalUserPacketRate;
      in minimumRate = system.nominalUserPacketRate;
    }
  }

  requirement def VoiceAvailabilityRequirement {
    doc /*
      The UMTS system shall provide mobile voice service with at least 99 percent nominal end-to-end availability.
    */
    subject system : UMTSSystem;
    attribute requiredAvailability : AvailabilityPercent {
      attribute value : Real = 99.0;
      attribute unit : String = "%";
    }
    require constraint MinimumAvailabilityConstraint {
      in availability = system.endToEndVoiceAvailability;
      in minimum = requiredAvailability;
    }
  }

  requirement def InteractiveLatencyRequirement {
    doc /*
      The UMTS system shall support interactive packet service with a nominal one-way latency not exceeding 250 ms.
    */
    subject system : UMTSSystem;
    attribute maximumLatency : Latencyms {
      attribute value : Real = 250.0;
      attribute unit : String = "ms";
    }
    require constraint MaximumLatencyConstraint {
      in latency = system.targetInteractiveLatency;
      in maximum = maximumLatency;
    }
  }

  part operationalUMTS : UMTSSystem;

  requirement primaryFunctionReq : PrimaryUMTSFunctionRequirement {
    subject system = operationalUMTS;
  }

  requirement authenticationReq : AuthenticationRequirement {
    subject system = operationalUMTS;
  }

  requirement radioBearerReq : RadioAccessBearerRequirement {
    subject system = operationalUMTS;
  }

  requirement packetDataReq : PacketDataServiceRequirement {
    subject system = operationalUMTS;
  }

  requirement voiceAvailabilityReq : VoiceAvailabilityRequirement {
    subject system = operationalUMTS;
  }

  requirement interactiveLatencyReq : InteractiveLatencyRequirement {
    subject system = operationalUMTS;
  }

  satisfy primaryFunctionReq by operationalUMTS;
  satisfy authenticationReq by operationalUMTS.coreNetwork.auc;
  satisfy radioBearerReq by operationalUMTS.radioAccessNetwork.servingRNC;
  satisfy packetDataReq by operationalUMTS.coreNetwork.ggsn;
  satisfy voiceAvailabilityReq by operationalUMTS.coreNetwork.msc;
  satisfy interactiveLatencyReq by operationalUMTS.coreNetwork.sgsn;

}
