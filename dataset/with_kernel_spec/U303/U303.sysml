package MedradContrastInjectionSystem {
	private import ScalarValues::*;
	private import ISQ::*;

	public import Definitions::*;

	package Definitions {
		private import ScalarValues::*;
		private import ISQ::*;

		attribute def PressureValue :> ISQ::PressureValue;
		attribute def FlowRateValue :> ISQ::VolumeFlowRateValue;
		attribute def VolumeValue :> ISQ::VolumeValue;
		attribute def DurationValue :> ISQ::DurationValue;

		item def ContrastMedia;
		item def Saline;

		attribute def PowerOnSignal;
		attribute def PowerOffSignal;
		attribute def LoadSyringesCmd;
		attribute def PrimeCmd;
		attribute def ArmCmd;
		attribute def StartInjectionSignal;
		attribute def PauseSignal;
		attribute def ResumeSignal;
		attribute def StopSignal;
		attribute def EmergencyStopSignal;
		attribute def FaultSignal;
		attribute def AlarmSignal;
		attribute def DeliveryCompleteSignal;
		attribute def ResetSignal;
		attribute def OverPressureAlarm;
		attribute def OverFlowAlarm;
		attribute def OverVolumeAlarm;
		attribute def SafetyChecksPassed;

		port def FluidPort {
			out contrast : ContrastMedia;
			out saline : Saline;
		}
		port def ControlPort {
			in command;
			out status;
		}
		port def SensorPort {
			out pressure : PressureValue;
			out flowRate : FlowRateValue;
			out volume : VolumeValue;
		}
		port def AlarmPort {
			out alarm : AlarmSignal;
		}

		part def PressureJacket {
			attribute maxPressure : PressureValue;
		}

		part def Syringe {
			attribute capacity : VolumeValue;
			attribute currentVolume : VolumeValue;
			port fluidOut : FluidPort;
		}

		part def Motor {
			port controlIn : ControlPort;
			port statusOut : ControlPort;
		}

		part def InjectorHead {
			part syringe : Syringe;
			part jacket : PressureJacket;
			part motor : Motor;
			port controlIn : ControlPort;
			port fluidOut : FluidPort;
		}

		part def DualHeadInjector {
			part contrastHead : InjectorHead;
			part salineHead : InjectorHead;
			port controlIn : ControlPort;
			port fluidOut : FluidPort;

			connect contrastHead.fluidOut to fluidOut;
			connect salineHead.fluidOut to fluidOut;
		}

		part def Sensor {
			port sensorOut : SensorPort;
		}

		part def SafetyInterlockSystem {
			port sensorIn : SensorPort;
			port controlOut : ControlPort;
			port alarmOut : AlarmPort;
			attribute pressureLimit : PressureValue;
			attribute flowRateLimit : FlowRateValue;
			attribute volumeLimit : VolumeValue;
			attribute safetyReady : Boolean;
		}

		part def OperatorConsole {
			port controlOut : ControlPort;
			port sensorIn : SensorPort;
			attribute protocolFlowRate : FlowRateValue;
			attribute protocolVolume : VolumeValue;
			attribute protocolDuration : DurationValue;
		}

		part def AlarmIndicator {
			port alarmIn : AlarmPort;
		}

		part def MedradContrastInjector {
			part injector : DualHeadInjector;
			part console : OperatorConsole;
			part safetySystem : SafetyInterlockSystem;
			part pressureSensor : Sensor;
			part flowRateSensor : Sensor;
			part volumeSensor : Sensor;
			part alarm : AlarmIndicator;

			connect console.controlOut to injector.controlIn;
			connect safetySystem.controlOut to injector.controlIn;
			connect pressureSensor.sensorOut to safetySystem.sensorIn;
			connect flowRateSensor.sensorOut to safetySystem.sensorIn;
			connect volumeSensor.sensorOut to safetySystem.sensorIn;
			connect safetySystem.sensorIn to console.sensorIn;
			connect safetySystem.alarmOut to alarm.alarmIn;

			exhibit state 'injection states': 'Injection States';
			exhibit state 'safety states': 'Safety States';
		}

		action def LoadSyringes;
		action def PrimeLines;
		action def ArmSystem;
		action def ExecuteProtocol;
		action def MonitorParameters {
			out pressure : PressureValue;
			out flowRate : FlowRateValue;
			out volume : VolumeValue;
		}
		action def PauseInjection;
		action def ResumeInjection;
		action def LogData;
		action def TriggerAlarm;
		action def EmergencyStop;

		state def 'Injection States';
		state def 'Safety States';

		requirement def FlowRateAccuracy {
			doc "The delivered flow rate shall be within 5 percent of the programmed value."
			attribute programmedFlowRate : FlowRateValue;
			attribute actualFlowRate : FlowRateValue;
		}
		requirement def PressureSafetyLimit {
			doc "The system shall stop injection if fluid pressure exceeds the preset safety limit."
			attribute maximumPressure : PressureValue;
		}
		requirement def AirPurgeRequirement {
			doc "The system shall purge all air from the fluid lines before injection begins."
			attribute isAirPurged : Boolean;
		}
		requirement def EmergencyStopRequirement {
			doc "The operator shall be able to initiate an emergency stop that halts injection immediately."
		}
		requirement def DualHeadPrecision {
			doc "Each injector head shall independently control plunger movement to deliver exact flow rates and volumes."
		}
	}

	package Usages {
		private import Definitions::*;

		part medradSystem : MedradContrastInjector;

		action 'load syringes' : LoadSyringes;
		action 'prime lines' : PrimeLines;
		action 'arm system' : ArmSystem;
		action 'execute protocol' : ExecuteProtocol;
		action 'monitor parameters' : MonitorParameters;
		action 'pause injection' : PauseInjection;
		action 'resume injection' : ResumeInjection;
		action 'log data' : LogData;
		action 'trigger alarm' : TriggerAlarm;
		action 'emergency stop' : EmergencyStop;

		state 'injection states': 'Injection States' {
			entry; then powerOff;

			state powerOff;
			accept PowerOnSignal then idle;

			state idle;
			accept LoadSyringesCmd do 'load syringes' then loaded;

			state loaded;
			accept PrimeCmd do 'prime lines' then priming;

			state priming {
				entry 'prime lines';
			}
			accept PrimeCmd then primed;

			state primed;
			accept ArmCmd do 'arm system' then armed;

			state armed;
			accept StartInjectionSignal
				if medradSystem.safetySystem.safetyReady
				do 'execute protocol'
				then injecting;

			state injecting {
				entry 'execute protocol';
				do 'execute protocol';
			}
			accept DeliveryCompleteSignal then completed;
			accept PauseSignal do 'pause injection' then paused;
			accept FaultSignal then fault;
			accept EmergencyStopSignal do 'emergency stop' then emergencyStopped;

			state paused;
			accept ResumeSignal do 'resume injection' then injecting;
			accept StopSignal then completed;
			accept EmergencyStopSignal do 'emergency stop' then emergencyStopped;

			state completed {
				entry 'log data';
			}
			accept ResetSignal then idle;
			accept PowerOffSignal then powerOff;

			state fault {
				entry 'trigger alarm';
			}
			accept ResetSignal then idle;

			state emergencyStopped {
				entry 'emergency stop';
			}
			accept ResetSignal then idle;
		}

		state 'safety states': 'Safety States' {
			entry; then monitoring;

			state monitoring {
				do 'monitor parameters' { out pressure; out flowRate; out volume; }
			}
			accept when 'monitor parameters'.pressure > medradSystem.safetySystem.pressureLimit
				do send new OverPressureAlarm() to medradSystem.safetySystem
				then alarm;
			accept when 'monitor parameters'.flowRate > medradSystem.safetySystem.flowRateLimit
				do send new OverFlowAlarm() to medradSystem.safetySystem
				then alarm;
			accept when 'monitor parameters'.volume > medradSystem.safetySystem.volumeLimit
				do send new OverVolumeAlarm() to medradSystem.safetySystem
				then alarm;

			state alarm {
				entry 'trigger alarm';
			}
			accept ResetSignal then monitoring;
		}

		requirement flowRateAccuracyReq : FlowRateAccuracy;
		requirement pressureSafetyLimitReq : PressureSafetyLimit;
		requirement airPurgeReq : AirPurgeRequirement;
		requirement emergencyStopReq : EmergencyStopRequirement;
		requirement dualHeadPrecisionReq : DualHeadPrecision;

		satisfy flowRateAccuracyReq by medradSystem;
		satisfy pressureSafetyLimitReq by medradSystem.safetySystem;
		satisfy airPurgeReq by medradSystem.injector;
		satisfy emergencyStopReq by medradSystem;
		satisfy dualHeadPrecisionReq by medradSystem.injector;
	}
}
