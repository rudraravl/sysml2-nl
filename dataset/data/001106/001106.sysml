package 'Intelligent Sensing Unit' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def SensorID :> String;
	attribute def CalibrationFactor :> Real;
	attribute def Timestamp :> Real;
	
	item def RawSensorSignal {
		attribute voltage : Real;
		attribute timestamp : Timestamp;
	}
	
	item def ProcessedMeasurement {
		attribute value : TemperatureValue;
		attribute quality : Real;
		attribute timestamp : Timestamp;
	}
	
	item def DiagnosticData {
		attribute status : String;
		attribute errorCode : Integer;
		attribute driftEstimate : Real;
	}
	
	port def MeasurementOutputPort {
		out item measurement : ProcessedMeasurement;
	}
	
	port def DiagnosticPort {
		out item diagnostics : DiagnosticData;
	}
	
	port def PowerSupplyPort {
		in attribute voltage : Real;
		in attribute current : Real;
	}
	
	port def CalibrationPort {
		in attribute referenceValue : TemperatureValue;
		out attribute calibrationStatus : Boolean;
	}
	
	part def TransducerElement {
		attribute sensitivity : CalibrationFactor;
		attribute responseTime : Real;
		
		action def ConvertPhysicalToElectrical {
			in physicalQuantity : TemperatureValue;
			out electricalSignal : RawSensorSignal;
		}
	}
	
	part def SignalConditioner {
		attribute gain : Real;
		attribute offset : Real;
		
		action def AmplifyAndFilter {
			in rawSignal : RawSensorSignal;
			out conditionedSignal : RawSensorSignal;
		}
	}
	
	part def AnalogToDigitalConverter {
		attribute resolution : Integer;
		attribute samplingRate : Real;
		
		action def Digitize {
			in analogSignal : RawSensorSignal;
			out digitalValue : Real;
		}
	}
	
	part def MicroprocessorUnit {
		attribute processingSpeed : Real;
		attribute memorySize : Integer;
		
		action def ApplyCalibration {
			in rawValue : Real;
			in calibrationCoefficient : CalibrationFactor;
			out calibratedValue : TemperatureValue;
		}
		
		action def CompensateNonlinearity {
			in linearValue : TemperatureValue;
			out compensatedValue : TemperatureValue;
		}
		
		action def CalculateQuality {
			in measurement : TemperatureValue;
			in diagnosticInfo : DiagnosticData;
			out qualityMetric : Real;
		}
	}
	
	part def SelfDiagnosticUnit {
		attribute lastDiagnosticTime : Timestamp;
		attribute healthScore : Real;
		
		action def MonitorSensorHealth {
			in currentReading : TemperatureValue;
			in historicalData : TemperatureValue[*];
			out diagnosticReport : DiagnosticData;
		}
		
		action def DetectDrift {
			in currentCalibration : CalibrationFactor;
			in referenceCalibration : CalibrationFactor;
			out driftDetected : Boolean;
			out driftMagnitude : Real;
		}
		
		action def ValidateMeasurement {
			in measurement : TemperatureValue;
			in expectedRange : Real[2];
			out isValid : Boolean;
		}
	}
	
	part def AdaptiveAlgorithmModule {
		attribute learningRate : Real;
		attribute adaptationEnabled : Boolean;
		
		action def AdjustSamplingRate {
			in signalVariability : Real;
			in powerBudget : Real;
			out optimalSamplingRate : Real;
		}
		
		action def OptimizeFilterParameters {
			in noiseLevel : Real;
			in signalBandwidth : Real;
			out filterCoefficients : Real[*];
		}
		
		action def PredictNextValue {
			in historicalMeasurements : TemperatureValue[*];
			out predictedValue : TemperatureValue;
			out confidence : Real;
		}
	}
	
	part def IntelligentSensor {
		attribute sensorID : SensorID;
		attribute measurementRange : Real[2];
		attribute accuracy : Real;
		attribute operatingTemperatureRange : Real[2];
		
		port measurementOutput : MeasurementOutputPort;
		port diagnosticOutput : DiagnosticPort;
		port powerInput : PowerSupplyPort;
		port calibrationInterface : CalibrationPort;
		
		part transducer : TransducerElement[1] {
			attribute :>> sensitivity = 0.01;
			attribute :>> responseTime = 0.1;
		}
		
		part signalConditioner : SignalConditioner[1] {
			attribute :>> gain = 100.0;
			attribute :>> offset = 0.0;
		}
		
		part adc : AnalogToDigitalConverter[1] {
			attribute :>> resolution = 16;
			attribute :>> samplingRate = 1000.0;
		}
		
		part processor : MicroprocessorUnit[1] {
			attribute :>> processingSpeed = 100.0;
			attribute :>> memorySize = 65536;
		}
		
		part diagnosticUnit : SelfDiagnosticUnit[1] {
			attribute :>> healthScore = 1.0;
		}
		
		part adaptiveModule : AdaptiveAlgorithmModule[1] {
			attribute :>> learningRate = 0.01;
			attribute :>> adaptationEnabled = true;
		}
		
		connection transducerToConditioner connect transducer to signalConditioner;
		connection conditionerToADC connect signalConditioner to adc;
		connection adcToProcessor connect adc to processor;
		connection processorToDiagnostic connect processor to diagnosticUnit;
		connection processorToAdaptive connect processor to adaptiveModule;
	}
	
	action def MeasurementSequence {
		in physicalQuantity : TemperatureValue;
		out finalMeasurement : ProcessedMeasurement;
		out diagnosticInfo : DiagnosticData;
		
		first start;
		then action transduce : TransducerElement::ConvertPhysicalToElectrical {
			in physicalQuantity;
			out electricalSignal;
		}
		then action condition : SignalConditioner::AmplifyAndFilter {
			in rawSignal = transduce.electricalSignal;
			out conditionedSignal;
		}
		then action digitize : AnalogToDigitalConverter::Digitize {
			in analogSignal = condition.conditionedSignal;
			out digitalValue;
		}
		then fork;
		
		then action calibrate : MicroprocessorUnit::ApplyCalibration {
			in rawValue = digitize.digitalValue;
			in calibrationCoefficient = 1.0;
			out calibratedValue;
		}
		then action compensate : MicroprocessorUnit::CompensateNonlinearity {
			in linearValue = calibrate.calibratedValue;
			out compensatedValue;
		}
		then joinNode;
		
		then action diagnose : SelfDiagnosticUnit::MonitorSensorHealth {
			in currentReading = compensate.compensatedValue;
			in historicalData;
			out diagnosticReport;
		}
		then joinNode;
		
		join joinNode;
		then action calculateQuality : MicroprocessorUnit::CalculateQuality {
			in measurement = compensate.compensatedValue;
			in diagnosticInfo = diagnose.diagnosticReport;
			out qualityMetric;
		}
		then action validate : SelfDiagnosticUnit::ValidateMeasurement {
			in measurement = compensate.compensatedValue;
			in expectedRange = (-40.0, 125.0);
			out isValid;
		}
		then decide;
		
		if validate.isValid then outputMeasurement;
		if !validate.isValid then flagError;
		
		action outputMeasurement {
			bind finalMeasurement.value = compensate.compensatedValue;
			bind finalMeasurement.quality = calculateQuality.qualityMetric;
		}
		then done;
		
		action flagError {
			bind diagnosticInfo.status = "Invalid";
			bind diagnosticInfo.errorCode = 1;
		}
		then done;
	}
	
	state def IntelligentSensorStates {
		entry; then powerOff;
		
		state powerOff;
		transition powerOff_to_initialization
			first powerOff
			accept PowerApplied
			then initialization;
		
		state initialization {
			entry; then selfTest;
			
			state selfTest;
			transition selfTest_to_calibration
				first selfTest
				accept SelfTestPassed
				then calibration;
			
			state calibration;
			transition calibration_to_ready
				first calibration
				accept CalibrationComplete
				then ready;
		}
		
		transition initialization_to_fault
			first initialization
			accept InitializationFailed
			then fault;
		
		state ready;
		transition ready_to_measuring
			first ready
			accept MeasurementRequested
			then measuring;
		
		state measuring {
			entry; then acquiring;
			
			state acquiring;
			transition acquiring_to_processing
				first acquiring
				accept DataAcquired
				then processing;
			
			state processing;
			transition processing_to_validating
				first processing
				accept ProcessingComplete
				then validating;
			
			state validating;
			transition validating_to_adapting
				first validating
				accept ValidationPassed
				then adapting;
			
			transition validating_to_error
				first validating
				accept ValidationFailed
				then error;
			
			state adapting;
			transition adapting_to_outputting
				first adapting
				accept AdaptationComplete
				then outputting;
			
			state outputting;
			transition outputting_to_ready
				first outputting
				accept OutputComplete
				then ready;
			
			state error;
			transition error_to_ready
				first error
				accept ErrorHandled
				then ready;
		}
		
		transition measuring_to_fault
			first measuring
			accept CriticalFailure
			then fault;
		
		transition ready_to_diagnosticMode
			first ready
			accept DiagnosticRequested
			then diagnosticMode;
		
		state diagnosticMode {
			entry; then runningDiagnostics;
			
			state runningDiagnostics;
			transition runningDiagnostics_to_reportingResults
				first runningDiagnostics
				accept DiagnosticsComplete
				then reportingResults;
			
			state reportingResults;
			transition reportingResults_to_ready
				first reportingResults
				accept ResultsReported
				then ready;
		}
		
		state fault;
		transition fault_to_initialization
			first fault
			accept Reset
			then initialization;
		
		transition fault_to_powerOff
			first fault
			accept PowerRemoved
			then powerOff;
	}
	
	requirement def MeasurementAccuracyRequirement {
		doc /* The intelligent sensor shall measure temperature with an 
		       accuracy of ±0.5°C over the operating range of -40°C to 125°C. */
		
		subject sensor : IntelligentSensor;
		
		require constraint {
			sensor.accuracy <= 0.5
		}
	}
	
	requirement def ResponseTimeRequirement {
		doc /* The intelligent sensor shall provide a valid measurement 
		       within 200 milliseconds of receiving a measurement request. */
		
		subject sensor : IntelligentSensor;
		
		require constraint {
			sensor.transducer.responseTime <= 0.2
		}
	}
	
	requirement def SelfDiagnosticRequirement {
		doc /* The intelligent sensor shall perform continuous self-diagnostics 
		       and report health status with each measurement. */
		
		subject sensor : IntelligentSensor;
		
		require constraint {
			sensor.diagnosticUnit.healthScore >= 0.8
		}
	}
	
	requirement def AdaptiveCapabilityRequirement {
		doc /* The intelligent sensor shall automatically adjust sampling rate 
		       and filtering based on signal characteristics to optimize 
		       measurement quality and power consumption. */
		
		subject sensor : IntelligentSensor;
	}
	
	requirement def CalibrationStabilityRequirement {
		doc /* The intelligent sensor shall maintain calibration accuracy 
		       with drift less than 0.1°C per year under normal operating conditions. */
		
		subject sensor : IntelligentSensor;
	}
	
	part sensingUnit : IntelligentSensor {
		attribute :>> sensorID = "IS-TEMP-2024-001";
		attribute :>> measurementRange = (-40.0, 125.0);
		attribute :>> accuracy = 0.5;
		attribute :>> operatingTemperatureRange = (-40.0, 85.0);
		
		part :>> transducer {
			attribute :>> sensitivity = 0.0095;
			attribute :>> responseTime = 0.15;
		}
		
		part :>> signalConditioner {
			attribute :>> gain = 120.0;
			attribute :>> offset = 0.05;
		}
		
		part :>> adc {
			attribute :>> resolution = 24;
			attribute :>> samplingRate = 2000.0;
		}
		
		part :>> processor {
			attribute :>> processingSpeed = 200.0;
			attribute :>> memorySize = 131072;
		}
		
		part :>> diagnosticUnit {
			attribute :>> healthScore = 0.98;
			attribute :>> lastDiagnosticTime = 0.0;
		}
		
		part :>> adaptiveModule {
			attribute :>> learningRate = 0.005;
			attribute :>> adaptationEnabled = true;
		}
		
		perform action measurementCycle : MeasurementSequence;
		exhibit state operationalBehavior : IntelligentSensorStates;
	}
	
	individual def HighPrecisionTemperatureSensor :> IntelligentSensor;
	individual def IndustrialTemperatureSensor :> IntelligentSensor;
	
	individual highPrecisionSensor : HighPrecisionTemperatureSensor :> sensingUnit {
		attribute :>> sensorID = "HP-TEMP-001";
		attribute :>> accuracy = 0.1;
		
		timeslice normalOperation {
			perform action :>> measurementCycle {
				in physicalQuantity = 25.0[K];
			}
		}
		
		then timeslice calibrationCheck {
			perform action :>> measurementCycle {
				in physicalQuantity = 20.0[K];
			}
		}
	}
	
	individual industrialSensor : IndustrialTemperatureSensor :> sensingUnit {
		attribute :>> sensorID = "IND-TEMP-001";
		attribute :>> measurementRange = (-40.0, 200.0);
		attribute :>> accuracy = 1.0;
		
		timeslice continuousMeasurement {
			perform action :>> measurementCycle {
				in physicalQuantity = 150.0[K];
			}
		}
	}
	
	verification accuracyVerification : MeasurementAccuracyRequirement {
		subject testSensor :> sensingUnit;
	}
	
	verification responseTimeVerification : ResponseTimeRequirement {
		subject testSensor :> sensingUnit;
	}
	
	verification selfDiagnosticVerification : SelfDiagnosticRequirement {
		subject testSensor :> sensingUnit;
	}
	
	verification adaptiveCapabilityVerification : AdaptiveCapabilityRequirement {
		subject testSensor :> sensingUnit;
	}
	
	verification calibrationStabilityVerification : CalibrationStabilityRequirement {
		subject testSensor :> sensingUnit;
	}
}
