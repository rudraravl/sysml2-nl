package 'Miele Dishwasher System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def WashProgramType;
	attribute def DoorState;
	attribute def RackPosition;
	attribute def DetergentType;
	
	enum def WashProgramEnum {
		eco;
		intensive;
		quickWash;
		delicate;
		autoSense;
	}
	
	enum def DoorStateEnum {
		open;
		closed;
		locked;
	}
	
	item def Dishes {
		attribute quantity : Integer;
		attribute soilLevel : Real;
		attribute material : String;
	}
	
	item def Water {
		attribute volume :> ISQ::volume;
		attribute temperature :> ISQ::thermodynamicTemperature;
		attribute pressure :> ISQ::pressure;
	}
	
	item def Detergent {
		attribute amount :> ISQ::mass;
		attribute detergentType : DetergentType;
	}
	
	item def WasteWater {
		attribute volume :> ISQ::volume;
		attribute contaminantLevel : Real;
	}
	
	port def WaterSupplyPort {
		in item freshWater : Water;
	}
	
	port def DrainPort {
		out item wasteWater : WasteWater;
	}
	
	port def PowerSupplyPort {
		in attribute voltage :> ISQ::electricPotentialDifference;
		in attribute current :> ISQ::electricCurrent;
		in attribute power :> ISQ::power;
	}
	
	port def UserInterfacePort {
		in attribute programSelection : WashProgramEnum;
		in attribute startSignal : Boolean;
		out attribute cycleStatus : Real;
		out attribute remainingTime :> ISQ::time;
		out attribute errorCode : Integer;
	}
	
	part def WaterInletValve {
		port supplyIn : WaterSupplyPort;
		port waterOut : WaterSupplyPort;
		attribute flowRate :> ISQ::volumeFlowRate;
		attribute isOpen : Boolean;
		
		action controlInletFlow {
			in openCommand : Boolean;
			in targetFlow :> ISQ::volumeFlowRate;
			out actualFlow :> ISQ::volumeFlowRate;
		}
	}
	
	part def WaterSoftener {
		port waterIn : WaterSupplyPort;
		port waterOut : WaterSupplyPort;
		attribute saltLevel :> ISQ::mass;
		attribute hardnessReduction : Real;
		
		action softenWater {
			in hardWater : Water;
			out softWater : Water;
		}
	}
	
	part def HeatingSystem {
		attribute targetTemperature :> ISQ::thermodynamicTemperature;
		attribute currentTemperature :> ISQ::thermodynamicTemperature;
		attribute heatingPower :> ISQ::power;
		
		action heatWater {
			in waterVolume :> ISQ::volume;
			in desiredTemp :> ISQ::thermodynamicTemperature;
			out heatedWater : Water;
			out energyConsumed :> ISQ::energy;
		}
	}
	
	part def CirculationPump {
		attribute pumpSpeed :> ISQ::frequency;
		attribute flowRate :> ISQ::volumeFlowRate;
		attribute pressure :> ISQ::pressure;
		
		action circulateWater {
			in waterVolume :> ISQ::volume;
			in targetPressure :> ISQ::pressure;
			out sprayPressure :> ISQ::pressure;
		}
	}
	
	part def SprayArmAssembly {
		attribute rotationSpeed :> ISQ::angularVelocity;
		attribute numberOfNozzles : Integer;
		attribute sprayPattern : String;
		
		action sprayDishes {
			in waterPressure :> ISQ::pressure;
			in waterTemp :> ISQ::thermodynamicTemperature;
			out cleaningCoverage : Real;
		}
	}
	
	part def DetergentDispenser {
		attribute mainCompartmentCapacity :> ISQ::volume;
		attribute rinseAidCapacity :> ISQ::volume;
		item detergent : Detergent;
		
		action dispenseDetergent {
			in washPhase : Integer;
			in waterTemp :> ISQ::thermodynamicTemperature;
			out dispensedAmount :> ISQ::mass;
		}
	}
	
	part def DrainPump {
		port drainIn : DrainPort;
		port drainOut : DrainPort;
		attribute pumpCapacity :> ISQ::volumeFlowRate;
		attribute filterStatus : Real;
		
		action drainWater {
			in wasteVolume :> ISQ::volume;
			out drainDuration :> ISQ::time;
		}
	}
	
	part def DoorLockMechanism {
		attribute lockState : DoorStateEnum;
		attribute safetyInterlock : Boolean;
		
		action controlDoorLock {
			in lockCommand : Boolean;
			in cycleActive : Boolean;
			out currentState : DoorStateEnum;
		}
	}
	
	part def DishRacks {
		attribute upperRackPosition : RackPosition;
		attribute lowerRackCapacity : Integer;
		attribute cutleryBasketPresent : Boolean;
		item loadedDishes : Dishes[*];
		
		action loadDishes {
			in dishItems : Dishes[*];
			out rackUtilization : Real;
		}
	}
	
	part def ControlModule {
		port userInterface : UserInterfacePort;
		attribute selectedProgram : WashProgramEnum;
		attribute cyclePhase : Integer;
		attribute sensorData : Real[*];
		
		action manageCycle {
			in programType : WashProgramEnum;
			in dishLoad : Integer;
			out washDuration :> ISQ::time;
			out waterTemp :> ISQ::thermodynamicTemperature;
			out waterVolume :> ISQ::volume;
		}
	}
	
	part def TurbiditySensor {
		attribute measuredTurbidity : Real;
		
		action measureWaterClarity {
			out turbidityLevel : Real;
		}
	}
	
	part def TemperatureSensor {
		attribute measuredTemp :> ISQ::thermodynamicTemperature;
		
		action measureTemperature {
			out temperature :> ISQ::thermodynamicTemperature;
		}
	}
	
	part def WaterLevelSensor {
		attribute measuredLevel :> ISQ::length;
		
		action measureLevel {
			out waterLevel :> ISQ::length;
		}
	}
	
	action def FillWaterAction {
		in targetVolume :> ISQ::volume;
		in targetTemp :> ISQ::thermodynamicTemperature;
		out actualVolume :> ISQ::volume;
		out fillTime :> ISQ::time;
	}
	
	action def PreWashAction {
		in waterVolume :> ISQ::volume;
		in duration :> ISQ::time;
		out prewashEfficiency : Real;
	}
	
	action def MainWashAction {
		in waterVolume :> ISQ::volume;
		in waterTemp :> ISQ::thermodynamicTemperature;
		in detergentAmount :> ISQ::mass;
		in duration :> ISQ::time;
		out cleaningEfficiency : Real;
	}
	
	action def RinseAction {
		in rinseCount : Integer;
		in waterTemp :> ISQ::thermodynamicTemperature;
		out detergentResidual : Real;
	}
	
	action def DryAction {
		in dryingMethod : String;
		in duration :> ISQ::time;
		out moistureLevel : Real;
	}
	
	action def DrainAction {
		in wasteVolume :> ISQ::volume;
		out drainComplete : Boolean;
	}
	
	action def CompleteDishwashCycle {
		in programType : WashProgramEnum;
		in dishQuantity : Integer;
		out cleanDishes : Dishes[*];
		
		first start;
		
		then action lockDoor {
			in lockCommand = true;
			in cycleActive = true;
			out currentState : DoorStateEnum;
		}
		
		then action prewashFill : FillWaterAction {
			in targetVolume = 4.0 [SI::L];
			in targetTemp = 313.15 [SI::K];
			out actualVolume;
			out fillTime;
		}
		
		then action prewashCycle : PreWashAction {
			in waterVolume = prewashFill.actualVolume;
			in duration = 300.0 [SI::s];
			out prewashEfficiency;
		}
		
		then action drainPrewash : DrainAction {
			in wasteVolume = prewashFill.actualVolume;
			out drainComplete;
		}
		
		then action mainWashFill : FillWaterAction {
			in targetVolume = 8.0 [SI::L];
			in targetTemp = 333.15 [SI::K];
			out actualVolume;
			out fillTime;
		}
		
		then action dispenseDetergent {
			in washPhase = 1;
			in waterTemp = 333.15 [SI::K];
			out dispensedAmount : ISQ::MassValue;
		}
		
		then action mainWash : MainWashAction {
			in waterVolume = mainWashFill.actualVolume;
			in waterTemp = 333.15 [SI::K];
			in detergentAmount = dispenseDetergent.dispensedAmount;
			in duration = 2400.0 [SI::s];
			out cleaningEfficiency;
		}
		
		then action drainMainWash : DrainAction {
			in wasteVolume = mainWashFill.actualVolume;
			out drainComplete;
		}
		
		then action rinsePhase : RinseAction {
			in rinseCount = 3;
			in waterTemp = 343.15 [SI::K];
			out detergentResidual;
		}
		
		then action finalDrain : DrainAction {
			in wasteVolume = 8.0 [SI::L];
			out drainComplete;
		}
		
		then action dryingPhase : DryAction {
			in dryingMethod = "condensation";
			in duration = 1800.0 [SI::s];
			out moistureLevel;
		}
		
		then action unlockDoor {
			in lockCommand = false;
			in cycleActive = false;
			out currentState : DoorStateEnum;
		}
		
		then done;
	}
	
	part def Dishwasher {
		attribute modelNumber : String;
		attribute energyRating : String;
		attribute placeSettings : Integer;
		attribute waterConsumptionPerCycle :> ISQ::volume;
		attribute noiseLevel :> ISQ::soundPressureLevel;
	}
	
	part mieleDishwasher : Dishwasher {
		doc /* Miele G7000 Series Dishwasher System */
		
		attribute modelNumber = "G7310";
		attribute energyRating = "A+++";
		attribute placeSettings = 14;
		attribute waterConsumptionPerCycle = 9.0 [SI::L];
		
		part inletValve : WaterInletValve;
		part softener : WaterSoftener;
		part heater : HeatingSystem;
		part pump : CirculationPump;
		part upperSprayArm : SprayArmAssembly;
		part lowerSprayArm : SprayArmAssembly;
		part dispenser : DetergentDispenser;
		part drainPump : DrainPump;
		part doorLock : DoorLockMechanism;
		part racks : DishRacks;
		part controller : ControlModule;
		part turbiditySensor : TurbiditySensor;
		part tempSensor : TemperatureSensor;
		part levelSensor : WaterLevelSensor;
		
		port waterSupply : WaterSupplyPort;
		port drainConnection : DrainPort;
		port powerConnection : PowerSupplyPort;
		port userPanel : UserInterfacePort;
		
		connection waterInletConnection connect waterSupply to inletValve.supplyIn;
		connection softenerConnection connect inletValve.waterOut to softener.waterIn;
		
		perform action dishwashingOperation[*] ordered : CompleteDishwashCycle {
			in programType = controller.selectedProgram;
			in dishQuantity = racks.lowerRackCapacity;
			out cleanDishes;
		}
	}
	
	requirement def CleaningPerformanceRequirement {
		doc /* The dishwasher shall effectively clean and sanitize dishes while optimizing resource consumption. */
		
		subject dishwasherSystem : Dishwasher;
		
		require constraint cleaningEffectiveness {
			doc /* Cleaning performance shall achieve at least 98% soil removal on standard test loads. */
		}
		
		require constraint sanitizationStandard {
			doc /* Final rinse temperature shall reach at least 65°C to ensure proper sanitization. */
		}
		
		require constraint waterEfficiency {
			doc /* Water consumption shall not exceed 10 liters per standard wash cycle. */
		}
		
		require constraint energyEfficiency {
			doc /* Energy consumption shall achieve A+++ rating per EU energy label standards. */
		}
	}
	
	requirement def OperationalSafetyRequirement {
		doc /* The dishwasher shall operate safely under all normal and fault conditions. */
		
		subject dishwasherSystem : Dishwasher;
		
		require constraint doorLockSafety {
			doc /* Door shall remain locked during all wash phases when water is present or temperature exceeds 50°C. */
		}
		
		require constraint leakProtection {
			doc /* System shall detect water leaks and shut off water supply within 2 seconds. */
		}
		
		require constraint thermalSafety {
			doc /* Water temperature shall not exceed 75°C to prevent scalding and component damage. */
		}
		
		require constraint electricalSafety {
			doc /* All electrical components shall be protected to IP rating IPX4 minimum. */
		}
	}
	
	requirement def UserExperienceRequirement {
		doc /* The dishwasher shall provide convenient and quiet operation. */
		
		subject dishwasherSystem : Dishwasher;
		
		require constraint noiseLevel {
			doc /* Operating noise shall not exceed 44 dB(A) during normal wash cycles. */
		}
		
		require constraint cycleFlexibility {
			doc /* System shall offer at least 5 distinct wash programs for different dish types and soil levels. */
		}
		
		require constraint loadCapacity {
			doc /* Dishwasher shall accommodate at least 14 place settings per IEC 60436 standard. */
		}
	}
	
	requirement <'REQ-DW-001'> primaryDishwashingFunction {
		doc /* The Miele dishwasher system shall automatically clean and sanitize dishes by executing a complete wash cycle that includes pre-wash, main wash with detergent, multiple rinse phases, and drying, all performed in proper sequence with optimized water and energy consumption. */
		
		subject dishwasherSystem : Dishwasher = mieleDishwasher;
		
		assume constraint validDishLoad {
			doc /* Dishes are properly loaded within rated capacity and door is securely closed. */
		}
		
		assume constraint utilitySupply {
			doc /* Water supply pressure is between 0.3 and 10 bar and electrical supply is 220-240V AC. */
		}
		
		require cleaningPerformance : CleaningPerformanceRequirement {
			redefines subject = mieleDishwasher;
		}
		
		require operationalSafety : OperationalSafetyRequirement {
			redefines subject = mieleDishwasher;
		}
		
		require userExperience : UserExperienceRequirement {
			redefines subject = mieleDishwasher;
		}
	}
	
	state machine def DishwasherStateMachine {
		entry; then idle;
		
		state idle {
			entry assign controller.cyclePhase := 0;
		}
		
		transition idleToFilling
			first idle
			accept userPanel.startSignal
			if doorLock.lockState == DoorStateEnum::closed
			then filling;
		
		state filling;
		
		transition fillingToHeating
			first filling
			if levelSensor.measuredLevel >= 0.05 [SI::m]
			then heating;
		
		state heating;
		
		transition heatingToWashing
			first heating
			then washing;
		
		state washing;
		
		transition washingToDraining
			first washing
			then draining;
		
		state draining;
		
		transition drainingToRinsing
			first draining
			if levelSensor.measuredLevel < 0.01 [SI::m]
			then rinsing;
		
		state rinsing;
		
		transition rinsingToDrying
			first rinsing
			then drying;
		
		state drying;
		
		transition dryingToComplete
			first drying
			then complete;
		
		state complete;
		
		transition completeToIdle
			first complete
			then idle;
	}
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import 'Miele Dishwasher System'::*;

    action orchestrator {
        attribute testTargetVolume : > ISQ::volume;
        attribute testTargetTemp : > ISQ::thermodynamicTemperature;
        action actionProbe : FillWaterAction {
            in targetVolume = testTargetVolume;
            in targetTemp = testTargetTemp;
        }
        first actionProbe;
    }
}
