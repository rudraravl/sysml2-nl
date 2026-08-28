package 'CO Detector System' {
	private import ScalarValues::*;
	private import ISQ::*;
	
	attribute def COConcentrationValue :> Real;
	attribute def BatteryChargeValue :> Real;
	attribute def VoltageValue :> Real;
	attribute def ExposureDurationValue :> Real;
	
	attribute def COReading {
		attribute concentration : COConcentrationValue;
		attribute timestamp : TimeValue;
	}
	
	attribute def AlarmCommand;
	attribute def LowBatteryAlert;
	
	port def SensorOutputPort {
		out reading : COReading;
	}
	port def SensorInputPort {
		in reading : COReading;
	}
	port def BatteryStatusPort {
		out alert : LowBatteryAlert;
	}
	port def BatteryInputPort {
		in alert : LowBatteryAlert;
	}
	port def AlarmOutputPort {
		out command : AlarmCommand;
	}
	port def AlarmInputPort {
		in command : AlarmCommand;
	}
	port def PowerOutPort {
		out voltage : VoltageValue;
	}
	port def PowerInPort {
		in voltage : VoltageValue;
	}
	
	action def SampleAir {
		out reading : COReading;
	}
	
	action def AnalyzeCO {
		in reading : COReading;
		in timer : TimeValue;
		out isHazardous : Boolean;
	}
	
	action def ActivateAlarm {
		in command : AlarmCommand;
		action soundBuzzer;
		action flashLED;
	}
	
	action def MonitorBattery {
		in charge : BatteryChargeValue;
		out alert : LowBatteryAlert;
	}
	
	part def ElectrochemicalSensor {
		port sensorOut : SensorOutputPort;
		port powerIn : PowerInPort;
		perform action sample : SampleAir;
		exhibit state sensorStates {
			entry; then sampling;
			state sampling {
				do action sampleAir : SampleAir {
					out reading;
				}
			}
		}
	}
	
	part def CentralProcessingUnit {
		port sensorIn : SensorInputPort;
		port batteryIn : BatteryInputPort;
		port alarmOut : AlarmOutputPort;
		port powerIn : PowerInPort;
		
		attribute exposureTimer : TimeValue = 0;
		
		exhibit state cpuStates {
			entry; then idle;
			state idle;
			accept 'CO Reading'
				then measuring;
			state measuring {
				do action analyze : AnalyzeCO {
					in reading = sensorIn.reading;
					in timer = exposureTimer;
					out isHazardous;
				}
			}
			accept when sensorIn.reading.concentration > 400
				do send new AlarmCommand() to alarmOut
				then alarming;
			accept when sensorIn.reading.concentration > 70 and exposureTimer >= 60
				do send new AlarmCommand() to alarmOut
				then alarming;
			accept when sensorIn.reading.concentration < 70
				then idle;
			state alarming {
				do send new AlarmCommand() to alarmOut;
			}
			accept 'Safe Condition'
				then idle;
		}
	}
	
	part def AudioVisualAlarm {
		port alarmIn : AlarmInputPort;
		port powerIn : PowerInPort;
		part buzzer;
		part ledIndicator;
		perform action activate : ActivateAlarm;
		exhibit state alarmStates {
			entry; then idle;
			state idle;
			accept 'Alarm Command'
				then active;
			state active {
				entry action soundBuzzer;
				entry action flashLED;
			}
			accept 'Clear Alarm'
				then idle;
		}
	}
	
	part def BatteryPowerSystem {
		part battery {
			attribute charge : BatteryChargeValue = 100;
			attribute voltage : VoltageValue = 9;
		}
		port powerOut : PowerOutPort;
		port statusOut : BatteryStatusPort;
		
		exhibit state batteryStates {
			entry; then normal;
			state normal {
				do action monitor : MonitorBattery {
					in charge = battery.charge;
					out alert;
				}
			}
			accept when battery.charge < 20
				do send new LowBatteryAlert() to statusOut
				then low;
			state low {
				do send new LowBatteryAlert() to statusOut;
			}
			accept 'Battery Replaced'
				then normal;
		}
	}
	
	part def CODetector {
		part sensor : ElectrochemicalSensor;
		part cpu : CentralProcessingUnit;
		part alarm : AudioVisualAlarm;
		part powerSystem : BatteryPowerSystem;
		
		connect sensor.sensorOut to cpu.sensorIn;
		connect cpu.alarmOut to alarm.alarmIn;
		connect powerSystem.statusOut to cpu.batteryIn;
		connect powerSystem.powerOut to sensor.powerIn;
		connect powerSystem.powerOut to cpu.powerIn;
		connect powerSystem.powerOut to alarm.powerIn;
	}
	
	requirement def COAlarmRequirement {
		subject coDetector : CODetector;
		doc /* The CO detector shall activate the alarm when CO concentration exceeds safe limits, considering both concentration and exposure duration. */;
	}
	
	requirement def LowBatteryRequirement {
		subject coDetector : CODetector;
		doc /* The system shall produce a distinct warning when the battery runs low. */;
	}
	
	requirement def ContinuousMonitoringRequirement {
		subject coDetector : CODetector;
		doc /* The system shall continuously monitor air quality and battery status. */;
	}
}
