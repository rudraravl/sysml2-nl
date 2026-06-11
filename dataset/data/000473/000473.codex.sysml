package MiraDryHighLevelSystemModel {

  import ScalarValues::*;

  enum def DeviceMode {
    enum off;
    enum standby;
    enum ready;
    enum positioning;
    enum cooling;
    enum deliveringEnergy;
    enum verifying;
    enum completed;
    enum fault;
  }

  enum def TreatmentOutcome {
    enum untreated;
    enum treated;
    enum paused;
    enum aborted;
    enum completedSafely;
  }

  attribute def Power_W :> Real {
    doc "Power measured in watts.";
  }

  attribute def Energy_J :> Real {
    doc "Energy measured in joules.";
  }

  attribute def Frequency_GHz :> Real {
    doc "Microwave frequency measured in gigahertz.";
  }

  attribute def Temperature_C :> Real {
    doc "Temperature measured in degrees Celsius.";
  }

  attribute def Pressure_kPa :> Real {
    doc "Pressure measured in kilopascals.";
  }

  attribute def Time_s :> Real {
    doc "Time measured in seconds.";
  }

  attribute def Distance_mm :> Real {
    doc "Distance measured in millimeters.";
  }

  item def ElectricalPower {
    attribute voltage_V : Real;
    attribute current_A : Real;
    attribute availablePower_W : Power_W;
  }

  item def MicrowaveEnergy {
    attribute frequency_GHz : Frequency_GHz;
    attribute peakPower_W : Power_W;
    attribute deliveredEnergy_J : Energy_J;
    attribute pulseDuration_s : Time_s;
  }

  item def CoolingFlow {
    attribute coolantTemperature_C : Temperature_C;
    attribute interfaceTemperature_C : Temperature_C;
    attribute flowRate_mL_per_min : Real;
  }

  item def VacuumLoad {
    attribute suctionPressure_kPa : Pressure_kPa;
    attribute sealIntegrity_percent : Real;
  }

  item def TissueThermalState {
    attribute epidermisTemperature_C : Temperature_C;
    attribute dermisTemperature_C : Temperature_C;
    attribute targetDepth_mm : Distance_mm;
  }

  item def TreatmentCommand {
    attribute requestedMode : DeviceMode;
    attribute targetEnergy_J : Energy_J;
    attribute maxSkinTemperature_C : Temperature_C;
    attribute maxTreatmentTime_s : Time_s;
  }

  item def TreatmentStatus {
    attribute currentMode : DeviceMode;
    attribute deliveredEnergy_J : Energy_J;
    attribute elapsedTime_s : Time_s;
    attribute outcome : TreatmentOutcome;
    attribute alarmActive : Boolean;
  }

  port def PowerInputPort {
    in item power : ElectricalPower;
  }

  port def CommandInputPort {
    in item command : TreatmentCommand;
  }

  port def StatusOutputPort {
    out item status : TreatmentStatus;
  }

  port def MicrowaveOutputPort {
    out item energy : MicrowaveEnergy;
  }

  port def CoolingPort {
    out item cooling : CoolingFlow;
  }

  port def VacuumPort {
    out item vacuum : VacuumLoad;
  }

  port def TissueFeedbackPort {
    in item thermalState : TissueThermalState;
  }

  part def MiraDryTreatmentSystem {
    attribute nominalFrequency_GHz : Frequency_GHz = 5.8;
    attribute maxMicrowavePower_W : Power_W = 120.0;
    attribute maxTreatmentEnergyPerSpot_J : Energy_J = 6000.0;
    attribute maxAllowedSkinTemperature_C : Temperature_C = 45.0;
    attribute minimumCoolingTemperature_C : Temperature_C = 0.0;
    attribute maximumTreatmentTimePerSpot_s : Time_s = 120.0;

    port powerIn : PowerInputPort;
    port clinicianCommandIn : CommandInputPort;
    port statusOut : StatusOutputPort;

    part console : SystemConsole;
    part controller : TreatmentController;
    part microwaveGenerator : MicrowaveGenerator;
    part handpiece : TreatmentHandpiece;
    part coolingSubsystem : ContactCoolingSubsystem;
    part vacuumSubsystem : VacuumPositioningSubsystem;
    part tissueInterface : AxillaryTissueInterface;
    part safetyMonitor : SafetyMonitor;

    connect powerIn to console.powerIn;
    connect console.controlPowerOut to controller.powerIn;
    connect controller.generatorCommandOut to microwaveGenerator.commandIn;
    connect microwaveGenerator.energyOut to handpiece.microwaveIn;
    connect coolingSubsystem.coolingOut to handpiece.coolingIn;
    connect vacuumSubsystem.vacuumOut to handpiece.vacuumIn;
    connect handpiece.energyOut to tissueInterface.energyIn;
    connect handpiece.coolingOut to tissueInterface.coolingIn;
    connect handpiece.vacuumOut to tissueInterface.vacuumIn;
    connect tissueInterface.thermalFeedbackOut to safetyMonitor.tissueFeedbackIn;
    connect safetyMonitor.statusOut to controller.safetyStatusIn;
    connect clinicianCommandIn to controller.clinicianCommandIn;
    connect controller.statusOut to statusOut;

    exhibit state treatmentWorkflow : MiraDryTreatmentWorkflow;
    perform action deliverAxillarySweatReductionTreatment : DeliverAxillarySweatReductionTreatment;
  }

  part def SystemConsole {
    port powerIn : PowerInputPort;
    port controlPowerOut : PowerInputPort;
    attribute displayMode : DeviceMode;
    attribute mainsAvailable : Boolean;
  }

  part def TreatmentController {
    port powerIn : PowerInputPort;
    port clinicianCommandIn : CommandInputPort;
    port generatorCommandOut : CommandInputPort;
    port safetyStatusIn : StatusOutputPort;
    port statusOut : StatusOutputPort;

    attribute activeMode : DeviceMode;
    attribute commandedEnergy_J : Energy_J;
    attribute elapsedTreatmentTime_s : Time_s;
    attribute treatmentEnabled : Boolean;
  }

  part def MicrowaveGenerator {
    port commandIn : CommandInputPort;
    port energyOut : MicrowaveOutputPort;

    attribute outputFrequency_GHz : Frequency_GHz = 5.8;
    attribute commandedPower_W : Power_W;
    attribute emittedEnergy_J : Energy_J;
    attribute generatorReady : Boolean;
  }

  part def TreatmentHandpiece {
    port microwaveIn : MicrowaveOutputPort;
    port coolingIn : CoolingPort;
    port vacuumIn : VacuumPort;
    port energyOut : MicrowaveOutputPort;
    port coolingOut : CoolingPort;
    port vacuumOut : VacuumPort;

    attribute applicatorContactArea_mm2 : Real = 1200.0;
    attribute alignmentTolerance_mm : Distance_mm = 2.0;
    attribute disposableTipInstalled : Boolean;
  }

  part def ContactCoolingSubsystem {
    port coolingOut : CoolingPort;

    attribute coolantTemperature_C : Temperature_C;
    attribute targetInterfaceTemperature_C : Temperature_C = 5.0;
    attribute pumpEnabled : Boolean;
  }

  part def VacuumPositioningSubsystem {
    port vacuumOut : VacuumPort;

    attribute suctionPressure_kPa : Pressure_kPa;
    attribute minimumSealIntegrity_percent : Real = 90.0;
    attribute vacuumEnabled : Boolean;
  }

  part def AxillaryTissueInterface {
    port energyIn : MicrowaveOutputPort;
    port coolingIn : CoolingPort;
    port vacuumIn : VacuumPort;
    port thermalFeedbackOut : TissueFeedbackPort;

    attribute targetTissueDepth_mm : Distance_mm = 3.0;
    attribute sweatGlandThermalDose_J : Energy_J;
    attribute epidermisTemperature_C : Temperature_C;
    attribute treatmentOutcome : TreatmentOutcome;
  }

  part def SafetyMonitor {
    port tissueFeedbackIn : TissueFeedbackPort;
    port statusOut : StatusOutputPort;

    attribute skinTemperatureLimit_C : Temperature_C = 45.0;
    attribute vacuumLossAlarmThreshold_percent : Real = 85.0;
    attribute emergencyStopRequested : Boolean;
    attribute alarmActive : Boolean;
  }

  action def DeliverAxillarySweatReductionTreatment {
    in command : TreatmentCommand;
    in tissueState : TissueThermalState;
    out status : TreatmentStatus;

    first startTreatment;
    then verifyDisposableTip;
    then applyVacuumPositioning;
    then beginContactCooling;
    then deliverControlledMicrowaveEnergy;
    then monitorThermalResponse;
    then stopEnergyDelivery;
    then releaseVacuum;
    then reportTreatmentStatus;

    action startTreatment {
      out mode : DeviceMode = DeviceMode::positioning;
    }

    action verifyDisposableTip {
      out verified : Boolean = true;
    }

    action applyVacuumPositioning {
      out suctionPressure_kPa : Pressure_kPa = 55.0;
    }

    action beginContactCooling {
      out interfaceTemperature_C : Temperature_C = 5.0;
    }

    action deliverControlledMicrowaveEnergy {
      in targetEnergy_J : Energy_J;
      out deliveredEnergy_J : Energy_J;
      out frequency_GHz : Frequency_GHz = 5.8;
    }

    action monitorThermalResponse {
      in epidermisTemperature_C : Temperature_C;
      in dermisTemperature_C : Temperature_C;
      out safeToContinue : Boolean;
    }

    action stopEnergyDelivery {
      out generatorPower_W : Power_W = 0.0;
    }

    action releaseVacuum {
      out suctionPressure_kPa : Pressure_kPa = 0.0;
    }

    action reportTreatmentStatus {
      out finalOutcome : TreatmentOutcome = TreatmentOutcome::completedSafely;
    }
  }

  state def MiraDryTreatmentWorkflow {
    state off;
    state standby;
    state ready;
    state positioning;
    state cooling;
    state deliveringEnergy;
    state verifying;
    state completed;
    state fault;

    transition initial then off;
    transition powerApplied first off then standby;
    transition selfTestPassed first standby then ready;
    transition clinicianStartsTreatment first ready then positioning;
    transition vacuumSealEstablished first positioning then cooling;
    transition coolingAtTarget first cooling then deliveringEnergy;
    transition targetEnergyDelivered first deliveringEnergy then verifying;
    transition thermalDoseConfirmed first verifying then completed;
    transition resetForNextSpot first completed then ready;
    transition unsafeTemperatureDetected first deliveringEnergy then fault;
    transition vacuumSealLost first positioning then fault;
    transition emergencyStopPressed first standby then fault;
    transition resetAfterFault first fault then standby;
  }

  requirement def PrimaryFunctionRequirement {
    subject system : MiraDryTreatmentSystem;

    require constraint {
      system.controller.treatmentEnabled implies
      system.tissueInterface.treatmentOutcome == TreatmentOutcome::completedSafely
    }

    doc "The system shall noninvasively treat an axillary tissue site by positioning the handpiece, cooling the skin interface, delivering controlled microwave energy to the target tissue depth, monitoring safety limits, and reporting completion status.";
  }

  requirement def MicrowaveDeliveryRequirement {
    subject generator : MicrowaveGenerator;

    require constraint {
      generator.outputFrequency_GHz == 5.8 and
      generator.commandedPower_W <= 120.0
    }

    doc "The microwave generator shall deliver controlled microwave energy at the nominal therapeutic frequency without exceeding the configured maximum power.";
  }

  requirement def CoolingProtectionRequirement {
    subject cooling : ContactCoolingSubsystem;

    require constraint {
      cooling.coolantTemperature_C <= 10.0
    }

    doc "The cooling subsystem shall maintain contact cooling during energy delivery to reduce epidermal heating.";
  }

  requirement def VacuumPositioningRequirement {
    subject vacuum : VacuumPositioningSubsystem;

    require constraint {
      vacuum.suctionPressure_kPa >= 40.0 and
      vacuum.minimumSealIntegrity_percent >= 90.0
    }

    doc "The vacuum subsystem shall stabilize and position the treatment site before microwave energy is enabled.";
  }

  requirement def SafetyInterlockRequirement {
    subject monitor : SafetyMonitor;

    require constraint {
      monitor.alarmActive implies monitor.emergencyStopRequested or
      monitor.skinTemperatureLimit_C <= 45.0
    }

    doc "The safety monitor shall inhibit or stop energy delivery when skin temperature, vacuum seal, or emergency stop conditions indicate an unsafe treatment state.";
  }

  satisfy PrimaryFunctionRequirement by MiraDryTreatmentSystem;
  satisfy MicrowaveDeliveryRequirement by MicrowaveGenerator;
  satisfy CoolingProtectionRequirement by ContactCoolingSubsystem;
  satisfy VacuumPositioningRequirement by VacuumPositioningSubsystem;
  satisfy SafetyInterlockRequirement by SafetyMonitor;

}