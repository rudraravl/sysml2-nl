package DockingSystemSpecification {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    value def Millimeter :> LengthValue {
        unit = "mm";
    }

    value def Newton :> ForceValue {
        unit = "N";
    }

    value def Degree :> AngleValue {
        unit = "deg";
    }

    value def Second :> TimeValue {
        unit = "s";
    }

    value def Percent :> Real {
        unit = "%";
    }

    item def DockingCommand {
        attribute commandId : String;
        attribute requestedMode : DockingMode;
        attribute issuedTime : Second;
    }

    item def AlignmentData {
        attribute lateralOffset : Millimeter;
        attribute verticalOffset : Millimeter;
        attribute yawError : Degree;
        attribute pitchError : Degree;
        attribute rangeToTarget : Millimeter;
        attribute confidence : Percent;
    }

    item def DockingStatus {
        attribute phase : DockingPhase;
        attribute isAligned : Boolean;
        attribute isCaptured : Boolean;
        attribute isLocked : Boolean;
        attribute faultActive : Boolean;
    }

    item def MechanicalLoad {
        attribute axialForce : Newton;
        attribute shearForce : Newton;
        attribute bendingMoment : Real;
    }

    enum def DockingMode {
        enum manual;
        enum assisted;
        enum automatic;
        enum emergencyRelease;
    }

    enum def DockingPhase {
        enum idle;
        enum approach;
        enum align;
        enum capture;
        enum lock;
        enum verify;
        enum docked;
        enum release;
        enum fault;
    }

    port def CommandPort {
        in item command : DockingCommand;
    }

    port def StatusPort {
        out item status : DockingStatus;
    }

    port def AlignmentPort {
        out item alignment : AlignmentData;
    }

    port def LoadPort {
        out item load : MechanicalLoad;
    }

    port def PowerPort {
        in attribute voltage : Real;
        in attribute current : Real;
    }

    port def ActuationPort {
        out attribute actuatorPosition : Millimeter;
        out attribute actuatorForce : Newton;
    }

    port def MechanicalDockingPort {
        inout item load : MechanicalLoad;
        attribute captureEnvelopeRadius : Millimeter;
        attribute hardMateTolerance : Millimeter;
    }

    interface def CommandInterface {
        end controller : CommandPort;
        end receiver : CommandPort;
    }

    interface def StatusInterface {
        end source : StatusPort;
        end sink : StatusPort;
    }

    interface def AlignmentInterface {
        end sensor : AlignmentPort;
        end processor : AlignmentPort;
    }

    interface def MechanicalDockingInterface {
        end activeSide : MechanicalDockingPort;
        end passiveSide : MechanicalDockingPort;
    }

    part def GuidanceSensor {
        port alignmentOut : AlignmentPort;

        attribute measurementRate : Real = 50.0;
        attribute maxRange : Millimeter = 5000.0;
        attribute lateralAccuracy : Millimeter = 2.0;
        attribute angularAccuracy : Degree = 0.25;
    }

    part def DockingController {
        port commandIn : CommandPort;
        port alignmentIn : AlignmentPort;
        port loadIn : LoadPort;
        port actuatorOut : ActuationPort;
        port statusOut : StatusPort;

        attribute alignmentTolerance : Millimeter = 5.0;
        attribute angularTolerance : Degree = 1.0;
        attribute captureRange : Millimeter = 150.0;
        attribute lockVerificationTime : Second = 3.0;
    }

    part def CaptureMechanism {
        port actuatorIn : ActuationPort;
        port mechanicalPort : MechanicalDockingPort;
        port loadOut : LoadPort;

        attribute jawOpening : Millimeter = 220.0;
        attribute captureForce : Newton = 1200.0;
        attribute maximumAllowableLoad : Newton = 5000.0;
        attribute captured : Boolean;
    }

    part def LockingMechanism {
        port actuatorIn : ActuationPort;
        port mechanicalPort : MechanicalDockingPort;

        attribute lockPinStroke : Millimeter = 45.0;
        attribute preloadForce : Newton = 2500.0;
        attribute locked : Boolean;
    }

    part def PassiveDockingTarget {
        port dockingPort : MechanicalDockingPort;

        attribute guideConeRadius : Millimeter = 180.0;
        attribute latchReceiverDepth : Millimeter = 60.0;
        attribute structuralLoadLimit : Newton = 6000.0;
    }

    part def PowerUnit {
        port powerOut : PowerPort;

        attribute nominalVoltage : Real = 28.0;
        attribute maximumCurrent : Real = 20.0;
    }

    part def OperatorConsole {
        port commandOut : CommandPort;
        port statusIn : StatusPort;

        attribute operatorEnabled : Boolean;
    }

    action def ComputeDockingAlignment {
        in item sensedAlignment : AlignmentData;
        out attribute aligned : Boolean;

        action evaluateLateralOffset;
        action evaluateVerticalOffset;
        action evaluateAngularError;
        action publishAlignmentDecision;
    }

    action def ExecuteCapture {
        in item alignment : AlignmentData;
        out attribute captured : Boolean;

        action extendCaptureJaws;
        action senseContactLoad;
        action closeCaptureJaws;
        action confirmCapture;
    }

    action def ExecuteHardLock {
        in attribute captured : Boolean;
        out attribute locked : Boolean;

        action driveLockPins;
        action applyPreload;
        action verifyPinPosition;
        action verifyLoadPath;
    }

    action def ReleaseDocking {
        out attribute released : Boolean;

        action removePreload;
        action retractLockPins;
        action openCaptureJaws;
        action confirmSeparation;
    }

    state def DockingControlStateMachine {
        entry action initializeDockingStatus;

        state idle;
        state approach;
        state align;
        state capture;
        state lock;
        state verify;
        state docked;
        state release;
        state fault;

        transition first idle;

        transition idle_to_approach
            first idle
            then approach
            accept DockingCommand
            if command.requestedMode == DockingMode::automatic;

        transition approach_to_align
            first approach
            then align
            if alignment.rangeToTarget <= 1000.0 [Millimeter];

        transition align_to_capture
            first align
            then capture
            if alignment.lateralOffset <= 5.0 [Millimeter]
            and alignment.verticalOffset <= 5.0 [Millimeter]
            and alignment.yawError <= 1.0 [Degree]
            and alignment.pitchError <= 1.0 [Degree];

        transition capture_to_lock
            first capture
            then lock
            if status.isCaptured == true;

        transition lock_to_verify
            first lock
            then verify
            if status.isLocked == true;

        transition verify_to_docked
            first verify
            then docked
            after 3.0 [Second]
            if status.faultActive == false;

        transition docked_to_release
            first docked
            then release
            accept DockingCommand
            if command.requestedMode == DockingMode::emergencyRelease;

        transition release_to_idle
            first release
            then idle
            if status.isCaptured == false and status.isLocked == false;

        transition any_to_fault
            first approach, align, capture, lock, verify, docked
            then fault
            if load.axialForce > 5000.0 [Newton]
            or status.faultActive == true;
    }

    part def DockingSystem {
        doc /* Primary function: mechanically align, capture, lock, verify, and release a host vehicle or platform to a passive docking target while exchanging command, status, alignment, power, and structural load information. */

        port commandPort : CommandPort;
        port statusPort : StatusPort;
        port activeDockingPort : MechanicalDockingPort;
        port powerPort : PowerPort;

        part console : OperatorConsole;
        part powerUnit : PowerUnit;
        part sensor : GuidanceSensor;
        part controller : DockingController;
        part captureMechanism : CaptureMechanism;
        part lockingMechanism : LockingMechanism;
        part target : PassiveDockingTarget;

        attribute maximumDockingRange : Millimeter = 5000.0;
        attribute finalAlignmentTolerance : Millimeter = 5.0;
        attribute finalAngularTolerance : Degree = 1.0;
        attribute maximumCaptureLoad : Newton = 5000.0;
        attribute nominalDockingTime : Second = 45.0;

        connect console.commandOut to controller.commandIn;
        connect controller.statusOut to console.statusIn;
        connect sensor.alignmentOut to controller.alignmentIn;
        connect captureMechanism.loadOut to controller.loadIn;
        connect controller.actuatorOut to captureMechanism.actuatorIn;
        connect controller.actuatorOut to lockingMechanism.actuatorIn;
        connect powerUnit.powerOut to powerPort;
        connect captureMechanism.mechanicalPort to activeDockingPort;
        connect lockingMechanism.mechanicalPort to activeDockingPort;
        connect activeDockingPort to target.dockingPort;
        connect controller.statusOut to statusPort;
        connect commandPort to controller.commandIn;

        perform action alignDecision : ComputeDockingAlignment;
        perform action captureAction : ExecuteCapture;
        perform action lockAction : ExecuteHardLock;
        perform action releaseAction : ReleaseDocking;

        exhibit state dockingBehavior : DockingControlStateMachine;
    }

    requirement def DockingPrimaryFunctionRequirement {
        subject dockingSystem : DockingSystem;

        require constraint {
            dockingSystem shall align, capture, lock, verify, and release a passive docking target under commanded operation.
        }
    }

    requirement def AlignmentRequirement {
        subject dockingSystem : DockingSystem;

        require constraint {
            dockingSystem.finalAlignmentTolerance <= 5.0 [Millimeter]
            and dockingSystem.finalAngularTolerance <= 1.0 [Degree]
        }
    }

    requirement def CaptureLoadRequirement {
        subject dockingSystem : DockingSystem;

        require constraint {
            dockingSystem.maximumCaptureLoad <= 5000.0 [Newton]
        }
    }

    requirement def StatusReportingRequirement {
        subject dockingSystem : DockingSystem;

        require constraint {
            dockingSystem.statusPort.status.phase is DockingPhase
            and dockingSystem.statusPort.status.faultActive is Boolean
        }
    }

    requirement def EmergencyReleaseRequirement {
        subject dockingSystem : DockingSystem;

        require constraint {
            dockingSystem shall transition from docked to release when an emergencyRelease command is accepted.
        }
    }

    satisfy DockingSystem by DockingPrimaryFunctionRequirement;
    satisfy DockingSystem by AlignmentRequirement;
    satisfy DockingSystem by CaptureLoadRequirement;
    satisfy DockingSystem by StatusReportingRequirement;
    satisfy DockingSystem by EmergencyReleaseRequirement;
}