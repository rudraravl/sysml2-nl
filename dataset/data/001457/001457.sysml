package 'Humanoid Robotic System' {
	private import ScalarValues::*;
	private import SI::*;
	
	enum def RobotMode {
		enum standby;
		enum operational;
		enum maintenance;
		enum emergency;
	}
	
	enum def TaskState {
		enum notStarted;
		enum inProgress;
		enum completed;
		enum aborted;
	}
	
	enum def GripState {
		enum open;
		enum closed;
		enum holding;
	}
	
	attribute def Position3D {
		attribute x : Real;
		attribute y : Real;
		attribute z : Real;
	}
	
	attribute def JointAngle {
		attribute value : Real;
	}
	
	attribute def Torque {
		attribute value : Real;
	}
	
	attribute def GripForce {
		attribute value : Real;
	}
	
	item def TaskCommand {
		attribute taskID : String;
		attribute targetPosition : Position3D;
		attribute priority : Integer;
	}
	
	item def TaskResult {
		attribute taskID : String;
		attribute status : TaskState;
		attribute completionTime : Real;
	}
	
	item def SensorData {
		attribute timestamp : Real;
		attribute objectDetected : Boolean;
		attribute objectPosition : Position3D;
	}
	
	port def PowerPort {
		attribute voltage : Real;
		attribute current : Real;
	}
	
	port def DataPort {
		in commandData : TaskCommand;
		out statusData : TaskResult;
	}
	
	port def SensorPort {
		out sensorReading : SensorData;
	}
	
	action def ScanEnvironment {
		out environmentData : SensorData;
	}
	
	action def ComputeTrajectory {
		in currentPos : Position3D;
		in targetPos : Position3D;
		out pathValid : Boolean;
	}
	
	action def MoveToPosition {
		in targetPos : Position3D;
		out positionReached : Boolean;
	}
	
	action def GraspObject {
		in graspForce : GripForce;
		out objectGrasped : Boolean;
	}
	
	action def ReleaseObject {
		out objectReleased : Boolean;
	}
	
	action def ReportTaskStatus {
		in taskStatus : TaskState;
		out reported : Boolean;
	}
	
	package LogicalModel {
		action def PerformTask;
		action def SenseEnvironment;
		action def PlanMotion;
		action def ExecuteMotion;
		action def ManipulateObject;
		
		part def TaskExecutor {
			attribute executorID : String;
		}
		
		action performPrimaryTask : PerformTask {
			first start;
			then action sense : SenseEnvironment;
			then action plan : PlanMotion;
			then action execute : ExecuteMotion;
			then action manipulate : ManipulateObject;
			then done;
		}
		
		part taskExecutor : TaskExecutor {
			attribute redefines executorID = "PRIMARY_EXECUTOR";
			perform performPrimaryTask;
		}
	}
	
	package PhysicalModel {
		private import LogicalModel::*;
		
		part def VisionSystem {
			attribute resolution : Integer = 1920;
			attribute frameRate : Real = 30.0;
			
			port sensorOut : SensorPort;
			
			action scanArea : ScanEnvironment {
				out environmentData;
			}
			
			perform scanArea;
		}
		
		part def MotionController {
			attribute processingFrequency : Real = 100.0;
			attribute maxAcceleration : Real = 2.0;
			
			action calculatePath : ComputeTrajectory {
				in currentPos;
				in targetPos;
				out pathValid;
			}
			
			perform calculatePath;
		}
		
		part def ArmActuator {
			attribute jointCount : Integer = 7;
			attribute maxReach : Real = 0.9;
			attribute maxTorque : Torque;
			
			part shoulder {
				attribute angle : JointAngle;
			}
			
			part elbow {
				attribute angle : JointAngle;
			}
			
			part wrist {
				attribute angle : JointAngle;
			}
			
			action moveArm : MoveToPosition {
				in targetPos;
				out positionReached;
			}
			
			perform moveArm;
		}
		
		part def GripperMechanism {
			attribute maxForce : GripForce;
			attribute fingerCount : Integer = 2;
			attribute currentState : GripState = GripState::open;
			
			action grip : GraspObject {
				in graspForce;
				out objectGrasped;
			}
			
			action release : ReleaseObject {
				out objectReleased;
			}
			
			perform grip;
			perform release;
		}
		
		part def MobilityBase {
			attribute maxSpeed : Real = 1.2;
			attribute wheelDiameter : Real = 0.15;
			attribute batteryCapacity : Real = 50000.0;
			attribute currentCharge : Real = 50000.0;
			
			port powerOut : PowerPort {
				attribute redefines voltage = 48.0;
				attribute redefines current = 10.0;
			}
			
			action navigate : MoveToPosition {
				in targetPos;
				out positionReached;
			}
			
			perform navigate;
		}
		
		part def HumanoidRobot {
			attribute robotID : String;
			attribute height : Real = 1.65;
			attribute weight : Real = 75.0;
			attribute operatingMode : RobotMode = RobotMode::standby;
			
			port powerIn : PowerPort;
			port dataInterface : DataPort;
			
			part visionSys : VisionSystem {
				attribute redefines resolution = 2048;
				attribute redefines frameRate = 60.0;
			}
			
			part controller : MotionController {
				attribute redefines processingFrequency = 200.0;
			}
			
			part leftArm : ArmActuator {
				attribute redefines jointCount = 7;
				attribute redefines maxReach = 0.85;
			}
			
			part rightArm : ArmActuator {
				attribute redefines jointCount = 7;
				attribute redefines maxReach = 0.85;
			}
			
			part leftGripper : GripperMechanism;
			
			part rightGripper : GripperMechanism;
			
			part base : MobilityBase {
				attribute redefines maxSpeed = 1.5;
				attribute redefines batteryCapacity = 60000.0;
			}
			
			connection powerSupply connect base.powerOut to powerIn;
			
			action executePrimaryTask {
				in taskCmd : TaskCommand;
				out taskRes : TaskResult;
				
				first start;
				
				then action scanPhase : ScanEnvironment {
					out environmentData;
				}
				
				then action trajectoryPhase : ComputeTrajectory {
					in currentPos;
					in targetPos = taskCmd.targetPosition;
					out pathValid;
				}
				
				then decide;
					if trajectoryPhase.pathValid then navigatePhase;
					if !trajectoryPhase.pathValid then abortTask;
				
				action navigatePhase : MoveToPosition {
					in targetPos = taskCmd.targetPosition;
					out positionReached;
				}
				
				then decide;
					if navigatePhase.positionReached then graspPhase;
					if !navigatePhase.positionReached then abortTask;
				
				action graspPhase : GraspObject {
					in graspForce;
					out objectGrasped;
				}
				
				then decide;
					if graspPhase.objectGrasped then reportSuccess;
					if !graspPhase.objectGrasped then abortTask;
				
				action reportSuccess : ReportTaskStatus {
					in taskStatus = TaskState::completed;
					out reported;
				}
				
				then done;
				
				action abortTask : ReportTaskStatus {
					in taskStatus = TaskState::aborted;
					out reported;
				}
				
				then done;
			}
			
			perform executePrimaryTask;
		}
		
		part def RoboticSystem {
			attribute systemID : String;
			attribute operationalStatus : String;
			
			part controlCenter {
				attribute centerID : String;
				
				port commandOut : DataPort;
			}
			
			part workZone {
				attribute zoneArea : Real = 25.0;
				attribute safetyPerimeter : Boolean = true;
			}
		}
		
		part roboticSystem : RoboticSystem {
			attribute redefines systemID = "HMND_SYS_001";
			attribute redefines operationalStatus = "Active";
			
			part humanoid : HumanoidRobot {
				attribute redefines robotID = "HMND_ROBOT_001";
				attribute redefines height = 1.70;
				attribute redefines weight = 80.0;
				
				perform executePrimaryTask;
			}
			
			connection taskInterface connect 
				controlCenter.commandOut to humanoid.dataInterface;
		}
		
		allocation def LogicalToPhysicalAllocation {
			end logical : TaskExecutor;
			end physical : RoboticSystem;
		}
		
		allocation systemAllocation : LogicalToPhysicalAllocation
			allocate taskExecutor to roboticSystem {
				allocate taskExecutor.performPrimaryTask 
					to roboticSystem.humanoid.executePrimaryTask;
				allocate taskExecutor.performPrimaryTask.sense 
					to roboticSystem.humanoid.visionSys.scanArea;
				allocate taskExecutor.performPrimaryTask.plan 
					to roboticSystem.humanoid.controller.calculatePath;
				allocate taskExecutor.performPrimaryTask.execute 
					to roboticSystem.humanoid.rightArm.moveArm;
				allocate taskExecutor.performPrimaryTask.manipulate 
					to roboticSystem.humanoid.rightGripper.grip;
			}
	}
	
	package Requirements {
		private import PhysicalModel::*;
		
		requirement def PrimaryTaskRequirement {
			doc /* The robotic system shall perform its primary task using a humanoid robot. */
			
			subject system : RoboticSystem;
			
			require constraint {
				system.humanoid.executePrimaryTask.taskRes.status == TaskState::completed
			}
		}
		
		requirement def SafetyRequirement {
			doc /* The humanoid robot shall operate within safe operational parameters. */
			
			subject robot : HumanoidRobot;
			
			require constraint {
				robot.operatingMode != RobotMode::emergency
			}
		}
		
		requirement def PerformanceRequirement {
			doc /* The humanoid robot shall execute tasks with high position accuracy. */
			
			subject robot : HumanoidRobot;
			
			require constraint {
				robot.rightArm.moveArm.positionReached == true
			}
		}
		
		requirement def PowerRequirement {
			doc /* The mobility base shall maintain sufficient power for continuous operation. */
			
			subject base : MobilityBase;
			
			require constraint {
				base.currentCharge > 0.2 * base.batteryCapacity
			}
		}
		
		requirement primaryTask : PrimaryTaskRequirement {
			subject roboticSystem;
		}
		
		requirement safety : SafetyRequirement {
			subject roboticSystem.humanoid;
		}
		
		requirement performance : PerformanceRequirement {
			subject roboticSystem.humanoid;
		}
		
		requirement power : PowerRequirement {
			subject roboticSystem.humanoid.base;
		}
	}
}
