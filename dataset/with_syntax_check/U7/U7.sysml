package 'Robotic Delivery System' {
	private import ScalarValues::*;
	private import SI::*;
	private import ISQ::*;
	private import Time::*;
	
	package ValueTypes {
		attribute def Position {
			attribute x : LengthValue;
			attribute y : LengthValue;
			attribute z : LengthValue;
		}
		
		attribute def Velocity {
			attribute linear : SpeedValue;
			attribute angular : AngularVelocityValue;
		}
		
		enum def RobotState {
			enum idle;
			enum navigating;
			enum loading;
			enum delivering;
			enum returning;
			enum charging;
			enum error;
		}
		
		enum def CompartmentStatus {
			enum open;
			enum closed;
			enum locked;
		}
		
		enum def DeliveryStatus {
			enum pending;
			enum inProgress;
			enum completed;
			enum failed;
		}
	}
	
	package ItemDefinitions {
		private import ValueTypes::*;
		
		item def Package {
			attribute weight : MassValue;
			attribute dimensions : Position;
			attribute deliveryAddress : String;
			attribute trackingNumber : String;
			attribute priority : Integer;
		}
		
		item def Obstacle {
			attribute position : Position;
			attribute size : LengthValue;
			attribute obstacleType : String;
		}
	}
	
	package LogicalModel {
		private import ValueTypes::*;
		private import ItemDefinitions::*;
		
		action def Navigate {
			in targetPosition : Position;
			in currentPosition : Position;
			out pathCommands : Velocity;
			out arrived : Boolean;
			out distanceTraveled : LengthValue;
		}
		
		action def ScanEnvironment {
			out obstacles : Obstacle[0..*];
			out pathClear : Boolean;
		}
		
		action def LoadPackage {
			in package : Package;
			out loadSuccess : Boolean;
			out compartmentStatus : CompartmentStatus;
		}
		
		action def UnloadPackage {
			out package : Package;
			out unloadSuccess : Boolean;
			out compartmentStatus : CompartmentStatus;
		}
		
		action def MonitorPower {
			out batteryLevel : Real;
			out chargingRequired : Boolean;
			out estimatedRange : LengthValue;
		}
		
		action def ExecuteDelivery {
			in deliveryPackage : Package;
			in pickupLocation : Position;
			in deliveryLocation : Position;
			in baseLocation : Position;
			out deliveryStatus : DeliveryStatus;
			
			first start;
			then merge statusCheck;
			
			action statusCheck {
				action monitorPower : MonitorPower;
			}
			
			then decide;
				if statusCheck.monitorPower.chargingRequired then abortAndCharge;
				if not statusCheck.monitorPower.chargingRequired then proceedToPickup;
			
			action proceedToPickup : Navigate;
			
			then merge navigationLoop;
			
			action navigationLoop {
				action scanEnvironment : ScanEnvironment;
				
				then decide;
					if not scanEnvironment.pathClear then avoidObstacles;
					if scanEnvironment.pathClear then continueNavigation;
				
				action avoidObstacles {
					action adjustPath : Navigate;
				}
				then navigationLoop;
				
				action continueNavigation : Navigate;
				
				then decide;
					if not continueNavigation.arrived then navigationLoop;
					if continueNavigation.arrived then loadCargo;
			}
			
			action loadCargo : LoadPackage;
			
			then navigateToDelivery : Navigate;
			
			then deliverCargo : UnloadPackage;
			
			then decide;
				if deliverCargo.unloadSuccess then returnToBase;
				if not deliverCargo.unloadSuccess then retryDelivery;
			
			action retryDelivery : UnloadPackage;
			then returnToBase;
			
			action returnToBase : Navigate;
			
			then completeDelivery;
			
			action completeDelivery;
			then done;
			
			action abortAndCharge : Navigate;
			then done;
		}
		
		part def DeliveryRobotLogical {
			attribute navigationAccuracy : LengthValue;
			attribute maxPayload : MassValue;
			attribute operatingTime : TimeValue;
			attribute detectionRange : LengthValue;
			
			perform action deliveryOperation : ExecuteDelivery;
		}
		
		part deliveryRobotLogical : DeliveryRobotLogical {
			attribute redefines navigationAccuracy = 0.3 [m];
			attribute redefines maxPayload = 25.0 [kg];
			attribute redefines operatingTime = 10.0 [h];
			attribute redefines detectionRange = 5.0 [m];
		}
	}
	
	package RequirementModel {
		private import LogicalModel::*;
		
		requirement deliverySystemRequirements {
			doc /* The robotic delivery system shall autonomously navigate, transport packages, and complete deliveries */
			
			requirement navigationCapability {
				doc /* The robot shall navigate autonomously to delivery destinations */
				subject robot : DeliveryRobotLogical;
				require constraint {
					robot.navigationAccuracy <= 0.5 [m]
				}
			}
			
			requirement payloadCapacity {
				doc /* The robot shall transport packages up to specified weight */
				subject robot : DeliveryRobotLogical;
				require constraint {
					robot.maxPayload >= 20.0 [kg]
				}
			}
			
			requirement batteryEndurance {
				doc /* The robot shall operate for minimum duration on single charge */
				subject robot : DeliveryRobotLogical;
				require constraint {
					robot.operatingTime >= 8.0 [h]
				}
			}
			
			requirement obstacleAvoidance {
				doc /* The robot shall detect and avoid obstacles during navigation */
				subject robot : DeliveryRobotLogical;
				require constraint {
					robot.detectionRange >= 3.0 [m]
				}
			}
		}
		
		satisfy deliverySystemRequirements.navigationCapability by LogicalModel::deliveryRobotLogical;
		satisfy deliverySystemRequirements.payloadCapacity by LogicalModel::deliveryRobotLogical;
		satisfy deliverySystemRequirements.batteryEndurance by LogicalModel::deliveryRobotLogical;
		satisfy deliverySystemRequirements.obstacleAvoidance by LogicalModel::deliveryRobotLogical;
	}
	
	package PhysicalModel {
		private import ValueTypes::*;
		private import ItemDefinitions::*;
		private import LogicalModel::*;
		
		port def PowerPort {
			attribute voltage : ElectricPotentialValue;
			attribute current : ElectricCurrentValue;
		}
		
		port def DataPort {
			attribute dataRate : Real;
			attribute protocol : String;
		}
		
		port def SensorPort {
			out sensorData : Real[0..*];
			out timestamp : TimeValue;
		}
		
		port def ActuatorPort {
			in commandSignal : Real;
			out feedback : Real;
		}
		
		part def Battery {
			attribute capacity : EnergyValue;
			attribute currentCharge : EnergyValue;
			attribute voltage : ElectricPotentialValue;
			attribute maxDischargeCurrent : ElectricCurrentValue;
			
			port powerOutput : PowerPort;
			
			perform action dischargePower {
				out powerLevel : PowerValue;
			}
		}
		
		part def Motor {
			attribute maxTorque : TorqueValue;
			attribute maxSpeed : AngularVelocityValue;
			attribute efficiency : Real;
			
			port powerInput : PowerPort;
			port controlInput : DataPort;
			port actuatorOutput : ActuatorPort;
			
			perform action generateTorque {
				in commandTorque : TorqueValue;
				out actualTorque : TorqueValue;
			}
		}
		
		part def Wheel {
			attribute diameter : LengthValue;
			attribute width : LengthValue;
			attribute material : String;
		}
		
		part def LidarSensor {
			attribute range : LengthValue;
			attribute resolution : LengthValue;
			attribute scanRate : FrequencyValue;
			
			port powerInput : PowerPort;
			port dataOutput : SensorPort;
			
			perform action scanEnvironment : ScanEnvironment;
		}
		
		part def Camera {
			attribute resolution : String;
			attribute fieldOfView : Real;
			attribute frameRate : FrequencyValue;
			
			port powerInput : PowerPort;
			port dataOutput : SensorPort;
		}
		
		part def GPSModule {
			attribute accuracy : LengthValue;
			attribute updateRate : FrequencyValue;
			
			port powerInput : PowerPort;
			port dataOutput : DataPort;
			
			perform action determinePosition {
				out position : Position;
				out accuracy : LengthValue;
			}
		}
		
		part def IMU {
			attribute gyroRange : AngularVelocityValue;
			attribute accelRange : AccelerationValue;
			
			port powerInput : PowerPort;
			port dataOutput : SensorPort;
			
			perform action measureMotion {
				out acceleration : AccelerationValue;
				out angularVelocity : AngularVelocityValue;
			}
		}
		
		part def NavigationSubsystem {
			attribute positionAccuracy : LengthValue;
			attribute obstacleDetectionRange : LengthValue;
			
			part lidar : LidarSensor {
				attribute redefines range = 10.0 [m];
				attribute redefines resolution = 0.05 [m];
				attribute redefines scanRate = 10.0 [Hz];
			}
			
			part frontCamera : Camera {
				attribute redefines resolution = "1920x1080";
				attribute redefines fieldOfView = 120.0;
				attribute redefines frameRate = 30.0 [Hz];
			}
			
			part rearCamera : Camera {
				attribute redefines resolution = "1280x720";
				attribute redefines fieldOfView = 90.0;
				attribute redefines frameRate = 30.0 [Hz];
			}
			
			part gps : GPSModule {
				attribute redefines accuracy = 0.3 [m];
				attribute redefines updateRate = 5.0 [Hz];
			}
			
			part imu : IMU {
				attribute redefines gyroRange = 500.0 [deg/s];
				attribute redefines accelRange = 16.0 [m/s^2];
			}
			
			part navigationProcessor {
				port sensorInputs : DataPort[5];
				port commandOutput : DataPort;
			}
			
			connect lidar.dataOutput to navigationProcessor.sensorInputs;
			connect frontCamera.dataOutput to navigationProcessor.sensorInputs;
			connect rearCamera.dataOutput to navigationProcessor.sensorInputs;
			connect gps.dataOutput to navigationProcessor.sensorInputs;
			connect imu.dataOutput to navigationProcessor.sensorInputs;
			
			perform action navigate : Navigate;
			perform action scanEnvironment : ScanEnvironment;
		}
		
		part def DriveSubsystem {
			part leftMotor : Motor {
				attribute redefines maxTorque = 50.0 [N*m];
				attribute redefines maxSpeed = 300.0 [rpm];
				attribute redefines efficiency = 0.85;
			}
			
			part rightMotor : Motor {
				attribute redefines maxTorque = 50.0 [N*m];
				attribute redefines maxSpeed = 300.0 [rpm];
				attribute redefines efficiency = 0.85;
			}
			
			part leftWheel : Wheel {
				attribute redefines diameter = 0.3 [m];
				attribute redefines width = 0.1 [m];
				attribute redefines material = "rubber";
			}
			
			part rightWheel : Wheel {
				attribute redefines diameter = 0.3 [m];
				attribute redefines width = 0.1 [m];
				attribute redefines material = "rubber";
			}
			
			part driveController {
				port motorCommands : DataPort[2];
			}
			
			connect leftMotor.actuatorOutput to leftWheel;
			connect rightMotor.actuatorOutput to rightWheel;
			connect driveController.motorCommands to leftMotor.controlInput;
			connect driveController.motorCommands to rightMotor.controlInput;
		}
		
		part def CargoSubsystem {
			attribute maxPayload : MassValue;
			attribute currentLoad : MassValue;
			attribute compartmentState : CompartmentStatus;
			
			item cargo : Package[0..5];
			
			part lockMechanism {
				attribute isLocked : Boolean;
				port actuatorControl : ActuatorPort;
			}
			
			part loadSensor {
				attribute maxCapacity : MassValue;
				port sensorOutput : SensorPort;
			}
			
			perform action loadPackage : LoadPackage;
			perform action unloadPackage : UnloadPackage;
		}
		
		part def PowerSubsystem {
			attribute totalCapacity : EnergyValue;
			attribute operatingTime : TimeValue;
			
			part mainBattery : Battery {
				attribute redefines capacity = 5500.0 [W*h];
				attribute redefines voltage = 48.0 [V];
				attribute redefines maxDischargeCurrent = 50.0 [A];
			}
			
			part powerDistributionUnit {
				port batteryInput : PowerPort;
				port motorPower : PowerPort[2];
				port sensorPower : PowerPort[6];
				port computePower : PowerPort[2];
			}
			
			part chargingPort {
				port externalPower : PowerPort;
			}
			
			connect mainBattery.powerOutput to powerDistributionUnit.batteryInput;
			connect chargingPort.externalPower to mainBattery.powerOutput;
			
			perform action monitorPower : MonitorPower;
		}
		
		part def ControlSubsystem {
			attribute currentState : RobotState;
			
			part mainController {
				port navigationInterface : DataPort;
				port driveInterface : DataPort;
				port cargoInterface : DataPort;
				port powerInterface : DataPort;
				port communicationInterface : DataPort;
			}
			
			state robotStateMachine {
				entry; then idle;
				
				state idle {
					entry; do initializeSystems;
					action initializeSystems;
				}
				transition idle_to_navigating
					first idle
					accept DeliveryRequest
					then navigating;
				
				state navigating {
					entry; do activateNavigation;
					action activateNavigation;
					
					state scanning {
						entry; do scanPath;
						action scanPath;
					}
					
					state moving {
						entry; do executeMovement;
						action executeMovement;
					}
					
					transition scanning_to_moving
						first scanning
						if pathClear
						then moving;
					
					transition moving_to_scanning
						first moving
						accept ObstacleDetected
						then scanning;
				}
				transition navigating_to_loading
					first navigating
					if arrivedAtPickup
					then loading;
				
				state loading {
					entry; do openCompartment;
					do loadPackageAction;
					do closeCompartment;
					action openCompartment;
					action loadPackageAction;
					action closeCompartment;
				}
				transition loading_to_navigating
					first loading
					if packageLoaded
					then navigating;
				
				state delivering {
					entry; do openCompartmentDeliver;
					do unloadPackageAction;
					do closeCompartmentDeliver;
					action openCompartmentDeliver;
					action unloadPackageAction;
					action closeCompartmentDeliver;
				}
				transition navigating_to_delivering
					first navigating
					if arrivedAtDestination
					then delivering;
				
				transition delivering_to_navigating
					first delivering
					if packageDelivered
					then navigating;
				
				state returning {
					entry; do navigateToBase;
					action navigateToBase;
				}
				transition delivering_to_returning
					first delivering
					if deliveryComplete
					then returning;
				
				transition returning_to_idle
					first returning
					if arrivedAtBase
					then idle;
				
				state charging {
					entry; do connectCharger;
					do chargeBattery;
					action connectCharger;
					action chargeBattery;
				}
				transition any_to_charging
					accept LowBattery
					then charging;
				
				transition charging_to_idle
					first charging
					if batteryFull
					then idle;
				
				state error {
					entry; do logError;
					do notifyOperator;
					action logError;
					action notifyOperator;
				}
				transition any_to_error
					accept SystemFault
					then error;
				
				transition error_to_idle
					first error
					accept ErrorResolved
					then idle;
			}
		}
		
		part def DeliveryRobot {
			attribute robotId : String;
			attribute currentState : RobotState;
			attribute totalDistance : LengthValue;
			attribute deliveriesCompleted : Integer;
			
			part navigationSubsystem : NavigationSubsystem {
				attribute redefines positionAccuracy = 0.3 [m];
				attribute redefines obstacleDetectionRange = 5.0 [m];
			}
			
			part driveSubsystem : DriveSubsystem;
			
			part cargoSubsystem : CargoSubsystem {
				attribute redefines maxPayload = 25.0 [kg];
			}
			
			part powerSubsystem : PowerSubsystem {
				attribute redefines totalCapacity = 5500.0 [W*h];
				attribute redefines operatingTime = 10.0 [h];
			}
			
			part controlSubsystem : ControlSubsystem;
			
			connect powerSubsystem.powerDistributionUnit.motorPower to driveSubsystem.leftMotor.powerInput;
			connect powerSubsystem.powerDistributionUnit.motorPower to driveSubsystem.rightMotor.powerInput;
			connect powerSubsystem.powerDistributionUnit.sensorPower to navigationSubsystem.lidar.powerInput;
			connect powerSubsystem.powerDistributionUnit.sensorPower to navigationSubsystem.frontCamera.powerInput;
			connect powerSubsystem.powerDistributionUnit.sensorPower to navigationSubsystem.rearCamera.powerInput;
			connect powerSubsystem.powerDistributionUnit.sensorPower to navigationSubsystem.gps.powerInput;
			connect powerSubsystem.powerDistributionUnit.sensorPower to navigationSubsystem.imu.powerInput;
			connect powerSubsystem.powerDistributionUnit.computePower to navigationSubsystem.navigationProcessor;
			connect powerSubsystem.powerDistributionUnit.computePower to controlSubsystem.mainController;
			
			connect controlSubsystem.mainController.navigationInterface to navigationSubsystem.navigationProcessor.commandOutput;
			connect controlSubsystem.mainController.driveInterface to driveSubsystem.driveController.motorCommands;
			connect controlSubsystem.mainController.cargoInterface to cargoSubsystem.lockMechanism.actuatorControl;
			
			perform deliveryOperation : ExecuteDelivery {
				action redefines proceedToPickup = navigationSubsystem.navigate;
				action redefines navigationLoop.scanEnvironment = navigationSubsystem.scanEnvironment;
				action redefines navigationLoop.continueNavigation = navigationSubsystem.navigate;
				action redefines navigationLoop.avoidObstacles.adjustPath = navigationSubsystem.navigate;
				action redefines loadCargo = cargoSubsystem.loadPackage;
				action redefines navigateToDelivery = navigationSubsystem.navigate;
				action redefines deliverCargo = cargoSubsystem.unloadPackage;
				action redefines retryDelivery = cargoSubsystem.unloadPackage;
				action redefines returnToBase = navigationSubsystem.navigate;
				action redefines abortAndCharge = navigationSubsystem.navigate;
				action redefines statusCheck.monitorPower = powerSubsystem.monitorPower;
			}
		}
		
		part deliveryRobot : DeliveryRobot {
			attribute redefines robotId = "DR-001";
			attribute redefines currentState = RobotState::idle;
			attribute redefines totalDistance = 0.0 [km];
			attribute redefines deliveriesCompleted = 0;
		}
		
		part def ChargingStation {
			attribute stationId : String;
			attribute location : Position;
			
			port powerOutput : PowerPort {
				attribute redefines voltage = 48.0 [V];
				attribute redefines current = 20.0 [A];
			}
		}
		
		part chargingStation : ChargingStation {
			attribute redefines stationId = "CS-001";
		}
		
		connect deliveryRobot.powerSubsystem.chargingPort.externalPower to chargingStation.powerOutput;
	}
	
	allocation def LogicalToPhysical {
		end logical : LogicalModel::DeliveryRobotLogical;
		end physical : PhysicalModel::DeliveryRobot;
	}
	
	allocation robotAllocation : LogicalToPhysical
		allocate logical ::> LogicalModel::deliveryRobotLogical
		to physical ::> PhysicalModel::deliveryRobot {
		allocate deliveryRobotLogical.deliveryOperation to deliveryRobot.deliveryOperation;
	}
}
