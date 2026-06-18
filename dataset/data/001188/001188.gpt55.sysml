package PhototransistorBasedLightDetectionSystem {

	import ScalarValues::*;

	value type Voltage specializes Real {
		doc "Electric potential in volts."
		attribute unitSymbol: String = "V";
	}

	value type ElectricCurrent specializes Real {
		doc "Electric current in amperes."
		attribute unitSymbol: String = "A";
	}

	value type Resistance specializes Real {
		doc "Electrical resistance in ohms."
		attribute unitSymbol: String = "ohm";
	}

	value type Capacitance specializes Real {
		doc "Electrical capacitance in farads."
		attribute unitSymbol: String = "F";
	}

	value type Irradiance specializes Real {
		doc "Optical radiant power per unit area in watts per square meter."
		attribute unitSymbol: String = "W/m^2";
	}

	value type Wavelength specializes Real {
		doc "Optical wavelength in nanometers."
		attribute unitSymbol: String = "nm";
	}

	value type OpticalPower specializes Real {
		doc "Optical radiant power in watts."
		attribute unitSymbol: String = "W";
	}

	value type TimeDuration specializes Real {
		doc "Elapsed time in seconds."
		attribute unitSymbol: String = "s";
	}

	value type Frequency specializes Real {
		doc "Frequency in hertz."
		attribute unitSymbol: String = "Hz";
	}

	value type Temperature specializes Real {
		doc "Temperature in degrees Celsius."
		attribute unitSymbol: String = "degC";
	}

	value type Percent specializes Real {
		doc "Ratio expressed as percent."
		attribute unitSymbol: String = "%";
	}

	value type PhototransistorResponsivity specializes Real {
		doc "Phototransistor collector current generated per incident irradiance."
		attribute unitSymbol: "A/(W/m^2)";
	}

	enum def LightPresenceKind {
		enum dark;
		enum illuminated;
		enum saturated;
		enum unknown;
	}

	enum def SensorHealthKind {
		enum healthy;
		enum degraded;
		enum faulted;
	}

	enum def OperatingModeKind {
		enum unpowered;
		enum initializing;
		enum monitoring;
		enum reporting;
		enum faultHandling;
	}

	item def OpticalRadiation {
		attribute irradiance: Irradiance;
		attribute wavelength: Wavelength;
		attribute opticalPower: OpticalPower;
		attribute modulationFrequency: Frequency;
	}

	item def DCPower {
		attribute voltage: Voltage;
		attribute currentLimit: ElectricCurrent;
		attribute ripple: Voltage;
	}

	item def ElectricalNode {
		attribute potential: Voltage;
		attribute current: ElectricCurrent;
	}

	item def CurrentSignal {
		attribute current: ElectricCurrent;
		attribute darkCurrent: ElectricCurrent;
		attribute photocurrent: ElectricCurrent;
	}

	item def AnalogVoltageSignal {
		attribute voltage: Voltage;
		attribute noiseRms: Voltage;
		attribute bandwidth: Frequency;
	}

	item def LightMeasurement {
		attribute measuredIrradiance: Irradiance;
		attribute outputVoltage: Voltage;
		attribute lightPresence: LightPresenceKind;
		attribute confidence: Percent;
		attribute sampleAge: TimeDuration;
	}

	item def DigitalLightReport {
		attribute lightPresence: LightPresenceKind;
		attribute measuredIrradiance: Irradiance;
		attribute sensorHealth: SensorHealthKind;
		attribute valid: Boolean;
	}

	item def ControlCommand {
		attribute enable: Boolean;
		attribute resetFault: Boolean;
		attribute thresholdOverrideEnabled: Boolean;
		attribute thresholdOverride: Irradiance;
	}

	port def OpticalInputPort {
		in item incidentRadiation: OpticalRadiation;
	}

	port def OpticalOutputPort {
		out item transmittedRadiation: OpticalRadiation;
	}

	port def DCPowerInputPort {
		in item supply: DCPower;
	}

	port def ElectricalNodePort {
		inout item node: ElectricalNode;
	}

	port def CurrentOutputPort {
		out item signalCurrent: CurrentSignal;
	}

	port def CurrentInputPort {
		in item signalCurrent: CurrentSignal;
	}

	port def AnalogVoltageOutputPort {
		out item voltageSignal: AnalogVoltageSignal;
	}

	port def AnalogVoltageInputPort {
		in item voltageSignal: AnalogVoltageSignal;
	}

	port def DigitalReportOutputPort {
		out item report: DigitalLightReport;
	}

	port def CommandInputPort {
		in item command: ControlCommand;
	}

	port def GroundPort {
		inout item reference: ElectricalNode;
	}

	interface def OpticalTransmission {
		end source: OpticalInputPort;
		end destination: OpticalOutputPort;
		flow source.incidentRadiation to destination.transmittedRadiation;
	}

	interface def CurrentToVoltageTransfer {
		end source: CurrentOutputPort;
		end destination: CurrentInputPort;
		flow source.signalCurrent to destination.signalCurrent;
	}

	interface def AnalogVoltageTransfer {
		end source: AnalogVoltageOutputPort;
		end destination: AnalogVoltageInputPort;
		flow source.voltageSignal to destination.voltageSignal;
	}

	part def OpticalWindow {
		doc "Transparent mechanical and optical element that admits ambient light to the phototransistor while limiting dust and handling damage."

		attribute transmissionAt940nm: Percent = 88.0;
		attribute transmissionAt850nm: Percent = 84.0;
		attribute minimumAcceptedWavelength: Wavelength = 400.0;
		attribute maximumAcceptedWavelength: Wavelength = 1100.0;
		attribute apertureArea: Real = 12.0;
		attribute apertureAreaUnit: String = "mm^2";

		port externalLight: OpticalInputPort;
		port internalLight: OpticalOutputPort;
	}

	part def NPNPhototransistor {
		doc "Light-sensitive transistor whose collector current increases as incident optical irradiance increases."

		attribute collectorEmitterMaxVoltage: Voltage = 30.0;
		attribute nominalCollectorEmitterVoltage: Voltage = 5.0;
		attribute darkCurrentAt25C: ElectricCurrent = 100.0e-9;
		attribute peakSensitivityWavelength: Wavelength = 940.0;
		attribute spectralRangeMinimum: Wavelength = 400.0;
		attribute spectralRangeMaximum: Wavelength = 1100.0;
		attribute responsivityAtPeak: PhototransistorResponsivity = 0.00045;
		attribute riseTime: TimeDuration = 15.0e-6;
		attribute fallTime: TimeDuration = 15.0e-6;
		attribute operatingTemperatureMinimum: Temperature = -40.0;
		attribute operatingTemperatureMaximum: Temperature = 85.0;

		port opticalBase: OpticalInputPort;
		port collector: ElectricalNodePort;
		port emitter: ElectricalNodePort;
		port photocurrentOutput: CurrentOutputPort;
	}

	part def CollectorLoadBiasNetwork {
		doc "Bias circuit that converts phototransistor collector current into a measurable voltage using a pull-up load and reference ground."

		attribute loadResistance: Resistance = 10000.0;
		attribute loadTolerance: Percent = 1.0;
		attribute pullupVoltage: Voltage = 5.0;
		attribute maximumCollectorCurrent: ElectricCurrent = 500.0e-6;

		port powerIn: DCPowerInputPort;
		port collectorNode: ElectricalNodePort;
		port emitterReference: GroundPort;
		port currentSenseIn: CurrentInputPort;
		port biasedVoltageOut: AnalogVoltageOutputPort;
	}

	part def LowPassFilter {
		doc "Analog filter that attenuates high-frequency noise and optical flicker above the measurement bandwidth."

		attribute seriesResistance: Resistance = 1000.0;
		attribute shuntCapacitance: Capacitance = 100.0e-9;
		attribute cutoffFrequency: Frequency = 1591.0;
		attribute settlingTime: TimeDuration = 2.5e-3;

		port rawVoltageIn: AnalogVoltageInputPort;
		port filteredVoltageOut: AnalogVoltageOutputPort;
	}

	part def SignalConditioner {
		doc "Signal conditioning circuit that scales and clamps the phototransistor voltage for downstream conversion."

		attribute inputVoltageMinimum: Voltage = 0.0;
		attribute inputVoltageMaximum: Voltage = 5.0;
		attribute outputVoltageMinimum: Voltage = 0.0;
		attribute outputVoltageMaximum: Voltage = 3.3;
		attribute gain: Real = 0.66;
		attribute offset: Voltage = 0.0;
		attribute outputNoiseRmsMaximum: Voltage = 0.010;

		port conditionedVoltageIn: AnalogVoltageInputPort;
		port conditionedVoltageOut: AnalogVoltageOutputPort;
	}

	part def AnalogToDigitalConverter {
		doc "Converter that samples the conditioned analog voltage and makes it available to the decision logic."

		attribute referenceVoltage: Voltage = 3.3;
		attribute resolutionBits: Integer = 12;
		attribute sampleRate: Frequency = 1000.0;
		attribute conversionTime: TimeDuration = 10.0e-6;
		attribute inputImpedance: Resistance = 1000000.0;

		port analogIn: AnalogVoltageInputPort;
		port sampledVoltageOut: AnalogVoltageOutputPort;
	}

	part def LightDecisionController {
		doc "Controller behavior that estimates irradiance, compares it to thresholds, and reports whether light is present."

		attribute defaultLightDetectedThreshold: Irradiance = 8.0;
		attribute defaultSaturationThreshold: Irradiance = 950.0;
		attribute hysteresis: Irradiance = 1.0;
		attribute validMeasurementTimeout: TimeDuration = 0.100;
		attribute selfTestInterval: TimeDuration = 10.0;
		attribute mode: OperatingModeKind = OperatingModeKind::unpowered;
		attribute health: SensorHealthKind = SensorHealthKind::healthy;

		port commandIn: CommandInputPort;
		port voltageIn: AnalogVoltageInputPort;
		port digitalReportOut: DigitalReportOutputPort;
	}

	part def StatusIndicator {
		doc "Visible indicator driven by the controller to provide local light-detection status."

		attribute forwardVoltage: Voltage = 2.1;
		attribute nominalCurrent: ElectricCurrent = 5.0e-3;
		attribute onWhenIlluminated: Boolean = true;

		port reportIn: DigitalReportOutputPort;
		port powerIn: DCPowerInputPort;
		port ground: GroundPort;
	}

	part def ReferenceGround {
		doc "Common electrical reference for the phototransistor emitter, bias network, and signal electronics."

		attribute referencePotential: Voltage = 0.0;

		port groundNode: GroundPort;
	}

	part def PhototransistorLightDetectionSystem {
		doc "System based on a phototransistor. Its primary high-level function is to sense incident optical radiation and convert the light level into an electrical indication: a proportional analog voltage and a digital light-present report."

		attribute nominalSupplyVoltage: Voltage = 5.0;
		attribute allowedSupplyMinimum: Voltage = 4.75;
		attribute allowedSupplyMaximum: Voltage = 5.25;
		attribute analogOutputMinimum: Voltage = 0.0;
		attribute analogOutputMaximum: Voltage = 3.3;
		attribute detectableIrradianceMinimum: Irradiance = 0.5;
		attribute detectableIrradianceMaximum: Irradiance = 900.0;
		attribute primaryDecisionThreshold: Irradiance = 8.0;
		attribute responseTimeMaximum: TimeDuration = 0.020;
		attribute operatingTemperatureMinimum: Temperature = -20.0;
		attribute operatingTemperatureMaximum: Temperature = 70.0;

		port lightInput: OpticalInputPort;
		port powerInput: DCPowerInputPort;
		port commandInput: CommandInputPort;
		port analogLightLevelOutput: AnalogVoltageOutputPort;
		port digitalLightReportOutput: DigitalReportOutputPort;

		part opticalWindow: OpticalWindow;
		part phototransistor: NPNPhototransistor;
		part biasNetwork: CollectorLoadBiasNetwork;
		part antiNoiseFilter: LowPassFilter;
		part conditioner: SignalConditioner;
		part adc: AnalogToDigitalConverter;
		part controller: LightDecisionController;
		part indicator: StatusIndicator;
		part groundReference: ReferenceGround;

		connect lightInput to opticalWindow.externalLight;
		connect opticalWindow.internalLight to phototransistor.opticalBase;

		connect powerInput to biasNetwork.powerIn;
		connect powerInput to indicator.powerIn;

		connect phototransistor.collector to biasNetwork.collectorNode;
		connect phototransistor.emitter to groundReference.groundNode;
		connect biasNetwork.emitterReference to groundReference.groundNode;
		connect indicator.ground to groundReference.groundNode;

		connect phototransistor.photocurrentOutput to biasNetwork.currentSenseIn;
		connect biasNetwork.biasedVoltageOut to antiNoiseFilter.rawVoltageIn;
		connect antiNoiseFilter.filteredVoltageOut to conditioner.conditionedVoltageIn;
		connect conditioner.conditionedVoltageOut to adc.analogIn;
		connect conditioner.conditionedVoltageOut to analogLightLevelOutput;
		connect adc.sampledVoltageOut to controller.voltageIn;

		connect commandInput to controller.commandIn;
		connect controller.digitalReportOut to digitalLightReportOutput;
		connect controller.digitalReportOut to indicator.reportIn;
	}

	constraint def PhototransistorCurrentGeneration {
		doc "Approximates photocurrent generated by the phototransistor from incident irradiance."
		in irradiance: Irradiance;
		in darkCurrent: ElectricCurrent;
		in responsivity: PhototransistorResponsivity;
		out collectorCurrent: ElectricCurrent;
		constraint currentEquation {
			collectorCurrent == darkCurrent + irradiance * responsivity
		}
	}

	constraint def LoadVoltageGeneration {
		doc "Approximates conversion from collector current to load voltage for the pull-up bias topology."
		in supplyVoltage: Voltage;
		in collectorCurrent: ElectricCurrent;
		in loadResistance: Resistance;
		out sensedVoltage: Voltage;
		constraint voltageEquation {
			sensedVoltage == supplyVoltage - collectorCurrent * loadResistance
		}
	}

	constraint def LightDetectedDecision {
		doc "Defines high-level threshold decision for light presence."
		in measuredIrradiance: Irradiance;
		in detectedThreshold: Irradiance;
		in saturationThreshold: Irradiance;
		out presence: LightPresenceKind;
	}

	action def ConvertIncidentLightToElectricalSignal {
		doc "Primary sensing action: receive light at the aperture, generate phototransistor collector current, convert current to voltage, filter and scale it, and output analog and digital light indications."

		in item receivedLight: OpticalRadiation;
		in item electricalSupply: DCPower;
		in item command: ControlCommand;
		out item analogLevel: AnalogVoltageSignal;
		out item lightReport: DigitalLightReport;

		action admitLight {
			in item rawLight: OpticalRadiation;
			out item transmittedLight: OpticalRadiation;
		}

		action generatePhotocurrent {
			in item transmittedLight: OpticalRadiation;
			out item collectorCurrent: CurrentSignal;
		}

		action convertCurrentToVoltage {
			in item collectorCurrent: CurrentSignal;
			in item electricalSupply: DCPower;
			out item rawVoltage: AnalogVoltageSignal;
		}

		action filterVoltage {
			in item rawVoltage: AnalogVoltageSignal;
			out item filteredVoltage: AnalogVoltageSignal;
		}

		action scaleVoltage {
			in item filteredVoltage: AnalogVoltageSignal;
			out item conditionedVoltage: AnalogVoltageSignal;
		}

		action evaluateLightPresence {
			in item conditionedVoltage: AnalogVoltageSignal;
			in item command: ControlCommand;
			out item report: DigitalLightReport;
		}

		first admitLight;
		then generatePhotocurrent;
		then convertCurrentToVoltage;
		then filterVoltage;
		then scaleVoltage;
		then evaluateLightPresence;
		then done;

		flow receivedLight to admitLight.rawLight;
		flow admitLight.transmittedLight to generatePhotocurrent.transmittedLight;
		flow generatePhotocurrent.collectorCurrent to convertCurrentToVoltage.collectorCurrent;
		flow electricalSupply to convertCurrentToVoltage.electricalSupply;
		flow convertCurrentToVoltage.rawVoltage to filterVoltage.rawVoltage;
		flow filterVoltage.filteredVoltage to scaleVoltage.filteredVoltage;
		flow scaleVoltage.conditionedVoltage to evaluateLightPresence.conditionedVoltage;
		flow command to evaluateLightPresence.command;
		flow scaleVoltage.conditionedVoltage to analogLevel;
		flow evaluateLightPresence.report to lightReport;
	}

	action def PerformPhototransistorSelfTest {
		doc "Checks whether supply, dark response, saturated response, and analog output are within expected bounds."

		in item supply: DCPower;
		in item presentMeasurement: LightMeasurement;
		out item healthReport: DigitalLightReport;

		action verifySupply;
		action verifyDarkCurrentRange;
		action verifyOutputRange;
		action updateHealthStatus;

		first verifySupply;
		then verifyDarkCurrentRange;
		then verifyOutputRange;
		then updateHealthStatus;
		then done;
	}

	state def LightDetectorOperatingStates {
		doc "Operational states for the phototransistor-based light detection system."

		in item command: ControlCommand;
		in item measurement: LightMeasurement;
		out item report: DigitalLightReport;

		state unpowered {
			entry action {
				send report;
			}
		}

		state initializing {
			entry action PerformPhototransistorSelfTest;
		}

		state monitoringDark {
			entry action ConvertIncidentLightToElectricalSignal;
		}

		state monitoringIlluminated {
			entry action ConvertIncidentLightToElectricalSignal;
		}

		state saturated {
			entry action ConvertIncidentLightToElectricalSignal;
		}

		state faulted {
			entry action {
				send report;
			}
		}

		transition initialToUnpowered first start then unpowered;

		transition powerApplied
			first unpowered
			then initializing
			if command.enable;

		transition initializationCompleteDark
			first initializing
			then monitoringDark
			if measurement.lightPresence == LightPresenceKind::dark;

		transition initializationCompleteIlluminated
			first initializing
			then monitoringIlluminated
			if measurement.lightPresence == LightPresenceKind::illuminated;

		transition darkToIlluminated
			first monitoringDark
			then monitoringIlluminated
			if measurement.lightPresence == LightPresenceKind::illuminated;

		transition illuminatedToDark
			first monitoringIlluminated
			then monitoringDark
			if measurement.lightPresence == LightPresenceKind::dark;

		transition illuminatedToSaturated
			first monitoringIlluminated
			then saturated
			if measurement.lightPresence == LightPresenceKind::saturated;

		transition saturatedToIlluminated
			first saturated
			then monitoringIlluminated
			if measurement.lightPresence == LightPresenceKind::illuminated;

		transition anyFaultFromDark
			first monitoringDark
			then faulted
			if report.sensorHealth == SensorHealthKind::faulted;

		transition anyFaultFromIlluminated
			first monitoringIlluminated
			then faulted
			if report.sensorHealth == SensorHealthKind::faulted;

		transition anyFaultFromSaturated
			first saturated
			then faulted
			if report.sensorHealth == SensorHealthKind::faulted;

		transition resetFault
			first faulted
			then initializing
			if command.resetFault;

		transition disableFromDark
			first monitoringDark
			then unpowered
			if not command.enable;

		transition disableFromIlluminated
			first monitoringIlluminated
			then unpowered
			if not command.enable;

		transition disableFromSaturated
			first saturated
			then unpowered
			if not command.enable;
	}

	requirement def PrimaryFunctionRequirement {
		doc "The system shall use a phototransistor as the primary sensing element to detect incident light and provide a high-level electrical representation of light presence and light level."

		subject system: PhototransistorLightDetectionSystem;

		require constraint {
			system.detectableIrradianceMinimum <= system.primaryDecisionThreshold and
			system.primaryDecisionThreshold < system.detectableIrradianceMaximum
		}
	}

	requirement def PhototransistorBasisRequirement {
		doc "The light-sensitive element shall be a phototransistor whose collector current varies with incident optical irradiance."

		subject detector: NPNPhototransistor;

		require constraint {
			detector.responsivityAtPeak > 0.0 and
			detector.peakSensitivityWavelength >= detector.spectralRangeMinimum and
			detector.peakSensitivityWavelength <= detector.spectralRangeMaximum
		}
	}

	requirement def AnalogOutputRequirement {
		doc "The system shall provide an analog voltage output representing measured light level within the allowed output voltage range."

		subject system: PhototransistorLightDetectionSystem;

		require constraint {
			system.analogOutputMinimum == 0.0 and
			system.analogOutputMaximum == 3.3
		}
	}

	requirement def DigitalReportRequirement {
		doc "The system shall provide a digital report indicating dark, illuminated, saturated, or unknown light condition with sensor health and validity."

		subject system: PhototransistorLightDetectionSystem;
	}

	requirement def ResponseTimeRequirement {
		doc "The system shall update the light-present indication within the maximum response time after a step change in incident light."

		subject system: PhototransistorLightDetectionSystem;

		require constraint {
			system.responseTimeMaximum <= 0.020
		}
	}

	requirement def SupplyCompatibilityRequirement {
		doc "The system shall operate from a nominal 5 V DC supply over the specified tolerance range."

		subject system: PhototransistorLightDetectionSystem;

		require constraint {
			system.allowedSupplyMinimum <= system.nominalSupplyVoltage and
			system.nominalSupplyVoltage <= system.allowedSupplyMaximum
		}
	}

	part phototransistorLightDetector: PhototransistorLightDetectionSystem;

	requirement primaryFunction: PrimaryFunctionRequirement {
		subject system = phototransistorLightDetector;
	}

	requirement phototransistorBasedSensing: PhototransistorBasisRequirement {
		subject detector = phototransistorLightDetector.phototransistor;
	}

	requirement analogLightLevelOutputRequirement: AnalogOutputRequirement {
		subject system = phototransistorLightDetector;
	}

	requirement digitalLightReportRequirement: DigitalReportRequirement {
		subject system = phototransistorLightDetector;
	}

	requirement responseTimeRequirement: ResponseTimeRequirement {
		subject system = phototransistorLightDetector;
	}

	requirement supplyRequirement: SupplyCompatibilityRequirement {
		subject system = phototransistorLightDetector;
	}

	satisfy primaryFunction by phototransistorLightDetector;
	satisfy phototransistorBasedSensing by phototransistorLightDetector.phototransistor;
	satisfy analogLightLevelOutputRequirement by phototransistorLightDetector.conditioner;
	satisfy digitalLightReportRequirement by phototransistorLightDetector.controller;
	satisfy responseTimeRequirement by phototransistorLightDetector.phototransistor;
	satisfy responseTimeRequirement by phototransistorLightDetector.antiNoiseFilter;
	satisfy supplyRequirement by phototransistorLightDetector.biasNetwork;
}
