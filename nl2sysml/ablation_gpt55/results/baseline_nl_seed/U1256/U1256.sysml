package WashingMachinePrimaryFunctionModel {
	import ScalarValues::*;

	attribute def KilogramValue :> Real {
		attribute unitSymbol : String = "kg";
	}

	attribute def LiterValue :> Real {
		attribute unitSymbol : String = "L";
	}

	attribute def DegreeCelsiusValue :> Real {
		attribute unitSymbol : String = "degC";
	}

	attribute def MinuteValue :> Real {
		attribute unitSymbol : String = "min";
	}

	attribute def SecondValue :> Real {
		attribute unitSymbol : String = "s";
	}

	attribute def WattValue :> Real {
		attribute unitSymbol : String = "W";
	}

	attribute def KilowattHourValue :> Real {
		attribute unitSymbol : String = "kWh";
	}

	attribute def RevolutionPerMinuteValue :> Real {
		attribute unitSymbol : String = "r/min";
	}

	attribute def PercentValue :> Real {
		attribute unitSymbol : String = "%";
	}

	attribute def VoltValue :> Real {
		attribute unitSymbol : String = "V";
	}

	attribute def AmpereValue :> Real {
		attribute unitSymbol : String = "A";
	}

	enum def WashProgramKind {
		enum quick;
		enum cotton;
		enum synthetic;
		enum delicate;
		enum rinseAndSpin;
		enum drumClean;
	}

	enum def DoorLockStateKind {
		enum unlocked;
		enum locking;
		enum locked;
		enum unlocking;
		enum faulted;
	}

	enum def CyclePhaseKind {
		enum poweredOff;
		enum standby;
		enum loading;
		enum locked;
		enum filling;
		enum heating;
		enum washing;
		enum draining;
		enum rinsing;
		enum spinning;
		enum complete;
		enum fault;
	}

	enum def MachineFaultKind {
		enum noFault;
		enum doorOpen;
		enum waterFillTimeout;
		enum drainTimeout;
		enum overTemperature;
		enum motorOverload;
		enum imbalance;
		enum leakDetected;
	}

	item def LaundryLoad {
		attribute dryMass : KilogramValue;
		attribute soilLevel : PercentValue;
		attribute moistureContent : PercentValue;
		attribute detergentResidual : PercentValue;
	}

	item def CleanLaundryLoad :> LaundryLoad {
		attribute finalSoilLevel : PercentValue;
		attribute finalMoistureContent : PercentValue;
		attribute finalDetergentResidual : PercentValue;
	}

	item def Water {
		attribute volume : LiterValue;
		attribute temperature : DegreeCelsiusValue;
		attribute hardness : PercentValue;
	}

	item def WasteWater :> Water {
		attribute removedSoilConcentration : PercentValue;
		attribute detergentConcentration : PercentValue;
	}

	item def DetergentDose {
		attribute volume : LiterValue;
		attribute concentration : PercentValue;
	}

	item def ElectricalPower {
		attribute voltage : VoltValue;
		attribute current : AmpereValue;
		attribute activePower : WattValue;
	}

	item def RotationalMotion {
		attribute speed : RevolutionPerMinuteValue;
		attribute torquePercent : PercentValue;
	}

	item def StartCycleCommand {
		attribute selectedProgram : WashProgramKind;
		attribute targetTemperature : DegreeCelsiusValue;
		attribute targetSpinSpeed : RevolutionPerMinuteValue;
	}

	item def PauseCommand {
		attribute requested : Boolean;
	}

	item def CancelCommand {
		attribute requested : Boolean;
	}

	item def CycleStatus {
		attribute phase : CyclePhaseKind;
		attribute remainingTime : MinuteValue;
		attribute doorLockState : DoorLockStateKind;
		attribute activeFault : MachineFaultKind;
	}

	item def ValveCommand {
		attribute openRequested : Boolean;
	}

	item def PumpCommand {
		attribute runRequested : Boolean;
	}

	item def HeaterCommand {
		attribute enableRequested : Boolean;
		attribute targetTemperature : DegreeCelsiusValue;
	}

	item def MotorCommand {
		attribute requestedSpeed : RevolutionPerMinuteValue;
		attribute requestedTorquePercent : PercentValue;
		attribute clockwise : Boolean;
	}

	item def DoorLockCommand {
		attribute lockRequested : Boolean;
	}

	item def LevelMeasurement {
		attribute waterVolumeEstimate : LiterValue;
		attribute tubFullPercent : PercentValue;
	}

	item def TemperatureMeasurement {
		attribute measuredTemperature : DegreeCelsiusValue;
	}

	item def DoorMeasurement {
		attribute closed : Boolean;
		attribute locked : Boolean;
	}

	item def ImbalanceMeasurement {
		attribute imbalancePercent : PercentValue;
	}

	port def WaterInputPort {
		in item water : Water;
	}

	port def WaterOutputPort {
		out item water : Water;
	}

	port def WasteWaterInputPort {
		in item wasteWater : WasteWater;
	}

	port def WasteWaterOutputPort {
		out item wasteWater : WasteWater;
	}

	port def DetergentInputPort {
		in item detergent : DetergentDose;
	}

	port def DetergentOutputPort {
		out item detergent : DetergentDose;
	}

	port def LaundryInputPort {
		in item laundryIn : LaundryLoad;
	}

	port def LaundryOutputPort {
		out item laundryOut : CleanLaundryLoad;
	}

	port def ElectricalPowerInputPort {
		in item power : ElectricalPower;
	}

	port def ElectricalPowerOutputPort {
		out item power : ElectricalPower;
	}

	port def UserCommandPort {
		in item start : StartCycleCommand;
		in item pause : PauseCommand;
		in item cancel : CancelCommand;
		out item status : CycleStatus;
	}

	port def ValveCommandInputPort {
		in item command : ValveCommand;
	}

	port def ValveCommandOutputPort {
		out item command : ValveCommand;
	}

	port def PumpCommandInputPort {
		in item command : PumpCommand;
	}

	port def PumpCommandOutputPort {
		out item command : PumpCommand;
	}

	port def HeaterCommandInputPort {
		in item command : HeaterCommand;
	}

	port def HeaterCommandOutputPort {
		out item command : HeaterCommand;
	}

	port def MotorCommandInputPort {
		in item command : MotorCommand;
	}

	port def MotorCommandOutputPort {
		out item command : MotorCommand;
	}

	port def DoorLockCommandInputPort {
		in item command : DoorLockCommand;
	}

	port def DoorLockCommandOutputPort {
		out item command : DoorLockCommand;
	}

	port def LevelMeasurementOutputPort {
		out item measurement : LevelMeasurement;
	}

	port def LevelMeasurementInputPort {
		in item measurement : LevelMeasurement;
	}

	port def TemperatureMeasurementOutputPort {
		out item measurement : TemperatureMeasurement;
	}

	port def TemperatureMeasurementInputPort {
		in item measurement : TemperatureMeasurement;
	}

	port def DoorMeasurementOutputPort {
		out item measurement : DoorMeasurement;
	}

	port def DoorMeasurementInputPort {
		in item measurement : DoorMeasurement;
	}

	port def ImbalanceMeasurementOutputPort {
		out item measurement : ImbalanceMeasurement;
	}

	port def ImbalanceMeasurementInputPort {
		in item measurement : ImbalanceMeasurement;
	}

	port def RotationalDriveOutputPort {
		out item motion : RotationalMotion;
	}

	port def RotationalDriveInputPort {
		in item motion : RotationalMotion;
	}

	constraint def LoadWithinRatedCapacity {
		in loadMass : KilogramValue;
		in ratedCapacity : KilogramValue;
		constraint { loadMass <= ratedCapacity }
	}

	constraint def CleaningEffectivenessSatisfied {
		in initialSoil : PercentValue;
		in finalSoil : PercentValue;
		in requiredRemoval : PercentValue;
		constraint { initialSoil - finalSoil >= requiredRemoval }
	}

	constraint def SafeWashTemperature {
		in measuredTemperature : DegreeCelsiusValue;
		in maximumAllowedTemperature : DegreeCelsiusValue;
		constraint { measuredTemperature <= maximumAllowedTemperature }
	}

	constraint def WaterConsumptionLimit {
		in consumedWater : LiterValue;
		in maximumWater : LiterValue;
		constraint { consumedWater <= maximumWater }
	}

	constraint def EnergyConsumptionLimit {
		in consumedEnergy : KilowattHourValue;
		in maximumEnergy : KilowattHourValue;
		constraint { consumedEnergy <= maximumEnergy }
	}

	action def ReceiveDirtyLaundry {
		in item dirtyLoad : LaundryLoad;
		out item acceptedLoad : LaundryLoad;
		attribute maximumAcceptedMass : KilogramValue = 8.0;
	}

	action def LockDoorForCycle {
		in item doorState : DoorMeasurement;
		out item lockCommand : DoorLockCommand;
		attribute lockTimeout : SecondValue = 5.0;
	}

	action def FillTub {
		in item suppliedWater : Water;
		out item retainedWater : Water;
		out item valveCommand : ValveCommand;
		attribute targetFillVolume : LiterValue = 52.0;
		attribute maximumFillTime : MinuteValue = 8.0;
	}

	action def DoseDetergent {
		in item detergentDose : DetergentDose;
		out item mixedWashLiquid : Water;
		attribute nominalDetergentVolume : LiterValue = 0.075;
	}

	action def HeatWashWater {
		in item coldWashLiquid : Water;
		out item heatedWashLiquid : Water;
		out item heaterCommand : HeaterCommand;
		attribute normalTargetTemperature : DegreeCelsiusValue = 40.0;
		attribute maximumTemperature : DegreeCelsiusValue = 60.0;
	}

	action def AgitateLaundry {
		in item wetSoiledLoad : LaundryLoad;
		in item washLiquid : Water;
		out item partiallyCleanLoad : LaundryLoad;
		out item motorCommand : MotorCommand;
		attribute tumbleSpeed : RevolutionPerMinuteValue = 55.0;
		attribute washDuration : MinuteValue = 28.0;
	}

	action def DrainTub {
		in item usedWashLiquid : WasteWater;
		out item drainedLiquid : WasteWater;
		out item pumpCommand : PumpCommand;
		attribute maximumDrainTime : MinuteValue = 5.0;
	}

	action def RinseLaundry {
		in item partiallyCleanLoad : LaundryLoad;
		in item rinseWater : Water;
		out item rinsedLoad : LaundryLoad;
		out item rinseWasteWater : WasteWater;
		attribute rinseCount : Integer = 2;
		attribute rinseFillVolume : LiterValue = 38.0;
	}

	action def SpinExtractWater {
		in item rinsedLoad : LaundryLoad;
		out item cleanLoad : CleanLaundryLoad;
		out item extractedWater : WasteWater;
		out item motorCommand : MotorCommand;
		attribute maximumSpinSpeed : RevolutionPerMinuteValue = 1200.0;
		attribute spinDuration : MinuteValue = 10.0;
	}

	action def CleanLaundry {
		in item dirtyLaundry : LaundryLoad;
		in item supplyWater : Water;
		in item detergent : DetergentDose;
		in item electricalPower : ElectricalPower;
		out item cleanLaundry : CleanLaundryLoad;
		out item wasteWater : WasteWater;
		attribute selectedProgram : WashProgramKind = WashProgramKind::cotton;
		attribute targetCleaningEffectiveness : PercentValue = 90.0;
		attribute targetResidualDetergent : PercentValue = 2.0;
		attribute targetFinalMoisture : PercentValue = 55.0;

		action receiveLoad : ReceiveDirtyLaundry;
		action lockDoor : LockDoorForCycle;
		action fill : FillTub;
		action dose : DoseDetergent;
		action heat : HeatWashWater;
		action agitate : AgitateLaundry;
		action drainWash : DrainTub;
		action rinse : RinseLaundry;
		action finalSpin : SpinExtractWater;

		succession s1 first receiveLoad then lockDoor;
		succession s2 first lockDoor then fill;
		succession s3 first fill then dose;
		succession s4 first dose then heat;
		succession s5 first heat then agitate;
		succession s6 first agitate then drainWash;
		succession s7 first drainWash then rinse;
		succession s8 first rinse then finalSpin;
	}

	state def WashingMachineOperatingStates {
		entry; then PoweredOff;

		state PoweredOff;
		state Standby;
		state DoorLocking;
		state Filling;
		state Heating;
		state Washing;
		state DrainingAfterWash;
		state Rinsing;
		state FinalSpinning;
		state Complete;
		state Faulted;

		transition powerApplied first PoweredOff then Standby;
		transition startAccepted first Standby then DoorLocking;
		transition doorLocked first DoorLocking then Filling;
		transition fillLevelReached first Filling then Heating;
		transition washTemperatureReached first Heating then Washing;
		transition washTimeComplete first Washing then DrainingAfterWash;
		transition washWaterDrained first DrainingAfterWash then Rinsing;
		transition rinseComplete first Rinsing then FinalSpinning;
		transition spinComplete first FinalSpinning then Complete;
		transition resetAfterComplete first Complete then Standby;
		transition faultFromFilling first Filling then Faulted;
		transition faultFromHeating first Heating then Faulted;
		transition faultFromWashing first Washing then Faulted;
		transition faultFromSpinning first FinalSpinning then Faulted;
		transition cancelToDrain first Washing then DrainingAfterWash;
	}

	part def WaterInletValve {
		port supply : WaterInputPort;
		port outlet : WaterOutputPort;
		port command : ValveCommandInputPort;
		port power : ElectricalPowerInputPort;
		attribute maximumFlowRate : LiterValue = 10.0;
		attribute normallyClosed : Boolean = true;
	}

	part def DetergentDispenser {
		port detergentIn : DetergentInputPort;
		port detergentOut : DetergentOutputPort;
		attribute dispenserVolume : LiterValue = 0.20;
		attribute flushWaterVolume : LiterValue = 3.0;
	}

	part def Tub {
		port waterIn : WaterInputPort;
		port detergentIn : DetergentInputPort;
		port drainOut : WasteWaterOutputPort;
		attribute usableWaterVolume : LiterValue = 58.0;
		attribute overflowVolume : LiterValue = 64.0;
		attribute maximumTemperature : DegreeCelsiusValue = 70.0;
	}

	part def Drum {
		port laundryIn : LaundryInputPort;
		port laundryOut : LaundryOutputPort;
		port drive : RotationalDriveInputPort;
		attribute ratedLoadMass : KilogramValue = 8.0;
		attribute drumVolume : LiterValue = 62.0;
		attribute maximumSpinSpeed : RevolutionPerMinuteValue = 1200.0;
	}

	part def DriveMotor {
		port command : MotorCommandInputPort;
		port power : ElectricalPowerInputPort;
		port shaft : RotationalDriveOutputPort;
		attribute ratedPower : WattValue = 650.0;
		attribute maximumSpeed : RevolutionPerMinuteValue = 1400.0;
	}

	part def WaterHeater {
		port command : HeaterCommandInputPort;
		port power : ElectricalPowerInputPort;
		attribute ratedPower : WattValue = 1800.0;
		attribute maximumWaterTemperature : DegreeCelsiusValue = 60.0;
	}

	part def DrainPump {
		port inlet : WasteWaterInputPort;
		port outlet : WasteWaterOutputPort;
		port command : PumpCommandInputPort;
		port power : ElectricalPowerInputPort;
		attribute ratedPower : WattValue = 90.0;
		attribute maximumDrainFlow : LiterValue = 18.0;
	}

	part def DoorLock {
		port command : DoorLockCommandInputPort;
		port measurement : DoorMeasurementOutputPort;
		port power : ElectricalPowerInputPort;
		attribute lockTime : SecondValue = 3.0;
		attribute unlockTime : SecondValue = 5.0;
	}

	part def WaterLevelSensor {
		port measurement : LevelMeasurementOutputPort;
		port power : ElectricalPowerInputPort;
		attribute accuracy : LiterValue = 1.0;
	}

	part def TemperatureSensor {
		port measurement : TemperatureMeasurementOutputPort;
		port power : ElectricalPowerInputPort;
		attribute accuracy : DegreeCelsiusValue = 1.5;
	}

	part def ImbalanceSensor {
		port measurement : ImbalanceMeasurementOutputPort;
		port power : ElectricalPowerInputPort;
		attribute tripThreshold : PercentValue = 80.0;
	}

	part def PowerDistributionUnit {
		port supply : ElectricalPowerInputPort;
		port controllerPower : ElectricalPowerOutputPort;
		port valvePower : ElectricalPowerOutputPort;
		port motorPower : ElectricalPowerOutputPort;
		port heaterPower : ElectricalPowerOutputPort;
		port pumpPower : ElectricalPowerOutputPort;
		port sensorPower : ElectricalPowerOutputPort;
		port lockPower : ElectricalPowerOutputPort;
		attribute nominalVoltage : VoltValue = 230.0;
		attribute maximumCurrent : AmpereValue = 10.0;
	}

	part def ElectronicController {
		port user : UserCommandPort;
		port valveCommand : ValveCommandOutputPort;
		port pumpCommand : PumpCommandOutputPort;
		port heaterCommand : HeaterCommandOutputPort;
		port motorCommand : MotorCommandOutputPort;
		port doorLockCommand : DoorLockCommandOutputPort;
		port levelMeasurement : LevelMeasurementInputPort;
		port temperatureMeasurement : TemperatureMeasurementInputPort;
		port doorMeasurement : DoorMeasurementInputPort;
		port imbalanceMeasurement : ImbalanceMeasurementInputPort;
		port power : ElectricalPowerInputPort;

		attribute selectedProgram : WashProgramKind = WashProgramKind::cotton;
		attribute currentPhase : CyclePhaseKind = CyclePhaseKind::standby;
		attribute activeFault : MachineFaultKind = MachineFaultKind::noFault;
		attribute nominalCycleTime : MinuteValue = 65.0;
		attribute maximumCycleTime : MinuteValue = 90.0;

		state operatingStates : WashingMachineOperatingStates;
	}

	part def WashingMachine {
		port waterSupply : WaterInputPort;
		port drain : WasteWaterOutputPort;
		port detergentFill : DetergentInputPort;
		port laundryDoorIn : LaundryInputPort;
		port laundryDoorOut : LaundryOutputPort;
		port mainsPower : ElectricalPowerInputPort;
		port userPanel : UserCommandPort;

		attribute ratedCapacity : KilogramValue = 8.0;
		attribute normalCycleWaterUse : LiterValue = 54.0;
		attribute maximumCycleWaterUse : LiterValue = 65.0;
		attribute normalCycleEnergyUse : KilowattHourValue = 0.85;
		attribute maximumCycleEnergyUse : KilowattHourValue = 1.20;
		attribute normalCycleDuration : MinuteValue = 65.0;
		attribute maximumCycleDuration : MinuteValue = 90.0;
		attribute minimumCleaningEffectiveness : PercentValue = 90.0;
		attribute maximumResidualDetergent : PercentValue = 2.0;
		attribute maximumFinalMoisture : PercentValue = 55.0;
		attribute maximumSafeWaterTemperature : DegreeCelsiusValue = 60.0;

		part powerDistribution : PowerDistributionUnit;
		part inletValve : WaterInletValve;
		part dispenser : DetergentDispenser;
		part tub : Tub;
		part drum : Drum;
		part motor : DriveMotor;
		part heater : WaterHeater;
		part pump : DrainPump;
		part doorLock : DoorLock;
		part levelSensor : WaterLevelSensor;
		part temperatureSensor : TemperatureSensor;
		part imbalanceSensor : ImbalanceSensor;
		part controller : ElectronicController;

		action primaryFunction : CleanLaundry;

		connection externalPower connect mainsPower to powerDistribution.supply;
		connection controllerPower connect powerDistribution.controllerPower to controller.power;
		connection valvePower connect powerDistribution.valvePower to inletValve.power;
		connection motorPower connect powerDistribution.motorPower to motor.power;
		connection heaterPower connect powerDistribution.heaterPower to heater.power;
		connection pumpPower connect powerDistribution.pumpPower to pump.power;
		connection levelSensorPower connect powerDistribution.sensorPower to levelSensor.power;
		connection temperatureSensorPower connect powerDistribution.sensorPower to temperatureSensor.power;
		connection imbalanceSensorPower connect powerDistribution.sensorPower to imbalanceSensor.power;
		connection doorLockPower connect powerDistribution.lockPower to doorLock.power;

		connection userToController connect userPanel to controller.user;

		connection incomingWater connect waterSupply to inletValve.supply;
		connection meteredWater connect inletValve.outlet to tub.waterIn;
		connection detergentLoaded connect detergentFill to dispenser.detergentIn;
		connection detergentToTub connect dispenser.detergentOut to tub.detergentIn;
		connection wasteFromTub connect tub.drainOut to pump.inlet;
		connection wasteToDrain connect pump.outlet to drain;

		connection laundryInput connect laundryDoorIn to drum.laundryIn;
		connection laundryOutput connect drum.laundryOut to laundryDoorOut;
		connection motorToDrum connect motor.shaft to drum.drive;

		connection valveControl connect controller.valveCommand to inletValve.command;
		connection pumpControl connect controller.pumpCommand to pump.command;
		connection heaterControl connect controller.heaterCommand to heater.command;
		connection motorControl connect controller.motorCommand to motor.command;
		connection doorControl connect controller.doorLockCommand to doorLock.command;

		connection levelFeedback connect levelSensor.measurement to controller.levelMeasurement;
		connection temperatureFeedback connect temperatureSensor.measurement to controller.temperatureMeasurement;
		connection doorFeedback connect doorLock.measurement to controller.doorMeasurement;
		connection imbalanceFeedback connect imbalanceSensor.measurement to controller.imbalanceMeasurement;
	}

	requirement def PrimaryWashingFunctionRequirement {
		subject machine : WashingMachine;
		require constraint {
			machine.ratedCapacity >= 8.0 and
			machine.minimumCleaningEffectiveness >= 90.0 and
			machine.maximumResidualDetergent <= 2.0 and
			machine.maximumFinalMoisture <= 55.0
		}
	}

	requirement def CycleResourceRequirement {
		subject machine : WashingMachine;
		require constraint {
			machine.maximumCycleWaterUse <= 65.0 and
			machine.maximumCycleEnergyUse <= 1.20 and
			machine.maximumCycleDuration <= 90.0
		}
	}

	requirement def TemperatureSafetyRequirement {
		subject machine : WashingMachine;
		require constraint {
			machine.maximumSafeWaterTemperature <= 60.0
		}
	}

	requirement def LoadCapacityRequirement {
		subject machine : WashingMachine;
		require constraint {
			machine.ratedCapacity == 8.0
		}
	}

	part washingMachine : WashingMachine;

	requirement primaryFunctionRequirement : PrimaryWashingFunctionRequirement {
		subject machine = washingMachine;
	}

	requirement resourceRequirement : CycleResourceRequirement {
		subject machine = washingMachine;
	}

	requirement temperatureSafetyRequirement : TemperatureSafetyRequirement {
		subject machine = washingMachine;
	}

	requirement loadCapacityRequirement : LoadCapacityRequirement {
		subject machine = washingMachine;
	}

	satisfy primaryFunctionRequirement by washingMachine;
	satisfy resourceRequirement by washingMachine;
	satisfy temperatureSafetyRequirement by washingMachine;
	satisfy loadCapacityRequirement by washingMachine;
}
