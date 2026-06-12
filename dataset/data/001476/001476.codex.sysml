package InternetBasedInformationExchangeSystem {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  attribute def Latency {
    :> scalarValues::Real;
    unit = "ms";
  }

  attribute def DataRate {
    :> scalarValues::Real;
    unit = "Mb/s";
  }

  attribute def Availability {
    :> scalarValues::Real;
    unit = "%";
  }

  attribute def PacketCount {
    :> scalarValues::Integer;
    unit = "packet";
  }

  attribute def ByteCount {
    :> scalarValues::Integer;
    unit = "byte";
  }

  enum def ProtocolKind {
    enum http;
    enum https;
    enum dns;
    enum tcp;
    enum udp;
    enum bgp;
    enum icmp;
  }

  enum def SecurityClassification {
    enum public;
    enum internal;
    enum confidential;
    enum restricted;
  }

  enum def ServiceHealth {
    enum healthy;
    enum degraded;
    enum unavailable;
  }

  item def UserRequest {
    attribute requestId : String;
    attribute sourceAddress : String;
    attribute targetUri : String;
    attribute protocol : ProtocolKind;
    attribute payloadSize : ByteCount;
    attribute classification : SecurityClassification;
  }

  item def UserResponse {
    attribute requestId : String;
    attribute statusCode : Integer;
    attribute payloadSize : ByteCount;
    attribute responseLatency : Latency;
    attribute cacheHit : Boolean;
  }

  item def DnsQuery {
    attribute domainName : String;
    attribute queryType : String;
  }

  item def DnsAnswer {
    attribute domainName : String;
    attribute resolvedAddress : String;
    attribute ttlSeconds : Integer;
  }

  item def IpPacket {
    attribute sourceAddress : String;
    attribute destinationAddress : String;
    attribute protocol : ProtocolKind;
    attribute payloadSize : ByteCount;
    attribute hopLimit : Integer;
  }

  item def TelemetryRecord {
    attribute timestampUtc : String;
    attribute observedLatency : Latency;
    attribute packetLossPercent : Real;
    attribute throughput : DataRate;
    attribute health : ServiceHealth;
  }

  port def RequestPort {
    in item request : UserRequest;
    out item response : UserResponse;
  }

  port def PacketPort {
    inout item packet : IpPacket;
  }

  port def DnsPort {
    out item query : DnsQuery;
    in item answer : DnsAnswer;
  }

  port def TelemetryPort {
    out item record : TelemetryRecord;
  }

  part def ClientDevice {
    attribute assignedAddress : String;
    attribute maximumUplinkRate : DataRate = 100.0;
    attribute maximumDownlinkRate : DataRate = 1000.0;

    port applicationAccess : RequestPort;
    port networkInterface : PacketPort;
    port nameResolution : DnsPort;

    action requestInternetResource {
      in item desiredRequest : UserRequest;
      out item receivedResponse : UserResponse;

      first start;
      then resolveName;
      then openSecureSession;
      then sendRequest;
      then receiveResponse;
      then validateResponse;
      then done;

      action resolveName;
      action openSecureSession;
      action sendRequest;
      action receiveResponse;
      action validateResponse;
    }
  }

  part def AccessNetwork {
    attribute accessTechnology : String;
    attribute subscriberCapacity : Integer;
    attribute nominalLatency : Latency = 15.0;
    attribute availableBandwidth : DataRate = 1000.0;

    port customerSide : PacketPort;
    port providerSide : PacketPort;
    port telemetry : TelemetryPort;
  }

  part def EdgeRouter {
    attribute routerId : String;
    attribute forwardingCapacity : DataRate = 100000.0;
    attribute packetBufferCapacity : PacketCount = 1000000;

    port accessFacing : PacketPort;
    port internetFacing : PacketPort;
    port telemetry : TelemetryPort;

    state def RouterOperationalState {
      state initializing;
      state forwarding;
      state congested;
      state failed;

      transition first initializing then forwarding;
      transition forwarding then congested
        if packetBufferCapacity < 10000;
      transition congested then forwarding
        if packetBufferCapacity >= 10000;
      transition forwarding then failed
        if forwardingCapacity == 0.0;
      transition congested then failed
        if forwardingCapacity == 0.0;
    }

    state routerState : RouterOperationalState;
  }

  part def DomainNameService {
    attribute authoritativeZoneCount : Integer;
    attribute averageResolutionLatency : Latency = 20.0;
    attribute serviceAvailability : Availability = 99.99;

    port resolverInterface : DnsPort;
    port networkInterface : PacketPort;
    port telemetry : TelemetryPort;

    action resolveDomainName {
      in item query : DnsQuery;
      out item answer : DnsAnswer;

      first receiveQuery;
      then searchCache;
      then queryAuthority;
      then returnAnswer;
      then done;

      action receiveQuery;
      action searchCache;
      action queryAuthority;
      action returnAnswer;
    }
  }

  part def InternetBackbone {
    attribute autonomousSystemCount : Integer = 75000;
    attribute backboneCapacity : DataRate = 10000000.0;
    attribute medianTransitLatency : Latency = 35.0;
    attribute availabilityTarget : Availability = 99.95;

    port ingress : PacketPort;
    port egress : PacketPort;
    port telemetry : TelemetryPort;

    action routePacketAcrossAutonomousSystems {
      in item inboundPacket : IpPacket;
      out item outboundPacket : IpPacket;

      first inspectDestination;
      then selectBestPath;
      then forwardByPolicy;
      then decrementHopLimit;
      then emitPacket;
      then done;

      action inspectDestination;
      action selectBestPath;
      action forwardByPolicy;
      action decrementHopLimit;
      action emitPacket;
    }
  }

  part def CloudServiceEndpoint {
    attribute serviceName : String;
    attribute publicAddress : String;
    attribute maximumRequestRatePerSecond : Integer = 250000;
    attribute nominalResponseLatency : Latency = 80.0;
    attribute serviceAvailability : Availability = 99.9;

    port publicNetworkInterface : PacketPort;
    port serviceInterface : RequestPort;
    port telemetry : TelemetryPort;

    action processUserRequest {
      in item request : UserRequest;
      out item response : UserResponse;

      first authenticateTransport;
      then authorizeRequest;
      then executeApplicationLogic;
      then prepareResponse;
      then transmitResponse;
      then done;

      action authenticateTransport;
      action authorizeRequest;
      action executeApplicationLogic;
      action prepareResponse;
      action transmitResponse;
    }

    state def EndpointHealthState {
      state online;
      state overloaded;
      state maintenance;
      state offline;

      transition first online;
      transition online then overloaded
        if maximumRequestRatePerSecond < 10000;
      transition overloaded then online
        if maximumRequestRatePerSecond >= 10000;
      transition online then maintenance;
      transition maintenance then online;
      transition online then offline
        if serviceAvailability < 90.0;
      transition overloaded then offline
        if serviceAvailability < 90.0;
    }

    state endpointHealth : EndpointHealthState;
  }

  part def MonitoringAndControlPlane {
    attribute telemetryRetentionDays : Integer = 30;
    attribute alertLatencyThreshold : Latency = 250.0;
    attribute minimumAvailabilityThreshold : Availability = 99.0;

    port accessTelemetry : TelemetryPort;
    port routerTelemetry : TelemetryPort;
    port backboneTelemetry : TelemetryPort;
    port dnsTelemetry : TelemetryPort;
    port endpointTelemetry : TelemetryPort;

    action evaluateInternetServiceHealth {
      in item accessRecord : TelemetryRecord;
      in item routerRecord : TelemetryRecord;
      in item backboneRecord : TelemetryRecord;
      in item dnsRecord : TelemetryRecord;
      in item endpointRecord : TelemetryRecord;
      out attribute aggregateHealth : ServiceHealth;

      first collectTelemetry;
      then correlateSymptoms;
      then classifyHealth;
      then publishOperationalStatus;
      then done;

      action collectTelemetry;
      action correlateSymptoms;
      action classifyHealth;
      action publishOperationalStatus;
    }
  }

  part def InternetBasedServiceSystem {
    attribute primaryFunction : String =
      "Provide users with reliable, secure, routed access to remote digital services by resolving names, transporting packets across interconnected networks, and returning application responses.";
    attribute endToEndLatencyObjective : Latency = 200.0;
    attribute minimumUserThroughput : DataRate = 25.0;
    attribute targetAvailability : Availability = 99.9;

    part client : ClientDevice {
      assignedAddress = "192.0.2.25";
    }

    part accessNetwork : AccessNetwork {
      accessTechnology = "fiber broadband";
      subscriberCapacity = 50000;
    }

    part edgeRouter : EdgeRouter {
      routerId = "edge-router-01";
    }

    part dns : DomainNameService {
      authoritativeZoneCount = 1000000;
    }

    part backbone : InternetBackbone;

    part cloudEndpoint : CloudServiceEndpoint {
      serviceName = "Public Information Service";
      publicAddress = "203.0.113.80";
    }

    part monitoring : MonitoringAndControlPlane;

    connect client.networkInterface to accessNetwork.customerSide;
    connect accessNetwork.providerSide to edgeRouter.accessFacing;
    connect edgeRouter.internetFacing to backbone.ingress;
    connect backbone.egress to cloudEndpoint.publicNetworkInterface;
    connect client.nameResolution to dns.resolverInterface;

    connect accessNetwork.telemetry to monitoring.accessTelemetry;
    connect edgeRouter.telemetry to monitoring.routerTelemetry;
    connect backbone.telemetry to monitoring.backboneTelemetry;
    connect dns.telemetry to monitoring.dnsTelemetry;
    connect cloudEndpoint.telemetry to monitoring.endpointTelemetry;

    flow client.applicationAccess.request to cloudEndpoint.serviceInterface.request;
    flow cloudEndpoint.serviceInterface.response to client.applicationAccess.response;

    action provideInternetBasedInformationAccess {
      in item userRequest : UserRequest;
      out item userResponse : UserResponse;

      first acceptUserRequest;
      then resolveServiceName;
      then encapsulateAsPackets;
      then routeAcrossInternet;
      then processAtServiceEndpoint;
      then returnResponsePackets;
      then presentResponseToUser;
      then done;

      action acceptUserRequest;
      action resolveServiceName;
      action encapsulateAsPackets;
      action routeAcrossInternet;
      action processAtServiceEndpoint;
      action returnResponsePackets;
      action presentResponseToUser;
    }

    state def SystemOperationalState {
      state starting;
      state available;
      state degraded;
      state unavailable;

      transition first starting then available;
      transition available then degraded
        if endToEndLatencyObjective > 200.0;
      transition degraded then available
        if endToEndLatencyObjective <= 200.0;
      transition available then unavailable
        if targetAvailability < 95.0;
      transition degraded then unavailable
        if targetAvailability < 95.0;
      transition unavailable then degraded
        if targetAvailability >= 95.0;
    }

    state systemState : SystemOperationalState;
  }

  requirement def PrimaryFunctionRequirement {
    doc
    /*
     * The system shall provide high-level Internet-based information access
     * by accepting a user request, resolving the destination name, routing data
     * through interconnected networks, invoking a remote service, and returning
     * a response to the requesting user.
     */
    subject system : InternetBasedServiceSystem;
    require constraint {
      system.primaryFunction != "";
    }
  }

  requirement def LatencyRequirement {
    subject system : InternetBasedServiceSystem;
    require constraint {
      system.endToEndLatencyObjective <= 200.0;
    }
  }

  requirement def ThroughputRequirement {
    subject system : InternetBasedServiceSystem;
    require constraint {
      system.minimumUserThroughput >= 25.0;
    }
  }

  requirement def AvailabilityRequirement {
    subject system : InternetBasedServiceSystem;
    require constraint {
      system.targetAvailability >= 99.9;
    }
  }

  requirement def SecureProtocolRequirement {
    subject request : UserRequest;
    require constraint {
      request.protocol == ProtocolKind::https;
    }
  }

  requirement def NameResolutionRequirement {
    subject dnsService : DomainNameService;
    require constraint {
      dnsService.averageResolutionLatency <= 50.0;
    }
  }

  requirement def MonitoringRequirement {
    subject controlPlane : MonitoringAndControlPlane;
    require constraint {
      controlPlane.telemetryRetentionDays >= 30;
    }
  }

  part internetService : InternetBasedServiceSystem;

  satisfy PrimaryFunctionRequirement by internetService;
  satisfy LatencyRequirement by internetService;
  satisfy ThroughputRequirement by internetService;
  satisfy AvailabilityRequirement by internetService;
}