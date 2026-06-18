package RoombaBasedCleaningSystem {

	import ScalarValues::*;
	import ISQ::*;
	import SI::*;

	attribute def Length :> ISQ::length;
	attribute def Area :> ISQ::area;
	attribute def Mass :> ISQ::mass;
	attribute def Time :> ISQ::time;
	attribute def Speed :> ISQ::speed;
	attribute def ElectricPotential :> ISQ::electricPotential;
	attribute def ElectricCurrent :> ISQ::electricCurrent;
	attribute def Power :> ISQ::power;
	attribute def Energy :> ISQ::energy;
	attribute def Percentage {
		attribute value : Real;
	}
	attribute def Count {
		attribute value : Integer;
	}
	attribute def BooleanStatus {
		attribute value : Boolean;
	}

	item def FloorSurface {
		attribute totalArea : Area;
		attribute cleanableArea : Area;
		attribute obstacleCoverage : Percentage;
		attribute surfaceType : SurfaceKind;
	}

	enum def SurfaceKind {
		enum hardwood;
		enum tile;
		enum carpet;
		enum rug;
		enum mixed;
	}

	item def DustAndDebris {
		attribute mass : Mass;
		attribute particleSizeClass : DebrisKind;
	}

	enum def DebrisKind {
		enum fineDust;
		enum hair;
		enum crumbs;
		enum mixedDebris;
	}

	item def CleanedFloorReport {
		attribute cleanedArea : Area;
		attribute remainingUncleanedArea : Area;
		attribute debrisCollected : Mass;
		attribute cleaningCompleteness : Percentage;
		attribute missionDuration : Time;
	}

	item def NavigationMap {
		attribute mappedArea : Area;
		attribute knownObstacleCount : Count;
		attribute localizationConfidence : Percentage;
	}

	item def BatteryCharge {
		attribute stateOfCharge : Percentage;
		attribute storedEnergy : Energy;
		attribute voltage : ElectricPotential;
	}

	item def ChargingPower {
		attribute voltage : ElectricPotential;
		attribute current : ElectricCurrent;
		attribute power : Power;
	}

	item def UserCommand {
		attribute commandKind : CommandKind;
	}

	enum def CommandKind {
		enum startCleaning;
		enum pauseCleaning;
		enum resumeCleaning;
		enum returnToDock;
		enum stopCleaning;
		enum spotClean;
	}

	item def RobotStatus {
		attribute state : RobotStateKind;
		attribute batteryStateOfCharge : Percentage;
		attribute binFull : Boolean;
		attribute faultPresent : Boolean;
	}

	enum def RobotStateKind {
		enum docked;
		enum idle;
		enum mapping;
		enum cleaning;
		enum avoidingObstacle;
		enum returningToDock;
		enum charging;
		enum paused;
		enum faulted;
		enum missionComplete;
	}

	port def CommandPort {
		in item command : UserCommand;
	}

	port def StatusPort {
		out item status : RobotStatus;
		out item report : CleanedFloorReport;
	}

	port def SurfaceInteractionPort {
		in item surface : FloorSurface;
		in item debris : DustAndDebris;
		out item cleanedReport : CleanedFloorReport;
	}

	port def MappingPort {
		in item surface : FloorSurface;
		out item map : NavigationMap;
	}

	port def ChargingPort {
		in item chargingPower : ChargingPower;
		out item batteryCharge : BatteryCharge;
	}

	port def DockChargingPort {
		out item chargingPower : ChargingPower;
		in item batteryCharge : BatteryCharge;
	}

	port def DebrisTransferPort {
		in item collectedDebris : DustAndDebris;
	}

	part def WheelModule {
		attribute wheelDiameter : Length = 0.072 [m];
		attribute maximumWheelSpeed : Speed = 0.55 [m/s];
		attribute tractionAvailable : Percentage = 95.0;
		port motionSurfacePort : SurfaceInteractionPort;
	}

	part def BrushModule {
		attribute brushWidth : Length = 0.165 [m];
		attribute nominalBrushSpeed : Count = 1200;
		attribute pickupEfficiencyOnHardFloor : Percentage = 92.0;
		attribute pickupEfficiencyOnCarpet : Percentage = 84.0;
		port cleaningSurfacePort : SurfaceInteractionPort;
	}

	part def VacuumFanModule {
		attribute suctionPower : Power = 28.0 [W];
		attribute airflowPower : Power = 12.0 [W];
		attribute maximumContinuousRunTime : Time = 7200.0 [s];
		port suctionSurfacePort : SurfaceInteractionPort;
	}

	part def DustBin {
		attribute capacity : Mass = 0.45 [kg];
		attribute currentLoad : Mass = 0.0 [kg];
		attribute fullThreshold : Percentage = 90.0;
		port debrisInlet : DebrisTransferPort;
	}

	part def BatteryPack {
		attribute nominalVoltage : ElectricPotential = 14.4 [V];
		attribute capacity : Energy = 74.0 [W*h];
		attribute minimumOperationalCharge : Percentage = 15.0;
		attribute fullCharge : Percentage = 100.0;
		port chargePort : ChargingPort;
	}

	part def SensorSuite {
		attribute cliffSensorCount : Count = 4;
		attribute bumpSensorCount : Count = 2;
		attribute opticalFloorSensorCount : Count = 1;
		attribute wallSensorCount : Count = 1;
		attribute obstacleDetectionRange : Length = 1.5 [m];
		attribute localizationUpdatePeriod : Time = 0.2 [s];
		port mappingPort : MappingPort;
	}

	part def NavigationController {
		attribute mapMemoryCapacity : Area = 250.0 [m^2];
		attribute targetCoverage : Percentage = 95.0;
		attribute nominalCleaningSpeed : Speed = 0.30 [m/s];
		attribute dockingAccuracy : Length = 0.05 [m];
		port commandInput : CommandPort;
		port statusOutput : StatusPort;
		port mappingInterface : MappingPort;
	}

	part def CleaningController {
		attribute cleaningPathOverlap : Percentage = 12.0;
		attribute spotCleaningRadius : Length = 0.60 [m];
		attribute maximumMissionDuration : Time = 7200.0 [s];
		port commandInput : CommandPort;
		port surfaceInterface : SurfaceInteractionPort;
		port statusOutput : StatusPort;
	}

	part def ChargingDock {
		attribute inputVoltage : ElectricPotential = 120.0 [V];
		attribute outputVoltage : ElectricPotential = 19.0 [V];
		attribute maximumOutputCurrent : ElectricCurrent = 1.25 [A];
		attribute dockingBeaconRange : Length = 6.0 [m];
		port robotChargingInterface : DockChargingPort;
	}

	part def MobileApplication {
		attribute scheduledCleaningEnabled : Boolean = true;
		attribute defaultCleanStartDelay : Time = 0.0 [s];
		port userCommandPort : CommandPort;
		port userStatusPort : StatusPort;
	}

	part def HomeFloorEnvironment {
		attribute homeArea : Area = 90.0 [m^2];
		attribute cleanableArea : Area = 72.0 [m^2];
		attribute typicalDebrisMassPerMission : Mass = 0.08 [kg];
		attribute averageObstacleCoverage : Percentage = 18.0;
		item floor : FloorSurface {
			attribute totalArea = 90.0 [m^2];
			attribute cleanableArea = 72.0 [m^2];
			attribute obstacleCoverage = 18.0;
			attribute surfaceType = SurfaceKind::mixed;
		}
		item debris : DustAndDebris {
			attribute mass = 0.08 [kg];
			attribute particleSizeClass = DebrisKind::mixedDebris;
		}
		port floorPort : SurfaceInteractionPort;
		port mapPort : MappingPort;
	}

	part def RoombaRobot {
		attribute diameter : Length = 0.34 [m];
		attribute height : Length = 0.092 [m];
		attribute mass : Mass = 3.8 [kg];
		attribute maximumTranslationalSpeed : Speed = 0.50 [m/s];
		attribute nominalCleaningSpeed : Speed = 0.30 [m/s];
		attribute targetCleanedAreaFraction : Percentage = 95.0;
		attribute minimumDockingCharge : Percentage = 15.0;

		port commandPort : CommandPort;
		port statusPort : StatusPort;
		port cleaningPort : SurfaceInteractionPort;
		port mappingPort : MappingPort;
		port chargingPort : ChargingPort;

		part leftWheel : WheelModule;
		part rightWheel : WheelModule;
		part brushSystem : BrushModule;
		part vacuumFan : VacuumFanModule;
		part dustBin : DustBin;
		part battery : BatteryPack;
		part sensors : SensorSuite;
		part navigationController : NavigationController;
		part cleaningController : CleaningController;

		connect commandPort to navigationController.commandInput;
		connect commandPort to cleaningController.commandInput;
		connect statusPort to navigationController.statusOutput;
		connect statusPort to cleaningController.statusOutput;
		connect mappingPort to sensors.mappingPort;
		connect sensors.mappingPort to navigationController.mappingInterface;
		connect cleaningPort to brushSystem.cleaningSurfacePort;
		connect cleaningPort to vacuumFan.suctionSurfacePort;
		connect cleaningPort to leftWheel.motionSurfacePort;
		connect cleaningPort to rightWheel.motionSurfacePort;
		connect cleaningController.surfaceInterface to cleaningPort;
		connect chargingPort to battery.chargePort;

		action def AcceptCleaningMission {
			in item command : UserCommand;
			out item accepted : BooleanStatus;
			attribute commandIsCleaningStart : Boolean;
			attribute batteryAdequate : Boolean;
			attribute binHasCapacity : Boolean;
		}

		action def BuildNavigationMap {
			in item floor : FloorSurface;
			out item map : NavigationMap;
			attribute estimatedCleanableArea : Area;
			attribute detectedObstacles : Count;
			attribute mapConfidence : Percentage;
		}

		action def PlanCoveragePath {
			in item map : NavigationMap;
			out item plannedCoverageArea : Area;
			attribute pathOverlap : Percentage = 12.0;
			attribute plannedSpeed : Speed = 0.30 [m/s];
		}

		action def ExecuteVacuumCleaning {
			in item floor : FloorSurface;
			in item debris : DustAndDebris;
			out item report : CleanedFloorReport;
			attribute brushEnabled : Boolean = true;
			attribute suctionEnabled : Boolean = true;
			attribute wheelDriveEnabled : Boolean = true;
		}

		action def DetectAndAvoidObstacle {
			in item map : NavigationMap;
			out item updatedMap : NavigationMap;
			attribute avoidanceClearance : Length = 0.08 [m];
			attribute avoidanceSpeed : Speed = 0.15 [m/s];
		}

		action def ReturnToChargingDock {
			out item status : RobotStatus;
			attribute dockingSearchSpeed : Speed = 0.20 [m/s];
			attribute requiredDockingAccuracy : Length = 0.05 [m];
		}

		action def RechargeBattery {
			in item chargingPower : ChargingPower;
			out item charge : BatteryCharge;
			attribute targetCharge : Percentage = 100.0;
			attribute nominalChargingTime : Time = 10800.0 [s];
		}

		action def PerformCleaningMission {
			in item command : UserCommand;
			in item floor : FloorSurface;
			in item debris : DustAndDebris;
			out item finalReport : CleanedFloorReport;

			first start;
			then acceptMission : AcceptCleaningMission;
			then mapHome : BuildNavigationMap;
			then planPath : PlanCoveragePath;
			then cleanFloor : ExecuteVacuumCleaning;
			then returnDock : ReturnToChargingDock;
			then done;

			flow command to acceptMission.command;
			flow floor to mapHome.floor;
			flow mapHome.map to planPath.map;
			flow floor to cleanFloor.floor;
			flow debris to cleanFloor.debris;
			flow cleanFloor.report to finalReport;
		}

		state def OperationalStates {
			entry action initializeRobot;
			exit action saveMissionSummary;

			state Docked {
				entry action publishDockedStatus;
			}

			state Idle {
				entry action stopBrushAndFan;
			}

			state Mapping {
				entry action enableSensors;
				do action BuildNavigationMap;
			}

			state Cleaning {
				entry action startBrushFanAndDrive;
				do action ExecuteVacuumCleaning;
			}

			state AvoidingObstacle {
				entry action reduceSpeed;
				do action DetectAndAvoidObstacle;
				exit action resumeCoveragePath;
			}

			state ReturningToDock {
				entry action disableBrushAndFan;
				do action ReturnToChargingDock;
			}

			state Charging {
				entry action engageChargingContacts;
				do action RechargeBattery;
			}

			state Paused {
				entry action holdPosition;
			}

			state MissionComplete {
				entry action publishCleanedFloorReport;
			}

			state Faulted {
				entry action stopAllActuators;
				do action publishFaultStatus;
			}

			transition initialToDocked first Docked;
			transition dockedToMapping from Docked to Mapping accept UserCommand if commandKind == CommandKind::startCleaning;
			transition idleToMapping from Idle to Mapping accept UserCommand if commandKind == CommandKind::startCleaning;
			transition mappingToCleaning from Mapping to Cleaning if localizationConfidence >= 80.0;
			transition cleaningToAvoidingObstacle from Cleaning to AvoidingObstacle if knownObstacleCount > 0;
			transition avoidingObstacleToCleaning from AvoidingObstacle to Cleaning if localizationConfidence >= 80.0;
			transition cleaningToReturningLowBattery from Cleaning to ReturningToDock if stateOfCharge <= 15.0;
			transition cleaningToReturningComplete from Cleaning to ReturningToDock if cleaningCompleteness >= 95.0;
			transition returningToCharging from ReturningToDock to Charging if dockingError <= 0.05 [m];
			transition chargingToDocked from Charging to Docked if stateOfCharge >= 100.0;
			transition cleaningToPaused from Cleaning to Paused accept UserCommand if commandKind == CommandKind::pauseCleaning;
			transition pausedToCleaning from Paused to Cleaning accept UserCommand if commandKind == CommandKind::resumeCleaning;
			transition anyToFault from Docked to Faulted if faultPresent == true;
			transition faultToIdle from Faulted to Idle accept UserCommand if commandKind == CommandKind::stopCleaning;
			transition returningToMissionComplete from ReturningToDock to MissionComplete if cleaningCompleteness >= 95.0 and dockingError <= 0.05 [m];
		}
	}

	part def RoombaCleaningSystem {
		attribute primaryFunction : String = "Autonomously remove dust and debris from accessible indoor floor surfaces by navigating the home, sweeping and vacuuming the floor, collecting debris in an onboard bin, and returning to the charging dock when cleaning is complete or battery energy is low.";

		part robot : RoombaRobot;
		part dock : ChargingDock;
		part mobileApp : MobileApplication;
		part home : HomeFloorEnvironment;

		connect mobileApp.userCommandPort to robot.commandPort;
		connect robot.statusPort to mobileApp.userStatusPort;
		connect robot.chargingPort to dock.robotChargingInterface;
		connect robot.cleaningPort to home.floorPort;
		connect robot.mappingPort to home.mapPort;

		action def HighLevelPrimaryFunction {
			in item requestedCommand : UserCommand;
			in item accessibleFloor : FloorSurface;
			in item initialDebris : DustAndDebris;
			out item cleaningResult : CleanedFloorReport;

			first receiveStartCommand;
			then autonomouslyNavigateAccessibleFloor;
			then sweepAndVacuumDebris;
			then collectDebrisInBin;
			then reportCleanedArea;
			then returnToDock;

			flow requestedCommand to robot.PerformCleaningMission.command;
			flow accessibleFloor to robot.PerformCleaningMission.floor;
			flow initialDebris to robot.PerformCleaningMission.debris;
			flow robot.PerformCleaningMission.finalReport to cleaningResult;
		}
	}

	requirement def PrimaryFunctionRequirement {
		subject system : RoombaCleaningSystem;
		doc "The system shall autonomously clean accessible indoor floor surfaces by navigating the environment, removing dust and debris, storing collected debris, and returning to the charging dock at mission completion or low battery.";
		require constraint {
			system.robot.targetCleanedAreaFraction >= 95.0
		}
	}

	requirement def CoverageRequirement {
		subject robot : RoombaRobot;
		doc "The robot shall clean at least 95 percent of the accessible cleanable floor area during a normal mission when battery capacity and dust-bin capacity are sufficient.";
		require constraint {
			robot.targetCleanedAreaFraction >= 95.0
		}
	}

	requirement def BatteryReturnRequirement {
		subject robot : RoombaRobot;
		doc "The robot shall stop active cleaning and return to the charging dock when battery state of charge reaches the minimum operational threshold.";
		require constraint {
			robot.minimumDockingCharge >= 15.0
		}
	}

	requirement def DockingRequirement {
		subject robot : RoombaRobot;
		doc "The robot shall dock accurately enough to engage the charging contacts without user intervention.";
		require constraint {
			robot.navigationController.dockingAccuracy <= 0.05 [m]
		}
	}

	requirement def DebrisCollectionRequirement {
		subject robot : RoombaRobot;
		doc "The robot shall collect removed debris in an onboard dust bin sized for a typical household cleaning mission.";
		require constraint {
			robot.dustBin.capacity >= 0.45 [kg]
		}
	}

	requirement def SafeNavigationRequirement {
		subject robot : RoombaRobot;
		doc "The robot shall detect obstacles and cliffs and alter its path to avoid unsafe movement while continuing floor coverage.";
		require constraint {
			robot.sensors.obstacleDetectionRange >= 1.5 [m]
		}
	}

	requirement def MissionDurationRequirement {
		subject robot : RoombaRobot;
		doc "The robot shall complete a normal cleaning mission within the maximum allowed mission duration unless interrupted by low battery, full bin, or user command.";
		require constraint {
			robot.cleaningController.maximumMissionDuration <= 7200.0 [s]
		}
	}

	part roombaSystemExample : RoombaCleaningSystem {
		part robot {
			attribute diameter = 0.34 [m];
			attribute height = 0.092 [m];
			attribute mass = 3.8 [kg];
			attribute maximumTranslationalSpeed = 0.50 [m/s];
			attribute nominalCleaningSpeed = 0.30 [m/s];
			attribute targetCleanedAreaFraction = 95.0;
			attribute minimumDockingCharge = 15.0;
		}
		part dock {
			attribute inputVoltage = 120.0 [V];
			attribute outputVoltage = 19.0 [V];
			attribute maximumOutputCurrent = 1.25 [A];
			attribute dockingBeaconRange = 6.0 [m];
		}
		part home {
			attribute homeArea = 90.0 [m^2];
			attribute cleanableArea = 72.0 [m^2];
			attribute typicalDebrisMassPerMission = 0.08 [kg];
			attribute averageObstacleCoverage = 18.0;
		}
	}

	satisfy PrimaryFunctionRequirement by roombaSystemExample;
	satisfy CoverageRequirement by roombaSystemExample.robot;
	satisfy BatteryReturnRequirement by roombaSystemExample.robot;
	satisfy DockingRequirement by roombaSystemExample.robot;
	satisfy DebrisCollectionRequirement by roombaSystemExample.robot;
	satisfy SafeNavigationRequirement by roombaSystemExample.robot;
	satisfy MissionDurationRequirement by roombaSystemExample.robot;
}
