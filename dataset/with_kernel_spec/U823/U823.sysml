package 'Pirani Gauge System' {
	private import ISQ::*;
	private import ScalarValues::*;
	private import SI::*;

	item def Gas;

	port def KF25Flange;

	part def VacuumChamberInterface {
		port flangePort : KF25Flange;
		ref item gas : Gas;
	}

	port def PowerPort {
		in power : PowerValue;
	}
	port def ResistancePort {
		out resistance : Real;
	}
	port def VoltagePort {
		out voltage : ElectricPotentialDifferenceValue;
	}
	port def PressurePort {
		out pressure : PressureValue;
	}

	part def PowerSupplyUnit {
		out port powerOut : PowerPort;
	}

	part def SensingFilament {
		in port powerIn : PowerPort;
		out port resistanceOut : ResistancePort;
		attribute temperature : ThermodynamicTemperatureValue;
		attribute resistance : Real;
	}

	part def BridgeCircuit {
		in port resistanceIn : ResistancePort;
		out port voltageOut : VoltagePort;
		attribute referenceResistance : Real;
	}

	part def SignalConditioner {
		in port voltageIn : VoltagePort;
		out port pressureOut : PressurePort;
	}

	part def DisplayController {
		in port pressureIn : PressurePort;
		attribute displayValue : PressureValue;
	}

	action def TurnOff;
	action def StartWarmup;
	action def StartMeasurement;
	action def MeasurePressure;
	action def HandleError;

	part def PiraniGauge {
		part vacuumInterface : VacuumChamberInterface;
		part powerSupply : PowerSupplyUnit;
		part filament : SensingFilament;
		part bridge : BridgeCircuit;
		part conditioner : SignalConditioner;
		part display : DisplayController;

		connect powerSupply.powerOut to filament.powerIn;
		connect filament.resistanceOut to bridge.resistanceIn;
		connect bridge.voltageOut to conditioner.voltageIn;
		connect conditioner.pressureOut to display.pressureIn;

		attribute powered : Boolean = false;
		attribute stabilized : Boolean = false;
		attribute faultDetected : Boolean = false;
		attribute reset : Boolean = false;

		state def GaugeOperation {
			state off {
				entry action TurnOff;
			}
			state warmup {
				entry action StartWarmup;
			}
			state measuring {
				entry action StartMeasurement;
				do action MeasurePressure;
			}
			state error {
				entry action HandleError;
			}
			transition off_to_warmup : off -> warmup when powered;
			transition warmup_to_measuring : warmup -> measuring when stabilized;
			transition measuring_to_error : measuring -> error when faultDetected;
			transition error_to_off : error -> off when reset;
		}

		state gaugeState : GaugeOperation;
	}

	requirement def MeasurePressureRequirement {
		doc /* The Pirani Gauge shall provide a continuous, real-time pressure reading by measuring the thermal conductivity of the gas. */
		subject gauge : PiraniGauge;
	}
}
