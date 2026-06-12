package HomePNAHighLevelSystem {
  import ScalarValues::*;

  enum def LinkState {
    enum idle;
    enum training;
    enum active;
    enum degraded;
    enum faulted;
  }

  enum def MediumKind {
    enum phoneline;
    enum coaxialCable;
    enum mixedPremiseWiring;
  }

  enum def TrafficClass {
    enum voice;
    enum video;
    enum bestEffortData;
    enum management;
  }

  attribute def DataRateMbps : Real {
    doc /* Megabits per second. */
  }

  attribute def FrequencyMHz : Real {
    doc /* Megahertz. */
  }

  attribute def PowerdBm : Real {
    doc /* Decibels referenced to one milliwatt. */
  }

  attribute def LengthMeters : Real {
    doc /* Meters. */
  }

  attribute def LatencyMs : Real {
    doc /* Milliseconds. */
  }

  attribute def Percent : Real {
    doc /* Percentage from 0 to 100. */
  }

  item def EthernetFrame {
    attribute sourceMac : String;
    attribute destinationMac : String;
    attribute payloadBytes : Integer;
    attribute trafficClass : TrafficClass;
  }

  item def HomePNASymbolStream {
    attribute channelFrequency : FrequencyMHz;
    attribute encodedBitRate : DataRateMbps;
    attribute transmitPower : PowerdBm;
    attribute linkState : LinkState;
  }

  item def ManagementMessage {
    attribute nodeId : String;
    attribute messageType : String;
    attribute sequenceNumber : Integer;
  }

  port def EthernetPort {
    in item rxFrame : EthernetFrame;
    out item txFrame : EthernetFrame;
  }

  port def HomePNALinePort {
    in item receivedSymbols : HomePNASymbolStream;
    out item transmittedSymbols : HomePNASymbolStream;
    in item controlIn : ManagementMessage;
    out item controlOut : ManagementMessage;
  }

  port def ServiceStatusPort {
    out attribute linkState : LinkState;
    out attribute aggregateThroughput : DataRateMbps;
    out attribute packetLoss : Percent;
  }

  interface def EthernetToHomePNA {
    end ethernet : EthernetPort;
    end hpna : HomePNALinePort;
  }

  interface def SharedHomePNAMedium {
    end nodeA : HomePNALinePort;
    end nodeB : HomePNALinePort;
  }

  action def ClassifyTraffic {
    in item frame : EthernetFrame;
    out attribute selectedClass : TrafficClass;
  }

  action def EncapsulateEthernetFrame {
    in item frame : EthernetFrame;
    in attribute selectedClass : TrafficClass;
    out item symbols : HomePNASymbolStream;
  }

  action def DecodeHomePNAStream {
    in item symbols : HomePNASymbolStream;
    out item frame : EthernetFrame;
  }

  action def ScheduleSharedMediumAccess {
    in attribute requestedRate : DataRateMbps;
    in attribute trafficClass : TrafficClass;
    out attribute grantedRate : DataRateMbps;
  }

  action def MonitorLineQuality {
    in item symbols : HomePNASymbolStream;
    out attribute signalToNoiseRatio : Real;
    out attribute errorRate : Percent;
    out attribute assessedState : LinkState;
  }

  state def HomePNALinkLifecycle {
    state poweredOff;
    state initializing;
    state discoveringNodes;
    state trainingPhysicalLayer;
    state forwardingTraffic;
    state degradedService;
    state faultIsolation;

    transition powerApplied first poweredOff then initializing;
    transition initializationComplete first initializing then discoveringNodes;
    transition nodesDiscovered first discoveringNodes then trainingPhysicalLayer;
    transition linkTrained first trainingPhysicalLayer then forwardingTraffic;
    transition qualityReduced first forwardingTraffic then degradedService;
    transition qualityRecovered first degradedService then forwardingTraffic;
    transition unrecoverableError first forwardingTraffic then faultIsolation;
    transition degradedFault first degradedService then faultIsolation;
    transition resetCommanded first faultIsolation then initializing;
  }

  part def HomePNAModem {
    attribute nodeId : String;
    attribute supportedMaximumRate : DataRateMbps = 320.0;
    attribute operatingFrequencyLow : FrequencyMHz = 4.0;
    attribute operatingFrequencyHigh : FrequencyMHz = 28.0;
    attribute transmitPowerLimit : PowerdBm = 17.0;
    attribute currentLinkState : LinkState = LinkState::idle;

    port ethernet : EthernetPort;
    port line : HomePNALinePort;
    port status : ServiceStatusPort;

    perform action classify : ClassifyTraffic;
    perform action encapsulate : EncapsulateEthernetFrame;
    perform action decode : DecodeHomePNAStream;
    perform action monitor : MonitorLineQuality;

    exhibit state linkLifecycle : HomePNALinkLifecycle;
  }

  part def ResidentialGateway {
    attribute managementAddress : String;
    attribute dhcpEnabled : Boolean = true;
    attribute natEnabled : Boolean = true;

    port wanEthernet : EthernetPort;
    port localEthernet : EthernetPort;
    port hpnaLine : HomePNALinePort;
    port status : ServiceStatusPort;

    part hpnaBridge : HomePNAModem {
      attribute nodeId = "gateway-hpna-bridge";
      attribute supportedMaximumRate = 320.0;
    }
  }

  part def HomePNAEndpointAdapter {
    attribute roomName : String;
    attribute attachedDeviceType : String;

    port deviceEthernet : EthernetPort;
    port hpnaLine : HomePNALinePort;
    port status : ServiceStatusPort;

    part hpnaModem : HomePNAModem {
      attribute supportedMaximumRate = 320.0;
    }
  }

  part def PremiseWiringMedium {
    attribute mediumKind : MediumKind = MediumKind::mixedPremiseWiring;
    attribute totalLength : LengthMeters = 120.0;
    attribute branchCount : Integer = 6;
    attribute nominalImpedanceOhms : Real = 100.0;
    attribute insertionLossPercent : Percent = 8.0;

    port gatewayTap : HomePNALinePort;
    port livingRoomTap : HomePNALinePort;
    port officeTap : HomePNALinePort;
    port bedroomTap : HomePNALinePort;
  }

  part def HomePNANetworkController {
    attribute minimumReservedVoiceRate : DataRateMbps = 1.0;
    attribute minimumReservedVideoRate : DataRateMbps = 25.0;
    attribute maximumBestEffortLatency : LatencyMs = 20.0;
    attribute targetPacketLoss : Percent = 0.1;

    port controlLine : HomePNALinePort;
    port status : ServiceStatusPort;

    perform action scheduler : ScheduleSharedMediumAccess;
    perform action monitor : MonitorLineQuality;
  }

  part def HomePNABasedHomeNetworkingSystem {
    doc /*
      Primary function: provide high-speed in-home data networking over existing telephone or coaxial premise wiring by bridging Ethernet traffic between a residential gateway and endpoint adapters without requiring new dedicated network cabling.
    */

    attribute systemName : String = "HomePNA-Based Residential Networking System";
    attribute aggregateNominalRate : DataRateMbps = 320.0;
    attribute maximumOneWayLatency : LatencyMs = 20.0;
    attribute supportedNodeCount : Integer = 16;

    port internetAccess : EthernetPort;
    port serviceStatus : ServiceStatusPort;

    part gateway : ResidentialGateway {
      attribute managementAddress = "192.168.1.1";
    }

    part wiring : PremiseWiringMedium {
      attribute mediumKind = MediumKind::mixedPremiseWiring;
      attribute totalLength = 120.0;
    }

    part controller : HomePNANetworkController;

    part livingRoomAdapter : HomePNAEndpointAdapter {
      attribute roomName = "Living Room";
      attribute attachedDeviceType = "IPTV Receiver";
    }

    part officeAdapter : HomePNAEndpointAdapter {
      attribute roomName = "Office";
      attribute attachedDeviceType = "Desktop Computer";
    }

    part bedroomAdapter : HomePNAEndpointAdapter {
      attribute roomName = "Bedroom";
      attribute attachedDeviceType = "Voice-over-IP Phone";
    }

    connect internetAccess to gateway.wanEthernet;
    connect gateway.hpnaLine to wiring.gatewayTap;
    connect controller.controlLine to wiring.gatewayTap;
    connect livingRoomAdapter.hpnaLine to wiring.livingRoomTap;
    connect officeAdapter.hpnaLine to wiring.officeTap;
    connect bedroomAdapter.hpnaLine to wiring.bedroomTap;
    connect gateway.status to serviceStatus;
  }

  requirement def ProvideNetworkingOverExistingWiring {
    doc /*
      The system shall transport Ethernet data between the residential gateway and endpoint adapters using existing in-home telephone or coaxial wiring as the physical communication medium.
    */

    subject system : HomePNABasedHomeNetworkingSystem;

    require constraint {
      system.wiring.totalLength <= 300.0
    }
  }

  requirement def SupportHighLevelPrimaryFunction {
    doc /*
      The system shall provide the high-level function of bridging user data, voice, video, and management traffic across a shared HomePNA physical layer.
    */

    subject system : HomePNABasedHomeNetworkingSystem;

    require constraint {
      system.supportedNodeCount >= 4
    }
  }

  requirement def MaintainThroughput {
    doc /*
      The system shall support an aggregate nominal HomePNA data rate sufficient for simultaneous video, voice, and best-effort data services.
    */

    subject system : HomePNABasedHomeNetworkingSystem;

    require constraint {
      system.aggregateNominalRate >= 128.0
    }
  }

  requirement def BoundLatency {
    doc /*
      The system shall maintain one-way latency low enough to support interactive voice and video services.
    */

    subject system : HomePNABasedHomeNetworkingSystem;

    require constraint {
      system.maximumOneWayLatency <= 20.0
    }
  }

  requirement def PrioritizeRealTimeTraffic {
    doc /*
      The system shall prioritize voice and video traffic over best-effort data traffic when the shared HomePNA medium is congested.
    */

    subject controller : HomePNANetworkController;

    require constraint {
      controller.minimumReservedVoiceRate >= 1.0 and
      controller.minimumReservedVideoRate >= 25.0
    }
  }

  requirement def ReportOperationalStatus {
    doc /*
      The system shall expose current link state, aggregate throughput, and packet loss to management functions.
    */

    subject system : HomePNABasedHomeNetworkingSystem;

    require constraint {
      system.controller.targetPacketLoss <= 0.1
    }
  }

  satisfy ProvideNetworkingOverExistingWiring by HomePNABasedHomeNetworkingSystem;
  satisfy SupportHighLevelPrimaryFunction by HomePNABasedHomeNetworkingSystem;
  satisfy MaintainThroughput by HomePNABasedHomeNetworkingSystem;
  satisfy BoundLatency by HomePNABasedHomeNetworkingSystem;
  satisfy PrioritizeRealTimeTraffic by HomePNANetworkController;
  satisfy ReportOperationalStatus by HomePNABasedHomeNetworkingSystem;
}