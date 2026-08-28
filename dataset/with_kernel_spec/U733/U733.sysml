package IntelligentTemperatureSensor {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	import Definitions::*;

	package Definitions {
		attribute def PowerOnSignal;
		attribute def DiagnosticRequestSignal;
		attribute def ReturnToNormalSignal;
		attribute def ResetCommandSignal;
		attribute def CriticalErrorSignal;

		attribute def QualityScore :> Real;
		attribute def CalibrationDriftValue :> Real;
		attribute def SamplingRateValue :> Real;
		attribute def FilterCutoffValue :> Real;
		attribute def ErrorCodeValue :> Integer;
		attribute def StatusCodeValue :> Integer;
		attribute def VoltageValue :> Real;
		attribute def CurrentValue :> Real;

		item def RawTemperatureSignal {
			attribute voltage : VoltageValue;
		}
		item def ConditionedSignal {
			attribute voltage : VoltageValue;
		}
		item def DigitalSample {
			attribute count : Integer;
		}
		item def ProcessedSample {
			attribute temperature : TemperatureValue;
			attribute quality : QualityScore;
		}
		item def ProcessedTemperatureMeasurement {
			attribute temperature : TemperatureValue;
			attribute quality : QualityScore;
			attribute timestamp : String;
		}
		item def DiagnosticReport {
			attribute status : StatusCodeValue;
			attribute errorCode : ErrorCodeValue;
			attribute calibrationDrift : CalibrationDriftValue;
			attribute selfTestResult : Boolean;
			attribute timestamp : String;
		}
		item def PowerInput {
			attribute voltage : VoltageValue;
			attribute current : CurrentValue;
		}
		item def CalibrationData {
			attribute referencePoints : Real[0..*];
			attribute compensationCoefficients : Real[0..*];
		}
		item def Acknowledgment {
			attribute accepted : Boolean;
		}

		port def PowerPort {
			in power : PowerInput;
		}
		port def CalibrationInterfacePort {
			in calibrationData : CalibrationData;
			out ack : Acknowledgment;
		}
		port def MeasurementOutputPort {
			out measurement : ProcessedTemperatureMeasurement;
		}
		port def DiagnosticOutputPort {
			out report : DiagnosticReport;
		}
		port def RawSignalOutPort {
			out raw : RawTemperatureSignal;
		}
		port def RawSignalInPort {
			in raw : RawTemperatureSignal;
		}
		port def ConditionedSignalOutPort {
			out conditioned : ConditionedSignal;
		}
		port def ConditionedSignalInPort {
			in conditioned : ConditionedSignal;
		}
		port def DigitalSignalOutPort {
			out digital : DigitalSample;
		}
		port def DigitalSignalInPort {
			in digital : DigitalSample;
		}
		port def ProcessedSignalOutPort {
			out processed : ProcessedSample;
		}
		port def ProcessedSignalInPort {
			in processed : ProcessedSample;
		}

		action def Transduce {
			in physicalTemp : TemperatureValue;
			out raw : RawTemperatureSignal;
		}
		action def Condition {
			in raw : RawTemperatureSignal;
			out conditioned : ConditionedSignal;
		}
		action def Convert {
			in conditioned : ConditionedSignal;
			out digital : DigitalSample;
		}
		action def ProcessMeasurement {
			in digital : DigitalSample;
			in calibrationFactors : Real[0..*];
			in nonlinearityCompensation : Real[0..*];
			out processed : ProcessedSample;
		}
		action def ValidateMeasurement {
			in processed : ProcessedSample;
			in rangeMin : TemperatureValue;
			in rangeMax : TemperatureValue;
			out isValid : Boolean;
			out quality : QualityScore;
		}
		action def MonitorCalibration {
			in referenceTemp : TemperatureValue;
			in measuredTemp : TemperatureValue;
			out drift : CalibrationDriftValue;
		}
		action def ValidateRange {
			in measuredTemp : TemperatureValue;
			in rangeMin : TemperatureValue;
			in rangeMax : TemperatureValue;
			out inRange : Boolean;
		}
		action def ReportStatus {
			in status : StatusCodeValue;
			in error : ErrorCodeValue;
			in drift : CalibrationDriftValue;
			in selfTestResult : Boolean;
			out report : DiagnosticReport;
		}
		action def AdjustParameters {
			in noiseLevel : Real;
			in powerBudget : Real;
			out newSamplingRate : SamplingRateValue;
			out newFilterCutoff : FilterCutoffValue;
		}
		action def InitializeAndSelfTest {
			out selfTestPassed : Boolean;
		}
		action def AcquireReading;
		action def OutputMeasurement;

		part def TransducerElement {
			attribute sensitivity : Real;
			attribute operatingMin : TemperatureValue;
			attribute operatingMax : TemperatureValue;
			port rawOutput : RawSignalOutPort;
			perform action transduce : Transduce;
		}
		part def SignalConditioner {
			attribute gain : Real;
			attribute filterCutoff : FilterCutoffValue;
			port conditionerInput : RawSignalInPort;
			port conditionerOutput : ConditionedSignalOutPort;
			perform action condition : Condition;
		}
		part def AnalogDigitalConverter {
			attribute resolutionBits : Integer;
			attribute referenceVoltage : VoltageValue;
			port adcInput : ConditionedSignalInPort;
			port adcOutput : DigitalSignalOutPort;
			perform action convert : Convert;
		}
		part def MicroprocessorUnit {
			attribute calibrationFactors : Real[0..*];
			attribute nonlinearityCompensation : Real[0..*];
			port processorInput : DigitalSignalInPort;
			port processorOutput : ProcessedSignalOutPort;
			perform action process : ProcessMeasurement;
			perform action validate : ValidateMeasurement;
		}
		part def SelfDiagnosticUnit {
			attribute calibrationDriftThreshold : CalibrationDriftValue;
			attribute rangeMin : TemperatureValue;
			attribute rangeMax : TemperatureValue;
			perform action monitorCalibration : MonitorCalibration;
			perform action validateRange : ValidateRange;
			perform action reportStatus : ReportStatus;
		}
		part def AdaptiveAlgorithmModule {
			attribute defaultSamplingRate : SamplingRateValue;
			attribute defaultFilterCutoff : FilterCutoffValue;
			attribute powerOptimizationEnabled : Boolean;
			perform action adjustParameters : AdjustParameters;
		}

		state def SensorStates;

		part def IntelligentTemperatureSensorUnit {
			attribute operatingRangeMin : TemperatureValue;
			attribute operatingRangeMax : TemperatureValue;
			attribute precisionRating : TemperatureValue;
			attribute selfTestPassed : Boolean;
			attribute criticalErrorDetected : Boolean;
			attribute currentSamplingRate : SamplingRateValue;
			attribute currentFilterCutoff : FilterCutoffValue;

			port powerInput : PowerPort;
			port calibrationInterface : CalibrationInterfacePort;
			port measurementOutput : MeasurementOutputPort;
			port diagnosticOutput : DiagnosticOutputPort;

			part transducer : TransducerElement;
			part signalConditioner : SignalConditioner;
			part adc : AnalogDigitalConverter;
			part microprocessor : MicroprocessorUnit;
			part selfDiagnostics : SelfDiagnosticUnit;
			part adaptiveModule : AdaptiveAlgorithmModule;

			connect transducer.rawOutput to signalConditioner.conditionerInput;
			connect signalConditioner.conditionerOutput to adc.adcInput;
			connect adc.adcOutput to microprocessor.processorInput;

			exhibit state sensorStates : SensorStates {
				entry; then poweredOff;
				state poweredOff;
				accept PowerOnSignal
					then initializing;
				state initializing {
					entry action init : InitializeAndSelfTest;
				}
				transition 'init-success'
					first initializing
					if selfTestPassed
					then measuring;
				transition 'init-failure'
					first initializing
					if not selfTestPassed
					then fault;
				state measuring {
					entry action acquire : AcquireReading;
					do action process : ProcessMeasurement;
					exit action output : OutputMeasurement;
				}
				accept DiagnosticRequestSignal
					then diagnostic;
				accept CriticalErrorSignal
					then fault;
				state diagnostic {
					entry action monitorCal : MonitorCalibration;
					do action validateRng : ValidateRange;
					exit action reportStat : ReportStatus;
				}
				accept ReturnToNormalSignal
					then measuring;
				state fault {
					entry action faultReport : ReportStatus;
				}
				accept ResetCommandSignal
					then poweredOff;
			}
		}

		part def HighPrecisionSensor :> IntelligentTemperatureSensorUnit;
		part def IndustrialRuggedSensor :> IntelligentTemperatureSensorUnit;

		requirement def PrecisionRequirement {
			subject sensor : IntelligentTemperatureSensorUnit;
			attribute requiredPrecision : TemperatureValue;
			assert constraint {
				sensor.precisionRating <= requiredPrecision
			}
		}
		requirement def OperatingRangeRequirement {
			subject sensor : IntelligentTemperatureSensorUnit;
			attribute minOperatingTemp : TemperatureValue;
			attribute maxOperatingTemp : TemperatureValue;
			assert constraint {
				sensor.operatingRangeMin >= minOperatingTemp and
				sensor.operatingRangeMax <= maxOperatingTemp
			}
		}
		requirement def DiagnosticReportingRequirement {
			subject sensor : IntelligentTemperatureSensorUnit;
			assert constraint {
				sensor.diagnosticOutput.report.status > 0
			}
		}
	}

	package Usages {
		private import Definitions::*;

		part highPrecisionLabSensor : HighPrecisionSensor {
			attribute operatingRangeMin = 253.15 [K];
			attribute operatingRangeMax = 353.15 [K];
			attribute precisionRating = 0.01 [K];
			attribute selfTestPassed = false;
			attribute criticalErrorDetected = false;
			attribute currentSamplingRate = 10;
			attribute currentFilterCutoff = 50;

			part transducer : TransducerElement {
				attribute sensitivity = 0.01;
				attribute operatingMin = 253.15 [K];
				attribute operatingMax = 353.15 [K];
			}
			part signalConditioner : SignalConditioner {
				attribute gain = 1000;
				attribute filterCutoff = 50;
			}
			part adc : AnalogDigitalConverter {
				attribute resolutionBits = 24;
				attribute referenceVoltage = 5.0;
			}
			part microprocessor : MicroprocessorUnit {
				attribute calibrationFactors = (1.0, 0.0012, -0.000003);
				attribute nonlinearityCompensation = (0.0, 0.0001, -0.00000005);
			}
			part selfDiagnostics : SelfDiagnosticUnit {
				attribute calibrationDriftThreshold = 0.5;
				attribute rangeMin = 253.15 [K];
				attribute rangeMax = 353.15 [K];
			}
			part adaptiveModule : AdaptiveAlgorithmModule {
				attribute defaultSamplingRate = 10;
				attribute defaultFilterCutoff = 50;
				attribute powerOptimizationEnabled = true;
			}
		}

		part industrialRuggedSensor : IndustrialRuggedSensor {
			attribute operatingRangeMin = 233.15 [K];
			attribute operatingRangeMax = 423.15 [K];
			attribute precisionRating = 0.5 [K];
			attribute selfTestPassed = false;
			attribute criticalErrorDetected = false;
			attribute currentSamplingRate = 5;
			attribute currentFilterCutoff = 20;

			part transducer : TransducerElement {
				attribute sensitivity = 0.05;
				attribute operatingMin = 233.15 [K];
				attribute operatingMax = 423.15 [K];
			}
			part signalConditioner : SignalConditioner {
				attribute gain = 500;
				attribute filterCutoff = 20;
			}
			part adc : AnalogDigitalConverter {
				attribute resolutionBits = 16;
				attribute referenceVoltage = 3.3;
			}
			part microprocessor : MicroprocessorUnit {
				attribute calibrationFactors = (1.0, 0.0058, -0.00012);
				attribute nonlinearityCompensation = (0.0, 0.0005, -0.000002);
			}
			part selfDiagnostics : SelfDiagnosticUnit {
				attribute calibrationDriftThreshold = 2.0;
				attribute rangeMin = 233.15 [K];
				attribute rangeMax = 423.15 [K];
			}
			part adaptiveModule : AdaptiveAlgorithmModule {
				attribute defaultSamplingRate = 5;
				attribute defaultFilterCutoff = 20;
				attribute powerOptimizationEnabled = false;
			}
		}

		requirement precisionReqLab : PrecisionRequirement {
			subject sensor = highPrecisionLabSensor;
			attribute requiredPrecision = 0.01 [K];
		}
		requirement operatingRangeReqLab : OperatingRangeRequirement {
			subject sensor = highPrecisionLabSensor;
			attribute minOperatingTemp = 253.15 [K];
			attribute maxOperatingTemp = 353.15 [K];
		}
		requirement operatingRangeReqIndustrial : OperatingRangeRequirement {
			subject sensor = industrialRuggedSensor;
			attribute minOperatingTemp = 233.15 [K];
			attribute maxOperatingTemp = 423.15 [K];
		}
		requirement diagnosticReq : DiagnosticReportingRequirement {
			subject sensor = highPrecisionLabSensor;
		}
	}
}
