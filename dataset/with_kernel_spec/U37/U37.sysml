package 'Angellift System' {
	private import SI::*;
	private import ScalarValues::*;

	attribute def Force :> ISQ::force;
	attribute def Pressure :> ISQ::pressure;
	attribute def Length :> ISQ::length;

	item def BiocompatibleSilicone {
		attribute isBiocompatible : Boolean = true;
	}

	port def LiftForceOutPort {
		out liftForce : Force;
	}

	port def AppliedForceInPort {
		in appliedForce : Force;
	}

	part def DermalStrip {
		attribute material : BiocompatibleSilicone;
		attribute flexibility : Real;
		attribute adhesiveQuality : Real;
		attribute liftForceValue : Force;
		port liftForcePort : LiftForceOutPort;
	}

	part def FacialTissue {
		attribute initialWrinkleDepth : Length;
		attribute currentWrinkleDepth : Length;
		port appliedForcePort : AppliedForceInPort;
	}

	part def AngelliftSystem {
		part dermalStrip : DermalStrip;
		part targetTissue : FacialTissue;
		connection liftConnection connect dermalStrip.liftForcePort to targetTissue.appliedForcePort;
	}

	action def PrepareSkin;
	action def InsertStrip {
		in strip : DermalStrip;
		in tissue : FacialTissue;
		attribute insertionDepth : Length;
		attribute pressure : Pressure;
	}
	action def LiftTissue {
		in strip : DermalStrip;
		out tissue : FacialTissue;
	}
	action def MonitorResponse {
		in tissue : FacialTissue;
		attribute adverseReaction : Boolean;
	}
	action def EvaluateEffectiveness {
		in tissue : FacialTissue;
		out wrinkleReduction : Length;
	}
	action def RemoveStrip {
		in strip : DermalStrip;
		in tissue : FacialTissue;
	}

	action def ClinicalProcedure {
		action prepareSkin : PrepareSkin;
		action insertStrip : InsertStrip;
		action liftTissue : LiftTissue;
		action monitorResponse : MonitorResponse;
		action evaluateEffectiveness : EvaluateEffectiveness;
		action removeStrip : RemoveStrip;

		succession first prepareSkin then insertStrip;
		succession first insertStrip then liftTissue;
		succession first liftTissue then monitorResponse;
		succession first monitorResponse then evaluateEffectiveness;
		succession first evaluateEffectiveness then removeStrip;
	}

	requirement def BiocompatibilityRequirement {
		subject strip : DermalStrip;
		require constraint { strip.material.isBiocompatible == true }
	}

	requirement def MechanicalForceRequirement {
		subject strip : DermalStrip;
		require constraint { strip.liftForceValue > 0.0 [N] }
	}

	requirement def SafetyProtocolRequirement {
		subject procedure : InsertStrip;
		require constraint { procedure.insertionDepth <= 5.0 [mm] }
		require constraint { procedure.pressure <= 10.0 [Pa] }
	}

	requirement biocompatibilityReq : BiocompatibilityRequirement;
	requirement mechanicalForceReq : MechanicalForceRequirement;
	requirement safetyProtocolReq : SafetyProtocolRequirement;

	state def TreatmentStateMachine {
		state idle;
		state preparingSkin;
		state insertingStrip;
		state liftingTissue;
		state monitoringResponse;
		state evaluatingEffectiveness;
		state removingStrip;
		transition from idle to preparingSkin;
		transition from preparingSkin to insertingStrip;
		transition from insertingStrip to liftingTissue;
		transition from liftingTissue to monitoringResponse;
		transition from monitoringResponse to evaluatingEffectiveness;
		transition from evaluatingEffectiveness to removingStrip;
	}

	part angelliftSystem : AngelliftSystem {
		perform clinicalProcedure : ClinicalProcedure;
		state treatmentStateMachine : TreatmentStateMachine;
		satisfy biocompatibilityReq by dermalStrip;
		satisfy mechanicalForceReq by dermalStrip;
		satisfy safetyProtocolReq by clinicalProcedure.insertStrip;
	}
}
