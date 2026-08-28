package IdealRectalDilatorSystem {
    import ScalarValues::*;

    // ---- Value Types with Units ----
    value type Length :> Real { unit "mm"; }
    value type Diameter :> Real { unit "mm"; }
    value type Volume :> Real { unit "mL"; }
    value type Duration :> Real { unit "min"; }
    value type Pressure :> Real {> Real { unit "kPa"; }
    value type PainLevel :> Integer;
    value type HeartRate :> Real { unit "bpm"; }
    value type Temperature :> Real { unit "degC"; }

    // ---- Enumerations ----
    enum MaterialType { medicalGradeHardRubber, medicalGradeSilicone }
    enum SurfaceFinish { polished, smoothMatte }
    enum MedicalCondition { stricture, hemorrhoids, postSurgicalStenosis }
    enum AdverseReaction { none, mildDiscomfort, significantDiscomfort, bleeding, vasovagalResponse }
    enum ProcedureStatus { notStarted, preparing, instrumentPreparation, insertion, holding, evaluation, removal, progressionDecision, halted, completed }
    enum ConsentStatus { pending, given, withdrawn }

    // ---- Item Definitions ----
    item def BiocompatibleMaterial {
        attribute materialType : MaterialType;
        attribute biocompatible : Boolean = true;
        attribute nonToxic : Boolean = true;
        attribute latexFree : Boolean = true;
    }

    item def SterileLubricant {
        attribute waterSoluble : Boolean = true;
        attribute hypoallergenic : Boolean = true;
        attribute sterile : Boolean = true;
        attribute volume : Volume = 100 [mL];
        attribute storageTemperature : Temperature = 25 [degC];
    }

    item def TreatmentPlan {
        attribute startingDilatorIndex : Integer;
        attribute targetDilatorIndex : Integer;
        attribute holdDuration : Duration = 5 [min];
        attribute insertionDepth : Length;
        attribute sessionGoal : String;
    }

    item def VitalSigns {
        attribute heartRate : HeartRate;
        attribute painLevel : PainLevel;
        attribute reaction : AdverseReaction;
    }

    // ---- Port Definitions ----
    port def AnalCanalPort {
        attribute depth : Length;
        attribute currentDiameter : Diameter;
    }

    port def VitalSignsPort {
        out attribute vitalSigns : VitalSigns;
    }

    port def DilatorHandlePort {
        attribute gripDiameter : Diameter;
    }

    port def DilatorTipPort {
        attribute tipDiameter : Diameter;
    }

    // ---- Part Definitions ----
    part def Dilator {
        attribute index : Integer;
        attribute diameter : Diameter;
        attribute length : Length;
        attribute tipDiameter : Diameter;
        attribute material : BiocompatibleMaterial;
        attribute surfaceFinish : SurfaceFinish;
        attribute sterilized : Boolean = false;
        attribute lubricated : Boolean = false;
        attribute inUse : Boolean = false;

        port handlePort : DilatorHandlePort;
        port tipPort : DilatorTipPort;

        action sterilize {
            assign sterilized = true;
        }

        action coatWithLubricant {
            assign lubricated = true;
        }

        action clean {
            assign sterilized = false;
            assign lubricated = false;
            assign inUse = false;
        }
    }

    part def DilatorSet {
        attribute count : Integer = 12;
        attribute minCount : Integer = 4;
        attribute maxCount : Integer = 12;
        part dilators : Dilator[4..12] ordered;

        action selectStartingDilator(condition : MedicalCondition, anatomyDepth : Length) : Dilator {
            // Select smallest appropriate dilator based on condition and anatomy
        }

        action getNextLargerDilator(current : Dilator) : Dilator {
            // Return next larger dilator in graduated set
        }

        action verifyGraduation {
            // Verify dilators are ordered by increasing size
        }
    }

    part def Patient {
        attribute identifier : String;
        attribute condition : MedicalCondition;
        attribute consentStatus : ConsentStatus = pending;
        attribute painLevel : PainLevel = 0;
        attribute heartRate : HeartRate = 72 [bpm];
        attribute toleranceThreshold : PainLevel = 6;
        attribute anatomyDepth : Length;
        attribute currentStrictureDiameter : Diameter;

        port analCanal : AnalCanalPort;
        port vitalSignsOut : VitalSignsPort;

        action giveConsent {
            assign consentStatus = given;
        }

        action withdrawConsent {
            assign consentStatus = withdrawn;
        }

        action reportDiscomfort(level : PainLevel) {
            assign painLevel = level;
        }

        action updateVitalSigns(hr : HeartRate, level : PainLevel, react : AdverseReaction) {
            assign heartRate = hr;
            assign painLevel = level;
        }

        action evaluateResponse() : AdverseReaction {
            if painLevel > toleranceThreshold then {
                return significantDiscomfort;
            } else {
                return none;
            }
        }
    }

    part def Clinician {
        attribute identifier : String;
        attribute certified : Boolean = true;
        attribute specialty : String = "Proctologist";
        attribute trainingCompleted : Boolean = true;
        attribute experienceYears : Real;
        attribute licenseNumber : String;

        action preparePatient(p : Patient) {
            // Position patient, explain procedure
        }

        action confirmConsent(p : Patient) {
            // Verify informed consent
        }

        action assessAnatomy(p : Patient) : Length {
            // Measure and assess patient anatomy
        }

        action createTreatmentPlan(p : Patient, condition : MedicalCondition) : TreatmentPlan {
            // Create individualized treatment plan
        }

        action selectDilator(set : DilatorSet, plan : TreatmentPlan) : Dilator {
            // Select starting dilator
        }

        action sterilizeInstrument(d : Dilator) {
            d.sterilize();
        }

        action lubricateInstrument(d : Dilator, lub : SterileLubricant) {
            d.coatWithLubricant();
        }

        action insertDilator(d : Dilator, p : Patient, depth : Length) {
            assign d.inUse = true;
            // Gently insert to specified depth
        }

        action holdDilator(d : Dilator, duration : Duration) {
            // Hold in place for tissue adaptation
        }

        action monitorPatient(p : Patient) : VitalSigns {
            // Continuously monitor comfort and vital signs
        }

        action removeDilator(d : Dilator) {
            assign d.inUse = false;
        }

        action assessProgression(p : Patient, plan : TreatmentPlan) : Boolean {
            if p.painLevel <= p.toleranceThreshold then {
                return true;
            } else {
                return false;
            }
        }

        action providePostProcedureCare(p : Patient) {
            // Provide care instructions
        }

        action scheduleFollowUp(p : Patient) {
            // Schedule follow-up appointment
        }

        action haltProcedure {
            // Emergency halt
        }
    }

    // ---- Main System ----
    part def IdealRectalDilatorSystem {
        part dilatorSet : DilatorSet {
            redefines count = 12;
        }
        part lubricant : SterileLubricant;
        part patient : Patient;
        part clinician : Clinician;

        connection vitalSignsFlow : Patient.vitalSignsOut ~> Clinician;
        connection clinicianToPatient : Clinician ~> Patient.analCanal;

        attribute sessionStatus : ProcedureStatus = notStarted;
        attribute currentDilatorIndex : Integer = 0;
        attribute sessionHoldDuration : Duration = 5 [min];
        attribute sessionInsertionDepth : Length = 75 [mm];

        // ---- State Machine ----
        state def ProcedureStateMachine {
            initial state NotStarted;

            state Preparing {
                entry action {
                    clinician.preparePatient(patient);
                    clinician.confirmConsent(patient);
                    clinician.assessAnatomy(patient);
                    clinician.createTreatmentPlan(patient, patient.condition);
                }
            }

            state InstrumentPreparation {
                entry action {
                    clinician.selectDilator(dilatorSet, clinician.createTreatmentPlan(patient, patient.condition));
                    clinician.sterilizeInstrument(dilatorSet.dilators[currentDilatorIndex]);
                    clinician.lubricateInstrument(dilatorSet.dilators[currentDilatorIndex], lubricant);
                }
            }

            state Insertion {
                entry action {
                    clinician.insertDilator(dilatorSet.dilators[currentDilatorIndex], patient, sessionInsertionDepth);
                }
                do action {
                    clinician.monitorPatient(patient);
                }
            }

            state Holding {
                entry action {
                    clinician.holdDilator(dilatorSet.dilators[currentDilatorIndex], sessionHoldDuration);
                }
                do action {
                    clinician.monitorPatient(patient);
                }
            }

            state Evaluation {
                entry action {
                    clinician.monitorPatient(patient);
                }
            }

            state Removal {
                entry action {
                    clinician.removeDilator(dilatorSet.dilators[currentDilatorIndex]);
                }
            }

            state ProgressionDecision {
                // Decide whether to progress to next dilator
            }

            state Halted {
                entry action {
                    clinician.haltProcedure();
                    clinician.removeDilator(dilatorSet.dilators[currentDilatorIndex]);
                    clinician.providePostProcedureCare(patient);
                }
            }

            state Completed {
                entry action {
                    clinician.providePostProcedureCare(patient);
                    clinician.scheduleFollowUp(patient);
                }
            }

            final state Terminated;

            transition from NotStarted to Preparing;
            transition from Preparing to InstrumentPreparation
                if patient.consentStatus == given;
            transition from Preparing to Halted
                if patient.consentStatus == withdrawn;
            transition from InstrumentPreparation to Insertion;
            transition from Insertion to Holding;
            transition from Holding to Evaluation;
            transition from Evaluation to Removal;
            transition from Removal to ProgressionDecision;
            transition from ProgressionDecision to InstrumentPreparation
                if clinician.assessProgression(patient, clinician.createTreatmentPlan(patient, patient.condition)) == true
                and currentDilatorIndex < dilatorSet.count - 1 {
                    assign currentDilatorIndex = currentDilatorIndex + 1;
                };
            transition from ProgressionDecision to Completed
                if currentDilatorIndex >= dilatorSet.count - 1
                or clinician.assessProgression(patient, clinician.createTreatmentPlan(patient, patient.condition)) == false;
            transition from Insertion to Halted
                if patient.painLevel > patient.toleranceThreshold;
            transition from Holding to Halted
                if patient.painLevel > patient.toleranceThreshold;
            transition from Evaluation to Halted
                if patient.painLevel > patient.toleranceThreshold;
            transition from Completed to Terminated;
            transition from Halted to Terminated;
        }

        part procedureController : ProcedureStateMachine;

        // ---- Requirements ----
        requirement def SafetyRequirement {
            doc "The system must ensure patient safety and comfort throughout the procedure.";
        }

        requirement def ConsentRequirement {
            doc "Patient consent must be obtained and confirmed before any procedure begins.";
            constraint { patient.consentStatus == given }
        }

        requirement def ClinicianQualificationRequirement {
            doc "Procedure must be performed by a certified and trained medical professional.";
            constraint { clinician.certified == true }
            constraint { clinician.trainingCompleted == true }
            constraint { clinician.specialty == "Proctologist" }
        }

        requirement def GraduatedDilatorSetRequirement {
            doc "Dilator set must contain between 4 and 12 graduated dilators in order of increasing size.";
            constraint { dilatorSet.count >= dilatorSet.minCount }
            constraint { dilatorSet.count <= dilatorSet.maxCount }
        }

        requirement def BiocompatibleMaterialRequirement {
            doc "All dilators must be manufactured from biocompatible materials such as medical-grade hard rubber or silicone.";
            constraint { dilatorSet.dilators.material.biocompatible == true }
            constraint { dilatorSet.dilators.material.materialType == MaterialType::medicalGradeHardRubber
                or dilatorSet.dilators.material.materialType == MaterialType::medicalGradeSilicone }
        }

        requirement def SurfaceFinishRequirement {
            doc "Dilators must feature a highly polished or smooth matte surface finish for patient safety and comfort.";
            constraint { dilatorSet.dilators.surfaceFinish == SurfaceFinish::polished
                or dilatorSet.dilators.surfaceFinish == SurfaceFinish::smoothMatte }
        }

        requirement def LubricantRequirement {
            doc "The system must include a sterile, water-soluble, and hypoallergenic lubricant.";
            constraint { lubricant.sterile == true }
            constraint { lubricant.waterSoluble == true }
            constraint { lubricant.hypoallergenic == true }
        }

        requirement def HaltOnDiscomfortRequirement {
            doc "The procedure must be halted immediately if the patient experiences significant discomfort or adverse reaction.";
            constraint { patient.painLevel <= patient.toleranceThreshold }
        }

        requirement def SterilizationRequirement {
            doc "Each dilator must be sterilized before use.";
            constraint { dilatorSet.dilators.sterilized == true }
        }

        requirement def LubricationRequirement {
            doc "Each dilator must be coated with sterile lubricant before insertion.";
            constraint { dilatorSet.dilators.lubricated == true }
        }

        requirement def ControlledInsertionRequirement {
            doc "Dilator insertion must be gentle and controlled to a specified depth.";
            constraint { sessionInsertionDepth <= patient.anatomyDepth }
        }

        requirement def HoldDurationRequirement {
            doc "Dilator must be held in place for a prescribed duration to allow tissue stretching and adaptation.";
            constraint { sessionHoldDuration >= 1 [min] }
            constraint { sessionHoldDuration <= 30 [min] }
        }

        requirement def PostProcedureCareRequirement {
            doc "Post-procedure care instructions and follow-up scheduling must be provided upon completion.";
        }

        requirement safetyReq : SafetyRequirement;
        requirement consentReq : ConsentRequirement;
        requirement clinicianReq : ClinicianQualificationRequirement;
        requirement dilatorSetReq : GraduatedDilatorSetRequirement;
        requirement materialReq : BiocompatibleMaterialRequirement;
        requirement surfaceReq : SurfaceFinishRequirement;
        requirement lubricantReq : LubricantRequirement;
        requirement haltReq : HaltOnDiscomfortRequirement;
        requirement sterilizationReq : SterilizationRequirement;
        requirement lubricationReq : LubricationRequirement;
        requirement insertionReq : ControlledInsertionRequirement;
        requirement holdDurReq : HoldDurationRequirement;
        requirement postCareReq : PostProcedureCareRequirement;

        // Requirement satisfactions
        satisfy consentReq by procedureController.Preparing.confirmConsent;
        satisfy sterilizationReq by Dilator.sterilize;
        satisfy lubricationReq by Dilator.coatWithLubricant;
        satisfy haltReq by procedureController.Halted;
        satisfy postCareReq by procedureController.Completed;
    }
}
