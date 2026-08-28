package 'Industrial Safety Monitoring and Response System' {
	private import ScalarValues::*;
	private import ISQ::*;

	package Definitions {
		attribute def PressureValue :> Real;
		attribute def TemperatureValue :> Real;
		attribute def GasConcentrationValue :> Real;
		attribute def BrightnessValue :> Real;
		attribute def VolumeValue :> Real;
		attribute def FrequencyValue :> Real;

		attribute def WarningSignal;
		attribute def CriticalSignal;
		attribute def EmergencySignal;
		attribute def NormalSignal;
		attribute def ResetSignal;

		port def PressureDataOut { out pressure : PressureValue; }
		port def TemperatureDataOut { out temperature : TemperatureValue; }
		port def GasDataOut { out concentration : GasConcentrationValue; }
		port def PressureDataIn { in pressure : PressureValue; }
		port def TemperatureDataIn { in temperature : TemperatureValue; }
		port def GasDataIn { in concentration : GasConcentrationValue; }

		state def ControllerStates;
		state def AlarmStates;
		state def ShutdownStates;

		action def MeasurePressure { out pressure : PressureValue; }
		action def MeasureTemperature { out temperature : TemperatureValue; }
		action def MeasureGasConcentration { out concentration : GasConcentrationValue; }
		action def ActivateAlarm {
			in brightness : BrightnessValue;
			in volume : VolumeValue;
			in frequency : FrequencyValue;
		}
		action def DeactivateAlarm;
		action def InitiateShutdown;
		action def RestoreSystems;

		part def PressureSensor {
			attribute warningThreshold : PressureValue = 80.0;
			attribute criticalThreshold : PressureValue = 120.0;
			port dataOut : PressureDataOut;
			perform action measurePressure : MeasurePressure;
		}

		part def TemperatureSensor {
			attribute warningThreshold : TemperatureValue = 90.0;
			attribute criticalThreshold : TemperatureValue = 130.0;
			port dataOut : TemperatureDataOut;
			perform action measureTemperature : MeasureTemperature;
		}

		part def GasSensor {
			attribute warningThreshold : GasConcentrationValue = 30.0;
			attribute criticalThreshold : GasConcentrationValue = 60.0;
			port dataOut : GasDataOut;
			perform action measureGasConcentration : MeasureGasConcentration;
		}

		part def AlarmSystem {
			perform action activateAlarm : ActivateAlarm;
			perform action deactivateAlarm : DeactivateAlarm;
			exhibit state alarmStates : AlarmStates {
				entry; then idle;
				state idle;
				accept WarningSignal
					do activateAlarm { in brightness = 0.5; in volume = 40.0; in frequency = 800.0; }
					then active;
				state active;
				accept CriticalSignal
					do activateAlarm { in brightness = 0.8; in volume = 80.0; in frequency = 1000.0; }
					then active;
				accept EmergencySignal
					do activateAlarm { in brightness = 1.0; in volume = 120.0; in frequency = 1200.0; }
					then active;
				accept NormalSignal
					do deactivateAlarm
					then idle;
			}
		}

		part def EmergencyShutdown {
			perform action initiateShutdown : InitiateShutdown;
			perform action restoreSystems : RestoreSystems;
			exhibit state shutdownStates : ShutdownStates {
				entry; then standby;
				state standby;
				accept EmergencySignal
					do initiateShutdown
					then engaged;
				state engaged;
				accept ResetSignal
					do restoreSystems
					then standby;
			}
		}

		part def SafetyController {
			attribute warningPressure : PressureValue = 80.0;
			attribute criticalPressure : PressureValue = 120.0;
			attribute emergencyPressure : PressureValue = 150.0;
			attribute warningTemperature : TemperatureValue = 90.0;
			attribute criticalTemperature : TemperatureValue = 130.0;
			attribute emergencyTemperature : TemperatureValue = 160.0;
			attribute warningGasConcentration : GasConcentrationValue = 30.0;
			attribute criticalGasConcentration : GasConcentrationValue = 60.0;
			attribute emergencyGasConcentration : GasConcentrationValue = 80.0;

			port pressureIn : PressureDataIn;
			port temperatureIn : TemperatureDataIn;
			port gasIn : GasDataIn;

			part alarmSystem : AlarmSystem;
			part emergencyShutdown : EmergencyShutdown;

			exhibit state controllerStates : ControllerStates {
				entry; then normal;
				state normal {
					entry action clearAlarm { send new NormalSignal() to alarmSystem; }
				}
				accept when pressureIn.pressure > warningPressure
					or temperatureIn.temperature > warningTemperature
					or gasIn.concentration > warningGasConcentration
					then warning;
				state warning {
					entry action alertWarning { send new WarningSignal() to alarmSystem; }
				}
				accept when pressureIn.pressure > criticalPressure
					or temperatureIn.temperature > criticalTemperature
					or gasIn.concentration > criticalGasConcentration
					then critical;
				accept when pressureIn.pressure <= warningPressure
					and temperatureIn.temperature <= warningTemperature
					and gasIn.concentration <= warningGasConcentration
					then normal;
				state critical {
					entry action alertCritical { send new CriticalSignal() to alarmSystem; }
				}
				accept when pressureIn.pressure > emergencyPressure
					or temperatureIn.temperature > emergencyTemperature
					or gasIn.concentration > emergencyGasConcentration
					do send new EmergencySignal() to emergencyShutdown
					then emergency;
				accept when pressureIn.pressure <= warningPressure
					and temperatureIn.temperature <= warningTemperature
					and gasIn.concentration <= warningGasConcentration
					then normal;
				state emergency {
					entry action alertEmergency { send new EmergencySignal() to alarmSystem; }
				}
				accept ResetSignal
					do send new ResetSignal() to emergencyShutdown
					then normal;
			}
		}

		requirement def MonitorConditions {
			doc /* The system shall continuously monitor pressure, temperature, and gas concentration. */
		}
		requirement def DetectThresholds {
			doc /* Each sensor shall detect conditions exceeding predefined safety thresholds. */
		}
		requirement def AssessRisk {
			doc /* The controller shall evaluate overall risk level as normal, warning, critical, or emergency. */
		}
		requirement def ActivateAlarmOnWarning {
			doc /* Upon detecting a low-level risk, the controller shall activate the alarm system. */
		}
		requirement def TriggerEmergencyShutdown {
			doc /* Upon severe threats, the system shall automatically trigger emergency shutdown. */
		}
		requirement def FastReliableResponse {
			doc /* The monitoring and response process shall be fast and reliable. */
		}
	}

	public import Definitions::*;

	package Usages {
		private import Definitions::*;

		part industrialSafetySystem {
			part safetyController : SafetyController;
			part pressureSensor1 : PressureSensor;
			part temperatureSensor1 : TemperatureSensor;
			part gasSensor1 : GasSensor;

			connect pressureSensor1.dataOut to safetyController.pressureIn;
			connect temperatureSensor1.dataOut to safetyController.temperatureIn;
			connect gasSensor1.dataOut to safetyController.gasIn;
		}

		requirement monitorConditions : MonitorConditions;
		requirement detectThresholds : DetectThresholds;
		requirement assessRisk : AssessRisk;
		requirement activateAlarmOnWarning : ActivateAlarmOnWarning;
		requirement triggerEmergencyShutdown : TriggerEmergencyShutdown;
		requirement fastReliableResponse : FastReliableResponse;

		satisfy monitorConditions by industrialSafetySystem.pressureSensor1;
		satisfy monitorConditions by industrialSafetySystem.temperatureSensor1;
		satisfy monitorConditions by industrialSafetySystem.gasSensor1;
		satisfy detectThresholds by industrialSafetySystem.pressureSensor1;
		satisfy detectThresholds by industrialSafetySystem.temperatureSensor1;
		satisfy detectThresholds by industrialSafetySystem.gasSensor1;
		satisfy assessRisk by industrialSafetySystem.safetyController;
		satisfy activateAlarmOnWarning by industrialSafetySystem.safetyController;
		satisfy triggerEmergencyShutdown by industrialSafetySystem.safetyController;
		satisfy fastReliableResponse by industrialSafetySystem.safetyController;
	}
}
