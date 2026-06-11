package WelnerTableSystem {

  import ScalarValues::*;
  import SI::*;
  import ISQ::*;

  attribute def LengthValue :> ISQ::length {
    unit = SI::millimetre;
  }

  attribute def AreaValue :> ISQ::area {
    unit = SI::squareMetre;
  }

  attribute def MassValue :> ISQ::mass {
    unit = SI::kilogram;
  }

  attribute def ForceValue :> ISQ::force {
    unit = SI::newton;
  }

  attribute def PowerValue :> ISQ::power {
    unit = SI::watt;
  }

  attribute def VoltageValue :> ISQ::electricPotential {
    unit = SI::volt;
  }

  attribute def TimeValue :> ISQ::time {
    unit = SI::second;
  }

  enum def TableMode {
    enum idle;
    enum movingUp;
    enum movingDown;
    enum locked;
    enum fault;
  }

  enum def BrakeState {
    enum released;
    enum engaged;
  }

  item def UserCommand {
    attribute requestedHeight : LengthValue;
    attribute lockRequested : Boolean;
    attribute unlockRequested : Boolean;
  }

  item def StatusIndication {
    attribute currentHeight : LengthValue;
    attribute mode : TableMode;
    attribute brakeState : BrakeState;
    attribute overload : Boolean;
    attribute lowBattery : Boolean;
  }

  item def ElectricalPower {
    attribute voltage : VoltageValue;
    attribute availablePower : PowerValue;
  }

  item def SupportedLoad {
    attribute mass : MassValue;
    attribute distributedForce : ForceValue;
  }

  port def CommandPort {
    in command : UserCommand;
  }

  port def StatusPort {
    out status : StatusIndication;
  }

  port def PowerPort {
    in power : ElectricalPower;
  }

  port def LoadPort {
    in load : SupportedLoad;
  }

  port def LiftDrivePort {
    out targetHeight : LengthValue;
    in measuredHeight : LengthValue;
  }

  port def BrakeControlPort {
    out requestedBrakeState : BrakeState;
    in actualBrakeState : BrakeState;
  }

  part def WelnerTableSystem {
    doc /* High-level primary function: provide a mobile, stable, height-adjustable table surface that can be positioned over or beside a seated or reclined user to support eating, reading, writing, clinical tasks, and light equipment safely. */

    attribute minimumHeight : LengthValue = 650 [SI::millimetre];
    attribute maximumHeight : LengthValue = 1050 [SI::millimetre];
    attribute nominalWidth : LengthValue = 800 [SI::millimetre];
    attribute nominalDepth : LengthValue = 450 [SI::millimetre];
    attribute maximumSupportedMass : MassValue = 25 [SI::kilogram];
    attribute maximumLiftTime : TimeValue = 18 [SI::second];

    port userInterface : CommandPort;
    port tableStatus : StatusPort;
    port mainsOrBatteryPower : PowerPort;
    port tabletopLoad : LoadPort;

    part tabletop : Tabletop;
    part liftColumn : LiftColumn;
    part baseFrame : BaseFrame;
    part casterSet : CasterSet;
    part brakeSystem : BrakeSystem;
    part controller : TableController;
    part heightSensor : HeightSensor;
    part loadSensor : LoadSensor;
    part powerModule : PowerModule;

    connect userInterface to controller.commandInput;
    connect controller.statusOutput to tableStatus;
    connect mainsOrBatteryPower to powerModule.powerInput;
    connect powerModule.controlPower to controller.controllerPower;
    connect powerModule.actuatorPower to liftColumn.powerInput;
    connect controller.liftCommand to liftColumn.driveInput;
    connect liftColumn.heightFeedback to heightSensor.heightInput;
    connect heightSensor.measuredHeightOutput to controller.heightFeedback;
    connect tabletopLoad to loadSensor.loadInput;
    connect loadSensor.loadOutput to controller.loadFeedback;
    connect controller.brakeCommand to brakeSystem.controlInput;
    connect brakeSystem.brakeOutput to casterSet.brakeInput;
    connect tabletop.supportInterface to liftColumn.upperMount;
    connect liftColumn.lowerMount to baseFrame.columnMount;
    connect baseFrame.casterMounts to casterSet.frameMounts;

    perform action provideAdjustableSupport;
    exhibit state tableOperatingStates;
  }

  part def Tabletop {
    attribute width : LengthValue = 800 [SI::millimetre];
    attribute depth : LengthValue = 450 [SI::millimetre];
    attribute thickness : LengthValue = 25 [SI::millimetre];
    attribute usableArea : AreaValue = 0.34 [SI::squareMetre];
    attribute mass : MassValue = 6.5 [SI::kilogram];
    attribute edgeLipHeight : LengthValue = 8 [SI::millimetre];

    port loadInterface : LoadPort;
    port supportInterface;
  }

  part def LiftColumn {
    attribute stroke : LengthValue = 400 [SI::millimetre];
    attribute ratedLiftForce : ForceValue = 450 [SI::newton];
    attribute liftSpeed : LengthValue = 25 [SI::millimetre];
    attribute selfLockingWhenUnpowered : Boolean = true;

    port powerInput : PowerPort;
    port driveInput : LiftDrivePort;
    port heightFeedback : LiftDrivePort;
    port upperMount;
    port lowerMount;

    perform action moveToCommandedHeight;
  }

  part def BaseFrame {
    attribute width : LengthValue = 760 [SI::millimetre];
    attribute depth : LengthValue = 520 [SI::millimetre];
    attribute groundClearance : LengthValue = 35 [SI::millimetre];
    attribute mass : MassValue = 9 [SI::kilogram];

    port columnMount;
    port casterMounts;
  }

  part def CasterSet {
    attribute casterCount : Integer = 4;
    attribute wheelDiameter : LengthValue = 75 [SI::millimetre];
    attribute minimumTurningRadius : LengthValue = 600 [SI::millimetre];

    port frameMounts;
    port brakeInput : BrakeControlPort;
  }

  part def BrakeSystem {
    attribute brakeState : BrakeState = BrakeState::engaged;
    attribute holdingForcePerCaster : ForceValue = 90 [SI::newton];

    port controlInput : BrakeControlPort;
    port brakeOutput : BrakeControlPort;

    perform action engageBrakes;
    perform action releaseBrakes;
  }

  part def TableController {
    attribute currentMode : TableMode = TableMode::idle;
    attribute commandedHeight : LengthValue = 760 [SI::millimetre];
    attribute heightTolerance : LengthValue = 5 [SI::millimetre];
    attribute overloadLimit : MassValue = 25 [SI::kilogram];
    attribute lowBatteryThreshold : VoltageValue = 21 [SI::volt];

    port commandInput : CommandPort;
    port statusOutput : StatusPort;
    port controllerPower : PowerPort;
    port liftCommand : LiftDrivePort;
    port brakeCommand : BrakeControlPort;
    port heightFeedback : LiftDrivePort;
    port loadFeedback : LoadPort;

    perform action validateCommand;
    perform action publishStatus;
  }

  part def HeightSensor {
    attribute resolution : LengthValue = 1 [SI::millimetre];
    attribute measurementError : LengthValue = 3 [SI::millimetre];

    port heightInput : LiftDrivePort;
    port measuredHeightOutput : LiftDrivePort;
  }

  part def LoadSensor {
    attribute capacity : MassValue = 40 [SI::kilogram];
    attribute overloadTripMass : MassValue = 27 [SI::kilogram];

    port loadInput : LoadPort;
    port loadOutput : LoadPort;
  }

  part def PowerModule {
    attribute nominalVoltage : VoltageValue = 24 [SI::volt];
    attribute maximumActuatorPower : PowerValue = 120 [SI::watt];
    attribute standbyPower : PowerValue = 2 [SI::watt];

    port powerInput : PowerPort;
    port controllerPower : PowerPort;
    port actuatorPower : PowerPort;
  }

  action def provideAdjustableSupport {
    in command : UserCommand;
    in load : SupportedLoad;
    out status : StatusIndication;

    first start;
    then checkLoad;
    then checkBrakeRequest;
    then adjustHeightIfRequested;
    then supportLoadAtHeight;
    then reportStatus;

    action start;
    action checkLoad;
    action checkBrakeRequest;
    action adjustHeightIfRequested;
    action supportLoadAtHeight;
    action reportStatus;
  }

  action def validateCommand {
    in command : UserCommand;
    in currentHeight : LengthValue;
    in load : SupportedLoad;
    out accepted : Boolean;
  }

  action def moveToCommandedHeight {
    in targetHeight : LengthValue;
    in measuredHeight : LengthValue;
    out atTarget : Boolean;
  }

  action def engageBrakes {
    out state : BrakeState = BrakeState::engaged;
  }

  action def releaseBrakes {
    out state : BrakeState = BrakeState::released;
  }

  action def publishStatus {
    in currentHeight : LengthValue;
    in mode : TableMode;
    in brakeState : BrakeState;
    in overload : Boolean;
    out status : StatusIndication;
  }

  state def tableOperatingStates {
    entry; then idle;

    state idle;
    state locked;
    state movingUp;
    state movingDown;
    state fault;

    transition idle_to_movingUp
      first idle
      accept UserCommand
      if command.requestedHeight > status.currentHeight
      then movingUp;

    transition idle_to_movingDown
      first idle
      accept UserCommand
      if command.requestedHeight < status.currentHeight
      then movingDown;

    transition movingUp_to_idle
      first movingUp
      if status.currentHeight >= command.requestedHeight
      then idle;

    transition movingDown_to_idle
      first movingDown
      if status.currentHeight <= command.requestedHeight
      then idle;

    transition idle_to_locked
      first idle
      accept UserCommand
      if command.lockRequested
      then locked;

    transition locked_to_idle
      first locked
      accept UserCommand
      if command.unlockRequested
      then idle;

    transition any_to_fault_on_overload
      first idle
      if status.overload
      then fault;

    transition movingUp_to_fault_on_overload
      first movingUp
      if status.overload
      then fault;

    transition movingDown_to_fault_on_overload
      first movingDown
      if status.overload
      then fault;
  }

  requirement def PrimaryFunctionRequirement {
    doc /* The Welner table system shall provide a stable, mobile, height-adjustable support surface for everyday user activities performed beside or over a seated or reclined user. */
  }

  requirement def HeightAdjustmentRequirement {
    doc /* The system shall adjust tabletop height over the required operating range without manual lifting of the tabletop. */

    require constraint {
      WelnerTableSystem::minimumHeight <= WelnerTableSystem::maximumHeight
    }
  }

  requirement def LoadSupportRequirement {
    doc /* The tabletop shall safely support a distributed working load of at least 25 kg while remaining level and mechanically stable. */

    require constraint {
      WelnerTableSystem::maximumSupportedMass >= 25 [SI::kilogram]
    }
  }

  requirement def MobilityRequirement {
    doc /* The system shall roll on four casters and shall provide user-controllable braking to hold position during use. */
  }

  requirement def SafetyRequirement {
    doc /* The controller shall prevent powered height motion when overload is detected or when measured height is outside the permitted travel range. */
  }

  requirement def StatusRequirement {
    doc /* The system shall report current height, operating mode, brake state, overload condition, and low battery condition to the user interface. */
  }

  satisfy PrimaryFunctionRequirement by WelnerTableSystem;
  satisfy HeightAdjustmentRequirement by LiftColumn;
  satisfy LoadSupportRequirement by Tabletop;
  satisfy MobilityRequirement by CasterSet;
  satisfy MobilityRequirement by BrakeSystem;
  satisfy SafetyRequirement by TableController;
  satisfy StatusRequirement by TableController;
}