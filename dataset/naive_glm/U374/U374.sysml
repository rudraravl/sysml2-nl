package ScavengerRobotSystem {

	import ScalarValues::*;
	import ISQ::*;

	valueType DistanceValue :> Real { unit 'm'; }
	valueType VolumeValue :> Real { unit 'm3'; }
	valueType BatteryLevel :> Real { unit '%'; }
	valueType MassValue :> Real { unit 'kg'; }
	valueType PowerValue :> Real { unit 'W'; }
	valueType ForceValue :> Real { unit 'N'; }
	valueType SpeedValue :> Real { unit 'm/s'; }
	valueType AccuracyValue :> Real { unit '%'; }
	valueType BearingValue :> Real { unit 'deg'; }

	enum MaterialType { metal; plastic; electronics; waste; unknown; }
	enum OperationMode { idle; searching; collecting; processing; transporting; depositing; charging; }

	item def Material {
		attribute type : MaterialType;
		attribute mass : MassValue;
		attribute valueScore : Real;
	}

	item def ProcessedMaterial :> Material {
		attribute sorted : Boolean;
		attribute isValuable : Boolean;
	}

	item def ScanResult {
		attribute detected : Boolean;
		attribute materialType : MaterialType;
		attribute distance : DistanceValue;
		attribute bearing : BearingValue;
		attribute position : Real[2];
	}

	requirement def ScanningCapabilityRequirement {
		subject sensor : SensorModule;
		requirement {
			subject sensor;
			constraint { sensor.maxRange >= 100 [m]; }
		}
	}

	requirement def ArmReachRequirement {
		subject arm : MechanicalArm;
		requirement {
			subject arm;
			constraint { arm.maxReach >= 3 [m]; }
		}
	}

	requirement def StorageCapacityRequirement {
		subject storage : StorageCompartment;
		requirement {
			subject storage;
			constraint { storage.capacity >= 1.5 [m3]; }
		}
	}

	requirement def SortingAccuracyRequirement {
		subject processor : ProcessingModule;
		requirement {
			subject processor;
			constraint { processor.sortingAccuracy >= 95 [%]; }
		}
	}

	requirement def AutonomyRequirement {
		subject robot : ScavengerRobot;
		requirement {
			subject robot;
			constraint { robot.requiresHumanSupervision == false; }
		}
	}

	requirement def ContinuousOperationRequirement {
		subject robot : ScavengerRobot;
		requirement {
			subject robot;
			constraint { robot.operatesContinuously == true; }
		}
	}

	port def MaterialPort {
		in item material : Material;
		out item processed : ProcessedMaterial;
	}

	port def PowerPort {
		in attribute power : PowerValue;
		out attribute level : BatteryLevel;
	}

	port def CommandPort {
		in attribute targetBearing : BearingValue;
		in attribute targetDistance : DistanceValue;
		out attribute position : Real[2];
	}

	port def ScanPort {
		out item scanResult : ScanResult;
	}

	port def DepositPort {
		in item deposited : ProcessedMaterial[*];
	}

	port def ChargePort {
		out attribute suppliedPower : PowerValue;
	}

	part def SensorModule {
		attribute maxRange : DistanceValue = 100 [m];
		attribute detectionAccuracy : AccuracyValue = 98 [%];
		port scanOut : ScanPort;

		action def PerformScan {
			in environmentPosition : Real[2];
			out result : ScanResult;
		}

		action scan : PerformScan;
	}

	part def NavigationSystem {
		attribute currentSpeed : SpeedValue = 1.5 [m/s];
		attribute currentPosition : Real[2] = (0.0, 0.0);
		port navCmd : CommandPort;

		action def NavigateTo {
			in target : Real[2];
			in currentPosition : Real[2];
			out newPosition : Real[2];
		}

		action navigate : NavigateTo;
	}

	part def MechanicalArm {
		attribute maxReach : DistanceValue = 3 [m];
		attribute graspForce : ForceValue = 500 [N];
		port armPort : MaterialPort;

		action def Grasp {
			in target : Material;
			out retrieved : Material;
		}

		action def Release {
			in item : Material;
		}

		action collect : Grasp;
	}

	part def ProcessingModule {
		attribute sortingAccuracy : AccuracyValue = 97 [%];
		attribute throughput : MassValue = 2 [kg];
		port procPort : MaterialPort;

		action def Sort {
			in raw : Material;
			out processed : ProcessedMaterial;
		}

		action process : Sort;
	}

	part def StorageCompartment {
		attribute capacity : VolumeValue = 1.5 [m3];
		attribute used : VolumeValue = 0 [m3];
		attribute isFull : Boolean = false;
		port storePort : MaterialPort;

		action def Store {
			in item : ProcessedMaterial;
		}

		action def Unload {
			out items : ProcessedMaterial[*];
		}

		action store : Store;
		action unload : Unload;
	}

	part def PowerManagement {
		attribute batteryLevel : BatteryLevel = 100 [%];
		attribute threshold : BatteryLevel = 20 [%];
		attribute criticalThreshold : BatteryLevel = 10 [%];
		port powerPort : PowerPort;

		action def Recharge {
			in amount : BatteryLevel;
			out newLevel : BatteryLevel;
		}

		action def Consume {
			in amount : BatteryLevel;
		}

		action recharge : Recharge;
		action consume : Consume;

		state powerState {
			entry; then Normal;
			state Normal;
			transition Normal to Low
				when batteryLevel <= threshold;
			state Low;
			transition Low to Critical
				when batteryLevel <= criticalThreshold;
			state Critical;
			transition Critical to Low
				when batteryLevel > criticalThreshold;
			transition Low to Normal
				when batteryLevel > threshold;
		}
	}

	part def DepositStation {
		attribute location : Real[2];
		attribute capacity : VolumeValue = 10 [m3];
		port depositPort : DepositPort;

		action def ReceiveDeposit {
			in items : ProcessedMaterial[*];
		}

		action receive : ReceiveDeposit;
	}

	part def ChargingStation {
		attribute location : Real[2];
		attribute outputPower : PowerValue = 1500 [W];
		port chargePort : ChargePort;

		action def Charge {
			out power : PowerValue;
		}

		action charge : Charge;
	}

	part def Environment {
		attribute area : Real[2];
		item materials : Material[*];
		part depositStations : DepositStation[*];
		part chargingStations : ChargingStation[*];
	}

	part def ScavengerRobot {
		attribute requiresHumanSupervision : Boolean = false;
		attribute operatesContinuously : Boolean = true;
		attribute position : Real[2] = (0.0, 0.0);
		attribute currentMode : OperationMode = idle;
		attribute depositStationLocation : Real[2];
		attribute chargingStationLocation : Real[2];

		part sensor : SensorModule;
		part navigation : NavigationSystem;
		part arm : MechanicalArm;
		part processor : ProcessingModule;
		part storage : StorageCompartment;
		part power : PowerManagement;

		port extScan : ScanPort;
		port extCmd : CommandPort;
		port extMaterial : MaterialPort;
		port extPower : PowerPort;

		connection sensor.scanOut to extScan;
		connection navigation.navCmd to extCmd;
		connection arm.armPort to processor.procPort;
		connection processor.procPort to storage.storePort;
		connection storage.storePort to extMaterial;
		connection power.powerPort to extPower;

		satisfy ScanningCapabilityRequirement by sensor;
		satisfy ArmReachRequirement by arm;
		satisfy StorageCapacityRequirement by storage;
		satisfy SortingAccuracyRequirement by processor;
		satisfy AutonomyRequirement by self;
		satisfy ContinuousOperationRequirement by self;

		state robotState {
			entry; then Idle;

			state Idle;
			transition Idle to Searching
				when power.batteryLevel > power.threshold and !storage.isFull;

			state Searching;
			transition Searching to Collecting
				when sensor.scanOut.scanResult.detected == true;
			transition Searching to Transporting
				when storage.isFull == true;
			transition Searching to Charging
				when power.batteryLevel <= power.threshold;

			state Collecting;
			transition Collecting to Processing
				when arm.collect.retrieved != null;
			transition Collecting to Searching
				when sensor.scanOut.scanResult.detected == false;

			state Processing;
			transition Processing to Searching
				when processor.process.done;

			state Transporting;
			transition Transporting to Depositing
				when position == depositStationLocation;

			state Depositing;
			transition Depositing to Searching
				when storage.isFull == false;

			state Charging;
			transition Charging to Searching
				when power.batteryLevel >= 100 [%];
		}

		action def ScavengeCycle {
			in env : Environment;

			action scanArea {
				out result : ScanResult;
			}
			then action moveToTarget {
				in result : ScanResult;
			}
			then action collectItem {
				in target : Material;
				out retrieved : Material;
			}
			then action processItem {
				in raw : Material;
				out processed : ProcessedMaterial;
			}
			then action storeItem {
				in processed : ProcessedMaterial;
			}
			then decide storageFull;
			if storageFull {
				action travelToDeposit {
					out deposited : ProcessedMaterial[*];
				}
			}
			decide batteryLow;
			if batteryLow {
				action travelToCharger {
					out recharged : Boolean;
				}
			}
		}

		action scavenge : ScavengeCycle;
	}

	part ScavengerSystem {
		part robot : ScavengerRobot;
		part environment : Environment;
		part depositStation : DepositStation {
			attribute location : Real[2] = (100.0, 100.0);
		}
		part chargingStation : ChargingStation {
			attribute location : Real[2] = (0.0, 50.0);
		}

		connection robot.extMaterial to depositStation.depositPort;
		connection robot.extPower to chargingStation.chargePort;
	}

}
