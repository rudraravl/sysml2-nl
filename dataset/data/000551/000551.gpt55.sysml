package BirthingChairSystem {

  import ScalarValues::*;

  enum def ChairMode {
    enum idle;
    enum entryExit;
    enum laborSupport;
    enum deliverySupport;
    enum emergencyFlat;
    enum cleaning;
    enum faultSafe;
  }

  enum def BackrestPosture {
    enum upright;
    enum reclined;
    enum deliveryIncline;
    enum flat;
  }

  enum def LegSupportPosture {
    enum stowed;
    enum footRest;
    enum lithotomy;
    enum lowered;
  }

  enum def BrakeState {
    enum locked;
    enum released;
  }

  enum def SurfaceCondition {
    enum clean;
    enum occupied;
    enum contaminated;
    enum disinfecting;
  }

  enum def PowerState {
    enum unpowered;
    enum battery;
    enum mains;
    enum lowBattery;
  }

  attribute def Mass_kg {
    attribute value : Real;
    attribute unit : String = "kg";
  }

  attribute def Force_N {
    attribute value : Real;
    attribute unit : String = "N";
  }

  attribute def Length_mm {
    attribute value : Real;
    attribute unit : String = "mm";
  }

  attribute def Angle_deg {
    attribute value : Real;
    attribute unit : String = "deg";
  }

  attribute def Time_s {
    attribute value : Real;
    attribute unit : String = "s";
  }

  attribute def Voltage_V {
    attribute value : Real;
    attribute unit : String = "V";
  }

  attribute def Current_A {
    attribute value : Real;
    attribute unit : String = "A";
  }

  attribute def Power_W {
    attribute value : Real;
    attribute unit : String = "W";
  }

  attribute def Temperature_C {
    attribute value : Real;
    attribute unit : String = "degC";
  }

  attribute def Percent {
    attribute value : Real;
    attribute unit : String = "%";
  }

  attribute def Pressure_kPa {
    attribute value : Real;
    attribute unit : String = "kPa";
  }

  attribute def StatusText {
    attribute value : String;
  }

  item def PatientBodyLoad {
    attribute patientMass : Mass_kg;
    attribute verticalForce : Force_N;
    attribute lateralForce : Force_N;
    attribute centerOfMassOffsetFromSeatCenter : Length_mm;
  }

  item def SupportReaction {
    attribute upwardForce : Force_N;
    attribute stabilizingMomentEstimate : Force_N;
    attribute contactPressure : Pressure_kPa;
  }

  item def PositionCommand {
    attribute requestedMode : ChairMode;
    attribute targetBackrestAngle : Angle_deg;
    attribute targetSeatTiltAngle : Angle_deg;
    attribute targetLegSupportAngle : Angle_deg;
    attribute requestedHeight : Length_mm;
    attribute commandTimeout : Time_s;
  }

  item def CaregiverCommand {
    attribute commandId : String;
    attribute requestedMode : ChairMode;
    attribute emergencyOverride : Boolean;
  }

  item def PatientComfortInput {
    attribute painReliefPositionRequested : Boolean;
    attribute preferredBackrestAngle : Angle_deg;
    attribute preferredLegSupportAngle : Angle_deg;
    attribute requestHandGrip : Boolean;
  }

  item def ChairStatus {
    attribute currentMode : ChairMode;
    attribute backrestPosture : BackrestPosture;
    attribute legSupportPosture : LegSupportPosture;
    attribute brakeState : BrakeState;
    attribute powerState : PowerState;
    attribute surfaceCondition : SurfaceCondition;
    attribute batteryCharge : Percent;
    attribute message : StatusText;
  }

  item def ElectricalPower {
    attribute voltage : Voltage_V;
    attribute currentLimit : Current_A;
    attribute availablePower : Power_W;
  }

  item def ControlSignal {
    attribute enabled : Boolean;
    attribute targetPosition : Angle_deg;
    attribute targetExtension : Length_mm;
    attribute safeStop : Boolean;
  }

  item def SterileBarrier {
    attribute intact : Boolean;
    attribute coveragePercent : Percent;
  }

  item def FluidWaste {
    attribute estimatedVolume_ml : Real;
    attribute infectiousRisk : Boolean;
  }

  item def CleaningAgent {
    attribute name : String;
    attribute concentrationPercent : Percent;
    attribute contactTime : Time_s;
  }

  item def AlarmNotification {
    attribute active : Boolean;
    attribute priority : Integer;
    attribute message : String;
  }

  port def PatientSupportPort {
    in item load : PatientBodyLoad;
    out item reaction : SupportReaction;
  }

  port def CaregiverControlPort {
    in item command : CaregiverCommand;
    out item status : ChairStatus;
    out item alarm : AlarmNotification;
  }

  port def PatientInputPort {
    in item comfortRequest : PatientComfortInput;
    out item status : ChairStatus;
  }

  port def PowerPort {
    in item powerIn : ElectricalPower;
    out item powerStatus : ChairStatus;
  }

  port def ActuatorControlPort {
    in item control : ControlSignal;
    out item status : ChairStatus;
  }

  port def CleaningPort {
    in item cleaningAgent : CleaningAgent;
    out item waste : FluidWaste;
    out item surfaceStatus : ChairStatus;
  }

  port def SterilityPort {
    in item barrier : SterileBarrier;
    out item surfaceStatus : ChairStatus;
  }

  interface def BodySupportInterface {
    end patientEnd : PatientSupportPort;
    end chairEnd : PatientSupportPort;
  }

  interface def CaregiverOperationInterface {
    end caregiverEnd : CaregiverControlPort;
    end chairEnd : CaregiverControlPort;
  }

  interface def PatientComfortInterface {
    end patientEnd : PatientInputPort;
    end chairEnd : PatientInputPort;
  }

  interface def ElectricalSupplyInterface {
    end supplyEnd : PowerPort;
    end chairEnd : PowerPort;
  }

  interface def InternalActuatorInterface {
    end controllerEnd : ActuatorControlPort;
    end actuatorEnd : ActuatorControlPort;
  }

  interface def InfectionControlInterface {
    end staffEnd : CleaningPort;
    end chairEnd : CleaningPort;
  }

  part def LaboringPatient {
    attribute mass : Mass_kg = (value = 95.0);
    attribute hipWidth : Length_mm = (value = 430.0);
    attribute seatedHeight : Length_mm = (value = 910.0);
    attribute requiresAssistedPositioning : Boolean = true;

    port bodySupport : PatientSupportPort;
    port comfortInput : PatientInputPort;
  }

  part def Caregiver {
    attribute clinicalRole : String = "midwife or obstetric clinician";
    attribute authorizedForEmergencyOverride : Boolean = true;

    port control : CaregiverControlPort;
    port cleaning : CleaningPort;
  }

  part def MainsPowerSupply {
    attribute nominalVoltage : Voltage_V = (value = 120.0);
    attribute maximumCurrent : Current_A = (value = 5.0);
    attribute availablePower : Power_W = (value = 600.0);

    port electricalOutput : PowerPort;
  }

  part def BaseFrame {
    attribute footprintLength : Length_mm = (value = 1280.0);
    attribute footprintWidth : Length_mm = (value = 780.0);
    attribute frameMass : Mass_kg = (value = 42.0);
    attribute ratedStaticLoad : Mass_kg = (value = 250.0);
    attribute corrosionResistant : Boolean = true;

    part leftCaster {
      attribute diameter : Length_mm = (value = 125.0);
      attribute brake : BrakeState = BrakeState::locked;
    }

    part rightCaster {
      attribute diameter : Length_mm = (value = 125.0);
      attribute brake : BrakeState = BrakeState::locked;
    }

    part frontCasterPair {
      attribute diameter : Length_mm = (value = 125.0);
      attribute brake : BrakeState = BrakeState::locked;
    }

    port supportPort : PatientSupportPort;
  }

  part def SeatPan {
    attribute seatWidth : Length_mm = (value = 610.0);
    attribute seatDepth : Length_mm = (value = 520.0);
    attribute seatHeightMinimum : Length_mm = (value = 520.0);
    attribute seatHeightMaximum : Length_mm = (value = 860.0);
    attribute currentSeatHeight : Length_mm = (value = 650.0);
    attribute seatTiltAngle : Angle_deg = (value = 0.0);
    attribute cushionPressureLimit : Pressure_kPa = (value = 32.0);
    attribute surfaceCondition : SurfaceCondition = SurfaceCondition::clean;

    port patientPort : PatientSupportPort;
    port framePort : PatientSupportPort;
    port sterilityPort : SterilityPort;
  }

  part def BackrestAssembly {
    attribute width : Length_mm = (value = 610.0);
    attribute length : Length_mm = (value = 760.0);
    attribute minimumAngleFromHorizontal : Angle_deg = (value = 0.0);
    attribute maximumAngleFromHorizontal : Angle_deg = (value = 82.0);
    attribute currentAngleFromHorizontal : Angle_deg = (value = 65.0);
    attribute posture : BackrestPosture = BackrestPosture::upright;

    port patientPort : PatientSupportPort;
    port actuatorPort : ActuatorControlPort;
  }

  part def LegSupportAssembly {
    attribute leftSupportAngle : Angle_deg = (value = 25.0);
    attribute rightSupportAngle : Angle_deg = (value = 25.0);
    attribute maximumAbductionAngle : Angle_deg = (value = 55.0);
    attribute maximumPatientLegLoadEach : Mass_kg = (value = 35.0);
    attribute posture : LegSupportPosture = LegSupportPosture::stowed;

    part leftLegRest {
      attribute paddedLength : Length_mm = (value = 410.0);
      attribute paddedWidth : Length_mm = (value = 180.0);
    }

    part rightLegRest {
      attribute paddedLength : Length_mm = (value = 410.0);
      attribute paddedWidth : Length_mm = (value = 180.0);
    }

    port patientPort : PatientSupportPort;
    port actuatorPort : ActuatorControlPort;
  }

  part def ArmAndGripAssembly {
    attribute leftGripHeight : Length_mm = (value = 780.0);
    attribute rightGripHeight : Length_mm = (value = 780.0);
    attribute gripLoadRating : Force_N = (value = 650.0);
    attribute removable : Boolean = true;

    part leftGrip {
      attribute textured : Boolean = true;
    }

    part rightGrip {
      attribute textured : Boolean = true;
    }

    port patientPort : PatientSupportPort;
  }

  part def FootStepAssembly {
    attribute deployedHeight : Length_mm = (value = 260.0);
    attribute stepWidth : Length_mm = (value = 520.0);
    attribute slipResistant : Boolean = true;
    attribute maximumStepLoad : Mass_kg = (value = 180.0);

    port patientPort : PatientSupportPort;
  }

  part def PelvicAccessSection {
    attribute perinealCutoutWidth : Length_mm = (value = 310.0);
    attribute perinealCutoutDepth : Length_mm = (value = 260.0);
    attribute removableSeatInsertInstalled : Boolean = true;
    attribute clinicianAccessClearance : Length_mm = (value = 520.0);

    port patientPort : PatientSupportPort;
    port cleaningPort : CleaningPort;
  }

  part def FluidCollectionTray {
    attribute trayCapacity_ml : Real = 2500.0;
    attribute removable : Boolean = true;
    attribute currentVolume_ml : Real = 0.0;
    attribute leakResistant : Boolean = true;

    port cleaningPort : CleaningPort;
  }

  part def LiftActuator {
    attribute stroke : Length_mm = (value = 340.0);
    attribute maximumLiftForce : Force_N = (value = 3200.0);
    attribute currentExtension : Length_mm = (value = 130.0);
    attribute motionRate : Length_mm = (value = 18.0);

    port controlPort : ActuatorControlPort;
  }

  part def BackrestActuator {
    attribute maximumPushForce : Force_N = (value = 1800.0);
    attribute currentAngleCommand : Angle_deg = (value = 65.0);
    attribute angularRateLimit : Angle_deg = (value = 5.0);

    port controlPort : ActuatorControlPort;
  }

  part def LegSupportActuator {
    attribute maximumPushForce : Force_N = (value = 900.0);
    attribute currentAngleCommand : Angle_deg = (value = 25.0);
    attribute angularRateLimit : Angle_deg = (value = 6.0);

    port controlPort : ActuatorControlPort;
  }

  part def BrakeSystem {
    attribute brakeState : BrakeState = BrakeState::locked;
    attribute releasePedalForce : Force_N = (value = 120.0);
    attribute automaticLockOnPowerLoss : Boolean = true;

    port statusPort : CaregiverControlPort;
  }

  part def BatteryPack {
    attribute nominalVoltage : Voltage_V = (value = 24.0);
    attribute capacity_Ah : Real = 12.0;
    attribute chargeLevel : Percent = (value = 92.0);
    attribute minimumSafeCharge : Percent = (value = 20.0);

    port powerPort : PowerPort;
  }

  part def PowerController {
    attribute inputVoltage : Voltage_V = (value = 24.0);
    attribute maximumOutputPower : Power_W = (value = 420.0);
    attribute powerState : PowerState = PowerState::mains;

    port mainsInput : PowerPort;
    port batteryInput : PowerPort;
    port actuatorPowerOutput : PowerPort;
  }

  part def PositionController {
    attribute currentMode : ChairMode = ChairMode::idle;
    attribute safeMotionEnabled : Boolean = true;
    attribute patientPresent : Boolean = false;
    attribute lastCommandAge : Time_s = (value = 0.0);

    port caregiverPort : CaregiverControlPort;
    port patientPort : PatientInputPort;
    port liftActuatorPort : ActuatorControlPort;
    port backrestActuatorPort : ActuatorControlPort;
    port legSupportActuatorPort : ActuatorControlPort;
    port brakeStatusPort : CaregiverControlPort;
  }

  part def SafetyMonitor {
    attribute maximumAllowedPatientMass : Mass_kg = (value = 180.0);
    attribute maximumAllowedBackrestAngle : Angle_deg = (value = 82.0);
    attribute minimumAllowedBackrestAngle : Angle_deg = (value = 0.0);
    attribute entrapmentDetected : Boolean = false;
    attribute overloadDetected : Boolean = false;
    attribute emergencyStopActive : Boolean = false;

    port caregiverPort : CaregiverControlPort;
    port patientLoadPort : PatientSupportPort;
    port actuatorPort : ActuatorControlPort;
  }

  part def InfectionControlSet {
    attribute removableCoversAvailable : Boolean = true;
    attribute disinfectantCompatible : Boolean = true;
    attribute targetSurfaceCoverage : Percent = (value = 100.0);
    attribute surfaceCondition : SurfaceCondition = SurfaceCondition::clean;

    part sterileDrape {
      attribute coverage : Percent = (value = 100.0);
      attribute singleUse : Boolean = true;
    }

    part wipeableMattressCover {
      attribute sealedSeams : Boolean = true;
      attribute fluidResistant : Boolean = true;
    }

    port cleaningPort : CleaningPort;
    port sterilityPort : SterilityPort;
  }

  action def ReceiveCaregiverCommand {
    in item command : CaregiverCommand;
    out item positionCommand : PositionCommand;
    out item accepted : Boolean;

    first start;
    then validateAuthorization;
    then mapModeToPosture;
    then issuePositionCommand;
    then done;

    action validateAuthorization {
      in item command : CaregiverCommand;
      out item accepted : Boolean;
    }

    action mapModeToPosture {
      in item command : CaregiverCommand;
      out item positionCommand : PositionCommand;
    }

    action issuePositionCommand {
      in item positionCommand : PositionCommand;
    }
  }

  action def PositionForLaborAndBirth {
    in item command : PositionCommand;
    in item patientLoad : PatientBodyLoad;
    out item chairStatus : ChairStatus;
    out item supportReaction : SupportReaction;

    first start;
    then lockBase;
    then verifyPatientLoad;
    then adjustSeatHeight;
    then adjustBackrest;
    then deployLegSupports;
    then exposePelvicAccess;
    then reportReady;
    then done;

    action lockBase {
      out item brakeState : ChairStatus;
    }

    action verifyPatientLoad {
      in item patientLoad : PatientBodyLoad;
      out item loadAccepted : Boolean;
    }

    action adjustSeatHeight {
      in item command : PositionCommand;
      out item status : ChairStatus;
    }

    action adjustBackrest {
      in item command : PositionCommand;
      out item status : ChairStatus;
    }

    action deployLegSupports {
      in item command : PositionCommand;
      out item status : ChairStatus;
    }

    action exposePelvicAccess {
      out item accessStatus : ChairStatus;
    }

    action reportReady {
      out item chairStatus : ChairStatus;
      out item supportReaction : SupportReaction;
    }
  }

  action def ProvidePrimaryBirthingSupport {
    in item patientLoad : PatientBodyLoad;
    in item caregiverCommand : CaregiverCommand;
    in item patientComfort : PatientComfortInput;
    out item chairStatus : ChairStatus;
    out item alarm : AlarmNotification;

    first start;
    then receiveCommand : ReceiveCaregiverCommand;
    then configureChair : PositionForLaborAndBirth;
    then maintainStableSupport;
    then enableClinicianAccess;
    then monitorSafety;
    then done;

    action maintainStableSupport {
      in item patientLoad : PatientBodyLoad;
      out item supportReaction : SupportReaction;
    }

    action enableClinicianAccess {
      out item chairStatus : ChairStatus;
    }

    action monitorSafety {
      in item patientLoad : PatientBodyLoad;
      out item alarm : AlarmNotification;
    }
  }

  action def CleanAndPrepareForNextUse {
    in item cleaningAgent : CleaningAgent;
    in item barrier : SterileBarrier;
    out item waste : FluidWaste;
    out item status : ChairStatus;

    first start;
    then removeFluidTray;
    then discardSingleUseBarriers;
    then applyDisinfectant;
    then verifyContactTime;
    then installCleanBarrier;
    then readyForUse;
    then done;

    action removeFluidTray {
      out item waste : FluidWaste;
    }

    action discardSingleUseBarriers {
      out item status : ChairStatus;
    }

    action applyDisinfectant {
      in item cleaningAgent : CleaningAgent;
    }

    action verifyContactTime {
      in item cleaningAgent : CleaningAgent;
      out item status : ChairStatus;
    }

    action installCleanBarrier {
      in item barrier : SterileBarrier;
      out item status : ChairStatus;
    }

    action readyForUse {
      out item status : ChairStatus;
    }
  }

  state def BirthingChairOperationalStateMachine {
    state initial;
    state Idle;
    state EntryExit;
    state LaborSupport;
    state DeliverySupport;
    state EmergencyFlat;
    state Cleaning;
    state FaultSafe;

    transition initial_to_idle
      first initial
      then Idle;

    transition idle_to_entryExit
      first Idle
      accept CaregiverCommand
      if command.requestedMode == ChairMode::entryExit
      then EntryExit;

    transition entryExit_to_laborSupport
      first EntryExit
      accept CaregiverCommand
      if command.requestedMode == ChairMode::laborSupport
      then LaborSupport;

    transition laborSupport_to_deliverySupport
      first LaborSupport
      accept CaregiverCommand
      if command.requestedMode == ChairMode::deliverySupport
      then DeliverySupport;

    transition deliverySupport_to_laborSupport
      first DeliverySupport
      accept CaregiverCommand
      if command.requestedMode == ChairMode::laborSupport
      then LaborSupport;

    transition any_to_emergencyFlat_from_labor
      first LaborSupport
      accept CaregiverCommand
      if command.emergencyOverride == true
      then EmergencyFlat;

    transition any_to_emergencyFlat_from_delivery
      first DeliverySupport
      accept CaregiverCommand
      if command.emergencyOverride == true
      then EmergencyFlat;

    transition emergencyFlat_to_faultSafe
      first EmergencyFlat
      accept AlarmNotification
      if alarm.active == true
      then FaultSafe;

    transition idle_to_cleaning
      first Idle
      accept CaregiverCommand
      if command.requestedMode == ChairMode::cleaning
      then Cleaning;

    transition cleaning_to_idle
      first Cleaning
      accept ChairStatus
      if status.surfaceCondition == SurfaceCondition::clean
      then Idle;

    transition faultSafe_to_idle
      first FaultSafe
      accept CaregiverCommand
      if command.emergencyOverride == false
      then Idle;
  }

  part def BirthingChair {
    attribute productName : String = "Adjustable Birthing Chair";
    attribute primaryFunction : String = "Support and position a laboring patient so that childbirth can occur safely, comfortably, and with clear clinical access for caregivers.";
    attribute maximumPatientMass : Mass_kg = (value = 180.0);
    attribute maximumStaticLoad : Mass_kg = (value = 250.0);
    attribute minimumSeatHeight : Length_mm = (value = 520.0);
    attribute maximumSeatHeight : Length_mm = (value = 860.0);
    attribute deliveryBackrestAngle : Angle_deg = (value = 45.0);
    attribute emergencyFlatAngle : Angle_deg = (value = 0.0);
    attribute designLifeYears : Real = 10.0;
    attribute ingressProtectionRating : String = "IPX4";
    attribute currentMode : ChairMode = ChairMode::idle;

    port patientSupportPort : PatientSupportPort;
    port caregiverControlPort : CaregiverControlPort;
    port patientInputPort : PatientInputPort;
    port electricalInputPort : PowerPort;
    port cleaningPort : CleaningPort;
    port sterilityPort : SterilityPort;

    part baseFrame : BaseFrame;
    part seatPan : SeatPan;
    part backrest : BackrestAssembly;
    part legSupports : LegSupportAssembly;
    part armAndGripAssembly : ArmAndGripAssembly;
    part footStep : FootStepAssembly;
    part pelvicAccess : PelvicAccessSection;
    part fluidCollectionTray : FluidCollectionTray;
    part liftActuator : LiftActuator;
    part backrestActuator : BackrestActuator;
    part legSupportActuator : LegSupportActuator;
    part brakeSystem : BrakeSystem;
    part batteryPack : BatteryPack;
    part powerController : PowerController;
    part positionController : PositionController;
    part safetyMonitor : SafetyMonitor;
    part infectionControlSet : InfectionControlSet;

    connection patient_to_seat : BodySupportInterface connect patientSupportPort to seatPan.patientPort;
    connection patient_to_backrest : BodySupportInterface connect patientSupportPort to backrest.patientPort;
    connection patient_to_legSupports : BodySupportInterface connect patientSupportPort to legSupports.patientPort;
    connection patient_to_grips : BodySupportInterface connect patientSupportPort to armAndGripAssembly.patientPort;
    connection patient_to_step : BodySupportInterface connect patientSupportPort to footStep.patientPort;
    connection seat_to_frame : BodySupportInterface connect seatPan.framePort to baseFrame.supportPort;
    connection seat_to_pelvic_access : BodySupportInterface connect seatPan.patientPort to pelvicAccess.patientPort;
    connection caregiver_to_controller : CaregiverOperationInterface connect caregiverControlPort to positionController.caregiverPort;
    connection caregiver_to_safety : CaregiverOperationInterface connect caregiverControlPort to safetyMonitor.caregiverPort;
    connection patient_input_to_controller : PatientComfortInterface connect patientInputPort to positionController.patientPort;
    connection mains_to_power_controller : ElectricalSupplyInterface connect electricalInputPort to powerController.mainsInput;
    connection battery_to_power_controller : ElectricalSupplyInterface connect batteryPack.powerPort to powerController.batteryInput;
    connection controller_to_lift : InternalActuatorInterface connect positionController.liftActuatorPort to liftActuator.controlPort;
    connection controller_to_backrest_actuator : InternalActuatorInterface connect positionController.backrestActuatorPort to backrestActuator.controlPort;
    connection controller_to_leg_actuator : InternalActuatorInterface connect positionController.legSupportActuatorPort to legSupportActuator.controlPort;
    connection backrest_actuator_to_backrest : InternalActuatorInterface connect backrestActuator.controlPort to backrest.actuatorPort;
    connection leg_actuator_to_leg_supports : InternalActuatorInterface connect legSupportActuator.controlPort to legSupports.actuatorPort;
    connection brake_status_to_controller : CaregiverOperationInterface connect brakeSystem.statusPort to positionController.brakeStatusPort;
    connection patient_load_to_safety : BodySupportInterface connect patientSupportPort to safetyMonitor.patientLoadPort;
    connection cleaning_to_pelvic_access : InfectionControlInterface connect cleaningPort to pelvicAccess.cleaningPort;
    connection cleaning_to_fluid_tray : InfectionControlInterface connect cleaningPort to fluidCollectionTray.cleaningPort;
    connection cleaning_to_infection_control : InfectionControlInterface connect cleaningPort to infectionControlSet.cleaningPort;
    connection sterility_to_seat : InfectionControlInterface connect sterilityPort to seatPan.sterilityPort;
    connection sterility_to_infection_control : InfectionControlInterface connect sterilityPort to infectionControlSet.sterilityPort;

    perform action primarySupport : ProvidePrimaryBirthingSupport;
    perform action cleaningPreparation : CleanAndPrepareForNextUse;

    exhibit state operationalStates : BirthingChairOperationalStateMachine;
  }

  part def BirthingChairCareEnvironment {
    attribute roomType : String = "labor and delivery room";
    attribute minimumClearanceAroundChair : Length_mm = (value = 900.0);
    attribute ambientTemperature : Temperature_C = (value = 22.0);

    part chair : BirthingChair;
    part patient : LaboringPatient;
    part caregiver : Caregiver;
    part mainsSupply : MainsPowerSupply;

    connection patient_body_to_chair : BodySupportInterface connect patient.bodySupport to chair.patientSupportPort;
    connection patient_comfort_to_chair : PatientComfortInterface connect patient.comfortInput to chair.patientInputPort;
    connection caregiver_controls_chair : CaregiverOperationInterface connect caregiver.control to chair.caregiverControlPort;
    connection caregiver_cleans_chair : InfectionControlInterface connect caregiver.cleaning to chair.cleaningPort;
    connection mains_powers_chair : ElectricalSupplyInterface connect mainsSupply.electricalOutput to chair.electricalInputPort;
  }

  requirement def PrimaryFunctionRequirement {
    subject chair : BirthingChair;

    doc /* The birthing chair shall provide stable, adjustable, accessible support for a laboring patient during entry, labor, delivery, emergency repositioning, and post-use cleaning. */

    require constraint {
      chair.maximumPatientMass.value >= 180.0
    }

    require constraint {
      chair.minimumSeatHeight.value <= 550.0 and chair.maximumSeatHeight.value >= 850.0
    }

    require constraint {
      chair.deliveryBackrestAngle.value >= 30.0 and chair.deliveryBackrestAngle.value <= 60.0
    }
  }

  requirement def StabilityRequirement {
    subject chair : BirthingChair;

    doc /* The chair shall remain stable while supporting the rated patient mass in labor and delivery positions with brakes locked. */

    require constraint {
      chair.maximumStaticLoad.value >= 250.0
    }

    require constraint {
      chair.baseFrame.ratedStaticLoad.value >= chair.maximumStaticLoad.value
    }
  }

  requirement def ClinicianAccessRequirement {
    subject chair : BirthingChair;

    doc /* The chair shall provide unobstructed pelvic access for caregivers during delivery while maintaining patient support at the seat, back, legs, and grips. */

    require constraint {
      chair.pelvicAccess.perinealCutoutWidth.value >= 300.0
    }

    require constraint {
      chair.pelvicAccess.clinicianAccessClearance.value >= 500.0
    }
  }

  requirement def ComfortAndPositioningRequirement {
    subject chair : BirthingChair;

    doc /* The chair shall adjust seat height, backrest angle, and leg support posture to accommodate labor support and delivery support configurations. */

    require constraint {
      chair.backrest.maximumAngleFromHorizontal.value >= 80.0
    }

    require constraint {
      chair.backrest.minimumAngleFromHorizontal.value <= 0.0
    }

    require constraint {
      chair.legSupports.maximumAbductionAngle.value >= 50.0
    }
  }

  requirement def EmergencyRepositioningRequirement {
    subject chair : BirthingChair;

    doc /* The chair shall allow emergency transition to a near-flat position for rapid clinical intervention. */

    require constraint {
      chair.emergencyFlatAngle.value <= 5.0
    }

    require constraint {
      chair.brakeSystem.automaticLockOnPowerLoss == true
    }
  }

  requirement def InfectionControlRequirement {
    subject chair : BirthingChair;

    doc /* Patient-contact surfaces and fluid collection features shall support cleaning, disinfection, and sterile barrier use between patients. */

    require constraint {
      chair.infectionControlSet.disinfectantCompatible == true
    }

    require constraint {
      chair.fluidCollectionTray.trayCapacity_ml >= 2000.0
    }

    require constraint {
      chair.infectionControlSet.targetSurfaceCoverage.value == 100.0
    }
  }

  requirement def ElectricalSafetyRequirement {
    subject chair : BirthingChair;

    doc /* Electrically powered functions shall be supplied through controlled low-voltage actuator power and shall support battery operation when mains power is unavailable. */

    require constraint {
      chair.batteryPack.nominalVoltage.value <= 24.0
    }

    require constraint {
      chair.powerController.maximumOutputPower.value <= 500.0
    }

    require constraint {
      chair.batteryPack.minimumSafeCharge.value >= 20.0
    }
  }

  satisfy PrimaryFunctionRequirement by BirthingChair;
  satisfy StabilityRequirement by BaseFrame;
  satisfy ClinicianAccessRequirement by PelvicAccessSection;
  satisfy ComfortAndPositioningRequirement by BackrestAssembly;
  satisfy ComfortAndPositioningRequirement by LegSupportAssembly;
  satisfy EmergencyRepositioningRequirement by BrakeSystem;
  satisfy InfectionControlRequirement by InfectionControlSet;
  satisfy InfectionControlRequirement by FluidCollectionTray;
  satisfy ElectricalSafetyRequirement by PowerController;
  satisfy ElectricalSafetyRequirement by BatteryPack;

  part birthingChairSystem : BirthingChairCareEnvironment;
}
