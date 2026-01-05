package 'Smoke Detector System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def SmokeConcentration {
		attribute particlesPerMillion : Real;
	}
	
	attribute def AlarmState {
		attribute isActive : Boolean;
		attribute soundLevel : ISQ::SoundPressureLevelValue;
	}
	
	attribute def BatteryLevel {
		attribute chargePercent : Real;
	}
	
	attribute def TestCommand;
	attribute def ResetCommand;
	attribute def SmokeThresholdExceeded;
	attribute def AirClear;
	
	item def AirSample {
		attribute smokeConcentration : SmokeConcentration;
		attribute temperature : ISQ::ThermodynamicTemperatureValue;
	}
	
	item def PowerSupply {
		attribute voltage : ISQ::ElectricPotentialValue;
		attribute current : ISQ::ElectricCurrentValue;
	}
	
	item def AlarmSignal {
		attribute active : Boolean;
		attribute intensity : ISQ::SoundPressureLevelValue;
	}
	
	port def AirIntakePort {
		in airSample : AirSample;
	}
	
	port def AlarmOutputPort {
		out alarmSignal : AlarmSignal;
	}
	
	port def PowerInputPort {
		in power : PowerSupply;
	}
	
	port def ControlPort {
		in testCmd : TestCommand;
		in resetCmd : ResetCommand;
	}
	
	action def MeasureSmokeLevel {
		in sample : AirSample;
		out concentration : SmokeConcentration;
	}
	
	action def ActivateAlarm {
		out signal : AlarmSignal;
	}
	
	action def DeactivateAlarm {
		out signal : AlarmSignal;
	}
	
	action def EmitTestTone {
		out signal : AlarmSignal;
	}
	
	action def Illuminate {
		in active : Boolean;
	}
	
	action def MonitorCharge {
		out level : BatteryLevel;
	}
	
	action def SupplyPower {
		out power : PowerSupply;
	}
	
	action def ProcessSensorData {
		in concentration : SmokeConcentration;
		in threshold : Real;
		out alarmRequired : Boolean;
	}
	
	action def CheckBattery {
		in batteryLevel : BatteryLevel;
		in threshold : Real;
		out batteryLow : Boolean;
	}
	
	action def ExecuteSelfTest {
		in testCmd : TestCommand;
		out testPassed : Boolean;
	}
	
	part def OpticalSensor {
		port airIn : AirIntakePort;
		attribute sensitivity : Real;
		attribute detectionThreshold : Real;
	}
	
	part def SoundAlarm {
		port alarmOut : AlarmOutputPort;
		attribute nominalLevel : ISQ::SoundPressureLevelValue;
	}
	
	part def LEDIndicator {
		attribute color : String;
		attribute blinkRate : ISQ::FrequencyValue;
	}
	
	part def BatteryPack {
		port powerOut : PowerInputPort;
		attribute capacity : ISQ::EnergyValue;
		attribute currentCharge : BatteryLevel;
	}
	
	part def ControlUnit {
		attribute smokeThreshold : Real;
		attribute lowBatteryThreshold : Real;
	}
	
	part def SmokeDetector {
		port airIntake : AirIntakePort;
		port alarmOutput : AlarmOutputPort;
		port powerInput : PowerInputPort;
		port controlInput : ControlPort;
		
		part sensor : OpticalSensor {
			attribute sensitivity = 0.85;
			attribute detectionThreshold = 3.5;
		}
		
		part alarm : SoundAlarm {
			attribute nominalLevel = 85.0 [SI::dB];
		}
		
		part indicator : LEDIndicator {
			attribute color = "red";
			attribute blinkRate = 1.0 [SI::Hz];
		}
		
		part battery : BatteryPack {
			attribute capacity = 32400.0 [SI::J];
			attribute currentCharge : BatteryLevel {
				attribute chargePercent = 100.0;
			}
		}
		
		part controller : ControlUnit {
			attribute smokeThreshold = 3.5;
			attribute lowBatteryThreshold = 15.0;
		}
		
		connect sensor.airIn to airIntake;
		connect alarm.alarmOut to alarmOutput;
		connect battery.powerOut to powerInput;
		
		perform action monitorAndAlert;
	}
	
	action def MonitorAndAlert {
		first start;
		then merge continuousMonitoring;
		
		action measureSmoke : MeasureSmokeLevel {
			in sample : AirSample;
			out concentration : SmokeConcentration;
		}
		
		then action evaluateSmoke : ProcessSensorData {
			in concentration = measureSmoke.concentration;
			in threshold = 3.5;
			out alarmRequired : Boolean;
		}
		
		then decide;
			if evaluateSmoke.alarmRequired then activateAlarm;
			if not evaluateSmoke.alarmRequired then checkBatteryStatus;
		
		action activateAlarm : ActivateAlarm {
			out signal : AlarmSignal;
		}
		then merge continuousMonitoring;
		
		action checkBatteryStatus : CheckBattery {
			in batteryLevel : BatteryLevel;
			in threshold = 15.0;
			out batteryLow : Boolean;
		}
		
		then decide;
			if checkBatteryStatus.batteryLow then warnLowBattery;
			if not checkBatteryStatus.batteryLow then continuousMonitoring;
		
		action warnLowBattery : Illuminate {
			in active = true;
		}
		then continuousMonitoring;
		
		accept testCmd : TestCommand;
		then action performSelfTest : ExecuteSelfTest {
			in testCmd;
			out testPassed : Boolean;
		}
		then action emitTestTone : EmitTestTone {
			out signal : AlarmSignal;
		}
		then continuousMonitoring;
		
		accept resetCmd : ResetCommand;
		then action deactivateAlarm : DeactivateAlarm {
			out signal : AlarmSignal;
		}
		then continuousMonitoring;
	}
	
	state def SmokeDetectorStateMachine {
		entry; then standby;
		
		state standby {
			entry action setStandbyMode {
				assign alarmActive = false;
			}
			do action monitorAir : MeasureSmokeLevel;
		}
		
		transition standby_to_detecting
			first standby
			accept SmokeThresholdExceeded
			then detecting;
		
		state detecting {
			entry action setDetectingMode {
				assign alarmActive = false;
			}
			do action continuousMonitor : MeasureSmokeLevel;
		}
		
		transition detecting_to_alarming
			first detecting
			if smokeAboveThreshold
			then alarming;
		
		state alarming {
			entry action setAlarmingMode {
				assign alarmActive = true;
			}
			do action soundAlarm : ActivateAlarm;
			do action flashIndicator : Illuminate;
		}
		
		transition alarming_to_detecting
			first alarming
			accept ResetCommand
			then detecting;
		
		transition detecting_to_standby
			first detecting
			accept AirClear
			then standby;
		
		state lowBatteryWarning {
			do action indicateLowBattery : Illuminate;
		}
		
		transition any_to_lowBattery
			first standby, detecting, alarming
			if batteryBelowThreshold
			then lowBatteryWarning;
		
		state selfTest {
			do action testSensor : ExecuteSelfTest;
			do action testAlarm : EmitTestTone;
		}
		
		transition any_to_selfTest
			first standby, detecting
			accept TestCommand
			then selfTest;
		
		transition selfTest_to_standby
			first selfTest
			then standby;
		
		attribute alarmActive : Boolean;
		attribute smokeAboveThreshold : Boolean;
		attribute batteryBelowThreshold : Boolean;
	}
	
	part smokeDetectorSystem : SmokeDetector {
		part opticalSensor : OpticalSensor {
			attribute sensitivity = 0.85;
			attribute detectionThreshold = 3.5;
		}
		
		part soundAlarm : SoundAlarm {
			attribute nominalLevel = 85.0 [SI::dB];
		}
		
		part ledIndicator : LEDIndicator {
			attribute color = "red";
			attribute blinkRate = 1.0 [SI::Hz];
		}
		
		part batteryPack : BatteryPack {
			attribute capacity = 32400.0 [SI::J];
			attribute currentCharge : BatteryLevel {
				attribute chargePercent = 100.0;
			}
		}
		
		part controlUnit : ControlUnit {
			attribute smokeThreshold = 3.5;
			attribute lowBatteryThreshold = 15.0;
			
			perform action processAndControl {
				first start;
				then merge processingLoop;
				
				action readSensor {
					in sensorData : SmokeConcentration;
					out processedData : SmokeConcentration;
				}
				
				then action makeDecision {
					in data : SmokeConcentration;
					in threshold : Real;
					out activateAlarm : Boolean;
				}
				
				then decide;
					if makeDecision.activateAlarm then sendAlarmCommand;
					if not makeDecision.activateAlarm then checkPower;
				
				action sendAlarmCommand {
					out command : Boolean;
				}
				then processingLoop;
				
				action checkPower {
					in batteryLevel : BatteryLevel;
					out powerOk : Boolean;
				}
				then processingLoop;
			}
		}
		
		connect opticalSensor.airIn to smokeDetectorSystem.airIntake;
		connect soundAlarm.alarmOut to smokeDetectorSystem.alarmOutput;
		connect batteryPack.powerOut to smokeDetectorSystem.powerInput;
	}
	
	requirement <'SD-REQ-001'> smokeDetectionRequirement {
		doc /* The smoke detector shall detect smoke particle concentrations exceeding 3.5 particles per million within 30 seconds of exposure. */
		
		subject detector : SmokeDetector;
		
		require constraint {
			detector.sensor.detectionThreshold <= 3.5
		}
	}
	
	requirement <'SD-REQ-002'> alarmSoundLevelRequirement {
		doc /* The smoke detector shall produce an audible alarm at a minimum sound pressure level of 85 dB at 3 meters distance when smoke is detected. */
		
		subject detector : SmokeDetector;
		
		require constraint {
			detector.alarm.nominalLevel >= 85.0 [SI::dB]
		}
	}
	
	requirement <'SD-REQ-003'> batteryOperationRequirement {
		doc /* The smoke detector shall operate continuously for a minimum of 12 months on battery power under normal conditions. */
		
		subject detector : SmokeDetector;
	}
	
	requirement <'SD-REQ-004'> selfTestCapabilityRequirement {
		doc /* The smoke detector shall provide a manual self-test function to verify sensor and alarm functionality. */
		
		subject detector : SmokeDetector;
	}
	
	requirement <'SD-REQ-005'> lowBatteryWarningRequirement {
		doc /* The smoke detector shall provide a visual low battery warning when battery charge drops below 15 percent. */
		
		subject detector : SmokeDetector;
		
		require constraint {
			detector.battery.currentCharge.chargePercent < 15.0 implies
			detector.indicator.color == "red"
		}
	}
	
	requirement <'SD-REQ-006'> falseAlarmPreventionRequirement {
		doc /* The smoke detector shall minimize false alarms by requiring sustained smoke concentration above threshold for at least 5 seconds before activating alarm. */
		
		subject detector : SmokeDetector;
	}
	
	requirement systemMissionRequirement {
		doc /* The smoke detector system shall continuously monitor the ambient air for the presence of smoke particles and immediately alert occupants through audible and visual alarms when smoke concentration exceeds safe thresholds, thereby providing early warning of potential fire hazards. */
		
		assume constraint operatingEnvironment {
			doc /* The detector operates in indoor environments with temperature range 0-40°C and relative humidity 10-90% non-condensing. */
		}
		
		require smokeDetectionRequirement;
		require alarmSoundLevelRequirement;
		require batteryOperationRequirement;
		require selfTestCapabilityRequirement;
		require lowBatteryWarningRequirement;
		require falseAlarmPreventionRequirement;
	}
}
