package 'Brake Fluid Pressure Sensing Unit' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	attribute def PressureValue :> ISQ::PressureValue;
	attribute def VoltageValue :> ISQ::ElectricPotentialValue;
	attribute def TemperatureValue :> ISQ::ThermodynamicTemperatureValue;
	attribute def FrequencyValue :> ISQ::FrequencyValue;
	attribute def TimeValue :> ISQ::DurationValue;

	item def BrakeFluid {
		attribute pressure : PressureValue;
		attribute temperature : TemperatureValue;
		attribute viscosity : Real;
	}

	item def AnalogSignal {
		attribute voltage : VoltageValue;
		attribute timestamp : TimeValue;
	}

	item def DigitalData {
		attribute pressureReading : PressureValue;
		attribute sensorStatus : SensorStatusType;
		attribute timestamp : TimeValue;
	}

	enum def SensorStatusType {
		enum normal;
		enum degraded;
		enum fault;
		enum calibrating;
	}

	port def FluidInterfacePort {
		in item fluid : BrakeFluid;
	}

	port def AnalogOutputPort {
		out item signal : AnalogSignal;
	}

	port def DigitalOutputPort {
		out item data : DigitalData;
	}

	port def PowerPort {
		in supplyVoltage : VoltageValue;
	}

	calc def PressureToVoltageConversion {
		in pressure : PressureValue;
		in sensitivity : Real;
		in offset : VoltageValue;
		return outputVoltage : VoltageValue = (pressure * sensitivity + offset);
	}

	calc def TemperatureCompensation {
		in rawPressure : PressureValue;
		in temperature : TemperatureValue;
		in compensationFactor : Real;
		in referenceTemp : TemperatureValue;
		return compensatedPressure : PressureValue = 
			(rawPressure * (1.0 + compensationFactor * (temperature - referenceTemp)));
	}

	action def SensePressure {
		in item fluidInput : BrakeFluid;
		out rawPressure : PressureValue;
	}

	action def CompensateForTemperature {
		in rawPressure : PressureValue;
		in temperature : TemperatureValue;
		out compensatedPressure : PressureValue;
	}

	action def ConvertToAnalog {
		in pressure : PressureValue;
		out analogVoltage : VoltageValue;
	}

	action def DigitizeSignal {
		in analogVoltage : VoltageValue;
		out digitalReading : PressureValue;
	}

	action def ValidateReading {
		in reading : PressureValue;
		in temperature : TemperatureValue;
		out isValid : Boolean;
		out status : SensorStatusType;
	}

	action def MeasurementCycle {
		in item brakeFluid : BrakeFluid;
		out item digitalOutput : DigitalData;

		action sense : SensePressure {
			in item :>> fluidInput = brakeFluid;
			out :>> rawPressure;
		}

		then action compensate : CompensateForTemperature {
			in :>> rawPressure;
			in :>> temperature = brakeFluid.temperature;
			out :>> compensatedPressure;
		}

		flow from sense.rawPressure to compensate.rawPressure;

		then action validate : ValidateReading {
			in :>> reading;
			in :>> temperature = brakeFluid.temperature;
			out :>> isValid;
			out :>> status;
		}

		flow from compensate.compensatedPressure to validate.reading;

		then action convert : ConvertToAnalog {
			in :>> pressure;
			out :>> analogVoltage;
		}

		flow from compensate.compensatedPressure to convert.pressure;

		then action digitize : DigitizeSignal {
			in :>> analogVoltage;
			out :>> digitalReading;
		}

		flow from convert.analogVoltage to digitize.analogVoltage;

		bind digitalOutput.pressureReading = digitize.digitalReading;
		bind digitalOutput.sensorStatus = validate.status;
	}

	state def SensorOperationalState {
		entry; then initialization;

		state initialization;
		accept CalibrationComplete then operational;

		state operational;
		accept ErrorDetected then faulted;
		accept OutOfRange then degradedOperation;

		state degradedOperation;
		accept ReturnToNormal then operational;
		accept ErrorDetected then faulted;

		state faulted;
		accept ResetCommand then initialization;
	}

	event CalibrationComplete;
	event ErrorDetected;
	event OutOfRange;
	event ReturnToNormal;
	event ResetCommand;

	part def SensingElement {
		attribute sensitivity : Real = 0.0004;
		attribute offset : VoltageValue = 0.5[V];
		attribute operatingRangeMin : PressureValue = 0.0[Pa];
		attribute operatingRangeMax : PressureValue = 20.0[MPa];

		perform action sense : SensePressure;
	}

	part def TemperatureCompensationUnit {
		attribute compensationFactor : Real = 0.0003;
		attribute referenceTemperature : TemperatureValue = 298.15[K];

		perform action compensate : CompensateForTemperature;
	}

	part def SignalConditioningCircuit {
		attribute gain : Real = 1000.0;
		attribute filterCutoffFrequency : FrequencyValue = 500.0[Hz];

		perform action convert : ConvertToAnalog;
	}

	part def AnalogToDigitalConverter {
		attribute resolution : Integer = 16;
		attribute samplingRate : FrequencyValue = 1000.0[Hz];
		attribute referenceVoltage : VoltageValue = 5.0[V];

		perform action digitize : DigitizeSignal;
	}

	part def DiagnosticController {
		attribute currentStatus : SensorStatusType;
		attribute errorCount : Integer = 0;
		attribute operatingHours : Real = 0.0;

		perform action validate : ValidateReading;
	}

	part def BrakeFluidPressureSensor {
		attribute sensorID : String;
		attribute calibrationDate : String;
		attribute nominalSupplyVoltage : VoltageValue = 12.0[V];
		attribute currentStatus : SensorStatusType = SensorStatusType::normal;

		port fluidInput : FluidInterfacePort;
		port analogOutput : AnalogOutputPort;
		port digitalOutput : DigitalOutputPort;
		port powerInput : PowerPort;

		part sensingElement : SensingElement {
			attribute :>> sensitivity = 0.0004;
			attribute :>> offset = 0.5[V];
			attribute :>> operatingRangeMin = 0.0[Pa];
			attribute :>> operatingRangeMax = 20.0[MPa];
		}

		part tempCompensator : TemperatureCompensationUnit {
			attribute :>> compensationFactor = 0.0003;
			attribute :>> referenceTemperature = 298.15[K];
		}

		part signalConditioner : SignalConditioningCircuit {
			attribute :>> gain = 1000.0;
			attribute :>> filterCutoffFrequency = 500.0[Hz];
		}

		part adc : AnalogToDigitalConverter {
			attribute :>> resolution = 16;
			attribute :>> samplingRate = 1000.0[Hz];
			attribute :>> referenceVoltage = 5.0[V];
		}

		part diagnostics : DiagnosticController {
			attribute :>> currentStatus = currentStatus;
		}

		perform action measurementCycle : MeasurementCycle {
			in item :>> brakeFluid = fluidInput.fluid;
			out item :>> digitalOutput = digitalOutput.data;
		}

		exhibit state operationalBehavior : SensorOperationalState;

		connection fluidConnection connect fluidInput.fluid to sensingElement;
		connection analogConnection connect signalConditioner to analogOutput.signal;
		connection digitalConnection connect adc to digitalOutput.data;
	}

	requirement def AccuracyRequirement {
		doc /* The sensor shall measure brake fluid pressure with accuracy within ±1% of full scale. */
		subject sensor : BrakeFluidPressureSensor;
		attribute maxError : Real = 0.01;
	}

	requirement def RangeRequirement {
		doc /* The sensor shall measure brake fluid pressure from 0 to 20 MPa. */
		subject sensor : BrakeFluidPressureSensor;
	}

	requirement def ResponseTimeRequirement {
		doc /* The sensor shall provide pressure reading within 5 milliseconds. */
		subject sensor : BrakeFluidPressureSensor;
		attribute maxResponseTime : TimeValue = 0.005[s];
	}

	requirement def TemperatureRangeRequirement {
		doc /* The sensor shall operate over temperature range -40°C to +125°C. */
		subject sensor : BrakeFluidPressureSensor;
		attribute minTemp : TemperatureValue = 233.15[K];
		attribute maxTemp : TemperatureValue = 398.15[K];
	}

	requirement def DiagnosticCapabilityRequirement {
		doc /* The sensor shall provide continuous diagnostic status information. */
		subject sensor : BrakeFluidPressureSensor;
	}

	part sensingUnit : BrakeFluidPressureSensor {
		attribute :>> sensorID = "BFP-2025-001";
		attribute :>> calibrationDate = "2025-01-15";

		satisfy accuracyReq : AccuracyRequirement {
			subject sensor = sensingUnit;
		}

		satisfy rangeReq : RangeRequirement {
			subject sensor = sensingUnit;
		}

		satisfy responseReq : ResponseTimeRequirement {
			subject sensor = sensingUnit;
		}

		satisfy tempRangeReq : TemperatureRangeRequirement {
			subject sensor = sensingUnit;
		}

		satisfy diagnosticReq : DiagnosticCapabilityRequirement {
			subject sensor = sensingUnit;
		}
	}
}
