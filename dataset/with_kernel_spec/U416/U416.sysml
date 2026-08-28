package FieldTourniquet {
	private import ScalarValues::*;
	private import ISQ::*;

	/* Value type definitions */
	attribute def Tension :> Real;
	attribute def OcclusionPressure :> Real;
	attribute def StrapWidth :> Real;
	attribute def RotationAngle :> Real;

	/* Item type definitions */
	item def Limb {
		attribute circumference : Real;
		attribute isArm : Boolean;
	}

	item def BloodFlow {
		attribute rate : Real;
		attribute isOccluded : Boolean := false;
	}

	/* Signal definitions */
	attribute def PositionOnLimb;
	attribute def StartTightening;
	attribute def BleedingStopped;
	attribute def ReleaseTourniquet;

	/* Port definitions */
	port def TensionPort {
		attribute tension : Tension;
	}

	port def LimbContactPort {
		in item limb : Limb;
		attribute appliedPressure : OcclusionPressure;
	}

	port def LockStatePort {
		attribute locked : Boolean;
	}

	/* Compression Strap part definition */
	part def CompressionStrap {
		attribute width : StrapWidth;
		attribute maxTension : Tension;
		attribute currentTension : Tension := 0;
		attribute materialStrength : Tension;
		port limbInterface : LimbContactPort;
		port tensionInput : TensionPort;
		action applyPressure;
		action releasePressure {
			assign currentTension := 0;
		}
	}

	/* Windlass Mechanism part definition */
	part def WindlassMechanism {
		attribute rotationAngle : RotationAngle := 0;
		attribute maxRotation : RotationAngle;
		attribute tensionPerRotation : Tension;
		attribute generatedTension : Tension := 0;
		port tensionOutput : TensionPort;
		action tighten;
		action release;
	}

	/* Securing Clip part definition */
	part def SecuringClip {
		attribute isLocked : Boolean := false;
		attribute retentionForce : Tension;
		port lockOutput : LockStatePort;
		action lock {
			assign isLocked := true;
		}
		action unlock {
			assign isLocked := false;
		}
	}

	/* Time Marker part definition */
	part def TimeMarker {
		attribute applicationTime : String := "";
		attribute isMarked : Boolean := false;
		attribute isVisible : Boolean := true;
		action markTime {
			assign isMarked := true;
		}
		action recordTime {
			in timeValue : String;
			assign applicationTime := timeValue;
		}
		action clear {
			assign applicationTime := "";
			assign isMarked := false;
		}
	}

	/* Tourniquet assembly */
	part def Tourniquet {
		attribute isApplied : Boolean := false;
		attribute occlusionAchieved : Boolean := false;
		attribute occlusionThreshold : Tension := 120;

		port limbPort : LimbContactPort;

		part compressionStrap : CompressionStrap {
			:>> width = 0.05;
			:>> maxTension = 250;
			:>> materialStrength = 500;
		}
		part windlass : WindlassMechanism {
			:>> maxRotation = 720;
			:>> tensionPerRotation = 20;
		}
		part securingClip : SecuringClip {
			:>> retentionForce = 300;
		}
		part timeMarker : TimeMarker;

		connect limbPort to compressionStrap.limbInterface;
		connect windlass.tensionOutput to compressionStrap.tensionInput;

		state 'operation states' {
			entry; then idle;
			state idle;
			accept PositionOnLimb then positioned;
			state positioned;
			accept StartTightening then tightening;
			state tightening {
				do windlass.tighten;
			}
			accept BleedingStopped then securing;
			state securing {
				entry securingClip.lock;
				entry timeMarker.markTime;
				entry assign isApplied := true;
				entry assign occlusionAchieved := true;
			}
			then secured;
			state secured;
			accept ReleaseTourniquet then releasing;
			state releasing {
				entry securingClip.unlock;
				entry windlass.release;
				entry compressionStrap.releasePressure;
				entry timeMarker.clear;
				entry assign isApplied := false;
				entry assign occlusionAchieved := false;
			}
			then idle;
		}
	}

	/* Requirement definitions */
	requirement def OccludeArterialFlow {
		doc
		/* The tourniquet must apply sufficient pressure to stop arterial blood flow in a limb. */
		subject t : Tourniquet;
	}

	requirement def PreventUnintentionalRelease {
		doc
		/* The securing clip must prevent the windlass from unwinding while the tourniquet is applied. */
		subject t : Tourniquet;
	}

	requirement def RapidSinglePersonOperation {
		doc
		/* The device must be operable by a single person in high-stress field conditions. */
		subject t : Tourniquet;
	}

	requirement def RecordApplicationTime {
		doc
		/* The time of application must be clearly visible and documented on the device. */
		subject t : Tourniquet;
	}

	requirement def WithstandHighTension {
		doc
		/* The compression strap must withstand high tension without tearing. */
		subject t : Tourniquet;
	}

	requirement def DistributePressureEvenly {
		doc
		/* The strap must be wide enough to distribute pressure evenly around the limb. */
		subject t : Tourniquet;
	}

	/* Requirement usage */
	requirement tourniquetSpec : OccludeArterialFlow;
}
