package MichelangeloHandHighLevelModel {

  private import ScalarValues::*;
  private import SI::*;

  attribute def Voltage_V :> Real {
    doc /* Electric potential in volts. */
  }

  attribute def Current_A :> Real {
    doc /* Electric current in amperes. */
  }

  attribute def Power_W :> Real {
    doc /* Electric power in watts. */
  }

  attribute def Force_N :> Real {
    doc /* Mechanical force in newtons. */
  }

  attribute def Torque_Nm :> Real {
    doc /* Mechanical torque in newton meters. */
  }

  attribute def Angle_deg :> Real {
    doc /* Angular position in degrees. */
  }

  attribute def Time_ms :> Real {
    doc /* Time in milliseconds. */
  }

  attribute def Impedance_Ohm :> Real {
    doc /* Electrical impedance in ohms. */
  }

  attribute def SignalMagnitude_mV :> Real {
    doc /* Myoelectric signal magnitude in millivolts. */
  }

  enum def GripMode {
    enum openPalm;
    enum lateralPinch;
    enum palmarPinch;
    enum tripodGrip;
    enum powerGrip;
    enum relaxed;
  }

  enum def HandHealthState {
    enum nominal;
    enum degraded;
    enum inhibited;
    enum faulted;
  }

  enum def IntentClass {
    enum open;
    enum close;
    enum hold;
    enum changeGrip;
    enum relax;
  }

  item def ElectricalEnergy {
    attribute voltage : Voltage_V;
    attribute current : Current_A;
    attribute availablePower : Power_W;
  }

  item def MyoelectricSignal {
    attribute flexorMagnitude : SignalMagnitude_mV;
    attribute extensorMagnitude : SignalMagnitude_mV;
    attribute skinElectrodeImpedance : Impedance_Ohm;
    attribute sampleAge : Time_ms;
  }

  item def UserIntent {
    attribute classification : IntentClass;
    attribute requestedGrip : GripMode;
    attribute confidence : Real;
  }

  item def MotorCommand {
    attribute targetAngle : Angle_deg;
    attribute targetTorque : Torque_Nm;
    attribute closingSpeed : Real;
  }

  item def JointFeedback {
    attribute measuredAngle : Angle_deg;
    attribute measuredTorque : Torque_Nm;
    attribute stallDetected : Boolean;
  }

  item def ContactFeedback {
    attribute thumbContactForce : Force_N;
    attribute indexContactForce : Force_N;
    attribute middleContactForce : Force_N;
    attribute objectStable : Boolean;
  }

  item def GripStatus {
    attribute activeGrip : GripMode;
    attribute graspForce : Force_N;
    attribute objectHeld : Boolean;
    attribute health : HandHealthState;
  }

  port def PowerInputPort {
    in item powerIn : ElectricalEnergy;
  }

  port def MyoInputPort {
    in item emg : MyoelectricSignal;
  }

  port def IntentPort {
    out item intent : UserIntent;
  }

  port def MotorCommandPort {
    out item command : MotorCommand;
  }

  port def MotorFeedbackPort {
    in item feedback : JointFeedback;
  }

  port def ContactSensorPort {
    out item contact : ContactFeedback;
  }

  port def GripStatusPort {
    out item status : GripStatus;
  }

  port def MechanicalInterfacePort {
    in item userResidualLimbMotion : UserIntent;
    out item graspOutcome : GripStatus;
  }

  part def BatteryPack {
    attribute nominalVoltage : Voltage_V = 7.4;
    attribute maximumContinuousPower : Power_W = 45.0;
    attribute minimumOperatingVoltage : Voltage_V = 6.2;

    port powerOutput : PowerInputPort;
  }

  part def ElectrodeSet {
    attribute electrodeCount : Integer = 2;
    attribute minimumSignalMagnitude : SignalMagnitude_mV = 0.05;
    attribute maximumAcceptableImpedance : Impedance_Ohm = 100000.0;

    port rawMyoOutput : MyoInputPort;
  }

  part def IntentProcessor {
    attribute decisionLatency : Time_ms = 35.0;
    attribute minimumIntentConfidence : Real = 0.78;

    port myoInput : MyoInputPort;
    port interpretedIntent : IntentPort;
  }

  part def GripController {
    attribute controlCycleTime : Time_ms = 10.0;
    attribute maximumCommandedGripForce : Force_N = 90.0;
    attribute defaultGrip : GripMode = GripMode::relaxed;

    port intentInput : IntentPort;
    port thumbCommand : MotorCommandPort;
    port indexCommand : MotorCommandPort;
    port middleCommand : MotorCommandPort;
    port thumbFeedback : MotorFeedbackPort;
    port indexFeedback : MotorFeedbackPort;
    port middleFeedback : MotorFeedbackPort;
    port contactFeedback : ContactSensorPort;
    port gripStatus : GripStatusPort;
  }

  part def ThumbActuator {
    attribute oppositionRange : Angle_deg = 105.0;
    attribute maximumTorque : Torque_Nm = 1.8;
    attribute maximumTipForce : Force_N = 45.0;

    port commandInput : MotorCommandPort;
    port feedbackOutput : MotorFeedbackPort;
  }

  part def IndexFingerActuator {
    attribute flexionRange : Angle_deg = 95.0;
    attribute maximumTorque : Torque_Nm = 1.3;
    attribute maximumTipForce : Force_N = 32.0;

    port commandInput : MotorCommandPort;
    port feedbackOutput : MotorFeedbackPort;
  }

  part def MiddleFingerActuator {
    attribute flexionRange : Angle_deg = 95.0;
    attribute maximumTorque : Torque_Nm = 1.3;
    attribute maximumTipForce : Force_N = 32.0;

    port commandInput : MotorCommandPort;
    port feedbackOutput : MotorFeedbackPort;
  }

  part def PassiveRingAndLittleFingerPair {
    attribute compliantClosureRange : Angle_deg = 80.0;
    attribute passiveReturnForce : Force_N = 4.0;
  }

  part def ContactSensorArray {
    attribute sensorCount : Integer = 6;
    attribute minimumDetectableForce : Force_N = 0.2;
    attribute maximumMeasuredForce : Force_N = 100.0;

    port contactOutput : ContactSensorPort;
  }

  part def WristInterface {
    attribute pronationSupinationFreedom : Angle_deg = 180.0;
    attribute maximumSocketLoad : Force_N = 250.0;

    port limbInterface : MechanicalInterfacePort;
  }

  action def InterpretMyoelectricIntent {
    in item emg : MyoelectricSignal;
    out item intent : UserIntent;

    first start;
    then validateSignal;
    then classifyPattern;
    then publishIntent;
  }

  action def SelectGripPattern {
    in item intent : UserIntent;
    in item currentStatus : GripStatus;
    out item thumbCommand : MotorCommand;
    out item indexCommand : MotorCommand;
    out item middleCommand : MotorCommand;

    first evaluateIntent;
    then chooseGripMode;
    then computeJointTargets;
    then limitForceAndSpeed;
    then issueMotorCommands;
  }

  action def StabilizeObject {
    in item contact : ContactFeedback;
    in item feedback : JointFeedback;
    out item status : GripStatus;

    first detectContact;
    then reduceClosingSpeed;
    then balanceFingerForces;
    then maintainHoldForce;
    then reportGripStatus;
  }

  action def OpenHand {
    out item thumbCommand : MotorCommand;
    out item indexCommand : MotorCommand;
    out item middleCommand : MotorCommand;

    first setThumbOpen;
    then setIndexOpen;
    then setMiddleOpen;
    then verifyOpenPosture;
  }

  action def FaultResponse {
    in item status : GripStatus;
    out item inhibitedStatus : GripStatus;

    first removeMotorDrive;
    then enterRelaxedGrip;
    then publishInhibitedState;
  }

  state def MichelangeloHandBehavior {
    entry action initializeElectronics;
    exit action storeLastGripMode;

    state poweredOff;
    state selfTest;
    state ready;
    state interpretingIntent;
    state opening;
    state closing;
    state holding;
    state changingGrip;
    state inhibited;
    state faulted;

    transition first poweredOff
      then selfTest
      accept powerApplied;

    transition selfTest
      then ready
      accept selfTestPassed;

    transition selfTest
      then faulted
      accept selfTestFailed;

    transition ready
      then interpretingIntent
      accept validMyoelectricSignal;

    transition interpretingIntent
      then opening
      accept openIntent;

    transition interpretingIntent
      then closing
      accept closeIntent;

    transition interpretingIntent
      then changingGrip
      accept changeGripIntent;

    transition opening
      then ready
      accept openPostureReached;

    transition closing
      then holding
      accept stableObjectContact;

    transition closing
      then ready
      accept noObjectDetected;

    transition holding
      then opening
      accept releaseIntent;

    transition changingGrip
      then ready
      accept gripModeSelected;

    transition ready
      then inhibited
      accept lowBatteryOrUnsafeSignal;

    transition holding
      then inhibited
      accept excessiveForceDetected;

    transition inhibited
      then ready
      accept safeConditionRestored;

    transition ready
      then faulted
      accept unrecoverableFault;

    transition faulted
      then poweredOff
      accept powerRemoved;
  }

  part def MichelangeloHandSystem {
    doc /*
      A Michelangelo Hand system is a myoelectric prosthetic hand whose primary high-level function is to transform residual forearm muscle activity into coordinated thumb and finger motion so the wearer can open the hand, select common grip patterns, grasp objects, hold them with controlled force, and release them on command.
    */

    attribute systemMass : Real = 0.520;
    attribute maximumGripForce : Force_N = 90.0;
    attribute nominalSupplyVoltage : Voltage_V = 7.4;
    attribute primaryFunction : String =
      "Convert user myoelectric intent into coordinated multi-finger grasp, hold, and release functions for daily object manipulation.";

    port powerInput : PowerInputPort;
    port myoInput : MyoInputPort;
    port externalGripStatus : GripStatusPort;
    port userMechanicalInterface : MechanicalInterfacePort;

    part battery : BatteryPack;
    part electrodes : ElectrodeSet;
    part intentProcessor : IntentProcessor;
    part gripController : GripController;
    part thumb : ThumbActuator;
    part indexFinger : IndexFingerActuator;
    part middleFinger : MiddleFingerActuator;
    part passiveFingers : PassiveRingAndLittleFingerPair;
    part sensors : ContactSensorArray;
    part wrist : WristInterface;

    perform action interpretIntent : InterpretMyoelectricIntent;
    perform action selectGrip : SelectGripPattern;
    perform action stabilizeGrip : StabilizeObject;
    perform action openHand : OpenHand;
    perform action faultResponse : FaultResponse;

    exhibit state behavior : MichelangeloHandBehavior;

    connect battery.powerOutput to powerInput;
    connect electrodes.rawMyoOutput to myoInput;
    connect myoInput to intentProcessor.myoInput;
    connect intentProcessor.interpretedIntent to gripController.intentInput;
    connect gripController.thumbCommand to thumb.commandInput;
    connect gripController.indexCommand to indexFinger.commandInput;
    connect gripController.middleCommand to middleFinger.commandInput;
    connect thumb.feedbackOutput to gripController.thumbFeedback;
    connect indexFinger.feedbackOutput to gripController.indexFeedback;
    connect middleFinger.feedbackOutput to gripController.middleFeedback;
    connect sensors.contactOutput to gripController.contactFeedback;
    connect gripController.gripStatus to externalGripStatus;
    connect wrist.limbInterface to userMechanicalInterface;
  }

  requirement def PrimaryFunctionRequirement {
    doc /*
      The hand shall provide coordinated powered grasping as its primary function by interpreting user myoelectric signals and commanding the thumb, index finger, and middle finger to form stable daily-use grip patterns.
    */

    subject hand : MichelangeloHandSystem;

    require constraint {
      hand.maximumGripForce >= 60.0 and
      hand.nominalSupplyVoltage >= 6.2
    }
  }

  requirement def IntentInterpretationRequirement {
    doc /*
      The system shall classify an open, close, hold, change-grip, or relax intent from valid myoelectric input quickly enough to feel responsive to the wearer.
    */

    subject processor : IntentProcessor;

    require constraint {
      processor.decisionLatency <= 50.0 and
      processor.minimumIntentConfidence >= 0.70
    }
  }

  requirement def GripForceRequirement {
    doc /*
      The hand shall limit commanded grasp force to prevent excessive object compression while still supporting firm daily-object handling.
    */

    subject controller : GripController;

    require constraint {
      controller.maximumCommandedGripForce <= 90.0
    }
  }

  requirement def ContactFeedbackRequirement {
    doc /*
      The system shall use contact feedback to detect object engagement and transition from closing to controlled holding.
    */

    subject sensors : ContactSensorArray;

    require constraint {
      sensors.minimumDetectableForce <= 0.5 and
      sensors.maximumMeasuredForce >= 80.0
    }
  }

  requirement def ThumbOppositionRequirement {
    doc /*
      The thumb actuator shall provide sufficient opposition range to support lateral pinch, palmar pinch, tripod grip, and power grip.
    */

    subject thumb : ThumbActuator;

    require constraint {
      thumb.oppositionRange >= 90.0 and
      thumb.maximumTipForce >= 35.0
    }
  }

  requirement def PowerAvailabilityRequirement {
    doc /*
      The battery pack shall provide sufficient electrical power for simultaneous controller operation and powered finger actuation.
    */

    subject battery : BatteryPack;

    require constraint {
      battery.nominalVoltage >= 7.0 and
      battery.maximumContinuousPower >= 35.0
    }
  }

  requirement def SafeFaultResponseRequirement {
    doc /*
      Upon unsafe signal quality, excessive force, low voltage, or internal fault detection, the hand shall inhibit active closing and report an inhibited or faulted state.
    */

    subject hand : MichelangeloHandSystem;

    require constraint {
      hand.maximumGripForce <= 90.0
    }
  }

  satisfy PrimaryFunctionRequirement by MichelangeloHandSystem;
  satisfy IntentInterpretationRequirement by MichelangeloHandSystem::intentProcessor;
  satisfy GripForceRequirement by MichelangeloHandSystem::gripController;
  satisfy ContactFeedbackRequirement by MichelangeloHandSystem::sensors;
  satisfy ThumbOppositionRequirement by MichelangeloHandSystem::thumb;
  satisfy PowerAvailabilityRequirement by MichelangeloHandSystem::battery;
  satisfy SafeFaultResponseRequirement by MichelangeloHandSystem;

}