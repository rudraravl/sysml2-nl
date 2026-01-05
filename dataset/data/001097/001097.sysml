package 'Impact Sensing Unit Model' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def AccelerationValue {
		attribute num : Real[3];
		attribute mRef : AccelerationUnit;
	}
	
	attribute def AccelerationUnit;
	
	attribute def ImpactMagnitude {
		attribute num : Real;
		attribute mRef : AccelerationUnit;
	}
	
	attribute def ImpactThreshold {
		attribute num : Real;
		attribute mRef : AccelerationUnit;
	}
	
	attribute def TimeValue {
		attribute num : Real;
		attribute mRef : TimeUnit;
	}
	
	attribute def TimeUnit;
	
	attribute def VoltageValue {
		attribute num : Real;
		attribute mRef : VoltageUnit;
	}
	
	attribute def VoltageUnit;
	
	attribute def FrequencyValue {
		attribute num : Real;
		attribute mRef : FrequencyUnit;
	}
	
	attribute def FrequencyUnit;
	
	item def ImpactEvent {
		attribute magnitude : ImpactMagnitude;
		attribute direction : AccelerationValue;
		attribute timestamp : TimeValue;
		attribute eventId : String;
	}
	
	item def CalibrationData {
		attribute offsetX : Real;
		attribute offsetY : Real;
		attribute offsetZ : Real;
		attribute scaleFactor : Real;
	}
	
	item def SensorStatus {
		attribute isCalibrated : Boolean;
		attribute isOperational : Boolean;
		attribute lastReadingTime : TimeValue;
		attribute errorCode : Integer;
	}
	
	port def AccelerometerPort {
		out attribute rawAcceleration : AccelerationValue;
		in item calibration : CalibrationData;
		out attribute status : SensorStatus;
	}
	
	port def ProcessorPort {
		in attribute inputSignal : AccelerationValue;
		out attribute outputSignal : AccelerationValue;
	}
	
	port def DetectorPort {
		in attribute acceleration : AccelerationValue;
		out item impactEvent : ImpactEvent;
	}
	
	port def DataPort {
		out item impactData : ImpactEvent;
		out attribute acceleration : AccelerationValue;
	}
	
	port def PowerPort {
		in attribute voltage : VoltageValue;
		in attribute current : Real;
	}
	
	action def MeasureAcceleration {
		out acceleration : AccelerationValue;
		
		action sampleXAxis {
			out xValue : Real;
		}
		then fork;
		
		action sampleYAxis {
			out yValue : Real;
		}
		then joinNode;
		
		action sampleZAxis {
			out zValue : Real;
		}
		then joinNode;
		
		join joinNode;
		then combineAxes;
		
		action combineAxes {
			in xAccel : Real;
			in yAccel : Real;
			in zAccel : Real;
			out combinedAcceleration : AccelerationValue;
		}
		
		flow from sampleXAxis.xValue to combineAxes.xAccel;
		flow from sampleYAxis.yValue to combineAxes.yAccel;
		flow from sampleZAxis.zValue to combineAxes.zAccel;
		flow from combineAxes.combinedAcceleration to acceleration;
	}
	
	part def Accelerometer {
		attribute measurementRange : Real;
		attribute resolution : Real;
		attribute bias : AccelerationValue;
		
		port accelPort : AccelerometerPort;
		port powerIn : PowerPort;
		
		action measureAcceleration : MeasureAcceleration {
			out acceleration : AccelerationValue;
		}
		
		state def Initializing;
		state def Ready;
		state def Measuring;
		state def Fault;
		
		state machine AccelerometerStateMachine {
			initial state initializing : Initializing;
			
			state ready : Ready;
			state measuring : Measuring;
			state fault : Fault;
			
			transition init
				first initializing
				then ready;
			
			transition startMeasure
				first ready
				then measuring;
			
			transition completeMeasure
				first measuring
				then ready;
			
			transition errorOccurred
				first ready
				then fault;
			
			transition recover
				first fault
				then initializing;
		}
	}
	
	action def ProcessSignal {
		in rawAcceleration : AccelerationValue;
		out processedAcceleration : AccelerationValue;
		
		action filterNoise {
			in signal : AccelerationValue;
			out filteredSignal : AccelerationValue;
		}
		then amplify;
		
		action amplify {
			in signal : AccelerationValue;
			out amplifiedSignal : AccelerationValue;
		}
		then calibrate;
		
		action calibrate {
			in signal : AccelerationValue;
			out calibratedSignal : AccelerationValue;
		}
		
		flow from rawAcceleration to filterNoise.signal;
		flow from filterNoise.filteredSignal to amplify.signal;
		flow from amplify.amplifiedSignal to calibrate.signal;
		flow from calibrate.calibratedSignal to processedAcceleration;
	}
	
	part def SignalProcessor {
		attribute filterCutoffFrequency : FrequencyValue;
		attribute gain : Real;
		
		port inputPort : ProcessorPort;
		port outputPort : ProcessorPort;
		port powerIn : PowerPort;
		
		action processSignal : ProcessSignal {
			in rawAcceleration : AccelerationValue;
			out processedAcceleration : AccelerationValue;
		}
	}
	
	action def DetectImpact {
		in acceleration : AccelerationValue;
		in threshold : ImpactThreshold;
		out impactEvent : ImpactEvent;
		
		action calculateMagnitude {
			in accel : AccelerationValue;
			out magnitude : ImpactMagnitude;
		}
		then evaluateThreshold;
		
		action evaluateThreshold {
			in mag : ImpactMagnitude;
			in thresh : ImpactThreshold;
			out exceedsThreshold : Boolean;
		}
		then decide decisionNode;
		
		decide decisionNode;
		if evaluateThreshold.exceedsThreshold then generateEvent;
		
		action generateEvent {
			in accel : AccelerationValue;
			in mag : ImpactMagnitude;
			out eventData : ImpactEvent;
		}
		
		flow from acceleration to calculateMagnitude.accel;
		flow from calculateMagnitude.magnitude to evaluateThreshold.mag;
		flow from threshold to evaluateThreshold.thresh;
		flow from acceleration to generateEvent.accel;
		flow from calculateMagnitude.magnitude to generateEvent.mag;
		flow from generateEvent.eventData to impactEvent;
	}
	
	part def ImpactDetector {
		attribute detectionThreshold : ImpactThreshold;
		attribute impactCount : Integer;
		
		port detectorPort : DetectorPort;
		port powerIn : PowerPort;
		
		action detectImpact : DetectImpact {
			in acceleration : AccelerationValue;
			in threshold : ImpactThreshold;
			out impactEvent : ImpactEvent;
		}
		
		state def Monitoring;
		state def ImpactDetected;
		state def Processing;
		
		state machine DetectorStateMachine {
			initial state monitoring : Monitoring;
			
			state impactDetected : ImpactDetected;
			state processing : Processing;
			
			transition detect
				first monitoring
				then impactDetected;
			
			transition process
				first impactDetected
				then processing;
			
			transition complete
				first processing
				then monitoring;
		}
	}
	
	action def SenseImpact {
		out impactEventData : ImpactEvent;
		out accel : AccelerationValue;
		
		action measure : MeasureAcceleration {
			out acceleration;
		}
		then process;
		
		action process : ProcessSignal {
			in rawAcceleration;
			out processedAcceleration;
		}
		then detect;
		
		action detect : DetectImpact {
			in acceleration;
			in threshold;
			out impactEvent;
		}
		
		flow from measure.acceleration to process.rawAcceleration;
		flow from process.processedAcceleration to detect.acceleration;
		flow from detect.impactEvent to impactEventData;
		flow from process.processedAcceleration to accel;
	}
	
	part def ImpactSensor {
		attribute sensitivity : ImpactThreshold;
		attribute samplingRate : FrequencyValue;
		attribute operatingRange : AccelerationValue;
		
		port sensorDataPort : DataPort;
		port powerIn : PowerPort;
		
		part accelerometer : Accelerometer {
			attribute :>> measurementRange = 200.0;
			attribute :>> resolution = 0.01;
		}
		
		part signalProcessor : SignalProcessor {
			attribute :>> gain = 2.0;
		}
		
		part impactDetector : ImpactDetector {
			attribute :>> impactCount = 0;
		}
		
		connect accelerometer.accelPort to signalProcessor.inputPort;
		connect signalProcessor.outputPort to impactDetector.detectorPort;
		connect accelerometer.powerIn to powerIn;
		connect signalProcessor.powerIn to powerIn;
		connect impactDetector.powerIn to powerIn;
		
		action senseImpact : SenseImpact {
			out impactEventData : ImpactEvent;
			out accel : AccelerationValue;
		}
	}
	
	part def PowerSupply {
		attribute outputVoltage : VoltageValue;
		attribute currentCapacity : Real;
		attribute efficiency : Real;
		
		port powerOut : PowerPort;
	}
	
	action def LogData {
		in impactEvent : ImpactEvent;
		
		action timestampEvent {
			in eventInput : ImpactEvent;
			out timestampedEvent : ImpactEvent;
		}
		then storeEvent;
		
		action storeEvent {
			in eventInput : ImpactEvent;
		}
		then transmitEvent;
		
		action transmitEvent {
			in eventInput : ImpactEvent;
			out transmittedEvent : ImpactEvent;
		}
		
		flow from impactEvent to timestampEvent.eventInput;
		flow from timestampEvent.timestampedEvent to storeEvent.eventInput;
		flow from storeEvent.eventInput to transmitEvent.eventInput;
	}
	
	part def DataLogger {
		attribute storageCapacity : Integer;
		attribute recordingRate : FrequencyValue;
		attribute dataBuffer : ImpactEvent[*];
		
		port dataIn : DataPort;
		
		action logData : LogData {
			in impactEvent : ImpactEvent;
		}
	}
	
	action def OperateSensingUnit {
		out impactEventData : ImpactEvent;
		
		action sense : SenseImpact {
			out impactEventData;
			out accel;
		}
		then log;
		
		action log : LogData {
			in impactEvent;
		}
		
		flow from sense.impactEventData to log.impactEvent;
		flow from sense.impactEventData to impactEventData;
	}
	
	part def SensingUnit {
		attribute unitId : String;
		attribute operatingVoltage : VoltageValue;
		attribute powerConsumption : Real;
		
		port dataOutput : DataPort;
		
		part sensor : ImpactSensor {
			attribute :>> samplingRate {
				attribute :>> num = 1000.0;
			}
		}
		
		part powerSupply : PowerSupply {
			attribute :>> outputVoltage {
				attribute :>> num = 5.0;
			}
			attribute :>> currentCapacity = 1.0;
			attribute :>> efficiency = 0.85;
		}
		
		part dataLogger : DataLogger {
			attribute :>> storageCapacity = 10000;
			attribute :>> recordingRate {
				attribute :>> num = 100.0;
			}
		}
		
		connect powerSupply.powerOut to sensor.powerIn;
		connect sensor.sensorDataPort to dataLogger.dataIn;
		connect sensor.sensorDataPort to dataOutput;
		
		action operateSensingUnit : OperateSensingUnit {
			out impactEventData : ImpactEvent;
		}
	}
	
	requirement def SensingUnitRequirements {
		doc /* The sensing unit shall measure impact events using an impact sensor. */
		
		requirement measurementAccuracy {
			doc /* The sensor shall measure acceleration with accuracy within 5% of actual value. */
			
			subject sensor : ImpactSensor;
			
			require constraint {
				(sensor.accelerometer.resolution / sensor.accelerometer.measurementRange) <= 0.05
			}
		}
		
		requirement detectionThreshold {
			doc /* The sensor shall detect impacts exceeding 50 m/s^2 acceleration. */
			
			subject sensor : ImpactSensor;
			
			require constraint {
				sensor.sensitivity.num >= 50.0
			}
		}
		
		requirement samplingRate {
			doc /* The sensor shall sample at minimum 1000 Hz. */
			
			subject sensor : ImpactSensor;
			
			require constraint {
				sensor.samplingRate.num >= 1000.0
			}
		}
		
		requirement responseTime {
			doc /* The sensor shall detect and report impact within 10 milliseconds. */
		}
	}
	
	part sensingUnitInstance : SensingUnit {
		attribute :>> unitId = "ISU-001";
		attribute :>> operatingVoltage {
			attribute :>> num = 12.0;
		}
		attribute :>> powerConsumption = 2.5;
		
		part :>> sensor {
			attribute :>> sensitivity {
				attribute :>> num = 50.0;
			}
			attribute :>> samplingRate {
				attribute :>> num = 1000.0;
			}
			
			part :>> accelerometer {
				attribute :>> measurementRange = 200.0;
				attribute :>> resolution = 0.01;
			}
			
			part :>> signalProcessor {
				attribute :>> filterCutoffFrequency {
					attribute :>> num = 100.0;
				}
				attribute :>> gain = 2.0;
			}
			
			part :>> impactDetector {
				attribute :>> detectionThreshold {
					attribute :>> num = 50.0;
				}
				attribute :>> impactCount = 0;
			}
		}
		
		part :>> powerSupply {
			attribute :>> outputVoltage {
				attribute :>> num = 5.0;
			}
			attribute :>> currentCapacity = 1.0;
			attribute :>> efficiency = 0.85;
		}
		
		part :>> dataLogger {
			attribute :>> storageCapacity = 10000;
			attribute :>> recordingRate {
				attribute :>> num = 100.0;
			}
		}
		
		satisfy requirements : SensingUnitRequirements {
			subject sensor :> sensingUnitInstance.sensor;
		}
		
		perform operation : OperateSensingUnit {
			out impactEventData;
		}
	}
}
