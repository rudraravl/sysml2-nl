package MagneticSensingUnit {
	private import ScalarValues::*;
	private import ISQ::*;
	private import ISQBase::*;
	private import SI::*;
	private import UnitsAndScales::*;
	
	attribute def MagneticFluxDensityValue :> QuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : TensorMeasurementReference;
	}
	
	attribute def VoltageValue :> QuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : TensorMeasurementReference;
	}
	
	attribute def FrequencyValue :> QuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : TensorMeasurementReference;
	}
	
	attribute def TemperatureValue :> QuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : TensorMeasurementReference;
	}
	
	attribute def SensorStatus {
		attribute isCalibrated : Boolean;
		attribute isOperational : Boolean;
		attribute errorCode : Integer;
		attribute temperature : TemperatureValue;
	}
	
	item def MagneticField {
		attribute fieldStrength : MagneticFluxDensityValue;
		attribute orientation : Real[3];
		attribute frequency : FrequencyValue;
	}
	
	item def RawSensorSignal {
		attribute outputVoltage : VoltageValue;
		attribute timestamp : Real;
	}
	
	item def DigitalMeasurement {
		attribute digitalValue : Integer;
		attribute resolution : Integer;
	}
	
	item def CalibratedMeasurement {
		attribute fieldMeasurement : MagneticFluxDensityValue;
		attribute uncertainty : Real;
		attribute timestamp : Real;
	}
	
	port def MagneticFieldInputPort {
		in item externalField : MagneticField;
	}
	
	port def MeasurementOutputPort {
		out item measurement : CalibratedMeasurement;
		out item status : SensorStatus;
	}
	
	port def PowerInputPort {
		in item supplyVoltage : VoltageValue;
		in item supplyCurrent : Real;
	}
	
	port def AnalogSignalPort {
		out item analogSignal : VoltageValue;
	}
	
	port def DigitalDataPort {
		out item digitalData : Integer;
	}
	
	part def HallEffectSensor {
		attribute sensitivity : Real;
		attribute operatingRange : MagneticFluxDensityValue[2];
		attribute calibrationOffset : MagneticFluxDensityValue;
		attribute temperatureCoefficient : Real;
		
		port fieldInput : MagneticFieldInputPort;
		port analogOutput : AnalogSignalPort;
		port powerInput : PowerInputPort;
		
		attribute currentReading : VoltageValue;
		attribute sensorTemperature : TemperatureValue;
	}
	
	part def SignalConditioner {
		attribute amplificationGain : Real;
		attribute filterCutoffFrequency : FrequencyValue;
		attribute inputImpedance : Real;
		attribute outputImpedance : Real;
		
		port analogInput {
			in item rawSignal : VoltageValue;
		}
		
		port analogOutput {
			out item conditionedSignal : VoltageValue;
		}
		
		port powerInput : PowerInputPort;
	}
	
	part def AnalogToDigitalConverter {
		attribute resolution : Integer;
		attribute samplingRate : FrequencyValue;
		attribute referenceVoltage : VoltageValue;
		attribute conversionTime : Real;
		
		port analogInput {
			in item analogSignal : VoltageValue;
		}
		
		port digitalOutput : DigitalDataPort;
		
		port powerInput : PowerInputPort;
	}
	
	part def MicrocontrollerUnit {
		attribute processingSpeed : FrequencyValue;
		attribute memorySize : Integer;
		attribute calibrationTable : Real[100];
		
		port digitalInput : DigitalDataPort;
		
		port dataOutput {
			out item processedMeasurement : CalibratedMeasurement;
			out item diagnosticStatus : SensorStatus;
		}
		
		port powerInput : PowerInputPort;
		
		attribute storedCalibrationOffset : MagneticFluxDensityValue;
	}
	
	action def CalibrateHallSensor {
		in ambientField : MagneticField;
		in referenceField : MagneticFluxDensityValue;
		out calibrationOffset : MagneticFluxDensityValue;
		out calibrationSuccess : Boolean;
		
		action measureAmbient {
			in item field : MagneticField;
			out item ambientReading : VoltageValue;
		}
		
		action measureReference {
			in item refField : MagneticFluxDensityValue;
			out item referenceReading : VoltageValue;
		}
		
		action calculateOffset {
			in item ambientVoltage : VoltageValue;
			in item referenceVoltage : VoltageValue;
			in item knownField : MagneticFluxDensityValue;
			out item offset : MagneticFluxDensityValue;
			out item success : Boolean;
		}
		
		bind measureAmbient.field = ambientField;
		bind measureReference.refField = referenceField;
		
		flow from measureAmbient.ambientReading to calculateOffset.ambientVoltage;
		flow from measureReference.referenceReading to calculateOffset.referenceVoltage;
		
		bind calculateOffset.knownField = referenceField;
		bind calculateOffset.offset = calibrationOffset;
		bind calculateOffset.success = calibrationSuccess;
	}
	
	action def MeasureMagneticField {
		in externalField : MagneticField;
		in sensorCalibration : MagneticFluxDensityValue;
		in sensorSensitivity : Real;
		out measuredField : CalibratedMeasurement;
		out operationalStatus : SensorStatus;
		
		action senseField {
			in item field : MagneticField;
			out item rawSignal : RawSensorSignal;
		}
		
		action conditionSignal {
			in item rawVoltage : VoltageValue;
			in item gain : Real;
			out item conditionedVoltage : VoltageValue;
		}
		
		action convertToDigital {
			in item analogVoltage : VoltageValue;
			in item resolution : Integer;
			out item digitalMeasurement : DigitalMeasurement;
		}
		
		action processData {
			in item digitalValue : Integer;
			in item calibrationOffset : MagneticFluxDensityValue;
			in item sensitivity : Real;
			out item calibratedMeasurement : CalibratedMeasurement;
		}
		
		action performDiagnostics {
			in item measurement : CalibratedMeasurement;
			out item status : SensorStatus;
		}
		
		bind senseField.field = externalField;
		
		flow from senseField.rawSignal to conditionSignal.rawVoltage;
		flow from conditionSignal.conditionedVoltage to convertToDigital.analogVoltage;
		flow from convertToDigital.digitalMeasurement to processData.digitalValue;
		
		bind processData.calibrationOffset = sensorCalibration;
		bind processData.sensitivity = sensorSensitivity;
		bind processData.calibratedMeasurement = measuredField;
		
		flow from processData.calibratedMeasurement to performDiagnostics.measurement;
		bind performDiagnostics.status = operationalStatus;
	}
	
	state def SensorOperatingStates {
		entry; then powerUp;
		
		state powerUp {
			entry; then checkPowerSupply;
			
			action checkPowerSupply;
		}
		
		transition powerUp_to_initialization
			first powerUp
			then initialization;
		
		state initialization {
			entry; then selfTest;
			
			state selfTest {
				entry; then testSensorResponse;
				
				action testSensorResponse;
			}
			
			transition selfTest_to_calibration
				first selfTest
				then calibration;
			
			state calibration {
				entry; then performCalibration;
				
				action performCalibration;
			}
		}
		
		transition initialization_to_operational
			first initialization
			then operational;
		
		state operational {
			entry; then idle;
			
			state idle {
				entry; then waitForTrigger;
				
				action waitForTrigger;
			}
			
			state measuring {
				entry; then acquireMeasurement;
				
				action acquireMeasurement;
			}
			
			state processing {
				entry; then processAndCalibrate;
				
				action processAndCalibrate;
			}
			
			state reporting {
				entry; then outputResults;
				
				action outputResults;
			}
			
			transition idle_to_measuring
				first idle
				then measuring;
			
			transition measuring_to_processing
				first measuring
				then processing;
			
			transition processing_to_reporting
				first processing
				then reporting;
			
			transition reporting_to_idle
				first reporting
				then idle;
		}
		
		transition operational_to_error
			first operational
			then error;
		
		state error {
			entry; then logError;
			
			action logError;
			
			state recoverable {
				entry; then attemptRecovery;
				
				action attemptRecovery;
			}
			
			state critical {
				entry; then shutdownSafely;
				
				action shutdownSafely;
			}
		}
		
		transition error_to_initialization
			first error.recoverable
			then initialization;
		
		transition error_to_powerDown
			first error.critical
			then powerDown;
		
		state powerDown;
	}
	
	part def MagneticSensingUnit {
		attribute operatingTemperatureRange : TemperatureValue[2];
		attribute measurementAccuracy : Real;
		attribute measurementResolution : MagneticFluxDensityValue;
		attribute updateRate : FrequencyValue;
		
		part hallSensor : HallEffectSensor[1] {
			attribute :>> sensitivity = 0.05;
			attribute :>> temperatureCoefficient = 0.001;
		}
		
		part signalConditioner : SignalConditioner[1] {
			attribute :>> amplificationGain = 100.0;
			attribute :>> inputImpedance = 1000000.0;
			attribute :>> outputImpedance = 50.0;
		}
		
		part adc : AnalogToDigitalConverter[1] {
			attribute :>> resolution = 16;
			attribute :>> conversionTime = 0.0001;
		}
		
		part mcu : MicrocontrollerUnit[1] {
			attribute :>> memorySize = 65536;
		}
		
		port fieldInput : MagneticFieldInputPort;
		port measurementOutput : MeasurementOutputPort;
		port powerSupply : PowerInputPort;
		
		connect hallSensor.fieldInput to fieldInput;
		connect hallSensor.powerInput to powerSupply;
		connect hallSensor.analogOutput to signalConditioner.analogInput;
		connect signalConditioner.powerInput to powerSupply;
		connect signalConditioner.analogOutput to adc.analogInput;
		connect adc.powerInput to powerSupply;
		connect adc.digitalOutput to mcu.digitalInput;
		connect mcu.powerInput to powerSupply;
		connect mcu.dataOutput to measurementOutput;
		
		perform action calibrationAction : CalibrateHallSensor;
		perform action measurementAction : MeasureMagneticField;
		
		exhibit state operatingStateMachine : SensorOperatingStates;
	}
	
	requirement def MeasurementRangeRequirement {
		doc /* The sensor shall measure magnetic fields from -100 mT to +100 mT. */
	}
	
	requirement def AccuracyRequirement {
		doc /* The measurement accuracy shall be within 2% of the full scale. */
	}
	
	requirement def ResponseTimeRequirement {
		doc /* The sensor shall provide updated readings at minimum 100 Hz. */
	}
	
	requirement def CalibrationRequirement {
		doc /* The sensor shall perform automatic calibration on startup. */
	}
	
	requirement def TemperatureStabilityRequirement {
		doc /* The sensor shall maintain accuracy over -40°C to +85°C operating range. */
	}
	
	requirement def MagneticSensingRequirement {
		doc /* The sensing unit shall measure magnetic flux density using a Hall effect sensor. */
		
		subject sensingUnit : MagneticSensingUnit;
		
		require rangeReq : MeasurementRangeRequirement;
		require accReq : AccuracyRequirement;
		require respReq : ResponseTimeRequirement;
		require calReq : CalibrationRequirement;
		require tempReq : TemperatureStabilityRequirement;
	}
	
	requirement measurementRange : MeasurementRangeRequirement;
	requirement accuracy : AccuracyRequirement;
	requirement responseTime : ResponseTimeRequirement;
	requirement calibration : CalibrationRequirement;
	requirement temperatureStability : TemperatureStabilityRequirement;
	
	part sensingUnitInstance : MagneticSensingUnit {
		attribute :>> measurementAccuracy = 0.02;
		
		satisfy measurementRange by sensingUnitInstance;
		satisfy accuracy by sensingUnitInstance;
		satisfy responseTime by sensingUnitInstance;
		satisfy calibration by sensingUnitInstance.calibrationAction;
		satisfy temperatureStability by sensingUnitInstance;
	}
}
