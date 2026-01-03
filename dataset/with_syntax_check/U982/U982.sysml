package AutomatedGuidedVehicleSystem {
	private import ISQ::*;
	private import SI::*;
	private import ScalarValues::*;
	private import SequenceFunctions::*;
	
	attribute def Percentage :> Real;
	
	item def Position2D {
		attribute x : LengthValue;
		attribute y : LengthValue;
		attribute theta : Real;
	}
	
	item def Waypoint {
		attribute location : Position2D;
		attribute waypointID : String;
		attribute taskType : TaskType;
	}
	
	enum def TaskType {
		enum pickup;
		enum delivery;
		enum charging;
		enum idle;
	}
	
	item def NavigationCommand {
		attribute targetWaypoint : Waypoint;
		attribute maxSpeed : SpeedValue;
		attribute priority : Integer;
	}
	
	item def ObstacleDetection {
		attribute obstacleDistance : LengthValue;
		attribute obstacleBearing : Real;
		attribute isPathBlocked : Boolean;
	}
	
	item def VehicleStatus {
		attribute currentPosition : Position2D;
		attribute currentSpeed : SpeedValue;
		attribute batteryLevel : Percentage;
		attribute loadStatus : LoadStatus;
		attribute operationalState : String;
	}
	
	enum def LoadStatus {
		enum empty;
		enum loaded;
		enum loading;
		enum unloading;
	}
	
	item def Payload {
		attribute mass : MassValue;
		attribute dimensions : LengthValue[3];
		attribute payloadID : String;
	}
	
	item def MotorCommand {
		attribute leftWheelTorque : TorqueValue;
		attribute rightWheelTorque : TorqueValue;
	}
	
	item def PowerSupply {
		attribute voltage : Real;
		attribute current : Real;
	}
	
	port def NavigationControlPort {
		in navCommand : NavigationCommand;
		out vehicleStatus : VehicleStatus;
	}
	
	port def SensorDataPort {
		out obstacleData : ObstacleDetection;
		out positionData : Position2D;
	}
	
	port def LoadHandlingPort {
		in loadCommand : String;
		out loadStatus : LoadStatus;
	}
	
	port def DriveControlPort {
		in motorCommand : MotorCommand;
		out wheelSpeed : SpeedValue[2];
	}
	
	port def PowerPort {
		in powerSupply : PowerSupply;
		out powerDemand : PowerValue;
	}
	
	port def ChargingPort {
		in chargingPower : PowerValue;
		out batteryStatus : Percentage;
	}
	
	part def VehicleController {
		port navControl : NavigationControlPort;
		port sensorInput : SensorDataPort;
		port driveOutput : DriveControlPort;
		port loadControl : LoadHandlingPort;
		
		attribute currentRoute : Waypoint[*];
		attribute routeIndex : Integer;
		attribute safetyOverride : Boolean;
	}
	
	part def ObstacleSensor {
		port sensorOutput : SensorDataPort;
		
		attribute detectionRange : LengthValue;
		attribute scanAngle : Real;
		attribute updateRate : Real;
	}
	
	part def PositioningSensor {
		port positionOutput : SensorDataPort;
		
		attribute accuracy : LengthValue;
		attribute updateFrequency : Real;
	}
	
	part def DifferentialDrive {
		port driveInput : DriveControlPort;
		port powerInput : PowerPort;
		
		part leftWheel : DriveWheel;
		part rightWheel : DriveWheel;
		
		attribute wheelBase : LengthValue;
		attribute maxTorque : TorqueValue;
	}
	
	part def DriveWheel {
		attribute wheelRadius : LengthValue;
		attribute wheelTorque : TorqueValue;
		attribute wheelSpeed : Real;
	}
	
	part def LoadingMechanism {
		port loadPort : LoadHandlingPort;
		port mechanismPower : PowerPort;
		
		part liftActuator : Actuator;
		part clampActuator : Actuator;
		
		attribute liftCapacity : MassValue;
		attribute liftHeight : LengthValue;
		attribute currentLoad : Payload[0..1];
	}
	
	part def Actuator {
		attribute actuatorForce : ForceValue;
		attribute actuatorPosition : LengthValue;
		attribute actuatorSpeed : SpeedValue;
	}
	
	part def BatteryPack {
		port powerOutput : PowerPort;
		port chargingInput : ChargingPort;
		
		attribute totalCapacity : Real;
		attribute currentCharge : Percentage;
		attribute voltage : Real;
		attribute maxDischargeCurrent : Real;
	}
	
	part def SafetySystem {
		attribute emergencyStopActive : Boolean;
		attribute collisionWarning : Boolean;
		attribute minimumSafeDistance : LengthValue;
	}
	
	part def AutomatedGuidedVehicle {
		attribute vehicleID : String;
		attribute maxPayloadMass : MassValue;
		attribute nominalSpeed : SpeedValue;
		
		port externalNavControl : NavigationControlPort;
		port externalLoadControl : LoadHandlingPort;
		port externalCharging : ChargingPort;
		
		part controller : VehicleController;
		part obstacleSensor : ObstacleSensor;
		part positionSensor : PositioningSensor;
		part driveSystem : DifferentialDrive;
		part loadingSystem : LoadingMechanism;
		part battery : BatteryPack;
		part safety : SafetySystem;
		
		connect controller.navControl to externalNavControl;
		connect controller.loadControl to externalLoadControl;
		connect obstacleSensor.sensorOutput to controller.sensorInput;
		connect positionSensor.positionOutput to controller.sensorInput;
		connect controller.driveOutput to driveSystem.driveInput;
		connect battery.powerOutput to driveSystem.powerInput;
		connect battery.powerOutput to loadingSystem.mechanismPower;
		connect battery.chargingInput to externalCharging;
	}
	
	part def ChargingStation {
		port chargingOutput : ChargingPort;
		
		attribute stationID : String;
		attribute chargingPower : PowerValue;
		attribute stationLocation : Position2D;
	}
	
	part def LoadingStation {
		port loadInterface : LoadHandlingPort;
		
		attribute stationID : String;
		attribute stationLocation : Position2D;
		attribute availablePayloads : Payload[*];
	}
	
	part def UnloadingStation {
		port unloadInterface : LoadHandlingPort;
		
		attribute stationID : String;
		attribute stationLocation : Position2D;
		attribute receivedPayloads : Payload[*];
	}
	
	part def FleetController {
		port vehicleCommand : NavigationControlPort;
		port vehicleStatus : NavigationControlPort;
		
		attribute managedVehicles : String[*];
		attribute missionQueue : Waypoint[*];
	}
	
	action def DetectObstacles {
		in scanRange : LengthValue;
		in scanAngle : Real;
		out obstacleDetected : ObstacleDetection;
	}
	
	action def DeterminePosition {
		out currentPosition : Position2D;
	}
	
	action def PlanPath {
		in startPosition : Position2D;
		in targetPosition : Position2D;
		in obstacles : ObstacleDetection[*];
		out plannedRoute : Waypoint[*];
		out pathValid : Boolean;
	}
	
	action def CalculateMotorCommands {
		in currentPosition : Position2D;
		in targetWaypoint : Waypoint;
		in currentSpeed : SpeedValue;
		in maxSpeed : SpeedValue;
		out motorCommand : MotorCommand;
	}
	
	action def PickupPayload {
		in pickupLocation : Position2D;
		in payloadToPickup : Payload;
		out loadStatus : LoadStatus;
		out payloadSecured : Boolean;
	}
	
	action def DeliverPayload {
		in deliveryLocation : Position2D;
		in payloadToDeliver : Payload;
		out deliveryComplete : Boolean;
		out loadStatus : LoadStatus;
	}
	
	action def ChargeVehicle {
		in chargingStation : ChargingStation;
		in currentBatteryLevel : Percentage;
		out batteryLevel : Percentage;
		out chargingComplete : Boolean;
	}
	
	action def MonitorSafety {
		in obstacleDistance : LengthValue;
		in currentSpeed : SpeedValue;
		in minimumSafeDistance : LengthValue;
		out emergencyStopRequired : Boolean;
		out safeToOperate : Boolean;
	}
	
	action def NavigateToWaypoint {
		in targetWaypoint : Waypoint;
		in maxSpeed : SpeedValue;
		out arrivedAtWaypoint : Boolean;
		out finalPosition : Position2D;
		
		private attribute currentPos : Position2D;
		private attribute obstacleData : ObstacleDetection;
		private attribute pathClear : Boolean;
		
		first start;
		then merge navigationLoop;
		
		then action determinePosition : DeterminePosition {
			out currentPosition;
		}
		
		then action detectObstacles : DetectObstacles {
			in scanRange = 10.0[m];
			in scanAngle = 180.0;
			out obstacleDetected;
		}
		
		then action monitorSafety : MonitorSafety {
			in obstacleDistance = detectObstacles.obstacleDetected.obstacleDistance;
			in currentSpeed = 1.0[m/s];
			in minimumSafeDistance = 0.5[m];
			out emergencyStopRequired;
			out safeToOperate;
		}
		
		then decide;
			if monitorSafety.emergencyStopRequired then emergencyStop;
			if !monitorSafety.emergencyStopRequired then continueNavigation;
		
		action emergencyStop {
			then navigationLoop;
		}
		
		action continueNavigation {
			then action calculateMotorCommands : CalculateMotorCommands {
				in currentPosition = determinePosition.currentPosition;
				in targetWaypoint = NavigateToWaypoint::targetWaypoint;
				in currentSpeed = 1.0[m/s];
				in maxSpeed = NavigateToWaypoint::maxSpeed;
				out motorCommand;
			}
			
			then assign currentPos := determinePosition.currentPosition;
			
			then action checkArrival {
				then decide;
					if NavigateToWaypoint::arrivedAtWaypoint then completeNavigation;
					else navigationLoop;
			}
		}
		
		action completeNavigation {
			then assign arrivedAtWaypoint := true;
			then assign finalPosition := currentPos;
			then done;
		}
	}
	
	action def ExecuteTransportMission {
		in pickupWaypoint : Waypoint;
		in deliveryWaypoint : Waypoint;
		in payload : Payload;
		in maxSpeed : SpeedValue;
		out missionComplete : Boolean;
		out finalBatteryLevel : Percentage;
		
		first start;
		
		then action navigateToPickup : NavigateToWaypoint {
			in targetWaypoint = pickupWaypoint;
			in maxSpeed = maxSpeed;
			out arrivedAtWaypoint;
			out finalPosition;
		}
		
		then action pickup : PickupPayload {
			in pickupLocation = navigateToPickup.finalPosition;
			in payloadToPickup = payload;
			out loadStatus;
			out payloadSecured;
		}
		
		then decide;
			if !pickup.payloadSecured then abortMission;
			if pickup.payloadSecured then continueToDelivery;
		
		action continueToDelivery {
			action navigateToDelivery : NavigateToWaypoint {
				in targetWaypoint = deliveryWaypoint;
				in maxSpeed = maxSpeed;
				out arrivedAtWaypoint;
				out finalPosition;
			}
			
			then action deliver : DeliverPayload {
				in deliveryLocation = navigateToDelivery.finalPosition;
				in payloadToDeliver = payload;
				out deliveryComplete;
				out loadStatus;
			}
			
			then assign missionComplete := deliver.deliveryComplete;
			then completeMission;
		}
		
		action abortMission {
			then assign missionComplete := false;
			then completeMission;
		}
		
		action completeMission {
			then done;
		}
	}
	
	state def AGVOperationalStateMachine {
		entry; then idle;
		
		state idle {
			entry assign isIdle := true;
			entry assign batteryCharging := false;
		}
		
		transition idleToCharging
			first idle
			accept lowBattery
			then charging;
		
		transition idleToReady
			first idle
			accept missionAssigned : NavigationCommand
			then ready;
		
		state charging {
			entry assign batteryCharging := true;
			do action chargeAction : ChargeVehicle;
		}
		
		transition chargingToIdle
			first charging
			if batteryLevel >= 95.0
			then idle;
		
		state ready {
			entry assign systemCheck := true;
		}
		
		transition readyToNavigating
			first ready
			if systemCheck
			then navigating;
		
		state navigating {
			entry assign isMoving := true;
			do action navigationAction : NavigateToWaypoint;
		}
		
		transition navigatingToLoading
			first navigating
			accept arrivedAtPickup
			then loading;
		
		transition navigatingToCharging
			first navigating
			if batteryLevel < 20.0
			then charging;
		
		state loading {
			entry assign isLoading := true;
			do action loadingAction : PickupPayload;
		}
		
		transition loadingToTransporting
			first loading
			if payloadSecured
			then transporting;
		
		transition loadingToIdle
			first loading
			if !payloadSecured
			then idle;
		
		state transporting {
			entry assign isTransporting := true;
			do action transportAction : NavigateToWaypoint;
		}
		
		transition transportingToUnloading
			first transporting
			accept arrivedAtDelivery
			then unloading;
		
		state unloading {
			entry assign isUnloading := true;
			do action unloadingAction : DeliverPayload;
		}
		
		transition unloadingToIdle
			first unloading
			if deliveryComplete
			then idle;
		
		state emergency {
			entry assign emergencyActive := true;
			entry assign isMoving := false;
		}
		
		transition anyToEmergency
			accept emergencyStop
			then emergency;
		
		transition emergencyToIdle
			first emergency
			accept emergencyCleared
			then idle;
		
		attribute isIdle : Boolean;
		attribute batteryCharging : Boolean;
		attribute systemCheck : Boolean;
		attribute isMoving : Boolean;
		attribute isLoading : Boolean;
		attribute isTransporting : Boolean;
		attribute isUnloading : Boolean;
		attribute batteryLevel : Percentage;
		attribute payloadSecured : Boolean;
		attribute deliveryComplete : Boolean;
		attribute emergencyActive : Boolean;
	}
	
	requirement def AGVPrimaryFunctionRequirement {
		doc /* The Automated Guided Vehicle shall autonomously transport payloads from designated 
		       pickup locations to delivery locations following planned routes while avoiding obstacles 
		       and maintaining safe operation. */
		
		subject agv : AutomatedGuidedVehicle;
		
		require autonomousNavigation : AutonomousNavigationRequirement;
		require payloadTransport : PayloadTransportRequirement;
		require obstacleAvoidance : ObstacleAvoidanceRequirement;
		require safeOperation : SafeOperationRequirement;
	}
	
	requirement def AutonomousNavigationRequirement {
		doc /* The AGV shall navigate autonomously to commanded waypoints with position accuracy 
		       within 50mm of the target location. */
		
		subject agv : AutomatedGuidedVehicle;
		
		require constraint {
			agv.positionSensor.accuracy <= 50.0[mm]
		}
	}
	
	requirement def PayloadTransportRequirement {
		doc /* The AGV shall transport payloads up to 500 kg without exceeding maximum speed 
		       of 2.0 m/s. */
		
		subject agv : AutomatedGuidedVehicle;
		
		require constraint {
			agv.maxPayloadMass >= 500.0[kg] and
			agv.nominalSpeed <= 2.0[m/s]
		}
	}
	
	requirement def ObstacleAvoidanceRequirement {
		doc /* The AGV shall detect obstacles within 10 meters and maintain minimum safe distance 
		       of 0.5 meters from detected obstacles. */
		
		subject agv : AutomatedGuidedVehicle;
		
		require constraint {
			agv.obstacleSensor.detectionRange >= 10.0[m] and
			agv.safety.minimumSafeDistance >= 0.5[m]
		}
	}
	
	requirement def SafeOperationRequirement {
		doc /* The AGV shall execute emergency stop within 1.0 second when obstacle detected 
		       within minimum safe distance. */
		
		subject agv : AutomatedGuidedVehicle;
		
		require constraint {
			agv.safety.emergencyStopActive implies 
			agv.driveSystem.leftWheel.wheelSpeed == 0.0 and
			agv.driveSystem.rightWheel.wheelSpeed == 0.0
		}
	}
	
	requirement def BatteryEnduranceRequirement {
		doc /* The AGV shall operate continuously for minimum 8 hours on single charge under 
		       nominal load conditions. */
		
		subject agv : AutomatedGuidedVehicle;
		
		require constraint {
			agv.battery.totalCapacity >= 8.0
		}
	}
	
	part warehouseAGVSystem {
		part agv1 : AutomatedGuidedVehicle {
			attribute :>> vehicleID = "AGV-001";
			attribute :>> maxPayloadMass = 500.0[kg];
			attribute :>> nominalSpeed = 1.5[m/s];
			
			part :>> obstacleSensor {
				attribute :>> detectionRange = 10.0[m];
				attribute :>> scanAngle = 180.0;
				attribute :>> updateRate = 10.0;
			}
			
			part :>> positionSensor {
				attribute :>> accuracy = 30.0[mm];
				attribute :>> updateFrequency = 20.0;
			}
			
			part :>> driveSystem {
				attribute :>> wheelBase = 0.8[m];
				attribute :>> maxTorque = 100.0[N*m];
				
				part :>> leftWheel {
					attribute :>> wheelRadius = 0.15[m];
				}
				
				part :>> rightWheel {
					attribute :>> wheelRadius = 0.15[m];
				}
			}
			
			part :>> loadingSystem {
				attribute :>> liftCapacity = 500.0[kg];
				attribute :>> liftHeight = 0.5[m];
			}
			
			part :>> battery {
				attribute :>> totalCapacity = 100.0;
				attribute :>> currentCharge = 100.0;
				attribute :>> voltage = 48.0;
				attribute :>> maxDischargeCurrent = 50.0;
			}
			
			part :>> safety {
				attribute :>> minimumSafeDistance = 0.5[m];
			}
		}
		
		part chargingStation1 : ChargingStation {
			attribute :>> stationID = "CHG-01";
			attribute :>> chargingPower = 2000.0[W];
		}
		
		part loadingDock : LoadingStation {
			attribute :>> stationID = "LOAD-01";
		}
		
		part unloadingDock : UnloadingStation {
			attribute :>> stationID = "UNLOAD-01";
		}
		
		part fleetController : FleetController;
		
		connect fleetController.vehicleCommand to agv1.externalNavControl;
		connect agv1.externalCharging to chargingStation1.chargingOutput;
		
		satisfy AGVPrimaryFunctionRequirement by agv1;
	}
	
	action warehouseOperation : ExecuteTransportMission {
		in :>> pickupWaypoint = Waypoint {
			attribute :>> location = Position2D { x = 10.0[m]; y = 5.0[m]; theta = 0.0; };
			attribute :>> waypointID = "PICKUP-A";
			attribute :>> taskType = TaskType::pickup;
		};
		in :>> deliveryWaypoint = Waypoint {
			attribute :>> location = Position2D { x = 50.0[m]; y = 25.0[m]; theta = 90.0; };
			attribute :>> waypointID = "DELIVERY-B";
			attribute :>> taskType = TaskType::delivery;
		};
		in :>> payload = Payload {
			attribute :>> mass = 250.0[kg];
			attribute :>> payloadID = "PKG-12345";
		};
		in :>> maxSpeed = 1.5[m/s];
		out :>> missionComplete;
		out :>> finalBatteryLevel;
	}
}
