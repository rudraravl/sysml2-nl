package 'Robotic Lawn Mower System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def BatteryChargeLevel :> Real;
	attribute def GrassHeight :> ISQ::LengthValue;
	attribute def MowingSpeed :> ISQ::SpeedValue;
	attribute def AreaCoverage :> ISQ::AreaValue;
	
	attribute def StartCommand;
	attribute def StopCommand;
	attribute def DockCommand;
	attribute def BoundarySignal;
	
	enum def OperationalMode {
		Idle;
		Mowing;
		Navigating;
		Docking;
		Charging;
		ObstacleAvoidance;
	}
	
	item def ElectricalPower {
		attribute voltage : ISQ::ElectricPotentialValue;
		attribute current : ISQ::ElectricCurrentValue;
	}
	
	port def PowerPort {
		inout power : ElectricalPower;
	}
	
	port def SensorDataPort {
		out obstacleDistance : ISQ::LengthValue;
		out boundaryDetected : Boolean;
		out grassHeight : GrassHeight;
	}
	
	port def ControlPort {
		in commandSignal : StartCommand;
		out statusFeedback : OperationalMode;
	}
	
	part def BatterySystem {
		attribute capacity : ISQ::EnergyValue;
		attribute currentCharge : ISQ::EnergyValue;
		attribute chargeLevel : BatteryChargeLevel;
		port powerOutput : PowerPort;
	}
	
	part def CuttingDeck {
		attribute bladeRotationSpeed : ISQ::AngularVelocityValue;
		attribute cuttingWidth : ISQ::LengthValue;
		attribute cuttingHeight : ISQ::LengthValue;
		port motorPower : PowerPort;
	}
	
	part def DriveSystem {
		attribute leftWheelSpeed : ISQ::SpeedValue;
		attribute rightWheelSpeed : ISQ::SpeedValue;
		attribute maxSpeed : ISQ::SpeedValue;
		port leftMotorPower : PowerPort;
		port rightMotorPower : PowerPort;
	}
	
	part def SensorArray {
		part ultrasonicSensor : ObstacleSensor {
			attribute range = 2.0 [SI::m];
		}
		part boundaryWireSensor : BoundaryDetector;
		part grassHeightSensor : GrassDetector;
		part bumpSensor : ContactSensor;
		port sensorOutput : SensorDataPort;
	}
	
	part def ObstacleSensor {
		attribute range : ISQ::LengthValue;
		attribute detectionAngle : Real;
	}
	
	part def BoundaryDetector {
		attribute signalStrength : Real;
	}
	
	part def GrassDetector {
		attribute measuredHeight : GrassHeight;
	}
	
	part def ContactSensor {
		attribute contactDetected : Boolean;
	}
	
	part def NavigationController {
		attribute currentPosition : ISQ::LengthValue[2];
		attribute targetPosition : ISQ::LengthValue[2];
		attribute coveredArea : AreaCoverage;
		attribute totalLawnArea : AreaCoverage;
	}
	
	part def ChargingDockStation {
		attribute dockVoltage : ISQ::ElectricPotentialValue;
		attribute chargingCurrent : ISQ::ElectricCurrentValue;
		attribute dockPosition : ISQ::LengthValue[2];
		port chargingPort : PowerPort;
	}
	
	part def RoboticMower {
		attribute operationalMode : OperationalMode;
		
		part battery : BatterySystem {
			attribute capacity = 3000.0 [SI::J];
			attribute currentCharge : ISQ::EnergyValue;
			attribute chargeLevel = (currentCharge / capacity) * 100.0;
		}
		
		part cuttingDeck : CuttingDeck {
			attribute cuttingWidth = 0.30 [SI::m];
			attribute cuttingHeight = 0.04 [SI::m];
		}
		
		part driveSystem : DriveSystem {
			attribute maxSpeed = 0.8 [SI::'m/s'];
		}
		
		part sensors : SensorArray;
		
		part navigator : NavigationController {
			attribute totalLawnArea = 500.0 [SI::'m^2'];
		}
		
		port controlInterface : ControlPort;
		port chargingContact : PowerPort;
		
		connection powerToDrive : ElectricalPower connect battery.powerOutput to driveSystem.leftMotorPower;
		connection powerToCutter : ElectricalPower connect battery.powerOutput to cuttingDeck.motorPower;
		
		perform action autonomousMowing[*] ordered references mowingOperation;
	}
	
	action def MonitorBatteryStatus {
		in mower : RoboticMower;
		out chargeLevel : BatteryChargeLevel;
		out needsCharging : Boolean;
	}
	
	action def DetectObstacles {
		in mower : RoboticMower;
		out obstaclePresent : Boolean;
		out obstacleDistance : ISQ::LengthValue;
	}
	
	action def CheckBoundary {
		in mower : RoboticMower;
		out atBoundary : Boolean;
	}
	
	action def NavigateToTarget {
		in mower : RoboticMower;
		in targetPos : ISQ::LengthValue[2];
		out arrived : Boolean;
	}
	
	action def CutGrass {
		in mower : RoboticMower;
		in cuttingSpeed : MowingSpeed;
		out areaCovered : AreaCoverage;
	}
	
	action def NavigateToDock {
		in mower : RoboticMower;
		in dockPos : ISQ::LengthValue[2];
		out docked : Boolean;
	}
	
	action def PerformCharging {
		in mower : RoboticMower;
		in station : ChargingDockStation;
		out chargeComplete : Boolean;
	}
	
	action def AvoidObstacle {
		in mower : RoboticMower;
		in obstacleDir : Real;
		out clearPath : Boolean;
	}
	
	action def TurnAround {
		in mower : RoboticMower;
		in turnAngle : Real;
	}
	
	action def AutonomousLawnMaintenance {
		in mowerUnit : RoboticMower;
		in chargingStation : ChargingDockStation;
	}
	
	action mowingOperation : AutonomousLawnMaintenance {
		in mowerUnit : RoboticMower;
		in chargingStation : ChargingDockStation;
		
		first start;
		then merge mainLoop;
		
		action checkBattery : MonitorBatteryStatus {
			in mower = mowingOperation::mowerUnit;
			out chargeLevel : BatteryChargeLevel;
			out needsCharging : Boolean;
		}
		
		then decide;
			if checkBattery.chargeLevel < 15.0 then initiateCharging;
			if checkBattery.chargeLevel >= 15.0 then performMowing;
		
		action initiateCharging {
			first action navigateToDock : NavigateToDock {
				in mower = mowingOperation::mowerUnit;
				in dockPos = mowingOperation::chargingStation.dockPosition;
				out docked : Boolean;
			}
			then action charge : PerformCharging {
				in mower = mowingOperation::mowerUnit;
				in station = mowingOperation::chargingStation;
				out chargeComplete : Boolean;
			}
		}
		then mainLoop;
		
		action performMowing {
			first action detectObstacles : DetectObstacles {
				in mower = mowingOperation::mowerUnit;
				out obstaclePresent : Boolean;
				out obstacleDistance : ISQ::LengthValue;
			}
			then decide;
				if detectObstacles.obstaclePresent then handleObstacle;
				if not detectObstacles.obstaclePresent then checkBoundaryStatus;
			
			action handleObstacle {
				first action avoid : AvoidObstacle {
					in mower = mowingOperation::mowerUnit;
					in obstacleDir = 0.0;
					out clearPath : Boolean;
				}
				then action turn : TurnAround {
					in mower = mowingOperation::mowerUnit;
					in turnAngle = 1.57;
				}
			}
			then checkBoundaryStatus;
			
			action checkBoundaryStatus {
				first action checkBoundary : CheckBoundary {
					in mower = mowingOperation::mowerUnit;
					out atBoundary : Boolean;
				}
				then decide;
					if checkBoundary.atBoundary then reverseTurn;
					if not checkBoundary.atBoundary then continueGrassCutting;
				
				action reverseTurn : TurnAround {
					in mower = mowingOperation::mowerUnit;
					in turnAngle = 3.14;
				}
				then continueGrassCutting;
				
				action continueGrassCutting : CutGrass {
					in mower = mowingOperation::mowerUnit;
					in cuttingSpeed = 0.5 [SI::'m/s'];
					out areaCovered : AreaCoverage;
				}
			}
		}
		then mainLoop;
	}
	
	requirement def SafetyRequirement;
	requirement def PerformanceRequirement;
	requirement def OperationalRequirement;
	requirement def EnergyRequirement;
	
	requirement <'REQ-SAFE-001'> obstacleDetectionAndAvoidance : SafetyRequirement {
		doc /* The robotic lawn mower shall detect obstacles within 2 meters and 
		     execute avoidance maneuvers to prevent collision. */
		subject mower : RoboticMower;
		require constraint {
			mower.sensors.ultrasonicSensor.range >= 2.0 [SI::m]
		}
	}
	
	requirement <'REQ-SAFE-002'> boundaryRespect : SafetyRequirement {
		doc /* The mower shall detect boundary wire signals and remain within 
		     the designated mowing area at all times. */
		subject mower : RoboticMower;
		require constraint {
			mower.sensors.boundaryWireSensor.signalStrength > 0.0
		}
	}
	
	requirement <'REQ-PERF-001'> cuttingEfficiency : PerformanceRequirement {
		doc /* The cutting deck shall maintain a minimum cutting width of 0.30 meters 
		     to ensure efficient grass coverage. */
		subject deck : CuttingDeck;
		require constraint {
			deck.cuttingWidth >= 0.30 [SI::m]
		}
	}
	
	requirement <'REQ-PERF-002'> mowingSpeed : PerformanceRequirement {
		doc /* The mower shall operate at speeds up to 0.8 m/s to balance efficiency 
		     and cutting quality. */
		subject drive : DriveSystem;
		require constraint {
			drive.maxSpeed <= 0.8 [SI::'m/s']
		}
	}
	
	requirement <'REQ-OPER-001'> autonomousOperation : OperationalRequirement {
		doc /* The mower shall operate autonomously following systematic mowing patterns 
		     without human intervention until battery depletion. */
		subject mower : RoboticMower;
		assume constraint {
			mower.navigator.totalLawnArea > 0.0 [SI::'m^2']
		}
		require constraint {
			mower.autonomousMowing
		}
	}
	
	requirement <'REQ-OPER-002'> automaticRecharging : OperationalRequirement {
		doc /* The mower shall automatically navigate to the charging station when 
		     battery charge level falls below 15 percent and resume operation after 
		     full recharge. */
		subject mower : RoboticMower;
		require constraint {
			mower.battery.chargeLevel < 15.0 implies 
			mower.autonomousMowing.initiateCharging
		}
	}
	
	requirement <'REQ-ENRG-001'> batteryCapacity : EnergyRequirement {
		doc /* The battery system shall provide minimum capacity of 3000 J to support 
		     at least 120 minutes of continuous mowing operation. */
		subject battery : BatterySystem;
		require constraint {
			battery.capacity >= 3000.0 [SI::J]
		}
	}
	
	requirement <'REQ-ENRG-002'> chargingEfficiency : EnergyRequirement {
		doc /* The charging system shall fully recharge the battery from 15% to 100% 
		     within 180 minutes. */
		subject station : ChargingDockStation;
		require constraint {
			station.chargingCurrent >= 5.0 [SI::A]
		}
	}
	
	requirement primaryMission {
		doc /* The robotic lawn mower system shall autonomously maintain lawn areas by 
		     systematically cutting grass to a uniform height while detecting and avoiding 
		     obstacles, respecting boundary limits, and managing its own energy through 
		     automatic docking and recharging cycles. */
		require obstacleDetectionAndAvoidance;
		require boundaryRespect;
		require cuttingEfficiency;
		require mowingSpeed;
		require autonomousOperation;
		require automaticRecharging;
		require batteryCapacity;
		require chargingEfficiency;
	}
	
	part lawnMowerSystem {
		part mower : RoboticMower {
			satisfy primaryMission;
		}
		part dock : ChargingDockStation {
			attribute dockVoltage = 24.0 [SI::V];
			attribute chargingCurrent = 8.0 [SI::A];
			attribute dockPosition = (0.0 [SI::m], 0.0 [SI::m]);
		}
		connection charging : ElectricalPower connect mower.chargingContact to dock.chargingPort;
	}
}
