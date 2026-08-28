package MedipinesRespiratorySystem {
	private import ScalarValues::*;
	private import ISQ::*;

	unit def mL;
	unit def L_per_min;
	unit def cmH2O;
	unit def mmHg;
	unit def percent;

	attribute def VolumeValue :> ScalarValues::Real;
	attribute def FlowRateValue :> ScalarValues::Real;
	attribute def PressureValue :> ScalarValues::Real;
	attribute def CO2Value :> ScalarValues::Real;
	attribute def FractionValue :> ScalarValues::Real;

	item def Air;
	item def Oxygen;
	item def GasMixture {
		attribute fiO2 : FractionValue;
	}
	item def VentilationSettings {
		attribute breathRate : ScalarValues::Real;
		attribute tidalVolume : VolumeValue;
		attribute targetFiO2 : FractionValue;
		attribute maxPressure : PressureValue;
	}
	item def ValveCommand {
		attribute position : ScalarValues::Real;
	}
	item def AlarmEvent {
		attribute alarmMessage : String;
		attribute severity : String;
	}

	attribute def PowerOn;
	attribute def PowerOff;
	attribute def Activate;
	attribute def Deactivate;
	attribute def SelfTestPassed;
	attribute def SelfTestFailed;
	attribute def InspirationComplete;
	attribute def ExpirationComplete;
	attribute def FaultDetected;
	attribute def FaultReset;

	action def PerformSelfTest;
	action def Inspire;
	action def Expire;

	action runSelfTest : PerformSelfTest;
	action inspire : Inspire;
	action expire : Expire;

	part def OxygenBlender {
		port airIn { in air : Air; }
		port oxygenIn { in oxygen : Oxygen; }
		port mixtureOut { out mixture : GasMixture; }
		port controlIn { in command : ValveCommand; }
	}
	part def Valve {
		port gasIn { in gas : GasMixture; }
		port gasOut { out gas : GasMixture; }
		port controlIn { in command : ValveCommand; }
	}
	part def PatientCircuit {
		port inspiratoryIn { in gas : GasMixture; }
		port patientPort { in out gas : GasMixture; }
		port expiratoryOut { out gas : GasMixture; }
	}
	part def FlowSensor {
		port gasIn { in gas : GasMixture; }
		port gasOut { out gas : GasMixture; }
		port flowOut { out flow : FlowRateValue; }
	}
	part def PressureSensor {
		port gasIn { in gas : GasMixture; }
		port pressureOut { out pressure : PressureValue; }
	}
	part def CO2Monitor {
		port gasIn { in gas : GasMixture; }
		port gasOut { out gas : GasMixture; }
		port co2Out { out co2 : CO2Value; }
	}
	part def UserInterface {
		port settingsOut { out settings : VentilationSettings; }
		port alarmIn { in alarm : AlarmEvent; }
	}
	part def AlarmSystem {
		port pressureIn { in pressure : PressureValue; }
		port alarmOut { out alarm : AlarmEvent; }
	}

	state def VentilatorStates;

	state 'ventilator states' : VentilatorStates {
		entry; then initializing;
		state initializing {
			entry runSelfTest;
			accept SelfTestPassed then standby;
			accept SelfTestFailed then fault;
		}
		state standby;
		accept Activate then ventilating;
		state ventilating {
			entry; then inspiring;
			state inspiring {
				entry inspire;
				accept ExpirationComplete then expiring;
			}
			state expiring {
				entry expire;
				accept InspirationComplete then inspiring;
			}
			accept Deactivate then standby;
			accept FaultDetected then fault;
		}
		state fault {
			accept FaultReset then standby;
		}
	}

	part def ControlProcessor {
		port settingsIn { in settings : VentilationSettings; }
		port inspFlowIn { in flow : FlowRateValue; }
		port expFlowIn { in flow : FlowRateValue; }
		port airwayPressureIn { in pressure : PressureValue; }
		port co2In { in co2 : CO2Value; }
		port inspValveControlOut { out command : ValveCommand; }
		port expValveControlOut { out command : ValveCommand; }
		port blenderControlOut { out command : ValveCommand; }
		attribute currentSettings : VentilationSettings;
		exhibit state 'ventilator states' : VentilatorStates;
	}

	requirement def SafePressureLimit {
		doc /* The system shall monitor airway pressure and trigger an alarm if it exceeds 40 cmH2O. */
		attribute maxLimit : PressureValue;
	}
	requirement def AccurateFiO2 {
		doc /* The oxygen blender shall maintain FiO2 within 2% of target. */
	}
	requirement def TidalVolumeAccuracy {
		doc /* The system shall deliver the set tidal volume within 10%. */
	}

	part def MedipinesVentilator {
		port airSupply { in air : Air; }
		port oxygenSupply { in oxygen : Oxygen; }
		port exhaust { out gas : GasMixture; }

		part oxygenBlender : OxygenBlender;
		part inspiratoryValve : Valve;
		part patientCircuit : PatientCircuit;
		part expiratoryValve : Valve;
		part inspiratoryFlowSensor : FlowSensor;
		part airwayPressureSensor : PressureSensor;
		part expiratoryFlowSensor : FlowSensor;
		part co2Monitor : CO2Monitor;
		part controlProcessor : ControlProcessor;
		part userInterface : UserInterface;
		part alarmSystem : AlarmSystem;

		flow airToBlender of Air from airSupply.air to oxygenBlender.airIn.air;
		flow o2ToBlender of Oxygen from oxygenSupply.oxygen to oxygenBlender.oxygenIn.oxygen;
		flow blendedToInspValve of GasMixture from oxygenBlender.mixtureOut.mixture to inspiratoryValve.gasIn.gas;
		flow inspValveToFlowSensor of GasMixture from inspiratoryValve.gasOut.gas to inspiratoryFlowSensor.gasIn.gas;
		flow inspFlowToCircuit of GasMixture from inspiratoryFlowSensor.gasOut.gas to patientCircuit.inspiratoryIn.gas;
		flow circuitToExpValve of GasMixture from patientCircuit.expiratoryOut.gas to expiratoryValve.gasIn.gas;
		flow expValveToExpFlowSensor of GasMixture from expiratoryValve.gasOut.gas to expiratoryFlowSensor.gasIn.gas;
		flow expFlowToCO2 of GasMixture from expiratoryFlowSensor.gasOut.gas to co2Monitor.gasIn.gas;
		flow co2ToExhaust of GasMixture from co2Monitor.gasOut.gas to exhaust.gas;

		flow pressureSample of GasMixture from patientCircuit.patientPort.gas to airwayPressureSensor.gasIn.gas;

		flow inspFlowData of FlowRateValue from inspiratoryFlowSensor.flowOut.flow to controlProcessor.inspFlowIn.flow;
		flow expFlowData of FlowRateValue from expiratoryFlowSensor.flowOut.flow to controlProcessor.expFlowIn.flow;
		flow airwayPressureData of PressureValue from airwayPressureSensor.pressureOut.pressure to controlProcessor.airwayPressureIn.pressure;
		flow co2Data of CO2Value from co2Monitor.co2Out.co2 to controlProcessor.co2In.co2;

		flow inspValveCmd of ValveCommand from controlProcessor.inspValveControlOut.command to inspiratoryValve.controlIn.command;
		flow expValveCmd of ValveCommand from controlProcessor.expValveControlOut.command to expiratoryValve.controlIn.command;
		flow blenderCmd of ValveCommand from controlProcessor.blenderControlOut.command to oxygenBlender.controlIn.command;

		flow settingsToCpu of VentilationSettings from userInterface.settingsOut.settings to controlProcessor.settingsIn.settings;
		flow pressureToAlarm of PressureValue from airwayPressureSensor.pressureOut.pressure to alarmSystem.pressureIn.pressure;
		flow alarmToUi of AlarmEvent from alarmSystem.alarmOut.alarm to userInterface.alarmIn.alarm;

		requirement safePressureLimit : SafePressureLimit;
		requirement accurateFiO2 : AccurateFiO2;
		requirement tidalVolumeAccuracy : TidalVolumeAccuracy;

		satisfy safePressureLimit by alarmSystem;
		satisfy accurateFiO2 by oxygenBlender;
		satisfy tidalVolumeAccuracy by controlProcessor;
	}
}
