package FirstLawThermodynamicPowerSystem {

  import ScalarValues::*;
  import SI::*;
  import ISQ::*;

  attribute def Energy :> ISQ::energy {
    :>> unit = SI::J;
  }

  attribute def Power :> ISQ::power {
    :>> unit = SI::W;
  }

  attribute def Mass :> ISQ::mass {
    :>> unit = SI::kg;
  }

  attribute def MassFlowRate {
    :>> unit = SI::kg / SI::s;
  }

  attribute def Temperature :> ISQ::thermodynamicTemperature {
    :>> unit = SI::K;
  }

  attribute def Pressure :> ISQ::pressure {
    :>> unit = SI::Pa;
  }

  attribute def SpecificEnergy {
    :>> unit = SI::J / SI::kg;
  }

  attribute def SpecificEntropy {
    :>> unit = SI::J / SI::kg / SI::K;
  }

  attribute def Volume {
    :>> unit = SI::m^3;
  }

  attribute def AngularSpeed {
    :>> unit = SI::rad / SI::s;
  }

  attribute def Torque {
    :>> unit = SI::N * SI::m;
  }

  attribute def Voltage {
    :>> unit = SI::V;
  }

  attribute def Current {
    :>> unit = SI::A;
  }

  attribute def Frequency {
    :>> unit = SI::Hz;
  }

  attribute def Efficiency {
    :>> unit = SI::one;
  }

  attribute def Fraction {
    :>> unit = SI::one;
  }

  enum def WorkingFluidPhase {
    enum compressedLiquid;
    enum saturatedLiquid;
    enum twoPhaseMixture;
    enum saturatedVapor;
    enum superheatedVapor;
  }

  enum def PlantMode {
    enum off;
    enum starting;
    enum preheating;
    enum generating;
    enum standby;
    enum shuttingDown;
    enum faulted;
  }

  item def HydrocarbonFuel {
    attribute massFlowRate : MassFlowRate;
    attribute lowerHeatingValue : SpecificEnergy;
    attribute supplyTemperature : Temperature;
    attribute chemicalEnergyRate : Power;
  }

  item def WorkingFluid {
    attribute massFlowRate : MassFlowRate;
    attribute pressure : Pressure;
    attribute temperature : Temperature;
    attribute specificEnthalpy : SpecificEnergy;
    attribute specificInternalEnergy : SpecificEnergy;
    attribute specificEntropy : SpecificEntropy;
    attribute vaporQuality : Fraction;
    attribute phase : WorkingFluidPhase;
  }

  item def HeatTransfer {
    attribute heatRate : Power;
    attribute boundaryTemperature : Temperature;
  }

  item def RejectedHeat {
    attribute heatRate : Power;
    attribute sinkTemperature : Temperature;
  }

  item def ShaftPower {
    attribute power : Power;
    attribute torque : Torque;
    attribute angularSpeed : AngularSpeed;
  }

  item def ElectricalPower {
    attribute realPower : Power;
    attribute voltage : Voltage;
    attribute current : Current;
    attribute frequency : Frequency;
  }

  item def ControlCommand {
    attribute requestedNetPower : Power;
    attribute requestedMode : PlantMode;
  }

  item def EnergyTelemetry {
    attribute heatInputRate : Power;
    attribute heatRejectedRate : Power;
    attribute shaftPowerRate : Power;
    attribute electricPowerRate : Power;
    attribute storedEnergyRate : Power;
    attribute thermalEfficiency : Efficiency;
    attribute firstLawResidual : Power;
  }

  port def FuelInletPort {
    in item fuel : HydrocarbonFuel;
  }

  port def HeatInputPort {
    in item heat : HeatTransfer;
  }

  port def HeatOutputPort {
    out item heat : RejectedHeat;
  }

  port def FluidInletPort {
    in item fluid : WorkingFluid;
  }

  port def FluidOutletPort {
    out item fluid : WorkingFluid;
  }

  port def ShaftPowerInputPort {
    in item shaftPower : ShaftPower;
  }

  port def ShaftPowerOutputPort {
    out item shaftPower : ShaftPower;
  }

  port def ElectricalPowerOutputPort {
    out item electricalPower : ElectricalPower;
  }

  port def CommandInputPort {
    in item command : ControlCommand;
  }

  port def TelemetryOutputPort {
    out item telemetry : EnergyTelemetry;
  }

  constraint def FirstLawControlVolumeBalance {
    in storedEnergyRate : Power;
    in heatTransferRateIn : Power;
    in heatTransferRateOut : Power;
    in workRateOut : Power;
    in workRateIn : Power;
    in enthalpyFlowRateIn : Power;
    in enthalpyFlowRateOut : Power;

    constraint firstLaw {
      storedEnergyRate == heatTransferRateIn - heatTransferRateOut - workRateOut + workRateIn + enthalpyFlowRateIn - enthalpyFlowRateOut;
    }
  }

  constraint def FuelChemicalPowerDefinition {
    in fuelMassFlowRate : MassFlowRate;
    in lowerHeatingValue : SpecificEnergy;
    out chemicalEnergyRate : Power;

    constraint chemicalPower {
      chemicalEnergyRate == fuelMassFlowRate * lowerHeatingValue;
    }
  }

  constraint def ThermalEfficiencyDefinition {
    in usefulElectricPower : Power;
    in heatInputRate : Power;
    out efficiency : Efficiency;

    constraint efficiencyEquation {
      efficiency == usefulElectricPower / heatInputRate;
    }
  }

  constraint def ShaftPowerDefinition {
    in torque : Torque;
    in angularSpeed : AngularSpeed;
    out shaftPower : Power;

    constraint shaftPowerEquation {
      shaftPower == torque * angularSpeed;
    }
  }

  constraint def GeneratorPowerDefinition {
    in shaftPowerIn : Power;
    in generatorEfficiency : Efficiency;
    out electricPowerOut : Power;

    constraint generatorPowerEquation {
      electricPowerOut == shaftPowerIn * generatorEfficiency;
    }
  }

  constraint def FirstLawResidualDefinition {
    in storedEnergyRate : Power;
    in heatTransferRateIn : Power;
    in heatTransferRateOut : Power;
    in workRateOut : Power;
    in workRateIn : Power;
    in enthalpyFlowRateIn : Power;
    in enthalpyFlowRateOut : Power;
    out residual : Power;

    constraint residualEquation {
      residual == storedEnergyRate - (heatTransferRateIn - heatTransferRateOut - workRateOut + workRateIn + enthalpyFlowRateIn - enthalpyFlowRateOut);
    }
  }

  part def CombustionHeatSource {
    port fuelIn : FuelInletPort;
    port heatOut : HeatOutputPort;
    port commandIn : CommandInputPort;

    attribute fuelMassFlowRate : MassFlowRate;
    attribute fuelLowerHeatingValue : SpecificEnergy;
    attribute chemicalEnergyRate : Power;
    attribute combustionEfficiency : Efficiency = 0.92;
    attribute heatReleaseRate : Power;
    attribute casingLossRate : Power;
    attribute exhaustLossRate : Power;
    attribute storedEnergyRate : Power;

    constraint chemicalPower : FuelChemicalPowerDefinition {
      fuelMassFlowRate = fuelMassFlowRate;
      lowerHeatingValue = fuelLowerHeatingValue;
      chemicalEnergyRate = chemicalEnergyRate;
    }

    constraint firstLaw : FirstLawControlVolumeBalance {
      storedEnergyRate = storedEnergyRate;
      heatTransferRateIn = chemicalEnergyRate;
      heatTransferRateOut = casingLossRate + exhaustLossRate;
      workRateOut = 0.0 [SI::W];
      workRateIn = 0.0 [SI::W];
      enthalpyFlowRateIn = 0.0 [SI::W];
      enthalpyFlowRateOut = 0.0 [SI::W];
    }

    constraint usefulHeat {
      heatReleaseRate == chemicalEnergyRate * combustionEfficiency;
    }
  }

  part def BoilerHeatExchanger {
    port heatIn : HeatInputPort;
    port feedwaterIn : FluidInletPort;
    port steamOut : FluidOutletPort;
    port telemetryOut : TelemetryOutputPort;

    attribute metalInternalEnergy : Energy;
    attribute storedEnergyRate : Power;
    attribute heatInputRate : Power;
    attribute heatLossRate : Power;
    attribute feedwaterMassFlowRate : MassFlowRate;
    attribute feedwaterSpecificEnthalpy : SpecificEnergy;
    attribute steamMassFlowRate : MassFlowRate;
    attribute steamSpecificEnthalpy : SpecificEnergy;
    attribute enthalpyFlowRateIn : Power;
    attribute enthalpyFlowRateOut : Power;
    attribute drumPressure : Pressure;
    attribute outletTemperature : Temperature;
    attribute outletVaporQuality : Fraction;

    constraint inletEnthalpyFlow {
      enthalpyFlowRateIn == feedwaterMassFlowRate * feedwaterSpecificEnthalpy;
    }

    constraint outletEnthalpyFlow {
      enthalpyFlowRateOut == steamMassFlowRate * steamSpecificEnthalpy;
    }

    constraint firstLaw : FirstLawControlVolumeBalance {
      storedEnergyRate = storedEnergyRate;
      heatTransferRateIn = heatInputRate;
      heatTransferRateOut = heatLossRate;
      workRateOut = 0.0 [SI::W];
      workRateIn = 0.0 [SI::W];
      enthalpyFlowRateIn = enthalpyFlowRateIn;
      enthalpyFlowRateOut = enthalpyFlowRateOut;
    }
  }

  part def SteamTurbineExpander {
    port steamIn : FluidInletPort;
    port exhaustOut : FluidOutletPort;
    port shaftOut : ShaftPowerOutputPort;
    port telemetryOut : TelemetryOutputPort;

    attribute inletMassFlowRate : MassFlowRate;
    attribute outletMassFlowRate : MassFlowRate;
    attribute inletSpecificEnthalpy : SpecificEnergy;
    attribute outletSpecificEnthalpy : SpecificEnergy;
    attribute inletEnthalpyFlowRate : Power;
    attribute outletEnthalpyFlowRate : Power;
    attribute shaftPowerRate : Power;
    attribute casingHeatLossRate : Power;
    attribute storedEnergyRate : Power;
    attribute isentropicEfficiency : Efficiency = 0.86;
    attribute inletPressure : Pressure;
    attribute exhaustPressure : Pressure;
    attribute rotorSpeed : AngularSpeed;
    attribute torque : Torque;

    constraint inletEnthalpyFlow {
      inletEnthalpyFlowRate == inletMassFlowRate * inletSpecificEnthalpy;
    }

    constraint outletEnthalpyFlow {
      outletEnthalpyFlowRate == outletMassFlowRate * outletSpecificEnthalpy;
    }

    constraint shaftPower : ShaftPowerDefinition {
      torque = torque;
      angularSpeed = rotorSpeed;
      shaftPower = shaftPowerRate;
    }

    constraint firstLaw : FirstLawControlVolumeBalance {
      storedEnergyRate = storedEnergyRate;
      heatTransferRateIn = 0.0 [SI::W];
      heatTransferRateOut = casingHeatLossRate;
      workRateOut = shaftPowerRate;
      workRateIn = 0.0 [SI::W];
      enthalpyFlowRateIn = inletEnthalpyFlowRate;
      enthalpyFlowRateOut = outletEnthalpyFlowRate;
    }
  }

  part def ElectricGenerator {
    port shaftIn : ShaftPowerInputPort;
    port electricOut : ElectricalPowerOutputPort;
    port telemetryOut : TelemetryOutputPort;

    attribute shaftPowerInputRate : Power;
    attribute electricPowerOutputRate : Power;
    attribute copperLossRate : Power;
    attribute ironLossRate : Power;
    attribute bearingLossRate : Power;
    attribute storedEnergyRate : Power;
    attribute generatorEfficiency : Efficiency = 0.96;
    attribute terminalVoltage : Voltage;
    attribute outputCurrent : Current;
    attribute gridFrequency : Frequency = 60.0 [SI::Hz];

    constraint generatorPower : GeneratorPowerDefinition {
      shaftPowerIn = shaftPowerInputRate;
      generatorEfficiency = generatorEfficiency;
      electricPowerOut = electricPowerOutputRate;
    }

    constraint firstLaw : FirstLawControlVolumeBalance {
      storedEnergyRate = storedEnergyRate;
      heatTransferRateIn = 0.0 [SI::W];
      heatTransferRateOut = copperLossRate + ironLossRate + bearingLossRate;
      workRateOut = electricPowerOutputRate;
      workRateIn = shaftPowerInputRate;
      enthalpyFlowRateIn = 0.0 [SI::W];
      enthalpyFlowRateOut = 0.0 [SI::W];
    }
  }

  part def CondenserHeatRejector {
    port vaporIn : FluidInletPort;
    port condensateOut : FluidOutletPort;
    port heatOut : HeatOutputPort;
    port telemetryOut : TelemetryOutputPort;

    attribute vaporMassFlowRate : MassFlowRate;
    attribute condensateMassFlowRate : MassFlowRate;
    attribute vaporSpecificEnthalpy : SpecificEnergy;
    attribute condensateSpecificEnthalpy : SpecificEnergy;
    attribute inletEnthalpyFlowRate : Power;
    attribute outletEnthalpyFlowRate : Power;
    attribute rejectedHeatRate : Power;
    attribute storedEnergyRate : Power;
    attribute condenserPressure : Pressure;
    attribute coolingBoundaryTemperature : Temperature;
    attribute condensateTemperature : Temperature;

    constraint inletEnthalpyFlow {
      inletEnthalpyFlowRate == vaporMassFlowRate * vaporSpecificEnthalpy;
    }

    constraint outletEnthalpyFlow {
      outletEnthalpyFlowRate == condensateMassFlowRate * condensateSpecificEnthalpy;
    }

    constraint firstLaw : FirstLawControlVolumeBalance {
      storedEnergyRate = storedEnergyRate;
      heatTransferRateIn = 0.0 [SI::W];
      heatTransferRateOut = rejectedHeatRate;
      workRateOut = 0.0 [SI::W];
      workRateIn = 0.0 [SI::W];
      enthalpyFlowRateIn = inletEnthalpyFlowRate;
      enthalpyFlowRateOut = outletEnthalpyFlowRate;
    }
  }

  part def FeedwaterPump {
    port liquidIn : FluidInletPort;
    port liquidOut : FluidOutletPort;
    port shaftIn : ShaftPowerInputPort;
    port telemetryOut : TelemetryOutputPort;

    attribute inletMassFlowRate : MassFlowRate;
    attribute outletMassFlowRate : MassFlowRate;
    attribute inletSpecificEnthalpy : SpecificEnergy;
    attribute outletSpecificEnthalpy : SpecificEnergy;
    attribute inletEnthalpyFlowRate : Power;
    attribute outletEnthalpyFlowRate : Power;
    attribute shaftPowerInputRate : Power;
    attribute heatLossRate : Power;
    attribute storedEnergyRate : Power;
    attribute pumpEfficiency : Efficiency = 0.78;
    attribute inletPressure : Pressure;
    attribute outletPressure : Pressure;

    constraint inletEnthalpyFlow {
      inletEnthalpyFlowRate == inletMassFlowRate * inletSpecificEnthalpy;
    }

    constraint outletEnthalpyFlow {
      outletEnthalpyFlowRate == outletMassFlowRate * outletSpecificEnthalpy;
    }

    constraint firstLaw : FirstLawControlVolumeBalance {
      storedEnergyRate = storedEnergyRate;
      heatTransferRateIn = 0.0 [SI::W];
      heatTransferRateOut = heatLossRate;
      workRateOut = 0.0 [SI::W];
      workRateIn = shaftPowerInputRate;
      enthalpyFlowRateIn = inletEnthalpyFlowRate;
      enthalpyFlowRateOut = outletEnthalpyFlowRate;
    }
  }

  part def EnergyBalanceController {
    port commandIn : CommandInputPort;
    port telemetryOut : TelemetryOutputPort;

    attribute commandedNetPower : Power;
    attribute measuredNetPower : Power;
    attribute commandedMode : PlantMode;
    attribute measuredMode : PlantMode;
    attribute heatInputSetpoint : Power;
    attribute feedwaterFlowSetpoint : MassFlowRate;
    attribute turbineValvePosition : Fraction;
    attribute pumpSpeedSetpoint : AngularSpeed;
    attribute firstLawResidualLimit : Power = 500.0 [SI::W];

    constraint commandTracking {
      heatInputSetpoint >= measuredNetPower;
    }
  }

  action def ProduceElectricPowerHighLevel {
    in commandedThermalPower : Power;
    in requestedNetElectricPower : Power;
    out deliveredElectricPower : Power;
    out rejectedThermalPower : Power;

    action establishClosedWorkingFluidFlow;
    action addHeatToWorkingFluid;
    action expandHighPressureVapor;
    action generateElectricalPower;
    action rejectUnusedHeatToSink;
    action verifyFirstLawBalance;

    first establishClosedWorkingFluidFlow then addHeatToWorkingFluid;
    first addHeatToWorkingFluid then expandHighPressureVapor;
    first expandHighPressureVapor then generateElectricalPower;
    first generateElectricalPower then rejectUnusedHeatToSink;
    first rejectUnusedHeatToSink then verifyFirstLawBalance;
  }

  action def StartPlant {
    out mode : PlantMode;

    action energizeController;
    action startFeedwaterPump;
    action purgeCombustionChamber;
    action igniteHeatSource;
    action warmBoilerMetal;
    action admitSteamToTurbine;

    first energizeController then startFeedwaterPump;
    first startFeedwaterPump then purgeCombustionChamber;
    first purgeCombustionChamber then igniteHeatSource;
    first igniteHeatSource then warmBoilerMetal;
    first warmBoilerMetal then admitSteamToTurbine;
  }

  action def RegulateFirstLawEnergyBalance {
    in measuredResidual : Power;
    in residualLimit : Power;
    out adjustedHeatInput : Power;
    out adjustedFeedwaterFlow : MassFlowRate;

    action compareResidualToLimit;
    action adjustFuelValve;
    action adjustPumpSpeed;
    action trimTurbineAdmissionValve;

    first compareResidualToLimit then adjustFuelValve;
    first adjustFuelValve then adjustPumpSpeed;
    first adjustPumpSpeed then trimTurbineAdmissionValve;
  }

  state def PlantLifecycle {
    entry action initializeTelemetry;
    exit action recordFinalEnergyInventory;

    state off;
    state starting;
    state preheating;
    state synchronizing;
    state generating;
    state standby;
    state shuttingDown;
    state faulted;

    transition initial then off;

    transition offToStarting
      first off
      accept ControlCommand
      then starting;

    transition startingToPreheating
      first starting
      then preheating;

    transition preheatingToSynchronizing
      first preheating
      then synchronizing;

    transition synchronizingToGenerating
      first synchronizing
      then generating;

    transition generatingToStandby
      first generating
      accept ControlCommand
      then standby;

    transition standbyToGenerating
      first standby
      accept ControlCommand
      then generating;

    transition generatingToShutdown
      first generating
      accept ControlCommand
      then shuttingDown;

    transition standbyToShutdown
      first standby
      accept ControlCommand
      then shuttingDown;

    transition shutdownToOff
      first shuttingDown
      then off;

    transition anyToFault
      first off
      then faulted;

    transition faultToOff
      first faulted
      accept ControlCommand
      then off;
  }

  part def FirstLawThermodynamicPowerPlant {
    port fuelIn : FuelInletPort;
    port commandIn : CommandInputPort;
    port electricOut : ElectricalPowerOutputPort;
    port heatRejectOut : HeatOutputPort;
    port telemetryOut : TelemetryOutputPort;

    part heatSource : CombustionHeatSource;
    part boiler : BoilerHeatExchanger;
    part turbine : SteamTurbineExpander;
    part generator : ElectricGenerator;
    part condenser : CondenserHeatRejector;
    part pump : FeedwaterPump;
    part controller : EnergyBalanceController;

    attribute primaryFunction : String = "Convert supplied thermal energy into useful electrical power while satisfying the First Law of Thermodynamics for the overall control volume.";
    attribute mode : PlantMode;
    attribute netElectricPower : Power;
    attribute grossElectricPower : Power;
    attribute auxiliaryPumpPower : Power;
    attribute fuelChemicalPower : Power;
    attribute boilerHeatInputRate : Power;
    attribute rejectedHeatRate : Power;
    attribute totalStoredEnergyRate : Power;
    attribute overallThermalEfficiency : Efficiency;
    attribute plantFirstLawResidual : Power;
    attribute maximumAllowableResidual : Power = 1000.0 [SI::W];
    attribute ratedNetElectricPower : Power = 100000.0 [SI::W];
    attribute minimumThermalEfficiency : Efficiency = 0.25;

    connect fuelIn to heatSource.fuelIn;
    connect commandIn to controller.commandIn;
    connect commandIn to heatSource.commandIn;
    connect heatSource.heatOut to boiler.heatIn;
    connect pump.liquidOut to boiler.feedwaterIn;
    connect boiler.steamOut to turbine.steamIn;
    connect turbine.exhaustOut to condenser.vaporIn;
    connect condenser.condensateOut to pump.liquidIn;
    connect turbine.shaftOut to generator.shaftIn;
    connect condenser.heatOut to heatRejectOut;
    connect generator.electricOut to electricOut;
    connect controller.telemetryOut to telemetryOut;

    perform action highLevelProduction : ProduceElectricPowerHighLevel;
    perform action startup : StartPlant;
    perform action energyRegulation : RegulateFirstLawEnergyBalance;

    exhibit state lifecycle : PlantLifecycle;

    constraint netPowerDefinition {
      netElectricPower == grossElectricPower - auxiliaryPumpPower;
    }

    constraint usefulEfficiency : ThermalEfficiencyDefinition {
      usefulElectricPower = netElectricPower;
      heatInputRate = boilerHeatInputRate;
      efficiency = overallThermalEfficiency;
    }

    constraint overallFirstLaw : FirstLawControlVolumeBalance {
      storedEnergyRate = totalStoredEnergyRate;
      heatTransferRateIn = boilerHeatInputRate;
      heatTransferRateOut = rejectedHeatRate;
      workRateOut = netElectricPower;
      workRateIn = 0.0 [SI::W];
      enthalpyFlowRateIn = 0.0 [SI::W];
      enthalpyFlowRateOut = 0.0 [SI::W];
    }

    constraint residualDefinition : FirstLawResidualDefinition {
      storedEnergyRate = totalStoredEnergyRate;
      heatTransferRateIn = boilerHeatInputRate;
      heatTransferRateOut = rejectedHeatRate;
      workRateOut = netElectricPower;
      workRateIn = 0.0 [SI::W];
      enthalpyFlowRateIn = 0.0 [SI::W];
      enthalpyFlowRateOut = 0.0 [SI::W];
      residual = plantFirstLawResidual;
    }

    constraint residualLimit {
      plantFirstLawResidual <= maximumAllowableResidual;
      plantFirstLawResidual >= -maximumAllowableResidual;
    }
  }

  requirement def PrimaryFunctionRequirement {
    subject plant : FirstLawThermodynamicPowerPlant;

    doc /* The system shall perform the high-level function of converting supplied thermal energy into useful electrical power for an external load. */

    require constraint {
      plant.netElectricPower >= plant.ratedNetElectricPower;
    }
  }

  requirement def FirstLawOverallConservationRequirement {
    subject plant : FirstLawThermodynamicPowerPlant;

    doc /* For the plant-level control volume, the rate of change of stored internal energy shall equal heat input minus rejected heat minus useful net work output. */

    require constraint {
      plant.totalStoredEnergyRate == plant.boilerHeatInputRate - plant.rejectedHeatRate - plant.netElectricPower;
    }
  }

  requirement def FirstLawComponentBalanceRequirement {
    subject plant : FirstLawThermodynamicPowerPlant;

    doc /* Each major component shall expose heat, work, stored-energy, and enthalpy-flow terms so that its energy balance is traceable to the First Law of Thermodynamics. */

    require constraint {
      plant.boiler.storedEnergyRate == plant.boiler.heatInputRate - plant.boiler.heatLossRate + plant.boiler.enthalpyFlowRateIn - plant.boiler.enthalpyFlowRateOut;
      plant.turbine.storedEnergyRate == -plant.turbine.casingHeatLossRate - plant.turbine.shaftPowerRate + plant.turbine.inletEnthalpyFlowRate - plant.turbine.outletEnthalpyFlowRate;
      plant.condenser.storedEnergyRate == -plant.condenser.rejectedHeatRate + plant.condenser.inletEnthalpyFlowRate - plant.condenser.outletEnthalpyFlowRate;
      plant.pump.storedEnergyRate == -plant.pump.heatLossRate + plant.pump.shaftPowerInputRate + plant.pump.inletEnthalpyFlowRate - plant.pump.outletEnthalpyFlowRate;
      plant.generator.storedEnergyRate == -plant.generator.copperLossRate - plant.generator.ironLossRate - plant.generator.bearingLossRate - plant.generator.electricPowerOutputRate + plant.generator.shaftPowerInputRate;
    }
  }

  requirement def MinimumThermalEfficiencyRequirement {
    subject plant : FirstLawThermodynamicPowerPlant;

    doc /* The plant shall deliver a minimum useful thermal efficiency during steady generating operation. */

    require constraint {
      plant.overallThermalEfficiency >= plant.minimumThermalEfficiency;
    }
  }

  requirement def ResidualMonitoringRequirement {
    subject plant : FirstLawThermodynamicPowerPlant;

    doc /* The controller shall monitor the difference between measured energy accumulation and the First Law prediction and maintain the residual within an allowable bound. */

    require constraint {
      plant.plantFirstLawResidual <= plant.maximumAllowableResidual;
      plant.plantFirstLawResidual >= -plant.maximumAllowableResidual;
    }
  }

  part thermodynamicPowerPlant : FirstLawThermodynamicPowerPlant {
    attribute mode = PlantMode::off;
    attribute ratedNetElectricPower = 100000.0 [SI::W];
    attribute minimumThermalEfficiency = 0.25;
    attribute maximumAllowableResidual = 1000.0 [SI::W];
  }

  requirement primaryFunctionReq : PrimaryFunctionRequirement {
    subject plant = thermodynamicPowerPlant;
  }

  requirement firstLawOverallReq : FirstLawOverallConservationRequirement {
    subject plant = thermodynamicPowerPlant;
  }

  requirement firstLawComponentReq : FirstLawComponentBalanceRequirement {
    subject plant = thermodynamicPowerPlant;
  }

  requirement minimumEfficiencyReq : MinimumThermalEfficiencyRequirement {
    subject plant = thermodynamicPowerPlant;
  }

  requirement residualMonitoringReq : ResidualMonitoringRequirement {
    subject plant = thermodynamicPowerPlant;
  }

  satisfy primaryFunctionReq by thermodynamicPowerPlant;
  satisfy firstLawOverallReq by thermodynamicPowerPlant;
  satisfy firstLawComponentReq by thermodynamicPowerPlant;
  satisfy minimumEfficiencyReq by thermodynamicPowerPlant;
  satisfy residualMonitoringReq by thermodynamicPowerPlant;
}
