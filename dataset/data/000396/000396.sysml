package 'Robotic System Model' {
	private import ScalarValues::*;
	private import ISQ::*;
	
	attribute def Position3D {
		attribute x : LengthValue;
		attribute y : LengthValue;
		attribute z : LengthValue;
	}
	
	attribute def Velocity3D {
		attribute vx : SpeedValue;
		attribute vy : SpeedValue;
		attribute vz : SpeedValue;
	}
	
	attribute def Force3D {
		attribute fx : ForceValue;
		attribute fy : ForceValue;
		attribute fz : ForceValue;
	}
	
	attribute def Torque3D {
		attribute tx : TorqueValue;
		attribute ty : TorqueValue;
		attribute tz : TorqueValue;
	}
	
	item def Workpiece {
		attribute mass : MassValue;
		attribute position : Position3D;
	}
	
	item def ElectricalPower;
	item def ControlSignal;
	
	enum def RobotState {
		enum idle;
		enum sensing;
		enum planning;
		enum moving;
		enum gripping;
		enum processing;
		enum releasing;
		enum error;
	}
	
	enum def GripperState {
		enum open;
		enum closed;
		enum partial;
	}
	
	port def PowerPort {
		item power : ElectricalPower;
		attribute voltage : Real;
		attribute current : Real;
	}
	
	port def ControlPort {
		item signal : ControlSignal;
		in attribute command : String;
		out attribute status : String;
	}
	
	port def SensorPort {
		out attribute position : Position3D;
		out attribute force : Force3D;
	}
	
	action def SenseEnvironment {
		out currentPosition : Position3D;
		out detectedForce : Force3D;
	}
	
	action def PlanTrajectory {
		in startPosition : Position3D;
		in targetPosition : Position3D;
		out plannedVelocity : Velocity3D;
	}
	
	action def MoveToTarget {
		in velocity : Velocity3D;
		out finalPosition : Position3D;
	}
	
	action def GraspWorkpiece {
		in gripForce : Force3D;
		out graspedItem : Workpiece;
	}
	
	action def ProcessWorkpiece {
		in workpiece : Workpiece;
		out processedWorkpiece : Workpiece;
	}
	
	action def ReleaseWorkpiece {
		in workpiece : Workpiece;
		out releasePosition : Position3D;
	}
	
	part def Joint {
		attribute maxTorque : TorqueValue;
		attribute maxSpeed : Real;
		attribute currentAngle : Real;
		port powerIn : PowerPort;
	}
	
	part def Gripper {
		attribute gripStrength : ForceValue;
		attribute gripperState : GripperState;
		part leftFinger {
			attribute force : ForceValue;
		}
		part rightFinger {
			attribute force : ForceValue;
		}
		port powerIn : PowerPort;
	}
	
	part def RobotArm {
		attribute reachDistance : LengthValue;
		part baseJoint : Joint {
			attribute redefines maxTorque = 50.0 [N*m];
		}
		part shoulderJoint : Joint {
			attribute redefines maxTorque = 40.0 [N*m];
		}
		part elbowJoint : Joint {
			attribute redefines maxTorque = 30.0 [N*m];
		}
		part wristJoint : Joint {
			attribute redefines maxTorque = 20.0 [N*m];
		}
	}
	
	part def VisionSensor {
		port sensorOut : SensorPort;
		attribute resolution : Real;
		attribute frameRate : FrequencyValue;
	}
	
	part def ForceSensor {
		port sensorOut : SensorPort;
		attribute sensitivity : ForceValue;
		attribute range : ForceValue;
	}
	
	part def RobotController {
		port controlInterface : ControlPort;
		attribute processingFrequency : FrequencyValue;
		attribute memoryCapacity : Real;
	}
	
	part def PowerSupply {
		port powerOut : PowerPort;
		attribute outputVoltage : Real;
		attribute maxCurrent : Real;
		attribute capacity : EnergyValue;
	}
	
	part def ModelRobot {
		attribute currentState : RobotState;
		attribute operatingVoltage : Real;
		
		part arm : RobotArm {
			attribute redefines reachDistance = 1.2 [m];
		}
		
		part gripper : Gripper {
			attribute redefines gripStrength = 150.0 [N];
			attribute redefines gripperState = GripperState::open;
		}
		
		part visionSensor : VisionSensor {
			attribute redefines resolution = 1920.0;
			attribute redefines frameRate = 30.0 [Hz];
		}
		
		part forceSensor : ForceSensor {
			attribute redefines sensitivity = 0.1 [N];
			attribute redefines range = 500.0 [N];
		}
		
		part controller : RobotController {
			attribute redefines processingFrequency = 1000.0 [Hz];
			attribute redefines memoryCapacity = 8192.0;
		}
		
		part powerSupply : PowerSupply {
			attribute redefines outputVoltage = 24.0;
			attribute redefines maxCurrent = 20.0;
			attribute redefines capacity = 7200.0 [J];
		}
		
		connect powerSupply.powerOut to arm.baseJoint.powerIn;
		connect powerSupply.powerOut to arm.shoulderJoint.powerIn;
		connect powerSupply.powerOut to arm.elbowJoint.powerIn;
		connect powerSupply.powerOut to arm.wristJoint.powerIn;
		connect powerSupply.powerOut to gripper.powerIn;
	}
	
	state def RobotOperationStateMachine {
		entry; then idleState;
		
		state idleState;
		
		transition idleState_to_sensingState
			first idleState
			accept taskCommandReceived
			then sensingState;
		
		state sensingState {
			entry action senseAction : SenseEnvironment;
		}
		
		transition sensingState_to_planningState
			first sensingState
			accept environmentSensed
			then planningState;
		
		state planningState {
			entry action planAction : PlanTrajectory;
		}
		
		transition planningState_to_movingState
			first planningState
			accept trajectoryPlanned
			then movingState;
			
		transition planningState_to_errorState
			first planningState
			accept planningFailed
			then errorState;
		
		state movingState {
			entry action moveAction : MoveToTarget;
		}
		
		transition movingState_to_grippingState
			first movingState
			accept targetReached
			then grippingState;
			
		transition movingState_to_errorState
			first movingState
			accept obstacleDetected
			then errorState;
		
		state grippingState {
			entry action graspAction : GraspWorkpiece;
		}
		
		transition grippingState_to_processingState
			first grippingState
			accept workpieceGrasped
			then processingState;
			
		transition grippingState_to_errorState
			first grippingState
			accept graspFailed
			then errorState;
		
		state processingState {
			entry action processAction : ProcessWorkpiece;
		}
		
		transition processingState_to_releasingState
			first processingState
			accept processingComplete
			then releasingState;
			
		transition processingState_to_errorState
			first processingState
			accept processingError
			then errorState;
		
		state releasingState {
			entry action releaseAction : ReleaseWorkpiece;
		}
		
		transition releasingState_to_idleState
			first releasingState
			accept workpieceReleased
			then idleState;
		
		state errorState;
		
		transition errorState_to_idleState
			first errorState
			accept errorRecovered
			then idleState;
	}
	
	action def PerformPrimaryTask {
		in targetLocation : Position3D;
		in workItem : Workpiece;
		out completedItem : Workpiece;
	}
	
	action performPrimaryTask : PerformPrimaryTask {
		in item targetLocation;
		in item workItem;
		out item completedItem;
		
		first start;
		
		then action sense : SenseEnvironment {
			out item currentPosition;
			out item detectedForce;
		}
		
		flow from sense.currentPosition to plan.startPosition;
		
		then action plan : PlanTrajectory {
			in item startPosition;
			in item targetPosition = performPrimaryTask::targetLocation;
			out item plannedVelocity;
		}
		
		flow from plan.plannedVelocity to move.velocity;
		
		then action move : MoveToTarget {
			in item velocity;
			out item finalPosition;
		}
		
		flow from move.finalPosition to grasp.gripForce;
		
		then action grasp : GraspWorkpiece {
			in item gripForce;
			out item graspedItem = performPrimaryTask::workItem;
		}
		
		flow from grasp.graspedItem to process.workpiece;
		
		then action process : ProcessWorkpiece {
			in item workpiece;
			out item processedWorkpiece;
		}
		
		flow from process.processedWorkpiece to release.workpiece;
		
		then action release : ReleaseWorkpiece {
			in item workpiece;
			out item releasePosition;
		}
		
		then assign completedItem = process.processedWorkpiece;
		
		then done;
	}
	
	requirement def PrimaryTaskRequirement {
		doc /* The robotic system shall perform its primary task using a Model robot with specified performance characteristics. */
		
		subject robot : ModelRobot;
		
		require constraint {
			robot.arm.reachDistance >= 1.0 [m]
		}
		
		require constraint {
			robot.gripper.gripStrength >= 100.0 [N]
		}
		
		require constraint {
			robot.visionSensor.frameRate >= 25.0 [Hz]
		}
	}
	
	requirement def AccuracyRequirement {
		doc /* The robot shall achieve positioning accuracy within specified tolerance. */
		
		subject robot : ModelRobot;
		
		require constraint {
			robot.forceSensor.sensitivity <= 0.5 [N]
		}
	}
	
	requirement def PowerRequirement {
		doc /* The robot shall have sufficient power capacity for continuous operation. */
		
		subject robot : ModelRobot;
		
		require constraint {
			robot.powerSupply.capacity >= 3600.0 [J]
		}
		
		require constraint {
			robot.powerSupply.outputVoltage == 24.0
		}
	}
	
	requirement def SafetyRequirement {
		doc /* The robot shall operate safely and handle error conditions appropriately. */
		
		subject robot : ModelRobot;
		
		require constraint {
			robot.gripper.gripStrength <= 200.0 [N]
		}
	}
	
	part roboticWorkCell {
		part modelRobot : ModelRobot {
			attribute redefines operatingVoltage = 24.0;
			attribute redefines currentState = RobotState::idle;
			
			perform performPrimaryTask;
			
			exhibit operationStates : RobotOperationStateMachine;
		}
		
		item workQueue {
			item workpieces : Workpiece[0..*];
		}
		
		ref item currentWorkpiece : Workpiece;
		
		satisfy primaryReq : PrimaryTaskRequirement by modelRobot;
		satisfy accuracyReq : AccuracyRequirement by modelRobot;
		satisfy powerReq : PowerRequirement by modelRobot;
		satisfy safetyReq : SafetyRequirement by modelRobot;
	}
	
	allocation def TaskToRobotAllocation {
		end logical : PerformPrimaryTask;
		end physical : ModelRobot;
	}
	
	allocation primaryTaskAllocation : TaskToRobotAllocation
		allocate performPrimaryTask to roboticWorkCell.modelRobot {
			allocate performPrimaryTask.sense to roboticWorkCell.modelRobot.visionSensor;
			allocate performPrimaryTask.plan to roboticWorkCell.modelRobot.controller;
			allocate performPrimaryTask.move to roboticWorkCell.modelRobot.arm;
			allocate performPrimaryTask.grasp to roboticWorkCell.modelRobot.gripper;
			allocate performPrimaryTask.process to roboticWorkCell.modelRobot.controller;
			allocate performPrimaryTask.release to roboticWorkCell.modelRobot.gripper;
		}
}
