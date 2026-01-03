package 'Speed Sensing Unit System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import UnitsAndScales::*;
	private import Quantities::*;
	
	attribute def SpeedUnit :> MeasurementUnit {
		attribute :>> unitPowerFactor : UnitPowerFactor[2] ordered;
	}
	
	attribute def SpeedValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : SpeedUnit;
	}
	
	attribute def VoltageValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : VoltageUnit;
	}
	
	attribute def VoltageUnit :> MeasurementUnit;
	
	item def SpeedMeasurement {
		attribute speed : SpeedValue;
		attribute timestamp : Real;
		attribute validity : Boolean;
	}
	
	item def RawSensorData {
		attribute voltage : VoltageValue;
		attribute pulseFrequency : Real;
	}
	
	port def SpeedOutputPort {
		out item measurement : SpeedMeasurement;
	}
	
	port def PowerInputPort {
		in item supply : VoltageValue;
	}
	
	port def DiagnosticPort {
		out item status : SensorStatus;
	}
	
	item def SensorStatus {
		attribute operational : Boolean;
		attribute errorCode : Integer;
		attribute lastCalibration : Real;
	}
	
	action def AcquireRawData {
		out rawData : RawSensorData;
	}
	
	action def ConvertToSpeed {
		in rawData : RawSensorData;
		in calibrationFactor : Real;
		out speedValue : SpeedValue;
	}
	
	action def ValidateMeasurement {
		in speedValue : SpeedValue;
		in minRange : SpeedValue;
		in maxRange : SpeedValue;
		out isValid : Boolean;
	}
	
	action def CreateMeasurement {
		in speedValue : SpeedValue;
		in isValid : Boolean;
		out measurement : SpeedMeasurement;
	}
	
	action def SpeedSensingCycle {
		in calibrationFactor : Real;
		in minRange : SpeedValue;
		in maxRange : SpeedValue;
		out measurement : SpeedMeasurement;
		
		action acquire : AcquireRawData {
			out rawData;
		}
		then action convert : ConvertToSpeed {
			in rawData;
			in calibrationFactor;
			out speedValue;
		}
		then action validate : ValidateMeasurement {
			in speedValue;
			in minRange;
			in maxRange;
			out isValid;
		}
		then action create : CreateMeasurement {
			in speedValue;
			in isValid;
			out measurement;
		}
		
		flow from acquire.rawData to convert.rawData;
		bind convert.calibrationFactor = calibrationFactor;
		flow from convert.speedValue to validate.speedValue;
		bind validate.minRange = minRange;
		bind validate.maxRange = maxRange;
		flow from convert.speedValue to create.speedValue;
		flow from validate.isValid to create.isValid;
		bind measurement = create.measurement;
	}
	
	state def SpeedSensorStateMachine {
		entry; then off;
		
		state off;
		transition off_to_initializing
			first off
			accept pwrOn : PowerOnSignal
			then initializing;
		
		state initializing {
			entry action performSelfTest;
		}
		transition initializing_to_ready
			first initializing
			accept initComp : InitializationComplete
			then ready;
		transition initializing_to_fault
			first initializing
			accept initFail : InitializationFailed
			then fault;
		
		state ready;
		transition ready_to_measuring
			first ready
			accept startMeas : StartMeasurement
			then measuring;
		
		state measuring {
			entry; then acquiring;
			
			state acquiring {
				entry action acquireData;
			}
			transition acquiring_to_processing
				first acquiring
				accept dataAcq : DataAcquired
				then processing;
			
			state processing {
				entry action processData;
			}
			transition processing_to_outputting
				first processing
				accept procComp : ProcessingComplete
				then outputting;
			
			state outputting {
				entry action transmitMeasurement;
			}
			transition outputting_to_acquiring
				first outputting
				accept transComp : TransmissionComplete
				then acquiring;
		}
		
		transition measuring_to_ready
			first measuring
			accept stopMeas : StopMeasurement
			then ready;
		
		transition measuring_to_fault
			first measuring
			accept sensErr : SensorError
			then fault;
		
		state fault {
			entry action reportFault;
		}
		transition fault_to_initializing
			first fault
			accept resetSens : ResetSensor
			then initializing;
		
		transition ready_to_off
			first ready
			accept pwrOff : PowerOffSignal
			then off;
	}
	
	event PowerOnSignal;
	event PowerOffSignal;
	event InitializationComplete;
	event InitializationFailed;
	event StartMeasurement;
	event StopMeasurement;
	event DataAcquired;
	event ProcessingComplete;
	event TransmissionComplete;
	event SensorError;
	event ResetSensor;
	
	action def performSelfTest;
	action def acquireData;
	action def processData;
	action def transmitMeasurement;
	action def reportFault;
	
	part def SpeedSensor {
		attribute sensorId : String;
		attribute calibrationFactor : Real;
		attribute measurementRangeMin : SpeedValue;
		attribute measurementRangeMax : SpeedValue;
		attribute accuracy : Real;
		attribute samplingRate : Real;
		
		port speedOutput : SpeedOutputPort;
		port powerInput : PowerInputPort;
		port diagnostics : DiagnosticPort;
		
		exhibit state behavior : SpeedSensorStateMachine;
		
		perform action sensing : SpeedSensingCycle {
			in calibrationFactor = SpeedSensor::calibrationFactor;
			in minRange = measurementRangeMin;
			in maxRange = measurementRangeMax;
			out measurement;
		}
		
		flow from sensing.measurement to speedOutput.measurement;
	}
	
	part def SignalConditioner {
		attribute filterCutoffFrequency : Real;
		attribute amplificationGain : Real;
		
		port rawInput {
			in item raw : RawSensorData;
		}
		port conditionedOutput {
			out item conditioned : RawSensorData;
		}
		
		action condition {
			in rawSignal : RawSensorData;
			out conditionedSignal : RawSensorData;
		}
		
		flow from rawInput.raw to condition.rawSignal;
		flow from condition.conditionedSignal to conditionedOutput.conditioned;
	}
	
	part def DataLogger {
		attribute bufferSize : Integer;
		attribute loggingInterval : Real;
		
		port dataInput {
			in item measurement : SpeedMeasurement;
		}
		
		action logData {
			in measurement : SpeedMeasurement;
		}
	}
	
	part def SensingUnit {
		attribute unitId : String;
		attribute operatingVoltage : VoltageValue;
		attribute updateRate : Real;
		
		part sensor : SpeedSensor[1] {
			attribute :>> sensorId = "SPD-SENSOR-001";
			attribute :>> calibrationFactor = 1.047;
			attribute :>> accuracy = 0.01;
			attribute :>> samplingRate = 100.0;
		}
		
		part conditioner : SignalConditioner[1] {
			attribute :>> filterCutoffFrequency = 50.0;
			attribute :>> amplificationGain = 2.5;
		}
		
		part logger : DataLogger[1] {
			attribute :>> bufferSize = 1000;
			attribute :>> loggingInterval = 0.1;
		}
		
		port outputPort : SpeedOutputPort;
		port powerPort : PowerInputPort;
		port diagnosticPort : DiagnosticPort;
		
		connect sensor.speedOutput to outputPort;
		connect sensor.diagnostics to diagnosticPort;
		connect powerPort to sensor.powerInput;
		connect sensor.speedOutput to logger.dataInput;
	}
	
	requirement def MeasurementAccuracyRequirement {
		doc /* The sensing unit shall measure speed with accuracy better than 1% of full scale. */
		
		subject unit : SensingUnit;
		
		require constraint {
			unit.sensor.accuracy <= 0.01
		}
	}
	
	requirement def MeasurementRangeRequirement {
		doc /* The sensing unit shall measure speeds from 0 to 150 m/s. */
		
		subject unit : SensingUnit;
		
		require constraint {
			unit.sensor.measurementRangeMin.num == 0.0 and
			unit.sensor.measurementRangeMax.num >= 150.0
		}
	}
	
	requirement def ResponseTimeRequirement {
		doc /* The sensing unit shall provide updated measurements at minimum 10 Hz rate. */
		
		subject unit : SensingUnit;
		
		require constraint {
			unit.updateRate >= 10.0
		}
	}
	
	requirement def PowerRequirement {
		doc /* The sensing unit shall operate on 5V DC supply with tolerance of +/- 0.5V. */
		
		subject unit : SensingUnit;
		
		require constraint {
			unit.operatingVoltage.num >= 4.5 and
			unit.operatingVoltage.num <= 5.5
		}
	}
	
	attribute mps : SpeedUnit {
		attribute :>> unitPowerFactor[1] : UnitPowerFactor {
			attribute :>> unit = m;
			attribute :>> exponent = 1.0;
		}
		attribute :>> unitPowerFactor[2] : UnitPowerFactor {
			attribute :>> unit = s;
			attribute :>> exponent = -1.0;
		}
	}
	
	attribute volt : VoltageUnit;
	
	part sensingUnitInstance : SensingUnit {
		attribute :>> unitId = "SU-2025-001";
		attribute :>> operatingVoltage : VoltageValue {
			attribute :>> num = 5.0;
			attribute :>> mRef = volt;
		}
		attribute :>> updateRate = 50.0;
		
		part :>> sensor {
			attribute :>> measurementRangeMin : SpeedValue {
				attribute :>> num = 0.0;
				attribute :>> mRef = mps;
			}
			attribute :>> measurementRangeMax : SpeedValue {
				attribute :>> num = 200.0;
				attribute :>> mRef = mps;
			}
		}
		
		satisfy accuracyReq : MeasurementAccuracyRequirement {
			subject :>> unit = sensingUnitInstance;
		}
		
		satisfy rangeReq : MeasurementRangeRequirement {
			subject :>> unit = sensingUnitInstance;
		}
		
		satisfy responseReq : ResponseTimeRequirement {
			subject :>> unit = sensingUnitInstance;
		}
		
		satisfy powerReq : PowerRequirement {
			subject :>> unit = sensingUnitInstance;
		}
	}
}
