package 'ABS Sensing Unit Model' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	enum def SensorStatus {
		enum operational;
		enum degraded;
		enum failed;
	}
	
	item def RawSensorSignal {
		attribute pulseFrequency : FrequencyValue;
		attribute signalVoltage : Real;
		attribute timestamp : TimeValue;
	}
	
	item def WheelSpeedMeasurement {
		attribute angularVelocity : AngularVelocityValue;
		attribute angularAcceleration : AngularAccelerationValue;
		attribute measurementTime : TimeValue;
		attribute status : SensorStatus;
		attribute confidence : Real;
	}
	
	port def SensorSignalPort {
		out item signal : RawSensorSignal;
	}
	
	port def MeasurementDataPort {
		out item measurement : WheelSpeedMeasurement;
	}
	
	port def PowerPort {
		in item voltage : Real;
	}
	
	connection def SignalConnection {
		end source : SensorSignalPort;
		end target : SensorSignalInputPort;
	}
	
	port def SensorSignalInputPort {
		in item signal : RawSensorSignal;
	}
	
	part def ToneRing {
		attribute teethCount : Integer;
		attribute diameter : LengthValue;
		attribute currentAngularVelocity : AngularVelocityValue;
	}
	
	part def MagneticSensingElement {
		attribute sensitivity : Real;
		attribute minOperatingTemp : TemperatureValue;
		attribute maxOperatingTemp : TemperatureValue;
		attribute airGap : LengthValue;
		
		port powerInput : PowerPort;
		port signalOutput : SensorSignalPort;
		
		action generateSignal {
			in toneRing : ToneRing;
			out rawSignal : RawSensorSignal;
		}
	}
	
	part def SignalConditioner {
		attribute amplificationGain : Real;
		attribute filterCutoffFreq : FrequencyValue;
		attribute samplingRate : FrequencyValue;
		
		port signalInput : SensorSignalInputPort;
		port dataOutput : MeasurementDataPort;
		
		action processSignal {
			in rawSignal : RawSensorSignal;
			out processedMeasurement : WheelSpeedMeasurement;
			
			action filterNoise {
				in signal : RawSensorSignal;
				out filteredSignal : RawSensorSignal;
			}
			
			action calculateVelocity {
				in signal : RawSensorSignal;
				in teethCount : Integer;
				out velocity : AngularVelocityValue;
			}
			
			action calculateAcceleration {
				in currentVelocity : AngularVelocityValue;
				in previousVelocity : AngularVelocityValue;
				in deltaTime : TimeValue;
				out acceleration : AngularAccelerationValue;
			}
			
			action validateMeasurement {
				in signal : RawSensorSignal;
				out status : SensorStatus;
				out confidence : Real;
			}
			
			first filterNoise;
			then fork;
				then calculateVelocity;
				then calculateAcceleration;
				then validateMeasurement;
			join joinNode;
			
			flow from filterNoise.filteredSignal to calculateVelocity.signal;
			flow from filterNoise.filteredSignal to validateMeasurement.signal;
			
			bind calculateVelocity.velocity = processedMeasurement.angularVelocity;
			bind calculateAcceleration.acceleration = processedMeasurement.angularAcceleration;
			bind validateMeasurement.status = processedMeasurement.status;
			bind validateMeasurement.confidence = processedMeasurement.confidence;
		}
	}
	
	state def ABSSensorStates {
		entry; then powerUp;
		
		state powerUp {
			entry action initializeSensor;
		}
		then selfTest;
		
		state selfTest {
			entry action runDiagnostics;
		}
		accept TestPassed then operational;
		accept TestFailed then faultMode;
		
		state operational {
			entry action beginMeasurement;
		}
		accept SignalDegraded then degradedMode;
		accept CriticalFault then faultMode;
		
		state degradedMode {
			entry action reduceSamplingRate;
		}
		accept SignalRestored then operational;
		accept CriticalFault then faultMode;
		
		state faultMode {
			entry action disableSensor;
		}
	}
	
	part def ABSSensor {
		attribute sensorIdentifier : String;
		attribute mountingLocation : String;
		attribute calibrationCoefficient : Real;
		attribute lastCalibrationDate : String;
		
		part sensingElement : MagneticSensingElement[1] {
			attribute :>> sensitivity = 0.92;
			attribute :>> minOperatingTemp = -40.0[Celsius];
			attribute :>> maxOperatingTemp = 125.0[Celsius];
			attribute :>> airGap = 1.5[mm];
		}
		
		part conditioner : SignalConditioner[1] {
			attribute :>> amplificationGain = 10.0;
			attribute :>> filterCutoffFreq = 500.0[Hz];
			attribute :>> samplingRate = 1000.0[Hz];
		}
		
		port power : PowerPort;
		port measurementOutput : MeasurementDataPort;
		
		connection internalSignalPath : SignalConnection
			connect sensingElement.signalOutput to conditioner.signalInput;
		
		perform action sensingOperation {
			in toneRing : ToneRing;
			out measurement : WheelSpeedMeasurement;
			
			action sense : sensingElement.generateSignal {
				in :>> toneRing;
				out rawSignal;
			}
			
			action process : conditioner.processSignal {
				in :>> rawSignal = sense.rawSignal;
				out :>> processedMeasurement = measurement;
			}
			
			succession sense then process;
			flow from sense.rawSignal to process.rawSignal;
		}
		
		exhibit state operatingState : ABSSensorStates;
	}
	
	part def SensingUnit {
		attribute unitIdentifier : String;
		attribute wheelPosition : String;
		
		part sensor : ABSSensor[1] {
			attribute :>> sensorIdentifier = "ABS_WS_001";
			attribute :>> mountingLocation = "Front Left Hub";
			attribute :>> calibrationCoefficient = 1.02;
			attribute :>> lastCalibrationDate = "2025-01-10";
		}
		
		part toneRing : ToneRing[1] {
			attribute :>> teethCount = 48;
			attribute :>> diameter = 95.0[mm];
		}
		
		port powerSupply : PowerPort;
		port speedOutput : MeasurementDataPort;
		
		connect powerSupply to sensor.power;
		bind sensor.measurementOutput = speedOutput;
		
		perform action measureWheelSpeed {
			in wheel :> toneRing;
			out speedData : WheelSpeedMeasurement;
			
			action sensorOperation : sensor.sensingOperation {
				in :>> toneRing = wheel;
				out :>> measurement = speedData;
			}
		}
	}
	
	requirement def SensingUnitRequirement {
		doc /* The sensing unit shall measure wheel angular velocity using an ABS sensor. */
		
		subject unit : SensingUnit;
		
		require constraint {
			unit.sensor <> null
		}
		
		require constraint {
			unit.toneRing <> null
		}
	}
	
	requirement def MeasurementAccuracyRequirement {
		doc /* The ABS sensor shall measure wheel speed with accuracy within ±2% of actual speed. */
		
		subject sensor : ABSSensor;
		
		attribute maxRelativeError : Real = 0.02;
		
		require constraint {
			sensor.sensingElement.sensitivity >= 0.90
		}
		
		require constraint {
			sensor.calibrationCoefficient >= 0.98 and sensor.calibrationCoefficient <= 1.02
		}
	}
	
	requirement def OperatingTemperatureRequirement {
		doc /* The ABS sensor shall operate across temperature range from -40°C to 125°C. */
		
		subject sensor : ABSSensor;
		
		require constraint {
			sensor.sensingElement.minOperatingTemp <= -40.0[Celsius]
		}
		
		require constraint {
			sensor.sensingElement.maxOperatingTemp >= 125.0[Celsius]
		}
	}
	
	requirement def SamplingRateRequirement {
		doc /* The signal conditioner shall sample at minimum 1000 Hz to capture wheel speed dynamics. */
		
		subject conditioner : SignalConditioner;
		
		require constraint {
			conditioner.samplingRate >= 1000.0[Hz]
		}
	}
	
	individual sensingUnitInstance : SensingUnit {
		attribute :>> unitIdentifier = "SU_FL_001";
		attribute :>> wheelPosition = "Front Left";
		
		part :>> sensor {
			part :>> sensingElement {
				port :>> powerInput {
					in item :>> voltage = 12.0;
				}
			}
		}
		
		part :>> toneRing {
			attribute :>> currentAngularVelocity = 523.6[rad_per_s];
		}
		
		perform action :>> measureWheelSpeed {
			in :>> wheel = toneRing;
			out :>> speedData {
				attribute :>> angularVelocity = 523.6[rad_per_s];
				attribute :>> angularAcceleration = 0.0[rad_per_s2];
				attribute :>> status = SensorStatus::operational;
				attribute :>> confidence = 0.98;
			}
		}
		
		satisfy unitReq : SensingUnitRequirement {
			subject :>> unit = sensingUnitInstance;
		}
		
		satisfy accuracyReq : MeasurementAccuracyRequirement {
			subject :>> sensor = sensor;
		}
		
		satisfy tempReq : OperatingTemperatureRequirement {
			subject :>> sensor = sensor;
		}
		
		satisfy samplingReq : SamplingRateRequirement {
			subject :>> conditioner = sensor.conditioner;
		}
	}
}
