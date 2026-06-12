package IP500AllianceSystemModel {

  import ScalarValues::*;
  import SI::*;

  attribute def Percent :> Real {
    unit = "%";
  }

  attribute def DecibelMilliwatt :> Real {
    unit = "dBm";
  }

  attribute def Millisecond :> Real {
    unit = "ms";
  }

  attribute def Meter :> Real {
    unit = "m";
  }

  attribute def BitPerSecond :> Real {
    unit = "bit/s";
  }

  item def IPv6Packet {
    attribute sourceAddress : String;
    attribute destinationAddress : String;
    attribute payloadLength : Integer;
    attribute hopLimit : Integer;
    attribute encrypted : Boolean;
  }

  item def BuildingAutomationEvent {
    attribute eventId : String;
    attribute eventType : String;
    attribute priority : Integer;
    attribute timestamp : String;
    attribute acknowledged : Boolean;
  }

  item def SensorMeasurement {
    attribute sensorId : String;
    attribute measuredValue : Real;
    attribute unitName : String;
    attribute confidence : Percent;
    attribute timestamp : String;
  }

  item def ControlCommand {
    attribute commandId : String;
    attribute targetDeviceId : String;
    attribute commandType : String;
    attribute authorized : Boolean;
  }

  port def WirelessIPv6Port {
    in packetIn : IPv6Packet;
    out packetOut : IPv6Packet;
    attribute centerFrequencyMHz : Real;
    attribute transmitPower : DecibelMilliwatt;
    attribute dataRate : BitPerSecond;
  }

  port def SensorPort {
    out measurement : SensorMeasurement;
    out event : BuildingAutomationEvent;
  }

  port def ActuatorPort {
    in command : ControlCommand;
    out event : BuildingAutomationEvent;
  }

  port def BackboneIPv6Port {
    in packetIn : IPv6Packet;
    out packetOut : IPv6Packet;
    attribute linkSpeed : BitPerSecond;
  }

  port def ManagementPort {
    in command : ControlCommand;
    out statusEvent : BuildingAutomationEvent;
  }

  part def IP500AllianceBasedBuildingNetwork {
    attribute primaryFunction : String =
      "Provide interoperable, secure, IPv6-based wireless communication for building automation, safety, security, and monitoring devices.";

    attribute nominalCoverageRadius : Meter = 80.0 [m];
    attribute maximumEndToEndLatency : Millisecond = 500.0 [ms];
    attribute minimumPacketDeliveryRatio : Percent = 99.0 [%];

    port wirelessAccess : WirelessIPv6Port;
    port buildingBackbone : BackboneIPv6Port;
    port management : ManagementPort;

    part gateway : IP500Gateway;
    part coordinator : NetworkCoordinator;
    part securityManager : SecurityManager;
    part routingManager : IPv6RoutingManager;
    part sensors[4] : IP500SensorNode;
    part actuators[3] : IP500ActuatorNode;
    part supervisor : BuildingAutomationSupervisor;

    connect gateway.backbone to buildingBackbone;
    connect gateway.management to management;
    connect gateway.routingControl to routingManager.routingService;
    connect coordinator.securityService to securityManager.securityService;
    connect coordinator.routingService to routingManager.routingService;
    connect supervisor.backbone to gateway.backbone;

    connect sensors[0].wireless to coordinator.meshAccess;
    connect sensors[1].wireless to coordinator.meshAccess;
    connect sensors[2].wireless to coordinator.meshAccess;
    connect sensors[3].wireless to coordinator.meshAccess;

    connect actuators[0].wireless to coordinator.meshAccess;
    connect actuators[1].wireless to coordinator.meshAccess;
    connect actuators[2].wireless to coordinator.meshAccess;

    perform action OperateNetwork;
  }

  part def IP500Gateway {
    attribute deviceId : String;
    attribute supportsIPv6 : Boolean = true;
    attribute supportsSecureCommissioning : Boolean = true;

    port wireless : WirelessIPv6Port;
    port backbone : BackboneIPv6Port;
    port management : ManagementPort;
    port routingControl : ManagementPort;

    perform action TranslateWirelessTrafficToBackbone;
  }

  part def NetworkCoordinator {
    attribute coordinatorId : String;
    attribute meshEnabled : Boolean = true;
    attribute maximumJoinedDevices : Integer = 250;

    port meshAccess : WirelessIPv6Port;
    port securityService : ManagementPort;
    port routingService : ManagementPort;

    perform action CommissionAndMaintainMesh;
  }

  part def SecurityManager {
    attribute authenticationRequired : Boolean = true;
    attribute encryptionRequired : Boolean = true;
    attribute minimumKeyLengthBits : Integer = 128;

    port securityService : ManagementPort;

    perform action AuthenticateDevice;
  }

  part def IPv6RoutingManager {
    attribute routeRepairEnabled : Boolean = true;
    attribute maximumHopCount : Integer = 8;

    port routingService : ManagementPort;

    perform action MaintainIPv6Routes;
  }

  part def IP500SensorNode {
    attribute nodeId : String;
    attribute batteryLevel : Percent;
    attribute reportingIntervalSeconds : Real;
    attribute lowPowerModeEnabled : Boolean = true;

    port wireless : WirelessIPv6Port;
    port sensorInterface : SensorPort;

    part radio : LowPowerIPv6Radio;
    part sensingElement : BuildingSensorElement;
    part localController : EmbeddedNodeController;

    connect radio.airInterface to wireless;
    connect sensingElement.sensorData to sensorInterface;
    connect localController.radioControl to radio.management;

    perform action SenseAndReport;
  }

  part def IP500ActuatorNode {
    attribute nodeId : String;
    attribute failSafeState : String;
    attribute commandTimeout : Millisecond = 1000.0 [ms];

    port wireless : WirelessIPv6Port;
    port actuatorInterface : ActuatorPort;

    part radio : LowPowerIPv6Radio;
    part actuatorDriver : BuildingActuatorDriver;
    part localController : EmbeddedNodeController;

    connect radio.airInterface to wireless;
    connect actuatorDriver.actuatorControl to actuatorInterface;
    connect localController.radioControl to radio.management;

    perform action ReceiveAndExecuteCommand;
  }

  part def LowPowerIPv6Radio {
    attribute receiveSensitivity : DecibelMilliwatt = -100.0 [dBm];
    attribute nominalTransmitPower : DecibelMilliwatt = 10.0 [dBm];
    attribute channelBandwidthKHz : Real = 200.0;

    port airInterface : WirelessIPv6Port;
    port management : ManagementPort;
  }

  part def BuildingSensorElement {
    attribute sensorKind : String;
    attribute accuracy : Percent;
    attribute samplingPeriodSeconds : Real;

    port sensorData : SensorPort;
  }

  part def BuildingActuatorDriver {
    attribute actuatorKind : String;
    attribute currentState : String;

    port actuatorControl : ActuatorPort;
  }

  part def EmbeddedNodeController {
    attribute firmwareVersion : String;
    attribute watchdogEnabled : Boolean = true;

    port radioControl : ManagementPort;
  }

  part def BuildingAutomationSupervisor {
    attribute operatorConsoleEnabled : Boolean = true;
    attribute alarmForwardingEnabled : Boolean = true;

    port backbone : BackboneIPv6Port;

    perform action MonitorBuildingEvents;
  }

  action def OperateNetwork {
    first start;
    then commissionDevices;
    then secureDevices;
    then establishRoutes;
    then monitorTraffic;
    then handleEvents;
    then continueOperation;

    action commissionDevices : CommissionAndMaintainMesh;
    action secureDevices : AuthenticateDevice;
    action establishRoutes : MaintainIPv6Routes;
    action monitorTraffic : MonitorBuildingEvents;
    action handleEvents : RouteEventOrCommand;
  }

  action def CommissionAndMaintainMesh {
    in candidateDeviceId : String;
    out joined : Boolean;
    out assignedIPv6Address : String;
  }

  action def AuthenticateDevice {
    in deviceId : String;
    in credentialValid : Boolean;
    out authenticated : Boolean;
    out sessionKeyEstablished : Boolean;
  }

  action def MaintainIPv6Routes {
    in destinationAddress : String;
    out nextHopAddress : String;
    out routeAvailable : Boolean;
  }

  action def SenseAndReport {
    out measurement : SensorMeasurement;
    out event : BuildingAutomationEvent;
  }

  action def ReceiveAndExecuteCommand {
    in command : ControlCommand;
    out executed : Boolean;
    out statusEvent : BuildingAutomationEvent;
  }

  action def TranslateWirelessTrafficToBackbone {
    in wirelessPacket : IPv6Packet;
    out backbonePacket : IPv6Packet;
  }

  action def MonitorBuildingEvents {
    in event : BuildingAutomationEvent;
    out alarmRaised : Boolean;
  }

  action def RouteEventOrCommand {
    in packet : IPv6Packet;
    out forwardedPacket : IPv6Packet;
  }

  state def NetworkOperationalState {
    entry action initializeNetwork : CommissionAndMaintainMesh;

    state Offline;
    state Commissioning;
    state Securing;
    state RoutingReady;
    state NormalOperation;
    state DegradedOperation;
    state Maintenance;

    transition first Offline;

    transition Offline_to_Commissioning
      first Offline
      then Commissioning;

    transition Commissioning_to_Securing
      first Commissioning
      then Securing;

    transition Securing_to_RoutingReady
      first Securing
      then RoutingReady;

    transition RoutingReady_to_NormalOperation
      first RoutingReady
      then NormalOperation;

    transition NormalOperation_to_DegradedOperation
      first NormalOperation
      then DegradedOperation;

    transition DegradedOperation_to_NormalOperation
      first DegradedOperation
      then NormalOperation;

    transition NormalOperation_to_Maintenance
      first NormalOperation
      then Maintenance;

    transition Maintenance_to_NormalOperation
      first Maintenance
      then NormalOperation;
  }

  requirement def PrimaryFunctionRequirement {
    subject network : IP500AllianceBasedBuildingNetwork;

    require constraint {
      network.primaryFunction ==
      "Provide interoperable, secure, IPv6-based wireless communication for building automation, safety, security, and monitoring devices."
    }
  }

  requirement def IPv6InteroperabilityRequirement {
    subject network : IP500AllianceBasedBuildingNetwork;

    require constraint {
      network.gateway.supportsIPv6 == true
    }
  }

  requirement def SecurityRequirement {
    subject network : IP500AllianceBasedBuildingNetwork;

    require constraint {
      network.securityManager.authenticationRequired == true and
      network.securityManager.encryptionRequired == true and
      network.securityManager.minimumKeyLengthBits >= 128
    }
  }

  requirement def LatencyRequirement {
    subject network : IP500AllianceBasedBuildingNetwork;

    require constraint {
      network.maximumEndToEndLatency <= 500.0 [ms]
    }
  }

  requirement def ReliabilityRequirement {
    subject network : IP500AllianceBasedBuildingNetwork;

    require constraint {
      network.minimumPacketDeliveryRatio >= 99.0 [%]
    }
  }

  requirement def MeshCapacityRequirement {
    subject network : IP500AllianceBasedBuildingNetwork;

    require constraint {
      network.coordinator.maximumJoinedDevices >= 250
    }
  }

  requirement def RouteResilienceRequirement {
    subject network : IP500AllianceBasedBuildingNetwork;

    require constraint {
      network.routingManager.routeRepairEnabled == true and
      network.routingManager.maximumHopCount <= 8
    }
  }

  part ip500AllianceBuildingCommunicationSystem : IP500AllianceBasedBuildingNetwork {
    attribute primaryFunction =
      "Provide interoperable, secure, IPv6-based wireless communication for building automation, safety, security, and monitoring devices.";

    attribute nominalCoverageRadius = 80.0 [m];
    attribute maximumEndToEndLatency = 500.0 [ms];
    attribute minimumPacketDeliveryRatio = 99.0 [%];

    part gateway {
      attribute deviceId = "IP500-GW-001";
    }

    part coordinator {
      attribute coordinatorId = "IP500-COORD-001";
      attribute maximumJoinedDevices = 250;
    }

    part securityManager {
      attribute minimumKeyLengthBits = 128;
    }

    part routingManager {
      attribute maximumHopCount = 8;
    }
  }

}