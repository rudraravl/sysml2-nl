package NailBraceSystemModel {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def ForceValue {
        attribute magnitude : Real;
        attribute unit : String = "N";
    }

    attribute def LengthValue {
        attribute magnitude : Real;
        attribute unit : String = "mm";
    }

    attribute def PressureValue {
        attribute magnitude : Real;
        attribute unit : String = "kPa";
    }

    attribute def CurvatureValue {
        attribute magnitude : Real;
        attribute unit : String = "1/mm";
    }

    attribute def DurationValue {
        attribute magnitude : Real;
        attribute unit : String = "day";
    }

    attribute def AdhesionStrengthValue {
        attribute magnitude : Real;
        attribute unit : String = "N/mm2";
    }

    item def CorrectiveForce {
        attribute force : ForceValue;
        attribute direction : String;
    }

    item def NailCurvature {
        attribute curvature : CurvatureValue;
        attribute measuredAcrossWidth : LengthValue;
    }

    item def SkinPressure {
        attribute pressure : PressureValue;
        attribute location : String;
    }

    item def BraceStatus {
        attribute attached : Boolean;
        attribute tensioned : Boolean;
        attribute treatmentDay : Integer;
        attribute patientComfortScore : Integer;
    }

    item def ClinicalInstruction {
        attribute text : String;
        attribute inspectionInterval : DurationValue;
    }

    port def MechanicalContactPort {
        out item correctiveForce : CorrectiveForce;
        in item nailCurvature : NailCurvature;
        in item skinPressure : SkinPressure;
    }

    port def AdhesiveInterfacePort {
        out item bondLoad : CorrectiveForce;
        in item adhesionCondition : BraceStatus;
    }

    port def MonitoringPort {
        out item status : BraceStatus;
        out item instruction : ClinicalInstruction;
    }

    part def Toenail {
        attribute width : LengthValue;
        attribute thickness : LengthValue;
        attribute freeEdgeLength : LengthValue;
        attribute currentCurvature : NailCurvature;
        attribute lateralFoldPressure : SkinPressure;

        port dorsalSurface : MechanicalContactPort;
    }

    part def NailFold {
        attribute leftPressure : SkinPressure;
        attribute rightPressure : SkinPressure;

        port pressureInterface : MechanicalContactPort;
    }

    part def BraceStrip {
        attribute stripLength : LengthValue;
        attribute stripWidth : LengthValue;
        attribute stripThickness : LengthValue;
        attribute elasticModulus : Real;
        attribute preformedCurvature : CurvatureValue;
        attribute maximumCorrectiveForce : ForceValue;

        port centerLiftInterface : MechanicalContactPort;
        port leftBondInterface : AdhesiveInterfacePort;
        port rightBondInterface : AdhesiveInterfacePort;
    }

    part def AdhesivePad {
        attribute contactArea : Real;
        attribute adhesionStrength : AdhesionStrengthValue;
        attribute cureDuration : DurationValue;
        attribute biocompatible : Boolean;

        port nailBond : AdhesiveInterfacePort;
        port braceBond : AdhesiveInterfacePort;
    }

    part def TensioningElement {
        attribute adjustmentRange : LengthValue;
        attribute appliedLiftForce : ForceValue;
        attribute locked : Boolean;

        port braceActuation : MechanicalContactPort;
    }

    part def Clinician {
        port monitor : MonitoringPort;
    }

    part def NailBrace {
        attribute nominalTreatmentDuration : DurationValue;
        attribute targetCurvatureReduction : CurvatureValue;
        attribute maximumAllowedSkinPressure : PressureValue;
        attribute installed : Boolean;

        part strip : BraceStrip;
        part leftAdhesive : AdhesivePad;
        part rightAdhesive : AdhesivePad;
        part tensioner : TensioningElement;

        port nailInterface : MechanicalContactPort;
        port statusPort : MonitoringPort;

        connect strip.centerLiftInterface to tensioner.braceActuation;
        connect strip.leftBondInterface to leftAdhesive.braceBond;
        connect strip.rightBondInterface to rightAdhesive.braceBond;
        connect leftAdhesive.nailBond to nailInterface;
        connect rightAdhesive.nailBond to nailInterface;

        action def ApplyBrace {
            in item initialCurvature : NailCurvature;
            in item clinicianInstruction : ClinicalInstruction;
            out item braceStatus : BraceStatus;

            action cleanNailSurface;
            action positionBraceStrip;
            action bondLeftAnchor;
            action bondRightAnchor;
            action applyControlledTension;
            action verifyComfortAndPressure;

            first start;
            then cleanNailSurface;
            then positionBraceStrip;
            then bondLeftAnchor;
            then bondRightAnchor;
            then applyControlledTension;
            then verifyComfortAndPressure;
            then done;

            bind braceStatus.attached = true;
            bind braceStatus.tensioned = true;
        }

        action def GenerateCorrectiveLift {
            in item observedCurvature : NailCurvature;
            out item liftForce : CorrectiveForce;

            action senseCurvature;
            action distributeForceAcrossNailPlate;
            action liftLateralEdges;
            action reduceNailFoldPressure;

            first start;
            then senseCurvature;
            then distributeForceAcrossNailPlate;
            then liftLateralEdges;
            then reduceNailFoldPressure;
            then done;

            bind liftForce.direction = "upward and outward at lateral nail edges";
        }

        action def InspectBrace {
            in item measuredPressure : SkinPressure;
            in item measuredCurvature : NailCurvature;
            out item inspectionStatus : BraceStatus;

            action checkAdhesiveRetention;
            action checkSkinIrritation;
            action compareCurvatureWithTarget;
            action decideRetensionOrRemoval;

            first start;
            then checkAdhesiveRetention;
            then checkSkinIrritation;
            then compareCurvatureWithTarget;
            then decideRetensionOrRemoval;
            then done;
        }

        state def NailBraceLifecycle {
            entry action initializeStatus;

            state Unapplied;
            state SurfacePrepared;
            state Attached;
            state Tensioned;
            state ActiveCorrection;
            state InspectionRequired;
            state Retensioned;
            state TreatmentComplete;
            state Removed;

            transition first Unapplied;
            transition Unapplied to SurfacePrepared
                accept cleanAndDryNail;
            transition SurfacePrepared to Attached
                accept adhesivePadsBonded;
            transition Attached to Tensioned
                accept correctiveTensionApplied;
            transition Tensioned to ActiveCorrection
                accept patientComfortVerified;
            transition ActiveCorrection to InspectionRequired
                accept inspectionIntervalElapsed;
            transition InspectionRequired to Retensioned
                accept curvatureReductionBelowPlan
                if skinPressureAcceptable;
            transition Retensioned to ActiveCorrection
                accept tensionReadjusted;
            transition InspectionRequired to TreatmentComplete
                accept targetCurvatureAchieved;
            transition TreatmentComplete to Removed
                accept braceRemoved;
            transition ActiveCorrection to Removed
                accept painOrAdhesiveFailureDetected;
        }
    }

    part def NailBraceTreatmentSystem {
        part patientToenail : Toenail {
            attribute width = LengthValue { magnitude = 16.0; }
            attribute thickness = LengthValue { magnitude = 0.8; }
            attribute freeEdgeLength = LengthValue { magnitude = 2.5; }
        }

        part lateralNailFold : NailFold;

        part brace : NailBrace {
            attribute nominalTreatmentDuration = DurationValue { magnitude = 42.0; }
            attribute targetCurvatureReduction = CurvatureValue { magnitude = 0.018; }
            attribute maximumAllowedSkinPressure = PressureValue { magnitude = 12.0; }
            attribute installed = false;

            part strip {
                attribute stripLength = LengthValue { magnitude = 18.0; }
                attribute stripWidth = LengthValue { magnitude = 2.0; }
                attribute stripThickness = LengthValue { magnitude = 0.25; }
                attribute elasticModulus = 210000.0;
                attribute preformedCurvature = CurvatureValue { magnitude = 0.010; }
                attribute maximumCorrectiveForce = ForceValue { magnitude = 3.0; }
            }

            part leftAdhesive {
                attribute contactArea = 8.0;
                attribute adhesionStrength = AdhesionStrengthValue { magnitude = 0.35; }
                attribute cureDuration = DurationValue { magnitude = 0.02; }
                attribute biocompatible = true;
            }

            part rightAdhesive {
                attribute contactArea = 8.0;
                attribute adhesionStrength = AdhesionStrengthValue { magnitude = 0.35; }
                attribute cureDuration = DurationValue { magnitude = 0.02; }
                attribute biocompatible = true;
            }

            part tensioner {
                attribute adjustmentRange = LengthValue { magnitude = 1.5; }
                attribute appliedLiftForce = ForceValue { magnitude = 1.2; }
                attribute locked = true;
            }
        }

        part clinician : Clinician;

        connect patientToenail.dorsalSurface to brace.nailInterface;
        connect lateralNailFold.pressureInterface to patientToenail.dorsalSurface;
        connect clinician.monitor to brace.statusPort;
    }

    requirement def PrimaryFunctionRequirement {
        subject system : NailBraceTreatmentSystem;

        doc /* The nail brace system shall apply a controlled lifting and outward corrective force to a curved toenail so that the nail plate gradually flattens, lateral nail-fold pressure is reduced, and patient discomfort associated with nail curvature is relieved without cutting or removing the nail. */

        require constraint {
            system.brace.installed == true implies
            system.brace.tensioner.appliedLiftForce.magnitude > 0.0 and
            system.brace.tensioner.appliedLiftForce.magnitude <= system.brace.strip.maximumCorrectiveForce.magnitude
        }
    }

    requirement def AttachmentRequirement {
        subject brace : NailBrace;

        doc /* The brace shall remain attached to the nail plate during normal daily activity for the planned inspection interval. */

        require constraint {
            brace.leftAdhesive.biocompatible == true and
            brace.rightAdhesive.biocompatible == true and
            brace.leftAdhesive.adhesionStrength.magnitude >= 0.30 and
            brace.rightAdhesive.adhesionStrength.magnitude >= 0.30
        }
    }

    requirement def PressureSafetyRequirement {
        subject system : NailBraceTreatmentSystem;

        doc /* The corrective action shall not increase pressure on the lateral nail fold beyond the maximum allowed clinical threshold. */

        require constraint {
            system.patientToenail.lateralFoldPressure.pressure.magnitude <=
            system.brace.maximumAllowedSkinPressure.magnitude
        }
    }

    requirement def TreatmentEffectivenessRequirement {
        subject system : NailBraceTreatmentSystem;

        doc /* The brace shall reduce excessive transverse nail curvature over the nominal treatment duration. */

        require constraint {
            system.brace.targetCurvatureReduction.magnitude >= 0.015 and
            system.brace.nominalTreatmentDuration.magnitude <= 56.0
        }
    }

    satisfy PrimaryFunctionRequirement by NailBraceTreatmentSystem;
    satisfy AttachmentRequirement by NailBrace;
    satisfy PressureSafetyRequirement by NailBraceTreatmentSystem;
    satisfy TreatmentEffectivenessRequirement by NailBraceTreatmentSystem;
}