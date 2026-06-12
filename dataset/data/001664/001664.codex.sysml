package IoBridgeModel {
  import ScalarValues::*;
  import SI::*;

  attribute def Voltage :> ISQ::ElectricPotential {
    unit = SI::volt;
  }

  attribute def Current :> ISQ::ElectricCurrent {
    unit = SI::ampere;
  }

  attribute def DataRate {
    unit = "Mbit/s";
  }

  attribute def Latency {
    unit = SI::millisecond;
  }

  attribute def Temperature {
    unit = SI::degreeCelsius;
  }

  item def AnalogSignal {
    attribute voltage: Voltage;
    attribute sampleRate: DataRate;
  }

  item def DigitalIoSignal {
    attribute logicLevel: Voltage;
    attribute timestamp: Real;
  }

  item def NetworkFrame {
    attribute payloadBytes: Integer;
    attribute sourceAddress: String;
    attribute destinationAddress: String;
    attribute checksumValid: Boolean;
  }

  item def BridgeStatus {
    attribute operational: Boolean;
    attribute activeChannels: Integer;
    attribute faultCode: String;
  }

  port def AnalogInputPort {
    in signal: AnalogSignal;
  }

  port def DigitalIoPort {
    in discreteInput: DigitalIoSignal;
    out discreteOutput: DigitalIoSignal;
  }

  port def EthernetPort {
    in rxFrame: NetworkFrame;
    out txFrame: NetworkFrame;
  }

  port def StatusPort {
    out status: BridgeStatus;
  }

  part def PowerRegulator {
    attribute inputVoltage: Voltage = 24.0 [SI::volt];
    attribute outputVoltage: Voltage = 5.0 [SI::volt];
    attribute maxOutputCurrent: Current = 2.0 [SI::ampere];
    port statusOut: StatusPort;
  }

  part def SignalConditioner {
    attribute channelCount: Integer = 8;
    attribute maxInputVoltage: Voltage = 10.0 [SI::volt];
    port analogIn: AnalogInputPort;
    port conditionedOut: AnalogInputPort;
  }

  part def DigitalIoBank {
    attribute channelCount: Integer = 16;
    attribute nominalLogicVoltage: Voltage = 3.3 [SI::volt];
    port io: DigitalIoPort;
  }

  part def BridgeProcessor {
    attribute clockRateMHz: Real = 400.0;
    attribute maxBridgeLatency: Latency = 20.0 [SI::millisecond];
    port analogDataIn: AnalogInputPort;
    port digitalDataInOut: DigitalIoPort;
    port networkInOut: EthernetPort;
    port statusOut: StatusPort;
  }

  part def NetworkInterface {
    attribute supportedRate: DataRate = 100.0 ["Mbit/s"];
    port ethernet: EthernetPort;
    port processorLink: EthernetPort;
  }

  action def AcquireIo {
    in analogSignal: AnalogSignal;
    in digitalSignal: DigitalIoSignal;
    out sampledAnalog: AnalogSignal;
    out sampledDigital: DigitalIoSignal;
  }

  action def TranslateIoToNetwork {
    in sampledAnalog: AnalogSignal;
    in sampledDigital: DigitalIoSignal;
    out telemetryFrame: NetworkFrame;
  }

  action def TranslateNetworkToIo {
    in commandFrame: NetworkFrame;
    out digitalCommand: DigitalIoSignal;
  }

  action def PublishBridgeStatus {
    in activeChannels: Integer;
    in faultPresent: Boolean;
    out status: BridgeStatus;
  }

  state def IoBridgeLifecycle {
    state Off;
    state Initializing;
    state Operational;
    state Degraded;
    state Faulted;

    transition initial then Off;
    transition powerApplied first Off then Initializing;
    transition initializationComplete first Initializing then Operational;
    transition minorFaultDetected first Operational then Degraded;
    transition faultCleared first Degraded then Operational;
    transition criticalFaultDetected first Operational then Faulted;
    transition criticalFaultDetectedFromDegraded first Degraded then Faulted;
    transition reset first Faulted then Initializing;
    transition powerRemoved first Operational then Off;
    transition powerRemovedFromDegraded first Degraded then Off;
    transition powerRemovedFromFaulted first Faulted then Off;
  }

  part def IoBridge {
    attribute nominalSupplyVoltage: Voltage = 24.0 [SI::volt];
    attribute operatingTemperatureMin: Temperature = -20.0 [SI::degreeCelsius];
    attribute operatingTemperatureMax: Temperature = 70.0 [SI::degreeCelsius];
    attribute primaryFunction: String = "Bridge local analog and digital input/output signals to network messages, and bridge network commands back to local output channels.";

    port analogInputs: AnalogInputPort;
    port digitalIo: DigitalIoPort;
    port network: EthernetPort;
    port status: StatusPort;

    part powerRegulator: PowerRegulator;
    part signalConditioner: SignalConditioner;
    part digitalBank: DigitalIoBank;
    part processor: BridgeProcessor;
    part networkInterface: NetworkInterface;

    connection analogPath connect analogInputs to signalConditioner.analogIn;
    connection conditionedAnalogPath connect signalConditioner.conditionedOut to processor.analogDataIn;
    connection digitalPath connect digitalIo to digitalBank.io;
    connection processorDigitalPath connect digitalBank.io to processor.digitalDataInOut;
    connection processorNetworkPath connect processor.networkInOut to networkInterface.processorLink;
    connection externalNetworkPath connect networkInterface.ethernet to network;
    connection statusPath connect processor.statusOut to status;

    perform action acquireIo: AcquireIo;
    perform action ioToNetwork: TranslateIoToNetwork;
    perform action networkToIo: TranslateNetworkToIo;
    perform action publishStatus: PublishBridgeStatus;

    exhibit state lifecycle: IoBridgeLifecycle;
  }

  requirement def PrimaryFunctionRequirement {
    subject bridge: IoBridge;
    require constraint {
      bridge.primaryFunction ==
      "Bridge local analog and digital input/output signals to network messages, and bridge network commands back to local output channels."
    }
  }

  requirement def LatencyRequirement {
    subject bridge: IoBridge;
    require constraint {
      bridge.processor.maxBridgeLatency <= 20.0 [SI::millisecond]
    }
  }

  requirement def ChannelCapacityRequirement {
    subject bridge: IoBridge;
    require constraint {
      bridge.signalConditioner.channelCount >= 8 and
      bridge.digitalBank.channelCount >= 16
    }
  }

  requirement def NetworkRateRequirement {
    subject bridge: IoBridge;
    require constraint {
      bridge.networkInterface.supportedRate >= 100.0 ["Mbit/s"]
    }
  }

  requirement def EnvironmentalRequirement {
    subject bridge: IoBridge;
    require constraint {
      bridge.operatingTemperatureMin <= -20.0 [SI::degreeCelsius] and
      bridge.operatingTemperatureMax >= 70.0 [SI::degreeCelsius]
    }
  }

  part ioBridgeSystem: IoBridge;

  satisfy PrimaryFunctionRequirement by ioBridgeSystem;
  satisfy LatencyRequirement by ioBridgeSystem;
  satisfy ChannelCapacityRequirement by ioBridgeSystem;
  satisfy NetworkRateRequirement by ioBridgeSystem;
  satisfy EnvironmentalRequirement by ioBridgeSystem;
}