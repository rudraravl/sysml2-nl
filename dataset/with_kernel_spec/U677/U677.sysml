package FlameDetectionSuppressionSystem {
	private import ScalarValues::*;
	private import ISQ::*;

	attribute def IRReading {
		doc /* Infrared radiation intensity in W/m^2 */
		attribute magnitude : Real;
	}
	attribute def UVReading {
		doc /* Ultraviolet radiation intensity in W/m^2 */
		attribute magnitude : Real;
	}
	attribute def TempReading {
		doc /* Ambient temperature in Kelvin */
		attribute magnitude : Real;
	}
	attribute def AlarmTrigger;
	attribute def SuppressTrigger;
	attribute def ResetSignal;
	attribute def Tick;

	port def IRPort {
		out reading : IRReading;
	}
	port def UVPort {
		out reading : UVReading;
	}
	port def TempPort {
		out reading : TempReading;
	}
	port def ProcessorIRPort {
		in reading : IRReading;
	}
	port def ProcessorUVPort {
		in reading : UVReading;
	}
	port def ProcessorTempPort {
		in reading : TempReading;
	}
	port def AlarmCmdPort {
		out cmd : AlarmTrigger;
	}
	port def SuppressCmdPort {
		out cmd : SuppressTrigger;
	}
	port def AlarmRcvPort {
		in cmd : AlarmTrigger;
	}
	port def SuppressRcvPort {
		in cmd : SuppressTrigger;
	}

	action def SoundSiren;
	action def FlashLights;
	action def DeployAgent;
	action def ActivateAlarm {
		first start;
		then action soundSiren : SoundSiren;
		then action flashLights : FlashLights;
	}

	part def IRSensor {
		port irOut : IRPort;
		attribute currentReading : Real = 45.0;
		exhibit state sensorState {
			entry; then active;
			state active;
			accept 'Tick'
				do send new IRReading(currentReading) via irOut
				then active;
		}
	}

	part def UVSensor {
		port uvOut : UVPort;
		attribute currentReading : Real = 15.0;
		exhibit state sensorState {
			entry; then active;
			state active;
			accept 'Tick'
				do send new UVReading(currentReading) via uvOut
				then active;
		}
	}

	part def ThermalSensor {
		port tempOut : TempPort;
		attribute currentReading : Real = 25.0;
		exhibit state sensorState {
			entry; then active;
			state active;
			accept 'Tick'
				do send new TempReading(currentReading) via tempOut
				then active;
		}
	}

	part def SignalProcessor {
		port irIn : ProcessorIRPort;
		port uvIn : ProcessorUVPort;
		port tempIn : ProcessorTempPort;
		port alarmOut : AlarmCmdPort;
		port suppressOut : SuppressCmdPort;

		attribute irThreshold : Real = 50.0;
		attribute uvThreshold : Real = 20.0;
		attribute tempThreshold : Real = 60.0;

		exhibit state processorState {
			entry; then monitoring;
			state monitoring;
			transition ir_exceed
				first monitoring
				accept ir: IRReading via irIn
				if ir.magnitude > irThreshold
				do action {
					first start;
					then send new AlarmTrigger() via alarmOut;
					then send new SuppressTrigger() via suppressOut;
				}
				then alerting;
			transition uv_exceed
				first monitoring
				accept uv: UVReading via uvIn
				if uv.magnitude > uvThreshold
				do action {
					first start;
					then send new AlarmTrigger() via alarmOut;
					then send new SuppressTrigger() via suppressOut;
				}
				then alerting;
			transition temp_exceed
				first monitoring
				accept temp: TempReading via tempIn
				if temp.magnitude > tempThreshold
				do action {
					first start;
					then send new AlarmTrigger() via alarmOut;
					then send new SuppressTrigger() via suppressOut;
				}
				then alerting;
			state alerting;
			accept reset: ResetSignal
				then monitoring;
		}
	}

	part def AlarmDevice {
		port alarmIn : AlarmRcvPort;
		action soundSiren : SoundSiren;
		action flashLights : FlashLights;
		exhibit state alarmState {
			entry; then idle;
			state idle;
			accept cmd: AlarmTrigger via alarmIn
				then active;
			state active {
				do action activateAlarm : ActivateAlarm;
			}
			accept reset: ResetSignal
				then idle;
		}
	}

	part def SuppressionActuator {
		port suppressIn : SuppressRcvPort;
		action deployAgent : DeployAgent;
		attribute agentType : String = "FM-200";
		exhibit state actuatorState {
			entry; then idle;
			state idle;
			accept cmd: SuppressTrigger via suppressIn
				then deployed;
			state deployed {
				do deployAgent;
			}
			accept reset: ResetSignal
				then idle;
		}
	}

	part def FlameDetectionSystem {
		part irSensor : IRSensor;
		part uvSensor : UVSensor;
		part thermalSensor : ThermalSensor;
		part processor : SignalProcessor;
		part alarm : AlarmDevice;
		part actuator : SuppressionActuator;

		connect irSensor.irOut to processor.irIn;
		connect uvSensor.uvOut to processor.uvIn;
		connect thermalSensor.tempOut to processor.tempIn;
		connect processor.alarmOut to alarm.alarmIn;
		connect processor.suppressOut to actuator.suppressIn;
	}

	requirement def MultiSensorDetection {
		doc /* The system shall utilize IR, UV, and Thermal sensors to continuously monitor the environment for fire indicators. */
		subject : FlameDetectionSystem;
	}
	requirement def RealTimeThresholdComparison {
		doc /* The Signal Processor shall compare incoming sensor data against pre-set safety thresholds in real-time. */
		subject : SignalProcessor;
		attribute irLimit : Real = 50.0;
		attribute uvLimit : Real = 20.0;
		attribute tempLimit : Real = 60.0;
	}
	requirement def AutomaticEmergencyResponse {
		doc /* Upon detecting a fire, the system shall automatically trigger the Alarm Device and Suppression Actuator without human intervention. */
		subject : FlameDetectionSystem;
	}
	requirement def AlarmAudibility {
		doc /* The Alarm Device shall provide a high-decibel siren and intense flashing lights to alert personnel. */
		subject : AlarmDevice;
		attribute minSirenDecibels : Real = 110.0;
	}
	requirement def SuppressionAgentDeployment {
		doc /* The Suppression Actuator shall deploy a fire-fighting agent to control or extinguish the blaze. */
		subject : SuppressionActuator;
		attribute coverageArea : Real = 100.0;
	}

	part system : FlameDetectionSystem;
}
