package 'Tilt Sensing Unit' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import Measurement::*;
	
	attribute def AngleUnit :> SimpleUnit;
	
	attribute def AngleValue :> ScalarQuantityValue {
		attribute redefines num : Real;
		attribute redefines mRef : AngleUnit;
	}
	
	attribute def VoltageValue :> ScalarQuantityValue {
		attribute redefines num : Real;
		attribute redefines mRef : VoltageUnit;
	}
	
	attribute def VoltageUnit :> SimpleUnit;
	
	item def TiltMeasurement {
		attribute pitchAngle : AngleValue;
		attribute rollAngle : AngleValue;
		attribute timestamp : Real;
		attribute quality : Real;
	}
	
	item def RawSensorData {
		attribute pitchVoltage : VoltageValue;
		attribute rollVoltage : VoltageValue;
		attribute temperature : TemperatureValue;
	}
	
	port def SensorDataPort {
		out item rawData : RawSensorData;
	}
	
	port def TiltOutputPort {
		out item measurement : TiltMeasurement;
	}
	
	port def PowerPort {
		in item voltage : VoltageValue;
	}
	
	state def TiltSensorStateMachine {
		entry; then powerOff;
		
		state powerOff;
		
		transition powerOff_to_initializing
			first powerOff
			accept PowerOn
			then initializing;
		
		state initializing {
			entry; then selfTest;
			
			state selfTest;
			
			transition selfTest_to_ready
				first selfTest
				accept SelfTestPassed
				then ready;
			
			state ready;
		}
		
		transition initializing_to_operational
			first initializing.ready
			accept InitializationComplete
			then operational;
		
		state operational {
			entry; then idle;
			
			state idle;
			
			transition idle_to_acquiring
				first idle
				accept StartMeasurement
				then acquiring;
			
			state acquiring;
			
			transition acquiring_to_transmitting
				first acquiring
				accept DataAcquired
				then transmitting;
			
			state transmitting;
			
			transition transmitting_to_idle
				first transmitting
				accept TransmissionComplete
				then idle;
		}
		
		transition operational_to_powerOff
			first operational
			accept PowerOff
			then powerOff;
		
		state fault;
		
		transition any_to_fault
			accept FaultDetected
			then fault;
		
		transition fault_to_initializing
			first fault
			accept Reset
			then initializing;
	}
	
	action def AcquireTiltData {
		out item rawData : RawSensorData;
		
		action readPitchSensor {
			out pitchVoltage : VoltageValue;
		}
		
		fork;
		
		then action readRollSensor {
			out rollVoltage : VoltageValue;
		}
		then joinNode;
		
		then action readTemperature {
			out temperature : TemperatureValue;
		}
		then joinNode;
		
		join joinNode;
		
		then action assembleRawData {
			in pitch : VoltageValue;
			in roll : VoltageValue;
			in temp : TemperatureValue;
			out data : RawSensorData;
		}
		
		flow from readPitchSensor.pitchVoltage to assembleRawData.pitch;
		flow from readRollSensor.rollVoltage to assembleRawData.roll;
		flow from readTemperature.temperature to assembleRawData.temp;
		bind assembleRawData.data = rawData;
		
		then done;
	}
	
	part def TiltSensor {
		port sensorOutput : SensorDataPort;
		port power : PowerPort;
		
		attribute sensitivity : Real default = 0.02;
		attribute operatingRange : AngleValue;
		attribute zeroOffsetPitch : VoltageValue;
		attribute zeroOffsetRoll : VoltageValue;
		
		perform action sense : AcquireTiltData;
		
		state sensorState : TiltSensorStateMachine;
	}
	
	action def ProcessSensorData {
		in item rawInput : RawSensorData;
		out item processedOutput : TiltMeasurement;
		
		action convertVoltageToAngle {
			in raw : RawSensorData;
			out pitchAngle : AngleValue;
			out rollAngle : AngleValue;
		}
		
		then action applyCalibration {
			in pitchRaw : AngleValue;
			in rollRaw : AngleValue;
			out pitchCalibrated : AngleValue;
			out rollCalibrated : AngleValue;
		}
		
		then action applyFilter {
			in pitchCal : AngleValue;
			in rollCal : AngleValue;
			out pitchFiltered : AngleValue;
			out rollFiltered : AngleValue;
		}
		
		then action validateMeasurement {
			in pitchFinal : AngleValue;
			in rollFinal : AngleValue;
			out validated : TiltMeasurement;
		}
		
		bind convertVoltageToAngle.raw = rawInput;
		flow from convertVoltageToAngle.pitchAngle to applyCalibration.pitchRaw;
		flow from convertVoltageToAngle.rollAngle to applyCalibration.rollRaw;
		flow from applyCalibration.pitchCalibrated to applyFilter.pitchCal;
		flow from applyCalibration.rollCalibrated to applyFilter.rollCal;
		flow from applyFilter.pitchFiltered to validateMeasurement.pitchFinal;
		flow from applyFilter.rollFiltered to validateMeasurement.rollFinal;
		bind validateMeasurement.validated = processedOutput;
		
		then done;
	}
	
	part def SignalProcessor {
		port dataInput : SensorDataPort;
		port dataOutput : TiltOutputPort;
		
		attribute calibrationPitchSlope : Real default = 1.0;
		attribute calibrationRollSlope : Real default = 1.0;
		attribute calibrationPitchOffset : AngleValue;
		attribute calibrationRollOffset : AngleValue;
		attribute filterCoefficient : Real default = 0.8;
		
		perform action process : ProcessSensorData;
	}
	
	action def MeasureTiltSequence {
		out item finalMeasurement : TiltMeasurement;
		
		fork;
		
		then action acquiring : AcquireTiltData {
			out rawData;
		}
		then joinNode;
		
		then action processing : ProcessSensorData {
			in rawInput;
			out processedOutput;
		}
		then joinNode;
		
		join joinNode;
		
		flow from acquiring.rawData to processing.rawInput;
		bind processing.processedOutput = finalMeasurement;
		
		then done;
	}
	
	state def SensingUnitStateMachine {
		entry; then offline;
		
		state offline;
		
		transition offline_to_startup
			first offline
			accept SystemPowerOn
			then startup;
		
		state startup {
			entry; then initializingSensor;
			
			state initializingSensor;
			
			transition initializingSensor_to_initializingProcessor
				first initializingSensor
				accept SensorReady
				then initializingProcessor;
			
			state initializingProcessor;
		}
		
		transition startup_to_ready
			first startup.initializingProcessor
			accept ProcessorReady
			then ready;
		
		state ready {
			entry; then standby;
			
			state standby;
			
			transition standby_to_measuring
				first standby
				accept MeasurementRequest
				then measuring;
			
			state measuring;
			
			transition measuring_to_standby
				first measuring
				accept MeasurementComplete
				then standby;
		}
		
		transition ready_to_offline
			first ready
			accept SystemShutdown
			then offline;
		
		state error;
		
		transition any_to_error
			accept SystemError
			then error;
		
		transition error_to_startup
			first error
			accept SystemReset
			then startup;
	}
	
	part def SensingUnit {
		part sensor : TiltSensor[1];
		part processor : SignalProcessor[1];
		port output : TiltOutputPort;
		port powerInput : PowerPort;
		
		connect sensor.sensorOutput to processor.dataInput;
		connect processor.dataOutput to output;
		connect powerInput to sensor.power;
		
		perform action measure : MeasureTiltSequence;
		
		state unitState : SensingUnitStateMachine;
	}
	
	requirement def TiltMeasurementAccuracyRequirement {
		doc /* The sensing unit shall measure tilt angles with specified accuracy. */
		
		subject unit : SensingUnit;
		
		attribute maxPitchError : AngleValue;
		attribute maxRollError : AngleValue;
		
		require constraint {
			maxPitchError.num <= 1.0 and maxRollError.num <= 1.0
		}
	}
	
	requirement def MeasurementRangeRequirement {
		doc /* The tilt sensor shall operate over the full specified angular range. */
		
		subject sensor : TiltSensor;
		
		attribute minAngle : AngleValue;
		attribute maxAngle : AngleValue;
		
		require constraint {
			minAngle.num >= -90.0 and maxAngle.num <= 90.0
		}
	}
	
	requirement def ResponseTimeRequirement {
		doc /* The sensing unit shall provide measurements within the specified time. */
		
		subject unit : SensingUnit;
		
		attribute maxResponseTime : Real;
		
		require constraint {
			maxResponseTime <= 0.1
		}
	}
	
	requirement def OperatingTemperatureRequirement {
		doc /* The sensing unit shall operate within the specified temperature range. */
		
		subject unit : SensingUnit;
		
		attribute minTemperature : TemperatureValue;
		attribute maxTemperature : TemperatureValue;
		
		require constraint {
			minTemperature.num >= -40.0 and maxTemperature.num <= 85.0
		}
	}
	
	part tiltSensingUnitInstance : SensingUnit {
		part redefines sensor {
			attribute :>> sensitivity = 0.015;
			attribute :>> operatingRange {
				attribute :>> num = 180.0;
			}
			attribute :>> zeroOffsetPitch {
				attribute :>> num = 2.5;
			}
			attribute :>> zeroOffsetRoll {
				attribute :>> num = 2.5;
			}
		}
		
		part redefines processor {
			attribute :>> calibrationPitchSlope = 1.02;
			attribute :>> calibrationRollSlope = 0.98;
			attribute :>> calibrationPitchOffset {
				attribute :>> num = 0.5;
			}
			attribute :>> calibrationRollOffset {
				attribute :>> num = -0.3;
			}
			attribute :>> filterCoefficient = 0.75;
		}
		
		perform action :>> measure {
			out item :>> finalMeasurement {
				attribute :>> pitchAngle {
					attribute :>> num = 12.5;
				}
				attribute :>> rollAngle {
					attribute :>> num = -8.3;
				}
				attribute :>> timestamp = 1234.567;
				attribute :>> quality = 0.95;
			}
		}
	}
	
	requirement accuracyReq : TiltMeasurementAccuracyRequirement {
		subject testUnit :> tiltSensingUnitInstance;
		attribute :>> maxPitchError {
			attribute :>> num = 0.5;
		}
		attribute :>> maxRollError {
			attribute :>> num = 0.5;
		}
	}
	
	requirement rangeReq : MeasurementRangeRequirement {
		subject testSensor :> tiltSensingUnitInstance.sensor;
		attribute :>> minAngle {
			attribute :>> num = -90.0;
		}
		attribute :>> maxAngle {
			attribute :>> num = 90.0;
		}
	}
	
	requirement responseReq : ResponseTimeRequirement {
		subject testUnit :> tiltSensingUnitInstance;
		attribute :>> maxResponseTime = 0.08;
	}
	
	requirement tempReq : OperatingTemperatureRequirement {
		subject testUnit :> tiltSensingUnitInstance;
		attribute :>> minTemperature {
			attribute :>> num = -40.0;
		}
		attribute :>> maxTemperature {
			attribute :>> num = 85.0;
		}
	}
}
