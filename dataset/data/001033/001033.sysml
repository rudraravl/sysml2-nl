package 'Electrochemical Fatigue Crack Sensing System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import Quantities::*;
	private import UnitsAndScales::*;
	
	attribute def ElectricalResistanceValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : ElectricalResistanceUnit;
	}
	
	attribute def ElectricalResistanceUnit :> DerivedUnit;
	
	attribute def ElectricalCurrentValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : ElectricalCurrentUnit;
	}
	
	attribute def ElectricalCurrentUnit :> DerivedUnit;
	
	attribute def ElectricalVoltageValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : ElectricalVoltageUnit;
	}
	
	attribute def ElectricalVoltageUnit :> DerivedUnit;
	
	attribute def CrackDepthValue :> LengthValue;
	attribute def CrackLengthValue :> LengthValue;
	attribute def CrackGrowthRateValue :> ScalarQuantityValue {
		attribute :>> num : Real;
	}
	
	item def ElectrolyteFluid {
		attribute conductivity : Real;
		attribute pH : Real;
	}
	
	item def ElectrochemicalSignal {
		attribute voltage : ElectricalVoltageValue;
		attribute current : ElectricalCurrentValue;
		attribute resistance : ElectricalResistanceValue;
	}
	
	item def CrackMeasurementData {
		attribute crackDepth : CrackDepthValue;
		attribute crackLength : CrackLengthValue;
		attribute growthRate : CrackGrowthRateValue;
		attribute timestamp : Real;
	}
	
	item def StructuralComponent {
		attribute materialType : String;
		attribute stressLevel : PressureValue;
		attribute cycleCount : Integer;
	}
	
	port def ElectricalPort {
		out voltage : ElectricalVoltageValue;
		out current : ElectricalCurrentValue;
	}
	
	port def DataPort {
		out measurementData : CrackMeasurementData;
	}
	
	port def FluidPort {
		in electrolyte : ElectrolyteFluid;
	}
	
	port def PowerPort {
		in voltage : ElectricalVoltageValue;
		in current : ElectricalCurrentValue;
	}
	
	part def Electrode {
		attribute electrodeNumber : Integer;
		attribute position : LengthValue;
		attribute material : String;
		attribute surfaceArea : AreaValue;
	}
	
	part def ElectrodeArray {
		attribute numberOfElectrodes : Integer;
		attribute electrodeSpacing : LengthValue;
		attribute arrayLength : LengthValue;
		part electrodes : Electrode[2..*];
	}
	
	part def ResistanceMeasurementCircuit {
		attribute measurementFrequency : Real;
		attribute excitationVoltage : ElectricalVoltageValue;
		port powerInput : PowerPort;
		port signalOutput : ElectricalPort;
	}
	
	part def ElectrochemicalSensor {
		attribute sensorId : String;
		attribute baselineResistance : ElectricalResistanceValue;
		attribute currentResistance : ElectricalResistanceValue;
		attribute sensitivity : Real;
		
		port electricalInterface : ElectricalPort;
		port fluidInterface : FluidPort;
		
		part electrodeArray : ElectrodeArray[1];
		part measurementCircuit : ResistanceMeasurementCircuit[1];
		part electrolyteReservoir[1];
	}
	
	part def SignalConditioner {
		attribute amplificationGain : Real;
		attribute filterCutoffFrequency : Real;
		attribute noiseThreshold : ElectricalVoltageValue;
		
		port signalInput : ElectricalPort;
		port conditionedOutput : ElectricalPort;
	}
	
	part def DataAcquisitionModule {
		attribute samplingRate : Real;
		attribute resolution : Integer;
		attribute bufferSize : Integer;
		
		port analogInput : ElectricalPort;
		port digitalOutput : DataPort;
	}
	
	part def CrackAnalysisProcessor {
		attribute calibrationFactor : Real;
		attribute sensitivityThreshold : Real;
		attribute detectionAccuracy : Real;
		
		port dataInput : DataPort;
		port analysisOutput : DataPort;
	}
	
	part def PowerSupply {
		attribute outputVoltage : ElectricalVoltageValue;
		attribute outputCurrent : ElectricalCurrentValue;
		attribute regulationAccuracy : Real;
		
		port output : PowerPort;
	}
	
	connection def ElectricalConnection {
		end source : ElectricalPort[1];
		end target : ElectricalPort[1];
	}
	
	connection def DataConnection {
		end source : DataPort[1];
		end target : DataPort[1];
	}
	
	connection def PowerConnection {
		end source : PowerPort[1];
		end target : PowerPort[1];
	}
	
	action def InitializeSensor {
		in sensorConfig : ElectrochemicalSensor;
		out initializedSensor : ElectrochemicalSensor;
	}
	
	action def ApplyExcitationVoltage {
		in sensor : ElectrochemicalSensor;
		in voltage : ElectricalVoltageValue;
		out excitedSensor : ElectrochemicalSensor;
	}
	
	action def MeasureElectrochemicalResponse {
		in sensor : ElectrochemicalSensor;
		out signal : ElectrochemicalSignal;
	}
	
	action def ConditionSignal {
		in rawSignal : ElectrochemicalSignal;
		out conditionedSignal : ElectrochemicalSignal;
	}
	
	action def AcquireData {
		in signal : ElectrochemicalSignal;
		out digitalData : CrackMeasurementData;
	}
	
	action def AnalyzeCrackCharacteristics {
		in measurementData : CrackMeasurementData;
		in baselineResistance : ElectricalResistanceValue;
		out crackDepth : CrackDepthValue;
		out crackLength : CrackLengthValue;
		out growthRate : CrackGrowthRateValue;
	}
	
	action def TransmitMeasurementData {
		in crackDepth : CrackDepthValue;
		in crackLength : CrackLengthValue;
		in growthRate : CrackGrowthRateValue;
		out measurementData : CrackMeasurementData;
	}
	
	action def PerformCrackMeasurement {
		in targetStructure : StructuralComponent;
		out measurementResult : CrackMeasurementData;
		
		action initialize : InitializeSensor {
			in sensorConfig;
			out initializedSensor;
		}
		
		then action applyVoltage : ApplyExcitationVoltage {
			in sensor;
			in voltage;
			out excitedSensor;
		}
		
		flow from initialize.initializedSensor to applyVoltage.sensor;
		
		then action measureResponse : MeasureElectrochemicalResponse {
			in sensor;
			out signal;
		}
		
		flow from applyVoltage.excitedSensor to measureResponse.sensor;
		
		then action conditionSignal : ConditionSignal {
			in rawSignal;
			out conditionedSignal;
		}
		
		flow from measureResponse.signal to conditionSignal.rawSignal;
		
		then action acquireData : AcquireData {
			in signal;
			out digitalData;
		}
		
		flow from conditionSignal.conditionedSignal to acquireData.signal;
		
		then action analyzeCrack : AnalyzeCrackCharacteristics {
			in measurementData;
			in baselineResistance;
			out crackDepth;
			out crackLength;
			out growthRate;
		}
		
		flow from acquireData.digitalData to analyzeCrack.measurementData;
		
		then action transmitData : TransmitMeasurementData {
			in crackDepth;
			in crackLength;
			in growthRate;
			out measurementData;
		}
		
		flow from analyzeCrack.crackDepth to transmitData.crackDepth;
		flow from analyzeCrack.crackLength to transmitData.crackLength;
		flow from analyzeCrack.growthRate to transmitData.growthRate;
		
		bind transmitData.measurementData = measurementResult;
	}
	
	state def SensorOperationalStates {
		entry; then idle;
		
		state idle;
		accept ActivationEvent;
		then initializing;
		
		state initializing {
			entry; then calibrate;
			state calibrate;
			then selfTest;
			state selfTest;
		}
		accept InitializationCompleteEvent;
		then measuring;
		
		state measuring {
			entry; then applyExcitation;
			
			state applyExcitation;
			then acquireSignal;
			
			state acquireSignal;
			then processData;
			
			state processData;
			then evaluateCrack;
			
			state evaluateCrack;
		}
		accept MeasurementCompleteEvent;
		then reporting;
		
		state reporting {
			entry transmitResults;
		}
		accept ReportCompleteEvent;
		then idle;
		
		accept FaultDetectedEvent;
		then fault;
		
		state fault {
			entry logError;
		}
		accept ResetEvent;
		then initializing;
		
		accept ShutdownEvent;
		then shutdown;
		
		state shutdown;
		then done;
	}
	
	part def SensingUnit {
		attribute unitId : String;
		attribute operatingTemperature : TemperatureValue;
		attribute measurementRange : LengthValue;
		attribute lastMeasurementTime : Real;
		
		part sensor : ElectrochemicalSensor[1] {
			attribute :>> sensorId = "ECS-FAT-001";
			attribute :>> baselineResistance = 1000.0[ohm];
			attribute :>> sensitivity = 0.95;
			
			part :>> electrodeArray {
				attribute :>> numberOfElectrodes = 4;
				attribute :>> electrodeSpacing = 2.5[mm];
				attribute :>> arrayLength = 10.0[mm];
				
				part electrode1 : Electrode :>> electrodes {
					attribute :>> electrodeNumber = 1;
					attribute :>> position = 0.0[mm];
					attribute :>> material = "Platinum";
					attribute :>> surfaceArea = 1.0[mm^2];
				}
				
				part electrode2 : Electrode :>> electrodes {
					attribute :>> electrodeNumber = 2;
					attribute :>> position = 2.5[mm];
					attribute :>> material = "Platinum";
					attribute :>> surfaceArea = 1.0[mm^2];
				}
				
				part electrode3 : Electrode :>> electrodes {
					attribute :>> electrodeNumber = 3;
					attribute :>> position = 5.0[mm];
					attribute :>> material = "Platinum";
					attribute :>> surfaceArea = 1.0[mm^2];
				}
				
				part electrode4 : Electrode :>> electrodes {
					attribute :>> electrodeNumber = 4;
					attribute :>> position = 7.5[mm];
					attribute :>> material = "Platinum";
					attribute :>> surfaceArea = 1.0[mm^2];
				}
			}
			
			part :>> measurementCircuit {
				attribute :>> measurementFrequency = 1000.0;
				attribute :>> excitationVoltage = 5.0[V];
			}
		}
		
		part conditioner : SignalConditioner[1] {
			attribute :>> amplificationGain = 100.0;
			attribute :>> filterCutoffFrequency = 500.0;
			attribute :>> noiseThreshold = 0.01[V];
		}
		
		part dataAcquisition : DataAcquisitionModule[1] {
			attribute :>> samplingRate = 10000.0;
			attribute :>> resolution = 16;
			attribute :>> bufferSize = 1024;
		}
		
		part processor : CrackAnalysisProcessor[1] {
			attribute :>> calibrationFactor = 1.05;
			attribute :>> sensitivityThreshold = 0.02;
			attribute :>> detectionAccuracy = 0.95;
		}
		
		part powerSupply : PowerSupply[1] {
			attribute :>> outputVoltage = 12.0[V];
			attribute :>> outputCurrent = 0.5[A];
			attribute :>> regulationAccuracy = 0.01;
		}
		
		connection sensorToConditioner : ElectricalConnection
			connect source references sensor.electricalInterface
			to target references conditioner.signalInput;
		
		connection conditionerToDAQ : ElectricalConnection
			connect source references conditioner.conditionedOutput
			to target references dataAcquisition.analogInput;
		
		connection daqToProcessor : DataConnection
			connect source references dataAcquisition.digitalOutput
			to target references processor.dataInput;
		
		connection powerToSensor : PowerConnection
			connect source references powerSupply.output
			to target references sensor.measurementCircuit.powerInput;
		
		perform action measurementOperation : PerformCrackMeasurement;
		
		exhibit state behavior : SensorOperationalStates;
	}
	
	requirement def MeasurementAccuracyRequirement {
		doc /* The sensing unit shall measure crack depth with accuracy better than 0.1 mm */
		
		subject sensingSystem : SensingUnit;
		
		require constraint {
			sensingSystem.processor.detectionAccuracy >= 0.90
		}
	}
	
	requirement def OperationalRangeRequirement {
		doc /* The sensing unit shall operate in temperature range from -20 to 80 degrees Celsius */
		
		subject sensingSystem : SensingUnit;
		
		require constraint {
			sensingSystem.operatingTemperature.num >= -20.0 and
			sensingSystem.operatingTemperature.num <= 80.0
		}
	}
	
	requirement def SensorResponseTimeRequirement {
		doc /* The sensing unit shall complete a measurement cycle within 100 milliseconds */
		
		subject sensingSystem : SensingUnit;
		
		require constraint {
			sensingSystem.dataAcquisition.samplingRate >= 1000.0
		}
	}
	
	requirement def CrackDetectionSensitivityRequirement {
		doc /* The sensing unit shall detect cracks with minimum depth of 0.05 mm */
		
		subject sensingSystem : SensingUnit;
		
		require constraint {
			sensingSystem.sensor.sensitivity >= 0.90
		}
	}
	
	part sensingUnitInstance : SensingUnit {
		attribute :>> unitId = "SU-FAT-001";
		attribute :>> operatingTemperature = 25.0[K];
		attribute :>> measurementRange = 10.0[mm];
		attribute :>> lastMeasurementTime = 0.0;
		
		part :>> sensor {
			attribute :>> currentResistance = 1250.0[ohm];
		}
		
		satisfy measurementAccuracy : MeasurementAccuracyRequirement {
			subject sensingSystem = sensingUnitInstance;
		}
		
		satisfy operationalRange : OperationalRangeRequirement {
			subject sensingSystem = sensingUnitInstance;
		}
		
		satisfy responseTime : SensorResponseTimeRequirement {
			subject sensingSystem = sensingUnitInstance;
		}
		
		satisfy detectionSensitivity : CrackDetectionSensitivityRequirement {
			subject sensingSystem = sensingUnitInstance;
		}
	}
	
	individual def TestStructure :> StructuralComponent;
	
	individual testStructure1 : TestStructure {
		attribute :>> materialType = "Aluminum 7075-T6";
		attribute :>> stressLevel = 350.0[MPa];
		attribute :>> cycleCount = 100000;
	}
	
	individual sensingUnitTest : SensingUnit :> sensingUnitInstance {
		timeslice measurement1 {
			perform action :>> measurementOperation {
				in :>> targetStructure : TestStructure = testStructure1;
				out :>> measurementResult {
					attribute :>> crackDepth = 0.15[mm];
					attribute :>> crackLength = 2.5[mm];
					attribute :>> growthRate = 0.001;
					attribute :>> timestamp = 1000.0;
				}
			}
		}
		
		then timeslice measurement2 {
			perform action :>> measurementOperation {
				in :>> targetStructure : TestStructure = testStructure1;
				out :>> measurementResult {
					attribute :>> crackDepth = 0.18[mm];
					attribute :>> crackLength = 2.8[mm];
					attribute :>> growthRate = 0.0015;
					attribute :>> timestamp = 2000.0;
				}
			}
		}
	}
}
