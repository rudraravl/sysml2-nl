package IEEE802154LowRateWirelessSystem {

  import ScalarValues::*;

  value type FrequencyMHz specializes Real;
  value type DataRateKbps specializes Real;
  value type PowerdBm specializes Real;
  value type VoltageV specializes Real;
  value type CurrentmA specializes Real;
  value type TimeMs specializes Real;
  value type DistanceM specializes Real;
  value type Percent specializes Real;
  value type OctetCount specializes Integer;
  value type ChannelNumber specializes Integer;
  value type PanIdentifier specializes Integer;
  value type ShortAddress specializes Integer;
  value type ExtendedAddress specializes Integer;
  value type SequenceNumber specializes Integer;

  enum def DeviceRole {
    enum coordinator;
    enum router;
    enum reducedFunctionDevice;
    enum fullFunctionDevice;
  }

  enum def PhyBand {
    enum band868MHz;
    enum band915MHz;
    enum band2450MHz;
  }

  enum def MacFrameType {
    enum beacon;
    enum data;
    enum acknowledgement;
    enum macCommand;
  }

  enum def SecurityLevel {
    enum none;
    enum mic32;
    enum mic64;
    enum mic128;
    enum enc;
    enum encMic32;
    enum encMic64;
    enum encMic128;
  }

  enum def NodeStateKind {
    enum unpowered;
    enum initializing;
    enum scanning;
    enum associating;
    enum synchronized;
    enum transmitting;
    enum receiving;
    enum sleeping;
    enum faulted;
  }

  item def SensorSample {
    attribute sourceAddress : ShortAddress;
    attribute sampleSequence : SequenceNumber;
    attribute measuredTemperatureC : Real;
    attribute measuredHumidityPercent : Percent;
    attribute batteryVoltage : VoltageV;
    attribute timestampMs : TimeMs;
  }

  item def ApplicationPayload {
    attribute payloadLength : OctetCount;
    attribute sample : SensorSample;
    attribute qosPriority : Integer;
  }

  item def MacFrame {
    attribute frameType : MacFrameType;
    attribute sequenceNumber : SequenceNumber;
    attribute panId : PanIdentifier;
    attribute sourceAddress : ShortAddress;
    attribute destinationAddress : ShortAddress;
    attribute securityLevel : SecurityLevel;
    attribute payloadLength : OctetCount;
    attribute ackRequested : Boolean;
  }

  item def Ppdu {
    attribute preambleLengthOctets : OctetCount;
    attribute startOfFrameDelimiter : Integer;
    attribute phyHeaderLengthOctets : OctetCount;
    attribute psduLength : OctetCount;
    attribute centerFrequency : FrequencyMHz;
    attribute dataRate : DataRateKbps;
    attribute transmitPower : PowerdBm;
  }

  item def RadioEnergy {
    attribute receivedSignalStrength : PowerdBm;
    attribute linkQualityIndicator : Percent;
    attribute noiseFloor : PowerdBm;
  }

  port def ApplicationDataPort {
    out item payloadOut : ApplicationPayload;
    in item payloadIn : ApplicationPayload;
  }

  port def MacServicePort {
    in item msduIn : ApplicationPayload;
    out item msduOut : ApplicationPayload;
    out item mpduOut : MacFrame;
    in item mpduIn : MacFrame;
  }

  port def PhyServicePort {
    in item psduTx : MacFrame;
    out item psduRx : MacFrame;
    out item ppduTx : Ppdu;
    in item ppduRx : Ppdu;
    in item channelEnergy : RadioEnergy;
  }

  port def RadioPort {
    out item radiatedFrame : Ppdu;
    in item receivedFrame : Ppdu;
    out item measuredEnergy : RadioEnergy;
  }

  port def PowerPort {
    in attribute supplyVoltage : VoltageV;
    out attribute loadCurrent : CurrentmA;
  }

  port def ManagementPort {
    in attribute desiredPanId : PanIdentifier;
    in attribute desiredChannel : ChannelNumber;
    out attribute joined : Boolean;
    out attribute currentState : NodeStateKind;
  }

  interface def AppToMac {
    end application : ApplicationDataPort;
    end mac : MacServicePort;
  }

  interface def MacToPhy {
    end mac : MacServicePort;
    end phy : PhyServicePort;
  }

  interface def PhyToRadio {
    end phy : PhyServicePort;
    end radio : RadioPort;
  }

  interface def RadioPropagation {
    end transmitter : RadioPort;
    end receiver : RadioPort;
  }

  action def SenseEnvironment {
    out item sample : SensorSample;
    attribute sensingPeriod : TimeMs = 60000.0;
  }

  action def BuildApplicationPayload {
    in item sample : SensorSample;
    out item payload : ApplicationPayload;
  }

  action def PerformCsmaCa {
    in item pendingFrame : MacFrame;
    out attribute channelClear : Boolean;
    attribute maxBackoffs : Integer = 4;
    attribute unitBackoffPeriod : TimeMs = 0.32;
  }

  action def TransmitIeee802154Frame {
    in item payload : ApplicationPayload;
    out item radiatedFrame : Ppdu;
    attribute maximumFrameSize : OctetCount = 127;
    attribute nominalDataRate : DataRateKbps = 250.0;
  }

  action def ReceiveIeee802154Frame {
    in item receivedFrame : Ppdu;
    out item payload : ApplicationPayload;
    out attribute validFrame : Boolean;
  }

  action def SleepUntilNextDutyCycle {
    attribute sleepDuration : TimeMs;
    out attribute wakeRequested : Boolean;
  }

  state def Ieee802154NodeLifecycle {
    state unpowered;
    state initializing;
    state scanning;
    state associating;
    state synchronized;
    state sleeping;
    state transmitting;
    state receiving;
    state faulted;

    transition first unpowered then initializing;
    transition initializing then scanning;
    transition scanning then associating;
    transition associating then synchronized;
    transition synchronized then sleeping;
    transition sleeping then transmitting;
    transition transmitting then receiving;
    transition receiving then sleeping;
    transition synchronized then faulted;
    transition sleeping then faulted;
    transition transmitting then faulted;
    transition receiving then faulted;
  }

  part def SensorApplication {
    port data : ApplicationDataPort;
    attribute sensingPeriod : TimeMs = 60000.0;
    attribute payloadPriority : Integer = 1;
    perform sense : SenseEnvironment;
    perform buildPayload : BuildApplicationPayload;
  }

  part def Ieee802154MacSublayer {
    port appService : MacServicePort;
    port phyService : PhyServicePort;

    attribute panId : PanIdentifier = 4660;
    attribute shortAddress : ShortAddress;
    attribute coordinatorAddress : ShortAddress = 0;
    attribute beaconEnabled : Boolean = false;
    attribute maxFrameRetries : Integer = 3;
    attribute maxFrameSize : OctetCount = 127;
    attribute defaultSecurityLevel : SecurityLevel = SecurityLevel::encMic32;

    perform channelAccess : PerformCsmaCa;
  }

  part def OqpskDsssPhy {
    port macService : PhyServicePort;
    port radio : RadioPort;

    attribute band : PhyBand = PhyBand::band2450MHz;
    attribute channel : ChannelNumber = 15;
    attribute centerFrequency : FrequencyMHz = 2425.0;
    attribute nominalDataRate : DataRateKbps = 250.0;
    attribute modulation : String = "O-QPSK DSSS";
    attribute chipRateKchipsPerSecond : Real = 2000.0;
    attribute receiverSensitivity : PowerdBm = -95.0;
  }

  part def RfTransceiver {
    port phy : RadioPort;
    port antenna : RadioPort;
    port power : PowerPort;

    attribute transmitPower : PowerdBm = 0.0;
    attribute receiverNoiseFloor : PowerdBm = -100.0;
    attribute txCurrent : CurrentmA = 17.0;
    attribute rxCurrent : CurrentmA = 19.0;
    attribute sleepCurrent : CurrentmA = 0.002;
    attribute supplyVoltage : VoltageV = 3.3;
  }

  part def Antenna {
    port radio : RadioPort;
    attribute antennaGainDbi : Real = 2.0;
    attribute impedanceOhm : Real = 50.0;
  }

  part def BatteryPowerSource {
    port powerOut : PowerPort;
    attribute nominalVoltage : VoltageV = 3.0;
    attribute capacityMah : Real = 2400.0;
    attribute minimumOperatingVoltage : VoltageV = 2.0;
  }

  part def Ieee802154SensorNode {
    port network : RadioPort;
    port management : ManagementPort;

    attribute role : DeviceRole = DeviceRole::reducedFunctionDevice;
    attribute nodeState : NodeStateKind = NodeStateKind::unpowered;
    attribute panId : PanIdentifier = 4660;
    attribute shortAddress : ShortAddress;
    attribute reportingPeriod : TimeMs = 60000.0;
    attribute maximumCommunicationRange : DistanceM = 30.0;

    part application : SensorApplication;
    part mac : Ieee802154MacSublayer;
    part phy : OqpskDsssPhy;
    part transceiver : RfTransceiver;
    part antenna : Antenna;
    part battery : BatteryPowerSource;

    connect application.data to mac.appService;
    connect mac.phyService to phy.macService;
    connect phy.radio to transceiver.phy;
    connect transceiver.antenna to antenna.radio;
    connect antenna.radio to network;
    connect battery.powerOut to transceiver.power;

    exhibit lifecycle : Ieee802154NodeLifecycle;
    perform transmitTelemetry : TransmitIeee802154Frame;
    perform receiveControl : ReceiveIeee802154Frame;
    perform sleepDutyCycle : SleepUntilNextDutyCycle;
  }

  part def Ieee802154CoordinatorNode {
    port network : RadioPort;
    port management : ManagementPort;

    attribute role : DeviceRole = DeviceRole::coordinator;
    attribute nodeState : NodeStateKind = NodeStateKind::synchronized;
    attribute panId : PanIdentifier = 4660;
    attribute shortAddress : ShortAddress = 0;
    attribute permitJoining : Boolean = true;
    attribute beaconInterval : TimeMs = 0.0;

    part mac : Ieee802154MacSublayer;
    part phy : OqpskDsssPhy;
    part transceiver : RfTransceiver;
    part antenna : Antenna;
    part powerSupply : BatteryPowerSource;

    connect mac.phyService to phy.macService;
    connect phy.radio to transceiver.phy;
    connect transceiver.antenna to antenna.radio;
    connect antenna.radio to network;
    connect powerSupply.powerOut to transceiver.power;

    exhibit lifecycle : Ieee802154NodeLifecycle;
    perform receiveTelemetry : ReceiveIeee802154Frame;
    perform transmitAcknowledgement : TransmitIeee802154Frame;
  }

  part def SharedWirelessMedium {
    port endpoint[2..65] : RadioPort;

    attribute band : PhyBand = PhyBand::band2450MHz;
    attribute channel : ChannelNumber = 15;
    attribute centerFrequency : FrequencyMHz = 2425.0;
    attribute occupiedBandwidthMHz : Real = 2.0;
    attribute maximumPracticalRange : DistanceM = 30.0;
    attribute backgroundNoise : PowerdBm = -100.0;
    attribute packetErrorRateTarget : Percent = 1.0;
  }

  part def Ieee802154LowRateWirelessPersonalAreaNetwork {
    attribute primaryFunction : String =
      "Provide low-rate, low-power wireless connectivity for sensor and control devices using IEEE 802.15.4 physical and MAC services.";

    attribute panId : PanIdentifier = 4660;
    attribute operatingChannel : ChannelNumber = 15;
    attribute carrierFrequency : FrequencyMHz = 2425.0;
    attribute nominalDataRate : DataRateKbps = 250.0;
    attribute maximumMacFrameSize : OctetCount = 127;
    attribute supportsAcknowledgedDelivery : Boolean = true;
    attribute supportsLowPowerDutyCycle : Boolean = true;

    part coordinator : Ieee802154CoordinatorNode;
    part sensorNode[1..32] : Ieee802154SensorNode;
    part medium : SharedWirelessMedium;

    connect coordinator.network to medium.endpoint;
    connect sensorNode.network to medium.endpoint;

    perform networkTelemetryTransfer : TransmitIeee802154Frame;
    perform networkTelemetryReception : ReceiveIeee802154Frame;
  }

  requirement def PrimaryFunctionRequirement {
    doc
      /* The system shall provide low-rate, low-power wireless communication among embedded sensor and control nodes using an IEEE 802.15.4 compatible PHY and MAC. */

    subject network : Ieee802154LowRateWirelessPersonalAreaNetwork;

    require constraint {
      network.nominalDataRate <= 250.0
    }

    require constraint {
      network.maximumMacFrameSize <= 127
    }

    require constraint {
      network.supportsLowPowerDutyCycle == true
    }
  }

  requirement def ChannelOperationRequirement {
    doc
      /* The network shall operate on a configured IEEE 802.15.4 channel and expose the channel, carrier frequency, and PAN identifier as managed configuration values. */

    subject network : Ieee802154LowRateWirelessPersonalAreaNetwork;

    require constraint {
      network.operatingChannel >= 11 and network.operatingChannel <= 26
    }

    require constraint {
      network.carrierFrequency >= 2405.0 and network.carrierFrequency <= 2480.0
    }
  }

  requirement def ReliableFrameDeliveryRequirement {
    doc
      /* The MAC sublayer shall support acknowledged frame transfer, frame sequencing, retry limits, and CSMA-CA channel access for shared-medium operation. */

    subject network : Ieee802154LowRateWirelessPersonalAreaNetwork;

    require constraint {
      network.supportsAcknowledgedDelivery == true
    }
  }

  requirement def PowerEfficiencyRequirement {
    doc
      /* Battery-powered sensor nodes shall spend normal inactive periods in a sleep state and wake periodically to sense, associate if needed, transmit telemetry, and receive acknowledgements or control data. */

    subject node : Ieee802154SensorNode;

    require constraint {
      node.reportingPeriod >= 1000.0
    }
  }

  part ieee802154System : Ieee802154LowRateWirelessPersonalAreaNetwork {
    satisfy PrimaryFunctionRequirement;
    satisfy ChannelOperationRequirement;
    satisfy ReliableFrameDeliveryRequirement;

    part coordinator redefines coordinator {
      attribute panId = 4660;
      attribute shortAddress = 0;
      attribute permitJoining = true;
    }

    part sensorNode[1] redefines sensorNode {
      attribute shortAddress = 1;
      attribute reportingPeriod = 60000.0;
      satisfy PowerEfficiencyRequirement;
    }

    part sensorNode[2] redefines sensorNode {
      attribute shortAddress = 2;
      attribute reportingPeriod = 30000.0;
      satisfy PowerEfficiencyRequirement;
    }

    part sensorNode[3] redefines sensorNode {
      attribute shortAddress = 3;
      attribute reportingPeriod = 120000.0;
      satisfy PowerEfficiencyRequirement;
    }
  }
}