package 'Heartbeat Sensing Unit' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import UnitsAndScales::*;
	private import Quantities::*;
	
	attribute def BeatsPerMinuteUnit :> MeasurementUnit {
		attribute :>> unitPowerFactor : UnitPowerFactor[2] ordered;
	}
	
	attribute def HeartRateValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : BeatsPerMinuteUnit;
	}
	
	attribute def SignalStrengthValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : MeasurementUnit;
	}
	
	item def PulseSignal {
		attribute timestamp : TimeValue;
		attribute amplitude : Real;
		attribute frequency : FrequencyValue;
	}
	
	item def HeartRateMeasurement {
		attribute rate : HeartRateValue;
		attribute signalQuality : SignalStrengthValue;
		attribute measurementTime : TimeValue;
		attribute isValid : Boolean;
	}
	
	port def SensorOutputPort {
		out item pulseData : PulseSignal;
	}
	
	port def MeasurementOutputPort {
		out item heartRateData : HeartRateMeasurement;
	}
	
	port def PowerSupplyPort {
		in attribute voltage : ISQ::ElectricPotentialValue;
		in attribute current : ISQ::ElectricCurrentValue;
	}
	
	connection def DataConnection {
		end source : SensorOutputPort[1];
		end sink : ~SensorOutputPort[1];
	}
	
	requirement def MeasurementAccuracyRequirement {
		doc /* The sensing unit shall measure heart rate with accuracy within ±2 BPM for rates between 40 and 200 BPM. */
		
		subject unit : HeartbeatSensingUnit;
		
		attribute maxError : Real = 2.0;
	}
	
	requirement def ResponseTimeRequirement {
		doc /* The sensing unit shall provide updated heart rate measurements within 2 seconds. */
		
		subject unit : HeartbeatSensingUnit;
		
		attribute maxInterval : Real = 2.0;
	}
	
	requirement def OperatingRangeRequirement {
		doc /* The sensing unit shall operate correctly for heart rates between 40 and 200 BPM. */
		
		subject unit : HeartbeatSensingUnit;
		
		attribute minRate : Real = 40.0;
		attribute maxRate : Real = 200.0;
	}
	
	action def DetectPulse {
		in item rawSignal : PulseSignal;
		out item detectedPulse : PulseSignal;
		out beatDetected : Boolean;
	}
	
	action def CalculateHeartRate {
		in item pulseSequence : PulseSignal[*];
		out item measurement : HeartRateMeasurement;
	}
	
	action def FilterNoise {
		in item noisySignal : PulseSignal;
		out item filteredSignal : PulseSignal;
	}
	
	action def ValidateQuality {
		in item rawMeasurement : HeartRateMeasurement;
		out item validatedMeasurement : HeartRateMeasurement;
	}
	
	action def MeasurementProcess {
		in item inputPulse : PulseSignal;
		out item outputMeasurement : HeartRateMeasurement;
		
		action filter : FilterNoise {
			in item noisySignal;
			out item filteredSignal;
		}
		
		bind filter.noisySignal = inputPulse;
		
		then action detect : DetectPulse {
			in item rawSignal;
			out item detectedPulse;
			out beatDetected;
		}
		
		flow from filter.filteredSignal to detect.rawSignal;
		
		then action calculate : CalculateHeartRate {
			in item pulseSequence[*];
			out item measurement;
		}
		
		flow from detect.detectedPulse to calculate.pulseSequence;
		
		then action validate : ValidateQuality {
			in item rawMeasurement;
			out item validatedMeasurement;
		}
		
		flow from calculate.measurement to validate.rawMeasurement;
		
		bind validate.validatedMeasurement = outputMeasurement;
	}
	
	state def SensorOperationStates {
		entry; then off;
		
		state off {
			entry assign powerLevel = 0.0;
		}
		
		transition powerUp
			first off
			accept PowerOnEvent
			then initializing;
		
		state initializing {
			entry assign powerLevel = 0.5;
		}
		
		transition initComplete
			first initializing
			if testPassed
			then ready;
		
		transition initFailed
			first initializing
			if not testPassed
			then fault;
		
		state ready {
			entry assign powerLevel = 0.3;
		}
		
		transition startMeasuring
			first ready
			accept StartMeasurementEvent
			then measuring;
		
		state measuring {
			entry assign powerLevel = 1.0;
		}
		
		transition measurementComplete
			first measuring
			if dataValid
			then transmitting;
		
		transition signalLost
			first measuring
			if not signalPresent
			then ready;
		
		state transmitting {
			entry assign powerLevel = 0.8;
		}
		
		transition transmitDone
			first transmitting
			then ready;
		
		state fault {
			entry assign powerLevel = 0.1;
		}
		
		transition recover
			first fault
			accept ResetEvent
			then initializing;
		
		attribute powerLevel : Real;
		attribute testPassed : Boolean;
		attribute dataValid : Boolean;
		attribute signalPresent : Boolean;
	}
	
	part def HeartbeatSensor {
		attribute sensorType : String default "Optical PPG";
		attribute wavelength : LengthValue;
		attribute sensitivity : Real;
		attribute noiseLevel : Real;
		
		port sensorOut : SensorOutputPort;
		port power : PowerSupplyPort;
		
		perform action acquireSignal : DetectPulse;
	}
	
	part def SignalProcessor {
		attribute samplingRate : FrequencyValue;
		attribute filterBandwidth : FrequencyValue;
		attribute accuracyTolerance : Real default 2.0;
		attribute measurementInterval : Real default 1.5;
		
		port signalIn : ~SensorOutputPort;
		port dataOut : MeasurementOutputPort;
		
		perform action processSignal : MeasurementProcess;
	}
	
	part def DataBuffer {
		attribute bufferSize : Integer default 100;
		attribute currentSamples : Integer default 0;
		
		port dataIn : ~MeasurementOutputPort;
	}
	
	part def HeartbeatSensingUnit {
		attribute minHeartRate : Real default 40.0;
		attribute maxHeartRate : Real default 200.0;
		attribute operatingVoltage : ISQ::ElectricPotentialValue;
		attribute totalPowerConsumption : ISQ::PowerValue;
		
		part sensor : HeartbeatSensor {
			attribute :>> wavelength = 525.0[nm];
			attribute :>> sensitivity = 0.95;
			attribute :>> noiseLevel = 0.05;
		}
		
		part processor : SignalProcessor {
			attribute :>> samplingRate = 100.0[Hz];
			attribute :>> filterBandwidth = 5.0[Hz];
			attribute :>> accuracyTolerance = 1.8;
			attribute :>> measurementInterval = 1.5;
		}
		
		part buffer : DataBuffer {
			attribute :>> bufferSize = 200;
		}
		
		port measurementOut : MeasurementOutputPort;
		port powerIn : PowerSupplyPort;
		
		connection sensorToProcessor : DataConnection 
			connect sensor.sensorOut to processor.signalIn;
		
		connection processorToBuffer : DataConnection 
			connect processor.dataOut to buffer.dataIn;
		
		connect processor.dataOut to measurementOut;
		
		exhibit state operationState : SensorOperationStates;
		
		perform action measureHeartRate : MeasurementProcess;
	}
	
	part heartbeatSensingSystem : HeartbeatSensingUnit {
		attribute :>> operatingVoltage = 3.3[V];
		attribute :>> minHeartRate = 40.0;
		attribute :>> maxHeartRate = 200.0;
		
		satisfy accuracyReq : MeasurementAccuracyRequirement {
			subject unit = heartbeatSensingSystem;
		}
		
		satisfy responseReq : ResponseTimeRequirement {
			subject unit = heartbeatSensingSystem;
		}
		
		satisfy rangeReq : OperatingRangeRequirement {
			subject unit = heartbeatSensingSystem;
		}
		
		part :>> sensor {
			attribute :>> wavelength = 525.0[nm];
			attribute :>> sensitivity = 0.98;
			attribute :>> noiseLevel = 0.03;
		}
		
		part :>> processor {
			attribute :>> samplingRate = 125.0[Hz];
			attribute :>> filterBandwidth = 8.0[Hz];
			attribute :>> accuracyTolerance = 1.5;
			attribute :>> measurementInterval = 1.2;
		}
		
		part :>> buffer {
			attribute :>> bufferSize = 300;
		}
	}
	
	individual def TestScenario :> HeartbeatSensingUnit;
	
	individual testSystem : TestScenario :> heartbeatSensingSystem {
		timeslice startup {
			snapshot :>> operationState.off;
			snapshot part :>> sensor {
				:>> sensitivity = 0.0;
			}
		}
		
		then timeslice initialization {
			snapshot :>> operationState.initializing;
			snapshot part :>> sensor {
				:>> sensitivity = 0.98;
			}
		}
		
		then timeslice activeMeasurement {
			snapshot :>> operationState.measuring;
			
			perform action :>> measureHeartRate {
				in item :>> inputPulse : PulseSignal {
					:>> timestamp = 0.0[s];
					:>> amplitude = 0.85;
					:>> frequency = 1.2[Hz];
				}
				out item :>> outputMeasurement : HeartRateMeasurement {
					:>> isValid = true;
				}
			}
			
			snapshot part :>> buffer {
				:>> currentSamples = 50;
			}
		}
		
		then timeslice dataTransmission {
			snapshot :>> operationState.transmitting;
			snapshot part :>> buffer {
				:>> currentSamples = 75;
			}
		}
	}
}
