package 'MieleG7310Dishwasher' {
	private import ScalarValues::*;

	package Definitions {
		attribute def Temperature :> Real;
		attribute def Volume :> Real;
		attribute def SoundLevel :> Real;
		attribute def PlaceSettings :> Integer;

		attribute def StartCycleSignal;
		attribute def DoorLockedSignal;
		attribute def PreWashCompleteSignal;
		attribute def DrainCompleteSignal;
		attribute def MainWashCompleteSignal;
		attribute def RinseCompleteSignal;
		attribute def SanitizeRinseCompleteSignal;
		attribute def DryingCompleteSignal;
		attribute def DoorUnlockedSignal;
		attribute def ProgramType;

		item def Water;
		item def SoftWater :> Water;
		item def HotWater :> SoftWater;
		item def SoiledWater :> Water;
		item def Detergent;
		item def Dish;
		item def CleanDish :> Dish;

		port def WaterPort {
			in item water : Water;
		}
		port def DetergentPort {
			in item detergent : Detergent;
		}
		port def ControlPort {
			in attribute command : Boolean;
		}
		port def SensorPort {
			out attribute reading : Real;
		}
		port def ProgramPort {
			in attribute program : ProgramType;
		}

		part def InletValve {
			port waterIn : WaterPort;
			port waterOut : ~WaterPort;
			port controlIn : ControlPort;
		}
		part def WaterSoftener {
			port waterIn : WaterPort;
			port waterOut : ~WaterPort;
		}
		part def HeatingSystem {
			port waterIn : WaterPort;
			port waterOut : ~WaterPort;
			port controlIn : ControlPort;
			port tempSensorIn : ~SensorPort;
		}
		part def CirculationPump {
			port waterIn : WaterPort;
			port waterOut : ~WaterPort;
			port controlIn : ControlPort;
		}
		part def SprayArm {
			port waterIn : WaterPort;
		}
		part def DetergentDispenser {
			port detergentOut : ~DetergentPort;
			port controlIn : ControlPort;
		}
		part def DrainPump {
			port waterIn : WaterPort;
			port waterOut : ~WaterPort;
			port controlIn : ControlPort;
		}
		part def DishRack {
			item dishes : Dish[0..*];
		}
		part def CutleryBasket {
			item cutlery : Dish[0..*];
		}
		part def WashingChamber {
			port detergentIn : DetergentPort;
			port drainOut : ~WaterPort;
			part upperRack : DishRack;
			part lowerRack : DishRack;
			part cutleryBasket : CutleryBasket;
			part upperSprayArm : SprayArm;
			part lowerSprayArm : SprayArm;
		}
		part def TemperatureSensor {
			port readingOut : SensorPort;
		}
		part def WaterLevelSensor {
			port readingOut : SensorPort;
		}
		part def TurbiditySensor {
			port readingOut : SensorPort;
		}
		part def DoorLock {
			port controlIn : ControlPort;
			attribute locked : Boolean = false;
		}
		part def ControlModule {
			port tempSensorIn : ~SensorPort;
			port levelSensorIn : ~SensorPort;
			port turbiditySensorIn : ~SensorPort;
			port inletValveControl : ~ControlPort;
			port heaterControl : ~ControlPort;
			port circPumpControl : ~ControlPort;
			port detergentControl : ~ControlPort;
			port drainPumpControl : ~ControlPort;
			port doorLockControl : ~ControlPort;
			port programSelectIn : ProgramPort;
		}

		action def PreWashAction {
			in water : Water;
			out soiledWater : SoiledWater;
		}
		action def MainWashAction {
			in water : HotWater;
			in detergent : Detergent;
			out soiledWater : SoiledWater;
		}
		action def RinseAction {
			in water : Water;
			out soiledWater : SoiledWater;
		}
		action def SanitizeRinseAction {
			in water : HotWater;
			out soiledWater : SoiledWater;
		}
		action def DrainAction {
			in soiledWater : SoiledWater;
			out drainedWater : SoiledWater;
		}
		action def DryAction {
			in dishes : Dish;
			out cleanDishes : CleanDish;
		}

		state def WashCycleStateMachine {
			entry; then idle;
			state idle;
			accept StartCycleSignal then doorLocking;
			state doorLocking;
			accept DoorLockedSignal then preWash;
			state preWash {
				entry action preWashAction : PreWashAction;
			}
			accept PreWashCompleteSignal then drain1;
			state drain1 {
				entry action drainAction1 : DrainAction;
			}
			accept DrainCompleteSignal then mainWash;
			state mainWash {
				entry action mainWashAction : MainWashAction;
			}
			accept MainWashCompleteSignal then drain2;
			state drain2 {
				entry action drainAction2 : DrainAction;
			}
			accept DrainCompleteSignal then rinse1;
			state rinse1 {
				entry action rinseAction1 : RinseAction;
			}
			accept RinseCompleteSignal then drain3;
			state drain3 {
				entry action drainAction3 : DrainAction;
			}
			accept DrainCompleteSignal then sanitizeRinse;
			state sanitizeRinse {
				entry action sanitizeRinseAction : SanitizeRinseAction;
			}
			accept SanitizeRinseCompleteSignal then drain4;
			state drain4 {
				entry action drainAction4 : DrainAction;
			}
			accept DrainCompleteSignal then drying;
			state drying {
				entry action dryAction : DryAction;
			}
			accept DryingCompleteSignal then doorUnlocking;
			state doorUnlocking;
			accept DoorUnlockedSignal then idle;
		}

		part def Dishwasher {
			attribute modelNumber : String = "G7310";
			attribute maxCapacity : PlaceSettings = 14;

			part controlModule : ControlModule;
			part inletValve : InletValve;
			part waterSoftener : WaterSoftener;
			part heatingSystem : HeatingSystem;
			part circulationPump : CirculationPump;
			part detergentDispenser : DetergentDispenser;
			part drainPump : DrainPump;
			part doorLock : DoorLock;
			part washingChamber : WashingChamber;
			part tempSensor : TemperatureSensor;
			part levelSensor : WaterLevelSensor;
			part turbiditySensor : TurbiditySensor;

			flow of water : Water
				from inletValve.waterOut.water to waterSoftener.waterIn.water;
			flow of softWater : SoftWater
				from waterSoftener.waterOut.water to heatingSystem.waterIn.water;
			flow of hotWater : HotWater
				from heatingSystem.waterOut.water to circulationPump.waterIn.water;
			flow of hotWater : HotWater
				from circulationPump.waterOut.water to washingChamber.upperSprayArm.waterIn.water;
			flow of hotWater : HotWater
				from circulationPump.waterOut.water to washingChamber.lowerSprayArm.waterIn.water;
			flow of detergent : Detergent
				from detergentDispenser.detergentOut.detergent to washingChamber.detergentIn.detergent;
			flow of soiledWater : SoiledWater
				from washingChamber.drainOut.water to drainPump.waterIn.water;

			bind controlModule.inletValveControl = inletValve.controlIn;
			bind controlModule.heaterControl = heatingSystem.controlIn;
			bind controlModule.circPumpControl = circulationPump.controlIn;
			bind controlModule.detergentControl = detergentDispenser.controlIn;
			bind controlModule.drainPumpControl = drainPump.controlIn;
			bind controlModule.doorLockControl = doorLock.controlIn;

			bind controlModule.tempSensorIn = tempSensor.readingOut;
			bind controlModule.levelSensorIn = levelSensor.readingOut;
			bind controlModule.turbiditySensorIn = turbiditySensor.readingOut;
			bind heatingSystem.tempSensorIn = tempSensor.readingOut;
		}
	}

	package Requirements {
		private import Definitions::*;

		requirement def CleaningPerformanceReq {
			doc /* The dishwasher shall effectively clean dishes to remove food soil. */
			attribute cleaningScore : Real;
			attribute minCleaningScore : Real = 0.95;
			require constraint { cleaningScore >= minCleaningScore }
		}
		requirement def SanitizationReq {
			doc /* The final rinse shall achieve sanitization temperatures of at least 70 degrees Celsius. */
			attribute finalRinseTemp : Temperature;
			attribute minSanitizeTemp : Temperature = 70;
			require constraint { finalRinseTemp >= minSanitizeTemp }
		}
		requirement def WaterEfficiencyReq {
			doc /* The dishwasher shall use under 10 liters of water per cycle. */
			attribute waterUsed : Volume;
			attribute maxWaterUsed : Volume = 10;
			require constraint { waterUsed <= maxWaterUsed }
		}
		requirement def EnergyEfficiencyReq {
			doc /* The dishwasher shall achieve an A+++ energy rating. */
			attribute energyRating : String;
			require constraint { energyRating == "A+++" }
		}
		requirement def SafetyReq {
			doc /* The dishwasher shall include an active door lock and leak protection. */
			attribute doorLockEngaged : Boolean;
			attribute leakProtectionActive : Boolean;
			require constraint { doorLockEngaged and leakProtectionActive }
		}
		requirement def NoiseLevelReq {
			doc /* The dishwasher shall operate under 44 dB. */
			attribute noiseLevel : SoundLevel;
			attribute maxNoiseLevel : SoundLevel = 44;
			require constraint { noiseLevel <= maxNoiseLevel }
		}
		requirement def CapacityReq {
			doc /* The dishwasher shall accommodate 14 place settings. */
			attribute capacity : PlaceSettings;
			attribute minCapacity : PlaceSettings = 14;
			require constraint { capacity >= minCapacity }
		}
		requirement def ProgramFlexibilityReq {
			doc /* The dishwasher shall offer multiple wash programs including eco, intensive, and quick. */
			attribute programCount : Integer;
			attribute minProgramCount : Integer = 3;
			require constraint { programCount >= minProgramCount }
		}
	}

	package Usages {
		private import Definitions::*;
		private import Requirements::*;

		part dishwasher : Dishwasher {
			state washCycle : WashCycleStateMachine;

			satisfy CleaningPerformanceReq;
			satisfy SanitizationReq;
			satisfy WaterEfficiencyReq;
			satisfy EnergyEfficiencyReq;
			satisfy SafetyReq;
			satisfy NoiseLevelReq;
			satisfy CapacityReq;
			satisfy ProgramFlexibilityReq;
		}
	}
}
