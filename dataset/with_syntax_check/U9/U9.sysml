package 'Robotic System Model' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def Position2D {
		attribute x : LengthValue;
		attribute y : LengthValue;
	}
	
	attribute def Orientation {
		attribute theta : Real;
	}
	
	attribute def Pose {
		attribute position : Position2D;
		attribute orientation : Orientation;
	}
	
	attribute def Velocity2D {
		attribute linear : SpeedValue;
		attribute angular : Real;
	}
	
	attribute def BatteryCharge :> Real;
	
	enum def RobotState {
		enum idle;
		enum navigating;
		enum executing;
		enum returning;
		enum charging;
		enum error;
	}
	
	enum def TaskState {
		enum pending;
		enum active;
		enum completed;
		enum failed;
	}
	
	item def WorkTask {
		attribute taskId : String;
		attribute targetPose : Pose;
		attribute taskType : String;
		attribute status : TaskState;
	}
	
	item def ObstacleData {
		attribute detected : Boolean;
		attribute distance : LengthValue;
		attribute angle : Real;
	}
	
	item def NavigationPath {
		attribute waypoints : Pose[*];
		attribute totalDistance : LengthValue;
	}
	
	port def SensorDataPort {
		out item obstacleInfo : ObstacleData;
		out item currentPose : Pose;
	}
	
	port def MotionControlPort {
		in item targetVelocity : Velocity2D;
		out item actualVelocity : Velocity2D;
	}
	
	port def PowerPort {
		in item powerDemand : PowerValue;
		out item chargeLevel : BatteryCharge;
	}
	
	port def TaskPort {
		in item task : WorkTask;
		out item taskResult : TaskState;
	}
	
	action def SenseEnvironment {
		out obstacleData : ObstacleData;
		out robotPose : Pose;
	}
	
	action def PlanNavigation {
		in startPose : Pose;
		in goalPose : Pose;
		in obstacles : ObstacleData;
		out path : NavigationPath;
	}
	
	action def ExecuteMotion {
		in path : NavigationPath;
		in currentPose : Pose;
		out velocity : Velocity2D;
		out arrived : Boolean;
	}
	
	action def PerformWorkTask {
		in task : WorkTask;
		in robotPose : Pose;
		out result : TaskState;
	}
	
	action def MonitorPower {
		in chargeLevel : BatteryCharge;
		out lowBattery : Boolean;
	}
	
	action def NavigateToBase {
		in currentPose : Pose;
		in basePose : Pose;
		out path : NavigationPath;
	}
	
	action def RechargeAction {
		in currentCharge : BatteryCharge;
		out newCharge : BatteryCharge;
	}
	
	state def MobileRobotStateMachine {
		entry; then idle;
		
		state idle;
		state navigating;
		state executing;
		state returning;
		state charging;
		state error;
		
		transition idle_to_navigating
			first idle
			accept taskAssigned : WorkTask
			then navigating;
		
		transition navigating_to_executing
			first navigating
			accept arrivedAtTarget
			then executing;
		
		transition executing_to_idle
			first executing
			accept taskComplete
			then idle;
		
		transition any_to_returning
			accept batteryLow
			then returning;
		
		transition returning_to_charging
			first returning
			accept arrivedAtBase
			then charging;
		
		transition charging_to_idle
			first charging
			accept fullyCharged
			then idle;
		
		transition any_to_error
			accept systemFault
			then error;
		
		transition error_to_idle
			first error
			accept faultCleared
			then idle;
	}
	
	part def LidarSensor {
		port sensorPort : SensorDataPort;
		attribute scanRange : LengthValue;
		attribute scanRate : Real;
		
		action scan : SenseEnvironment {
			out obstacleData;
			out robotPose;
		}
	}
	
	part def MotionController {
		port controlPort : MotionControlPort;
		attribute maxLinearSpeed : SpeedValue;
		attribute maxAngularSpeed : Real;
		
		action controlMotion : ExecuteMotion {
			in path;
			in currentPose;
			out velocity;
			out arrived;
		}
	}
	
	part def TaskProcessor {
		port taskPort : TaskPort;
		
		action processTask : PerformWorkTask {
			in task;
			in robotPose;
			out result;
		}
	}
	
	part def PathPlanner {
		action planPath : PlanNavigation {
			in startPose;
			in goalPose;
			in obstacles;
			out path;
		}
	}
	
	part def BatterySystem {
		port powerPort : PowerPort;
		attribute capacity : EnergyValue;
		attribute currentCharge : BatteryCharge;
		attribute minChargeThreshold : BatteryCharge;
		
		action monitorBattery : MonitorPower {
			in chargeLevel = currentCharge;
			out lowBattery;
		}
		
		action recharge : RechargeAction {
			in currentCharge;
			out newCharge;
		}
	}
	
	part def DriveSystem {
		attribute wheelDiameter : LengthValue;
		attribute wheelBase : LengthValue;
		
		action drive {
			in commandVelocity : Velocity2D;
			out actualVelocity : Velocity2D;
		}
	}
	
	part def MobileRobot {
		attribute robotId : String;
		attribute currentPose : Pose;
		attribute currentVelocity : Velocity2D;
		attribute operationalState : RobotState;
		attribute basePose : Pose;
		
		port taskInput : TaskPort;
		
		part lidar : LidarSensor {
			attribute redefines scanRange = 10.0 [m];
			attribute redefines scanRate = 10.0;
		}
		
		part motionCtrl : MotionController {
			attribute redefines maxLinearSpeed = 2.0 [m/s];
			attribute redefines maxAngularSpeed = 1.57;
		}
		
		part taskProc : TaskProcessor;
		
		part planner : PathPlanner;
		
		part battery : BatterySystem {
			attribute redefines capacity = 5000.0 [W*h];
			attribute redefines currentCharge = 100.0;
			attribute redefines minChargeThreshold = 20.0;
		}
		
		part driveSystem : DriveSystem {
			attribute redefines wheelDiameter = 0.2 [m];
			attribute redefines wheelBase = 0.5 [m];
		}
		
		connection sensorToPlanner connect lidar.sensorPort to planner;
		connection plannerToMotion connect planner to motionCtrl.controlPort;
		connection motionToDrive connect motionCtrl.controlPort to driveSystem;
		connection batteryToPower connect battery.powerPort to motionCtrl;
		
		perform robotOperation;
		
		action robotOperation {
			first start;
			then merge powerCheck;
			
			action powerCheck : MonitorPower {
				in chargeLevel = battery.currentCharge;
				out lowBattery;
			}
			
			then decide;
				if powerCheck.lowBattery then returnToBase;
				if !powerCheck.lowBattery then awaitTask;
			
			action returnToBase {
				action navigateBack : NavigateToBase {
					in currentPose = MobileRobot::currentPose;
					in basePose = MobileRobot::basePose;
					out path;
				}
				
				flow from navigateBack.path to executeReturn.path;
				
				action executeReturn : ExecuteMotion {
					in path;
					in currentPose = MobileRobot::currentPose;
					out velocity;
					out arrived;
				}
				
				then action chargeRobot : RechargeAction {
					in currentCharge = battery.currentCharge;
					out newCharge;
				}
			}
			then powerCheck;
			
			action awaitTask {
				in item receivedTask : WorkTask;
			}
			
			then action navigateToTask {
				action sense : SenseEnvironment {
					out obstacleData;
					out robotPose;
				}
				
				flow from sense.obstacleData to plan.obstacles;
				flow from sense.robotPose to plan.startPose;
				
				action plan : PlanNavigation {
					in startPose;
					in goalPose = awaitTask.receivedTask.targetPose;
					in obstacles;
					out path;
				}
				
				flow from plan.path to execute.path;
				
				action execute : ExecuteMotion {
					in path;
					in currentPose = MobileRobot::currentPose;
					out velocity;
					out arrived;
				}
			}
			
			then action executeTask : PerformWorkTask {
				in task = awaitTask.receivedTask;
				in robotPose = MobileRobot::currentPose;
				out result;
			}
			
			then powerCheck;
		}
		
		state robotStateMachine : MobileRobotStateMachine;
	}
	
	part def ChargingDock {
		attribute dockId : String;
		attribute dockPose : Pose;
		
		port chargingPort : PowerPort;
		
		action supplyPower {
			in batteryLevel : BatteryCharge;
			out chargedLevel : BatteryCharge;
		}
	}
	
	part def MissionController {
		attribute controllerName : String;
		
		action dispatchTask {
			in availableRobot : MobileRobot;
			in taskQueue : WorkTask[*];
			out dispatchedTask : WorkTask;
		}
		
		action monitorProgress {
			in robot : MobileRobot;
			out taskStatus : TaskState;
		}
	}
	
	requirement def PrimaryTaskRequirement {
		doc /* The robotic system shall perform its primary task using a mobile robot 
		       that autonomously navigates to task locations and executes assigned work. */
		
		subject robot : MobileRobot;
		
		require constraint {
			robot.taskProc.processTask.result == TaskState::completed
		}
	}
	
	requirement def AutonomousNavigationRequirement {
		doc /* The mobile robot shall autonomously navigate to target locations 
		       while avoiding obstacles detected by sensors. */
		
		subject robot : MobileRobot;
		
		require constraint {
			robot.planner.planPath.path.waypoints->size() > 0 and
			robot.motionCtrl.controlMotion.arrived == true
		}
	}
	
	requirement def PowerManagementRequirement {
		doc /* The mobile robot shall monitor battery charge and autonomously 
		       return to charging dock when charge falls below threshold. */
		
		subject robot : MobileRobot;
		
		require constraint {
			robot.battery.monitorBattery.lowBattery implies
			robot.operationalState == RobotState::returning or
			robot.operationalState == RobotState::charging
		}
	}
	
	requirement def SensorRequirement {
		doc /* The mobile robot shall use lidar sensor for environment perception 
		       and obstacle detection during navigation. */
		
		subject robot : MobileRobot;
		
		require constraint {
			robot.lidar.scanRange >= 5.0 [m] and
			robot.lidar.scanRate >= 5.0
		}
	}
	
	requirement def SafetyRequirement {
		doc /* The mobile robot shall enter error state and halt operation 
		       upon detection of system faults. */
		
		subject robot : MobileRobot;
		
		require constraint {
			robot.operationalState == RobotState::error implies
			robot.currentVelocity.linear == 0.0 [m/s]
		}
	}
	
	part roboticSystem {
		part mobileRobot : MobileRobot {
			attribute redefines robotId = "ROBOT-001";
			attribute redefines currentPose {
				attribute redefines position {
					attribute redefines x = 0.0 [m];
					attribute redefines y = 0.0 [m];
				}
				attribute redefines orientation {
					attribute redefines theta = 0.0;
				}
			}
			attribute redefines basePose {
				attribute position {
					attribute x = 0.0 [m];
					attribute y = 0.0 [m];
				}
				attribute orientation {
					attribute theta = 0.0;
				}
			}
			attribute redefines operationalState = RobotState::idle;
		}
		
		part chargingDock : ChargingDock {
			attribute redefines dockId = "DOCK-001";
			attribute redefines dockPose {
				attribute position {
					attribute x = 0.0 [m];
					attribute y = 0.0 [m];
				}
				attribute orientation {
					attribute theta = 0.0;
				}
			}
		}
		
		part missionController : MissionController {
			attribute redefines controllerName = "MainMissionController";
		}
		
		connection powerConnection connect mobileRobot.battery.powerPort to chargingDock.chargingPort;
		connection taskConnection connect missionController to mobileRobot.taskInput;
		
		satisfy primaryTaskReq by mobileRobot;
		satisfy navReq by mobileRobot.planner;
		satisfy powerReq by mobileRobot.battery;
		satisfy sensorReq by mobileRobot.lidar;
		satisfy safetyReq by mobileRobot.robotStateMachine;
	}
	
	requirement primaryTaskReq : PrimaryTaskRequirement {
		subject robot = roboticSystem.mobileRobot;
	}
	
	requirement navReq : AutonomousNavigationRequirement {
		subject robot = roboticSystem.mobileRobot;
	}
	
	requirement powerReq : PowerManagementRequirement {
		subject robot = roboticSystem.mobileRobot;
	}
	
	requirement sensorReq : SensorRequirement {
		subject robot = roboticSystem.mobileRobot;
	}
	
	requirement safetyReq : SafetyRequirement {
		subject robot = roboticSystem.mobileRobot;
	}
	
	allocation def TaskExecutionAllocation {
		end logical : TaskProcessor;
		end physical : MobileRobot;
	}
	
	allocation taskAllocation : TaskExecutionAllocation
		allocate roboticSystem.mobileRobot.taskProc to roboticSystem.mobileRobot {
		allocate roboticSystem.mobileRobot.taskProc.processTask 
			to roboticSystem.mobileRobot.robotOperation.executeTask;
	}
}
