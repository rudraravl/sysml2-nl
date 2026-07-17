package 'TouchSensingUnit' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	enum def TouchState {
		noContact;
		lightTouch;
		firmTouch;
		heavyTouch;
	}
	
	item def TouchMeasurement {
		attribute contactForce :> ISQ::force;
		attribute capacitance : Real;
		attribute touchState : TouchState;
		attribute timestamp : Real;
	}
	
	port def SensorOutputPort {
		out item measurement : TouchMeasurement;
	}
	
	port def ProcessedDataPort {
		in item rawData : TouchMeasurement;
		out item calibratedData : TouchMeasurement;
	}
	
	part def CapacitiveTouchElement {
		attribute elementId : String;
		attribute baselineCapacitance : Real;
		attribute currentCapacitance : Real;
		
		action senseCapacitance {
			out capacitanceReading : Real;
		}
	}
	
	part def ForceTransducer {
		attribute transducerId : String;
		attribute sensitivity : Real;
		attribute maxForce :> ISQ::force;
		
		action convertForceToVoltage {
			in appliedForce :> ISQ::force;
			out outputVoltage : Real;
		}
	}
	
	part def TouchSensor {
		attribute sensorId : String;
		attribute calibrationFactor : Real;
		attribute forceThresholdLight :> ISQ::force;
		attribute forceThresholdFirm :> ISQ::force;
		attribute forceThresholdHeavy :> ISQ::force;
		
		port sensorOutput : SensorOutputPort;
		
		part capacitiveElement : CapacitiveTouchElement;
		part forceTransducer : ForceTransducer;
		
		action measureTouch {
			out touchData : TouchMeasurement;
			
			action readCapacitance {
				out capacitance : Real;
			}
			
			then action readForce {
				in voltage : Real;
				out force :> ISQ::force;
			}
			
			then action classifyTouch {
				in measuredForce :> ISQ::force;
				out state : TouchState;
			}
		}
		
		state machine TouchSensorBehavior {
			entry; then idle;
			
			state idle;
			
			transition idleToActive
				first idle
				then active;
			
			state active {
				state measuring;
				
				state processing;
				
				transition measuringToProcessing
					first measuring
					then processing;
				
				transition processingToMeasuring
					first processing
					then measuring;
			}
			
			transition activeToIdle
				first active
				then idle;
		}
	}
	
	part def SignalConditioner {
		attribute conditionerId : String;
		attribute amplificationGain : Real;
		attribute filterFrequency : Real;
		
		port dataPort : ProcessedDataPort;
		
		action filterNoise {
			in noisySignal : TouchMeasurement;
			out cleanSignal : TouchMeasurement;
		}
		
		action amplifySignal {
			in inputSignal : TouchMeasurement;
			out amplifiedSignal : TouchMeasurement;
		}
		
		action calibrateReading {
			in rawReading : TouchMeasurement;
			out calibratedReading : TouchMeasurement;
		}
	}
	
	part def DataAcquisitionUnit {
		attribute acquisitionRate : Real;
		attribute bufferSize : Integer;
		
		action acquireData {
			in sensorData : TouchMeasurement;
			out storedData : TouchMeasurement;
		}
		
		action timestampData {
			in data : TouchMeasurement;
			out timestampedData : TouchMeasurement;
		}
	}
	
	connection def SensorDataConnection {
		end source : SensorOutputPort;
		end target : ProcessedDataPort;
	}
	
	part def SensingUnit {
		part sensor : TouchSensor;
		part conditioner : SignalConditioner;
		part dataAcquisition : DataAcquisitionUnit;
		
		connection sensorToConditioner : SensorDataConnection
			connect sensor.sensorOutput to conditioner.dataPort;
		
		perform action operateSensingUnit {
			action initializeUnit;
			
			then fork;
				then action runSensor {
					perform sensor.measureTouch;
				}
				
				then action conditionSignal {
					perform conditioner.filterNoise;
					then perform conditioner.amplifySignal;
					then perform conditioner.calibrateReading;
				}
				
				then action acquireAndStore {
					perform dataAcquisition.timestampData;
					then perform dataAcquisition.acquireData;
				}
			join operationComplete;
			
			then action finalizeOperation;
		}
	}
	
	part sensingUnitInstance : SensingUnit {
		part :>> sensor {
			attribute :>> sensorId = "TS-TOUCH-001";
			attribute :>> calibrationFactor = 50.0;
			attribute :>> forceThresholdLight = 0.5[N];
			attribute :>> forceThresholdFirm = 2.0[N];
			attribute :>> forceThresholdHeavy = 5.0[N];
			
			part :>> capacitiveElement {
				attribute :>> elementId = "CAP-001";
				attribute :>> baselineCapacitance = 10.0;
			}
			
			part :>> forceTransducer {
				attribute :>> transducerId = "FT-001";
				attribute :>> sensitivity = 0.95;
				attribute :>> maxForce = 10.0[N];
			}
		}
		
		part :>> conditioner {
			attribute :>> conditionerId = "SC-001";
			attribute :>> amplificationGain = 1.5;
			attribute :>> filterFrequency = 50.0;
		}
		
		part :>> dataAcquisition {
			attribute :>> acquisitionRate = 100.0;
			attribute :>> bufferSize = 1024;
		}
	}
	
	requirement def TouchSensingRequirement {
		doc /* The sensing unit shall measure contact force using a touch sensor with specified accuracy and range. */
		
		subject unit : SensingUnit;
		
		require forceRange : ForceRangeRequirement;
		require accuracy : AccuracyRequirement;
		require responseTime : ResponseTimeRequirement;
	}
	
	requirement def ForceRangeRequirement {
		doc /* The sensor shall measure forces from 0.1 N to 10 N. */
		
		subject sensor : TouchSensor;
		
		attribute minForce :> ISQ::force = 0.1[N];
		attribute maxForce :> ISQ::force = 10.0[N];
	}
	
	requirement def AccuracyRequirement {
		doc /* The sensor shall measure force with accuracy of ±2% of reading. */
		
		subject sensor : TouchSensor;
		
		attribute maxError : Real = 0.02;
	}
	
	requirement def ResponseTimeRequirement {
		doc /* The sensing unit shall provide measurements at minimum 50 Hz rate. */
		
		subject unit : SensingUnit;
		
		attribute minRate : Real = 50.0;
	}
	
	requirement touchSensingReq : TouchSensingRequirement {
		subject actualUnit :> sensingUnitInstance;
	}
	
	individual def TestSensingUnit :> SensingUnit;
	
	individual testUnit : TestSensingUnit :> sensingUnitInstance {
		timeslice measurement1 {
			perform action :>> operateSensingUnit;
		}
		
		then timeslice measurement2 {
			perform action :>> operateSensingUnit;
		}
		
		then timeslice measurement3 {
			perform action :>> operateSensingUnit;
		}
	}
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import TouchSensingUnit::*;
    part testSubject : CapacitiveTouchElement;
    // TODO(human): define boundary input values for: contactForce, capacitance, touchState, timestamp, elementId, baselineCapacitance, currentCapacitance, transducerId
}
