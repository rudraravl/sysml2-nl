package 'Free Fall Sensing Unit' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import Time::*;
	private import Measurement::*;
	
	attribute def AccelerationUnit :> MeasurementUnit {
		attribute :>> unitPowerFactor : UnitPowerFactor[2] ordered;
		attribute :>> unitPowerFactor[1] {
			attribute :>> unit = SI::m;
			attribute :>> exponent = 1;
		}
		attribute :>> unitPowerFactor[2] {
			attribute :>> unit = SI::s;
			attribute :>> exponent = -2;
		}
	}
	
	attribute def AccelerationValue :> ISQ::AccelerationValue {
		attribute :>> num : Real;
		attribute :>> mRef : AccelerationUnit;
	}
	
	attribute def DurationValue :> ISQ::DurationValue {
		attribute :>> num : Real;
		attribute :>> mRef : SI::s;
	}
	
	item def SensorReading {
		attribute timestamp : DurationValue;
		attribute accelerationX : AccelerationValue;
		attribute accelerationY : AccelerationValue;
		attribute accelerationZ : AccelerationValue;
		attribute magnitude : AccelerationValue;
	}
	
	item def FreeFallEvent {
		attribute detectionTime : DurationValue;
		attribute duration : DurationValue;
		attribute minimumAcceleration : AccelerationValue;
	}
	
	port def SensorDataPort {
		out item reading : SensorReading;
	}
	
	port def EventPort {
		out item freeFallEvent : FreeFallEvent;
	}
	
	port def ControlPort {
		in attribute enable : Boolean;
		in attribute threshold : AccelerationValue;
		out attribute status : String;
	}
	
	connection def DataConnection {
		end source : SensorDataPort;
		end target : SensorDataPort;
	}
	
	action def MeasureAcceleration {
		out reading : SensorReading;
	}
	
	action def FilterSignal {
		in rawReading : SensorReading;
		out filteredReading : SensorReading;
	}
	
	action def CalculateMagnitude {
		in reading : SensorReading;
		out magnitude : AccelerationValue;
	}
	
	action def DetectFreeFall {
		in reading : SensorReading;
		in threshold : AccelerationValue;
		out isFreeFall : Boolean;
	}
	
	action def LogEvent {
		in freeFallEvent : FreeFallEvent;
		out logEntry : String;
	}
	
	part def Accelerometer {
		attribute range : AccelerationValue;
		attribute resolution : AccelerationValue;
		attribute samplingRate : Real;
		
		port dataOut : SensorDataPort;
		
		perform measureAction : MeasureAcceleration {
			out reading;
		}
		
		flow from measureAction.reading to dataOut.reading;
	}
	
	part def SignalProcessor {
		attribute filterCoefficient : Real;
		
		port dataIn : SensorDataPort;
		port dataOut : SensorDataPort;
		
		action processSignal {
			action filterSignal : FilterSignal {
				in rawReading;
				out filteredReading;
			}
			then calculateMagnitude;
			
			action calculateMagnitude : CalculateMagnitude {
				in reading = filterSignal.filteredReading;
				out magnitude;
			}
			
			flow from filterSignal.filteredReading to dataOut.reading;
		}
		
		perform processSignal;
	}
	
	part def FreeFallDetector {
		attribute detectionThreshold : AccelerationValue;
		attribute minimumDuration : DurationValue;
		attribute freeFallActive : Boolean;
		
		port dataIn : SensorDataPort;
		port eventOut : EventPort;
		
		action detectAndReport {
			action detect : DetectFreeFall {
				in reading;
				in threshold = detectionThreshold;
				out isFreeFall;
			}
			then decision;
			
			action decision;
			
			action createEvent {
				out freeFallEvent : FreeFallEvent;
			}
			
			flow from createEvent.freeFallEvent to eventOut.freeFallEvent;
		}
		
		perform detectAndReport;
	}
	
	part def DataLogger {
		attribute storageCapacity : Integer;
		attribute recordCount : Integer;
		
		port eventIn : EventPort;
		
		action logData : LogEvent {
			in freeFallEvent;
			out logEntry;
		}
		
		perform logData;
	}
	
	part def FreeFallSensor {
		attribute sensorId : String;
		attribute calibrationDate : String;
		attribute operationalStatus : String;
		
		port sensorOut : SensorDataPort;
		port control : ControlPort;
		
		part accelerometer : Accelerometer {
			attribute :>> range = 16.0[SI::m / (SI::s ^ 2)];
			attribute :>> resolution = 0.01[SI::m / (SI::s ^ 2)];
			attribute :>> samplingRate = 100.0;
			
			port :>> dataOut;
		}
		
		part processor : SignalProcessor {
			attribute :>> filterCoefficient = 0.8;
			
			port :>> dataIn;
			port :>> dataOut;
		}
		
		connection accelToProcessor : DataConnection
			connect accelerometer.dataOut to processor.dataIn;
		
		connection processorToOutput : DataConnection
			connect processor.dataOut to sensorOut;
	}
	
	part def SensingUnit {
		attribute unitId : String;
		attribute freeFallThreshold : AccelerationValue;
		attribute operatingMode : String;
		
		port dataOutput : SensorDataPort;
		port eventOutput : EventPort;
		port controlInput : ControlPort;
		
		part sensor : FreeFallSensor {
			attribute :>> sensorId = "FF-SENSOR-001";
			attribute :>> calibrationDate = "2025-01-01";
			attribute :>> operationalStatus = "Operational";
			
			port :>> sensorOut;
			port :>> control;
		}
		
		part detector : FreeFallDetector {
			attribute :>> detectionThreshold = 2.0[SI::m / (SI::s ^ 2)];
			attribute :>> minimumDuration = 0.1[SI::s];
			attribute :>> freeFallActive = false;
			
			port :>> dataIn;
			port :>> eventOut;
		}
		
		part logger : DataLogger {
			attribute :>> storageCapacity = 1000;
			attribute :>> recordCount = 0;
			
			port :>> eventIn;
		}
		
		connection sensorToDetector : DataConnection
			connect sensor.sensorOut to detector.dataIn;
		
		connection detectorToLogger
			connect detector.eventOut to logger.eventIn;
		
		connection sensorToExternal : DataConnection
			connect sensor.sensorOut to dataOutput;
		
		connection detectorToExternal
			connect detector.eventOut to eventOutput;
		
		connection externalControl
			connect controlInput to sensor.control;
		
		action sensingOperation {
			action initialize {
				out initComplete : Boolean;
			}
			then fork;
			
			action continuousMeasurement : MeasureAcceleration {
				out reading;
			}
			then joinNode;
			
			action signalProcessing : FilterSignal {
				in rawReading = continuousMeasurement.reading;
				out filteredReading;
			}
			then joinNode;
			
			action freeFallDetection : DetectFreeFall {
				in reading = signalProcessing.filteredReading;
				in threshold = freeFallThreshold;
				out isFreeFall;
			}
			then joinNode;
			
			flow from continuousMeasurement.reading to signalProcessing.rawReading;
			flow from signalProcessing.filteredReading to freeFallDetection.reading;
			
			join joinNode;
			then done;
		}
		
		perform sensingOperation;
	}
	
	requirement def FreeFallSensingRequirement {
		doc /* The sensing unit shall continuously measure acceleration 
		       and detect free fall conditions when the measured acceleration 
		       magnitude falls below the specified threshold. */
		
		subject unit : SensingUnit;
		
		require measurementRange {
			doc /* The sensor shall measure acceleration in the range 
			       of -16 to +16 m/s^2 in all three axes. */
		}
		
		require measurementAccuracy {
			doc /* The sensor shall measure acceleration with a resolution 
			       of 0.01 m/s^2 or better. */
		}
		
		require detectionThreshold {
			doc /* The system shall detect free fall when the acceleration 
			       magnitude remains below 2.0 m/s^2 for at least 100 ms. */
		}
		
		require samplingRate {
			doc /* The sensor shall sample acceleration at a minimum rate 
			       of 100 Hz to ensure accurate detection. */
		}
		
		require responseTime {
			doc /* The system shall detect and report a free fall condition 
			       within 50 ms of its occurrence. */
		}
		
		require dataLogging {
			doc /* The system shall log all detected free fall events with 
			       timestamp, duration, and minimum acceleration. */
		}
	}
	
	part sensingUnitInstance : SensingUnit {
		attribute :>> unitId = "UNIT-001";
		attribute :>> freeFallThreshold = 2.0[SI::m / (SI::s ^ 2)];
		attribute :>> operatingMode = "Continuous";
		
		satisfy freeFallReq : FreeFallSensingRequirement {
			subject testUnit :> sensingUnitInstance;
		}
	}
	
	individual def NormalOperationScenario :> SensingUnit;
	individual def FreeFallScenario :> SensingUnit;
	
	individual testInstance : NormalOperationScenario :> sensingUnitInstance {
		timeslice normalOperation {
			perform action :>> sensingOperation {
				action :>> continuousMeasurement {
					out :>> reading {
						attribute :>> accelerationX = 0.2[SI::m / (SI::s ^ 2)];
						attribute :>> accelerationY = 0.3[SI::m / (SI::s ^ 2)];
						attribute :>> accelerationZ = 9.81[SI::m / (SI::s ^ 2)];
						attribute :>> magnitude = 9.82[SI::m / (SI::s ^ 2)];
					}
				}
				action :>> freeFallDetection {
					out :>> isFreeFall = false;
				}
			}
		}
		then timeslice freeFallDetected {
			perform action :>> sensingOperation {
				action :>> continuousMeasurement {
					out :>> reading {
						attribute :>> accelerationX = 0.1[SI::m / (SI::s ^ 2)];
						attribute :>> accelerationY = 0.05[SI::m / (SI::s ^ 2)];
						attribute :>> accelerationZ = 1.2[SI::m / (SI::s ^ 2)];
						attribute :>> magnitude = 1.21[SI::m / (SI::s ^ 2)];
					}
				}
				action :>> freeFallDetection {
					out :>> isFreeFall = true;
				}
			}
		}
	}
}
