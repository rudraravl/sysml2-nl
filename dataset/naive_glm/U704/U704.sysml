package HallEffectSensingUnit {

	import ScalarValues::*;

	value def Voltage :> Real { unit 'V'; }
	value def Current :> Real { unit 'A'; }
	value def MagneticFluxDensity :> Real { unit 'mT'; }
	value def Temperature :> Real { unit 'degC'; }
	value def ResponseTime :> Real { unit 'us'; }
	value def Percent :> Real { unit '%'; }
	value def Frequency :> Real { unit 'kHz'; }

	item def MagneticField {
		attribute fluxDensity : MagneticFluxDensity;
	}
	item def RawVoltageSignal {
		attribute voltage : Voltage;
	}
	item def ConditionedVoltageSignal {
		attribute voltage : Voltage;
	}
	item def ElectricalPower {
		attribute supplyVoltage : Voltage;
		attribute supplyCurrent : Current;
	}

	port def MagneticFieldPort {
		in item field : MagneticField;
		attribute fluxDensity : MagneticFluxDensity = field.fluxDensity;
	}
	port def PowerPort {
		in item power : ElectricalPower;
		attribute supplyVoltage : Voltage = power.supplyVoltage;
		attribute supplyCurrent : Current = power.supplyCurrent;
	}
	port def RawSignalOutPort {
		out item rawSignal : RawVoltageSignal;
		attribute voltage : Voltage = rawSignal.voltage;
	}
	port def RawSignalInPort {
		in item rawSignal : RawVoltageSignal;
		attribute voltage : Voltage = rawSignal.voltage;
	}
	port def VoltageOutputPort {
		out item signal : ConditionedVoltageSignal;
		attribute voltage : Voltage = signal.voltage;
	}

	interface def RawSignalFlow {
		end supplier : RawSignalOutPort;
		end consumer : RawSignalInPort;
		flow of rawSignal : RawVoltageSignal from supplier.rawSignal to consumer.rawSignal;
	}

	requirement def AccuracyRequirement {
		attribute maxError : Percent = 2 [%];
		doc { The sensing unit shall measure magnetic field strength with an accuracy within 2% of full scale. }
	}
	requirement def ResponseTimeRequirement {
		attribute maxResponseTime : ResponseTime = 10 [us];
		doc { The sensing unit shall respond to changes in the magnetic field within 10 microseconds. }
	}
	requirement def TemperatureRangeRequirement {
		attribute minOperatingTemp : Temperature = -40 [degC];
		attribute maxOperatingTemp : Temperature = 125 [degC];
		doc { The sensing unit shall operate across a temperature range from -40 degC to 125 degC. }
	}

	part def HallEffectSensor {
		port magneticInput : MagneticFieldPort;
		port powerIn : PowerPort;
		port rawOut : RawSignalOutPort;

		attribute sensitivity : Real = 1.0 [mV/mT];
		attribute offset : Voltage = 0 [V];
		attribute operatingTempMin : Temperature = -40 [degC];
		attribute operatingTempMax : Temperature = 125 [degC];

		state def SensorStateBehavior {
			entry;
			state Off;
			state Powered;
			state Sensing;

			transition off_to_powered
				initial Off -> Powered
				when powerIn.supplyVoltage > 0 [V];
			transition powered_to_sensing
				Powered -> Sensing
				when magneticInput.fluxDensity != 0 [mT];
			transition sensing_to_powered
				Sensing -> Powered
				when magneticInput.fluxDensity == 0 [mT];
			transition powered_to_off
				Powered -> Off
				when powerIn.supplyVoltage == 0 [V];
		}

		action def GenerateRawVoltage {
			in fluxDensity : MagneticFluxDensity;
			in supplyCurrent : Current;
			out rawVoltage : Voltage;
			action sense;
			action generate;
			flow fluxDensity to sense.in;
			flow supplyCurrent to sense.in;
			flow sense.out to generate.in;
			flow generate.out to rawVoltage;
		}

		compute rawOut.voltage = magneticInput.fluxDensity * sensitivity + offset;

		exhibit state behavior : SensorStateBehavior;
		exhibit action behavior : GenerateRawVoltage;
	}

	part def SignalConditioner {
		port rawIn : RawSignalInPort;
		port powerIn : PowerPort;
		port output : VoltageOutputPort;

		attribute gain : Real = 100.0;
		attribute offset : Voltage = 0 [V];
		attribute bandwidth : Frequency = 100 [kHz];
		attribute noiseFloor : Voltage = 0.001 [V];
		attribute linearityError : Percent = 0.5 [%];

		action def ConditioningProcess {
			in raw : RawVoltageSignal;
			out conditioned : ConditionedVoltageSignal;

			action amplify {
				out amplified : Voltage;
			}
			action filter {
				out filtered : Voltage;
			}
			action linearize {
				out linearized : Voltage;
			}
			action calibrate {
				out calibrated : Voltage;
			}

			flow raw to amplify.in;
			flow amplify.amplified to filter.in;
			flow filter.filtered to linearize.in;
			flow linearize.linearized to calibrate.in;
			flow calibrate.calibrated to conditioned.voltage;
		}

		compute output.voltage = (rawIn.voltage * gain) + offset;

		exhibit action behavior : ConditioningProcess;
	}

	part def HallEffectSensingUnit {
		port magneticFieldInput : MagneticFieldPort;
		port powerInput : PowerPort;
		port voltageOutput : VoltageOutputPort;

		attribute fullScaleRange : MagneticFluxDensity = 100 [mT];
		attribute accuracy : Percent = 2 [%];
		attribute responseTime : ResponseTime = 10 [us];
		attribute operatingTempMin : Temperature = -40 [degC];
		attribute operatingTempMax : Temperature = 125 [degC];

		part hallSensor : HallEffectSensor {
			port magneticInput : MagneticFieldPort;
			port powerIn : PowerPort;
			port rawOut : RawSignalOutPort;
		}

		part signalConditioner : SignalConditioner {
			port rawIn : RawSignalInPort;
			port powerIn : PowerPort;
			port output : VoltageOutputPort;
		}

		connection magneticFieldLink connect magneticFieldInput to hallSensor.magneticInput;
		connection powerToSensor connect powerInput to hallSensor.powerIn;
		connection powerToConditioner connect powerInput to signalConditioner.powerIn;
		connection rawSignalLink : RawSignalFlow connect hallSensor.rawOut to signalConditioner.rawIn;
		connection outputLink connect signalConditioner.output to voltageOutput;

		satisfy AccuracyRequirement by self;
		satisfy ResponseTimeRequirement by self;
		satisfy TemperatureRangeRequirement by self;
	}

}
