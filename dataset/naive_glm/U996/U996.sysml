package WAMRobotSystem {
    import ScalarValues::*;
    import SI::*;

    // ===== Value Types =====
    value type Torque :> Real;
    value type JointAngle :> Real;
    value type AngularVelocity :> Real;
    value type Force :> Real;
    value type Mass :> Real;
    value type Length :> Real;
    value type Pressure :> Real;
    value type Current :> Real;

    // ===== Item Definitions =====
    item def JointCommand {
        attribute targetAngle : JointAngle;
        attribute targetVelocity : AngularVelocity;
    }

    item def PositionFeedback {
        attribute measuredAngle : JointAngle;
    }

    item def TorqueFeedback {
        attribute measuredTorque : Torque;
    }

    item def TactileData {
        attribute contactForce : Force;
        attribute pressure : Pressure;
    }

    item def TrajectoryPoint {
        attribute jointPositions : JointAngle[7];
        attribute jointVelocities : AngularVelocity[7];
    }

    item def CartesianTarget {
        attribute x : Length;
        attribute y : Length;
        attribute z : Length;
    }

    item def EmergencyStopSignal;
    item def GraspCommand;
    item def ReleaseCommand;
    item def MoveCommand {
        attribute target : CartesianTarget;
    }
    item def TrajectoryComplete;
    item def GraspComplete;
    item def ReleaseComplete;
    item def ResetCommand;

    // ===== Port Definitions =====
    port def CommandPort {
        out command : JointCommand;
    }

    port def FeedbackPort {
        in position : PositionFeedback;
        in torque : TorqueFeedback;
    }

    port def TactilePort {
        in data : TactileData;
    }

    port def EmergencyPort {
        in stop : EmergencyStopSignal;
    }

    port def TrajectoryPort {
        out trajectory : TrajectoryPoint;
    }

    port def CartesianPort {
        in target : CartesianTarget;
    }

    port def BrakeControlPort {
        out engage : Boolean;
    }

    port def HandCommandPort {
        out grasp : GraspCommand;
        out release : ReleaseCommand;
    }

    // ===== Action Definitions =====
    action def PlanTrajectory {
        in target : CartesianTarget;
        out trajectory : TrajectoryPoint;
    }

    action def SolveInverseKinematics {
        in target : CartesianTarget;
        out jointCommands : JointCommand[7];
    }

    action def MonitorSafety {
        in torque : Torque;
        in velocity : AngularVelocity;
        out trigger : Boolean;
    }

    action def ExecuteGrasp {
        in grasp : GraspCommand;
        out complete : GraspComplete;
    }

    // ===== Part Definitions =====

    part def BrushlessMotor {
        attribute ratedTorque : Torque = 5.0 [N*m];
        port powerIn { in current : Current; }
        port shaftOut { out torque : Torque; }
    }

    part def CableDriveTransmission {
        attribute gearRatio : Real = 100.0;
        attribute friction : Torque = 0.01 [N*m];
        attribute backdrivable : Boolean = true;
        port driveIn { in torque : Torque; }
        port driveOut { out torque : Torque; }
    }

    part def ElectromagneticBrake {
        attribute engaged : Boolean = false;
        port brakeControl : ~BrakeControlPort;
    }

    part def PositionEncoder {
        attribute resolution : Integer = 4096;
        port encoderOut { out position : PositionFeedback; }
    }

    part def TorqueSensor {
        attribute range : Torque = 50.0 [N*m];
        port torqueOut { out torque : TorqueFeedback; }
    }

    part def Joint {
        attribute index : Integer;
        attribute currentAngle : JointAngle = 0.0 [rad];
        attribute currentVelocity : AngularVelocity = 0.0 [rad/s];
        attribute currentTorque : Torque = 0.0 [N*m];

        part motor : BrushlessMotor;
        part transmission : CableDriveTransmission;
        part brake : ElectromagneticBrake;
        part encoder : PositionEncoder;
        part torqueSensor : TorqueSensor;

        port commandIn : ~CommandPort;
        port feedbackOut {
            out position : PositionFeedback;
            out torque : TorqueFeedback;
        }

        connection motorToTransmission connect motor.shaftOut to transmission.driveIn;
        connection encoderToFeedback connect encoder.encoderOut to feedbackOut;
        connection torqueToFeedback connect torqueSensor.torqueOut to feedbackOut;
    }

    part def TactileSensor {
        attribute sensitivity : Pressure = 1.0 [Pa];
        port tactileOut { out data : TactileData; }
    }

    part def FingerLink {
        attribute length : Length;
    }

    part def Finger {
        attribute fingerIndex : Integer;
        attribute spreadAngle : JointAngle = 0.0 [rad];
        attribute linkCount : Integer = 3;

        part links : FingerLink[3];
        part tactileSensors : TactileSensor[3];
        part tendonActuator : BrushlessMotor;

        port commandIn : ~CommandPort;
        port tactileOut : ~TactilePort;

        connection tactileFeedback connect tactileSensors.tactileOut to tactileOut;
    }

    part def BarrettHand {
        attribute maxGraspForce : Force = 30.0 [N];
        attribute canSpread : Boolean = true;
        attribute fingerCount : Integer = 3;

        part fingers : Finger[3];

        port handCommandIn : ~HandCommandPort;
        port commandOut : CommandPort;
        port tactileOut : ~TactilePort;

        connection commandToFingers connect commandOut to fingers.commandIn;
        connection tactileAggregate connect fingers.tactileOut to tactileOut;
    }

    part def MotionPlanner {
        port cartesianIn : ~CartesianPort;
        port trajectoryOut : TrajectoryPort;

        action planTrajectory : PlanTrajectory;
    }

    part def KinematicsSolver {
        port trajectoryIn : ~TrajectoryPort;
        port commandOut : CommandPort;

        action solveInverseKinematics : SolveInverseKinematics;
    }

    part def SafetyController {
        attribute maxTorque : Torque = 50.0 [N*m];
        attribute maxVelocity : AngularVelocity = 3.0 [rad/s];
        attribute safetyTriggered : Boolean = false;

        port feedbackIn : FeedbackPort;
        port tactileIn : TactilePort;
        port emergencyIn : EmergencyPort;
        port brakeEngageOut : BrakeControlPort;
        port motionHaltOut { out halt : Boolean; }

        action monitorSafety : MonitorSafety;
    }

    part def ControlSystem {
        part motionPlanner : MotionPlanner;
        part kinematicsSolver : KinematicsSolver;
        part safetyController : SafetyController;

        port cartesianIn : ~CartesianPort;
        port feedbackIn : FeedbackPort;
        port tactileIn : TactilePort;
        port emergencyIn : EmergencyPort;
        port commandOut : CommandPort;
        port brakeOut : BrakeControlPort;

        connection planToSolve connect motionPlanner.trajectoryOut to kinematicsSolver.trajectoryIn;
        connection solveToCommand connect kinematicsSolver.commandOut to commandOut;
        connection safetyFeedback connect feedbackIn to safetyController.feedbackIn;
        connection safetyTactile connect tactileIn to safetyController.tactileIn;
        connection safetyEmergency connect emergencyIn to safetyController.emergencyIn;
        connection safetyBrake connect safetyController.brakeEngageOut to brakeOut;
        connection cartesianToPlanner connect cartesianIn to motionPlanner.cartesianIn;
    }

    part def WAMArm {
        attribute reach : Length = 1.0 [m];
        attribute payloadCapacity : Mass = 3.0 [kg];
        attribute jointCount : Integer = 7;

        part joints : Joint[7];
        part hand : BarrettHand;

        port commandIn : ~CommandPort;
        port feedbackOut {
            out position : PositionFeedback;
            out torque : TorqueFeedback;
        }
        port tactileOut : ~TactilePort;
        port handCommandIn : ~HandCommandPort;
        port brakeIn : ~BrakeControlPort;

        connection commandToJoints connect commandIn to joints.commandIn;
        connection jointFeedback connect joints.feedbackOut to feedbackOut;
        connection handTactile connect hand.tactileOut to tactileOut;
        connection handCommandDelegation connect handCommandIn to hand.handCommandIn;
        connection brakeDelegation connect brakeIn to joints.brake.brakeControl;
    }

    part def WAMRobot {
        attribute systemActive : Boolean = true;
        attribute manufacturer : String = "Barrett Technology";
        attribute model : String = "WAM";

        part arm : WAMArm;
        part control : ControlSystem;

        port cartesianCommand : ~CartesianPort;
        port emergencyStop : EmergencyPort;
        port handCommand : HandCommandPort;

        connection controlToArm connect control.commandOut to arm.commandIn;
        connection armFeedback connect arm.feedbackOut to control.feedbackIn;
        connection armTactileToControl connect arm.tactileOut to control.tactileIn;
        connection cartesianToControl connect cartesianCommand to control.cartesianIn;
        connection emergencyToControl connect emergencyStop to control.emergencyIn;
        connection handCommandToArm connect handCommand to arm.handCommandIn;
        connection brakeToArm connect control.brakeOut to arm.brakeIn;

        state operationalState {
            entry; then Idle;

            state Idle {
                entry {
                    /* System waiting for command; brakes disengaged, motors idle */
                }
            }

            state Moving {
                entry {
                    /* Executing trajectory; motion planner and kinematics solver active */
                }
            }

            state Grasping {
                entry {
                    /* BarrettHand fingers closing around object; tactile sensors monitoring */
                }
            }

            state Releasing {
                entry {
                    /* BarrettHand fingers opening to release object */
                }
            }

            state Holding {
                entry {
                    /* Object securely held; joint brakes engaged to maintain position */
                }
            }

            state EmergencyStopped {
                entry {
                    /* All motion halted; all electromagnetic brakes engaged */
                }
            }

            transition Idle_to_Moving
                first Idle
                accept MoveCommand
                then Moving;

            transition Moving_to_Grasping
                first Moving
                accept GraspCommand
                then Grasping;

            transition Moving_to_Idle
                first Moving
                accept TrajectoryComplete
                then Idle;

            transition Grasping_to_Holding
                first Grasping
                accept GraspComplete
                then Holding;

            transition Holding_to_Releasing
                first Holding
                accept ReleaseCommand
                then Releasing;

            transition Releasing_to_Idle
                first Releasing
                accept ReleaseComplete
                then Idle;

            transition Idle_to_Emergency
                first Idle
                accept EmergencyStopSignal
                then EmergencyStopped;

            transition Moving_to_Emergency
                first Moving
                accept EmergencyStopSignal
                then EmergencyStopped;

            transition Grasping_to_Emergency
                first Grasping
                accept EmergencyStopSignal
                then EmergencyStopped;

            transition Holding_to_Emergency
                first Holding
                accept EmergencyStopSignal
                then EmergencyStopped;

            transition Releasing_to_Emergency
                first Releasing
                accept EmergencyStopSignal
                then EmergencyStopped;

            transition Emergency_to_Idle
                first EmergencyStopped
                accept ResetCommand
                then Idle;
        }
    }

    // ===== Requirements =====
    requirement def ReachRequirement {
        doc /* The robotic arm shall have a maximum reach of one meter. */
        attribute maxReach : Length = 1.0 [m];
    }

    requirement def PayloadRequirement {
        doc /* The robotic arm shall handle objects weighing up to 3 kilograms. */
        attribute maxPayload : Mass = 3.0 [kg];
    }

    requirement def SevenJointRequirement {
        doc /* The arm shall have seven joints providing shoulder, elbow, and multi-axis wrist dexterity. */
        attribute jointCount : Integer = 7;
    }

    requirement def BackdrivabilityRequirement {
        doc /* Each joint shall use a cable-drive transmission enabling low-friction, backdrivable movement for safe hand-guided teaching. */
    }

    requirement def BrakeRequirement {
        doc /* Each joint shall be equipped with an electromagnetic brake to hold its position securely. */
    }

    requirement def BrushlessMotorRequirement {
        doc /* Each joint shall be powered by a brushless motor. */
    }

    requirement def BarrettHandRequirement {
        doc /* The system shall include a three-fingered BarrettHand with adaptive grip and finger spread capability. */
        attribute fingerCount : Integer = 3;
    }

    requirement def TactileSensingRequirement {
        doc /* Each finger shall be equipped with tactile sensors providing touch and force feedback. */
    }

    requirement def ControlSystemRequirement {
        doc /* An integrated control system shall include a motion planner and inverse kinematics solver to translate target hand positions into joint angles. */
    }

    requirement def SensorFeedbackRequirement {
        doc /* Each joint shall have position encoders and torque sensors providing real-time feedback for precise control and force monitoring. */
    }

    requirement def SafetyMonitoringRequirement {
        doc /* A dedicated safety controller shall continuously monitor joint torques and velocities to detect collisions or excessive forces. */
        attribute maxTorque : Torque = 50.0 [N*m];
        attribute maxVelocity : AngularVelocity = 3.0 [rad/s];
    }

    requirement def EmergencyStopRequirement {
        doc /* Upon detecting a fault or receiving an emergency stop command, the system shall immediately halt all motion and engage all electromagnetic brakes. */
    }

    requirement def OperationalStatesRequirement {
        doc /* The system shall transition through idle, moving, grasping, releasing, holding, and emergency stopped operational states. */
    }

    part wamRobotSystem : WAMRobot {
        satisfy ReachRequirement by arm.reach;
        satisfy PayloadRequirement by arm.payloadCapacity;
        satisfy SevenJointRequirement by arm.jointCount;
        satisfy BackdrivabilityRequirement by arm.joints.transmission;
        satisfy BrakeRequirement by arm.joints.brake;
        satisfy BrushlessMotorRequirement by arm.joints.motor;
        satisfy BarrettHandRequirement by arm.hand;
        satisfy TactileSensingRequirement by arm.hand.fingers.tactileSensors;
        satisfy ControlSystemRequirement by control;
        satisfy SensorFeedbackRequirement by arm.joints.encoder;
        satisfy SafetyMonitoringRequirement by control.safetyController;
        satisfy EmergencyStopRequirement by control.safetyController;
        satisfy OperationalStatesRequirement by operationalState;
    }
}
