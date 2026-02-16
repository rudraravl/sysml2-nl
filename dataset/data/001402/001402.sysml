package 'Disability Robotic Assistance System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	enum def TaskType {
		enum mobilityAssistance;
		enum objectRetrieval;
		enum medicationDelivery;
		enum environmentalControl;
	}
	
	enum def RobotState {
		enum idle;
		enum navigating;
		enum executing;
		enum returning;
		enum charging;
		enum error;
	}
	
	enum def NavigationStatus {
		enum pathClear;
		enum obstacleDetected;
		enum destinationReached;
	}
	
	attribute def BatteryCapacity :> Real;
	
	attribute def Location {
		attribute x : LengthValue;
		attribute y : LengthValue;
		attribute z : LengthValue;
	}
	
	attribute def Velocity {
		attribute linear : SpeedValue;
		attribute angular : AngularVelocityValue;
	}
	
	item def TaskRequest {
		attribute taskType : TaskType;
		attribute priority : Integer;
		attribute targetLocation : Location;
		attribute requestTime : Real;
	}
	
	item def TaskResponse {
		attribute taskCompleted : Boolean;
		attribute completionTime : Real;
		attribute errorCode : Integer;
	}
	
	item def SensorData {
		attribute obstacleDistance : LengthValue;
		attribute currentLocation : Location;
		attribute batteryLevel : BatteryCapacity;
	}
	
	item def NavigationCommand {
		attribute targetLocation : Location;
		attribute maxSpeed : SpeedValue;
		attribute avoidanceEnabled : Boolean;
	}
	
	port def SensorPort {
		out sensorData : SensorData;
	}
	
	port def ActuatorPort {
		in navigationCmd : NavigationCommand;
		out currentVelocity : Velocity;
	}
	
	port def CommunicationPort {
		in taskRequest : TaskRequest;
		out taskResponse : TaskResponse;
	}
	
	port def PowerPort {
		in powerSupply : PowerValue;
		out powerDemand : PowerValue;
	}
	
	port def ManipulatorPort {
		in graspCommand : Boolean;
		out graspStatus : Boolean;
	}
	
	action def NavigateToLocation {
		in startLocation : Location;
		in targetLocation : Location;
		in maxSpeed : SpeedValue;
		out pathCompleted : Boolean;
		out finalLocation : Location;
	}
	
	action def PerformGrasp {
		in objectLocation : Location;
		in graspForce : ForceValue;
		out objectGrasped : Boolean;
	}
	
	action def MonitorBattery {
		in currentLevel : BatteryCapacity;
		out chargingNeeded : Boolean;
	}
	
	action def DetectObstacles {
		in sensorRange : LengthValue;
		out obstacleDetected : Boolean;
		out obstacleDistance : LengthValue;
	}
	
	action def ExecuteTask {
		in request : TaskRequest;
		out response : TaskResponse;
		
		first start;
		then action validateRequest {
			in taskReq = request;
			out valid : Boolean;
		}
		
		then decide;
			if validateRequest.valid then proceedWithTask;
			else reportError;
		
		action proceedWithTask {
			first action navigateToTarget : NavigateToLocation {
				in targetLocation = request.targetLocation;
				in maxSpeed = 1.0[SI::'m/s'];
			}
			
			then decide;
				if request.taskType == TaskType::objectRetrieval then retrieveObject;
				if request.taskType == TaskType::mobilityAssistance then provideMobilitySupport;
				if request.taskType == TaskType::medicationDelivery then deliverMedication;
				if request.taskType == TaskType::environmentalControl then controlEnvironment;
			
			action retrieveObject {
				first action detectObject : DetectObstacles;
				then action graspObject : PerformGrasp {
					in objectLocation = navigateToTarget.finalLocation;
					in graspForce = 20.0[SI::N];
				}
			}
			
			action provideMobilitySupport {
				out supportProvided : Boolean;
			}
			
			action deliverMedication {
				out medicationDelivered : Boolean;
			}
			
			action controlEnvironment {
				out environmentAdjusted : Boolean;
			}
			
			then action returnToBase : NavigateToLocation {
				in startLocation = navigateToTarget.finalLocation;
			}
		}
		then completeTask;
		
		action reportError {
			out :>> response {
				:>> taskCompleted = false;
				:>> errorCode = 1;
			}
		}
		then done;
		
		action completeTask {
			out :>> response {
				:>> taskCompleted = true;
				:>> errorCode = 0;
			}
		}
		then done;
	}
	
	state def DisabilityRobotStateMachine {
		entry; then initializing;
		
		state initializing {
			entry assign currentState = RobotState::idle;
		}
		transition init_to_idle
			first initializing
			accept at when batteryLevel >= 20.0
			then idle;
		
		state idle {
			entry assign currentState = RobotState::idle;
		}
		transition idle_to_navigating
			first idle
			accept TaskRequest
			then navigating;
		
		state navigating {
			entry assign currentState = RobotState::navigating;
			do action navigate : NavigateToLocation;
		}
		transition navigating_to_executing
			first navigating
			accept when navigate.pathCompleted
			then executing;
		
		transition navigating_to_error
			first navigating
			accept when obstacleDetected
			then error;
		
		state executing {
			entry assign currentState = RobotState::executing;
			do action executeTask : ExecuteTask;
		}
		transition executing_to_returning
			first executing
			accept when executeTask.response.taskCompleted
			then returning;
		
		state returning {
			entry assign currentState = RobotState::returning;
			do action returnHome : NavigateToLocation;
		}
		transition returning_to_idle
			first returning
			accept when returnHome.pathCompleted && batteryLevel >= 30.0
			then idle;
		
		transition returning_to_charging
			first returning
			accept when returnHome.pathCompleted && batteryLevel < 30.0
			then charging;
		
		state charging {
			entry assign currentState = RobotState::charging;
		}
		transition charging_to_idle
			first charging
			accept when batteryLevel >= 95.0
			then idle;
		
		state error {
			entry assign currentState = RobotState::error;
		}
		transition error_to_idle
			first error
			accept when !obstacleDetected
			then idle;
	}
	
	part def DisabilityRobot {
		attribute batteryLevel : BatteryCapacity;
		attribute currentLocation : Location;
		attribute currentState : RobotState;
		attribute obstacleDetected : Boolean;
		
		port sensorInterface : SensorPort;
		port actuatorInterface : ActuatorPort;
		port commInterface : CommunicationPort;
		port powerInterface : PowerPort;
		port manipulatorInterface : ManipulatorPort;
		
		ref action primaryTask : ExecuteTask;
		
		part mobilityBase : MobilityBase {
			attribute maxSpeed : SpeedValue = 2.0[SI::'m/s'];
			attribute wheelDiameter : LengthValue = 0.15[SI::m];
			
			port actuators : ActuatorPort;
			
			part motors[4] {
				attribute maxTorque : TorqueValue = 10.0[SI::'N·m'];
				attribute ratedPower : PowerValue = 100.0[SI::W];
			}
		}
		
		part navigationSystem : NavigationSystem {
			port sensors : SensorPort;
			
			part lidar {
				attribute scanRate : FrequencyValue = 10.0[SI::Hz];
				attribute range : LengthValue = 10.0[SI::m];
				attribute accuracy : LengthValue = 0.03[SI::m];
			}
			
			part imu {
				attribute updateRate : FrequencyValue = 100.0[SI::Hz];
			}
			
			part pathPlanner {
				action planPath : NavigateToLocation;
			}
		}
		
		part manipulatorArm : ManipulatorArm {
			attribute reachDistance : LengthValue = 0.9[SI::m];
			attribute payloadCapacity : MassValue = 5.0[SI::kg];
			
			port manipulator : ManipulatorPort;
			
			part joints[6] {
				attribute maxAngle : Real = 180.0;
				attribute maxTorque : TorqueValue = 15.0[SI::'N·m'];
			}
			
			part endEffector {
				attribute maxGraspWidth : LengthValue = 0.12[SI::m];
				attribute graspForce : ForceValue = 50.0[SI::N];
			}
		}
		
		part visionSystem : VisionSystem {
			attribute fieldOfView : Real = 110.0;
			attribute detectionRange : LengthValue = 5.0[SI::m];
			
			part cameras[2] {
				attribute resolution : Integer = 1920 * 1080;
				attribute frameRate : FrequencyValue = 60.0[SI::Hz];
			}
			
			part depthSensor {
				attribute range : LengthValue = 8.0[SI::m];
				attribute resolution : Integer = 640 * 480;
			}
		}
		
		part controlSystem : ControlSystem {
			part mainProcessor {
				attribute clockSpeed : FrequencyValue = 3.0e9[SI::Hz];
				attribute cores : Integer = 8;
				attribute memory : Integer = 16;
			}
			
			part motionController {
				action coordinateMotion;
			}
			
			part taskScheduler {
				action scheduleTask;
			}
			
			perform primaryTask;
		}
		
		part powerSystem : PowerSystem {
			attribute maxCapacity : EnergyValue = 50000.0[SI::'W·h'];
			attribute currentCharge : EnergyValue;
			
			port power : PowerPort;
			
			part batteryPack {
				attribute voltage : Real = 48.0;
				attribute capacity : EnergyValue = 50000.0[SI::'W·h'];
				attribute chemistry : String = "Lithium-Ion";
			}
			
			part powerManagement {
				action monitorPower : MonitorBattery;
			}
		}
		
		state operationalState : DisabilityRobotStateMachine;
	}
	
	part def MobilityBase;
	part def NavigationSystem;
	part def ManipulatorArm;
	part def VisionSystem;
	part def ControlSystem;
	part def PowerSystem;
	
	part def ChargingStation {
		port chargingPort : PowerPort;
		port dataPort : CommunicationPort;
		
		part chargingDock {
			attribute outputPower : PowerValue = 1000.0[SI::W];
			attribute chargingVoltage : Real = 48.0;
		}
		
		part userInterface {
			action displayStatus;
			action receiveRequest;
		}
	}
	
	part def UserInterface {
		port requestPort : CommunicationPort;
		
		action submitTaskRequest {
			out request : TaskRequest;
		}
		
		action receiveTaskResponse {
			in response : TaskResponse;
		}
	}
	
	requirement def SystemRequirements {
		doc /* The disability robotic system shall provide reliable autonomous assistance */
		
		requirement taskCompletionRate {
			doc /* The system shall achieve 98% task completion rate under normal conditions */
			subject robot : DisabilityRobot;
			require constraint {
				robot.primaryTask.response.taskCompleted == true
			}
		}
		
		requirement operationalDuration {
			doc /* The system shall operate continuously for at least 6 hours on a single charge */
			subject robot : DisabilityRobot;
			require constraint {
				robot.powerSystem.maxCapacity >= 6.0 * 3600.0[SI::J]
			}
		}
		
		requirement responseTime {
			doc /* The system shall respond to task requests within 5 seconds */
			subject robot : DisabilityRobot;
			require constraint {
				robot.primaryTask.response.completionTime <= 5.0
			}
		}
		
		requirement safetyCompliance {
			doc /* The system shall maintain safe operation with obstacle detection range >= 2m */
			subject robot : DisabilityRobot;
			require constraint {
				robot.navigationSystem.lidar.range >= 2.0[SI::m]
			}
		}
		
		requirement payloadCapacity {
			doc /* The manipulator shall handle objects up to 5 kg */
			subject robot : DisabilityRobot;
			require constraint {
				robot.manipulatorArm.payloadCapacity >= 5.0[SI::kg]
			}
		}
	}
	
	part assistanceSystem {
		part disabilityRobot : DisabilityRobot {
			:>> batteryLevel = 100.0;
			:>> obstacleDetected = false;
			
			perform action primaryTaskExecution : ExecuteTask;
			
			part :>> mobilityBase {
				:>> maxSpeed = 2.0[SI::'m/s'];
				:>> wheelDiameter = 0.15[SI::m];
			}
			
			part :>> navigationSystem {
				part :>> lidar {
					:>> scanRate = 10.0[SI::Hz];
					:>> range = 10.0[SI::m];
					:>> accuracy = 0.03[SI::m];
				}
				part :>> imu {
					:>> updateRate = 100.0[SI::Hz];
				}
			}
			
			part :>> manipulatorArm {
				:>> reachDistance = 0.9[SI::m];
				:>> payloadCapacity = 5.0[SI::kg];
				
				part :>> endEffector {
					:>> maxGraspWidth = 0.12[SI::m];
					:>> graspForce = 50.0[SI::N];
				}
			}
			
			part :>> visionSystem {
				:>> fieldOfView = 110.0;
				:>> detectionRange = 5.0[SI::m];
				
				part :>> cameras {
					:>> resolution = 1920 * 1080;
					:>> frameRate = 60.0[SI::Hz];
				}
			}
			
			part :>> controlSystem {
				part :>> mainProcessor {
					:>> clockSpeed = 3.0e9[SI::Hz];
					:>> cores = 8;
					:>> memory = 16;
				}
			}
			
			part :>> powerSystem {
				:>> maxCapacity = 50000.0[SI::'W·h'];
				:>> currentCharge = 50000.0[SI::'W·h'];
				
				part :>> batteryPack {
					:>> voltage = 48.0;
					:>> capacity = 50000.0[SI::'W·h'];
					:>> chemistry = "Lithium-Ion";
				}
			}
		}
		
		part chargingStation : ChargingStation {
			part :>> chargingDock {
				:>> outputPower = 1000.0[SI::W];
				:>> chargingVoltage = 48.0;
			}
		}
		
		part userInterface : UserInterface;
		
		connect userInterface.requestPort to disabilityRobot.commInterface;
		connect chargingStation.chargingPort to disabilityRobot.powerInterface;
		connect chargingStation.dataPort to disabilityRobot.commInterface;
		
		connect disabilityRobot.navigationSystem.sensors to disabilityRobot.sensorInterface;
		connect disabilityRobot.mobilityBase.actuators to disabilityRobot.actuatorInterface;
		connect disabilityRobot.manipulatorArm.manipulator to disabilityRobot.manipulatorInterface;
		
		satisfy systemRequirements by disabilityRobot;
	}
	
	requirement systemRequirements : SystemRequirements {
		subject testRobot :> assistanceSystem.disabilityRobot;
	}
	
	package LogicalModel {
		action def ProvideAssistance;
		action def PerformNavigation;
		action def PerformManipulation;
		
		part def AssistanceProvider {
			perform assistanceCapability : ProvideAssistance;
		}
		
		part assistanceProvider : AssistanceProvider {
			action navigationCapability : PerformNavigation;
			action manipulationCapability : PerformManipulation;
		}
	}
	
	package PhysicalModel {
		private import LogicalModel::*;
		
		allocate assistanceProvider to assistanceSystem.disabilityRobot {
			allocate assistanceProvider.navigationCapability 
				to assistanceSystem.disabilityRobot.navigationSystem.pathPlanner.planPath;
			allocate assistanceProvider.manipulationCapability 
				to assistanceSystem.disabilityRobot.manipulatorArm;
		}
	}
}
