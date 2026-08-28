package 'Digital Stadiometer' {
	private import ScalarValues::*;
	private import ISQ::LengthValue;
	private import SI::m;
	private import SI::mm;
	private import SI::s;

	attribute def PresenceSignal;
	attribute def ContactSignal;
	attribute def ResetSignal;
	attribute def LevelFaultSignal;
	attribute def CalibrationFaultSignal;
	attribute def LowerCmd;
	attribute def LockCmd;
	attribute def RetractCmd;

	part def Person {
		attribute standingHeight : LengthValue;
	}

	part def BasePlatform {
		attribute isLevel : Boolean;
		port presencePort { out presence : PresenceSignal; }
	}

	part def VerticalRail {
		attribute maxRange : LengthValue;
	}

	part def SlidingHeadpiece {
		attribute position : LengthValue;
		port contactPort { out contact : ContactSignal; }
		port positionPort { out positionValue : LengthValue; }
	}

	part def ControlUnit {
		port presencePort { in presence : PresenceSignal; }
		port contactPort { in contact : ContactSignal; }
		port positionPort { in positionValue : LengthValue; }
		port displayPort { out displayValue : LengthValue; }

		action def ProcessHeight {
			in rawHeight : LengthValue;
			out calibratedHeight : LengthValue;
		}
		action processHeight : ProcessHeight {
			in rawHeight = positionPort.positionValue;
			out calibratedHeight = displayPort.displayValue;
		}
	}

	part def DigitalDisplay {
		port displayPort { in displayValue : LengthValue; }
	}

	part def Stadiometer {
		attribute isCalibrated : Boolean = true;

		part basePlatform : BasePlatform;
		part verticalRail : VerticalRail;
		part slidingHeadpiece : SlidingHeadpiece;
		part controlUnit : ControlUnit;
		part digitalDisplay : DigitalDisplay;

		flow presenceFlow of PresenceSignal 
			from basePlatform.presencePort.presence to controlUnit.presencePort.presence;
		flow contactFlow of ContactSignal 
			from slidingHeadpiece.contactPort.contact to controlUnit.contactPort.contact;
		flow positionFlow of LengthValue 
			from slidingHeadpiece.positionPort.positionValue to controlUnit.positionPort.positionValue;
		flow displayFlow of LengthValue 
			from controlUnit.displayPort.displayValue to digitalDisplay.displayPort.displayValue;

		state stadiometerStates parallel {
			state operationalStates {
				entry; then ready;
				state ready;
				accept PresenceSignal
					if basePlatform.isLevel and isCalibrated
					do send new LowerCmd() to slidingHeadpiece
					then measuring;
				state measuring {
					entry; then lowering;
					state lowering;
					accept ContactSignal
						do send new LockCmd() to slidingHeadpiece
						then reading;
					state reading {
						entry controlUnit.processHeight;
						accept after 3 [s]
							do send new RetractCmd() to slidingHeadpiece
							then ready;
					}
				}
			}
			state monitoringStates {
				entry; then normal;
				state normal;
				accept LevelFaultSignal
					then error;
				accept CalibrationFaultSignal
					then error;
				state error;
				accept ResetSignal
					then normal;
			}
		}
	}

	requirement def AccuracyRequirement {
		doc { The stadiometer shall measure height with an accuracy of at least 1 [mm]. }
	}

	requirement def SafetyContactRequirement {
		doc { The headpiece shall stop and lock immediately upon sensing contact. }
	}

	requirement def LevelSurfaceRequirement {
		doc { The system shall not operate if the base platform is not level. }
	}
}
