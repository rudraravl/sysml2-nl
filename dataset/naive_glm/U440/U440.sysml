package VaginalDilationTherapySystem {
    import ScalarValues::*;
    import ISQ::*;

    // ============================================================
    // Value Types with Units
    // ============================================================
    value type DiameterValue :> Real { unit = 'mm'; }
    value type LengthValue :> Real { unit = 'mm'; }
    value type DurationValue :> Real { unit = 'min'; }
    value type FrequencyValue :> Real { unit = 'sessions/week'; }
    value type PHValue :> Real { unit = 'pH'; }
    value type ComfortScore :> Real { unit = 'score'; }
    value type TemperatureValue :> Real { unit = 'degC'; }
    value type InsertionForceValue :> Real { unit = 'N'; }
    value type VolumeValue :> Real { unit = 'mL'; }
    value type SessionCountValue :> Integer;
    value type WeekNumberValue :> Integer;

    // ============================================================
    // Enumerations
    // ============================================================
    enum DilatorSize {
        size1,
        size2,
        size3,
        size4,
        size5
    }

    enum SessionStatus {
        pending,
        preparing,
        assessing,
        dilating,
        cleaning,
        completed,
        postponed,
        aborted
    }

    enum CleaningState {
        dirty,
        washed,
        sterilized
    }

    enum PatientReadiness {
        notReady,
        ready,
        uncomfortable
    }

    enum TissueResponse {
        relaxed,
        resistant,
        irritated
    }

    enum MaterialType {
        medicalGradeSilicone,
        medicalGradePlastic,
        medicalGradeGlass
    }

    // ============================================================
    // Item Definitions
    // ============================================================
    item def BiocompatibleCoating {
        attribute materialName : String;
        attribute isHypoallergenic : Boolean;
        attribute isBiocompatible : Boolean;
        attribute thicknessMicrons : Real;
    }

    item def MedicalGradeLubricant {
        attribute pH : PHValue;
        attribute volume : VolumeValue;
        attribute isWaterBased : Boolean;
        attribute isPHBalanced : Boolean;
        attribute isFragranceFree : Boolean;
        attribute isGlycerinFree : Boolean;
    }

    item def LubricantApplicationAmount {
        attribute volume : VolumeValue;
        attribute coveragePercent : Real;
    }

    item def SessionRecord {
        attribute sessionNumber : SessionCountValue;
        attribute date : String;
        attribute dilatorSizeUsed : DilatorSize;
        attribute duration : DurationValue;
        attribute comfortScore : ComfortScore;
        attribute tissueResponse : TissueResponse;
        attribute status : SessionStatus;
    }

    // ============================================================
    // Port Definitions
    // ============================================================
    port def DilatorSelectionPort {
        out item selectedDilatorSize : DilatorSize;
        out item selectedDilator : VaginalDilator;
    }

    port def LubricantDispensingPort {
        out item dispensedLubricant : MedicalGradeLubricant;
    }

    port def LubricantReceivingPort {
        in item appliedLubricant : MedicalGradeLubricant;
    }

    port def ComfortReportingPort {
        out item readiness : PatientReadiness;
        out item comfortScore : ComfortScore;
        out item tissueResponse : TissueResponse;
    }

    port def ComfortListeningPort {
        in item patientReadiness : PatientReadiness;
        in item patientComfortScore : ComfortScore;
    }

    port def InsertionForcePort {
        out item appliedForce : InsertionForceValue;
    }

    port def TissueResponsePort {
        out item tissueResponse : TissueResponse;
    }

    port def ProtocolInstructionPort {
        out item sessionDuration : DurationValue;
        out item sessionFrequency : FrequencyValue;
        out item recommendedSize : DilatorSize;
        out item progressionApproved : Boolean;
    }

    port def ProtocolListeningPort {
        in item currentSize : DilatorSize;
        in item sessionsCompleted : SessionCountValue;
        in item patientComfortScore : ComfortScore;
    }

    port def CleaningStatusPort {
        out item cleaningState : CleaningState;
    }

    // ============================================================
    // Part Definitions
    // ============================================================
    part def VaginalDilator {
        attribute size : DilatorSize;
        attribute diameter : DiameterValue;
        attribute totalLength : LengthValue;
        attribute insertionLength : LengthValue;
        attribute handleLength : LengthValue;
        attribute isTapered : Boolean;
        attribute materialType : MaterialType;
        attribute coating : BiocompatibleCoating;
        attribute cleaningState : CleaningState;
        attribute isSterile : Boolean;
        attribute isLubricated : Boolean;

        port lubricantReceivingPort : LubricantReceivingPort;
        port insertionForcePort : InsertionForcePort;
        port cleaningStatusPort : CleaningStatusPort;

        action def applyLubricant(lubricant : MedicalGradeLubricant) {
            // Apply water-based lubricant to tapered body
        }
