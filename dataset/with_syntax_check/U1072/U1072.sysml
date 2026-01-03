package HarvestAutomationSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def CropType;
	attribute def RipenessLevel :> Real;
	attribute def HarvestQuality;
	
	item def GPSCoordinate {
		attribute latitude : Real;
		attribute longitude : Real;
		attribute altitude : LengthValue;
	}
	
	item def CropData {
		attribute location : GPSCoordinate;
		attribute cropType : CropType;
		attribute ripeness : RipenessLevel;
		attribute estimatedMass : MassValue;
		attribute timestamp : TimeValue;
	}
	
	item def HarvestCommand {
		attribute targetLocation : GPSCoordinate;
		attribute gripForce : ForceValue;
		attribute approachSpeed : SpeedValue;
	}
	
	item def HarvestReport {
		attribute harvestedMass : MassValue;
		attribute harvestedCount : Integer;
		attribute operationDuration : TimeValue;
		attribute averageQuality : HarvestQuality;
	}
	
	item def SystemStatus {
		attribute currentPosition : GPSCoordinate;
		attribute binCapacityUsed : Real;
		attribute batteryLevel : Real;
		attribute isOperational : Boolean;
	}
	
	attribute def RipenessThreshold :> Real;
	attribute def DetectionConfidence :> Real;
	
	port def SensorDataPort {
		out cropDetection : CropData;
		out environmentData : Real;
	}
	
	port def ControlCommandPort {
		in harvestCmd : HarvestCommand;
		in navigationCmd : GPSCoordinate;
		out statusFeedback : SystemStatus;
	}
	
	port def PowerPort {
		attribute voltage : Real;
		attribute current : Real;
		attribute power : PowerValue;
	}
	
	port def CropFlowPort {
		attribute cropMass : MassValue;
	}
	
	part def VisionSystem {
		port sensorOut : SensorDataPort;
		
		attribute detectionRange : LengthValue;
		attribute fieldOfView : Real;
		attribute resolution : Real;
		
		action def ScanField {
			out detectedCrops : CropData[*];
		}
		
		action def AssessRipeness {
			in crop : CropData;
			out ripenessScore : RipenessLevel;
			out confidence : DetectionConfidence;
		}
		
		perform action continuousScan[*] : ScanField;
	}
	
	part def NavigationController {
		attribute currentPosition : GPSCoordinate;
		attribute targetPosition : GPSCoordinate;
		attribute maxSpeed : SpeedValue;
		
		action def PlanPath {
			in start : GPSCoordinate;
			in goal : GPSCoordinate;
			out waypoints : GPSCoordinate[*];
		}
		
		action def NavigateToTarget {
			in target : GPSCoordinate;
			out arrived : Boolean;
		}
	}
	
	part def HarvestingArm {
		port controlIn : ControlCommandPort;
		port powerIn : PowerPort;
		
		attribute maxReach : LengthValue;
		attribute maxGripForce : ForceValue;
		attribute currentLoad : MassValue;
		
		action def PositionArm {
			in targetLocation : GPSCoordinate;
			out positioned : Boolean;
		}
		
		action def GripCrop {
			in force : ForceValue;
			out gripped : Boolean;
		}
		
		action def PickCrop {
			in command : HarvestCommand;
			out harvested : CropData;
			out success : Boolean;
			
			first start;
			then action position : PositionArm {
				in targetLocation = command.targetLocation;
				out positioned;
			}
			then decide;
				if position.positioned then grip;
				else abort;
			
			action grip : GripCrop {
				in force = command.gripForce;
				out gripped;
			}
			then decide;
				if grip.gripped then extract;
				else abort;
			
			action extract {
				out success = true;
			}
			then done;
			
			action abort {
				out success = false;
			}
			then done;
		}
	}
	
	part def ConveyorSystem {
		port powerIn : PowerPort;
		port cropIn : CropFlowPort;
		port cropOut : CropFlowPort;
		
		attribute beltSpeed : SpeedValue;
		attribute throughput : Real;
		
		action def TransportCrop {
			in incomingMass : MassValue;
			out deliveredMass : MassValue;
		}
	}
	
	part def StorageBin {
		port intake : CropFlowPort;
		
		attribute capacity : MassValue;
		attribute currentLoad : MassValue;
		attribute fillLevel : Real;
		
		action def StoreCrop {
			in crop : CropData;
			out stored : Boolean;
			out newLoad : MassValue;
		}
		
		constraint capacityLimit {
			currentLoad <= capacity
		}
	}
	
	part def BatteryPack {
		port supply : PowerPort;
		
		attribute capacity : EnergyValue;
		attribute stateOfCharge : Real;
		attribute voltage : Real;
		
		action def SupplyPower {
			out availablePower : PowerValue;
		}
		
		constraint chargeLevel {
			stateOfCharge >= 0.0 and stateOfCharge <= 1.0
		}
	}
	
	part def MissionController {
		attribute harvestGoal : MassValue;
		attribute ripenessThreshold : RipenessThreshold;
		attribute operatingMode : String;
		
		action def EvaluateCrop {
			in cropData : CropData;
			in threshold : RipenessThreshold;
			out shouldHarvest : Boolean;
		}
		
		action def GenerateHarvestCommand {
			in crop : CropData;
			out command : HarvestCommand;
		}
		
		action def UpdateMissionStatus {
			in harvestedMass : MassValue;
			in binLevel : Real;
			out continueOperation : Boolean;
		}
	}
	
	action def AutonomousHarvestMission {
		in goalMass : MassValue;
		in ripenessThreshold : RipenessThreshold;
		out finalReport : HarvestReport;
		
		private attribute totalHarvested : MassValue := 0.0 [kg];
		private attribute cropCount : Integer := 0;
		private attribute startTime : TimeValue;
		
		first start;
		then merge operationLoop;
		
		then action scanField {
			out detectedCrops : CropData[*];
		}
		
		then decide;
			if scanField.detectedCrops->size() > 0 then processCrops;
			if scanField.detectedCrops->size() == 0 then checkCompletion;
		
		action processCrops {
			for crop in scanField.detectedCrops {
				action evaluateRipeness {
					in cropData = crop;
					in threshold = ripenessThreshold;
					out isRipe : Boolean;
				}
				
				then decide;
					if evaluateRipeness.isRipe then navigateToCrop;
					else skipCrop;
				
				action navigateToCrop {
					in target = crop.location;
					out arrived : Boolean;
				}
				
				then action harvestCrop {
					in cropData = crop;
					out harvested : CropData;
					out success : Boolean;
				}
				
				then decide;
					if harvestCrop.success then transferCrop;
					else skipCrop;
				
				action transferCrop {
					in harvested = harvestCrop.harvested;
					out transferred : Boolean;
				}
				
				then assign totalHarvested := totalHarvested + harvestCrop.harvested.estimatedMass;
				then assign cropCount := cropCount + 1;
				
				action skipCrop;
			}
		}
		
		then action checkCompletion {
			out goalReached : Boolean;
		}
		
		then decide;
			if totalHarvested >= goalMass then generateReport;
			if totalHarvested < goalMass then operationLoop;
		
		action generateReport {
			assign finalReport := HarvestReport {
				harvestedMass = totalHarvested;
				harvestedCount = cropCount;
				operationDuration = 0.0 [s];
			};
		}
		
		then done;
	}
	
	state machine def SystemOperatingModes {
		state standby {
			entry action powerDown;
		}
		
		state initializing {
			entry action systemCheck;
		}
		
		state autonomous {
			entry action startMission;
			do action executeHarvest;
		}
		
		state manual {
			entry action enableManualControl;
		}
		
		state unloading {
			entry action transferToStorage;
		}
		
		state charging {
			entry action connectCharger;
		}
		
		state fault {
			entry action diagnostics;
		}
		
		transition standby_to_initializing
			first standby
			accept startCommand
			then initializing;
		
		transition initializing_to_autonomous
			first initializing
			if systemCheck.passed
			then autonomous;
		
		transition autonomous_to_unloading
			first autonomous
			if binFull
			then unloading;
		
		transition unloading_to_autonomous
			first unloading
			if binEmpty
			then autonomous;
		
		transition autonomous_to_charging
			first autonomous
			if batteryLow
			then charging;
		
		transition charging_to_standby
			first charging
			if batteryFull
			then standby;
		
		transition any_to_fault
			first standby, initializing, autonomous, manual, unloading, charging
			accept errorDetected
			then fault;
		
		transition fault_to_standby
			first fault
			if errorCleared
			then standby;
	}
	
	part harvestAutomationSystem {
		satisfy primaryMissionRequirement;
		satisfy harvestEfficiencyRequirement;
		satisfy operationalDurationRequirement;
		satisfy safetyRequirement;
		
		perform state systemModes : SystemOperatingModes;
		perform action mission[*] : AutonomousHarvestMission {
			in goalMass = 200.0 [kg];
			in ripenessThreshold = 0.75;
		}
		
		part battery : BatteryPack {
			attribute :>> capacity = 15.0 [kWh];
			attribute :>> stateOfCharge = 0.9;
			attribute :>> voltage = 48.0;
		}
		
		part vision : VisionSystem {
			attribute :>> detectionRange = 5.0 [m];
			attribute :>> fieldOfView = 120.0;
			attribute :>> resolution = 1920.0;
		}
		
		part navigation : NavigationController {
			attribute :>> maxSpeed = 2.0 [m/s];
		}
		
		part arm : HarvestingArm {
			attribute :>> maxReach = 1.5 [m];
			attribute :>> maxGripForce = 50.0 [N];
			attribute :>> currentLoad = 0.0 [kg];
		}
		
		part conveyor : ConveyorSystem {
			attribute :>> beltSpeed = 0.5 [m/s];
			attribute :>> throughput = 100.0;
		}
		
		part bin : StorageBin {
			attribute :>> capacity = 250.0 [kg];
			attribute :>> currentLoad = 0.0 [kg];
			attribute :>> fillLevel = 0.0;
		}
		
		part controller : MissionController {
			attribute :>> harvestGoal = 200.0 [kg];
			attribute :>> ripenessThreshold = 0.75;
			attribute :>> operatingMode = "autonomous";
		}
		
		connect battery.supply to arm.powerIn;
		connect battery.supply to conveyor.powerIn;
		connect arm.controlIn to controller;
		connect conveyor.cropOut to bin.intake;
	}
	
	requirement def SystemRequirement;
	
	requirement <'HR-001'> primaryMissionRequirement : SystemRequirement {
		doc /* The harvest automation system shall autonomously identify, navigate to, 
		     and harvest ripe crops from agricultural fields with minimal human intervention. */
		
		subject system : HarvestAutomationSystem;
	}
	
	requirement <'HR-002'> harvestEfficiencyRequirement : SystemRequirement {
		doc /* The system shall achieve a minimum harvest success rate of 92% for all 
		     crops identified as ripe by the vision system. */
		
		subject system : HarvestAutomationSystem;
		
		require constraint {
			system.controller.harvestGoal * 0.92 <= system.bin.currentLoad
		}
	}
	
	requirement <'HR-003'> operationalDurationRequirement : SystemRequirement {
		doc /* The system shall operate continuously for at least 6 hours on a single 
		     battery charge under normal field conditions. */
		
		subject battery : BatteryPack;
		
		require constraint {
			battery.capacity >= 12.0 [kWh]
		}
	}
	
	requirement <'HR-004'> safetyRequirement : SystemRequirement {
		doc /* The harvesting arm shall not exceed maximum grip force limits to prevent 
		     damage to crops and ensure safe operation. */
		
		subject arm : HarvestingArm;
		
		require constraint {
			arm.maxGripForce <= 60.0 [N]
		}
	}
	
	requirement <'HR-005'> storageCapacityRequirement : SystemRequirement {
		doc /* The storage bin shall accommodate harvested crops equivalent to at least 
		     4 hours of continuous harvesting operation. */
		
		subject bin : StorageBin;
		
		require constraint {
			bin.capacity >= 200.0 [kg] and bin.currentLoad <= bin.capacity
		}
	}
	
	requirement <'HR-006'> ripenessDetectionRequirement : SystemRequirement {
		doc /* The vision system shall assess crop ripeness with a minimum confidence 
		     level of 85% to ensure harvest quality. */
		
		subject vision : VisionSystem;
	}
}
