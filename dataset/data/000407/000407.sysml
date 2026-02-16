package 'Insectoid Robotic System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import Time::*;
	
	package DataTypes {
		attribute def Position3D {
			attribute x :> ISQ::length;
			attribute y :> ISQ::length;
			attribute z :> ISQ::length;
		}
		
		attribute def Orientation {
			attribute roll : Real;
			attribute pitch : Real;
			attribute yaw : Real;
		}
		
		attribute def JointAngle :> Real;
		
		attribute def BatteryLevel :> Real;
		
		item def SensorReading {
			attribute timestamp : Real;
			attribute value : Real;
			attribute quality : Real;
		}
		
		item def MotorCommand {
			attribute jointId : String;
			attribute targetAngle : Real;
			attribute targetVelocity : Real;
		}
		
		item def NavigationData {
			attribute currentX : Real;
			attribute currentY : Real;
			attribute currentZ : Real;
			attribute targetX : Real;
			attribute targetY : Real;
			attribute targetZ : Real;
			attribute obstacleDetected : Boolean;
			attribute obstacleDistance : Real;
		}
		
		port def SensorDataPort {
			out item reading : SensorReading;
		}
		
		port def MotorControlPort {
			in item command : MotorCommand;
		}
		
		port def PowerPort {
			attribute voltage : Real;
			attribute current : Real;
		}
		
		port def CommunicationPort {
			in item commandData : NavigationData;
			out item statusData : NavigationData;
		}
	}
	
	package LogicalModel {
		private import DataTypes::*;
		
		action def NavigateToTarget {
			in startX : Real;
			in startY : Real;
			in startZ : Real;
			in targetX : Real;
			in targetY : Real;
			in targetZ : Real;
			out pathCompleted : Boolean;
			out distanceTraveled : Real;
		}
		
		action def DetectEnvironment {
			out obstacleDetected : Boolean;
			out obstacleDistance : Real;
			out terrainType : String;
		}
		
		action def GraspObject {
			in objectX : Real;
			in objectY : Real;
			in objectZ : Real;
			in gripForce : Real;
			out graspSuccess : Boolean;
		}
		
		action def TransportObject {
			in destinationX : Real;
			in destinationY : Real;
			in destinationZ : Real;
			out transportSuccess : Boolean;
		}
		
		action def ExecutePrimaryTask {
			in targetLocationX : Real;
			in targetLocationY : Real;
			in targetLocationZ : Real;
			in objectLocationX : Real;
			in objectLocationY : Real;
			in objectLocationZ : Real;
			in returnLocationX : Real;
			in returnLocationY : Real;
			in returnLocationZ : Real;
			out taskSuccess : Boolean;
			out obstacleAvoidanceSuccess : Boolean;
			
			first start;
			then merge navigationLoop;
			
			then action navigateToObject : NavigateToTarget {
				in startX = 0.0;
				in startY = 0.0;
				in startZ = 0.0;
				in targetX = objectLocationX;
				in targetY = objectLocationY;
				in targetZ = objectLocationZ;
			}
			
			then action detectObstacles : DetectEnvironment;
			
			then decide obstacleCheck;
				if detectObstacles.obstacleDetected then avoidObstacle;
				else proceedToGrasp;
			
			action avoidObstacle {
				do action recalculateRoute : NavigateToTarget;
			}
			then assign obstacleAvoidanceSuccess := true;
			then navigationLoop;
			
			action proceedToGrasp;
			then action graspObject : GraspObject {
				in objectX = objectLocationX;
				in objectY = objectLocationY;
				in objectZ = objectLocationZ;
				in gripForce = 75.0;
			}
			
			then decide graspCheck;
				if graspObject.graspSuccess then transportObject;
				else retryGrasp;
			
			action retryGrasp {
				do action retryGraspAction : GraspObject;
			}
			then transportObject;
			
			action transportObject : TransportObject {
				in destinationX = returnLocationX;
				in destinationY = returnLocationY;
				in destinationZ = returnLocationZ;
			}
			
			then action releaseObject;
			
			then assign taskSuccess := graspObject.graspSuccess and transportObject.transportSuccess;
			then done;
		}
		
		part def LogicalElement;
		
		part def TaskExecutionUnit :> LogicalElement {
			perform action primaryTask : ExecutePrimaryTask;
		}
		
		part taskExecutor : TaskExecutionUnit {
			perform primaryTask;
		}
	}
	
	package PhysicalModel {
		private import DataTypes::*;
		private import LogicalModel::*;
		
		part def PhysicalElement;
		
		part def LegSegment {
			attribute segmentLength : LengthValue;
			attribute jointAngle : Real;
			
			part actuator {
				attribute maxTorque : Real;
				port motorPort : MotorControlPort;
			}
			
			part positionSensor {
				port sensorPort : SensorDataPort;
			}
		}
		
		part def Leg {
			attribute legId : Integer;
			attribute totalLength : LengthValue;
			
			part coxa : LegSegment {
				attribute :>> segmentLength = 0.05 [m];
			}
			
			part femur : LegSegment {
				attribute :>> segmentLength = 0.08 [m];
			}
			
			part tibia : LegSegment {
				attribute :>> segmentLength = 0.10 [m];
			}
			
			part footContactSensor {
				port sensorPort : SensorDataPort;
				attribute contactForce : Real;
			}
		}
		
		part def LocomotionSystem {
			attribute numberOfLegs : Integer;
			attribute currentGait : String;
			attribute walkingSpeed : Real;
			
			part legs : Leg[6] {
				attribute :>> totalLength = 0.23 [m];
			}
			
			action def ExecuteGait {
				in gaitPattern : String;
				in targetSpeed : Real;
				out legCommandsGenerated : Boolean;
			}
			
			state locomotionControl {
				entry; then stationary;
				
				state stationary {
					entry assign currentGait := "stopped";
				}
				
				transition start_walking
					first stationary
					accept at startWalkCommand
					then walking;
				
				state walking {
					entry assign currentGait := "tripod";
					do action executeGait : ExecuteGait {
						in gaitPattern = currentGait;
						in targetSpeed = 0.3;
					}
				}
				
				transition switch_to_climbing
					first walking
					accept at terrainChange
					then climbing;
				
				state climbing {
					entry assign currentGait := "wave";
					do action executeGait : ExecuteGait {
						in gaitPattern = currentGait;
						in targetSpeed = 0.15;
					}
				}
				
				transition climbing_to_walking
					first climbing
					accept at flatTerrain
					then walking;
				
				transition stop_walking
					first walking
					accept at stopCommand
					then stationary;
				
				transition stop_climbing
					first climbing
					accept at stopCommand
					then stationary;
			}
		}
		
		part def SensorSubsystem {
			part proximityFront {
				port sensorPort : SensorDataPort;
				attribute range : LengthValue = 2.0 [m];
				attribute fieldOfView : Real = 60.0;
			}
			
			part proximityLeft {
				port sensorPort : SensorDataPort;
				attribute range : LengthValue = 1.5 [m];
			}
			
			part proximityRight {
				port sensorPort : SensorDataPort;
				attribute range : LengthValue = 1.5 [m];
			}
			
			part imu {
				port sensorPort : SensorDataPort;
				attribute accelerationRange : Real = 16.0;
				attribute gyroRange : Real = 2000.0;
			}
			
			part visionSystem {
				port sensorPort : SensorDataPort;
				attribute resolutionX : Integer = 1920;
				attribute resolutionY : Integer = 1080;
				attribute frameRate : Real = 30.0;
			}
			
			part lidar {
				port sensorPort : SensorDataPort;
				attribute maxRange : LengthValue = 10.0 [m];
				attribute angularResolution : Real = 0.25;
			}
		}
		
		part def ManipulatorSubsystem {
			part shoulder {
				attribute jointAngle : Real;
				port motorPort : MotorControlPort;
			}
			
			part elbow {
				attribute jointAngle : Real;
				port motorPort : MotorControlPort;
			}
			
			part wrist {
				attribute jointAngle : Real;
				port motorPort : MotorControlPort;
			}
			
			part gripper {
				attribute gripWidth : LengthValue;
				attribute maxGripForce : Real = 100.0;
				port motorPort : MotorControlPort;
				port forceSensorPort : SensorDataPort;
			}
			
			action def PositionArm {
				in targetX : Real;
				in targetY : Real;
				in targetZ : Real;
				out armPositioned : Boolean;
			}
			
			action def CloseGripper {
				in targetForce : Real;
				out gripAchieved : Boolean;
			}
		}
		
		part def PowerSubsystem {
			attribute batteryCapacity : Real = 10000.0;
			attribute batteryLife : Real = 7200.0;
			attribute currentCharge : Real = 100.0;
			
			part mainBattery {
				attribute voltage : Real = 24.0;
				attribute capacity : Real = 10000.0;
				port powerOut : PowerPort;
			}
			
			part powerDistributionUnit {
				port powerIn : PowerPort;
				port locomotionPower : PowerPort[6];
				port sensorPower : PowerPort[6];
				port manipulatorPower : PowerPort;
				port computePower : PowerPort;
			}
			
			connection batteryToPDU : PowerPort connect mainBattery.powerOut to powerDistributionUnit.powerIn;
		}
		
		part def ControlSubsystem {
			part mainProcessor {
				attribute processingSpeed : Real = 2.5;
				attribute memory : Integer = 8192;
			}
			
			part motorController {
				attribute numberOfChannels : Integer = 24;
			}
			
			action def ProcessSensorInputs {
				in sensorCount : Integer;
				out environmentModelReady : Boolean;
			}
			
			action def PlanTrajectory {
				in currentX : Real;
				in currentY : Real;
				in currentZ : Real;
				in targetX : Real;
				in targetY : Real;
				in targetZ : Real;
				out trajectoryReady : Boolean;
			}
			
			action def ExecuteMotorCommands {
				in commandCount : Integer;
				out commandsSent : Boolean;
			}
			
			state controlLoop {
				entry; then initialize;
				
				state initialize {
					do action systemCheck;
				}
				
				transition init_complete
					first initialize
					accept at systemReady
					then operational;
				
				state operational {
					entry; then sense;
					
					state sense {
						do action processSensors : ProcessSensorInputs {
							in sensorCount = 6;
						}
					}
					then plan;
					
					state plan {
						do action planTrajectory : PlanTrajectory;
					}
					then execute;
					
					state execute {
						do action executeCommands : ExecuteMotorCommands {
							in commandCount = 24;
						}
					}
					then sense;
				}
				
				transition emergency_stop
					first operational
					accept at emergencySignal
					then emergency;
				
				state emergency {
					do action haltAllSystems;
				}
				
				transition emergency_clear
					first emergency
					accept at emergencyClear
					then operational;
			}
		}
		
		part def InsectoidRobot :> PhysicalElement {
			attribute currentPositionX : Real;
			attribute currentPositionY : Real;
			attribute currentPositionZ : Real;
			attribute currentOrientationRoll : Real;
			attribute currentOrientationPitch : Real;
			attribute currentOrientationYaw : Real;
			attribute operationalStatus : String;
			
			port commPort : CommunicationPort;
			
			part locomotionSystem : LocomotionSystem {
				attribute :>> numberOfLegs = 6;
				attribute :>> walkingSpeed = 0.3;
			}
			
			part sensorSubsystem : SensorSubsystem;
			
			part manipulatorSubsystem : ManipulatorSubsystem;
			
			part powerSubsystem : PowerSubsystem {
				attribute :>> batteryLife = 7200.0;
			}
			
			part controlSubsystem : ControlSubsystem;
			
			part bodyFrame {
				attribute mass : MassValue = 5.0 [kg];
				attribute lengthDim : LengthValue = 0.3 [m];
				attribute widthDim : LengthValue = 0.2 [m];
				attribute heightDim : LengthValue = 0.15 [m];
			}
			
			action performPrimaryTask : ExecutePrimaryTask {
				first start;
				then merge taskLoop;
				
				then action navigateToObject : NavigateToTarget {
					in startX = currentPositionX;
					in startY = currentPositionY;
					in startZ = currentPositionZ;
					in targetX = performPrimaryTask.objectLocationX;
					in targetY = performPrimaryTask.objectLocationY;
					in targetZ = performPrimaryTask.objectLocationZ;
				}
				
				then action detectObstacles : DetectEnvironment;
				
				then decide obstacleCheck;
					if detectObstacles.obstacleDetected then avoidObstacle;
					else proceedToGrasp;
				
				action avoidObstacle {
					do action recalculateRoute : NavigateToTarget;
				}
				then assign performPrimaryTask.obstacleAvoidanceSuccess := true;
				then taskLoop;
				
				action proceedToGrasp;
				then action positionArm : manipulatorSubsystem.PositionArm {
					in targetX = performPrimaryTask.objectLocationX;
					in targetY = performPrimaryTask.objectLocationY;
					in targetZ = performPrimaryTask.objectLocationZ;
				}
				
				then action graspObject : GraspObject {
					in objectX = performPrimaryTask.objectLocationX;
					in objectY = performPrimaryTask.objectLocationY;
					in objectZ = performPrimaryTask.objectLocationZ;
					in gripForce = 75.0;
				}
				
				then decide graspCheck;
					if graspObject.graspSuccess then transportObject;
					else retryGrasp;
				
				action retryGrasp {
					do action retryGraspAction : GraspObject;
				}
				then transportObject;
				
				action transportObject : TransportObject {
					in destinationX = performPrimaryTask.returnLocationX;
					in destinationY = performPrimaryTask.returnLocationY;
					in destinationZ = performPrimaryTask.returnLocationZ;
				}
				
				then action releaseObject {
					do action openGripper : manipulatorSubsystem.CloseGripper {
						in targetForce = 0.0;
					}
				}
				
				then assign performPrimaryTask.taskSuccess := graspObject.graspSuccess and transportObject.transportSuccess;
				then done;
			}
		}
		
		part insectoidRobot : InsectoidRobot {
			perform taskExecutor.primaryTask :>> performPrimaryTask;
		}
	}
	
	package RequirementModel {
		private import PhysicalModel::*;
		
		requirement def InsectoidFormRequirement {
			subject robot : InsectoidRobot;
			require constraint {
				robot.locomotionSystem.numberOfLegs >= 6 and
				robot.locomotionSystem.numberOfLegs <= 8
			}
		}
		
		requirement def TaskCompletionRequirement {
			subject robot : InsectoidRobot;
			require constraint {
				robot.performPrimaryTask.taskSuccess == true
			}
		}
		
		requirement def PowerEnduranceRequirement {
			subject robot : InsectoidRobot;
			require constraint {
				robot.powerSubsystem.batteryLife >= 3600.0
			}
		}
		
		requirement def ObstacleAvoidanceRequirement {
			subject robot : InsectoidRobot;
			require constraint {
				robot.performPrimaryTask.obstacleAvoidanceSuccess == true
			}
		}
		
		requirement def ManipulationRequirement {
			subject robot : InsectoidRobot;
			require constraint {
				robot.manipulatorSubsystem.gripper.maxGripForce >= 50.0
			}
		}
		
		satisfy InsectoidFormRequirement by PhysicalModel::insectoidRobot;
		satisfy TaskCompletionRequirement by PhysicalModel::insectoidRobot;
		satisfy PowerEnduranceRequirement by PhysicalModel::insectoidRobot;
		satisfy ObstacleAvoidanceRequirement by PhysicalModel::insectoidRobot;
		satisfy ManipulationRequirement by PhysicalModel::insectoidRobot;
	}
	
	package SystemIntegration {
		private import PhysicalModel::*;
		private import LogicalModel::*;
		private import DataTypes::*;
		
		part def ControlStation {
			port robotComm : ~CommunicationPort;
			
			part operatorInterface {
				attribute displayResolutionX : Integer = 1920;
				attribute displayResolutionY : Integer = 1080;
			}
			
			part missionPlanner {
				action def PlanMission {
					in missionObjectiveCount : Integer;
					out missionPlanReady : Boolean;
				}
			}
		}
		
		part def RoboticSystem {
			part robot : InsectoidRobot;
			part station : ControlStation;
			
			connection commLink : CommunicationPort connect station.robotComm to robot.commPort;
			
			perform robot.performPrimaryTask;
		}
		
		part roboticSystem : RoboticSystem {
			perform robot.performPrimaryTask;
		}
	}
	
	allocation def LogicalToPhysical {
		end logical : LogicalModel::LogicalElement;
		end physical : PhysicalModel::PhysicalElement;
	}
	
	allocation taskAllocation : LogicalToPhysical
		allocate logical ::> LogicalModel::taskExecutor
		to physical ::> PhysicalModel::insectoidRobot {
		allocate LogicalModel::taskExecutor.primaryTask
			to PhysicalModel::insectoidRobot.performPrimaryTask;
	}
}
