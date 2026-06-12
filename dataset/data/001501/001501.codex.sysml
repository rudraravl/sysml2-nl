package MixAutomationSystem {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  attribute def Percent : Real {
    unit = "%";
  }

  attribute def Liter : Real {
    unit = "L";
  }

  attribute def LiterPerMinute : Real {
    unit = "L/min";
  }

  attribute def Kilogram : Real {
    unit = "kg";
  }

  attribute def RevolutionPerMinute : Real {
    unit = "rpm";
  }

  attribute def DegreeCelsius : Real {
    unit = "degC";
  }

  attribute def Second : Real {
    unit = "s";
  }

  attribute def Watt : Real {
    unit = "W";
  }

  item def Ingredient {
    attribute name : String;
    attribute batchMass : Kilogram;
    attribute targetVolume : Liter;
    attribute viscosityClass : String;
  }

  item def Mixture {
    attribute batchId : String;
    attribute actualVolume : Liter;
    attribute homogeneity : Percent;
    attribute temperature : DegreeCelsius;
    attribute status : String;
  }

  item def Recipe {
    attribute recipeId : String;
    attribute targetVolume : Liter;
    attribute targetMixSpeed : RevolutionPerMinute;
    attribute mixDuration : Second;
    attribute targetTemperature : DegreeCelsius;
    attribute requiredHomogeneity : Percent;
  }

  item def ProcessCommand {
    attribute commandId : String;
    attribute commandType : String;
  }

  item def ProcessStatus {
    attribute mode : String;
    attribute activeStep : String;
    attribute alarmActive : Boolean;
    attribute completionPercent : Percent;
  }

  item def SensorSignal {
    attribute measuredValue : Real;
    attribute quality : String;
  }

  item def ActuatorSignal {
    attribute setpoint : Real;
    attribute enable : Boolean;
  }

  port def IngredientInletPort {
    in item ingredient : Ingredient;
  }

  port def MixtureOutletPort {
    out item mixture : Mixture;
  }

  port def RecipePort {
    in item recipe : Recipe;
  }

  port def CommandPort {
    in item command : ProcessCommand;
  }

  port def StatusPort {
    out item status : ProcessStatus;
  }

  port def SensorPort {
    out item signal : SensorSignal;
  }

  port def ActuatorPort {
    in item signal : ActuatorSignal;
  }

  port def PowerPort {
    in attribute voltage : Volt;
    in attribute powerAvailable : Watt;
  }

  part def MixAutomation {
    doc /* Primary function: automatically dose ingredients, mix them according to a recipe, monitor process conditions, and discharge a completed homogeneous mixture while maintaining safety and traceability. */

    port recipeInput : RecipePort;
    port operatorCommand : CommandPort;
    port processStatus : StatusPort;
    port ingredientAInlet : IngredientInletPort;
    port ingredientBInlet : IngredientInletPort;
    port finishedMixtureOutlet : MixtureOutletPort;
    port electricalSupply : PowerPort;

    part controller : AutomationController;
    part vessel : MixingVessel;
    part dosingSkid : DosingSkid;
    part agitator : AgitatorAssembly;
    part thermalControl : ThermalControlUnit;
    part sensorSuite : ProcessSensorSuite;
    part dischargeUnit : DischargeUnit;
    part safetySystem : SafetySystem;
    part operatorPanel : OperatorInterface;

    connection recipeToController connect recipeInput to controller.recipeInput;
    connection commandToController connect operatorCommand to controller.commandInput;
    connection controllerStatusToSystem connect controller.statusOutput to processStatus;

    connection ingredientAToDosing connect ingredientAInlet to dosingSkid.ingredientAInlet;
    connection ingredientBToDosing connect ingredientBInlet to dosingSkid.ingredientBInlet;
    connection dosingToVessel connect dosingSkid.dosedIngredientOutlet to vessel.materialInlet;

    connection vesselToDischarge connect vessel.materialOutlet to dischargeUnit.mixtureInlet;
    connection dischargeToSystem connect dischargeUnit.mixtureOutlet to finishedMixtureOutlet;

    connection controllerToDosing connect controller.dosingCommand to dosingSkid.actuatorInput;
    connection controllerToAgitator connect controller.agitatorCommand to agitator.actuatorInput;
    connection controllerToThermal connect controller.temperatureCommand to thermalControl.actuatorInput;
    connection controllerToDischarge connect controller.dischargeCommand to dischargeUnit.actuatorInput;

    connection vesselLevelSignal connect sensorSuite.levelSensorOutput to controller.levelSensorInput;
    connection vesselTempSignal connect sensorSuite.temperatureSensorOutput to controller.temperatureSensorInput;
    connection vesselTorqueSignal connect sensorSuite.torqueSensorOutput to controller.torqueSensorInput;
    connection vesselHomogeneitySignal connect sensorSuite.homogeneitySensorOutput to controller.homogeneitySensorInput;

    connection safetyInterlock connect safetySystem.safetyStatus to controller.safetyInput;
    connection panelStatus connect controller.statusOutput to operatorPanel.statusInput;
    connection panelCommand connect operatorPanel.commandOutput to controller.commandInput;

    attribute nominalBatchVolume : Liter = 500.0;
    attribute maximumBatchVolume : Liter = 650.0;
    attribute minimumBatchVolume : Liter = 50.0;
  }

  part def AutomationController {
    port recipeInput : RecipePort;
    port commandInput : CommandPort;
    port statusOutput : StatusPort;
    port dosingCommand : ActuatorPort;
    port agitatorCommand : ActuatorPort;
    port temperatureCommand : ActuatorPort;
    port dischargeCommand : ActuatorPort;
    port levelSensorInput : SensorPort;
    port temperatureSensorInput : SensorPort;
    port torqueSensorInput : SensorPort;
    port homogeneitySensorInput : SensorPort;
    port safetyInput : SensorPort;

    attribute activeRecipe : Recipe;
    attribute batchCounter : Integer;
    attribute currentStep : String;
    attribute emergencyStopLatched : Boolean;
    attribute commandedMixSpeed : RevolutionPerMinute;
    attribute commandedDoseRate : LiterPerMinute;
  }

  part def MixingVessel {
    port materialInlet : IngredientInletPort;
    port materialOutlet : MixtureOutletPort;

    attribute workingVolume : Liter = 500.0;
    attribute maximumVolume : Liter = 650.0;
    attribute currentVolume : Liter;
    attribute designPressure : Pascal = 200000.0;
    attribute vesselTemperature : DegreeCelsius;
  }

  part def DosingSkid {
    port ingredientAInlet : IngredientInletPort;
    port ingredientBInlet : IngredientInletPort;
    port dosedIngredientOutlet : IngredientInletPort;
    port actuatorInput : ActuatorPort;

    part pumpA : MeteringPump;
    part pumpB : MeteringPump;
    part inletValveA : ControlValve;
    part inletValveB : ControlValve;

    attribute maxCombinedFlowRate : LiterPerMinute = 120.0;
    attribute dosingAccuracy : Percent = 1.0;
  }

  part def MeteringPump {
    port command : ActuatorPort;
    attribute maximumFlowRate : LiterPerMinute = 75.0;
    attribute minimumFlowRate : LiterPerMinute = 1.0;
    attribute ratedPower : Watt = 1500.0;
  }

  part def ControlValve {
    port command : ActuatorPort;
    attribute opening : Percent;
    attribute failClosed : Boolean = true;
  }

  part def AgitatorAssembly {
    port actuatorInput : ActuatorPort;
    attribute speed : RevolutionPerMinute;
    attribute maximumSpeed : RevolutionPerMinute = 1800.0;
    attribute minimumControlledSpeed : RevolutionPerMinute = 60.0;
    attribute motorPower : Watt = 7500.0;
  }

  part def ThermalControlUnit {
    port actuatorInput : ActuatorPort;
    attribute heatingPower : Watt = 9000.0;
    attribute coolingCapacity : Watt = 7000.0;
    attribute temperatureControlTolerance : DegreeCelsius = 1.5;
  }

  part def ProcessSensorSuite {
    port levelSensorOutput : SensorPort;
    port temperatureSensorOutput : SensorPort;
    port torqueSensorOutput : SensorPort;
    port homogeneitySensorOutput : SensorPort;

    attribute levelRange : Liter = 650.0;
    attribute temperatureRangeHigh : DegreeCelsius = 120.0;
    attribute homogeneityMeasurementAccuracy : Percent = 2.0;
  }

  part def DischargeUnit {
    port mixtureInlet : MixtureOutletPort;
    port mixtureOutlet : MixtureOutletPort;
    port actuatorInput : ActuatorPort;

    part dischargeValve : ControlValve;
    part transferPump : MeteringPump;

    attribute maximumDischargeRate : LiterPerMinute = 150.0;
  }

  part def SafetySystem {
    port safetyStatus : SensorPort;

    attribute guardClosed : Boolean;
    attribute overTemperatureTrip : Boolean;
    attribute overTorqueTrip : Boolean;
    attribute emergencyStopPressed : Boolean;
  }

  part def OperatorInterface {
    port commandOutput : CommandPort;
    port statusInput : StatusPort;

    attribute selectedRecipeId : String;
    attribute operatorId : String;
    attribute manualModeEnabled : Boolean;
  }

  action def ExecuteBatchMix {
    in item recipe : Recipe;
    in item ingredientA : Ingredient;
    in item ingredientB : Ingredient;
    out item completedMixture : Mixture;

    first startBatch;
    then validateRecipe;
    then verifySafety;
    then doseIngredientA;
    then doseIngredientB;
    then rampAgitator;
    then controlTemperature;
    then mixUntilHomogeneous;
    then stopAgitator;
    then dischargeMixture;
    then recordBatch;

    action startBatch;
    action validateRecipe;
    action verifySafety;
    action doseIngredientA;
    action doseIngredientB;
    action rampAgitator;
    action controlTemperature;
    action mixUntilHomogeneous;
    action stopAgitator;
    action dischargeMixture;
    action recordBatch;
  }

  state def BatchMixingStateMachine {
    entry action initializeController;

    state Idle;
    state RecipeLoaded;
    state SafetyCheck;
    state Dosing;
    state Mixing;
    state TemperatureHold;
    state QualityVerification;
    state Discharging;
    state Complete;
    state Faulted;
    state EmergencyStopped;

    transition idleToLoaded
      first Idle
      accept ProcessCommand
      if commandType == "LoadRecipe"
      then RecipeLoaded;

    transition loadedToSafety
      first RecipeLoaded
      accept ProcessCommand
      if commandType == "StartBatch"
      then SafetyCheck;

    transition safetyToDosing
      first SafetyCheck
      if emergencyStopLatched == false
      then Dosing;

    transition dosingToMixing
      first Dosing
      if currentVolume >= activeRecipe.targetVolume
      then Mixing;

    transition mixingToHold
      first Mixing
      if commandedMixSpeed == activeRecipe.targetMixSpeed
      then TemperatureHold;

    transition holdToQuality
      first TemperatureHold
      if vesselTemperature >= activeRecipe.targetTemperature - 1.5 and vesselTemperature <= activeRecipe.targetTemperature + 1.5
      then QualityVerification;

    transition qualityToDischarge
      first QualityVerification
      if homogeneity >= activeRecipe.requiredHomogeneity
      then Discharging;

    transition dischargeToComplete
      first Discharging
      if currentVolume <= 5.0
      then Complete;

    transition completeToIdle
      first Complete
      accept ProcessCommand
      if commandType == "Reset"
      then Idle;

    transition anyToFault
      first Idle, RecipeLoaded, SafetyCheck, Dosing, Mixing, TemperatureHold, QualityVerification, Discharging
      if overTemperatureTrip == true or overTorqueTrip == true
      then Faulted;

    transition anyToEmergencyStopped
      first Idle, RecipeLoaded, SafetyCheck, Dosing, Mixing, TemperatureHold, QualityVerification, Discharging, Faulted
      if emergencyStopPressed == true
      then EmergencyStopped;

    transition faultToIdle
      first Faulted
      accept ProcessCommand
      if commandType == "AcknowledgeFault"
      then Idle;
  }

  requirement def PrimaryFunctionRequirement {
    subject system : MixAutomation;

    require constraint {
      system shall dose, blend, monitor, and discharge a recipe-defined mixture with automatic sequencing and operator-supervised status reporting.
    }
  }

  requirement def BatchVolumeRequirement {
    subject system : MixAutomation;

    require constraint {
      system.nominalBatchVolume <= system.maximumBatchVolume and
      system.nominalBatchVolume >= system.minimumBatchVolume
    }
  }

  requirement def HomogeneityRequirement {
    subject mixture : Mixture;
    subject recipe : Recipe;

    require constraint {
      mixture.homogeneity >= recipe.requiredHomogeneity
    }
  }

  requirement def TemperatureControlRequirement {
    subject mixture : Mixture;
    subject recipe : Recipe;

    require constraint {
      mixture.temperature >= recipe.targetTemperature - 1.5 and
      mixture.temperature <= recipe.targetTemperature + 1.5
    }
  }

  requirement def DosingAccuracyRequirement {
    subject skid : DosingSkid;

    require constraint {
      skid.dosingAccuracy <= 1.0
    }
  }

  requirement def SafetyInterlockRequirement {
    subject safety : SafetySystem;

    require constraint {
      safety.guardClosed == true and
      safety.emergencyStopPressed == false and
      safety.overTemperatureTrip == false and
      safety.overTorqueTrip == false
    }
  }

  requirement def FailSafeValveRequirement {
    subject valve : ControlValve;

    require constraint {
      valve.failClosed == true
    }
  }

  requirement def StatusReportingRequirement {
    subject controller : AutomationController;

    require constraint {
      controller shall publish current mode, active batch step, alarm state, and completion percentage during automatic operation.
    }
  }

  satisfy PrimaryFunctionSatisfaction by MixAutomation;
  satisfy BatchVolumeSatisfaction by MixAutomation;
  satisfy HomogeneitySatisfaction by Mixture;
  satisfy TemperatureSatisfaction by ThermalControlUnit;
  satisfy DosingAccuracySatisfaction by DosingSkid;
  satisfy SafetySatisfaction by SafetySystem;
  satisfy ValveSafetySatisfaction by ControlValve;
  satisfy StatusReportingSatisfaction by AutomationController;

  part mixAutomationSystem : MixAutomation {
    attribute nominalBatchVolume = 500.0;
    attribute maximumBatchVolume = 650.0;
    attribute minimumBatchVolume = 50.0;
  }

  action automaticBatchRun : ExecuteBatchMix;

}