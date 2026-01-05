package 'Parking Sensor Sensing Unit' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def ObstacleDistance :> LengthValue;
	attribute def UltrasonicFrequency :> FrequencyValue;
	
	attribute def SignalStrengthUnit :> SimpleUnit;
	
	attribute def SignalStrength :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : SignalStrengthUnit;
	}
	
	attribute def DetectionStatus;
	attribute def ObstaclePresent :> DetectionStatus;
	attribute def NoObstacleDetected :> DetectionStatus;
	attribute def SensorFault :> DetectionStatus;
	
	attribute def VoltageUnit :> SimpleUnit;
	
	attribute def VoltageValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : VoltageUnit;
	}
	
	attribute def TimeValue :> DurationValue;
	
	item def UltrasonicPulse {
		attribute frequency : UltrasonicFrequency;
		attribute transmitTime : TimeValue;
	}
	
	item def EchoSignal {
		attribute receiveTime : TimeValue;
		attribute strength : SignalStrength;
	}
	
	item def DistanceMeasurement {
		attribute distance : ObstacleDistance;
		attribute status : DetectionStatus;
		attribute timestamp : TimeValue;
		attribute confidence : Real;
	}
	
	port def SensorDataPort {
		out item distanceData : DistanceMeasurement;
	}
	
	port def PowerPort {
		in attribute voltage : VoltageValue;
		in attribute current : Real;
	}
	
	port def DiagnosticPort {
		out attribute temperature : ThermodynamicTemperatureValue;
		out attribute operationalStatus : DetectionStatus;
		out attribute errorCode : Integer;
	}
	
	action def TransmitUltrasonicPulse {
		in attribute operatingFrequency : UltrasonicFrequency;
		out item pulse : UltrasonicPulse;
	}
	
	action def ReceiveEcho {
		in item transmittedPulse : UltrasonicPulse;
		out item echo : EchoSignal;
	}
	
	action def CalculateDistance {
		in item transmittedPulse : UltrasonicPulse;
		in item receivedEcho : EchoSignal;
		out attribute calculatedDistance : ObstacleDistance;
		attribute speedOfSound : SpeedValue = 343.0[m/s];
	}
	
	action def ValidateMeasurement {
		in attribute distance : ObstacleDistance;
		in attribute echoStrength : SignalStrength;
		out attribute isValid : Boolean;
		out attribute confidence : Real;
	}
	
	action def DetermineMeasurementStatus {
		in attribute distance : ObstacleDistance;
		in attribute isValid : Boolean;
		in attribute maxRange : ObstacleDistance;
		out attribute status : DetectionStatus;
	}
	
	action def PerformSensing {
		in attribute frequency : UltrasonicFrequency;
		in attribute maxDetectionRange : ObstacleDistance;
		out item measurement : DistanceMeasurement;
		
		action transmit : TransmitUltrasonicPulse {
			in attribute :>> operatingFrequency = frequency;
			out item :>> pulse;
		}
		then action receive : ReceiveEcho {
			in item :>> transmittedPulse = transmit.pulse;
			out item :>> echo;
		}
		then action calculate : CalculateDistance {
			in item :>> transmittedPulse = transmit.pulse;
			in item :>> receivedEcho = receive.echo;
			out attribute :>> calculatedDistance;
		}
		then action validate : ValidateMeasurement {
			in attribute :>> distance = calculate.calculatedDistance;
			in attribute :>> echoStrength = receive.echo.strength;
			out attribute :>> isValid;
			out attribute :>> confidence;
		}
		then action determineStatus : DetermineMeasurementStatus {
			in attribute :>> distance = calculate.calculatedDistance;
			in attribute :>> isValid = validate.isValid;
			in attribute :>> maxRange = maxDetectionRange;
			out attribute :>> status;
		}
		
		flow from transmit.pulse to receive.transmittedPulse;
		flow from transmit.pulse to calculate.transmittedPulse;
		flow from receive.echo to calculate.receivedEcho;
		flow from calculate.calculatedDistance to validate.distance;
		flow from receive.echo.strength to validate.echoStrength;
		flow from calculate.calculatedDistance to determineStatus.distance;
		flow from validate.isValid to determineStatus.isValid;
		
		bind measurement.distance = calculate.calculatedDistance;
		bind measurement.status = determineStatus.status;
		bind measurement.confidence = validate.confidence;
	}
	
	state def SensorOperationalStates {
		entry action initialize;
		
		state idle {
			entry action enterIdle;
		}
		
		transition first idle
			accept at SensorFault
			then active;
		
		state active {
			entry action startSensing;
			do action continuousSensing : PerformSensing;
		}
		
		transition first active
			accept EchoSignal
			then processing;
		
		state processing {
			do action processData;
		}
		
		transition first processing
			then idle;
		
		transition first active
			accept SensorFault
			then fault;
		
		state fault {
			entry action reportFault;
			do action attemptRecovery;
		}
		
		transition first fault
			then idle;
	}
	
	part def UltrasonicTransducer {
		attribute operatingFrequency : UltrasonicFrequency;
		attribute beamAngle : Real;
		
		perform action transmitPulse : TransmitUltrasonicPulse;
		perform action receiveEcho : ReceiveEcho;
	}
	
	part def SignalProcessor {
		attribute processingSpeed : Real;
		attribute filterCutoffFrequency : UltrasonicFrequency;
		
		perform action calculateDistance : CalculateDistance;
		perform action validateMeasurement : ValidateMeasurement;
	}
	
	part def ControlUnit {
		attribute firmwareVersion : String;
		attribute calibrationData : Real[*];
		
		perform action determineMeasurementStatus : DetermineMeasurementStatus;
		exhibit state operationalStates : SensorOperationalStates;
	}
	
	part def TemperatureSensor {
		attribute measurementRange : ThermodynamicTemperatureValue[2];
		perform action measureTemperature {
			out temp : ThermodynamicTemperatureValue;
		}
	}
	
	part def ParkingSensorUnit {
		attribute sensorId : String;
		attribute maxDetectionRange : ObstacleDistance;
		attribute minDetectionRange : ObstacleDistance;
		attribute nominalOperatingFrequency : UltrasonicFrequency;
		attribute operatingTemperatureRange : ThermodynamicTemperatureValue[2];
		
		part transducer : UltrasonicTransducer[1] {
			attribute :>> operatingFrequency = nominalOperatingFrequency;
			attribute :>> beamAngle = 60.0;
		}
		
		part processor : SignalProcessor[1] {
			attribute :>> processingSpeed = 1000000.0;
			attribute :>> filterCutoffFrequency = nominalOperatingFrequency;
		}
		
		part controller : ControlUnit[1] {
			attribute :>> firmwareVersion = "v2.1.0";
		}
		
		part tempSensor : TemperatureSensor[1] {
			attribute :>> measurementRange = (233.15[K], 358.15[K]);
		}
		
		port dataOutput : SensorDataPort[1];
		port powerInput : PowerPort[1];
		port diagnosticOutput : DiagnosticPort[1];
		
		perform action sensing : PerformSensing {
			in attribute :>> frequency = nominalOperatingFrequency;
			in attribute :>> maxDetectionRange = maxDetectionRange;
			out item :>> measurement;
		}
		
		connect transducer to processor;
		connect processor to controller;
		connect tempSensor to controller;
		
		flow from sensing.measurement to dataOutput.distanceData;
		flow from tempSensor.measureTemperature.temp to diagnosticOutput.temperature;
	}
	
	requirement def SensingAccuracyRequirement {
		doc /* The parking sensor shall measure obstacle distance with accuracy within specified tolerance. */
		
		subject sensor : ParkingSensorUnit;
		
		require constraint accuracyConstraint {
			attribute measuredDistance : ObstacleDistance;
			attribute actualDistance : ObstacleDistance;
			attribute tolerance : ObstacleDistance;
			
			(measuredDistance.num - actualDistance.num) <= tolerance.num and
			(actualDistance.num - measuredDistance.num) <= tolerance.num
		}
	}
	
	requirement def DetectionRangeRequirement {
		doc /* The parking sensor shall detect obstacles within the specified range. */
		
		subject sensor : ParkingSensorUnit;
		
		require constraint rangeConstraint {
			sensor.minDetectionRange.num >= 0.15 and
			sensor.maxDetectionRange.num <= 2.5
		}
	}
	
	requirement def OperatingFrequencyRequirement {
		doc /* The parking sensor shall operate at ultrasonic frequency. */
		
		subject sensor : ParkingSensorUnit;
		
		require constraint frequencyConstraint {
			sensor.nominalOperatingFrequency.num >= 40000.0 and
			sensor.nominalOperatingFrequency.num <= 48000.0
		}
	}
	
	requirement def EnvironmentalRequirement {
		doc /* The parking sensor shall operate within specified temperature range. */
		
		subject sensor : ParkingSensorUnit;
		
		require constraint temperatureConstraint {
			sensor.operatingTemperatureRange[1].num >= 233.15 and
			sensor.operatingTemperatureRange[2].num <= 358.15
		}
	}
	
	part rearParkingSensor : ParkingSensorUnit {
		attribute :>> sensorId = "RPS-001";
		attribute :>> maxDetectionRange = 2.5[m];
		attribute :>> minDetectionRange = 0.15[m];
		attribute :>> nominalOperatingFrequency = 40000.0[Hz];
		attribute :>> operatingTemperatureRange = (233.15[K], 358.15[K]);
		
		satisfy sensingAccuracy : SensingAccuracyRequirement {
			subject sensor = rearParkingSensor;
			
			redefine constraint accuracyConstraint {
				attribute :>> tolerance = 0.03[m];
			}
		}
		
		satisfy detectionRange : DetectionRangeRequirement {
			subject sensor = rearParkingSensor;
		}
		
		satisfy operatingFrequency : OperatingFrequencyRequirement {
			subject sensor = rearParkingSensor;
		}
		
		satisfy environmental : EnvironmentalRequirement {
			subject sensor = rearParkingSensor;
		}
	}
	
	individual def TestObstacle {
		attribute position : ObstacleDistance;
	}
	
	individual def TestScenario {
		individual obstacle : TestObstacle {
			attribute :>> position = 1.0[m];
		}
	}
	
	verification sensingTest {
		subject testSensor : ParkingSensorUnit = rearParkingSensor;
		
		individual scenario : TestScenario;
		
		perform action testMeasurement : PerformSensing {
			in attribute :>> frequency = testSensor.nominalOperatingFrequency;
			in attribute :>> maxDetectionRange = testSensor.maxDetectionRange;
			out item :>> measurement;
		}
		
		assert constraint measurementValid {
			testMeasurement.measurement.status == ObstaclePresent and
			testMeasurement.measurement.distance.num > testSensor.minDetectionRange.num and
			testMeasurement.measurement.distance.num < testSensor.maxDetectionRange.num
		}
	}
}
