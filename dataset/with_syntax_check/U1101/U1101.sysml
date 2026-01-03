package 'Robotic System Model' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	enum def RobotOperatingMode {
		enum manual;
		enum automatic;
		enum maintenance;
		enum emergency;
	}
	
	enum def TaskStatus {
		enum idle;
		enum executing;
		enum completed;
		enum failed;
	}
	
	attribute def Position {
		attribute x : LengthValue;
		attribute y : LengthValue;
		attribute z : LengthValue;
	}
	
	attribute def Orientation {
		attribute roll : Real;
		attribute pitch : Real;
		attribute yaw : Real;
	}
	
	attribute def JointAngles {
		attribute j1 : Real;
		attribute j2 : Real;
		attribute j3 : Real;
		attribute j4 : Real;
		attribute j5 : Real;
		attribute j6 : Real;
	}
	
	item def Workpiece {
		attribute mass : MassValue;
		attribute dimensions : LengthValue[3];
	}
	
	item def Tool;
	item def Person;
	
	port def PowerPort {
		attribute voltage : Real;
		attribute current : Real;
	}
	
	port def ControlSignalPort {
		attribute commandSignal : Real;
		attribute feedbackSignal : Real;
	}
	
	port def DataPort {
		out position : Position;
		out jointAngles : JointAngles;
		out status : TaskStatus;
	}
	
	port def MaterialPort {
		in item inputWorkpiece : Workpiece;
		out item outputWorkpiece : Workpiece;
	}
	
	action def PickWorkpiece {
		in targetPosition : Position;
		in targetOrientation : Orientation;
		out graspedWorkpiece : Workpiece;
		out success : Boolean;
	}
	
	action def MoveToPosition {
		in destination : Position;
		in orientation : Orientation;
		out currentPosition : Position;
		out arrived : Boolean;
	}
	
	action def PlaceWorkpiece {
		in workpiece : Workpiece;
		in placePosition : Position;
		in placeOrientation : Orientation;
		out placed : Boolean;
	}
	
	action def InspectWorkpiece {
		in workpiece : Workpiece;
		out qualityCheck : Boolean;
	}
	
	action def PerformPickAndPlace {
		first start;
		then moveToPickup;
		
		action moveToPickup : MoveToPosition {
			in destination;
			in orientation;
			out currentPosition;
			out arrived;
		}
		
		then pickItem;
		
		action pickItem : PickWorkpiece {
			in targetPosition = moveToPickup.currentPosition;
			in targetOrientation;
			out graspedWorkpiece;
			out success;
		}
		
		then decide;
			if pickItem.success then moveToPlace;
			if not pickItem.success then handlePickFailure;
		
		action moveToPlace : MoveToPosition {
			in destination;
			in orientation;
			out currentPosition;
			out arrived;
		}
		
		then placeItem;
		
		action placeItem : PlaceWorkpiece {
			in workpiece = pickItem.graspedWorkpiece;
			in placePosition = moveToPlace.currentPosition;
			in placeOrientation;
			out placed;
		}
		
		then inspectItem;
		
		action inspectItem : InspectWorkpiece {
			in workpiece = pickItem.graspedWorkpiece;
			out qualityCheck;
		}
		
		then decide;
			if inspectItem.qualityCheck then done;
			if not inspectItem.qualityCheck then handleQualityFailure;
		
		action handlePickFailure {
			out errorCode : String;
		}
		then done;
		
		action handleQualityFailure {
			out errorCode : String;
		}
		then done;
	}
	
	action def MonitorRobotStatus {
		out operatingMode : RobotOperatingMode;
		out taskStatus : TaskStatus;
		out currentPosition : Position;
	}
	
	action def ExecutePrimaryTask {
		first start;
		then merge continueOperation;
		
		then monitor : MonitorRobotStatus {
			out operatingMode;
			out taskStatus;
			out currentPosition;
		}
		
		then decide;
			if monitor.operatingMode == RobotOperatingMode::automatic then checkTaskStatus;
			if monitor.operatingMode == RobotOperatingMode::emergency then emergencyStop;
			if monitor.operatingMode == RobotOperatingMode::maintenance then waitMaintenance;
		
		action checkTaskStatus {
			in taskStatus : TaskStatus = monitor.taskStatus;
			out shouldExecute : Boolean;
		}
		then decide;
			if checkTaskStatus.shouldExecute then initiate;
		
		action initiate {
			out initialized : Boolean;
		}
		then execute;
		
		action execute : PerformPickAndPlace;
		then continueOperation;
		
		action emergencyStop {
			out stopped : Boolean;
		}
		then done;
		
		action waitMaintenance;
		then done;
	}
	
	state def RobotStateMachine {
		entry; then idle;
		
		state idle {
			entry assign RobotOperatingMode::manual;
		}
		
		transition idle_to_automatic
			first idle
			accept StartAutomaticMode
			then automatic;
		
		state automatic {
			entry assign RobotOperatingMode::automatic;
			do action executeTask : ExecutePrimaryTask;
		}
		
		transition automatic_to_idle
			first automatic
			accept StopCommand
			then idle;
		
		transition automatic_to_emergency
			first automatic
			accept EmergencySignal
			then emergency;
		
		state emergency {
			entry assign RobotOperatingMode::emergency;
			do action haltAllMotion;
		}
		
		transition emergency_to_maintenance
			first emergency
			accept MaintenanceRequest
			then maintenance;
		
		state maintenance {
			entry assign RobotOperatingMode::maintenance;
		}
		
		transition maintenance_to_idle
			first maintenance
			accept MaintenanceComplete
			then idle;
	}
	
	part def Joint {
		attribute jointNumber : Integer;
		attribute maxTorque : TorqueValue;
		attribute maxSpeed : Real;
		attribute currentAngle : Real;
		
		port powerIn : PowerPort;
		port controlIn : ControlSignalPort;
		
		perform action rotateJoint {
			in targetAngle : Real;
			out actualAngle : Real;
		}
	}
	
	part def Gripper {
		attribute maxGraspForce : ForceValue;
		attribute openingWidth : LengthValue;
		
		port powerIn : PowerPort;
		port controlIn : ControlSignalPort;
		
		item heldWorkpiece : Workpiece[0..1];
		
		perform action grasp {
			in workpiece : Workpiece;
			out graspForce : ForceValue;
			out success : Boolean;
		}
		
		perform action release {
			out workpiece : Workpiece;
		}
	}
	
	part def PositionSensor {
		attribute accuracy : LengthValue;
		attribute samplingRate : FrequencyValue;
		
		port dataOut : DataPort;
		
		perform action measurePosition {
			out position : Position;
		}
	}
	
	part def ForceSensor {
		attribute maxForce : ForceValue;
		attribute sensitivity : Real;
		
		perform action measureForce {
			out force : ForceValue;
		}
	}
	
	part def RobotController {
		attribute processorSpeed : FrequencyValue;
		attribute memoryCapacity : Real;
		
		port controlOut : ControlSignalPort;
		port dataIn : DataPort;
		
		perform action planTrajectory {
			in startPosition : Position;
			in endPosition : Position;
			out trajectory : Position[0..*];
		}
		
		perform action executeControl : ExecutePrimaryTask;
	}
	
	part def SafetySystem {
		attribute emergencyStopTime : TimeValue;
		
		part emergencyStopButton;
		part lightCurtain;
		part collisionDetector;
		
		perform action detectHazard {
			out hazardDetected : Boolean;
		}
		
		perform action triggerEmergencyStop {
			out stopped : Boolean;
		}
	}
	
	part def RobotArm {
		attribute numberOfJoints : Integer;
		attribute reach : LengthValue;
		attribute payloadCapacity : MassValue;
		attribute repeatability : LengthValue;
		
		part joint1 : Joint {
			attribute redefines jointNumber = 1;
			attribute redefines maxTorque = 200.0 [N*m];
			attribute redefines maxSpeed = 180.0;
		}
		
		part joint2 : Joint {
			attribute redefines jointNumber = 2;
			attribute redefines maxTorque = 180.0 [N*m];
			attribute redefines maxSpeed = 180.0;
		}
		
		part joint3 : Joint {
			attribute redefines jointNumber = 3;
			attribute redefines maxTorque = 150.0 [N*m];
			attribute redefines maxSpeed = 200.0;
		}
		
		part joint4 : Joint {
			attribute redefines jointNumber = 4;
			attribute redefines maxTorque = 100.0 [N*m];
			attribute redefines maxSpeed = 250.0;
		}
		
		part joint5 : Joint {
			attribute redefines jointNumber = 5;
			attribute redefines maxTorque = 80.0 [N*m];
			attribute redefines maxSpeed = 300.0;
		}
		
		part joint6 : Joint {
			attribute redefines jointNumber = 6;
			attribute redefines maxTorque = 50.0 [N*m];
			attribute redefines maxSpeed = 350.0;
		}
		
		part endEffector : Gripper {
			attribute redefines maxGraspForce = 300.0 [N];
			attribute redefines openingWidth = 150.0 [mm];
		}
		
		part positionSensor : PositionSensor {
			attribute redefines accuracy = 0.05 [mm];
			attribute redefines samplingRate = 1000.0 [Hz];
		}
		
		part forceSensor : ForceSensor {
			attribute redefines maxForce = 500.0 [N];
			attribute redefines sensitivity = 0.01;
		}
		
		connection joint1Power connect joint1.powerIn to joint2.powerIn;
		connection joint2Power connect joint2.powerIn to joint3.powerIn;
		connection joint3Power connect joint3.powerIn to joint4.powerIn;
		connection joint4Power connect joint4.powerIn to joint5.powerIn;
		connection joint5Power connect joint5.powerIn to joint6.powerIn;
		connection joint6Power connect joint6.powerIn to endEffector.powerIn;
	}
	
	part def IndustrialRobot {
		attribute serialNumber : String;
		attribute manufacturerModel : String;
		attribute operatingVoltage : Real;
		attribute powerConsumption : PowerValue;
		attribute currentMode : RobotOperatingMode;
		
		ref item operator : Person;
		
		port mainPower : PowerPort {
			attribute redefines voltage = 480.0;
			attribute redefines current = 25.0;
		}
		
		port controlInterface : ControlSignalPort;
		port dataInterface : DataPort;
		port materialInput : MaterialPort;
		
		part controller : RobotController {
			attribute redefines processorSpeed = 3.0e9 [Hz];
			attribute redefines memoryCapacity = 16.0;
		}
		
		part arm : RobotArm {
			attribute redefines numberOfJoints = 6;
			attribute redefines reach = 2.0 [m];
			attribute redefines payloadCapacity = 25.0 [kg];
			attribute redefines repeatability = 0.03 [mm];
		}
		
		part safety : SafetySystem {
			attribute redefines emergencyStopTime = 0.3 [s];
		}
		
		part teachPendant {
			attribute displaySize : LengthValue;
		}
		
		perform action primaryOperation : PerformPickAndPlace;
		
		exhibit state behavior : RobotStateMachine;
		
		connection powerDistribution connect mainPower to arm.joint1.powerIn;
		connection controlLink connect controller.controlOut to controlInterface;
		connection dataLink connect arm.positionSensor.dataOut to dataInterface;
	}
	
	part def Conveyor {
		attribute speed : SpeedValue;
		attribute length : LengthValue;
		
		port powerIn : PowerPort;
		port materialOut : MaterialPort;
		
		item workpieces : Workpiece[0..*];
		
		perform action transportWorkpiece {
			in workpiece : Workpiece;
			out delivered : Boolean;
		}
	}
	
	part def WorkCell {
		attribute cellIdentifier : String;
		attribute floorArea : AreaValue;
		
		part safetyFence {
			attribute height : LengthValue;
			attribute material : String;
		}
		
		part workTable {
			attribute surfaceArea : AreaValue;
		}
		
		part lightingSystem {
			attribute illuminance : Real;
		}
	}
	
	part def PowerSupply {
		attribute inputVoltage : Real;
		attribute outputVoltage : Real;
		attribute maxCurrent : Real;
		attribute efficiency : Real;
		
		port powerOut : PowerPort;
		
		perform action supplyPower {
			out voltage : Real;
			out current : Real;
		}
	}
	
	part def ProgrammableLogicController {
		attribute scanTime : TimeValue;
		attribute ioPoints : Integer;
		
		port controlOut : ControlSignalPort;
		
		perform action coordinateSystem {
			out systemStatus : Boolean;
		}
	}
	
	part roboticManufacturingSystem {
		part robot : IndustrialRobot {
			attribute redefines serialNumber = "IR-6000-2024-001";
			attribute redefines manufacturerModel = "IR-6000";
			attribute redefines operatingVoltage = 480.0;
			attribute redefines powerConsumption = 12000.0 [W];
			attribute redefines currentMode = RobotOperatingMode::automatic;
		}
		
		part inputConveyor : Conveyor {
			attribute redefines speed = 0.5 [m/s];
			attribute redefines length = 3.0 [m];
		}
		
		part outputConveyor : Conveyor {
			attribute redefines speed = 0.5 [m/s];
			attribute redefines length = 3.0 [m];
		}
		
		part cell : WorkCell {
			attribute redefines cellIdentifier = "CELL-A-01";
			attribute redefines floorArea = 25.0 [m^2];
		}
		
		part powerSupply : PowerSupply {
			attribute redefines inputVoltage = 480.0;
			attribute redefines outputVoltage = 480.0;
			attribute redefines maxCurrent = 50.0;
			attribute redefines efficiency = 0.95;
		}
		
		part systemController : ProgrammableLogicController {
			attribute redefines scanTime = 10.0 [ms];
			attribute redefines ioPoints = 128;
		}
		
		ref item robotOperator : Person;
		
		connection powerToRobot connect powerSupply.powerOut to robot.mainPower;
		connection powerToInputConveyor connect powerSupply.powerOut to inputConveyor.powerIn;
		connection powerToOutputConveyor connect powerSupply.powerOut to outputConveyor.powerIn;
		connection materialFlow connect inputConveyor.materialOut to robot.materialInput;
		connection systemControl connect systemController.controlOut to robot.controlInterface;
		
		bind robot.operator = robotOperator;
	}
	
	requirement def SafetyRequirement {
		doc /* The robotic system shall ensure safe operation and protect personnel. */
		
		require emergencyStopResponse : TimeValue;
		require collisionForceLimit : ForceValue;
		require workspaceIsolation : Boolean;
	}
	
	requirement def PerformanceRequirement {
		doc /* The robotic system shall meet specified performance criteria. */
		
		require cycleTime : TimeValue;
		require positionAccuracy : LengthValue;
		require repeatability : LengthValue;
		require payloadCapacity : MassValue;
	}
	
	requirement def ReliabilityRequirement {
		doc /* The robotic system shall operate reliably over its service life. */
		
		require meanTimeBetweenFailures : TimeValue;
		require taskSuccessRate : Real;
		require maintenanceInterval : TimeValue;
	}
	
	requirement def FunctionalRequirement {
		doc /* The robotic system shall perform pick and place operations. */
		
		require pickAccuracy : LengthValue;
		require placeAccuracy : LengthValue;
		require graspForce : ForceValue;
	}
	
	requirement systemRequirements {
		doc /* Top-level requirements for the robotic manufacturing system. */
		
		subject roboticManufacturingSystem;
		
		requirement safety : SafetyRequirement {
			require redefines emergencyStopResponse = 0.3 [s];
			require redefines collisionForceLimit = 150.0 [N];
			require redefines workspaceIsolation = true;
		}
		
		requirement performance : PerformanceRequirement {
			require redefines cycleTime = 12.0 [s];
			require redefines positionAccuracy = 0.05 [mm];
			require redefines repeatability = 0.03 [mm];
			require redefines payloadCapacity = 25.0 [kg];
		}
		
		requirement reliability : ReliabilityRequirement {
			require redefines meanTimeBetweenFailures = 10000.0 [h];
			require redefines taskSuccessRate = 0.998;
			require redefines maintenanceInterval = 2000.0 [h];
		}
		
		requirement functional : FunctionalRequirement {
			require redefines pickAccuracy = 0.1 [mm];
			require redefines placeAccuracy = 0.1 [mm];
			require redefines graspForce = 300.0 [N];
		}
		
		satisfy safety by roboticManufacturingSystem.robot.safety;
		satisfy performance by roboticManufacturingSystem.robot.arm;
		satisfy reliability by roboticManufacturingSystem.robot;
		satisfy functional by roboticManufacturingSystem.robot.arm.endEffector;
	}
	
	package LogicalArchitecture {
		action def PerformManufacturingOperation;
		action def ExecutePickAndPlaceTask;
		
		part def ManufacturingTaskExecutor;
		
		action performManufacturing : PerformManufacturingOperation {
			action executePickAndPlace : ExecutePickAndPlaceTask;
		}
		
		part taskExecutor : ManufacturingTaskExecutor {
			perform performManufacturing.executePickAndPlace;
		}
	}
	
	package PhysicalArchitecture {
		private import LogicalArchitecture::*;
		
		part def PhysicalComponent;
		part def RoboticManipulator :> PhysicalComponent;
		
		part roboticManipulator : RoboticManipulator {
			part industrialRobot : IndustrialRobot {
				perform performManufacturing.executePickAndPlace;
			}
		}
		
		allocation def LogicalToPhysicalAllocation {
			end logical : ManufacturingTaskExecutor;
			end physical : RoboticManipulator;
		}
		
		allocation taskAllocation : LogicalToPhysicalAllocation 
			allocate taskExecutor to roboticManipulator {
			allocate taskExecutor.executePickAndPlace 
				to roboticManipulator.industrialRobot.executePickAndPlace;
		}
	}
}
