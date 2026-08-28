package CRISPR_Cas9_Gene_Editing_System {
    private import ScalarValues::Real;
    private import ScalarValues::String;
    private import ScalarValues::Integer;
    private import ScalarValues::Boolean;

    item def DNA {
        attribute strand1 : String;
        attribute strand2 : String;
        attribute isDoubleStranded : Boolean = true;
        attribute cutSite : Integer[0..1];
    }

    item def TargetDNA :> DNA {
        attribute targetLocus : String;
    }

    item def EditedDNA :> DNA {
        attribute editApplied : Boolean = true;
    }

    item def GuideRNA {
        attribute sequence : String;
        attribute spacerSequence : String = sequence;
        attribute pamSequence : String = "NGG";
    }

    item def Cas9Protein {
        attribute name : String = "Cas9";
        attribute activeConformation : Boolean = false;
    }

    item def RNPComplex {
        ref cas9 : Cas9Protein;
        ref guide : GuideRNA;
        attribute isActive : Boolean = cas9.activeConformation;
    }

    item def RepairTemplate {
        attribute sequence : String;
        attribute homologyArmLeft : String;
        attribute homologyArmRight : String;
        attribute desiredEdit : String;
    }

    item def CutTrigger;
    item def CutComplete;
    item def RepairComplete;

    port def GuideRNAPort {
        out item guideRNA : GuideRNA;
    }

    port def Cas9Port {
        out item cas9 : Cas9Protein;
    }

    port def TemplatePort {
        out item template : RepairTemplate;
    }

    port def TargetDNAPort {
        out item targetDNA : TargetDNA;
    }

    port def EditedDNAPort {
        out item editedDNA : EditedDNA;
    }

    port def RNPPort {
        out item rnp : RNPComplex;
    }

    port def CutDNAPort {
        out item cutDNA : TargetDNA;
    }

    action def FormRNP {
        in guideRNA : GuideRNA;
        in cas9 : Cas9Protein;
        out complex : RNPComplex;
    }

    action def ScanAndBind {
        in complex : RNPComplex;
        in target : TargetDNA;
        out boundComplex : RNPComplex;
        out targetSite : TargetDNA;
    }

    action def CleaveDNA {
        in boundComplex : RNPComplex;
        in target : TargetDNA;
        out cutDNA : TargetDNA;
    }

    action def RepairDNA {
        in cutDNA : TargetDNA;
        in template : RepairTemplate;
        out editedDNA : EditedDNA;
    }

    action def CRISPREditing {
        in targetDNA : TargetDNA;
        in guideRNA : GuideRNA;
        in cas9 : Cas9Protein;
        in repairTemplate : RepairTemplate;
        out editedDNA : EditedDNA;
        attribute editingEfficiency : Real;
    }

    state def CRISPRStates {
        entry; then idle;
        state idle;
        transition idle_to_assembling
            first idle
            accept GuideRNA
            then assembling;
        state assembling;
        transition assembling_to_scanning
            first assembling
            accept RNPComplex
            then scanning;
        state scanning;
        transition scanning_to_bound
            first scanning
            accept TargetDNA
            then bound;
        state bound;
        transition bound_to_cutting
            first bound
            accept CutTrigger
            then cutting;
        state cutting;
        transition cutting_to_repairing
            first cutting
            accept CutComplete
            then repairing;
        state repairing;
        transition repairing_to_complete
            first repairing
            accept RepairComplete
            then complete;
        state complete;
    }

    part def GuideRNAModule {
        port outPort : GuideRNAPort;
        item guideRNA : GuideRNA;
        flow from guideRNA to outPort.guideRNA;
    }

    part def Cas9Module {
        port outPort : Cas9Port;
        item cas9 : Cas9Protein;
        flow from cas9 to outPort.cas9;
    }

    part def RepairTemplateModule {
        port outPort : TemplatePort;
        item template : RepairTemplate;
        flow from template to outPort.template;
    }

    part def TargetDNAModule {
        port outPort : TargetDNAPort;
        item targetDNA : TargetDNA;
        flow from targetDNA to outPort.targetDNA;
    }

    part def CRISPRCas9System {
        port guideRNAIn : ~GuideRNAPort;
        port cas9In : ~Cas9Port;
        port templateIn : ~TemplatePort;
        port targetDNAIn : ~TargetDNAPort;
        port editedDNAOut : EditedDNAPort;

        part rnpAssemblyUnit {
            port rnpOut : RNPPort;
            perform action formRNP : FormRNP {
                in guideRNA = guideRNAIn.guideRNA;
                in cas9 = cas9In.cas9;
                out complex = rnpOut.rnp;
            }
        }

        part cuttingUnit {
            port rnpIn : ~RNPPort;
            port cutDNAOut : CutDNAPort;
            perform action scanAndBind : ScanAndBind {
                in complex = rnpIn.rnp;
                in target = targetDNAIn.targetDNA;
                out boundComplex;
                out targetSite;
            }
            then action cleaveDNA : CleaveDNA {
                in boundComplex = scanAndBind.boundComplex;
                in target = scanAndBind.targetSite;
                out cutDNA = cutDNAOut.cutDNA;
            }
        }

        part repairUnit {
            port cutDNAIn : ~CutDNAPort;
            perform action repairDNA : RepairDNA {
                in cutDNA = cutDNAIn.cutDNA;
                in template = templateIn.template;
                out editedDNA = editedDNAOut.editedDNA;
            }
        }

        flow of RNPComplex from rnpAssemblyUnit.rnpOut.rnp to cuttingUnit.rnpIn.rnp;
        flow of TargetDNA from cuttingUnit.cutDNAOut.cutDNA to repairUnit.cutDNAIn.cutDNA;

        exhibit state crisprState : CRISPRStates;

        attribute editingEfficiency : Real = 0.85;
    }

    requirement def EditingEfficiencyRequirement {
        doc /* The CRISPR-Cas9 system shall achieve a minimum editing efficiency of 80 percent. */
        attribute minEfficiency : Real = 0.80;
        subject crisprSystem : CRISPRCas9System;
        constraint efficiencyConstraint {
            crisprSystem.editingEfficiency >= minEfficiency;
        }
    }

    requirement def TargetSpecificityRequirement {
        doc /* The Guide RNA shall bind only to the intended target sequence on the DNA strand. */
        subject crisprSystem : CRISPRCas9System;
    }

    requirement def RepairFidelityRequirement {
        doc /* The repair module shall incorporate the desired edit from the repair template at the cut site. */
        subject crisprSystem : CRISPRCas9System;
    }

    part geneEditingContext {
        part guideRNAModule : GuideRNAModule {
            item guideRNA : GuideRNA {
                attribute sequence = "GAGTCCGAGCAGAAGA";
            }
        }

        part cas9Module : Cas9Module {
            item cas9 : Cas9Protein {
                attribute activeConformation = true;
            }
        }

        part repairTemplateModule : RepairTemplateModule {
            item template : RepairTemplate {
                attribute desiredEdit = "GAGTCCGAGCAGAAGA";
                attribute homologyArmLeft = "ACTG";
                attribute homologyArmRight = "TGCA";
            }
        }

        part targetDNAModule : TargetDNAModule {
            item targetDNA : TargetDNA {
                attribute strand1 = "ATCGGAGTCCGAGCAGAAGAGGCATCG";
                attribute strand2 = "TAGCCTCAGGCTCGTCTTCTCCGTAGC";
                attribute targetLocus = "chr1:12345";
                attribute cutSite = 0;
            }
        }

        part crisprSystem : CRISPRCas9System;

        flow of GuideRNA from guideRNAModule.outPort.guideRNA to crisprSystem.guideRNAIn.guideRNA;
        flow of Cas9Protein from cas9Module.outPort.cas9 to crisprSystem.cas9In.cas9;
        flow of RepairTemplate from repairTemplateModule.outPort.template to crisprSystem.templateIn.template;
        flow of TargetDNA from targetDNAModule.outPort.targetDNA to crisprSystem.targetDNAIn.targetDNA;
        flow of EditedDNA from crisprSystem.editedDNAOut.editedDNA to targetDNAModule.targetDNA;
    }

    requirement editingEfficiencyReq : EditingEfficiencyRequirement {
        subject = geneEditingContext.crisprSystem;
    }

    requirement targetSpecificityReq : TargetSpecificityRequirement {
        subject = geneEditingContext.crisprSystem;
    }

    requirement repairFidelityReq : RepairFidelityRequirement {
        subject = geneEditingContext.crisprSystem;
    }
}
