package 'Non-Silicon Robotic System' {
	private import ScalarValues::*;
	private import SI::*;
	
	attribute def Voltage {
		attribute num : Real;
		attribute unit : String = "V";
	}
	
	attribute def Current {
		attribute num : Real;
		attribute unit : String = "A";
	}
	
	attribute def Force {
		attribute num : Real;
		attribute unit : String = "N";
	}
	
	attribute def Pressure {
		attribute num : Real;
		attribute unit : String = "Pa";
	}
	
	attribute def Position {
		attribute x : Real;
		attribute y : Real;
		attribute z : Real;
	}
	
	enum def MaterialType {
		enum silicon;
		enum organicPolymer;
		enum fluidicMaterial;
		enum biocompatible;
	}
	
	enum def TaskState {
		enum idle;
		enum executing;
		enum completed;
		enum failed;
	}
	
	item def WorkPiece {
		attribute position : Position;
		attribute mass : Real;
	}
	
	item def FluidicSignal {
		attribute pressure : Pressure;
		attribute flowRate : Real;
	}
	
	item def SensorReading {
		attribute position : Position;
		attribute force : Force;
		attribute timestamp : Real;
	}
	
	port def FluidicPort {
		in item pressureIn : Pressure;
		out item pressureOut : Pressure;
	}
	
	port def SensorPort {
		out item reading : SensorReading;
	}
	
	port def ActuatorPort {
		in item command : FluidicSignal;
		out item feedback : SensorReading;
	}
	
	port def PowerPort {
		in item voltage : Voltage;
		in item current : Current;
	}
	
	action def SenseEnvironment {
		out sensorData : SensorReading;
	}
	
	action def ComputeTrajectory {
		in currentPosition : Position;
		in targetPosition : Position;
		out trajectory : Position[0..*];
	}
	
	action def MoveToPosition {
		in trajectory : Position[0..*];
		out finalPosition : Position;
	}
	
	action def GraspObject {
		in target : WorkPiece;
		in graspForce : Force;
		out success : Boolean;
	}
	
	action def TransportObject {
		in object : WorkPiece;
		in destination : Position;
		out success : Boolean;
	}
	
	action def ReleaseObject {
		in object : WorkPiece;
		out success : Boolean;
	}
	
	action def PerformPrimaryTask {
		in workPiece : WorkPiece;
		out taskState : TaskState;
		
		first start;
		then action sense : SenseEnvironment {
			out item sensorData;
		}
		then action computePath : ComputeTrajectory {
			in item currentPosition = sense.sensorData.position;
			in item targetPosition = workPiece.position;
			out item trajectory;
		}
		then action approach : MoveToPosition {
			in item trajectory = computePath.trajectory;
			out item finalPosition;
		}
		then action grasp : GraspObject {
			in item target = workPiece;
			in item graspForce;
			out item success;
		}
		then decide;
			if grasp.success then transport;
			if !grasp.success then failTask;
		action transport : TransportObject {
			in item object = workPiece;
			in item destination;
			out item success;
		}
		then action release : ReleaseObject {
			in item object = workPiece;
			out item success;
		}
		then done;
		action failTask {
			out item taskState = TaskState::failed;
		}
		then done;
	}
	
	state def RobotStateMachine {
		entry; then powerOff;
		
		state powerOff;
		transition powerOff_to_init
			first powerOff
			accept PowerOnEvent
			then initializing;
		
		state initializing;
		transition init_to_ready
			first initializing
			then ready;
		
		state ready;
		transition ready_to_operating
			first ready
			accept StartTaskEvent
			then operating;
		
		state operating {
			entry action executeTask : PerformPrimaryTask;
		}
		transition operating_to_ready
			first operating
			if executeTask.taskState == TaskState::completed
			then ready;
		
		transition operating_to_error
			first operating
			if executeTask.taskState == TaskState::failed
			then error;
		
		state error;
		transition error_to_ready
			first error
			accept ResetEvent
			then ready;
	}
	
	part def FluidicActuator {
		attribute material : MaterialType;
		attribute maxForce : Force;
		port fluidPort : FluidicPort;
		port actuatorPort : ActuatorPort;
		
		assert constraint { material == MaterialType::fluidicMaterial }
	}
	
	part def OrganicSensor {
		attribute material : MaterialType;
		attribute sensitivity : Real;
		port sensorPort : SensorPort;
		
		assert constraint { material == MaterialType::organicPolymer or material == MaterialType::biocompatible }
	}
	
	part def FluidicController {
		attribute material : MaterialType;
		attribute processingRate : Real;
		port controlPort : FluidicPort;
		
		assert constraint { material == MaterialType::fluidicMaterial or material == MaterialType::organicPolymer }
	}
	
	part def FluidicPump {
		attribute nominalPressure : Pressure;
		port output : FluidicPort;
	}
	
	connection def SensorConnection {
		end source : SensorPort;
		end target : FluidicController;
	}
	
	connection def FluidicConnection {
		end source : FluidicPort;
		end target : FluidicPort;
	}
	
	connection def PowerConnection {
		end source;
		end target : PowerPort;
	}
	
	part def NonSiliconRobot {
		attribute robotMaterial : MaterialType;
		attribute currentState : TaskState;
		
		port powerInput : PowerPort;
		port fluidicSupply : FluidicPort;
		
		part controller : FluidicController {
			attribute redefines material = MaterialType::fluidicMaterial;
			attribute redefines processingRate = 500.0;
		}
		
		part sensors : OrganicSensor[4] {
			attribute redefines material = MaterialType::biocompatible;
			attribute redefines sensitivity = 0.98;
		}
		
		part armActuators : FluidicActuator[3] {
			attribute redefines material = MaterialType::fluidicMaterial;
			attribute redefines maxForce;
		}
		
		part gripper : FluidicActuator {
			attribute redefines material = MaterialType::fluidicMaterial;
			attribute redefines maxForce;
		}
		
		connection sensorToController : SensorConnection connect sensors.sensorPort to controller;
		connection controllerToArm : FluidicConnection connect controller.controlPort to armActuators.fluidPort;
		connection controllerToGripper : FluidicConnection connect controller.controlPort to gripper.fluidPort;
		
		perform action primaryTask : PerformPrimaryTask;
		
		exhibit state robotControl : RobotStateMachine;
		
		assert constraint nonSiliconConstraint {
			robotMaterial != MaterialType::silicon and
			controller.material != MaterialType::silicon
		}
	}
	
	part def RoboticWorkCell {
		part fluidicPump : FluidicPump {
			attribute redefines nominalPressure;
		}
		
		part powerSupply {
			attribute outputVoltage : Voltage;
			attribute outputCurrent : Current;
		}
		
		part robot : NonSiliconRobot {
			attribute redefines robotMaterial = MaterialType::organicPolymer;
		}
		
		part workPieces : WorkPiece[0..*];
		
		connection fluidConnection : FluidicConnection connect fluidicPump.output to robot.fluidicSupply;
		connection powerConnection : PowerConnection connect powerSupply to robot.powerInput;
	}
	
	requirement def NonSiliconMaterialRequirement {
		doc /* All robot components must use non-silicon materials. */
		subject robot : NonSiliconRobot;
		require constraint {
			robot.robotMaterial != MaterialType::silicon and
			robot.controller.material != MaterialType::silicon
		}
	}
	
	requirement def PrimaryTaskRequirement {
		doc /* The robot must successfully perform its primary task. */
		subject robot : NonSiliconRobot;
		require constraint {
			robot.primaryTask.taskState == TaskState::completed
		}
	}
	
	requirement def SafetyRequirement {
		doc /* The robot must operate within safe force limits. */
		subject robot : NonSiliconRobot;
		require constraint {
			robot.armActuators.maxForce.num <= 400.0 and
			robot.gripper.maxForce.num <= 150.0
		}
	}
	
	part roboticSystem : RoboticWorkCell {
		part redefines fluidicPump {
			attribute :>> nominalPressure {
				attribute :>> num = 500000.0;
				attribute :>> unit = "Pa";
			}
		}
		
		part redefines powerSupply {
			attribute :>> outputVoltage {
				attribute :>> num = 24.0;
				attribute :>> unit = "V";
			}
			attribute :>> outputCurrent {
				attribute :>> num = 8.0;
				attribute :>> unit = "A";
			}
		}
		
		part redefines robot {
			part redefines armActuators {
				attribute :>> maxForce {
					attribute :>> num = 350.0;
					attribute :>> unit = "N";
				}
			}
			part redefines gripper {
				attribute :>> maxForce {
					attribute :>> num = 120.0;
					attribute :>> unit = "N";
				}
			}
		}
		
		satisfy materialReq : NonSiliconMaterialRequirement by robot;
		satisfy taskReq : PrimaryTaskRequirement by robot;
		satisfy safetyReq : SafetyRequirement by robot;
	}
	
	allocation def TaskToRobotAllocation {
		end logical : PerformPrimaryTask;
		end physical : NonSiliconRobot;
	}
	
	allocation taskAllocation : TaskToRobotAllocation
		allocate PerformPrimaryTask to roboticSystem.robot {
		allocate PerformPrimaryTask::sense to roboticSystem.robot.sensors;
		allocate PerformPrimaryTask::grasp to roboticSystem.robot.gripper;
		allocate PerformPrimaryTask::transport to roboticSystem.robot.armActuators;
	}
}
