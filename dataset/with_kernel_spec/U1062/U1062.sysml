package 'Fullerene Nanoparticle Therapy' {
    private import SI::*;
    private import ScalarValues::*;

    attribute def Wavelength :> ScalarValues::Real;
    attribute def Concentration :> ScalarValues::Real;
    attribute def DrugMass :> ScalarValues::Real;
    attribute def LightIntensity :> ScalarValues::Real;

    item def Light {
        attribute wavelength : Wavelength;
        attribute intensity : LightIntensity;
    }

    item def Oxygen {
        attribute concentration : Concentration;
    }

    item def ROS {
        attribute concentration : Concentration;
    }

    item def ChemotherapyDrug {
        attribute mass : DrugMass;
    }

    part def CancerCell;
    part def HealthyCell;

    item def Tumor {
        part cancerCells : CancerCell[*];
        part healthyCells : HealthyCell[*];
    }

    action def CirculateAndTarget {
        out boundCell : CancerCell;
    }

    action def GenerateROS {
        in light : Light;
        in oxygen : Oxygen;
        out ros : ROS;
    }

    action def ReleaseDrug {
        in trigger : ROS;
        out drug : ChemotherapyDrug;
    }

    action def TherapeuticProcess {
        in light : Light;
        in oxygen : Oxygen;
        out drug : ChemotherapyDrug;
        out ros : ROS;
    }

    port def LightInputPort {
        in item light : Light;
    }

    port def OxygenInputPort {
        in item oxygen : Oxygen;
    }

    port def ROSOutputPort {
        out item ros : ROS;
    }

    port def DrugOutputPort {
        out item drug : ChemotherapyDrug;
    }

    port def TargetingPort {
        in item cell : CancerCell;
        out item boundCell : CancerCell;
    }

    part def FullereneCage {
        attribute carbonAtomCount : Integer = 60;
        attribute diameter : ScalarValues::Real = 0.71 [nm];
    }

    part def PhotosensitizingLayer {
        attribute activationWavelength : Wavelength = 700 [nm];
        port lightIn : LightInputPort;
        port oxygenIn : OxygenInputPort;
        port rosOut : ROSOutputPort;
    }

    part def PayloadChamber {
        attribute releaseThreshold : Concentration = 1e-6;
        ref item encapsulatedDrug : ChemotherapyDrug;
        port triggerIn : ROSOutputPort;
        port drugOut : DrugOutputPort;
    }

    part def FunctionalCoating {
        attribute biocompatible : Boolean = true;
        attribute targetingEnabled : Boolean = true;
        port targetPort : TargetingPort;
    }

    state def TherapeuticAction {
        entry;
            then dormant;

        state dormant {
            doc /* Nanoparticle remains inactive until activated by light. */
        }

        transition dormant_to_generating
            first dormant
            accept LightExposure
            then generatingROS;

        state generatingROS {
            doc /* Photosensitizing layer absorbs light energy and converts oxygen to ROS. */
        }

        transition generating_to_releasing
            first generatingROS
            accept ROSCriticalLevel
            then releasingPayload;

        state releasingPayload {
            doc /* Payload chamber opens and releases chemotherapy drug. */
        }

        transition releasing_to_done
            first releasingPayload
            accept DrugReleaseComplete
            then done;

        state done {
            doc /* Therapeutic process complete. */
        }
    }

    part def Nanoparticle {
        in item light : Light;
        in item oxygen : Oxygen;
        out item drug : ChemotherapyDrug;
        out item ros : ROS;

        ref item loadedDrug : ChemotherapyDrug;
        ref item tumorCell : CancerCell;

        part cage : FullereneCage;
        part psLayer : PhotosensitizingLayer;
        part payload : PayloadChamber {
            ref item :>> encapsulatedDrug = Nanoparticle::loadedDrug;
        }
        part coating : FunctionalCoating;

        flow light to psLayer.lightIn.light;
        flow oxygen to psLayer.oxygenIn.oxygen;
        flow psLayer.rosOut.ros to payload.triggerIn.ros;
        flow psLayer.rosOut.ros to ros;
        flow payload.drugOut.drug to drug;

        state therapeuticAction : TherapeuticAction;

        perform action treat : TherapeuticProcess {
            action circulate : CirculateAndTarget;
            action generateROS : GenerateROS {
                in light = treat::light;
                in oxygen = treat::oxygen;
                out ros :> treat::ros;
            }
            action releaseDrug : ReleaseDrug {
                in trigger = generateROS.ros;
                out drug :> treat::drug;
            }
            flow generateROS.ros to releaseDrug.trigger;
            first start;
            then circulate;
            then generateROS;
            then releaseDrug;
            then done;
        }

        flow light to treat.light;
        flow oxygen to treat.oxygen;
        flow treat.ros to ros;
        flow treat.drug to drug;
    }

    part def TumorSite {
        ref item tumor : Tumor;
        part nanoparticles : Nanoparticle[*];

        part externalLaser {
            attribute outputWavelength : Wavelength = 700 [nm];
            out item light : Light;
        }

        part tumorCells : CancerCell[*];
        part healthyCells : HealthyCell[*];

        flow externalLaser.light to nanoparticles.light;
    }

    requirement def TargetingRequirement {
        subject np : Nanoparticle;
        doc /* The nanoparticle shall selectively accumulate at tumor sites
             via its functional coating, binding to cancer cells while
             ignoring healthy cells. */
    }

    requirement def DormancyRequirement {
        subject np : Nanoparticle;
        doc /* The nanoparticle shall remain dormant until activated by
             light of the specified wavelength. */
        attribute requiredWavelength : Wavelength = 700 [nm];
    }

    requirement def DualTherapyRequirement {
        subject np : Nanoparticle;
        doc /* The nanoparticle shall deliver a two-pronged attack: ROS
             generation followed by drug payload release triggered by
             critical ROS concentration. */
        attribute rosThreshold : Concentration = 1e-6;
    }

    requirement def LocalizationRequirement {
        subject np : Nanoparticle;
        doc /* The therapeutic effects shall be localized to the tumor
             area, minimizing damage to healthy tissue. */
    }

    requirement def BiocompatibilityRequirement {
        subject np : Nanoparticle;
        doc /* The functional coating shall be biocompatible to ensure
             safe circulation within the body. */
    }

    requirement targeting : TargetingRequirement;
    requirement dormancy : DormancyRequirement;
    requirement dualTherapy : DualTherapyRequirement;
    requirement localization : LocalizationRequirement;
    requirement biocompatibility : BiocompatibilityRequirement;

    part nanoparticleSystem : Nanoparticle;

    satisfy targeting by nanoparticleSystem.coating;
    satisfy dormancy by nanoparticleSystem.psLayer;
    satisfy dualTherapy by nanoparticleSystem;
    satisfy localization by nanoparticleSystem.payload;
    satisfy biocompatibility by nanoparticleSystem.coating;
}
