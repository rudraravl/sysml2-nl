package 'Autonomous Robotic System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	attribute def BatteryLevel :> Real {
		doc /* Battery charge level as percentage */
	}

	attribute def Position {
		attribute x : LengthValue;
		attribute y : LengthValue;
		attribute z : LengthValue;
	}

	attribute def Velocity {
		attribute vx : SpeedValue;
		attribute vy : SpeedValue;
		attribute vz : SpeedValue;
	}

	enum def TaskStatus {
		enum idle;
		enum navigating;
		enum executing;
		enum completed;
		enum failed;
	}

	enum def ObstacleStatus {
		enum clear;
		enum detected;
		enum critical;
	}

	item def SensorData {
		attribute currentPosition : Position;
		attribute obstacleStatus : ObstacleStatus;
		attribute batteryLevel : BatteryLevel;
	}

	item def NavigationCommand {
		attribute targetPosition : Position;
		attribute maxSpeed : SpeedValue;
	}

	item def TaskCommand {
		attribute taskType : String;
		attribute targetLocation : Position;
		attribute priority : Integer;
	}

	port def SensorPort {
		out sensorData : SensorData;
	}

	port def ControlPort {
		in navigationCmd : NavigationCommand;
		in taskCmd : TaskCommand;
		out statusReport : TaskStatus;
	}

	port def ActuatorPort {
		in movementCmd : NavigationCommand;
		out currentVelocity : Velocity;
	}

	port def PowerPort {
		out batteryLevel : BatteryLevel;
		in chargingSignal : Boolean;
	}

	package LogicalModel {
		action def SenseEnvironment {
			out environmentData : SensorData;
		}

		action def PlanPath {
			in sensed : SensorData;
			in target : Position;
			out plannedRoute : NavigationCommand;
		}

		action def NavigateToTarget {
			in route : NavigationCommand;
			in currentPos : Position;
			in obstacleInfo : ObstacleStatus;
			out navigationStatus : TaskStatus;
		}

		action def ExecuteTask {
			in location : Position;
			in taskType : String;
			out executionStatus : TaskStatus;
		}

		action def MonitorBattery {
			out chargeLevel : BatteryLevel;
		}

		action def PerformPrimaryTask {
			in taskParameters : TaskCommand;
			in availableEnergy : BatteryLevel;
			out taskResult : TaskStatus;

			first start;
			then merge continueTask;

			then action sense : SenseEnvironment {
				out envData : SensorData;
			}

			then action checkBattery : MonitorBattery {
				out batteryStatus : BatteryLevel;
			}

			then decide;
				if checkBattery.batteryStatus < 20.0 then returnToCharge;
				if checkBattery.batteryStatus >= 20.0 then planNavigation;

			action planNavigation : PlanPath {
				in sensed = sense.envData;
				in target = taskParameters.targetLocation;
				out route : NavigationCommand;
			}
			then navigate;

			action navigate : NavigateToTarget {
				in route = planNavigation.route;
				in currentPos = sense.envData.currentPosition;
				in obstacleInfo = sense.envData.obstacleStatus;
				out navStatus : TaskStatus;
			}

			then decide;
				if navigate.navStatus == TaskStatus::failed then continueTask;
				if navigate.navStatus == TaskStatus::completed then executeWork;

			action executeWork : ExecuteTask {
				in location = taskParameters.targetLocation;
				in taskType = taskParameters.taskType;
				out workStatus : TaskStatus;
			}

			then decide;
				if executeWork.workStatus == TaskStatus::completed then done;
				if executeWork.workStatus == TaskStatus::failed then continueTask;

			action returnToCharge {
				doc /* Navigate to charging station */
			}
			then done;

			then done;
		}

		part def AutonomousController {
			attribute currentTaskStatus : TaskStatus;
			action controllerOperation : PerformPrimaryTask;
		}

		part def SensorSystem {
			action sensingOperation : SenseEnvironment;
		}

		part def NavigationSystem {
			action navigatingOperation : NavigateToTarget;
		}

		part def TaskExecutor {
			action executingOperation : ExecuteTask;
		}

		part def PowerManagement {
			action monitoringOperation : MonitorBattery;
		}

		part autonomousRobotLogical {
			part controller : AutonomousController;
			part sensors : SensorSystem;
			part navigator : NavigationSystem;
			part executor : TaskExecutor;
			part powerMgmt : PowerManagement;
		}
	}

	package PhysicalModel {
		private import LogicalModel::*;

		state def RobotOperationalStates {
			entry; then initializing;

			state initializing {
				entry; then systemCheck;
				action systemCheck {
					doc /* Verify all subsystems operational */
				}
			}
			then standby;

			state standby;
			accept taskCmd : TaskCommand
			then active;

			state active {
				state navigation {
					entry; then sensing;

					state sensing {
						do action sense : SenseEnvironment;
					}
					then deciding;

					state deciding {
						do action plan : PlanPath;
					}
					then moving;

					state moving;
					then taskExecution;
				}

				state taskExecution {
					do action execute : ExecuteTask;
				}
				then standby;
			}
			then charging;

			state charging {
				entry; then chargingActive;
				action chargingActive {
					doc /* Connect to charging station and charge */
				}
			}
			then standby;

			state emergency;
		}

		part def LidarSensor {
			port sensorOut : SensorPort;
			attribute scanRange : LengthValue = 10.0[m];
			attribute scanResolution : Real = 0.1;
		}

		part def CameraModule {
			port imageOut : SensorPort;
			attribute resolution : String = "1920x1080";
			attribute frameRate : Real = 30.0;
		}

		part def MotorController {
			port actuatorIn : ActuatorPort;
			attribute maxTorque : Real = 50.0;
			attribute efficiency : Real = 0.92;
		}

		part def WheelAssembly {
			attribute diameter : LengthValue = 0.2[m];
			attribute width : LengthValue = 0.08[m];
		}

		part def BatteryPack {
			port powerOut : PowerPort;
			attribute capacity : Real = 5000.0;
			attribute voltage : Real = 48.0;
			attribute currentCharge : BatteryLevel;
		}

		part def ProcessingUnit {
			attribute processorSpeed : Real = 2.4;
			attribute memory : Real = 16.0;
			attribute storage : Real = 512.0;
			action processorOperation : PerformPrimaryTask;
		}

		part def RobotChassis {
			attribute length : LengthValue = 0.8[m];
			attribute width : LengthValue = 0.6[m];
			attribute height : LengthValue = 0.4[m];
			attribute mass : MassValue = 45.0[kg];
		}

		part def AutonomousRobot {
			part chassis : RobotChassis;

			part mainProcessor : ProcessingUnit {
				port controlInterface : ControlPort;
			}

			part lidar : LidarSensor {
				port redefines sensorOut;
			}

			part camera : CameraModule {
				port redefines imageOut;
			}

			part motorCtrl : MotorController[4] {
				port redefines actuatorIn;
			}

			part wheels : WheelAssembly[4];

			part battery : BatteryPack {
				port redefines powerOut;
				attribute redefines currentCharge = 100.0;
			}

			connection lidarToProcessor connect lidar.sensorOut to mainProcessor.controlInterface;
			connection cameraToProcessor connect camera.imageOut to mainProcessor.controlInterface;
			connection processorToMotors connect mainProcessor.controlInterface to motorCtrl.actuatorIn;
			connection batteryToPower connect battery.powerOut to mainProcessor.controlInterface;

			state robotBehavior : RobotOperationalStates;

			action primaryOperation : PerformPrimaryTask;
		}

		part roboticSystem {
			part robot : AutonomousRobot;

			requirement autonomousOperationReq {
				doc /* The robotic system shall perform its primary task autonomously */
				subject robotSubject = robot;

				require constraint {
					robot.primaryOperation.taskResult == TaskStatus::completed
				}
			}

			requirement batteryManagementReq {
				doc /* The robot shall monitor battery and return to charging when below 20% */
				subject batterySubject = robot;

				require constraint {
					robot.battery.currentCharge >= 20.0
				}
			}

			requirement obstacleAvoidanceReq {
				doc /* The robot shall detect and avoid obstacles during navigation */
				subject lidarSubject = robot;

				require constraint {
					robot.lidar.scanRange >= 5.0[m]
				}
			}

			requirement taskExecutionReq {
				doc /* The robot shall execute assigned tasks at target locations */
				subject taskSubject = robot;

				require constraint {
					robot.primaryOperation.taskResult == TaskStatus::completed or
					robot.primaryOperation.taskResult == TaskStatus::failed
				}
			}
		}

		allocation def LogicalToPhysicalAllocation {
			end logical : AutonomousController;
			end physical : AutonomousRobot;
		}

		allocate autonomousRobotLogical to roboticSystem.robot {
			allocate autonomousRobotLogical.controller to roboticSystem.robot.mainProcessor;
			allocate autonomousRobotLogical.sensors to roboticSystem.robot.lidar;
			allocate autonomousRobotLogical.navigator to roboticSystem.robot.motorCtrl;
			allocate autonomousRobotLogical.executor to roboticSystem.robot.mainProcessor;
			allocate autonomousRobotLogical.powerMgmt to roboticSystem.robot.battery;

			allocate autonomousRobotLogical.controller.controllerOperation 
				to roboticSystem.robot.mainProcessor.processorOperation;
		}

		satisfy roboticSystem.autonomousOperationReq by roboticSystem.robot.primaryOperation;
		satisfy roboticSystem.batteryManagementReq by roboticSystem.robot.battery;
		satisfy roboticSystem.obstacleAvoidanceReq by roboticSystem.robot.lidar;
		satisfy roboticSystem.taskExecutionReq by roboticSystem.robot.primaryOperation;
	}
}
