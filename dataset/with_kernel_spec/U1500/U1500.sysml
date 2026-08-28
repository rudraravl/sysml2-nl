package 'Slug Flow Control System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	item def PressureMeasurement {
		attribute value : ISQ::PressureValue;
		attribute timestamp : ISQ::TimeValue;
	}
	item def VoidFractionMeasurement {
		attribute value : Real;
		attribute timestamp : ISQ::TimeValue;
	}
	item def ValveCommand {
		attribute opening : Real;
	}
	item def AlarmSignal {
		attribute level : String;
		attribute description : String;
	}
	item def ShutdownSignal;

	enum def FlowRegime {
		normal;
		bubbly;
		slug;
	}

	port def PressureOutPort {
		out pressure : PressureMeasurement;
	}
	port def PressureInPort {
		in pressure : PressureMeasurement;
	}
	port def VoidFractionOutPort {
		out voidFraction : VoidFractionMeasurement;
	}
	port def VoidFractionInPort {
		in voidFraction : VoidFractionMeasurement;
	}
	port def ValveCommandOutPort {
		out command : ValveCommand;
	}
	port def ValveCommandInPort {
		in command : ValveCommand;
	}
	port def AlarmOutPort {
		out alarm : AlarmSignal;
	}
	port def AlarmInPort {
		in alarm : AlarmSignal;
	}
	port def ShutdownOutPort {
		out shutdown : ShutdownSignal;
	}
	port def ShutdownInPort {
		in shutdown : ShutdownSignal;
	}
	port def TwoPhaseFlowPort;

	action def AnalyzeFlowRegime {
		in pressure : PressureMeasurement;
		in voidFraction : VoidFractionMeasurement;
		out regime : FlowRegime;
		out slugFrequency : ISQ::FrequencyValue;
		out slugSeverity : Real;
	}
	action def CalculateBackPressure {
		in severity : Real;
		in frequency : ISQ::FrequencyValue;
		out opening : Real;
	}
	action def AdjustValve {
		in opening : Real;
		out command : ValveCommand;
	}
	action def SendAlarm {
		out alarm : AlarmSignal;
	}
	action def EmergencyShutdownAction {
		out valveCommand : ValveCommand;
		out shutdownSignal : ShutdownSignal;
	}

	part def PressureTransducer {
		port pressureOut : PressureOutPort;
		action measurePressure {
			out pressure : PressureMeasurement;
		}
	}

	part def VoidFractionMeter {
		port voidFractionOut : VoidFractionOutPort;
		action measureVoidFraction {
			out voidFraction : VoidFractionMeasurement;
		}
	}

	part def ThrottleValve {
		port commandIn : ValveCommandInPort;
		attribute currentOpening : Real = 100;
		action adjust {
			in command : ValveCommand;
		}
	}

	part def SlugCatcher {
		attribute capacity : ISQ::VolumeValue;
		port inlet : TwoPhaseFlowPort;
		port gasOutlet : TwoPhaseFlowPort;
		port liquidOutlet : TwoPhaseFlowPort;
		action absorbMomentum;
		action separatePhases;
	}

	part def Pipeline {
		attribute length : ISQ::LengthValue;
		attribute diameter : ISQ::LengthValue;
		port inlet : TwoPhaseFlowPort;
		port outlet : TwoPhaseFlowPort;
		part throttleValve : ThrottleValve;
	}

	part def AlarmSystem {
		port alarmIn : AlarmInPort;
		action triggerAlarm { in alarm : AlarmSignal; }
	}

	part def ShutdownSystem {
		port shutdownIn : ShutdownInPort;
		action initiateShutdown { in shutdown : ShutdownSignal; }
	}

	state def ControllerStates;

	part def Controller {
		port pressureIn : PressureInPort;
		port voidFractionIn : VoidFractionInPort;
		port valveCommandOut : ValveCommandOutPort;
		port alarmOut : AlarmOutPort;
		port shutdownOut : ShutdownOutPort;

		attribute frequencyThreshold : ISQ::FrequencyValue = 0.5 [SI::Hz];
		attribute severityAlarmThreshold : Real = 0.8;
		attribute severityShutdownThreshold : Real = 0.95;

		action analyzeFlow : AnalyzeFlowRegime;

		exhibit state controllerStates : ControllerStates {
			entry; then NormalMonitoring;

			do analyzeFlow {
				in pressure = pressureIn.pressure;
				in voidFraction = voidFractionIn.voidFraction;
				out regime;
				out slugFrequency;
				out slugSeverity;
			}

			state NormalMonitoring;

			accept when analyzeFlow.slugFrequency > frequencyThreshold
				then ActiveSlugMitigation;

			state ActiveSlugMitigation {
				entry action calculateBackPressure : CalculateBackPressure {
					in severity = analyzeFlow.slugSeverity;
					in frequency = analyzeFlow.slugFrequency;
					out opening;
				}
				do action adjustValve : AdjustValve {
					in opening = calculateBackPressure.opening;
					out command;
				}
			}

			accept when analyzeFlow.slugSeverity > severityAlarmThreshold
				then AlarmState;

			accept when analyzeFlow.slugSeverity > severityShutdownThreshold
				then EmergencyShutdown;

			accept when analyzeFlow.slugFrequency < frequencyThreshold
				then NormalMonitoring;

			state AlarmState {
				entry action sendAlarm : SendAlarm {
					out alarm;
				}
			}

			accept when analyzeFlow.slugSeverity > severityShutdownThreshold
				then EmergencyShutdown;

			accept when analyzeFlow.slugFrequency < frequencyThreshold
				then NormalMonitoring;

			state EmergencyShutdown {
				entry action emergencyShutdown : EmergencyShutdownAction {
					out valveCommand;
					out shutdownSignal;
				}
			}
		}
	}

	part slugFlowControlSystem {
		part pipeline : Pipeline {
			:>> length = 1000 [SI::m];
			:>> diameter = 0.5 [SI::m];
		}
		part pressureTransducer : PressureTransducer;
		part voidFractionMeter : VoidFractionMeter;
		part controller : Controller;
		part slugCatcher : SlugCatcher {
			:>> capacity = 50 [SI::m^3];
		}
		part alarmSystem : AlarmSystem;
		part shutdownSystem : ShutdownSystem;

		flow pressureFlow of PressureMeasurement
			from pressureTransducer.pressureOut.pressure to controller.pressureIn.pressure;

		flow voidFractionFlow of VoidFractionMeasurement
			from voidFractionMeter.voidFractionOut.voidFraction to controller.voidFractionIn.voidFraction;

		flow valveCommandFlow of ValveCommand
			from controller.valveCommandOut.command to pipeline.throttleValve.commandIn.command;

		flow alarmFlow of AlarmSignal
			from controller.alarmOut.alarm to alarmSystem.alarmIn.alarm;

		flow shutdownFlow of ShutdownSignal
			from controller.shutdownOut.shutdown to shutdownSystem.shutdownIn.shutdown;

		connect pipeline.outlet to slugCatcher.inlet;
	}

	requirement def SlugDetectionRequirement {
		doc /* The system shall detect slug flow formation when slug frequency exceeds 0.5 Hz and classify the flow regime as normal, bubbly, or slug. */
		satisfy :>> Controller;
	}

	requirement def SlugMitigationRequirement {
		doc /* The system shall automatically adjust the throttle valve opening to manipulate back-pressure and reduce slug severity when slug flow is detected. */
		satisfy :>> Controller;
	}

	requirement def AlarmRequirement {
		doc /* The system shall trigger an alarm when slug severity exceeds 0.8. */
		satisfy :>> Controller;
	}

	requirement def EmergencyShutdownRequirement {
		doc /* The system shall initiate emergency shutdown by closing the throttle valve when slug severity exceeds 0.95. */
		satisfy :>> Controller;
	}

	requirement def SlugCatcherRequirement {
		doc /* The slug catcher shall safely absorb the momentum of incoming slugs and separate gas and liquid phases before downstream processing. */
		satisfy :>> SlugCatcher;
	}
}
