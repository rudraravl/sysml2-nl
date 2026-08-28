package MedicalOralExamination {

    import ScalarValues::*;
    import ISQSpace::*;
    import ISQForce::*;
    import ISQMass::*;

    // ===== Value Types =====

    value type LengthUnit = Real { /mm }
    value type WidthUnit = Real { /mm }
    value type ThicknessUnit = Real { /mm }
    value type ForceUnit = Real { /N }
    value type DensityUnit = Real { /kg/m3 }
    value type PressureUnit = Real { /Pa }

    value type DepressorLength :> Real { /mm }
    value type DepressorWidth :> Real { /mm }
    value type DepressorThickness :> Real { /mm }
    value type AppliedForce :> Real { /N }
    value type WoodDensity :> Real { /kg/m3 }
    value type SplinterStrength :> Real { /Pa }

    // ===== Enumerations =====

    enum sterilityStatus { sterile, nonSterile }
    enum depressorState { packaged, ready, active, discarded }
    enum examinationPhase { notStarted, preparation, positioning, pressing, inspecting, withdrawing, completed }
    enum patientReadiness { notReady, ready, uncooperative }

    // ===== Item Definitions =====

    item def OralCavityView {
        attribute clarity : Real;
        attribute throatVisible : Boolean;
        attribute tongueDepressed : Boolean;
    }

    item def DiagnosticObservation {
        attribute observationText : String;
        attribute timestamp : String;
        attribute abnormalityDetected : Boolean;
    }

    item def PackagingMaterial {
        attribute materialType : String;
        attribute sealed : Boolean;
    }

    // ===== Part Definitions =====

    abstract part def HumanActor {
        port healthStatePort out Boolean;
        attribute name : String;
    }

    part def Clinician :> HumanActor {
        attribute role : String = "Medical Examiner";
        attribute gloved : Boolean;
        attribute trained : Boolean;

        action performExamination {
            in depressor : TongueDepressor;
            in patient : Patient;
            out observation : DiagnosticObservation;
        }
    }

    part def Patient :> HumanActor {
        attribute ageYears : Integer;
        attribute cooperative : Boolean;
        attribute mouthOpen : Boolean;
        attribute tongueExtended : Boolean;

        port mouthPort out OralCavityView;

        action cooperate {
            out readiness : patientReadiness;
        }
    }

    part def TongueDepressor {
        // Physical attributes
        attribute totalLength : DepressorLength = 150 [/mm];
        attribute totalWidth : DepressorWidth = 18 [/mm];
        attribute attribute_thickness : DepressorThickness = 2 [/mm];
        attribute materialDensity : WoodDensity = 600 [/kg/m3];
        attribute grainOrientation : String = "longitudinal";
        attribute materialType : String = "birch wood";
        attribute nonToxic : Boolean = true;
        attribute maxSplinterPressure : SplinterStrength = 25e6 [/Pa];

        // State
        attribute currentSterility : sterilityStatus = sterile;
        attribute currentState : depressorState = packaged;
        attribute useCount : Integer = 0;

        // Sub-parts
        part blade : Blade {
            attribute bladeLength : DepressorLength = 110 [/mm];
            attribute bladeWidth : DepressorWidth = 18 [/mm];
            attribute surfaceFinish : String = "smooth";
            attribute roundedEdges : Boolean = true;
        }

        part handle : Handle {
            attribute handleLength : DepressorLength = 40 [/mm];
            attribute handleWidth : DepressorWidth = 18 [/mm];
            attribute gripTexture : String = "textured";
        }

        port bladeContactPort out Boolean;
        port handleGripPort in Boolean;

        // Lifecycle state machine
        state depressorLifecycle {
            entry; then packagedState;

            state packagedState {
                entry;
                attribute currentState = packaged;
                attribute currentSterility = sterile;
            }

            transition from packagedState to readyState
                when (packagingOpened == true);

            state readyState {
                entry;
                attribute currentState = ready;
                attribute currentSterility = sterile;
            }

            transition from readyState to activeState
                when (inUse == true);

            state activeState {
                entry;
                attribute currentState = active;
                attribute useCount = 1;
            }

            transition from activeState to discardedState
                when (examinationComplete == true);

            state discardedState {
                entry;
                attribute currentState = discarded;
                attribute currentSterility = nonSterile;
            }
        }

        attribute packagingOpened : Boolean = false;
        attribute inUse : Boolean = false;
        attribute examinationComplete : Boolean = false;

        action applyForce {
            in force : AppliedForce;
            out applied : Boolean;
        }
    }

    part def Blade {
        attribute bladeLength : DepressorLength;
        attribute bladeWidth : DepressorWidth;
        attribute surfaceFinish : String;
        attribute roundedEdges : Boolean;
    }

    part def Handle {
        attribute handleLength : DepressorLength;
        attribute handleWidth : DepressorWidth;
        attribute gripTexture : String;
    }

    part def ExaminationEnvironment {
        attribute lightingLux : Real;
        attribute sanitized : Boolean;
        attribute wasteDisposalAvailable : Boolean;
    }

    // ===== Requirements =====

    requirement def SafetyRequirement {
        doc /* The tongue depressor must be safe for patient contact. */
    }

    requirement NonToxicMaterialRequirement : SafetyRequirement {
        doc /* The material of the tongue depressor must be non-toxic. */
        subject depressor : TongueDepressor;
        constraint { depressor.nonToxic == true }
        constraint { depressor.materialType == "birch wood" }
    }

    requirement SplinterResistanceRequirement : SafetyRequirement {
        doc /* The tongue depressor must not splinter under the applied examination force. */
        subject depressor : TongueDepressor;
        attribute appliedForce : AppliedForce = 2.5 [/N];
        attribute contactArea : Real = 18 * 2; // mm^2 approx
        constraint { depressor.maxSplinterPressure > (appliedForce / (contactArea * 1e-6)) }
    }

    requirement SterilityRequirement : SafetyRequirement {
        doc /* The tongue depressor must be sterile when packaged and single-use only. */
        subject depressor : TongueDepressor;
        constraint { depressor.currentSterility == sterile when depressor.currentState == packaged }
        constraint { depressor.useCount <= 1 }
    }

    requirement def FunctionalRequirement {
        doc /* The tongue depressor must function effectively for oral examination. */
    }

    requirement DimensionalRequirement : FunctionalRequirement {
        doc /* The tongue depressor must have correct dimensions for oral examination. */
        subject depressor : TongueDepressor;
        constraint { depressor.totalLength == 150 [/mm] }
        constraint { depressor.totalWidth == 18 [/mm] }
        constraint { depressor.attribute_thickness == 2 [/mm] }
    }

    requirement BladeSmoothnessRequirement : FunctionalRequirement {
        doc /* The blade must be smooth to avoid injury to the patient's tongue. */
        subject depressor : TongueDepressor;
        constraint { depressor.blade.surfaceFinish == "smooth" }
        constraint { depressor.blade.roundedEdges == true }
    }

    requirement ForceApplicationRequirement : FunctionalRequirement {
        doc /* The clinician must apply approximately 2.5 N of sustained force. */
        subject clinician : Clinician;
        attribute targetForce : AppliedForce = 2.5 [/N];
        attribute tolerance : AppliedForce = 0.5 [/N];
        constraint { targetForce >= 2.0 [/N] and targetForce <= 3.0 [/N] }
    }

    requirement DisposableDesignRequirement : FunctionalRequirement {
        doc /* The tongue depressor is designed for single use to prevent cross-contamination. */
        subject depressor : TongueDepressor;
        constraint { depressor.useCount == 1 }
        constraint { depressor.currentState == discarded after depressor.currentState == active }
    }

    requirement ExaminationEffectivenessRequirement : FunctionalRequirement {
        doc /* The examination must provide a clear view of the oral cavity and throat. */
        subject view : OralCavityView;
        constraint { view.throatVisible == true }
        constraint { view.tongueDepressed == true }
    }

    // ===== Examination Process Behavior =====

    action def OralExaminationProcess {
        in clinician : Clinician;
        in patient : Patient;
        in depressor : TongueDepressor;
        in environment : ExaminationEnvironment;
        out observation : DiagnosticObservation;

        attribute currentPhase : examinationPhase = notStarted;
        attribute appliedForce : AppliedForce = 2.5 [/N];

        // Preparation
        action verifySterility {
            out sterile : Boolean;
        }

        action verifyPatientReadiness {
            out ready : patientReadiness;
        }

        // Positioning
        action positionDepressor {
            in depressor : TongueDepressor;
            in patient : Patient;
            out positioned : Boolean;
        }

        // Pressing
        action applySustainedForce {
            in depressor : TongueDepressor;
            in force : AppliedForce;
            out tongueDepressed : Boolean;
        }

        // Inspecting
        action performVisualInspection {
            in patient : Patient;
            out view : OralCavityView;
        }

        // Withdrawing
        action withdrawDepressor {
            in depressor : TongueDepressor;
            out withdrawn : Boolean;
        }

        // Discarding
        action discardDepressor {
            in depressor : TongueDepressor;
            out discarded : Boolean;
        }

        // Control flow
        first verifySterility;
        then verifyPatientReadiness;
        then positionDepressor;
        then applySustainedForce;
        then performVisualInspection;
        then withdrawDepressor;
        then discardDepressor;

        // State machine for examination process
        state examinationStateMachine {
            entry; then notStartedState;

            state notStartedState {
                entry;
                attribute currentPhase = notStarted;
            }

            transition from notStartedState to preparationState
                when (examinationInitiated == true);

            state preparationState {
                entry;
                attribute currentPhase = preparation;
            }

            transition from preparationState to positioningState
                when (depressor.currentSterility == sterile and patientReady == true);

            state positioningState {
                entry;
                attribute currentPhase = positioning;
            }

            transition from positioningState to pressingState
                when (depressorPositioned == true);

            state pressingState {
                entry;
                attribute currentPhase = pressing;
                attribute depressor.inUse = true;
                attribute depressor.currentState = active;
            }

            transition from pressingState to inspectingState
                when (tongueHeld == true);

            state inspectingState {
                entry;
                attribute currentPhase = inspecting;
            }

            transition from inspectingState to withdrawingState
                when (inspectionDone == true);

            state withdrawingState {
                entry;
                attribute currentPhase = withdrawing;
                attribute depressor.inUse = false;
            }

            transition from withdrawingState to completedState
                when (depressorWithdrawn == true);

            state completedState {
                entry;
                attribute currentPhase = completed;
                attribute depressor.examinationComplete = true;
                attribute depressor.currentState = discarded;
                attribute depressor.currentSterility = nonSterile;
            }
        }

        attribute examinationInitiated : Boolean = false;
        attribute patientReady : Boolean = false;
        attribute depressorPositioned : Boolean = false;
        attribute tongueHeld : Boolean = false;
        attribute inspectionDone : Boolean = false;
        attribute depressorWithdrawn : Boolean = false;
    }

    // ===== Top-level System Part =====

    part OralExaminationSystem {
        part clinician : Clinician {
            attribute name = "Dr. Smith";
            attribute gloved = true;
            attribute trained = true;
        }

        part patient : Patient {
            attribute name = "Patient A";
            attribute ageYears = 35;
            attribute cooperative = true;
            attribute mouthOpen = false;
            attribute tongueExtended = false;
        }

        part tongueDepressor : TongueDepressor {
            redef totalLength = 150 [/mm];
            redef totalWidth = 18 [/mm];
            redef attribute_thickness = 2 [/mm];
            redef materialDensity = 600 [/kg/m3];
        }

        part environment : ExaminationEnvironment {
            attribute lightingLux = 1000;
            attribute sanitized = true;
            attribute wasteDisposalAvailable = true;
        }

        // Connections
        connection clinicianGrip connect clinician to tongueDepressor.handleGripPort;
        connection bladeContact connect tongueDepressor.bladeContactPort to patient.mouthPort;

        // Satisfy requirements
        satisfy NonToxicMaterialRequirement by tongueDepressor;
        satisfy SplinterResistanceRequirement by tongueDepressor;
        satisfy SterilityRequirement by tongueDepressor;
        satisfy DimensionalRequirement by tongueDepressor;
        satisfy BladeSmoothnessRequirement by tongueDepressor;
        satisfy ForceApplicationRequirement by clinician;
        satisfy DisposableDesignRequirement by tongueDepressor;
        satisfy ExaminationEffectivenessRequirement by patient.mouthPort;

        // Perform examination
        perform OralExaminationProcess {
            in clinician = clinician;
            in patient = patient;
            in depressor = tongueDepressor;
            in environment = environment;
        }
    }

}
