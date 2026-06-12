package DishwasherSystemModel {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  value type Celsius specializes Real;
  value type Liter specializes Real;
  value type Minute specializes Real;
  value type Percent specializes Real;
  value type Watt specializes Real;
  value type Kilogram specializes Real;
  value type RPM specializes Real;
  value type dBA specializes Real;
  value type Volt specializes Real;
  value type Ampere specializes Real;
  value type Gram specializes Real;

  enum def DoorPosition {
    enum open;
    enum closed;
    enum latched;
  }

  enum def CycleSelection {
    enum eco;
    enum normal;
    enum heavy;
    enum quick;
    enum rinseOnly;
    enum sanitize;
  }

  enum def SoilLevel {
    enum light;
    enum medium;
    enum heavy;
  }

  enum def WaterQuality {
    enum clean;
    enum soapy;
    enum dirty;
    enum rinseWater;
  }

  enum def FaultCode {
    enum noFault;
    enum doorOpen;
    enum waterFillTimeout;
    enum drainTimeout;
    enum overTemperature;
    enum leakDetected;
    enum heaterFault;
    enum pumpFault;
  }

  item def Water {
    attribute temperature : Celsius;
    attribute volume : Liter;
    attribute quality : WaterQuality;
  }

  item def Detergent {
    attribute mass : Gram;
    attribute concentration : Percent;
  }

  item def DishLoad {
    attribute loadMass : Kilogram;
    attribute soil : SoilLevel;
    attribute sanitized : Boolean;
    attribute clean : Boolean;
    attribute dry : Boolean;
  }

  item def WasteWater specializes Water {
    attribute suspendedSoilMass : Gram;
  }

  item def ElectricalPower {
    attribute voltage : Volt;
    attribute current : Ampere;
    attribute frequencyHz : Real;
  }

  item def UserCommand {
    attribute selectedCycle : CycleSelection;
    attribute startRequested : Boolean;
    attribute cancelRequested : Boolean;
    attribute delayStartMinutes : Minute;
  }

  item def CycleStatus {
    attribute activeCycle : CycleSelection;
    attribute remainingTime : Minute;
    attribute progress : Percent;
    attribute currentFault : FaultCode;
  }

  port def WaterInletPort {
    in item incomingWater : Water;
  }

  port def DrainPort {
    out item dischargedWater : WasteWater;
  }

  port def PowerInputPort {
    in item suppliedPower : ElectricalPower;
  }

  port def UserInterfacePort {
    in item command : UserCommand;
    out item status : CycleStatus;
  }

  port def WashChamberPort {
    inout item load : DishLoad;
    inout item chamberWater : Water;
  }

  port def DetergentPort {
    out item releasedDetergent : Detergent;
  }

  part def Dishwasher {
    attribute maxLoadMass : Kilogram = 12.0;
    attribute nominalWaterUsePerNormalCycle : Liter = 12.5;
    attribute nominalEnergyUsePerNormalCycleWh : Real = 950.0;
    attribute maximumWashTemperature : Celsius = 70.0;
    attribute noiseLevel : dBA = 46.0;
    attribute selectedCycle : CycleSelection = CycleSelection::normal;
    attribute fault : FaultCode = FaultCode::noFault;

    port waterSupply : WaterInletPort;
    port drainOutlet : DrainPort;
    port electricalInput : PowerInputPort;
    port operatorPanel : UserInterfacePort;
    port tubAccess : WashChamberPort;

    part controller : ControlUnit;
    part tub : WashTub;
    part door : DoorAssembly;
    part inletValve : InletValve;
    part circulationPump : CirculationPump;
    part spraySystem : SprayArmSystem;
    part heater : HeatingElement;
    part detergentDispenser : DetergentDispenser;
    part filter : SoilFilter;
    part drainPump : DrainPump;
    part dryingSystem : DryingSystem;
    part leakSensor : LeakSensor;
    part temperatureSensor : TemperatureSensor;
    part waterLevelSensor : WaterLevelSensor;
    part userInterface : UserInterface;

    connect electricalInput to controller.powerInput;
    connect controller.uiPort to userInterface.controlPort;
    connect operatorPanel to userInterface.externalPanel;
    connect waterSupply to inletValve.supplyPort;
    connect inletValve.outletPort to tub.fillPort;
    connect tub.sumpPort to circulationPump.intakePort;
    connect circulationPump.pressurePort to spraySystem.feedPort;
    connect spraySystem.chamberPort to tub.sprayPort;
    connect detergentDispenser.dosePort to tub.detergentPort;
    connect tub.drainPort to drainPump.intakePort;
    connect drainPump.dischargePort to drainOutlet;
    connect heater.thermalPort to tub.thermalPort;
    connect dryingSystem.airPort to tub.airPort;
    connect temperatureSensor.sensedPort to tub.thermalPort;
    connect waterLevelSensor.sensedPort to tub.levelPort;
    connect leakSensor.monitoredPort to tub.leakPort;
    connect tubAccess to tub.loadPort;
  }

  part def ControlUnit {
    attribute commandedCycle : CycleSelection = CycleSelection::normal;
    attribute cycleProgress : Percent = 0.0;
    attribute remainingTime : Minute = 0.0;
    attribute activeFault : FaultCode = FaultCode::noFault;

    port powerInput : PowerInputPort;
    port uiPort : UserInterfacePort;

    perform action runSelectedCycle;
  }

  part def UserInterface {
    port externalPanel : UserInterfacePort;
    port controlPort : UserInterfacePort;

    attribute displayedRemainingTime : Minute;
    attribute displayedProgress : Percent;
    attribute displayedFault : FaultCode;
  }

  part def WashTub {
    attribute internalVolume : Liter = 85.0;
    attribute currentWaterVolume : Liter = 0.0;
    attribute currentTemperature : Celsius = 20.0;
    attribute retainedSoilMass : Gram = 0.0;

    port fillPort : WaterInletPort;
    port loadPort : WashChamberPort;
    port sprayPort : WashChamberPort;
    port detergentPort : DetergentPort;
    port sumpPort : WashChamberPort;
    port drainPort : DrainPort;
    port thermalPort;
    port airPort;
    port levelPort;
    port leakPort;
  }

  part def DoorAssembly {
    attribute position : DoorPosition = DoorPosition::closed;
    attribute sealCompressionPercent : Percent = 95.0;
    attribute lockedDuringCycle : Boolean = false;
  }

  part def InletValve {
    attribute flowRate : Liter = 4.5;
    attribute open : Boolean = false;

    port supplyPort : WaterInletPort;
    port outletPort : WaterInletPort;
  }

  part def CirculationPump {
    attribute motorPower : Watt = 120.0;
    attribute impellerSpeed : RPM = 2800.0;
    attribute operating : Boolean = false;

    port intakePort : WashChamberPort;
    port pressurePort : WashChamberPort;
  }

  part def SprayArmSystem {
    attribute lowerArmSpeed : RPM = 35.0;
    attribute upperArmSpeed : RPM = 42.0;
    attribute nozzleCount : Integer = 38;

    port feedPort : WashChamberPort;
    port chamberPort : WashChamberPort;
  }

  part def HeatingElement {
    attribute ratedPower : Watt = 1800.0;
    attribute energized : Boolean = false;
    attribute targetTemperature : Celsius = 0.0;

    port thermalPort;
  }

  part def DetergentDispenser {
    attribute detergentCapacity : Gram = 45.0;
    attribute loadedDetergentMass : Gram = 30.0;
    attribute doorReleased : Boolean = false;

    port dosePort : DetergentPort;
  }

  part def SoilFilter {
    attribute capturedSoilMass : Gram = 0.0;
    attribute cloggingPercent : Percent = 0.0;
  }

  part def DrainPump {
    attribute pumpPower : Watt = 45.0;
    attribute drainRate : Liter = 8.0;
    attribute operating : Boolean = false;

    port intakePort : DrainPort;
    port dischargePort : DrainPort;
  }

  part def DryingSystem {
    attribute fanPower : Watt = 35.0;
    attribute ventOpen : Boolean = false;
    attribute dryingAirTemperature : Celsius = 55.0;

    port airPort;
  }

  part def TemperatureSensor {
    attribute measuredTemperature : Celsius;
    attribute accuracy : Celsius = 1.5;

    port sensedPort;
  }

  part def WaterLevelSensor {
    attribute measuredWaterVolume : Liter;
    attribute highLevelDetected : Boolean = false;
    attribute lowLevelDetected : Boolean = true;

    port sensedPort;
  }

  part def LeakSensor {
    attribute waterDetectedInBasePan : Boolean = false;

    port monitoredPort;
  }

  action def RunDishwasherCycle {
    in selectedCycle : CycleSelection;
    inout load : DishLoad;
    out completionStatus : CycleStatus;

    first start;

    action validateStartConditions {
      in doorPosition : DoorPosition;
      in loadMass : Kilogram;
      out permitted : Boolean;
    }

    action fillForPreWash {
      out fillWater : Water {
        attribute temperature = 20.0;
        attribute volume = 3.5;
        attribute quality = WaterQuality::clean;
      }
    }

    action preWash {
      inout load : DishLoad;
      inout water : Water;
    }

    action drainPreWash {
      in water : Water;
      out waste : WasteWater;
    }

    action dispenseDetergent {
      out detergentDose : Detergent {
        attribute mass = 22.0;
        attribute concentration = 100.0;
      }
    }

    action fillForMainWash {
      out fillWater : Water {
        attribute temperature = 20.0;
        attribute volume = 4.0;
        attribute quality = WaterQuality::clean;
      }
    }

    action heatMainWashWater {
      inout water : Water;
      in targetTemperature : Celsius = 62.0;
    }

    action washLoad {
      inout load : DishLoad;
      inout water : Water;
      in detergent : Detergent;
    }

    action drainMainWash {
      in water : Water;
      out waste : WasteWater;
    }

    action rinseLoad {
      inout load : DishLoad;
      inout water : Water;
    }

    action sanitizeLoad {
      inout load : DishLoad;
      in sanitizeTemperature : Celsius = 70.0;
      out sanitized : Boolean;
    }

    action dryLoad {
      inout load : DishLoad;
      in dryingTemperature : Celsius = 55.0;
      out dry : Boolean;
    }

    action reportComplete {
      out status : CycleStatus {
        attribute progress = 100.0;
        attribute currentFault = FaultCode::noFault;
      }
    }

    flow start then validateStartConditions;
    flow validateStartConditions then fillForPreWash;
    flow fillForPreWash then preWash;
    flow preWash then drainPreWash;
    flow drainPreWash then dispenseDetergent;
    flow dispenseDetergent then fillForMainWash;
    flow fillForMainWash then heatMainWashWater;
    flow heatMainWashWater then washLoad;
    flow washLoad then drainMainWash;
    flow drainMainWash then rinseLoad;
    flow rinseLoad then sanitizeLoad;
    flow sanitizeLoad then dryLoad;
    flow dryLoad then reportComplete;
  }

  state def DishwasherOperationalStates {
    entry;
    state Idle;
    state CycleSelected;
    state Filling;
    state PreWashing;
    state DrainingPreWash;
    state DispensingDetergent;
    state MainWashing;
    state Rinsing;
    state Sanitizing;
    state Drying;
    state Complete;
    state Faulted;

    transition entry first Idle;

    transition Idle_to_CycleSelected
      first Idle
      accept UserCommand
      if command.startRequested == false
      then CycleSelected;

    transition CycleSelected_to_Filling
      first CycleSelected
      accept UserCommand
      if command.startRequested == true
      then Filling;

    transition Filling_to_PreWashing
      first Filling
      if waterLevelSensor.highLevelDetected == true
      then PreWashing;

    transition PreWashing_to_DrainingPreWash
      first PreWashing
      after 8.0 [Minute]
      then DrainingPreWash;

    transition DrainingPreWash_to_DispensingDetergent
      first DrainingPreWash
      if waterLevelSensor.lowLevelDetected == true
      then DispensingDetergent;

    transition DispensingDetergent_to_MainWashing
      first DispensingDetergent
      after 1.0 [Minute]
      then MainWashing;

    transition MainWashing_to_Rinsing
      first MainWashing
      after 32.0 [Minute]
      then Rinsing;

    transition Rinsing_to_Sanitizing
      first Rinsing
      after 18.0 [Minute]
      then Sanitizing;

    transition Sanitizing_to_Drying
      first Sanitizing
      if temperatureSensor.measuredTemperature >= 70.0
      then Drying;

    transition Drying_to_Complete
      first Drying
      after 28.0 [Minute]
      then Complete;

    transition Complete_to_Idle
      first Complete
      accept UserCommand
      if command.startRequested == false
      then Idle;

    transition Any_to_Faulted_DoorOpen
      first Idle
      accept UserCommand
      if activeFault == FaultCode::doorOpen
      then Faulted;

    transition Any_to_Faulted_Leak
      first Filling
      if leakSensor.waterDetectedInBasePan == true
      then Faulted;

    transition Faulted_to_Idle
      first Faulted
      accept UserCommand
      if command.cancelRequested == true
      then Idle;
  }

  requirement def PrimaryFunctionRequirement {
    doc /* The dishwasher shall automatically clean, rinse, sanitize when selected, and dry a loaded set of dishware by controlling water, detergent, heat, spray circulation, filtration, drainage, and drying airflow through a complete user-selected wash cycle. */
  }

  requirement def LoadCapacityRequirement {
    require constraint {
      dishwasher.maxLoadMass >= 12.0
    }
  }

  requirement def NormalCycleWaterUseRequirement {
    require constraint {
      dishwasher.nominalWaterUsePerNormalCycle <= 13.0
    }
  }

  requirement def WashTemperatureRequirement {
    require constraint {
      dishwasher.maximumWashTemperature >= 65.0 and dishwasher.maximumWashTemperature <= 75.0
    }
  }

  requirement def DoorSafetyRequirement {
    doc /* The dishwasher shall prevent water circulation and heating when the door is open or not latched. */
  }

  requirement def LeakProtectionRequirement {
    doc /* The dishwasher shall stop water filling, stop circulation, energize the drain pump, and report a leak fault when water is detected in the base pan. */
  }

  requirement def DrainPerformanceRequirement {
    require constraint {
      drainPump.drainRate >= 7.0
    }
  }

  requirement def NoiseRequirement {
    require constraint {
      dishwasher.noiseLevel <= 48.0
    }
  }

  requirement def CompletionReportingRequirement {
    doc /* The dishwasher shall report cycle completion, remaining time, progress percentage, and fault status through the user interface. */
  }

  part dishwasher : Dishwasher;

  satisfy PrimaryFunctionRequirement by dishwasher;
  satisfy LoadCapacityRequirement by dishwasher;
  satisfy NormalCycleWaterUseRequirement by dishwasher;
  satisfy WashTemperatureRequirement by dishwasher;
  satisfy DoorSafetyRequirement by dishwasher.controller;
  satisfy LeakProtectionRequirement by dishwasher.leakSensor;
  satisfy DrainPerformanceRequirement by dishwasher.drainPump;
  satisfy NoiseRequirement by dishwasher;
  satisfy CompletionReportingRequirement by dishwasher.userInterface;

}