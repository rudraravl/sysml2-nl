package 'Proximity Sensing Unit' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import UnitsAndScales::*;
	
	comment about ProximitySensingUnit
	/* This model describes a proximity sensing unit that measures distance to nearby objects
	 * using ultrasonic sensing technology. The system emits ultrasonic pulses and measures
	 * the time-of-flight of reflected echoes to calculate object distance. The unit includes
	 * signal generation, echo detection, signal processing, and power management subsystems. */
	
	attribute def DistanceValue :> ISQ::LengthValue;
	
	attribute def TimeValue :> ISQ::TimeValue;
	
	attribute def VoltageValue :> ISQ::VoltageValue;
	
	attribute def FrequencyValue :> ISQ::FrequencyValue;
	
	item def UltrasonicPulse {
		attribute frequency : FrequencyValue;
		attribute duration : TimeValue;
		attribute amplitude : VoltageValue;
	}
	
	item def EchoSignal {
		attribute timeOfFlight : TimeValue;
		attribute signalStrength : VoltageValue;
		attribute isValid : Boolean;
	}
	
	item def ProximityMeasurement {
		attribute distance : DistanceValue;
		attribute timestamp : TimeValue;
		attribute confidence : Real;
	}
	
	port def SensorTransmitPort {
		out item pulse : UltrasonicPulse;
	}
	
	port def SensorReceivePort {
		in item echo : EchoSignal;
	}
	
	port def PowerPort {
		in attribute voltage : VoltageValue;
		in attribute current : Real;
	}
	
	port def DataOutputPort {
		out item measurement : ProximityMeasurement;
	}
	
	port def ControlPort {
		in attribute triggerMeasurement : Boolean;
		out attribute ready : Boolean;
	}
	
	connection def PowerConnection {
		end sourcePort : PowerPort;
		end sinkPort : PowerPort;
	}
	
	connection def SignalConnection {
		end transmitPort : SensorTransmitPort;
		end receivePort : SensorReceivePort;
	}
	
	action def GeneratePulse {
		in targetFrequency : FrequencyValue;
		out item transmitPulse : UltrasonicPulse;
	}
	
	action def DetectEcho {
		in item receivedSignal : EchoSignal;
		out validEcho : Boolean;
		out item processedEcho : EchoSignal;
	}
	
	action def CalculateDistance {
		in item echoData : EchoSignal;
		in speedOfSound : Real;
		out item distanceMeasurement : ProximityMeasurement;
	}
	
	action def MeasureProximity {
		in operatingFrequency : FrequencyValue;
		out item proximityResult : ProximityMeasurement;
		
		action generatePulse : GeneratePulse {
			in targetFrequency = operatingFrequency;
			out transmitPulse;
		}
		
		then waitForEcho;
		
		action waitForEcho {
			out item receivedEcho : EchoSignal;
		}
		
		then detectEcho;
		
		action detectEcho : DetectEcho {
			in receivedSignal;
			out validEcho;
			out processedEcho;
		}
		
		then calculateDistance;
		
		action calculateDistance : CalculateDistance {
			in echoData;
			in speedOfSound = 343.0;
			out distanceMeasurement;
		}
		
		flow from waitForEcho.receivedEcho to detectEcho.receivedSignal;
		flow from detectEcho.processedEcho to calculateDistance.echoData;
		flow from calculateDistance.distanceMeasurement to proximityResult;
	}
	
	state def ProximitySensorStates {
		entry; then powerOff;
		
		state powerOff;
		
		transition powerOn
			first powerOff
			accept PowerOnCommand
			then idle;
		
		state idle;
		
		transition startMeasurement
			first idle
			accept TriggerCommand
			then measuring;
		
		state measuring {
			entry; then transmitting;
			
			state transmitting;
			
			transition transmitComplete
				first transmitting
				accept PulseEmitted
				then listening;
			
			state listening;
			
			transition echoDetected
				first listening
				accept EchoReceived
				then processing;
			
			transition timeout
				first listening
				accept TimeoutExpired
				then idle;
			
			state processing;
			
			transition processingComplete
				first processing
				accept CalculationDone
				then idle;
		}
		
		state error;
		
		transition errorDetected
			first measuring
			accept ErrorCondition
			then error;
		
		transition errorRecovery
			first error
			accept ResetCommand
			then idle;
		
		transition shutdown
			first idle
			accept PowerOffCommand
			then powerOff;
	}
	
	part def UltrasonicTransducer {
		attribute operatingFrequency : FrequencyValue;
		attribute beamAngle : Real;
		
		port transmitPort : SensorTransmitPort;
		port receivePort : SensorReceivePort;
		port power : PowerPort;
		
		perform action transmit : GeneratePulse;
		perform action receive : DetectEcho;
	}
	
	part def SignalProcessor {
		attribute processingSpeed : Real;
		attribute soundVelocity : Real;
		
		port echoInput : SensorReceivePort;
		port dataOutput : DataOutputPort;
		port power : PowerPort;
		
		perform action process : CalculateDistance;
	}
	
	part def PowerSupply {
		attribute outputVoltage : VoltageValue;
		attribute maxCurrent : Real;
		attribute efficiency : Real;
		
		port powerOut1 : PowerPort;
		port powerOut2 : PowerPort;
	}
	
	part def ControlUnit {
		attribute samplingRate : FrequencyValue;
		
		port controlInterface : ControlPort;
		port power : PowerPort;
		
		exhibit state controlStates : ProximitySensorStates;
	}
	
	part def ProximitySensingUnit {
		attribute systemIdentifier : String;
		attribute measurementRange : DistanceValue;
		attribute resolution : DistanceValue;
		
		part transducer : UltrasonicTransducer {
			attribute :>> operatingFrequency = 40000.0[SI::Hz];
			attribute :>> beamAngle = 15.0;
		}
		
		part processor : SignalProcessor {
			attribute :>> processingSpeed = 1000000.0;
			attribute :>> soundVelocity = 343.0;
		}
		
		part powerSupply : PowerSupply {
			attribute :>> outputVoltage = 5.0[SI::V];
			attribute :>> maxCurrent = 1.0;
			attribute :>> efficiency = 0.85;
		}
		
		part controller : ControlUnit {
			attribute :>> samplingRate = 10.0[SI::Hz];
		}
		
		port systemOutput : DataOutputPort;
		port systemControl : ControlPort;
		
		connection signalPath : SignalConnection
			connect transmitPort => transducer.transmitPort
			to receivePort => transducer.receivePort;
		
		connection echoToProcessor
			connect transducer.receivePort to processor.echoInput;
		
		connection processorToOutput
			connect processor.dataOutput to systemOutput;
		
		connection powerToTransducer : PowerConnection
			connect sourcePort => powerSupply.powerOut1
			to sinkPort => transducer.power;
		
		connection powerToProcessor : PowerConnection
			connect sourcePort => powerSupply.powerOut2
			to sinkPort => processor.power;
		
		connection powerToController
			connect powerSupply.powerOut1 to controller.power;
		
		connection controlInterface
			connect controller.controlInterface to systemControl;
		
		perform action measureDistance : MeasureProximity {
			in operatingFrequency = transducer.operatingFrequency;
			out proximityResult;
		}
	}
	
	requirement def MeasurementRangeRequirement {
		doc /* The proximity sensing unit shall measure distances from 2 cm to 400 cm. */
		
		subject sensorRange : ProximitySensingUnit;
		
		require constraint {
			sensorRange.measurementRange.num >= 0.02 and
			sensorRange.measurementRange.num <= 4.0
		}
	}
	
	requirement def AccuracyRequirement {
		doc /* The sensing unit shall provide distance measurements with accuracy of ±1% of reading or ±3mm, whichever is greater. */
		
		subject measurement : ProximityMeasurement;
		attribute maxError : DistanceValue;
		
		require constraint {
			maxError.num <= 0.003 or maxError.num <= measurement.distance.num * 0.01
		}
	}
	
	requirement def ResponseTimeRequirement {
		doc /* The sensing unit shall complete a measurement cycle within 100 milliseconds. */
		
		subject cycleTime : TimeValue;
		
		require constraint {
			cycleTime.num <= 0.1
		}
	}
	
	requirement def OperatingFrequencyRequirement {
		doc /* The ultrasonic transducer shall operate at 40 kHz ± 1 kHz. */
		
		subject transducerFreq : FrequencyValue;
		
		require constraint {
			transducerFreq.num >= 39000.0 and transducerFreq.num <= 41000.0
		}
	}
	
	requirement def PowerConsumptionRequirement {
		doc /* The sensing unit shall operate with power consumption not exceeding 5 watts. */
		
		subject powerUsage : Real;
		
		require constraint {
			powerUsage <= 5.0
		}
	}
	
	requirement systemRequirements {
		doc /* Top-level requirements for the proximity sensing unit system. */
		
		requirement rangeReq : MeasurementRangeRequirement;
		requirement accuracyReq : AccuracyRequirement;
		requirement responseReq : ResponseTimeRequirement;
		requirement frequencyReq : OperatingFrequencyRequirement;
		requirement powerReq : PowerConsumptionRequirement;
	}
	
	part proximitySensingSystem : ProximitySensingUnit {
		attribute :>> systemIdentifier = "PSU-001";
		attribute :>> measurementRange = 4.0[SI::m];
		attribute :>> resolution = 0.003[SI::m];
	}
	
	satisfy systemRequirements by proximitySensingSystem;
	
	dependency from proximitySensingSystem.transducer to systemRequirements.frequencyReq;
	dependency from proximitySensingSystem.processor to systemRequirements.accuracyReq;
	dependency from proximitySensingSystem.controller to systemRequirements.responseReq;
	dependency from proximitySensingSystem.powerSupply to systemRequirements.powerReq;
}
