package 'Inductor Circuit' {
	private import ScalarValues::*;

	value def Voltage :> Real;
	value def Current :> Real;
	value def Resistance :> Real;
	value def Inductance :> Real;
	value def Energy :> Real;

	item def MagneticField;

	part def FerriteCore {
		attribute permeability : Real;
		attribute saturationFlux : Real = 0.5;
	}

	part def WireWinding {
		attribute turnCount : Integer = 100;
	}

	part def Inductor {
		attribute inductance : Inductance;
		part core : FerriteCore;
		part winding : WireWinding;
		attribute storedEnergy : Energy = 0;
		item magneticField : MagneticField;
		in port powerIn : Voltage;
		out port currentOut : Current;
	}

	part def PowerSupply {
		attribute outputVoltage : Voltage = 12;
		out port powerOut : Voltage;
	}

	part def LoadResistor {
		attribute resistance : Resistance = 10;
		in port currentIn : Current;
		out port voltageDrop : Voltage;
	}

	part def CurrentSensor {
		attribute measuredCurrent : Current;
		in port sensedCurrent : Current;
		out port currentReading : Current;
	}

	action def BuildMagneticField {
		in voltage : Voltage;
		out energy : Energy;
	}

	action def MaintainCurrent {
		in energy : Energy;
		out current : Current;
	}

	action def ReleaseStoredEnergy {
		in energy : Energy;
		out current : Current;
	}

	requirement def SmoothCurrentFlow {
		doc /* The inductor shall smooth the flow of electrical current by opposing changes in current. */
		subject circuit : InductorCircuit;
	}

	requirement def StoreMagneticEnergy {
		doc /* The inductor shall store electrical energy within a magnetic field. */
		subject inductorPart : Inductor;
	}

	requirement def HandleSaturation {
		doc /* The system shall handle overload conditions when the inductor core is saturated. */
		subject circuit : InductorCircuit;
	}

	part def InductorCircuit {
		part powerSupply : PowerSupply;
		part inductor : Inductor;
		part loadResistor : LoadResistor;
		part currentSensor : CurrentSensor;

		flow powerSupply.powerOut to inductor.powerIn;
		flow inductor.currentOut to loadResistor.currentIn;
		flow inductor.currentOut to currentSensor.sensedCurrent;

		state InductorBehavior {
			state charging {
				entry action buildField : BuildMagneticField {
					in voltage = powerSupply.outputVoltage;
					out energy = inductor.storedEnergy;
				}
			}
			state steadyState {
				do action maintainCurrent : MaintainCurrent {
					in energy = inductor.storedEnergy;
					out current = inductor.currentOut;
				}
			}
			state discharging {
				do action releaseEnergy : ReleaseStoredEnergy {
					in energy = inductor.storedEnergy;
					out current = inductor.currentOut;
				}
			}
			state saturated;

			transition from initial to charging;
			transition from charging to steadyState
				when currentSensor.measuredCurrent >= 1.0;
			transition from steadyState to discharging
				when powerSupply.outputVoltage < 12.0;
			transition from discharging to steadyState
				when inductor.storedEnergy <= 0.0;
			transition from charging to saturated
				when inductor.storedEnergy >= 100.0;
			transition from saturated to discharging
				when powerSupply.outputVoltage < 12.0;
		}

		requirement smoothCurrent : SmoothCurrentFlow {
			subject = this;
		}

		requirement storeEnergy : StoreMagneticEnergy {
			subject = inductor;
		}

		requirement handleOverload : HandleSaturation {
			subject = this;
		}
	}
}
