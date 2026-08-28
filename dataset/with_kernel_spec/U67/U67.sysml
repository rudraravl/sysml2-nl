package MedicalGloveSystem {
    private import ScalarValues::*;

    attribute def Thickness :> Real;
    attribute def Length :> Real;
    attribute def Force :> Real;
    attribute def TensileStrength :> Real;
    attribute def PermeationResistance :> Real;
    attribute def GripCoefficient :> Real;

    enum def MaterialType {
        nitrile;
        latex;
        vinyl;
    }

    enum def GloveSize {
        small;
        medium;
        large;
        extraLarge;
    }

    enum def Sterility {
        sterile;
        nonSterile;
    }

    item def Contaminant;
    item def BodyFluid :> Contaminant;
    item def Pathogen :> Contaminant;
    item def ChemicalAgent :> Contaminant;

    port def HandInterface;
    port def EnvironmentInterface;
    port def BarrierPort;
    port def GripPort;
    port def CuffPort;

    part def BarrierMaterial {
        attribute materialType : MaterialType;
        attribute thickness : Thickness;
        attribute permeationResistance : PermeationResistance;
        attribute structuralIntegrity : TensileStrength;
        attribute integrityIntact : Boolean;
        port barrierPort : BarrierPort;
    }

    part def TexturedSurface {
        attribute coversFingers : Boolean = true;
        attribute coversPalm : Boolean = true;
        attribute wetGripEnhancement : Boolean = true;
        attribute dryGripEnhancement : Boolean = true;
        attribute gripCoefficient : GripCoefficient;
        port gripPort : GripPort;
    }

    part def CuffSection {
        attribute length : Length;
        attribute rollDownResistance : Force;
        port cuffPort : CuffPort;
    }

    part def HealthcareProfessional;
    part def Patient;

    part def MedicalGlove {
        attribute size : GloveSize;
        attribute sterility : Sterility;
        attribute isAmbidextrous : Boolean = true;
        attribute tactileSensitivity : Real;
        attribute dexterity : Real;

        part barrier : BarrierMaterial;
        part texture : TexturedSurface;
        part cuff : CuffSection;

        port handPort : HandInterface;
        port environmentPort : EnvironmentInterface;

        connect barrier.barrierPort to environmentPort;
        connect texture.gripPort to handPort;
        connect cuff.cuffPort to handPort;

        ref part wearer : HealthcareProfessional[0..1];

        action monitorIntegrity;

        state def GloveLifecycle {
            entry; then packaged;
            state packaged;
            transition packaged to donned;
            state donned;
            transition donned to inUse;
            state inUse {
                entry / monitorIntegrity();
            }
            state compromised;
            transition inUse to compromised;
            transition inUse to disposed;
            transition compromised to disposed;
            state disposed;
        }

        state machine lifecycle : GloveLifecycle;
    }

    requirement def BarrierProtectionRequirement {
        doc /* The glove shall provide a physical barrier against body fluids, pathogens, and chemical agents. */
        attribute minThickness : Thickness = 0.1;
        attribute minPermeationResistance : PermeationResistance = 4.0;
        subject glove : MedicalGlove;
        require glove.barrier.thickness >= minThickness;
        require glove.barrier.permeationResistance >= minPermeationResistance;
    }

    requirement def GripRequirement {
        doc /* The glove shall provide adequate grip in wet and dry conditions. */
        subject glove : MedicalGlove;
        require glove.texture.wetGripEnhancement == true;
        require glove.texture.dryGripEnhancement == true;
    }

    requirement def SecureFitRequirement {
        doc /* The cuff shall secure the glove and prevent rolling down during use. */
        attribute minLength : Length = 50.0;
        attribute minRollDownResistance : Force = 5.0;
        subject glove : MedicalGlove;
        require glove.cuff.length >= minLength;
        require glove.cuff.rollDownResistance >= minRollDownResistance;
    }

    requirement def TactilePerformanceRequirement {
        doc /* The glove shall maintain high tactile sensitivity and dexterity for medical tasks. */
        attribute minTactileSensitivity : Real = 0.8;
        attribute minDexterity : Real = 0.8;
        subject glove : MedicalGlove;
        require glove.tactileSensitivity >= minTactileSensitivity;
        require glove.dexterity >= minDexterity;
    }

    requirement def SterilityRequirement {
        doc /* The glove shall be available in sterile or non-sterile configurations and packaged accordingly. */
        subject glove : MedicalGlove;
        require glove.sterility == Sterility::sterile or glove.sterility == Sterility::nonSterile;
    }

    part gloveSystem : MedicalGlove {
        attribute :>> size = GloveSize::medium;
        attribute :>> sterility = Sterility::sterile;
        attribute :>> isAmbidextrous = true;
        attribute :>> tactileSensitivity = 0.85;
        attribute :>> dexterity = 0.90;

        part :>> barrier {
            attribute :>> materialType = MaterialType::nitrile;
            attribute :>> thickness = 0.15;
            attribute :>> permeationResistance = 5.0;
            attribute :>> structuralIntegrity = 20.0;
            attribute :>> integrityIntact = true;
        }
        part :>> texture {
            attribute :>> coversFingers = true;
            attribute :>> coversPalm = true;
            attribute :>> wetGripEnhancement = true;
            attribute :>> dryGripEnhancement = true;
            attribute :>> gripCoefficient = 1.2;
        }
        part :>> cuff {
            attribute :>> length = 55.0;
            attribute :>> rollDownResistance = 6.0;
        }
    }

    satisfy BarrierProtectionRequirement by gloveSystem;
    satisfy GripRequirement by gloveSystem;
    satisfy SecureFitRequirement by gloveSystem;
    satisfy TactilePerformanceRequirement by gloveSystem;
    satisfy SterilityRequirement by gloveSystem;
}
