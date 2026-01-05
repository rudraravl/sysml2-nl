package 'Tactile Sensing Unit' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import UnitsAndScales::*;
	private import Quantities::*;
	
	attribute def PressureValue :> ISQ::PressureValue;
	attribute def ForceValue :> ISQ::ForceValue;
	attribute def AreaValue :> ISQ::AreaValue;
	attribute def VoltageValue :> ISQ::ElectricPotentialValue;
	attribute def TemperatureValue :> ISQ::ThermodynamicTemperatureValue;
	
	item def TactileData {
		attribute pressure : PressureValue;
		attribute force : ForceValue;
		attribute contactArea : AreaValue;
		attribute temperature : TemperatureValue;
		attribute timestamp : Real;
	}
	
	item def RawSensorSignal {
		attribute voltage : VoltageValue;
		attribute resistance : Real;
	}
	
	port def TactileDataOutputPort {
		out item tactileData : TactileData;
	}
	
	port def PowerInputPort {
		in attribute voltage : VoltageValue;
		in attribute current : Real;
	}
	
	port def RawSignalPort {
		out item signal : RawSensorSignal;
	}
	
	port def ProcessedSignalPort {
		in item signal : RawSensorSignal;
	}
	
	action def GenerateRawSignal {
		in attribute appliedForce : ForceValue;
		in attribute contactArea : AreaValue;
		out item rawSignal : RawSensorSignal;
	}
	
	action def AmplifySignal {
		in item inputSignal : RawSensorSignal;
		in attribute gain : Real;
		out item amplifiedSignal : RawSensorSignal;
	}
	
	action def ConvertSignal {
		in item analogSignal : RawSensorSignal;
		out item digitalSignal : RawSensorSignal;
	}
	
	action def ProcessRawData {
		in item rawSignal : RawSensorSignal;
		in attribute calibrationFactor : Real;
		out item tactileData : TactileData;
	}
	
	action def LogTactileData {
		in item data : TactileData;
	}
	
	part def PiezoelectricElement {
		attribute materialType : String;
		attribute activeArea : AreaValue;
		attribute piezoCoefficient : Real;
		
		port rawOutput : RawSignalPort;
		
		action generateSignal : GenerateRawSignal;
	}
	
	part def SignalAmplifier {
		attribute gain : Real;
		attribute bandwidth : Real;
		
		port signalInput : ProcessedSignalPort;
		port signalOutput : RawSignalPort;
		
		action amplify : AmplifySignal;
	}
	
	part def AnalogToDigitalConverter {
		attribute resolution : Integer;
		attribute samplingRate : Real;
		
		port analogInput : ProcessedSignalPort;
		port digitalOutput : RawSignalPort;
		
		action convert : ConvertSignal;
	}
	
	state def TactileSensorStates {
		entry; then idle;
		
		state idle;
		
		transition idle_to_calibrating
			first idle
			accept CalibrationRequest
			then calibrating;
		
		state calibrating;
		
		transition calibrating_to_ready
			first calibrating
			accept CalibrationComplete
			then ready;
		
		state ready;
		
		transition ready_to_measuring
			first ready
			accept MeasurementTrigger
			then measuring;
		
		state measuring {
			entry; then acquiring;
			
			state acquiring;
			
			transition acquiring_to_processing
				first acquiring
				accept DataAcquired
				then processing;
			
			state processing;
			
			transition processing_to_outputting
				first processing
				accept DataProcessed
				then outputting;
			
			state outputting;
			
			transition outputting_to_done
				first outputting
				accept DataOutput
				then done;
		}
		
		transition measuring_to_ready
			first measuring
			accept MeasurementComplete
			then ready;
		
		state error;
		
		transition any_to_error
			accept ErrorDetected
			then error;
		
		transition error_to_idle
			first error
			accept ErrorCleared
			then idle;
	}
	
	part def TactileSensor {
		attribute sensorId : String;
		attribute sensitivity : Real;
		attribute responseTime : Real;
		attribute operatingMode : String;
		
		port powerIn : PowerInputPort;
		port dataOut : RawSignalPort;
		
		part sensingElement : PiezoelectricElement[1] {
			attribute :>> materialType = "PVDF";
			attribute :>> piezoCoefficient = 33.0;
		}
		
		part amplifier : SignalAmplifier[1] {
			attribute :>> gain = 100.0;
			attribute :>> bandwidth = 10000.0;
		}
		
		part adc : AnalogToDigitalConverter[1] {
			attribute :>> resolution = 16;
			attribute :>> samplingRate = 1000.0;
		}
		
		connect sensingElement.rawOutput to amplifier.signalInput;
		connect amplifier.signalOutput to adc.analogInput;
		connect adc.digitalOutput to dataOut;
		
		state sensorOperation : TactileSensorStates;
	}
	
	part def SignalProcessor {
		attribute filterCutoffFrequency : Real;
		
		port rawDataIn : ProcessedSignalPort;
		port processedDataOut : TactileDataOutputPort;
		
		action processSignal : ProcessRawData;
	}
	
	part def DataLogger {
		attribute bufferSize : Integer;
		attribute storageCapacity : Integer;
		attribute currentSampleCount : Integer;
		
		port dataIn : TactileDataOutputPort;
		
		action logData : LogTactileData;
	}
	
	action def MeasureTactileQuantity {
		in attribute appliedForce : ForceValue;
		in attribute contactArea : AreaValue;
		in attribute calibrationFactor : Real;
		out item measuredData : TactileData;
		
		action generate : GenerateRawSignal {
			in appliedForce;
			in contactArea;
			out rawSignal;
		}
		then action amplify : AmplifySignal {
			in inputSignal;
			in gain = 100.0;
			out amplifiedSignal;
		}
		then action convert : ConvertSignal {
			in analogSignal;
			out digitalSignal;
		}
		then action process : ProcessRawData {
			in rawSignal;
			in calibrationFactor;
			out tactileData;
		}
		
		flow from generate.rawSignal to amplify.inputSignal;
		flow from amplify.amplifiedSignal to convert.analogSignal;
		flow from convert.digitalSignal to process.rawSignal;
		
		bind process.tactileData = measuredData;
	}
	
	part def TactileSensingUnit {
		attribute unitId : String;
		
		port powerSupply : PowerInputPort;
		port tactileOutput : TactileDataOutputPort;
		
		part sensor : TactileSensor[1];
		part processor : SignalProcessor[1];
		part logger : DataLogger[1];
		
		connect sensor.dataOut to processor.rawDataIn;
		connect processor.processedDataOut to tactileOutput;
		connect processor.processedDataOut to logger.dataIn;
		connect powerSupply to sensor.powerIn;
		
		action measurementAction : MeasureTactileQuantity;
	}
	
	part tactileSensingUnit : TactileSensingUnit {
		attribute :>> unitId = "TSU-001";
		
		part :>> sensor {
			attribute :>> sensorId = "TS-PIEZO-001";
			attribute :>> sensitivity = 0.98;
			attribute :>> responseTime = 0.001;
			
			part :>> sensingElement {
				attribute :>> activeArea = 100.0[mm^2];
			}
		}
		
		part :>> processor {
			attribute :>> filterCutoffFrequency = 500.0;
		}
		
		part :>> logger {
			attribute :>> bufferSize = 1000;
			attribute :>> storageCapacity = 100000;
			attribute :>> currentSampleCount = 0;
		}
	}
	
	requirement def TactileSensingRequirement {
		doc /* The tactile sensing unit shall measure contact force, pressure, 
		       contact area, and temperature using a piezoelectric tactile sensor 
		       with specified accuracy, response time, and operating range. */
		
		require accuracyReq : AccuracyRequirement;
		require responseReq : ResponseTimeRequirement;
		require rangeReq : MeasurementRangeRequirement;
		require reliabilityReq : ReliabilityRequirement;
	}
	
	requirement def AccuracyRequirement {
		doc /* The tactile sensor shall measure force with accuracy better than 
		       ±2% of full scale and pressure with accuracy better than ±1.5% 
		       of full scale. */
		
		attribute maxForceError : Real = 0.02;
		attribute maxPressureError : Real = 0.015;
	}
	
	requirement def ResponseTimeRequirement {
		doc /* The tactile sensor shall respond to changes in applied force 
		       within 1 millisecond. */
		
		attribute maxResponseTime : Real = 0.001;
	}
	
	requirement def MeasurementRangeRequirement {
		doc /* The tactile sensor shall measure forces from 0 to 100 N, 
		       pressures from 0 to 1000 kPa, and temperatures from 
		       -20 to 85 degrees Celsius. */
		
		attribute minForce : ForceValue;
		attribute maxForce : ForceValue;
		attribute minPressure : PressureValue;
		attribute maxPressure : PressureValue;
		attribute minTemperature : TemperatureValue;
		attribute maxTemperature : TemperatureValue;
	}
	
	requirement def ReliabilityRequirement {
		doc /* The tactile sensing unit shall operate continuously for at least 
		       10000 hours with a failure rate less than 0.1%. */
		
		attribute minOperatingHours : Real = 10000.0;
		attribute maxFailureRate : Real = 0.001;
	}
	
	requirement tactileSensingReq : TactileSensingRequirement {
		subject sensingUnitSubject : TactileSensingUnit;
		
		require :>> accuracyReq {
			assume constraint {
				sensingUnitSubject.sensor.sensitivity >= 0.98
			}
		}
		
		require :>> responseReq {
			assume constraint {
				sensingUnitSubject.sensor.responseTime <= maxResponseTime
			}
		}
		
		require :>> rangeReq {
			assume constraint {
				sensingUnitSubject.sensor.sensingElement.activeArea >= 50.0[mm^2]
			}
		}
	}
	
	individual def TestSensingUnit :> TactileSensingUnit;
	
	individual testUnit : TestSensingUnit :> tactileSensingUnit {
		timeslice measurement1 {
			perform action :>> measurementAction {
				in attribute :>> appliedForce = 15.0[N];
				in attribute :>> contactArea = 100.0[mm^2];
				in attribute :>> calibrationFactor = 1.02;
			}
		}
		then timeslice measurement2 {
			perform action :>> measurementAction {
				in attribute :>> appliedForce = 35.0[N];
				in attribute :>> contactArea = 150.0[mm^2];
				in attribute :>> calibrationFactor = 1.02;
			}
		}
		then timeslice measurement3 {
			perform action :>> measurementAction {
				in attribute :>> appliedForce = 50.0[N];
				in attribute :>> contactArea = 200.0[mm^2];
				in attribute :>> calibrationFactor = 1.02;
			}
		}
	}
}
