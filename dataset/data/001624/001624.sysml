package WashingMachineSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def WaterTemperature :> TemperatureValue;
	attribute def WaterVolume :> VolumeValue;
	attribute def RotationSpeed :> AngularVelocityValue;
	attribute def WashDuration :> DurationValue;
	attribute def LoadMass :> MassValue;
	
	item def FreshWater {
		attribute temperature : WaterTemperature;
		attribute volume : WaterVolume;
	}
	
	item def WasteWater {
		attribute temperature : WaterTemperature;
		attribute volume : WaterVolume;
	}
	
	item def Detergent {
		attribute amount : Real;
	}
	
	item def DirtyLaundry {
		attribute mass : LoadMass;
	}
	
	item def CleanLaundry {
		attribute mass : LoadMass;
	}
	
	port def WaterSupplyPort {
		out item freshWater : FreshWater;
		attribute pressure : PressureValue;
	}
	
	port def WaterIntakePort {
		in item freshWater : FreshWater;
	}
	
	port def DrainPort {
		out item wasteWater : WasteWater;
	}
	
	port def SewerPort {
		in item wasteWater : WasteWater;
	}
	
	port def PowerPort {
		attribute voltage : Real;
		attribute current : Real;
	}
	
	part def WaterInletValve {
		port inlet : WaterIntakePort;
		attribute isOpen : Boolean;
	}
	
	part def DrumAssembly {
		attribute currentSpeed : RotationSpeed;
		attribute capacity : LoadMass;
		in item laundryIn : DirtyLaundry;
		out item laundryOut : CleanLaundry;
	}
	
	part def DriveMotor {
		port power : PowerPort;
		attribute targetSpeed : RotationSpeed;
		attribute actualSpeed : RotationSpeed;
	}
	
	part def DrainPump {
		port power : PowerPort;
		attribute isRunning : Boolean;
	}
	
	part def WaterHeater {
		port power : PowerPort;
		attribute targetTemperature : WaterTemperature;
		attribute currentTemperature : WaterTemperature;
	}
	
	part def WaterLevelSensor {
		attribute measuredLevel : WaterVolume;
	}
	
	part def TemperatureSensor {
		attribute measuredTemperature : WaterTemperature;
	}
	
	part def ControlModule {
		attribute selectedProgram : WashProgram;
		attribute currentState : CycleState;
	}
	
	part def DoorLock {
		attribute isLocked : Boolean;
	}
	
	enum def WashProgram {
		enum cottonHeavy;
		enum cottonNormal;
		enum synthetic;
		enum delicate;
		enum quickWash;
		enum rinseAndSpin;
	}
	
	enum def CycleState {
		enum idle;
		enum doorLocked;
		enum filling;
		enum heating;
		enum mainWash;
		enum draining;
		enum rinsing;
		enum spinning;
		enum completed;
	}
	
	action def LockDoor {
		comment /* Engage door lock mechanism for safety during operation. */
	}
	
	action def UnlockDoor {
		comment /* Release door lock mechanism after cycle completion. */
	}
	
	action def FillWater {
		in targetVolume : WaterVolume;
		out actualVolume : WaterVolume;
		comment /* Open inlet valve and fill drum to specified water level. */
	}
	
	action def HeatWater {
		in targetTemp : WaterTemperature;
		in currentTemp : WaterTemperature;
		out finalTemp : WaterTemperature;
		comment /* Activate heater to raise water temperature to target. */
	}
	
	action def AddDetergent {
		in detergentAmount : Real;
		comment /* Dispense detergent into drum during fill cycle. */
	}
	
	action def RotateDrum {
		in speed : RotationSpeed;
		in duration : WashDuration;
		comment /* Rotate drum at specified speed for specified duration. */
	}
	
	action def DrainWater {
		comment /* Activate drain pump to empty water from drum. */
	}
	
	action def MainWashCycle {
		first start;
		then action lockDoorAction : LockDoor;
		then action fillMainWash : FillWater;
		then action addDetergentAction : AddDetergent;
		then action heatMainWash : HeatWater;
		then action agitateWash : RotateDrum;
		then action drainMainWash : DrainWater;
		then done;
	}
	
	action def RinseCycle {
		first start;
		then action fillRinse : FillWater;
		then action agitateRinse : RotateDrum;
		then action drainRinse : DrainWater;
		then done;
	}
	
	action def SpinCycle {
		in spinSpeed : RotationSpeed;
		in spinDuration : WashDuration;
		first start;
		then action accelerateSpin : RotateDrum;
		then action finalDrain : DrainWater;
		then done;
	}
	
	action def CompleteWashCycle {
		in program : WashProgram;
		in laundryLoad : DirtyLaundry;
		out cleanLoad : CleanLaundry;
		
		first start;
		then merge programSelection;
		then decide;
			if program == WashProgram::cottonHeavy then cottonHeavyWash;
			if program == WashProgram::cottonNormal then cottonNormalWash;
			if program == WashProgram::synthetic then syntheticWash;
			if program == WashProgram::delicate then delicateWash;
			if program == WashProgram::quickWash then quickWashSequence;
			if program == WashProgram::rinseAndSpin then rinseSpinOnly;
		
		action cottonHeavyWash {
			first action mainWash : MainWashCycle;
			then action rinse1 : RinseCycle;
			then action rinse2 : RinseCycle;
			then action rinse3 : RinseCycle;
			then action finalSpin : SpinCycle;
		}
		
		action cottonNormalWash {
			first action mainWash : MainWashCycle;
			then action rinse1 : RinseCycle;
			then action rinse2 : RinseCycle;
			then action finalSpin : SpinCycle;
		}
		
		action syntheticWash {
			first action lockDoor : LockDoor;
			then action fillSynthetic : FillWater;
			then action addDetergent : AddDetergent;
			then action heatSynthetic : HeatWater;
			then action agitateSynthetic : RotateDrum;
			then action drainSynthetic : DrainWater;
			then action rinseSynthetic : RinseCycle;
			then action spinSynthetic : SpinCycle;
		}
		
		action delicateWash {
			first action lockDoor : LockDoor;
			then action fillDelicate : FillWater;
			then action addDetergent : AddDetergent;
			then action agitateDelicate : RotateDrum;
			then action drainDelicate : DrainWater;
			then action rinseDelicate : RinseCycle;
			then action spinDelicate : SpinCycle;
		}
		
		action quickWashSequence {
			first action lockDoor : LockDoor;
			then action fillQuick : FillWater;
			then action addDetergent : AddDetergent;
			then action agitateQuick : RotateDrum;
			then action drainQuick : DrainWater;
			then action spinQuick : SpinCycle;
		}
		
		action rinseSpinOnly {
			first action lockDoor : LockDoor;
			then action rinseOnly : RinseCycle;
			then action spinOnly : SpinCycle;
		}
		
		then merge cycleComplete;
		then action unlockDoorAction : UnlockDoor;
		then done;
	}
	
	state def WashingMachineStateMachine {
		entry; then idle;
		
		state idle {
			entry assign currentState = CycleState::idle;
		}
		accept at idle then doorLocked
			when StartButtonPressed;
		
		state doorLocked {
			entry assign currentState = CycleState::doorLocked;
			do action lockAction : LockDoor;
		}
		transition doorLocked_to_filling
			first doorLocked then filling
			if doorSecured;
		
		state filling {
			entry assign currentState = CycleState::filling;
			do action fillAction : FillWater;
		}
		transition filling_to_heating
			first filling then heating
			if waterLevelReached;
		
		state heating {
			entry assign currentState = CycleState::heating;
			do action heatAction : HeatWater;
		}
		transition heating_to_mainWash
			first heating then mainWash
			if temperatureReached;
		
		state mainWash {
			entry assign currentState = CycleState::mainWash;
			do action washAction : RotateDrum;
		}
		transition mainWash_to_draining
			first mainWash then draining
			if washTimeComplete;
		
		state draining {
			entry assign currentState = CycleState::draining;
			do action drainAction : DrainWater;
		}
		transition draining_to_rinsing
			first draining then rinsing
			if waterDrained;
		
		state rinsing {
			entry assign currentState = CycleState::rinsing;
			do action rinseAction : RinseCycle;
		}
		transition rinsing_to_spinning
			first rinsing then spinning
			if rinseComplete;
		
		state spinning {
			entry assign currentState = CycleState::spinning;
			do action spinAction : SpinCycle;
		}
		transition spinning_to_completed
			first spinning then completed
			if spinComplete;
		
		state completed {
			entry assign currentState = CycleState::completed;
			do action unlockAction : UnlockDoor;
		}
		transition completed_to_idle
			first completed then idle
			if doorOpened;
		
		attribute currentState : CycleState;
	}
	
	part def WashingMachine {
		port waterInlet : WaterIntakePort;
		port waterDrain : DrainPort;
		port powerSupply : PowerPort;
		
		part controlModule : ControlModule;
		part drum : DrumAssembly;
		part motor : DriveMotor;
		part heater : WaterHeater;
		part pump : DrainPump;
		part inletValve : WaterInletValve;
		part waterLevelSensor : WaterLevelSensor;
		part temperatureSensor : TemperatureSensor;
		part doorLock : DoorLock;
		
		connect inletValve.inlet to waterInlet;
		connect pump to waterDrain;
		connect motor.power to powerSupply;
		connect heater.power to powerSupply;
		connect pump.power to powerSupply;
		
		attribute maxLoadCapacity : LoadMass;
		attribute energyRating : String;
		attribute waterConsumptionPerCycle : WaterVolume;
	}
	
	part washingMachineSystem {
		part machine : WashingMachine {
			perform action washOperation[*] ordered references CompleteWashCycle;
			
			part :>> controlModule {
				perform washOperation;
			}
			
			part :>> drum {
				perform washOperation.cottonHeavyWash.mainWash.agitateWash;
				perform washOperation.cottonNormalWash.mainWash.agitateWash;
			}
			
			part :>> motor {
				perform washOperation.cottonHeavyWash.finalSpin.accelerateSpin;
			}
			
			part :>> heater {
				perform washOperation.cottonHeavyWash.mainWash.heatMainWash;
			}
			
			part :>> pump {
				perform washOperation.cottonHeavyWash.mainWash.drainMainWash;
			}
		}
		
		part waterSupply {
			port supply : WaterSupplyPort;
		}
		
		part sewerSystem {
			port drain : SewerPort;
		}
		
		part electricalGrid {
			port power : PowerPort;
		}
		
		connect waterSupply.supply to machine.waterInlet;
		connect machine.waterDrain to sewerSystem.drain;
		connect electricalGrid.power to machine.powerSupply;
	}
	
	requirement <'WM-REQ-001'> primaryFunction {
		doc /* The washing machine shall automatically clean laundry by executing a complete wash cycle consisting of filling, washing, rinsing, and spinning phases. */
		subject washingMachineSystem.machine;
	}
	
	requirement <'WM-REQ-002'> waterEfficiency {
		doc /* The washing machine shall consume no more than 50 liters of water per standard cotton wash cycle. */
		subject washingMachineSystem.machine;
	}
	
	requirement <'WM-REQ-003'> safetyInterlock {
		doc /* The washing machine door shall remain locked whenever the drum is rotating or contains water. */
		subject washingMachineSystem.machine.doorLock;
	}
	
	requirement <'WM-REQ-004'> temperatureControl {
		doc /* The washing machine shall heat water to the target temperature within 5 degrees Celsius accuracy. */
		subject washingMachineSystem.machine.heater;
	}
	
	requirement <'WM-REQ-005'> loadCapacity {
		doc /* The washing machine shall accommodate a maximum load of 8 kg of dry laundry. */
		subject washingMachineSystem.machine.drum;
	}
	
	requirement washingMachineSystemRequirements {
		doc /* Top-level requirements for the washing machine system. */
		subject washingMachineSystem;
		require primaryFunction;
		require waterEfficiency;
		require safetyInterlock;
		require temperatureControl;
		require loadCapacity;
	}
}
