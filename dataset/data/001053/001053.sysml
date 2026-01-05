package 'Flame Detector System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def FlameDetected;
	attribute def NoFlame;
	attribute def AlarmActive;
	attribute def AlarmInactive;
	
	attribute def IRIntensityValue :> Real;
	
	attribute def TemperatureThresholdValue :> ThermodynamicTemperatureValue;
	
	item def FlameSignature {
		attribute irIntensity : IRIntensityValue;
		attribute temperature : ThermodynamicTemperatureValue;
		attribute flickerRate : FrequencyValue;
	}
	
	item def AlarmSignal {
		attribute isActive : Boolean;
		attribute timestamp : TimeValue;
	}
	
	port def SensorDataPort {
		out irReading : IRIntensityValue;
		out tempReading : ThermodynamicTemperatureValue;
		out flickerReading : FrequencyValue;
	}
	
	port def AlarmControlPort {
		in activationCommand : Boolean;
		out alarmStatus : Boolean;
	}
	
	port def PowerInputPort {
		in voltage : Real;
		in current : ElectricCurrentValue;
	}
	
	part def InfraredSensor {
		attribute sensitivity : IRIntensityValue = 0.5;
		attribute detectionRange : LengthValue = 10.0;
		port dataOutput : SensorDataPort;
		
		action def MeasureIRIntensity {
			out intensity : IRIntensityValue;
		}
		
		perform action measure : MeasureIRIntensity;
	}
	
	part def TemperatureSensor {
		attribute accuracy : ThermodynamicTemperatureValue = 2.0;
		attribute responseTime : TimeValue = 0.5;
		port dataOutput : SensorDataPort;
		
		action def MeasureTemperature {
			out temp : ThermodynamicTemperatureValue;
		}
		
		perform action measure : MeasureTemperature;
	}
	
	part def FlickerDetector {
		attribute frequencyRange : FrequencyValue = 15.0;
		port dataOutput : SensorDataPort;
		
		action def DetectFlicker {
			out flickerFreq : FrequencyValue;
		}
		
		perform action detect : DetectFlicker;
	}
	
	part def AnalysisModule {
		attribute irThreshold : IRIntensityValue = 1.2;
		attribute tempThreshold : ThermodynamicTemperatureValue = 373.15;
		attribute flickerThreshold : FrequencyValue = 5.0;
		
		port irInput : ~SensorDataPort;
		port tempInput : ~SensorDataPort;
		port flickerInput : ~SensorDataPort;
		port alarmOutput : AlarmControlPort;
		
		action def AnalyzeFlameCharacteristics {
			in irLevel : IRIntensityValue;
			in tempLevel : ThermodynamicTemperatureValue;
			in flickerLevel : FrequencyValue;
			in irThresh : IRIntensityValue;
			in tempThresh : ThermodynamicTemperatureValue;
			in flickerThresh : FrequencyValue;
			out flameConfirmed : Boolean;
			
			first start;
			then action evaluateIR {
				attribute irExceeded : Boolean;
			}
			then action evaluateTemp {
				attribute tempExceeded : Boolean;
			}
			then action evaluateFlicker {
				attribute flickerExceeded : Boolean;
			}
			then decide;
				if evaluateIR.irExceeded and evaluateTemp.tempExceeded and evaluateFlicker.flickerExceeded 
					then confirmFlame;
				if not (evaluateIR.irExceeded and evaluateTemp.tempExceeded and evaluateFlicker.flickerExceeded) 
					then rejectFlame;
			action confirmFlame {
				then assign flameConfirmed := true;
			}
			then done;
			action rejectFlame {
				then assign flameConfirmed := false;
			}
			then done;
		}
		
		perform action analyze : AnalyzeFlameCharacteristics;
	}
	
	part def AlarmUnit {
		attribute soundLevel : Real = 95.0;
		attribute strobeFrequency : FrequencyValue = 2.0;
		port controlInput : ~AlarmControlPort;
		
		action def ActivateAlarm {
			in trigger : Boolean;
			out status : Boolean;
			
			first start;
			then decide;
				if trigger then soundAlarm;
				if not trigger then silenceAlarm;
			action soundAlarm {
				then assign status := true;
			}
			then done;
			action silenceAlarm {
				then assign status := false;
			}
			then done;
		}
		
		perform action activate : ActivateAlarm;
	}
	
	part def PowerModule {
		attribute inputVoltage : Real = 24.0;
		attribute maxCurrent : ElectricCurrentValue = 2.0;
		port powerOutput : PowerInputPort;
	}
	
	state def FlameDetectorOperationalState {
		entry; then standby;
		
		state standby {
			entry assign operationalMode := "Standby";
		}
		
		transition standby_to_monitoring
			first standby
			accept powerOn : Real
			then monitoring;
		
		state monitoring {
			entry assign operationalMode := "Active Monitoring";
			do action continuousSensing;
		}
		
		transition monitoring_to_analyzing
			first monitoring
			accept sensorData : FlameSignature
			then analyzing;
		
		state analyzing {
			entry assign operationalMode := "Analyzing Data";
			do action processData;
		}
		
		transition analyzing_to_flameConfirmed
			first analyzing
			accept FlameDetected
			then flameConfirmed;
		
		transition analyzing_to_monitoring
			first analyzing
			accept NoFlame
			then monitoring;
		
		state flameConfirmed {
			entry assign operationalMode := "Flame Confirmed";
		}
		
		transition flameConfirmed_to_alarming
			first flameConfirmed
			accept AlarmActive
			then alarming;
		
		state alarming {
			entry assign operationalMode := "Alarm Active";
			do action maintainAlarm;
		}
		
		transition alarming_to_monitoring
			first alarming
			accept AlarmInactive
			then monitoring;
		
		attribute operationalMode : String;
	}
	
	action def ContinuousFlameMonitoring {
		out flameStatus : Boolean;
		out irMeasurement : IRIntensityValue;
		out tempMeasurement : ThermodynamicTemperatureValue;
		out flickerMeasurement : FrequencyValue;
		
		first start;
		then merge monitoringLoop;
		then action collectSensorData {
			out ir : IRIntensityValue;
			out temp : ThermodynamicTemperatureValue;
			out flicker : FrequencyValue;
		}
		then action evaluateData {
			in ir : IRIntensityValue = collectSensorData.ir;
			in temp : ThermodynamicTemperatureValue = collectSensorData.temp;
			in flicker : FrequencyValue = collectSensorData.flicker;
			out detected : Boolean;
		}
		then decide;
			if evaluateData.detected then activateResponse;
			if not evaluateData.detected then continueMonitoring;
		action activateResponse {
			then assign flameStatus := true;
		}
		then monitoringLoop;
		action continueMonitoring {
			then assign flameStatus := false;
		}
		then monitoringLoop;
	}
	
	connection def SensorConnection {
		end source : SensorDataPort;
		end target : ~SensorDataPort;
	}
	
	connection def AlarmConnection {
		end source : AlarmControlPort;
		end target : ~AlarmControlPort;
	}
	
	connection def PowerConnection {
		end source : PowerInputPort;
		end target : ~PowerInputPort;
	}
	
	part def FlameDetectorSystem {
		doc /* 
		The flame detector system continuously monitors the environment for flame presence
		using multiple sensor modalities including infrared radiation, temperature, and
		flicker frequency analysis. Upon detecting a confirmed flame signature, the system
		automatically activates an alarm to alert personnel and initiate emergency response.
		*/
		
		part irSensor : InfraredSensor {
			port dataOutput;
		}
		
		part tempSensor : TemperatureSensor {
			port dataOutput;
		}
		
		part flickerSensor : FlickerDetector {
			port dataOutput;
		}
		
		part analysisUnit : AnalysisModule {
			port irInput;
			port tempInput;
			port flickerInput;
			port alarmOutput;
		}
		
		part alarmDevice : AlarmUnit {
			port controlInput;
		}
		
		part powerSupply : PowerModule {
			port powerOutput;
		}
		
		connection irConnection : SensorConnection
			connect irSensor.dataOutput to analysisUnit.irInput;
		
		connection tempConnection : SensorConnection
			connect tempSensor.dataOutput to analysisUnit.tempInput;
		
		connection flickerConnection : SensorConnection
			connect flickerSensor.dataOutput to analysisUnit.flickerInput;
		
		connection alarmConnection : AlarmConnection
			connect analysisUnit.alarmOutput to alarmDevice.controlInput;
		
		perform action monitorFlames : ContinuousFlameMonitoring;
		
		exhibit state systemState : FlameDetectorOperationalState;
	}
	
	part flameDetector : FlameDetectorSystem;
	
	requirement <'FD-REQ-001'> primaryFlameDetectionFunction {
		doc /* 
		The flame detector system shall continuously monitor the environment and detect
		the presence of flames by analyzing infrared radiation, temperature elevation,
		and characteristic flicker patterns, then automatically activate an alarm when
		a flame is confirmed.
		*/
		
		subject flameDetector : FlameDetectorSystem;
		
		require constraint multiModalDetection {
			doc /* 
			Flame detection shall utilize at least three independent sensing modalities:
			infrared intensity, temperature, and flicker frequency.
			*/
		}
		
		require constraint automaticAlarmActivation {
			doc /* 
			The alarm shall activate automatically within 2 seconds of confirmed flame detection.
			*/
		}
	}
	
	requirement <'FD-REQ-002'> detectionSensitivity {
		doc /* 
		The system shall detect flames with infrared intensity exceeding 1.2 W/m^2,
		temperature exceeding 373.15 K, and flicker frequency between 5-15 Hz.
		*/
		
		subject analysisUnit : AnalysisModule;
		
		require constraint irSensitivityThreshold {
			doc /* IR threshold shall be configurable between 0.5 and 2.0 W/m^2. */
		}
		
		require constraint temperatureSensitivityThreshold {
			doc /* Temperature threshold shall be configurable between 323.15 K and 423.15 K. */
		}
	}
	
	requirement <'FD-REQ-003'> falseAlarmMitigation {
		doc /* 
		The system shall minimize false alarms by requiring simultaneous threshold
		exceedance across all three sensor modalities before confirming flame presence.
		*/
		
		subject analysisUnit : AnalysisModule;
		
		require constraint simultaneousThresholdExceedance {
			doc /* 
			All three sensor thresholds (IR, temperature, flicker) must be exceeded
			concurrently for flame confirmation.
			*/
		}
	}
	
	requirement <'FD-REQ-004'> continuousOperationalAvailability {
		doc /* 
		The flame detector system shall operate continuously with a minimum uptime
		of 99.9% under normal environmental conditions.
		*/
		
		subject flameDetector : FlameDetectorSystem;
		
		require constraint powerReliability {
			doc /* Power supply shall maintain stable output within ±5% of nominal voltage. */
		}
		
		require constraint sensorReliability {
			doc /* All sensors shall maintain calibration accuracy for minimum 12 months. */
		}
	}
	
	requirement <'FD-REQ-005'> alarmPerformance {
		doc /* 
		The alarm unit shall produce audible and visual alerts with sound level
		of at least 85 dB at 3 meters and strobe frequency of 1-3 Hz.
		*/
		
		subject alarmDevice : AlarmUnit;
		
		require constraint soundLevelRequirement {
			doc /* Alarm sound level shall be at least 85 dB at 3 meters distance. */
		}
		
		require constraint strobeFrequencyRequirement {
			doc /* Strobe frequency shall be between 1 and 3 Hz for visibility. */
		}
	}
}
