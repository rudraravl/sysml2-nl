package GasTurbineHighLevelDesign {

  import ScalarValues::*;

  attribute def Temperature :> Real {
    attribute unit : String = "K";
  }

  attribute def Pressure :> Real {
    attribute unit : String = "Pa";
  }

  attribute def MassFlowRate :> Real {
    attribute unit : String = "kg/s";
  }

  attribute def VolumeFlowRate :> Real {
    attribute unit : String = "m^3/s";
  }

  attribute def Power :> Real {
    attribute unit : String = "W";
  }

  attribute def Energy :> Real {
    attribute unit : String = "J";
  }

  attribute def SpecificEnergy :> Real {
    attribute unit : String = "J/kg";
  }

  attribute def Torque :> Real {
    attribute unit : String = "N*m";
  }

  attribute def RotationalSpeed :> Real {
    attribute unit : String = "rad/s";
  }

  attribute def Frequency :> Real {
    attribute unit : String = "Hz";
  }

  attribute def Voltage :> Real {
    attribute unit : String = "V";
  }

  attribute def Current :> Real {
    attribute unit : String = "A";
  }

  attribute def Ratio :> Real {
    attribute unit : String = "1";
  }

  attribute def Efficiency :> Ratio;

  attribute def FuelAirRatio :> Ratio;

  attribute def TimeDuration :> Real {
    attribute unit : String = "s";
  }

  attribute def VibrationLevel :> Real {
    attribute unit : String = "mm/s";
  }

  attribute def EmissionIndex :> Real {
    attribute unit : String = "g/kgFuel";
  }

  attribute def PositionPercent :> Real {
    attribute unit : String = "%";
  }

  attribute def BooleanCommand :> Boolean;

  enum def OperatingMode {
    enum off;
    enum standby;
    enum start;
    enum ignition;
    enum acceleration;
    enum synchronized;
    enum loaded;
    enum cooldown;
    enum trip;
    enum maintenance;
  }

  enum def FuelType {
    enum naturalGas;
    enum diesel;
    enum hydrogenBlend;
  }

  enum def HealthState {
    enum normal;
    enum degraded;
    enum warning;
    enum fault;
    enum shutdownRequired;
  }

  enum def CommandKind {
    enum startCommand;
    enum stopCommand;
    enum loadSetpointCommand;
    enum emergencyTripCommand;
    enum purgeCommand;
    enum resetCommand;
  }

  item def Air {
    attribute massFlow : MassFlowRate;
    attribute temperature : Temperature;
    attribute pressure : Pressure;
    attribute oxygenMoleFraction : Ratio = 0.2095;
    attribute humidityRatio : Ratio;
  }

  item def FilteredAir :> Air {
    attribute particulateLoading : Ratio;
  }

  item def CompressedAir :> Air {
    attribute compressorPressureRatio : Ratio;
  }

  item def Fuel {
    attribute fuelType : FuelType;
    attribute massFlow : MassFlowRate;
    attribute lowerHeatingValue : SpecificEnergy;
    attribute supplyPressure : Pressure;
    attribute supplyTemperature : Temperature;
  }

  item def AtomizedFuel :> Fuel {
    attribute dropletQuality : Ratio;
  }

  item def CombustionGas {
    attribute massFlow : MassFlowRate;
    attribute temperature : Temperature;
    attribute pressure : Pressure;
    attribute fuelAirRatio : FuelAirRatio;
    attribute enthalpyFlow : Power;
  }

  item def ExhaustGas :> CombustionGas {
    attribute oxygenMoleFraction : Ratio;
    attribute nitrogenOxidesIndex : EmissionIndex;
    attribute carbonMonoxideIndex : EmissionIndex;
  }

  item def ShaftPower {
    attribute power : Power;
    attribute torque : Torque;
    attribute speed : RotationalSpeed;
  }

  item def ElectricalPower {
    attribute activePower : Power;
    attribute voltage : Voltage;
    attribute current : Current;
    attribute frequency : Frequency;
    attribute powerFactor : Ratio;
  }

  item def ControlCommand {
    attribute kind : CommandKind;
    attribute requestedLoad : Power;
    attribute requestedSpeed : RotationalSpeed;
    attribute enable : BooleanCommand;
  }

  item def ControlStatus {
    attribute mode : OperatingMode;
    attribute health : HealthState;
    attribute measuredSpeed : RotationalSpeed;
    attribute measuredPower : Power;
    attribute exhaustTemperature : Temperature;
    attribute alarmActive : Boolean;
  }

  item def TemperatureSignal {
    attribute value : Temperature;
    attribute valid : Boolean;
  }

  item def PressureSignal {
    attribute value : Pressure;
    attribute valid : Boolean;
  }

  item def SpeedSignal {
    attribute value : RotationalSpeed;
    attribute valid : Boolean;
  }

  item def VibrationSignal {
    attribute value : VibrationLevel;
    attribute valid : Boolean;
  }

  item def ValvePositionSignal {
    attribute value : PositionPercent;
    attribute valid : Boolean;
  }

  port def AirInletPort {
    in item air : Air;
    attribute designMassFlow : MassFlowRate;
    attribute designPressure : Pressure;
    attribute designTemperature : Temperature;
  }

  port def AirOutletPort {
    out item air : Air;
    attribute designMassFlow : MassFlowRate;
    attribute designPressure : Pressure;
    attribute designTemperature : Temperature;
  }

  port def CompressedAirInletPort {
    in item compressedAir : CompressedAir;
    attribute designMassFlow : MassFlowRate;
    attribute designPressure : Pressure;
    attribute designTemperature : Temperature;
  }

  port def CompressedAirOutletPort {
    out item compressedAir : CompressedAir;
    attribute designMassFlow : MassFlowRate;
    attribute designPressure : Pressure;
    attribute designTemperature : Temperature;
  }

  port def FuelInletPort {
    in item fuel : Fuel;
    attribute minimumSupplyPressure : Pressure;
    attribute maximumSupplyPressure : Pressure;
  }

  port def FuelOutletPort {
    out item fuel : Fuel;
    attribute regulatedPressure : Pressure;
    attribute maximumMassFlow : MassFlowRate;
  }

  port def AtomizedFuelPort {
    out item atomizedFuel : AtomizedFuel;
    attribute commandedFlow : MassFlowRate;
  }

  port def CombustionGasInletPort {
    in item gas : CombustionGas;
    attribute designTemperature : Temperature;
    attribute designPressure : Pressure;
  }

  port def CombustionGasOutletPort {
    out item gas : CombustionGas;
    attribute designTemperature : Temperature;
    attribute designPressure : Pressure;
  }

  port def ExhaustGasInletPort {
    in item exhaust : ExhaustGas;
    attribute designMassFlow : MassFlowRate;
  }

  port def ExhaustGasOutletPort {
    out item exhaust : ExhaustGas;
    attribute stackTemperature : Temperature;
  }

  port def ShaftPort {
    inout item shaftPower : ShaftPower;
    attribute ratedSpeed : RotationalSpeed;
    attribute ratedTorque : Torque;
  }

  port def ElectricalPort {
    out item electricalPower : ElectricalPower;
    attribute nominalVoltage : Voltage;
    attribute nominalFrequency : Frequency;
  }

  port def CommandInputPort {
    in item command : ControlCommand;
  }

  port def StatusOutputPort {
    out item status : ControlStatus;
  }

  port def TemperatureSignalPort {
    out item signal : TemperatureSignal;
  }

  port def PressureSignalPort {
    out item signal : PressureSignal;
  }

  port def SpeedSignalPort {
    out item signal : SpeedSignal;
  }

  port def VibrationSignalPort {
    out item signal : VibrationSignal;
  }

  port def ValveCommandPort {
    in item command : ControlCommand;
  }

  port def ValvePositionPort {
    out item signal : ValvePositionSignal;
  }

  part def AirIntakeSystem {
    attribute inletLossCoefficient : Ratio = 0.025;
    attribute filtrationEfficiency : Efficiency = 0.995;
    attribute antiIcingEnabled : Boolean = true;

    port ambientAirIn : AirInletPort {
      :>> designMassFlow = 120.0;
      :>> designPressure = 101325.0;
      :>> designTemperature = 288.15;
    }

    port filteredAirOut : AirOutletPort {
      :>> designMassFlow = 120.0;
      :>> designPressure = 100000.0;
      :>> designTemperature = 288.15;
    }
  }

  part def AxialCompressor {
    attribute stageCount : Integer = 14;
    attribute designPressureRatio : Ratio = 16.5;
    attribute isentropicEfficiency : Efficiency = 0.88;
    attribute surgeMargin : Ratio = 0.12;
    attribute variableGuideVanePosition : PositionPercent = 35.0;

    port airIn : AirInletPort {
      :>> designMassFlow = 120.0;
      :>> designPressure = 100000.0;
      :>> designTemperature = 288.15;
    }

    port compressedAirOut : CompressedAirOutletPort {
      :>> designMassFlow = 120.0;
      :>> designPressure = 1650000.0;
      :>> designTemperature = 670.0;
    }

    port driveShaft : ShaftPort {
      :>> ratedSpeed = 314.16;
      :>> ratedTorque = 410000.0;
    }
  }

  part def FuelSupplySystem {
    attribute fuelTypeSelected : FuelType = FuelType::naturalGas;
    attribute minimumFuelHeatingValue : SpecificEnergy = 45000000.0;
    attribute fuelFilterEfficiency : Efficiency = 0.99;

    port fuelSupplyIn : FuelInletPort {
      :>> minimumSupplyPressure = 2200000.0;
      :>> maximumSupplyPressure = 3500000.0;
    }

    port meteredFuelOut : FuelOutletPort {
      :>> regulatedPressure = 2000000.0;
      :>> maximumMassFlow = 2.9;
    }
  }

  part def FuelControlValve {
    attribute failSafeClosed : Boolean = true;
    attribute maximumOpening : PositionPercent = 100.0;
    attribute minimumStableOpening : PositionPercent = 8.0;
    attribute currentOpening : PositionPercent = 0.0;

    port fuelIn : FuelInletPort {
      :>> minimumSupplyPressure = 1800000.0;
      :>> maximumSupplyPressure = 2200000.0;
    }

    port fuelOut : AtomizedFuelPort {
      :>> commandedFlow = 0.0;
    }

    port valveCommand : ValveCommandPort;
    port valvePositionFeedback : ValvePositionPort;
  }

  part def AnnularCombustor {
    attribute linerCount : Integer = 1;
    attribute burnerCanCount : Integer = 18;
    attribute combustionEfficiency : Efficiency = 0.992;
    attribute pressureLossRatio : Ratio = 0.045;
    attribute designTurbineInletTemperature : Temperature = 1420.0;
    attribute leanBlowoutFuelAirRatio : FuelAirRatio = 0.012;

    port compressedAirIn : CompressedAirInletPort {
      :>> designMassFlow = 120.0;
      :>> designPressure = 1650000.0;
      :>> designTemperature = 670.0;
    }

    port atomizedFuelIn : FuelInletPort {
      :>> minimumSupplyPressure = 1800000.0;
      :>> maximumSupplyPressure = 2200000.0;
    }

    port hotGasOut : CombustionGasOutletPort {
      :>> designTemperature = 1420.0;
      :>> designPressure = 1575000.0;
    }
  }

  part def IgnitionSystem {
    attribute igniterCount : Integer = 2;
    attribute ignitionEnergyPerSpark : Energy = 25.0;
    attribute maximumIgnitionDuration : TimeDuration = 30.0;
    attribute energized : Boolean = false;

    port commandIn : CommandInputPort;
    port statusOut : StatusOutputPort;
  }

  part def HighPressureTurbine {
    attribute stageCount : Integer = 3;
    attribute isentropicEfficiency : Efficiency = 0.91;
    attribute bladeCoolingAirFraction : Ratio = 0.08;
    attribute maximumInletTemperature : Temperature = 1450.0;

    port hotGasIn : CombustionGasInletPort {
      :>> designTemperature = 1420.0;
      :>> designPressure = 1575000.0;
    }

    port exhaustGasOut : ExhaustGasOutletPort {
      :>> stackTemperature = 780.0;
    }

    port outputShaft : ShaftPort {
      :>> ratedSpeed = 314.16;
      :>> ratedTorque = 520000.0;
    }
  }

  part def StarterMotor {
    attribute ratedStartingPower : Power = 1200000.0;
    attribute cutoutSpeed : RotationalSpeed = 210.0;
    attribute engaged : Boolean = false;

    port electricalStartPowerIn : CommandInputPort;
    port starterShaft : ShaftPort {
      :>> ratedSpeed = 210.0;
      :>> ratedTorque = 5800.0;
    }
  }

  part def ExhaustSystem {
    attribute diffuserPressureRecovery : Ratio = 0.35;
    attribute stackBackPressure : Pressure = 4500.0;
    attribute silencerInsertionLoss : Ratio = 0.85;

    port exhaustIn : ExhaustGasInletPort {
      :>> designMassFlow = 122.5;
    }

    port stackOut : ExhaustGasOutletPort {
      :>> stackTemperature = 760.0;
    }
  }

  part def ElectricGenerator {
    attribute ratedActivePower : Power = 32000000.0;
    attribute ratedVoltage : Voltage = 13800.0;
    attribute ratedFrequency : Frequency = 50.0;
    attribute generatorEfficiency : Efficiency = 0.975;
    attribute poleCount : Integer = 4;

    port mechanicalInput : ShaftPort {
      :>> ratedSpeed = 314.16;
      :>> ratedTorque = 101860.0;
    }

    port electricalOutput : ElectricalPort {
      :>> nominalVoltage = 13800.0;
      :>> nominalFrequency = 50.0;
    }
  }

  part def PowerExportInterface {
    attribute gridCodeFrequencyLowLimit : Frequency = 49.5;
    attribute gridCodeFrequencyHighLimit : Frequency = 50.5;
    attribute maximumExportPower : Power = 31000000.0;

    port generatorPowerIn : ElectricalPort {
      :>> nominalVoltage = 13800.0;
      :>> nominalFrequency = 50.0;
    }

    port plantPowerOut : ElectricalPort {
      :>> nominalVoltage = 13800.0;
      :>> nominalFrequency = 50.0;
    }
  }

  part def SensorSuite {
    attribute sensorRedundancyLevel : Integer = 2;

    port compressorDischargePressure : PressureSignalPort;
    port turbineInletTemperature : TemperatureSignalPort;
    port exhaustTemperature : TemperatureSignalPort;
    port shaftSpeed : SpeedSignalPort;
    port bearingVibration : VibrationSignalPort;
    port fuelValvePosition : ValvePositionPort;
  }

  part def GasTurbineController {
    attribute speedSetpoint : RotationalSpeed = 314.16;
    attribute loadSetpoint : Power = 25000000.0;
    attribute exhaustTemperatureLimit : Temperature = 880.0;
    attribute overspeedTripSetpoint : RotationalSpeed = 345.0;
    attribute highVibrationTripSetpoint : VibrationLevel = 12.5;
    attribute activeMode : OperatingMode = OperatingMode::off;

    port operatorCommandIn : CommandInputPort;
    port systemStatusOut : StatusOutputPort;

    port fuelValveCommandOut : ValveCommandPort;
    port ignitionCommandOut : CommandInputPort;
    port starterCommandOut : CommandInputPort;

    port compressorPressureIn : PressureSignalPort;
    port turbineTemperatureIn : TemperatureSignalPort;
    port exhaustTemperatureIn : TemperatureSignalPort;
    port speedIn : SpeedSignalPort;
    port vibrationIn : VibrationSignalPort;
    port valvePositionIn : ValvePositionPort;
  }

  action def DrawAmbientAir {
    in item ambientAir : Air;
    out item filteredAir : FilteredAir;
    attribute pressureLoss : Pressure;
  }

  action def CompressAir {
    in item filteredAir : FilteredAir;
    in item shaftPowerConsumed : ShaftPower;
    out item compressedAir : CompressedAir;
    attribute pressureRatio : Ratio = 16.5;
    attribute compressorEfficiency : Efficiency = 0.88;
  }

  action def MeterFuel {
    in item rawFuel : Fuel;
    in item fuelCommand : ControlCommand;
    out item meteredFuel : AtomizedFuel;
    attribute commandedMassFlow : MassFlowRate;
  }

  action def BurnFuelWithCompressedAir {
    in item compressedAir : CompressedAir;
    in item meteredFuel : AtomizedFuel;
    out item hotGas : CombustionGas;
    attribute combustorEfficiency : Efficiency = 0.992;
    attribute turbineInletTemperature : Temperature;
  }

  action def ExpandHotGas {
    in item hotGas : CombustionGas;
    out item exhaustGas : ExhaustGas;
    out item producedShaftPower : ShaftPower;
    attribute turbineEfficiency : Efficiency = 0.91;
  }

  action def ConvertShaftPowerToElectricalPower {
    in item shaftPower : ShaftPower;
    out item electricalPower : ElectricalPower;
    attribute conversionEfficiency : Efficiency = 0.975;
  }

  action def ExportElectricalPower {
    in item generatorPower : ElectricalPower;
    out item deliveredPower : ElectricalPower;
    attribute exportLimit : Power = 31000000.0;
  }

  action def StartGasTurbine {
    in item startCommand : ControlCommand;
    out item startStatus : ControlStatus;

    action energizeStarter;
    action accelerateRotor;
    action purgeCombustor;
    action enableIgnition;
    action admitStartFuel;
    action detectFlame;
    action disengageStarter;
  }

  action def StopGasTurbine {
    in item stopCommand : ControlCommand;
    out item stopStatus : ControlStatus;

    action reduceLoad;
    action closeFuelValve;
    action motorDownRotor;
    action coolDown;
  }

  action def GenerateUsefulPower {
    in item ambientAir : Air;
    in item fuel : Fuel;
    out item exhaust : ExhaustGas;
    out item exportedPower : ElectricalPower;

    action drawAir : DrawAmbientAir;
    action compress : CompressAir;
    action meterFuel : MeterFuel;
    action combust : BurnFuelWithCompressedAir;
    action expand : ExpandHotGas;
    action generateElectricity : ConvertShaftPowerToElectricalPower;
    action exportPower : ExportElectricalPower;

    flow drawAir.filteredAir to compress.filteredAir;
    flow compress.compressedAir to combust.compressedAir;
    flow meterFuel.meteredFuel to combust.meteredFuel;
    flow combust.hotGas to expand.hotGas;
    flow expand.producedShaftPower to generateElectricity.shaftPower;
    flow generateElectricity.electricalPower to exportPower.generatorPower;
    flow expand.exhaustGas to exhaust;
    flow exportPower.deliveredPower to exportedPower;
  }

  state def GasTurbineOperatingStateMachine {
    attribute mode : OperatingMode;

    state off;
    state standby;
    state starting;
    state purging;
    state igniting;
    state accelerating;
    state synchronized;
    state loaded;
    state cooldown;
    state tripped;
    state maintenance;

    transition initialToOff first off;

    transition offToStandby
      first off
      then standby;

    transition standbyToStarting
      first standby
      accept ControlCommand
      if command.kind == CommandKind::startCommand
      then starting;

    transition startingToPurging
      first starting
      then purging;

    transition purgingToIgniting
      first purging
      then igniting;

    transition ignitingToAccelerating
      first igniting
      if status.health != HealthState::fault
      then accelerating;

    transition acceleratingToSynchronized
      first accelerating
      if status.measuredSpeed >= 314.16
      then synchronized;

    transition synchronizedToLoaded
      first synchronized
      accept ControlCommand
      if command.kind == CommandKind::loadSetpointCommand
      then loaded;

    transition loadedToCooldown
      first loaded
      accept ControlCommand
      if command.kind == CommandKind::stopCommand
      then cooldown;

    transition cooldownToStandby
      first cooldown
      if status.exhaustTemperature <= 420.0
      then standby;

    transition anyToTrippedFromStarting
      first starting
      accept ControlCommand
      if command.kind == CommandKind::emergencyTripCommand
      then tripped;

    transition anyToTrippedFromLoaded
      first loaded
      if status.health == HealthState::shutdownRequired
      then tripped;

    transition trippedToStandby
      first tripped
      accept ControlCommand
      if command.kind == CommandKind::resetCommand
      then standby;

    transition standbyToMaintenance
      first standby
      then maintenance;
  }

  constraint def CompressorOutletPressureConstraint {
    in inletPressure : Pressure;
    in pressureRatio : Ratio;
    in outletPressure : Pressure;

    outletPressure >= inletPressure * pressureRatio * 0.97;
  }

  constraint def CombustorTemperatureLimitConstraint {
    in turbineInletTemperature : Temperature;
    in maximumAllowedTemperature : Temperature;

    turbineInletTemperature <= maximumAllowedTemperature;
  }

  constraint def NetPowerBalanceConstraint {
    in turbinePower : Power;
    in compressorPower : Power;
    in accessoryPower : Power;
    in generatorEfficiency : Efficiency;
    in netElectricalPower : Power;

    netElectricalPower <= (turbinePower - compressorPower - accessoryPower) * generatorEfficiency;
  }

  constraint def FuelEnergyInputConstraint {
    in fuelMassFlow : MassFlowRate;
    in lowerHeatingValue : SpecificEnergy;
    in fuelThermalPower : Power;

    fuelThermalPower == fuelMassFlow * lowerHeatingValue;
  }

  constraint def ExhaustEmissionLimitConstraint {
    in noxIndex : EmissionIndex;
    in carbonMonoxideIndex : EmissionIndex;

    noxIndex <= 25.0 and carbonMonoxideIndex <= 15.0;
  }

  requirement def PrimaryFunctionRequirement {
    attribute id : String = "GT-REQ-001";
    attribute text : String = "The gas turbine system shall convert chemical energy in fuel and oxygen from ambient air into controlled shaft power and exported electrical power by compressing air, combusting fuel in the compressed air stream, expanding hot gas through a turbine, and rejecting exhaust safely.";
    attribute minimumContinuousNetElectricalPower : Power = 25000000.0;
    attribute ratedNetElectricalPower : Power = 30000000.0;
  }

  requirement def AirCompressionRequirement {
    attribute id : String = "GT-REQ-002";
    attribute text : String = "The compressor shall raise filtered ambient air pressure by a design pressure ratio of at least 16.0 while maintaining a minimum surge margin of 10 percent at rated operation.";
    attribute minimumPressureRatio : Ratio = 16.0;
    attribute minimumSurgeMargin : Ratio = 0.10;
  }

  requirement def CombustionRequirement {
    attribute id : String = "GT-REQ-003";
    attribute text : String = "The combustor shall mix metered fuel with compressed air and deliver stable high-temperature combustion gas to the turbine without exceeding the turbine inlet temperature limit.";
    attribute minimumCombustionEfficiency : Efficiency = 0.99;
    attribute maximumTurbineInletTemperature : Temperature = 1450.0;
  }

  requirement def ShaftPowerRequirement {
    attribute id : String = "GT-REQ-004";
    attribute text : String = "The turbine shall extract enough power from combustion gas to drive the compressor and provide net useful power to the generator at rated shaft speed.";
    attribute ratedShaftSpeed : RotationalSpeed = 314.16;
    attribute minimumNetShaftPower : Power = 30770000.0;
  }

  requirement def ControlAndProtectionRequirement {
    attribute id : String = "GT-REQ-005";
    attribute text : String = "The controller shall sequence start, ignition, acceleration, synchronization, loading, cooldown, and trip functions while protecting against overspeed, excessive exhaust temperature, low fuel pressure, and high vibration.";
    attribute overspeedTripSetpoint : RotationalSpeed = 345.0;
    attribute exhaustTemperatureLimit : Temperature = 880.0;
    attribute vibrationTripSetpoint : VibrationLevel = 12.5;
  }

  requirement def EmissionsRequirement {
    attribute id : String = "GT-REQ-006";
    attribute text : String = "The exhaust system and combustion process shall limit rated-load nitrogen oxides and carbon monoxide emissions while safely discharging exhaust gas to the stack.";
    attribute maximumNOxIndex : EmissionIndex = 25.0;
    attribute maximumCOIndex : EmissionIndex = 15.0;
  }

  part def GasTurbinePowerSystem {
    attribute primaryFunction : String = "Convert fuel chemical energy and ambient air into useful rotating shaft power and electrical power through compression, combustion, and turbine expansion.";
    attribute ratedNetElectricalPower : Power = 30000000.0;
    attribute minimumContinuousNetElectricalPower : Power = 25000000.0;
    attribute ratedShaftSpeed : RotationalSpeed = 314.16;
    attribute thermalEfficiencyAtRatedLoad : Efficiency = 0.36;
    attribute availabilityTarget : Ratio = 0.97;

    port ambientAirInterface : AirInletPort {
      :>> designMassFlow = 120.0;
      :>> designPressure = 101325.0;
      :>> designTemperature = 288.15;
    }

    port fuelInterface : FuelInletPort {
      :>> minimumSupplyPressure = 2200000.0;
      :>> maximumSupplyPressure = 3500000.0;
    }

    port electricalExportInterface : ElectricalPort {
      :>> nominalVoltage = 13800.0;
      :>> nominalFrequency = 50.0;
    }

    port exhaustInterface : ExhaustGasOutletPort {
      :>> stackTemperature = 760.0;
    }

    port operatorCommandInterface : CommandInputPort;
    port operatorStatusInterface : StatusOutputPort;

    part intake : AirIntakeSystem;
    part compressor : AxialCompressor;
    part fuelSupply : FuelSupplySystem;
    part fuelValve : FuelControlValve;
    part combustor : AnnularCombustor;
    part igniters : IgnitionSystem;
    part turbine : HighPressureTurbine;
    part starter : StarterMotor;
    part exhaust : ExhaustSystem;
    part generator : ElectricGenerator;
    part exportInterface : PowerExportInterface;
    part sensors : SensorSuite;
    part controller : GasTurbineController;

    connect ambientAirInterface to intake.ambientAirIn;
    connect intake.filteredAirOut to compressor.airIn;
    connect compressor.compressedAirOut to combustor.compressedAirIn;

    connect fuelInterface to fuelSupply.fuelSupplyIn;
    connect fuelSupply.meteredFuelOut to fuelValve.fuelIn;
    connect fuelValve.fuelOut to combustor.atomizedFuelIn;

    connect combustor.hotGasOut to turbine.hotGasIn;
    connect turbine.exhaustGasOut to exhaust.exhaustIn;
    connect exhaust.stackOut to exhaustInterface;

    connect compressor.driveShaft to turbine.outputShaft;
    connect turbine.outputShaft to generator.mechanicalInput;
    connect starter.starterShaft to turbine.outputShaft;

    connect generator.electricalOutput to exportInterface.generatorPowerIn;
    connect exportInterface.plantPowerOut to electricalExportInterface;

    connect operatorCommandInterface to controller.operatorCommandIn;
    connect controller.systemStatusOut to operatorStatusInterface;

    connect controller.fuelValveCommandOut to fuelValve.valveCommand;
    connect controller.ignitionCommandOut to igniters.commandIn;
    connect controller.starterCommandOut to starter.electricalStartPowerIn;

    connect sensors.compressorDischargePressure to controller.compressorPressureIn;
    connect sensors.turbineInletTemperature to controller.turbineTemperatureIn;
    connect sensors.exhaustTemperature to controller.exhaustTemperatureIn;
    connect sensors.shaftSpeed to controller.speedIn;
    connect sensors.bearingVibration to controller.vibrationIn;
    connect fuelValve.valvePositionFeedback to controller.valvePositionIn;

    perform normalPowerGeneration : GenerateUsefulPower;
    perform startSequence : StartGasTurbine;
    perform stopSequence : StopGasTurbine;

    state operatingState : GasTurbineOperatingStateMachine;

    constraint compressorPressurePerformance : CompressorOutletPressureConstraint {
      :>> inletPressure = 100000.0;
      :>> pressureRatio = compressor.designPressureRatio;
      :>> outletPressure = 1650000.0;
    }

    constraint combustorTemperatureProtection : CombustorTemperatureLimitConstraint {
      :>> turbineInletTemperature = combustor.designTurbineInletTemperature;
      :>> maximumAllowedTemperature = turbine.maximumInletTemperature;
    }

    constraint ratedNetPowerBalance : NetPowerBalanceConstraint {
      :>> turbinePower = 158000000.0;
      :>> compressorPower = 126000000.0;
      :>> accessoryPower = 1200000.0;
      :>> generatorEfficiency = generator.generatorEfficiency;
      :>> netElectricalPower = ratedNetElectricalPower;
    }

    constraint ratedFuelEnergyInput : FuelEnergyInputConstraint {
      :>> fuelMassFlow = 2.32;
      :>> lowerHeatingValue = 45000000.0;
      :>> fuelThermalPower = 104400000.0;
    }

    constraint ratedEmissions : ExhaustEmissionLimitConstraint {
      :>> noxIndex = 22.0;
      :>> carbonMonoxideIndex = 8.0;
    }

    satisfy PrimaryFunctionRequirement by normalPowerGeneration;
    satisfy AirCompressionRequirement by compressor;
    satisfy CombustionRequirement by combustor;
    satisfy ShaftPowerRequirement by turbine;
    satisfy ControlAndProtectionRequirement by controller;
    satisfy EmissionsRequirement by combustor;
    satisfy EmissionsRequirement by exhaust;
  }

  part gasTurbinePlant : GasTurbinePowerSystem {
    :>> ratedNetElectricalPower = 30000000.0;
    :>> minimumContinuousNetElectricalPower = 25000000.0;
    :>> ratedShaftSpeed = 314.16;
    :>> thermalEfficiencyAtRatedLoad = 0.36;
  }

  requirement primaryFunctionRequirement : PrimaryFunctionRequirement {
    subject gasTurbinePlant;
  }

  requirement airCompressionRequirement : AirCompressionRequirement {
    subject gasTurbinePlant.compressor;
  }

  requirement combustionRequirement : CombustionRequirement {
    subject gasTurbinePlant.combustor;
  }

  requirement shaftPowerRequirement : ShaftPowerRequirement {
    subject gasTurbinePlant.turbine;
  }

  requirement controlAndProtectionRequirement : ControlAndProtectionRequirement {
    subject gasTurbinePlant.controller;
  }

  requirement emissionsRequirement : EmissionsRequirement {
    subject gasTurbinePlant.exhaust;
  }

}
