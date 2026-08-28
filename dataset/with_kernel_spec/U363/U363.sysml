package DryEyeTreatmentSystem {
	private import ScalarValues::*;

	attribute def DiameterValue :> Real;
	attribute def LengthValue :> Real;
	attribute def VolumeValue :> Real;
	attribute def EfficiencyValue :> Real;

	enum def PlugMaterial {
		silicone;
		collagen;
		hydrogel;
	}

	enum def EyelidPosition {
		upper;
		lower;
	}

	event occurrence insertionRequested;
	event occurrence displacementOccurred;
	event occurrence removalRequested;
	event occurrence repositionRequested;

	port def InsertionInterface;
	port def ReceptacleInterface;

	part def PunctalPlug {
		attribute diameter : DiameterValue;
		attribute length : LengthValue;
		attribute material : PlugMaterial;
		attribute occlusionEfficiency : EfficiencyValue;
		port insertionPort : InsertionInterface;

		state uninserted;
		state seated;
		state displaced;

		transition t1 from uninserted to seated accept insertionRequested;
		transition t2 from seated to displaced accept displacementOccurred;
		transition t3 from displaced to seated accept repositionRequested;
		transition t4 from seated to uninserted accept removalRequested;
		transition t5 from displaced to uninserted accept removalRequested;
	}

	part def Punctum {
		attribute position : EyelidPosition;
		attribute anatomicalDiameter : DiameterValue;
		port receptaclePort : ReceptacleInterface;
	}

	part def TearFilm {
		attribute currentVolume : VolumeValue;
		attribute targetVolume : VolumeValue;
	}

	part def Eye {
		attribute targetTearVolume : VolumeValue;
		part punctum : Punctum;
		part tearFilm : TearFilm;
	}

	part def Patient {
		part eye : Eye;
	}

	part def Clinician;

	action def AssessFit {
		in plug : PunctalPlug;
		in punctum : Punctum;
		out isProperFit : Boolean;
	}

	action def InsertPlug {
		in clinician : Clinician;
		in plug : PunctalPlug;
		in punctum : Punctum;
		out success : Boolean;
	}

	action def RemovePlug {
		in clinician : Clinician;
		in plug : PunctalPlug;
		out success : Boolean;
	}

	action def MonitorTearRetention {
		in tearFilm : TearFilm;
		out isAdequate : Boolean;
	}

	requirement def CorrectSizing {
		subject plug : PunctalPlug;
		subject punctum : Punctum;
		require constraint { plug.diameter == punctum.anatomicalDiameter }
	}

	requirement def TherapeuticTearVolume {
		subject eye : Eye;
		require constraint { eye.tearFilm.currentVolume >= eye.targetTearVolume }
	}

	requirement def OcclusionEfficiency {
		subject plug : PunctalPlug;
		require constraint { plug.occlusionEfficiency >= 80.0 }
	}

	part treatmentSystem {
		part plug : PunctalPlug {
			attribute :>> diameter = 0.5;
			attribute :>> length = 2.0;
			attribute :>> material = PlugMaterial::silicone;
			attribute :>> occlusionEfficiency = 95.0;
		}

		part patient : Patient {
			part eye : Eye {
				attribute :>> targetTearVolume = 10.0;
				part punctum : Punctum {
					attribute :>> position = EyelidPosition::lower;
					attribute :>> anatomicalDiameter = 0.5;
				}
				part tearFilm : TearFilm {
					attribute :>> currentVolume = 5.0;
					attribute :>> targetVolume = 10.0;
				}
			}
		}

		part clinician : Clinician;

		connection plugToPunctum {
			end plugEnd :> plug.insertionPort;
			end punctumEnd :> patient.eye.punctum.receptaclePort;
		}

		action assessFit : AssessFit {
			in plug :>> plug;
			in punctum :>> patient.eye.punctum;
		}
		then action insertPlug : InsertPlug {
			in clinician :>> clinician;
			in plug :>> plug;
			in punctum :>> patient.eye.punctum;
		}
		then action monitor : MonitorTearRetention {
			in tearFilm :>> patient.eye.tearFilm;
		}

		requirement correctSizing : CorrectSizing {
			:>> plug = treatmentSystem.plug;
			:>> punctum = treatmentSystem.patient.eye.punctum;
		}

		requirement therapeuticGoal : TherapeuticTearVolume {
			:>> eye = treatmentSystem.patient.eye;
		}

		requirement effectiveOcclusion : OcclusionEfficiency {
			:>> plug = treatmentSystem.plug;
		}

		satisfy correctSizing by plug;
		satisfy effectiveOcclusion by plug;
		satisfy therapeuticGoal by patient.eye.tearFilm;
	}
}
