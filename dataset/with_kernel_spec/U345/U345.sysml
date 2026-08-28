package PalatalObturatorSystem {
	attribute def LengthValue :> ScalarValues::Real;
	attribute def FitQualityValue :> ScalarValues::Real;

	item def BiocompatibleMaterial;
	item def MedicalGradeResin :> BiocompatibleMaterial;
	item def SiliconeMaterial :> BiocompatibleMaterial;
	item def MetalAlloy :> BiocompatibleMaterial;

	item def DefectMeasurements {
		attribute width : LengthValue;
		attribute length : LengthValue;
		attribute depth : LengthValue;
	}

	port def MechanicalInterface;
	port def OralNasalInterface;
	port def ToothAnchorInterface;

	part def Tooth {
		port anchor : ToothAnchorInterface;
	}

	part def Palate;
	part def NasalCavity;
	part def OralCavity;

	part def Patient {
		attribute defectMeasurements : DefectMeasurements;
		part remainingTeeth : Tooth[0..*];
		part palate : Palate;
		part nasalCavity : NasalCavity;
		part oralCavity : OralCavity;
		port oralNasalPort : OralNasalInterface;
	}

	part def ObturatorBody {
		attribute material : MedicalGradeResin;
		attribute shapeMeasurements : DefectMeasurements;
		port bulbInterface : MechanicalInterface;
		port claspInterface : MechanicalInterface;
	}

	part def ObturatorBulb {
		attribute material : SiliconeMaterial;
		attribute compressibility : ScalarValues::Real;
		port bodyInterface : MechanicalInterface;
		port sealInterface : MechanicalInterface;
	}

	part def RetentionClasp {
		attribute material : MetalAlloy;
		port bodyInterface : MechanicalInterface;
		port toothInterface : ToothAnchorInterface;
	}

	part def PalatalObturator {
		port oralSealPort : OralNasalInterface;

		part body : ObturatorBody;
		part bulb : ObturatorBulb;
		part clasps : RetentionClasp[1..*];

		connect body.bulbInterface to bulb.bodyInterface;
		connect body.claspInterface to clasps.bodyInterface;
		connect bulb.sealInterface to oralSealPort;
	}

	part def PalatalObturatorAssembly {
		part patient : Patient;
		part obturator : PalatalObturator;

		connect obturator.oralSealPort to patient.oralNasalPort;
		connect obturator.clasps.toothInterface to patient.remainingTeeth.anchor;
	}

	requirement def RestoreOralNasalSeparation {
		subject p : PalatalObturatorAssembly;
		doc /* The system shall restore the natural separation between the oral and nasal cavities. */
	}

	requirement def EnableSpeech {
		subject p : PalatalObturatorAssembly;
		doc /* The system shall enable the patient to speak clearly. */
	}

	requirement def EnableSwallowing {
		subject p : PalatalObturatorAssembly;
		doc /* The system shall enable swallowing without nasal regurgitation. */
	}

	requirement def EnableChewing {
		subject p : PalatalObturatorAssembly;
		doc /* The system shall enable effective chewing of food. */
	}

	requirement def Biocompatibility {
		subject p : PalatalObturator;
		doc /* All components in contact with tissue shall be fabricated from biocompatible materials. */
	}

	requirement def RetentionStability {
		subject p : PalatalObturator;
		doc /* The device shall remain securely anchored during normal oral functions. */
	}

	part assembly : PalatalObturatorAssembly;

	requirement r1 : RestoreOralNasalSeparation;
	requirement r2 : EnableSpeech;
	requirement r3 : EnableSwallowing;
	requirement r4 : EnableChewing;
	requirement r5 : Biocompatibility;
	requirement r6 : RetentionStability;

	satisfy r1 by assembly.obturator;
	satisfy r2 by assembly.obturator;
	satisfy r3 by assembly.obturator;
	satisfy r4 by assembly.obturator;
	satisfy r5 by assembly.obturator;
	satisfy r6 by assembly.obturator;

	action def ClinicalAssessment {
		in patient : Patient;
		out defectMeasurements : DefectMeasurements;
	}

	action def FabricateObturator {
		in defectMeasurements : DefectMeasurements;
		out obturator : PalatalObturator;
	}

	action def FitObturator {
		in obturatorIn : PalatalObturator;
		in patient : Patient;
		out fitQuality : FitQualityValue;
		out obturatorOut : PalatalObturator;
	}

	action def UseObturator {
		in obturator : PalatalObturator;
		in patient : Patient;
	}

	action def MaintainObturator {
		in obturatorIn : PalatalObturator;
		out obturatorOut : PalatalObturator;
	}

	state def ObturatorLifecycle {
		entry; then Assessing;
		state Assessing {
			entry perform action assess : ClinicalAssessment;
			then Fabricating;
		}
		state Fabricating {
			entry perform action fabricate : FabricateObturator;
			then Fitting;
		}
		state Fitting {
			entry perform action fit : FitObturator;
			accept when fit.fitQuality > 0.9 then InUse;
			then Maintaining;
		}
		state InUse {
			entry perform action use : UseObturator;
			accept MaintenanceNeeded;
			then Maintaining;
		}
		state Maintaining {
			entry perform action maintain : MaintainObturator;
			then Fitting;
		}
		state Removed;
	}

	state lifecycle : ObturatorLifecycle;
}
