package 'Bush Robotic System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	enum def RobotMode {
		enum standby;
		enum operational;
		enum fault;
		enum maintenance;
	}
	
	enum def TaskStatus {
		enum pending;
		enum inProgress;
		enum completed;
		enum failed;
	}
	
	attribute def Position3D {
		attribute x : LengthValue;
		attribute y : LengthValue;
		attribute z : LengthValue;
	}
	
	attribute def Orientation {
		attribute roll : Real;
		attribute pitch : Real;
		attribute yaw : Real;
	}
	
	attribute def Pose {
		attribute position : Position3D;
		attribute orientation : Orientation;
	}
	
	attribute def JointState {
		attribute angle : Real;
		attribute velocity : AngularVelocityValue;
		attribute torque : TorqueValue;
	}
	
	item def ElectricalPower {
		attribute voltage : ElectricPotentialValue;
		attribute current : ElectricCurrentValue;
	}
	
	item def ControlCommand {
		attribute commandType : String;
		attribute targetPose : Pose;
		attribute timestamp : Real;
	}
	
	item def SensorData {
		attribute currentPose : Pose;
		attribute jointStates : JointState[6];
		attribute timestamp : Real;
	}
	
	port def PowerPort {
		in item power : ElectricalPower;
	}
	
	port def ControlPort {
		in item command : ControlCommand;
		out item status : SensorData;
	}
	
	port def DataPort {
		out item sensorOutput : SensorData;
	}
	
	action def InitializeRobot {
		in initialPose : Pose;
		out initialized : Boolean;
	}
	
	action def PlanTrajectory {
		in startPose : Pose;
		in targetPose : Pose;
		out trajectoryValid : Boolean;
	}
	
	action def ExecuteMotion {
		in targetPose : Pose;
		out motionComplete : Boolean;
	}
	
	action def MonitorSafety {
		in currentState : SensorData;
		out safetyOk : Boolean;
	}
	
	action def PerformPrimaryTask {
		in taskParameters : Pose;
		out taskSuccess : Boolean;
		
		first start;
		then action initialize : InitializeRobot;
		then merge planningLoop;
		then action plan : PlanTrajectory {
			in startPose = initialize.initialPose;
			in targetPose = taskParameters;
		}
		then decide;
			if plan.trajectoryValid then executeMotion;
			if !plan.trajectoryValid then abortTask;
		action executeMotion : ExecuteMotion {
			in targetPose = taskParameters;
		}
		then merge safetyCheck;
		action abortTask;
		then done;
		then action monitor : MonitorSafety;
		then decide;
			if monitor.safetyOk then completeTask;
			if !monitor.safetyOk then emergencyStop;
		action completeTask;
		then done;
		action emergencyStop;
		then done;
		then safetyCheck;
		then planningLoop;
	}
	
	part def Joint {
		attribute jointId : Integer;
		attribute state : JointState;
		attribute minAngle : Real;
		attribute maxAngle : Real;
		
		port controlInterface {
			in item targetAngle : Real;
			out item currentState : JointState;
		}
	}
	
	part def Link {
		attribute linkId : Integer;
		attribute length : LengthValue;
		attribute mass : MassValue;
	}
	
	part def EndEffector {
		attribute gripperState : Boolean;
		attribute maxGripForce : ForceValue;
		
		port effectorControl {
			in item gripCommand : Boolean;
			out item gripStatus : Boolean;
		}
		
		action def Grasp {
			in targetForce : ForceValue;
			out graspSuccess : Boolean;
		}
		
		action def Release {
			out releaseComplete : Boolean;
		}
	}
	
	part def SensorModule {
		attribute sensorId : String;
		
		port dataOutput : DataPort;
		
		action def AcquireData {
			out data : SensorData;
		}
		
		perform action sensing {
			action acquire : AcquireData;
		}
	}
	
	part def ControlModule {
		attribute controllerMode : RobotMode;
		
		port commandInterface : ControlPort;
		
		action def ProcessCommand {
			in cmd : ControlCommand;
			out response : Boolean;
		}
		
		perform action controlling {
			action process : ProcessCommand;
		}
	}
	
	part def PowerSupply {
		attribute nominalVoltage : ElectricPotentialValue;
		attribute maxCurrent : ElectricCurrentValue;
		
		port powerOutput : PowerPort;
	}
	
	part def BushRobot {
		attribute robotId : String;
		attribute currentMode : RobotMode;
		attribute currentTaskStatus : TaskStatus;
		
		port mainPower : PowerPort;
		port mainControl : ControlPort;
		
		part joint[6] : Joint {
			attribute :>> minAngle = -180.0;
			attribute :>> maxAngle = 180.0;
		}
		
		part link[6] : Link {
			attribute :>> length = 0.5[m];
			attribute :>> mass = 2.0[kg];
		}
		
		part endEffector : EndEffector {
			attribute :>> maxGripForce = 100.0[N];
		}
		
		part sensorModule : SensorModule {
			attribute :>> sensorId = "BUSH_SENSOR_01";
		}
		
		part controlModule : ControlModule {
			attribute :>> controllerMode = currentMode;
		}
		
		connection c1 connect controlModule.commandInterface to mainControl;
		connection c2 connect sensorModule.dataOutput to controlModule.commandInterface;
		
		perform action robotOperation : PerformPrimaryTask;
		
		state bushRobotStateMachine {
			entry; then standby;
			
			state standby {
				entry assign currentMode = RobotMode::standby;
				entry assign currentTaskStatus = TaskStatus::pending;
			}
			
			transition standby_to_operational
				first standby
				accept taskCommand
				then operational;
			
			state operational {
				entry assign currentMode = RobotMode::operational;
				
				state initializing {
					entry assign currentTaskStatus = TaskStatus::inProgress;
				}
				
				transition init_to_executing
					first initializing
					accept initComplete
					then executing;
				
				state executing;
				
				transition exec_to_completing
					first executing
					accept motionComplete
					then completing;
				
				state completing {
					entry assign currentTaskStatus = TaskStatus::completed;
				}
			}
			
			transition operational_to_standby
				first operational
				accept taskComplete
				then standby;
			
			transition any_to_fault
				first standby
				accept errorDetected
				then fault;
			
			state fault {
				entry assign currentMode = RobotMode::fault;
				entry assign currentTaskStatus = TaskStatus::failed;
			}
			
			transition fault_to_maintenance
				first fault
				accept maintenanceRequest
				then maintenance;
			
			state maintenance {
				entry assign currentMode = RobotMode::maintenance;
			}
			
			transition maintenance_to_standby
				first maintenance
				accept maintenanceComplete
				then standby;
		}
	}
	
	package LogicalModel {
		action def ExecutePrimaryTask {
			in taskSpec : Pose;
			out result : Boolean;
		}
		
		part def TaskExecutor {
			perform task : ExecutePrimaryTask;
		}
		
		action executePrimaryTask : ExecutePrimaryTask;
		
		part taskExecutor : TaskExecutor {
			perform executePrimaryTask;
		}
	}
	
	package PhysicalModel {
		private import LogicalModel::*;
		
		part def RoboticSystem {
			attribute systemId : String;
			ref part primaryRobot : BushRobot;
			
			perform systemTask : ExecutePrimaryTask;
		}
		
		part roboticSystem : RoboticSystem {
			attribute :>> systemId = "BUSH_SYS_001";
			
			part bushRobot : BushRobot {
				attribute :>> robotId = "BUSH_ROBOT_001";
				attribute :>> currentMode = RobotMode::standby;
				attribute :>> currentTaskStatus = TaskStatus::pending;
			}
			
			part powerSupply : PowerSupply {
				attribute :>> nominalVoltage = 48.0[V];
				attribute :>> maxCurrent = 20.0[A];
			}
			
			binding primaryRobot = bushRobot;
			
			connection powerConnection connect powerSupply.powerOutput to bushRobot.mainPower;
			
			perform action :>> systemTask;
		}
		
		allocation def LogicalToPhysicalAllocation {
			end logical : TaskExecutor;
			end physical : RoboticSystem;
		}
		
		allocation systemAllocation : LogicalToPhysicalAllocation
			allocate taskExecutor to roboticSystem {
				allocate taskExecutor.task to roboticSystem.bushRobot.robotOperation;
			}
	}
	
	requirement def SystemRequirement {
		doc /* Base requirement for robotic system */
		subject system;
	}
	
	requirement def FunctionalRequirement :> SystemRequirement {
		doc /* Functional requirements for robotic operations */
		attribute requiredAccuracy : LengthValue;
		attribute requiredSpeed : SpeedValue;
	}
	
	requirement primaryTaskRequirement : FunctionalRequirement {
		doc /* The robotic system shall perform its primary task using a Bush robot */
		subject roboticSystem : PhysicalModel::RoboticSystem;
		
		require constraint {
			roboticSystem.primaryRobot == roboticSystem.bushRobot
		}
		
		attribute :>> requiredAccuracy = 0.01[m];
		attribute :>> requiredSpeed = 0.5[m/s];
	}
	
	requirement operationalRequirement : SystemRequirement {
		doc /* The Bush robot shall execute tasks autonomously and safely */
		subject bushRobot : BushRobot;
		
		require constraint {
			bushRobot.currentMode == RobotMode::operational or
			bushRobot.currentMode == RobotMode::standby
		}
	}
	
	requirement safetyRequirement : SystemRequirement {
		doc /* The Bush robot shall monitor safety during operation */
		subject bushRobot : BushRobot;
		
		require constraint {
			bushRobot.currentMode != RobotMode::fault
		}
	}
	
	verification def VerifyPrimaryTask {
		subject testRobot : BushRobot;
		return verdict : Boolean;
	}
	
	verification verifyBushRobotOperation : VerifyPrimaryTask {
		subject testBushRobot :> PhysicalModel::roboticSystem.bushRobot;
	}
	
	part verificationSystem {
		perform verifyBushRobotOperation {
			in part :>> testBushRobot {
				attribute :>> robotId = "BUSH_TEST_001";
			}
		}
	}
}
