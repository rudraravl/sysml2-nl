package 'Neil Robertson Stretcher System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    item def DeployCommand;
    item def SecurePatientCommand;
    item def LiftCommand;
    item def EvacuationCompleteEvent;

    port def LiftingInterface;
    port def PatientInterface;

    part def CanvasShell {
        attribute material : String = "Heavy-duty canvas";
        attribute thickness : ISQ::Length;
    }

    part def WoodenSlat {
        attribute material : String = "Ash wood";
        attribute length : ISQ::Length;
        attribute width : ISQ::Length;
        attribute thickness : ISQ::Length;
    }

    part def NylonWebbingStrap {
        attribute material : String = "Nylon";
        attribute tensileStrength : ISQ::Force;
        attribute length : ISQ::Length;
        attribute width : ISQ::Length;
    }

    part def HeadNeckRestraint {
        attribute paddingMaterial : String;
    }

    part def LiftingBridle {
        attribute material : String = "High-tensile rope or webbing";
        attribute breakingStrength : ISQ::Force;
        attribute length : ISQ::Length;
        port stretcherAttachment : ~LiftingInterface;
        port hoistAttachment : ~LiftingInterface;
    }

    part def AttachmentPoint {
        attribute loadRating : ISQ::Force;
        port bridleAttachment : ~LiftingInterface;
    }

    part def Patient {
        attribute mass : ISQ::Mass;
        attribute hasSuspectedSpinalInjury : Boolean;
    }

    part def NeilRobertsonStretcher {
        attribute maxPatientWeight : ISQ::Mass = 182 [kg];
        attribute designType : String = "Rigid wrap-around cocoon";

        part canvasShell : CanvasShell[1];
        part woodenSlat : WoodenSlat[1..*] {
            doc /* Series of strong wooden slats for semi-rigid stiffness */
        }
        part webbingStrap : NylonWebbingStrap[7] {
            doc /* Fastened across the body to prevent movement */
        }
        part headNeckRestraint : HeadNeckRestraint[1];
        part liftingBridle : LiftingBridle[4];
        part attachmentPoint : AttachmentPoint[4] {
            doc /* Multiple attachment points for vertical and horizontal extraction */
        }
        part patient : Patient[0..1];

        port liftingPort : ~LiftingInterface;
        port patientSecuringPort : ~PatientInterface;

        connect liftingBridle.stretcherAttachment to attachmentPoint.bridleAttachment;
        connect liftingBridle.hoistAttachment to liftingPort;
    }

    requirement def ImmobilizationRequirement {
        doc /* The stretcher must completely immobilize a patient, especially one with suspected spinal injuries. */
        subject stretcher : NeilRobertsonStretcher;
    }

    requirement def WeightCapacityRequirement {
        doc /* The stretcher must support a patient weighing up to 182 kg. */
        subject stretcher : NeilRobertsonStretcher;
        attribute maxWeight : ISQ::Mass = 182 [kg];
        constraint { stretcher.maxPatientWeight >= maxWeight }
    }

    requirement def ExtractionRequirement {
        doc /* The stretcher must allow for vertical and horizontal extraction using lifting bridles. */
        subject stretcher : NeilRobertsonStretcher;
    }

    requirement def ConfinedSpaceRequirement {
        doc /* The stretcher must be narrow and compact for maneuvering through tight passages. */
        subject stretcher : NeilRobertsonStretcher;
    }

    part stretcherInstance : NeilRobertsonStretcher {
        satisfy ImmobilizationRequirement;
        satisfy WeightCapacityRequirement;
        satisfy ExtractionRequirement;
        satisfy ConfinedSpaceRequirement;
    }

    action def DeployStretcher {
        doc /* Unfold and prepare the stretcher for use. */
    }

    action def SecurePatient {
        doc /* Position the patient on the stretcher and fasten all seven straps and head/neck restraint. */
        in patientMass : ISQ::Mass;
        constraint { patientMass <= 182 [kg] }
    }

    action def LiftAndNavigate {
        doc /* Attach hoist to lifting bridles, lift the stretcher, and navigate through confined space. */
    }

    action def CompleteEvacuation {
        doc /* Lower the stretcher at the extraction point and release the patient. */
    }

    state def StretcherOperationalStates {
        in stretcher : NeilRobertsonStretcher;

        entry; then Stowed;

        state Stowed {
            doc /* The stretcher is stowed and ready for deployment. */
        }

        state Deployed {
            doc /* The stretcher is deployed and patient is positioned. */
        }

        state PatientSecured {
            doc /* The patient is securely strapped in and immobilized. */
        }

        state Extraction {
            doc /* The stretcher is being lifted and navigated out of the confined space. */
        }

        state EvacuationComplete {
            doc /* The evacuation is complete and the patient is safely out. */
        }

        transition stowed_to_deployed
            first Stowed
            accept DeployCommand
            do action deployStretcher : DeployStretcher
            then Deployed;

        transition deployed_to_secured
            first Deployed
            accept SecurePatientCommand
            do action securePatient : SecurePatient
            then PatientSecured;

        transition secured_to_extraction
            first PatientSecured
            accept LiftCommand
            do action liftAndNavigate : LiftAndNavigate
            then Extraction;

        transition extraction_to_complete
            first Extraction
            accept EvacuationCompleteEvent
            do action completeEvacuation : CompleteEvacuation
            then EvacuationComplete;
    }
}
