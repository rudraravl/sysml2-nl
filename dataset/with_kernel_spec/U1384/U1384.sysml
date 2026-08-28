package 'Pitot-Static Airspeed System' {
	private import ScalarValues::*;
	private import ISQ::*;

	attribute def TotalPressure :> PressureValue;
	attribute def StaticPressure :> PressureValue;
	attribute def DynamicPressure :> PressureValue;
	attribute def AirDensity :> DensityValue;
	attribute def IndicatedAirspeed :> SpeedValue;

	attribute def PowerOn;
	attribute def AirflowDetected;
	attribute def AirflowStopped;

	port def PressureOutput {
		out totalPressure : TotalPressure;
		out staticPressure : StaticPressure;
	}

	port def PressureInput {
		in totalPressure : TotalPressure;
		in staticPressure : StaticPressure;
	}

	port def AirspeedOutput {
		out airspeed : IndicatedAirspeed;
		out valid : Boolean;
	}

	port def AirspeedInput {
		in airspeed : IndicatedAirspeed;
		in valid : Boolean;
	}

	action def MeasureTotalPressure {
		out totalPressure : TotalPressure;
	}

	action def MeasureStaticPressure {
		out staticPressure : StaticPressure;
	}

	action def CalculateDynamicPressure {
		in totalPressure : TotalPressure;
		in staticPressure : StaticPressure;
		out dynamicPressure : DynamicPressure;
	}

	action def CalculateAirspeed {
		in dynamicPressure : DynamicPressure;
		in airDensity : AirDensity;
		out airspeed : IndicatedAirspeed;
	}

	action def ValidateAirspeed {
		in airspeed : IndicatedAirspeed;
		out valid : Boolean;
	}

	action def DisplayAirspeed {
		in airspeed : IndicatedAirspeed;
		in valid : Boolean;
	}

	action def ProcessAirspeed {
		in totalPressure : TotalPressure;
		in staticPressure : StaticPressure;
		in airDensity : AirDensity;
		out airspeed : IndicatedAirspeed;
		out valid : Boolean;

		perform action calcDynamicPressure : CalculateDynamicPressure {
			in totalPressure = totalPressure;
			in staticPressure = staticPressure;
			out dynamicPressure;
		}
		then perform action calcAirspeed : CalculateAirspeed {
			in dynamicPressure = calcDynamicPressure.dynamicPressure;
			in airDensity = airDensity;
			out airspeed;
		}
		then perform action validate : ValidateAirspeed {
			in airspeed = calcAirspeed.airspeed;
			out valid;
		}
	}

	part def PitotTube {
		port pressureOut : PressureOutput;
		perform action measureTotalPressure : MeasureTotalPressure;
		perform action measureStaticPressure : MeasureStaticPressure;
	}

	part def AirDataComputer {
		port pressureIn : PressureInput;
		port airspeedOut : AirspeedOutput;
		attribute airDensity : AirDensity;
		perform action processAirspeed : ProcessAirspeed;
	}

	part def DisplayUnit {
		port airspeedIn : AirspeedInput;
		perform action displayAirspeed : DisplayAirspeed;
	}

	state def PitotStaticStates;

	part def PitotStaticSystem {
		part pitotTube : PitotTube;
		part airDataComputer : AirDataComputer;
		part displayUnit : DisplayUnit;

		connect pitotTube.pressureOut to airDataComputer.pressureIn;
		connect airDataComputer.airspeedOut to displayUnit.airspeedIn;

		exhibit state systemStates : PitotStaticStates {
			entry; then initializing;
			state initializing;
			accept PowerOn then standby;
			state standby;
			accept AirflowDetected then active;
			state active {
				do pitotTube.measureTotalPressure
				then pitotTube.measureStaticPressure
				then airDataComputer.processAirspeed {
					in totalPressure = pitotTube.measureTotalPressure.totalPressure;
					in staticPressure = pitotTube.measureStaticPressure.staticPressure;
					in airDensity = airDataComputer.airDensity;
					out airspeed;
					out valid;
				}
				then displayUnit.displayAirspeed {
					in airspeed = airDataComputer.processAirspeed.airspeed;
					in valid = airDataComputer.processAirspeed.valid;
				}
			}
			accept AirflowStopped then standby;
		}
	}

	requirement def AirspeedMeasurementRequirement {
		doc /* The system shall continuously measure and display the aircraft's indicated airspeed. */
	}

	requirement def PressureMeasurementRequirement {
		doc /* The pitot tube shall measure total and static pressure simultaneously. */
	}

	requirement def DynamicPressureCalculationRequirement {
		doc /* The air data computer shall calculate dynamic pressure as the difference between total and static pressure. */
	}

	requirement def AirspeedCalculationRequirement {
		doc /* The air data computer shall calculate indicated airspeed using Bernoulli's principle with dynamic pressure and air density. */
	}

	requirement def ValidationRequirement {
		doc /* The system shall validate calculated airspeed for plausibility. */
	}

	requirement def DisplayRequirement {
		doc /* The display unit shall present airspeed in knots and update at a regular rate. */
	}

	requirement def StateBehaviorRequirement {
		doc /* The system shall initialize on power-up, enter standby on the ground, become active when airflow is detected, and return to standby when airflow stops. */
	}

	requirement airspeedMeasurement : AirspeedMeasurementRequirement;
	requirement pressureMeasurement : PressureMeasurementRequirement;
	requirement dynamicPressureCalc : DynamicPressureCalculationRequirement;
	requirement airspeedCalc : AirspeedCalculationRequirement;
	requirement validation : ValidationRequirement;
	requirement display : DisplayRequirement;
	requirement stateBehavior : StateBehaviorRequirement;
}
