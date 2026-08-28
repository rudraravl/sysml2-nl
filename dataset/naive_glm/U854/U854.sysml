package ResistanceThermometerSystem {

	import ScalarValues::*;
	import ISQ::*;
	import ISQTemperature::*;
	import ISQElectromagnetism::*;
	import ISQSpaceTime::*;

	// ---- Value types with units ----
	
	value def TemperatureValue :> RealValue {
	private attr unit = "°C";
	}
	
	value def ResistanceValue :> RealValue {
	private attr unit = "Ω";
	}
	
	value def CurrentValue :> RealValue {
	private attr unit = "A";
	}
	
	value def VoltageValue :> RealValue {
	private attr unit = "V";
	}
	
	value def TimeValue :> RealValue {
	private attr unit = "s";
	}
	
	value def AccuracyValue :> RealValue {
	private attr unit = "°C";
	}
	
	// ---- Item types ----
	
	item def ExcitationCurrent {
	attr magnitude : CurrentValue;
	}
	
	item def RawVoltageSignal {
	attr magnitude : VoltageValue;
	}
	
	item def ConditionedSignal {
	attr voltage : VoltageValue;
	attr resistance : ResistanceValue;
	}
	
	item def TemperatureReading {
	attr temperature : TemperatureValue;
	attr timestamp : TimeValue;
	attr accuracy : AccuracyValue;
	}
	
	// ---- Port definitions ----
	
	port def CurrentPort {
	out excitationCurrent : ExcitationCurrent;
	}
	
	port def VoltagePort {
	out rawVoltage : RawVoltageSignal;
	}
	
	port def ConditionedSignalPort {
	out conditionedSignal : ConditionedSignal;
	}
	
	port def ReadingPort {
	out reading : TemperatureReading;
	}
	
	// ---- Requirements ----
	
	requirement def HighAccuracy {
	doc /* The thermometer shall measure temperature with high accuracy. */
	subject :>> thermometerSystem;
	require constraint { thermometerSystem.measurementAccuracy <= 0.5 [TemperatureValue] }
	}
	
	requirement def FastResponseTime {
	doc /* The thermometer shall complete a measurement cycle in under two seconds. */
	subject :>> thermometerSystem;
	require constraint { thermometerSystem.responseTime < 2.0 [TimeValue] }
	}
	
	requirement def WideTemperatureRange {
	doc /* The thermometer shall operate from -200°C to 850°C. */
	subject :>> thermometerSystem;
	require constraint { thermometerSystem.minOperatingTemp >= -200 [TemperatureValue] and thermometerSystem.maxOperatingTemp <= 850 [TemperatureValue] }
	}
	
	requirement def ThermometerRequirements {
	require highAccuracy : HighAccuracy;
	require fastResponse : FastResponseTime;
	require wideRange : WideTemperatureRange;
	}
	
	// ---- Component part definitions ----
	
	part def ExcitationSource {
	attr outputCurrent : CurrentValue = 0.001 [CurrentValue]; // 1 mA constant current
	port currentOut : CurrentPort;
	
	action def GenerateCurrent {
	out current : ExcitationCurrent;
	}
	
	action generateCurrent : GenerateCurrent {
	assign current.magnitude = outputCurrent;
	}
	
	connection currentFlow from generateCurrent.current to currentOut.excitationCurrent;
	}
	
	part def RTDSensor {
	attr nominalResistance : ResistanceValue = 100.0 [ResistanceValue]; // Pt100
	attr temperatureCoefficient : Real = 0.00385; // per °C
	attr ambientTemperature : TemperatureValue;
	
	port currentIn : CurrentPort;
	port voltageOut : VoltagePort;
	
	action def SenseTemperature {
	in current : ExcitationCurrent;
	out voltage : RawVoltageSignal;
	}
	
	action sense : SenseTemperature {
	in current = currentIn.excitationCurrent;
	out voltage;
	
	assign voltage.magnitude {
	// Compute resistance from temperature: R = R0 * (1 + α * T)
	// Then voltage: V = I * R
	val resistance = nominalResistance * (1.0 + temperatureCoefficient * ambientTemperature);
	result = currentIn.excitationCurrent.magnitude * resistance;
	}
	}
	
	connection senseFlow from sense.voltage to voltageOut.rawVoltage;
	}
	
	part def SignalConditioner {
	attr gain : Real = 100.0;
	attr filterCutoff : Real = 10.0; // Hz
	
	port signalIn : VoltagePort;
	port signalOut : ConditionedSignalPort;
	
	action def ConditionSignal {
	in raw : RawVoltageSignal;
	out conditioned : ConditionedSignal;
	}
	
	action condition : ConditionSignal {
	in raw = signalIn.rawVoltage;
	out conditioned;
	
	assign conditioned.voltage {
	result = raw.magnitude * gain;
	}
	
	assign conditioned.resistance {
	// Derive resistance from amplified voltage and known excitation current
	val excitationCurrent = 0.001 [CurrentValue];
	result = (raw.magnitude * gain) / excitationCurrent;
	}
	}
	
	connection conditionFlow from condition.conditioned to signalOut.conditionedSignal;
	}
	
	part def TemperatureConverter {
	attr calibrationCoefficient : Real = 0.00385;
	attr referenceResistance : ResistanceValue = 100.0 [ResistanceValue];
	
	port signalIn : ConditionedSignalPort;
	port readingOut : ReadingPort;
	
	action def ConvertToTemperature {
	in signal : ConditionedSignal;
	out reading : TemperatureReading;
	}
	
	action convert : ConvertToTemperature {
	in signal = signalIn.conditionedSignal;
	out reading;
	
	assign reading.temperature {
	// Inverse of R = R0 * (1 + α * T) => T = (R/R0 - 1) / α
	result = (signal.resistance / referenceResistance - 1.0) / calibrationCoefficient;
	}
	
	assign reading.timestamp {
	result = 0.0 [TimeValue];
	}
	
	assign reading.accuracy {
	result = 0.2 [AccuracyValue];
	}
	}
	
	connection convertFlow from convert.reading to readingOut.reading;
	}
	
	part def Display {
	port readingIn : ReadingPort;
	
	attr displayedTemperature : TemperatureValue;
	attr displayedTimestamp : TimeValue;
	attr displayedAccuracy : AccuracyValue;
	
	action def ShowReading {
	in reading : TemperatureReading;
	}
	
	action show : ShowReading {
	in reading = readingIn.reading;
	
	assign displayedTemperature = reading.temperature;
	assign displayedTimestamp = reading.timestamp;
	assign displayedAccuracy = reading.accuracy;
	}
	}
	
	// ---- Top-level system ----
	
	part def ResistanceThermometer {
	attr measurementAccuracy : AccuracyValue = 0.2 [AccuracyValue];
	attr responseTime : TimeValue = 1.5 [TimeValue];
	attr minOperatingTemp : TemperatureValue = -200 [TemperatureValue];
	attr maxOperatingTemp : TemperatureValue = 850 [TemperatureValue];
	
	part excitationSource : ExcitationSource;
	part rtdSensor : RTDSensor;
	part signalConditioner : SignalConditioner;
	part temperatureConverter : TemperatureConverter;
	part display : Display;
	
	connection excitationToSensor from excitationSource.currentOut to rtdSensor.currentIn;
	connection sensorToConditioner from rtdSensor.voltageOut to signalConditioner.signalIn;
	connection conditionerToConverter from signalConditioner.signalOut to temperatureConverter.signalIn;
	connection converterToDisplay from temperatureConverter.readingOut to display.readingIn;
	
	satisfy ThermometerRequirements by this;
	
	// ---- State machine behavior ----
	
	enum def ThermometerState {
	enum idle;
	enum sensing;
	enum converting;
	enum displaying;
	}
	
	state def ThermometerOperation {
	
	state idle {
	entry action {
	// Reset for next measurement cycle
	}
	}
	
	state sensing {
	entry action {
	excitationSource.generateCurrent();
	rtdSensor.sense();
	}
	}
	
	state converting {
	entry action {
	signalConditioner.condition();
	temperatureConverter.convert();
	}
	}
	
	state displaying {
	entry action {
	display.show();
	}
	}
	
	transition idle_to_sensing first idle if true to sensing;
	transition sensing_to_converting first sensing if true to converting;
	transition converting_to_displaying first converting if true to displaying;
	transition displaying_to_idle first displaying if true to idle;
	}
	
	state operation : ThermometerOperation;
	}
	
}</think>package ResistanceThermometerSystem {

	import ScalarValues::*;
	import ISQ::*;
	import ISQTemperature::*;
	import ISQElectromagnetism::*;
	import ISQSpaceTime::*;

	// ---- Value types with units ----

	value def TemperatureValue :> RealValue {
		private attr unit = "°C";
	}

	value def ResistanceValue :> RealValue {
		private attr unit = "Ω";
	}

	value def CurrentValue :> RealValue {
		private attr unit = "A";
	}

	value def VoltageValue :> RealValue {
		private attr unit = "V";
	}

	value def TimeValue :> RealValue {
		private attr unit = "s";
	}

	value def AccuracyValue :> RealValue {
		private attr unit = "°C";
	}

	// ---- Item types ----

	item def ExcitationCurrent {
		attr magnitude : CurrentValue;
	}

	item def RawVoltageSignal {
		attr magnitude : VoltageValue;
	}

	item def ConditionedSignal {
		attr voltage : VoltageValue;
		attr resistance : ResistanceValue;
	}

	item def TemperatureReading {
		attr temperature : TemperatureValue;
		attr timestamp : TimeValue;
		attr accuracy : AccuracyValue;
	}

	// ---- Port definitions ----

	port def CurrentPort {
		out excitationCurrent : ExcitationCurrent;
	}

	port def VoltagePort {
		out rawVoltage : RawVoltageSignal;
	}

	port def ConditionedSignalPort {
		out conditionedSignal : ConditionedSignal;
	}

	port def ReadingPort {
		out reading : TemperatureReading;
	}

	// ---- Requirements ----

	requirement def HighAccuracy {
		doc /* The thermometer shall measure temperature with high accuracy. */
		subject :>> thermometerSystem;
		require constraint { thermometerSystem.measurementAccuracy <= 0.5 [TemperatureValue] }
	}

	requirement def FastResponseTime {
		doc /* The thermometer shall complete a measurement cycle in under two seconds. */
		subject :>> thermometerSystem;
		require constraint { thermometerSystem.responseTime < 2.0 [TimeValue] }
	}

	requirement def WideTemperatureRange {
		doc /* The thermometer shall operate from -200°C to 850°C. */
		subject :>> thermometerSystem;
		require constraint { thermometerSystem.minOperatingTemp >= -200 [TemperatureValue] and thermometerSystem.maxOperatingTemp <= 850 [TemperatureValue] }
	}

	requirement def ThermometerRequirements {
		require highAccuracy : HighAccuracy;
		require fastResponse : FastResponseTime;
		require wideRange : WideTemperatureRange;
	}

	// ---- Component part definitions ----

	part def ExcitationSource {
		attr outputCurrent : CurrentValue = 0.001 [CurrentValue];
		port currentOut : CurrentPort;

		action def GenerateCurrent {
			out current : ExcitationCurrent;
		}

		action generateCurrent : GenerateCurrent {
			assign current.magnitude = outputCurrent;
		}

		connection currentFlow from generateCurrent.current to currentOut.excitationCurrent;
	}

	part def RTDSensor {
		attr nominalResistance : ResistanceValue = 100.0 [ResistanceValue];
		attr temperatureCoefficient : Real = 0.00385;
		attr ambientTemperature : TemperatureValue;
		port currentIn : CurrentPort;
		port voltageOut : VoltagePort;

		action def SenseTemperature {
			in current : ExcitationCurrent;
			out voltage : RawVoltageSignal;
		}

		action sense : SenseTemperature {
			in current = currentIn.excitationCurrent;
			out voltage;
			assign voltage.magnitude {
				val resistance = nominalResistance * (1.0 + temperatureCoefficient * ambientTemperature);
				result = currentIn.excitationCurrent.magnitude * resistance;
			}
		}

		connection senseFlow from sense.voltage to voltageOut.rawVoltage;
	}

	part def SignalConditioner {
		attr gain : Real = 100.0;
		attr filterCutoff : Real = 10.0;
		port signalIn : VoltagePort;
		port signalOut : ConditionedSignalPort;

		action def ConditionSignal {
			in raw : RawVoltageSignal;
			out conditioned : ConditionedSignal;
		}

		action condition : ConditionSignal {
			in raw = signalIn.rawVoltage;
			out conditioned;
			assign conditioned.voltage {
				result = raw.magnitude * gain;
			}
			assign conditioned.resistance {
				val excitationCurrent = 0.001 [CurrentValue];
				result = (raw.magnitude * gain) / excitationCurrent;
			}
		}

		connection conditionFlow from condition.conditioned to signalOut.conditionedSignal;
	}

	part def TemperatureConverter {
		attr calibrationCoefficient : Real = 0.00385;
		attr referenceResistance : ResistanceValue = 100.0 [ResistanceValue];
		port signalIn : ConditionedSignalPort;
		port readingOut : ReadingPort;

		action def ConvertToTemperature {
			in signal : ConditionedSignal;
			out reading : TemperatureReading;
		}

		action convert : ConvertToTemperature {
			in signal = signalIn.conditionedSignal;
			out reading;
			assign reading.temperature {
				result = (signal.resistance / referenceResistance - 1.0) / calibrationCoefficient;
			}
			assign reading.timestamp {
				result = 0.0 [TimeValue];
			}
			assign reading.accuracy {
				result = 0.2 [AccuracyValue];
			}
		}

		connection convertFlow from convert.reading to readingOut.reading;
	}

	part def Display {
		port readingIn : ReadingPort;
		attr displayedTemperature : TemperatureValue;
		attr displayedTimestamp : TimeValue;
		attr displayedAccuracy : AccuracyValue;

		action def ShowReading {
			in reading : TemperatureReading;
		}

		action show : ShowReading {
			in reading = readingIn.reading;
			assign displayedTemperature = reading.temperature;
			assign displayedTimestamp = reading.timestamp;
			assign displayedAccuracy = reading.accuracy;
		}
	}

	// ---- Top-level system ----

	part def ResistanceThermometer {
		attr measurementAccuracy : AccuracyValue = 0.2 [AccuracyValue];
		attr responseTime : TimeValue = 1.5 [TimeValue];
		attr minOperatingTemp : TemperatureValue = -200 [TemperatureValue];
		attr maxOperatingTemp : TemperatureValue = 850 [TemperatureValue];

		part excitationSource : ExcitationSource;
		part rtdSensor : RTDSensor;
		part signalConditioner : SignalConditioner;
		part temperatureConverter : TemperatureConverter;
		part display : Display;

		connection excitationToSensor from excitationSource.currentOut to rtdSensor.currentIn;
		connection sensorToConditioner from rtdSensor.voltageOut to signalConditioner.signalIn;
		connection conditionerToConverter from signalConditioner.signalOut to temperatureConverter.signalIn;
		connection converterToDisplay from temperatureConverter.readingOut to display.readingIn;

		satisfy ThermometerRequirements by this;

		enum def ThermometerState {
			enum idle;
			enum sensing;
			enum converting;
			enum displaying;
		}

		state def ThermometerOperation {

			state idle {
				entry action {
				}
			}

			state sensing {
				entry action {
					excitationSource.generateCurrent();
					rtdSensor.sense();
				}
			}

			state converting {
				entry action {
					signalConditioner.condition();
					temperatureConverter.convert();
				}
			}

			state displaying {
				entry action {
					display.show();
				}
			}

			transition idle_to_sensing first idle if true to sensing;
			transition sensing_to_converting first sensing if true to converting;
			transition converting_to_displaying first converting if true to displaying;
			transition displaying_to_idle first displaying if true to idle;
		}

		state operation : ThermometerOperation;
	}

}
