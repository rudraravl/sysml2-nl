package 'Carbon Monoxide Detector System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def COConcentration :> Real {
		doc /* Carbon monoxide concentration in parts per million (ppm) */
	}
	
	attribute def AlarmThreshold {
		attribute level : COConcentration;
		attribute exposureDuration : DurationValue;
	}
	
	attribute def BatteryCapacity :> Real {
		doc /* Battery charge level as percentage (0-100) */
	}
	
	item def COSample {
		attribute concentration : COConcentration;
		attribute timestamp : TimeValue;
		attribute temperature : ThermodynamicTemperatureValue;
	}
	
	item def AlarmCommand {
		attribute activate : Boolean;
		attribute intensity : Real;
	}
	
	port def SensorDataPort {
		out sample : COSample;
	}
	
	port def AlarmControlPort {
		in command : AlarmCommand;
		out audioActive : Boolean;
		out visualActive : Boolean;
	}
	
	port def PowerSupplyPort {
		in batteryLevel : BatteryCapacity;
		out lowBatteryAlert : Boolean;
	}
	
	part def ElectrochemicalSensor {
		doc /* Electrochemical sensor that detects CO gas and outputs concentration readings */
		
		port dataOutput : SensorDataPort;
		
		attribute calibrationFactor : Real := 1.0;
		attribute sensorDrift : Real := 0.0;
		
		action def SampleAmbientAir {
			out reading : COSample;
		}
		
		perform action continuousSampling {
			first start;
			then merge sampleLoop;
			action sample : SampleAmbientAir {
				out reading : COSample;
			}
			then sampleLoop;
		}
	}
	
	part def AudioVisualAlarm {
		doc /* Combined audio and visual alarm unit with piezoelectric buzzer and LED indicators */
		
		port control : ~AlarmControlPort;
		
		attribute audioEnabled : Boolean := false;
		attribute visualEnabled : Boolean := false;
		attribute buzzerFrequency : FrequencyValue := 3000.0[Hz];
		attribute ledBrightness : Real := 0.0;
		
		action def ActivateAudio {
			in enable : Boolean;
		}
		
		action def ActivateVisual {
			in enable : Boolean;
		}
		
		state alarmBehavior {
			entry; then standby;
			
			state standby {
				entry assign audioEnabled := false;
				entry assign visualEnabled := false;
				entry assign ledBrightness := 0.0;
			}
			
			transition standby_to_active
				first standby
				accept control.command
				if control.command.activate == true
				then active;
			
			state active {
				entry assign audioEnabled := true;
				entry assign visualEnabled := true;
				entry assign ledBrightness := 100.0;
			}
			
			transition active_to_standby
				first active
				accept control.command
				if control.command.activate == false
				then standby;
		}
	}
	
	part def BatteryPowerSystem {
		doc /* 9V battery power system with voltage monitoring and low battery detection */
		
		port powerMonitor : PowerSupplyPort;
		
		attribute nominalVoltage : ElectricPotentialValue := 9.0[V];
		attribute currentCharge : BatteryCapacity := 100.0;
		attribute dischargeRate : Real := 0.01;
		attribute lowBatteryThreshold : BatteryCapacity := 20.0;
		
		action def CheckBatteryLevel {
			in charge : BatteryCapacity;
			in threshold : BatteryCapacity;
			out isLow : Boolean;
		}
		
		perform action batteryManagement {
			first start;
			then merge monitorLoop;
			action checkLevel : CheckBatteryLevel {
				in charge = currentCharge;
				in threshold = lowBatteryThreshold;
				out isLow;
			}
			then decide;
				if checkLevel.isLow then lowBatteryAction;
				else normalBatteryAction;
			action lowBatteryAction {
				assign powerMonitor.lowBatteryAlert := true;
			}
			then monitorLoop;
			action normalBatteryAction {
				assign powerMonitor.lowBatteryAlert := false;
			}
			then monitorLoop;
		}
	}
	
	part def ProcessingUnit {
		doc /* Microcontroller-based processing unit that analyzes CO levels and controls alarm activation */
		
		in port sensorData : ~SensorDataPort;
		out port alarmControl : AlarmControlPort;
		in port powerStatus : ~PowerSupplyPort;
		
		attribute ulThreshold : AlarmThreshold {
			doc /* UL 2034 standard: 70 ppm for 60-240 minutes */
			attribute level = 70.0;
			attribute exposureDuration = 60.0[min];
		}
		
		attribute immediateThreshold : AlarmThreshold {
			doc /* Immediate danger: 400 ppm */
			attribute level = 400.0;
			attribute exposureDuration = 0.0[s];
		}
		
		attribute mediumThreshold : AlarmThreshold {
			doc /* Medium danger: 150 ppm for 10-50 minutes */
			attribute level = 150.0;
			attribute exposureDuration = 10.0[min];
		}
		
		attribute currentConcentration : COConcentration := 0.0;
		attribute exposureStartTime : TimeValue;
		attribute alarmActive : Boolean := false;
		attribute batteryLow : Boolean := false;
		
		action def EvaluateHazard {
			in reading : COSample;
			in threshold1 : AlarmThreshold;
			in threshold2 : AlarmThreshold;
			in threshold3 : AlarmThreshold;
			out hazardDetected : Boolean;
			out alarmIntensity : Real;
		}
		
		action def GenerateAlarmCommand {
			in activate : Boolean;
			in intensity : Real;
			out command : AlarmCommand;
		}
		
		perform action hazardAnalysis {
			first start;
			then merge continuousAnalysis;
			accept reading : COSample via sensorData;
			then assign currentConcentration := reading.concentration;
			then action evaluate : EvaluateHazard {
				in reading = reading;
				in threshold1 = ulThreshold;
				in threshold2 = mediumThreshold;
				in threshold3 = immediateThreshold;
				out hazardDetected;
				out alarmIntensity;
			}
			then decide;
				if evaluate.hazardDetected then triggerAlarm;
				else clearAlarm;
			action triggerAlarm {
				action generateCommand : GenerateAlarmCommand {
					in activate = true;
					in intensity = evaluate.alarmIntensity;
					out command;
				}
				then assign alarmActive := true;
			}
			then continuousAnalysis;
			action clearAlarm {
				action generateCommand : GenerateAlarmCommand {
					in activate = false;
					in intensity = 0.0;
					out command;
				}
				then assign alarmActive := false;
			}
			then continuousAnalysis;
		}
	}
	
	part carbonMonoxideDetector : CODetectorSystem {
		doc /* 
			A carbon monoxide detector system that continuously monitors ambient CO concentration
			and activates audio-visual alarms when hazardous levels are detected according to
			UL 2034 safety standards. The system operates on battery power with low battery
			indication and provides multi-level alarm response based on concentration and
			exposure duration.
		*/
		
		part sensor : ElectrochemicalSensor;
		part processor : ProcessingUnit;
		part alarm : AudioVisualAlarm;
		part battery : BatteryPowerSystem;
		
		connect sensor.dataOutput to processor.sensorData;
		connect processor.alarmControl to alarm.control;
		connect battery.powerMonitor to processor.powerStatus;
		
		perform action detectAndAlertCO {
			doc /* Primary system function: detect carbon monoxide and alert occupants */
			
			first start;
			then action systemInitialization {
				action sensorWarmup;
				then action selfDiagnostic;
				then action calibrationCheck;
			}
			then merge operationalLoop;
			action sensorMonitoring references sensor.continuousSampling;
			then action hazardProcessing references processor.hazardAnalysis;
			then action alarmManagement references alarm.alarmBehavior;
			then action powerManagement references battery.batteryManagement;
			then operationalLoop;
		}
	}
	
	requirement def SafetyStandard;
	requirement def OperationalRequirement;
	
	requirement <'REQ-CO-001'> detectHazardousLevels : SafetyStandard {
		doc /* 
			The carbon monoxide detector shall activate an alarm when CO concentration
			reaches or exceeds 400 ppm immediately, or 150 ppm for 10-50 minutes,
			or 70 ppm for 60-240 minutes, in accordance with UL 2034 standard.
		*/
		
		subject detector : CODetectorSystem;
		
		require constraint {
			detector.processor.currentConcentration >= detector.processor.immediateThreshold.level
			implies detector.processor.alarmActive == true
		}
	}
	
	requirement <'REQ-CO-002'> continuousMonitoring : OperationalRequirement {
		doc /* 
			The system shall continuously monitor ambient CO levels with a sampling
			rate sufficient to detect rapid concentration changes and respond within
			the time limits specified by safety standards.
		*/
		
		subject detector : CODetectorSystem;
	}
	
	requirement <'REQ-CO-003'> audioVisualIndication : SafetyStandard {
		doc /* 
			When an alarm condition is detected, the system shall activate both
			audio (minimum 85 dB at 10 feet) and visual indicators to alert occupants.
		*/
		
		subject detector : CODetectorSystem;
		
		require constraint {
			detector.processor.alarmActive == true implies
			(detector.alarm.audioEnabled == true and detector.alarm.visualEnabled == true)
		}
	}
	
	requirement <'REQ-CO-004'> lowBatteryWarning : OperationalRequirement {
		doc /* 
			The system shall provide a distinct low battery warning when battery
			capacity falls below 20% to ensure continued operation and user awareness.
		*/
		
		subject detector : CODetectorSystem;
		
		require constraint {
			detector.battery.currentCharge < detector.battery.lowBatteryThreshold
			implies detector.battery.powerMonitor.lowBatteryAlert == true
		}
	}
	
	requirement <'REQ-CO-005'> falseAlarmPrevention : SafetyStandard {
		doc /* 
			The system shall incorporate exposure duration thresholds to prevent
			false alarms from brief, non-hazardous CO spikes while ensuring rapid
			response to genuinely dangerous conditions.
		*/
		
		subject detector : CODetectorSystem;
	}
	
	requirement systemMission {
		doc /* 
			The primary function of the carbon monoxide detector system is to protect
			building occupants from carbon monoxide poisoning by continuously monitoring
			ambient CO levels and providing timely audio-visual warnings when hazardous
			concentrations are detected, while maintaining reliable battery-powered
			operation with user notification of low battery conditions.
		*/
		
		require detectHazardousLevels;
		require continuousMonitoring;
		require audioVisualIndication;
		require lowBatteryWarning;
		require falseAlarmPrevention;
	}
}
