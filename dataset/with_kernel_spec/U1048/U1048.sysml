package RoboticManipulationSystem {
	private import ScalarValues::*;

	attribute def LengthValue :> Real { unit = "mm"; }
	attribute def MassValue :> Real { unit = "kg"; }
	attribute def ForceValue :> Real { unit = "N"; }
	attribute def TimeValue :> Real { unit = "s"; }
	attribute def AngleValue :> Real { unit = "rad"; }

	attribute def Pose {
		x : LengthValue;
		y : LengthValue;
		z : LengthValue;
		roll : AngleValue;
		pitch : AngleValue;
		yaw : AngleValue;
	}

	attribute def JointAngles {
		angles[7] : AngleValue;
	}

	attribute def Obstacle {
		position : Pose;
		boundingRadius : LengthValue;
	}

	item def TargetCommand {
		targetPose : Pose;
	}

	item def Trajectory {
		waypoints[*] : Pose;
	}

	item def JointCommand {
		angles : JointAngles;
	}

	item def SensorFeedback {
		jointAngles : JointAngles;
		contactForce : ForceValue;
	}

	item def GraspCommand;
	item def DoneSignal;

	part def ManipulatorArm {
		attribute maxReach : LengthValue = 850;
		attribute maxPayload : MassValue = 5;
		port jointCommandPort {
			in jointCommand : JointCommand;
		}
		port feedbackPort {
			out feedback : SensorFeedback;
		}
		part joints[7] : Joint;
	}

	part def Joint {
		port commandPort {
			in angle : AngleValue;
		}
		port feedbackPort {
			out currentAngle : AngleValue;
		}
	}

	part def AdaptiveGripper {
		port commandPort {
			in gripForce : ForceValue;
		}
		port feedbackPort {
			out measuredForce : ForceValue;
		}
		part forceSensor : ForceSensor;
	}

	part def ForceSensor {
		port outputPort {
			out force : ForceValue;
		}
	}

	part def PerceptionModule {
		port feedbackPort {
			in feedback : SensorFeedback;
		}
		port environmentPort {
			out obstacles[*] : Obstacle;
		}
		port posePort {
			out currentPose : Pose;
		}
	}

	part def KinematicsEngine {
		port targetCommandPort {
			in targetCommand : TargetCommand;
		}
		port jointAnglesPort {
			out jointAngles : JointAngles;
		}
	}

	part def TrajectoryOptimizer {
		port jointAnglesPort {
			in jointAngles : JointAngles;
		}
		port trajectoryPort {
			out trajectory : Trajectory;
		}
	}

	part def MotionPlanningModule {
		port targetCommandPort {
			in targetCommand : TargetCommand;
		}
		port environmentPort {
			in obstacles[*] : Obstacle;
		}
		port currentPosePort {
			in currentPose : Pose;
		}
		port trajectoryPort {
			out trajectory : Trajectory;
		}
		attribute maxPlanningTime : TimeValue = 0.5;

		part kinematicsEngine : KinematicsEngine;
		part trajectoryOptimizer : TrajectoryOptimizer;

		flow targetCommandFlow of TargetCommand
			from targetCommandPort.targetCommand to kinematicsEngine.targetCommandPort.targetCommand;
		flow jointAnglesFlow of JointAngles
			from kinematicsEngine.jointAnglesPort.jointAngles to trajectoryOptimizer.jointAnglesPort.jointAngles;
		flow trajectoryFlow of Trajectory
			from trajectoryOptimizer.trajectoryPort.trajectory to trajectoryPort.trajectory;
	}

	part def MotionController {
		port trajectoryPort {
			in trajectory : Trajectory;
		}
		port feedbackPort {
			in feedback : SensorFeedback;
		}
		port jointCommandPort {
			out jointCommand : JointCommand;
		}
		attribute positionAccuracy : LengthValue = 2;
	}

	part def SafetyMonitor {
		port feedbackPort {
			in feedback : SensorFeedback;
		}
		port environmentPort {
			in obstacles[*] : Obstacle;
		}
		port currentPosePort {
			in currentPose : Pose;
		}
		port haltPort {
			out haltSignal : Boolean;
		}
		attribute maxContactForce : ForceValue = 50;
		attribute minClearance : LengthValue = 50;
	}

	requirement def ArmReachRequirement {
		doc /* The arm must reach up to 850mm. */
		attribute maxReach : LengthValue = 850;
	}

	requirement def PayloadRequirement {
		doc /* The arm must handle payloads of up to 5kg. */
		attribute maxPayload : MassValue = 5;
	}

	requirement def PlanningTimeRequirement {
		doc /* Planning must complete in under half a second. */
		attribute maxPlanningTime : TimeValue = 0.5;
	}

	requirement def PositionAccuracyRequirement {
		doc /* Motion controller must maintain accuracy within 2mm. */
		attribute positionAccuracy : LengthValue = 2;
	}

	requirement def ForceLimitRequirement {
		doc /* Halt motion if contact force exceeds 50N. */
		attribute maxContactForce : ForceValue = 50;
	}

	requirement def ClearanceRequirement {
		doc /* Maintain minimum clearance of 50mm from obstacles. */
		attribute minClearance : LengthValue = 50;
	}

	part def RoboticSystem {
		port taskPort {
			in targetCommand : TargetCommand;
		}

		part arm : ManipulatorArm;
		part gripper : AdaptiveGripper;
		part perception : PerceptionModule;
		part planner : MotionPlanningModule;
		part controller : MotionController;
		part safetyMonitor : SafetyMonitor;

		flow targetCommandFlow of TargetCommand
			from taskPort.targetCommand to planner.targetCommandPort.targetCommand;
		flow obstaclesFlow of Obstacle
			from perception.environmentPort.obstacles to planner.environmentPort.obstacles;
		flow currentPoseFlow of Pose
			from perception.posePort.currentPose to planner.currentPosePort.currentPose;
		flow trajectoryFlow of Trajectory
			from planner.trajectoryPort.trajectory to controller.trajectoryPort.trajectory;
		flow jointCommandFlow of JointCommand
			from controller.jointCommandPort.jointCommand to arm.jointCommandPort.jointCommand;
		flow feedbackFlow of SensorFeedback
			from arm.feedbackPort.feedback to controller.feedbackPort.feedback;
		flow feedbackToPerceptionFlow of SensorFeedback
			from arm.feedbackPort.feedback to perception.feedbackPort.feedback;
		flow feedbackToSafetyFlow of SensorFeedback
			from arm.feedbackPort.feedback to safetyMonitor.feedbackPort.feedback;
		flow obstaclesToSafetyFlow of Obstacle
			from perception.environmentPort.obstacles to safetyMonitor.environmentPort.obstacles;
		flow poseToSafetyFlow of Pose
			from perception.posePort.currentPose to safetyMonitor.currentPosePort.currentPose;

		state def SystemStates {
			entry; then idle;
			state idle;
			state planning;
			state executing;
			state grasping;

			transition first idle
				accept cmd : TargetCommand
				then planning;
			transition first planning
				accept trajReady : Trajectory
				then executing;
			transition first executing
				accept graspCmd : GraspCommand
				then grasping;
			transition first grasping
				accept doneSig : DoneSignal
				then idle;
			transition first executing
				accept halt : Boolean
				then idle;
		}

		state mode : SystemStates;

		requirement armReachReq : ArmReachRequirement;
		requirement payloadReq : PayloadRequirement;
		requirement planningTimeReq : PlanningTimeRequirement;
		requirement positionAccuracyReq : PositionAccuracyRequirement;
		requirement forceLimitReq : ForceLimitRequirement;
		requirement clearanceReq : ClearanceRequirement;

		satisfy armReachReq by arm;
		satisfy payloadReq by arm;
		satisfy planningTimeReq by planner;
		satisfy positionAccuracyReq by controller;
		satisfy forceLimitReq by safetyMonitor;
		satisfy clearanceReq by safetyMonitor;
	}
}
