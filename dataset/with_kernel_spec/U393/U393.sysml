package SpicaSplintSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    item def ThermoplasticComposite;
    item def ClosedCellFoam;

    port def AttachmentPort;
    port def LimbInterface {
        in item contactPressure : PressureValue;
        out item pressureReading : PressureValue;
    }

    part def OuterShell {
        item material : ThermoplasticComposite;
        attribute mass : MassValue;
        attribute rigidity : Real;
        port thumbMount : AttachmentPort;
        port wristMount : AttachmentPort;
    }

    part def PaddingLayer {
        item material : ClosedCellFoam;
        attribute thickness : LengthValue;
        attribute moistureWickingRate : Real;
        attribute pressureDistribution : PressureValue;
    }

    part def ThumbComponent {
        attribute abductionAngle : PlaneAngleValue;
        port attach : AttachmentPort;
    }

    part def WristComponent {
        attribute extensionAngle : PlaneAngleValue;
        port attach : AttachmentPort;
    }

    part def FasteningStrap {
        attribute tension : ForceValue;
        attribute length : LengthValue;
        attribute adjustable : Boolean = true;
        action def AdjustTension { in delta : ForceValue; }
    }

    part def Patient {
        part limb : Limb;
        port limbInterface : LimbInterface;
    }

    part def Limb {
        part thumb;
        part wrist;
        attribute swellingLevel : Real;
        attribute circulationStatus : String;
    }

    part def SpicaSplint {
        attribute isApplied : Boolean = false;
        attribute isHealed : Boolean = false;
        attribute needsAdjustment : Boolean = false;

        part outerShell : OuterShell;
        part paddingLayer : PaddingLayer;
        part thumbComponent : ThumbComponent;
        part wristComponent : WristComponent;
        part fasteningStraps : FasteningStrap[4];

        port limbInterface : LimbInterface;

        connect outerShell.thumbMount to thumbComponent.attach;
        connect outerShell.wristMount to wristComponent.attach;
    }

    state def ClinicalLifecycle {
        in splint : SpicaSplint;

        state InitialFitting;
        transition from InitialFitting to Immobilizing if splint.isApplied;

        state Immobilizing;
        transition from Immobilizing to Monitoring;

        state Monitoring;
        transition from Monitoring to Adjusting if splint.needsAdjustment;
        transition from Monitoring to Removed if splint.isHealed;

        state Adjusting;
        transition from Adjusting to Monitoring;

        state Removed;
    }

    requirement def ImmobilizationRequirement {
        doc /* The splint must immobilize the thumb and wrist in a stable therapeutic position. */
        subject splint : SpicaSplint;
        require constraint { splint.isApplied == true }
    }

    requirement def AngleRequirement {
        doc /* Thumb and wrist must be held at precise anatomical angles for proper healing. */
        attribute requiredThumbAngle : PlaneAngleValue;
        attribute requiredWristAngle : PlaneAngleValue;
        subject splint : SpicaSplint;
        require constraint {
            splint.thumbComponent.abductionAngle == requiredThumbAngle and
            splint.wristComponent.extensionAngle == requiredWristAngle
        }
    }

    requirement def ComfortRequirement {
        doc /* Padding must ensure comfort, distribute pressure, and wick moisture. */
        subject padding : PaddingLayer;
        require constraint {
            padding.thickness > 0 [mm] and
            padding.moistureWickingRate > 0.0
        }
    }

    requirement def FasteningRequirement {
        doc /* Four adjustable straps secure the splint to accommodate swelling changes. */
        attribute numberOfStraps : Integer = 4;
        subject splint : SpicaSplint;
        require constraint { splint.fasteningStraps->size() == numberOfStraps }
    }

    part spicaSplint : SpicaSplint {
        :>> outerShell {
            :>> mass = 0.5 [kg];
        }
        :>> paddingLayer {
            :>> thickness = 5 [mm];
            :>> moistureWickingRate = 0.5;
            :>> pressureDistribution = 2600 [Pa];
        }
        :>> thumbComponent {
            :>> abductionAngle = 30 [deg];
        }
        :>> wristComponent {
            :>> extensionAngle = 15 [deg];
        }

        exhibit clinicalLifecycle : ClinicalLifecycle {
            in splint = spicaSplint;
        }
    }

    part patient : Patient;

    connect spicaSplint.limbInterface to patient.limbInterface;

    requirement immobilizationReq : ImmobilizationRequirement;
    requirement angleReq : AngleRequirement {
        :>> requiredThumbAngle = 30 [deg];
        :>> requiredWristAngle = 15 [deg];
    }
    requirement comfortReq : ComfortRequirement;
    requirement fasteningReq : FasteningRequirement;

    satisfy immobilizationReq by spicaSplint;
    satisfy angleReq by spicaSplint;
    satisfy comfortReq by spicaSplint.paddingLayer;
    satisfy fasteningReq by spicaSplint;
}
