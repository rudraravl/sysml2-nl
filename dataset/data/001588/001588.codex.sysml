package SuperfluidityBasedThermalTransportSystem {

  import ScalarValues::*;
  import SI::*;
  import ISQ::*;

  value def Temperature {
    unit = "K";
  }

  value def Pressure {
    unit = "Pa";
  }

  value def HeatFlowRate {
    unit = "W";
  }

  value def MassFlowRate {
    unit = "kg/s";
  }

  value def Volume {
    unit = "L";
  }

  value def Length {
    unit = "m";
  }

  value def ElectricalPower {
    unit = "W";
  }

  value def Time {
    unit = "s";
  }

  value def Fraction {
    unit = "1";
  }

  item def Helium4 {
    attribute temperature : Temperature;
    attribute pressure : Pressure;
    attribute superfluidFraction : Fraction;
    attribute normalFluidFraction : Fraction;
  }

  item def HeatLoad {
    attribute thermalPower : HeatFlowRate;
    attribute sourceTemperature : Temperature;
  }

  item def RemovedHeat {
    attribute thermalPower : HeatFlowRate;
    attribute sinkTemperature : Temperature;
  }

  item def ControlCommand {
    attribute targetTemperature : Temperature;
    attribute targetPressure : Pressure;
    attribute targetHeatRemoval : HeatFlowRate;
  }

  item def SensorReport {
    attribute measuredTemperature : Temperature;
    attribute measuredPressure : Pressure;
    attribute measuredHeatFlow : HeatFlowRate;
    attribute measuredSuperfluidFraction : Fraction;
  }

  port def HeliumPort {
    inout item helium : Helium4;
  }

  port def HeatInputPort {
    in item heatLoad : HeatLoad;
  }

  port def HeatOutputPort {
    out item removedHeat : RemovedHeat;
  }

  port def CommandPort {
    in item command : ControlCommand;
  }

  port def TelemetryPort {
    out item report : SensorReport;
  }

  part def SuperfluidHeliumThermalTransportSystem {
    attribute primaryFunction : String =
      "Maintain helium-4 below the lambda transition and use superfluidity to transport heat with near-zero viscous resistance from a protected thermal load to a cryogenic sink.";

    attribute lambdaTemperature : Temperature = 2.17;
    attribute nominalBathTemperature : Temperature = 1.80;
    attribute maximumOperatingPressure : Pressure = 250000.0;
    attribute nominalHeatRemovalCapacity : HeatFlowRate = 75.0;
    attribute startupTimeLimit : Time = 900.0;

    port heatIn : HeatInputPort;
    port heatOut : HeatOutputPort;
    port commandIn : CommandPort;
    port telemetryOut : TelemetryPort;

    part heliumReservoir : HeliumReservoir;
    part lambdaPointRefrigerator : LambdaPointRefrigerator;
    part superfluidChannel : SuperfluidTransportChannel;
    part porousPhaseSeparator : PorousPhaseSeparator;
    part thermalInterface : ThermalLoadInterface;
    part heatSinkInterface : CryogenicHeatSinkInterface;
    part sensorSuite : CryogenicSensorSuite;
    part controller : SuperfluidityController;
    part safetyRelief : PressureReliefAssembly;

    connection heatInputPath connect heatIn to thermalInterface.heatIn;
    connection thermalToChannel connect thermalInterface.heliumOut to superfluidChannel.warmEnd;
    connection channelToSink connect superfluidChannel.coldEnd to heatSinkInterface.heliumIn;
    connection sinkToReservoir connect heatSinkInterface.heliumOut to heliumReservoir.returnPort;
    connection reservoirToRefrigerator connect heliumReservoir.supplyPort to lambdaPointRefrigerator.inlet;
    connection refrigeratorToSeparator connect lambdaPointRefrigerator.outlet to porousPhaseSeparator.inlet;
    connection separatorToChannel connect porousPhaseSeparator.superfluidOutlet to superfluidChannel.supplyPort;
    connection heatOutputPath connect heatSinkInterface.heatOut to heatOut;

    connection commandPath connect commandIn to controller.commandIn;
    connection controlToRefrigerator connect controller.refrigeratorCommand to lambdaPointRefrigerator.commandIn;
    connection controlToRelief connect controller.reliefCommand to safetyRelief.commandIn;
    connection sensorToController connect sensorSuite.telemetryOut to controller.telemetryIn;
    connection systemTelemetry connect sensorSuite.telemetryOut to telemetryOut;

    perform action maintainSuperfluidHeatTransport : MaintainSuperfluidHeatTransport;
    exhibit state operatingState : SuperfluidSystemState;
  }

  part def HeliumReservoir {
    attribute storedVolume : Volume = 120.0;
    attribute bathTemperature : Temperature = 1.85;
    attribute bathPressure : Pressure = 160000.0;

    port supplyPort : HeliumPort;
    port returnPort : HeliumPort;
  }

  part def LambdaPointRefrigerator {
    attribute coolingPower : HeatFlowRate = 120.0;
    attribute electricalInputPower : ElectricalPower = 950.0;
    attribute outletTemperature : Temperature = 1.75;

    port inlet : HeliumPort;
    port outlet : HeliumPort;
    port commandIn : CommandPort;
  }

  part def SuperfluidTransportChannel {
    attribute length : Length = 4.5;
    attribute innerDiameter : Length = 0.018;
    attribute designMassFlowRate : MassFlowRate = 0.035;
    attribute targetSuperfluidFraction : Fraction = 0.90;

    port supplyPort : HeliumPort;
    port warmEnd : HeliumPort;
    port coldEnd : HeliumPort;
  }

  part def PorousPhaseSeparator {
    attribute poreDiameter : Length = 0.0000002;
    attribute normalFluidRejectionFraction : Fraction = 0.96;

    port inlet : HeliumPort;
    port superfluidOutlet : HeliumPort;
    port normalFluidReturn : HeliumPort;
  }

  part def ThermalLoadInterface {
    attribute maximumAcceptedHeatLoad : HeatFlowRate = 75.0;
    attribute interfaceTemperatureLimit : Temperature = 2.05;

    port heatIn : HeatInputPort;
    port heliumOut : HeliumPort;
  }

  part def CryogenicHeatSinkInterface {
    attribute sinkTemperature : Temperature = 1.70;
    attribute rejectionCapacity : HeatFlowRate = 100.0;

    port heliumIn : HeliumPort;
    port heliumOut : HeliumPort;
    port heatOut : HeatOutputPort;
  }

  part def CryogenicSensorSuite {
    attribute temperatureAccuracy : Temperature = 0.005;
    attribute pressureAccuracy : Pressure = 25.0;
    attribute heatFlowAccuracy : HeatFlowRate = 0.5;

    port telemetryOut : TelemetryPort;
  }

  part def SuperfluidityController {
    attribute controlPeriod : Time = 0.1;
    attribute commandedBathTemperature : Temperature = 1.80;
    attribute commandedPressure : Pressure = 160000.0;

    port commandIn : CommandPort;
    port telemetryIn : TelemetryPort;
    port refrigeratorCommand : CommandPort;
    port reliefCommand : CommandPort;
  }

  part def PressureReliefAssembly {
    attribute reliefSetPressure : Pressure = 245000.0;
    attribute reseatPressure : Pressure = 210000.0;

    port commandIn : CommandPort;
  }

  action def MaintainSuperfluidHeatTransport {
    in item requestedCommand : ControlCommand;
    in item appliedHeatLoad : HeatLoad;
    out item rejectedHeat : RemovedHeat;
    out item statusReport : SensorReport;

    first start;
    then coolHeliumBelowLambda;
    then establishSuperfluidFraction;
    then absorbHeatAtLoad;
    then transportHeatThroughSuperfluidChannel;
    then rejectHeatToCryogenicSink;
    then regulateTemperaturePressureAndFlow;
    then publishTelemetry;

    action coolHeliumBelowLambda {
      objective {
        maintain heliumTemperature : Temperature below 2.17;
      }
    }

    action establishSuperfluidFraction {
      objective {
        maintain superfluidFraction : Fraction above 0.85;
      }
    }

    action absorbHeatAtLoad {
      in item appliedHeatLoad : HeatLoad;
    }

    action transportHeatThroughSuperfluidChannel {
      objective {
        minimize viscousPressureDrop : Pressure;
      }
    }

    action rejectHeatToCryogenicSink {
      out item rejectedHeat : RemovedHeat;
    }

    action regulateTemperaturePressureAndFlow {
      objective {
        maintain bathPressure : Pressure below 250000.0;
      }
    }

    action publishTelemetry {
      out item statusReport : SensorReport;
    }
  }

  state def SuperfluidSystemState {
    entry action initializeSensors;
    state Off;
    state PreCool;
    state NormalHeliumCirculation;
    state LambdaTransition;
    state SuperfluidTransport;
    state HeatRejection;
    state FaultIsolation;
    state SafeVent;

    transition initial then Off;

    transition powerApplied
      first Off
      then PreCool;

    transition bathBelowFourKelvin
      first PreCool
      then NormalHeliumCirculation;

    transition temperatureBelowLambda
      first NormalHeliumCirculation
      then LambdaTransition
      guard measuredTemperature <= 2.17;

    transition superfluidEstablished
      first LambdaTransition
      then SuperfluidTransport
      guard measuredSuperfluidFraction >= 0.85;

    transition heatLoadAccepted
      first SuperfluidTransport
      then HeatRejection;

    transition heatTransportStable
      first HeatRejection
      then SuperfluidTransport
      guard measuredHeatFlow <= 75.0;

    transition overTemperatureFault
      first SuperfluidTransport
      then FaultIsolation
      guard measuredTemperature > 2.17;

    transition overPressureFault
      first SuperfluidTransport
      then SafeVent
      guard measuredPressure >= 245000.0;

    transition recoveryComplete
      first FaultIsolation
      then PreCool;

    transition pressureRelieved
      first SafeVent
      then Off;
  }

  requirement def PrimaryFunctionRequirement {
    subject system : SuperfluidHeliumThermalTransportSystem;

    require constraint {
      system.nominalBathTemperature < system.lambdaTemperature
    }

    doc /* The system shall use the superfluid phase of helium-4 as its operating basis to transport heat from a thermal load to a cryogenic sink with near-zero viscous resistance. */
  }

  requirement def LambdaTemperatureRequirement {
    subject system : SuperfluidHeliumThermalTransportSystem;

    require constraint {
      system.nominalBathTemperature <= 1.90
    }

    doc /* The system shall maintain the helium bath temperature below the helium-4 lambda transition during nominal operation. */
  }

  requirement def HeatRemovalRequirement {
    subject system : SuperfluidHeliumThermalTransportSystem;

    require constraint {
      system.nominalHeatRemovalCapacity >= 75.0
    }

    doc /* The system shall remove at least 75 W of heat from the protected thermal interface while operating in the superfluid transport state. */
  }

  requirement def PressureSafetyRequirement {
    subject system : SuperfluidHeliumThermalTransportSystem;

    require constraint {
      system.maximumOperatingPressure <= 250000.0
    }

    doc /* The system shall keep helium circuit pressure at or below 250 kPa during all controlled operating modes. */
  }

  requirement def StartupRequirement {
    subject system : SuperfluidHeliumThermalTransportSystem;

    require constraint {
      system.startupTimeLimit <= 900.0
    }

    doc /* The system shall transition from ambient command start to stable superfluid heat transport within 900 seconds. */
  }

  requirement def SuperfluidFractionRequirement {
    subject channel : SuperfluidTransportChannel;

    require constraint {
      channel.targetSuperfluidFraction >= 0.90
    }

    doc /* The transport channel shall sustain a superfluid fraction of at least 0.90 at the nominal bath temperature. */
  }

  requirement def HeatSinkRequirement {
    subject sink : CryogenicHeatSinkInterface;

    require constraint {
      sink.rejectionCapacity >= 100.0
    }

    doc /* The cryogenic sink interface shall provide margin above the nominal transported heat load. */
  }

  satisfy PrimaryFunctionRequirement by SuperfluidHeliumThermalTransportSystem;
  satisfy LambdaTemperatureRequirement by LambdaPointRefrigerator;
  satisfy HeatRemovalRequirement by SuperfluidTransportChannel;
  satisfy PressureSafetyRequirement by PressureReliefAssembly;
  satisfy StartupRequirement by SuperfluidityController;
  satisfy SuperfluidFractionRequirement by SuperfluidTransportChannel;
  satisfy HeatSinkRequirement by CryogenicHeatSinkInterface;
}