package AdamsClaspSystem {
	private import ScalarValues::*;
	private import Quantities::*;
	private import MeasurementReferences::*;
	private import ISQ::*;
	private import SI::*;

	doc
	/*
	 * Adams Clasp System — a mechanical retention device for removable
	 * orthodontic appliances. Bent stainless steel wire arms engage the
	 * undercuts of an anchor tooth and are partially embedded in an
	 * acrylic base.
	 */

	attribute def ArmsPassedBulge;
	attribute def RemovalForceApplied;

	part def AcrylicBase {
		port mesialSocket : AcrylicEmbedIF;
		port distalSocket : AcrylicEmbedIF;
	}

	part def StainlessSteelWire {
		attribute diameter :> ISQ::length;
		attribute yieldStrength :> ISQ::pressure;
	}

	part def AnchorTooth {
		attribute crownWidth :> ISQ::length;
		attribute undercutDepth :> ISQ::length;
		port mesialBulge : ToothBulgeIF;
		port distalBulge : ToothBulgeIF;
		port mesialUndercut : ToothUndercutIF;
		port distalUndercut : ToothUndercutIF;
	}

	part def AdamsClasp {
		part mesialArm : StainlessSteelWire {
			port embeddedEnd : AcrylicEmbedIF;
			port retentiveTip : ClaspTipIF;
		}
		part distalArm : StainlessSteelWire {
			port embeddedEnd : AcrylicEmbedIF;
			port retentiveTip : ClaspTipIF;
		}
		part bridgeWire : StainlessSteelWire {
			attribute occlusalClearance :> ISQ::length;
		}
		port mesialEmbedding : AcrylicEmbedIF;
		port distalEmbedding : AcrylicEmbedIF;
		connect mesialArm.embeddedEnd to mesialEmbedding;
		connect distalArm.embeddedEnd to distalEmbedding;
	}

	part def OrthodonticAppliance {
		part base : AcrylicBase;
		part clasp : AdamsClasp;
		connect clasp.mesialEmbedding to base.mesialSocket;
		connect clasp.distalEmbedding to base.distalSocket;
	}

	port def AcrylicEmbedIF;
	port def ClaspTipIF {
		out appliedForce :> ISQ::force;
		in reactionForce :> ISQ::force;
	}
	port def ToothBulgeIF {
		out deflectingForce :> ISQ::force;
	}
	port def ToothUndercutIF {
		in retentiveForce :> ISQ::force;
		out reactiveForce :> ISQ::force;
	}

	interface def ToothClaspInterface {
		doc /* Mechanical interface between a clasp tip and a tooth undercut. */
		end claspTip : ClaspTipIF;
		end toothUndercut : ToothUndercutIF;
		flow claspTip.appliedForce to toothUndercut.retentiveForce;
		flow toothUndercut.reactiveForce to claspTip.reactionForce;
	}

	action deflectArms;
	action snapIntoUndercuts;
	action exertRetentiveForce;
	action flexOutOfUndercuts;

	state def ClaspOperation {
		entry; then Insertion;
		state Insertion {
			doc /* Patient pushes appliance onto tooth; arms deflect over the bulge. */
			do action deflectArms;
		}
		accept ArmsPassedBulge then Engagement;
		state Engagement {
			doc /* Arms snap back inwards, fitting into tooth undercuts. */
			do action snapIntoUndercuts;
		}
		transition first Engagement then Retention;
		state Retention {
			doc /* Clasp exerts continuous retentive force resisting dislodgement. */
			do action exertRetentiveForce;
		}
		accept RemovalForceApplied then Removal;
		state Removal {
			doc /* Patient flexes arms out of undercuts to remove appliance. */
			do action flexOutOfUndercuts;
		}
		transition first Removal then done;
	}

	requirement def RetentionForceRequirement {
		doc /* The clasp must provide sufficient retention force to resist accidental dislodgement. */
		subject clasp : AdamsClasp;
		attribute minRetentionForce :> ISQ::force = 5.0 [N];
		attribute maxRetentionForce :> ISQ::force = 15.0 [N];
		constraint { clasp.mesialArm.retentiveTip.appliedForce >= minRetentionForce }
		constraint { clasp.distalArm.retentiveTip.appliedForce >= minRetentionForce }
		constraint { clasp.mesialArm.retentiveTip.appliedForce <= maxRetentionForce }
		constraint { clasp.distalArm.retentiveTip.appliedForce <= maxRetentionForce }
	}

	requirement def PatientComfortRequirement {
		doc /* Insertion and removal forces must remain within patient comfort limits. */
		subject clasp : AdamsClasp;
		attribute maxInsertionForce :> ISQ::force = 15.0 [N];
		attribute maxRemovalForce :> ISQ::force = 15.0 [N];
		constraint { maxInsertionForce <= 15.0 [N] }
		constraint { maxRemovalForce <= 15.0 [N] }
	}

	requirement def MaterialRequirement {
		doc /* Wire shall be stainless steel with adequate yield strength for repeated deflection. */
		subject wire : StainlessSteelWire;
		attribute minYieldStrength :> ISQ::pressure = 200000000 [Pa];
		constraint { wire.yieldStrength >= minYieldStrength }
	}

	requirement def BridgeClearanceRequirement {
		doc /* Bridge wire shall maintain minimum clearance above the chewing surface. */
		subject clasp : AdamsClasp;
		attribute minClearance :> ISQ::length = 0.5 [mm];
		constraint { clasp.bridgeWire.occlusalClearance >= minClearance }
	}

	part appliance : OrthodonticAppliance;
	part anchorTooth : AnchorTooth;

	connect appliance.clasp.mesialArm.retentiveTip to anchorTooth.mesialUndercut;
	connect appliance.clasp.distalArm.retentiveTip to anchorTooth.distalUndercut;

	state claspOperation : ClaspOperation;
}
