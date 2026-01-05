package 'Ultrasonic Sensing Unit' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import Time::*;
	
	item def UltrasonicPulse {
		attribute frequency : ISQ::FrequencyValue;
		attribute emissionTime : Time::TimeValue;
	}
	
	item def EchoSignal {
		attribute receptionTime : Time::TimeValue;
		attribute amplitude : Real;
	}
	
	port def SensorOutputPort {
		out distance : ISQ::LengthValue;
		out validMeasurement : Boolean;
	}
	
	port def PowerInputPort {
		in voltage : Real;
		in current : Real;
	}
	
	port def AcousticPort {
		out pulse : UltrasonicPulse;
		in echo : EchoSignal;
	}
	
	part def UltrasonicTransducer {
		attribute operatingFrequency : ISQ::FrequencyValue;
		attribute beamWidth : Real;
		
		port acoustic : AcousticPort;
		port power : PowerInputPort;
	}
	
	part def SignalProcessor {
		attribute speedOfSound : ISQ::SpeedValue;
		
		port pulseInput {
			in emissionTime : Time::TimeValue;
		}
		
		port echoInput {
			in receptionTime : Time::TimeValue;
		}
		
		port distanceOutput {
			out calculatedDistance : ISQ::LengthValue;
		}
	}
	
	part def TemperatureCompensator {
		attribute ambientTemperature : ISQ::TemperatureValue;
		attribute baseSpeedOfSound : ISQ::SpeedValue;
		
		port temperatureInput {
			in temperature : ISQ::TemperatureValue;
		}
		
		port velocityOutput {
			out compensatedVelocity : ISQ::SpeedValue;
		}
	}
	
	action def EmitUltrasonicPulse {
		in frequency : ISQ::FrequencyValue;
		out pulse : UltrasonicPulse;
		out emissionTimestamp : Time::TimeValue;
	}
	
	action def DetectEcho {
		in transmittedPulse : UltrasonicPulse;
		out echo : EchoSignal;
		out receptionTimestamp : Time::TimeValue;
	}
	
	action def ComputeDistance {
		in timeOfFlight : Time::TimeValue;
		in soundSpeed : ISQ::SpeedValue;
		out distance : ISQ::LengthValue;
	}
	
	action def CompensateTemperature {
		in temperature : ISQ::TemperatureValue;
		in baseVelocity : ISQ::SpeedValue;
		out adjustedVelocity : ISQ::SpeedValue;
	}
	
	action def ValidateMeasurement {
		in measuredDistance : ISQ::LengthValue;
		in minRange : ISQ::LengthValue;
		in maxRange : ISQ::LengthValue;
		out isValid : Boolean;
	}
	
	action def PerformUltrasonicMeasurement {
		in operatingFrequency : ISQ::FrequencyValue;
		in currentTemperature : ISQ::TemperatureValue;
		in nominalSoundSpeed : ISQ::SpeedValue;
		in minimumRange : ISQ::LengthValue;
		in maximumRange : ISQ::LengthValue;
		out distance : ISQ::LengthValue;
		out valid : Boolean;
		
		action compensate : CompensateTemperature {
			in temperature = currentTemperature;
			in baseVelocity = nominalSoundSpeed;
			out adjustedVelocity;
		}
		then action emit : EmitUltrasonicPulse {
			in frequency = operatingFrequency;
			out pulse;
			out emissionTimestamp;
		}
		then action detect : DetectEcho {
			in transmittedPulse = emit.pulse;
			out echo;
			out receptionTimestamp;
		}
		then action compute : ComputeDistance {
			in timeOfFlight;
			in soundSpeed = compensate.adjustedVelocity;
			out distance;
		}
		then action validate : ValidateMeasurement {
			in measuredDistance = compute.distance;
			in minRange = minimumRange;
			in maxRange = maximumRange;
			out isValid;
		}
		
		flow from emit.emissionTimestamp to compute.timeOfFlight;
		flow from detect.receptionTimestamp to compute.timeOfFlight;
		
		bind compute.distance = distance;
		bind validate.isValid = valid;
	}
	
	state def UltrasonicSensorStateMachine {
		entry; then idle;
		
		state idle;
		transition idle_to_measuring
			first idle
			then measuring;
		
		state measuring {
			entry; then transmitting;
			
			state transmitting;
			transition transmitting_to_receiving
				first transmitting
				then receiving;
			
			state receiving;
			transition receiving_to_computing
				first receiving
				then computing;
			
			state computing;
			transition computing_to_done
				first computing
				then done;
		}
		transition measuring_to_idle
			first measuring
			then idle;
		
		state timeout;
		transition receiving_to_timeout
			first receiving
			then timeout;
		
		transition timeout_to_idle
			first timeout
			then idle;
	}
	
	part def UltrasonicSensingUnit {
		attribute minimumRange : ISQ::LengthValue;
		attribute maximumRange : ISQ::LengthValue;
		attribute operatingFrequency : ISQ::FrequencyValue;
		attribute ambientTemperature : ISQ::TemperatureValue;
		attribute nominalSoundSpeed : ISQ::SpeedValue;
		
		part transducer : UltrasonicTransducer {
			attribute :>> operatingFrequency = UltrasonicSensingUnit::operatingFrequency;
			attribute :>> beamWidth = 15.0;
		}
		
		part processor : SignalProcessor {
			attribute :>> speedOfSound = nominalSoundSpeed;
		}
		
		part tempCompensator : TemperatureCompensator {
			attribute :>> ambientTemperature = UltrasonicSensingUnit::ambientTemperature;
			attribute :>> baseSpeedOfSound = nominalSoundSpeed;
		}
		
		port sensorOutput : SensorOutputPort;
		port powerInput : PowerInputPort;
		
		connection tempToProcessor
			connect tempCompensator.velocityOutput.compensatedVelocity
			to processor.speedOfSound;
		
		connection transducerPower
			connect powerInput
			to transducer.power;
		
		connection processorToOutput
			connect processor.distanceOutput.calculatedDistance
			to sensorOutput.distance;
		
		perform action measurementCycle : PerformUltrasonicMeasurement {
			in :>> operatingFrequency = UltrasonicSensingUnit::operatingFrequency;
			in :>> currentTemperature = tempCompensator.ambientTemperature;
			in :>> nominalSoundSpeed = UltrasonicSensingUnit::nominalSoundSpeed;
			in :>> minimumRange = UltrasonicSensingUnit::minimumRange;
			in :>> maximumRange = UltrasonicSensingUnit::maximumRange;
			out :>> distance;
			out :>> valid;
		}
		
		exhibit state sensorBehavior : UltrasonicSensorStateMachine;
	}
	
	part ultrasonicSensor : UltrasonicSensingUnit {
		attribute :>> minimumRange = 0.02[m];
		attribute :>> maximumRange = 4.0[m];
		attribute :>> operatingFrequency = 40000.0[Hz];
		attribute :>> ambientTemperature = 293.15[K];
		attribute :>> nominalSoundSpeed = 343.0[m/s];
	}
	
	requirement def RangeMeasurementRequirement {
		doc /* The ultrasonic sensing unit shall measure distances within the range of 2 cm to 4 meters. */
		
		subject sensingUnit : UltrasonicSensingUnit;
		
		require constraint {
			sensingUnit.minimumRange == 0.02[m] and
			sensingUnit.maximumRange == 4.0[m]
		}
	}
	
	requirement def AccuracyRequirement {
		doc /* The ultrasonic sensing unit shall provide distance measurements with an accuracy of ±1% of the measured value. */
		
		subject sensingUnit : UltrasonicSensingUnit;
		
		require constraint {
			sensingUnit.sensorOutput.distance >= sensingUnit.minimumRange and
			sensingUnit.sensorOutput.distance <= sensingUnit.maximumRange
		}
	}
	
	requirement def TemperatureCompensationRequirement {
		doc /* The ultrasonic sensing unit shall compensate for temperature variations between -20°C and 60°C to maintain measurement accuracy. */
		
		subject sensingUnit : UltrasonicSensingUnit;
		
		require constraint {
			sensingUnit.tempCompensator.ambientTemperature >= 253.15[K] and
			sensingUnit.tempCompensator.ambientTemperature <= 333.15[K]
		}
	}
	
	requirement def ResponseTimeRequirement {
		doc /* The ultrasonic sensing unit shall complete a measurement cycle within 100 milliseconds. */
		
		subject sensingUnit : UltrasonicSensingUnit;
	}
	
	individual def TestScenario1 :> UltrasonicSensingUnit;
	individual def TestScenario2 :> UltrasonicSensingUnit;
	
	individual testSensor : UltrasonicSensingUnit :> ultrasonicSensor {
		timeslice normalConditions {
			attribute :>> ambientTemperature = 293.15[K];
			perform action :>> measurementCycle {
				out :>> distance = 1.25[m];
				out :>> valid = true;
			}
		}
		then timeslice coldConditions {
			attribute :>> ambientTemperature = 263.15[K];
			perform action :>> measurementCycle {
				out :>> distance = 0.50[m];
				out :>> valid = true;
			}
		}
		then timeslice hotConditions {
			attribute :>> ambientTemperature = 313.15[K];
			perform action :>> measurementCycle {
				out :>> distance = 3.5[m];
				out :>> valid = true;
			}
		}
	}
}
