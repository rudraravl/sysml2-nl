package StretchSensorSensingUnitModel {
	private import ScalarValues::*;

	attribute def Voltage :> Real {
		attribute unitSymbol: String = "V";
	}

	attribute def Current :> Real {
		attribute unitSymbol: String = "A";
	}

	attribute def Resistance :> Real {
		attribute unitSymbol: String = "ohm";
	}

	attribute def Length :> Real {
		attribute unitSymbol: String = "m";
	}

	attribute def Strain :> Real {
		attribute unitSymbol: String = "m/m";
	}

	attribute def Time :> Real {
		attribute unitSymbol: String = "s";
	}

	attribute def Frequency :> Real {
		attribute unitSymbol: String = "Hz";
	}

	attribute def Temperature :> Real {
		attribute unitSymbol: String = "degC";
	}

	attribute def Ratio :> Real {
		attribute unitSymbol: String = "1";
	}

	attribute def GaugeFactor :> Real {
		attribute unitSymbol: String = "1";
	}

	attribute def DigitalCount :> Real {
		attribute unitSymbol: String = "count";
	}

	attribute def Percent :> Real {
		attribute unitSymbol: String = "%";
	}

	enum def DiagnosticSeverity {
		enum normal;
		enum warning;
		enum fault;
	}

	enum def ControllerCommandKind {
		enum startMeasurement;
		enum stopMeasurement;
		enum zeroCalibration;
		enum resetFault;
		enum enterLowPower;
	}

	item def MechanicalStretch {
		attribute referenceLength: Length;
		attribute elongation: Length;
		attribute strain: Strain;
		attribute temperature: Temperature;
		attribute timeStamp: Time;
	}

	item def ElectricPower {
		attribute voltage: Voltage;
		attribute current: Current;
		attribute ripple: Voltage;
		attribute timeStamp: Time;
	}

	item def RegulatedPower :> ElectricPower {
		attribute regulationError: Percent;
	}

	item def StretchResistanceSignal {
		attribute resistance: Resistance;
		attribute resistanceChange: Resistance;
		attribute excitationVoltage: Voltage;
		attribute temperature: Temperature;
		attribute timeStamp: Time;
	}

	item def AnalogVoltageSignal {
		attribute voltage: Voltage;
		attribute commonModeVoltage: Voltage;
		attribute noiseRms: Voltage;
		attribute bandwidth: Frequency;
		attribute timeStamp: Time;
	}

	item def RawAdcSample {
		attribute counts: DigitalCount;
		attribute resolutionCounts: DigitalCount;
		attribute referenceVoltage: Voltage;
		attribute samplePeriod: Time;
		attribute timeStamp: Time;
	}

	item def StretchMeasurement {
		attribute strain: Strain;
		attribute elongation: Length;
		attribute referenceLength: Length;
		attribute accuracy: Strain;
		attribute sampleRate: Frequency;
		attribute valid: Boolean;
		attribute timeStamp: Time;
	}

	item def DiagnosticMessage {
		attribute severity: DiagnosticSeverity;
		attribute code: Integer;
		attribute message: String;
		attribute timeStamp: Time;
	}

	item def ControllerCommand {
		attribute kind: ControllerCommandKind;
		attribute requestedSampleRate: Frequency;
		attribute timeStamp: Time;
	}

	port def StretchInputPort {
		in item stretch: MechanicalStretch;
	}

	port def PowerInputPort {
		in item power: ElectricPower;
	}

	port def PowerOutputPort {
		out item power: RegulatedPower;
	}

	port def ResistiveSensorOutputPort {
		out item signal: StretchResistanceSignal;
	}

	port def ResistiveSensorInputPort {
		in item signal: StretchResistanceSignal;
	}

	port def AnalogOutputPort {
		out item signal: AnalogVoltageSignal;
	}

	port def AnalogInputPort {
		in item signal: AnalogVoltageSignal;
	}

	port def DigitalSampleOutputPort {
		out item sample: RawAdcSample;
	}

	port def DigitalSampleInputPort {
		in item sample: RawAdcSample;
	}

	port def MeasurementOutputPort {
		out item measurement: StretchMeasurement;
	}

	port def MeasurementInputPort {
		in item measurement: StretchMeasurement;
	}

	port def DiagnosticOutputPort {
		out item diagnostic: DiagnosticMessage;
	}

	port def CommandInputPort {
		in item command: ControllerCommand;
	}

	connection def PowerHarness {
		end source: PowerOutputPort;
		end load: PowerInputPort;
	}

	connection def StretchMechanicalCoupling {
		end specimen: StretchInputPort;
		end sensor: StretchInputPort;
	}

	connection def ResistanceSignalWiring {
		end sensorOutput: ResistiveSensorOutputPort;
		end conditionerInput: ResistiveSensorInputPort;
	}

	connection def AnalogSignalTrace {
		end source: AnalogOutputPort;
		end sink: AnalogInputPort;
	}

	connection def DigitalSampleBus {
		end source: DigitalSampleOutputPort;
		end sink: DigitalSampleInputPort;
	}

	constraint def StrainGeometryLaw {
		in deltaLength: Length;
		in referenceLength: Length;
		out computedStrain: Strain;
		constraint strainEquation {
			computedStrain == deltaLength / referenceLength;
		}
	}

	constraint def StretchSensorResistanceLaw {
		in nominalResistance: Resistance;
		in gaugeFactor: GaugeFactor;
		in strain: Strain;
		out resistanceChange: Resistance;
		out resistance: Resistance;
		constraint resistanceChangeEquation {
			resistanceChange == nominalResistance * gaugeFactor * strain;
		}
		constraint resistanceEquation {
			resistance == nominalResistance + resistanceChange;
		}
	}

	constraint def QuarterBridgeVoltageLaw {
		in excitation: Voltage;
		in gaugeFactor: GaugeFactor;
		in strain: Strain;
		out bridgeVoltage: Voltage;
		constraint bridgeEquation {
			bridgeVoltage == excitation * gaugeFactor * strain / 4.0;
		}
	}

	constraint def AdcConversionLaw {
		in analogVoltage: Voltage;
		in referenceVoltage: Voltage;
		in resolutionCounts: DigitalCount;
		out counts: DigitalCount;
		constraint conversionEquation {
			counts == analogVoltage * resolutionCounts / referenceVoltage;
		}
	}

	action def ConvertCountsToVoltage {
		in item sample: RawAdcSample;
		out item voltageSignal: AnalogVoltageSignal;
		constraint conversion {
			voltageSignal.voltage == sample.referenceVoltage * sample.counts / sample.resolutionCounts;
		}
		constraint timePropagation {
			voltageSignal.timeStamp == sample.timeStamp;
		}
	}

	action def LowPassFilterVoltage {
		in item voltageSignal: AnalogVoltageSignal;
		in cutoffFrequency: Frequency;
		out item filteredVoltage: AnalogVoltageSignal;
		constraint bandwidthLimit {
			filteredVoltage.bandwidth == cutoffFrequency;
		}
		constraint timePropagation {
			filteredVoltage.timeStamp == voltageSignal.timeStamp;
		}
	}

	action def EstimateStretchFromVoltage {
		in item filteredVoltage: AnalogVoltageSignal;
		in excitationVoltage: Voltage;
		in gaugeFactor: GaugeFactor;
		in referenceLength: Length;
		out item measurement: StretchMeasurement;
		constraint strainEstimate {
			measurement.strain == 4.0 * filteredVoltage.voltage / (excitationVoltage * gaugeFactor);
		}
		constraint elongationEstimate {
			measurement.elongation == measurement.strain * referenceLength;
		}
		constraint referenceLengthPropagation {
			measurement.referenceLength == referenceLength;
		}
		constraint timePropagation {
			measurement.timeStamp == filteredVoltage.timeStamp;
		}
	}

	action def ValidateMeasurement {
		in item candidate: StretchMeasurement;
		in minimumStrain: Strain;
		in maximumStrain: Strain;
		in maximumError: Strain;
		out item validated: StretchMeasurement;
		constraint accuracyLimit {
			validated.accuracy <= maximumError;
		}
		constraint lowerRange {
			validated.strain >= minimumStrain;
		}
		constraint upperRange {
			validated.strain <= maximumStrain;
		}
		constraint dataPropagation {
			validated.strain == candidate.strain;
		}
	}

	action def AcquireComputeAndPublishStretch {
		in item rawSample: RawAdcSample;
		in excitationVoltage: Voltage;
		in gaugeFactor: GaugeFactor;
		in referenceLength: Length;
		in minimumStrain: Strain;
		in maximumStrain: Strain;
		in maximumError: Strain;
		out item measurement: StretchMeasurement;

		action conversion: ConvertCountsToVoltage;
		action filtering: LowPassFilterVoltage;
		action estimation: EstimateStretchFromVoltage;
		action validation: ValidateMeasurement;

		flow rawSample to conversion.sample;
		flow conversion.voltageSignal to filtering.voltageSignal;
		flow filtering.filteredVoltage to estimation.filteredVoltage;
		flow estimation.measurement to validation.candidate;
		flow validation.validated to measurement;
	}

	state def StretchSensingLifecycle {
		state off;
		state powerStabilizing;
		state selfTesting;
		state zeroCalibrating;
		state ready;
		state measuring;
		state lowPower;
		state fault;

		transition initialPowerOn first off then powerStabilizing;
		transition regulationStable first powerStabilizing then selfTesting;
		transition selfTestPassed first selfTesting then zeroCalibrating;
		transition zeroComplete first zeroCalibrating then ready;
		transition measurementStarted first ready then measuring;
		transition sampleAccepted first measuring then measuring;
		transition measurementStopped first measuring then ready;
		transition lowPowerRequested first ready then lowPower;
		transition wakeRequested first lowPower then ready;
		transition faultDetectedFromSelfTest first selfTesting then fault;
		transition faultDetectedFromMeasurement first measuring then fault;
		transition resetAfterFault first fault then selfTesting;
		transition powerRemoved first ready then off;
	}

	part def StretchSensorElement {
		port stretchInput: StretchInputPort;
		port excitationInput: PowerInputPort;
		port variableResistanceOutput: ResistiveSensorOutputPort;

		attribute nominalResistance: Resistance = 10000.0;
		attribute gaugeFactor: GaugeFactor = 2.10;
		attribute referenceLength: Length = 0.080;
		attribute maximumStrain: Strain = 0.300;
		attribute minimumStrain: Strain = -0.050;
		attribute operatingTemperatureMin: Temperature = -20.0;
		attribute operatingTemperatureMax: Temperature = 70.0;

		constraint geometry: StrainGeometryLaw;
		constraint resistanceResponse: StretchSensorResistanceLaw;
	}

	part def PowerRegulator {
		port sourceInput: PowerInputPort;
		port logicSupply: PowerOutputPort;
		port sensorExcitation: PowerOutputPort;

		attribute inputVoltageMin: Voltage = 4.5;
		attribute inputVoltageMax: Voltage = 5.5;
		attribute logicVoltage: Voltage = 3.3;
		attribute excitationVoltage: Voltage = 3.3;
		attribute maxOutputCurrent: Current = 0.050;
		attribute maxRipple: Voltage = 0.005;
		attribute regulationAccuracy: Percent = 1.0;
	}

	part def WheatstoneBridgeAndAmplifier {
		port sensorInput: ResistiveSensorInputPort;
		port excitationInput: PowerInputPort;
		port conditionedVoltage: AnalogOutputPort;

		attribute bridgeCompletionResistance: Resistance = 10000.0;
		attribute instrumentationGain: Ratio = 80.0;
		attribute offsetVoltage: Voltage = 1.65;
		attribute bandwidth: Frequency = 50.0;
		attribute inputReferredNoise: Voltage = 0.000010;

		constraint bridgeLaw: QuarterBridgeVoltageLaw;
	}

	part def AnalogToDigitalConverter {
		port analogInput: AnalogInputPort;
		port digitalOutput: DigitalSampleOutputPort;
		port powerInput: PowerInputPort;

		attribute resolutionCounts: DigitalCount = 4096.0;
		attribute referenceVoltage: Voltage = 3.3;
		attribute sampleRate: Frequency = 100.0;
		attribute conversionTime: Time = 0.000020;

		constraint conversionLaw: AdcConversionLaw;
	}

	part def MeasurementController {
		port sampleInput: DigitalSampleInputPort;
		port commandInput: CommandInputPort;
		port measurementOutput: MeasurementOutputPort;
		port diagnosticOutput: DiagnosticOutputPort;
		port powerInput: PowerInputPort;

		attribute commandedSampleRate: Frequency = 50.0;
		attribute filterCutoffFrequency: Frequency = 10.0;
		attribute maximumAllowedError: Strain = 0.005;
		attribute minimumAllowedStrain: Strain = -0.050;
		attribute maximumAllowedStrain: Strain = 0.300;
		attribute zeroOffsetVoltage: Voltage = 1.65;
		attribute selfTestResistanceMin: Resistance = 9500.0;
		attribute selfTestResistanceMax: Resistance = 10500.0;

		state lifecycle: StretchSensingLifecycle;
		action measurementAlgorithm: AcquireComputeAndPublishStretch;
	}

	part def CommunicationsInterface {
		port measurementInput: MeasurementInputPort;
		port diagnosticInput: DiagnosticOutputPort;
		port externalMeasurementOutput: MeasurementOutputPort;
		port externalDiagnosticOutput: DiagnosticOutputPort;
		port powerInput: PowerInputPort;

		attribute updateRate: Frequency = 50.0;
		attribute frameLatency: Time = 0.010;
	}

	part def StretchSensingUnit {
		port mechanicalInput: StretchInputPort;
		port powerInput: PowerInputPort;
		port commandInput: CommandInputPort;
		port measurementOutput: MeasurementOutputPort;
		port diagnosticOutput: DiagnosticOutputPort;

		part regulator: PowerRegulator;
		part installedSensor: StretchSensorElement;
		part signalConditioner: WheatstoneBridgeAndAmplifier;
		part adc: AnalogToDigitalConverter;
		part controller: MeasurementController;
		part communications: CommunicationsInterface;

		attribute supplyVoltageNominal: Voltage = 5.0;
		attribute outputSampleRate: Frequency = 50.0;
		attribute measurementRangeMin: Strain = -0.050;
		attribute measurementRangeMax: Strain = 0.300;
		attribute maximumStrainError: Strain = 0.005;
		attribute startupTime: Time = 0.500;
		attribute operatingTemperatureMin: Temperature = -20.0;
		attribute operatingTemperatureMax: Temperature = 70.0;

		connect powerInput to regulator.sourceInput;
		connect regulator.logicSupply to adc.powerInput;
		connect regulator.logicSupply to controller.powerInput;
		connect regulator.logicSupply to communications.powerInput;
		connect regulator.sensorExcitation to installedSensor.excitationInput;
		connect regulator.sensorExcitation to signalConditioner.excitationInput;

		connect mechanicalInput to installedSensor.stretchInput;
		connect installedSensor.variableResistanceOutput to signalConditioner.sensorInput;
		connect signalConditioner.conditionedVoltage to adc.analogInput;
		connect adc.digitalOutput to controller.sampleInput;
		connect commandInput to controller.commandInput;
		connect controller.measurementOutput to communications.measurementInput;
		connect controller.diagnosticOutput to communications.diagnosticInput;
		connect communications.externalMeasurementOutput to measurementOutput;
		connect communications.externalDiagnosticOutput to diagnosticOutput;
	}

	requirement def StretchSensorUseRequirement {
		subject unit: StretchSensingUnit;
		require constraint sensorExists {
			unit.installedSensor.nominalResistance > 0.0;
		}
		require constraint usesStretchSensor {
			unit.installedSensor.gaugeFactor > 1.0;
		}
	}

	requirement def StretchMeasurementRangeRequirement {
		subject unit: StretchSensingUnit;
		require constraint lowerRange {
			unit.measurementRangeMin <= -0.050;
		}
		require constraint upperRange {
			unit.measurementRangeMax >= 0.300;
		}
	}

	requirement def StretchMeasurementAccuracyRequirement {
		subject unit: StretchSensingUnit;
		require constraint errorLimit {
			unit.maximumStrainError <= 0.005;
		}
	}

	requirement def StretchSamplingRequirement {
		subject unit: StretchSensingUnit;
		require constraint sampleRateLimit {
			unit.outputSampleRate >= 50.0;
		}
		require constraint startupLimit {
			unit.startupTime <= 0.500;
		}
	}

	part sensingUnit: StretchSensingUnit;

	requirement stretchSensorUse: StretchSensorUseRequirement {
		subject unit = sensingUnit;
	}

	requirement stretchMeasurementRange: StretchMeasurementRangeRequirement {
		subject unit = sensingUnit;
	}

	requirement stretchMeasurementAccuracy: StretchMeasurementAccuracyRequirement {
		subject unit = sensingUnit;
	}

	requirement stretchSampling: StretchSamplingRequirement {
		subject unit = sensingUnit;
	}
}
