package OpticalDetectionSystem {
	private import ISQ::IlluminanceValue;
	private import ISQ::ElectricCurrentValue;
	private import ISQ::ElectricPotentialValue;
	private import ScalarValues::Boolean;
	private import ScalarValues::Real;
	private import SI::*;

	port def LightInput { in light : IlluminanceValue; }
	port def PowerInput { in power : ElectricPotentialValue; }
	port def PowerOutput { out power : ElectricPotentialValue; }
	port def CurrentOutput { out current : ElectricCurrentValue; }
	port def CurrentInput { in current : ElectricCurrentValue; }
	port def VoltageOutput { out voltage : ElectricPotentialValue; }
	port def VoltageInput { in voltage : ElectricPotentialValue; }
	port def ConditionedSignalOutput {
		out analog : ElectricPotentialValue;
		out digital : Boolean;
	}

	requirement def DetectAmbientLight {
		/* The system shall sense the level of ambient light. */
	}
	requirement def ConvertToElectricalSignal {
		/* The system shall convert light intensity into a measurable electrical signal. */
	}
	requirement def OperateInModes {
		/* The system shall operate in cutoff, active, and saturated modes based on light intensity. */
	}
	requirement def ConditionSignal {
		/* The system shall filter noise and convert the analog voltage to a usable digital or scaled analog format. */
	}

	action def ConvertCurrentToVoltage {
		in inputCurrent : ElectricCurrentValue;
		in resistanceValue : Real;
		out outputVoltage : ElectricPotentialValue;
		assign outputVoltage := inputCurrent * resistanceValue;
	}

	action def FilterAndScale {
		in rawVoltage : ElectricPotentialValue;
		out analog : ElectricPotentialValue;
		assign analog := rawVoltage;
	}

	action def Digitize {
		in rawVoltage : ElectricPotentialValue;
		in threshold : ElectricPotentialValue;
		out digital : Boolean;
		assign digital := rawVoltage > threshold;
	}

	part def PowerSupply {
		port powerOut : PowerOutput;
		attribute supplyVoltage : ElectricPotentialValue := 5 [V];
		bind powerOut.power = supplyVoltage;
	}

	part def CollectorResistor {
		port currentIn : CurrentInput;
		port voltageOut : VoltageOutput;
		attribute resistance : Real := 1000;
		action convert : ConvertCurrentToVoltage;
		bind convert.inputCurrent = currentIn.current;
		bind convert.resistanceValue = resistance;
		bind convert.outputVoltage = voltageOut.voltage;
	}

	part def SignalConditioner {
		port voltageIn : VoltageInput;
		port signalOut : ConditionedSignalOutput;
		attribute threshold : ElectricPotentialValue := 2.5 [V];
		action scaleSignal : FilterAndScale;
		action digitize : Digitize;
		bind scaleSignal.rawVoltage = voltageIn.voltage;
		bind scaleSignal.analog = signalOut.analog;
		bind digitize.rawVoltage = voltageIn.voltage;
		bind digitize.threshold = threshold;
		bind digitize.digital = signalOut.digital;
	}

	part def Phototransistor {
		port lightIn : LightInput;
		port powerIn : PowerInput;
		port currentOut : CurrentOutput;

		attribute internalCurrent : ElectricCurrentValue;
		bind currentOut.current = internalCurrent;

		state PhototransistorOperation {
			entry; then cutoff;

			state cutoff {
				do assign internalCurrent := 0.0001 [A];
			}

			transition cutoff_to_active
				first cutoff
				accept when lightIn.light > 10 [lx]
				then active;

			state active {
				do assign internalCurrent := lightIn.light * 0.001 [A/lx];
			}

			transition active_to_cutoff
				first active
				accept when lightIn.light <= 10 [lx]
				then cutoff;

			transition active_to_saturated
				first active
				accept when lightIn.light > 1000 [lx]
				then saturated;

			state saturated {
				do assign internalCurrent := 0.05 [A];
			}

			transition saturated_to_active
				first saturated
				accept when lightIn.light <= 1000 [lx]
				then active;
		}
	}

	part def OpticalSystem {
		satisfy DetectAmbientLight;
		satisfy ConvertToElectricalSignal;
		satisfy OperateInModes;
		satisfy ConditionSignal;

		part power : PowerSupply;
		part sensor : Phototransistor;
		part resistor : CollectorResistor;
		part conditioner : SignalConditioner;

		port lightPort : LightInput;
		port outputPort : ConditionedSignalOutput;

		connect lightPort to sensor.lightIn;
		connect power.powerOut to sensor.powerIn;
		connect sensor.currentOut to resistor.currentIn;
		connect resistor.voltageOut to conditioner.voltageIn;
		connect conditioner.signalOut to outputPort;
	}
}
