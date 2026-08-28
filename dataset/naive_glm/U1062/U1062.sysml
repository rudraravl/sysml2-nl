package FullereneNanoparticleTherapy {

    import ScalarValues::*;
    import ISQ::*;
    import ISQSpace::*;

    // ============================================================
    // Value Types
    // ============================================================

    value type WavelengthValue :> LengthValue;

    value type EnergyValue :> Real {
        unit J;
    }

    value type ConcentrationValue :> Real {
        unit "mol/m^3";
    }

    value type MassValue :> Mass;

    value type DiameterValue :> LengthValue;

    value type CriticalROSConcentrationValue :> ConcentrationValue;

    // ============================================================
    // Item Types
    // ============================================================

    item def Carbon {
        attribute atomicNumber : Integer := 6;
    }

    item def Oxygen;

    item def ReactiveOxygenSpecies {
        attribute concentration : ConcentrationValue;
    }

    item def TherapeuticDrug {
        attribute mass : MassValue;
        attribute name : String;
    }

    item def TargetingMolecule {
        attribute specificity : Real;
    }

    item def BiocompatibleCoatingMaterial {
        attribute biocompatibilityScore : Real;
    }

    item def PhotosensitizerMaterial {
        attribute absorptionWavelength : WavelengthValue;
    }

    item def LaserLight {
        attribute wavelength : WavelengthValue;
        attribute energy : EnergyValue;
    }

    item def CancerCell;

    // ============================================================
    // Part Definitions
    // ============================================================

    part def FullereneCage {
        attribute atomCount : Integer := 60;
        attribute diameter : DiameterValue;
        item :>> carbonAtoms : Carbon[60];

        port exteriorSurfacePort {
            in item oxygen : Oxygen;
            out item ros : ReactiveOxygenSpecies;
        }

        port interiorChamberPort {
            out item drug : TherapeuticDrug;
        }
    }

    part def PhotosensitizingLayer {
        item :>> material : PhotosensitizerMaterial;
        attribute absorptionWavelength : WavelengthValue;

        port lightInputPort {
            in item light : LaserLight;
        }

        port energyOutputPort {
            out item transferredEnergy : LaserLight;
        }

        action def AbsorbLight {
            in light : LaserLight;
            out transferredEnergy : LaserLight;
        }

        action def GenerateROS {
            in oxygen : Oxygen;
            in transferredEnergy : LaserLight;
            out ros : ReactiveOxygenSpecies;
        }
    }

    part def PayloadChamber {
        item :>> storedDrug : TherapeuticDrug;
        attribute capacity : MassValue;
        attribute isOpen : Boolean := false;

        port drugReleasePort {
            out item releasedDrug : TherapeuticDrug;
        }

        port triggerPort {
            in item triggerROS : ReactiveOxygenSpecies;
        }

        action def ReleaseDrug {
            in trigger : ReactiveOxygenSpecies;
            out releasedDrug : TherapeuticDrug;
        }
    }

    part def FunctionalCoating {
        item :>> biocompatibleLayer : BiocompatibleCoatingMaterial;
        item :>> targetingMolecules : TargetingMolecule[0..*];

        port bindingPort {
            out item targetingSignal : TargetingMolecule;
        }
    }

    part def LightSource {
        attribute outputWavelength : WavelengthValue;
        attribute outputEnergy : EnergyValue;

        port lightOutputPort {
            out item emittedLight : LaserLight;
        }
    }

    part def TumorSite {
        item :>> cancerCells : CancerCell[0..*];
        item :>> oxygen : Oxygen;

        port tumorBindingPort {
            in item targetingSignal : TargetingMolecule;
        }

        port tumorLightPort {
            in item light : LaserLight;
        }

        port tumorDrugPort {
            in item drug : TherapeuticDrug;
        }

        port tumorROSPort {
            in item ros : ReactiveOxygenSpecies;
        }
    }

    part def Bloodstream {
        item :>> oxygen : Oxygen;

        port circulationPort {
            out item oxygen : Oxygen;
        }
    }

    // ============================================================
    // Main Nanoparticle System
    // ============================================================

    part def FullereneNanoparticle {

        attribute criticalROSLevel : CriticalROSConcentrationValue;

        part cage : FullereneCage {
            redefines diameter := 0.71e-9 [m];
        }

        part photosensitizingLayer : PhotosensitizingLayer {
            redefines absorptionWavelength := 660e-9 [m];
        }

        part payloadChamber : PayloadChamber {
            redefines storedDrug.mass := 1.0e-21 [kg];
        }

        part functionalCoating : FunctionalCoating;

        // Internal connections
        connection lightEnergyConn connect photosensitizingLayer.energyOutputPort to cage.exteriorSurfacePort;
        connection chamberTriggerConn connect cage.exteriorSurfacePort.ros to payloadChamber.triggerPort;
        connection chamberDrugConn connect cage.interiorChamberPort to payloadChamber.drugReleasePort;

        // External ports
        port externalLightPort {
            in item light : LaserLight;
        }
        port externalBindingPort {
            out item targetingSignal : TargetingMolecule;
        }
        port externalDrugReleasePort {
            out item releasedDrug : TherapeuticDrug;
        }
        port externalROSPort {
            out item ros : ReactiveOxygenSpecies;
        }
        port externalOxygenPort {
            in item oxygen : Oxygen;
        }

        // Connect external ports to internal parts
        connection extLightConn connect externalLightPort to photosensitizingLayer.lightInputPort;
        connection extBindingConn connect functionalCoating.bindingPort to externalBindingPort;
        connection extDrugConn connect payloadChamber.drugReleasePort to externalDrugReleasePort;
        connection extROSConn connect cage.exteriorSurfacePort.ros to externalROSPort;
        connection extOxygenConn connect externalOxygenPort to cage.exteriorSurfacePort;

        // ============================================================
        // State Machine
        // ============================================================

        state def NanoparticleStates {

            entry action initAction {
                // Initialize nanoparticle in dormant state
            }

            state dormant {
                entry action enterDormant {
                    // Nanoparticle circulates in bloodstream
                    // Functional coating binds to cancer cells at tumor site
                }
                do action circulateAndBind {
                    in targeting : TargetingMolecule;
                    out bound : Boolean;
                }
            }

            state rosGenerating {
                entry action enterROSGenerating {
                    // Photosensitizing layer absorbs light energy
                    // Converts nearby oxygen to ROS
                }
                do action generateROS : PhotosensitizingLayer::GenerateROS {
                    in oxygen : Oxygen;
                    in transferredEnergy : LaserLight;
                    out ros : ReactiveOxygenSpecies;
                }
            }

            state payloadReleasing {
                entry action enterPayloadReleasing {
                    // ROS concentration reached critical level
                    // Payload chamber opens, releases drug
                }
                do action releasePayload : PayloadChamber::ReleaseDrug {
                    in trigger : ReactiveOxygenSpecies;
                    out releasedDrug : TherapeuticDrug;
                }
            }

            transition dormant_to_rosGenerating
                first dormant then rosGenerating
                when externalLightPort.light.wavelength == photosensitizingLayer.absorptionWavelength;

            transition ros_to_payload
                first rosGenerating then payloadReleasing
                when payloadChamber.triggerPort.triggerROS.concentration >= criticalROSLevel;

            transition payload_to_terminal
                first payloadReleasing then dormant
                when payloadChamber.storedDrug.mass == 0 [kg];
        }

        exhibit state behavior : NanoparticleStates;
    }

    // ============================================================
    // Requirements
    // ============================================================

    requirement def TargetingRequirement {
        doc /* The nanoparticle must bind to cancer cells while largely ignoring healthy ones. */
        attribute bindingSpecificity : Real;
        constraint { bindingSpecificity >= 0.90 }
    }

    requirement def LightActivationRequirement {
        doc /* The photosensitizing layer must absorb light at a specific wavelength. */
        attribute requiredWavelength : WavelengthValue := 660e-9 [m];
        constraint { photosensitizingLayer.absorptionWavelength == requiredWavelength }
    }

    requirement def ROSGenerationRequirement {
        doc /* The system must generate reactive oxygen species when activated by light. */
        constraint { rosGenerating.generateROS.ros.concentration > 0 [mol/m^3] }
    }

    requirement def PayloadReleaseRequirement {
        doc /* The payload chamber must release its drug when ROS concentration reaches critical level. */
        constraint {
            payloadChamber.isOpen == true
            when payloadChamber.triggerPort.triggerROS.concentration >= criticalROSLevel
        }
    }

    requirement def BiocompatibilityRequirement {
        doc /* The functional coating must be biocompatible. */
        constraint { functionalCoating.biocompatibleLayer.biocompatibilityScore >= 0.85 }
    }

    requirement def LocalizationRequirement {
        doc /* Therapeutic effects must be localized to the targeted tumor area. */
        constraint { externalDrugReleasePort.releasedDrug.location == TumorSite }
    }

    requirement def DormancyRequirement {
        doc /* The nanoparticle must remain dormant until activated by light. */
        constraint { dormant.isActive == true until externalLightPort.light.energy > 0 [J] }
    }

    // ============================================================
    // Top-Level Therapy Context
    // ============================================================

    part therapySystem {

        part nanoparticles : FullereneNanoparticle[0..*] {
            redefines criticalROSLevel := 1.0e-6 [mol/m^3];
        }

        part lightSource : LightSource {
            redefines outputWavelength := 660e-9 [m];
            redefines outputEnergy := 5.0e-3 [J];
        }

        part tumor : TumorSite;

        part bloodstream : Bloodstream;

        // Connections
        connection lightDeliveryConn connect lightSource.lightOutputPort to tumor.tumorLightPort;
        connection nanoparticleLightConn connect lightSource.lightOutputPort to nanoparticles.externalLightPort;
        connection nanoparticleCirculationConn connect nanoparticles.externalBindingPort to tumor.tumorBindingPort;
        connection rosDeliveryConn connect nanoparticles.externalROSPort to tumor.tumorROSPort;
        connection drugDeliveryConn connect nanoparticles.externalDrugReleasePort to tumor.tumorDrugPort;
        connection oxygenSupplyConn connect bloodstream.circulationPort to nanoparticles.externalOxygenPort;

        // Requirement satisfaction
        satisfy TargetingRequirement by nanoparticles;
        satisfy LightActivationRequirement by nanoparticles;
        satisfy ROSGenerationRequirement by nanoparticles;
        satisfy PayloadReleaseRequirement by nanoparticles;
        satisfy BiocompatibilityRequirement by nanoparticles;
        satisfy LocalizationRequirement by nanoparticles;
        satisfy DormancyRequirement by nanoparticles;
    }
}
