package 'Robotic System Model' {
	private import ScalarValues::*;
	private import SI::*;
	private import ISQ::*;
	
	package ValueTypes {
		attribute def BatteryLevel :> Real;
		
		attribute def Position {
			attribute x :> ISQ::length;
			attribute y :> ISQ::length;
			attribute z :> ISQ::length;
		}
		
		attribute def Velocity :> ISQ::speed;
		
		attribute def GripForce :> ISQ::force;
		
		enum def TaskStatus {
			enum idle;
			enum detecting;
			enum approaching;
			enum grasping;
			enum transporting;
			enum releasing;
			enum completed;
			enum failed;
		}
		
		enum def ObjectType {
			enum small;
			enum medium;
			enum large;
		}
	}
	
	package ItemDefinitions {
		private import ValueTypes::*;
		
		item def TargetObject {
			attribute objectType : ObjectType;
			attribute mass :> ISQ::mass;
			attribute position : Position;
		}
		
		item def Operator;
		
		item def ElectricalPower {
			attribute voltage :> ISQ::voltage;
			attribute current :> ISQ::electricCurrent;
		}
	}
	
	package InterfaceDefinitions {
		private import ValueTypes::*;
		
		port def PowerPort {
			attribute voltage :> ISQ::voltage;
			attribute current :> ISQ::electricCurrent;
		}
		
		port def ControlBus {
			in attribute commandData : String;
			out attribute statusData : String;
		}
		
		port def SensorDataPort {
			out attribute detectionData : Boolean;
			out attribute distanceData :> ISQ::length;
			out attribute positionData : Position;
		}
		
		port def ActuatorControlPort {
			in attribute targetPosition : Position;
			in attribute targetForce :> ISQ::force;
			out attribute actualPosition : Position;
			out attribute actualForce :> ISQ::force;
		}
	}
	
	package RequirementModel {
		private import ValueTypes::*;
		
		requirement def SystemRequirement;
		
		requirement primaryTaskCompletion : SystemRequirement {
			doc /* The robotic system shall successfully complete its primary task of detecting, grasping, and relocating target objects. */
			subject robotExecutor : LogicalModel::RoboticTaskExecutor;
			require constraint {
				robotExecutor.performTask.taskSuccess
			}
		}
		
		requirement operationalPower : SystemRequirement {
			doc /* The robotic system shall maintain battery level above minimum threshold during operation. */
			subject robotKit : PhysicalModel::RobotKit;
			require constraint {
				robotKit.powerModule.batteryLevel > 15.0
			}
		}
		
		requirement safeOperatingSpeed : SystemRequirement {
			doc /* The robotic system shall not exceed maximum safe velocity during navigation. */
			subject robotKit : PhysicalModel::RobotKit;
			require constraint {
				robotKit.navigationModule.currentVelocity <= robotKit.navigationModule.maxSafeVelocity
			}
		}
		
		requirement graspingCapability : SystemRequirement {
			doc /* The manipulation system shall apply sufficient grip force to secure objects. */
			subject robotKit : PhysicalModel::RobotKit;
			require constraint {
				robotKit.manipulationModule.gripper.appliedForce >= 10.0 [SI::N] and
				robotKit.manipulationModule.gripper.appliedForce <= 100.0 [SI::N]
			}
		}
	}
	
	package ActionDefinitions {
		private import ValueTypes::*;
		private import ItemDefinitions::*;
		
		action def DetectObject {
			out objectDetected : Boolean;
			out objectPosition : Position;
			out objectDistance :> ISQ::length;
		}
		
		action def NavigateToPosition {
			in targetPosition : Position;
			in currentPosition : Position;
			out navigationComplete : Boolean;
			out finalPosition : Position;
		}
		
		action def GraspObject {
			in targetObject : TargetObject;
			in gripForce : GripForce;
			out graspSuccessful : Boolean;
			out heldObject : TargetObject;
		}
		
		action def TransportObject {
			in heldObject : TargetObject;
			in destinationPosition : Position;
			out transportComplete : Boolean;
		}
		
		action def ReleaseObject {
			in heldObject : TargetObject;
			out releaseSuccessful : Boolean;
		}
		
		action def MonitorPowerLevel {
			out batteryLevel : BatteryLevel;
			out powerSufficient : Boolean;
		}
		
		action def PerformPrimaryTask {
			in targetDestination : Position;
			out taskSuccess : Boolean;
			out finalStatus : TaskStatus;
			
			first start;
			then merge powerCheckLoop;
			
			action powerCheckAction : MonitorPowerLevel {
				out powerOk : Boolean;
			}
			
			then decide;
				if powerCheckAction.powerOk then detectPhaseAction;
				if !powerCheckAction.powerOk then taskFailedAction;
			
			action detectPhaseAction : DetectObject {
				out detected : Boolean;
				out targetPos : Position;
			}
			
			then decide;
				if detectPhaseAction.detected then navigateToObjectAction;
				if !detectPhaseAction.detected then powerCheckLoop;
			
			action navigateToObjectAction : NavigateToPosition {
				in targetPosition = detectPhaseAction.targetPos;
				out navComplete : Boolean;
			}
			
			then decide;
				if navigateToObjectAction.navComplete then graspPhaseAction;
				if !navigateToObjectAction.navComplete then taskFailedAction;
			
			action graspPhaseAction : GraspObject {
				in gripForce = 50.0 [SI::N];
				out grasped : Boolean;
				out object : TargetObject;
			}
			
			then decide;
				if graspPhaseAction.grasped then transportPhaseAction;
				if !graspPhaseAction.grasped then taskFailedAction;
			
			action transportPhaseAction : TransportObject {
				in heldObject = graspPhaseAction.object;
				in destinationPosition = targetDestination;
				out transported : Boolean;
			}
			
			then decide;
				if transportPhaseAction.transported then releasePhaseAction;
				if !transportPhaseAction.transported then taskFailedAction;
			
			action releasePhaseAction : ReleaseObject {
				in heldObject = graspPhaseAction.object;
				out released : Boolean;
			}
			
			then decide;
				if releasePhaseAction.released then taskCompletedAction;
				if !releasePhaseAction.released then taskFailedAction;
			
			action taskCompletedAction {
				out success = true;
			}
			then done;
			
			action taskFailedAction {
				out success = false;
			}
			then done;
		}
	}
	
	package ComponentDefinitions {
		private import ValueTypes::*;
		private import InterfaceDefinitions::*;
		private import ActionDefinitions::*;
		
		part def PowerModule {
			port powerOutput : PowerPort;
			attribute batteryLevel : BatteryLevel;
			attribute capacity : Real;
			attribute outputVoltage :> ISQ::voltage;
			
			perform action monitorPower : MonitorPowerLevel;
		}
		
		part def ControlModule {
			port controlBus : ControlBus;
			attribute processorSpeed : Real;
			attribute memoryCapacity : Real;
			
			perform action coordinateTask : PerformPrimaryTask;
		}
		
		part def VisionSensor {
			port sensorOutput : SensorDataPort;
			attribute fieldOfView : Real;
			attribute detectionRange :> ISQ::length;
			attribute resolution : String;
			
			perform action detect : DetectObject;
		}
		
		part def NavigationModule {
			attribute currentPosition : Position;
			attribute currentVelocity : Velocity;
			attribute maxSafeVelocity : Velocity;
			
			part wheel[4] {
				attribute diameter :> ISQ::length;
				attribute rotationSpeed : Real;
			}
			
			part driveMotor[4] {
				port motorControl : ActuatorControlPort;
				attribute maxTorque :> ISQ::torque;
			}
			
			perform action navigate : NavigateToPosition;
		}
		
		part def ManipulationModule {
			attribute reachRadius :> ISQ::length;
			attribute maxPayload :> ISQ::mass;
			
			part armJoint[6] {
				port jointControl : ActuatorControlPort;
				attribute angleRange : Real;
				attribute maxTorque :> ISQ::torque;
			}
			
			part gripper {
				attribute maxOpening :> ISQ::length;
				attribute appliedForce : GripForce;
				
				perform action grasp : GraspObject;
				perform action release : ReleaseObject;
			}
			
			perform action transport : TransportObject;
		}
		
		part def ProximitySensor {
			port sensorOutput : SensorDataPort;
			attribute sensingRange :> ISQ::length;
			attribute accuracy :> ISQ::length;
		}
	}
	
	package LogicalModel {
		private import ValueTypes::*;
		private import ActionDefinitions::*;
		private import RequirementModel::*;
		
		part def RoboticTaskExecutor {
			attribute taskType : String;
			attribute operatingMode : TaskStatus;
			
			perform action performTask : PerformPrimaryTask;
		}
		
		part roboticTaskExecutor : RoboticTaskExecutor {
			attribute redefines taskType = "PickAndPlace";
			attribute redefines operatingMode = TaskStatus::idle;
		}
		
		satisfy primaryTaskCompletion by roboticTaskExecutor;
	}
	
	package PhysicalModel {
		private import ValueTypes::*;
		private import ItemDefinitions::*;
		private import InterfaceDefinitions::*;
		private import ComponentDefinitions::*;
		private import ActionDefinitions::*;
		private import LogicalModel::*;
		private import RequirementModel::*;
		
		part def RobotKit {
			attribute serialNumber : String;
			attribute totalMass :> ISQ::mass;
			attribute operatingTemperature :> ISQ::temperature;
			
			ref item operator : Operator;
			
			part powerModule : PowerModule {
				attribute redefines batteryLevel = 100.0;
				attribute redefines capacity = 8000.0;
				attribute redefines outputVoltage = 48.0 [SI::V];
			}
			
			part controlModule : ControlModule {
				attribute redefines processorSpeed = 3.2;
				attribute redefines memoryCapacity = 16.0;
			}
			
			part visionSensor : VisionSensor {
				attribute redefines fieldOfView = 120.0;
				attribute redefines detectionRange = 5.0 [SI::m];
				attribute redefines resolution = "1920x1080";
			}
			
			part navigationModule : NavigationModule {
				attribute redefines maxSafeVelocity = 1.5 [SI::m/SI::s];
				attribute redefines currentVelocity = 0.0 [SI::m/SI::s];
			}
			
			part manipulationModule : ManipulationModule {
				attribute redefines reachRadius = 0.9 [SI::m];
				attribute redefines maxPayload = 8.0 [SI::kg];
			}
			
			part proximitySensor[4] : ProximitySensor {
				attribute redefines sensingRange = 2.0 [SI::m];
				attribute redefines accuracy = 0.01 [SI::m];
			}
			
			connection powerDistribution1 connect 
				powerModule.powerOutput to controlModule.controlBus;
			
			connection powerDistribution2 connect 
				powerModule.powerOutput to visionSensor.sensorOutput;
			
			connection sensorDataFlow connect 
				visionSensor.sensorOutput to controlModule.controlBus;
			
			connection navigationControl1 connect 
				controlModule.controlBus to navigationModule.driveMotor[1].motorControl;
			
			connection manipulatorControl1 connect 
				controlModule.controlBus to manipulationModule.armJoint[1].jointControl;
			
			perform action executeTask : PerformPrimaryTask {
				action redefines powerCheckAction = powerModule.monitorPower;
				action redefines detectPhaseAction = visionSensor.detect;
				action redefines navigateToObjectAction = navigationModule.navigate;
				action redefines graspPhaseAction = manipulationModule.gripper.grasp;
				action redefines transportPhaseAction = manipulationModule.transport;
				action redefines releasePhaseAction = manipulationModule.gripper.release;
			}
		}
		
		part robotKit : RobotKit {
			attribute redefines serialNumber = "RBT-KIT-2025-A1";
			attribute redefines totalMass = 52.0 [SI::kg];
			attribute redefines operatingTemperature = 298.15 [SI::K];
		}
		
		satisfy operationalPower by robotKit;
		satisfy safeOperatingSpeed by robotKit;
		satisfy graspingCapability by robotKit;
	}
	
	package AllocationModel {
		private import LogicalModel::*;
		private import PhysicalModel::*;
		
		allocation def LogicalToPhysicalAllocation {
			end logical : RoboticTaskExecutor;
			end physical : RobotKit;
		}
		
		allocation taskExecutionAllocation : LogicalToPhysicalAllocation
			allocate logical ::> roboticTaskExecutor to physical ::> robotKit {
			doc /* This allocation maps the logical task executor to the physical robot kit implementation. */
			allocate roboticTaskExecutor.performTask to robotKit.executeTask;
			allocate roboticTaskExecutor.performTask.powerCheckAction to robotKit.powerModule.monitorPower;
			allocate roboticTaskExecutor.performTask.detectPhaseAction to robotKit.visionSensor.detect;
			allocate roboticTaskExecutor.performTask.navigateToObjectAction to robotKit.navigationModule.navigate;
			allocate roboticTaskExecutor.performTask.graspPhaseAction to robotKit.manipulationModule.gripper.grasp;
			allocate roboticTaskExecutor.performTask.transportPhaseAction to robotKit.manipulationModule.transport;
			allocate roboticTaskExecutor.performTask.releasePhaseAction to robotKit.manipulationModule.gripper.release;
		}
	}
}
