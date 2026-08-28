package 'Denis Browne Bar System' {
	private import ScalarValues::*;

	doc
	/*
	 * Denis Browne bar orthopedic brace system for maintaining clubfoot correction
	 * in infants after initial treatment such as serial casting.
	 */

	attribute def RotationAngle :> Real;
	attribute def WearDuration :> Real;
	attribute def BarLength :> Real;
	attribute def ShoeSize :> Real;
	attribute def AppliedForce :> Real;

	item def Infant {
		attribute shoulderWidth : BarLength;
		attribute age : Real;
	}
	item def ClubfootDeformity;
	item def CorrectivePosition {
		attribute externalRotation : RotationAngle;
		attribute abductionAngle : RotationAngle;
	}

	port def BarEndPort;
	port def PlateBarPort;
	port def PlateShoePort;
	port def ShoeMountPort;

	part def RigidBar {
		doc /* Rigid metal bar sized to match infant shoulder width. */
		attribute length : BarLength;
		attribute material : String = "aluminum";
		port leftEnd : BarEndPort;
		port rightEnd : BarEndPort;
	}

	part def Footplate {
		doc /* Adjustable footplate set and locked at a specific external rotation angle. */
		attribute rotationAngle : RotationAngle = 70;
		attribute isLocked : Boolean = false;
		attribute appliedForce : AppliedForce;
		port barAttachment : PlateBarPort;
		port shoeMount : PlateShoePort;
		action adjustAngle;
		action lockPosition;
	}

	part def OrthopedicShoe {
		doc /* Specialized orthopedic shoe mounted onto the footplate. */
		attribute size : ShoeSize;
		port plateMount : ShoeMountPort;
		action secureFoot;
	}

	connection def BarPlateJoint {
		end port barEnd : BarEndPort;
		end port plateBar : PlateBarPort;
		attribute isAdjustable : Boolean = true;
	}

	connection def ShoePlateMount {
		end port shoePort : ShoeMountPort;
		end port platePort : PlateShoePort;
	}

	flow def CorrectionFlow {
		ref :>> payload : CorrectivePosition;
		end port source : PlateShoePort;
		end port target : ShoeMountPort;
	}

	state def TreatmentLifecycle {
		doc /* Treatment plan progresses through stages: initial fitting, active correction, maintenance, and weaning. */
		state initialFitting {
			entry action fitBrace;
		}
		then state activeCorrection {
			entry action beginFullTimeWear;
		}
		then state maintenance {
			entry action maintainAlignment;
		}
		then state weaning {
			entry action reduceUsage;
		}
		then state correctionStable {
			entry action discontinueBrace;
		}
	}

	part def DenisBrowneBar {
		doc /* Denis Browne bar assembly: bar, footplates, and shoes holding feet in corrected alignment. */
		attribute barLength : BarLength = 0.28;
		attribute externalRotation : RotationAngle = 70;

		part bar : RigidBar {
			attribute :>> length = 0.28;
		}
		part leftFootplate : Footplate;
		part rightFootplate : Footplate;
		part leftShoe : OrthopedicShoe;
		part rightShoe : OrthopedicShoe;

		connection barLeftPlate : BarPlateJoint connect bar.leftEnd to leftFootplate.barAttachment;
		connection barRightPlate : BarPlateJoint connect bar.rightEnd to rightFootplate.barAttachment;
		connection leftShoeMount : ShoePlateMount connect leftShoe.plateMount to leftFootplate.shoeMount;
		connection rightShoeMount : ShoePlateMount connect rightShoe.plateMount to rightFootplate.shoeMount;

		flow leftCorrection : CorrectionFlow of CorrectivePosition
			from leftFootplate.shoeMount to leftShoe.plateMount;
		flow rightCorrection : CorrectionFlow of CorrectivePosition
			from rightFootplate.shoeMount to rightShoe.plateMount;

		perform treatment : TreatmentLifecycle;
	}

	requirement def PreventRelapse {
		doc /* Prevent relapse of clubfoot deformity after initial correction. */
		subject patient : Infant;
		objective {
			/* Maintain corrected foot alignment and prevent deformity recurrence. */
		}
	}

	requirement def MaintainExternalRotation {
		doc /* Hold each foot in outwardly rotated position at specified angle. */
		subject brace : DenisBrowneBar;
		attribute requiredRotation : RotationAngle = 70;
		objective {
			/* Both footplates set and locked at required external rotation angle. */
		}
	}

	requirement def MatchShoulderWidth {
		doc /* Bar length shall match infant shoulder width. */
		subject bar : RigidBar;
		attribute requiredLength : BarLength;
		objective {
			/* Bar length sized to infant's shoulder width. */
		}
	}

	requirement def SecureFootPlacement {
		doc /* Securely hold infant feet in corrected alignment within shoes. */
		subject shoes : OrthopedicShoe[2];
		objective {
			/* Feet held securely in orthopedic shoes on footplates. */
		}
	}

	requirement def FollowTreatmentPlan {
		doc /* Progress through fitting, active correction, maintenance, and weaning phases. */
		subject treatment : TreatmentLifecycle;
		attribute fullTimeWearDuration : WearDuration = 23;
		objective {
			/* Treatment stages followed in sequence per protocol. */
		}
	}

	part def Caregiver;

	use case def ClubfootTreatment {
		subject brace : DenisBrowneBar;
		actor caregiver : Caregiver;
		actor patient : Infant;
		objective {
			/* Correct and maintain clubfoot correction using the Denis Browne bar. */
		}
	}

	use case clubfootTreatment : ClubfootTreatment;

	part denisBrowneBar : DenisBrowneBar {
		ref part patient : Infant;
		perform clubfootTreatment;
		satisfy req1 : PreventRelapse;
		satisfy req2 : MaintainExternalRotation;
		satisfy req3 : MatchShoulderWidth;
		satisfy req4 : SecureFootPlacement;
		satisfy req5 : FollowTreatmentPlan;
	}
}
