package AngelliftCosmeticLiftSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def WrinkleDepth :> LengthValue;
    attribute def TissueLiftDistance :> LengthValue;
    attribute def AdhesiveStrength :> Real;
    attribute def FlexibilityIndex :> Real;

    item def SiliconeStrip {
        attribute length : LengthValue;
        attribute width : LengthValue;
        attribute thickness : LengthValue;
        attribute flexibility : FlexibilityIndex;
        attribute adhesiveCoating : AdhesiveStrength;
        attribute biocompatible : Boolean;
    }

    item def FacialTissue {
        attribute elasticity : Real;
        attribute thickness : LengthValue;
        attribute baselineWrinkleDepth : WrinkleDepth;
        attribute currentWrinkleDepth : WrinkleDepth;
    }

    attribute def TreatmentDuration :> DurationValue;
    attribute def LiftForce :> ForceValue;

    port def TissueContactPort {
        attribute contactArea : AreaValue;
        attribute appliedPressure : PressureValue;
        attribute adhesionQuality : AdhesiveStrength;
    }

    port def MechanicalLiftPort {
        attribute liftForce : LiftForce;
        attribute liftAngle : Real;
        attribute liftDistance : TissueLiftDistance;
    }

    part def AngelliftDermalStrip {
        doc /* Medical-grade silicone strip designed for subdermal insertion to provide mechanical support. */
        
        part stripMaterial : SiliconeStrip {
            attribute length = 25.0 [mm];
            attribute width = 3.0 [mm];
            attribute thickness = 0.5 [mm];
            attribute flexibility = 0.85;
            attribute adhesiveCoating = 0.90;
            attribute biocompatible = true;
        }

        port tissueContact : TissueContactPort[2];
        port mechanicalLift : MechanicalLiftPort;

        attribute insertionDepth : LengthValue = 2.0 [mm];
        attribute targetLiftForce : LiftForce = 1.5 [N];
    }

    part def PeriOralRegion {
        doc /* Facial region around the mouth where perioral wrinkles form. */
        
        part dermis : FacialTissue {
            attribute elasticity = 0.70;
            attribute thickness = 1.8 [mm];
            attribute baselineWrinkleDepth = 0.8 [mm];
            attribute currentWrinkleDepth = 0.8 [mm];
        }

        part epidermis : FacialTissue {
            attribute elasticity = 0.60;
            attribute thickness = 0.2 [mm];
            attribute baselineWrinkleDepth = 0.5 [mm];
            attribute currentWrinkleDepth = 0.5 [mm];
        }

        port externalSurface : TissueContactPort;
        port subdermalLayer : MechanicalLiftPort;
    }

    part def Patient {
        doc /* Individual receiving Angellift cosmetic treatment. */
        
        part leftPeriOralArea : PeriOralRegion;
        part rightPeriOralArea : PeriOralRegion;
        
        attribute age : Real;
        attribute skinType : String;
        attribute treatmentHistory : String;
    }

    action def PrepareInsertionSite {
        in targetRegion : PeriOralRegion;
        out sitePrepared : Boolean;
        out cleanlinessVerified : Boolean;
    }

    action def InsertDermalStrip {
        in strip : AngelliftDermalStrip;
        in targetDepth : LengthValue;
        in insertionSite : PeriOralRegion;
        out stripPlaced : Boolean;
        out placementDepth : LengthValue;
    }

    action def ApplyMechanicalLift {
        in strip : AngelliftDermalStrip;
        in targetForce : LiftForce;
        out liftApplied : Boolean;
        out achievedLift : TissueLiftDistance;
        out wrinkleReduction : Real;
    }

    action def MonitorTissueResponse {
        in treatedRegion : PeriOralRegion;
        in monitoringDuration : TreatmentDuration;
        out tissueStable : Boolean;
        out adverseReaction : Boolean;
    }

    action def AssessWrinkleReduction {
        in pretreatmentDepth : WrinkleDepth;
        in posttreatmentDepth : WrinkleDepth;
        out reductionPercentage : Real;
        out treatmentEffective : Boolean;
    }

    message def SiteReadyEvent;
    message def RemovalRequestEvent;

    state def TreatmentPhases {
        entry; then preparation;

        state preparation {
            doc /* Initial phase where insertion site is prepared. */
        }
        transition preparation_to_insertion
            first preparation
            accept SiteReadyEvent
            then insertion;

        state insertion {
            doc /* Phase where dermal strip is inserted subdermally. */
        }
        transition insertion_to_lifting
            first insertion
            then lifting;

        state lifting {
            doc /* Active phase where mechanical lift is applied to tissue. */
        }
        transition lifting_to_monitoring
            first lifting
            then monitoring;

        state monitoring {
            doc /* Ongoing monitoring of tissue response and lift maintenance. */
        }
        transition monitoring_to_assessment
            first monitoring
            then assessment;

        state assessment {
            doc /* Evaluation of treatment effectiveness. */
        }
        transition assessment_to_maintenance
            first assessment
            then maintenance;

        state maintenance {
            doc /* Long-term maintenance of cosmetic improvement. */
        }
        transition maintenance_to_removal
            first maintenance
            accept RemovalRequestEvent
            then removal;

        state removal {
            doc /* Controlled removal of dermal strip if needed. */
        }
        transition removal_to_complete
            first removal
            then complete;

        state complete;
    }

    action def AngelliftTreatmentProcedure {
        doc /* Complete treatment procedure for Angellift cosmetic lift application. */
        
        in patient : Patient;
        in leftStrip : AngelliftDermalStrip;
        in rightStrip : AngelliftDermalStrip;
        in treatmentDuration : TreatmentDuration;

        first start;

        then action prepareSites : PrepareInsertionSite {
            in targetRegion = patient.leftPeriOralArea;
            out sitePrepared;
            out cleanlinessVerified;
        }

        then action insertLeftStrip : InsertDermalStrip {
            in strip = leftStrip;
            in targetDepth = 2.0 [mm];
            in insertionSite = patient.leftPeriOralArea;
            out stripPlaced;
            out placementDepth;
        }

        then action insertRightStrip : InsertDermalStrip {
            in strip = rightStrip;
            in targetDepth = 2.0 [mm];
            in insertionSite = patient.rightPeriOralArea;
            out stripPlaced;
            out placementDepth;
        }

        then action applyLeftLift : ApplyMechanicalLift {
            in strip = leftStrip;
            in targetForce = 1.5 [N];
            out liftApplied;
            out achievedLift;
            out wrinkleReduction;
        }

        then action applyRightLift : ApplyMechanicalLift {
            in strip = rightStrip;
            in targetForce = 1.5 [N];
            out liftApplied;
            out achievedLift;
            out wrinkleReduction;
        }

        then action monitorResponse : MonitorTissueResponse {
            in treatedRegion = patient.leftPeriOralArea;
            in monitoringDuration = treatmentDuration;
            out tissueStable;
            out adverseReaction;
        }

        then decide;
            if monitorResponse.adverseReaction then abortTreatment;
            if monitorResponse.tissueStable then assessResults;

        action assessResults : AssessWrinkleReduction {
            in pretreatmentDepth = patient.leftPeriOralArea.dermis.baselineWrinkleDepth;
            in posttreatmentDepth = patient.leftPeriOralArea.dermis.currentWrinkleDepth;
            out reductionPercentage;
            out treatmentEffective;
        }
        then done;

        action abortTreatment;
        then done;
    }

    part angelliftSystem : AngelliftDermalStrip {
        doc /* Complete Angellift cosmetic lift system instance. */
        
        part leftDevice : AngelliftDermalStrip;
        part rightDevice : AngelliftDermalStrip;
    }

    requirement def BiocompatibilityRequirement {
        doc /* The Angellift dermal strip shall be made of biocompatible medical-grade silicone 
                that does not cause adverse tissue reactions. */

        subject systemUnderTest : AngelliftDermalStrip;

        require constraint materialSafety {
            systemUnderTest.stripMaterial.biocompatible = true
        }

        require constraint adhesiveStrength {
            systemUnderTest.stripMaterial.adhesiveCoating >= 0.80 and
            systemUnderTest.stripMaterial.adhesiveCoating <= 0.95
        }
    }

    requirement def MechanicalPerformanceRequirement {
        doc /* The Angellift system shall provide sufficient mechanical lift to reduce 
                perioral wrinkle depth by at least 40%. */

        subject systemUnderTest : AngelliftDermalStrip;

        require constraint minimumLiftForce {
            systemUnderTest.targetLiftForce >= 1.0 [N]
        }

        require constraint flexibilityRange {
            systemUnderTest.stripMaterial.flexibility >= 0.75 and
            systemUnderTest.stripMaterial.flexibility <= 0.95
        }
    }

    requirement def SafetyRequirement {
        doc /* The Angellift system shall operate safely without causing tissue damage 
                or excessive discomfort. */

        subject systemUnderTest : AngelliftDermalStrip;

        require constraint insertionDepthLimit {
            systemUnderTest.insertionDepth <= 3.0 [mm]
        }

        require constraint contactPressureLimit {
            systemUnderTest.tissueContact.appliedPressure <= 20.0 [kPa]
        }
    }

    requirement def UsabilityRequirement {
        doc /* The Angellift system shall be insertable and maintainable with minimal 
                patient discomfort and professional oversight. */
    }

    requirement <'ANGEL-001'> primaryFunctionRequirement {
        doc /* The Angellift system shall provide non-surgical cosmetic improvement of perioral 
                wrinkles by inserting flexible, biocompatible dermal strips subdermally to apply 
                controlled mechanical lift that smooths facial tissue and reduces wrinkle appearance 
                by at least 40% while maintaining tissue safety and patient comfort. */

        assume constraint patientSuitability {
            doc /* Patient has appropriate skin type and no contraindications for subdermal insertion. */
        }

        assume constraint properSterilization {
            doc /* All Angellift components are properly sterilized before insertion. */
        }

        require BiocompatibilityRequirement;
        require MechanicalPerformanceRequirement;
        require SafetyRequirement;
        require UsabilityRequirement;
    }

    part treatmentSystem {
        doc /* Complete integrated Angellift treatment system. */
        
        part treatedPatient : Patient {
            attribute age = 52.0;
            attribute skinType = "Type II";
            attribute treatmentHistory = "First Angellift procedure";
        }

        part leftAngellift : AngelliftDermalStrip;
        part rightAngellift : AngelliftDermalStrip;

        connect leftAngellift.tissueContact to treatedPatient.leftPeriOralArea.externalSurface;
        connect rightAngellift.tissueContact to treatedPatient.rightPeriOralArea.externalSurface;
        connect leftAngellift.mechanicalLift to treatedPatient.leftPeriOralArea.subdermalLayer;
        connect rightAngellift.mechanicalLift to treatedPatient.rightPeriOralArea.subdermalLayer;

        satisfy primaryFunctionRequirement;
    }
}
