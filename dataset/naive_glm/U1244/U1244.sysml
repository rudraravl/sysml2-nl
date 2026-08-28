package IndustrialRobotSystem {
    import ScalarValues::*;
    import SI::*;

    // ---------- Value Types with Units ----------
    value def Length :> Real { unit "m"; }
    value def Angle :> Real { unit "rad"; }
    value def LinearSpeed :> Real { unit "m/s"; }
    value def AngularSpeed :> Real { unit "rad/s"; }
    value def LinearAcceleration :> Real { unit "m/s^2"; }
    value def AngularAcceleration :> Real { unit "rad/s^2"; }
    value def ForceValue :> Real { unit "N"; }
    value def TorqueValue :> Real { unit "N*m"; }
    value def MassValue :> Real { unit "kg"; }
    value def TimeValue :> Real { unit "s"; }
    value def FrequencyValue :> Real { unit "Hz"; }
    value def PowerValue :> Real { unit "W"; }
    value def CurrentValue :> Real { unit "A"; }
    value def VoltageValue :> Real { unit "V"; }
    value def ConfidenceValue :> Real { unit "1"; }

    // ---------- Enumerations ----------
    enum def SafetyStopType {
        emergencyStop;
        protectiveStop;
        reducedSpeed;
    }

    enum def OperatingMode {
        manual;
        automatic;
        teaching;
    }

    enum def JointName {
        base;
        shoulder;
        elbow;
        wrist1;
        wrist2;
        wrist3;
    }

    enum def GripperState {
        open;
        closed;
        moving;
    }

    // ---------- Item Types ----------
    item def Pose {
        attribute x : Length;
        attribute y : Length;
        attribute z : Length;
        attribute roll : Angle;
        attribute pitch : Angle;
        attribute yaw : Angle;
    }

    item def Workpiece {
        attribute id : String;
        attribute mass : MassValue;
        attribute length : Length;
        attribute width : Length;
        attribute height : Length;
        attribute pose : Pose;
    }

    item def MotionCommand {
        attribute commandId : String;
        attribute targetPose : Pose;
        attribute linearSpeed : LinearSpeed;
        attribute angularSpeed : AngularSpeed;
        attribute linearAccel : LinearAcceleration;
        attribute angularAccel : AngularAcceleration;
    }

    item def Image {
        attribute imageId : String;
        attribute width : Integer;
        attribute height : Integer;
        attribute timestamp : TimeValue;
    }

    item def DetectionResult {
        attribute workpieceId : String;
        attribute pose : Pose;
        attribute confidence : ConfidenceValue;
    }

    item def SafetyStopSignal {
        attribute stopType : SafetyStopType;
        attribute timestamp : TimeValue;
    }

    item def JointCommand {
        attribute joint : JointName;
        attribute targetAngle : Angle;
        attribute maxSpeed : AngularSpeed;
        attribute maxAccel : AngularAcceleration;
    }

    // ---------- Requirements ----------
    requirement def PickAndPlaceRequirement {
        doc /* The robotic system shall perform automated pick-and-place tasks with high reliability. */
        subject robot : IndustrialRobot;
        attribute successRate : Real = 0.99;
        objective {
            robot.pickAndPlaceSuccessRate >= successRate
        }
    }

    requirement def ReachRequirement {
        doc /* The arm shall reach any point within a 0.85 m radius hemisphere. */
        subject arm : RoboticArm;
        attribute minReach : Length = 0.0;
        attribute maxReach : Length = 0.85;
        objective {
            arm.reach >= minReach and arm.reach <= maxReach
        }
    }

    requirement def GripperForceRequirement {
        doc /* The gripper shall grasp objects with a controlled force between 5 N and 60 N. */
        subject gripper : Gripper;
        attribute minForce : ForceValue = 5.0;
        attribute maxForce : ForceValue = 60.0;
        objective {
            gripper.graspForce >= minForce and gripper.graspForce <= maxForce
        }
    }

    requirement def SafetyMonitoringRequirement {
        doc /* The safety controller shall enforce speed and force limits and handle stop signals. */
        subject safety : SafetyController;
        attribute maxSafeSpeed : LinearSpeed = 0.25;
        attribute maxSafeForce : ForceValue = 150.0;
        attribute emergencyStopResponseTime : TimeValue = 0.1;
        objective {
            safety.enforcedMaxSpeed <= maxSafeSpeed and
            safety.enforcedMaxForce <= maxSafeForce and
            safety.stopResponseTime <= emergencyStopResponseTime
        }
    }

    requirement def VisionAccuracyRequirement {
        doc /* The vision sensor shall detect workpieces with at least 95% confidence. */
        subject vision : VisionSensor;
        attribute minConfidence : ConfidenceValue = 0.95;
        objective {
            vision.detectionConfidence >= minConfidence
        }
    }

    // ---------- Port Definitions ----------
    port def MotionCommandOutPort {
        out command : MotionCommand;
    }

    port def MotionCommandInPort {
        in command : MotionCommand;
    }

    port def JointCommandOutPort {
        out jointCommand : JointCommand;
    }

    port def JointCommandInPort {
        in jointCommand : JointCommand;
    }

    port def GripperCommandPort {
        out graspForce : ForceValue;
        out openCommand : Boolean;
    }

    port def GripperFeedbackPort {
        in gripperState : GripperState;
        in measuredForce : ForceValue;
    }

    port def ImageOutPort {
        out image : Image;
    }

    port def ImageInPort {
        in image : Image;
    }

    port def DetectionOutPort {
        out detection : DetectionResult;
    }

    port def DetectionInPort {
        in detection : DetectionResult;
    }

    port def SafetyStopOutPort {
        out stopSignal : SafetyStopSignal;
    }

    port def SafetyStopInPort {
        in stopSignal : SafetyStopSignal;
    }

    port def SafetyStatusOutPort {
        out safeToOperate : Boolean;
        out enforcedSpeed : LinearSpeed;
        out enforcedForce : ForceValue;
    }

    port def SafetyStatusInPort {
        in safeToOperate : Boolean;
        in enforcedSpeed : LinearSpeed;
        in enforcedForce : ForceValue;
    }

    port def ModeCommandPort {
        out mode : OperatingMode;
    }

    // ---------- Interface / Connection Definitions ----------
    connection def MotionCommandLink {
        end source : MotionCommandOutPort;
        end target : MotionCommandInPort;
        item command : MotionCommand;
    }

    connection def JointCommandLink {
        end source : JointCommandOutPort;
        end target : JointCommandInPort;
        item jointCommand : JointCommand;
    }

    connection def GripperCommandLink {
        end source : GripperCommandPort;
        end target : GripperCommandPort;
        item graspForce : ForceValue;
        item openCommand : Boolean;
    }

    connection def GripperFeedbackLink {
        end source : GripperFeedbackPort;
        end target : GripperFeedbackPort;
        item gripperState : GripperState;
        item measuredForce : ForceValue;
    }

    connection def ImageLink {
        end source : ImageOutPort;
        end target : ImageInPort;
        item image : Image;
    }

    connection def DetectionLink {
        end source : DetectionOutPort;
        end target : DetectionInPort;
        item detection : DetectionResult;
    }

    connection def SafetyStopLink {
        end source : SafetyStopOutPort;
        end target : SafetyStopInPort;
        item stopSignal : SafetyStopSignal;
    }

    connection def SafetyStatusLink {
        end source : SafetyStatusOutPort;
        end target : SafetyStatusInPort;
        item safeToOperate : Boolean;
        item enforcedSpeed : LinearSpeed;
        item enforcedForce : ForceValue;
    }

    // ---------- Part Definitions ----------
    part def RevoluteJoint {
        attribute name : JointName;
        attribute minAngle : Angle;
        attribute maxAngle : Angle;
        attribute maxSpeed : AngularSpeed;
        attribute maxTorque : TorqueValue;
        attribute currentAngle : Angle;
        attribute currentSpeed : AngularSpeed = 0.0;
        attribute locked : Boolean = false;
        port jointCmdIn : JointCommandInPort;
        port jointFeedbackOut : JointCommandOutPort;
        action executeJointCommand(in cmd : JointCommand) {
            if not locked {
                currentAngle := cmd.targetAngle;
            }
        }
    }

    part def RoboticArm {
        attribute reach : Length = 0.85;
        attribute payload : MassValue = 5.0;
        port jointCmdIn : JointCommandInPort;
        port jointFeedbackOut : JointCommandOutPort;
        part baseJoint : RevoluteJoint {
            attribute name = JointName::base;
            attribute minAngle = -3.14159;
            attribute maxAngle = 3.14159;
            attribute maxSpeed = 2.0;
            attribute maxTorque = 300.0;
        }
        part shoulderJoint : RevoluteJoint {
            attribute name = JointName::shoulder;
            attribute minAngle = -1.5708;
            attribute maxAngle = 1.5708;
            attribute maxSpeed = 2.0;
            attribute maxTorque = 300.0;
        }
        part elbowJoint : RevoluteJoint {
            attribute name = JointName::elbow;
            attribute minAngle = -3.14159;
            attribute maxAngle = 3.14159;
            attribute maxSpeed = 3.0;
            attribute maxTorque = 200.0;
        }
        part wristJoint1 : RevoluteJoint {
            attribute name = JointName::wrist1;
            attribute minAngle = -3.14159;
            attribute maxAngle = 3.14159;
            attribute maxSpeed = 3.0;
            attribute maxTorque = 100.0;
        }
        part wristJoint2 : RevoluteJoint {
            attribute name = JointName::wrist2;
            attribute minAngle = -2.0944;
            attribute maxAngle = 2.0944;
            attribute maxSpeed = 3.0;
            attribute maxTorque = 100.0;
        }
        part wristJoint3 : RevoluteJoint {
            attribute name = JointName::wrist3;
            attribute minAngle = -3.14159;
            attribute maxAngle = 3.14159;
            attribute maxSpeed = 4.0;
            attribute maxTorque = 50.0;
        }
        action lockAllJoints() {
            baseJoint.locked := true;
            shoulderJoint.locked := true;
            elbowJoint.locked := true;
            wristJoint1.locked := true;
            wristJoint2.locked := true;
            wristJoint3.locked := true;
        }
        action unlockAllJoints() {
            baseJoint.locked := false;
            shoulderJoint.locked := false;
            elbowJoint.locked := false;
            wristJoint1.locked := false;
            wristJoint2.locked := false;
            wristJoint3.locked := false;
        }
    }

    part def Gripper {
        attribute maxGraspForce : ForceValue = 60.0;
        attribute graspForce : ForceValue = 0.0;
        attribute state : GripperState = GripperState::open;
        port gripperCmdIn : GripperCommandPort;
        port gripperFeedbackOut : GripperFeedbackPort;
        action grasp(in force : ForceValue) {
            graspForce := force;
            state := GripperState::closed;
        }
        action release() {
            graspForce := 0.0;
            state := GripperState::open;
        }
    }

    part def VisionSensor {
        attribute detectionConfidence : ConfidenceValue = 0.97;
        attribute frameRate : FrequencyValue = 30.0;
        port imageOut : ImageOutPort;
        port detectionOut : DetectionOutPort;
        action captureImage() : Image {
            return new Image(imageId = "img_001", width = 1920, height = 1080, timestamp = 0.0);
        }
        action processImage(in img : Image) : DetectionResult {
            return new DetectionResult(workpieceId = "wp_001", pose = new Pose(0.5, 0.2, 0.1, 0.0, 0.0, 0.0), confidence = detectionConfidence);
        }
        action detectWorkpiece() : DetectionResult {
            var img : Image = captureImage();
            return processImage(img);
        }
    }

    part def RobotController {
        attribute commandQueue : MotionCommand[0..*] ordered;
        attribute currentMode : OperatingMode = OperatingMode::automatic;
        attribute pickAndPlaceSuccessRate : Real = 0.995;
        port commandIn : MotionCommandInPort;
        port jointCmdOut : JointCommandOutPort;
        port gripperCmdOut : GripperCommandPort;
        port gripperFeedbackIn : GripperFeedbackPort;
        port detectionIn : DetectionInPort;
        port safetyStatusIn : SafetyStatusInPort;
        port modeOut : ModeCommandPort;
        action planPath(in target : Pose) : MotionCommand {
            return new MotionCommand(
                commandId = "cmd_001",
                targetPose = target,
                linearSpeed = 0.5,
                angularSpeed = 1.0,
                linearAccel = 0.5,
                angularAccel = 1.0
            );
        }
        action executePickAndPlace(in workpiecePose : Pose, in dropOffPose : Pose) {
            var approachCmd : MotionCommand = planPath(workpiecePose);
            commandQueue := commandQueue.append(approachCmd);
            var dropCmd : MotionCommand = planPath(dropOffPose);
            commandQueue := commandQueue.append(dropCmd);
        }
        state def ControllerStateMachine {
            entry action { currentMode := OperatingMode::automatic; }
            then Initializing;
            state Initializing {
                entry action { /* initialize subsystems */ }
            }
            transition from Initializing to Idle when safetyStatusIn.safeToOperate == true;
            state Idle {
                entry action { /* wait for commands */ }
            }
            transition from Idle to Active when commandQueue.size() > 0 and safetyStatusIn.safeToOperate == true;
            state Active {
                entry action { /* execute motion sequence */ }
            }
            transition from Active to Idle when commandQueue.size() == 0;
            transition from Active to EmergencyStop when safetyStatusIn.safeToOperate == false;
            transition from Idle to EmergencyStop when safetyStatusIn.safeToOperate == false;
            state EmergencyStop {
                entry action { /* halt all motion */ }
            }
            transition from EmergencyStop to Initializing when safetyStatusIn.safeToOperate == true;
        }
    }

    part def SafetyController {
        attribute enforcedMaxSpeed : LinearSpeed = 0.25;
        attribute enforcedMaxForce : ForceValue = 150.0;
        attribute stopResponseTime : TimeValue = 0.08;
        attribute safeToOperate : Boolean = true;
        attribute currentStopType : SafetyStopType;
        port stopSignalIn : SafetyStopInPort;
        port safetyStatusOut : SafetyStatusOutPort;
        action evaluateSafety() {
            if stopSignalIn.stopSignal.stopType == SafetyStopType::emergencyStop {
                safeToOperate := false;
                currentStopType := SafetyStopType::emergencyStop;
            } else if stopSignalIn.stopSignal.stopType == SafetyStopType::protectiveStop {
                safeToOperate := false;
                currentStopType := SafetyStopType::protectiveStop;
            } else if stopSignalIn.stopSignal.stopType == SafetyStopType::reducedSpeed {
                enforcedMaxSpeed := 0.1;
                currentStopType := SafetyStopType::reducedSpeed;
            }
        }
        action resetSafety() {
            safeToOperate := true;
            enforcedMaxSpeed := 0.25;
            currentStopType := null;
        }
        state def SafetyStateMachine {
            entry then NormalOperation;
            state NormalOperation {
                entry action { safeToOperate := true; }
            }
            transition from NormalOperation to ProtectiveStop when stopSignalIn.stopSignal.stopType == SafetyStopType::protectiveStop;
            transition from NormalOperation to ReducedSpeed when stopSignalIn.stopSignal.stopType == SafetyStopType::reducedSpeed;
            transition from NormalOperation to EmergencyStop when stopSignalIn.stopSignal.stopType == SafetyStopType::emergencyStop;
            state ProtectiveStop {
                entry action { safeToOperate := false; }
            }
            state ReducedSpeed {
                entry action { enforcedMaxSpeed := 0.1; safeToOperate := true; }
            }
            state EmergencyStop {
                entry action { safeToOperate := false; }
            }
            transition from ProtectiveStop to NormalOperation when stopSignalIn.stopSignal == null;
            transition from ReducedSpeed to NormalOperation when stopSignalIn.stopSignal == null;
            transition from EmergencyStop to NormalOperation when stopSignalIn.stopSignal == null;
        }
    }

    // ---------- Top-Level System ----------
    part def IndustrialRobot {
        attribute systemId : String = "Cobot_001";
        attribute pickAndPlaceSuccessRate : Real = 0.995;
        satisfy PickAndPlaceRequirement by robot;
        satisfy ReachRequirement by arm;
        satisfy GripperForceRequirement by gripper;
        satisfy SafetyMonitoringRequirement by safetyController;
        satisfy VisionAccuracyRequirement by visionSensor;

        part arm : RoboticArm {
            satisfy ReachRequirement by arm;
        }
        part gripper : Gripper {
            satisfy GripperForceRequirement by gripper;
        }
        part controller : RobotController;
        part visionSensor : VisionSensor {
            satisfy VisionAccuracyRequirement by visionSensor;
        }
        part safetyController : SafetyController {
            satisfy SafetyMonitoringRequirement by safetyController;
        }

        // Connections
        connection : MotionCommandLink connect controller.commandIn to controller.commandIn;
        connection : JointCommandLink connect controller.jointCmdOut to arm.jointCmdIn;
        connection : GripperCommandLink connect controller.gripperCmdOut to gripper.gripperCmdIn;
        connection : GripperFeedbackLink connect gripper.gripperFeedbackOut to controller.gripperFeedbackIn;
        connection : ImageLink connect visionSensor.imageOut to visionSensor.imageOut;
        connection : DetectionLink connect visionSensor.detectionOut to controller.detectionIn;
        connection : SafetyStatusLink connect safetyController.safetyStatusOut to controller.safetyStatusIn;

        // System-level pick-and-place action
        action performPickAndPlace(in workpiece : Workpiece, in dropOffPose : Pose) {
            var detection : DetectionResult = visionSensor.detectWorkpiece();
            var planCmd : MotionCommand = controller.planPath(detection.pose);
            controller.commandQueue := controller.commandQueue.append(planCmd);
            gripper.grasp(20.0);
            var dropCmd : MotionCommand = controller.planPath(dropOffPose);
            controller.commandQueue := controller.commandQueue.append(dropCmd);
            gripper.release();
        }
    }

    // ---------- Instances ----------
    part cobot : IndustrialRobot {
        attribute systemId = "Cobot_001";
    }
}
