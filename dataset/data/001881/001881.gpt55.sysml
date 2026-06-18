package TurbinePowerSystemModel {

  import ScalarValues::*;
  import ISQ::*;

  attribute def Pressure :> ScalarValues::Real {
    doc /* Fluid static pressure, expressed in pascal. */
  }

  attribute def Temperature :> ScalarValues::Real {
    doc /* Thermodynamic temperature, expressed in kelvin. */
  }

  attribute def MassFlowRate :> ScalarValues::Real {
    doc /* Fluid mass flow rate, expressed in kilogram per second. */
  }

  attribute def RotationalSpeed :> ScalarValues::Real {
    doc /* Shaft rotational speed, expressed in revolutions per minute. */
  }

  attribute def Torque :> ScalarValues::Real {
    doc /* Shaft torque, expressed in newton meter. */
  }

  attribute def Power :> ScalarValues::Real {
    doc /* Power, expressed in watt. */
  }

  attribute def Efficiency :> ScalarValues::Real {
    doc /* Dimensionless conversion efficiency from 0.0 to 1.0. */
  }

  attribute def VibrationLevel :> ScalarValues::Real {
    doc /* Overall vibration velocity, expressed in millimeter per second. */
  }

  attribute def TimeDuration :> ScalarValues::Real {
    doc /* Time duration, expressed in second. */
  }

  attribute def OpeningFraction :> ScalarValues::Real {
    doc /* Valve or vane opening fraction from 0.0 closed to 1.0 fully open. */
  }

  attribute def ControlSignal :> ScalarValues::Real {
    doc /* Normalized control command from 0.0 to 1.0. */
  }

  item def WorkingFluid {
    attribute pressure : Pressure;
    attribute temperature : Temperature;
    attribute massFlowRate : MassFlowRate;
    attribute specificEnthalpy : ScalarValues::Real;
  }

  item def HighEnergySteam :> WorkingFluid {
    attribute pressure = 12000000.0;
    attribute temperature = 813.15;
    attribute massFlowRate = 85.0;
    attribute specificEnthalpy = 3450000.0;
  }

  item def ExhaustSteam :> WorkingFluid {
    attribute pressure = 18000.0;
    attribute temperature = 330.0;
    attribute massFlowRate = 85.0;
    attribute specificEnthalpy = 2350000.0;
  }

  item def LubricatingOil {
    attribute pressure : Pressure;
    attribute temperature : Temperature;
    attribute massFlowRate : MassFlowRate;
  }

  item def MechanicalRotation {
    attribute speed : RotationalSpeed;
    attribute torque : Torque;
    attribute power : Power;
  }

  item def ElectricalPower {
    attribute realPower : Power;
    attribute voltage : ScalarValues::Real;
    attribute frequency : ScalarValues::Real;
  }

  item def Heat {
    attribute thermalPower : Power;
  }

  item def SensorData {
    attribute measuredSpeed : RotationalSpeed;
    attribute measuredPower : Power;
    attribute measuredVibration : VibrationLevel;
    attribute measuredInletPressure : Pressure;
    attribute measuredExhaustPressure : Pressure;
  }

  item def ActuatorCommand {
    attribute governorValveCommand : ControlSignal;
    attribute tripCommand : ScalarValues::Boolean;
  }

  port def FluidInletPort {
    in fluid : WorkingFluid;
  }

  port def FluidOutletPort {
    out fluid : WorkingFluid;
  }

  port def RotationOutPort {
    out rotation : MechanicalRotation;
  }

  port def RotationInPort {
    in rotation : MechanicalRotation;
  }

  port def OilSupplyPort {
    in oil : LubricatingOil;
  }

  port def OilReturnPort {
    out oil : LubricatingOil;
  }

  port def HeatRejectionPort {
    out rejectedHeat : Heat;
  }

  port def ElectricalOutPort {
    out electricity : ElectricalPower;
  }

  port def SensorOutPort {
    out data : SensorData;
  }

  port def CommandInPort {
    in command : ActuatorCommand;
  }

  interface def WorkingFluidTransfer {
    end source : FluidOutletPort;
    end sink : FluidInletPort;
    flow fluid from source to sink;
  }

  interface def ShaftPowerTransfer {
    end driver : RotationOutPort;
    end driven : RotationInPort;
    flow rotation from driver to driven;
  }

  interface def OilSupplyTransfer {
    end source : OilSupplyPort;
    end sink : OilSupplyPort;
    flow oil from source to sink;
  }

  interface def HeatTransfer {
    end source : HeatRejectionPort;
    end sink : HeatRejectionPort;
    flow rejectedHeat from source to sink;
  }

  interface def MeasurementTransfer {
    end source : SensorOutPort;
    end sink : SensorOutPort;
    flow data from source to sink;
  }

  part def TurbineCasing {
    port steamIn : FluidInletPort;
    port steamOut : FluidOutletPort;
    port heatLoss : HeatRejectionPort;

    attribute designPressure : Pressure = 14000000.0;
    attribute designTemperature : Temperature = 850.0;
    attribute allowableLeakageMassFlow : MassFlowRate = 0.02;

    item containedSteam : WorkingFluid;
    item casingHeatLoss : Heat;

    perform action confineWorkingFluid : ConfineWorkingFluid;
  }

  part def GovernorValve {
    port steamIn : FluidInletPort;
    port steamOut : FluidOutletPort;
    port commandIn : CommandInPort;

    attribute opening : OpeningFraction = 0.0;
    attribute failSafeOpening : OpeningFraction = 0.0;
    attribute maximumMassFlow : MassFlowRate = 100.0;

    perform action modulateFlow : ModulateSteamFlow;
  }

  part def InletGuideVanes {
    port steamIn : FluidInletPort;
    port steamOut : FluidOutletPort;
    port commandIn : CommandInPort;

    attribute vaneAngle : ScalarValues::Real = 0.0;
    attribute opening : OpeningFraction = 0.0;

    perform action directFlow : DirectSteamOntoRotor;
  }

  part def RotorAssembly {
    port steamIn : FluidInletPort;
    port steamOut : FluidOutletPort;
    port shaftOut : RotationOutPort;
    port oilIn : OilSupplyPort;
    port oilOut : OilReturnPort;

    attribute rotorSpeed : RotationalSpeed = 0.0;
    attribute ratedSpeed : RotationalSpeed = 3600.0;
    attribute rotorTorque : Torque = 0.0;
    attribute inertia : ScalarValues::Real = 4200.0;
    attribute tipClearance : ScalarValues::Real = 0.0015;

    item inletSteam : WorkingFluid;
    item exhaustSteam : WorkingFluid;
    item shaftRotation : MechanicalRotation;

    part highPressureBlades : BladeRow[8];
    part lowPressureBlades : BladeRow[6];
    part shaft : TurbineShaft;

    perform action extractEnergy : ExtractFluidEnergy;
  }

  part def BladeRow {
    port steamIn : FluidInletPort;
    port steamOut : FluidOutletPort;

    attribute rowNumber : ScalarValues::Integer;
    attribute stageEfficiency : Efficiency = 0.88;
    attribute pressureRatio : ScalarValues::Real = 0.85;
    attribute bladeMetalTemperature : Temperature = 700.0;

    perform action expandSteamAcrossBlades : ExpandWorkingFluid;
  }

  part def TurbineShaft {
    port rotationOut : RotationOutPort;

    attribute speed : RotationalSpeed = 0.0;
    attribute torque : Torque = 0.0;
    attribute deliveredPower : Power = 0.0;
    attribute torsionalVibration : VibrationLevel = 0.0;

    item rotation : MechanicalRotation;
  }

  part def BearingSet {
    port rotationIn : RotationInPort;
    port oilIn : OilSupplyPort;
    port oilOut : OilReturnPort;
    port heatLoss : HeatRejectionPort;

    attribute radialLoad : ScalarValues::Real = 250000.0;
    attribute axialLoad : ScalarValues::Real = 90000.0;
    attribute bearingTemperature : Temperature = 340.0;
    attribute vibrationLevel : VibrationLevel = 1.5;

    perform action supportRotor : SupportRotor;
  }

  part def LubricationSystem {
    port oilSupply : OilSupplyPort;
    port oilReturn : OilReturnPort;
    port heatLoss : HeatRejectionPort;

    attribute oilSupplyPressure : Pressure = 450000.0;
    attribute oilSupplyTemperature : Temperature = 318.0;
    attribute oilFlowRate : MassFlowRate = 2.4;

    item conditionedOil : LubricatingOil;

    perform action conditionOil : ConditionLubricatingOil;
  }

  part def SealSystem {
    port steamIn : FluidInletPort;
    port steamOut : FluidOutletPort;

    attribute sealLeakageRate : MassFlowRate = 0.01;
    attribute sealPressure : Pressure = 250000.0;

    perform action limitLeakage : LimitSteamLeakage;
  }

  part def Generator {
    port shaftIn : RotationInPort;
    port electricalOut : ElectricalOutPort;
    port heatLoss : HeatRejectionPort;

    attribute ratedElectricalPower : Power = 95000000.0;
    attribute generatorEfficiency : Efficiency = 0.985;
    attribute terminalVoltage : ScalarValues::Real = 13800.0;
    attribute gridFrequency : ScalarValues::Real = 60.0;

    item generatedElectricity : ElectricalPower;

    perform action convertMechanicalToElectrical : ConvertShaftPowerToElectricity;
  }

  part def Condenser {
    port steamIn : FluidInletPort;
    port condensateOut : FluidOutletPort;
    port heatLoss : HeatRejectionPort;

    attribute condenserPressure : Pressure = 18000.0;
    attribute heatRejected : Power = 120000000.0;

    perform action condenseExhaustSteam : CondenseSteam;
  }

  part def InstrumentationSystem {
    port sensorOut : SensorOutPort;

    attribute speedMeasurement : RotationalSpeed = 0.0;
    attribute powerMeasurement : Power = 0.0;
    attribute vibrationMeasurement : VibrationLevel = 0.0;
    attribute inletPressureMeasurement : Pressure = 0.0;
    attribute exhaustPressureMeasurement : Pressure = 0.0;

    item currentMeasurements : SensorData;

    perform action acquireMeasurements : AcquireTurbineMeasurements;
  }

  part def TurbineController {
    port sensorIn : SensorOutPort;
    port commandOut : CommandInPort;

    attribute targetSpeed : RotationalSpeed = 3600.0;
    attribute targetPower : Power = 90000000.0;
    attribute overspeedTripSetpoint : RotationalSpeed = 3960.0;
    attribute highVibrationTripSetpoint : VibrationLevel = 7.1;

    item actuatorCommand : ActuatorCommand;

    perform action regulateTurbine : RegulateTurbineOperation;
  }

  action def ConfineWorkingFluid {
    in inletFluid : WorkingFluid;
    out outletFluid : WorkingFluid;
    out casingHeatLoss : Heat;

    attribute leakage : MassFlowRate = 0.0;

    constraint leakageLimit {
      leakage <= 0.02
    }
  }

  action def ModulateSteamFlow {
    in inletFluid : WorkingFluid;
    in command : ActuatorCommand;
    out outletFluid : WorkingFluid;

    attribute commandedOpening : OpeningFraction;

    constraint validOpening {
      commandedOpening >= 0.0 and commandedOpening <= 1.0
    }
  }

  action def DirectSteamOntoRotor {
    in inletFluid : WorkingFluid;
    in command : ActuatorCommand;
    out outletFluid : WorkingFluid;

    attribute vaneOpening : OpeningFraction;

    constraint validVaneOpening {
      vaneOpening >= 0.0 and vaneOpening <= 1.0
    }
  }

  action def ExpandWorkingFluid {
    in inletFluid : WorkingFluid;
    out outletFluid : WorkingFluid;

    attribute stagePressureDrop : Pressure;
    attribute stageEfficiency : Efficiency;

    constraint positiveExpansion {
      outletFluid.pressure < inletFluid.pressure
    }
  }

  action def ExtractFluidEnergy {
    in highEnergyFluid : WorkingFluid;
    out lowEnergyFluid : WorkingFluid;
    out mechanicalRotation : MechanicalRotation;

    attribute conversionEfficiency : Efficiency = 0.90;
    attribute extractedThermalPower : Power;
    attribute producedShaftPower : Power;

    first expand;
    then turnRotor;
    then deliverRotation;

    action expand : ExpandWorkingFluid {
      in inletFluid = highEnergyFluid;
      out outletFluid = lowEnergyFluid;
    }

    action turnRotor;
    action deliverRotation;

    constraint energyConversion {
      producedShaftPower == extractedThermalPower * conversionEfficiency
    }
  }

  action def SupportRotor {
    in rotation : MechanicalRotation;
    in oil : LubricatingOil;
    out returnedOil : LubricatingOil;
    out heat : Heat;

    attribute bearingVibration : VibrationLevel;

    constraint acceptableBearingVibration {
      bearingVibration <= 4.5
    }
  }

  action def ConditionLubricatingOil {
    in returnedOil : LubricatingOil;
    out suppliedOil : LubricatingOil;
    out rejectedHeat : Heat;

    attribute supplyPressure : Pressure = 450000.0;
    attribute supplyTemperature : Temperature = 318.0;
  }

  action def LimitSteamLeakage {
    in sealSteam : WorkingFluid;
    out recoveredSteam : WorkingFluid;

    attribute leakageRate : MassFlowRate;

    constraint leakageAcceptable {
      leakageRate <= 0.01
    }
  }

  action def ConvertShaftPowerToElectricity {
    in rotation : MechanicalRotation;
    out electricity : ElectricalPower;
    out wasteHeat : Heat;

    attribute generatorEfficiency : Efficiency = 0.985;

    constraint generatedPowerRelation {
      electricity.realPower == rotation.power * generatorEfficiency
    }
  }

  action def CondenseSteam {
    in exhaustSteam : WorkingFluid;
    out condensate : WorkingFluid;
    out rejectedHeat : Heat;

    constraint condenserPressureLimit {
      condensate.pressure <= 50000.0
    }
  }

  action def AcquireTurbineMeasurements {
    out measurements : SensorData;

    attribute samplePeriod : TimeDuration = 0.1;
  }

  action def RegulateTurbineOperation {
    in measurements : SensorData;
    out command : ActuatorCommand;

    attribute speedError : RotationalSpeed;
    attribute powerError : Power;

    first compareTargets;
    then computeValveCommand;
    then issueCommand;

    action compareTargets;
    action computeValveCommand;
    action issueCommand;

    constraint overspeedProtection {
      if measurements.measuredSpeed >= 3960.0 then command.tripCommand == true else command.tripCommand == false
    }
  }

  action def GenerateUsefulShaftPower {
    in steamSupply : WorkingFluid;
    out steamExhaust : WorkingFluid;
    out shaftPower : MechanicalRotation;

    attribute overallEfficiency : Efficiency = 0.90;
    attribute nominalMechanicalPower : Power = 92000000.0;

    first admitWorkingFluid;
    then expandAndAccelerateRotor;
    then exportShaftPower;

    action admitWorkingFluid : ModulateSteamFlow;
    action expandAndAccelerateRotor : ExtractFluidEnergy;
    action exportShaftPower;

    constraint primaryFunctionPower {
      shaftPower.power >= 90000000.0
    }
  }

  state def TurbineLifecycle {
    entry; then shutdown;

    state shutdown;
    state standby;
    state preLube;
    state rolling;
    state synchronizing;
    state loaded;
    state controlledShutdown;
    state trip;

    transition initialize
      first shutdown
      accept startRequested
      then standby;

    transition startLubrication
      first standby
      accept lubeOilPressureAvailable
      then preLube;

    transition openAdmission
      first preLube
      accept permissivesSatisfied
      then rolling;

    transition reachRatedSpeed
      first rolling
      accept ratedSpeedReached
      then synchronizing;

    transition connectLoad
      first synchronizing
      accept generatorSynchronized
      then loaded;

    transition normalStop
      first loaded
      accept stopRequested
      then controlledShutdown;

    transition shutdownComplete
      first controlledShutdown
      accept rotorStopped
      then shutdown;

    transition protectiveTripFromRolling
      first rolling
      accept tripConditionDetected
      then trip;

    transition protectiveTripFromLoaded
      first loaded
      accept tripConditionDetected
      then trip;

    transition resetTrip
      first trip
      accept tripReset
      then shutdown;
  }

  part def TurbineSystem {
    port steamSupply : FluidInletPort;
    port exhaust : FluidOutletPort;
    port electricalOutput : ElectricalOutPort;
    port wasteHeat : HeatRejectionPort;
    port supervisoryCommand : CommandInPort;
    port supervisoryMeasurements : SensorOutPort;

    attribute ratedShaftPower : Power = 92000000.0;
    attribute ratedElectricalPower : Power = 90000000.0;
    attribute ratedSpeed : RotationalSpeed = 3600.0;
    attribute minimumContinuousPower : Power = 25000000.0;
    attribute maximumContinuousPower : Power = 95000000.0;
    attribute overallThermalToShaftEfficiency : Efficiency = 0.90;
    attribute normalInletPressure : Pressure = 12000000.0;
    attribute normalInletTemperature : Temperature = 813.15;
    attribute normalExhaustPressure : Pressure = 18000.0;

    item inletSteam : HighEnergySteam;
    item dischargeSteam : ExhaustSteam;
    item shaftPower : MechanicalRotation {
      attribute speed = 3600.0;
      attribute torque = 244034.0;
      attribute power = 92000000.0;
    }

    part casing : TurbineCasing;
    part governorValve : GovernorValve;
    part inletGuideVanes : InletGuideVanes;
    part rotorAssembly : RotorAssembly;
    part bearings : BearingSet[2];
    part lubricationSystem : LubricationSystem;
    part seals : SealSystem;
    part generator : Generator;
    part condenser : Condenser;
    part instrumentation : InstrumentationSystem;
    part controller : TurbineController;

    connect steamSupply to governorValve.steamIn;
    connect governorValve.steamOut to inletGuideVanes.steamIn;
    connect inletGuideVanes.steamOut to casing.steamIn;
    connect casing.steamOut to rotorAssembly.steamIn;
    connect rotorAssembly.steamOut to seals.steamIn;
    connect seals.steamOut to condenser.steamIn;
    connect condenser.condensateOut to exhaust;

    connect rotorAssembly.shaftOut to bearings.rotationIn;
    connect rotorAssembly.shaft.srotationOut to generator.shaftIn;
    connect generator.electricalOut to electricalOutput;

    connect lubricationSystem.oilSupply to rotorAssembly.oilIn;
    connect rotorAssembly.oilOut to lubricationSystem.oilReturn;
    connect lubricationSystem.oilSupply to bearings.oilIn;
    connect bearings.oilOut to lubricationSystem.oilReturn;

    connect casing.heatLoss to wasteHeat;
    connect bearings.heatLoss to wasteHeat;
    connect lubricationSystem.heatLoss to wasteHeat;
    connect generator.heatLoss to wasteHeat;
    connect condenser.heatLoss to wasteHeat;

    connect instrumentation.sensorOut to controller.sensorIn;
    connect instrumentation.sensorOut to supervisoryMeasurements;
    connect supervisoryCommand to controller.commandOut;
    connect controller.commandOut to governorValve.commandIn;
    connect controller.commandOut to inletGuideVanes.commandIn;

    perform action primaryFunction : GenerateUsefulShaftPower {
      in steamSupply = inletSteam;
      out steamExhaust = dischargeSteam;
      out shaftPower = shaftPower;
    }

    exhibit state operatingLife : TurbineLifecycle;
  }

  requirement def PrimaryFunctionRequirement {
    doc /* The TurbineSystem shall convert thermal and pressure energy in a high-energy working fluid into useful rotating shaft power at a controlled speed. */

    subject turbine : TurbineSystem;

    require constraint {
      turbine.ratedShaftPower >= 90000000.0 and
      turbine.ratedSpeed == 3600.0 and
      turbine.overallThermalToShaftEfficiency >= 0.88
    }
  }

  requirement def ControlledAdmissionRequirement {
    doc /* The turbine shall regulate admitted steam flow to control rotor speed and delivered power during startup, synchronization, loading, and shutdown. */

    subject turbine : TurbineSystem;

    require constraint {
      turbine.governorValve.opening >= 0.0 and
      turbine.governorValve.opening <= 1.0 and
      turbine.inletGuideVanes.opening >= 0.0 and
      turbine.inletGuideVanes.opening <= 1.0
    }
  }

  requirement def EnergyExtractionRequirement {
    doc /* The rotor and blade rows shall reduce working-fluid pressure and enthalpy while producing mechanical shaft rotation. */

    subject turbine : TurbineSystem;

    require constraint {
      turbine.normalExhaustPressure < turbine.normalInletPressure and
      turbine.rotorAssembly.rotorSpeed <= turbine.controller.overspeedTripSetpoint
    }
  }

  requirement def LubricationRequirement {
    doc /* The lubrication system shall provide conditioned oil to bearings and rotor interfaces whenever the turbine is rolling or loaded. */

    subject turbine : TurbineSystem;

    require constraint {
      turbine.lubricationSystem.oilSupplyPressure >= 350000.0 and
      turbine.lubricationSystem.oilSupplyTemperature <= 333.0
    }
  }

  requirement def ProtectionRequirement {
    doc /* The turbine controller shall issue a trip command when overspeed or excessive vibration is detected. */

    subject turbine : TurbineSystem;

    require constraint {
      turbine.controller.overspeedTripSetpoint <= 3960.0 and
      turbine.controller.highVibrationTripSetpoint <= 7.1
    }
  }

  requirement def ElectricalGenerationRequirement {
    doc /* When coupled to the generator, the turbine shall provide sufficient shaft power to support nominal electrical output. */

    subject turbine : TurbineSystem;

    require constraint {
      turbine.generator.ratedElectricalPower >= turbine.ratedElectricalPower and
      turbine.generator.generatorEfficiency >= 0.98
    }
  }

  part turbinePowerPlant : TurbineSystem {
    attribute ratedShaftPower = 92000000.0;
    attribute ratedElectricalPower = 90000000.0;
    attribute ratedSpeed = 3600.0;
    attribute normalInletPressure = 12000000.0;
    attribute normalInletTemperature = 813.15;
    attribute normalExhaustPressure = 18000.0;
  }

}
