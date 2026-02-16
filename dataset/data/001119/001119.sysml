package LightAddressablePotentiometricSensingUnit {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import Quantities::*;
	private import MeasurementReferences::*;
	
	attribute def VoltageValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : VoltageUnit;
	}
	
	attribute def VoltageUnit :> SimpleUnit;
	
	attribute def CurrentValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : CurrentUnit;
	}
	
	attribute def CurrentUnit :> SimpleUnit;
	
	attribute def pHValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : pHUnit;
	}
	
	attribute def pHUnit :> SimpleUnit;
	
	attribute def ConcentrationValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : ConcentrationUnit;
	}
	
	attribute def ConcentrationUnit :> SimpleUnit;
	
	item def ChemicalAnalyte {
		attribute pH : pHValue;
		attribute ionConcentration : ConcentrationValue;
		attribute temperature : TemperatureValue;
	}
	
	item def OpticalStimulus {
		attribute wavelength : LengthValue;
		attribute intensity : Real;
		attribute modulationFrequency : Real;
		attribute spatialPattern : String;
	}
	
	item def SurfacePotentialDistribution {
		attribute potentialValues : VoltageValue[0..*] ordered;
		attribute spatialCoordinates : Real[0..*] ordered;
		attribute timestamp : Real;
	}
	
	item def PhotocurrentSignal {
		attribute current : CurrentValue;
		attribute phaseShift : Real;
		attribute amplitude : Real;
	}
	
	item def MeasurementData {
		attribute potentialMap : SurfacePotentialDistribution;
		attribute analyteConcentration : ConcentrationValue;
		attribute measurementQuality : Real;
	}
	
	port def AnalyteInputPort {
		in item analyte : ChemicalAnalyte;
	}
	
	port def OpticalInputPort {
		in item lightStimulus : OpticalStimulus;
	}
	
	port def SignalOutputPort {
		out item signal : PhotocurrentSignal;
	}
	
	port def DataOutputPort {
		out item data : MeasurementData;
	}
	
	port def PowerSupplyPort {
		in attribute supplyVoltage : VoltageValue;
		in attribute supplyCurrent : CurrentValue;
	}
	
	port def BiasControlPort {
		in attribute biasVoltage : VoltageValue;
	}
	
	part def IonSensitiveMembrane {
		attribute thickness : LengthValue;
		attribute selectivity : Real;
		attribute responseSlope : VoltageValue;
		attribute detectionLimit : ConcentrationValue;
		
		port analyteInterface : AnalyteInputPort;
		
		attribute surfacePotential : VoltageValue;
		attribute boundIonDensity : Real;
	}
	
	part def SemiconductorSubstrate {
		attribute dopingConcentration : ConcentrationValue;
		attribute carrierMobility : Real;
		attribute bandgap : Real;
		
		attribute depletionWidth : LengthValue;
		attribute spaceChargeCapacitance : Real;
	}
	
	part def InsulatingLayer {
		attribute dielectricConstant : Real;
		attribute thickness : LengthValue;
		attribute breakdownVoltage : VoltageValue;
		
		attribute capacitance : Real;
	}
	
	part def ElectrolyteLayer {
		attribute ionicStrength : ConcentrationValue;
		attribute conductivity : Real;
		attribute bufferCapacity : Real;
		
		port analyteContact : AnalyteInputPort;
		
		attribute ionicCurrent : CurrentValue;
	}
	
	part def ReferenceElectrode {
		attribute standardPotential : VoltageValue;
		attribute stability : Real;
		attribute driftRate : Real;
		
		attribute electrodePotential : VoltageValue;
	}
	
	part def LightSource {
		attribute emissionWavelength : LengthValue;
		attribute opticalPower : Real;
		attribute modulationBandwidth : Real;
		
		port lightOutput : OpticalInputPort;
		port powerInput : PowerSupplyPort;
		
		attribute outputIntensity : Real;
	}
	
	part def OpticalSystem {
		attribute numericalAperture : Real;
		attribute focusSpotSize : LengthValue;
		attribute transmissionEfficiency : Real;
		
		port lightInput : OpticalInputPort;
		port lightOutput : OpticalInputPort;
		
		attribute focusedIntensity : Real;
	}
	
	part def PhotodetectionCircuit {
		attribute transimpedanceGain : Real;
		attribute bandwidth : Real;
		attribute inputNoise : CurrentValue;
		
		port signalInput : SignalOutputPort;
		port signalOutput : SignalOutputPort;
		port powerInput : PowerSupplyPort;
		
		attribute amplifiedSignal : VoltageValue;
	}
	
	part def LockInAmplifier {
		attribute referenceFrequency : Real;
		attribute timeConstant : Real;
		attribute dynamicReserve : Real;
		
		port signalInput : SignalOutputPort;
		port dataOutput : DataOutputPort;
		port powerInput : PowerSupplyPort;
		
		attribute extractedAmplitude : VoltageValue;
		attribute phaseAngle : Real;
	}
	
	part def ScanningController {
		attribute scanRange : LengthValue;
		attribute scanResolution : LengthValue;
		attribute scanSpeed : Real;
		
		port lightControl : OpticalInputPort;
		port biasControl : BiasControlPort;
		
		attribute currentPosition : Real;
		attribute scanPattern : String;
	}
	
	part def DataProcessor {
		attribute calibrationCoefficients : Real[0..*];
		attribute filterParameters : Real[0..*];
		
		port dataInput : DataOutputPort;
		port dataOutput : DataOutputPort;
		
		attribute processedConcentration : ConcentrationValue;
		attribute confidenceLevel : Real;
	}
	
	action def GenerateOpticalStimulus {
		in attribute wavelength : LengthValue;
		in attribute modulationFreq : Real;
		out item lightOutput : OpticalStimulus;
	}
	
	action def FocusLight {
		in item lightInput : OpticalStimulus;
		in attribute targetPosition : Real;
		out item focusedLight : OpticalStimulus;
	}
	
	action def DetectPhotocurrent {
		in item lightStimulus : OpticalStimulus;
		in item analyte : ChemicalAnalyte;
		in attribute biasVoltage : VoltageValue;
		out item photocurrent : PhotocurrentSignal;
	}
	
	action def AmplifySignal {
		in item inputSignal : PhotocurrentSignal;
		out item amplifiedSignal : PhotocurrentSignal;
	}
	
	action def ExtractPotential {
		in item signal : PhotocurrentSignal;
		in attribute referenceFreq : Real;
		out attribute potential : VoltageValue;
	}
	
	action def MapSurface {
		in attribute pointPotential : VoltageValue;
		in attribute scanPosition : Real;
		out item potentialMap : SurfacePotentialDistribution;
	}
	
	action def CalculateConcentration {
		in item potentialMap : SurfacePotentialDistribution;
		in attribute calibrationData : Real[0..*];
		out attribute concentration : ConcentrationValue;
	}
	
	action def PerformMeasurement {
		in item analyte : ChemicalAnalyte;
		in attribute measurementParameters : Real[0..*];
		out item measurementResult : MeasurementData;
		
		action generateLight : GenerateOpticalStimulus {
			in wavelength;
			in modulationFreq;
			out lightOutput;
		}
		
		action focusBeam : FocusLight {
			in lightInput;
			in targetPosition;
			out focusedLight;
		}
		
		action detectCurrent : DetectPhotocurrent {
			in lightStimulus;
			in analyte;
			in biasVoltage;
			out photocurrent;
		}
		
		action amplify : AmplifySignal {
			in inputSignal;
			out amplifiedSignal;
		}
		
		action extract : ExtractPotential {
			in signal;
			in referenceFreq;
			out potential;
		}
		
		action mapPotential : MapSurface {
			in pointPotential;
			in scanPosition;
			out potentialMap;
		}
		
		action calculate : CalculateConcentration {
			in potentialMap;
			in calibrationData;
			out concentration;
		}
		
		succession first generateLight then focusBeam;
		succession first focusBeam then detectCurrent;
		succession first detectCurrent then amplify;
		succession first amplify then extract;
		succession first extract then mapPotential;
		succession first mapPotential then calculate;
		
		bind focusBeam.lightInput = generateLight.lightOutput;
		bind detectCurrent.lightStimulus = focusBeam.focusedLight;
		bind detectCurrent.analyte = analyte;
		bind amplify.inputSignal = detectCurrent.photocurrent;
		bind extract.signal = amplify.amplifiedSignal;
		bind mapPotential.pointPotential = extract.potential;
		bind calculate.potentialMap = mapPotential.potentialMap;
		bind calculate.calibrationData = measurementParameters;
		bind measurementResult.analyteConcentration = calculate.concentration;
		bind measurementResult.potentialMap = mapPotential.potentialMap;
	}
	
	state def SensorOperationalStates {
		entry; 
		then initialization;
		
		state initialization {
			entry;
		}
		
		accept at initialization CalibrationRequest;
		then calibration;
		
		state calibration;
		
		accept at calibration MeasurementRequest;
		then measuring;
		
		state measuring;
		
		accept at measuring ProcessingRequest;
		then processing;
		
		state processing;
		
		accept at processing ReadyRequest;
		then ready;
		
		state ready;
		
		accept at ready ShutdownCommand;
		then shutdown;
		
		state shutdown;
	}
	
	part def LAPSSensingUnit {
		attribute operatingVoltage : VoltageValue;
		attribute biasVoltage : VoltageValue;
		attribute spatialResolution : LengthValue;
		attribute measurementRange : VoltageValue;
		attribute sensitivity : VoltageValue;
		attribute detectionLimit : ConcentrationValue;
		
		port analyteInput : AnalyteInputPort;
		port measurementOutput : DataOutputPort;
		port powerSupply : PowerSupplyPort;
		port biasControl : BiasControlPort;
		
		part membrane : IonSensitiveMembrane;
		part substrate : SemiconductorSubstrate;
		part insulator : InsulatingLayer;
		part electrolyte : ElectrolyteLayer;
		part reference : ReferenceElectrode;
		part lightSource : LightSource;
		part optics : OpticalSystem;
		part photodetector : PhotodetectionCircuit;
		part lockIn : LockInAmplifier;
		part scanner : ScanningController;
		part processor : DataProcessor;
		
		connect membrane.analyteInterface to analyteInput;
		connect electrolyte.analyteContact to analyteInput;
		connect lightSource.lightOutput to optics.lightInput;
		connect scanner.lightControl to optics.lightOutput;
		connect photodetector.signalOutput to lockIn.signalInput;
		connect lockIn.dataOutput to processor.dataInput;
		connect processor.dataOutput to measurementOutput;
		connect lightSource.powerInput to powerSupply;
		connect photodetector.powerInput to powerSupply;
		connect lockIn.powerInput to powerSupply;
		connect scanner.biasControl to biasControl;
		
		perform action measurement : PerformMeasurement;
		
		exhibit state behavior : SensorOperationalStates;
	}
	
	requirement def SpatialResolutionRequirement {
		doc /* The LAPS sensing unit shall achieve spatial resolution better than 10 micrometers. */
		
		subject sensor : LAPSSensingUnit;
		
		require constraint {
			sensor.spatialResolution.num <= 10.0
		}
	}
	
	requirement def SensitivityRequirement {
		doc /* The sensing unit shall exhibit sensitivity of at least 55 mV per pH unit. */
		
		subject sensor : LAPSSensingUnit;
		
		require constraint {
			sensor.sensitivity.num >= 55.0
		}
	}
	
	requirement def DetectionLimitRequirement {
		doc /* The sensor shall detect ion concentrations down to 1 micromolar. */
		
		subject sensor : LAPSSensingUnit;
		
		require constraint {
			sensor.detectionLimit.num <= 1.0e-6
		}
	}
	
	requirement def ResponseTimeRequirement {
		doc /* The ion-sensitive membrane shall respond to chemical changes within 1.5 seconds. */
		
		subject membrane : IonSensitiveMembrane;
		
		require constraint {
			membrane.responseSlope.num >= 50.0
		}
	}
	
	requirement def MeasurementRangeRequirement {
		doc /* The sensor shall measure potential differences from -500 mV to +500 mV. */
		
		subject sensor : LAPSSensingUnit;
		
		require constraint {
			sensor.measurementRange.num >= 1000.0
		}
	}
	
	requirement def StabilityRequirement {
		doc /* The reference electrode shall maintain stability better than 99%. */
		
		subject reference : ReferenceElectrode;
		
		require constraint {
			reference.stability >= 0.99
		}
	}
	
	requirement lapsSensingUnitRequirements {
		doc /* Comprehensive requirements for the LAPS sensing unit system. */
		
		subject sensingSystem : LAPSSensingUnit;
		
		requirement spatialRes : SpatialResolutionRequirement {
			subject sensor = sensingSystem;
		}
		
		requirement sensitivity : SensitivityRequirement {
			subject sensor = sensingSystem;
		}
		
		requirement detectionLimit : DetectionLimitRequirement {
			subject sensor = sensingSystem;
		}
		
		requirement responseTime : ResponseTimeRequirement {
			subject membrane = sensingSystem.membrane;
		}
		
		requirement measurementRange : MeasurementRangeRequirement {
			subject sensor = sensingSystem;
		}
		
		requirement stability : StabilityRequirement {
			subject reference = sensingSystem.reference;
		}
	}
	
	part lapsSystem : LAPSSensingUnit {
		attribute :>> operatingVoltage = 5.0[V];
		attribute :>> biasVoltage = 1.5[V];
		attribute :>> spatialResolution = 8.0[um];
		attribute :>> measurementRange = 1000.0[mV];
		attribute :>> sensitivity = 58.5[mV];
		
		part :>> membrane {
			attribute :>> thickness = 100.0[nm];
			attribute :>> selectivity = 0.98;
		}
		
		part :>> substrate {
			attribute :>> carrierMobility = 0.14;
			attribute :>> bandgap = 1.12;
		}
		
		part :>> insulator {
			attribute :>> dielectricConstant = 3.9;
			attribute :>> thickness = 50.0[nm];
		}
		
		part :>> electrolyte {
			attribute :>> conductivity = 1.5;
			attribute :>> bufferCapacity = 20.0;
		}
		
		part :>> reference {
			attribute :>> stability = 0.995;
			attribute :>> driftRate = 0.1;
		}
		
		part :>> lightSource {
			attribute :>> opticalPower = 5.0;
			attribute :>> modulationBandwidth = 10000.0;
		}
		
		part :>> optics {
			attribute :>> numericalAperture = 0.5;
			attribute :>> transmissionEfficiency = 0.85;
		}
		
		part :>> photodetector {
			attribute :>> transimpedanceGain = 1.0e6;
			attribute :>> bandwidth = 100000.0;
		}
		
		part :>> lockIn {
			attribute :>> referenceFrequency = 1000.0;
			attribute :>> timeConstant = 0.1;
			attribute :>> dynamicReserve = 60.0;
		}
		
		part :>> scanner {
			attribute :>> scanResolution = 2.0[um];
			attribute :>> scanSpeed = 10.0;
		}
		
		satisfy lapsSensingUnitRequirements;
	}
	
	part testConfiguration {
		part testSystem : LAPSSensingUnit :> lapsSystem;
		
		ref item testAnalyte : ChemicalAnalyte;
		
		part testResults : MeasurementData[0..*];
		
		connect testSystem.analyteInput to testAnalyte;
		
		satisfy lapsSensingUnitRequirements by testSystem;
	}
}
