package 'S-ICD System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import ISQElectromagnetism::*;

	item def CardiacSignal;
	item def FilteredSignal;
	enum def RhythmType { normal; ventricularFibrillation; ventricularTachycardia; }
	item def ShockDecision;
	item def HighVoltagePulse;

	attribute def ArrhythmiaDetected;
	attribute def ArrhythmiaConfirmed;
	attribute def ArrhythmiaRejected;
	attribute def CapacitorCharged;
	attribute def RhythmRestored;
	attribute def RhythmNotRestored;
	attribute def StartChargingSignal;

	port def SignalOutPort { out signal : CardiacSignal; }
	port def FilteredSignalOutPort { out signal : FilteredSignal; }
	port def RhythmOutPort { out rhythm : RhythmType; }
	port def DecisionOutPort { out decision : ShockDecision; }
	port def PowerOutPort { out voltage : ElectricPotentialValue; }
	port def HVOutPort { out charge : ElectricChargeValue; }
	port def ControlPort { out command : StartChargingSignal; }
	port def PulseOutPort { out pulse : HighVoltagePulse; }

	action def MonitorHeart { in rawSignal : CardiacSignal; out cardiacSignal : CardiacSignal; }
	action def ProcessSignal { in rawSignal : CardiacSignal; out filteredSignal : FilteredSignal; }
	action def DetectArrhythmia { in signal : FilteredSignal; out rhythm : RhythmType; }
	action def DecideTherapy { in rhythm : RhythmType; out decision : ShockDecision; }
	action def ChargeCapacitor { in power : ElectricPotentialValue; in command : StartChargingSignal; out charge : ElectricChargeValue; }
	action def DeliverShock { in charge : ElectricChargeValue; out pulse : HighVoltagePulse; }
	action def AssessPostShock { in signal : FilteredSignal; out rhythmRestored : Boolean; }
	action def ProcessDecision { in decision : ShockDecision; out command : StartChargingSignal; }

	part def Patient {
		port pulseIn : PulseOutPort;
		port signalOut : SignalOutPort;
	}

	part def SensingElectrode {
		port signalIn : SignalOutPort;
		port signalOut : SignalOutPort;
		perform action monitorHeart : MonitorHeart {
			in rawSignal = signalIn.signal;
			out cardiacSignal = signalOut.signal;
		}
	}

	part def SignalProcessingUnit {
		port signalIn : SignalOutPort;
		port filteredOut : FilteredSignalOutPort;
		perform action processSignal : ProcessSignal {
			in rawSignal = signalIn.signal;
			out filteredSignal = filteredOut.signal;
		}
	}

	part def ArrhythmiaDetectionUnit {
		port filteredIn : FilteredSignalOutPort;
		port rhythmOut : RhythmOutPort;
		perform action detectArrhythmia : DetectArrhythmia {
			in signal = filteredIn.signal;
			out rhythm = rhythmOut.rhythm;
		}
	}

	part def TherapyDecisionUnit {
		port rhythmIn : RhythmOutPort;
		port decisionOut : DecisionOutPort;
		perform action decideTherapy : DecideTherapy {
			in rhythm = rhythmIn.rhythm;
			out decision = decisionOut.decision;
		}
	}

	part def BatteryPack {
		port powerOut : PowerOutPort;
		attribute capacity : ElectricChargeValue = 1 [A*h];
	}

	part def HighVoltageCapacitor {
		port powerIn : PowerOutPort;
		port controlIn : ControlPort;
		port hvOut : HVOutPort;
		perform action chargeCapacitor : ChargeCapacitor {
			in power = powerIn.voltage;
			in command = controlIn.command;
			out charge = hvOut.charge;
		}
	}

	part def DefibrillationElectrode {
		port hvIn : HVOutPort;
		port pulseOut : PulseOutPort;
		perform action deliverShock : DeliverShock {
			in charge = hvIn.charge;
			out pulse = pulseOut.pulse;
		}
	}

	part def ControlProcessor {
		port decisionIn : DecisionOutPort;
		port chargeControlOut : ControlPort;
		perform action processDecision : ProcessDecision {
			in decision = decisionIn.decision;
			out command = chargeControlOut.command;
		}
	}

	part def SICD {
		part patient : Patient;
		part sensingElectrode : SensingElectrode;
		part signalProcessingUnit : SignalProcessingUnit;
		part arrhythmiaDetectionUnit : ArrhythmiaDetectionUnit;
		part therapyDecisionUnit : TherapyDecisionUnit;
		part controlProcessor : ControlProcessor;
		part batteryPack : BatteryPack;
		part highVoltageCapacitor : HighVoltageCapacitor;
		part defibrillationElectrode : DefibrillationElectrode;

		attribute maxTherapyDelay : TimeValue = 10 [s];
		attribute monitoringActive : Boolean = true;

		exhibit state sicdStates {
			entry; then monitoring;
			state monitoring {
				do sensingElectrode.monitorHeart;
			}
			accept ArrhythmiaDetected then detection;
			state detection {
				do arrhythmiaDetectionUnit.detectArrhythmia;
				do therapyDecisionUnit.decideTherapy;
			}
			accept ArrhythmiaConfirmed then charging;
			accept ArrhythmiaRejected then monitoring;
			state charging {
				do highVoltageCapacitor.chargeCapacitor;
			}
			accept CapacitorCharged then therapyDelivery;
			state therapyDelivery {
				do defibrillationElectrode.deliverShock;
			}
			then postShockAssessment;
			state postShockAssessment {
				do action assess : AssessPostShock {
					in signal = signalProcessingUnit.filteredOut.signal;
					out rhythmRestored;
				}
			}
			accept RhythmRestored then monitoring;
			accept RhythmNotRestored then charging;
		}

		connect patient.signalOut to sensingElectrode.signalIn;
		connect sensingElectrode.signalOut to signalProcessingUnit.signalIn;
		connect signalProcessingUnit.filteredOut to arrhythmiaDetectionUnit.filteredIn;
		connect arrhythmiaDetectionUnit.rhythmOut to therapyDecisionUnit.rhythmIn;
		connect therapyDecisionUnit.decisionOut to controlProcessor.decisionIn;
		connect controlProcessor.chargeControlOut to highVoltageCapacitor.controlIn;
		connect batteryPack.powerOut to highVoltageCapacitor.powerIn;
		connect highVoltageCapacitor.hvOut to defibrillationElectrode.hvIn;
		connect defibrillationElectrode.pulseOut to patient.pulseIn;
	}

	requirement def TherapyDeliveryTimeRequirement {
		doc /* The S-ICD must deliver therapy within a specified time frame. */
		attribute maxTime : TimeValue = 10 [s];
		subject sicd : SICD;
		constraint { sicd.maxTherapyDelay <= maxTime }
	}

	requirement def ContinuousMonitoringRequirement {
		doc /* The S-ICD must continuously monitor the heart's electrical activity. */
		subject sicd : SICD;
		constraint { sicd.monitoringActive == true }
	}
}
