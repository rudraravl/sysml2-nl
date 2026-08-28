package 'MAF Sensor System' {
	private import ISQ::*;
	private import SI::*;
	private import ScalarValues::*;

	value def MassFlowRate :> Real { unit 'kg/s'; }
	value def TemperatureValue :> Real { unit 'K'; }
	value def PressureValue :> Real { unit 'Pa'; }
	value def VoltageValue :> Real { unit 'V'; }
	value def TimeValue :> Real { unit 'ms'; }

	item def Air;
	item def AirFlow {
		attribute massFlowRate : MassFlowRate;
		attribute temperature : TemperatureValue;
		attribute pressure : PressureValue;
	}
	item def VoltageSignal {
		attribute voltage : VoltageValue;
	}
	item def FuelCommand {
		attribute fuelFlow : MassFlowRate;
	}

	port def AirPort {
		out item air : Air;
	}
	port def AirSinkPort {
		in item air : Air;
	}
	port def SignalOutPort {
		out item signal : VoltageSignal;
	}
	port def SignalInPort {
		in item signal : VoltageSignal;
	}
	port def FuelOutPort {
		out item fuel : FuelCommand;
	}
	port def FuelInPort {
		in item fuel : FuelCommand;
	}

	action def ProcessAirFlow {
		in attribute massFlowRate : MassFlowRate;
		in attribute temperature : TemperatureValue;
		in attribute pressure : PressureValue;
		out item processedAirFlow : AirFlow;
	}
	action def ConditionSignal {
		in item airFlow : AirFlow;
		out item voltageSignal : VoltageSignal;
	}
	action def CalculateFuel {
		in item voltageSignal : VoltageSignal;
		out item fuelCommand : FuelCommand;
	}

	part def AirFilter {
		port airIn : AirSinkPort;
		port airOut : AirPort;
	}
	part def HotWireElement {
		out attribute massFlowRate : MassFlowRate;
	}
	part def TemperatureSensor {
		out attribute temperature : TemperatureValue;
	}
	part def PressureSensor {
		out attribute pressure : PressureValue;
	}
	part def Microcontroller {
		in attribute massFlowRate : MassFlowRate;
		in attribute temperature : TemperatureValue;
		in attribute pressure : PressureValue;
		attribute calibrationParam : Real;
		perform action processAirFlow : ProcessAirFlow;
		out item processedAirFlow : AirFlow;
		bind processAirFlow.massFlowRate = massFlowRate;
		bind processAirFlow.temperature = temperature;
		bind processAirFlow.pressure = pressure;
		bind processedAirFlow = processAirFlow.processedAirFlow;
	}
	part def SignalConditioner {
		in item airFlow : AirFlow;
		perform action conditionSignal : ConditionSignal;
		out item voltageSignal : VoltageSignal;
		bind conditionSignal.airFlow = airFlow;
		bind voltageSignal = conditionSignal.voltageSignal;
	}

	state machine def MAFSensorBehavior {
		initial state Idle;
		state Measuring;
		state Processing;
		state Signaling;
		transition from Idle to Measuring when airIn.air.massFlowRate > 0;
		transition from Measuring to Processing after 5;
		transition from Processing to Signaling after 5;
		transition from Signaling to Idle after 5;
	}

	part def MAFSensor {
		port airIn : AirSinkPort;
		port airOut : AirPort;
		port signalOut : SignalOutPort;

		part hotWire : HotWireElement;
		part tempSensor : TemperatureSensor;
		part pressureSensor : PressureSensor;

		part microcontroller : Microcontroller {
			bind massFlowRate = hotWire.massFlowRate;
			bind temperature = tempSensor.temperature;
			bind pressure = pressureSensor.pressure;
		}
		part signalConditioner : SignalConditioner {
			bind airFlow = microcontroller.processedAirFlow;
		}
		bind signalOut.signal = signalConditioner.voltageSignal;

		perform state machine mafBehavior : MAFSensorBehavior;
	}
	part def IntakeManifold {
		port airIn : AirSinkPort;
		port airOut : AirPort;
	}
	part def Engine {
		port airIn : AirSinkPort;
		port fuelIn : FuelInPort;
	}
	part def ECU {
		port signalIn : SignalInPort;
		port fuelOut : FuelOutPort;
		in item voltageSignal : VoltageSignal;
		perform action calculateFuel : CalculateFuel;
		out item fuelCommand : FuelCommand;
		bind voltageSignal = signalIn.signal;
		bind calculateFuel.voltageSignal = voltageSignal;
		bind fuelCommand = calculateFuel.fuelCommand;
		bind fuelOut.fuel = fuelCommand;
	}
	part def Vehicle {
		part airFilter : AirFilter;
		part mafSensor : MAFSensor;
		part intakeManifold : IntakeManifold;
		part engine : Engine;
		part ecu : ECU;

		connect airFilter.airOut to mafSensor.airIn;
		connect mafSensor.airOut to intakeManifold.airIn;
		connect intakeManifold.airOut to engine.airIn;
		connect mafSensor.signalOut to ecu.signalIn;
		connect ecu.fuelOut to engine.fuelIn;
	}

	requirement def ResponseTimeRequirement {
		doc /* The MAF sensor shall react to changes in airflow in under 15 milliseconds. */
		attribute responseTime : TimeValue;
		require constraint { responseTime < 15 }
	}
	requirement def AccurateMeasurementRequirement {
		doc /* The MAF sensor shall provide a precise mass measurement regardless of altitude or weather. */
		subject mafSensor : MAFSensor;
	}
	requirement def FuelCalculationRequirement {
		doc /* The ECU shall calculate the exact amount of fuel to inject based on the MAF signal. */
		subject ecu : ECU;
	}
}
