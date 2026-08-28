package DoosanCobotSystem {

    import ScalarValues::*;

    // ============================================================
    //  Value Types with Units
    // ============================================================
    value def MassValue :> Real { unit 'kg'; }
    value def LengthValue :> Real { unit 'mm'; }
    value def TorqueValue :> Real { unit 'N*m'; }
    value def AngleValue :> Real { unit 'rad'; }
    value def ForceValue :> Real { unit 'N'; }
    value def AngularVelocityValue :> Real { unit 'rad/s'; }
    value def PowerValue :> Real { unit 'W'; }
    value def VoltageValue :> Real { unit 'V'; }
    value def CurrentValue :> Real { unit 'A'; }
    value def TimeValue :> Real { unit 's'; }
    value def DistanceValue :> Real { unit 'm'; }
    value def FrequencyValue :> Real { unit 'Hz'; }

    // ============================================================
    //  Attribute Definitions
    // ============================================================
    attribute def Pose3D {
        x, y, z : LengthValue;
        roll, pitch, yaw : AngleValue;
    }

    attribute def JointState {
        angle : AngleValue;
        angularVelocity : AngularVelocityValue;
        torque : TorqueValue;
    }

    attribute def Trajectory {
        waypoints : Pose3D[0..*];
        duration : TimeValue;
    }

    attribute def WorkpieceDetection {
        objectId : String;
        pose : Pose3D;
        confidence : Real;
    }

    // ============================================================
    //  Item Definitions
    // ============================================================
    item def Workpiece;
    item def ElectricalPower;
    item def EmergencyStopSignal;
    item def StatusReport;

    // ============================================================
    //  Port Definitions
    // ============================================================
    port def PowerPort {
        attribute nominalVoltage : VoltageValue;
        attribute maxCurrent : CurrentValue;
    }

    port def JointCommandPort {
        attribute targetAngle : AngleValue;
    }

    port def JointFeedbackPort {
        attribute measuredAngle : AngleValue;
        attribute measuredTorque : TorqueValue;
        attribute measuredVelocity : AngularVelocityValue;
    }

    port def GripperCommandPort {
        attribute targetOpening : LengthValue;
        attribute targetForce : ForceValue;
    }

    port def GripperFeedbackPort {
        attribute measuredOpening : LengthValue;
        attribute measuredForce : ForceValue;
    }

    port def VisionPort {
        attribute detections : WorkpieceDetection[0..*];
    }

    port def JointTorqueReportPort {
        attribute torques : TorqueValue[6];
    }

    port def ObstacleReportPort {
        attribute distance : DistanceValue;
    }

    port def EstopPort {
        attribute pressed : Boolean;
    }

    port def SafetyAlertPort {
        attribute emergencyStop : EmergencyStopSignal;
    }

    // ============================================================
    //  Requirements
    // ============================================================
    requirement def PayloadRequirement {
        doc /* The robotic arm shall handle payloads up to 15 kg. */
    }

    requirement def RepeatabilityRequirement {
        doc /* The arm shall achieve a positioning repeatability of 0.05 mm. */
    }

    requirement def CollisionSafetyRequirement {
        doc /* The safety controller shall trigger an emergency stop upon detecting unexpected joint torque or obstacle proximity. */
    }

    requirement def VisionRequirement {
        doc /* The vision system shall identify workpieces and their 3D pose. */
    }

    requirement def GraspControlRequirement {
        doc /* The gripper shall apply controlled force to avoid damaging delicate workpieces. */
    }

    requirement def PowerRequirement {
        doc /* The power supply unit shall deliver electrical energy to all subsystems. */
    }

    requirement def PickAndPlaceRequirement {
        doc /* The system shall perform a complete pick-and-place cycle: scan, plan, approach, grasp, transport, place, verify, and return home. */
    }

    // ============================================================
    //  Leaf Components
    // ============================================================
    part def ServoMotor {
        attribute nominalTorque : TorqueValue;
        attribute maxSpeed : AngularVelocityValue;
        attribute powerRating : PowerValue;
        port powerIn : PowerPort;
        port cmdIn : JointCommandPort;
        port fbOut : JointFeedbackPort;
    }

    part def JointSensor {
        attribute angleResolution : AngleValue;
        attribute torqueRange : TorqueValue;
        attribute samplingRate : FrequencyValue;
    }

    part def RoboticJoint {
        attribute jointName : String;
        attribute jointIndex : Integer;
        attribute minAngle : AngleValue;
        attribute maxAngle : AngleValue;
        part motor : ServoMotor;
        part sensor : JointSensor;
        port cmdIn : JointCommandPort;
        port fbOut : JointFeedbackPort;
        port powerIn : PowerPort;
        attribute currentTorque : TorqueValue;
        attribute currentAngle : AngleValue;
        attribute currentVelocity : AngularVelocityValue;
        flow ElectricalPower from powerIn to motor.powerIn;
        connection cmdInternal connects cmdIn to motor.cmdIn;
        connection fbInternal connects motor.fbOut to fbOut;
    }

    part def SixAxisArm {
        attribute payloadCapacity : MassValue = 15;
        attribute repeatability : LengthValue = 0.05;
        attribute maxReach : LengthValue = 850;
        satisfy PayloadRequirement;
        satisfy RepeatabilityRequirement;

        part base : RoboticJoint {
            attribute jointName : String = "base";
            attribute jointIndex : Integer = 1;
        }
        part shoulder : RoboticJoint {
            attribute jointName : String = "shoulder";
            attribute jointIndex : Integer = 2;
        }
        part elbow : RoboticJoint {
            attribute jointName : String = "elbow";
            attribute jointIndex : Integer = 3;
        }
        part wristRoll : RoboticJoint {
            attribute jointName : String = "wristRoll";
            attribute jointIndex : Integer = 4;
        }
        part wristPitch : RoboticJoint {
            attribute jointName : String = "wristPitch";
            attribute jointIndex : Integer = 5;
        }
        part wristYaw : RoboticJoint {
            attribute jointName : String = "wristYaw";
            attribute jointIndex : Integer = 6;
        }

        port cmd1 : JointCommandPort;
        port cmd2 : JointCommandPort;
        port cmd3 : JointCommandPort;
        port cmd4 : JointCommandPort;
        port cmd5 : JointCommandPort;
        port cmd6 : JointCommandPort;
        port fb1 : JointFeedbackPort;
        port fb2 : JointFeedbackPort;
        port fb3 : JointFeedbackPort;
        port fb4 : JointFeedbackPort;
        port fb5 : JointFeedbackPort;
        port fb6 : JointFeedbackPort;
        port torqueReport : JointTorqueReportPort;
        port powerIn : PowerPort;
        attribute jointTorques : TorqueValue[6];

        connection c1 connects cmd1 to base.cmdIn;
        connection c2 connects cmd2 to shoulder.cmdIn;
        connection c3 connects cmd3 to elbow.cmdIn;
        connection c4 connects cmd4 to wristRoll.cmdIn;
        connection c5 connects cmd5 to wristPitch.cmdIn;
        connection c6 connects cmd6 to wristYaw.cmdIn;
        connection f1 connects base.fbOut to fb1;
        connection f2 connects shoulder.fbOut to fb2;
        connection f3 connects elbow.fbOut to fb3;
        connection f4 connects wristRoll.fbOut to fb4;
        connection f5 connects wristPitch.fbOut to fb5;
        connection f6 connects wristYaw.fbOut to fb6;
    }

    part def ForceSensor {
        attribute maxForce : ForceValue;
        attribute resolution : ForceValue;
    }

    part def LinearActuator {
        attribute maxStroke : LengthValue;
        attribute maxForce : ForceValue;
        attribute speed : AngularVelocityValue;
    }

    part def AdaptiveGripper {
        attribute maxOpening : LengthValue = 80;
        attribute minOpening : LengthValue = 0;
        attribute maxForce : ForceValue = 200;
        part actuators : LinearActuator[2];
        part forceSensors : ForceSensor[2];
        port cmdIn : GripperCommandPort;
        port fbOut : GripperFeedbackPort;
        port powerIn : PowerPort;
        attribute currentOpening : LengthValue;
        attribute currentForce : ForceValue;
        attribute isClosed : Boolean;
        satisfy GraspControlRequirement;

        exhibit state GripperOperation {
            state Open;
            state Closing;
            state Closed;
            state Opening;
            transition from Open to Closing when graspCommand;
            transition from Closing to Closed when forceReached;
            transition from Closed to Opening when releaseCommand;
            transition from Opening to Open when fullyOpen;
        }
    }

    part def DepthCamera {
        attribute resolution : String;
        attribute frameRate : FrequencyValue;
        attribute depthRange : DistanceValue;
        port imageOut : VisionPort;
        port powerIn : PowerPort;
    }

    part def VisionSystem {
        part camera : DepthCamera;
        attribute detectionConfidenceThreshold : Real;
        attribute scanRange : DistanceValue;
        port detectionOut : VisionPort;
        port powerIn : PowerPort;
        connection imgConn connects camera.imageOut to detectionOut;
        connection camPower connects powerIn to camera.powerIn;
        satisfy VisionRequirement;
    }

    part def CPU {
        attribute clockSpeed : FrequencyValue;
        attribute memorySize : Real;
    }

    part def MainController {
        attribute algorithm : String;
        part processor : CPU;
        port armCmd1 : JointCommandPort;
        port armCmd2 : JointCommandPort;
        port armCmd3 : JointCommandPort;
        port armCmd4 : JointCommandPort;
        port armCmd5 : JointCommandPort;
        port armCmd6 : JointCommandPort;
        port armFb1 : JointFeedbackPort;
        port armFb2 : JointFeedbackPort;
        port armFb3 : JointFeedbackPort;
        port armFb4 : JointFeedbackPort;
        port armFb5 : JointFeedbackPort;
        port armFb6 : JointFeedbackPort;
        port armTorque : JointTorqueReportPort;
        port gripperCmd : GripperCommandPort;
        port gripperFb : GripperFeedbackPort;
        port visionIn : VisionPort;
        port safetyIn : SafetyAlertPort;
        port powerIn : PowerPort;
        attribute currentTrajectory : Trajectory;
        attribute currentJointStates : JointState[6];
        attribute emergencyStopActive : Boolean;
        attribute cycleCount : Integer;
        satisfy PickAndPlaceRequirement;

        exhibit state PickAndPlace {
            state Idle;
            state Scanning;
            state Planning;
            state Approaching;
            state Grasping;
            state Transporting;
            state Placing;
            state Verifying;
            state Homing;
            transition from Idle to Scanning when startRequested;
            transition from Scanning to Planning when detectionReceived;
            transition from Planning to Approaching when trajectoryComputed;
            transition from Approaching to Grasping when targetReached;
            transition from Grasping to Transporting when graspConfirmed;
            transition from Transporting to Placing when destinationReached;
            transition from Placing to Verifying when placementComplete;
            transition from Verifying to Homing when verificationPassed;
            transition from Homing to Idle when homeReached;
            transition from any to Idle when emergencyStopActive;
        }
    }

    part def LaserScanner {
        attribute scanRange : DistanceValue;
        attribute fieldOfView : AngleValue;
        port obstacleOut : ObstacleReportPort;
        port powerIn : PowerPort;
    }

    part def EmergencyStopButton {
        attribute isPressed : Boolean;
        port eStopOut : EstopPort;
    }

    part def SafetyController {
        attribute torqueThreshold : TorqueValue;
        attribute proximityThreshold : DistanceValue;
        part laserScanner : LaserScanner;
        part eStopButton : EmergencyStopButton;
        port armTorqueIn : JointTorqueReportPort;
        port obstacleIn : ObstacleReportPort;
        port eStopIn : EstopPort;
        port alertOut : SafetyAlertPort;
        port powerIn : PowerPort;
        attribute collisionDetected : Boolean;
        attribute emergencyStopRequested : Boolean;
        attribute obstacleDistance : DistanceValue;

        connection scanConn connects laserScanner.obstacleOut to obstacleIn;
        connection estopConn connects eStopButton.eStopOut to eStopIn;
        connection laserPower connects powerIn to laserScanner.powerIn;
        satisfy CollisionSafetyRequirement;

        exhibit state SafetyStateMachine {
            state Monitoring;
            state EmergencyStop;
            state Recovering;
            transition from Monitoring to EmergencyStop when collisionDetected;
            transition from EmergencyStop to Recovering when operatorReset;
            transition from Recovering to Monitoring when systemCleared;
        }
    }

    part def PowerSupplyUnit {
        attribute outputVoltage : VoltageValue = 24;
        attribute maxPower : PowerValue = 1500;
        attribute maxCurrent : CurrentValue = 60;
        port powerOut : PowerPort;
        satisfy PowerRequirement;
    }

    // ============================================================
    //  System Composite
    // ============================================================
    part def DoosanCobot {
        part arm : SixAxisArm;
        part gripper : AdaptiveGripper;
        part vision : VisionSystem;
        part controller : MainController;
        part safety : SafetyController;
        part powerSupply : PowerSupplyUnit;

        connection power1 connects powerSupply.powerOut to controller.powerIn;
        connection power2 connects powerSupply.powerOut to arm.powerIn;
        connection power3 connects powerSupply.powerOut to gripper.powerIn;
        connection power4 connects powerSupply.powerOut to safety.powerIn;
        connection power5 connects powerSupply.powerOut to vision.powerIn;

        connection visionCtrl connects vision.detectionOut to controller.visionIn;

        connection cmd1c connects controller.armCmd1 to arm.cmd1;
        connection cmd2c connects controller.armCmd2 to arm.cmd2;
        connection cmd3c connects controller.armCmd3 to arm.cmd3;
        connection cmd4c connects controller.armCmd4 to arm.cmd4;
        connection cmd5c connects controller.armCmd5 to arm.cmd5;
        connection cmd6c connects controller.armCmd6 to arm.cmd6;

        connection fb1c connects arm.fb1 to controller.armFb1;
        connection fb2c connects arm.fb2 to controller.armFb2;
        connection fb3c connects arm.fb3 to controller.armFb3;
        connection fb4c connects arm.fb4 to controller.armFb4;
        connection fb5c connects arm.fb5 to controller.armFb5;
        connection fb6c connects arm.fb6 to controller.armFb6;

        connection torqueToSafety connects arm.torqueReport to safety.armTorqueIn;
        connection torqueToCtrl connects arm.torqueReport to controller.armTorque;

        connection gripperCmdC connects controller.gripperCmd to gripper.cmdIn;
        connection gripperFbC connects gripper.fbOut to controller.gripperFb;

        connection safetyCtrl connects safety.alertOut to controller.safetyIn;
    }
}
