package 'Electronic Boost Gauge System' {
	private import ISQ::*;
	private import SI::*;
	private import ScalarValues::*;

	item def AirPressure {
		attribute value : PressureValue;
	}
	item def VoltageSignal {
		attribute value : Real;
	}
	item def ProcessedPressure {
		attribute pressure : PressureValue;
		attribute warningActive : Boolean;
	}

	action def MeasurePressure {
		in air : AirPressure;
		out signal : VoltageSignal;
	}
	action def ProcessSignal {
		in signal : VoltageSignal;
		out pressure : ProcessedPressure;
	}
	action def UpdateDisplay {
		in pressure : ProcessedPressure;
	}
	action def ActivateWarningLight;

	part def IntakeManifold {
		out item pressurizedAir : AirPressure;
	}

	part def BoostPressureSensor {
		in item pressurizedAir : AirPressure;
		out item voltageSignal : VoltageSignal;
		perform action measurePressure : MeasurePressure {
			in air = pressurizedAir;
			out signal = voltageSignal;
		}
	}

	part def SignalProcessor {
		in item voltageSignal : VoltageSignal;
		out item processedPressure : ProcessedPressure;
		attribute safetyThreshold : PressureValue = 200 [kPa];
		perform action processSignal : ProcessSignal {
			in signal = voltageSignal;
			out pressure = processedPressure;
		}
	}

	state def DisplayStates {
		in display : GaugeDisplay;
		entry; then normal;
		state normal {
			do action updateDisplay : UpdateDisplay { in pressure = display.processedPressure; }
		}
		accept when display.processedPressure.warningActive
			then warning;
		state warning {
			entry action activateWarningLight : ActivateWarningLight;
			do action updateDisplay : UpdateDisplay { in pressure = display.processedPressure; }
		}
		accept when not display.processedPressure.warningActive
			then normal;
	}

	part def GaugeDisplay {
		in item processedPressure : ProcessedPressure;
		exhibit state displayStates : DisplayStates {
			in display = this;
		}
	}

	part boostGaugeSystem {
		part manifold : IntakeManifold;
		part sensor : BoostPressureSensor;
		part processor : SignalProcessor;
		part display : GaugeDisplay;

		connect manifold.pressurizedAir to sensor.pressurizedAir;
		connect sensor.voltageSignal to processor.voltageSignal;
		connect processor.processedPressure to display.processedPressure;
	}

	requirement def ResponseTimeRequirement {
		doc /* The system shall update the display within 50 milliseconds of a pressure change. */
		attribute maxLatency : DurationValue = 50 [ms];
	}

	requirement def OverboostWarningRequirement {
		doc /* The system shall activate a distinct warning light when intake manifold pressure exceeds the safety threshold. */
	}

	requirement def AccuracyRequirement {
		doc /* The sensor shall provide pressure readings with a tolerance of 2 kPa. */
		attribute tolerance : PressureValue = 2 [kPa];
	}

	requirement boostGaugeSpec {
		requirement responseTime : ResponseTimeRequirement;
		requirement overboostWarning : OverboostWarningRequirement;
		requirement accuracy : AccuracyRequirement;
	}

	satisfy boostGaugeSpec.responseTime by boostGaugeSystem.display;
	satisfy boostGaugeSpec.overboostWarning by boostGaugeSystem.processor;
	satisfy boostGaugeSpec.accuracy by boostGaugeSystem.sensor;
}
