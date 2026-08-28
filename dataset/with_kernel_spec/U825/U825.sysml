package PitotAirspeedSystem {
	private import ISQ::*;
	private import ScalarFunctions::*;
	private import NumericalFunctions::*;

	requirement def ProvideContinuousAirspeed {
		doc "The system shall provide a continuous and accurate airspeed reading to the pilot.";
	}

	requirement def CalculateDynamicPressureRequirement {
		doc "The pressure sensor shall calculate dynamic pressure as the difference between total and static pressure.";
	}

	requirement def CalculateIndicatedAirspeedRequirement {
		doc "The air data computer shall calculate indicated airspeed using Bernoulli's principle with dynamic pressure and standard air density.";
	}

	part def PitotProbe {
		port totalPressurePort {
			out totalPressure : PressureValue;
		}
		port staticPressurePort {
			out staticPressure : PressureValue;
		}
	}

	part def PressureSensor {
		port totalPressurePort {
			in totalPressure : PressureValue;
		}
		port staticPressurePort {
			in staticPressure : PressureValue;
		}
		port dynamicPressurePort {
			out dynamicPressure : PressureValue;
		}

		calc dynamicPressureCalc {
			in tp : PressureValue = totalPressurePort.totalPressure;
			in sp : PressureValue = staticPressurePort.staticPressure;
			return dp : PressureValue = tp - sp;
		}

		bind dynamicPressurePort.dynamicPressure = dynamicPressureCalc.dp;
	}

	part def AirDataComputer {
		port dynamicPressurePort {
			in dynamicPressure : PressureValue;
		}
		port indicatedAirspeedPort {
			out indicatedAirspeed : SpeedValue;
		}
		attribute airDensity : MassDensityValue = 1.225 [kg/m^3];

		calc indicatedAirspeedCalc {
			in dp : PressureValue = dynamicPressurePort.dynamicPressure;
			in rho : MassDensityValue = airDensity;
			return v : SpeedValue = sqrt(2 * dp / rho);
		}

		bind indicatedAirspeedPort.indicatedAirspeed = indicatedAirspeedCalc.v;
	}

	part def AirspeedIndicator {
		port indicatedAirspeedPort {
			in indicatedAirspeed : SpeedValue;
		}
		attribute displayedSpeed : SpeedValue;
		bind displayedSpeed = indicatedAirspeedPort.indicatedAirspeed;
	}

	state def MeasurementCycle {
		state Sensing;
		state ComputingDynamicPressure;
		state ComputingAirspeed;
		state Displaying;

		transition senseToDynamic from Sensing to ComputingDynamicPressure;
		transition dynamicToAirspeed from ComputingDynamicPressure to ComputingAirspeed;
		transition airspeedToDisplay from ComputingAirspeed to Displaying;
		transition displayToSense from Displaying to Sensing;
	}

	part def PitotAirspeedSystem {
		part probe : PitotProbe;
		part sensor : PressureSensor;
		part computer : AirDataComputer;
		part indicator : AirspeedIndicator;

		flow totalPressureFlow of PressureValue
			from probe.totalPressurePort.totalPressure to sensor.totalPressurePort.totalPressure;
		flow staticPressureFlow of PressureValue
			from probe.staticPressurePort.staticPressure to sensor.staticPressurePort.staticPressure;
		flow dynamicPressureFlow of PressureValue
			from sensor.dynamicPressurePort.dynamicPressure to computer.dynamicPressurePort.dynamicPressure;
		flow indicatedAirspeedFlow of SpeedValue
			from computer.indicatedAirspeedPort.indicatedAirspeed to indicator.indicatedAirspeedPort.indicatedAirspeed;

		behavior measurementCycle : MeasurementCycle;

		satisfy ProvideContinuousAirspeed;
		satisfy CalculateDynamicPressureRequirement by sensor;
		satisfy CalculateIndicatedAirspeedRequirement by computer;
	}

	part pitotSystem : PitotAirspeedSystem;
}
