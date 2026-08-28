package MedicalGloveSystem {
    import ScalarValues::*;
    import ISQ::*;

    // ---- Value types with units ----
    value type Thickness :> Real {
        attribute unit : String = "mm";
    }
    value type Length :> Real {
        attribute unit : String = "mm";
    }
    value type Resistance :> Real {
        attribute unit : String = "N";
    }
    value type PermeationResistance :> Real {
        attribute unit : String = "kPa";
    }
    value type GripCoefficient :> Real {
        attribute unit : String = "dimensionless";
    }
    value type TactileSensitivity :> Real {
        attribute unit : String = "dimensionless";
    }
    value type TensileStrength :> Real {
        attribute unit : String = "MPa";
    }
    value type Elongation :> Real {
        attribute unit : String = "percent";
    }

    // ---- Enumerations ----
    enum MaterialType { nitrile, latex, vinyl }
    enum GloveSize { XS, S, M, L, XL }
    enum Sterility { sterile, nonSterile }
    enum Handedness { left, right, ambidextrous }
    enum ContaminantType { bodyFluid, pathogen, chemicalAgent }

    // ---- Item types ----
    item def Contaminant {
        attribute contaminantType : ContaminantType;
        attribute concentration : Real;
    }

    item def Fluid {
        attribute viscosity : Real;
        attribute ph : Real;
    }

    // ---- Requirements ----
    requirement def PhysicalBarrierRequirement {
        doc << "The glove shall provide a physical barrier protecting healthcare professionals and patients from cross-contamination during clinical procedures.">>
        objective barrierProtection;
    }

    requirement def BarrierMaterialRequirement {
        doc << "The barrier material shall resist permeation by fluids and pathogens.">>
        subject barrierMaterial : BarrierMaterial;
        constraint { barrierMaterial.permeationResistance >= 10.0 [kPa] }
        constraint { barrierMaterial.thickness >= 0.08 [mm] }
        constraint { barrierMaterial.tensileStrength >= 14.0 [MPa] }
    }

    requirement def GripRequirement {
        doc << "The textured surface shall provide grip in both wet and dry conditions.">>
        subject texturedSurface : TexturedSurface;
        constraint { texturedSurface.dryGripCoefficient >= 0.6 }
        constraint { texturedSurface.wetGripCoefficient >= 0.4 }
    }

    requirement def CuffRequirement {
        doc << "The cuff shall secure the glove around the wrist and resist rolling down during use.">>
        subject cuff : Cuff;
        constraint { cuff.length >= 25.0 [mm] }
        constraint { cuff.rollResistance >= 2.0 [N] }
    }

    requirement def TactileSensitivityRequirement {
        doc << "The glove shall maintain tactile sensitivity and dexterity required for medical tasks.">>
        subject glove : MedicalGlove;
        constraint { glove.tactileSensitivity >= 0.7 }
    }

    requirement def StructuralIntegrityRequirement {
        doc << "The glove shall maintain structural integrity throughout its in-use lifecycle.">>
        subject glove : MedicalGlove;
        constraint { glove.barrierMaterial.elongationAtBreak >= 500.0 [percent] }
    }

    // ---- Part definitions ----
    part def BarrierMaterial {
        attribute materialType : MaterialType = MaterialType::nitrile;
        attribute thickness : Thickness = 0.1;
        attribute permeationResistance : PermeationResistance = 20.0;
        attribute tensileStrength : TensileStrength = 20.0;
        attribute elongationAtBreak : Elongation = 600.0;
        attribute integrityIntact : Boolean = true;

        action def ResistPermeation {
            in contaminant : Contaminant;
            out resisted : Boolean;
        }
    }

    part def TexturedSurface {
        attribute location : String = "fingers and palm";
        attribute dryGripCoefficient : GripCoefficient = 0.7;
        attribute wetGripCoefficient : GripCoefficient = 0.5;
        attribute patternType : String = "microTexture";

        action def ProvideGrip {
            in condition : String;
            out gripQuality : GripCoefficient;
        }
    }

    part def Cuff {
        attribute length : Length = 30.0;
        attribute rollResistance : Resistance = 3.0;
        attribute fitType : String = "beaded";

        action def SecureFit {
            in wristCircumference : Length;
            out secured : Boolean;
        }
    }

    // ---- Ports ----
    port def BarrierPort {
        in item contaminant : Contaminant;
        out item blockedContaminant : Contaminant;
    }

    port def GripPort {
        out attribute gripCoefficient : GripCoefficient;
    }

    port def CuffPort {
        out attribute secured : Boolean;
    }

    // ---- Main glove part ----
    part def MedicalGlove {
        attribute size : GloveSize = GloveSize::M;
        attribute sterility : Sterility = Sterility::sterile;
        attribute handedness : Handedness = Handedness::ambidextrous;
        attribute tactileSensitivity : TactileSensitivity = 0.8;
        attribute isCompromised : Boolean = false;

        part barrierMaterial : BarrierMaterial {
            port barrierInterface : BarrierPort;
        }

        part texturedSurface : TexturedSurface {
            port gripInterface : GripPort;
        }

        part cuff : Cuff {
            port cuffInterface : CuffPort;
        }

        // Internal connections
        connection barrierToGrip connect barrierMaterial.barrierInterface to texturedSurface.gripInterface;
        connection gripToCuff connect texturedSurface.gripInterface to cuff.cuffInterface;

        // ---- State machine for lifecycle ----
        state def GloveLifecycle {
            state packaged {
                entry { glove.sterility = Sterility::sterile; }
            }

            state donned {
                entry { glove.isCompromised = false; }
            }

            state inUse {
                entry { glove.barrierMaterial.integrityIntact = true; }
            }

            state compromised {
                entry { glove.isCompromised = true; glove.barrierMaterial.integrityIntact = false; }
            }

            state disposed {
                entry { glove.sterility = Sterility::nonSterile; }
            }

            transition packaged_to_donned
                source packaged
                target donned
                accept DonSignal;

            transition donned_to_inUse
                source donned
                target inUse
                accept UseSignal;

            transition inUse_to_compromised
                source inUse
                target compromised
                accept BreachSignal
                guard { glove.barrierMaterial.integrityIntact == false };

            transition inUse_to_disposed
                source inUse
                target disposed
                accept RemoveSignal
                guard { glove.barrierMaterial.integrityIntact == true };

            transition compromised_to_disposed
                source compromised
                target disposed
                accept RemoveSignal;
        }

        // ---- Actions ----
        action def DonGlove {
            in glove : MedicalGlove;
            out donned : Boolean;
            perform {
                glove.barrierMaterial.integrityIntact = true;
                glove.isCompromised = false;
                donned = true;
            }
        }

        action def MonitorIntegrity {
            in glove : MedicalGlove;
            out compromised : Boolean;
            perform {
                if (glove.barrierMaterial.integrityIntact == false) {
                    glove.isCompromised = true;
                    compromised = true;
                } else {
                    compromised = false;
                }
            }
        }

        action def RemoveAndDispose {
            in glove : MedicalGlove;
            out disposed : Boolean;
            perform {
                glove.sterility = Sterility::nonSterile;
                disposed = true;
            }
        }

        action def ProvideBarrierProtection {
            in contaminant : Contaminant;
            out blocked : Boolean;
            perform {
                blocked = (barrierMaterial.permeationResistance >= 10.0);
            }
        }

        // ---- Signals ----        item def DonSignal;
        item def UseSignal;
        item def BreachSignal;
        item def RemoveSignal;

        // Requirement satisfaction
        satisfy PhysicalBarrierRequirement by glove;
        satisfy TactileSensitivityRequirement by glove;
        satisfy StructuralIntegrityRequirement by glove;
        satisfy BarrierMaterialRequirement by barrierMaterial;
        satisfy GripRequirement by texturedSurface;
        satisfy CuffRequirement by cuff;
    }

    // ---- System context ----
    part MedicalGloveSystem {
        part glove : MedicalGlove {
            attribute size : GloveSize = GloveSize::M;
            attribute sterility : Sterility = Sterility::sterile;
            attribute handedness : Handedness = Handedness::ambidextrous;
        }

        part wearer {
            attribute role : String = "healthcare professional";
        }

        part patient {
            attribute role : String = "patient";
        }

        connection wearerToGlove connect wearer to glove.cuff.cuffInterface;
        connection gloveToPatient connect glove.barrierMaterial.barrierInterface to patient;
    }
}
