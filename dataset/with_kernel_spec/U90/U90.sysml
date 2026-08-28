package 'Nail Brace System' {
	private import ScalarValues::*;
	private import SI::*;

	attribute def CurvatureValue :> Real;

	attribute def InstallSignal;
	attribute def MonitorSignal;
	attribute def AdjustSignal;
	attribute def CompleteSignal;
	attribute def RemoveSignal;

	port def MechanicalPort {
		in appliedForce : ForceValue;
		out position : LengthValue;
	}

	port def TensionPort {
		in setTension : ForceValue;
		out currentTension : ForceValue;
	}

	part def AnchorHook {
		attribute attachmentStrength : ForceValue;
		port attachment : MechanicalPort;
	}

	part def BraceWire {
		attribute material : String = "Nickel-Titanium";
		attribute wireTension : ForceValue;
		attribute wireLength : LengthValue;
		attribute maxTension : ForceValue = 2.0 [N];

		port leftEnd : MechanicalPort;
		port rightEnd : MechanicalPort;
		port tensionInput : TensionPort;

		assert constraint { wireTension > 0 [N] and wireTension <= maxTension }
	}

	part def TensionAdjuster {
		attribute currentTension : ForceValue;
		attribute minTension : ForceValue = 0.1 [N];
		attribute maxTension : ForceValue = 2.0 [N];

		port adjustPort : TensionPort;
	}

	part def Nail {
		attribute curvature : CurvatureValue;
		attribute targetCurvature : CurvatureValue = 0.1;
		attribute thickness : LengthValue;

		port leftEdge : MechanicalPort;
		port rightEdge : MechanicalPort;
	}

	part def NailBraceSystem {
		part leftHook : AnchorHook;
		part rightHook : AnchorHook;
		part wire : BraceWire;
		part adjuster : TensionAdjuster;
		part nail : Nail;

		connect leftHook.attachment to wire.leftEnd;
		connect rightHook.attachment to wire.rightEnd;
		connect adjuster.adjustPort to wire.tensionInput;
		connect leftHook.attachment to nail.leftEdge;
		connect rightHook.attachment to nail.rightEdge;

		attribute appliedForce : ForceValue = wire.wireTension;
		attribute treatmentDuration : TimeValue;

		assert constraint { appliedForce <= 2 [N] }
	}

	action def PerformAdjustment {
		in requestedTension : ForceValue;
		out appliedTension : ForceValue;

		assert constraint {
			requestedTension >= 0.1 [N] and requestedTension <= 2.0 [N]
		}
	}

	state def TreatmentLifecycle {
		entry; then installed;

		state installed;
		transition install_to_active
			first installed
			accept InstallSignal
			then activeCorrection;

		state activeCorrection;
		transition active_to_monitoring
			first activeCorrection
			accept MonitorSignal
			then monitoring;

		state monitoring;
		transition monitoring_to_adjusting
			first monitoring
			accept AdjustSignal
			then adjusting;
		transition monitoring_to_complete
			first monitoring
			accept CompleteSignal
			then treatmentComplete;

		state adjusting;
		transition adjusting_to_active
			first adjusting
			accept MonitorSignal
			then activeCorrection;

		state treatmentComplete;
		transition complete_to_removed
			first treatmentComplete
			accept RemoveSignal
			then removed;

		state removed;
	}

	requirement def CorrectNailShape {
		doc /* The system shall reduce nail curvature to a clinically acceptable level. */
		subject braceSystem : NailBraceSystem;
	}

	requirement def ForceSafetyLimit {
		doc /* The system shall not exceed force limits that could damage the nail or cause excessive pain. */
		subject braceSystem : NailBraceSystem;
	}

	requirement def GradualCorrection {
		doc /* The system shall apply a gentle, controlled mechanical force to gradually reshape the nail plate. */
		subject braceSystem : NailBraceSystem;
	}

	constraint def CorrectionDynamics {
		in initialCurvature : CurvatureValue;
		in finalCurvature : CurvatureValue;
		in appliedForce : ForceValue;
		in duration : TimeValue;

		finalCurvature < initialCurvature and
		appliedForce > 0 [N] and
		appliedForce <= 2 [N] and
		duration > 0 [s]
	}
}
