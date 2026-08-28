package SoftRoboticArmSystem {
    private import ScalarValues::*;

    attribute def PressureValue :> Real;
    attribute def ForceValue :> Real;
    attribute def AngleValue :> Real;
    attribute def LengthValue :> Real;

    attribute def Position3d {
        attribute x : Real;
        attribute y : Real;
        attribute z : Real;
    }

    item def CompressedAir;

    enum def GripperCommandKind { open; close; release; }

    port def PneumaticPort {
        ref item air : CompressedAir;
        attribute pressure : PressureValue;
    }

    port def SegmentSensorPort {
        attribute pressureReading : PressureValue;
        attribute bendingAngle : AngleValue;
    }

    port def GripperSensorPort {
        attribute forceReading : ForceValue;
    }

    port def ControlCommandPort {
        attribute targetPressures : PressureValue[3];
        attribute targetBendingAngles : AngleValue[3];
        attribute gripperCommand : GripperCommandKind;
    }

    state def SegmentState {
        entry; then deflated;
        state deflated;
        transition deflated_to_inflating
            first deflated
            accept 'inflate'
            then inflating;
        state inflating;
        transition inflating_to_holding
            first inflating
            accept 'pressureReached'
            then holding;
        state holding;
        transition holding_to_deflating
            first holding
            accept 'deflate'
            then deflating;
        state deflating;
        transition deflating_to_deflated
            first deflating
            accept 'pressureZero'
            then deflated;
    }

    state def GripperState {
        entry; then open;
        state open;
        transition open_to_closing
            first open
            accept 'closeGripper'
            then closing;
        state closing;
        transition closing_to_gripping
            first closing
            accept 'forceThresholdReached'
            then gripping;
        state gripping;
        transition gripping_to_releasing
            first gripping
            accept 'openGripper'
            then releasing;
        state releasing;
        transition releasing_to_open
            first releasing
            accept 'gripComplete'
            then open;
    }

    part def SoftActuatorSegment {
        port pneumaticIn : PneumaticPort;
        port sensorOut : SegmentSensorPort;
        attribute currentPressure : PressureValue = 0.0;
        attribute currentBendingAngle : AngleValue = 0.0;
        attribute segmentLength : LengthValue;
        exhibit segmentState : SegmentState;
    }

    part def SoftFinger :> SoftActuatorSegment {
        attribute curlAngle : AngleValue;
    }

    part def SoftGripper {
        port pneumaticIn : PneumaticPort;
        port sensorOut : GripperSensorPort;
        attribute currentForce : ForceValue = 0.0;
        attribute maxGripForce : ForceValue = 5.0;

        part finger1 : SoftFinger;
        part finger2 : SoftFinger;
        part finger3 : SoftFinger;

        connect pneumaticIn to finger1.pneumaticIn;
        connect pneumaticIn to finger2.pneumaticIn;
        connect pneumaticIn to finger3.pneumaticIn;

        exhibit gripperState : GripperState;
    }

    part def AirCompressor {
        out item air : CompressedAir;
        attribute outputPressure : PressureValue;
        action start;
        action stop;
    }

    part def Valve {
        ref item air : CompressedAir;
        attribute isOpen : Boolean = false;
        attribute channelPressure : PressureValue = 0.0;
    }

    part def PneumaticControlUnit {
        port armControlOut1 : PneumaticPort;
        port armControlOut2 : PneumaticPort;
        port armControlOut3 : PneumaticPort;
        port gripperControlOut : PneumaticPort;
        port commandIn : ControlCommandPort;

        part compressor : AirCompressor;
        part valves : Valve[4];

        action def RegulatePressure {
            in attribute targetPressure : PressureValue;
            in attribute channelIndex : Integer;
            out item air : CompressedAir;
        }

        action regulateAllPressures {
            in attribute targetPressures : PressureValue[3];
            in attribute gripperPressure : PressureValue;
        }
    }

    part def MotionController {
        port sensorIn1 : SegmentSensorPort;
        port sensorIn2 : SegmentSensorPort;
        port sensorIn3 : SegmentSensorPort;
        port gripperSensorIn : GripperSensorPort;
        port commandOut : ControlCommandPort;

        attribute targetPickLocation : Position3d;
        attribute targetPlaceLocation : Position3d;

        calc def InverseKinematics {
            in attribute targetPosition : Position3d;
            return : PressureValue[3];
        }
    }

    action def PickAndPlace {
        in attribute pickPosition : Position3d;
        in attribute placePosition : Position3d;

        action planMotion;
        action moveArmToPickup;
        action closeGripper;
        action moveArmToPlacement;
        action openGripper;
        action returnToHome;

        succession first planMotion then moveArmToPickup;
        succession first moveArmToPickup then closeGripper;
        succession first closeGripper then moveArmToPlacement;
        succession first moveArmToPlacement then openGripper;
        succession first openGripper then returnToHome;
    }

    part def ArticulatedSoftArm {
        part baseSegment : SoftActuatorSegment {
            attribute :>> segmentLength = 0.20;
        }
        part middleSegment : SoftActuatorSegment {
            attribute :>> segmentLength = 0.18;
        }
        part tipSegment : SoftActuatorSegment {
            attribute :>> segmentLength = 0.12;
        }
        part gripper : SoftGripper;
    }

    requirement def SafeHandlingRequirement {
        subject gripper : SoftGripper;
        attribute maxGripForce : ForceValue = 5.0;
        constraint gripForceLimit { gripper.currentForce <= maxGripForce }
    }

    requirement def PrecisePositioningRequirement {
        subject arm : ArticulatedSoftArm;
        attribute positionTolerance : LengthValue = 0.001;
    }

    requirement def PickAndPlaceCompletionRequirement {
        subject system : SoftRoboticSystem;
    }

    part def SoftRoboticSystem {
        part arm : ArticulatedSoftArm;
        part pneumaticUnit : PneumaticControlUnit;
        part controller : MotionController;

        connect pneumaticUnit.armControlOut1 to arm.baseSegment.pneumaticIn;
        connect pneumaticUnit.armControlOut2 to arm.middleSegment.pneumaticIn;
        connect pneumaticUnit.armControlOut3 to arm.tipSegment.pneumaticIn;
        connect pneumaticUnit.gripperControlOut to arm.gripper.pneumaticIn;

        connect arm.baseSegment.sensorOut to controller.sensorIn1;
        connect arm.middleSegment.sensorOut to controller.sensorIn2;
        connect arm.tipSegment.sensorOut to controller.sensorIn3;
        connect arm.gripper.sensorOut to controller.gripperSensorIn;

        connect controller.commandOut to pneumaticUnit.commandIn;

        action pickAndPlace : PickAndPlace;

        requirement safeHandling : SafeHandlingRequirement;
        requirement precisePositioning : PrecisePositioningRequirement;
        requirement pickAndPlaceCompletion : PickAndPlaceCompletionRequirement;
    }
}
