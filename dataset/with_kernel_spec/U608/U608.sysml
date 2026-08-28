package 'Mechanical Barograph' {
	private import ISQ::*;
	private import SI::*;
	private import ScalarValues::*;

	item def StartRecording;
	item def ChartFull;
	item def ChartReplaced;
	item def InkTrace;

	action def SensePressure {
		in pressure : ISQ::PressureValue;
		out displacement : ISQ::LengthValue;
	}

	action def AmplifyDisplacement {
		in input : ISQ::LengthValue;
		out output : ISQ::LengthValue;
	}

	action def MoveRecordingArm {
		in displacement : ISQ::LengthValue;
	}

	action def RotateDrum {
		out angle : Real;
	}

	part def ChartPaper {
		attribute width : ISQ::LengthValue;
		attribute height : ISQ::LengthValue;
		attribute isFull : Boolean = false;
	}

	part def AneroidCapsule {
		port pressurePort {
			in pressure : ISQ::PressureValue;
		}
		port displacementPort {
			out displacement : ISQ::LengthValue;
		}
		attribute sensitivity : Real = 0.1;
	}

	part def MechanicalLinkage {
		port displacementInPort {
			in displacement : ISQ::LengthValue;
		}
		port displacementOutPort {
			out displacement : ISQ::LengthValue;
		}
		attribute magnification : Real = 10.0;
	}

	part def RecordingArm {
		port displacementInPort {
			in displacement : ISQ::LengthValue;
		}
		port tracePort {
			out trace : InkTrace;
		}
		attribute armLength : ISQ::LengthValue;
		attribute inkLevel : Real;
	}

	part def ClockworkDrum {
		port traceInPort {
			in trace : InkTrace;
		}
		attribute rotationPeriod : ISQ::TimeValue = 7 [SI::d];
		attribute currentAngle : Real;
		part chartPaper : ChartPaper;
	}

	part def Atmosphere {
		port pressurePort {
			out pressure : ISQ::PressureValue;
		}
	}

	part def Barograph {
		port atmospherePort {
			in pressure : ISQ::PressureValue;
		}

		part aneroidCapsule : AneroidCapsule;
		part linkage : MechanicalLinkage;
		part arm : RecordingArm;
		part drum : ClockworkDrum;

		connect atmospherePort to aneroidCapsule.pressurePort;
		connect aneroidCapsule.displacementPort to linkage.displacementInPort;
		connect linkage.displacementOutPort to arm.displacementInPort;
		connect arm.tracePort to drum.traceInPort;

		perform action sensePressure : SensePressure;
		perform action amplifyDisplacement : AmplifyDisplacement;
		perform action moveRecordingArm : MoveRecordingArm;
		perform action rotateDrum : RotateDrum;

		state BarographBehavior {
			entry; then idle;
			state idle;
			accept StartRecording then recording;
			state recording {
				do sensePressure;
				do amplifyDisplacement;
				do moveRecordingArm;
				do rotateDrum;
			}
			accept ChartFull then maintenance;
			state maintenance;
			accept ChartReplaced then idle;
		}
	}

	part def BarographSystem {
		part atmosphere : Atmosphere;
		part barograph : Barograph;
		connect atmosphere.pressurePort to barograph.atmospherePort;
	}

	requirement def BarographRequirements {
		subject barograph : Barograph;
		doc /* The barograph shall continuously measure and record atmospheric pressure over time to produce a barogram chart for meteorological analysis. */
	}

	requirement def MeasurePressureRequirement {
		subject barograph : Barograph;
		doc /* The barograph shall continuously measure atmospheric pressure using an aneroid capsule that expands and contracts in response to pressure changes. */
	}

	requirement def RecordBarogramRequirement {
		subject barograph : Barograph;
		doc /* The barograph shall produce a continuous trace of pressure over time on chart paper wrapped around a clockwork drum. */
	}

	requirement def DrumRotationRequirement {
		subject drum : ClockworkDrum;
		doc /* The clockwork drum shall complete one full rotation over a seven-day period to provide a time axis for the barogram. */
	}

	requirement def MagnifyMotionRequirement {
		subject linkage : MechanicalLinkage;
		doc /* The mechanical linkage shall magnify the aneroid capsule displacement to drive the recording arm. */
	}

	requirement def OperationalStatesRequirement {
		subject barograph : Barograph;
		doc /* The barograph shall support idle, recording, and maintenance operational states. */
	}
}
