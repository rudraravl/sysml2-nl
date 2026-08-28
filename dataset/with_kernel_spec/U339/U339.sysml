package ClinicalAssessmentSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	attribute def Volume :> ScalarValues::Real {
		doc
		/*
		 * Testicular volume measured in milliliters (mL).
		 */
	}

	enum def PraderStage {
		stage1;
		stage2;
		stage3;
		stage4;
		stage5;
	}

	enum def TesticleSide {
		left;
		right;
	}

	part def Bead {
		attribute volume : Volume;
	}

	part def Orchidometer {
		doc
		/*
		 * Prader orchidometer: a chain of twelve ellipsoidal reference beads
		 * with volumes 1, 2, 3, 4, 5, 6, 8, 10, 12, 15, 20, and 25 mL.
		 */
		part bead1 : Bead { :>> volume = 1.0; }
		part bead2 : Bead { :>> volume = 2.0; }
		part bead3 : Bead { :>> volume = 3.0; }
		part bead4 : Bead { :>> volume = 4.0; }
		part bead5 : Bead { :>> volume = 5.0; }
		part bead6 : Bead { :>> volume = 6.0; }
		part bead7 : Bead { :>> volume = 8.0; }
		part bead8 : Bead { :>> volume = 10.0; }
		part bead9 : Bead { :>> volume = 12.0; }
		part bead10 : Bead { :>> volume = 15.0; }
		part bead11 : Bead { :>> volume = 20.0; }
		part bead12 : Bead { :>> volume = 25.0; }
	}

	part def Testicle {
		attribute measuredVolume : Volume [0..1];
	}

	part def Patient {
		attribute patientID : String;
		part leftTesticle : Testicle;
		part rightTesticle : Testicle;
	}

	part def Clinician {
		attribute clinicianID : String;
	}

	attribute def MeasurementRecord {
		attribute patientID : String;
		attribute leftVolume : Volume;
		attribute rightVolume : Volume;
		attribute stage : PraderStage;
	}

	part def RecordingSystem {
		attribute records : MeasurementRecord [0..*];
	}

	action def MeasureTesticle {
		in part examiner : Clinician;
		in part examinee : Patient;
		in part tool : Orchidometer;
		in side : TesticleSide;

		action palpate {
			out estimatedVolume : Volume;
		}
		then action selectBead {
			in estimatedVolume : Volume = palpate.estimatedVolume;
			out selectedBead : Bead;
		}
		then action compare {
			in part bead : Bead = selectBead.selectedBead;
			out finalVolume : Volume;
		}
		return volume : Volume = compare.finalVolume;
	}

	action def ClassifyPraderStage {
		in leftVolume : Volume;
		in rightVolume : Volume;
		out stage : PraderStage;
	}

	action def AssessmentWorkflow {
		in part examiner : Clinician;
		in part examinee : Patient;
		in part tool : Orchidometer;

		action prepare {
			doc
			/*
			 * Prepare the examination: sanitize hands, position the patient,
			 * and lay out the orchidometer beads.
			 */
		}
		then action measureLeft : MeasureTesticle {
			in part :>> examiner = that.examiner;
			in part :>> examinee = that.examinee;
			in part :>> tool = that.tool;
			in :>> side = TesticleSide::left;
		}
		then action measureRight : MeasureTesticle {
			in part :>> examiner = that.examiner;
			in part :>> examinee = that.examinee;
			in part :>> tool = that.tool;
			in :>> side = TesticleSide::right;
		}
		then action classify : ClassifyPraderStage {
			in :>> leftVolume = measureLeft.volume;
			in :>> rightVolume = measureRight.volume;
		}
		then action document {
			in patientID : String = that.examinee.patientID;
			in leftVolume : Volume = measureLeft.volume;
			in rightVolume : Volume = measureRight.volume;
			in stage : PraderStage = classify.stage;
			out record : MeasurementRecord = new MeasurementRecord(
				patientID = patientID,
				leftVolume = leftVolume,
				rightVolume = rightVolume,
				stage = stage
			);
		}
		return record : MeasurementRecord = document.record;
	}

	requirement def PubertalAssessmentRequirement {
		subject patient : Patient;
		doc
		/*
		 * The system shall measure both testicular volumes and classify
		 * the patient's pubertal stage using the larger volume.
		 */
		require constraint {
			patient.leftTesticle.measuredVolume > 0 and
			patient.rightTesticle.measuredVolume > 0
		}
	}

	requirement def RecordCompletenessRequirement {
		subject record : MeasurementRecord;
		doc
		/*
		 * The measurement record shall include the patient ID, both
		 * testicular volumes, and the determined Prader stage.
		 */
		require constraint {
			record.leftVolume > 0 and
			record.rightVolume > 0
		}
	}

	part def AssessmentSystem {
		part clinician : Clinician;
		part orchidometer : Orchidometer;
		ref part patient : Patient;
		ref part ehr : RecordingSystem;

		perform action assess : AssessmentWorkflow {
			in part :>> examiner = clinician;
			in part :>> examinee = patient;
			in part :>> tool = orchidometer;
		}
	}
}
