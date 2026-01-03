package 'Angular Rate Sensing Unit' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import Measurement::*;
	
	attribute def AngularVelocityUnit :> MeasurementUnit {
		attribute :>> unitPowerFactor : UnitPowerFactor[2] ordered;
		attribute :>> unitPowerFactor[1] {
			attribute :>> unit = SI::rad;
			attribute :>> exponent = 1.0;
		}
		attribute :>> unitPowerFactor[2] {
			attribute :>> unit = SI::s;
			attribute :>> exponent = -1.0;
		}
	}
	
	attribute def AngularVelocityValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : AngularVelocityUnit;
	}
	
	attribute angularVelocity : AngularVelocityValue :> ISQ::quantity;
	
	attribute def VoltageUnit :> MeasurementUnit {
		attribute :>> unitPowerFactor : UnitPowerFactor[1] ordered;
		attribute :>> unitPowerFactor[1] {
			attribute :>> unit = SI::V;
			attribute :>> exponent = 1.0;
		}
	}
	
	attribute def VoltageValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : VoltageUnit;
	}
	
	attribute voltage : VoltageValue :> ISQ::quantity;
	
	item def AngularRateSignal {
		attribute rate : AngularVelocityValue;
		attribute timestamp : Real;
	}
	
	item def PowerInput {
		attribute supplyVoltage : VoltageValue;
	}
	
	item def DigitalOutput {
		attribute value : Integer;
		attribute timestamp : Real;
	}
	
	port def PowerPort {
		in item power : PowerInput;
	}
	
	port def AnalogOutputPort {
		out item signal : AngularRateSignal;
	}
	
	port def DigitalOutputPort {
		out item data : DigitalOutput;
	}
	
	part def AngularRateSensor {
		attribute sensorId : String;
		attribute measurementRange : AngularVelocityValue;
		attribute sensitivity : Real;
		attribute bias : AngularVelocityValue;
		attribute currentRate : AngularVelocityValue;
		
		port powerIn : PowerPort;
		port analogOut : AnalogOutputPort;
		port digitalOut : DigitalOutputPort;
		
		part sensingElement : GyroscopicElement {
			attribute :>> detectedRate = currentRate;
		}
		
		part signalProcessor : SignalProcessor {
			in attribute rawRate : AngularVelocityValue;
			out attribute processedSignal : AngularRateSignal;
		}
		
		part adc : AnalogToDigitalConverter {
			in attribute analogInput : AngularRateSignal;
			out attribute digitalOutput : DigitalOutput;
			attribute resolution : Integer;
		}
		
		connect sensingElement.rateOutput to signalProcessor.rawRate;
		connect signalProcessor.processedSignal to adc.analogInput;
		connect signalProcessor.processedSignal to analogOut.signal;
		connect adc.digitalOutput to digitalOut.data;
	}
	
	part def GyroscopicElement {
		attribute detectedRate : AngularVelocityValue;
		out attribute rateOutput : AngularVelocityValue;
		
		attribute :>> rateOutput = detectedRate;
	}
	
	part def SignalProcessor {
		in attribute rawRate : AngularVelocityValue;
		out attribute processedSignal : AngularRateSignal;
		attribute gain : Real default = 1.0;
		attribute offset : AngularVelocityValue;
		
		part amplifier : Amplifier {
			attribute amplificationFactor : Real = gain;
		}
		
		part lowPassFilter : LowPassFilter {
			attribute cutoffFrequency : Real;
		}
	}
	
	part def Amplifier {
		attribute amplificationFactor : Real;
	}
	
	part def LowPassFilter {
		attribute cutoffFrequency : Real;
	}
	
	part def AnalogToDigitalConverter {
		in attribute analogInput : AngularRateSignal;
		out attribute digitalOutput : DigitalOutput;
		attribute resolution : Integer;
		attribute samplingRate : Real;
	}
	
	action def MeasureAngularRate {
		in item physicalMotion : AngularVelocityValue;
		out item measurement : AngularRateSignal;
	}
	
	action def CalibrateAngularRateSensor {
		in item sensor : AngularRateSensor;
		out calibrationComplete : Boolean;
	}
	
	action def ProcessAngularRateData {
		in item rawData : AngularRateSignal;
		out item processedData : AngularRateSignal;
	}
	
	event def PowerOnEvent;
	event def WarmupCompleteEvent;
	event def CalibrationCompleteEvent;
	event def DataAcquiredEvent;
	event def ProcessingCompleteEvent;
	event def OutputCompleteEvent;
	event def PowerOffEvent;
	event def FaultDetectedEvent;
	event def ResetEvent;
	
	state def SensorOperatingStates {
		entry; then idle;
		
		state idle;
		transition idle_to_warmup
			first idle
			accept PowerOnEvent
			then warmup;
		
		state warmup;
		transition warmup_to_calibrating
			first warmup
			accept WarmupCompleteEvent
			then calibrating;
		
		state calibrating;
		transition calibrating_to_measuring
			first calibrating
			accept CalibrationCompleteEvent
			then measuring;
		
		state measuring {
			entry; then acquiring;
			
			state acquiring;
			transition acquiring_to_processing
				first acquiring
				accept DataAcquiredEvent
				then processing;
			
			state processing;
			transition processing_to_outputting
				first processing
				accept ProcessingCompleteEvent
				then outputting;
			
			state outputting;
			transition outputting_to_acquiring
				first outputting
				accept OutputCompleteEvent
				then acquiring;
		}
		
		transition measuring_to_idle
			first measuring
			accept PowerOffEvent
			then idle;
		
		state fault;
		transition idle_to_fault
			first idle
			accept FaultDetectedEvent
			then fault;
		transition warmup_to_fault
			first warmup
			accept FaultDetectedEvent
			then fault;
		transition calibrating_to_fault
			first calibrating
			accept FaultDetectedEvent
			then fault;
		transition measuring_to_fault
			first measuring
			accept FaultDetectedEvent
			then fault;
		
		transition fault_to_idle
			first fault
			accept ResetEvent
			then idle;
	}
	
	part def SensingUnit {
		attribute unitId : String;
		attribute maxMeasurementRate : Real;
		
		part sensor : AngularRateSensor {
			attribute :>> sensorId = "GYRO-001";
			attribute :>> measurementRange = AngularVelocityValue {
				:>> num = 500.0;
				:>> mRef = AngularVelocityUnit {};
			}
			attribute :>> sensitivity = 0.01;
			attribute :>> bias = AngularVelocityValue {
				:>> num = 0.0;
				:>> mRef = AngularVelocityUnit {};
			}
		}
		
		part powerSupply : PowerSupplyModule {
			attribute outputVoltage : VoltageValue = VoltageValue {
				:>> num = 5.0;
				:>> mRef = VoltageUnit {};
			}
		}
		
		part dataProcessor : DataProcessingUnit {
			in attribute sensorData : DigitalOutput;
			out attribute processedOutput : AngularRateSignal;
		}
		
		connect powerSupply.powerOut to sensor.powerIn;
		connect sensor.digitalOut to dataProcessor.sensorData;
		
		perform action measurementCycle : MeasurementCycle;
	}
	
	part def PowerSupplyModule {
		attribute outputVoltage : VoltageValue;
		port powerOut : PowerPort;
	}
	
	part def DataProcessingUnit {
		in attribute sensorData : DigitalOutput;
		out attribute processedOutput : AngularRateSignal;
		attribute processingAlgorithm : String;
	}
	
	action def MeasurementCycle {
		action calibrate : CalibrateAngularRateSensor;
		then fork;
		then measure : MeasureAngularRate {
			out measurement : AngularRateSignal;
		}
		then joinNode;
		then process : ProcessAngularRateData {
			in rawData : AngularRateSignal;
			out processedData : AngularRateSignal;
		}
		then joinNode;
		
		flow from measure.measurement to process.rawData;
		
		join joinNode;
		then done;
	}
	
	requirement def SensingAccuracyRequirement {
		doc /* The angular rate sensor shall measure angular velocity with an accuracy of ±1% over the specified range. */
		
		subject sensor : AngularRateSensor;
		
		require constraint {
			sensor.sensitivity <= 0.01
		}
	}
	
	requirement def MeasurementRangeRequirement {
		doc /* The sensing unit shall measure angular rates from -500 to +500 rad/s. */
		
		subject unit : SensingUnit;
		
		require constraint {
			unit.sensor.measurementRange.num >= 500.0
		}
	}
	
	requirement def OperatingRequirement {
		doc /* The sensor shall operate continuously and provide stable measurements. */
		
		subject sensor : AngularRateSensor;
	}
	
	part sensingUnitInstance : SensingUnit {
		attribute :>> unitId = "ASU-100";
		attribute :>> maxMeasurementRate = 1000.0;
		
		part :>> sensor {
			attribute :>> currentRate = AngularVelocityValue {
				:>> num = 0.0;
				:>> mRef = AngularVelocityUnit {};
			}
			
			exhibit state behavior : SensorOperatingStates;
		}
		
		satisfy accuracyReq : SensingAccuracyRequirement {
			subject sensorRef = sensor;
		}
		
		satisfy rangeReq : MeasurementRangeRequirement {
			subject unitRef = sensingUnitInstance;
		}
		
		satisfy operatingReq : OperatingRequirement {
			subject sensorRef = sensor;
		}
	}
}
