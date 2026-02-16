package 'Water Sensing Unit' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import Measurement::*;
	
	attribute def WaterLevelValue :> LengthValue;
	
	attribute def VolumeFlowRateUnit :> DerivedUnit;
	
	attribute def WaterFlowRateValue :> QuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : VolumeFlowRateUnit;
	}
	
	attribute def WaterTemperatureValue :> TemperatureValue;
	
	attribute def WaterQualityIndex {
		attribute indexValue : Real;
		attribute turbidity : Real;
		attribute pH : Real;
		attribute conductivity : Real;
	}
	
	enum def SensorState {
		enum idle;
		enum calibrating;
		enum measuring;
		enum processing;
		enum transmitting;
		enum error;
	}
	
	item def WaterSample {
		attribute volume : VolumeValue;
		attribute sourceLocation : String;
		attribute timestamp : String;
	}
	
	port def SensorDataPort {
		out attribute waterLevel : WaterLevelValue;
		out attribute flowRate : WaterFlowRateValue;
		out attribute temperature : WaterTemperatureValue;
		out attribute quality : WaterQualityIndex;
		out attribute sensorStatus : SensorState;
	}
	
	port def PowerSupplyPort {
		in attribute voltage : Real;
		in attribute current : Real;
	}
	
	port def ControlPort {
		in attribute calibrationCommand : String;
		in attribute measurementInterval : TimeValue;
		out attribute diagnosticInfo : String;
	}
	
	connection def DataConnection {
		end source : SensorDataPort;
		end sink : SensorDataPort;
	}
	
	connection def PowerConnection {
		end source : PowerSupplyPort;
		end sink : PowerSupplyPort;
	}
	
	action def CalibrateWaterSensor {
		in referenceStandard : WaterSample;
		out calibrationFactor : Real;
		out calibrationSuccess : Boolean;
	}
	
	action def MeasureWaterLevel {
		in waterSample : WaterSample;
		out levelReading : WaterLevelValue;
	}
	
	action def MeasureFlowRate {
		in waterSample : WaterSample;
		out flowReading : WaterFlowRateValue;
	}
	
	action def MeasureTemperature {
		in waterSample : WaterSample;
		out temperatureReading : WaterTemperatureValue;
	}
	
	action def MeasureWaterQuality {
		in waterSample : WaterSample;
		out qualityReading : WaterQualityIndex;
	}
	
	action def ProcessSensorData {
		in rawLevel : WaterLevelValue;
		in rawFlow : WaterFlowRateValue;
		in rawTemperature : WaterTemperatureValue;
		in rawQuality : WaterQualityIndex;
		out processedLevel : WaterLevelValue;
		out processedFlow : WaterFlowRateValue;
		out processedTemperature : WaterTemperatureValue;
		out processedQuality : WaterQualityIndex;
	}
	
	action def TransmitSensorData {
		in level : WaterLevelValue;
		in flow : WaterFlowRateValue;
		in temperature : WaterTemperatureValue;
		in quality : WaterQualityIndex;
		out transmissionSuccess : Boolean;
	}
	
	action def WaterSensingCycle {
		in item sample : WaterSample;
		out item finalQuality : WaterQualityIndex;
		
		action measureLevel : MeasureWaterLevel {
			in :>> waterSample = sample;
			out levelReading;
		}
		then fork;
		
		action measureFlow : MeasureFlowRate {
			in :>> waterSample = sample;
			out flowReading;
		}
		then joinNode;
		
		action measureTemp : MeasureTemperature {
			in :>> waterSample = sample;
			out temperatureReading;
		}
		then joinNode;
		
		action measureQuality : MeasureWaterQuality {
			in :>> waterSample = sample;
			out qualityReading;
		}
		then joinNode;
		
		join joinNode;
		then action processData : ProcessSensorData {
			in :>> rawLevel = measureLevel.levelReading;
			in :>> rawFlow = measureFlow.flowReading;
			in :>> rawTemperature = measureTemp.temperatureReading;
			in :>> rawQuality = measureQuality.qualityReading;
			out processedLevel : WaterLevelValue;
			out processedFlow : WaterFlowRateValue;
			out processedTemperature : WaterTemperatureValue;
			out processedQuality : WaterQualityIndex;
		}
		then action transmitData : TransmitSensorData {
			in :>> level = processData.processedLevel;
			in :>> flow = processData.processedFlow;
			in :>> temperature = processData.processedTemperature;
			in :>> quality = processData.processedQuality;
			out transmitSuccess : Boolean;
		}
		
		bind transmitData.quality = finalQuality;
	}
	
	state def WaterSensorStateMachine {
		entry; then idle;
		
		state idle {
			entry assign currentState = SensorState::idle;
		}
		transition idle_to_calibrating
			first idle
			accept CalibrationRequest
			then calibrating;
		
		transition idle_to_measuring
			first idle
			accept MeasurementTrigger
			then measuring;
		
		state calibrating {
			entry assign currentState = SensorState::calibrating;
			do action performCalibration : CalibrateWaterSensor;
		}
		transition calibrating_to_idle
			first calibrating
			then idle;
		
		state measuring {
			entry assign currentState = SensorState::measuring;
			do action performMeasurement : WaterSensingCycle;
		}
		transition measuring_to_processing
			first measuring
			then processing;
		
		state processing {
			entry assign currentState = SensorState::processing;
		}
		transition processing_to_transmitting
			first processing
			then transmitting;
		
		state transmitting {
			entry assign currentState = SensorState::transmitting;
		}
		transition transmitting_to_idle
			first transmitting
			then idle;
		
		transition any_to_error
			accept ErrorEvent
			then errorState;
		
		state errorState {
			entry assign currentState = SensorState::error;
		}
		transition error_to_idle
			first errorState
			accept ResetEvent
			then idle;
		
		attribute currentState : SensorState;
	}
	
	part def WaterSensor {
		attribute sensorId : String;
		attribute accuracy : Real;
		attribute measurementRangeMin : WaterLevelValue;
		attribute measurementRangeMax : WaterLevelValue;
		attribute responseTime : TimeValue;
		
		port dataOutput : SensorDataPort;
		port powerInput : PowerSupplyPort;
		port controlInterface : ControlPort;
	}
	
	part def SignalProcessor {
		attribute processingAlgorithm : String;
		attribute filterType : String;
		attribute samplingRate : FrequencyValue;
		
		port dataInput : SensorDataPort;
		port dataOutput : SensorDataPort;
	}
	
	part def DataTransmitter {
		attribute protocol : String;
		attribute transmissionFrequency : FrequencyValue;
		attribute transmissionPower : PowerValue;
		attribute range : LengthValue;
		
		port dataInput : SensorDataPort;
	}
	
	part def PowerSupply {
		attribute outputVoltage : Real;
		attribute outputCurrent : Real;
		attribute batteryCapacity : EnergyValue;
		attribute batteryLifetime : TimeValue;
		
		port powerOutput : PowerSupplyPort;
	}
	
	part def WaterSensingUnit {
		attribute unitId : String;
		attribute installationLocation : String;
		attribute operatingTempMin : TemperatureValue;
		attribute operatingTempMax : TemperatureValue;
		
		part waterSensor : WaterSensor[1] {
			attribute :>> sensorId = "WS-2024-001";
			attribute :>> accuracy = 0.98;
			attribute :>> responseTime = 2.0[s];
		}
		
		part processor : SignalProcessor[1] {
			attribute :>> processingAlgorithm = "KalmanFilter";
			attribute :>> filterType = "LowPass";
			attribute :>> samplingRate = 10.0[Hz];
		}
		
		part transmitter : DataTransmitter[1] {
			attribute :>> protocol = "LoRaWAN";
			attribute :>> transmissionFrequency = 868.0[MHz];
			attribute :>> range = 5000.0[m];
		}
		
		part powerSupply : PowerSupply[1] {
			attribute :>> outputVoltage = 5.0;
			attribute :>> outputCurrent = 0.5;
			attribute :>> batteryLifetime = 8760.0[h];
		}
		
		port externalControl : ControlPort;
		port externalPower : PowerSupplyPort;
		
		connection sensorToProcessor : DataConnection
			connect waterSensor.dataOutput to processor.dataInput;
		
		connection processorToTransmitter : DataConnection
			connect processor.dataOutput to transmitter.dataInput;
		
		connection powerSupplyToSensor : PowerConnection
			connect powerSupply.powerOutput to waterSensor.powerInput;
		
		perform action sensingOperation : WaterSensingCycle;
		
		exhibit state sensorBehavior : WaterSensorStateMachine;
	}
	
	requirement def AccuracyRequirement {
		doc /* The water sensor shall measure water level with accuracy of at least 98% */
		
		subject sensor : WaterSensor;
		
		require constraint {
			sensor.accuracy >= 0.98
		}
	}
	
	requirement def ResponseTimeRequirement {
		doc /* The water sensor shall respond to water level changes within 3 seconds */
		
		subject sensor : WaterSensor;
		
		require constraint {
			sensor.responseTime.num <= 3.0
		}
	}
	
	requirement def MeasurementRangeRequirement {
		doc /* The water sensor shall measure water levels from 0 to 10 meters */
		
		subject sensor : WaterSensor;
		
		require constraint {
			sensor.measurementRangeMin.num == 0.0 and
			sensor.measurementRangeMax.num >= 10.0
		}
	}
	
	requirement def BatteryLifeRequirement {
		doc /* The sensing unit shall operate continuously for at least 1 year on battery power */
		
		subject supply : PowerSupply;
		
		require constraint {
			supply.batteryLifetime.num >= 8760.0
		}
	}
	
	requirement waterSensingRequirements {
		doc /* Top-level requirements for the water sensing unit */
		
		subject sensingUnit : WaterSensingUnit;
		
		require accuracyReq : AccuracyRequirement {
			subject sensor = sensingUnit.waterSensor;
		}
		
		require responseReq : ResponseTimeRequirement {
			subject sensor = sensingUnit.waterSensor;
		}
		
		require rangeReq : MeasurementRangeRequirement {
			subject sensor = sensingUnit.waterSensor;
		}
		
		require batteryReq : BatteryLifeRequirement {
			subject supply = sensingUnit.powerSupply;
		}
	}
	
	part waterSensingUnitInstance : WaterSensingUnit {
		attribute :>> unitId = "WSU-2024-001";
		attribute :>> installationLocation = "River Monitoring Station Alpha";
		attribute :>> operatingTempMin = -10.0[Celsius];
		attribute :>> operatingTempMax = 50.0[Celsius];
		
		part :>> waterSensor {
			attribute :>> measurementRangeMin = 0.0[m];
			attribute :>> measurementRangeMax = 10.0[m];
		}
		
		satisfy waterSensingRequirements by waterSensingUnitInstance;
	}
	
	individual def TestWaterSample1 :> WaterSample;
	individual def TestWaterSample2 :> WaterSample;
	
	individual testUnit : WaterSensingUnit :> waterSensingUnitInstance {
		timeslice measurement1 {
			perform action :>> sensingOperation {
				in individual :>> sample : TestWaterSample1 {
					:>> volume = 100.0[mL];
					:>> sourceLocation = "Upstream";
					:>> timestamp = "2024-01-15T10:00:00Z";
				}
			}
		}
		then timeslice measurement2 {
			perform action :>> sensingOperation {
				in individual :>> sample : TestWaterSample2 {
					:>> volume = 100.0[mL];
					:>> sourceLocation = "Downstream";
					:>> timestamp = "2024-01-15T10:05:00Z";
				}
			}
		}
	}
}
