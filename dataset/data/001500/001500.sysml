package 'Military Robotic System' {
	private import ScalarValues::*;
	private import SI::*;
	private import ISQ::*;
	private import Time::*;
	
	package ValueTypes {
		attribute def EncryptionLevel :> Integer;
		attribute def ThreatLevel :> Integer;
		
		attribute def Coordinates {
			attribute latitude : Real;
			attribute longitude : Real;
			attribute altitude : Real;
		}
		
		enum def RobotStatus {
			enum standby;
			enum navigating;
			enum scanning;
			enum engaging;
			enum transmitting;
			enum returning;
			enum fault;
		}
		
		enum def ThreatType {
			enum none;
			enum personnel;
			enum vehicle;
			enum structure;
			enum unknown;
		}
		
		enum def MissionPhase {
			enum initialization;
			enum deployment;
			enum reconnaissance;
			enum engagement;
			enum extraction;
			enum complete;
		}
	}
	
	package ItemDefinitions {
		private import ValueTypes::*;
		
		item def Ammunition;
		item def Fuel;
		item def SensorData;
		item def CommandSignal;
		item def TelemetryData;
		
		item def ThreatInformation {
			attribute threatType : ThreatType;
			attribute location : Coordinates;
			attribute threatLevel : ThreatLevel;
			attribute timestamp : DateTime;
		}
	}
	
	package InterfaceDefinitions {
		private import ItemDefinitions::*;
		
		port def PowerPort {
			attribute voltage : ISQ::electricPotential;
			attribute current : ISQ::electricCurrent;
		}
		
		port def DataPort {
			in item commandIn : CommandSignal;
			out item telemetryOut : TelemetryData;
		}
		
		port def SensorPort {
			out item sensorOutput : SensorData;
		}
		
		port def WeaponPort {
			in item fireCommand : CommandSignal;
			out item weaponStatus : TelemetryData;
		}
	}
	
	package PhysicalModel {
		private import ValueTypes::*;
		private import ItemDefinitions::*;
		private import InterfaceDefinitions::*;
		
		part def SensorSuite {
			attribute detectionRange : ISQ::length;
			attribute fieldOfView : Real;
			port sensorOut : SensorPort;
			
			part opticalSensor {
				attribute resolution : Real;
				attribute range : ISQ::length;
			}
			
			part thermalSensor {
				attribute sensitivity : Real;
				attribute range : ISQ::length;
			}
			
			part radarSensor {
				attribute frequency : ISQ::frequency;
				attribute range : ISQ::length;
			}
			
			perform action detectTargets {
				out targets : ThreatInformation[0..*];
			}
		}
		
		part def WeaponSystem {
			attribute ammunitionCount : Integer;
			attribute maxRange : ISQ::length;
			attribute fireRate : Real;
			port weaponControl : WeaponPort;
			
			item ammunition : Ammunition;
			
			perform action fireWeapon {
				in target : Coordinates;
				out success : Boolean;
			}
		}
		
		part def CommunicationSystem {
			attribute encryptionLevel : EncryptionLevel;
			attribute transmissionRange : ISQ::length;
			attribute bandwidth : Real;
			port dataLink : DataPort;
			
			perform action transmitData {
				in message : TelemetryData;
				out status : Boolean;
			}
		}
		
		part def NavigationSystem {
			attribute currentPosition : Coordinates;
			attribute heading : Real;
			attribute speed : ISQ::speed;
			attribute accuracy : ISQ::length;
			
			perform action navigateToWaypoint {
				in waypoint : Coordinates;
				out arrived : Boolean;
			}
		}
		
		part def PowerSystem {
			attribute batteryCapacity : Real;
			attribute currentCharge : Real;
			attribute voltage : ISQ::electricPotential;
			port powerOut : PowerPort;
			
			perform action supplyPower {
				out power : ISQ::power;
			}
		}
		
		part def MobilityPlatform {
			attribute maxSpeed : ISQ::speed;
			attribute terrainCapability : String;
			attribute weight : ISQ::mass;
			
			perform action move {
				in direction : Real;
				in velocity : ISQ::speed;
			}
		}
		
		part def MissionController {
			attribute currentPhase : MissionPhase;
			attribute status : RobotStatus;
			
			perform action controlMission {
				out commands : CommandSignal;
			}
		}
		
		part def MilitaryRobot {
			attribute robotId : String;
			attribute operationalStatus : RobotStatus;
			attribute mass : ISQ::mass;
			
			part sensorSuite : SensorSuite {
				attribute redefines detectionRange = 1000.0 [m];
				attribute redefines fieldOfView = 180.0;
				
				part redefines opticalSensor {
					attribute redefines resolution = 4096.0;
					attribute redefines range = 1000.0 [m];
				}
				
				part redefines thermalSensor {
					attribute redefines sensitivity = 0.05;
					attribute redefines range = 800.0 [m];
				}
				
				part redefines radarSensor {
					attribute redefines frequency = 10.0 [GHz];
					attribute redefines range = 1500.0 [m];
				}
			}
			
			part weaponSystem : WeaponSystem {
				attribute redefines ammunitionCount = 200;
				attribute redefines maxRange = 800.0 [m];
				attribute redefines fireRate = 600.0;
			}
			
			part commSystem : CommunicationSystem {
				attribute redefines encryptionLevel = 256;
				attribute redefines transmissionRange = 15000.0 [m];
				attribute redefines bandwidth = 100.0;
			}
			
			part navigationSystem : NavigationSystem {
				attribute redefines speed = 12.0 [m/s];
				attribute redefines accuracy = 1.0 [m];
			}
			
			part powerSystem : PowerSystem {
				attribute redefines batteryCapacity = 18000.0 [W*h];
				attribute redefines currentCharge = 18000.0 [W*h];
				attribute redefines voltage = 48.0 [V];
			}
			
			part mobilityPlatform : MobilityPlatform {
				attribute redefines maxSpeed = 15.0 [m/s];
				attribute redefines terrainCapability = "all-terrain";
				attribute redefines weight = 450.0 [kg];
			}
			
			part controller : MissionController {
				attribute redefines currentPhase = MissionPhase::initialization;
				attribute redefines status = RobotStatus::standby;
			}
			
			connect powerSystem.powerOut to sensorSuite;
			connect powerSystem.powerOut to weaponSystem;
			connect powerSystem.powerOut to commSystem;
			connect powerSystem.powerOut to navigationSystem;
			connect powerSystem.powerOut to mobilityPlatform;
			connect powerSystem.powerOut to controller;
			
			connect sensorSuite.sensorOut to controller;
			connect controller to commSystem.dataLink;
			connect controller to weaponSystem.weaponControl;
			
			perform executeMission;
		}
		
		part militaryRobot : MilitaryRobot {
			attribute redefines robotId = "MR-Alpha-001";
			attribute redefines operationalStatus = RobotStatus::standby;
			attribute redefines mass = 500.0 [kg];
		}
	}
	
	package RequirementModel {
		private import ValueTypes::*;
		private import PhysicalModel::*;
		
		requirement def MissionCapabilityRequirement {
			doc /* The military robot shall detect and engage targets at specified range */
			subject robot : MilitaryRobot;
			require constraint {
				robot.sensorSuite.detectionRange >= 800.0 [m]
			}
		}
		
		requirement def EnduranceRequirement {
			doc /* The military robot shall operate continuously for minimum mission duration */
			subject robot : MilitaryRobot;
			require constraint {
				robot.powerSystem.batteryCapacity >= 15000.0 [W*h]
			}
		}
		
		requirement def CommunicationSecurityRequirement {
			doc /* The military robot shall maintain encrypted communication */
			subject robot : MilitaryRobot;
			require constraint {
				robot.commSystem.encryptionLevel >= 256
			}
		}
		
		requirement def WeaponSystemRequirement {
			doc /* The military robot shall carry sufficient ammunition for mission */
			subject robot : MilitaryRobot;
			require constraint {
				robot.weaponSystem.ammunitionCount >= 150
			}
		}
		
		requirement missionCapabilityReq : MissionCapabilityRequirement;
		requirement enduranceReq : EnduranceRequirement;
		requirement commSecurityReq : CommunicationSecurityRequirement;
		requirement weaponReq : WeaponSystemRequirement;
	}
	
	package LogicalModel {
		private import ValueTypes::*;
		private import ItemDefinitions::*;
		
		action def NavigateToTarget {
			in targetLocation : Coordinates;
			out navigationComplete : Boolean;
		}
		
		action def ScanArea {
			in scanLocation : Coordinates;
			out detectedThreats : ThreatInformation[0..*];
		}
		
		action def EngageTarget {
			in threat : ThreatInformation;
			out engagementSuccess : Boolean;
		}
		
		action def TransmitIntelligence {
			in data : TelemetryData;
			out transmissionSuccess : Boolean;
		}
		
		action def ReturnToBase {
			in baseLocation : Coordinates;
			out returnComplete : Boolean;
		}
		
		action def ExecuteCombatMission {
			in missionArea : Coordinates;
			in baseLocation : Coordinates;
			out missionSuccess : Boolean;
			
			first start;
			then merge missionLoop;
			
			then action navigate : NavigateToTarget {
				in targetLocation = missionArea;
			}
			
			then action scan : ScanArea {
				in scanLocation = missionArea;
			}
			
			then decide;
				if scan.detectedThreats->notEmpty() then engage;
				if scan.detectedThreats->isEmpty() then transmit;
			
			action engage : EngageTarget;
			then transmit;
			
			action transmit : TransmitIntelligence;
			
			then decide;
				if transmit.transmissionSuccess == true then returnHome;
				if transmit.transmissionSuccess == false then missionLoop;
			
			action returnHome : ReturnToBase {
				in baseLocation = baseLocation;
			}
			
			then done;
		}
		
		part def CombatRobotSystem {
			perform action executeMission : ExecuteCombatMission;
		}
		
		part combatRobotSystem : CombatRobotSystem;
	}
	
	package BehaviorModel {
		private import ValueTypes::*;
		private import PhysicalModel::*;
		
		state def MilitaryRobotStateMachine {
			entry; then standby;
			
			state standby {
				entry assign militaryRobot.operationalStatus := RobotStatus::standby;
			}
			accept MissionAssigned;
			then navigating;
			
			state navigating {
				entry assign militaryRobot.operationalStatus := RobotStatus::navigating;
				do action navigate {
					perform militaryRobot.navigationSystem.navigateToWaypoint;
					perform militaryRobot.mobilityPlatform.move;
				}
			}
			accept WaypointReached;
			then scanning;
			
			state scanning {
				entry assign militaryRobot.operationalStatus := RobotStatus::scanning;
				do action scan {
					perform militaryRobot.sensorSuite.detectTargets;
				}
			}
			accept ThreatDetected;
			then engaging;
			accept NoThreat;
			then transmitting;
			
			state engaging {
				entry assign militaryRobot.operationalStatus := RobotStatus::engaging;
				do action engage {
					perform militaryRobot.weaponSystem.fireWeapon;
				}
			}
			accept TargetNeutralized;
			then transmitting;
			accept EngagementFailed;
			then scanning;
			
			state transmitting {
				entry assign militaryRobot.operationalStatus := RobotStatus::transmitting;
				do action transmit {
					perform militaryRobot.commSystem.transmitData;
				}
			}
			accept TransmissionComplete;
			then returning;
			accept TransmissionFailed;
			then transmitting;
			
			state returning {
				entry assign militaryRobot.operationalStatus := RobotStatus::returning;
				do action returnToBase {
					perform militaryRobot.navigationSystem.navigateToWaypoint;
					perform militaryRobot.mobilityPlatform.move;
				}
			}
			accept BaseReached;
			then standby;
			accept SystemFault;
			then fault;
			
			state fault {
				entry assign militaryRobot.operationalStatus := RobotStatus::fault;
			}
			accept FaultCleared;
			then standby;
		}
	}
	
	package AllocationModel {
		private import RequirementModel::*;
		private import LogicalModel::*;
		private import PhysicalModel::*;
		
		allocation def LogicalToPhysical {
			end logical : CombatRobotSystem;
			end physical : MilitaryRobot;
		}
		
		allocation robotAllocation : LogicalToPhysical
			allocate logical ::> combatRobotSystem to physical ::> militaryRobot {
			allocate combatRobotSystem.executeMission to militaryRobot.executeMission;
			allocate combatRobotSystem.executeMission.navigate 
				to militaryRobot.navigationSystem.navigateToWaypoint;
			allocate combatRobotSystem.executeMission.scan 
				to militaryRobot.sensorSuite.detectTargets;
			allocate combatRobotSystem.executeMission.engage 
				to militaryRobot.weaponSystem.fireWeapon;
			allocate combatRobotSystem.executeMission.transmit 
				to militaryRobot.commSystem.transmitData;
			allocate combatRobotSystem.executeMission.returnHome 
				to militaryRobot.navigationSystem.navigateToWaypoint;
		}
		
		satisfy missionCapabilityReq by militaryRobot;
		satisfy enduranceReq by militaryRobot;
		satisfy commSecurityReq by militaryRobot;
		satisfy weaponReq by militaryRobot;
	}
}
