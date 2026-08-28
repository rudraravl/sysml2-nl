package IndustrialPressureSensingUnit {
	private import ISQ::PressureValue;
	private import ScalarValues::Integer;
	private import ScalarValues::Real;
	private import ScalarValues::String;

	attribute def PowerOn;
	attribute def InitComplete;
	attribute def MeasureCmd;
	attribute def FaultDetected;
	attribute def ResetCmd;

	attribute def PhysicalPressure :> PressureValue;
	attribute def RawSignal :> Real;
	attribute def ConditionedSignal :> Real;
	attribute def DigitalData :> Integer;
	attribute def CalibratedPressure :> PressureValue;

	port def PhysicalPressureIn {
		in pressure : PhysicalPressure;
	}
	port def RawSignalOut {
		out signal : RawSignal;
	}
	port def RawSignalIn {
		in signal : RawSignal;
	}
	port def CondSignalOut {
		out signal : ConditionedSignal;
	}
	port def CondSignalIn {
		in signal : ConditionedSignal;
	}
	port def CalibratedPressureOut {
		out pressure : CalibratedPressure;
	}

	part def SensingElement {
		port pressIn : PhysicalPressureIn;
		port rawOut : RawSignalOut;
		action sense {
			in p : PhysicalPressure;
			out r : RawSignal;
		}
		flow pressIn.pressure to sense.p;
		flow sense.r to rawOut.signal;
	}

	part def SignalConditioner {
		port rawIn : RawSignalIn;
		port condOut : CondSignalOut;
		action condition {
			in r : RawSignal;
			out c : ConditionedSignal;
		}
		flow rawIn.signal to condition.r;
		flow condition.c to condOut.signal;
	}

	part def PressureSensor {
		port pressIn : PhysicalPressureIn;
		port condOut : CondSignalOut;
		part sensingElement : SensingElement;
		part signalConditioner : SignalConditioner;
		flow pressIn.pressure to sensingElement.pressIn.pressure;
		flow sensingElement.rawOut.signal to signalConditioner.rawIn.signal;
		flow signalConditioner.condOut.signal to condOut.signal;
	}

	part def DataProcessor {
		port condIn : CondSignalIn;
		port dataOut : CalibratedPressureOut;
		attribute sampleRate : Real = 1000;
		attribute bufferSize : Integer = 256;
		action sample {
			in c : ConditionedSignal;
			out d : DigitalData;
		}
		action calibrate {
			in d : DigitalData;
			out p : CalibratedPressure;
		}
		flow condIn.signal to sample.c;
		flow sample.d to calibrate.d;
		flow calibrate.p to dataOut.pressure;
	}

	part def ProtectiveHousing {
		attribute material : String = "Stainless Steel";
		attribute ipRating : String = "IP67";
	}

	part def PressureSensingUnit {
		port extPressIn : PhysicalPressureIn;
		port extDataOut : CalibratedPressureOut;
		part pressureSensor : PressureSensor;
		part dataProcessor : DataProcessor;
		part housing : ProtectiveHousing;
		flow extPressIn.pressure to pressureSensor.pressIn.pressure;
		flow pressureSensor.condOut.signal to dataProcessor.condIn.signal;
		flow dataProcessor.dataOut.pressure to extDataOut.pressure;

		action measure {
			perform pressureSensor.sensingElement.sense;
			perform pressureSensor.signalConditioner.condition;
			perform dataProcessor.sample;
			perform dataProcessor.calibrate;
		}

		state lifecycle {
			entry; then off;
			state off;
			accept PowerOn then initializing;
			state initializing;
			accept InitComplete then idle;
			state idle;
			accept MeasureCmd then measuring;
			accept FaultDetected then fault;
			state measuring {
				do measure;
			}
			then idle;
			state fault;
			accept ResetCmd then idle;
		}
	}

	part def MultiSensorArray {
		part unit1 : PressureSensingUnit;
		part unit2 : PressureSensingUnit;
		part unit3 : PressureSensingUnit;
		part unit4 : PressureSensingUnit;
	}

	requirement def AccuracyReq {
		doc /* The unit shall measure pressure with an accuracy of ±0.5%. */
	}
	requirement def TempRangeReq {
		doc /* The unit shall operate in temperatures from -40°C to 85°C. */
	}
	requirement def ResponseTimeReq {
		doc /* The unit shall have a response time less than 10 ms. */
	}
	requirement def HousingReq {
		doc /* The housing shall provide IP67 water and dust resistance. */
	}

	requirement def PressureSensingUnitRequirements {
		requirement accuracy : AccuracyReq;
		requirement tempRange : TempRangeReq;
		requirement responseTime : ResponseTimeReq;
		requirement housing : HousingReq;
	}

	part sensingUnit : PressureSensingUnit {
		satisfy req : PressureSensingUnitRequirements;
	}
}
