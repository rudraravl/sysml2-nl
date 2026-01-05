package 'Sudden Motion Sensing Unit' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def AccelerationMagnitude :> ISQ::AccelerationValue {
		attribute :>> num : Real;
		attribute :>> mRef : ISQ::AccelerationUnit;
	}
	
	item def AccelerationVector {
		attribute xComponent : AccelerationMagnitude;
		attribute yComponent : AccelerationMagnitude;
		attribute zComponent : AccelerationMagnitude;
		attribute magnitude : AccelerationMagnitude;
		attribute timestamp : Real;
	}
	
	item def MotionEvent {
		attribute detectedAcceleration : AccelerationMagnitude;
		attribute eventTime : Real;
		attribute severity : String;
	}
	
	port def AccelerationOutputPort {
		out item accelerationData : AccelerationVector;
	}
	
	port def EventOutputPort {
		out item motionEvent : MotionEvent;
	}
	
	port def PowerInputPort {
		in attribute voltage : ISQ::ElectricPotentialValue;
		in attribute current : ISQ::ElectricCurrentValue;
	}
	
	port def ConfigurationPort {
		in attribute samplingFrequency : Real;
		in attribute detectionThreshold : AccelerationMagnitude;
		out attribute operationalStatus : String;
	}
	
	connection def DataConnection {
		end source : AccelerationOutputPort;
		end sink : AccelerationOutputPort;
	}
	
	part def SuddenMotionSensor {
		attribute sensorID : String;
		attribute measurementRange : AccelerationMagnitude;
		attribute resolution : AccelerationMagnitude;
		
		port dataOutput : AccelerationOutputPort;
		port eventOutput : EventOutputPort;
		port powerInput : PowerInputPort;
		port configuration : ConfigurationPort;
		
		part mems : MEMSAccelerometer[1];
		part signalConditioner : SignalConditioner[1];
		part digitalConverter : ADConverter[1];
		
		connect mems.analogOutput to signalConditioner.analogInput;
		connect signalConditioner.conditionedOutput to digitalConverter.analogInput;
		connect digitalConverter.digitalOutput to dataOutput;
	}
	
	part def MEMSAccelerometer {
		attribute xSensitivity : Real;
		attribute ySensitivity : Real;
		attribute zSensitivity : Real;
		attribute noiseFloor : AccelerationMagnitude;
		
		port analogOutput : AccelerationOutputPort;
	}
	
	part def SignalConditioner {
		attribute amplificationGain : Real;
		attribute filterFrequency : Real;
		
		port analogInput : AccelerationOutputPort;
		port conditionedOutput : AccelerationOutputPort;
	}
	
	part def ADConverter {
		attribute bitResolution : Integer;
		attribute conversionRate : Real;
		
		port analogInput : AccelerationOutputPort;
		port digitalOutput : AccelerationOutputPort;
	}
	
	part def SensingUnit {
		attribute unitID : String;
		attribute calibrationDate : String;
		
		port accelerationOutput : AccelerationOutputPort;
		port eventNotification : EventOutputPort;
		port power : PowerInputPort;
		port control : ConfigurationPort;
		
		part sensor : SuddenMotionSensor[1];
		part processor : DataProcessor[1];
		part eventAnalyzer : EventAnalyzer[1];
		
		connection sensorToProcessor : DataConnection
			connect source references sensor.dataOutput
			to sink references processor.dataInput;
		
		connect processor.processedOutput to eventAnalyzer.dataInput;
		connect eventAnalyzer.analysisOutput to accelerationOutput;
		connect eventAnalyzer.eventOutput to eventNotification;
		connect power to sensor.powerInput;
		connect control to sensor.configuration;
	}
	
	part def DataProcessor {
		attribute calibrationOffsetX : AccelerationMagnitude;
		attribute calibrationOffsetY : AccelerationMagnitude;
		attribute calibrationOffsetZ : AccelerationMagnitude;
		
		port dataInput : AccelerationOutputPort;
		port processedOutput : AccelerationOutputPort;
	}
	
	part def EventAnalyzer {
		attribute thresholdLevel : AccelerationMagnitude;
		attribute analysisWindow : Real;
		
		port dataInput : AccelerationOutputPort;
		port analysisOutput : AccelerationOutputPort;
		port eventOutput : EventOutputPort;
	}
	
	action def SenseAcceleration {
		in attribute axis : String;
		in attribute samplingPeriod : Real;
		out item measurement : AccelerationVector;
	}
	
	action def ConditionSignal {
		in item rawSignal : AccelerationVector;
		in attribute gain : Real;
		out item conditionedSignal : AccelerationVector;
	}
	
	action def ConvertToDigital {
		in item analogSignal : AccelerationVector;
		in attribute resolution : Integer;
		out item digitalSignal : AccelerationVector;
	}
	
	action def CalibrateData {
		in item rawData : AccelerationVector;
		in attribute offsetX : AccelerationMagnitude;
		in attribute offsetY : AccelerationMagnitude;
		in attribute offsetZ : AccelerationMagnitude;
		out item calibratedData : AccelerationVector;
	}
	
	action def AnalyzeMotion {
		in item accelerationData : AccelerationVector;
		in attribute threshold : AccelerationMagnitude;
		out item event : MotionEvent;
		out attribute eventDetected : Boolean;
	}
	
	action def ContinuousSensing {
		action initializeSensor {
			out attribute ready : Boolean;
		}
		then fork;
			then senseX;
			then senseY;
			then senseZ;
		
		action senseX : SenseAcceleration {
			in axis = "X";
			in samplingPeriod;
			out xMeasurement : AccelerationVector;
		}
		then joinNode;
		
		action senseY : SenseAcceleration {
			in axis = "Y";
			in samplingPeriod;
			out yMeasurement : AccelerationVector;
		}
		then joinNode;
		
		action senseZ : SenseAcceleration {
			in axis = "Z";
			in samplingPeriod;
			out zMeasurement : AccelerationVector;
		}
		then joinNode;
		
		join joinNode;
		then aggregateData;
		
		action aggregateData {
			in item xData : AccelerationVector;
			in item yData : AccelerationVector;
			in item zData : AccelerationVector;
			out item combinedData : AccelerationVector;
		}
		
		flow from senseX.xMeasurement to aggregateData.xData;
		flow from senseY.yMeasurement to aggregateData.yData;
		flow from senseZ.zMeasurement to aggregateData.zData;
		
		then loop;
	}
	
	action def DataProcessing {
		in item inputData : AccelerationVector;
		out item outputData : AccelerationVector;
		
		action applyCalibration : CalibrateData {
			in rawData;
			in offsetX;
			in offsetY;
			in offsetZ;
			out calibratedData;
		}
		then filterNoise;
		
		flow from inputData to applyCalibration.rawData;
		
		action filterNoise {
			in item noisyData : AccelerationVector;
			out item filteredData : AccelerationVector;
		}
		then computeMagnitude;
		
		flow from applyCalibration.calibratedData to filterNoise.noisyData;
		
		action computeMagnitude {
			in item vectorData : AccelerationVector;
			out item magnitudeData : AccelerationVector;
		}
		
		flow from filterNoise.filteredData to computeMagnitude.vectorData;
		flow from computeMagnitude.magnitudeData to outputData;
	}
	
	action def EventAnalysis {
		in item currentAcceleration : AccelerationVector;
		in attribute detectionThreshold : AccelerationMagnitude;
		out item detectedEvent : MotionEvent;
		out attribute isEventDetected : Boolean;
		
		action evaluateThreshold {
			in item data : AccelerationVector;
			in threshold : AccelerationMagnitude;
			out attribute exceedsThreshold : Boolean;
		}
		then decideNode;
		
		flow from currentAcceleration to evaluateThreshold.data;
		flow from detectionThreshold to evaluateThreshold.threshold;
		
		decide decideNode;
			if evaluateThreshold.exceedsThreshold
				then generateEvent;
			else
				then noEventDetected;
		
		action generateEvent : AnalyzeMotion {
			in accelerationData;
			in threshold;
			out event;
			out eventDetected;
		}
		then mergeNode;
		
		flow from currentAcceleration to generateEvent.accelerationData;
		flow from detectionThreshold to generateEvent.threshold;
		
		action noEventDetected {
			out attribute noEvent : Boolean = false;
		}
		then mergeNode;
		
		merge mergeNode;
		then done;
		
		flow from generateEvent.event to detectedEvent;
		flow from generateEvent.eventDetected to isEventDetected;
	}
	
	state def SensorOperationalStates {
		entry; then powerOff;
		
		state powerOff {
			entry assign status = "off";
		}
		transition powerOff_to_initialization
			first powerOff
			accept PowerOnCommand
			then initialization;
		
		state initialization {
			entry assign status = "initializing";
			do action selfTest;
		}
		transition initialization_to_standby
			first initialization
			accept InitializationComplete
			then standby;
		
		state standby {
			entry assign status = "standby";
		}
		transition standby_to_active
			first standby
			accept StartMeasurementCommand
			then active;
		
		state active {
			entry assign status = "active";
			
			state measuring {
				do action continuousSensing : ContinuousSensing;
			}
			transition measuring_to_processing
				first measuring
				accept DataAcquired
				then processing;
			
			state processing {
				do action dataProcessing : DataProcessing;
			}
			transition processing_to_analyzing
				first processing
				accept ProcessingComplete
				then analyzing;
			
			state analyzing {
				do action eventAnalysis : EventAnalysis;
			}
			transition analyzing_to_measuring
				first analyzing
				accept AnalysisComplete
				then measuring;
		}
		
		transition active_to_alert
			first active
			accept SuddenMotionDetected
			then alert;
		
		state alert {
			entry assign status = "alert";
			do action notifyEvent;
		}
		transition alert_to_active
			first alert
			accept AlertAcknowledged
			then active;
		
		transition active_to_standby
			first active
			accept StopMeasurementCommand
			then standby;
		
		transition standby_to_powerOff
			first standby
			accept PowerOffCommand
			then powerOff;
		
		transition any_to_error
			accept ErrorDetected
			then error;
		
		state error {
			entry assign status = "error";
		}
		transition error_to_initialization
			first error
			accept ResetCommand
			then initialization;
	}
	
	requirement def MeasurementAccuracyRequirement {
		doc /* The sensing unit shall measure acceleration with accuracy within ±3% of the actual value across the full measurement range. */
		
		subject unit : SensingUnit;
		
		attribute maxError : Real = 0.03;
		
		require constraint {
			unit.sensor.mems.xSensitivity >= (1.0 - maxError) and
			unit.sensor.mems.xSensitivity <= (1.0 + maxError) and
			unit.sensor.mems.ySensitivity >= (1.0 - maxError) and
			unit.sensor.mems.ySensitivity <= (1.0 + maxError) and
			unit.sensor.mems.zSensitivity >= (1.0 - maxError) and
			unit.sensor.mems.zSensitivity <= (1.0 + maxError)
		}
	}
	
	requirement def MeasurementRangeRequirement {
		doc /* The sensing unit shall measure accelerations from -16g to +16g on all three axes. */
		
		subject sensor : SuddenMotionSensor;
		
		attribute minRange : Real = -16.0;
		attribute maxRange : Real = 16.0;
		
		require constraint {
			sensor.measurementRange.num >= maxRange
		}
	}
	
	requirement def ResponseTimeRequirement {
		doc /* The sensing unit shall detect and report sudden motion events within 5 milliseconds of occurrence. */
		
		subject analyzer : EventAnalyzer;
		
		attribute maxResponseTime : Real = 0.005;
		
		require constraint {
			analyzer.analysisWindow <= maxResponseTime
		}
	}
	
	requirement def PowerConsumptionRequirement {
		doc /* The sensing unit shall operate with power consumption not exceeding 100 milliwatts during active measurement. */
		
		subject unit : SensingUnit;
		
		attribute maxPowerConsumption : Real = 0.1;
		
		require constraint {
			unit.power.voltage.num * unit.power.current.num <= maxPowerConsumption
		}
	}
	
	part sensingUnitInstance : SensingUnit {
		attribute :>> unitID = "SMU-2025-001";
		attribute :>> calibrationDate = "2025-01-15";
		
		part :>> sensor {
			attribute :>> sensorID = "SMS-001";
			attribute :>> measurementRange : AccelerationMagnitude {
				attribute :>> num = 16.0;
			}
			attribute :>> resolution : AccelerationMagnitude {
				attribute :>> num = 0.001;
			}
			
			part :>> mems {
				attribute :>> xSensitivity = 0.99;
				attribute :>> ySensitivity = 1.01;
				attribute :>> zSensitivity = 0.98;
				attribute :>> noiseFloor : AccelerationMagnitude {
					attribute :>> num = 0.0005;
				}
			}
			
			part :>> signalConditioner {
				attribute :>> amplificationGain = 10.0;
				attribute :>> filterFrequency = 200.0;
			}
			
			part :>> digitalConverter {
				attribute :>> bitResolution = 16;
				attribute :>> conversionRate = 1000.0;
			}
			
			port :>> powerInput {
				in attribute :>> voltage : ISQ::ElectricPotentialValue {
					attribute :>> num = 3.3;
				}
				in attribute :>> current : ISQ::ElectricCurrentValue {
					attribute :>> num = 0.025;
				}
			}
			
			port :>> configuration {
				in attribute :>> samplingFrequency = 1000.0;
				in attribute :>> detectionThreshold : AccelerationMagnitude {
					attribute :>> num = 2.5;
				}
				out attribute :>> operationalStatus = "ready";
			}
		}
		
		part :>> processor {
			attribute :>> calibrationOffsetX : AccelerationMagnitude {
				attribute :>> num = 0.01;
			}
			attribute :>> calibrationOffsetY : AccelerationMagnitude {
				attribute :>> num = -0.02;
			}
			attribute :>> calibrationOffsetZ : AccelerationMagnitude {
				attribute :>> num = 0.015;
			}
		}
		
		part :>> eventAnalyzer {
			attribute :>> thresholdLevel : AccelerationMagnitude {
				attribute :>> num = 2.5;
			}
			attribute :>> analysisWindow = 0.003;
		}
		
		perform sensorOperation : SensorOperationalStates;
	}
	
	requirement accuracyReq : MeasurementAccuracyRequirement {
		subject testUnit :>> unit = sensingUnitInstance;
	}
	
	requirement rangeReq : MeasurementRangeRequirement {
		subject testSensor :>> sensor = sensingUnitInstance.sensor;
	}
	
	requirement responseReq : ResponseTimeRequirement {
		subject testAnalyzer :>> analyzer = sensingUnitInstance.eventAnalyzer;
	}
	
	requirement powerReq : PowerConsumptionRequirement {
		subject testUnit :>> unit = sensingUnitInstance;
	}
}
