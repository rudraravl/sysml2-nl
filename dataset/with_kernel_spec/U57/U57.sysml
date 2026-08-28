package DrYoungsIdealRectalDilatorSystem {

    private import ScalarValues::*;

    value type Diameter :> Real;
    value type Depth :> Real;
    value type Duration :> Real;
    value type ComfortScale :> Real;
    value type Volume :> Real;

    enum def MaterialKind {
        medicalGradeRubber;
        medicalGradeSilicone;
    }

    enum def SurfaceFinishKind {
        polished;
        smoothMatte;
    }

    item def Lubricant {
        attribute isSterile : Boolean = true;
        attribute isWaterSoluble : Boolean = true;
        attribute isHypoallergenic : Boolean = true;
        attribute volume : Volume;
    }

    part def Dilator {
        attribute diameter : Diameter;
        attribute length : Depth;
        attribute material : MaterialKind;
        attribute surfaceFinish : SurfaceFinishKind;
        attribute isSterilized : Boolean = false;
        attribute isLubricated : Boolean = false;
    }

    part def DilatorSet {
        part dilators : Dilator[4..12] ordered;
    }

    part def Patient {
        attribute hasConsent : Boolean = false;
        attribute comfortLevel : ComfortScale;
        attribute medicalCondition : String;
        attribute vitalSignsStable : Boolean = true;
        attribute anatomyAssessed : Boolean = false;
    }

    part def Clinician {
        attribute isCertified : Boolean = true;
        attribute specialty : String = "Proctology";
        attribute yearsOfExperience : Integer;
        attribute trainingCompleted : Boolean = true;
    }

    connection def ClinicianPatientInteraction {
        end clinicianEnd : Clinician;
        end patientEnd : Patient;
    }

    connection def DilatorApplication {
        end clinicianEnd : Clinician;
        end dilatorEnd : Dilator;
        end patientEnd : Patient;
    }

    action def PreparePatient;
    action def ConfirmConsent;
    action def AssessAnatomy;
    action def SelectStartingDilator;
    action def SterilizeInstrument;
    action def CoatWithLubricant;
    action def InsertDilator;
    action def MonitorPatient;
    action def HoldDilator;
    action def RemoveDilator;
    action def AssessProgression;
    action def ProvidePostCare;
    action def ScheduleFollowUp;

    state def TherapeuticProcedure {
        entry;
        then preparing;

        state preparing;
        transition preparing_to_inserting
            first preparing
            accept PatientPrepared
            then inserting;

        state inserting;
        transition inserting_to_holding
            first inserting
            accept InsertionComplete
            then holding;

        transition inserting_to_halted
            first inserting
            accept AdverseReaction
            then halted;

        state holding;
        transition holding_to_assessing
            first holding
            accept HoldDurationElapsed
            then assessing;

        transition holding_to_halted
            first holding
            accept AdverseReaction
            then halted;

        state assessing;
        transition assessing_to_preparing
            first assessing
            accept ProgressionApproved
            then preparing;

        transition assessing_to_concluding
            first assessing
            accept GoalAchieved
            then concluding;

        transition assessing_to_concluding_discomfort
            first assessing
            accept PatientCannotProceed
            then concluding;

        state halted;
        transition halted_to_concluding
            first halted
            accept PatientStabilized
            then concluding;

        state concluding;
        transition concluding_to_done
            first concluding
            accept ProcedureComplete
            then done;

        state done;
    }

    requirement def BiocompatibilityRequirement {
        doc /* All dilator materials must be biocompatible and safe for internal use. */
        subject dilator : Dilator;
        constraint {
            dilator.material == MaterialKind::medicalGradeRubber or
            dilator.material == MaterialKind::medicalGradeSilicone
        }
    }

    requirement def SurfaceFinishRequirement {
        doc /* Dilator surface must be highly polished or smooth matte. */
        subject dilator : Dilator;
        constraint {
            dilator.surfaceFinish == SurfaceFinishKind::polished or
            dilator.surfaceFinish == SurfaceFinishKind::smoothMatte
        }
    }

    requirement def SterilityRequirement {
        doc /* All instruments must be sterilized before use. */
        subject dilator : Dilator;
        constraint {
            dilator.isSterilized == true
        }
    }

    requirement def ConsentRequirement {
        doc /* Patient consent must be obtained and confirmed before procedure. */
        subject patient : Patient;
        constraint {
            patient.hasConsent == true
        }
    }

    requirement def ClinicianCertificationRequirement {
        doc /* Procedure must be performed by a certified and trained clinician. */
        subject clinician : Clinician;
        constraint {
            clinician.isCertified == true and
            clinician.trainingCompleted == true
        }
    }

    requirement def LubricantRequirement {
        doc /* Lubricant must be sterile, water-soluble, and hypoallergenic. */
        subject lubricant : Lubricant;
        constraint {
            lubricant.isSterile == true and
            lubricant.isWaterSoluble == true and
            lubricant.isHypoallergenic == true
        }
    }

    requirement def GraduatedSetRequirement {
        doc /* Dilator set must contain 4 to 12 dilators in increasing size order. */
        subject dilatorSet : DilatorSet;
    }

    requirement def ComfortMonitoringRequirement {
        doc /* Patient comfort and vital signs must be continuously monitored during insertion and holding. */
        subject patient : Patient;
        constraint {
            patient.comfortLevel >= 0.0 and
            patient.vitalSignsStable == true
        }
    }

    part def RectalDilatorSystem {
        part dilatorSet : DilatorSet {
            part dilator1 : Dilator {
                :>> diameter = 10;
                :>> length = 80;
                :>> material = MaterialKind::medicalGradeSilicone;
                :>> surfaceFinish = SurfaceFinishKind::polished;
                :>> isSterilized = true;
                :>> isLubricated = true;
            }
            part dilator2 : Dilator {
                :>> diameter = 13;
                :>> length = 85;
                :>> material = MaterialKind::medicalGradeSilicone;
                :>> surfaceFinish = SurfaceFinishKind::polished;
                :>> isSterilized = true;
                :>> isLubricated = true;
            }
            part dilator3 : Dilator {
                :>> diameter = 16;
                :>> length = 90;
                :>> material = MaterialKind::medicalGradeSilicone;
                :>> surfaceFinish = SurfaceFinishKind::polished;
                :>> isSterilized = true;
                :>> isLubricated = true;
            }
            part dilator4 : Dilator {
                :>> diameter = 19;
                :>> length = 95;
                :>> material = MaterialKind::medicalGradeSilicone;
                :>> surfaceFinish = SurfaceFinishKind::polished;
                :>> isSterilized = true;
                :>> isLubricated = true;
            }
            part dilator5 : Dilator {
                :>> diameter = 22;
                :>> length = 100;
                :>> material = MaterialKind::medicalGradeSilicone;
                :>> surfaceFinish = SurfaceFinishKind::polished;
                :>> isSterilized = true;
                :>> isLubricated = true;
            }
        }

        part lubricant : Lubricant {
            :>> isSterile = true;
            :>> isWaterSoluble = true;
            :>> isHypoallergenic = true;
            :>> volume = 120;
        }

        part patient : Patient {
            :>> hasConsent = true;
            :>> comfortLevel = 7.0;
            :>> medicalCondition = "Post-surgical stenosis";
            :>> vitalSignsStable = true;
            :>> anatomyAssessed = true;
        }

        part clinician : Clinician {
            :>> isCertified = true;
            :>> specialty = "Proctology";
            :>> yearsOfExperience = 10;
            :>> trainingCompleted = true;
        }

        connection clinicianPatientConn : ClinicianPatientInteraction
            connect clinician to patient;

        connection dilatorApplicationConn : DilatorApplication
            connect clinician to dilatorSet.dilator1 to patient;

        perform procedure : TherapeuticProcedure;

        requirement biocompatibilityReq : BiocompatibilityRequirement {
            subject dilator :> dilatorSet.dilator1;
        }
        requirement surfaceFinishReq : SurfaceFinishRequirement {
            subject dilator :> dilatorSet.dilator1;
        }
        requirement sterilityReq : SterilityRequirement {
            subject dilator :> dilatorSet.dilator1;
        }
        requirement consentReq : ConsentRequirement {
            subject patient :> patient;
        }
        requirement clinicianCertReq : ClinicianCertificationRequirement {
            subject clinician :> clinician;
        }
        requirement lubricantReq : LubricantRequirement {
            subject lubricant :> lubricant;
        }
        requirement graduatedSetReq : GraduatedSetRequirement {
            subject dilatorSet :> dilatorSet;
        }
        requirement comfortMonitoringReq : ComfortMonitoringRequirement {
            subject patient :> patient;
        }
    }
}
