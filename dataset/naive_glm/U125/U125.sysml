package SurgicalMeshSystem {
    import SI::*;
    import ScalarValues::*;

    // ===== Unit Definitions =====
    unit def mm :> m;
    unit def um :> m;
    unit def cm :> m;
    unit def day :> s;
    unit def g :> kg;
    unit def N_per_cm;
    unit def g_per_cm3;
    unit def cm2;

    // ===== Value Types =====
    value type TensileStrengthValue :> Real { unit N_per_cm; }
    value type PoreSizeValue :> Real { unit um; }
    value type ForceValue :> Real { unit N; }
    value type ThicknessValue :> Real { unit mm; }
    value type AreaValue :> Real { unit cm2; }
    value type DurationValue :> Real { unit day; }
    value type PressureValue :> Real { unit Pa; }
    value type MassValue :> Real { unit g; }
    value type DensityValue :> Real { unit g_per_cm3; }

    // ===== Enumerations =====
    enum def MaterialType { synthetic; biological; composite; }
    enum def AbsorbabilityType { absorbable; permanent; }
    enum def BiocompatibilityGrade { excellent; good; moderate; poor; }

    // ===== Item Definitions =====
    item def MechanicalLoad {
        attribute magnitude : ForceValue;
        attribute directionX : Real;
        attribute directionY : Real;
        attribute directionZ : Real;
        attribute source : String;
    }

    item def DistributedLoad {
        attribute magnitude : ForceValue;
        attribute distributionArea : AreaValue;
        attribute pressure : PressureValue;
        attribute distributionFactor : Real;
    }

    item def CellPopulation {
        attribute cellDensity : DensityValue;
        attribute growthRate : Real;
        attribute viability : Real;
        attribute cellType : String;
    }

    item def TissueIngrowth {
        attribute ingrowthPercentage : Real;
        attribute cellPopulation : CellPopulation;
        attribute maturityLevel : Real;
        attribute collagenDensity : DensityValue;
    }

    item def BiologicalResponse {
        attribute inflammationLevel : Real;
        attribute fibrosisLevel : Real;
        attribute angiogenesisLevel : Real;
        attribute immuneResponseLevel : Real;
    }

    // ===== Port Definitions =====
    port def MechanicalInterfacePort {
        in item appliedLoad : MechanicalLoad;
        out item distributedLoad : DistributedLoad;
    }

    port def BiologicalInterfacePort {
        in item incomingCells : CellPopulation;
        out item tissueIngrowth : TissueIngrowth;
        out item biologicalResponse : BiologicalResponse;
    }

    // ===== Part: Surgical Mesh =====
    part def SurgicalMesh {
        doc /* Specialized medical implant designed to reinforce and support weakened or damaged biological tissue. */;

        attribute materialType : MaterialType;
        attribute absorbability : AbsorbabilityType;
        attribute biocompatibility : BiocompatibilityGrade;
        attribute tensileStrength : TensileStrengthValue;
        attribute poreSize : PoreSizeValue;
        attribute thickness : ThicknessValue;
        attribute meshArea : AreaValue;
        attribute meshMass : MassValue;
        attribute porosity : Real;
        attribute degradationComplete : Boolean;

        port mechanicalInterface : MechanicalInterfacePort;
        port biologicalInterface : BiologicalInterfacePort;

        action distributeLoad {
            in load : MechanicalLoad;
            out distributed : DistributedLoad;
        }

        action promoteIngrowth {
            in cells : CellPopulation;
            out ingrowth : TissueIngrowth;
        }

        action degrade {
            out degradationRate : Real;
        }

        state def MeshState {
            entry; then Intact;

            state Intact {
                do action {
                    // Mesh maintains structural integrity and distributes mechanical loads
                }
            }

            transition from Intact to Degrading
                when absorbability == AbsorbabilityType::absorbable;

            state Degrading {
                do degrade;
            }

            transition from Degrading to Absorbed
                when degradationComplete;

            state Absorbed {
                entry action {
                    // Mesh fully dissolved; remodeled tissue provides reinforcement
                }
            }
        }
    }

    // ===== Part: Surrounding Tissue =====
    part def SurroundingTissue {
        doc /* Biological tissue surrounding and interacting with the surgical mesh implant. */;

        attribute tissueType : String;
        attribute tissueThickness : ThicknessValue;
        attribute tissueArea : AreaValue;
        attribute baselineStrength : TensileStrengthValue;
        attribute healingCapacity : Real;
        attribute bloodSupply : Real;
        attribute elasticity : Real;

        port mechanicalPort : ~MechanicalInterfacePort;
        port biologicalPort : ~BiologicalInterfacePort;

        action exertForce {
            out load : MechanicalLoad;
        }

        action respondToMesh {
            in ingrowth : TissueIngrowth;
            in response : BiologicalResponse;
            out updatedCells : CellPopulation;
        }

        action remodel {
            in currentIngrowth : TissueIngrowth;
            out remodeledTissue : TissueIngrowth;
        }
    }

    // ===== System Assembly =====
    part def MeshTissueSystem {
        doc /* Complete surgical mesh system comprising the mesh implant and surrounding body tissue. */;

        attribute currentIngrowthPercentage : Real;
        attribute currentMaturityLevel : Real;
        attribute healingTime : DurationValue;
        attribute currentStage : String;

        part mesh : SurgicalMesh {
            attribute materialType = MaterialType::composite;
            attribute absorbability = AbsorbabilityType::permanent;
            attribute biocompatibility = BiocompatibilityGrade::excellent;
            attribute tensileStrength = 50.0;
            attribute poreSize = 800.0;
            attribute thickness = 0.5;
            attribute meshArea = 100.0;
            attribute meshMass = 15.0;
            attribute porosity = 0.65;
            attribute degradationComplete = false;
        }

        part tissue : SurroundingTissue {
            attribute tissueType = "abdominal fascia";
            attribute tissueThickness = 3.0;
            attribute tissueArea = 120.0;
            attribute baselineStrength = 20.0;
            attribute healingCapacity = 0.8;
            attribute bloodSupply = 0.7;
            attribute elasticity = 0.3;
        }

        connection mechanicalLink connect tissue.mechanicalPort to mesh.mechanicalInterface;
        connection biologicalLink connect tissue.biologicalPort to mesh.biologicalInterface;

        state def HealingLifecycle {
            entry; then InitialPlacement;

            state InitialPlacement {
                doc /* Mesh placed in body; initial tissue contact established. */;
                entry action {
                    currentStage = "initialPlacement";
                }
                do action {
                    // Mesh absorbs and distributes physical forces from surrounding tissue
                    // Tissue begins initial biological response to implant presence
                }
            }

            transition from InitialPlacement to EarlyIntegration
                when currentIngrowthPercentage > 0.0;

            state EarlyIntegration {
                doc /* Cells begin growing into mesh scaffold; tissue integration starts. */;
                entry action {
                    currentStage = "earlyIntegration";
                }
                do action {
                    // Mesh porous structure promotes cell migration and proliferation
                    // Fibroblasts deposit extracellular matrix within mesh pores
                }
            }

            transition from EarlyIntegration to TissueStabilization
                when currentIngrowthPercentage > 30.0;

            state TissueStabilization {
                doc /* New tissue within mesh matures; mechanical stability improves. */;
                entry action {
                    currentStage = "tissueStabilization";
                }
                do action {
                    // Collagen matrix matures and cross-links within mesh structure
                    // Mesh continues distributing mechanical loads during maturation
                }
            }

            transition from TissueStabilization to FullIntegration
                when currentIngrowthPercentage > 80.0
                    and currentMaturityLevel > 0.7;

            state FullIntegration {
                doc /* Mesh fully incorporated into body; repair stable and complete. */;
                entry action {
                    currentStage = "fullIntegration";
                }
                do action {
                    // Mesh-tissue composite provides permanent reinforcement
                    // Tissue homeostasis maintained around integrated mesh
                }
            }
        }
    }

    // ===== Requirements =====
    requirement def StrengthRequirement {
        doc /* Mesh must have sufficient tensile strength to handle physical loads from surrounding tissue. */;
        attribute minTensileStrength : TensileStrengthValue;
        subject mesh : SurgicalMesh;
        require { mesh.tensileStrength >= minTensileStrength }
    }

    requirement def BiocompatibilityRequirement {
        doc /* Mesh must minimize adverse biological reactions in surrounding tissue. */;
        subject mesh : SurgicalMesh;
        require {
            mesh.biocompatibility == BiocompatibilityGrade::excellent
            or mesh.biocompatibility == BiocompatibilityGrade::good
        }
    }

    requirement def PoreSizeRequirement {
        doc /* Pore size must promote tissue ingrowth while maintaining structural integrity. */;
        attribute minPoreSize : PoreSizeValue;
        attribute maxPoreSize : PoreSizeValue;
        subject mesh : SurgicalMesh;
        require { mesh.poreSize >= minPoreSize and mesh.poreSize <= maxPoreSize }
    }

    requirement def HealingTimeRequirement {
        doc /* Healing process must complete within a clinically acceptable timeframe. */;
        attribute maxHealingTime : DurationValue;
        subject system : MeshTissueSystem;
        require { system.healingTime <= maxHealingTime }
    }

    requirement def LoadDistributionRequirement {
        doc /* Mesh must distribute mechanical loads to prevent re-injury of surrounding tissue. */;
        subject mesh : SurgicalMesh;
        subject tissue : SurroundingTissue;
        require {
            mesh.mechanicalInterface.distributedLoad.pressure
                < tissue.baselineStrength
        }
    }

    requirement def TissueIntegrationRequirement {
        doc /* Mesh must achieve sufficient tissue ingrowth for stable integration. */;
        attribute minIngrowthPercentage : Real;
        subject system : MeshTissueSystem;
        require { system.currentIngrowthPercentage >= minIngrowthPercentage }
    }

    requirement def ContinuousReinforcementRequirement {
        doc /* System must provide continuous reinforcement throughout the healing process. */;
        subject system : MeshTissueSystem;
        require { system.mesh.tensileStrength >= system.tissue.baselineStrength }
    }

    // ===== Requirement Instances =====
    requirement meshStrengthReq : StrengthRequirement {
        attribute minTensileStrength = 30.0;
    }

    requirement meshBiocompatibilityReq : BiocompatibilityRequirement;

    requirement meshPoreSizeReq : PoreSizeRequirement {
        attribute minPoreSize = 100.0;
        attribute maxPoreSize = 2000.0;
    }

    requirement healingTimeReq : HealingTimeRequirement {
        attribute maxHealingTime = 90.0;
    }

    requirement loadDistributionReq : LoadDistributionRequirement;

    requirement tissueIntegrationReq : TissueIntegrationRequirement {
        attribute minIngrowthPercentage = 80.0;
    }

    requirement continuousReinforcementReq : ContinuousReinforcementRequirement;

    // ===== Satisfaction =====
    satisfy meshStrengthReq by SurgicalMesh;
    satisfy meshBiocompatibilityReq by SurgicalMesh;
    satisfy meshPoreSizeReq by SurgicalMesh;
    satisfy healingTimeReq by MeshTissueSystem;
    satisfy loadDistributionReq by SurgicalMesh;
    satisfy tissueIntegrationReq by MeshTissueSystem;
    satisfy continuousReinforcementReq by MeshTissueSystem;
}
