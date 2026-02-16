package DishwasherSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def WaterTemperature :> ThermodynamicTemperatureValue;
	attribute def WaterVolume :> VolumeValue;
	attribute def WaterPressure :> PressureValue;
	attribute def WashDuration :> DurationValue;
	attribute def PowerConsumption :> PowerValue;
	
	item def FreshWater {
		attribute volume : WaterVolume;
		attribute temperature : WaterTemperature;
		attribute pressure : WaterPressure;
	}
	
	item def WasteWater {
		attribute volume : WaterVolume;
		attribute soilContent : Real;
	}
	
	item def DetergentPod {
		attribute mass : MassValue;
		attribute chemicalConcentration : Real;
	}
	
	item def DirtyDishes {
		attribute count : Integer;
		attribute soilLevel : Real;
	}
	
	item def CleanDishes {
		attribute count : Integer;
		attribute residualSoil : Real;
	}
	
	item def ElectricalPower {
		attribute voltage : Real;
		attribute current : Real;
	}
	
	port def WaterSupplyPort {
		in item freshWater : FreshWater;
	}
	
	port def DrainPort {
		out item wasteWater : WasteWater;
	}
	
	port def PowerPort {
		in item power : ElectricalPower;
	}
	
	port def UserControlPort {
		in attribute cycleSelection : Integer;
		in attribute startSignal : Boolean;
		out attribute statusIndicator : Integer;
	}
	
	part def WaterInletValve {
		port powerIn : PowerPort;
		port waterSupply : WaterSupplyPort;
		port waterOut;
		attribute isOpen : Boolean;
		attribute flowRate : Real;
	}
	
	part def WashChamber {
		attribute currentVolume : WaterVolume;
		attribute currentTemperature : WaterTemperature;
		attribute dishCapacity : Integer;
		part lowerSprayArm : SprayArm;
		part upperSprayArm : SprayArm;
		part filterAssembly : Filter;
	}
	
	part def SprayArm {
		attribute nozzleCount : Integer;
		attribute rotationSpeed : Real;
		attribute sprayPressure : WaterPressure;
	}
	
	part def Filter {
		attribute meshSize : Real;
		attribute clogLevel : Real;
	}
	
	part def HeatingElement {
		port powerIn : PowerPort;
		attribute ratedPower : PowerConsumption;
		attribute targetTemperature : WaterTemperature;
		attribute isActive : Boolean;
	}
	
	part def CirculationPump {
		port powerIn : PowerPort;
		attribute flowRate : Real;
		attribute pressure : WaterPressure;
		attribute isRunning : Boolean;
	}
	
	part def DrainPump {
		port powerIn : PowerPort;
		port wasteIn;
		port drainOut : DrainPort;
		attribute flowRate : Real;
		attribute isRunning : Boolean;
	}
	
	part def DetergentDispenser {
		attribute podLoaded : Boolean;
		attribute dispensed : Boolean;
		attribute releaseTime : DurationValue;
	}
	
	part def DoorLatch {
		attribute isClosed : Boolean;
		attribute isLocked : Boolean;
	}
	
	part def TemperatureSensor {
		attribute measuredTemp : WaterTemperature;
		attribute accuracy : Real;
	}
	
	part def WaterLevelSensor {
		attribute measuredLevel : WaterVolume;
		attribute threshold : WaterVolume;
	}
	
	part def ControlModule {
		port userInterface : UserControlPort;
		attribute selectedProgram : Integer;
		attribute currentPhase : Integer;
		attribute cycleActive : Boolean;
		attribute errorCode : Integer;
	}
	
	action def FillChamber {
		in targetVolume : WaterVolume;
		out actualVolume : WaterVolume;
		out fillComplete : Boolean;
	}
	
	action def HeatWater {
		in currentTemp : WaterTemperature;
		in targetTemp : WaterTemperature;
		out finalTemp : WaterTemperature;
		out heatingComplete : Boolean;
	}
	
	action def ReleaseDetergent {
		in pod : DetergentPod;
		out detergentDispensed : Boolean;
	}
	
	action def CirculateAndSpray {
		in waterTemp : WaterTemperature;
		in duration : WashDuration;
		in pressure : WaterPressure;
		out washEffectiveness : Real;
	}
	
	action def DrainChamber {
		in currentVolume : WaterVolume;
		out drainComplete : Boolean;
	}
	
	action def PerformDryingCycle {
		in duration : WashDuration;
		out moistureLevel : Real;
	}
	
	action def CompleteDishwashingCycle {
		in dirtyLoad : DirtyDishes;
		in detergent : DetergentPod;
		in programSelection : Integer;
		out cleanLoad : CleanDishes;
		
		first start;
		
		then action verifyDoorClosed {
			out doorSecure : Boolean;
		}
		
		then decide;
			if verifyDoorClosed.doorSecure then lockDoorAction;
			if not verifyDoorClosed.doorSecure then abortCycleAction;
		
		action lockDoorAction {
			out locked : Boolean;
		}
		then prewashFill;
		
		action abortCycleAction;
		then done;
		
		action prewashFill : FillChamber {
			out actualVolume;
			out fillComplete;
		}
		
		then action prewashSpray : CirculateAndSpray {
			out washEffectiveness;
		}
		
		then action prewashDrain : DrainChamber {
			in currentVolume = prewashFill.actualVolume;
			out drainComplete;
		}
		
		then action mainWashFill : FillChamber {
			out actualVolume;
			out fillComplete;
		}
		
		then action mainWashHeat : HeatWater {
			out finalTemp;
			out heatingComplete;
		}
		
		then action dispenseDetergent : ReleaseDetergent {
			in pod = detergent;
			out detergentDispensed;
		}
		
		then action mainWashSpray : CirculateAndSpray {
			in waterTemp = mainWashHeat.finalTemp;
			out washEffectiveness;
		}
		
		then action mainWashDrain : DrainChamber {
			in currentVolume = mainWashFill.actualVolume;
			out drainComplete;
		}
		
		then action rinseFill : FillChamber {
			out actualVolume;
			out fillComplete;
		}
		
		then action rinseHeat : HeatWater {
			out finalTemp;
			out heatingComplete;
		}
		
		then action rinseSpray : CirculateAndSpray {
			in waterTemp = rinseHeat.finalTemp;
			out washEffectiveness;
		}
		
		then action finalDrain : DrainChamber {
			in currentVolume = rinseFill.actualVolume;
			out drainComplete;
		}
		
		then action dryingPhase : PerformDryingCycle {
			out moistureLevel;
		}
		
		then action unlockDoor {
			out unlocked : Boolean;
		}
		
		then done;
	}
	
	state def DishwasherOperationalStates {
		entry; then idle;
		
		state idle {
			entry assign controlModule.cycleActive := false;
			entry assign controlModule.currentPhase := 0;
		}
		
		transition idle_to_prewash
			first idle
			accept startCommand
			if doorLatch.isClosed
			then prewash;
		
		state prewash {
			entry assign controlModule.currentPhase := 1;
			do action prewashAction : CirculateAndSpray;
		}
		
		transition prewash_to_mainwash
			first prewash
			if prewashComplete
			then mainwash;
		
		state mainwash {
			entry assign controlModule.currentPhase := 2;
			do action mainwashAction : CirculateAndSpray;
		}
		
		transition mainwash_to_rinse
			first mainwash
			if mainwashComplete
			then rinse;
		
		state rinse {
			entry assign controlModule.currentPhase := 3;
			do action rinseAction : CirculateAndSpray;
		}
		
		transition rinse_to_drying
			first rinse
			if rinseComplete
			then drying;
		
		state drying {
			entry assign controlModule.currentPhase := 4;
			do action dryingAction : PerformDryingCycle;
		}
		
		transition drying_to_complete
			first drying
			if dryingComplete
			then complete;
		
		state complete {
			entry assign controlModule.currentPhase := 5;
			entry assign controlModule.cycleActive := false;
		}
		
		transition complete_to_idle
			first complete
			accept userAcknowledge
			then idle;
	}
	
	part def Dishwasher {
		port waterSupply : WaterSupplyPort;
		port drain : DrainPort;
		port powerSupply : PowerPort;
		port userControl : UserControlPort;
		
		part controlModule : ControlModule;
		part chamber : WashChamber;
		part inletValve : WaterInletValve;
		part heater : HeatingElement;
		part circulationPump : CirculationPump;
		part drainPump : DrainPump;
		part dispenser : DetergentDispenser;
		part doorLatch : DoorLatch;
		part tempSensor : TemperatureSensor;
		part levelSensor : WaterLevelSensor;
		
		perform action dishwashingCycle[*] ordered references CompleteDishwashingCycle {
			in attribute loadedDishes : DirtyDishes;
			in attribute detergentPod : DetergentPod;
			in attribute program : Integer;
			out attribute cleanedDishes : CleanDishes;
		}
		
		exhibit state operationalStates : DishwasherOperationalStates;
		
		connection waterSupplyConnection connect waterSupply to inletValve.waterSupply;
		connection valveToChambConnection connect inletValve.waterOut to chamber;
		connection chamberToPumpConnection connect chamber to circulationPump;
		connection chamberToDrainConnection connect chamber to drainPump.wasteIn;
		connection drainToDrainPortConnection connect drainPump.drainOut to drain;
		connection powerToValveConnection connect powerSupply to inletValve.powerIn;
		connection powerToHeaterConnection connect powerSupply to heater.powerIn;
		connection powerToCircPumpConnection connect powerSupply to circulationPump.powerIn;
		connection powerToDrainPumpConnection connect powerSupply to drainPump.powerIn;
		connection userToControlConnection connect userControl to controlModule.userInterface;
	}
	
	part dishwasher : Dishwasher {
		perform action cleanDishes[*] ordered references dishwashingCycle;
		
		part :>> controlModule {
			perform cleanDishes.verifyDoorClosed;
			perform cleanDishes.lockDoorAction;
			perform cleanDishes.unlockDoor;
		}
		
		part :>> inletValve {
			perform cleanDishes.prewashFill;
			perform cleanDishes.mainWashFill;
			perform cleanDishes.rinseFill;
		}
		
		part :>> heater {
			perform cleanDishes.mainWashHeat;
			perform cleanDishes.rinseHeat;
		}
		
		part :>> dispenser {
			perform cleanDishes.dispenseDetergent;
		}
		
		part :>> circulationPump {
			perform cleanDishes.prewashSpray;
			perform cleanDishes.mainWashSpray;
			perform cleanDishes.rinseSpray;
		}
		
		part :>> drainPump {
			perform cleanDishes.prewashDrain;
			perform cleanDishes.mainWashDrain;
			perform cleanDishes.finalDrain;
		}
		
		part :>> chamber {
			perform cleanDishes.dryingPhase;
		}
	}
	
	requirement def CleaningPerformanceRequirement {
		doc /* The dishwasher shall remove at least 98% of food soil from dishes during a complete wash cycle. */
		
		subject dishwasher : Dishwasher;
		
		require constraint {
			dishwasher.dishwashingCycle.cleanedDishes.residualSoil <= 0.02
		}
	}
	
	requirement def WaterEfficiencyRequirement {
		doc /* The dishwasher shall use no more than 12 liters of water per standard wash cycle. */
		
		subject dishwasher : Dishwasher;
	}
	
	requirement def TemperatureRequirement {
		doc /* The dishwasher shall achieve a minimum rinse temperature of 65 degrees Celsius for sanitization. */
		
		subject dishwasher : Dishwasher;
	}
	
	requirement def SafetyRequirement {
		doc /* The dishwasher door shall remain locked during all water-containing phases of operation. */
		
		subject dishwasher : Dishwasher;
	}
	
	requirement def PrimaryFunctionRequirement {
		doc /* The dishwasher shall automatically clean loaded dishes by washing, rinsing, and drying them through controlled application of heated water, detergent, and mechanical spray action. */
		
		subject dishwasher : Dishwasher;
		
		require cleaningPerformance : CleaningPerformanceRequirement;
		require waterEfficiency : WaterEfficiencyRequirement;
		require temperatureControl : TemperatureRequirement;
		require safety : SafetyRequirement;
	}
}
