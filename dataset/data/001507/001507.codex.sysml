package MultiFunctionStructureSystem {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  attribute def Voltage :> ISQ::electricPotential {
    unit = SI::volt;
  }

  attribute def Current :> ISQ::electricCurrent {
    unit = SI::ampere;
  }

  attribute def Power :> ISQ::power {
    unit = SI::watt;
  }

  attribute def Temperature :> ISQ::thermodynamicTemperature {
    unit = SI::kelvin;
  }

  attribute def Mass :> ISQ::mass {
    unit = SI::kilogram;
  }

  attribute def DataRate {
    :>> num;
    unit = "Mbit/s";
  }

  attribute def LoadCapacity {
    :>> num;
    unit = SI::newton;
  }

  item def ElectricalEnergy {
    attribute voltage : Voltage;
    attribute current : Current;
    attribute power : Power;
  }

  item def ThermalEnergy {
    attribute temperature : Temperature;
    attribute heatFlow : Power;
  }

  item def DataPacket {
    attribute sourceId : String;
    attribute destinationId : String;
    attribute payloadSize : DataRate;
    attribute priority : Integer;
  }

  item def StructuralLoad {
    attribute force : LoadCapacity;
    attribute loadPathId : String;
  }

  item def MissionCommand {
    attribute commandId : String;
    attribute requestedMode : String;
    attribute priority : Integer;
  }

  port def PowerPort {
    inout item energy : ElectricalEnergy;
  }

  port def ThermalPort {
    inout item heat : ThermalEnergy;
  }

  port def DataPort {
    inout item packet : DataPacket;
  }

  port def LoadPort {
    inout item load : StructuralLoad;
  }

  port def CommandPort {
    in item command : MissionCommand;
  }

  part def MultifunctionStructure {
    attribute mass : Mass = 42 [SI::kilogram];
    attribute maxStructuralLoad : LoadCapacity = 18000 [SI::newton];
    attribute maxContinuousPower : Power = 2400 [SI::watt];
    attribute peakDataRate : DataRate = 1000 ["Mbit/s"];

    port externalPower : PowerPort;
    port externalData : DataPort;
    port externalThermal : ThermalPort;
    port externalLoad : LoadPort;
    port commandInput : CommandPort;

    part loadBearingFrame {
      port frameLoadIn : LoadPort;
      port frameLoadOut : LoadPort;
      attribute allowableLoad : LoadCapacity = 18000 [SI::newton];
      attribute frameMass : Mass = 24 [SI::kilogram];
    }

    part embeddedPowerBus {
      port busPowerIn : PowerPort;
      port busPowerOut : PowerPort;
      attribute nominalVoltage : Voltage = 48 [SI::volt];
      attribute maxCurrent : Current = 50 [SI::ampere];
    }

    part thermalSpreader {
      port heatIn : ThermalPort;
      port heatOut : ThermalPort;
      attribute normalOperatingTemperature : Temperature = 323 [SI::kelvin];
      attribute maximumTemperature : Temperature = 358 [SI::kelvin];
    }

    part dataBackbone {
      port dataIn : DataPort;
      port dataOut : DataPort;
      attribute backboneRate : DataRate = 1000 ["Mbit/s"];
    }

    part controlNode {
      port controlData : DataPort;
      port controlPower : PowerPort;
      port controlCommand : CommandPort;
      attribute processorPower : Power = 85 [SI::watt];
    }

    connection powerFeed connect externalPower to embeddedPowerBus.busPowerIn;
    connection powerToController connect embeddedPowerBus.busPowerOut to controlNode.controlPower;
    connection dataFeed connect externalData to dataBackbone.dataIn;
    connection dataToController connect dataBackbone.dataOut to controlNode.controlData;
    connection thermalPath connect thermalSpreader.heatOut to externalThermal;
    connection loadPath connect externalLoad to loadBearingFrame.frameLoadIn;
    connection commandPath connect commandInput to controlNode.controlCommand;
  }

  part def SensorModule {
    port sensorPower : PowerPort;
    port sensorData : DataPort;
    port sensorThermal : ThermalPort;

    attribute operatingPower : Power = 120 [SI::watt];
    attribute measurementRate : DataRate = 50 ["Mbit/s"];

    action senseEnvironment {
      in item command : MissionCommand;
      out item measurement : DataPacket;
    }
  }

  part def CommunicationModule {
    port commPower : PowerPort;
    port commData : DataPort;
    port commThermal : ThermalPort;

    attribute transmitPower : Power = 300 [SI::watt];
    attribute downlinkRate : DataRate = 250 ["Mbit/s"];

    action routeMissionData {
      in item missionData : DataPacket;
      out item routedData : DataPacket;
    }
  }

  part def ActuationModule {
    port actuatorPower : PowerPort;
    port actuatorData : DataPort;
    port actuatorLoad : LoadPort;
    port actuatorThermal : ThermalPort;

    attribute peakPower : Power = 900 [SI::watt];
    attribute generatedLoad : LoadCapacity = 4500 [SI::newton];

    action executeMechanicalResponse {
      in item command : MissionCommand;
      out item appliedLoad : StructuralLoad;
    }
  }

  part def MultifunctionPlatform {
    doc /* Primary high-level function: provide one integrated physical structure that simultaneously carries mechanical loads, distributes electrical power, transports thermal energy, routes mission data, and coordinates attached functional modules to perform sensing, communication, and actuation services. */

    port platformPower : PowerPort;
    port platformData : DataPort;
    port platformThermal : ThermalPort;
    port platformLoad : LoadPort;
    port platformCommand : CommandPort;

    part structure : MultifunctionStructure;
    part sensors : SensorModule;
    part communications : CommunicationModule;
    part actuators : ActuationModule;

    connection platformPowerInput connect platformPower to structure.externalPower;
    connection platformDataInput connect platformData to structure.externalData;
    connection platformThermalOutput connect structure.externalThermal to platformThermal;
    connection platformLoadInput connect platformLoad to structure.externalLoad;
    connection platformCommandInput connect platformCommand to structure.commandInput;

    connection sensorPowerSupply connect structure.embeddedPowerBus.busPowerOut to sensors.sensorPower;
    connection commPowerSupply connect structure.embeddedPowerBus.busPowerOut to communications.commPower;
    connection actuatorPowerSupply connect structure.embeddedPowerBus.busPowerOut to actuators.actuatorPower;

    connection sensorDataPath connect sensors.sensorData to structure.dataBackbone.dataIn;
    connection commDataPath connect structure.dataBackbone.dataOut to communications.commData;
    connection actuatorDataPath connect structure.dataBackbone.dataOut to actuators.actuatorData;

    connection sensorHeatPath connect sensors.sensorThermal to structure.thermalSpreader.heatIn;
    connection commHeatPath connect communications.commThermal to structure.thermalSpreader.heatIn;
    connection actuatorHeatPath connect actuators.actuatorThermal to structure.thermalSpreader.heatIn;

    connection actuatorLoadPath connect actuators.actuatorLoad to structure.loadBearingFrame.frameLoadOut;

    action performPrimaryFunction {
      in item operatorCommand : MissionCommand;
      out item missionReport : DataPacket;

      first start;

      then distributePower;
      action distributePower {
        out item busEnergy : ElectricalEnergy;
      }

      then routeCommand;
      action routeCommand {
        in item command : MissionCommand = operatorCommand;
        out item routedCommand : MissionCommand;
      }

      then collectMeasurements;
      action collectMeasurements {
        in item command : MissionCommand = routeCommand.routedCommand;
        out item measurementData : DataPacket;
      }

      then controlActuation;
      action controlActuation {
        in item command : MissionCommand = routeCommand.routedCommand;
        out item responseLoad : StructuralLoad;
      }

      then rejectHeat;
      action rejectHeat {
        in item heatLoad : ThermalEnergy;
        out item expelledHeat : ThermalEnergy;
      }

      then transmitReport;
      action transmitReport {
        in item data : DataPacket = collectMeasurements.measurementData;
        out item report : DataPacket = missionReport;
      }

      then done;
    }

    state operationalState {
      entry action initializePlatform;
      state Off;
      state Standby;
      state IntegratedOperation;
      state ThermalProtection;
      state FaultIsolated;
      state Shutdown;

      transition initial then Off;

      transition powerApplied
        first Off
        accept MissionCommand
        if command.requestedMode == "standby"
        then Standby;

      transition activate
        first Standby
        accept MissionCommand
        if command.requestedMode == "operate"
        then IntegratedOperation;

      transition overTemperature
        first IntegratedOperation
        if structure.thermalSpreader.maximumTemperature <= structure.thermalSpreader.normalOperatingTemperature
        then ThermalProtection;

      transition faultDetected
        first IntegratedOperation
        accept MissionCommand
        if command.requestedMode == "fault-isolate"
        then FaultIsolated;

      transition recover
        first FaultIsolated
        accept MissionCommand
        if command.requestedMode == "standby"
        then Standby;

      transition coolDownComplete
        first ThermalProtection
        accept MissionCommand
        if command.requestedMode == "standby"
        then Standby;

      transition shutdown
        first Standby
        accept MissionCommand
        if command.requestedMode == "shutdown"
        then Shutdown;
    }
  }

  requirement def IntegratedMultifunctionRequirement {
    doc /* The platform shall integrate structural support, power distribution, thermal transport, data routing, sensing, communication, and actuation within one multifunction structure. */
  }

  requirement def LoadBearingRequirement {
    doc /* The multifunction structure shall carry operational mechanical loads of at least 18000 N without losing power, data, or thermal-transfer capability. */
    attribute requiredLoad : LoadCapacity = 18000 [SI::newton];
  }

  requirement def PowerDistributionRequirement {
    doc /* The embedded power bus shall distribute at least 2400 W continuous electrical power at 48 V nominal to attached modules. */
    attribute requiredPower : Power = 2400 [SI::watt];
    attribute requiredVoltage : Voltage = 48 [SI::volt];
  }

  requirement def DataRoutingRequirement {
    doc /* The data backbone shall route mission data at a minimum aggregate rate of 1000 Mbit/s between the control node and functional modules. */
    attribute requiredRate : DataRate = 1000 ["Mbit/s"];
  }

  requirement def ThermalManagementRequirement {
    doc /* The thermal spreader shall maintain attached module interface temperature below 358 K during integrated operation. */
    attribute maxInterfaceTemperature : Temperature = 358 [SI::kelvin];
  }

  requirement def PrimaryFunctionRequirement {
    doc /* The system shall perform the high-level primary function of using one integrated structure to support, power, cool, command, and coordinate multiple mission functions. */
  }

  part platform : MultifunctionPlatform;

  requirement integratedReq : IntegratedMultifunctionRequirement;
  requirement loadReq : LoadBearingRequirement;
  requirement powerReq : PowerDistributionRequirement;
  requirement dataReq : DataRoutingRequirement;
  requirement thermalReq : ThermalManagementRequirement;
  requirement primaryFunctionReq : PrimaryFunctionRequirement;

  satisfy platform by integratedReq;
  satisfy platform.structure by loadReq;
  satisfy platform.structure.embeddedPowerBus by powerReq;
  satisfy platform.structure.dataBackbone by dataReq;
  satisfy platform.structure.thermalSpreader by thermalReq;
  satisfy platform by primaryFunctionReq;

}