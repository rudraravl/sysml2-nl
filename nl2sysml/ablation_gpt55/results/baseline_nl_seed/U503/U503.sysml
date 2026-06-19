package FuelPumpingSubsystemModel {
	import ScalarValues::*;

	attribute def Liter :> Real;
	attribute def LiterPerMinute :> Real;
	attribute def Kilopascal :> Real;
	attribute def Volt :> Real;
	attribute def Ampere :> Real;
	attribute def Watt :> Real;
	attribute def Ohm :> Real;
	attribute def DegreeCelsius :> Real;
	attribute def KilogramPerLiter :> Real;
	attribute def Micrometer :> Real;
	attribute def Millimeter :> Real;
	attribute def Meter :> Real;
	attribute def Second :> Real;
	attribute def Percent :> Real;

	enum def PumpCommandKind {
		enum off;
		enum prime;
		enum run;
		enum stop;
		enum reset;
	}

	enum def PumpModeKind {
		enum deenergized;
		enum priming;
		enum pumping;
		enum coastdown;
		enum faulted;
	}

	enum def PumpHealthKind {
		enum nominal;
		enum degraded;
		enum blockedInlet;
		enum overPressure;
		enum underVoltage;
		enum overTemperature;
	}

	item def Fuel {
		attribute density : KilogramPerLiter = 0.74;
		attribute temperature : DegreeCelsius = 20.0;
		attribute vaporPressure : Kilopascal = 55.0;
		attribute waterContent : Percent = 0.02;
	}

	item def FuelVapor {
		attribute pressure : Kilopascal = 101.3;
		attribute temperature : DegreeCelsius = 25.0;
	}

	item def DirectCurrentPower {
		attribute voltage : Volt = 28.0;
		attribute current : Ampere = 0.0;
		attribute power : Watt = 0.0;
	}

	item def PumpCommand {
		attribute selectedMode : PumpCommandKind = PumpCommandKind::off;
		attribute demandedFlow : LiterPerMinute = 0.0;
		attribute demandedOutletPressure : Kilopascal = 0.0;
	}

	item def PumpStatus {
		attribute mode : PumpModeKind = PumpModeKind::deenergized;
		attribute health : PumpHealthKind = PumpHealthKind::nominal;
		attribute deliveredFlow : LiterPerMinute = 0.0;
		attribute outletPressure : Kilopascal = 0.0;
		attribute motorCurrent : Ampere = 0.0;
		attribute caseTemperature : DegreeCelsius = 20.0;
	}

	item def PressureSignal {
		attribute measuredPressure : Kilopascal = 0.0;
		attribute signalVoltage : Volt = 0.5;
	}

	port def FuelPort {
		inout item fuel : Fuel;
		attribute ratedPressure : Kilopascal = 600.0;
		attribute nominalFlow : LiterPerMinute = 40.0;
	}

	port def VaporPort {
		inout item vapor : FuelVapor;
		attribute ratedPressure : Kilopascal = 150.0;
	}

	port def PowerPort {
		inout item power : DirectCurrentPower;
		attribute nominalVoltage : Volt = 28.0;
		attribute maxCurrent : Ampere = 20.0;
	}

	port def CommandPort {
		inout item command : PumpCommand;
	}

	port def StatusPort {
		inout item status : PumpStatus;
	}

	port def PressureSignalPort {
		inout item signal : PressureSignal;
	}

	connection def FuelLine {
		end source : FuelPort;
		end target : FuelPort;
		attribute innerDiameter : Millimeter = 8.0;
		attribute length : Meter = 0.5;
		attribute maxWorkingPressure : Kilopascal = 700.0;
		attribute pressureDropAtNominalFlow : Kilopascal = 4.0;
	}

	connection def VaporLine {
		end source : VaporPort;
		end target : VaporPort;
		attribute innerDiameter : Millimeter = 4.0;
		attribute maxWorkingPressure : Kilopascal = 150.0;
	}

	connection def PowerCable {
		end source : PowerPort;
		end target : PowerPort;
		attribute resistance : Ohm = 0.05;
		attribute maxCurrent : Ampere = 20.0;
	}

	connection def CommandLink {
		end source : CommandPort;
		end target : CommandPort;
		attribute updatePeriod : Second = 0.05;
	}

	connection def StatusLink {
		end source : StatusPort;
		end target : StatusPort;
		attribute updatePeriod : Second = 0.05;
	}

	connection def PressureSignalLink {
		end source : PressureSignalPort;
		end target : PressureSignalPort;
		attribute updatePeriod : Second = 0.02;
	}

	action def ReceiveFuel {
		in item inletFuel : Fuel;
		out item capturedFuel : Fuel;
		attribute inletPressure : Kilopascal = 100.0;
		attribute inletFlow : LiterPerMinute = 0.0;
	}

	action def PressurizeFuel {
		in item capturedFuel : Fuel;
		in item electricalPower : DirectCurrentPower;
		out item pressurizedFuel : Fuel;
		attribute pressureRise : Kilopascal = 350.0;
		attribute hydraulicEfficiency : Percent = 72.0;
		attribute motorCurrent : Ampere = 8.0;
	}

	action def DischargeFuel {
		in item pressurizedFuel : Fuel;
		out item deliveredFuel : Fuel;
		out item pumpStatus : PumpStatus;
		attribute deliveredFlow : LiterPerMinute = 40.0;
		attribute outletPressure : Kilopascal = 450.0;
	}

	action def PumpFuel {
		in item lowPressureFuel : Fuel;
		in item command : PumpCommand;
		in item supplyPower : DirectCurrentPower;
		out item highPressureFuel : Fuel;
		out item status : PumpStatus;
		attribute commandedFlow : LiterPerMinute = 40.0;
		attribute deliveredFlow : LiterPerMinute = 40.0;
		attribute inletPressure : Kilopascal = 100.0;
		attribute outletPressure : Kilopascal = 450.0;
		action receive : ReceiveFuel;
		action pressurize : PressurizeFuel;
		action discharge : DischargeFuel;
	}

	action def FilterFuel {
		in item unfilteredFuel : Fuel;
		out item filteredFuel : Fuel;
		attribute particleRating : Micrometer = 25.0;
		attribute pressureDrop : Kilopascal = 8.0;
	}

	action def MeasureOutletPressure {
		in item sensedFuel : Fuel;
		out item pressureSignal : PressureSignal;
		attribute samplePeriod : Second = 0.02;
		attribute measurementRange : Kilopascal = 700.0;
	}

	state def FuelPumpLifecycle {
		state off;
		state priming;
		state pumping;
		state stopping;
		state fault;
		transition offToPriming first off then priming;
		transition primingToPumping first priming then pumping;
		transition pumpingToStopping first pumping then stopping;
		transition stoppingToOff first stopping then off;
		transition offToFault first off then fault;
		transition primingToFault first priming then fault;
		transition pumpingToFault first pumping then fault;
		transition faultToOff first fault then off;
	}

	part def FuelReservoir {
		port tankOutlet : FuelPort;
		port returnInlet : FuelPort;
		port ventOutlet : VaporPort;
		attribute usableFuelVolume : Liter = 120.0;
		attribute minimumUnusableVolume : Liter = 2.0;
		attribute ullagePressure : Kilopascal = 101.3;
		attribute outletHeadPressure : Kilopascal = 108.0;
	}

	part def FuelFilter {
		port filterInlet : FuelPort;
		port filterOutlet : FuelPort;
		attribute absoluteRating : Micrometer = 25.0;
		attribute nominalPressureDrop : Kilopascal = 8.0;
		attribute bypassCrackingPressure : Kilopascal = 80.0;
		perform action filtering : FilterFuel;
	}

	part def FuelPump {
		port fuelInlet : FuelPort;
		port fuelOutlet : FuelPort;
		port electricalInput : PowerPort;
		port commandInput : CommandPort;
		port statusOutput : StatusPort;
		attribute nominalFlowRate : LiterPerMinute = 45.0;
		attribute minimumControllableFlowRate : LiterPerMinute = 5.0;
		attribute maximumFlowRate : LiterPerMinute = 60.0;
		attribute nominalInletPressure : Kilopascal = 100.0;
		attribute nominalDischargePressure : Kilopascal = 450.0;
		attribute maximumDischargePressure : Kilopascal = 600.0;
		attribute nominalSupplyVoltage : Volt = 28.0;
		attribute nominalCurrent : Ampere = 8.0;
		attribute lockedRotorCurrent : Ampere = 18.0;
		attribute maximumCaseTemperature : DegreeCelsius = 85.0;
		attribute maxParticleSize : Micrometer = 40.0;
		perform action fuelPumping : PumpFuel;
		exhibit state lifecycle : FuelPumpLifecycle;
	}

	part def OutletPressureSensor {
		port sensedFuelIn : FuelPort;
		port sensedFuelOut : FuelPort;
		port electricalInput : PowerPort;
		port pressureOutput : PressureSignalPort;
		attribute range : Kilopascal = 700.0;
		attribute accuracy : Percent = 1.0;
		attribute responseTime : Second = 0.02;
		perform action pressureMeasurement : MeasureOutletPressure;
	}

	part def OutletManifold {
		port manifoldInlet : FuelPort;
		port deliveryOutlet : FuelPort;
		attribute designPressure : Kilopascal = 600.0;
		attribute requiredDeliveryPressure : Kilopascal = 400.0;
		attribute nominalDemandFlow : LiterPerMinute = 40.0;
	}

	part def ElectricalBus {
		port externalPowerInput : PowerPort;
		port pumpPowerOutput : PowerPort;
		port controllerPowerOutput : PowerPort;
		port sensorPowerOutput : PowerPort;
		attribute nominalVoltage : Volt = 28.0;
		attribute maxContinuousCurrent : Ampere = 25.0;
		attribute minimumOperatingVoltage : Volt = 22.0;
	}

	part def PumpController {
		port operatorCommandInput : CommandPort;
		port pumpCommandOutput : CommandPort;
		port pumpStatusInput : StatusPort;
		port subsystemStatusOutput : StatusPort;
		port pressureInput : PressureSignalPort;
		port electricalInput : PowerPort;
		attribute commandUpdatePeriod : Second = 0.05;
		attribute faultTripPressure : Kilopascal = 575.0;
		attribute lowVoltageTrip : Volt = 22.0;
		attribute overTemperatureTrip : DegreeCelsius = 90.0;
	}

	part def PumpingSubsystem {
		port fuelDelivery : FuelPort;
		port fuelReturn : FuelPort;
		port vaporVent : VaporPort;
		port powerInput : PowerPort;
		port commandInput : CommandPort;
		port statusOutput : StatusPort;

		attribute requiredDeliveryFlow : LiterPerMinute = 40.0;
		attribute requiredDeliveryPressure : Kilopascal = 400.0;
		attribute allowableOutletPressureRipple : Kilopascal = 15.0;
		attribute maximumStartTime : Second = 3.0;

		part reservoir : FuelReservoir;
		part filter : FuelFilter;
		part pump : FuelPump;
		part pressureSensor : OutletPressureSensor;
		part manifold : OutletManifold;
		part electricalBus : ElectricalBus;
		part controller : PumpController;

		connection tankToFilter : FuelLine connect reservoir.tankOutlet to filter.filterInlet;
		connection filterToPump : FuelLine connect filter.filterOutlet to pump.fuelInlet;
		connection pumpToSensor : FuelLine connect pump.fuelOutlet to pressureSensor.sensedFuelIn;
		connection sensorToManifold : FuelLine connect pressureSensor.sensedFuelOut to manifold.manifoldInlet;
		connection manifoldToDelivery : FuelLine connect manifold.deliveryOutlet to fuelDelivery;
		connection returnToReservoir : FuelLine connect fuelReturn to reservoir.returnInlet;
		connection reservoirVent : VaporLine connect reservoir.ventOutlet to vaporVent;

		connection externalPowerToBus : PowerCable connect powerInput to electricalBus.externalPowerInput;
		connection busToPump : PowerCable connect electricalBus.pumpPowerOutput to pump.electricalInput;
		connection busToController : PowerCable connect electricalBus.controllerPowerOutput to controller.electricalInput;
		connection busToPressureSensor : PowerCable connect electricalBus.sensorPowerOutput to pressureSensor.electricalInput;

		connection operatorCommandToController : CommandLink connect commandInput to controller.operatorCommandInput;
		connection controllerCommandToPump : CommandLink connect controller.pumpCommandOutput to pump.commandInput;
		connection pumpStatusToController : StatusLink connect pump.statusOutput to controller.pumpStatusInput;
		connection controllerStatusToExternal : StatusLink connect controller.subsystemStatusOutput to statusOutput;
		connection pressureSensorToController : PressureSignalLink connect pressureSensor.pressureOutput to controller.pressureInput;
	}

	requirement def MoveFuelWithFuelPumpRequirement {
		subject subsystem : PumpingSubsystem;
		require constraint { subsystem.pump.nominalFlowRate >= subsystem.requiredDeliveryFlow }
	}

	requirement def ProvideDeliveryPressureRequirement {
		subject subsystem : PumpingSubsystem;
		require constraint { subsystem.pump.nominalDischargePressure >= subsystem.requiredDeliveryPressure }
	}

	requirement def ProtectPumpFromDebrisRequirement {
		subject subsystem : PumpingSubsystem;
		require constraint { subsystem.filter.absoluteRating <= subsystem.pump.maxParticleSize }
	}

	requirement def ElectricalCompatibilityRequirement {
		subject subsystem : PumpingSubsystem;
		require constraint { subsystem.pump.nominalSupplyVoltage == subsystem.electricalBus.nominalVoltage }
	}

	requirement def PressureContainmentRequirement {
		subject subsystem : PumpingSubsystem;
		require constraint { subsystem.pump.maximumDischargePressure <= subsystem.manifold.designPressure }
	}

	requirement def ThermalSafetyRequirement {
		subject subsystem : PumpingSubsystem;
		require constraint { subsystem.pump.maximumCaseTemperature <= subsystem.controller.overTemperatureTrip }
	}

	part pumpingSubsystem : PumpingSubsystem;
}
