package SixLoWPAN_Based_Environmental_Monitoring_System {

  import ScalarValues::*;

  enum def NodeRole {
    enum borderRouter;
    enum meshRouter;
    enum sensingLeaf;
  }

  enum def NetworkHealth {
    enum nominal;
    enum degraded;
    enum disconnected;
    enum maintenance;
  }

  enum def SecurityMode {
    enum unsecured;
    enum aes128Ccm;
    enum dtlsPsk;
    enum oscore;
  }

  enum def PrimaryFunctionKind {
    enum environmentalTelemetryGateway;
  }

  attribute def TemperatureC :> Real {
    attribute unit: String = "degC";
  }

  attribute def RelativeHumidityPercent :> Real {
    attribute unit: String = "%RH";
  }

  attribute def IlluminanceLux :> Real {
    attribute unit: String = "lx";
  }

  attribute def BatteryVoltage :> Real {
    attribute unit: String = "V";
  }

  attribute def EnergyMilliwattHour :> Real {
    attribute unit: String = "mWh";
  }

  attribute def CurrentMilliampere :> Real {
    attribute unit: String = "mA";
  }

  attribute def PowerMilliwatt :> Real {
    attribute unit: String = "mW";
  }

  attribute def TimeSecond :> Real {
    attribute unit: String = "s";
  }

  attribute def TimeMinute :> Real {
    attribute unit: String = "min";
  }

  attribute def DataRateKilobitPerSecond :> Real {
    attribute unit: String = "kb/s";
  }

  attribute def LengthMeter :> Real {
    attribute unit: String = "m";
  }

  attribute def RadioFrequencyMegahertz :> Real {
    attribute unit: String = "MHz";
  }

  attribute def RssiDbm :> Real {
    attribute unit: String = "dBm";
  }

  attribute def PacketCount :> Integer {
    attribute unit: String = "packet";
  }

  attribute def Percent :> Real {
    attribute unit: String = "%";
  }

  item def IPv6Address {
    attribute text: String;
    attribute prefixLength: Integer;
  }

  item def MacAddress64 {
    attribute eui64: String;
  }

  item def EnvironmentalReading {
    attribute sourceNodeId: String;
    attribute sampleSequence: Integer;
    attribute sampleTime: TimeSecond;
    attribute temperature: TemperatureC;
    attribute humidity: RelativeHumidityPercent;
    attribute illuminance: IlluminanceLux;
    attribute batteryVoltage: BatteryVoltage;
  }

  item def ControlCommand {
    attribute destinationNodeId: String;
    attribute commandId: String;
    attribute requestedSamplingPeriod: TimeSecond;
    attribute enableReporting: Boolean;
  }

  item def IEEE802154Frame {
    attribute sourceMac: MacAddress64;
    attribute destinationMac: MacAddress64;
    attribute channel: Integer;
    attribute payloadLength: Integer;
    attribute linkQualityIndicator: Percent;
    attribute receivedSignalStrength: RssiDbm;
  }

  item def IPv6Packet {
    attribute sourceAddress: IPv6Address;
    attribute destinationAddress: IPv6Address;
    attribute hopLimit: Integer;
    attribute payloadLength: Integer;
    attribute flowLabel: Integer;
  }

  item def SixLoWPANCompressedPacket {
    attribute compressedHeaderLength: Integer;
    attribute uncompressedHeaderLength: Integer;
    attribute meshHeaderPresent: Boolean;
    attribute fragmentationHeaderPresent: Boolean;
    attribute datagramTag: Integer;
    attribute datagramSize: Integer;
  }

  item def CoAPMessage {
    attribute method: String;
    attribute uriPath: String;
    attribute messageId: Integer;
    attribute confirmable: Boolean;
    attribute payloadFormat: String;
  }

  item def TelemetryReport {
    attribute reportId: String;
    attribute networkHealth: NetworkHealth;
    attribute totalNodes: Integer;
    attribute deliveredSamples: PacketCount;
    attribute lostSamples: PacketCount;
    attribute deliveryRatio: Percent;
  }

  port def EnvironmentalSensorPort {
    out item reading: EnvironmentalReading;
  }

  port def SensorInputPort {
    in item reading: EnvironmentalReading;
  }

  port def CommandInputPort {
    in item command: ControlCommand;
  }

  port def ApplicationTelemetryPort {
    out item report: TelemetryReport;
    out item reading: EnvironmentalReading;
    in item command: ControlCommand;
  }

  port def IPv6Port {
    in item rxPacket: IPv6Packet;
    out item txPacket: IPv6Packet;
  }

  port def SixLoWPANPort {
    in item rxCompressedPacket: SixLoWPANCompressedPacket;
    out item txCompressedPacket: SixLoWPANCompressedPacket;
  }

  port def IEEE802154RadioPort {
    in item rxFrame: IEEE802154Frame;
    out item txFrame: IEEE802154Frame;
  }

  port def CoAPPort {
    in item rxMessage: CoAPMessage;
    out item txMessage: CoAPMessage;
  }

  port def EthernetPort {
    in item rxPacket: IPv6Packet;
    out item txPacket: IPv6Packet;
  }

  connection def SensorBus {
    end source: EnvironmentalSensorPort;
    end sink: SensorInputPort;
  }

  connection def InternalIPv6Link {
    end upper: IPv6Port;
    end lower: IPv6Port;
  }

  connection def AdaptationLink {
    end upper: SixLoWPANPort;
    end lower: SixLoWPANPort;
  }

  connection def LowPowerMeshLink {
    end firstRadio: IEEE802154RadioPort;
    end secondRadio: IEEE802154RadioPort;
    attribute centerFrequency: RadioFrequencyMegahertz = 2405.0;
    attribute nominalRange: LengthMeter = 35.0;
    attribute dataRate: DataRateKilobitPerSecond = 250.0;
    attribute nominalRssi: RssiDbm = -72.0;
  }

  connection def BackhaulIPv6Link {
    end border: EthernetPort;
    end server: EthernetPort;
    attribute dataRate: DataRateKilobitPerSecond = 100000.0;
  }

  action def SampleEnvironment {
    out item reading: EnvironmentalReading;
  }

  action def EncodeCoAPTelemetry {
    in item reading: EnvironmentalReading;
    out item message: CoAPMessage;
  }

  action def BuildIPv6Packet {
    in item message: CoAPMessage;
    out item packet: IPv6Packet;
  }

  action def CompressIPv6ForSixLoWPAN {
    in item packet: IPv6Packet;
    out item compressedPacket: SixLoWPANCompressedPacket;
  }

  action def FragmentAndTransmitIEEE802154 {
    in item compressedPacket: SixLoWPANCompressedPacket;
    out item frame: IEEE802154Frame;
  }

  action def ReceiveAndReassembleSixLoWPAN {
    in item frame: IEEE802154Frame;
    out item compressedPacket: SixLoWPANCompressedPacket;
  }

  action def DecompressToIPv6 {
    in item compressedPacket: SixLoWPANCompressedPacket;
    out item packet: IPv6Packet;
  }

  action def RouteUsingRPL {
    in item inboundPacket: IPv6Packet;
    out item outboundPacket: IPv6Packet;
  }

  action def AggregateTelemetry {
    in item reading: EnvironmentalReading;
    out item report: TelemetryReport;
  }

  action def SenseCompressRouteDeliverMission {
    action sample: SampleEnvironment;
    action encode: EncodeCoAPTelemetry;
    action buildIPv6: BuildIPv6Packet;
    action compress: CompressIPv6ForSixLoWPAN;
    action transmit: FragmentAndTransmitIEEE802154;
    action receive: ReceiveAndReassembleSixLoWPAN;
    action decompress: DecompressToIPv6;
    action route: RouteUsingRPL;
    action aggregate: AggregateTelemetry;

    flow sample.reading to encode.reading;
    flow encode.message to buildIPv6.message;
    flow buildIPv6.packet to compress.packet;
    flow compress.compressedPacket to transmit.compressedPacket;
    flow transmit.frame to receive.frame;
    flow receive.compressedPacket to decompress.compressedPacket;
    flow decompress.packet to route.inboundPacket;
    flow sample.reading to aggregate.reading;
  }

  action def JoinSixLoWPANMesh {
    out joinSucceeded: Boolean;
    out assignedIPv6Address: IPv6Address;
  }

  action def SleepForDutyCycle {
    in duration: TimeSecond;
    out wakeRequested: Boolean;
  }

  action def ProcessRemoteCommand {
    in item command: ControlCommand;
    out accepted: Boolean;
  }

  state def SensorNodeLifecycle {
    state initializing;
    state discoveringMesh;
    state joiningMesh;
    state synchronizedSleep;
    state sampling;
    state transmitting;
    state receivingCommand;
    state faultIsolation;

    transition first initializing then discoveringMesh;
    transition discoveringMesh then joiningMesh;
    transition joiningMesh then synchronizedSleep;
    transition synchronizedSleep then sampling;
    transition sampling then transmitting;
    transition transmitting then synchronizedSleep;
    transition synchronizedSleep then receivingCommand;
    transition receivingCommand then synchronizedSleep;
    transition sampling then faultIsolation;
    transition transmitting then faultIsolation;
    transition faultIsolation then discoveringMesh;
  }

  state def BorderRouterLifecycle {
    state booting;
    state formingDodag;
    state routingPackets;
    state forwardingToBackhaul;
    state acceptingCommands;
    state degradedOperation;

    transition first booting then formingDodag;
    transition formingDodag then routingPackets;
    transition routingPackets then forwardingToBackhaul;
    transition forwardingToBackhaul then routingPackets;
    transition routingPackets then acceptingCommands;
    transition acceptingCommands then routingPackets;
    transition routingPackets then degradedOperation;
    transition degradedOperation then formingDodag;
  }

  state def SystemLifecycle {
    state installed;
    state meshFormation;
    state monitoring;
    state commandDistribution;
    state degradedMonitoring;
    state maintenance;

    transition first installed then meshFormation;
    transition meshFormation then monitoring;
    transition monitoring then commandDistribution;
    transition commandDistribution then monitoring;
    transition monitoring then degradedMonitoring;
    transition degradedMonitoring then monitoring;
    transition degradedMonitoring then maintenance;
    transition maintenance then meshFormation;
  }

  part def EnvironmentalSensor {
    port dataPort: EnvironmentalSensorPort;
    attribute measurementPeriod: TimeSecond = 60.0;
    attribute temperatureAccuracy: TemperatureC = 0.5;
    attribute humidityAccuracy: RelativeHumidityPercent = 3.0;
    attribute illuminanceAccuracy: IlluminanceLux = 5.0;
    perform action sampling: SampleEnvironment;
  }

  part def LowPowerMicrocontroller {
    port sensorIn: SensorInputPort;
    port ipv6Port: IPv6Port;
    port commandIn: CommandInputPort;
    attribute sleepCurrent: CurrentMilliampere = 0.015;
    attribute activeCurrent: CurrentMilliampere = 6.5;
    attribute clockFrequencyMHz: Real = 48.0;
    perform action encodeTelemetry: EncodeCoAPTelemetry;
    perform action processCommand: ProcessRemoteCommand;
  }

  part def IEEE802154Radio {
    port radioPort: IEEE802154RadioPort;
    attribute channel: Integer = 15;
    attribute panId: Integer = 4660;
    attribute transmitPower: RssiDbm = 0.0;
    attribute receiveSensitivity: RssiDbm = -98.0;
    attribute centerFrequency: RadioFrequencyMegahertz = 2425.0;
    attribute rawDataRate: DataRateKilobitPerSecond = 250.0;
    perform action transmitFrame: FragmentAndTransmitIEEE802154;
    perform action receiveFrame: ReceiveAndReassembleSixLoWPAN;
  }

  part def SixLoWPANAdaptationLayer {
    port ipv6Side: IPv6Port;
    port lowpanSide: SixLoWPANPort;
    attribute supportsHeaderCompression: Boolean = true;
    attribute supportsFragmentation: Boolean = true;
    attribute maxMacPayloadOctets: Integer = 127;
    attribute typicalCompressedHeaderOctets: Integer = 7;
    perform action compress: CompressIPv6ForSixLoWPAN;
    perform action decompress: DecompressToIPv6;
  }

  part def RPLRoutingAgent {
    port ipv6Port: IPv6Port;
    attribute instanceId: Integer = 1;
    attribute rank: Integer = 256;
    attribute objectiveFunction: String = "MRHOF";
    attribute trickleMinInterval: TimeSecond = 4.0;
    attribute trickleMaxInterval: TimeSecond = 1048.0;
    perform action route: RouteUsingRPL;
  }

  part def EnergyStore {
    attribute nominalVoltage: BatteryVoltage = 3.6;
    attribute capacity: EnergyMilliwattHour = 7200.0;
    attribute minimumOperatingVoltage: BatteryVoltage = 2.1;
    attribute estimatedLife: TimeMinute = 525600.0;
  }

  part def SensingLeafNode {
    attribute nodeId: String;
    attribute role: NodeRole = NodeRole::sensingLeaf;
    attribute ipv6Address: IPv6Address;
    attribute macAddress: MacAddress64;
    attribute samplingPeriod: TimeSecond = 60.0;
    attribute reportPeriod: TimeSecond = 300.0;

    port sensorCommandIn: CommandInputPort;
    port radioPort: IEEE802154RadioPort;

    part sensor: EnvironmentalSensor;
    part controller: LowPowerMicrocontroller;
    part adaptation: SixLoWPANAdaptationLayer;
    part routing: RPLRoutingAgent;
    part radio: IEEE802154Radio;
    part battery: EnergyStore;

    connection sensorToController: SensorBus connect sensor.dataPort to controller.sensorIn;
    connection controllerToAdaptation: InternalIPv6Link connect controller.ipv6Port to adaptation.ipv6Side;
    connection adaptationToRouting: InternalIPv6Link connect adaptation.ipv6Side to routing.ipv6Port;
    connection exposedRadio connect radio.radioPort to radioPort;

    exhibit state lifecycle: SensorNodeLifecycle;
    perform action join: JoinSixLoWPANMesh;
    perform action dutyCycleSleep: SleepForDutyCycle;
    perform action mission: SenseCompressRouteDeliverMission;
  }

  part def MeshRouterNode {
    attribute nodeId: String;
    attribute role: NodeRole = NodeRole::meshRouter;
    attribute ipv6Address: IPv6Address;
    attribute macAddress: MacAddress64;

    port radioPort: IEEE802154RadioPort;

    part controller: LowPowerMicrocontroller;
    part adaptation: SixLoWPANAdaptationLayer;
    part routing: RPLRoutingAgent;
    part radio: IEEE802154Radio;
    part battery: EnergyStore;

    connection controllerToAdaptation: InternalIPv6Link connect controller.ipv6Port to adaptation.ipv6Side;
    connection adaptationToRouting: InternalIPv6Link connect adaptation.ipv6Side to routing.ipv6Port;
    connection exposedRadio connect radio.radioPort to radioPort;

    exhibit state lifecycle: SensorNodeLifecycle;
    perform action join: JoinSixLoWPANMesh;
    perform action routePackets: RouteUsingRPL;
  }

  part def BorderRouter {
    attribute nodeId: String = "border-router-01";
    attribute role: NodeRole = NodeRole::borderRouter;
    attribute lowpanPrefix: String = "fd00:6lowpan:1::/64";
    attribute backhaulAddress: IPv6Address;
    attribute securityMode: SecurityMode = SecurityMode::oscore;

    port lowpanRadioPort: IEEE802154RadioPort;
    port backhaulPort: EthernetPort;
    port applicationPort: ApplicationTelemetryPort;

    part controller: LowPowerMicrocontroller;
    part adaptation: SixLoWPANAdaptationLayer;
    part routing: RPLRoutingAgent;
    part radio: IEEE802154Radio;

    connection controllerToAdaptation: InternalIPv6Link connect controller.ipv6Port to adaptation.ipv6Side;
    connection adaptationToRouting: InternalIPv6Link connect adaptation.ipv6Side to routing.ipv6Port;
    connection exposedLowpanRadio connect radio.radioPort to lowpanRadioPort;

    exhibit state lifecycle: BorderRouterLifecycle;
    perform action routeLowpanPackets: RouteUsingRPL;
    perform action reassemble: ReceiveAndReassembleSixLoWPAN;
    perform action decompress: DecompressToIPv6;
  }

  part def MonitoringApplicationServer {
    attribute serverName: String = "facility-environment-monitor";
    attribute ipv6Address: IPv6Address;
    attribute retentionDays: Integer = 365;
    attribute alarmTemperatureHigh: TemperatureC = 35.0;
    attribute alarmHumidityHigh: RelativeHumidityPercent = 80.0;

    port backhaulPort: EthernetPort;
    port telemetryPort: ApplicationTelemetryPort;
    port coapPort: CoAPPort;

    perform action aggregateTelemetry: AggregateTelemetry;
    perform action processRemoteCommand: ProcessRemoteCommand;
  }

  part def SixLoWPANEnvironmentalMonitoringSystem {
    attribute systemName: String = "6LoWPAN Environmental Monitoring System";
    attribute primaryFunction: PrimaryFunctionKind = PrimaryFunctionKind::environmentalTelemetryGateway;
    attribute highLevelFunctionStatement: String = "Collect low-rate environmental measurements from battery-powered IPv6 sensor nodes, transport them over an IEEE 802.15.4 6LoWPAN mesh, and deliver aggregated telemetry and commands through a border router to an IPv6 application server.";
    attribute meshPrefix: String = "fd00:6lowpan:1::/64";
    attribute operatingChannel: Integer = 15;
    attribute nominalNodeCount: Integer = 6;
    attribute reportingInterval: TimeSecond = 300.0;
    attribute expectedPacketDeliveryRatio: Percent = 97.0;
    attribute networkHealth: NetworkHealth = NetworkHealth::nominal;
    attribute securityMode: SecurityMode = SecurityMode::oscore;

    part borderRouter: BorderRouter {
      attribute backhaulAddress: IPv6Address {
        attribute text: String = "2001:db8:100::1";
        attribute prefixLength: Integer = 64;
      }
    }

    part routerNorth: MeshRouterNode {
      attribute nodeId: String = "router-north";
      attribute ipv6Address: IPv6Address {
        attribute text: String = "fd00:6lowpan:1::10";
        attribute prefixLength: Integer = 64;
      }
      attribute macAddress: MacAddress64 {
        attribute eui64: String = "02-00-00-00-00-00-00-10";
      }
    }

    part routerSouth: MeshRouterNode {
      attribute nodeId: String = "router-south";
      attribute ipv6Address: IPv6Address {
        attribute text: String = "fd00:6lowpan:1::11";
        attribute prefixLength: Integer = 64;
      }
      attribute macAddress: MacAddress64 {
        attribute eui64: String = "02-00-00-00-00-00-00-11";
      }
    }

    part sensorColdRoom: SensingLeafNode {
      attribute nodeId: String = "sensor-cold-room";
      attribute samplingPeriod: TimeSecond = 30.0;
      attribute ipv6Address: IPv6Address {
        attribute text: String = "fd00:6lowpan:1::101";
        attribute prefixLength: Integer = 64;
      }
      attribute macAddress: MacAddress64 {
        attribute eui64: String = "02-00-00-00-00-00-01-01";
      }
    }

    part sensorWarehouse: SensingLeafNode {
      attribute nodeId: String = "sensor-warehouse";
      attribute samplingPeriod: TimeSecond = 60.0;
      attribute ipv6Address: IPv6Address {
        attribute text: String = "fd00:6lowpan:1::102";
        attribute prefixLength: Integer = 64;
      }
      attribute macAddress: MacAddress64 {
        attribute eui64: String = "02-00-00-00-00-00-01-02";
      }
    }

    part sensorOffice: SensingLeafNode {
      attribute nodeId: String = "sensor-office";
      attribute samplingPeriod: TimeSecond = 120.0;
      attribute ipv6Address: IPv6Address {
        attribute text: String = "fd00:6lowpan:1::103";
        attribute prefixLength: Integer = 64;
      }
      attribute macAddress: MacAddress64 {
        attribute eui64: String = "02-00-00-00-00-00-01-03";
      }
    }

    part applicationServer: MonitoringApplicationServer {
      attribute ipv6Address: IPv6Address {
        attribute text: String = "2001:db8:100::20";
        attribute prefixLength: Integer = 64;
      }
    }

    connection borderToNorth: LowPowerMeshLink connect borderRouter.lowpanRadioPort to routerNorth.radioPort {
      attribute centerFrequency: RadioFrequencyMegahertz = 2425.0;
      attribute nominalRange: LengthMeter = 28.0;
      attribute nominalRssi: RssiDbm = -62.0;
    }

    connection borderToSouth: LowPowerMeshLink connect borderRouter.lowpanRadioPort to routerSouth.radioPort {
      attribute centerFrequency: RadioFrequencyMegahertz = 2425.0;
      attribute nominalRange: LengthMeter = 31.0;
      attribute nominalRssi: RssiDbm = -68.0;
    }

    connection northToColdRoom: LowPowerMeshLink connect routerNorth.radioPort to sensorColdRoom.radioPort {
      attribute centerFrequency: RadioFrequencyMegahertz = 2425.0;
      attribute nominalRange: LengthMeter = 18.0;
      attribute nominalRssi: RssiDbm = -70.0;
    }

    connection northToOffice: LowPowerMeshLink connect routerNorth.radioPort to sensorOffice.radioPort {
      attribute centerFrequency: RadioFrequencyMegahertz = 2425.0;
      attribute nominalRange: LengthMeter = 22.0;
      attribute nominalRssi: RssiDbm = -73.0;
    }

    connection southToWarehouse: LowPowerMeshLink connect routerSouth.radioPort to sensorWarehouse.radioPort {
      attribute centerFrequency: RadioFrequencyMegahertz = 2425.0;
      attribute nominalRange: LengthMeter = 26.0;
      attribute nominalRssi: RssiDbm = -76.0;
    }

    connection routerRedundancy: LowPowerMeshLink connect routerNorth.radioPort to routerSouth.radioPort {
      attribute centerFrequency: RadioFrequencyMegahertz = 2425.0;
      attribute nominalRange: LengthMeter = 34.0;
      attribute nominalRssi: RssiDbm = -79.0;
    }

    connection backhaul: BackhaulIPv6Link connect borderRouter.backhaulPort to applicationServer.backhaulPort;

    exhibit state lifecycle: SystemLifecycle;
    perform action primaryMission: SenseCompressRouteDeliverMission;
  }

  constraint def MinimumPacketDeliveryRatio {
    in actual: Percent;
    in required: Percent;
    actual >= required
  }

  constraint def MaximumSamplingPeriod {
    in actual: TimeSecond;
    in maximum: TimeSecond;
    actual <= maximum
  }

  constraint def MinimumBatteryLife {
    in actual: TimeMinute;
    in required: TimeMinute;
    actual >= required
  }

  requirement def PrimaryFunctionRequirement {
    subject system: SixLoWPANEnvironmentalMonitoringSystem;
    require constraint {
      system.primaryFunction == PrimaryFunctionKind::environmentalTelemetryGateway
    }
  }

  requirement def IPv6OverLowPowerWirelessRequirement {
    subject system: SixLoWPANEnvironmentalMonitoringSystem;
    require constraint {
      system.borderRouter.adaptation.supportsHeaderCompression == true
    }
    require constraint {
      system.borderRouter.adaptation.supportsFragmentation == true
    }
  }

  requirement def TelemetryDeliveryRequirement {
    subject system: SixLoWPANEnvironmentalMonitoringSystem;
    require constraint delivery: MinimumPacketDeliveryRatio {
      in actual = system.expectedPacketDeliveryRatio;
      in required = 95.0;
    }
  }

  requirement def SamplingRequirement {
    subject system: SixLoWPANEnvironmentalMonitoringSystem;
    require constraint coldRoomPeriod: MaximumSamplingPeriod {
      in actual = system.sensorColdRoom.samplingPeriod;
      in maximum = 60.0;
    }
    require constraint warehousePeriod: MaximumSamplingPeriod {
      in actual = system.sensorWarehouse.samplingPeriod;
      in maximum = 300.0;
    }
    require constraint officePeriod: MaximumSamplingPeriod {
      in actual = system.sensorOffice.samplingPeriod;
      in maximum = 300.0;
    }
  }

  requirement def LowPowerOperationRequirement {
    subject system: SixLoWPANEnvironmentalMonitoringSystem;
    require constraint coldRoomLife: MinimumBatteryLife {
      in actual = system.sensorColdRoom.battery.estimatedLife;
      in required = 525600.0;
    }
    require constraint warehouseLife: MinimumBatteryLife {
      in actual = system.sensorWarehouse.battery.estimatedLife;
      in required = 525600.0;
    }
    require constraint officeLife: MinimumBatteryLife {
      in actual = system.sensorOffice.battery.estimatedLife;
      in required = 525600.0;
    }
  }

  requirement def MeshResilienceRequirement {
    subject system: SixLoWPANEnvironmentalMonitoringSystem;
    require constraint {
      system.nominalNodeCount >= 6
    }
    require constraint {
      system.routerNorth.role == NodeRole::meshRouter
    }
    require constraint {
      system.routerSouth.role == NodeRole::meshRouter
    }
  }

  requirement primaryFunction: PrimaryFunctionRequirement {
    subject system = sixLoWPANMonitoringSystem;
  }

  requirement ipv6LowPowerOperation: IPv6OverLowPowerWirelessRequirement {
    subject system = sixLoWPANMonitoringSystem;
  }

  requirement telemetryDelivery: TelemetryDeliveryRequirement {
    subject system = sixLoWPANMonitoringSystem;
  }

  requirement periodicSampling: SamplingRequirement {
    subject system = sixLoWPANMonitoringSystem;
  }

  requirement batteryLife: LowPowerOperationRequirement {
    subject system = sixLoWPANMonitoringSystem;
  }

  requirement resilientMesh: MeshResilienceRequirement {
    subject system = sixLoWPANMonitoringSystem;
  }

  part sixLoWPANMonitoringSystem: SixLoWPANEnvironmentalMonitoringSystem;
}
