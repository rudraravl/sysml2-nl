package CRISPR_Cas9_GeneEditing {

    import ScalarValues::*;

    // ---- Units ----
    unit nt;
    unit kJ_per_mol = "kJ/mol";
    unit percent = "%";
    unit nM;

    // ---- Value Types ----
    value type NucleotideCount > Real {
        unit nt;
    }

    value type BindingAffinityValue > Real {
        unit kJ_per_mol;
    }

    value type EfficiencyValue > Real {
        unit percent;
    }

    value type ConcentrationValue > Real {
        unit nM;
    }

    // ---- Item Definitions ----
    item def DNASequence {
        attribute length : NucleotideCount;
        attribute sequence : String;
        attribute isDoubleStranded : Boolean default true;
    }

    item def GuideRNA {
        attribute spacerLength : NucleotideCount;
        attribute targetMatchSequence : String;
        attribute concentration : ConcentrationValue;
    }

    item def Cas9Protein {
        attribute isActive : Boolean default true;
        attribute concentration : ConcentrationValue;
    }

    item def RNPComplex {
        attribute guideRNA : GuideRNA;
        attribute cas9 : Cas9Protein;
        attribute isAssembled : Boolean default false;
        attribute bindingAffinity : BindingAffinityValue;
    }

    item def RepairTemplate {
        attribute payloadSequence : String;
        attribute homologyArmLength : NucleotideCount;
    }

    item def CutSite {
        attribute position : NucleotideCount;
        attribute bothStrandsCut : Boolean default false;
    }

    item def EditedDNA {
        attribute sequence : String;
        attribute editsApplied : NucleotideCount;
        attribute editingEfficiency : EfficiencyValue;
    }

    // ---- Port Definitions ----
    port def GuideRNAOutPort {
        out guide : GuideRNA;
    }

    port def GuideRNAInPort {
        in guide : GuideRNA;
    }

    port def Cas9OutPort {
        out cas9 : Cas9Protein;
    }

    port def Cas9InPort {
        in cas9 : Cas9Protein;
    }

    port def RNPOutPort {
        out rnp : RNPComplex;
    }

    port def RNPInPort {
        in rnp : RNPComplex;
    }

    port def DNAInPort {
        in dna : DNASequence;
    }

    port def DNAOutPort {
        out dna : DNASequence;
    }

    port def PositionOutPort {
        out position : NucleotideCount;
    }

    port def PositionInPort {
        in position : NucleotideCount;
    }

    port def CutOutPort {
        out cut : CutSite;
    }

    port def CutInPort {
        in cut : CutSite;
    }

    port def RepairTemplateInPort {
        in template : RepairTemplate;
    }

    port def EditedDNAOutPort {
        out editedDna : EditedDNA;
    }

    // ---- Action Definitions ----
    action def ProduceGuideRNA {
        out guide : GuideRNA;
    }

    action def ProduceCas9 {
        out cas9 : Cas9Protein;
    }

    action def AssembleRNP {
        in guide : GuideRNA;
        in cas9 : Cas9Protein;
        out rnp : RNPComplex;
    }

    action def ScanDNA {
        in rnp : RNPComplex;
        in dna : DNASequence;
        out position : NucleotideCount;
    }

    action def CleaveDNA {
        in dna : DNASequence;
        in position : NucleotideCount;
        out cut : CutSite;
    }

    action def RepairDNA {
        in dna : DNASequence;
        in cut : CutSite;
        in template : RepairTemplate;
        out edited : EditedDNA;
    }

    // ---- Part Definitions ----
    part def GuideRNAProduction {
        port out guideOut : GuideRNAOutPort;
        attribute producedGuide : GuideRNA;
        perform produceGuide : ProduceGuideRNA;
    }

    part def Cas9Production {
        port out cas9Out : Cas9OutPort;
        attribute producedCas9 : Cas9Protein;
        perform produceCas9 : ProduceCas9;
    }

    part def RNPAssemblyUnit {
        port in guideIn : GuideRNAInPort;
        port in cas9In : Cas9InPort;
        port out rnpOut : RNPOutPort;
        attribute assembledRNP : RNPComplex;
        perform assemble : AssembleRNP;
    }

    part def DNATargetHolder {
        port in dnaIn : DNAInPort;
        port out dnaOut : DNAOutPort;
        attribute targetDNA : DNASequence;
    }

    part def ScanningUnit {
        port in rnpIn : RNPInPort;
        port in dnaIn : DNAInPort;
        port out dnaOut : DNAOutPort;
        port out positionOut : PositionOutPort;
        attribute scanPosition : NucleotideCount;
        attribute targetFound : Boolean default false;
        perform scan : ScanDNA;
    }

    part def CleavageUnit {
        port in dnaIn : DNAInPort;
        port in positionIn : PositionInPort;
        port out dnaOut : DNAOutPort;
        port out cutOut : CutOutPort;
        attribute cutSite : CutSite;
        perform cleave : CleaveDNA;
    }

    part def RepairUnit {
        port in dnaIn : DNAInPort;
        port in cutIn : CutInPort;
        port in templateIn : RepairTemplateInPort;
        port out editedOut : EditedDNAOutPort;
        perform repair : RepairDNA;
    }

    // ---- Top-Level System ----
    part def CRISPR_Cas9_System {
        port in targetDNAIn : DNAInPort;
        port in repairTemplateIn : RepairTemplateInPort;
        port out editedDNAOut : EditedDNAOutPort;

        attribute rnpAssembled : Boolean default false;
        attribute targetFound : Boolean default false;
        attribute dnaCut : Boolean default false;
        attribute editingComplete : Boolean default false;

        part guideProduction : GuideRNAProduction;
        part cas9Production : Cas9Production;
        part rnpAssembly : RNPAssemblyUnit;
        part dnaTarget : DNATargetHolder;
        part scanning : ScanningUnit;
        part cleavage : CleavageUnit;
        part repair : RepairUnit;

        connection guideFlow connect guideProduction.guideOut to rnpAssembly.guideIn;
        connection cas9Flow connect cas9Production.cas9Out to rnpAssembly.cas9In;
        connection rnpFlow connect rnpAssembly.rnpOut to scanning.rnpIn;
        connection targetDNAFlow connect targetDNAIn to dnaTarget.dnaIn;
        connection dnaToScanning connect dnaTarget.dnaOut to scanning.dnaIn;
        connection scannedDNA connect scanning.dnaOut to cleavage.dnaIn;
        connection positionFlow connect scanning.positionOut to cleavage.positionIn;
        connection cleavedDNA connect cleavage.dnaOut to repair.dnaIn;
        connection cutFlow connect cleavage.cutOut to repair.cutIn;
        connection templateFlow connect repairTemplateIn to repair.templateIn;
        connection editedFlow connect repair.editedOut to editedDNAOut;

        state machine EditingLifecycle {
            state Idle;
            state AssemblingRNP;
            state ScanningDNA;
            state TargetRecognized;
            state CleavingDNA;
            state DNACut;
            state RepairingDNA;
            state EditingComplete;

            transition t1
                from Idle to AssemblingRNP
                when targetDNAIn.dna != null;

            transition t2
                from AssemblingRNP to ScanningDNA
                when rnpAssembled == true;

            transition t3
                from ScanningDNA to TargetRecognized
                when scanning.targetFound == true;

            transition t4
                from TargetRecognized to CleavingDNA;

            transition t5
                from CleavingDNA to DNACut
                when cleavage.cutSite.bothStrandsCut == true;

            transition t6
                from DNACut to RepairingDNA
                when repairTemplateIn.template != null;

            transition t7
                from RepairingDNA to EditingComplete
                when editingComplete == true;
        }

        // ---- Requirements ----
        requirement rnpAssemblyReq : RNPAssemblyRequirement;
        requirement targetRecogReq : TargetRecognitionRequirement;
        requirement doubleStrandReq : DoubleStrandBreakRequirement;
        requirement efficiencyReq : EditingEfficiencyRequirement;
        requirement outputReq : EditedDNAOutputRequirement;

        satisfy rnpAssemblyReq by rnpAssembly.assembledRNP;
        satisfy targetRecogReq by scanning;
        satisfy doubleStrandReq by cleavage.cutSite;
        satisfy efficiencyReq by repair.editedOut.editedDna;
        satisfy outputReq by editedDNAOut.editedDna;
    }

    // ---- Requirement Definitions ----
    requirement def RNPAssemblyRequirement {
        doc /* The RNP complex must be properly assembled from Guide RNA and Cas9 protein. */;
        subject rnp : RNPComplex;
        constraint { rnp.isAssembled == true; }
    }

    requirement def TargetRecognitionRequirement {
        doc /* The Guide RNA must find and bind to the matching target DNA sequence. */;
        subject scanning : ScanningUnit;
        constraint { scanning.targetFound == true; }
    }

    requirement def DoubleStrandBreakRequirement {
        doc /* Cas9 must cut both strands of the DNA at the recognized target site. */;
        subject cut : CutSite;
        constraint { cut.bothStrandsCut == true; }
    }

    requirement def EditingEfficiencyRequirement {
        doc /* The overall editing efficiency must be at least 70 percent. */;
        subject edited : EditedDNA;
        constraint { edited.editingEfficiency >= 70.0; }
    }

    requirement def EditedDNAOutputRequirement {
        doc /* The system must output an edited DNA strand incorporating the intended changes. */;
        subject editedDna : EditedDNA;
        constraint { editedDna.editsApplied > 0; }
    }

}
