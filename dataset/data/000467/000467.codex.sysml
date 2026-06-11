package LUCAS_Device_High_Level_Model {

  import ScalarValues::*;
  import SI::*;

  attribute def Millimeter :> ISQ::length;
  attribute def Newton :> ISQ::force;
  attribute def CompressionPerMinute :> ISQ::frequency;
  attribute def Percent :> ISQ::dimensionless;
  attribute def Second :> ISQ::time;
  attribute def Volt :> ISQ::electricPotential;
  attribute def WattHour :> ISQ::energy;

  item def PatientThorax {
    attribute sternumPosition : Millimeter;
    attribute chestResistance : Newton;
    attribute recoilDetected : Boolean;
  }

  item def CompressionStroke {
    attribute targetDepth : Millimeter = 53;
    attribute actualDepth : Millimeter;
    attribute peakForce : Newton;
    attribute rate : CompressionPerMinute = 102;
    attribute dutyCycle : Percent = 50;
    attribute recoilComplete : Boolean;
  }

  item def TherapyStatus {
    attribute active : Boolean;
    attribute elapsedTherapyTime : Second;
    attribute deliveredCompressionCount : Integer;
    attribute alarmActive : Boolean;
    attribute pauseRequested : Boolean;
  }

  item def OperatorCommand {
    attribute powerOn : Boolean;
    attribute startTherapy : Boolean;
    attribute pauseTherapy : Boolean;
    attribute stopTherapy : Boolean;
    attribute adjustToPatient : Boolean;
  }

  item def BatteryEnergy {
    attribute voltage : Volt = 25.2;
    attribute remainingEnergy : WattHour;
    attribute stateOfCharge : Percent;
  }

  item def CompressionFeedback {
    attribute measuredDepth : Millimeter;
    attribute measuredForce : Newton;
    attribute measuredRate : CompressionPerMinute;
    attribute patientContact : Boolean;
  }

  port def PatientInterfacePort {
    out item stroke : CompressionStroke;
    in item thorax : PatientThorax;
  }

  port def OperatorInterfacePort {
    in item command : OperatorCommand;
    out item status : TherapyStatus;
  }

  port def PowerInputPort {
    in item energy : BatteryEnergy;
  }

  port def SensorPort {
    out item feedback : CompressionFeedback;
  }

  port def ActuatorCommandPort {
    in item targetStroke : CompressionStroke;
    out item feedback : CompressionFeedback;
  }

  part def LUCASChestCompressionSystem {
    attribute primaryFunction : String =
      "Provide consistent automated external chest compressions to support blood circulation during cardiopulmonary resuscitation.";
    attribute nominalCompressionDepth : Millimeter = 53;
    attribute nominalCompressionRate : CompressionPerMinute = 102;
    attribute maximumAllowedForce : Newton = 600;
    attribute therapyPaused : Boolean = true;

    port patientPort : PatientInterfacePort;
    port operatorPort : OperatorInterfacePort;
    port powerPort : PowerInputPort;

    part backPlate : BackPlate;
    part upperAssembly : UpperAssembly;
    part compressionPiston : CompressionPiston;
    part driveUnit : ElectromechanicalDriveUnit;
    part controller : TherapyController;
    part battery : RechargeableBattery;
    part sensors : CompressionSensorSet;
    part alarmUnit : AlarmUnit;
    part userPanel : UserControlPanel;

    connect powerPort.energy to battery.inputEnergy;
    connect battery.outputEnergy to controller.powerIn;
    connect battery.outputEnergy to driveUnit.powerIn;

    connect operatorPort.command to userPanel.commandIn;
    connect userPanel.validatedCommandOut to controller.commandIn;
    connect controller.statusOut to operatorPort.status;
    connect controller.statusOut to alarmUnit.statusIn;

    connect controller.strokeCommandOut to driveUnit.commandIn;
    connect driveUnit.mechanicalStrokeOut to compressionPiston.strokeIn;
    connect compressionPiston.patientContactOut to patientPort.stroke;

    connect patientPort.thorax to sensors.thoraxIn;
    connect compressionPiston.feedbackOut to sensors.pistonFeedbackIn;
    connect sensors.feedbackOut to controller.feedbackIn;

    perform action DeliverAutomatedChestCompressionTherapy;
    exhibit state TherapyLifecycle;
  }

  part def BackPlate {
    attribute supportsPatientMass : Boolean = true;
    attribute alignmentStable : Boolean;
  }

  part def UpperAssembly {
    attribute lockedToBackPlate : Boolean;
    attribute patientFitConfirmed : Boolean;
  }

  part def CompressionPiston {
    port strokeIn : ActuatorCommandPort;
    port patientContactOut : PatientInterfacePort;
    port feedbackOut : SensorPort;

    attribute currentPosition : Millimeter;
    attribute contactForce : Newton;
    attribute suctionCupAttached : Boolean;
  }

  part def ElectromechanicalDriveUnit {
    port powerIn : PowerInputPort;
    port commandIn : ActuatorCommandPort;
    port mechanicalStrokeOut : ActuatorCommandPort;

    attribute motorEnabled : Boolean;
    attribute commandedDepth : Millimeter;
    attribute commandedRate : CompressionPerMinute;
    attribute deliveredForce : Newton;
  }

  part def TherapyController {
    port powerIn : PowerInputPort;
    port commandIn : OperatorInterfacePort;
    port feedbackIn : SensorPort;
    port strokeCommandOut : ActuatorCommandPort;
    port statusOut : OperatorInterfacePort;

    attribute configuredDepth : Millimeter = 53;
    attribute configuredRate : CompressionPerMinute = 102;
    attribute compressionCounter : Integer = 0;
    attribute therapyTime : Second = 0;
    attribute faultDetected : Boolean = false;
  }

  part def RechargeableBattery {
    port inputEnergy : PowerInputPort;
    port outputEnergy : PowerInputPort;

    attribute nominalVoltage : Volt = 25.2;
    attribute remainingEnergy : WattHour;
    attribute lowChargeThreshold : Percent = 15;
    attribute stateOfCharge : Percent;
  }

  part def CompressionSensorSet {
    port thoraxIn : PatientInterfacePort;
    port pistonFeedbackIn : SensorPort;
    port feedbackOut : SensorPort;

    attribute depthMeasurement : Millimeter;
    attribute forceMeasurement : Newton;
    attribute recoilMeasurementValid : Boolean;
    attribute contactDetected : Boolean;
  }

  part def AlarmUnit {
    port statusIn : OperatorInterfacePort;

    attribute audibleAlarmActive : Boolean;
    attribute visualAlarmActive : Boolean;
    attribute alarmMessage : String;
  }

  part def UserControlPanel {
    port commandIn : OperatorInterfacePort;
    port validatedCommandOut : OperatorInterfacePort;

    attribute powerButtonPressed : Boolean;
    attribute startPauseButtonPressed : Boolean;
    attribute adjustmentModeSelected : Boolean;
  }

  action def DeliverAutomatedChestCompressionTherapy {
    in item patientThorax : PatientThorax;
    in item operatorCommand : OperatorCommand;
    out item therapyStatus : TherapyStatus;

    first start SelfTest;
    then AdjustToPatient;
    then GenerateCompressionCycle;
    then MonitorCompressionQuality;
    then ReportTherapyStatus;
  }

  action def SelfTest {
    out attribute passed : Boolean;
    action CheckBattery;
    action CheckController;
    action CheckDriveUnit;
    action CheckSensors;
  }

  action def AdjustToPatient {
    in item patientThorax : PatientThorax;
    out attribute initialSternumReference : Millimeter;
  }

  action def GenerateCompressionCycle {
    in attribute targetDepth : Millimeter = 53;
    in attribute targetRate : CompressionPerMinute = 102;
    out item stroke : CompressionStroke;
  }

  action def MonitorCompressionQuality {
    in item feedback : CompressionFeedback;
    out attribute compressionAcceptable : Boolean;
    constraint depthWithinRange {
      feedback.measuredDepth >= 50 and feedback.measuredDepth <= 60
    }
    constraint rateWithinRange {
      feedback.measuredRate >= 100 and feedback.measuredRate <= 104
    }
  }

  action def ReportTherapyStatus {
    in attribute compressionCounter : Integer;
    in attribute therapyTime : Second;
    in attribute faultDetected : Boolean;
    out item therapyStatus : TherapyStatus;
  }

  state def TherapyLifecycle {
    entry action SelfTest;

    state Off;
    state PowerUp;
    state ReadyForAdjustment;
    state AdjustingToPatient;
    state ReadyForTherapy;
    state Compressing;
    state Paused;
    state Fault;
    state Shutdown;

    transition initial then Off;

    transition Off_to_PowerUp
      first Off
      accept OperatorCommand.powerOn
      then PowerUp;

    transition PowerUp_to_ReadyForAdjustment
      first PowerUp
      if SelfTest.passed
      then ReadyForAdjustment;

    transition PowerUp_to_Fault
      first PowerUp
      if not SelfTest.passed
      then Fault;

    transition ReadyForAdjustment_to_AdjustingToPatient
      first ReadyForAdjustment
      accept OperatorCommand.adjustToPatient
      then AdjustingToPatient;

    transition AdjustingToPatient_to_ReadyForTherapy
      first AdjustingToPatient
      if CompressionSensorSet.contactDetected
      then ReadyForTherapy;

    transition ReadyForTherapy_to_Compressing
      first ReadyForTherapy
      accept OperatorCommand.startTherapy
      then Compressing;

    transition Compressing_to_Paused
      first Compressing
      accept OperatorCommand.pauseTherapy
      then Paused;

    transition Paused_to_Compressing
      first Paused
      accept OperatorCommand.startTherapy
      then Compressing;

    transition Compressing_to_Fault
      first Compressing
      if TherapyController.faultDetected
      then Fault;

    transition Paused_to_Shutdown
      first Paused
      accept OperatorCommand.stopTherapy
      then Shutdown;

    transition Fault_to_Shutdown
      first Fault
      accept OperatorCommand.stopTherapy
      then Shutdown;
  }

  requirement def PrimaryFunctionRequirement {
    subject lucas : LUCASChestCompressionSystem;

    doc
      /* The LUCAS device shall provide automated external chest compressions as its primary high-level function during resuscitation support. */

    require constraint primaryFunctionDefined {
      lucas.primaryFunction ==
      "Provide consistent automated external chest compressions to support blood circulation during cardiopulmonary resuscitation."
    }
  }

  requirement def CompressionDepthRequirement {
    subject lucas : LUCASChestCompressionSystem;

    doc
      /* The system shall command a nominal adult compression depth of 53 mm while monitoring actual depth. */

    require constraint nominalDepth {
      lucas.nominalCompressionDepth == 53
    }
  }

  requirement def CompressionRateRequirement {
    subject lucas : LUCASChestCompressionSystem;

    doc
      /* The system shall command automated compressions at approximately 102 compressions per minute. */

    require constraint nominalRate {
      lucas.nominalCompressionRate == 102
    }
  }

  requirement def PatientInterfaceRequirement {
    subject lucas : LUCASChestCompressionSystem;

    doc
      /* The system shall transfer compression strokes through a piston interface aligned with the patient's sternum. */

    require constraint patientInterfaceExists {
      exists lucas.patientPort
    }
  }

  requirement def OperatorControlRequirement {
    subject lucas : LUCASChestCompressionSystem;

    doc
      /* The system shall allow an operator to power on, adjust to the patient, start therapy, pause therapy, and stop therapy. */

    require constraint operatorInterfaceExists {
      exists lucas.operatorPort
    }
  }

  requirement def SafetyMonitoringRequirement {
    subject lucas : LUCASChestCompressionSystem;

    doc
      /* The system shall monitor compression depth, force, rate, patient contact, recoil, battery state, and fault status during operation. */

    require constraint sensorsPresent {
      exists lucas.sensors and exists lucas.alarmUnit
    }
  }

}