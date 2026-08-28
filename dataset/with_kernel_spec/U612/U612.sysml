package 'Bimetallic Thermostat' {
	private import ISQ::*;
	private import SI::*;
	private import ScalarValues::*;

	item def ElectricalSignal;

	port def ElectricalPort {
		inout signal : ElectricalSignal;
	}

	part def MetalLayer {
		attribute thermalExpansionCoeff : Real;
		attribute thickness : LengthValue;
	}

	part def BimetallicStrip {
		part highExpansionLayer : MetalLayer {
			attribute redefines thermalExpansionCoeff = 23e-6;
			attribute redefines thickness = 0.5 [mm];
		}
		part lowExpansionLayer : MetalLayer {
			attribute redefines thermalExpansionCoeff = 5e-6;
			attribute redefines thickness = 0.5 [mm];
		}
		attribute deflection : LengthValue;
		attribute currentTemp : TemperatureValue;
	}

	part def ElectricalContact {
		attribute contactResistance : Real;
	}

	flow def PowerFlow {
		ref :>> payload : ElectricalSignal;
		end port inputPort : ElectricalPort;
		end port outputPort : ElectricalPort;
	}

	part def BimetallicThermostat {
		port lineIn : ElectricalPort;
		port lineOut : ElectricalPort;

		attribute setpoint : TemperatureValue;
		attribute hysteresis : TemperatureValue;
		attribute ambientTemp : TemperatureValue;

		part strip : BimetallicStrip;
		part movableContact : ElectricalContact;
		part fixedContact : ElectricalContact;

		connection contactBridge connect movableContact to fixedContact;

		flow : PowerFlow of ElectricalSignal from self.lineIn to self.lineOut;

		state ThermostatBehavior {
			entry; then open;
			state open;
			accept when ambientTemp <= setpoint - hysteresis / 2
				then closed;
			state closed;
			accept when ambientTemp >= setpoint + hysteresis / 2
				then open;
		}
	}

	requirement def TemperatureControlRequirement {
		subject thermostat : BimetallicThermostat;
		doc /* The thermostat shall open or close the electrical circuit based on ambient temperature crossing the setpoint. */;
	}

	requirement def HysteresisRequirement {
		subject thermostat : BimetallicThermostat;
		doc /* The thermostat shall include a hysteresis value to prevent rapid cycling. */;
	}

	requirement def SelfContainedOperationRequirement {
		subject thermostat : BimetallicThermostat;
		doc /* The thermostat shall operate without external power or electronics for sensing and actuation. */;
	}

	requirement def BimetallicStripRequirement {
		subject strip : BimetallicStrip;
		doc /* The bimetallic strip shall consist of two bonded metal layers with different thermal expansion coefficients. */;
	}

	part thermostat : BimetallicThermostat {
		attribute redefines setpoint = 298.15 [K];
		attribute redefines hysteresis = 2 [K];
		attribute redefines ambientTemp = 293.15 [K];
	}

	requirement tcr : TemperatureControlRequirement;
	requirement hr : HysteresisRequirement;
	requirement scor : SelfContainedOperationRequirement;
	requirement bsr : BimetallicStripRequirement;

	satisfy tcr by thermostat;
	satisfy hr by thermostat;
	satisfy scor by thermostat;
	satisfy bsr by thermostat.strip;
}
