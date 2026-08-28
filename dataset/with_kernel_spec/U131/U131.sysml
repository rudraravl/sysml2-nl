package 'Trigeminal Nerve Stimulation System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	package Definitions {
		item def Power;
		item def TherapySettings {
			attribute duration : ISQ::Time;
			attribute intensity : ISQ::ElectricCurrent;
			attribute frequency : ISQ::Frequency;
			attribute mode : String;
		}
		item def StimulationCommand {
			attribute current : ISQ::ElectricCurrent;
			attribute frequency : ISQ::Frequency;
			attribute mode : String;
		}
		item def FeedbackData {
			attribute impedance : ISQ::ElectricResistance;
			attribute potential : ISQ::ElectricPotential;
		}
		item def PowerOnSignal;
		item def PowerOffSignal;
		item def StartTherapySignal;
		item def StopTherapySignal;
		item def UnsafeConditionAlert;

		action def MeasureBaseline;
		action def VerifyConnection;
		action def DeliverStimulation;
		action def SenseFeedback;
		action def AdjustParameters;
		action def ShutdownSystem;

		part def PowerModule {
			part battery;
			port powerOut { out power : Power; }
			attribute batteryLevel : Real;
		}

		part def SignalGenerator {
			port commandPort { in command : StimulationCommand; }
			port signalOut { out signal : StimulationCommand; }
			port powerIn { in power : Power; }
		}

		part def ElectrodeArray {
			port signalIn { in signal : StimulationCommand; }
			port tissueSenseOut { out tissueSense : FeedbackData; }
			attribute contactPoints : Integer = 4;
		}

		part def FeedbackSensor {
			port sensePort { in tissueSense : FeedbackData; }
			port feedbackOut { out feedback : FeedbackData; }
			port powerIn { in power : Power; }
		}

		part def ControlProcessor {
			port settingsPort { in settings : TherapySettings; }
			port controlPort {
				in powerOn : PowerOnSignal;
				in startTherapy : StartTherapySignal;
				in stopTherapy : StopTherapySignal;
				in powerOff : PowerOffSignal;
			}
			port commandPort { out command : StimulationCommand; }
			port feedbackPort { in feedback : FeedbackData; }
			port alertPort { out alert : UnsafeConditionAlert; }
			port powerIn { in power : Power; }

			attribute maxImpedance : ISQ::ElectricResistance = 5000 [SI::Ohm];
			attribute minImpedance : ISQ::ElectricResistance = 100 [SI::Ohm];
			attribute safeNervePotential : ISQ::ElectricPotential = 0.01 [SI::V];

			exhibit state 'Control Processor States' {
				entry; then off;

				state off;
				accept PowerOnSignal via controlPort
					then standby;

				state standby;
				accept StartTherapySignal via controlPort
					then calibrating;

				state calibrating {
					do action measureBaseline { }
				}
				accept after 10 [SI::s]
					then activeTreatment;

				state activeTreatment parallel {
					state stimulating {
						do action deliverStimulation { }
					}
					state monitoring {
						do action senseFeedback { }
					}
				}
				accept feedback : FeedbackData via feedbackPort
					if feedback.impedance > maxImpedance or feedback.impedance < minImpedance or feedback.potential > safeNervePotential
					then fault;

				accept StopTherapySignal via controlPort
					then standby;

				state fault {
					do action shutdownSystem { }
				}
				accept PowerOffSignal via controlPort
					then off;
			}
		}

		part def TrigeminalStimulationSystem {
			part controlProcessor : ControlProcessor;
			part powerModule : PowerModule;
			part signalGenerator : SignalGenerator;
			part electrodeArray : ElectrodeArray;
			part feedbackSensor : FeedbackSensor;

			connection powerToProcessor connect powerModule.powerOut to controlProcessor.powerIn;
			connection powerToGenerator connect powerModule.powerOut to signalGenerator.powerIn;
			connection powerToSensor connect powerModule.powerOut to feedbackSensor.powerIn;

			connection commandConn connect controlProcessor.commandPort to signalGenerator.commandPort;
			connection signalConn connect signalGenerator.signalOut to electrodeArray.signalIn;
			connection senseConn connect electrodeArray.tissueSenseOut to feedbackSensor.sensePort;
			connection feedbackConn connect feedbackSensor.feedbackOut to controlProcessor.feedbackPort;
		}

		requirement def SafetyRequirement {
			doc /* The system must automatically enter a fault state and shut down if tissue impedance exceeds safe thresholds or nerve potential exceeds safe limits. */
			attribute maxImpedance : ISQ::ElectricResistance = 5000 [SI::Ohm];
			attribute minImpedance : ISQ::ElectricResistance = 100 [SI::Ohm];
			attribute safeNervePotential : ISQ::ElectricPotential = 0.01 [SI::V];
		}

		requirement def ClosedLoopRequirement {
			doc /* The system shall continuously monitor neural feedback and adjust stimulation parameters in real-time to maintain optimal therapeutic effect. */
		}

		requirement def CalibrationRequirement {
			doc /* The system shall perform a baseline tissue calibration before initiating active treatment to ensure proper connection. */
		}
	}

	package Usages {
		private import Definitions::*;

		part system : TrigeminalStimulationSystem {
			requirement safetyReq : SafetyRequirement;
			requirement closedLoopReq : ClosedLoopRequirement;
			requirement calibrationReq : CalibrationRequirement;
		}
	}
}
