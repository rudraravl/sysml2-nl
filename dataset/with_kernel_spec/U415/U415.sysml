package OralExaminationSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    item def Wood {
        attribute density : Real;
        attribute grain : String;
        attribute nonToxic : Boolean;
    }

    part def Blade {
        attribute surfaceFinish : String = "smooth";
        port contactSurface;
    }

    part def Handle {
        port gripInterface;
    }

    attribute def PackageOpened;
    attribute def DepressorPositioned;
    attribute def ExaminationCompleteSignal;

    state def TongueDepressorLifecycle {
        entry; then sterilePackaged;
        state sterilePackaged;
        accept PackageOpened
            then readyForUse;
        state readyForUse;
        accept DepressorPositioned
            then active;
        state active {
            do action holdTongueDown {
                /* Sustained force applied to hold tongue */
            }
        }
        accept ExaminationCompleteSignal
            then discarded;
        state discarded {
            attribute sterile : Boolean = false;
        }
    }

    part def TongueDepressor {
        attribute length :> ISQ::length = 150['mm'];
        attribute width :> ISQ::length = 18['mm'];
        attribute thickness :> ISQ::length = 2['mm'];
        ref item material : Wood;
        part blade : Blade {
            attribute length :> ISQ::length = 100['mm'];
        }
        part handle : Handle {
            attribute length :> ISQ::length = 50['mm'];
        }
        port gripPort;
        port contactPort;
        connect gripPort to handle.gripInterface;
        connect contactPort to blade.contactSurface;
        exhibit state lifecycle : TongueDepressorLifecycle;
    }

    part def Clinician {
        port handPort;
    }

    part def Patient {
        port tonguePort;
    }

    part def OralCavity;

    part def OralExamination {
        part clinician : Clinician;
        part patient : Patient;
        part tongueDepressor : TongueDepressor;
        part oralCavity : OralCavity;
        connect clinician.handPort to tongueDepressor.gripPort;
        connect tongueDepressor.contactPort to patient.tonguePort;
    }

    action def EnsureSterility {
        in depressor : TongueDepressor;
        out isSterile : Boolean;
    }

    action def ConfirmPatientReady {
        in patient : Patient;
        out isReady : Boolean;
    }

    action def PositionDepressor {
        in depressor : TongueDepressor;
        in oralCavity : OralCavity;
    }

    action def ApplySustainedForce {
        in depressor : TongueDepressor;
        in patient : Patient;
        out appliedForce :> ISQ::force;
    }

    action def PerformVisualInspection {
        in oralCavity : OralCavity;
        out findings : String;
    }

    action def WithdrawDepressor {
        in depressor : TongueDepressor;
    }

    action def OralExaminationProcedure {
        in clinician : Clinician;
        in patient : Patient;
        in depressor : TongueDepressor;
        in oralCavity : OralCavity;

        action ensureSterility : EnsureSterility {
            in depressor = depressor;
        }
        action confirmPatientReady : ConfirmPatientReady {
            in patient = patient;
        }
        action positionDepressor : PositionDepressor {
            in depressor = depressor;
            in oralCavity = oralCavity;
        }
        action applyForce : ApplySustainedForce {
            in depressor = depressor;
            in patient = patient;
            out appliedForce = 2.5['N'];
        }
        action visualInspection : PerformVisualInspection {
            in oralCavity = oralCavity;
        }
        action withdrawDepressor : WithdrawDepressor {
            in depressor = depressor;
        }

        then ensureSterility;
        then confirmPatientReady;
        then positionDepressor;
        then applyForce;
        then visualInspection;
        then withdrawDepressor;
    }

    requirement def MaterialSafetyRequirement {
        subject depressor : TongueDepressor;
        doc /* The tongue depressor material shall be non-toxic and safe for oral contact. */
    }

    requirement def StructuralIntegrityRequirement {
        subject depressor : TongueDepressor;
        attribute maxSafeForce :> ISQ::force = 5['N'];
        doc /* The depressor shall not splinter or break under an applied force up to 5 N. */
    }

    requirement def DimensionalRequirement {
        subject depressor : TongueDepressor;
        attribute requiredLength :> ISQ::length = 150['mm'];
        attribute requiredWidth :> ISQ::length = 18['mm'];
        attribute requiredThickness :> ISQ::length = 2['mm'];
        doc /* The depressor shall have the specified dimensions. */
    }

    requirement def SterilityRequirement {
        subject depressor : TongueDepressor;
        doc /* The depressor shall be sterile when packaged and single-use to prevent cross-contamination. */
    }

    requirement def ExaminationForceRequirement {
        subject depressor : TongueDepressor;
        attribute targetForce :> ISQ::force = 2.5['N'];
        doc /* The clinician shall apply a light, sustained force of approximately 2.5 N to hold the tongue down. */
    }

    requirement materialSafetyReq : MaterialSafetyRequirement {
        subject depressor : TongueDepressor;
    }
    requirement structuralIntegrityReq : StructuralIntegrityRequirement {
        subject depressor : TongueDepressor;
    }
    requirement dimensionalReq : DimensionalRequirement {
        subject depressor : TongueDepressor;
    }
    requirement sterilityReq : SterilityRequirement {
        subject depressor : TongueDepressor;
    }
    requirement examinationForceReq : ExaminationForceRequirement {
        subject depressor : TongueDepressor;
    }

    individual item def BirchWood_1 :> Wood {
        attribute :>> density = 650;
        attribute :>> grain = "longitudinal";
        attribute :>> nonToxic = true;
    }

    individual part def Blade_1 :> Blade;
    individual part def Handle_1 :> Handle;

    individual part def TongueDepressor_1 :> TongueDepressor {
        ref item :>> material : BirchWood_1;
        part :>> blade : Blade_1;
        part :>> handle : Handle_1;
    }

    individual part def Clinician_1 :> Clinician;
    individual part def Patient_1 :> Patient;
    individual part def OralCavity_1 :> OralCavity;

    individual part def OralExamination_1 :> OralExamination {
        part :>> clinician : Clinician_1;
        part :>> patient : Patient_1;
        part :>> tongueDepressor : TongueDepressor_1;
        part :>> oralCavity : OralCavity_1;
    }

    individual action def OralExaminationProcedure_1 :> OralExaminationProcedure;

    individual part clinician_1 : Clinician_1;
    individual part patient_1 : Patient_1;
    individual part oralCavity_1 : OralCavity_1;
    individual part tongueDepressor_1 : TongueDepressor_1;

    individual part examination_1 : OralExamination_1 {
        part :>> clinician = clinician_1;
        part :>> patient = patient_1;
        part :>> tongueDepressor = tongueDepressor_1;
        part :>> oralCavity = oralCavity_1;
    }

    individual action examinationProcedure_1 : OralExaminationProcedure_1 {
        in clinician = clinician_1;
        in patient = patient_1;
        in depressor = tongueDepressor_1;
        in oralCavity = oralCavity_1;
    }

    individual requirement def MaterialSafetyRequirement_1 :> MaterialSafetyRequirement;
    individual requirement def DimensionalRequirement_1 :> DimensionalRequirement;
    individual requirement def ExaminationForceRequirement_1 :> ExaminationForceRequirement;

    individual requirement materialSafetyReq_1 : MaterialSafetyRequirement_1 {
        subject depressor = tongueDepressor_1;
    }
    individual requirement dimensionalReq_1 : DimensionalRequirement_1 {
        subject depressor = tongueDepressor_1;
    }
    individual requirement examinationForceReq_1 : ExaminationForceRequirement_1 {
        subject depressor = tongueDepressor_1;
    }
}
