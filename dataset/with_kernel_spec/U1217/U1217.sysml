package SoftRoboticGripperSystem {
	private import ScalarValues::Real;
	private import ISQ::Force;
	private import ISQ::Pressure;

	item def GripCommand {
		attribute desiredForce : Force;
		attribute desiredCompliance : Real;
	}

	item def ForceFeedback {
		attribute measuredForce : Force;
	}

	item def PressureCommand {
		attribute targetPressure : Pressure;
	}

	item def CompressedAir {
		attribute pressure : Pressure;
	}

	port def CommandPort {
		in ref command : GripCommand;
	}

	port def FeedbackPort {
		out ref feedback : ForceFeedback;
	}

	port def PressureControlPort {
		in ref command : PressureCommand;
	}

	port def AirSupplyPort {
		out ref air : CompressedAir;
	}

	requirement def SoftGripRequirement {
		doc /* The gripper must securely hold delicate or irregularly shaped objects without crushing or damaging them. */
	}

	part def SoftPneumaticActuator {
		port airPort : ~AirSupplyPort;
		port feedbackPort : FeedbackPort;
		attribute currentForce : Force;

		perform action actuate {
			in ref air : CompressedAir;
			out ref fb : ForceFeedback;
		}

		flow airFlow from airPort.air to actuate.air;
		flow feedbackFlow from actuate.fb to feedbackPort.feedback;
	}

	part def AirCompressor {
		port outputPort : AirSupplyPort;

		perform action generateAir {
			out ref a : CompressedAir;
		}

		flow airFlow from generateAir.a to outputPort.air;
	}

	part def PressureRegulator {
		port inputPort : ~AirSupplyPort;
		port controlPort : PressureControlPort;
		port outputPort1 : AirSupplyPort;
		port outputPort2 : AirSupplyPort;
		port outputPort3 : AirSupplyPort;

		perform action regulate {
			in ref air : CompressedAir;
			in ref cmd : PressureCommand;
			out ref out1 : CompressedAir;
			out ref out2 : CompressedAir;
			out ref out3 : CompressedAir;
		}

		flow airIn from inputPort.air to regulate.air;
		flow cmdIn from controlPort.command to regulate.cmd;
		flow airOut1 from regulate.out1 to outputPort1.air;
		flow airOut2 from regulate.out2 to outputPort2.air;
		flow airOut3 from regulate.out3 to outputPort3.air;
	}

	part def ControlUnit {
		port commandPort : CommandPort;
		port feedbackPort1 : ~FeedbackPort;
		port feedbackPort2 : ~FeedbackPort;
		port feedbackPort3 : ~FeedbackPort;
		port controlPort1 : ~PressureControlPort;
		port controlPort2 : ~PressureControlPort;
		port controlPort3 : ~PressureControlPort;

		state def ControlStateMachine {
			entry; then Idle;

			state Idle {
				accept command : GripCommand
				then Grasping;
			}

			state Grasping {
				accept command : GripCommand
					if command.desiredForce == 0
				then Releasing;
			}

			state Releasing {
				entry; then Idle;
			}
		}

		perform state machine behavior : ControlStateMachine;
	}

	part def SoftRoboticGripper {
		port commandPort : CommandPort;

		part controlUnit : ControlUnit;
		part compressor : AirCompressor;
		part regulator : PressureRegulator;
		part finger1 : SoftPneumaticActuator;
		part finger2 : SoftPneumaticActuator;
		part finger3 : SoftPneumaticActuator;

		interface commandInterface connect commandPort to controlUnit.commandPort;

		interface airSupplyInterface connect compressor.outputPort to regulator.inputPort;

		interface controlInterface1 connect controlUnit.controlPort1 to regulator.controlPort;
		interface controlInterface2 connect controlUnit.controlPort2 to regulator.controlPort;
		interface controlInterface3 connect controlUnit.controlPort3 to regulator.controlPort;

		interface regulatedAir1 connect regulator.outputPort1 to finger1.airPort;
		interface regulatedAir2 connect regulator.outputPort2 to finger2.airPort;
		interface regulatedAir3 connect regulator.outputPort3 to finger3.airPort;

		interface feedbackInterface1 connect finger1.feedbackPort to controlUnit.feedbackPort1;
		interface feedbackInterface2 connect finger2.feedbackPort to controlUnit.feedbackPort2;
		interface feedbackInterface3 connect finger3.feedbackPort to controlUnit.feedbackPort3;

		satisfy softGripReq : SoftGripRequirement;
	}
}
