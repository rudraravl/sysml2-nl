package Angellift {

    import SI::*;
    import ScalarValues::*;

    // ---------- Value Types ----------
    value type ForceValue :> N;
    value type PressureValue :> Pa;
    value type LengthValue :> mm;
    value type DepthValue :> mm;
    value type DurationValue :> d;
    value type WrinkleDepthValue :> mm;
    value type FlexibilityIndex :> Real;
    value type AdhesionIndex :> Real;
    value type ResponseScore :> Real;
    value type ReductionFraction :> Real;

    // ---------- Item Definitions ----------
    item def MedicalGradeSilicone;
    item def SkinPreparationSolution;
    item def DermalTissue;
    item def PerioralTissue :> DermalTissue {
        attribute regionLabel : String;
    }

    // ---------- Port Definitions ----------
    port def TissueInterfacePort {
        in liftForce : ForceValue;
        in appliedPressure : PressureValue;
        out tissueResponse : ResponseScore;
    }

    port def InsertionPort {
        out insertionDepth : DepthValue;
        out insertionForce : ForceValue;
    }

    port def MonitoringPort {
        in measuredWrinkleDepth : WrinkleDepthValue;
        in currentTissueResponse : ResponseScore;
    }

    // ---------- Part: Dermal Strip ----------
    part def DermalStrip {
        attribute material : MedicalGradeSilicone;
        attribute length : LengthValue = 15 [mm];
        attribute width : LengthValue = 2.0 [mm];
        attribute thickness : LengthValue = 0.4 [mm];
        attribute flexibility : FlexibilityIndex = 0.85;
        attribute adhesion : AdhesionIndex = 0.75;
        attribute maxLiftForce : ForceValue = 0.2 [N];
        attribute maxPressure : PressureValue = 2000 [Pa];
        attribute isBiocompatible : Boolean = true;
        attribute isRemovable : Boolean = true;

        port tissueInterface : TissueInterfacePort;

        action def provideContinuousLift {
            out generatedForce : ForceValue;
            out exertedPressure : PressureValue;
        }

        action def anchorTissue {
            in adhesionLevel : AdhesionIndex;
        }

        action def conformToTissue {
            in flexibilityLevel : FlexibilityIndex;
        }

        action performLift : provideContinuousLift {
            out generatedForce = maxLiftForce;
            out exertedPressure = maxPressure;
        }
    }

    // ---------- Part: Insertion Tool ----------
    part def InsertionTool {
        attribute maxInsertionDepth : DepthValue = 2.5 [mm];
        attribute maxInsertionForce : ForceValue = 1.5 [N];
        attribute strokeLength : LengthValue = 0.5 [mm];
        attribute depthSafetyLimit : DepthValue = 2.5 [mm];

        port insertionPort : InsertionPort;

        action def insertStrip {
            in target : DermalTissue;
            in targetDepth : DepthValue;
            out achievedDepth : DepthValue;
            out appliedForce : ForceValue;
        }

        action def verifyDepth {
            in measuredDepth : DepthValue;
            out withinLimits : Boolean;
        }

        action def limitInsertionForce {
            in appliedForce : ForceValue;
            out clampedForce : ForceValue;
        }

        action ensureSafeInsertion : verifyDepth {
            in measuredDepth;
            out withinLimits = (measuredDepth <= depthSafetyLimit);
        }

        action clampForce : limitInsertionForce {
            in appliedForce;
            out clampedForce = (appliedForce <= maxInsertionForce) ? appliedForce : maxInsertionForce;
        }
    }

    // ---------- Part: Monitoring Instrument ----------
    part def MonitoringInstrument {
        attribute measurementInterval : DurationValue = 1 [d];
        attribute adverseReactionThreshold : ResponseScore = 0.2;
        attribute capillaryOcclusionPressure : PressureValue = 3000 [Pa];
        value measuredWrinkleDepth : WrinkleDepthValue;
        value currentTissueResponse : ResponseScore;
        attribute responseStable : Boolean = false;

        port monitorPort : MonitoringPort;

        action def measureWrinkleDepth {
            out depth : WrinkleDepthValue;
        }

        action def assessResponse {
            in response : ResponseScore;
            out stable : Boolean;
        }

        action def monitorTissuePressure {
            in appliedPressure : PressureValue;
            out withinLimits : Boolean;
        }

        action evaluateSafety : assessResponse {
            in response = currentTissueResponse;
            out stable = (response < adverseReactionThreshold);
        }

        action pressureSafetyCheck : monitorTissuePressure {
            in appliedPressure;
            out withinLimits = (appliedPressure <= capillaryOcclusionPressure);
        }
    }

    // ---------- Part: Patient ----------
    part def Patient {
        part perioralTissue : PerioralTissue[1..2] {
            attribute regionLabel : String = "perioral";
        }
        value initialWrinkleDepth : WrinkleDepthValue = 0.8 [mm];
        value postTreatmentWrinkleDepth : WrinkleDepthValue;
        value currentTissueResponse : ResponseScore;
        attribute treatmentTargetMet : Boolean = false;

        port tissueInterface : TissueInterfacePort;
    }

    // ---------- Root System ----------
    part def AngelliftSystem {
        part strips : DermalStrip[1..4];
        part insertionTool : InsertionTool;
        part monitor : MonitoringInstrument;
        ref part patient : Patient;

        attribute targetWrinkleReductionFraction : ReductionFraction = 0.5;
        attribute minimumWrinkleReductionFraction : ReductionFraction = 0.3;
        attribute maxTreatmentDuration : DurationValue = 90 [d];
        attribute removable : Boolean = true;
        attribute systemReady : Boolean = false;

        connection insertToolToStrip connect insertionTool.insertionPort to strips.tissueInterface;
        connection stripToPatient connect strips.tissueInterface to patient.tissueInterface;
        connection patientToMonitor connect patient.tissueInterface to monitor.monitorPort;

        action def assessTreatmentEffectiveness {
            in initialDepth : WrinkleDepthValue;
            in finalDepth : WrinkleDepthValue;
            out reductionFraction : ReductionFraction;
            out targetAchieved : Boolean;
        }

        action computeEffectiveness : assessTreatmentEffectiveness {
            in initialDepth = patient.initialWrinkleDepth;
            in finalDepth = patient.postTreatmentWrinkleDepth;
            out reductionFraction = (initialDepth - finalDepth) / initialDepth;
            out targetAchieved = (reductionFraction >= minimumWrinkleReductionFraction);
        }

        action def prepareSkin;
        action def applySkinPreparation;
        action def verifyPrepared;
        action def loadStrip;
        action def insertStrips;
        action def confirmPlacement;
        action def initiateLift;
        action def applyContinuousLift;
        action def stabilizeLift;
        action def monitorTissueResponse;
        action def reportOutcome;
        action def periodicCheck;
        action def prepareRemoval;
        action def extractStrips;
        action def finalizeRemoval;
    }

    // ---------- Clinical Procedure State Machine ----------
    state def ClinicalProcedure {
        attribute prepared : Boolean = false;
        attribute stripsInserted : Boolean = false;
        attribute liftActive : Boolean = false;
        attribute responseStable : Boolean = false;
        attribute effectivenessConfirmed : Boolean = false;
        attribute periodicCheckComplete : Boolean = false;
        attribute removalRequested : Boolean = false;
        attribute procedureComplete : Boolean = false;

        state Preparing {
            entry / prepareSkin();
            do / applySkinPreparation();
            exit / verifyPrepared();
        }
        state Inserting {
            entry / loadStrip();
            do / insertStrips();
            exit / confirmPlacement();
        }
        state Lifting {
            entry / initiateLift();
            do / applyContinuousLift();
            exit / stabilizeLift();
        }
        state Monitoring {
            do / monitorTissueResponse();
            exit / evaluateSafety();
        }
        state Evaluating {
            entry / measureWrinkleDepth();
            do / computeEffectiveness();
            exit / reportOutcome();
        }
        state Maintaining {
            do / periodicCheck();
        }
        state Removing {
            entry / prepareRemoval();
            do / extractStrips();
            exit / finalizeRemoval();
        }

        transition from Preparing to Inserting when prepared;
        transition from Inserting to Lifting when stripsInserted;
        transition from Lifting to Monitoring when liftActive;
        transition from Monitoring to Lifting when responseStable && !effectivenessConfirmed;
        transition from Monitoring to Evaluating when responseStable;
        transition from Evaluating to Maintaining when effectivenessConfirmed;
        transition from Maintaining to Removing when removalRequested;
        transition from Evaluating to Removing when removalRequested;
        transition from Maintaining to Evaluating when periodicCheckComplete;
        transition from Removing to done when procedureComplete;
    }

    // ---------- Requirements ----------
    requirement def BiocompatibilityRequirement {
        doc /* The dermal strip shall be composed of biocompatible medical-grade silicone to prevent adverse tissue reactions. */;
        subject strip : DermalStrip;
        requirement {
            strip.isBiocompatible == true;
        }
    }

    requirement def MechanicalForceRequirement {
        doc /* Each strip shall deliver a continuous mechanical lift force sufficient to smooth perioral wrinkles without exceeding safe tissue tolerance. */;
        subject strip : DermalStrip;
        requirement {
            strip.maxLiftForce >= 0.1 [N] && strip.maxLiftForce <= 0.3 [N];
        }
    }

    requirement def InsertionDepthSafetyRequirement {
        doc /* Insertion depth shall be limited to the superficial subcutaneous layer to avoid vascular and neural injury. */;
        subject tool : InsertionTool;
        requirement {
            tool.maxInsertionDepth <= 2.5 [mm];
        }
    }

    requirement def PressureSafetyRequirement {
        doc /* Contact pressure exerted by the strip on surrounding tissue shall remain below the capillary occlusion threshold. */;
        subject strip : DermalStrip;
        requirement {
            strip.maxPressure <= 3000 [Pa];
        }
    }

    requirement def WrinkleReductionRequirement {
        doc /* Treatment shall reduce perioral wrinkle depth by at least 30% relative to the pre-treatment baseline. */;
        subject system : AngelliftSystem;
        requirement {
            system.patient.postTreatmentWrinkleDepth <= 0.7 * system.patient.initialWrinkleDepth;
        }
    }

    requirement def RemovabilityRequirement {
        doc /* The strip shall be safely removable on demand without inducing permanent tissue damage. */;
        subject system : AngelliftSystem;
        requirement {
            system.removable == true;
        }
    }

    requirement def FlexibilityRequirement {
        doc /* The strip shall be sufficiently flexible to conform to perioral tissue contours while preserving lift capacity. */;
        subject strip : DermalStrip;
        requirement {
            strip.flexibility >= 0.7;
        }
    }

    requirement def AdhesionRequirement {
        doc /* The strip shall provide sufficient internal adhesion to gently grip and lift underlying facial tissue. */;
        subject strip : DermalStrip;
        requirement {
            strip.adhesion >= 0.6;
        }
    }

    requirement def TreatmentDurationRequirement {
        doc /* The intended cosmetic improvement shall be sustained for a minimum treatment duration of up to 90 days. */;
        subject system : AngelliftSystem;
        requirement {
            system.maxTreatmentDuration <= 90 [d];
        }
    }

    // ---------- Specification Part Aggregating Requirements ----------
    part def AngelliftSystemSpecification :> AngelliftSystem {
        requirement biocompatibility : BiocompatibilityRequirement;
        requirement mechanicalForce : MechanicalForceRequirement;
        requirement insertionDepthSafety : InsertionDepthSafetyRequirement;
        requirement pressureSafety : PressureSafetyRequirement;
        requirement wrinkleReduction : WrinkleReductionRequirement;
        requirement removability : RemovabilityRequirement;
        requirement flexibility : FlexibilityRequirement;
        requirement adhesion : AdhesionRequirement;
        requirement treatmentDuration : TreatmentDurationRequirement;
    }

    // ---------- Verification Cases ----------
    verification BiocompatibilityVerification {
        subject strip : DermalStrip;
        objective {
            strip.isBiocompatible == true;
        }
    }

    verification MechanicalForceVerification {
        subject strip : DermalStrip;
        objective {
            strip.maxLiftForce >= 0.1 [N] && strip.maxLiftForce <= 0.3 [N];
        }
    }

    verification DepthSafetyVerification {
        subject tool : InsertionTool;
        objective {
            tool.maxInsertionDepth <= 2.5 [mm];
        }
    }

    verification PressureSafetyVerification {
        subject strip : DermalStrip;
        objective {
            strip.maxPressure <= 3000 [Pa];
        }
    }

    verification WrinkleReductionVerification {
        subject system : AngelliftSystem;
        objective {
            system.patient.postTreatmentWrinkleDepth <= 0.7 * system.patient.initialWrinkleDepth;
        }
    }

    verification RemovabilityVerification {
        subject system : AngelliftSystem;
        objective {
            system.removable == true;
        }
    }

    verification FlexibilityVerification {
        subject strip : DermalStrip;
        objective {
            strip.flexibility >= 0.7;
        }
    }

    verification AdhesionVerification {
        subject strip : DermalStrip;
        objective {
            strip.adhesion >= 0.6;
        }
    }

    verification TreatmentDurationVerification {
        subject system : AngelliftSystem;
        objective {
            system.maxTreatmentDuration <= 90 [d];
        }
    }
}
