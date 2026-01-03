package 'Robotic Companion System' {
	private import ScalarValues::*;
	private import SI::*;
	
	attribute def Distance :> Real;
	attribute def Velocity :> Real;
	attribute def BatteryLevel :> Real;
	attribute def TaskProgress :> Real;
	
	enum def RobotStatus {
		enum idle;
		enum executing;
		enum charging;
		enum error;
	}
	
	enum def TaskType {
		enum delivery;
		enum inspection;
		enum maintenance;
		enum surveillance;
	}
	
	item def TaskCommand {
		attribute taskType : TaskType;
		attribute priority : Integer;
		attribute targetLocation : Distance[3];
		attribute deadline : Real;
	}
	
	item def TaskResult {
		attribute taskType : TaskType;
		attribute completionLevel : TaskProgress;
		attribute success : Boolean;
		attribute executionTime : Real;
	}
	
	item def SensorData {
		attribute position : Distance[3];
		attribute obstacleDetected : Boolean;
		attribute batteryLevel : BatteryLevel;
	}
	
	port def CommandPort {
		out item command : TaskCommand;
	}
	
	port def ResultPort {
		in item result : TaskResult;
	}
	
	port def SensorPort {
		out item data : SensorData;
	}
	
	port def ControlPort {
		in item command : TaskCommand;
		out item result : TaskResult;
	}
	
	connection def CommandLink {
		end source : CommandPort;
		end target : ControlPort;
	}
	
	connection def ResultLink {
		end source : ControlPort;
		end target : ResultPort;
	}
	
	action def NavigateToTarget {
		in targetLocation : Distance[3];
		in currentPosition : Distance[3];
		out navigationComplete : Boolean;
	}
	
	action def PerformInspection {
		in location : Distance[3];
		out inspectionData : SensorData;
	}
	
	action def DeliverItem {
		in destination : Distance[3];
		out deliveryComplete : Boolean;
	}
	
	action def MonitorBattery {
		out batteryLevel : BatteryLevel;
	}
	
	action def ExecuteAssignedTask {
		in taskCommand : TaskCommand;
		out taskResult : TaskResult;
		
		first start;
		then checkBattery;
		
		action checkBattery : MonitorBattery {
			out batteryLevel;
		}
		
		then decide;
			if checkBattery.batteryLevel < 20.0 then abortTask;
			if checkBattery.batteryLevel >= 20.0 then navigateToTarget;
		
		action navigateToTarget : NavigateToTarget {
			in targetLocation = taskCommand.targetLocation;
			in currentPosition;
			out navigationComplete;
		}
		
		then decide;
			if taskCommand.taskType == TaskType::inspection then performInspection;
			if taskCommand.taskType == TaskType::delivery then deliverItem;
		
		action performInspection : PerformInspection {
			in location = taskCommand.targetLocation;
			out inspectionData;
		}
		then completeTask;
		
		action deliverItem : DeliverItem {
			in destination = taskCommand.targetLocation;
			out deliveryComplete;
		}
		then completeTask;
		
		action completeTask {
			in item success : Boolean;
			out item result : TaskResult {
				attribute taskType = taskCommand.taskType;
				attribute completionLevel = 100.0;
				attribute success = success;
			}
		}
		then done;
		
		action abortTask {
			out item result : TaskResult {
				attribute taskType = taskCommand.taskType;
				attribute completionLevel = 0.0;
				attribute success = false;
			}
		}
		then done;
	}
	
	part def Sensor {
		attribute sensorId : String;
		attribute range : Distance;
		port dataOutput : SensorPort;
		
		perform action scan {
			out data : SensorData;
		}
	}
	
	part def Actuator {
		attribute actuatorId : String;
		attribute maxSpeed : Velocity;
		
		perform action move : NavigateToTarget;
	}
	
	part def Battery {
		attribute capacity : Real;
		attribute currentCharge : BatteryLevel;
	}
	
	part def CompanionController {
		port controlInterface : ControlPort;
		attribute currentStatus : RobotStatus;
	}
	
	part def CompanionRobot {
		attribute robotId : String;
		attribute status : RobotStatus;
		
		part sensors : Sensor[4] {
			attribute range = 10.0;
		}
		
		part actuators : Actuator[2] {
			attribute maxSpeed = 3.0;
		}
		
		part battery : Battery {
			attribute capacity = 5000.0;
			attribute currentCharge = 100.0;
		}
		
		part controller : CompanionController;
		
		perform action executeTask : ExecuteAssignedTask;
	}
	
	part def MainController {
		attribute controllerId : String;
		port commandOutput : CommandPort;
		port resultInput : ResultPort;
		
		perform action delegateTask {
			in taskRequest : TaskCommand;
			out delegatedCommand : TaskCommand;
		}
	}
	
	part def ChargingStation {
		attribute stationId : String;
		
		perform action chargeRobot {
			in currentLevel : BatteryLevel;
			out chargedLevel : BatteryLevel;
		}
	}
	
	requirement def SystemRequirements {
		doc /* Requirements for robotic companion system */
		
		requirement taskExecutionReq {
			doc /* Companion robot shall execute delegated tasks autonomously */
			subject companion : CompanionRobot;
			require companion.executeTask.taskResult.success;
		}
		
		requirement batteryManagementReq {
			doc /* Companion robot shall maintain battery above minimum threshold */
			subject companion : CompanionRobot;
			require companion.battery.currentCharge >= 15.0;
		}
		
		requirement navigationReq {
			doc /* Companion robot shall navigate to target locations */
			subject companion : CompanionRobot;
			require companion.executeTask.navigateToTarget.navigationComplete;
		}
	}
	
	package LogicalModel {
		action def PerformPrimaryTask;
		action def DelegateToCompanion;
		
		part def PrimarySystem;
		part def CompanionAgent;
		
		action primaryTask : PerformPrimaryTask {
			action delegateTask : DelegateToCompanion;
		}
		
		part primarySystem : PrimarySystem {
			perform primaryTask;
		}
		
		part companionAgent : CompanionAgent {
			perform primaryTask.delegateTask;
		}
	}
	
	package PhysicalModel {
		private import LogicalModel::*;
		
		part roboticSystem {
			part mainController : MainController {
				attribute controllerId = "MAIN-001";
				
				perform primaryTask;
			}
			
			part companion : CompanionRobot {
				attribute robotId = "COMP-001";
				attribute status = RobotStatus::idle;
				
				perform primaryTask.delegateTask;
			}
			
			part chargingStation : ChargingStation {
				attribute stationId = "CHARGE-001";
			}
			
			connection commandLink : CommandLink
				connect mainController.commandOutput to companion.controller.controlInterface;
			
			connection resultLink : ResultLink
				connect companion.controller.controlInterface to mainController.resultInput;
			
			satisfy systemReqs : SystemRequirements;
		}
		
		allocation def LogicalToPhysicalAllocation {
			end logical : PrimarySystem;
			end physical : MainController;
		}
		
		allocation def CompanionAllocation {
			end logical : CompanionAgent;
			end physical : CompanionRobot;
		}
		
		allocation primaryAllocation : LogicalToPhysicalAllocation
			allocate primarySystem to roboticSystem.mainController {
				allocate primarySystem.primaryTask to roboticSystem.mainController.delegateTask;
			}
		
		allocation companionAllocation : CompanionAllocation
			allocate companionAgent to roboticSystem.companion {
				allocate companionAgent.delegateTask to roboticSystem.companion.executeTask;
			}
	}
}
