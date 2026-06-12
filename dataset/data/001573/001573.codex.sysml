package SewingMachineSystemModel {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  attribute def StitchRate {
    :> scalar;
    unit = SI::Hz;
  }

  attribute def NeedleStrokeLength {
    :> scalar;
    unit = SI::mm;
  }

  attribute def ThreadTension {
    :> scalar;
    unit = SI::N;
  }

  attribute def FabricThickness {
    :> scalar;
    unit = SI::mm;
  }

  attribute def SeamLength {
    :> scalar;
    unit = SI::mm;
  }

  attribute def MotorPower {
    :> scalar;
    unit = SI::W;
  }

  attribute def PedalPosition {
    :> scalar;
    unit = SI::one;
  }

  attribute def StitchLength {
    :> scalar;
    unit = SI::mm;
  }

  attribute def BobbinThreadRemaining {
    :> scalar;
    unit = SI::m;
  }

  attribute def NeedleTemperature {
    :> scalar;
    unit = SI::degC;
  }

  item def Fabric {
    attribute thickness : FabricThickness;
    attribute width : LengthValue;
    attribute length : LengthValue;
    attribute material : String;
  }

  item def UpperThread {
    attribute color : String;
    attribute tensileStrength : ForceValue;
    attribute diameter : LengthValue;
  }

  item def BobbinThread {
    attribute color : String;
    attribute tensileStrength : ForceValue;
    attribute remainingLength : BobbinThreadRemaining;
  }

  item def StitchedFabric {
    attribute seamLength : SeamLength;
    attribute stitchPattern : String;
    attribute stitchLength : StitchLength;
    attribute stitchCount : Integer;
  }

  item def ElectricalEnergy {
    attribute voltage : ElectricPotentialValue;
    attribute current : ElectricCurrentValue;
  }

  item def OperatorCommand {
    attribute requestedSpeed : StitchRate;
    attribute reverseRequested : Boolean;
    attribute selectedPattern : String;
  }

  item def MachineStatus {
    attribute powered : Boolean;
    attribute ready : Boolean;
    attribute faultActive : Boolean;
    attribute message : String;
  }

  port def FabricInputPort {
    in fabricIn : Fabric;
  }

  port def FabricOutputPort {
    out fabricOut : StitchedFabric;
  }

  port def UpperThreadPort {
    in upperThreadIn : UpperThread;
  }

  port def BobbinThreadPort {
    in bobbinThreadIn : BobbinThread;
  }

  port def PowerPort {
    in powerIn : ElectricalEnergy;
  }

  port def CommandPort {
    in commandIn : OperatorCommand;
  }

  port def StatusPort {
    out statusOut : MachineStatus;
  }

  port def MechanicalDrivePort {
    out rotationalSpeed : AngularVelocityValue;
    out driveTorque : TorqueValue;
  }

  port def NeedleMotionPort {
    in strokeRate : StitchRate;
    in strokeLength : NeedleStrokeLength;
  }

  port def FeedMotionPort {
    in feedStep : StitchLength;
    in feedRate : StitchRate;
  }

  port def ThreadPathPort {
    in threadTension : ThreadTension;
  }

  part def SewingMachine {
    attribute maximumStitchRate : StitchRate = 20 [SI::Hz];
    attribute minimumStitchLength : StitchLength = 0.5 [SI::mm];
    attribute maximumStitchLength : StitchLength = 5.0 [SI::mm];
    attribute ratedMotorPower : MotorPower = 90 [SI::W];
    attribute maximumFabricThickness : FabricThickness = 6.0 [SI::mm];

    port powerPort : PowerPort;
    port commandPort : CommandPort;
    port fabricInput : FabricInputPort;
    port upperThreadInput : UpperThreadPort;
    port bobbinThreadInput : BobbinThreadPort;
    port fabricOutput : FabricOutputPort;
    port statusPort : StatusPort;

    part frame : MachineFrame;
    part driveSystem : DriveSystem;
    part needleAssembly : NeedleAssembly;
    part feedSystem : FeedSystem;
    part stitchFormationSystem : StitchFormationSystem;
    part threadManagementSystem : ThreadManagementSystem;
    part operatorInterface : OperatorInterface;
    part safetySystem : SafetySystem;

    connect powerPort.powerIn to driveSystem.powerInput.powerIn;
    connect commandPort.commandIn to operatorInterface.commandInput.commandIn;
    connect operatorInterface.driveCommand to driveSystem.speedCommand;
    connect driveSystem.mechanicalOutput to needleAssembly.driveInput;
    connect driveSystem.mechanicalOutput to feedSystem.driveInput;
    connect needleAssembly.needleMotionOutput to stitchFormationSystem.needleMotionInput;
    connect feedSystem.feedMotionOutput to stitchFormationSystem.feedMotionInput;
    connect upperThreadInput.upperThreadIn to threadManagementSystem.upperThreadInput.upperThreadIn;
    connect bobbinThreadInput.bobbinThreadIn to threadManagementSystem.bobbinThreadInput.bobbinThreadIn;
    connect threadManagementSystem.upperThreadPath to stitchFormationSystem.upperThreadPath;
    connect threadManagementSystem.bobbinThreadPath to stitchFormationSystem.bobbinThreadPath;
    connect fabricInput.fabricIn to feedSystem.fabricInput.fabricIn;
    connect feedSystem.positionedFabricOutput to stitchFormationSystem.fabricInput;
    connect stitchFormationSystem.stitchedFabricOutput to fabricOutput.fabricOut;
    connect safetySystem.machineStatus to statusPort.statusOut;
  }

  part def MachineFrame {
    attribute mass : MassValue = 7.5 [SI::kg];
    attribute bedLength : LengthValue = 380 [SI::mm];
    attribute throatDepth : LengthValue = 165 [SI::mm];
  }

  part def DriveSystem {
    port powerInput : PowerPort;
    port speedCommand : CommandPort;
    port mechanicalOutput : MechanicalDrivePort;

    part electricMotor : ElectricMotor;
    part beltDrive : BeltDrive;
    part handWheel : HandWheel;

    connect powerInput.powerIn to electricMotor.powerPort.powerIn;
    connect electricMotor.shaftOutput to beltDrive.motorInput;
    connect beltDrive.machineOutput to mechanicalOutput;
  }

  part def ElectricMotor {
    attribute ratedPower : MotorPower = 90 [SI::W];
    attribute nominalSpeed : AngularVelocityValue = 1500 [SI::rpm];

    port powerPort : PowerPort;
    port shaftOutput : MechanicalDrivePort;
  }

  part def BeltDrive {
    attribute speedReductionRatio : Real = 3.2;

    port motorInput : MechanicalDrivePort;
    port machineOutput : MechanicalDrivePort;
  }

  part def HandWheel {
    attribute diameter : LengthValue = 95 [SI::mm];
  }

  part def NeedleAssembly {
    attribute nominalStrokeLength : NeedleStrokeLength = 32 [SI::mm];
    attribute needleSize : String = "90/14 universal";
    attribute maximumNeedleTemperature : NeedleTemperature = 80 [SI::degC];

    port driveInput : MechanicalDrivePort;
    port needleMotionOutput : NeedleMotionPort;

    part needleBar : NeedleBar;
    part needle : Needle;
    part presserFoot : PresserFoot;
  }

  part def NeedleBar {
    attribute strokeLength : NeedleStrokeLength = 32 [SI::mm];
  }

  part def Needle {
    attribute pointType : String = "universal";
    attribute shaftDiameter : LengthValue = 0.9 [SI::mm];
  }

  part def PresserFoot {
    attribute normalForce : ForceValue = 18 [SI::N];
    attribute liftHeight : LengthValue = 8 [SI::mm];
  }

  part def FeedSystem {
    port driveInput : MechanicalDrivePort;
    port feedMotionOutput : FeedMotionPort;
    port fabricInput : FabricInputPort;
    port positionedFabricOutput : FabricInputPort;

    part feedDogs : FeedDogs;
    part stitchLengthRegulator : StitchLengthRegulator;
    part reverseLever : ReverseLever;
  }

  part def FeedDogs {
    attribute toothHeight : LengthValue = 1.2 [SI::mm];
    attribute feedStep : StitchLength = 2.5 [SI::mm];
  }

  part def StitchLengthRegulator {
    attribute selectedStitchLength : StitchLength = 2.5 [SI::mm];
    attribute minimumSetting : StitchLength = 0.5 [SI::mm];
    attribute maximumSetting : StitchLength = 5.0 [SI::mm];
  }

  part def ReverseLever {
    attribute reverseEnabled : Boolean = false;
  }

  part def StitchFormationSystem {
    port needleMotionInput : NeedleMotionPort;
    port feedMotionInput : FeedMotionPort;
    port upperThreadPath : ThreadPathPort;
    port bobbinThreadPath : ThreadPathPort;
    port fabricInput : FabricInputPort;
    port stitchedFabricOutput : FabricOutputPort;

    part shuttleHook : ShuttleHook;
    part bobbinCase : BobbinCase;
    part throatPlate : ThroatPlate;
  }

  part def ShuttleHook {
    attribute hookTimingOffset : TimeValue = 0.002 [SI::s];
    attribute rotationSpeed : AngularVelocityValue = 600 [SI::rpm];
  }

  part def BobbinCase {
    attribute bobbinCapacity : BobbinThreadRemaining = 60 [SI::m];
    attribute bobbinTension : ThreadTension = 0.35 [SI::N];
  }

  part def ThroatPlate {
    attribute needleHoleDiameter : LengthValue = 2.0 [SI::mm];
    attribute seamGuideSpacing : LengthValue = 10 [SI::mm];
  }

  part def ThreadManagementSystem {
    port upperThreadInput : UpperThreadPort;
    port bobbinThreadInput : BobbinThreadPort;
    port upperThreadPath : ThreadPathPort;
    port bobbinThreadPath : ThreadPathPort;

    part spoolPin : SpoolPin;
    part tensionDiscs : TensionDiscs;
    part takeUpLever : TakeUpLever;
    part bobbinWinder : BobbinWinder;
  }

  part def SpoolPin {
    attribute spoolCapacity : LengthValue = 500 [SI::m];
  }

  part def TensionDiscs {
    attribute selectedUpperTension : ThreadTension = 0.75 [SI::N];
    attribute minimumTension : ThreadTension = 0.2 [SI::N];
    attribute maximumTension : ThreadTension = 2.0 [SI::N];
  }

  part def TakeUpLever {
    attribute takeUpStroke : LengthValue = 42 [SI::mm];
  }

  part def BobbinWinder {
    attribute windingSpeed : AngularVelocityValue = 900 [SI::rpm];
    attribute autoStopEnabled : Boolean = true;
  }

  part def OperatorInterface {
    port commandInput : CommandPort;
    port driveCommand : CommandPort;

    part footPedal : FootPedal;
    part patternSelector : PatternSelector;
    part stitchLengthDial : StitchLengthDial;
    part statusLamp : StatusLamp;
  }

  part def FootPedal {
    attribute pedalPosition : PedalPosition = 0.0 [SI::one];
    attribute minimumOutputRate : StitchRate = 0 [SI::Hz];
    attribute maximumOutputRate : StitchRate = 20 [SI::Hz];
  }

  part def PatternSelector {
    attribute selectedPattern : String = "lockstitch";
    attribute supportedPatterns : String = "lockstitch, zigzag, buttonhole";
  }

  part def StitchLengthDial {
    attribute selectedLength : StitchLength = 2.5 [SI::mm];
  }

  part def StatusLamp {
    attribute illuminated : Boolean = false;
    attribute color : String = "green";
  }

  part def SafetySystem {
    port machineStatus : StatusPort;

    part needleGuard : NeedleGuard;
    part overcurrentProtection : OvercurrentProtection;
    part bobbinMonitor : BobbinMonitor;
    part threadBreakSensor : ThreadBreakSensor;
  }

  part def NeedleGuard {
    attribute installed : Boolean = true;
  }

  part def OvercurrentProtection {
    attribute tripCurrent : ElectricCurrentValue = 1.2 [SI::A];
    attribute tripped : Boolean = false;
  }

  part def BobbinMonitor {
    attribute lowThreadThreshold : BobbinThreadRemaining = 2.0 [SI::m];
    attribute lowThreadDetected : Boolean = false;
  }

  part def ThreadBreakSensor {
    attribute breakDetected : Boolean = false;
  }

  action def SewFabric {
    in rawFabric : Fabric;
    in upperThread : UpperThread;
    in bobbinThread : BobbinThread;
    in operatorCommand : OperatorCommand;
    out finishedFabric : StitchedFabric;

    first startMachine;
    then clampFabric;
    then synchronizeNeedleFeedAndHook;
    then formRepeatedLockstitches;
    then advanceFabric;
    then stopMachine;

    action startMachine {
      in command : OperatorCommand = operatorCommand;
    }

    action clampFabric {
      in fabric : Fabric = rawFabric;
    }

    action synchronizeNeedleFeedAndHook {
      in commandedRate : StitchRate = operatorCommand.requestedSpeed;
    }

    action formRepeatedLockstitches {
      in topThread : UpperThread = upperThread;
      in lowerThread : BobbinThread = bobbinThread;
      out seam : StitchedFabric = finishedFabric;
    }

    action advanceFabric {
      in stitchLength : StitchLength;
    }

    action stopMachine;
  }

  state def SewingMachineOperatingState {
    entry; then Off;

    state Off;
    state PoweredIdle;
    state Threading;
    state ReadyToSew;
    state SewingForward;
    state SewingReverse;
    state BobbinWinding;
    state Fault;

    transition Off_to_PoweredIdle
      first Off
      accept powerApplied
      then PoweredIdle;

    transition PoweredIdle_to_Threading
      first PoweredIdle
      accept threadSetupRequested
      then Threading;

    transition Threading_to_ReadyToSew
      first Threading
      accept threadsInstalled
      then ReadyToSew;

    transition PoweredIdle_to_ReadyToSew
      first PoweredIdle
      accept readyConfirmed
      then ReadyToSew;

    transition ReadyToSew_to_SewingForward
      first ReadyToSew
      accept pedalPressed
      if noFaultActive
      then SewingForward;

    transition SewingForward_to_ReadyToSew
      first SewingForward
      accept pedalReleased
      then ReadyToSew;

    transition SewingForward_to_SewingReverse
      first SewingForward
      accept reverseLeverPressed
      then SewingReverse;

    transition SewingReverse_to_SewingForward
      first SewingReverse
      accept reverseLeverReleased
      then SewingForward;

    transition ReadyToSew_to_BobbinWinding
      first ReadyToSew
      accept bobbinWinderEngaged
      then BobbinWinding;

    transition BobbinWinding_to_ReadyToSew
      first BobbinWinding
      accept bobbinFull
      then ReadyToSew;

    transition Any_to_Fault
      first Off, PoweredIdle, Threading, ReadyToSew, SewingForward, SewingReverse, BobbinWinding
      accept faultDetected
      then Fault;

    transition Fault_to_PoweredIdle
      first Fault
      accept faultCleared
      then PoweredIdle;
  }

  requirement def PrimaryFunctionRequirement {
    subject machine : SewingMachine;

    doc /* The sewing machine shall join one or more layers of fabric by repeatedly interlocking an upper thread and a bobbin thread while advancing the fabric at a controlled stitch length to create a continuous seam. */

    require constraint {
      machine.maximumStitchRate >= 10 [SI::Hz] and
      machine.maximumFabricThickness >= 4 [SI::mm]
    }
  }

  requirement def ControlledStitchRateRequirement {
    subject machine : SewingMachine;

    doc /* The sewing machine shall vary stitch formation rate in response to operator foot pedal input from stopped to the maximum commanded sewing speed. */

    require constraint {
      machine.operatorInterface.footPedal.minimumOutputRate == 0 [SI::Hz] and
      machine.operatorInterface.footPedal.maximumOutputRate <= machine.maximumStitchRate
    }
  }

  requirement def AdjustableStitchLengthRequirement {
    subject machine : SewingMachine;

    doc /* The sewing machine shall support operator adjustment of stitch length for ordinary seams. */

    require constraint {
      machine.operatorInterface.stitchLengthDial.selectedLength >= machine.minimumStitchLength and
      machine.operatorInterface.stitchLengthDial.selectedLength <= machine.maximumStitchLength
    }
  }

  requirement def ThreadTensionRequirement {
    subject machine : SewingMachine;

    doc /* The sewing machine shall maintain upper and bobbin thread tensions within ranges suitable for balanced lockstitch formation. */

    require constraint {
      machine.threadManagementSystem.tensionDiscs.selectedUpperTension >= 0.2 [SI::N] and
      machine.threadManagementSystem.tensionDiscs.selectedUpperTension <= 2.0 [SI::N] and
      machine.stitchFormationSystem.bobbinCase.bobbinTension >= 0.2 [SI::N] and
      machine.stitchFormationSystem.bobbinCase.bobbinTension <= 0.8 [SI::N]
    }
  }

  requirement def FabricHandlingRequirement {
    subject machine : SewingMachine;

    doc /* The sewing machine shall hold fabric against the feed dogs and advance it by one selected stitch length for each completed needle cycle. */

    require constraint {
      machine.needleAssembly.presserFoot.normalForce >= 10 [SI::N] and
      machine.feedSystem.feedDogs.feedStep == machine.feedSystem.stitchLengthRegulator.selectedStitchLength
    }
  }

  requirement def SafetyRequirement {
    subject machine : SewingMachine;

    doc /* The sewing machine shall detect unsafe operating conditions and enter a fault state when overcurrent, thread breakage, or low bobbin thread conditions occur. */

    require constraint {
      machine.safetySystem.needleGuard.installed == true and
      machine.safetySystem.overcurrentProtection.tripCurrent <= 1.5 [SI::A]
    }
  }

  requirement def BobbinCapacityRequirement {
    subject machine : SewingMachine;

    doc /* The sewing machine shall provide enough bobbin thread capacity for typical household seams and warn before the bobbin thread is exhausted. */

    require constraint {
      machine.stitchFormationSystem.bobbinCase.bobbinCapacity >= 50 [SI::m] and
      machine.safetySystem.bobbinMonitor.lowThreadThreshold >= 1.0 [SI::m]
    }
  }

  satisfy PrimaryFunctionRequirement by SewingMachine;
  satisfy ControlledStitchRateRequirement by SewingMachine;
  satisfy AdjustableStitchLengthRequirement by SewingMachine;
  satisfy ThreadTensionRequirement by SewingMachine;
  satisfy FabricHandlingRequirement by SewingMachine;
  satisfy SafetyRequirement by SewingMachine;
  satisfy BobbinCapacityRequirement by SewingMachine;

  part sewingMachineSystem : SewingMachine {
    attribute maximumStitchRate = 18 [SI::Hz];
    attribute ratedMotorPower = 90 [SI::W];
    attribute maximumFabricThickness = 6 [SI::mm];

    part operatorInterface {
      part patternSelector {
        attribute selectedPattern = "lockstitch";
      }
      part stitchLengthDial {
        attribute selectedLength = 2.5 [SI::mm];
      }
    }

    part threadManagementSystem {
      part tensionDiscs {
        attribute selectedUpperTension = 0.75 [SI::N];
      }
    }

    part stitchFormationSystem {
      part bobbinCase {
        attribute bobbinTension = 0.35 [SI::N];
        attribute bobbinCapacity = 60 [SI::m];
      }
    }
  }

  action sewStandardSeam : SewFabric {
    in rawFabric {
      attribute thickness = 2.0 [SI::mm];
      attribute width = 300 [SI::mm];
      attribute length = 500 [SI::mm];
      attribute material = "cotton";
    }

    in upperThread {
      attribute color = "white";
      attribute tensileStrength = 8 [SI::N];
      attribute diameter = 0.2 [SI::mm];
    }

    in bobbinThread {
      attribute color = "white";
      attribute tensileStrength = 8 [SI::N];
      attribute remainingLength = 60 [SI::m];
    }

    in operatorCommand {
      attribute requestedSpeed = 12 [SI::Hz];
      attribute reverseRequested = false;
      attribute selectedPattern = "lockstitch";
    }

    out finishedFabric {
      attribute seamLength = 450 [SI::mm];
      attribute stitchPattern = "lockstitch";
      attribute stitchLength = 2.5 [SI::mm];
      attribute stitchCount = 180;
    }
  }
}