package 'Yaw Rate Sensing Unit' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import Quantities::*;
	private import UnitsAndScales::*;
	
	attribute def AngularVelocityUnit :> MeasurementUnit {
		attribute :>> unitPowerFactor : UnitPowerFactor[2] ordered = (
			UnitPowerFactor(unit = SI::rad, exponent = 1.0),
			UnitPowerFactor(unit = SI::s, exponent = -1.0)
		);
	}
	
	attribute def YawRateValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : AngularVelocityUnit;
	}
	
	attribute def VoltageValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : MeasurementUnit;
	}
	
	attribute def TemperatureValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : MeasurementUnit;
	}
	
	item def RawSensorSignal {
		attribute analogVoltage : VoltageValue;
		attribute temperature : TemperatureValue;
		attribute timestamp : Real;
	}
	
	item def ProcessedYawData {
		attribute yawRate : YawRateValue;
		attribute quality : Real;
		attribute valid : Boolean;
	}
	
	item def CalibrationParameters {
		attribute zeroOffset : YawRateValue;
		attribute scaleFactor : Real;
		attribute temperatureCompensation : Real;
	}
	
	port def SensorOutputPort {
		out signal : RawSensorSignal;
	}
	
	port def ProcessedDataPort {
		out data : ProcessedYawData;
	}
	
	port def PowerSupplyPort {
		in voltage : VoltageValue;
		in current : Real;
	}
	
	port def CalibrationPort {
		in parameters : CalibrationParameters;
	}
	
	connection def SignalConnection {
		end source : SensorOutputPort;
		end sink : ProcessedDataPort;
	}
	
	action def AcquireSensorData {
		in power : VoltageValue;
		out rawSignal : RawSensorSignal;
	}
	
	action def ApplyCalibration {
		in rawSignal : RawSensorSignal;
		in calibration : CalibrationParameters;
		out calibratedData : ProcessedYawData;
	}
	
	action def FilterData {
		in calibratedData : ProcessedYawData;
		out filteredData : ProcessedYawData;
	}
	
	action def ValidateData {
		in filteredData : ProcessedYawData;
		out validatedData : ProcessedYawData;
	}
	
	action def MeasureYawRate {
		in powerSupply : VoltageValue;
		in calibrationParams : CalibrationParameters;
		out yawRateOutput : ProcessedYawData;
		
		bind acquireData.power = powerSupply;
		
		action acquireData : AcquireSensorData {
			in power;
			out rawSignal;
		}
		
		then succession flow from acquireData.rawSignal to applyCalibration.rawSignal;
		
		bind applyCalibration.calibration = calibrationParams;
		
		action applyCalibration : ApplyCalibration {
			in rawSignal;
			in calibration;
			out calibratedData;
		}
		
		then succession flow from applyCalibration.calibratedData to filterData.calibratedData;
		
		action filterData : FilterData {
			in calibratedData;
			out filteredData;
		}
		
		then succession flow from filterData.filteredData to validateData.filteredData;
		
		action validateData : ValidateData {
			in filteredData;
			out validatedData;
		}
		
		bind validateData.validatedData = yawRateOutput;
	}
	
	attribute def PowerOnSignal;
	attribute def StartMeasurementSignal;
	attribute def StopMeasurementSignal;
	attribute def ErrorDetectedSignal;
	attribute def ResetSignal;
	
	state def SensorOperationalState {
		entry; then powerOff;
		
		state powerOff;
		transition powerOff_to_initialization
			first powerOff
			accept PowerOnSignal
			then initialization;
		
		state initialization {
			entry; then selfTest;
			state selfTest;
			then calibrationLoad;
			state calibrationLoad;
		}
		transition initialization_to_standby
			first initialization
			then standby;
		
		state standby;
		transition standby_to_active
			first standby
			accept StartMeasurementSignal
			then active;
		
		state active {
			entry; then acquiring;
			state acquiring;
			then processing;
			state processing;
			then outputting;
			state outputting;
		}
		transition active_to_standby
			first active
			accept StopMeasurementSignal
			then standby;
		
		transition active_to_error
			first active
			accept ErrorDetectedSignal
			then error;
		
		state error;
		transition error_to_initialization
			first error
			accept ResetSignal
			then initialization;
	}
	
	part def GyroscopicElement {
		attribute elementType : String;
		attribute sensitivity : Real;
		attribute noiseLevel : YawRateValue;
	}
	
	part def SignalConditioner {
		attribute gain : Real;
		attribute bandwidth : Real;
		attribute filterOrder : Integer;
	}
	
	part def AnalogToDigitalConverter {
		attribute resolution : Integer;
		attribute samplingRate : Real;
	}
	
	part def YawRateSensor {
		attribute sensorID : String;
		attribute measurementRange : YawRateValue;
		
		port sensorOutput : SensorOutputPort;
		port powerInput : PowerSupplyPort;
		
		part gyroElement : GyroscopicElement {
			attribute :>> elementType = "MEMS Vibratory";
			attribute :>> sensitivity = 0.0167;
			attribute :>> noiseLevel : YawRateValue {
				attribute :>> num = 0.01;
			}
		}
		
		part conditioner : SignalConditioner {
			attribute :>> gain = 100.0;
			attribute :>> bandwidth = 200.0;
			attribute :>> filterOrder = 4;
		}
		
		part adc : AnalogToDigitalConverter {
			attribute :>> resolution = 16;
			attribute :>> samplingRate = 1000.0;
		}
	}
	
	part def DataProcessor {
		attribute processorID : String;
		attribute updateRate : Real;
		
		port dataInput : SensorOutputPort;
		port calibrationInput : CalibrationPort;
		port dataOutput : ProcessedDataPort;
		
		part calibrationMemory {
			attribute storedParams : CalibrationParameters {
				attribute :>> zeroOffset : YawRateValue {
					attribute :>> num = 0.0;
				}
				attribute :>> scaleFactor = 1.0;
				attribute :>> temperatureCompensation = 0.001;
			}
		}
		
		part digitalFilter {
			attribute cutoffFrequency : Real default 50.0;
			attribute filterType : String default "Butterworth";
		}
	}
	
	part def YawRateSensingUnit {
		attribute unitID : String;
		attribute operatingVoltage : VoltageValue;
		attribute operatingTemperatureMin : TemperatureValue;
		attribute operatingTemperatureMax : TemperatureValue;
		
		port powerSupply : PowerSupplyPort;
		port calibrationInterface : CalibrationPort;
		port yawRateOutput : ProcessedDataPort;
		
		part sensor : YawRateSensor {
			attribute :>> sensorID = "YRS-2024-001";
			attribute :>> measurementRange : YawRateValue {
				attribute :>> num = 300.0;
			}
		}
		
		part processor : DataProcessor {
			attribute :>> processorID = "PROC-001";
			attribute :>> updateRate = 100.0;
		}
		
		connect sensor.sensorOutput to processor.dataInput;
		connect calibrationInterface to processor.calibrationInput;
		connect processor.dataOutput to yawRateOutput;
		connect powerSupply to sensor.powerInput;
		
		perform action measureYawRate : MeasureYawRate;
		
		exhibit state operationalState : SensorOperationalState;
	}
	
	requirement def YawRateSensingRequirement {
		doc /* The yaw rate sensing unit shall measure vehicle yaw rate with specified accuracy and range. */
		
		subject unit : YawRateSensingUnit;
		
		require constraint measurementAccuracy {
			doc /* Measurement accuracy shall be within ±0.5 deg/s over the full range. */
		}
		
		require constraint measurementRange {
			doc /* Measurement range shall be ±300 deg/s minimum. */
		}
		
		require constraint responseTime {
			doc /* Response time shall be less than 10 milliseconds. */
		}
		
		require constraint operatingTemperature {
			doc /* Operating temperature range shall be -40°C to +85°C. */
		}
		
		require constraint powerConsumption {
			doc /* Power consumption shall not exceed 500 mW during active measurement. */
		}
	}
	
	part yawRateSensingSystem : YawRateSensingUnit {
		attribute :>> unitID = "YRSU-MAIN-001";
		attribute :>> operatingVoltage : VoltageValue {
			attribute :>> num = 5.0;
		}
		attribute :>> operatingTemperatureMin : TemperatureValue {
			attribute :>> num = 233.15;
		}
		attribute :>> operatingTemperatureMax : TemperatureValue {
			attribute :>> num = 358.15;
		}
		
		satisfy systemRequirement : YawRateSensingRequirement {
			subject testUnit :> yawRateSensingSystem;
		}
		
		part :>> sensor {
			part :>> gyroElement {
				attribute :>> elementType = "MEMS Coriolis Vibratory";
				attribute :>> sensitivity = 0.0125;
			}
			part :>> conditioner {
				attribute :>> gain = 150.0;
				attribute :>> bandwidth = 250.0;
			}
		}
		
		part :>> processor {
			attribute :>> updateRate = 200.0;
			part :>> digitalFilter {
				attribute :>> cutoffFrequency = 100.0;
			}
		}
	}
	
	individual def TestCalibration :> CalibrationParameters;
	individual def NominalPower :> VoltageValue;
	
	individual testCalibration : TestCalibration {
		attribute :>> zeroOffset : YawRateValue {
			attribute :>> num = 0.2;
		}
		attribute :>> scaleFactor = 1.005;
		attribute :>> temperatureCompensation = 0.0012;
	}
	
	individual nominalPower : NominalPower {
		attribute :>> num = 5.0;
	}
	
	individual operationalSystem : YawRateSensingUnit :> yawRateSensingSystem {
		timeslice systemInitialization {
			exhibit state :>> operationalState.initialization;
		}
		then timeslice activeMeasurement {
			exhibit state :>> operationalState.active;
			perform action :>> measureYawRate {
				in item :>> powerSupply = nominalPower;
				in item :>> calibrationParams = testCalibration;
				out item :>> yawRateOutput : ProcessedYawData {
					attribute :>> yawRate : YawRateValue {
						attribute :>> num = 32.5;
					}
					attribute :>> quality = 0.95;
					attribute :>> valid = true;
				}
			}
		}
		then timeslice continuedMeasurement {
			exhibit state :>> operationalState.active;
			perform action :>> measureYawRate {
				in item :>> powerSupply = nominalPower;
				in item :>> calibrationParams = testCalibration;
				out item :>> yawRateOutput : ProcessedYawData {
					attribute :>> yawRate : YawRateValue {
						attribute :>> num = 28.3;
					}
					attribute :>> quality = 0.97;
					attribute :>> valid = true;
				}
			}
		}
	}
}
