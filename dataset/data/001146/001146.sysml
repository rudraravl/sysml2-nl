package MicrowaveChemistrySensingSystem {
	private import ScalarValues::*;
	private import ScalarFunctions::*;
	private import ISQ::*;
	private import SI::*;
	private import UnitsAndScales::*;
	private import Quantities::*;
	
	comment about MicrowaveChemistrySensingUnit
	/* This model describes a microwave chemistry sensing unit that measures
	 * chemical composition and concentration by analyzing microwave absorption
	 * and reflection patterns. The system uses resonant cavity techniques to
	 * detect dielectric properties of chemical samples, which correlate with
	 * molecular structure and concentration.
	 */
	
	attribute def PermittivityUnit :> SimpleUnit {
		attribute :>> unitPowerFactor[1] {
			attribute :>> unit = PermittivityUnit::self;
			attribute :>> exponent = 1;
		}
	}
	
	attribute def ConductivityUnit :> MeasurementUnit {
		attribute :>> unitPowerFactor : UnitPowerFactor[3] ordered {
			[1] { attribute :>> unit = SI::A; attribute :>> exponent = 1; }
			[2] { attribute :>> unit = SI::V; attribute :>> exponent = -1; }
			[3] { attribute :>> unit = SI::m; attribute :>> exponent = -1; }
		}
	}
	
	attribute def ConcentrationUnit :> MeasurementUnit {
		attribute :>> unitPowerFactor : UnitPowerFactor[2] ordered {
			[1] { attribute :>> unit = SI::mol; attribute :>> exponent = 1; }
			[2] { attribute :>> unit = SI::L; attribute :>> exponent = -1; }
		}
	}
	
	attribute def PermittivityValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : PermittivityUnit;
	}
	
	attribute def ConductivityValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : ConductivityUnit;
	}
	
	attribute def ConcentrationValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : ConcentrationUnit;
	}
	
	item def ChemicalSample {
		attribute sampleId : String;
		attribute volume : VolumeValue;
		attribute temperature : TemperatureValue;
		attribute relativePermittivity : PermittivityValue;
		attribute conductivity : ConductivityValue;
		attribute concentration : ConcentrationValue;
	}
	
	item def MicrowaveSignal {
		attribute frequency : FrequencyValue;
		attribute power : PowerValue;
		attribute phase : Real;
		attribute amplitude : Real;
	}
	
	item def MeasurementData {
		attribute timestamp : Real;
		attribute reflectionCoefficient : Real;
		attribute transmissionCoefficient : Real;
		attribute phaseShift : Real;
		attribute resonantFrequency : FrequencyValue;
		attribute qualityFactor : Real;
	}
	
	item def ProcessedResult {
		attribute measuredPermittivity : PermittivityValue;
		attribute measuredConductivity : ConductivityValue;
		attribute calculatedConcentration : ConcentrationValue;
		attribute measurementUncertainty : Real;
		attribute validMeasurement : Boolean;
	}
	
	port def SampleInputPort {
		in item sample : ChemicalSample;
	}
	
	port def MicrowaveTransmitPort {
		out item transmitSignal : MicrowaveSignal;
	}
	
	port def MicrowaveReceivePort {
		in item receivedSignal : MicrowaveSignal;
	}
	
	port def DataOutputPort {
		out item result : ProcessedResult;
	}
	
	port def ControlPort {
		in attribute targetFrequency : FrequencyValue;
		in attribute targetPower : PowerValue;
		in attribute calibrationMode : Boolean;
		out attribute systemStatus : String;
	}
	
	part def MicrowaveSource {
		attribute operatingFrequency : FrequencyValue;
		attribute outputPower : PowerValue;
		attribute frequencyStability : Real;
		
		port transmitPort : MicrowaveTransmitPort;
		port controlInput : ControlPort;
		
		action generateMicrowave {
			in targetFreq : FrequencyValue;
			in targetPwr : PowerValue;
			out signal : MicrowaveSignal;
			
			bind signal.frequency = targetFreq;
			bind signal.power = targetPwr;
		}
	}
	
	part def ResonantCavity {
		attribute cavityLength : LengthValue;
		attribute cavityDiameter : LengthValue;
		attribute cavityVolume : VolumeValue;
		attribute unloadedQuality : Real;
		attribute resonantFrequency : FrequencyValue;
		
		port microwaveIn : MicrowaveReceivePort;
		port microwaveOut : MicrowaveTransmitPort;
		port samplePort : SampleInputPort;
		
		action interactWithSample {
			in incidentSignal : MicrowaveSignal;
			in sample : ChemicalSample;
			out reflectedSignal : MicrowaveSignal;
			out transmittedSignal : MicrowaveSignal;
			out resonanceShift : FrequencyValue;
		}
	}
	
	part def MicrowaveDetector {
		attribute sensitivity : PowerValue;
		attribute dynamicRange : Real;
		attribute detectionBandwidth : FrequencyValue;
		
		port receivePort : MicrowaveReceivePort;
		port dataOut : DataOutputPort;
		
		action detectSignal {
			in receivedSignal : MicrowaveSignal;
			out rawData : MeasurementData;
		}
	}
	
	part def SignalAnalyzer {
		attribute samplingRate : FrequencyValue;
		attribute resolution : Real;
		attribute processingDelay : TimeValue;
		
		port dataIn : DataOutputPort;
		port dataOut : DataOutputPort;
		
		action analyzeMeasurement {
			in rawData : MeasurementData;
			in sample : ChemicalSample;
			out permittivity : PermittivityValue;
			out conductivity : ConductivityValue;
		}
	}
	
	part def ConcentrationCalculator {
		attribute calibrationCurve : Real[10];
		attribute algorithmVersion : String;
		
		port dataIn : DataOutputPort;
		port resultOut : DataOutputPort;
		
		action calculateConcentration {
			in permittivity : PermittivityValue;
			in conductivity : ConductivityValue;
			in temperature : TemperatureValue;
			out concentration : ConcentrationValue;
			out uncertainty : Real;
		}
	}
	
	part def TemperatureController {
		attribute setpoint : TemperatureValue;
		attribute tolerance : TemperatureValue;
		attribute controlGain : Real;
		
		port sampleInterface : SampleInputPort;
		
		action maintainTemperature {
			in currentTemp : TemperatureValue;
			in targetTemp : TemperatureValue;
			out heatingPower : PowerValue;
		}
	}
	
	connection def MicrowaveConnection {
		end source : MicrowaveTransmitPort;
		end target : MicrowaveReceivePort;
	}
	
	connection def DataConnection {
		end source : DataOutputPort;
		end target : DataOutputPort;
	}
	
	part MicrowaveChemistrySensingUnit {
		attribute operatingFrequencyRange : FrequencyValue[2];
		attribute measurementRange : ConcentrationValue[2];
		attribute measurementAccuracy : Real;
		attribute responseTime : TimeValue;
		
		part microwaveGenerator : MicrowaveSource[1] {
			attribute :>> operatingFrequency = 2.45e9[Hz];
			attribute :>> outputPower = 50.0[W];
			attribute :>> frequencyStability = 1.0e-6;
		}
		
		part resonator : ResonantCavity[1] {
			attribute :>> cavityLength = 0.05[m];
			attribute :>> cavityDiameter = 0.03[m];
			attribute :>> cavityVolume = 3.534e-5[m^3];
			attribute :>> unloadedQuality = 5000.0;
			attribute :>> resonantFrequency = 2.45e9[Hz];
		}
		
		part reflectionDetector : MicrowaveDetector[1] {
			attribute :>> sensitivity = 1.0e-9[W];
			attribute :>> dynamicRange = 80.0;
			attribute :>> detectionBandwidth = 1.0e8[Hz];
		}
		
		part transmissionDetector : MicrowaveDetector[1] {
			attribute :>> sensitivity = 1.0e-9[W];
			attribute :>> dynamicRange = 80.0;
			attribute :>> detectionBandwidth = 1.0e8[Hz];
		}
		
		part analyzer : SignalAnalyzer[1] {
			attribute :>> samplingRate = 1.0e6[Hz];
			attribute :>> resolution = 16.0;
			attribute :>> processingDelay = 0.01[s];
		}
		
		part calculator : ConcentrationCalculator[1] {
			attribute :>> algorithmVersion = "v2.1";
		}
		
		part tempController : TemperatureController[1] {
			attribute :>> setpoint = 298.15[K];
			attribute :>> tolerance = 0.1[K];
			attribute :>> controlGain = 2.5;
		}
		
		connection sourceToResonator : MicrowaveConnection
			connect microwaveGenerator.transmitPort to resonator.microwaveIn;
		
		connection resonatorToReflection : MicrowaveConnection
			connect resonator.microwaveOut to reflectionDetector.receivePort;
		
		connection resonatorToTransmission : MicrowaveConnection
			connect resonator.microwaveOut to transmissionDetector.receivePort;
		
		connection reflectionToAnalyzer : DataConnection
			connect reflectionDetector.dataOut to analyzer.dataIn;
		
		connection analyzerToCalculator : DataConnection
			connect analyzer.dataOut to calculator.dataIn;
		
		port sampleInput : SampleInputPort;
		port measurementOutput : DataOutputPort;
		port systemControl : ControlPort;
		
		connect sampleInput to resonator.samplePort;
		connect sampleInput to tempController.sampleInterface;
		connect systemControl to microwaveGenerator.controlInput;
		connect calculator.resultOut to measurementOutput;
	}
	
	action def PerformMeasurementCycle {
		in sample : ChemicalSample;
		in targetFreq : FrequencyValue;
		in targetPwr : PowerValue;
		out finalResult : ProcessedResult;
		
		action stabilizeTemperature {
			in sample : ChemicalSample;
			in setpoint : TemperatureValue;
			out stabilized : Boolean;
		}
		then generateSignal;
		
		action generateSignal {
			in frequency : FrequencyValue;
			in power : PowerValue;
			out microwaveSignal : MicrowaveSignal;
		}
		then interactWithSample;
		
		action interactWithSample {
			in signal : MicrowaveSignal;
			in chemSample : ChemicalSample;
			out reflected : MicrowaveSignal;
			out transmitted : MicrowaveSignal;
		}
		then fork;
		
		then detectReflection;
		then detectTransmission;
		
		action detectReflection {
			in reflectedSignal : MicrowaveSignal;
			out reflectionData : MeasurementData;
		}
		then joinNode;
		
		action detectTransmission {
			in transmittedSignal : MicrowaveSignal;
			out transmissionData : MeasurementData;
		}
		then joinNode;
		
		join joinNode;
		then analyzeData;
		
		action analyzeData {
			in reflectionData : MeasurementData;
			in transmissionData : MeasurementData;
			in sample : ChemicalSample;
			out permittivity : PermittivityValue;
			out conductivity : ConductivityValue;
		}
		then calculateConcentration;
		
		action calculateConcentration {
			in permittivity : PermittivityValue;
			in conductivity : ConductivityValue;
			in temperature : TemperatureValue;
			out concentration : ConcentrationValue;
			out uncertainty : Real;
		}
		then validateResult;
		
		action validateResult {
			in concentration : ConcentrationValue;
			in uncertainty : Real;
			out result : ProcessedResult;
		}
		then done;
		
		flow from generateSignal.microwaveSignal to interactWithSample.signal;
		flow from interactWithSample.reflected to detectReflection.reflectedSignal;
		flow from interactWithSample.transmitted to detectTransmission.transmittedSignal;
		flow from detectReflection.reflectionData to analyzeData.reflectionData;
		flow from detectTransmission.transmissionData to analyzeData.transmissionData;
		flow from analyzeData.permittivity to calculateConcentration.permittivity;
		flow from analyzeData.conductivity to calculateConcentration.conductivity;
		flow from calculateConcentration.concentration to validateResult.concentration;
		flow from calculateConcentration.uncertainty to validateResult.uncertainty;
		flow from validateResult.result to finalResult;
		
		bind stabilizeTemperature.sample = sample;
		bind interactWithSample.chemSample = sample;
		bind analyzeData.sample = sample;
		bind calculateConcentration.temperature = sample.temperature;
		bind generateSignal.frequency = targetFreq;
		bind generateSignal.power = targetPwr;
	}
	
	state def SensorOperationalStates {
		entry; then idle;
		
		state idle;
		
		transition idleToInitializing
			first idle
			accept StartupCommand
			then initializing;
		
		state initializing;
		
		transition initializingToCalibrating
			first initializing
			if systemCheckPassed
			then calibrating;
		
		state calibrating;
		
		transition calibratingToReady
			first calibrating
			if calibrationComplete
			then ready;
		
		state ready;
		
		transition readyToStabilizing
			first ready
			accept MeasurementRequest
			then stabilizing;
		
		state stabilizing;
		
		transition stabilizingToMeasuring
			first stabilizing
			if temperatureStable
			then measuring;
		
		state measuring;
		
		transition measuringToProcessing
			first measuring
			if dataAcquired
			then processing;
		
		state processing;
		
		transition processingToReady
			first processing
			if processingComplete
			then ready;
		
		transition readyToIdle
			first ready
			accept ShutdownCommand
			then idle;
		
		transition errorTransition
			first measuring
			accept ErrorDetected
			then error;
		
		state error;
		
		transition errorToIdle
			first error
			accept ResetCommand
			then idle;
	}
	
	requirement def MeasurementAccuracyRequirement {
		doc /* The sensing unit shall measure chemical concentration with accuracy better than 2% of reading */
		subject sensingUnit : MicrowaveChemistrySensingUnit;
		require constraint {
			sensingUnit.measurementAccuracy <= 0.02
		}
	}
	
	requirement def FrequencyStabilityRequirement {
		doc /* The microwave source shall maintain frequency stability better than 1 ppm */
		subject sensingUnit : MicrowaveChemistrySensingUnit;
		require constraint {
			sensingUnit.microwaveGenerator.frequencyStability <= 1.0e-6
		}
	}
	
	requirement def TemperatureControlRequirement {
		doc /* The system shall maintain sample temperature within 0.1 K of setpoint */
		subject sensingUnit : MicrowaveChemistrySensingUnit;
		require constraint {
			sensingUnit.tempController.tolerance.num <= 0.1
		}
	}
	
	requirement def ResponseTimeRequirement {
		doc /* The sensing unit shall complete a measurement cycle within 5 seconds */
		subject sensingUnit : MicrowaveChemistrySensingUnit;
		require constraint {
			sensingUnit.responseTime.num <= 5.0
		}
	}
	
	requirement def DynamicRangeRequirement {
		doc /* The detector shall provide minimum 80 dB dynamic range */
		subject sensingUnit : MicrowaveChemistrySensingUnit;
		require constraint {
			sensingUnit.reflectionDetector.dynamicRange >= 80.0 and
			sensingUnit.transmissionDetector.dynamicRange >= 80.0
		}
	}
	
	requirement def SensitivityRequirement {
		doc /* The detector shall detect signals as low as 1 nW */
		subject sensingUnit : MicrowaveChemistrySensingUnit;
		require constraint {
			sensingUnit.reflectionDetector.sensitivity.num <= 1.0e-9
		}
	}
	
	requirement SystemRequirements {
		doc /* Top-level requirements for microwave chemistry sensing unit */
		subject system : MicrowaveChemistrySensingUnit;
		
		requirement accuracyReq : MeasurementAccuracyRequirement;
		requirement frequencyReq : FrequencyStabilityRequirement;
		requirement temperatureReq : TemperatureControlRequirement;
		requirement responseReq : ResponseTimeRequirement;
		requirement dynamicRangeReq : DynamicRangeRequirement;
		requirement sensitivityReq : SensitivityRequirement;
	}
	
	part sensingUnitInstance : MicrowaveChemistrySensingUnit {
		attribute :>> operatingFrequencyRange = (2.4e9[Hz], 2.5e9[Hz]);
		attribute :>> measurementAccuracy = 0.015;
		attribute :>> responseTime = 3.5[s];
		
		part :>> microwaveGenerator {
			attribute :>> operatingFrequency = 2.45e9[Hz];
			attribute :>> outputPower = 50.0[W];
			attribute :>> frequencyStability = 5.0e-7;
		}
		
		part :>> resonator {
			attribute :>> cavityLength = 0.05[m];
			attribute :>> cavityDiameter = 0.03[m];
			attribute :>> unloadedQuality = 6000.0;
			attribute :>> resonantFrequency = 2.45e9[Hz];
		}
		
		part :>> reflectionDetector {
			attribute :>> sensitivity = 5.0e-10[W];
			attribute :>> dynamicRange = 90.0;
		}
		
		part :>> transmissionDetector {
			attribute :>> sensitivity = 5.0e-10[W];
			attribute :>> dynamicRange = 90.0;
		}
		
		part :>> analyzer {
			attribute :>> samplingRate = 2.0e6[Hz];
			attribute :>> resolution = 24.0;
			attribute :>> processingDelay = 0.005[s];
		}
		
		part :>> tempController {
			attribute :>> setpoint = 298.15[K];
			attribute :>> tolerance = 0.05[K];
			attribute :>> controlGain = 3.0;
		}
	}
	
	dependency from sensingUnitInstance to SystemRequirements;
}
