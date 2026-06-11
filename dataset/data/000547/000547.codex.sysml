package BiliBlanketPhototherapySystem {
  import ScalarValues::*;
  import SI::*;

  unit def nanometer :> metre;
  unit def milliwatt :> watt;
  unit def squareCentimeter :> squareMetre;
  unit def hour :> second;
  unit def degreeCelsius;

  attribute def Wavelength_nm :> Real {
    unit = nanometer;
  }

  attribute def Irradiance_mW_per_cm2_per_nm :> Real {
    unit = milliwatt / squareCentimeter / nanometer;
  }

  attribute def Temperature_C :> Real {
    unit = degreeCelsius;
  }

  attribute def TherapyTime_h :> Real {
    unit = hour;
  }

  attribute def ElectricalPower_W :> Real {
    unit = watt;
  }

  attribute def Percent :> Real;

  enum def TherapyStateKind {
    enum Off;
    enum Standby;
    enum SelfTest;
    enum Ready;
    enum DeliveringTherapy;
    enum Paused;
    enum Alarmed;
    enum Completed;
  }

  enum def AlarmKind {
    enum None;
    enum OverTemperature;
    enum LowIrradiance;
    enum PadDisconnected;
    enum SkinContactLost;
    enum PowerFault;
    enum SessionExpired;
  }

  item def ElectricalEnergy {
    attribute voltage_V : Real;
    attribute current_A : Real;
    attribute power_W : ElectricalPower_W;
  }

  item def BluePhototherapyLight {
    attribute peakWavelength : Wavelength_nm = 460.0;
    attribute lowerTherapeuticWavelength : Wavelength_nm = 430.0;
    attribute upperTherapeuticWavelength : Wavelength_nm = 490.0;
    attribute spectralIrradiance : Irradiance_mW_per_cm2_per_nm;
  }

  item def ThermalCondition {
    attribute blanketSurfaceTemperature : Temperature_C;
    attribute infantSkinTemperature : Temperature_C;
  }

  item def TreatmentPrescription {
    attribute prescribedDuration : TherapyTime_h;
    attribute targetIrradiance : Irradiance_mW_per_cm2_per_nm;
    attribute maximumSurfaceTemperature : Temperature_C = 38.0;
    attribute bilirubinReductionObjective_pct : Percent;
  }

  item def TreatmentStatus {
    attribute elapsedTime : TherapyTime_h;
    attribute deliveredDose_pct : Percent;
    attribute activeState : TherapyStateKind;
    attribute activeAlarm : AlarmKind;
  }

  port def ElectricalPowerPort {
    in item power : ElectricalEnergy;
  }

  port def OpticalOutputPort {
    out item light : BluePhototherapyLight;
  }

  port def OpticalInputPort {
    in item light : BluePhototherapyLight;
  }

  port def ThermalSensePort {
    out item condition : ThermalCondition;
  }

  port def PrescriptionPort {
    in item prescription : TreatmentPrescription;
  }

  port def StatusPort {
    out item status : TreatmentStatus;
  }

  port def AlarmPort {
    out item alarm : AlarmKind;
  }

  port def UserCommandPort {
    in item prescription : TreatmentPrescription;
    in item startCommand : Boolean;
    in item pauseCommand : Boolean;
    in item stopCommand : Boolean;
  }

  part def BiliblanketSystem {
    attribute systemState : TherapyStateKind = TherapyStateKind::Off;
    attribute nominalPeakWavelength : Wavelength_nm = 460.0;
    attribute minimumTherapeuticIrradiance : Irradiance_mW_per_cm2_per_nm = 30.0;
    attribute maximumSafeSurfaceTemperature : Temperature_C = 38.0;
    attribute maximumSessionDuration : TherapyTime_h = 24.0;

    port acPower : ElectricalPowerPort;
    port clinicianCommands : UserCommandPort;
    port therapyStatus : StatusPort;
    port audibleVisibleAlarm : AlarmPort;

    part powerSubsystem : PowerSubsystem;
    part therapyController : TherapyController;
    part lightEngine : BlueLedLightEngine;
    part fiberOpticPad : FiberOpticBlanketPad;
    part infantInterface : InfantWrap;
    part sensingSubsystem : SensingSubsystem;
    part userInterface : UserInterface;
    part alarmSubsystem : AlarmSubsystem;

    connect acPower to powerSubsystem.inputPower;
    connect powerSubsystem.controlledPower to therapyController.power;
    connect powerSubsystem.ledPower to lightEngine.power;
    connect therapyController.lightCommand to lightEngine.command;
    connect lightEngine.opticalOutput to fiberOpticPad.opticalInput;
    connect fiberOpticPad.therapeuticOutput to infantInterface.therapeuticInput;
    connect sensingSubsystem.temperatureData to therapyController.thermalInput;
    connect sensingSubsystem.irradianceData to therapyController.opticalFeedback;
    connect sensingSubsystem.contactData to therapyController.contactFeedback;
    connect clinicianCommands to userInterface.commands;
    connect userInterface.prescriptionOutput to therapyController.prescriptionInput;
    connect therapyController.statusOutput to therapyStatus;
    connect therapyController.alarmOutput to alarmSubsystem.alarmInput;
    connect alarmSubsystem.externalAlarm to audibleVisibleAlarm;
  }

  part def PowerSubsystem {
    port inputPower : ElectricalPowerPort;
    port controlledPower : ElectricalPowerPort;
    port ledPower : ElectricalPowerPort;

    attribute inputVoltage_V : Real = 120.0;
    attribute outputVoltage_V : Real = 24.0;
    attribute maximumOutputPower : ElectricalPower_W = 60.0;
    attribute leakageCurrent_mA : Real = 0.1;
  }

  part def BlueLedLightEngine {
    port power : ElectricalPowerPort;
    port command : PrescriptionPort;
    port opticalOutput : OpticalOutputPort;

    attribute ledCount : Integer = 96;
    attribute peakWavelength : Wavelength_nm = 460.0;
    attribute wavelengthTolerance_nm : Real = 10.0;
    attribute maximumIrradiance : Irradiance_mW_per_cm2_per_nm = 45.0;
    attribute dimmingLevel_pct : Percent;
  }

  part def FiberOpticBlanketPad {
    port opticalInput : OpticalInputPort;
    port therapeuticOutput : OpticalOutputPort;

    attribute emittingArea_cm2 : Real = 750.0;
    attribute opticalTransmission_pct : Percent = 82.0;
    attribute bendRadiusMinimum_cm : Real = 5.0;
    attribute washableCoverPresent : Boolean = true;
  }

  part def InfantWrap {
    port therapeuticInput : OpticalInputPort;

    attribute maintainsEyeExposureAvoidance : Boolean = true;
    attribute allowsFeedingDuringTreatment : Boolean = true;
    attribute supportsSkinContactPositioning : Boolean = true;
  }

  part def SensingSubsystem {
    port temperatureData : ThermalSensePort;
    port irradianceData : OpticalOutputPort;
    port contactData : StatusPort;

    part surfaceTemperatureSensor : SurfaceTemperatureSensor;
    part skinTemperatureSensor : SkinTemperatureSensor;
    part irradianceSensor : IrradianceSensor;
    part padConnectionSensor : PadConnectionSensor;
    part skinContactSensor : SkinContactSensor;
  }

  part def SurfaceTemperatureSensor {
    attribute measuredTemperature : Temperature_C;
    attribute accuracy_C : Real = 0.5;
  }

  part def SkinTemperatureSensor {
    attribute measuredTemperature : Temperature_C;
    attribute accuracy_C : Real = 0.5;
  }

  part def IrradianceSensor {
    attribute measuredIrradiance : Irradiance_mW_per_cm2_per_nm;
    attribute calibrationInterval_months : Integer = 12;
  }

  part def PadConnectionSensor {
    attribute padConnected : Boolean;
  }

  part def SkinContactSensor {
    attribute adequateContact : Boolean;
  }

  part def TherapyController {
    port power : ElectricalPowerPort;
    port prescriptionInput : PrescriptionPort;
    port thermalInput : ThermalSensePort;
    port opticalFeedback : OpticalInputPort;
    port contactFeedback : StatusPort;
    port lightCommand : PrescriptionPort;
    port statusOutput : StatusPort;
    port alarmOutput : AlarmPort;

    attribute commandedIrradiance : Irradiance_mW_per_cm2_per_nm;
    attribute elapsedTherapyTime : TherapyTime_h;
    attribute activeState : TherapyStateKind;
    attribute activeAlarm : AlarmKind = AlarmKind::None;
  }

  part def UserInterface {
    port commands : UserCommandPort;
    port prescriptionOutput : PrescriptionPort;

    attribute displayedElapsedTime : TherapyTime_h;
    attribute displayedIrradiance : Irradiance_mW_per_cm2_per_nm;
    attribute displayedAlarm : AlarmKind;
    attribute startButtonEnabled : Boolean;
  }

  part def AlarmSubsystem {
    port alarmInput : AlarmPort;
    port externalAlarm : AlarmPort;

    attribute audibleLevel_dBA : Real = 65.0;
    attribute visualIndicatorPresent : Boolean = true;
    attribute alarmSilenceDuration_min : Real = 2.0;
  }

  action def PerformSelfTest {
    in item inputPower : ElectricalEnergy;
    out item testPassed : Boolean;
    out item detectedAlarm : AlarmKind;
  }

  action def DeliverBlueLightTherapy {
    in item prescription : TreatmentPrescription;
    in item sensedTemperature : ThermalCondition;
    in item sensedLight : BluePhototherapyLight;
    out item status : TreatmentStatus;
    out item alarm : AlarmKind;
  }

  action def RegulateIrradiance {
    in item target : TreatmentPrescription;
    in item feedback : BluePhototherapyLight;
    out item commandedLight : BluePhototherapyLight;
  }

  action def MonitorSafety {
    in item temperature : ThermalCondition;
    in item light : BluePhototherapyLight;
    in item status : TreatmentStatus;
    out item alarm : AlarmKind;
  }

  state def TherapyControlStateMachine {
    entry action PerformSelfTest;

    state Off;
    state Standby;
    state SelfTest;
    state Ready;
    state DeliveringTherapy;
    state Paused;
    state Alarmed;
    state Completed;

    transition initial then Off;
    transition Off then Standby accept powerApplied;
    transition Standby then SelfTest accept prescriptionEntered;
    transition SelfTest then Ready if selfTestPassed;
    transition SelfTest then Alarmed if not selfTestPassed;
    transition Ready then DeliveringTherapy accept startCommand;
    transition DeliveringTherapy then Paused accept pauseCommand;
    transition Paused then DeliveringTherapy accept resumeCommand;
    transition DeliveringTherapy then Alarmed if activeAlarm != AlarmKind::None;
    transition DeliveringTherapy then Completed if elapsedTherapyTime >= prescribedDuration;
    transition Alarmed then Ready accept alarmCleared if activeAlarm == AlarmKind::None;
    transition Completed then Standby accept acknowledgeCompletion;
    transition Ready then Standby accept stopCommand;
    transition Paused then Standby accept stopCommand;
  }

  requirement def HighLevelPrimaryFunctionRequirement {
    subject system : BiliblanketSystem;

    doc
    /*
     The system shall provide high-level neonatal phototherapy by delivering controlled blue light through a flexible blanket pad to an infant's skin to support reduction of elevated bilirubin while allowing wrapping, holding, and routine care.
    */

    require constraint {
      system.nominalPeakWavelength >= 430.0 and
      system.nominalPeakWavelength <= 490.0 and
      system.minimumTherapeuticIrradiance >= 30.0
    }
  }

  requirement def IrradianceControlRequirement {
    subject controller : TherapyController;

    require constraint {
      controller.commandedIrradiance >= 30.0 and
      controller.commandedIrradiance <= 45.0
    }
  }

  requirement def ThermalSafetyRequirement {
    subject system : BiliblanketSystem;

    require constraint {
      system.maximumSafeSurfaceTemperature <= 38.0
    }
  }

  requirement def SessionDurationRequirement {
    subject system : BiliblanketSystem;

    require constraint {
      system.maximumSessionDuration <= 24.0
    }
  }

  requirement def OpticalSpectrumRequirement {
    subject lightEngine : BlueLedLightEngine;

    require constraint {
      lightEngine.peakWavelength >= 450.0 and
      lightEngine.peakWavelength <= 470.0
    }
  }

  requirement def AlarmRequirement {
    subject alarm : AlarmSubsystem;

    require constraint {
      alarm.visualIndicatorPresent == true and
      alarm.audibleLevel_dBA >= 60.0
    }
  }

  requirement def InfantCareAccessRequirement {
    subject wrap : InfantWrap;

    require constraint {
      wrap.allowsFeedingDuringTreatment == true and
      wrap.supportsSkinContactPositioning == true
    }
  }

  part biliBlanketPhototherapySystem : BiliblanketSystem;

  requirement highLevelPrimaryFunction : HighLevelPrimaryFunctionRequirement {
    subject system = biliBlanketPhototherapySystem;
  }

  requirement irradianceControl : IrradianceControlRequirement {
    subject controller = biliBlanketPhototherapySystem.therapyController;
  }

  requirement thermalSafety : ThermalSafetyRequirement {
    subject system = biliBlanketPhototherapySystem;
  }

  requirement opticalSpectrum : OpticalSpectrumRequirement {
    subject lightEngine = biliBlanketPhototherapySystem.lightEngine;
  }

  requirement alarmPerformance : AlarmRequirement {
    subject alarm = biliBlanketPhototherapySystem.alarmSubsystem;
  }

  requirement infantCareAccess : InfantCareAccessRequirement {
    subject wrap = biliBlanketPhototherapySystem.infantInterface;
  }
}