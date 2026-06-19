package PulserPumpingSubsystemModel {
	import ScalarValues::*;

	attribute def UnitValue {
		attribute value : Real;
		attribute unitSymbol : String;
	}

	attribute def LiterPerMinuteValue :> UnitValue {
		:>> unitSymbol = "L/min";
	}

	attribute def MilliliterValue :> UnitValue {
		:>> unitSymbol = "mL";
	}

	attribute def KilopascalValue :> UnitValue {
		:>> unitSymbol = "kPa";
	}

	attribute def HertzValue :> UnitValue {
		:>> unitSymbol = "Hz";
	}

	attribute def VoltValue :> UnitValue {
		:>> unitSymbol = "V";
	}

	attribute def AmpereValue :> UnitValue {
		:>> unitSymbol = "A";
	}

	attribute def WattValue :> UnitValue {
		:>> unitSymbol = "W";
	}

	attribute def CelsiusValue :> UnitValue {
		:>> unitSymbol = "degC";
	}

	attribute def CentipoiseValue :> UnitValue {
		:>> unitSymbol = "cP";
	}

	attribute def KilogramPerCubicMeterValue :> UnitValue {
		:>> unitSymbol = "kg/m3";
	}

	attribute def MicrometerValue :> UnitValue {
		:>> unitSymbol = "um";
	}

	attribute def PercentValue :> UnitValue {
		:>> unitSymbol = "%";
	}

	item def ProcessFluid {
		attribute density : KilogramPerCubicMeterValue {
			:>> value = 998.0;
		}
		attribute dynamicViscosity : CentipoiseValue {
			:>> value = 1.0;
		}
		attribute temperature : CelsiusValue {
			:>> value = 20.0;
		}
		attribute particulateLimit : MicrometerValue {
			:>> value = 50.0;
		}
		attribute chemicallyCompatible : Boolean = true;
	}

	item def DirectCurrentPower {
		attribute voltage : VoltValue {
			:>> value = 24.0;
		}
		attribute current : AmpereValue {
			:>> value = 8.0;
		}
		attribute availablePower : WattValue {
			:>> value = 192.0;
		}
	}

	item def PumpCommand {
		attribute startRequested : Boolean = false;
		attribute stopRequested : Boolean = false;
		attribute primeRequested : Boolean = false;
		attribute flushRequested : Boolean = false;
		attribute commandedPulseFrequency : HertzValue {
			:>> value = 4.0;
		}
		attribute commandedFlow : LiterPerMinuteValue {
			:>> value = 12.0;
		}
	}

	item def PumpStatus {
		attribute ready : Boolean = true;
		attribute primed : Boolean = false;
		attribute running : Boolean = false;
		attribute faulted : Boolean = false;
		attribute dryRunDetected : Boolean = false;
		attribute measuredFlow : LiterPerMinuteValue {
			:>> value = 0.0;
		}
		attribute measuredDischargePressure : KilopascalValue {
			:>> value = 0.0;
		}
	}

	item def FlowSignal {
		attribute measuredFlow : LiterPerMinuteValue {
			:>> value = 0.0;
		}
		attribute signalValid : Boolean = true;
	}

	item def PressureSignal {
		attribute measuredPressure : KilopascalValue {
			:>> value = 0.0;
		}
		attribute signalValid : Boolean = true;
	}

	port def FluidInletPort {
		in item fluid : ProcessFluid;
		attribute pressure : KilopascalValue {
			:>> value = 0.0;
		}
		attribute temperature : CelsiusValue {
			:>> value = 20.0;
		}
	}

	port def FluidOutletPort {
		out item fluid : ProcessFluid;
		attribute pressure : KilopascalValue {
			:>> value = 0.0;
		}
		attribute temperature : CelsiusValue {
			:>> value = 20.0;
		}
	}

	port def DCPowerInputPort {
		in item power : DirectCurrentPower;
	}

	port def DCPowerOutputPort {
		out item power : DirectCurrentPower;
	}

	port def PumpControlInputPort {
		in item command : PumpCommand;
		out item status : PumpStatus;
	}

	port def PumpControlOutputPort {
		out item command : PumpCommand;
		in item status : PumpStatus;
	}

	port def SensorOutputPort {
		out item flowSignal : FlowSignal;
		out item pressureSignal : PressureSignal;
	}

	port def SensorInputPort {
		in item flowSignal : FlowSignal;
		in item pressureSignal : PressureSignal;
	}

	connection def FluidLine {
		end source : FluidOutletPort;
		end target : FluidInletPort;
		attribute internalDiameter : MilliliterValue {
			:>> value = 12.0;
			:>> unitSymbol = "mm";
		}
		attribute maximumWorkingPressure : KilopascalValue {
			:>> value = 600.0;
		}
	}

	connection def ElectricalCable {
		end source : DCPowerOutputPort;
		end target : DCPowerInputPort;
		attribute voltageDrop : VoltValue {
			:>> value = 0.2;
		}
	}

	connection def ControlCable {
		end controllerEnd : PumpControlOutputPort;
		end pumpEnd : PumpControlInputPort;
	}

	connection def SensorCable {
		end sensorEnd : SensorOutputPort;
		end controllerEnd : SensorInputPort;
	}

	action def PulserPumpingCycle {
		in item incomingFluid : ProcessFluid;
		in attribute commandedPulseFrequency : HertzValue;
		out item dischargedFluid : ProcessFluid;
		out attribute deliveredFlow : LiterPerMinuteValue;

		action openInletCheck;
		action retractDiaphragm;
		action fillDisplacementChamber;
		action closeInletCheck;
		action advanceDiaphragm;
		action openOutletCheck;
		action deliverDischargePulse;
		action closeOutletCheck;

		succession openInletCheck then retractDiaphragm;
		succession retractDiaphragm then fillDisplacementChamber;
		succession fillDisplacementChamber then closeInletCheck;
		succession closeInletCheck then advanceDiaphragm;
		succession advanceDiaphragm then openOutletCheck;
		succession openOutletCheck then deliverDischargePulse;
		succession deliverDischargePulse then closeOutletCheck;
	}

	action def PrimePump {
		out item primedFluid : ProcessFluid;
		attribute primingFlow : LiterPerMinuteValue {
			:>> value = 3.0;
		}
		attribute maximumPrimingPressure : KilopascalValue {
			:>> value = 80.0;
		}
	}

	action def StopPumpSafely {
		attribute rampDownFrequency : HertzValue {
			:>> value = 1.0;
		}
		attribute closeDischargeCheckValve : Boolean = true;
	}

	state def PulserPumpOperatingState {
		entry; then off;

		state off;
		state priming;
		state pulsing;
		state flushing;
		state fault;

		transition off_to_priming first off accept PumpCommand then priming;
		transition priming_to_pulsing first priming accept PumpStatus then pulsing;
		transition pulsing_to_flushing first pulsing accept PumpCommand then flushing;
		transition pulsing_to_off first pulsing accept PumpCommand then off;
		transition any_to_fault first off accept PumpStatus then fault;
		transition fault_to_off first fault accept PumpCommand then off;
	}

	state def PumpingSubsystemState {
		entry; then standby;

		state standby;
		state priming;
		state transferring;
		state controlledShutdown;
		state faultIsolated;

		transition standby_to_priming first standby accept PumpCommand then priming;
		transition priming_to_transferring first priming accept PumpStatus then transferring;
		transition transferring_to_shutdown first transferring accept PumpCommand then controlledShutdown;
		transition shutdown_to_standby first controlledShutdown accept PumpStatus then standby;
		transition transferring_to_fault first transferring accept PumpStatus then faultIsolated;
		transition fault_to_standby first faultIsolated accept PumpCommand then standby;
	}

	part def FluidSourceInterface {
		port outlet : FluidOutletPort;
		port returnInlet : FluidInletPort;

		attribute supplyPressure : KilopascalValue {
			:>> value = 25.0;
		}
		attribute minimumAvailableVolume : MilliliterValue {
			:>> value = 5000.0;
		}
	}

	part def FluidSinkInterface {
		port inlet : FluidInletPort;

		attribute backPressure : KilopascalValue {
			:>> value = 150.0;
		}
		attribute acceptedFlow : LiterPerMinuteValue {
			:>> value = 12.0;
		}
	}

	part def InletFilter {
		port inlet : FluidInletPort;
		port outlet : FluidOutletPort;

		attribute absoluteRating : MicrometerValue {
			:>> value = 50.0;
		}
		attribute cleanDifferentialPressure : KilopascalValue {
			:>> value = 5.0;
		}
		attribute cloggedDifferentialPressure : KilopascalValue {
			:>> value = 35.0;
		}
		attribute bypassAllowed : Boolean = false;
	}

	part def PulserPump {
		port suction : FluidInletPort;
		port discharge : FluidOutletPort;
		port powerInput : DCPowerInputPort;
		port control : PumpControlInputPort;

		attribute displacementPerPulse : MilliliterValue {
			:>> value = 50.0;
		}
		attribute minimumPulseFrequency : HertzValue {
			:>> value = 0.5;
		}
		attribute maximumPulseFrequency : HertzValue {
			:>> value = 6.0;
		}
		attribute ratedFlow : LiterPerMinuteValue {
			:>> value = 18.0;
		}
		attribute ratedDifferentialPressure : KilopascalValue {
			:>> value = 350.0;
		}
		attribute maximumDischargePressure : KilopascalValue {
			:>> value = 500.0;
		}
		attribute minimumSuctionPressure : KilopascalValue {
			:>> value = 10.0;
		}
		attribute volumetricEfficiency : PercentValue {
			:>> value = 92.0;
		}
		attribute dryRunProtected : Boolean = true;

		perform action pumpingCycle : PulserPumpingCycle;
		perform action primingCycle : PrimePump;
		perform action shutdownCycle : StopPumpSafely;
		exhibit state operatingState : PulserPumpOperatingState;
	}

	part def CheckValve {
		port inlet : FluidInletPort;
		port outlet : FluidOutletPort;

		attribute crackingPressure : KilopascalValue {
			:>> value = 8.0;
		}
		attribute reverseLeakage : LiterPerMinuteValue {
			:>> value = 0.02;
		}
		attribute reverseFlowBlocked : Boolean = true;
	}

	part def PulsationDampener {
		port inlet : FluidInletPort;
		port outlet : FluidOutletPort;

		attribute prechargePressure : KilopascalValue {
			:>> value = 120.0;
		}
		attribute gasVolume : MilliliterValue {
			:>> value = 750.0;
		}
		attribute inletRipple : KilopascalValue {
			:>> value = 90.0;
		}
		attribute outletRipple : KilopascalValue {
			:>> value = 25.0;
		}
	}

	part def ReliefValve {
		port inlet : FluidInletPort;
		port outlet : FluidOutletPort;

		attribute setPressure : KilopascalValue {
			:>> value = 450.0;
		}
		attribute reseatPressure : KilopascalValue {
			:>> value = 390.0;
		}
		attribute fullBypassFlow : LiterPerMinuteValue {
			:>> value = 20.0;
		}
	}

	part def FlowMeter {
		port inlet : FluidInletPort;
		port outlet : FluidOutletPort;
		port signal : SensorOutputPort;

		attribute measurementRangeLow : LiterPerMinuteValue {
			:>> value = 0.5;
		}
		attribute measurementRangeHigh : LiterPerMinuteValue {
			:>> value = 20.0;
		}
		attribute accuracy : PercentValue {
			:>> value = 1.0;
		}
	}

	part def PressureTransducer {
		port wettedPort : FluidInletPort;
		port signal : SensorOutputPort;

		attribute pressureRange : KilopascalValue {
			:>> value = 600.0;
		}
		attribute accuracy : PercentValue {
			:>> value = 0.5;
		}
	}

	part def DCPowerSupply {
		port output : DCPowerOutputPort;

		attribute nominalVoltage : VoltValue {
			:>> value = 24.0;
		}
		attribute maximumCurrent : AmpereValue {
			:>> value = 10.0;
		}
		attribute maximumPower : WattValue {
			:>> value = 240.0;
		}
	}

	part def PumpController {
		port powerInput : DCPowerInputPort;
		port pumpControl : PumpControlOutputPort;
		port sensorInput : SensorInputPort;

		attribute targetFlow : LiterPerMinuteValue {
			:>> value = 12.0;
		}
		attribute minimumAllowedSuctionPressure : KilopascalValue {
			:>> value = 10.0;
		}
		attribute maximumAllowedDischargePressure : KilopascalValue {
			:>> value = 420.0;
		}
		attribute dryRunTripEnabled : Boolean = true;
		attribute overPressureTripEnabled : Boolean = true;
		attribute closedLoopFlowControlEnabled : Boolean = true;
	}

	part def PumpingSubsystem {
		port fluidIn : FluidInletPort;
		port fluidOut : FluidOutletPort;
		port powerIn : DCPowerInputPort;

		part suctionInterface : FluidSourceInterface;
		part inletFilter : InletFilter;
		part pulserPump : PulserPump;
		part dischargeCheckValve : CheckValve;
		part pulsationDampener : PulsationDampener;
		part reliefValve : ReliefValve;
		part flowMeter : FlowMeter;
		part suctionPressureSensor : PressureTransducer;
		part dischargePressureSensor : PressureTransducer;
		part dischargeInterface : FluidSinkInterface;
		part powerSupply : DCPowerSupply;
		part controller : PumpController;

		attribute requiredFlow : LiterPerMinuteValue {
			:>> value = 12.0;
		}
		attribute deliveredFlow : LiterPerMinuteValue {
			:>> value = 12.0;
		}
		attribute suctionPressure : KilopascalValue {
			:>> value = 25.0;
		}
		attribute dischargePressure : KilopascalValue {
			:>> value = 180.0;
		}
		attribute dischargePressureRipple : KilopascalValue {
			:>> value = 25.0;
		}
		attribute maximumPermittedRipple : KilopascalValue {
			:>> value = 30.0;
		}
		attribute maximumPermittedDischargePressure : KilopascalValue {
			:>> value = 420.0;
		}
		attribute minimumPermittedSuctionPressure : KilopascalValue {
			:>> value = 10.0;
		}
		attribute externalLeakage : LiterPerMinuteValue {
			:>> value = 0.0;
		}
		attribute maximumExternalLeakage : LiterPerMinuteValue {
			:>> value = 0.01;
		}
		attribute operatingTemperature : CelsiusValue {
			:>> value = 25.0;
		}
		attribute maximumOperatingTemperature : CelsiusValue {
			:>> value = 60.0;
		}

		connection sourceToFilter : FluidLine connect suctionInterface.outlet to inletFilter.inlet;
		connection filterToPump : FluidLine connect inletFilter.outlet to pulserPump.suction;
		connection pumpToCheckValve : FluidLine connect pulserPump.discharge to dischargeCheckValve.inlet;
		connection checkValveToDampener : FluidLine connect dischargeCheckValve.outlet to pulsationDampener.inlet;
		connection dampenerToFlowMeter : FluidLine connect pulsationDampener.outlet to flowMeter.inlet;
		connection flowMeterToDischarge : FluidLine connect flowMeter.outlet to dischargeInterface.inlet;
		connection reliefSupply : FluidLine connect pulserPump.discharge to reliefValve.inlet;
		connection reliefReturn : FluidLine connect reliefValve.outlet to suctionInterface.returnInlet;

		connection pumpPowerCable : ElectricalCable connect powerSupply.output to pulserPump.powerInput;
		connection controllerPowerCable : ElectricalCable connect powerSupply.output to controller.powerInput;
		connection pumpControlCable : ControlCable connect controller.pumpControl to pulserPump.control;
		connection flowSensorCable : SensorCable connect flowMeter.signal to controller.sensorInput;
		connection suctionPressureCable : SensorCable connect suctionPressureSensor.signal to controller.sensorInput;
		connection dischargePressureCable : SensorCable connect dischargePressureSensor.signal to controller.sensorInput;

		perform action transferFluid : PulserPumpingCycle;
		perform action primeBeforeTransfer : PrimePump;
		perform action stopTransfer : StopPumpSafely;
		exhibit state subsystemState : PumpingSubsystemState;
	}

	requirement def TransferFlowRequirement {
		subject subsystem : PumpingSubsystem;

		attribute minimumContinuousFlow : LiterPerMinuteValue {
			:>> value = 10.0;
		}

		require constraint flowCapacity {
			subsystem.deliveredFlow.value >= minimumContinuousFlow.value
		}
	}

	requirement def PressureProtectionRequirement {
		subject subsystem : PumpingSubsystem;

		require constraint dischargeLimit {
			subsystem.dischargePressure.value <= subsystem.maximumPermittedDischargePressure.value
		}

		require constraint suctionLimit {
			subsystem.suctionPressure.value >= subsystem.minimumPermittedSuctionPressure.value
		}
	}

	requirement def PulsationControlRequirement {
		subject subsystem : PumpingSubsystem;

		require constraint rippleLimit {
			subsystem.dischargePressureRipple.value <= subsystem.maximumPermittedRipple.value
		}
	}

	requirement def DryRunProtectionRequirement {
		subject subsystem : PumpingSubsystem;

		require constraint dryRunProtectionInstalled {
			subsystem.controller.dryRunTripEnabled == true
		}
	}

	requirement def LeakTightnessRequirement {
		subject subsystem : PumpingSubsystem;

		require constraint leakageLimit {
			subsystem.externalLeakage.value <= subsystem.maximumExternalLeakage.value
		}
	}

	requirement def FluidTemperatureRequirement {
		subject subsystem : PumpingSubsystem;

		require constraint temperatureLimit {
			subsystem.operatingTemperature.value <= subsystem.maximumOperatingTemperature.value
		}
	}

	part pulserPumpingSubsystem : PumpingSubsystem;

	requirement transferFlowRequirement : TransferFlowRequirement {
		subject subsystem = pulserPumpingSubsystem;
	}

	requirement pressureProtectionRequirement : PressureProtectionRequirement {
		subject subsystem = pulserPumpingSubsystem;
	}

	requirement pulsationControlRequirement : PulsationControlRequirement {
		subject subsystem = pulserPumpingSubsystem;
	}

	requirement dryRunProtectionRequirement : DryRunProtectionRequirement {
		subject subsystem = pulserPumpingSubsystem;
	}

	requirement leakTightnessRequirement : LeakTightnessRequirement {
		subject subsystem = pulserPumpingSubsystem;
	}

	requirement fluidTemperatureRequirement : FluidTemperatureRequirement {
		subject subsystem = pulserPumpingSubsystem;
	}

	satisfy transferFlowRequirement by pulserPumpingSubsystem;
	satisfy pressureProtectionRequirement by pulserPumpingSubsystem;
	satisfy pulsationControlRequirement by pulserPumpingSubsystem;
	satisfy dryRunProtectionRequirement by pulserPumpingSubsystem;
	satisfy leakTightnessRequirement by pulserPumpingSubsystem;
	satisfy fluidTemperatureRequirement by pulserPumpingSubsystem;
}
