package 'Penile Clamp Medical Device' {
	private import ISQ::PressureValue;
	private import ISQ::DurationValue;
	private import ISQ::VolumeFlowRateValue;
	private import SI::Pa;
	private import SI::h;
	private import ScalarValues::Integer;

	item def UrineFlow;

	attribute def ActivateSignal;
	attribute def ReleaseSignal;
	attribute def PositionSignal;
	attribute def EmergencyReleaseSignal;

	part def AdjustmentLever {
		attribute currentPosition : Integer := 1;
		attribute targetPressure : PressureValue;
		port positionPort {
			in positionSignal : PositionSignal;
		}
		action setPosition {
			in pos : Integer;
			assign currentPosition := pos;
			assign targetPressure := pos * 7500 [Pa];
		}
	}

	part def CompressionMechanism {
		attribute targetPressure : PressureValue;
		attribute appliedPressure : PressureValue := 0 [Pa];
		port pressurePort {
			out appliedPressureOut : PressureValue;
		}
		action applyCompression {
			assign appliedPressure := targetPressure;
		}
		action releaseCompression {
			assign appliedPressure := 0 [Pa];
		}
	}

	part def PressurePad {
		port pressureInPort {
			in pressureIn : PressureValue;
		}
		port distributedPressurePort {
			out distributedPressure : PressureValue;
		}
	}

	part def FlowSensor {
		port flowInPort {
			in urineFlow : UrineFlow;
		}
		port flowRatePort {
			out flowRate : VolumeFlowRateValue;
		}
		action senseFlow {
			out rate : VolumeFlowRateValue;
		}
	}

	part def SafetyMonitor {
		attribute maxPressure : PressureValue := 45000 [Pa];
		attribute maxDuration : DurationValue := 2 [h];
		attribute currentPressure : PressureValue := 0 [Pa];
		attribute elapsedTime : DurationValue := 0 [h];
		port pressureMonitorPort {
			in pressureReading : PressureValue;
		}
	}

	part def PenileClamp {
		part adjustmentLever : AdjustmentLever;
		part compressionMechanism : CompressionMechanism;
		part pressurePad : PressurePad;
		part flowSensor : FlowSensor;
		part safetyMonitor : SafetyMonitor;

		port userActivatePort {
			in activate : ActivateSignal;
		}
		port userReleasePort {
			in release : ReleaseSignal;
		}
		port userPositionPort {
			in position : PositionSignal;
		}
		port emergencyPort {
			out emergencyRelease : EmergencyReleaseSignal;
		}
		port urineFlowInputPort {
			in urine : UrineFlow;
		}

		flow pressureFlow of PressureValue
			from compressionMechanism.pressurePort.appliedPressureOut to pressurePad.pressureInPort.pressureIn;
		flow distributedPressureFlow of PressureValue
			from pressurePad.distributedPressurePort.distributedPressure to safetyMonitor.pressureMonitorPort.pressureReading;
		flow urineFlowIn of UrineFlow
			from urineFlowInputPort.urine to flowSensor.flowInPort.urineFlow;
	}

	state clampLifecycle {
		in clamp : PenileClamp;
		entry; then idle;

		state idle;
		accept ActivateSignal
			then positioning;

		state positioning {
			entry assign clamp.compressionMechanism.appliedPressure := 0 [Pa];
		}
		accept PositionSignal
			then compressing;

		state compressing {
			entry action achieveTarget {
				assign clamp.compressionMechanism.targetPressure := clamp.adjustmentLever.targetPressure;
				assign clamp.compressionMechanism.appliedPressure := clamp.adjustmentLever.targetPressure;
			}
		}
		accept when clamp.compressionMechanism.appliedPressure >= clamp.compressionMechanism.targetPressure
			then active;

		state active {
			do action maintainAndMonitor {
				assign clamp.compressionMechanism.appliedPressure := clamp.compressionMechanism.targetPressure;
				assign clamp.safetyMonitor.currentPressure := clamp.compressionMechanism.appliedPressure;
			}
		}
		accept ReleaseSignal
			then releasing;
		accept when clamp.safetyMonitor.currentPressure > clamp.safetyMonitor.maxPressure
			then emergency;
		accept after 2 [h]
			then emergency;

		state releasing {
			entry action releaseNormal {
				assign clamp.compressionMechanism.appliedPressure := 0 [Pa];
			}
		}
		then idle;

		state emergency {
			entry action emergencyReleaseAction {
				assign clamp.compressionMechanism.appliedPressure := 0 [Pa];
			}
		}
		then idle;
	}

	requirement safetyPressureReq {
		doc /* The maximum applied pressure shall not exceed 45,000 Pa. */
		subject device : PenileClamp;
	}
	requirement safetyDurationReq {
		doc /* The maximum continuous usage duration shall not exceed 2 hours. */
		subject device : PenileClamp;
	}
	requirement functionalCompressionReq {
		doc /* The device shall apply controlled external pressure to manage urinary incontinence. */
		subject device : PenileClamp;
	}
}
