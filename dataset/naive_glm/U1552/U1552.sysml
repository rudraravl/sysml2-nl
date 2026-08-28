package RoboticArmManipulator {

    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types with Units =====

    value def AngleValue :> Real { unit = "deg"; }
    value def AngularVelocityValue :> Real { unit = "deg/s"; }
    value def AngularAccelerationValue :> Real { unit = "deg/s2"; }
    value def TorqueValue :> Real { unit = "N*m"; }
    value def ForceValue :> Real { unit = "N"; }
    value def MassValue :> Real { unit = "kg"; }
    value def LengthValue :> Real { unit = "m"; }
    value def VoltageValue :> Real { unit = "V"; }
    value def CurrentValue :> Real { unit = "A"; }
    value def TimeValue :> Real { unit = "s"; }

    // ===== Item Definitions =====

    item def JointAngle {
        attribute angle : AngleValue;
        attribute velocity : AngularVelocityValue;
        attribute acceleration : AngularAccelerationValue;
    }

    item def JointTorqueCommand {
        attribute jointId : String;
        attribute torque : TorqueValue;
    }

    item def Pose {
        attribute x : LengthValue;
        attribute y : LengthValue;
        attribute z : LengthValue;
        attribute roll : AngleValue;
        attribute pitch : AngleValue;
        attribute yaw : AngleValue;
    }

    item def Waypoint {
        attribute pose : Pose;
        attribute time : TimeValue;
    }

    item def Trajectory {
        attribute waypoints : Waypoint[0..*];
        attribute jointAngles : JointAngle[6];
    }

    item def MotionCommand {
        attribute targetPose : Pose;
        attribute maxVelocity : AngularVelocityValue;
    }

    item def PowerFlow {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
    }

    item def GraspedObject {
        attribute mass : MassValue;
    }

    // ===== Port Definitions =====

    port def JointCommandPort {
        out torqueCommand : JointTorqueCommand;
    }

    port def JointFeedbackPort {
        in jointState : JointAngle;
    }

    port def PowerPort {
        out power : PowerFlow;
    }

    port def MotionCommandPort {
        in command : MotionCommand;
    }

    port def TrajectoryPort {
        out trajectory : Trajectory;
    }

    port def EndEffectorPort {
        in graspForce : ForceValue;
        out object : GraspedObject;
    }

    // ===== Requirements =====

    requirement def PayloadRequirement {
        doc "The manipulator shall handle a maximum payload of 15 kg.";
        attribute maxPayload : MassValue = 15 [kg];
        subject payload : MassValue;
        require payload <= maxPayload;
    }

    requirement def WorkspaceRequirement {
        doc "The manipulator shall operate within a workspace radius of 1.5 m.";
        attribute maxRadius : LengthValue = 1.5 [m];
        subject reach : LengthValue;
        require reach <= maxRadius;
    }

    requirement def DOFRequirement {
        doc "The manipulator shall have six independent degrees of freedom.";
        attribute dofCount : Integer = 6;
        subject joints : Integer;
        require joints == dofCount;
    }

    requirement def PowerRequirement {
        doc "The system shall be powered by a dedicated 48 V supply.";
        attribute nominalVoltage : VoltageValue = 48 [V];
        subject supplyVoltage : VoltageValue;
        require supplyVoltage == nominalVoltage;
    }

    requirement def GraspForceRequirement {
        doc "The end-effector shall grasp objects with a specified force.";
        attribute minGraspForce : ForceValue = 20 [N];
        subject graspForce : ForceValue;
        require graspForce >= minGraspForce;
    }

    requirement def PositioningAccuracyRequirement {
        doc "The manipulator shall provide precise automated positioning and orientation.";
        attribute positionTolerance : LengthValue = 0.001 [m];
        attribute orientationTolerance : AngleValue = 0.1 [deg];
    }

    // ===== Actuator and Sensor Definitions =====

    part def JointActuator {
        attribute jointId : String;
        attribute maxTorque : TorqueValue = 50 [N*m];
        port commandIn : JointCommandPort;
        port powerIn : PowerPort;
        attribute appliedTorque : TorqueValue;

        action def applyTorque {
            in cmd : JointTorqueCommand;
            out torque : TorqueValue;
        }

        perform applyTorque;
    }

    part def PositionSensor {
        attribute jointId : String;
        attribute resolution : AngleValue = 0.01 [deg];
        port feedbackOut : JointFeedbackPort;
        attribute measuredAngle : AngleValue;
        attribute measuredVelocity : AngularVelocityValue;
        attribute measuredAcceleration : AngularAccelerationValue;

        action def measure {
            out state : JointAngle;
        }

        perform measure;
    }

    // ===== Joint Definitions =====

    part def RotatingJoint {
        attribute jointId : String;
        attribute minAngle : AngleValue;
        attribute maxAngle : AngleValue;
        attribute maxTorque : TorqueValue;
        attribute currentAngle : AngleValue;
        attribute currentVelocity : AngularVelocityValue;
        attribute currentAcceleration : AngularAccelerationValue;

        port commandPort : JointCommandPort;
        port feedbackPort : JointFeedbackPort;
        port powerPort : PowerPort;

        part actuator : JointActuator {
            attribute jointId = jointId;
        }
        part sensor : PositionSensor {
            attribute jointId = jointId;
        }

        connection actuator.commandIn <> commandPort;
        connection sensor.feedbackOut <> feedbackPort;
        connection actuator.powerIn <> powerPort;

        action def rotate {
            in targetAngle : AngleValue;
        }
    }

    part def BaseJoint :> RotatingJoint {
        attribute minAngle = -180 [deg];
        attribute maxAngle = 180 [deg];
        attribute maxTorque = 100 [N*m];
    }

    part def ShoulderJoint :> RotatingJoint {
        attribute minAngle = -90 [deg];
        attribute maxAngle = 90 [deg];
        attribute maxTorque = 120 [N*m];
    }

    part def ElbowJoint :> RotatingJoint {
        attribute minAngle = -135 [deg];
        attribute maxAngle = 135 [deg];
        attribute maxTorque = 80 [N*m];
    }

    part def WristRollJoint :> RotatingJoint {
        attribute minAngle = -180 [deg];
        attribute maxAngle = 180 [deg];
        attribute maxTorque = 30 [N*m];
    }

    part def WristPitchJoint :> RotatingJoint {
        attribute minAngle = -90 [deg];
        attribute maxAngle = 90 [deg];
        attribute maxTorque = 30 [N*m];
    }

    part def WristYawJoint :> RotatingJoint {
        attribute minAngle = -180 [deg];
        attribute maxAngle = 180 [deg];
        attribute maxTorque = 25 [N*m];
    }

    // ===== Link Definitions =====

    part def StructuralLink {
        attribute length : LengthValue;
        attribute mass : MassValue;
        attribute material : String;
    }

    part def UpperArmLink :> StructuralLink {
        attribute length = 0.6 [m];
        attribute mass = 5.0 [kg];
        attribute material = "Aluminum 6061";
    }

    part def ForearmLink :> StructuralLink {
        attribute length = 0.5 [m];
        attribute mass = 3.0 [kg];
        attribute material = "Aluminum 6061";
    }

    part def WristLink :> StructuralLink {
        attribute length = 0.15 [m];
        attribute mass = 1.0 [kg];
        attribute material = "Aluminum 6061";
    }

    // ===== End-Effector Definition =====

    part def EndEffector {
        attribute maxGraspForce : ForceValue = 50 [N];
        attribute currentGraspForce : ForceValue;
        attribute isGrasping : Boolean = false;

        port toolPort : EndEffectorPort;
        port powerPort : PowerPort;

        action def grasp {
            in force : ForceValue;
            in object : GraspedObject;
        }

        action def release {
            out object : GraspedObject;
        }

        perform grasp;
        perform release;
    }

    // ===== Control System Definitions =====

    part def MotionPlanner {
        attribute planningHorizon : TimeValue = 10 [s];
        attribute maxWaypoints : Integer = 100;

        port commandIn : MotionCommandPort;
        port trajectoryOut : TrajectoryPort;

        action def solveInverseKinematics {
            in targetPose : Pose;
            out jointAngles : JointAngle[6];
        }

        action def generateWaypoints {
            in startPose : Pose;
            in targetPose : Pose;
            out waypoints : Waypoint[0..*];
        }

        action def planTrajectory {
            in command : MotionCommand;
            out trajectory : Trajectory;
        }

        perform planTrajectory;
    }

    part def MotionController {
        attribute controlRate : TimeValue = 0.001 [s];
        attribute safetyEnabled : Boolean = true;

        port trajectoryIn : TrajectoryPort;
        port jointCommandsOut : JointCommandPort[6];
        port jointFeedbackIn : JointFeedbackPort[6];

        action def computeTorqueCommands {
            in trajectory : Trajectory;
            in feedback : JointAngle[6];
            out commands : JointTorqueCommand[6];
        }

        action def checkSafetyLimits {
            in jointAngles : JointAngle[6];
            out violations : Boolean;
        }

        action def controlLoop {
            in trajectory : Trajectory;
            out commands : JointTorqueCommand[6];
        }

        perform controlLoop;
    }

    // ===== Power Supply Definition =====

    part def PowerSupply {
        attribute nominalVoltage : VoltageValue = 48 [V];
        attribute maxCurrent : CurrentValue = 50 [A];
        attribute outputVoltage : VoltageValue = 48 [V];

        port powerOut : PowerPort;

        action def regulatePower {
            out power : PowerFlow;
        }

        perform regulatePower;
    }

    // ===== Main Robotic Arm Assembly =====

    part def RoboticArmManipulator {
        satisfy PayloadRequirement;
        satisfy WorkspaceRequirement;
        satisfy DOFRequirement;
        satisfy PowerRequirement;
        satisfy GraspForceRequirement;
        satisfy PositioningAccuracyRequirement;

        attribute maxPayload : MassValue = 15 [kg];
        attribute workspaceRadius : LengthValue = 1.5 [m];
        attribute dofCount : Integer = 6;

        // Power
        part powerSupply : PowerSupply;

        // Structural Links
        part upperArm : UpperArmLink;
        part forearm : ForearmLink;
        part wrist : WristLink;

        // Six Joints
        part baseJoint : BaseJoint {
            attribute jointId = "J1_base";
        }
        part shoulderJoint : ShoulderJoint {
            attribute jointId = "J2_shoulder";
        }
        part elbowJoint : ElbowJoint {
            attribute jointId = "J3_elbow";
        }
        part wristRollJoint : WristRollJoint {
            attribute jointId = "J4_wrist_roll";
        }
        part wristPitchJoint : WristPitchJoint {
            attribute jointId = "J5_wrist_pitch";
        }
        part wristYawJoint : WristYawJoint {
            attribute jointId = "J6_wrist_yaw";
        }

        // End-Effector
        part endEffector : EndEffector;

        // Control System
        part motionPlanner : MotionPlanner;
        part motionController : MotionController;

        // External command port
        port commandPort : MotionCommandPort;

        // Power distribution connections
        connection powerSupply.powerOut to baseJoint.powerPort;
        connection powerSupply.powerOut to shoulderJoint.powerPort;
        connection powerSupply.powerOut to elbowJoint.powerPort;
        connection powerSupply.powerOut to wristRollJoint.powerPort;
        connection powerSupply.powerOut to wristPitchJoint.powerPort;
        connection powerSupply.powerOut to wristYawJoint.powerPort;
        connection powerSupply.powerOut to endEffector.powerPort;

        // Command flow: external command -> planner
        connection commandPort to motionPlanner.commandIn;

        // Trajectory flow: planner -> controller
        connection motionPlanner.trajectoryOut to motionController.trajectoryIn;

        // Joint command connections: controller -> joints
        connection motionController.jointCommandsOut[1] to baseJoint.commandPort;
        connection motionController.jointCommandsOut[2] to shoulderJoint.commandPort;
        connection motionController.jointCommandsOut[3] to elbowJoint.commandPort;
        connection motionController.jointCommandsOut[4] to wristRollJoint.commandPort;
        connection motionController.jointCommandsOut[5] to wristPitchJoint.commandPort;
        connection motionController.jointCommandsOut[6] to wristYawJoint.commandPort;

        // Feedback connections: joints -> controller
        connection baseJoint.feedbackPort to motionController.jointFeedbackIn[1];
        connection shoulderJoint.feedbackPort to motionController.jointFeedbackIn[2];
        connection elbowJoint.feedbackPort to motionController.jointFeedbackIn[3];
        connection wristRollJoint.feedbackPort to motionController.jointFeedbackIn[4];
        connection wristPitchJoint.feedbackPort to motionController.jointFeedbackIn[5];
        connection wristYawJoint.feedbackPort to motionController.jointFeedbackIn[6];

        // Structural assembly: links connected by joints
        connection baseJoint to upperArm;
        connection upperArm to shoulderJoint;
        connection shoulderJoint to forearm;
        connection forearm to elbowJoint;
        connection elbowJoint to wrist;
        connection wrist to wristRollJoint;
        connection wristRollJoint to wristPitchJoint;
        connection wristPitchJoint to wristYawJoint;
        connection wristYawJoint to endEffector;

        // ===== State Machine Behavior =====

        state def ManipulatorStateMachine {
            attribute currentPose : Pose;
            attribute targetPose : Pose;
            attribute isReachable : Boolean;
            attribute hasError : Boolean;

            state idle {
                entry action {
                    log "Entering idle state";
                }
                transition idle_to_planning
                    first idle
                    if commandPort.command.targetPose != null
                    then planning;
            }

            state planning {
                entry action {
                    log "Validating target reachability";
                    // Validate target is within workspace
                    if (targetPose.x * targetPose.x + targetPose.y * targetPose.y + targetPose.z * targetPose.z <= workspaceRadius * workspaceRadius) {
                        isReachable = true;
                    } else {
                        isReachable = false;
                    }
                }
                do action {
                    // Motion planner computes trajectory
                    send commandPort.command to motionPlanner.commandIn;
                }
                transition planning_to_executing
                    first planning
                    if isReachable
                    then executing;
                transition planning_to_error
                    first planning
                    if !isReachable
                    then errorState;
            }

            state executing {
                entry action {
                    log "Executing motion trajectory";
                }
                do action {
                    // Controller drives joints along trajectory
                    // Monitor for safety violations
                    if (baseJoint.currentAngle < baseJoint.minAngle | baseJoint.currentAngle > baseJoint.maxAngle) {
                        hasError = true;
                    }
                    if (shoulderJoint.currentAngle < shoulderJoint.minAngle | shoulderJoint.currentAngle > shoulderJoint.maxAngle) {
                        hasError = true;
                    }
                    if (elbowJoint.currentAngle < elbowJoint.minAngle | elbowJoint.currentAngle > elbowJoint.maxAngle) {
                        hasError = true;
                    }
                }
                transition executing_to_idle
                    first executing
                    if !hasError & motionComplete
                    then idle;
                transition executing_to_error
                    first executing
                    if hasError
                    then errorState;
            }

            state errorState {
                entry action {
                    log "Safety violation detected - entering error state";
                    // Stop all joint motion
                }
                do action {
                    // Halt all actuators
                    // Await operator reset
                }
                transition error_to_idle
                    first errorState
                    if resetCommandReceived
                    then idle;
            }

            attribute motionComplete : Boolean;
            attribute resetCommandReceived : Boolean;
        }

        part behavior : ManipulatorStateMachine;

        // Initialization
        action def initialize {
            // Power on sequence
            powerSupply.regulatePower();
            // Home all joints
            baseJoint.currentAngle = 0 [deg];
            shoulderJoint.currentAngle = 0 [deg];
            elbowJoint.currentAngle = 0 [deg];
            wristRollJoint.currentAngle = 0 [deg];
            wristPitchJoint.currentAngle = 0 [deg];
            wristYawJoint.currentAngle = 0 [deg];
            // Enter idle state
            behavior.idle.entry();
        }

        perform initialize;
    }

}
