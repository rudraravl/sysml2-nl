package RoboticManipulationSystem {

	import ScalarValues::*;
	import ISQ::*;
	import ISQSpace::*;
	import ISQForce::*;

	// ===== Value Types =====

	value def JointAngleValue :> Real { unit 'deg'; }
	value def JointTorqueValue :> Real { unit 'N*m'; }
	value def AngularVelocityValue :> Real { unit 'rad/s'; }
	value def LinearVelocityValue :> Real { unit 'm/s'; }
	value def ForceValue :> Real { unit 'N'; }
	value def DistanceValue :> Real { unit 'mm'; }
	value def MassValue :> Real { unit 'kg'; }
	value def DurationValue :> Real { unit 's'; }
	value def ConfidenceValue :> Real { :>> min = 0.0; :>> max = 1.0; }

	item def Pose {
		attribute x : DistanceValue;
		attribute y : DistanceValue;
		attribute z : DistanceValue;
		attribute roll : JointAngleValue;
		attribute pitch : JointAngleValue;
		attribute yaw : JointAngleValue;
	}

	item def JointState {
		attribute jointId : Integer;
		attribute angle : JointAngleValue;
		attribute velocity : AngularVelocityValue;
		attribute torque : JointTorqueValue;
	}

	item def JointCommand {
		attribute jointId : Integer;
		attribute targetAngle : JointAngleValue;
		attribute maxVelocity : AngularVelocityValue;
		attribute maxTorque : JointTorqueValue;
	}

	item def Waypoint {
		attribute sequence : Integer;
		attribute jointStates : JointState[1..7];
		attribute timeFromStart : DurationValue;
	}

	item def Trajectory {
		attribute id : String;
		attribute waypoints : Waypoint[1..*] ordered;
		attribute totalDuration : DurationValue;
		attribute smoothnessScore : Real;
	}

	item def ObstacleDescriptor {
		attribute id : String;
		attribute center : Pose;
		attribute boundingRadius : DistanceValue;
		attribute confidence : ConfidenceValue;
	}

	item def WorkspaceModel {
		attribute obstacles : ObstacleDescriptor[0..*];
		attribute armPose : Pose;
		attribute timestamp : String;
	}

	item def GraspCommand {
		attribute targetPose : Pose;
		attribute targetForce : ForceValue;
		attribute objectMass : MassValue;
	}

	item def TaskCommand {
		attribute id : String;
		attribute targetPose : Pose;
		attribute graspForce : ForceValue;
		attribute priority : Integer;
	}

	item def SafetyAlert {
		attribute alertType : String;
		attribute severity : Integer;
		attribute measuredValue : Real;
		attribute threshold : Real;
		attribute timestamp : String;
	}

	item def SensorFeedback {
		attribute jointStates : JointState[1..7];
		attribute gripperForce : ForceValue;
		attribute endEffectorPose : Pose;
		attribute timestamp : String;
	}

	// ===== Requirements =====

	requirement def ManipulatorArmSpec {
		subject arm : ManipulatorArm;
		requirement ReachRequirement {
			doc /* The arm shall reach up to 850mm. */
			require arm.maxReach == 850 [mm];
		}
		requirement PayloadRequirement {
			doc /* The arm shall handle payloads up to 5kg. */
			require arm.maxPayload == 5 [kg];
		}
		requirement JointCountRequirement {
			doc /* The arm shall have seven joints. */
			require arm.jointCount == 7;
		}
	}

	requirement def PlanningTimeRequirement {
		subject planner : MotionPlanningModule;
		doc /* Planning shall complete in under half a second. */
		require planner.maxPlanningTime < 0.5 [s];
	}

	requirement def TrackingAccuracyRequirement {
		subject controller : MotionController;
		doc /* The arm shall follow the trajectory within 2mm. */
		require controller.maxTrackingError <= 2 [mm];
	}

	requirement def SafetyClearanceRequirement {
		subject monitor : SafetyMonitor;
		doc /* The system shall maintain 50mm minimum clearance from obstacles. */
		require monitor.minObstacleClearance >= 50 [mm];
	}

	requirement def ForceHaltRequirement {
		subject monitor : SafetyMonitor;
		doc /* Contact force greater than 50N shall halt all motion. */
		require monitor.forceHaltThreshold == 50 [N];
	}

	requirement def SystemRequirements {
		subject system : RoboticManipulationSystem;
		satisfy ManipulatorArmSpec by system.arm;
		satisfy PlanningTimeRequirement by system.planningModule;
		satisfy TrackingAccuracyRequirement by system.motionController;
		satisfy SafetyClearanceRequirement by system.safetyMonitor;
		satisfy ForceHaltRequirement by system.safetyMonitor;
	}

	// ===== Parts =====

	part def ManipulatorJoint {
		attribute jointId : Integer;
		attribute minAngle : JointAngleValue;
		attribute maxAngle : JointAngleValue;
		attribute maxTorque : JointTorqueValue;
		attribute maxVelocity : AngularVelocityValue;
		port in jointCmd : JointCommand;
		port out jointState : JointState;
	}

	part def ManipulatorArm {
		attribute jointCount : Integer = 7;
		attribute maxReach : DistanceValue = 850 [mm];
		attribute maxPayload : MassValue = 5 [kg];
		part joints : ManipulatorJoint[7] {
			attribute jointId = 1;
		}
		port in armCommands : JointCommand[1..7];
		port out armFeedback : JointState[1..7];
		port out endEffectorPose : Pose;
		flow armCommands to joints.jointCmd;
		flow joints.jointState to armFeedback;
	}

	part def ForceSensor {
		attribute sensorId : String;
		attribute maxRange : ForceValue;
		attribute resolution : ForceValue;
		port out measuredForce : ForceValue;
	}

	part def AdaptiveGripper {
		attribute maxGripForce : ForceValue = 80 [N];
		attribute fingerCount : Integer = 2;
		part forceSensors : ForceSensor[2];
		port in graspCmd : GraspCommand;
		port out gripperForce : ForceValue;
		port out gripperPose : Pose;
		flow graspCmd to forceSensors;
		flow forceSensors.measuredForce to gripperForce;
	}

	part def PerceptionModule {
		attribute processingLatency : DurationValue = 0.05 [s];
		port in rawSensorData : SensorFeedback;
		port out workspaceModel : WorkspaceModel;
		action processPerception {
			in data : SensorFeedback;
			out model : WorkspaceModel;
		}
		flow rawSensorData to processPerception.data;
		flow processPerception.model to workspaceModel;
	}

	part def KinematicsEngine {
		attribute solveLatency : DurationValue = 0.1 [s];
		port in targetPose : Pose;
		port in currentJointStates : JointState[1..7];
		port out jointSolution : JointState[1..7];
		action solveIK {
			in target : Pose;
			in current : JointState[1..7];
			out solution : JointState[1..7];
		}
		flow targetPose to solveIK.target;
		flow currentJointStates to solveIK.current;
		flow solveIK.solution to jointSolution;
	}

	part def TrajectoryOptimizer {
		attribute optimizationLatency : DurationValue = 0.15 [s];
		port in jointSolution : JointState[1..7];
		port in obstacles : ObstacleDescriptor[0..*];
		port out trajectory : Trajectory;
		action optimizeTrajectory {
			in solution : JointState[1..7];
			in obs : ObstacleDescriptor[0..*];
			out traj : Trajectory;
		}
		flow jointSolution to optimizeTrajectory.solution;
		flow obstacles to optimizeTrajectory.obs;
		flow optimizeTrajectory.traj to trajectory;
	}

	part def MotionPlanningModule {
		attribute maxPlanningTime : DurationValue = 0.5 [s];
		part kinematicsEngine : KinematicsEngine;
		part trajectoryOptimizer : TrajectoryOptimizer;
		port in taskCommand : TaskCommand;
		port in workspaceModel : WorkspaceModel;
		port in currentJointStates : JointState[1..7];
		port out plannedTrajectory : Trajectory;
		connection kinematicsEngine.jointSolution to trajectoryOptimizer.jointSolution;
		flow taskCommand.targetPose to kinematicsEngine.targetPose;
		flow currentJointStates to kinematicsEngine.currentJointStates;
		flow workspaceModel.obstacles to trajectoryOptimizer.obstacles;
		flow trajectoryOptimizer.trajectory to plannedTrajectory;
	}

	part def MotionController {
		attribute maxTrackingError : DistanceValue = 2 [mm];
		attribute controlRate : Real = 1000; // Hz
		port in plannedTrajectory : Trajectory;
		port in sensorFeedback : SensorFeedback;
		port out jointCommands : JointCommand[1..7];
		action executeControl {
			in trajectory : Trajectory;
			in feedback : SensorFeedback;
			out commands : JointCommand[1..7];
		}
		flow plannedTrajectory to executeControl.trajectory;
		flow sensorFeedback to executeControl.feedback;
		flow executeControl.commands to jointCommands;
	}

	part def SafetyMonitor {
		attribute forceHaltThreshold : ForceValue = 50 [N];
		attribute minObstacleClearance : DistanceValue = 50 [mm];
		attribute monitoringActive : Boolean = true;
		port in sensorFeedback : SensorFeedback;
		port in workspaceModel : WorkspaceModel;
		port out safetyAlert : SafetyAlert;
		port out emergencyStop : Boolean;
		action monitorSafety {
			in feedback : SensorFeedback;
			in model : WorkspaceModel;
			out alert : SafetyAlert;
			out estop : Boolean;
		}
		flow sensorFeedback to monitorSafety.feedback;
		flow workspaceModel to monitorSafety.model;
		flow monitorSafety.alert to safetyAlert;
		flow monitorSafety.estop to emergencyStop;
	}

	part def RoboticManipulationSystem {
		part arm : ManipulatorArm;
		part gripper : AdaptiveGripper;
		part perceptionModule : PerceptionModule;
		part planningModule : MotionPlanningModule;
		part motionController : MotionController;
		part safetyMonitor : SafetyMonitor;
		port in externalTask : TaskCommand;
		port out systemStatus : String;
		connection arm.endEffectorPose to gripper.gripperPose;
		connection arm.armFeedback to perceptionModule.rawSensorData;
		connection perceptionModule.workspaceModel to planningModule.workspaceModel;
		connection perceptionModule.workspaceModel to safetyMonitor.workspaceModel;
		connection arm.armFeedback to planningModule.currentJointStates;
		connection planningModule.plannedTrajectory to motionController.plannedTrajectory;
		connection arm.armFeedback to motionController.sensorFeedback;
		connection motionController.jointCommands to arm.armCommands;
		connection arm.armFeedback to safetyMonitor.sensorFeedback;
		connection safetyMonitor.emergencyStop to motionController.jointCommands;
		flow externalTask to planningModule.taskCommand;
	}

	// ===== State Machine =====

	state def ManipulationStates {
		entry action { /* initialize system */ }
		exit action { /* cleanup */ }

		state idle {
			doc /* Waiting for instructions. */
			entry action { /* ready to receive task */ }
		}

		state planning {
			doc /* Planning a new move. */
			entry action { /* invoke motion planning */ }
			do action { /* compute trajectory */ }
			exit action { /* validate trajectory */ }
		}

		state executing {
			doc /* Executing the motion. */
			entry action { /* begin trajectory execution */ }
			do action { /* send joint commands, monitor feedback */ }
			exit action { /* confirm arrival */ }
		}

		state grasping {
			doc /* Grasping an object. */
			entry action { /* close gripper */ }
			do action { /* apply force control */ }
			exit action { /* verify grasp */ }
		}

		state emergencyHalted {
			doc /* Motion halted due to safety alert. */
			entry action { /* stop all joints */ }
		}

		transition from idle to planning
			when externalTask != null;

		transition from planning to executing
			when planningModule.plannedTrajectory != null
			if safetyMonitor.emergencyStop == false;

		transition from planning to emergencyHalted
			when safetyMonitor.emergencyStop == true;

		transition from executing to grasping
			when motionController.maxTrackingError <= 2 [mm]
			if arm.endEffectorPose == externalTask.targetPose;

		transition from executing to emergencyHalted
			when safetyMonitor.emergencyStop == true;

		transition from grasping to idle
			when gripper.gripperForce >= externalTask.graspForce;

		transition from grasping to emergencyHalted
			when safetyMonitor.emergencyStop == true;

		transition from emergencyHalted to idle
			when safetyMonitor.emergencyStop == false;
	}

	part manipulationSystemBehavior : RoboticManipulationSystem {
		exhibit ManipulationStates;
	}

}
