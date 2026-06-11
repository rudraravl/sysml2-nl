package ExaminationTableSystem {

  import ScalarValues::*;
  import SI::*;
  import ISQ::*;
  import Requirements::*;

  attribute def LengthValue :> ScalarValues::Real {
    unit = SI::metre;
  }

  attribute def MassValue :> ScalarValues::Real {
    unit = SI::kilogram;
  }

  attribute def ForceValue :> ScalarValues::Real {
    unit = SI::newton;
  }

  attribute def TimeValue :> ScalarValues::Real {
    unit = SI::second;
  }

  attribute def PowerValue :> ScalarValues::Real {
    unit = SI::watt;
  }

  attribute def VoltageValue :> ScalarValues::Real {
    unit = SI::volt;
  }

  attribute def CurrentValue :> ScalarValues::Real {
    unit = SI::ampere;
  }

  attribute def AngleValue :> ScalarValues::Real {
    unit = SI::degree;
  }

  attribute def TemperatureValue :> ScalarValues::Real {
    unit = SI::degreeCelsius;
  }

  attribute def PercentValue :> ScalarValues::Real {
    unit = SI::percent;
  }

  enum def TableMotionMode {
    enum idle;
    enum raising;
    enum lowering;
    enum tiltingBackrest;
    enum returningFlat;
    enum emergencyStopped;
  }

  enum def PatientSupportMode {
    enum empty;
    enum patientBoarding;
    enum patientSupported;
    enum patientExiting;
  }

  enum def PowerSourceState {
    enum disconnected;
    enum mainsAvailable;
    enum batteryBackup;
  }

  item def ElectricalPower {
    attribute voltage : VoltageValue;
    attribute current : CurrentValue;
    attribute frequency : ScalarValues::Real;
  }

  item def ControlCommand {
    attribute requestedHeight : LengthValue;
    attribute requestedBackrestAngle : AngleValue;
    attribute enableMotion : Boolean;
    attribute emergencyStop : Boolean;
  }

  item def MotionStatus {
    attribute actualHeight : LengthValue;
    attribute actualBackrestAngle : AngleValue;
    attribute motionMode : TableMotionMode;
    attribute limitReached : Boolean;
    attribute faultActive : Boolean;
  }

  item def PatientLoad {
    attribute mass : MassValue;
    attribute distributedForce : ForceValue;
    attribute centerOffsetFromTableCenter : LengthValue;
  }

  item def CaregiverInput {
    attribute raisePressed : Boolean;
    attribute lowerPressed : Boolean;
    attribute backrestUpPressed : Boolean;
    attribute backrestDownPressed : Boolean;
    attribute stopPressed : Boolean;
  }

  item def SafetySignal {
    attribute obstructionDetected : Boolean;
    attribute sideRailLatched : Boolean;
    attribute overloadDetected : Boolean;
    attribute emergencyStopPressed : Boolean;
  }

  port def ElectricalInPort {
    in item power : ElectricalPower;
  }

  port def CommandInPort {
    in item command : ControlCommand;
  }

  port def StatusOutPort {
    out item status : MotionStatus;
  }

  port def PatientLoadPort {
    in item load : PatientLoad;
  }

  port def CaregiverInputPort {
    out item input : CaregiverInput;
  }

  port def SafetySignalPort {
    out item signal : SafetySignal;
  }

  part def TableBase {
    attribute footprintLength : LengthValue = 1.55;
    attribute footprintWidth : LengthValue = 0.72;
    attribute mass : MassValue = 82.0;
    attribute casterDiameter : LengthValue = 0.125;

    port powerIn : ElectricalInPort;
    port statusOut : StatusOutPort;

    part caster[4] {
      attribute locked : Boolean;
      attribute brakeHoldingForce : ForceValue = 450.0;
    }

    part frame {
      attribute materialYieldStrength : ScalarValues::Real = 250000000.0;
      attribute corrosionResistantFinish : Boolean = true;
    }
  }

  part def HeightLiftAssembly {
    attribute minHeight : LengthValue = 0.48;
    attribute maxHeight : LengthValue = 0.94;
    attribute verticalTravel : LengthValue = 0.46;
    attribute ratedLiftForce : ForceValue = 3200.0;
    attribute liftSpeed : ScalarValues::Real = 0.018;
    attribute currentHeight : LengthValue = 0.68;

    port commandIn : CommandInPort;
    port statusOut : StatusOutPort;
    port safetyIn : SafetySignalPort;

    part columnActuator {
      attribute supplyVoltage : VoltageValue = 24.0;
      attribute peakCurrent : CurrentValue = 8.0;
      attribute dutyCycleLimit : PercentValue = 10.0;
      attribute thermalCutoffTemperature : TemperatureValue = 85.0;
    }

    part lowerLimitSwitch {
      attribute engaged : Boolean;
    }

    part upperLimitSwitch {
      attribute engaged : Boolean;
    }
  }

  part def PatientSupportDeck {
    attribute deckLength : LengthValue = 1.90;
    attribute deckWidth : LengthValue = 0.68;
    attribute cushionThickness : LengthValue = 0.075;
    attribute cushionFirmness : ScalarValues::Real = 38.0;
    attribute safeWorkingLoad : MassValue = 250.0;
    attribute backrestAngle : AngleValue = 0.0;

    port patientLoadIn : PatientLoadPort;
    port statusOut : StatusOutPort;

    part seatSection {
      attribute length : LengthValue = 0.82;
      attribute width : LengthValue = 0.68;
    }

    part backrestSection {
      attribute length : LengthValue = 0.78;
      attribute width : LengthValue = 0.68;
      attribute minAngle : AngleValue = 0.0;
      attribute maxAngle : AngleValue = 70.0;
    }

    part legSection {
      attribute length : LengthValue = 0.30;
      attribute width : LengthValue = 0.68;
    }

    part paperRollHolder {
      attribute rollWidth : LengthValue = 0.53;
      attribute remainingPaperLength : LengthValue = 35.0;
    }
  }

  part def BackrestActuationAssembly {
    attribute minAngle : AngleValue = 0.0;
    attribute maxAngle : AngleValue = 70.0;
    attribute angularRate : ScalarValues::Real = 3.0;
    attribute ratedPushForce : ForceValue = 1800.0;

    port commandIn : CommandInPort;
    port statusOut : StatusOutPort;
    port safetyIn : SafetySignalPort;

    part linearActuator {
      attribute strokeLength : LengthValue = 0.22;
      attribute supplyVoltage : VoltageValue = 24.0;
      attribute peakCurrent : CurrentValue = 6.5;
      attribute selfLocking : Boolean = true;
    }

    part angleSensor {
      attribute measuredAngle : AngleValue;
      attribute accuracy : AngleValue = 1.0;
    }
  }

  part def UserControlPendant {
    attribute cableLength : LengthValue = 2.0;
    attribute ingressProtectionRating : String = "IPX4";

    port caregiverInputOut : CaregiverInputPort;

    part raiseButton {
      attribute pressed : Boolean;
    }

    part lowerButton {
      attribute pressed : Boolean;
    }

    part backrestUpButton {
      attribute pressed : Boolean;
    }

    part backrestDownButton {
      attribute pressed : Boolean;
    }

    part stopButton {
      attribute pressed : Boolean;
    }
  }

  part def SafetySubsystem {
    attribute emergencyStopLatched : Boolean = false;
    attribute overloadThreshold : MassValue = 275.0;
    attribute obstructionForceThreshold : ForceValue = 150.0;

    port safetyOut : SafetySignalPort;
    port patientLoadIn : PatientLoadPort;
    port caregiverInputIn : CaregiverInputPort;

    part sideRailSensor[2] {
      attribute latched : Boolean;
    }

    part obstructionSensor {
      attribute detectedForce : ForceValue;
      attribute obstructionDetected : Boolean;
    }

    part loadSensor[4] {
      attribute measuredLoad : MassValue;
    }

    part emergencyStopCircuit {
      attribute stopPressed : Boolean;
      attribute relayClosed : Boolean;
    }
  }

  part def PowerSubsystem {
    attribute inputVoltage : VoltageValue = 120.0;
    attribute outputVoltage : VoltageValue = 24.0;
    attribute maxOutputPower : PowerValue = 240.0;
    attribute backupRuntime : TimeValue = 600.0;
    attribute sourceState : PowerSourceState = PowerSourceState::mainsAvailable;

    port mainsIn : ElectricalInPort;
    port dcOut : ElectricalInPort;

    part acDcConverter {
      attribute efficiency : PercentValue = 88.0;
      attribute isolationVoltage : VoltageValue = 1500.0;
    }

    part battery {
      attribute nominalVoltage : VoltageValue = 24.0;
      attribute capacityAmpHours : ScalarValues::Real = 2.9;
      attribute stateOfCharge : PercentValue = 100.0;
    }

    part fuse {
      attribute rating : CurrentValue = 12.0;
      attribute open : Boolean = false;
    }
  }

  part def MotionController {
    attribute controlLoopPeriod : TimeValue = 0.02;
    attribute commandedHeight : LengthValue = 0.68;
    attribute commandedBackrestAngle : AngleValue = 0.0;
    attribute currentMode : TableMotionMode = TableMotionMode::idle;

    port caregiverInputIn : CaregiverInputPort;
    port safetyIn : SafetySignalPort;
    port commandOut : CommandInPort;
    port statusIn : StatusOutPort;
    port statusOut : StatusOutPort;

    part microcontroller {
      attribute supplyVoltage : VoltageValue = 5.0;
      attribute watchdogTimeout : TimeValue = 0.1;
    }

    part motorDriverHeight {
      attribute outputVoltage : VoltageValue = 24.0;
      attribute maxCurrent : CurrentValue = 10.0;
    }

    part motorDriverBackrest {
      attribute outputVoltage : VoltageValue = 24.0;
      attribute maxCurrent : CurrentValue = 8.0;
    }
  }

  action def InterpretCaregiverInput {
    in item input : CaregiverInput;
    in item safety : SafetySignal;
    out item command : ControlCommand;

    first start;
    then decideStop;

    action decideStop {
      if safety.emergencyStopPressed or input.stopPressed then stopCommand;
      else decideMotion;
    }

    action stopCommand {
      command.enableMotion := false;
      command.emergencyStop := true;
    }

    action decideMotion {
      if input.raisePressed then raiseCommand;
      else if input.lowerPressed then lowerCommand;
      else if input.backrestUpPressed then backrestUpCommand;
      else if input.backrestDownPressed then backrestDownCommand;
      else holdCommand;
    }

    action raiseCommand {
      command.enableMotion := true;
      command.emergencyStop := false;
      command.requestedHeight := 0.94;
    }

    action lowerCommand {
      command.enableMotion := true;
      command.emergencyStop := false;
      command.requestedHeight := 0.48;
    }

    action backrestUpCommand {
      command.enableMotion := true;
      command.emergencyStop := false;
      command.requestedBackrestAngle := 70.0;
    }

    action backrestDownCommand {
      command.enableMotion := true;
      command.emergencyStop := false;
      command.requestedBackrestAngle := 0.0;
    }

    action holdCommand {
      command.enableMotion := false;
      command.emergencyStop := false;
    }

    then done;
  }

  action def SupportPatientForExamination {
    in item patientLoad : PatientLoad;
    in item caregiverInput : CaregiverInput;
    in item safety : SafetySignal;
    out item status : MotionStatus;

    first receivePatient;
    then stabilizeTable;
    then positionDeck;
    then maintainExamPosition;
    then releasePatient;

    action receivePatient {
      status.motionMode := TableMotionMode::idle;
    }

    action stabilizeTable {
      if patientLoad.mass <= 250.0 and safety.sideRailLatched then positionDeck;
      else stopForUnsafeCondition;
    }

    action positionDeck {
      if caregiverInput.raisePressed then status.motionMode := TableMotionMode::raising;
      if caregiverInput.lowerPressed then status.motionMode := TableMotionMode::lowering;
      if caregiverInput.backrestUpPressed then status.motionMode := TableMotionMode::tiltingBackrest;
      if caregiverInput.backrestDownPressed then status.motionMode := TableMotionMode::returningFlat;
    }

    action maintainExamPosition {
      status.faultActive := false;
      status.limitReached := false;
    }

    action stopForUnsafeCondition {
      status.motionMode := TableMotionMode::emergencyStopped;
      status.faultActive := true;
    }

    action releasePatient {
      status.motionMode := TableMotionMode::idle;
    }

    then done;
  }

  state def ExaminationTableOperatingState {
    entry action initialize {
      send ControlCommand {
        requestedHeight = 0.68;
        requestedBackrestAngle = 0.0;
        enableMotion = false;
        emergencyStop = false;
      }
    }

    state Off;
    state Ready;
    state BoardingPatient;
    state SupportingPatient;
    state AdjustingHeight;
    state AdjustingBackrest;
    state ExaminationPosition;
    state PatientExit;
    state Fault;
    state EmergencyStop;

    transition first Off;
    transition Off_to_Ready
      first Off
      accept ElectricalPower
      then Ready;

    transition Ready_to_Boarding
      first Ready
      accept PatientLoad
      if load.mass > 5.0 and load.mass <= 250.0
      then BoardingPatient;

    transition Boarding_to_Supporting
      first BoardingPatient
      if true
      then SupportingPatient;

    transition Supporting_to_HeightAdjustment
      first SupportingPatient
      accept CaregiverInput
      if input.raisePressed or input.lowerPressed
      then AdjustingHeight;

    transition Supporting_to_BackrestAdjustment
      first SupportingPatient
      accept CaregiverInput
      if input.backrestUpPressed or input.backrestDownPressed
      then AdjustingBackrest;

    transition HeightAdjustment_to_Exam
      first AdjustingHeight
      accept MotionStatus
      if not status.faultActive
      then ExaminationPosition;

    transition BackrestAdjustment_to_Exam
      first AdjustingBackrest
      accept MotionStatus
      if not status.faultActive
      then ExaminationPosition;

    transition Exam_to_AdjustHeight
      first ExaminationPosition
      accept CaregiverInput
      if input.raisePressed or input.lowerPressed
      then AdjustingHeight;

    transition Exam_to_AdjustBackrest
      first ExaminationPosition
      accept CaregiverInput
      if input.backrestUpPressed or input.backrestDownPressed
      then AdjustingBackrest;

    transition Exam_to_Exit
      first ExaminationPosition
      accept PatientLoad
      if load.mass < 5.0
      then PatientExit;

    transition Exit_to_Ready
      first PatientExit
      then Ready;

    transition Any_to_Fault
      first Ready
      accept SafetySignal
      if signal.overloadDetected or signal.obstructionDetected
      then Fault;

    transition Supporting_to_Fault
      first SupportingPatient
      accept SafetySignal
      if signal.overloadDetected or signal.obstructionDetected
      then Fault;

    transition AdjustHeight_to_Fault
      first AdjustingHeight
      accept SafetySignal
      if signal.overloadDetected or signal.obstructionDetected
      then Fault;

    transition AdjustBackrest_to_Fault
      first AdjustingBackrest
      accept SafetySignal
      if signal.overloadDetected or signal.obstructionDetected
      then Fault;

    transition Any_to_EStop
      first Ready
      accept SafetySignal
      if signal.emergencyStopPressed
      then EmergencyStop;

    transition Fault_to_Ready
      first Fault
      accept CaregiverInput
      if input.stopPressed
      then Ready;

    transition EStop_to_Ready
      first EmergencyStop
      accept CaregiverInput
      if not input.stopPressed
      then Ready;
  }

  part def ExaminationTable {
    attribute primaryFunction : String =
      "Support, position, and stabilize a patient at an ergonomic height and posture so a clinician can perform a physical examination safely and efficiently.";

    attribute overallLength : LengthValue = 1.95;
    attribute overallWidth : LengthValue = 0.74;
    attribute minimumHeight : LengthValue = 0.48;
    attribute maximumHeight : LengthValue = 0.94;
    attribute maximumPatientMass : MassValue = 250.0;
    attribute expectedServiceLifeYears : ScalarValues::Integer = 10;

    port mainsPower : ElectricalInPort;
    port patientLoad : PatientLoadPort;
    port caregiverControls : CaregiverInputPort;
    port tableStatus : StatusOutPort;

    part base : TableBase;
    part lift : HeightLiftAssembly;
    part deck : PatientSupportDeck;
    part backrestActuator : BackrestActuationAssembly;
    part pendant : UserControlPendant;
    part safety : SafetySubsystem;
    part power : PowerSubsystem;
    part controller : MotionController;

    connect mainsPower to power.mainsIn;
    connect power.dcOut to base.powerIn;
    connect pendant.caregiverInputOut to controller.caregiverInputIn;
    connect pendant.caregiverInputOut to safety.caregiverInputIn;
    connect patientLoad to deck.patientLoadIn;
    connect patientLoad to safety.patientLoadIn;
    connect safety.safetyOut to controller.safetyIn;
    connect safety.safetyOut to lift.safetyIn;
    connect safety.safetyOut to backrestActuator.safetyIn;
    connect controller.commandOut to lift.commandIn;
    connect controller.commandOut to backrestActuator.commandIn;
    connect lift.statusOut to controller.statusIn;
    connect backrestActuator.statusOut to controller.statusIn;
    connect controller.statusOut to tableStatus;
    connect deck.statusOut to tableStatus;
    connect base.statusOut to tableStatus;

    perform action InterpretCaregiverInput;
    perform action SupportPatientForExamination;
    exhibit state ExaminationTableOperatingState;
  }

  requirement def PrimaryFunctionRequirement {
    doc
      /* The examination table shall support a patient and provide controlled positioning of table height and backrest angle for clinical examination. */

    subject table : ExaminationTable;

    require constraint {
      table.maximumPatientMass >= 250.0 and
      table.minimumHeight <= 0.50 and
      table.maximumHeight >= 0.90
    }
  }

  requirement def PatientSupportRequirement {
    doc
      /* The patient support deck shall safely support the rated patient mass without loss of stability or structural integrity. */

    subject deck : PatientSupportDeck;

    require constraint {
      deck.safeWorkingLoad >= 250.0 and
      deck.deckLength >= 1.85 and
      deck.deckWidth >= 0.65
    }
  }

  requirement def HeightAdjustmentRequirement {
    doc
      /* The examination table shall provide powered vertical adjustment over the clinical working range. */

    subject lift : HeightLiftAssembly;

    require constraint {
      lift.minHeight <= 0.50 and
      lift.maxHeight >= 0.90 and
      lift.verticalTravel >= 0.40
    }
  }

  requirement def BackrestPositioningRequirement {
    doc
      /* The examination table shall adjust the backrest from flat to an upright seated examination posture. */

    subject backrest : BackrestActuationAssembly;

    require constraint {
      backrest.minAngle <= 0.0 and
      backrest.maxAngle >= 65.0
    }
  }

  requirement def SafetyStopRequirement {
    doc
      /* The examination table shall stop powered motion when emergency stop, obstruction, or overload conditions are detected. */

    subject safety : SafetySubsystem;

    require constraint {
      safety.overloadThreshold <= 275.0 and
      safety.obstructionForceThreshold <= 150.0
    }
  }

  requirement def PowerRequirement {
    doc
      /* The examination table shall operate from mains power and provide short-duration battery backup for patient egress. */

    subject power : PowerSubsystem;

    require constraint {
      power.inputVoltage == 120.0 and
      power.outputVoltage == 24.0 and
      power.backupRuntime >= 300.0
    }
  }

  requirement def MobilityStabilityRequirement {
    doc
      /* The examination table shall be movable for room cleaning and repositioning while providing lockable stability during examination. */

    subject base : TableBase;

    require constraint {
      base.footprintLength <= 1.70 and
      base.footprintWidth <= 0.80 and
      base.casterDiameter >= 0.10
    }
  }

  satisfy PrimaryFunctionRequirement by ExaminationTable;
  satisfy PatientSupportRequirement by ExaminationTable::deck;
  satisfy HeightAdjustmentRequirement by ExaminationTable::lift;
  satisfy BackrestPositioningRequirement by ExaminationTable::backrestActuator;
  satisfy SafetyStopRequirement by ExaminationTable::safety;
  satisfy PowerRequirement by ExaminationTable::power;
  satisfy MobilityStabilityRequirement by ExaminationTable::base;
}