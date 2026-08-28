package PotentiometricSensingUnit {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	item def RawAnalogSignal {
		attribute voltage : ElectricPotentialValue;
	}
	item def ConditionedAnalogSignal {
		attribute voltage : ElectricPotentialValue;
	}
	item def RawDigitalValue {
		attribute value : Integer;
	}
	item def ProcessedPosition {
		attribute position : Real;
	}

	attribute def StartCmd;
	attribute def StopCmd;
	attribute def ResetCmd;
	attribute def FaultSignal;

	action def SenseDisplacement {
		in disp : LengthValue;
		in excite : ElectricPotentialValue;
		out sig : RawAnalogSignal;
	}
	action def ConditionSignal {
		in raw : RawAnalogSignal;
		in gain : Real;
		in cutoff : FrequencyValue;
		out cond : ConditionedAnalogSignal;
	}
	action def ConvertToDigital {
		in cond : ConditionedAnalogSignal;
		in sampleRate : FrequencyValue;
		out dig : RawDigitalValue;
	}
	action def ProcessAndCalibrate {
		in dig : RawDigitalValue;
		in offset : Real;
		in scale : Real;
		out pos : ProcessedPosition;
	}
	action def SelfTest;
	action def LoadCalibration;
	action def EnterLowPower;
	action def ExitLowPower;
	action def MeasurePosition;
	action def Initialize {
		action selfTest : SelfTest;
		action loadCal : LoadCalibration;
	}

	part def PotentiometricSensor {
		in displacement : LengthValue;
		out rawSignal : RawAnalogSignal;
		attribute excitationVoltage : ElectricPotentialValue := 5.0 [V];
		action sense : SenseDisplacement {
			in disp = displacement;
			in excite = excitationVoltage;
			out sig = rawSignal;
		}
	}

	part def SignalConditioner {
		in rawSignal : RawAnalogSignal;
		out conditionedSignal : ConditionedAnalogSignal;
		attribute gain : Real := 10.0;
		attribute cutoffFrequency : FrequencyValue := 1000 [Hz];
		action condition : ConditionSignal {
			in raw = rawSignal;
			in gain = gain;
			in cutoff = cutoffFrequency;
			out cond = conditionedSignal;
		}
	}

	part def ADC {
		in conditionedSignal : ConditionedAnalogSignal;
		out rawDigital : RawDigitalValue;
		attribute samplingRate : FrequencyValue := 10000 [Hz];
		action convert : ConvertToDigital {
			in cond = conditionedSignal;
			in sampleRate = samplingRate;
			out dig = rawDigital;
		}
	}

	part def Microcontroller {
		in rawDigital : RawDigitalValue;
		out processedPosition : ProcessedPosition;
		attribute zeroOffset : Real := 0.0;
		attribute scaleFactor : Real := 1.0;
		action process : ProcessAndCalibrate {
			in dig = rawDigital;
			in offset = zeroOffset;
			in scale = scaleFactor;
			out pos = processedPosition;
		}
	}

	requirement def AccuracyRequirement {
		doc /* The system shall maintain position measurement accuracy within ±0.1 mm. */
		attribute maxError : Real := 0.1;
	}
	requirement def ResponseTimeRequirement {
		doc /* The system shall respond to displacement changes within 5 ms. */
		attribute maxResponseTime : DurationValue := 0.005 [s];
	}
	requirement def OperatingTemperatureRequirement {
		doc /* The system shall operate reliably from -40°C to 125°C. */
		attribute minTemp : ThermodynamicTemperatureValue := 233.15 [K];
		attribute maxTemp : ThermodynamicTemperatureValue := 398.15 [K];
	}

	part def SensingUnit {
		in displacement : LengthValue;
		out processedPosition : ProcessedPosition;

		part sensor : PotentiometricSensor {
			in displacement = SensingUnit::displacement;
		}
		part conditioner : SignalConditioner;
		part adc : ADC;
		part mcu : Microcontroller {
			out processedPosition = SensingUnit::processedPosition;
		}

		flow sensor.rawSignal to conditioner.rawSignal;
		flow conditioner.conditionedSignal to adc.conditionedSignal;
		flow adc.rawDigital to mcu.rawDigital;

		action initialize : Initialize;
		action enterLowPower : EnterLowPower;
		action exitLowPower : ExitLowPower;
		action measure : MeasurePosition;

		requirement accReq : AccuracyRequirement;
		requirement rtReq : ResponseTimeRequirement;
		requirement tempReq : OperatingTemperatureRequirement;

		exhibit state lifecycle {
			entry; then initialization;
			state initialization {
				entry initialize;
			}
			then idle;
			state idle {
				entry enterLowPower;
			}
			accept StartCmd then measuring;
			state measuring {
				entry exitLowPower;
				do measure;
			}
			accept StopCmd then idle;
			accept FaultSignal then fault;
			state fault;
			accept ResetCmd then initialization;
		}

		satisfy accReq;
		satisfy rtReq;
		satisfy tempReq;
	}
}
