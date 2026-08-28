package HipAbductorWedgeSystem {
	private import ISQ::*;
	private import SI::*;
	private import ScalarValues::*;

	attribute def AbductionAngle :> Angle;
	attribute def FoamDensity :> MassDensity;
	attribute def StrapTension :> Force;
	attribute def ContactPressure :> Pressure;
	attribute def StrapLength :> Length;

	port def StrapAttachmentPort;
	port def LegContactPort;

	part def FoamWedge {
		port leftAttachment : StrapAttachmentPort;
		port rightAttachment : StrapAttachmentPort;
		attribute abductionAngle : AbductionAngle = 25 [deg];
		attribute firmness : StrapTension;
		attribute density : FoamDensity;
		attribute hypoallergenic : Boolean = true;
	}

	part def ProtectiveCover {
		attribute waterproof : Boolean = true;
		attribute antimicrobial : Boolean = true;
		attribute material : String;
	}

	part def SecuringStrap {
		port wedgeEnd : StrapAttachmentPort;
		port legEnd : LegContactPort;
		attribute adjustableLength : StrapLength;
		attribute maxSafeTension : StrapTension;
		attribute currentTension : StrapTension;
		attribute appliedPressure : ContactPressure;
	}

	part def PatientLeg {
		port strapContact : LegContactPort;
		attribute circumference : StrapLength;
	}

	part def Patient {
		part leftLeg : PatientLeg;
		part rightLeg : PatientLeg;
	}

	connection def CoverEnclosure {
		end cover : ProtectiveCover[1];
		end wedge : FoamWedge[1];
	}

	connection def WedgeStrapLink {
		end wedgePort : StrapAttachmentPort[1];
		end strapPort : StrapAttachmentPort[1];
	}

	connection def LegStrapLink {
		end strapPort : LegContactPort[1];
		end legPort : LegContactPort[1];
	}

	action def PlaceWedge {
		doc
		/*
		 * Position the foam wedge between the patient's thighs.
		 */
	}

	action def EncloseWedge {
		doc
		/*
		 * Ensure the protective cover completely encloses the foam wedge.
		 */
	}

	action def SecureStraps {
		doc
		/*
		 * Wrap straps around each leg and the wedge.
		 */
	}

	action def AdjustTension {
		doc
		/*
		 * Adjust strap tension to maintain abduction without exceeding safe pressure.
		 */
	}

	action def MonitorPosition {
		doc
		/*
		 * Monitor leg separation angle and strap contact pressure over time.
		 */
	}

	requirement def MaintainAbductionAngle {
		doc
		/*
		 * The system shall maintain the patient's legs in approximately 25 degrees
		 * of abduction to prevent dislocation of the new hip joint during healing.
		 */
		attribute targetAngle : AbductionAngle = 25 [deg];
	}

	requirement def PreventTissueDamage {
		doc
		/*
		 * Strap tension shall be adjustable and applied pressure shall remain
		 * within safe limits to prevent skin and soft tissue damage.
		 */
		attribute maxSafePressure : ContactPressure;
	}

	requirement def InfectionControl {
		doc
		/*
		 * The protective cover shall be waterproof and antimicrobial to prevent
		 * contamination and support cleaning.
		 */
	}

	state machine def OperationStates {
		state Idle;
		state Positioned {
			entry perform placeWedge;
		}
		state Enclosed {
			entry perform encloseWedge;
		}
		state Secured {
			entry perform secureStraps;
		}
		state Adjusted {
			entry perform adjustTension;
		}
		state Monitoring {
			entry perform monitorPosition;
		}
		transition from Idle to Positioned;
		transition from Positioned to Enclosed;
		transition from Enclosed to Secured;
		transition from Secured to Adjusted;
		transition from Adjusted to Monitoring;
		transition from Monitoring to Adjusted when pressureExceeded;
		transition from Monitoring to Adjusted when angleDeviated;
	}

	part def HipAbductorWedgeAssembly {
		part wedge : FoamWedge;
		part cover : ProtectiveCover;
		part leftStrap : SecuringStrap;
		part rightStrap : SecuringStrap;
		ref patient : Patient;

		connection coverEnclosure : CoverEnclosure connect cover to wedge;
		connection leftWedgeStrap : WedgeStrapLink
			connect wedge.leftAttachment to leftStrap.wedgeEnd;
		connection rightWedgeStrap : WedgeStrapLink
			connect wedge.rightAttachment to rightStrap.wedgeEnd;
		connection leftLegStrap : LegStrapLink
			connect leftStrap.legEnd to patient.leftLeg.strapContact;
		connection rightLegStrap : LegStrapLink
			connect rightStrap.legEnd to patient.rightLeg.strapContact;

		attribute pressureExceeded : Boolean = false;
		attribute angleDeviated : Boolean = false;

		perform placeWedge : PlaceWedge;
		perform encloseWedge : EncloseWedge;
		perform secureStraps : SecureStraps;
		perform adjustTension : AdjustTension;
		perform monitorPosition : MonitorPosition;

		exhibit opState : OperationStates;
	}

	part hipAbductorSystem : HipAbductorWedgeAssembly {
		wedge.abductionAngle = 25 [deg];
		wedge.hypoallergenic = true;
		wedge.density = 45 [kg/m^3];
		wedge.firmness = 120 [N];
		cover.waterproof = true;
		cover.antimicrobial = true;
		cover.material = "Waterproof Antimicrobial Fabric";
		leftStrap.maxSafeTension = 50 [N];
		rightStrap.maxSafeTension = 50 [N];
		leftStrap.adjustableLength = 0.3 [m];
		rightStrap.adjustableLength = 0.3 [m];

		satisfy req1 : MaintainAbductionAngle;
		satisfy req2 : PreventTissueDamage;
		satisfy req3 : InfectionControl;
	}
}
