package RoombaSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def BatteryPercentage :> Real;
	attribute def DistanceValue :> LengthValue;
	attribute def DustCapacityValue :> VolumeValue;
	
	item def DustParticle {
		attribute mass : MassValue;
	}
	
	item def ObstacleData {
		attribute detected : Boolean;
		attribute distance : DistanceValue;
	}
	
	item def DockingSignal {
		attribute visible : Boolean;
		attribute strength : Real;
	}
	
	port def SensorPort {
		out obstacleData : ObstacleData;
		out dirtDetected : Boolean;
	}
	
	port def MotorControlPort {
		in leftWheelSpeed : Real;
		in rightWheelSpeed : Real;
	}
	
	port def BrushControlPort {
		in brushSpeed : Real;
		in suctionPower : PowerValue;
	}
	
	port def PowerPort {
		out voltage : ElectricPotentialValue;
		out current : ElectricCurrentValue;
	}
	
	port def ChargingPort {
		in chargingActive : Boolean;
		out batteryLevel : BatteryPercentage;
	}
	
	part def Battery {
		attribute capacity : EnergyValue;
		attribute chargeLevel : BatteryPercentage;
		port powerOut : PowerPort;
		port chargingIn : ChargingPort;
	}
	
	part def WheelMotor {
		attribute maxSpeed : Real;
		port control : MotorControlPort;
		port powerIn : PowerPort;
	}
	
	part def BrushMotor {
		attribute rotationSpeed : Real;
		port control : BrushControlPort;
		port powerIn : PowerPort;
	}
	
	part def VacuumFan {
		attribute suctionPower : PowerValue;
		port control : BrushControlPort;
		port powerIn : PowerPort;
	}
	
	part def DustBin {
		attribute capacity : DustCapacityValue;
		attribute currentLoad : DustCapacityValue;
	}
	
	part def ObstacleSensor {
		attribute detectionRange : DistanceValue;
		port sensorOut : SensorPort;
	}
	
	part def DirtSensor {
		port sensorOut : SensorPort;
	}
	
	part def ChargingDock {
		port powerSupply : PowerPort;
		port dockingInterface : ChargingPort;
		attribute outputVoltage : ElectricPotentialValue;
	}
	
	part def NavigationController {
		in port sensorInput : SensorPort;
		out port motorOutput : MotorControlPort;
		
		action def Navigate {
			in obstacleInfo : ObstacleData;
			out leftSpeed : Real;
			out rightSpeed : Real;
		}
		
		action def ReturnToDock {
			in dockSignal : DockingSignal;
			out navigationPath : DistanceValue;
		}
	}
	
	part def CleaningController {
		in port dirtSensorInput : SensorPort;
		out port brushOutput : BrushControlPort;
		
		action def AdjustCleaning {
			in dirtLevel : Boolean;
			out brushSpeed : Real;
			out suctionLevel : PowerValue;
		}
	}
	
	action def MonitorEnvironment {
		out obstacleDetected : Boolean;
		out obstacleDistance : DistanceValue;
		out dirtPresent : Boolean;
	}
	
	action def CheckBatteryStatus {
		out batteryLevel : BatteryPercentage;
		out needsCharging : Boolean;
	}
	
	action def MoveForward {
		in speed : Real;
		out leftWheelSpeed : Real;
		out rightWheelSpeed : Real;
	}
	
	action def Turn {
		in angle : Real;
		out leftWheelSpeed : Real;
		out rightWheelSpeed : Real;
	}
	
	action def ActivateCleaning {
		in intensity : Real;
		out brushSpeed : Real;
		out suctionPower : PowerValue;
	}
	
	action def DockAndCharge {
		in dockLocation : DistanceValue;
	}
	
	action def AutonomousCleaningCycle {
		first start;
		then merge cleaningLoop;
		
		then action monitorEnvironment : MonitorEnvironment {
			out obstacleDetected : Boolean;
			out obstacleDistance : DistanceValue;
			out dirtPresent : Boolean;
		}
		
		then action checkBattery : CheckBatteryStatus {
			out batteryLevel : BatteryPercentage;
			out needsCharging : Boolean;
		}
		
		then decide;
			if checkBattery.needsCharging then dockAndCharge;
			if !checkBattery.needsCharging then navigation;
		
		action navigation {
			first decide;
				if monitorEnvironment.obstacleDetected then turn;
				if !monitorEnvironment.obstacleDetected then cleanAndMove;
			
			action turn : Turn {
				in angle = 45.0;
				out leftWheelSpeed : Real;
				out rightWheelSpeed : Real;
			}
			
			action cleanAndMove {
				first action activateCleaning : ActivateCleaning {
					in intensity = 1.0;
					out brushSpeed : Real;
					out suctionPower : PowerValue;
				}
				then action moveForward : MoveForward {
					in speed = 0.3;
					out leftWheelSpeed : Real;
					out rightWheelSpeed : Real;
				}
			}
		}
		then cleaningLoop;
		
		action dockAndCharge : DockAndCharge {
			in dockLocation = 0.0 [SI::m];
		}
		then done;
	}
	
	state def RoombaOperationalStates {
		entry; then idle;
		
		state idle {
			entry assign batteryCharging = true;
		}
		
		transition idle_to_cleaning
			first idle
			accept at startTime
			then cleaning;
		
		state cleaning {
			entry; then navigating;
			
			state navigating;
			
			transition navigating_to_avoiding
				first navigating
				if obstacleDetected
				then avoiding;
			
			state avoiding;
			
			transition avoiding_to_navigating
				first avoiding
				if !obstacleDetected
				then navigating;
			
			transition cleaning_to_lowBattery
				first navigating
				if batteryLevel < 20.0
				then lowBattery;
		}
		
		state lowBattery;
		
		transition lowBattery_to_returning
			first lowBattery
			then returning;
		
		state returning;
		
		transition returning_to_docked
			first returning
			if atDock
			then docked;
		
		state docked;
		
		transition docked_to_charging
			first docked
			then charging;
		
		state charging;
		
		transition charging_to_idle
			first charging
			if batteryLevel >= 100.0
			then idle;
	}
	
	part def Roomba {
		attribute operatingMode : String;
		attribute cleanedArea : Real;
		attribute batteryCharging : Boolean;
		attribute batteryLevel : BatteryPercentage;
		attribute obstacleDetected : Boolean;
		attribute atDock : Boolean;
		attribute startTime : Real;
		
		part battery : Battery {
			attribute :>> capacity = 72000.0 [SI::J];
			attribute :>> chargeLevel = 100.0;
		}
		
		part leftWheel : WheelMotor {
			attribute :>> maxSpeed = 1.0;
		}
		
		part rightWheel : WheelMotor {
			attribute :>> maxSpeed = 1.0;
		}
		
		part mainBrush : BrushMotor {
			attribute :>> rotationSpeed = 0.0;
		}
		
		part sideBrush : BrushMotor[2] {
			attribute :>> rotationSpeed = 0.0;
		}
		
		part vacuumFan : VacuumFan {
			attribute :>> suctionPower = 30.0 [SI::W];
		}
		
		part dustBin : DustBin {
			attribute :>> capacity = 0.6 [SI::L];
			attribute :>> currentLoad = 0.0 [SI::L];
		}
		
		part obstacleSensors : ObstacleSensor[6] {
			attribute :>> detectionRange = 0.15 [SI::m];
		}
		
		part dirtSensor : DirtSensor;
		
		part navigationController : NavigationController;
		
		part cleaningController : CleaningController;
		
		connect battery.powerOut to leftWheel.powerIn;
		connect battery.powerOut to rightWheel.powerIn;
		connect battery.powerOut to mainBrush.powerIn;
		connect battery.powerOut to vacuumFan.powerIn;
		
		connect obstacleSensors[1].sensorOut to navigationController.sensorInput;
		connect dirtSensor.sensorOut to cleaningController.dirtSensorInput;
		
		connect navigationController.motorOutput to leftWheel.control;
		connect navigationController.motorOutput to rightWheel.control;
		
		connect cleaningController.brushOutput to mainBrush.control;
		connect cleaningController.brushOutput to vacuumFan.control;
		
		perform action cleaningCycle : AutonomousCleaningCycle[*] ordered;
		
		exhibit state operationalStates : RoombaOperationalStates;
	}
	
	part roombaUnit : Roomba {
		attribute :>> operatingMode = "Automatic";
		attribute :>> cleanedArea = 0.0;
		attribute :>> batteryCharging = false;
		attribute :>> batteryLevel = 100.0;
		attribute :>> obstacleDetected = false;
		attribute :>> atDock = false;
	}
	
	part chargingDock : ChargingDock {
		attribute :>> outputVoltage = 18.0 [SI::V];
	}
	
	part cleaningEnvironment {
		part roomba :>> roombaUnit;
		part dock :>> chargingDock;
		
		connect roomba.battery.chargingIn to dock.dockingInterface;
	}
	
	requirement def FunctionalRequirement;
	
	requirement <'R1'> autonomousNavigation : FunctionalRequirement {
		doc /* The Roomba shall autonomously navigate indoor floor surfaces without human intervention. */
		subject roomba : Roomba;
	}
	
	requirement <'R2'> floorCleaning : FunctionalRequirement {
		doc /* The Roomba shall remove dust and debris from floor surfaces using rotating brushes and vacuum suction. */
		subject roomba : Roomba;
	}
	
	requirement <'R3'> obstacleAvoidance : FunctionalRequirement {
		doc /* The Roomba shall detect obstacles within 15 cm and adjust its path to avoid collisions. */
		subject roomba : Roomba;
		require constraint {
			roomba.obstacleSensors[1].detectionRange.num >= 0.15
		}
	}
	
	requirement <'R4'> automaticRecharging : FunctionalRequirement {
		doc /* The Roomba shall automatically return to its charging dock when battery level falls below 20 percent. */
		subject roomba : Roomba;
	}
	
	requirement <'R5'> batteryCapacity : FunctionalRequirement {
		doc /* The Roomba shall operate continuously for at least 60 minutes on a full charge. */
		subject roomba : Roomba;
		require constraint {
			roomba.battery.capacity.num >= 60.0 * 60.0 * 20.0
		}
	}
	
	requirement <'ROOMBA-MAIN'> primaryCleaningMission {
		doc /* The Roomba shall autonomously clean indoor floor surfaces by navigating, avoiding obstacles, removing dirt, and managing its own battery charging. */
		
		subject roomba : Roomba;
		
		assume constraint validEnvironment {
			doc /* The operating environment consists of flat indoor floor surfaces with typical household obstacles. */
		}
		
		require autonomousNavigation;
		require floorCleaning;
		require obstacleAvoidance;
		require automaticRecharging;
		require batteryCapacity;
	}
}
