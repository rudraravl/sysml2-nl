package 'Deep Tendon Reflex Examination System' {
    private import ScalarValues::*;
    private import SI::*;
    private import ISQ::*;

    enum def TendonType {
        patellar;
        achilles;
        biceps;
    }

    enum def ReflexGrade {
        absent = 0;
        hypoactive = 1;
        normal = 2;
        brisk = 3;
        hyperactive = 4;
    }

    value type def HardnessValue :> ScalarValues::Real;
    value type def ForceValue :> ScalarValues::Real;
    value type def MagnitudeValue :> ScalarValues::Real;

    port def GripInterface;
    port def StrikeInterface;
    port def ResponseInterface;

    part def HammerHead {
        doc /* Rubber head delivering safe but effective impact to tendon. */
        attribute material : String = "Medical-grade rubber";
        attribute hardness : HardnessValue = 50;
        attribute diameter : ISQ::LengthValue = 0.025 [m];
    }

    part def HammerHandle {
        doc /* Ergonomic handle with textured grip to minimize clinician fatigue. */
        attribute material : String = "Stainless steel";
        attribute gripType : String = "Textured";
        attribute length : ISQ::LengthValue = 0.15 [m];
        attribute diameter : ISQ::LengthValue = 0.02 [m];
    }

    part def ReflexHammer {
        doc /* Balanced reflex hammer composed of head and handle. */
        attribute mass : ISQ::MassValue = 0.15 [kg];
        attribute length : ISQ::LengthValue = 0.30 [m];
        part head : HammerHead;
        part handle : HammerHandle;
        port gripPort : GripInterface;
        port strikePort : StrikeInterface;
    }

    part def Patient {
        attribute targetTendon : TendonType = TendonType::patellar;
        port tendonPort : StrikeInterface;
        port responsePort : ResponseInterface;
    }

    part def Clinician {
        port handPort : GripInterface;
        port observationPort : ResponseInterface;
    }

    action def PerformReflexExamination {
        in clinician : Clinician;
        in patient : Patient;
        in hammer : ReflexHammer;
        in targetTendon : TendonType;

        action positionHammer;
        then action strikeTendon {
            out strikeForce : ForceValue;
        }
        then action elicitReflex {
            in strikeForce : ForceValue;
            out reflexLatency : ISQ::DurationValue;
            out reflexMagnitude : MagnitudeValue;
        }
        then action observeResponse {
            in reflexLatency : ISQ::DurationValue;
            in reflexMagnitude : MagnitudeValue;
        }
        then action gradeResponse {
            in reflexLatency : ISQ::DurationValue;
            in reflexMagnitude : MagnitudeValue;
            out grade : ReflexGrade;
        }
    }

    state def ExaminationWorkflow {
        state Ready;
        state Positioning;
        state Striking;
        state Observing;
        state Grading;
        state Complete;

        transition from Ready to Positioning;
        transition from Positioning to Striking;
        transition from Striking to Observing;
        transition from Observing to Grading;
        transition from Grading to Complete;
    }

    requirement def HammerBalanceRequirement {
        doc /* The hammer shall be balanced for precise handling. */
        attribute mass : ISQ::MassValue;
        attribute length : ISQ::LengthValue;
        constraint { mass >= 0.12 [kg] and mass <= 0.20 [kg] }
        constraint { length >= 0.25 [m] and length <= 0.35 [m] }
    }

    requirement def HeadHardnessRequirement {
        doc /* The head shall be medical-grade rubber with safe but effective hardness. */
        attribute hardness : HardnessValue;
        constraint { hardness >= 40 and hardness <= 60 }
    }

    requirement def HandleErgonomicsRequirement {
        doc /* The handle shall be ergonomically designed to minimize fatigue. */
        attribute gripType : String;
        attribute length : ISQ::LengthValue;
        constraint { gripType == "Textured" }
        constraint { length >= 0.12 [m] and length <= 0.18 [m] }
    }

    requirement def ReflexGradingRequirement {
        doc /* The response shall be graded on a standard five-point clinical scale. */
        attribute grade : ReflexGrade;
    }

    requirement def ProcedureRequirement {
        doc /* The clinician shall deliver a controlled strike to elicit a reflex. */
    }

    part def ReflexExamSystem {
        part clinician : Clinician;
        part patient : Patient;
        part hammer : ReflexHammer;
        connect clinician.handPort to hammer.gripPort;
        connect hammer.strikePort to patient.tendonPort;
        connect patient.responsePort to clinician.observationPort;
        action exam : PerformReflexExamination;
    }

    part reflexExamSystem : ReflexExamSystem {
        part :>> clinician : Clinician;
        part :>> patient : Patient {
            :>> targetTendon = TendonType::patellar;
        }
        part :>> hammer : ReflexHammer {
            part :>> head : HammerHead {
                :>> hardness = 50;
            }
            part :>> handle : HammerHandle {
                :>> length = 0.15 [m];
            }
            :>> mass = 0.15 [kg];
            :>> length = 0.30 [m];
        }

        satisfy HammerBalanceRequirement by hammer;
        satisfy HeadHardnessRequirement by hammer.head;
        satisfy HandleErgonomicsRequirement by hammer.handle;
        satisfy ProcedureRequirement by clinician;

        perform action :>> exam {
            in :>> clinician = clinician;
            in :>> patient = patient;
            in :>> hammer = hammer;
            in :>> targetTendon = patient.targetTendon;

            action :>> strikeTendon {
                out :>> strikeForce = 5.0;
            }
            action :>> elicitReflex {
                in :>> strikeForce = exam.strikeTendon.strikeForce;
                out :>> reflexLatency = 0.05 [s];
                out :>> reflexMagnitude = 0.8;
            }
            action :>> observeResponse {
                in :>> reflexLatency = exam.elicitReflex.reflexLatency;
                in :>> reflexMagnitude = exam.elicitReflex.reflexMagnitude;
            }
            action :>> gradeResponse {
                in :>> reflexLatency = exam.elicitReflex.reflexLatency;
                in :>> reflexMagnitude = exam.elicitReflex.reflexMagnitude;
                out :>> grade = ReflexGrade::normal;
            }
        }

        satisfy ReflexGradingRequirement by exam;

        perform ExaminationWorkflow;
    }

    individual def TestSession :> ReflexExamSystem;
    individual def TestPatient :> Patient;
    individual def TestClinician :> Clinician;
    individual def TestHammer :> ReflexHammer;

    individual testSession : TestSession :> reflexExamSystem {
        :>> clinician : TestClinician;
        :>> patient : TestPatient;
        :>> hammer : TestHammer;

        timeslice patellarExam {
            perform action :>> exam {
                in :>> targetTendon = TendonType::patellar;
            }
        }
        then timeslice achillesExam {
            perform action :>> exam {
                in :>> targetTendon = TendonType::achilles;
            }
        }
    }
}
