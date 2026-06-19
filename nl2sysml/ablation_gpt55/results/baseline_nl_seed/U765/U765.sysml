package MagneticSensingUnitModel {
	import ScalarValues::*;

	enum def SensorKind {
		enum magnetic;
		enum optical;
		enum thermal;
		enum inertial;
	}

	enum def MeasurementQuality {
		enum valid;
		enum saturated;
		enum belowRange;
		enum aboveRange;
		enum sensorFault;
		enum stale;
	}

	enum def HealthState {
		enum healthy;
		enum degraded;
		enum failed;
	}

	enum def CommandKind {
		enum powerOn;
		enum initialize;
		enum startSampling;
		enum stopSampling;
		enum calibrateZero;
		enum resetFault;
	}

	attribute def MagneticFluxDensity {
		attribute value : Real;
		attribute unitSymbol : String = "T";
	}

	attribute def ElectricPotential {
		attribute value : Real;
		attribute unitSymbol : String = "V";
	}

	attribute def TimeInstant {
		attribute value : Real;
		attribute unitSymbol : String = "s";
	}

	attribute def SampleRate {
		attribute value : Real;
		attribute unitSymbol : String = "Hz";
	}

	attribute def Temperature {
		attribute value : Real;
		attribute unitSymbol : String = "degC";
	}

	attribute def Percent {
		attribute value : Real;
		attribute unitSymbol : String = "%";
	}

	attribute def DimensionlessRatio {
		attribute value : Real;
		attribute unitSymbol : String = "1";
	}

	attribute def DigitalCount {
		attribute value : Integer;
		attribute unitSymbol : String = "count";
	}

	attribute def DirectionVector {
		attribute x : Real;
		attribute y : Real;
		attribute z : Real;
	}

	item def MagneticField {
		attribute fluxDensity : MagneticFluxDensity;
		attribute direction : DirectionVector;
		attribute ambientTemperature : Temperature;
		attribute timeOfField : TimeInstant;
	}

	item def AnalogVoltageSignal {
		attribute voltage : ElectricPotential;
		attribute signalTime : TimeInstant;
		attribute noiseRatio : DimensionlessRatio;
	}

	item def ConditionedVoltageSignal {
		attribute voltage : ElectricPotential;
		attribute signalTime : TimeInstant;
		attribute gainApplied : DimensionlessRatio;
		attribute offsetRemoved : ElectricPotential;
	}

	item def DigitalSensorSample {
		attribute count : DigitalCount;
		attribute sampleTime : TimeInstant;
		attribute converterReference : ElectricPotential;
	}

	item def MagneticMeasurement {
		attribute measuredFluxDensity : MagneticFluxDensity;
		attribute measurementTime : TimeInstant;
		attribute quality : MeasurementQuality;
		attribute estimatedError : MagneticFluxDensity;
	}

	item def SensorCommand {
		attribute command : CommandKind;
		attribute requestedSampleRate : SampleRate;
		attribute commandTime : TimeInstant;
	}

	item def SensorStatus {
		attribute health : HealthState;
		attribute saturation : Boolean;
		attribute latestTemperature : Temperature;
		attribute statusTime : TimeInstant;
	}

	port def MagneticFieldInputPort {
		in item field : MagneticField;
	}

	port def MagneticFieldOutputPort {
		out item field : MagneticField;
	}

	port def AnalogVoltageInputPort {
		in item analogSignal : AnalogVoltageSignal;
	}

	port def AnalogVoltageOutputPort {
		out item analogSignal : AnalogVoltageSignal;
	}

	port def ConditionedVoltageInputPort {
		in item conditionedSignal : ConditionedVoltageSignal;
	}

	port def ConditionedVoltageOutputPort {
		out item conditionedSignal : ConditionedVoltageSignal;
	}

	port def DigitalSampleInputPort {
		in item digitalSample : DigitalSensorSample;
	}

	port def DigitalSampleOutputPort {
		out item digitalSample : DigitalSensorSample;
	}

	port def MagneticMeasurementInputPort {
		in item measurement : MagneticMeasurement;
	}

	port def MagneticMeasurementOutputPort {
		out item measurement : MagneticMeasurement;
	}

	port def SensorCommandInputPort {
		in item command : SensorCommand;
	}

	port def SensorCommandOutputPort {
		out item command : SensorCommand;
	}

	port def SensorStatusInputPort {
		in item status : SensorStatus;
	}

	port def SensorStatusOutputPort {
		out item status : SensorStatus;
	}

	action def SenseMagneticField {
		in item field : MagneticField;
		out item rawSignal : AnalogVoltageSignal;
	}

	action def ConditionAnalogSignal {
		in item rawSignal : AnalogVoltageSignal;
		out item conditionedSignal : ConditionedVoltageSignal;
	}

	action def DigitizeConditionedSignal {
		in item conditionedSignal : ConditionedVoltageSignal;
		out item digitalSample : DigitalSensorSample;
	}

	action def ComputeMagneticMeasurement {
		in item digitalSample : DigitalSensorSample;
		out item measurement : MagneticMeasurement;
	}

	action def PublishMagneticMeasurement {
		in item measurement : MagneticMeasurement;
		out item publishedMeasurement : MagneticMeasurement;
	}

	action def AcquireMagneticMeasurement {
		in item sensedField : MagneticField;
		out item reportedMeasurement : MagneticMeasurement;

		action sense : SenseMagneticField;
		action condition : ConditionAnalogSignal;
		action digitize : DigitizeConditionedSignal;
		action compute : ComputeMagneticMeasurement;
		action publish : PublishMagneticMeasurement;

		flow sensedField to sense.field;
		flow sense.rawSignal to condition.rawSignal;
		flow condition.conditionedSignal to digitize.conditionedSignal;
		flow digitize.digitalSample to compute.digitalSample;
		flow compute.measurement to publish.measurement;
		flow publish.publishedMeasurement to reportedMeasurement;
	}

	state def SensorElementStates {
		entry; then unpowered;

		state unpowered;
		state initializing;
		state biasCalibrating;
		state sensing;
		state saturated;
		state faulted;

		transition powerOn
			first unpowered
			then initializing;

		transition initializeComplete
			first initializing
			then biasCalibrating;

		transition calibrationComplete
			first biasCalibrating
			then sensing;

		transition saturationDetected
			first sensing
			then saturated;

		transition saturationCleared
			first saturated
			then sensing;

		transition faultDetected
			first sensing
			then faulted;

		transition resetFromFault
			first faulted
			then initializing;
	}

	state def ControllerStates {
		entry; then off;

		state off;
		state configuring;
		state idle;
		state sampling;
		state reporting;
		state faultHandling;

		transition commandedOn
			first off
			then configuring;

		transition configurationComplete
			first configuring
			then idle;

		transition samplingStarted
			first idle
			then sampling;

		transition sampleComputed
			first sampling
			then reporting;

		transition reportComplete
			first reporting
			then sampling;

		transition samplingStopped
			first sampling
			then idle;

		transition controllerFault
			first sampling
			then faultHandling;

		transition controllerReset
			first faultHandling
			then configuring;
	}

	part def MagneticSensor {
		attribute kind : SensorKind = SensorKind::magnetic;
		attribute health : HealthState = HealthState::healthy;

		attribute lowerRange : MagneticFluxDensity {
			:>> value = -0.012;
		}

		attribute upperRange : MagneticFluxDensity {
			:>> value = 0.012;
		}

		attribute sensitivity : ElectricPotential {
			:>> value = 0.200;
		}

		attribute zeroFieldOffset : ElectricPotential {
			:>> value = 2.500;
		}

		attribute maximumLinearityError : Percent {
			:>> value = 0.5;
		}

		attribute operatingTemperature : Temperature {
			:>> value = 25.0;
		}

		port fieldIn : MagneticFieldInputPort;
		port commandIn : SensorCommandInputPort;
		port rawSignalOut : AnalogVoltageOutputPort;
		port statusOut : SensorStatusOutputPort;

		perform action sensing : SenseMagneticField;
		exhibit state behavior : SensorElementStates;
	}

	part def SignalConditioner {
		attribute gain : DimensionlessRatio {
			:>> value = 2.0;
		}

		attribute lowPassCornerFrequency : SampleRate {
			:>> value = 500.0;
		}

		attribute outputOffset : ElectricPotential {
			:>> value = 0.0;
		}

		port rawSignalIn : AnalogVoltageInputPort;
		port conditionedSignalOut : ConditionedVoltageOutputPort;

		perform action conditioning : ConditionAnalogSignal;
	}

	part def AnalogToDigitalConverter {
		attribute resolution : DigitalCount {
			:>> value = 4096;
		}

		attribute referenceVoltage : ElectricPotential {
			:>> value = 3.300;
		}

		attribute conversionRate : SampleRate {
			:>> value = 1000.0;
		}

		port conditionedSignalIn : ConditionedVoltageInputPort;
		port digitalSampleOut : DigitalSampleOutputPort;

		perform action digitizing : DigitizeConditionedSignal;
	}

	part def MeasurementController {
		attribute configuredSampleRate : SampleRate {
			:>> value = 100.0;
		}

		attribute maximumAllowedError : MagneticFluxDensity {
			:>> value = 0.000050;
		}

		attribute latestMeasurement : MagneticMeasurement;
		attribute latestStatus : SensorStatus;

		port digitalSampleIn : DigitalSampleInputPort;
		port sensorStatusIn : SensorStatusInputPort;
		port sensorCommandOut : SensorCommandOutputPort;
		port measurementOut : MagneticMeasurementOutputPort;

		perform action computation : ComputeMagneticMeasurement;
		perform action publication : PublishMagneticMeasurement;
		exhibit state controllerBehavior : ControllerStates;
	}

	part def SensingUnit {
		attribute relevantQuantityName : String = "magnetic flux density";
		attribute minimumMeasurableFluxDensity : MagneticFluxDensity {
			:>> value = -0.012;
		}

		attribute maximumMeasurableFluxDensity : MagneticFluxDensity {
			:>> value = 0.012;
		}

		attribute specifiedAccuracy : MagneticFluxDensity {
			:>> value = 0.000050;
		}

		attribute outputSampleRate : SampleRate {
			:>> value = 100.0;
		}

		port magneticFieldIn : MagneticFieldInputPort;
		port measurementOut : MagneticMeasurementOutputPort;

		part magneticSensor : MagneticSensor;
		part signalConditioner : SignalConditioner;
		part converter : AnalogToDigitalConverter;
		part controller : MeasurementController;

		connection appliedFieldToSensor connect magneticFieldIn to magneticSensor.fieldIn;
		connection rawSignalToConditioner connect magneticSensor.rawSignalOut to signalConditioner.rawSignalIn;
		connection conditionedSignalToConverter connect signalConditioner.conditionedSignalOut to converter.conditionedSignalIn;
		connection digitalSampleToController connect converter.digitalSampleOut to controller.digitalSampleIn;
		connection commandToSensor connect controller.sensorCommandOut to magneticSensor.commandIn;
		connection statusToController connect magneticSensor.statusOut to controller.sensorStatusIn;
		connection measurementToUnitOutput connect controller.measurementOut to measurementOut;

		perform action acquisition : AcquireMagneticMeasurement;
	}

	part def MagneticFieldSource {
		attribute nominalField : MagneticFluxDensity {
			:>> value = 0.001500;
		}

		attribute fieldDirection : DirectionVector {
			:>> x = 0.0;
			:>> y = 0.0;
			:>> z = 1.0;
		}

		attribute sourceTemperature : Temperature {
			:>> value = 25.0;
		}

		port fieldOut : MagneticFieldOutputPort;
	}

	part def MeasurementConsumer {
		attribute requiredInputRate : SampleRate {
			:>> value = 100.0;
		}

		port measurementIn : MagneticMeasurementInputPort;
	}

	part def MagneticSensingSystem {
		part fieldSource : MagneticFieldSource;
		part sensingUnit : SensingUnit;
		part consumer : MeasurementConsumer;

		connection sourceToSensingUnit connect fieldSource.fieldOut to sensingUnit.magneticFieldIn;
		connection sensingUnitToConsumer connect sensingUnit.measurementOut to consumer.measurementIn;
	}

	requirement def UseMagneticSensorRequirement {
		subject unit : SensingUnit;

		require constraint {
			unit.magneticSensor.kind == SensorKind::magnetic
		}
	}

	requirement def MeasureRelevantQuantityRequirement {
		subject unit : SensingUnit;

		require constraint {
			unit.relevantQuantityName == "magnetic flux density"
		}

		require constraint {
			unit.outputSampleRate.value >= 100.0
		}
	}

	requirement def MeasurementRangeRequirement {
		subject unit : SensingUnit;

		require constraint {
			unit.minimumMeasurableFluxDensity.value <= -0.010
		}

		require constraint {
			unit.maximumMeasurableFluxDensity.value >= 0.010
		}
	}

	requirement def MeasurementAccuracyRequirement {
		subject unit : SensingUnit;

		require constraint {
			unit.specifiedAccuracy.value <= 0.000050
		}
	}

	requirement magneticSensorRequirement : UseMagneticSensorRequirement {
		subject unit : SensingUnit;
	}

	requirement relevantQuantityRequirement : MeasureRelevantQuantityRequirement {
		subject unit : SensingUnit;
	}

	requirement rangeRequirement : MeasurementRangeRequirement {
		subject unit : SensingUnit;
	}

	requirement accuracyRequirement : MeasurementAccuracyRequirement {
		subject unit : SensingUnit;
	}

	part magneticSensingSystem : MagneticSensingSystem;
}
