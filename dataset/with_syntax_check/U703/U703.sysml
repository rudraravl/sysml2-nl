package 'GyroscopicSensingUnit' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import UnitsAndScales::*;
	private import Quantities::*;
	
	attribute def AngularVelocityUnit :> MeasurementUnit {
		attribute :>> unitPowerFactor : UnitPowerFactor[2] ordered {
			[0] {
				attribute :>> unit = SI::rad;
				attribute :>> exponent = 1.0;
			}
			[1] {
				attribute :>> unit = SI::s;
				attribute :>> exponent = -1.0;
			}
		}
	}
	
	attribute radPerSecond : AngularVelocityUnit;
	
	attribute def AngularVelocityValue :> VectorQuantityValue {
		attribute :>> num : Real[3];
		attribute :>> mRef : AngularVelocityUnit;
	}
	
	attribute def TemperatureValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : SI::TemperatureUnit;
	}
	
	attribute def VoltageValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : SI::VoltageUnit;
	}
	
	attribute def FrequencyValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : SI::FrequencyUnit;
	}
	
	item def GyroscopeReading {
		attribute xRate : Real;
		attribute yRate : Real;
		attribute zRate : Real;
		attribute timestamp : Real;
	}
	
	item def CalibrationParameters {
		attribute xBias : Real;
		attribute yBias : Real;
		attribute zBias : Real;
		attribute scaleFactor : Real;
	}
	
	item def DiagnosticData {
		attribute temperature : TemperatureValue;
		attribute voltage : VoltageValue;
		attribute statusCode : Integer;
	}
	
	port def SensorDataPort {
		out item reading : GyroscopeReading;
		out item diagnostics : DiagnosticData;
	}
	
	port def PowerSupplyPort {
		in item voltage : VoltageValue;
	}
	
	port def ConfigurationPort {
		in item calibration : CalibrationParameters;
		in item sampleRate : FrequencyValue;
	}
	
	action def SenseRotation {
		in item physicalRotation : AngularVelocityValue;
		out item rawReading : AngularVelocityValue;
	}
	
	action def CalibrateReading {
		in item rawData : AngularVelocityValue;
		in item calibParams : CalibrationParameters;
		out item calibratedData : AngularVelocityValue;
	}
	
	action def CompensateTemperature {
		in item inputData : AngularVelocityValue;
		in item currentTemp : TemperatureValue;
		out item compensatedData : AngularVelocityValue;
	}
	
	action def FilterSignal {
		in item rawSignal : AngularVelocityValue;
		out item filteredSignal : AngularVelocityValue;
	}
	
	action def FormatOutput {
		in item processedData : AngularVelocityValue;
		out item outputReading : GyroscopeReading;
	}
	
	action def PerformMeasurement {
		in item rotation : AngularVelocityValue;
		in item calib : CalibrationParameters;
		in item temp : TemperatureValue;
		out item finalReading : GyroscopeReading;
		
		action sense : SenseRotation {
			in item :>> physicalRotation = rotation;
			out item raw : AngularVelocityValue :>> rawReading;
		}
		
		succession flow from sense.raw to calibrate.rawData;
		
		action calibrate : CalibrateReading {
			in item :>> rawData;
			in item :>> calibParams = calib;
			out item calibrated : AngularVelocityValue :>> calibratedData;
		}
		
		succession flow from calibrate.calibrated to compensate.inputData;
		
		action compensate : CompensateTemperature {
			in item :>> inputData;
			in item :>> currentTemp = temp;
			out item compensated : AngularVelocityValue :>> compensatedData;
		}
		
		succession flow from compensate.compensated to filter.rawSignal;
		
		action filter : FilterSignal {
			in item :>> rawSignal;
			out item filtered : AngularVelocityValue :>> filteredSignal;
		}
		
		succession flow from filter.filtered to format.processedData;
		
		action format : FormatOutput {
			in item :>> processedData;
			out item :>> outputReading = finalReading;
		}
	}
	
	state def GyroscopeStates {
		entry; then powerUp;
		
		state powerUp;
		accept PowerApplied
			then initializing;
		
		state initializing {
			do action performSelfTest;
		}
		accept SelfTestPassed
			then calibrating;
		accept SelfTestFailed
			then fault;
		
		state calibrating {
			do action applyCalibration;
		}
		accept CalibrationComplete
			then ready;
		
		state ready;
		accept StartMeasurement
			then measuring;
		
		state measuring {
			do action continuousMeasurement : PerformMeasurement;
		}
		accept StopMeasurement
			then ready;
		accept OverTemperature
			then fault;
		
		state fault;
		accept Reset
			then initializing;
	}
	
	part def VibratingMassElement {
		attribute resonanceFrequency : FrequencyValue;
		attribute mass : ISQ::MassValue;
		attribute dampingCoefficient : Real;
	}
	
	part def CapacitiveSenseElement {
		attribute capacitance : Real;
		attribute sensitivity : Real;
		attribute noiseFloor : Real;
	}
	
	part def AnalogToDigitalConverter {
		attribute resolution : Integer;
		attribute samplingRate : FrequencyValue;
		attribute referenceVoltage : VoltageValue;
	}
	
	part def DigitalSignalProcessor {
		attribute clockFrequency : FrequencyValue;
		attribute filterOrder : Integer;
	}
	
	part def TemperatureSensor {
		attribute currentTemp : TemperatureValue;
		attribute accuracy : TemperatureValue;
	}
	
	part def VoltageRegulator {
		attribute inputVoltage : VoltageValue;
		attribute outputVoltage : VoltageValue;
		attribute efficiency : Real;
	}
	
	part def GyroscopicSensor {
		attribute xAxisSensitivity : Real;
		attribute yAxisSensitivity : Real;
		attribute zAxisSensitivity : Real;
		attribute biasStability : Real;
		attribute noiseLevel : Real;
		
		part vibratingElement : VibratingMassElement[1];
		part xSensor : CapacitiveSenseElement[1];
		part ySensor : CapacitiveSenseElement[1];
		part zSensor : CapacitiveSenseElement[1];
		part adc : AnalogToDigitalConverter[1];
		part dsp : DigitalSignalProcessor[1];
		part tempSensor : TemperatureSensor[1];
		part regulator : VoltageRegulator[1];
		
		attribute calibration : CalibrationParameters {
			attribute :>> xBias = 0.0;
			attribute :>> yBias = 0.0;
			attribute :>> zBias = 0.0;
			attribute :>> scaleFactor = 1.0;
		}
		
		port dataOut : SensorDataPort;
		port powerIn : PowerSupplyPort;
		port configIn : ConfigurationPort;
		
		perform action measurementCycle : PerformMeasurement;
		
		exhibit state operationalState : GyroscopeStates;
	}
	
	part def SensingUnit {
		part gyroscope : GyroscopicSensor[1];
		
		port measurementOutput : SensorDataPort;
		port powerSupply : PowerSupplyPort;
		port configuration : ConfigurationPort;
		
		connect gyroscope.dataOut to measurementOutput;
		connect powerSupply to gyroscope.powerIn;
		connect configuration to gyroscope.configIn;
	}
	
	requirement def MeasurementRangeRequirement {
		doc /* The gyroscopic sensor shall measure angular velocity across all three axes. */
		
		subject sensor : GyroscopicSensor;
		
		require constraint {
			sensor.xAxisSensitivity > 0.0 and
			sensor.yAxisSensitivity > 0.0 and
			sensor.zAxisSensitivity > 0.0
		}
	}
	
	requirement def CalibrationRequirement {
		doc /* The sensing unit shall apply calibration to compensate for bias errors. */
		
		subject unit : SensingUnit;
		
		require constraint {
			unit.gyroscope.calibration.scaleFactor >= 0.95 and
			unit.gyroscope.calibration.scaleFactor <= 1.05
		}
	}
	
	requirement def TemperatureStabilityRequirement {
		doc /* The sensing unit shall operate within specified temperature range. */
		
		subject unit : SensingUnit;
		
		require constraint {
			unit.gyroscope.tempSensor.currentTemp.num >= 233.15 and
			unit.gyroscope.tempSensor.currentTemp.num <= 358.15
		}
	}
	
	requirement def NoisePerformanceRequirement {
		doc /* The gyroscopic sensor shall maintain noise below specified threshold. */
		
		subject sensor : GyroscopicSensor;
		
		require constraint {
			sensor.noiseLevel <= 0.01
		}
	}
	
	part sensingUnitInstance : SensingUnit {
		part :>> gyroscope {
			attribute :>> xAxisSensitivity = 0.0175;
			attribute :>> yAxisSensitivity = 0.0175;
			attribute :>> zAxisSensitivity = 0.0175;
			attribute :>> biasStability = 0.005;
			attribute :>> noiseLevel = 0.007;
			
			part :>> adc {
				attribute :>> resolution = 16;
			}
			
			part :>> dsp {
				attribute :>> filterOrder = 4;
			}
			
			part :>> regulator {
				attribute :>> efficiency = 0.88;
			}
		}
		
		satisfy rangeReq : MeasurementRangeRequirement {
			subject sensor = sensingUnitInstance.gyroscope;
		}
		
		satisfy calibReq : CalibrationRequirement {
			subject unit = sensingUnitInstance;
		}
		
		satisfy tempReq : TemperatureStabilityRequirement {
			subject unit = sensingUnitInstance;
		}
		
		satisfy noiseReq : NoisePerformanceRequirement {
			subject sensor = sensingUnitInstance.gyroscope;
		}
	}
}
