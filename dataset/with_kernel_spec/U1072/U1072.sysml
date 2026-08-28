package AutonomousHarvester {
	private import ScalarValues::*;

	attribute def StartCommand;
	attribute def InitComplete;
	attribute def BatteryLow;
	attribute def BatteryFull;
	attribute def BinFull;
	attribute def BinEmpty;
	attribute def MissionComplete;
	attribute def SystemFault;
	attribute def ResetCommand;

	item def GPSLocation {
		attribute latitude : Real;
		attribute longitude : Real;
	}

	attribute def RipenessLevel :> Real;
	attribute def MassValue :> Real;
	attribute def ForceValue :> Real;
	attribute def LengthValue :> Real;
	attribute def EnergyValue :> Real;

	item def Crop {
		attribute location : GPSLocation;
		attribute ripeness : RipenessLevel;
		attribute weight : MassValue;
	}

	item def HarvestedCrop :> Crop;

	port def CropDataPort {
		out detectedCrops : Crop[0..*];
	}

	port def NavCommandPort {
		out targetLocation : GPSLocation;
	}

	port def ArmCommandPort {
		out targetLocation : GPSLocation;
		out gripForce : ForceValue;
	}

	port def CropFlowPort {
		out crop : HarvestedCrop;
	}

	port def StoragePort {
		in crop : HarvestedCrop;
		out currentWeight : MassValue;
		out isFull : Boolean;
	}

	port def PowerPort {
		out chargeLevel : Real;
	}

	action def RunDiagnostics { out ready : Boolean; }
	action def ScanField { out detectedCrops : Crop[0..*]; }
	action def SelectTarget { in crops : Crop[0..*]; out selected : Crop; }
	action def AnalyzeRipeness { in crop : Crop; out ripeness : RipenessLevel; }
	action def PlanPath { in target : GPSLocation; out path : GPSLocation[0..*]; }
	action def DriveToTarget { in path : GPSLocation[0..*]; out arrived : Boolean; }
	action def PositionArm { in target : GPSLocation; out positioned : Boolean; }
	action def GripCrop { in force : ForceValue; out gripped : Boolean; }
	action def PickCrop { out crop : HarvestedCrop; }
	action def TransferCrop { in crop : HarvestedCrop; out delivered : Boolean; }
	action def StoreCrop { in crop : HarvestedCrop; out currentWeight : MassValue; }
	action def UnloadBin;
	action def RechargeBattery;
	action def LogError;
	action def SafeShutdown;
	action def EvaluateMission { in current : MassValue; in target : MassValue; out complete : Boolean; }

	action def HarvestCropSequence {
		in target : GPSLocation;
		in force : ForceValue;
		out crop : HarvestedCrop;
		first start;
		then action position : PositionArm { in target; out positioned; }
		then action grip : GripCrop { in force; out gripped; }
		then action pick : PickCrop { out crop; }
		then done;
	}

	action def HarvestingCycle {
		in targetWeight : MassValue;
		first start;
		then action scan : ScanField { out detectedCrops; }
		then action select : SelectTarget { in crops = scan.detectedCrops; out selected; }
		then action analyze : AnalyzeRipeness { in crop = select.selected; out ripeness; }
		then if analyze.ripeness >= 0.85 {
			action harvestBranch : HarvestCropSequence {
				in target = select.selected.location;
				in force = 35.0;
				out crop;
			}
			then action transfer : TransferCrop { in crop = harvestBranch.crop; out delivered; }
			then action store : StoreCrop { in crop = transfer.crop; out currentWeight; }
			then action evaluate : EvaluateMission {
				in current = store.currentWeight;
				in target = targetWeight;
				out complete;
			}
		}
		then done;
	}

	part def VisionSystem {
		port cropDataOut : CropDataPort;
		port powerIn : ~PowerPort;
		perform action scanField : ScanField;
		perform action analyzeRipeness : AnalyzeRipeness;
	}

	part def NavigationController {
		port navCmdIn : ~NavCommandPort;
		port powerIn : ~PowerPort;
		perform action planPath : PlanPath;
		perform action driveToTarget : DriveToTarget;
	}

	part def HarvestingArm {
		attribute maxReach : LengthValue = 2.5;
		attribute maxGripForce : ForceValue = 45.0;
		port armCmdIn : ~ArmCommandPort;
		port cropOut : CropFlowPort;
		port powerIn : ~PowerPort;
		perform action positionArm : PositionArm;
		perform action gripCrop : GripCrop;
		perform action pickCrop : PickCrop;
	}

	part def ConveyorSystem {
		port cropIn : ~CropFlowPort;
		port cropOut : CropFlowPort;
		port powerIn : ~PowerPort;
		perform action transferCrop : TransferCrop;
	}

	part def StorageBin {
		attribute capacity : MassValue = 500.0;
		attribute currentWeight : MassValue = 0.0;
		port storageIn : StoragePort;
		perform action storeCrop : StoreCrop;
		perform action unloadBin : UnloadBin;
	}

	part def BatteryPack {
		attribute capacity : EnergyValue = 12.0;
		attribute currentCharge : Real = 100.0;
		port powerOut : PowerPort;
		perform action rechargeBattery : RechargeBattery;
	}

	part def MissionController {
		attribute harvestTarget : MassValue = 300.0;
		port cropDataIn : ~CropDataPort;
		port navCmdOut : NavCommandPort;
		port armCmdOut : ArmCommandPort;
		port powerIn : ~PowerPort;
		perform action selectTarget : SelectTarget;
		perform action evaluateMission : EvaluateMission;
	}

	state def HarvesterStates {
		in battery : BatteryPack;
		in storage : StorageBin;
		in targetWeight : MassValue;

		entry; then initialization;
		state initialization {
			do action diagnostics : RunDiagnostics { out ready; }
		}
		accept InitComplete then standby;
		state standby;
		accept StartCommand then active;
		state active {
			do action cycle : HarvestingCycle { in targetWeight; }
		}
		accept BatteryLow then charging;
		accept BinFull then unloading;
		accept SystemFault then fault;
		state charging {
			do action recharge : RechargeBattery;
		}
		accept BatteryFull then standby;
		state unloading {
			do action unload : UnloadBin;
		}
		accept BinEmpty then standby;
		state fault {
			entry action logError : LogError;
			do action safeShutdown : SafeShutdown;
		}
		accept ResetCommand then initialization;
	}

	part def HarvesterSystem {
		attribute targetWeight : MassValue = 300.0;

		part visionSystem : VisionSystem;
		part navigationController : NavigationController;
		part harvestingArm : HarvestingArm;
		part conveyorSystem : ConveyorSystem;
		part storageBin : StorageBin;
		part batteryPack : BatteryPack;
		part missionController : MissionController;

		connect visionSystem.cropDataOut to missionController.cropDataIn;
		connect missionController.navCmdOut to navigationController.navCmdIn;
		connect missionController.armCmdOut to harvestingArm.armCmdIn;

		flow of HarvestedCrop from harvestingArm.cropOut.crop to conveyorSystem.cropIn.crop;
		flow of HarvestedCrop from conveyorSystem.cropOut.crop to storageBin.storageIn.crop;

		connect batteryPack.powerOut to visionSystem.powerIn;
		connect batteryPack.powerOut to navigationController.powerIn;
		connect batteryPack.powerOut to harvestingArm.powerIn;
		connect batteryPack.powerOut to conveyorSystem.powerIn;
		connect batteryPack.powerOut to missionController.powerIn;

		state harvesterStates : HarvesterStates {
			in battery = batteryPack;
			in storage = storageBin;
			in targetWeight = targetWeight;
		}
	}

	requirement def HarvestingRequirement {
		doc /* The system shall autonomously identify, navigate to, and harvest ripe crops without human intervention. */
		attribute minRipeness : RipenessLevel = 0.85;
	}

	requirement def CropSafetyRequirement {
		doc /* The harvesting arm shall not exceed the maximum grip force to prevent crop damage. */
		attribute maxForce : ForceValue = 45.0;
	}

	requirement def StorageCapacityRequirement {
		doc /* The storage bin shall have sufficient capacity for harvested crops. */
		attribute minCapacity : MassValue = 500.0;
	}

	requirement def BatteryLifeRequirement {
		doc /* The battery pack shall provide sufficient energy for extended field operation. */
		attribute minCapacity : EnergyValue = 12.0;
	}

	requirement def AutonomousOperationRequirement {
		doc /* The system shall operate autonomously through initialization, harvesting, charging, and unloading states. */
	}

	requirement harvestReq : HarvestingRequirement {
		subject harvester : HarvesterSystem;
	}

	requirement cropSafetyReq : CropSafetyRequirement {
		subject arm : HarvestingArm;
	}

	requirement storageCapacityReq : StorageCapacityRequirement {
		subject bin : StorageBin;
	}

	requirement batteryLifeReq : BatteryLifeRequirement {
		subject battery : BatteryPack;
	}

	requirement autonomousReq : AutonomousOperationRequirement {
		subject harvester : HarvesterSystem;
	}
}
