package MyriaNedHighLevelModel {

  import ScalarValues::*;
  import SI::*;

  attribute def Voltage {
    attribute value : Real;
    attribute unit : String = "V";
  }

  attribute def Current {
    attribute value : Real;
    attribute unit : String = "mA";
  }

  attribute def Power {
    attribute value : Real;
    attribute unit : String = "mW";
  }

  attribute def Energy {
    attribute value : Real;
    attribute unit : String = "J";
  }

  attribute def Frequency {
    attribute value : Real;
    attribute unit : String = "MHz";
  }

  attribute def DataRate {
    attribute value : Real;
    attribute unit : String = "kbps";
  }

  attribute def TimeDuration {
    attribute value : Real;
    attribute unit : String = "ms";
  }

  attribute def Temperature {
    attribute value : Real;
    attribute unit : String = "degC";
  }

  attribute def RelativeHumidity {
    attribute value : Real;
    attribute unit : String = "%RH";
  }

  attribute def Illuminance {
    attribute value : Real;
    attribute unit : String = "lx";
  }

  attribute def LinkQuality {
    attribute value : Real;
    attribute unit : "%";
  }

  attribute def HopCount {
    attribute value : Integer;
    attribute unit : String = "hop";
  }

  enum def NodeRole {
    enum sensingNode;
    enum actuatorNode;
    enum gatewayNode;
    enum repeaterNode;
  }

  enum def PacketClass {
    enum sensorSample;
    enum actuatorCommand;
    enum neighborBeacon;
    enum networkHealth;
    enum configurationUpdate;
    enum acknowledgement;
  }

  item def SensorSample {
    attribute sourceNodeId : Integer;
    attribute sequenceNumber : Integer;
    attribute sampleTime : TimeDuration;
    attribute temperature : Temperature;
    attribute humidity : RelativeHumidity;
    attribute illuminance : Illuminance;
    attribute batteryVoltage : Voltage;
  }

  item def ActuatorCommand {
    attribute targetNodeId : Integer;
    attribute sequenceNumber : Integer;
    attribute commandName : String;
    attribute commandValue : Real;
    attribute commandTimeout : TimeDuration;
  }

  item def NeighborBeacon {
    attribute sourceNodeId : Integer;
    attribute role : NodeRole;
    attribute batteryVoltage : Voltage;
    attribute linkQualityEstimate : LinkQuality;
    attribute advertisedHopCountToGateway : HopCount;
  }

  item def NetworkPacket {
    attribute packetClass : PacketClass;
    attribute sourceNodeId : Integer;
    attribute destinationNodeId : Integer;
    attribute networkId : Integer;
    attribute sequenceNumber : Integer;
    attribute timeToLive : HopCount;
    attribute receivedSignalQuality : LinkQuality;
  }

  item def NetworkHealthReport {
    attribute nodeId : Integer;
    attribute neighborCount : Integer;
    attribute packetForwardCount : Integer;
    attribute packetDropCount : Integer;
    attribute averageLinkQuality : LinkQuality;
    attribute remainingEnergy : Energy;
  }

  port def WirelessMeshPort {
    out item transmittedPacket : NetworkPacket;
    in item receivedPacket : NetworkPacket;
    out item beaconOut : NeighborBeacon;
    in item beaconIn : NeighborBeacon;
  }

  port def SensorPort {
    out item sample : SensorSample;
  }

  port def ActuatorPort {
    in item command : ActuatorCommand;
  }

  port def BackhaulPort {
    out item uplinkPacket : NetworkPacket;
    out item healthReport : NetworkHealthReport;
    in item downlinkCommand : ActuatorCommand;
  }

  part def MyriaNedRadio {
    attribute carrierFrequency : Frequency = (value = 868.0, unit = "MHz");
    attribute nominalDataRate : DataRate = (value = 19.2, unit = "kbps");
    attribute transmitPower : Power = (value = 10.0, unit = "mW");
    attribute receiveCurrent : Current = (value = 18.0, unit = "mA");
    attribute transmitCurrent : Current = (value = 24.0, unit = "mA");
    attribute wakeupInterval : TimeDuration = (value = 250.0, unit = "ms");

    port mesh : WirelessMeshPort;
  }

  part def EnvironmentalSensorSet {
    attribute temperatureAccuracy : Temperature = (value = 0.5, unit = "degC");
    attribute humidityAccuracy : RelativeHumidity = (value = 3.0, unit = "%RH");
    attribute lightRange : Illuminance = (value = 10000.0, unit = "lx");

    port sensedData : SensorPort;
  }

  part def LocalActuator {
    attribute maximumCommandLatency : TimeDuration = (value = 1000.0, unit = "ms");
    port commandInput : ActuatorPort;
  }

  part def BatteryPowerUnit {
    attribute nominalVoltage : Voltage = (value = 3.0, unit = "V");
    attribute storedEnergy : Energy = (value = 18000.0, unit = "J");
    attribute sleepCurrent : Current = (value = 0.02, unit = "mA");
  }

  part def MeshProtocolController {
    attribute networkId : Integer;
    attribute nodeId : Integer;
    attribute role : NodeRole;
    attribute maximumRetransmissions : Integer = 3;
    attribute duplicateCacheDepth : Integer = 32;
    attribute defaultTimeToLive : HopCount = (value = 8, unit = "hop");
    attribute beaconPeriod : TimeDuration = (value = 5000.0, unit = "ms");

    port meshAccess : WirelessMeshPort;
    port sensorInput : SensorPort;
    port actuatorOutput : ActuatorPort;
    port gatewayBackhaul : BackhaulPort;
  }

  part def MyriaNedNode {
    attribute nodeId : Integer;
    attribute role : NodeRole;
    attribute samplePeriod : TimeDuration = (value = 60000.0, unit = "ms");

    part radio : MyriaNedRadio;
    part protocol : MeshProtocolController;
    part sensors : EnvironmentalSensorSet;
    part actuator : LocalActuator;
    part battery : BatteryPowerUnit;

    port mesh : WirelessMeshPort;
    port sensedData : SensorPort;
    port commandInput : ActuatorPort;

    connect radio.mesh to protocol.meshAccess;
    connect sensors.sensedData to protocol.sensorInput;
    connect protocol.actuatorOutput to actuator.commandInput;
    connect mesh to radio.mesh;
    connect sensedData to sensors.sensedData;
    connect commandInput to actuator.commandInput;
  }

  part def MyriaNedGateway {
    attribute gatewayNodeId : Integer = 1;
    attribute networkId : Integer;
    attribute backhaulLatencyBudget : TimeDuration = (value = 2000.0, unit = "ms");

    part radio : MyriaNedRadio;
    part protocol : MeshProtocolController;

    port mesh : WirelessMeshPort;
    port backhaul : BackhaulPort;

    connect mesh to radio.mesh;
    connect radio.mesh to protocol.meshAccess;
    connect protocol.gatewayBackhaul to backhaul;
  }

  part def ApplicationServer {
    attribute retainedSampleWindow : TimeDuration = (value = 86400000.0, unit = "ms");
    attribute commandAuditWindow : TimeDuration = (value = 2592000000.0, unit = "ms");

    port networkInterface : BackhaulPort;
  }

  part def MyriaNedBasedSystem {
    doc /* Primary function: provide a low-power, self-organizing wireless mesh that gathers distributed sensor measurements, disseminates actuator commands, and forwards network health information between field nodes and an application server without relying on fixed routing infrastructure. */

    attribute networkId : Integer = 1001;
    attribute operatingFrequency : Frequency = (value = 868.0, unit = "MHz");
    attribute nominalMeshDataRate : DataRate = (value = 19.2, unit = "kbps");
    attribute requiredCoverageHopDepth : HopCount = (value = 6, unit = "hop");
    attribute maximumEndToEndLatency : TimeDuration = (value = 10000.0, unit = "ms");

    part gateway : MyriaNedGateway {
      attribute networkId = 1001;
    }

    part server : ApplicationServer;

    part sensorNodeA : MyriaNedNode {
      attribute nodeId = 11;
      attribute role = NodeRole::sensingNode;
    }

    part sensorNodeB : MyriaNedNode {
      attribute nodeId = 12;
      attribute role = NodeRole::sensingNode;
    }

    part actuatorNodeA : MyriaNedNode {
      attribute nodeId = 21;
      attribute role = NodeRole::actuatorNode;
    }

    part repeaterNodeA : MyriaNedNode {
      attribute nodeId = 31;
      attribute role = NodeRole::repeaterNode;
    }

    connect gateway.backhaul to server.networkInterface;

    connect sensorNodeA.mesh to repeaterNodeA.mesh;
    connect sensorNodeB.mesh to repeaterNodeA.mesh;
    connect actuatorNodeA.mesh to repeaterNodeA.mesh;
    connect repeaterNodeA.mesh to gateway.mesh;
    connect sensorNodeA.mesh to sensorNodeB.mesh;
    connect sensorNodeB.mesh to actuatorNodeA.mesh;
  }

  action def SenseEnvironment {
    in attribute nodeId : Integer;
    out item sample : SensorSample;
  }

  action def PackageSensorSample {
    in item sample : SensorSample;
    in attribute networkId : Integer;
    out item packet : NetworkPacket;
  }

  action def BroadcastPacket {
    in item packet : NetworkPacket;
    out item transmittedPacket : NetworkPacket;
  }

  action def ReceivePacket {
    in item receivedPacket : NetworkPacket;
    out item acceptedPacket : NetworkPacket;
  }

  action def FilterDuplicatePacket {
    in item acceptedPacket : NetworkPacket;
    out item newPacket : NetworkPacket;
  }

  action def ForwardPacket {
    in item newPacket : NetworkPacket;
    out item forwardedPacket : NetworkPacket;
  }

  action def DeliverCommand {
    in item commandPacket : NetworkPacket;
    out item command : ActuatorCommand;
  }

  action def ReportNetworkHealth {
    in attribute nodeId : Integer;
    out item healthReport : NetworkHealthReport;
  }

  action def MyriaNedPrimaryFunction {
    in attribute activeNetworkId : Integer;
    out item deliveredSample : SensorSample;
    out item deliveredHealth : NetworkHealthReport;

    first start;
    then sense : SenseEnvironment;
    then package : PackageSensorSample;
    then broadcast : BroadcastPacket;
    then receive : ReceivePacket;
    then filter : FilterDuplicatePacket;
    then forward : ForwardPacket;
    then report : ReportNetworkHealth;
    then done;

    flow sense.sample to package.sample;
    flow package.packet to broadcast.packet;
    flow broadcast.transmittedPacket to receive.receivedPacket;
    flow receive.acceptedPacket to filter.acceptedPacket;
    flow filter.newPacket to forward.newPacket;
    flow report.healthReport to deliveredHealth;
  }

  state def NodeOperatingState {
    entry action InitializeNode;

    state booting;
    state discoveringNeighbors;
    state synchronizedSleep;
    state sensing;
    state transmitting;
    state receiving;
    state forwarding;
    state actuating;
    state reportingHealth;
    state lowEnergySafeMode;

    transition first booting;
    transition booting then discoveringNeighbors;
    transition discoveringNeighbors then synchronizedSleep;
    transition synchronizedSleep then sensing;
    transition sensing then transmitting;
    transition transmitting then synchronizedSleep;
    transition synchronizedSleep then receiving;
    transition receiving then forwarding;
    transition forwarding then synchronizedSleep;
    transition receiving then actuating;
    transition actuating then synchronizedSleep;
    transition synchronizedSleep then reportingHealth;
    transition reportingHealth then synchronizedSleep;
    transition synchronizedSleep then lowEnergySafeMode;
  }

  state def GatewayOperatingState {
    state joiningMesh;
    state collectingPackets;
    state forwardingToServer;
    state acceptingCommands;
    state injectingCommandsToMesh;
    state degradedBackhaul;

    transition first joiningMesh;
    transition joiningMesh then collectingPackets;
    transition collectingPackets then forwardingToServer;
    transition forwardingToServer then acceptingCommands;
    transition acceptingCommands then injectingCommandsToMesh;
    transition injectingCommandsToMesh then collectingPackets;
    transition forwardingToServer then degradedBackhaul;
    transition degradedBackhaul then collectingPackets;
  }

  requirement def PrimaryFunctionRequirement {
    doc /* The system shall use a MyriaNed-style low-power mesh to collect environmental sensor data from distributed nodes and deliver it to an application server while distributing commands back to actuator nodes. */
  }

  requirement def SelfOrganizingMeshRequirement {
    doc /* Each active node shall periodically advertise neighbor and link information so that packets can propagate through available neighboring nodes without preconfigured fixed routes. */
  }

  requirement def LowPowerOperationRequirement {
    doc /* Field nodes shall spend most operating time in synchronized sleep and wake for sensing, beaconing, receiving, transmitting, forwarding, and actuation events. */
  }

  requirement def PacketFloodingControlRequirement {
    doc /* The mesh protocol shall suppress duplicate packets and limit packet propagation using a time-to-live hop count. */
  }

  requirement def SensorDeliveryRequirement {
    doc /* A valid sensor sample generated by a field node shall be deliverable to the gateway within the maximum end-to-end latency budget when at least one connected multi-hop path exists. */
  }

  requirement def CommandDeliveryRequirement {
    doc /* An actuator command received by the gateway shall be injected into the mesh and delivered to the addressed actuator node when the target node is reachable. */
  }

  requirement def HealthMonitoringRequirement {
    doc /* Nodes shall report remaining energy, neighbor count, forwarding activity, packet drops, and average link quality to support network supervision. */
  }

  requirement def MyriaNedSystemRequirements {
    requirement primaryFunction : PrimaryFunctionRequirement;
    requirement selfOrganization : SelfOrganizingMeshRequirement;
    requirement lowPower : LowPowerOperationRequirement;
    requirement floodingControl : PacketFloodingControlRequirement;
    requirement sampleDelivery : SensorDeliveryRequirement;
    requirement commandDelivery : CommandDeliveryRequirement;
    requirement healthMonitoring : HealthMonitoringRequirement;
  }

  satisfy MyriaNedBasedSystem by MyriaNedSystemRequirements;

}