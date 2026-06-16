package VaporLockSystemModel {

  private import ScalarValues::*;

  attribute def Temperature_c :> Real;
  attribute def Pressure_kPa :> Real;
  attribute def FlowRate_L_per_min :> Real;
  attribute def Volume_L :> Real;
  attribute def Time_s :> Real;
  attribute def Ratio :> Real;
  attribute def Voltage_V :> Real;
  attribute def Current_A :> Real;

  item def LiquidFuel {
    attribute temperature : Temperature_c;
    attribute pressure : Pressure_kPa;
    attribute flowRate : FlowRate_L_per_min;
    attribute vaporFraction : Ratio;
  }

  item def FuelVapor {
    attribute temperature : Temperature_c;
    attribute pressure : Pressure_kPa;
    attribute volume : Volume_L;
  }

  item def FuelDemand {
    attribute requestedFlow : FlowRate_L_per_min;
    attribute minimumPressure : Pressure_kPa;
  }

  item def ControlSignal {
    attribute commandVoltage : Voltage_V;
    attribute dutyCycle : Ratio;
  }

  item def SensorReading {
    attribute fuelTemperature : Temperature_c;
    attribute fuelPressure : Pressure_kPa;
    attribute measuredFlow : FlowRate_L_per_min;
    attribute vaporFractionEstimate : Ratio;
  }

  port def FuelInputPort {
    in item fuelIn : LiquidFuel;
  }

  port def FuelOutputPort {
    out item fuelOut : LiquidFuel;
  }

  port def VaporOutputPort {
    out item vaporOut : FuelVapor;
  }

  port def DemandInputPort {
    in item demand : FuelDemand;
  }

  port def SensorOutputPort {
    out item reading : SensorReading;
  }

  port def ControlInputPort {
    in item command : ControlSignal;
  }

  port def ControlOutputPort {
    out item command : ControlSignal;
  }

  part def FuelTank {
    attribute usableFuelVolume : Volume_L = 45.0;
    attribute ullagePressure : Pressure_kPa = 101.3;
    attribute fuelTemperature : Temperature_c;

    port outlet : FuelOutputPort;
    port vaporReturn : VaporOutputPort;
  }

  part def LiftPump {
    attribute nominalFlow : FlowRate_L_per_min = 3.5;
    attribute pressureRise : Pressure_kPa = 45.0;
    attribute supplyVoltage : Voltage_V = 12.0;
    attribute operatingCurrent : Current_A;

    port inlet : FuelInputPort;
    port outlet : FuelOutputPort;
    port control : ControlInputPort;
  }

  part def FuelLine {
    attribute internalVolume : Volume_L = 0.25;
    attribute heatSoakTemperature : Temperature_c;
    attribute pressureDrop : Pressure_kPa;

    port inlet : FuelInputPort;
    port outlet : FuelOutputPort;
  }

  part def VaporSeparator {
    attribute chamberVolume : Volume_L = 0.40;
    attribute separationEfficiency : Ratio = 0.95;
    attribute minimumLiquidLevel : Ratio = 0.25;
    attribute maximumLiquidLevel : Ratio = 0.85;

    port inlet : FuelInputPort;
    port liquidOutlet : FuelOutputPort;
    port vaporOutlet : VaporOutputPort;
  }

  part def PressureRegulator {
    attribute targetPressure : Pressure_kPa = 310.0;
    attribute reliefPressure : Pressure_kPa = 360.0;

    port inlet : FuelInputPort;
    port outlet : FuelOutputPort;
  }

  part def CarburetorOrInjectorRail {
    attribute requiredMinimumFlow : FlowRate_L_per_min = 1.2;
    attribute requiredMinimumPressure : Pressure_kPa = 250.0;

    port inlet : FuelInputPort;
    port engineDemand : DemandInputPort;
  }

  part def TemperatureSensor {
    attribute sensingRangeLow : Temperature_c = -40.0;
    attribute sensingRangeHigh : Temperature_c = 150.0;

    port sensedFuel : FuelInputPort;
    port readingOut : SensorOutputPort;
  }

  part def PressureSensor {
    attribute sensingRangeLow : Pressure_kPa = 0.0;
    attribute sensingRangeHigh : Pressure_kPa = 500.0;

    port sensedFuel : FuelInputPort;
    port readingOut : SensorOutputPort;
  }

  part def VaporFractionEstimator {
    attribute detectionThreshold : Ratio = 0.08;
    attribute confirmedLockThreshold : Ratio = 0.20;

    port pressureReading : SensorOutputPort;
    port temperatureReading : SensorOutputPort;
    port estimateOut : SensorOutputPort;
  }

  part def ElectronicController {
    attribute vaporRiskTemperature : Temperature_c = 60.0;
    attribute minimumSafePressure : Pressure_kPa = 250.0;
    attribute purgeDuration : Time_s = 8.0;

    port demandIn : DemandInputPort;
    port sensorIn : SensorOutputPort;
    port pumpCommand : ControlOutputPort;
    port purgeCommand : ControlOutputPort;
  }

  part def PurgeValve {
    attribute normallyClosed : Boolean = true;
    attribute openCommandVoltage : Voltage_V = 12.0;

    port command : ControlInputPort;
    port vaporIn : VaporOutputPort;
    port vaporOut : VaporOutputPort;
  }

  action def SenseFuelCondition {
    in item fuel : LiquidFuel;
    out item reading : SensorReading;

    action measureTemperature;
    action measurePressure;
    action estimateVaporFraction;
  }

  action def DetectVaporLock {
    in item reading : SensorReading;
    out attribute vaporLockDetected : Boolean;
    out attribute vaporRiskDetected : Boolean;

    constraint vaporRiskRule {
      vaporRiskDetected == reading.fuelTemperature >= 60.0 or reading.fuelPressure < 250.0;
    }

    constraint vaporLockRule {
      vaporLockDetected == reading.vaporFractionEstimate >= 0.20 and reading.measuredFlow < 1.2;
    }
  }

  action def MaintainLiquidFuelDelivery {
    in item demand : FuelDemand;
    in item inletFuel : LiquidFuel;
    out item deliveredFuel : LiquidFuel;

    action pressurizeFuel;
    action separateVapor;
    action regulatePressure;
    action deliverLiquidFuel;

    constraint primaryFunction {
      deliveredFuel.flowRate >= demand.requestedFlow and
      deliveredFuel.pressure >= demand.minimumPressure and
      deliveredFuel.vaporFraction <= 0.05;
    }
  }

  action def PurgeVaporPocket {
    in item trappedVapor : FuelVapor;
    out item returnedVapor : FuelVapor;

    action openPurgeValve;
    action routeVaporToTankUllage;
    action closePurgeValve;
  }

  state def VaporLockOperatingStateMachine {
    state Off;
    state Priming;
    state NormalDelivery;
    state VaporRisk;
    state VaporLockDetected;
    state Purging;
    state Recovery;
    state Fault;

    transition initial then Off;

    transition Off_to_Priming
      first Off
      then Priming
      accept ControlSignal
      if command.commandVoltage >= 10.0;

    transition Priming_to_NormalDelivery
      first Priming
      then NormalDelivery
      if fuelPressureEstablished;

    transition NormalDelivery_to_VaporRisk
      first NormalDelivery
      then VaporRisk
      if fuelTemperatureHigh or pressureMarginLow;

    transition VaporRisk_to_NormalDelivery
      first VaporRisk
      then NormalDelivery
      if pressureStable and vaporFractionLow;

    transition VaporRisk_to_VaporLockDetected
      first VaporRisk
      then VaporLockDetected
      if vaporFractionHigh and flowRestricted;

    transition VaporLockDetected_to_Purging
      first VaporLockDetected
      then Purging;

    transition Purging_to_Recovery
      first Purging
      then Recovery
      if purgeTimerExpired;

    transition Recovery_to_NormalDelivery
      first Recovery
      then NormalDelivery
      if flowRestored and pressureStable;

    transition Recovery_to_Fault
      first Recovery
      then Fault
      if purgeAttemptsExceeded;
  }

  part def VaporLockMitigationSystem {
    doc /* Primary function: maintain continuous liquid fuel delivery to the engine by preventing, detecting, separating, and purging vapor pockets that would otherwise interrupt fuel flow. */

    attribute minimumDeliveredPressure : Pressure_kPa = 250.0;
    attribute maximumAllowedVaporFraction : Ratio = 0.05;
    attribute nominalDeliveredFlow : FlowRate_L_per_min = 2.5;
    attribute maximumPurgeTime : Time_s = 10.0;

    port fuelDemand : DemandInputPort;
    port fuelToEngine : FuelOutputPort;

    part tank : FuelTank;
    part pump : LiftPump;
    part hotLine : FuelLine;
    part separator : VaporSeparator;
    part regulator : PressureRegulator;
    part engineFuelMetering : CarburetorOrInjectorRail;
    part temperatureSensor : TemperatureSensor;
    part pressureSensor : PressureSensor;
    part vaporEstimator : VaporFractionEstimator;
    part controller : ElectronicController;
    part purgeValve : PurgeValve;

    perform action deliveryFunction : MaintainLiquidFuelDelivery;
    exhibit state operatingStates : VaporLockOperatingStateMachine;

    connect tank.outlet to pump.inlet;
    connect pump.outlet to hotLine.inlet;
    connect hotLine.outlet to separator.inlet;
    connect separator.liquidOutlet to regulator.inlet;
    connect regulator.outlet to engineFuelMetering.inlet;
    connect engineFuelMetering.inlet to fuelToEngine;

    connect separator.vaporOutlet to purgeValve.vaporIn;
    connect purgeValve.vaporOut to tank.vaporReturn;

    connect fuelDemand to controller.demandIn;
    connect fuelDemand to engineFuelMetering.engineDemand;

    connect hotLine.outlet to temperatureSensor.sensedFuel;
    connect regulator.outlet to pressureSensor.sensedFuel;
    connect temperatureSensor.readingOut to vaporEstimator.temperatureReading;
    connect pressureSensor.readingOut to vaporEstimator.pressureReading;
    connect vaporEstimator.estimateOut to controller.sensorIn;

    connect controller.pumpCommand to pump.control;
    connect controller.purgeCommand to purgeValve.command;
  }

  requirement def PrimaryFunctionRequirement {
    subject system : VaporLockMitigationSystem;

    doc /* The system shall deliver liquid fuel to the engine under vapor-forming conditions by maintaining pressure, separating vapor from liquid fuel, and purging accumulated vapor to the tank. */

    require constraint {
      system.nominalDeliveredFlow >= 1.2 and
      system.minimumDeliveredPressure >= 250.0 and
      system.maximumAllowedVaporFraction <= 0.05;
    }
  }

  requirement def VaporDetectionRequirement {
    subject estimator : VaporFractionEstimator;

    doc /* The system shall identify a vapor lock condition when vapor fraction is high enough to restrict liquid fuel flow. */

    require constraint {
      estimator.confirmedLockThreshold <= 0.20 and
      estimator.detectionThreshold <= 0.08;
    }
  }

  requirement def PurgeRequirement {
    subject system : VaporLockMitigationSystem;

    doc /* The purge function shall clear separated vapor within the permitted recovery interval. */

    require constraint {
      system.maximumPurgeTime <= 10.0;
    }
  }

  requirement def PressureRegulationRequirement {
    subject regulator : PressureRegulator;

    doc /* The regulator shall maintain engine supply pressure above the minimum needed for stable fuel metering. */

    require constraint {
      regulator.targetPressure >= 310.0 and
      regulator.reliefPressure <= 360.0;
    }
  }

  requirement def SeparationRequirement {
    subject separator : VaporSeparator;

    doc /* The separator shall remove most vapor from the incoming fuel stream before fuel reaches the engine metering device. */

    require constraint {
      separator.separationEfficiency >= 0.95;
    }
  }

  requirement def FailOperationalRequirement {
    subject controller : ElectronicController;

    doc /* The controller shall command increased pump duty and vapor purge when vapor risk is detected before declaring a fault. */

    require constraint {
      controller.minimumSafePressure >= 250.0 and
      controller.purgeDuration <= 8.0;
    }
  }

  satisfy PrimaryFunctionRequirement by VaporLockMitigationSystem;
  satisfy VaporDetectionRequirement by VaporFractionEstimator;
  satisfy PurgeRequirement by VaporLockMitigationSystem;
  satisfy PressureRegulationRequirement by PressureRegulator;
  satisfy SeparationRequirement by VaporSeparator;
  satisfy FailOperationalRequirement by ElectronicController;
}