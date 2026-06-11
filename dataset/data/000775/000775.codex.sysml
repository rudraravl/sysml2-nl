package StandingFrameSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Mass :> ISQ::mass {
        unit = SI::kg;
    }

    attribute def Length :> ISQ::length {
        unit = SI::m;
    }

    attribute def Angle :> ISQ::planeAngle {
        unit = SI::rad;
    }

    attribute def Force :> ISQ::force {
        unit = SI::N;
    }

    attribute def Time :> ISQ::time {
        unit = SI::s;
    }

    attribute def ElectricPotential :> ISQ::electricPotential {
        unit = SI::V;
    }

    attribute def Percent {
        :>> range = "0..100";
    }

    item def UserBody {
        attribute bodyMass : Mass;
        attribute standingToleranceTime : Time;
        attribute hipWidth : Length;
        attribute kneeHeight : Length;
    }

    item def SupportLoad {
        attribute verticalForce : Force;
        attribute lateralForce : Force;
        attribute posteriorForce : Force;
    }

    item def AdjustmentCommand {
        attribute targetTiltAngle : Angle;
        attribute targetHeight : Length;
        attribute requestedByUser : Boolean;
    }

    item def StabilityStatus {
        attribute centerOfMassWithinBase : Boolean;
        attribute leftBrakeLocked : Boolean;
        attribute rightBrakeLocked : Boolean;
        attribute tiltAngleStable : Boolean;
    }

    item def BatteryEnergy {
        attribute stateOfCharge : Percent;
        attribute voltage : ElectricPotential;
    }

    port def BodySupportPort {
        in item user : UserBody;
        out item supportLoad : SupportLoad;
    }

    port def MechanicalAttachmentPort {
        inout item load : SupportLoad;
    }

    port def ControlPort {
        in item command : AdjustmentCommand;
        out item status : StabilityStatus;
    }

    port def PowerPort {
        inout item energy : BatteryEnergy;
    }

    part def StandingFrame {
        attribute maximumUserMass : Mass = 120 [SI::kg];
        attribute minimumUserHeight : Length = 1.20 [SI::m];
        attribute maximumUserHeight : Length = 1.95 [SI::m];
        attribute nominalStandingAngle : Angle = 1.4835 [SI::rad];
        attribute footprintLength : Length = 0.92 [SI::m];
        attribute footprintWidth : Length = 0.68 [SI::m];

        port bodyInterface : BodySupportPort;
        port caregiverControls : ControlPort;
        port electricalInput : PowerPort;

        part base : BaseFrame;
        part verticalColumn : HeightAdjustableColumn;
        part tiltMechanism : TiltMechanism;
        part footplates : FootplateAssembly;
        part kneeSupports : KneeSupportAssembly;
        part pelvicSupport : PelvicSupportAssembly;
        part chestSupport : ChestSupportAssembly;
        part harness : SafetyHarness;
        part controller : ControlUnit;
        part actuatorPower : BatteryPack;

        connection baseToColumn connect base.columnMount to verticalColumn.lowerMount;
        connection columnToTilt connect verticalColumn.upperMount to tiltMechanism.columnMount;
        connection tiltToChest connect tiltMechanism.supportMount to chestSupport.frameMount;
        connection tiltToPelvis connect tiltMechanism.supportMount to pelvicSupport.frameMount;
        connection baseToFootplates connect base.footplateMount to footplates.baseMount;
        connection columnToKnees connect verticalColumn.kneeSupportMount to kneeSupports.columnMount;
        connection harnessToChest connect harness.upperAnchor to chestSupport.harnessAnchor;
        connection harnessToPelvis connect harness.lowerAnchor to pelvicSupport.harnessAnchor;
        connection batteryToController connect actuatorPower.powerOut to controller.powerIn;
        connection controllerToTilt connect controller.tiltControl to tiltMechanism.control;
        connection controllerToColumn connect controller.heightControl to verticalColumn.control;
        connection userLoadPath1 connect bodyInterface to chestSupport.bodyContact;
        connection userLoadPath2 connect bodyInterface to pelvicSupport.bodyContact;
        connection userLoadPath3 connect bodyInterface to kneeSupports.bodyContact;
        connection userLoadPath4 connect bodyInterface to footplates.bodyContact;
        connection statusPath connect caregiverControls to controller.externalControl;
        connection powerPath connect electricalInput to actuatorPower.chargePort;

        perform action provideSupportedStanding;
        exhibit state standingFrameOperationalStates;
    }

    part def BaseFrame {
        attribute length : Length = 0.92 [SI::m];
        attribute width : Length = 0.68 [SI::m];
        attribute maximumStaticLoad : Force = 1600 [SI::N];

        port columnMount : MechanicalAttachmentPort;
        port footplateMount : MechanicalAttachmentPort;

        part leftCaster : LockingCaster;
        part rightCaster : LockingCaster;
        part rearLeftCaster : LockingCaster;
        part rearRightCaster : LockingCaster;
        part antiTipBar : AntiTipBar;
    }

    part def LockingCaster {
        attribute wheelDiameter : Length = 0.10 [SI::m];
        attribute brakeLocked : Boolean;

        port loadInterface : MechanicalAttachmentPort;
    }

    part def AntiTipBar {
        attribute extensionLength : Length = 0.18 [SI::m];
        attribute allowableTipMoment : Force = 450 [SI::N];

        port loadInterface : MechanicalAttachmentPort;
    }

    part def HeightAdjustableColumn {
        attribute minimumHeight : Length = 0.82 [SI::m];
        attribute maximumHeight : Length = 1.25 [SI::m];
        attribute currentHeight : Length;
        attribute liftCapacity : Force = 1400 [SI::N];

        port lowerMount : MechanicalAttachmentPort;
        port upperMount : MechanicalAttachmentPort;
        port kneeSupportMount : MechanicalAttachmentPort;
        port control : ControlPort;

        perform action adjustHeight;
    }

    part def TiltMechanism {
        attribute minimumTiltAngle : Angle = 0.0 [SI::rad];
        attribute maximumTiltAngle : Angle = 1.5708 [SI::rad];
        attribute currentTiltAngle : Angle;
        attribute angularRateLimit : Angle = 0.035 [SI::rad];

        port columnMount : MechanicalAttachmentPort;
        port supportMount : MechanicalAttachmentPort;
        port control : ControlPort;

        part linearActuator : LinearActuator;
        part pivotJoint : PivotJoint;

        connection actuatorToPivot connect linearActuator.outputLink to pivotJoint.actuationLink;

        perform action transitionToStanding;
        perform action transitionToSeated;
    }

    part def LinearActuator {
        attribute strokeLength : Length = 0.30 [SI::m];
        attribute ratedPushForce : Force = 1800 [SI::N];
        attribute inputVoltage : ElectricPotential = 24 [SI::V];

        port powerIn : PowerPort;
        port outputLink : MechanicalAttachmentPort;
    }

    part def PivotJoint {
        attribute rotationLimit : Angle = 1.5708 [SI::rad];
        attribute bearingLoadLimit : Force = 2200 [SI::N];

        port actuationLink : MechanicalAttachmentPort;
        port supportedFrameLink : MechanicalAttachmentPort;
    }

    part def FootplateAssembly {
        attribute footplateWidth : Length = 0.24 [SI::m];
        attribute footplateLength : Length = 0.30 [SI::m];
        attribute toeOutAngle : Angle = 0.0873 [SI::rad];

        port baseMount : MechanicalAttachmentPort;
        port bodyContact : BodySupportPort;

        part leftFootplate : Footplate;
        part rightFootplate : Footplate;
        part heelStraps : HeelStrapSet;
    }

    part def Footplate {
        attribute length : Length = 0.30 [SI::m];
        attribute width : Length = 0.12 [SI::m];
        attribute slipResistanceCoefficient : Real = 0.70;

        port loadInterface : MechanicalAttachmentPort;
    }

    part def HeelStrapSet {
        attribute strapTensionLimit : Force = 180 [SI::N];

        port loadInterface : MechanicalAttachmentPort;
    }

    part def KneeSupportAssembly {
        attribute padHeightRangeMinimum : Length = 0.32 [SI::m];
        attribute padHeightRangeMaximum : Length = 0.62 [SI::m];
        attribute padSpacingRangeMinimum : Length = 0.12 [SI::m];
        attribute padSpacingRangeMaximum : Length = 0.32 [SI::m];

        port columnMount : MechanicalAttachmentPort;
        port bodyContact : BodySupportPort;

        part leftKneePad : KneePad;
        part rightKneePad : KneePad;
    }

    part def KneePad {
        attribute padWidth : Length = 0.11 [SI::m];
        attribute padHeight : Length = 0.16 [SI::m];
        attribute allowableContactForce : Force = 250 [SI::N];

        port contactSurface : BodySupportPort;
    }

    part def PelvicSupportAssembly {
        attribute beltWidth : Length = 0.10 [SI::m];
        attribute lateralAdjustmentRange : Length = 0.18 [SI::m];
        attribute allowablePelvicSupportForce : Force = 450 [SI::N];

        port frameMount : MechanicalAttachmentPort;
        port bodyContact : BodySupportPort;
        port harnessAnchor : MechanicalAttachmentPort;

        part pelvicBelt : PelvicBelt;
        part leftHipGuide : LateralHipGuide;
        part rightHipGuide : LateralHipGuide;
    }

    part def PelvicBelt {
        attribute minimumCircumference : Length = 0.55 [SI::m];
        attribute maximumCircumference : Length = 1.20 [SI::m];
        attribute ratedTension : Force = 700 [SI::N];

        port bodyContact : BodySupportPort;
    }

    part def LateralHipGuide {
        attribute padLength : Length = 0.18 [SI::m];
        attribute padWidth : Length = 0.08 [SI::m];

        port bodyContact : BodySupportPort;
    }

    part def ChestSupportAssembly {
        attribute padWidth : Length = 0.36 [SI::m];
        attribute padHeight : Length = 0.18 [SI::m];
        attribute heightAdjustmentRange : Length = 0.34 [SI::m];
        attribute allowableChestSupportForce : Force = 350 [SI::N];

        port frameMount : MechanicalAttachmentPort;
        port bodyContact : BodySupportPort;
        port harnessAnchor : MechanicalAttachmentPort;

        part chestPad : ChestPad;
        part trunkStrap : TrunkStrap;
    }

    part def ChestPad {
        attribute cushionThickness : Length = 0.035 [SI::m];
        attribute contactAreaWidth : Length = 0.36 [SI::m];

        port bodyContact : BodySupportPort;
    }

    part def TrunkStrap {
        attribute minimumCircumference : Length = 0.50 [SI::m];
        attribute maximumCircumference : Length = 1.10 [SI::m];
        attribute ratedTension : Force = 600 [SI::N];

        port bodyContact : BodySupportPort;
    }

    part def SafetyHarness {
        attribute ratedLoad : Force = 1000 [SI::N];
        attribute quickReleaseAccessible : Boolean = true;

        port upperAnchor : MechanicalAttachmentPort;
        port lowerAnchor : MechanicalAttachmentPort;
        port bodyContact : BodySupportPort;
    }

    part def ControlUnit {
        attribute powerEnabled : Boolean;
        attribute emergencyStopActive : Boolean;
        attribute measuredTiltAngle : Angle;
        attribute measuredHeight : Length;

        port powerIn : PowerPort;
        port tiltControl : ControlPort;
        port heightControl : ControlPort;
        port externalControl : ControlPort;

        part handPendant : HandPendant;
        part emergencyStop : EmergencyStopSwitch;
        part tiltSensor : TiltAngleSensor;
        part loadMonitor : LoadMonitor;

        perform action evaluateStability;
        perform action inhibitMotionIfUnsafe;
    }

    part def HandPendant {
        port operatorCommand : ControlPort;

        attribute raiseButtonPressed : Boolean;
        attribute lowerButtonPressed : Boolean;
        attribute standButtonPressed : Boolean;
        attribute sitButtonPressed : Boolean;
    }

    part def EmergencyStopSwitch {
        attribute activated : Boolean;

        port safetySignal : ControlPort;
    }

    part def TiltAngleSensor {
        attribute sensedAngle : Angle;
        attribute accuracy : Angle = 0.0175 [SI::rad];

        port statusOut : ControlPort;
    }

    part def LoadMonitor {
        attribute measuredUserLoad : Force;
        attribute overloadDetected : Boolean;

        port statusOut : ControlPort;
    }

    part def BatteryPack {
        attribute nominalVoltage : ElectricPotential = 24 [SI::V];
        attribute stateOfCharge : Percent;
        attribute lowChargeThreshold : Percent = 20;

        port powerOut : PowerPort;
        port chargePort : PowerPort;
    }

    action def ProvideSupportedStanding {
        in item user : UserBody;
        in item requestedPosture : AdjustmentCommand;
        out item stability : StabilityStatus;

        first start;
        then verifyUserWithinCapacity;
        then secureFeetKneesPelvisAndChest;
        then unlockMotionControl;
        then raiseAndTiltUserGradually;
        then monitorLoadTiltAndBrakes;
        then maintainSupportedStanding;
        then done;

        action verifyUserWithinCapacity;
        action secureFeetKneesPelvisAndChest;
        action unlockMotionControl;
        action raiseAndTiltUserGradually;
        action monitorLoadTiltAndBrakes;
        action maintainSupportedStanding;
    }

    action def AdjustHeight {
        in item command : AdjustmentCommand;
        out item status : StabilityStatus;

        first receiveHeightTarget;
        then moveColumnWithinRange;
        then confirmHeightStable;
        then done;

        action receiveHeightTarget;
        action moveColumnWithinRange;
        action confirmHeightStable;
    }

    action def TransitionToStanding {
        in item command : AdjustmentCommand;
        out item status : StabilityStatus;

        first confirmBrakesLocked;
        then applyControlledActuatorMotion;
        then stopAtStandingAngle;
        then verifyCenterOfMassWithinBase;
        then done;

        action confirmBrakesLocked;
        action applyControlledActuatorMotion;
        action stopAtStandingAngle;
        action verifyCenterOfMassWithinBase;
    }

    action def TransitionToSeated {
        in item command : AdjustmentCommand;
        out item status : StabilityStatus;

        first confirmUserSecured;
        then reduceTiltAngleGradually;
        then stopAtTransferAngle;
        then done;

        action confirmUserSecured;
        action reduceTiltAngleGradually;
        action stopAtTransferAngle;
    }

    action def EvaluateStability {
        in item load : SupportLoad;
        out item status : StabilityStatus;

        first computeLoadDistribution;
        then compareCenterOfMassToBaseEnvelope;
        then reportStability;
        then done;

        action computeLoadDistribution;
        action compareCenterOfMassToBaseEnvelope;
        action reportStability;
    }

    action def InhibitMotionIfUnsafe {
        in item status : StabilityStatus;

        first inspectStatus;
        then decideMotionPermission;
        then done;

        action inspectStatus;
        action decideMotionPermission;
    }

    state def StandingFrameOperationalStates {
        entry action initializeController;

        state Off;
        state ReadyForTransfer;
        state UserSecured;
        state RaisingToStand;
        state StandingSupport;
        state LoweringToTransfer;
        state FaultLocked;

        transition initial then Off;

        transition powerApplied
            first Off
            then ReadyForTransfer;

        transition userSecured
            first ReadyForTransfer
            then UserSecured;

        transition standCommandAccepted
            first UserSecured
            then RaisingToStand;

        transition standingAngleReached
            first RaisingToStand
            then StandingSupport;

        transition sitCommandAccepted
            first StandingSupport
            then LoweringToTransfer;

        transition transferAngleReached
            first LoweringToTransfer
            then ReadyForTransfer;

        transition unsafeConditionDetected
            first ReadyForTransfer
            then FaultLocked;

        transition unsafeConditionDetectedWhileSecured
            first UserSecured
            then FaultLocked;

        transition unsafeConditionDetectedWhileMovingUp
            first RaisingToStand
            then FaultLocked;

        transition unsafeConditionDetectedWhileStanding
            first StandingSupport
            then FaultLocked;

        transition unsafeConditionDetectedWhileMovingDown
            first LoweringToTransfer
            then FaultLocked;

        transition faultCleared
            first FaultLocked
            then ReadyForTransfer;

        action initializeController;
    }

    requirement def PrimaryStandingSupportRequirement {
        doc /* The standing frame shall support a user in a stable upright posture to enable weight bearing, positioning, and assisted participation while reducing continuous caregiver lifting effort. */

        subject frame : StandingFrame;

        require constraint {
            frame.maximumUserMass >= 120 [SI::kg]
        }
    }

    requirement def UserCapacityRequirement {
        doc /* The standing frame shall accommodate users with body mass up to 120 kg and user height from 1.20 m to 1.95 m. */

        subject frame : StandingFrame;

        require constraint {
            frame.maximumUserMass >= 120 [SI::kg] and
            frame.minimumUserHeight <= 1.20 [SI::m] and
            frame.maximumUserHeight >= 1.95 [SI::m]
        }
    }

    requirement def StabilityRequirement {
        doc /* The standing frame shall maintain the combined center of mass of the user and frame within the base footprint during transfer, raising, supported standing, and lowering. */

        subject status : StabilityStatus;

        require constraint {
            status.centerOfMassWithinBase == true
        }
    }

    requirement def BrakeSafetyRequirement {
        doc /* The standing frame shall permit powered raising or lowering only when both primary base brakes are locked. */

        subject status : StabilityStatus;

        require constraint {
            status.leftBrakeLocked == true and
            status.rightBrakeLocked == true
        }
    }

    requirement def TiltRangeRequirement {
        doc /* The tilt mechanism shall move the supported user from transfer orientation to near-upright standing orientation without exceeding the mechanical tilt limit. */

        subject tilt : TiltMechanism;

        require constraint {
            tilt.currentTiltAngle >= tilt.minimumTiltAngle and
            tilt.currentTiltAngle <= tilt.maximumTiltAngle
        }
    }

    requirement def ContactLoadRequirement {
        doc /* Body support pads and straps shall distribute support loads through feet, knees, pelvis, and chest without exceeding local rated contact forces. */

        subject load : SupportLoad;

        require constraint {
            load.verticalForce >= 0 [SI::N] and
            load.lateralForce <= 450 [SI::N] and
            load.posteriorForce <= 450 [SI::N]
        }
    }

    requirement def EmergencyStopRequirement {
        doc /* Activation of the emergency stop shall immediately inhibit actuator motion and place the standing frame in a fault locked state. */

        subject controller : ControlUnit;

        require constraint {
            controller.emergencyStopActive implies controller.powerEnabled == false
        }
    }

    requirement def BatteryRequirement {
        doc /* The battery pack shall provide 24 V nominal power and shall report low charge when state of charge is below 20 percent. */

        subject battery : BatteryPack;

        require constraint {
            battery.nominalVoltage == 24 [SI::V] and
            battery.lowChargeThreshold == 20
        }
    }

    satisfy PrimaryStandingSupportRequirement by StandingFrame::provideSupportedStanding;
    satisfy UserCapacityRequirement by StandingFrame;
    satisfy StabilityRequirement by ControlUnit::evaluateStability;
    satisfy BrakeSafetyRequirement by ControlUnit::inhibitMotionIfUnsafe;
    satisfy TiltRangeRequirement by TiltMechanism;
    satisfy ContactLoadRequirement by ChestSupportAssembly;
    satisfy ContactLoadRequirement by PelvicSupportAssembly;
    satisfy ContactLoadRequirement by KneeSupportAssembly;
    satisfy ContactLoadRequirement by FootplateAssembly;
    satisfy EmergencyStopRequirement by ControlUnit::inhibitMotionIfUnsafe;
    satisfy BatteryRequirement by BatteryPack;

    part standingFrameSystem : StandingFrame {
        :>> maximumUserMass = 120 [SI::kg];
        :>> minimumUserHeight = 1.20 [SI::m];
        :>> maximumUserHeight = 1.95 [SI::m];
        :>> nominalStandingAngle = 1.4835 [SI::rad];
    }

}