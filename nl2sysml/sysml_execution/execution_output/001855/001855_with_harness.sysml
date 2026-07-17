package 'CRISPR Gene Editing System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	attribute def SequenceLength :> Real;
	attribute def BindingAffinity :> Real;
	attribute def EditingEfficiency :> Real;
	attribute def ConcentrationValue :> Real;

	item def DNAStrand {
		attribute sequence : String;
		attribute length : SequenceLength;
		attribute targetSite : String;
	}

	item def GuideRNA {
		attribute sequence : String;
		attribute length : SequenceLength;
		attribute complementaryRegion : String;
	}

	item def Cas9Protein {
		attribute isActive : Boolean;
		attribute nucleaseActivity : Real;
	}

	item def EditedDNA {
		attribute sequence : String;
		attribute editLocation : SequenceLength;
		attribute modificationType : String;
	}

	item def RibonucleoproteinComplex {
		attribute isAssembled : Boolean;
		attribute bindingStrength : BindingAffinity;
	}

	port def DNAInputPort {
		in item targetDNA : DNAStrand;
		in attribute dnaConcentration : ConcentrationValue;
	}

	port def GuideRNAPort {
		in item guideRNA : GuideRNA;
		in attribute rnaConcentration : ConcentrationValue;
	}

	port def Cas9Port {
		in item cas9 : Cas9Protein;
		in attribute proteinConcentration : ConcentrationValue;
	}

	port def EditedDNAPort {
		out item editedDNA : EditedDNA;
		out attribute editingEfficiency : EditingEfficiency;
	}

	action def AssembleRibonucleoprotein {
		in guideRNA : GuideRNA;
		in cas9Protein : Cas9Protein;
		out rnpComplex : RibonucleoproteinComplex;
	}

	action def ScanTargetSequence {
		in targetDNA : DNAStrand;
		in rnpComplex : RibonucleoproteinComplex;
		out targetFound : Boolean;
		out bindingPosition : SequenceLength;
	}

	action def CleaveDNA {
		in bindingSite : SequenceLength;
		in rnpComplex : RibonucleoproteinComplex;
		out cleavedDNA : DNAStrand;
		out cleavageSuccess : Boolean;
	}

	action def RepairAndEdit {
		in cleavedDNA : DNAStrand;
		in repairTemplate : DNAStrand;
		out editedDNA : EditedDNA;
		out editingSuccess : Boolean;
	}

	part def RNPAssemblyComplex {
		port guideRNAIn : GuideRNAPort;
		port cas9In : Cas9Port;
		port rnpOut {
			out item rnpComplex : RibonucleoproteinComplex;
		}

		perform action assembleRNP : AssembleRibonucleoprotein;
	}

	part def TargetRecognitionModule {
		port dnaIn : DNAInputPort;
		port rnpIn {
			in item rnpComplex : RibonucleoproteinComplex;
		}
		port recognitionOut {
			out attribute isTargetFound : Boolean;
			out attribute bindingSite : SequenceLength;
		}

		perform action scanAndBind : ScanTargetSequence;
	}

	part def CleavageModule {
		port targetSiteIn {
			in attribute bindingSite : SequenceLength;
		}
		port rnpIn {
			in item rnpComplex : RibonucleoproteinComplex;
		}
		port cleavageOut {
			out item cleavedDNA : DNAStrand;
			out attribute cleavageComplete : Boolean;
		}

		perform action performCleavage : CleaveDNA;
	}

	part def RepairModule {
		port cleavedDNAIn {
			in item cleavedDNA : DNAStrand;
		}
		port templateIn {
			in item repairTemplate : DNAStrand;
		}
		port repairedDNAOut : EditedDNAPort;

		perform action repairDNA : RepairAndEdit;
	}

	part def CRISPREditingSystem {
		doc /* A gene editing system that uses CRISPR-Cas9 technology to precisely modify DNA sequences. */

		port dnaInput : DNAInputPort;
		port guideRNAInput : GuideRNAPort;
		port cas9Input : Cas9Port;
		port editedOutput : EditedDNAPort;

		part rnpAssembly : RNPAssemblyComplex {
			perform action assembly[*] references assembleRNP;
		}

		part targetRecognition : TargetRecognitionModule {
			perform action recognition[*] references scanAndBind;
		}

		part cleavage : CleavageModule {
			perform action cutting[*] references performCleavage;
		}

		part repair : RepairModule {
			perform action editing[*] references repairDNA;
		}

		connection guideRNAFlow connect guideRNAInput to rnpAssembly.guideRNAIn;
		connection cas9Flow connect cas9Input to rnpAssembly.cas9In;
		connection rnpToRecognition connect rnpAssembly.rnpOut to targetRecognition.rnpIn;
		connection dnaToRecognition connect dnaInput to targetRecognition.dnaIn;
		connection recognitionToCleavage connect targetRecognition.recognitionOut to cleavage.targetSiteIn;
		connection rnpToCleavage connect rnpAssembly.rnpOut to cleavage.rnpIn;
		connection cleavageToRepair connect cleavage.cleavageOut to repair.cleavedDNAIn;
		connection repairToOutput connect repair.repairedDNAOut to editedOutput;

		perform action editingCycle : GeneEditingProcess;
	}

	action def GeneEditingProcess {
		first start;

		then action assembleComplex : AssembleRibonucleoprotein {
			in guideRNA;
			in cas9Protein;
			out rnpComplex;
		}

		then action findTarget : ScanTargetSequence {
			in targetDNA;
			in rnpComplex = assembleComplex.rnpComplex;
			out targetFound;
			out bindingPosition;
		}

		then decide;
			if findTarget.targetFound then proceedToCleavage;
			if not findTarget.targetFound then retryScanning;

		action retryScanning;
		then findTarget;

		action proceedToCleavage;
		then action cutDNA : CleaveDNA {
			in bindingSite = findTarget.bindingPosition;
			in rnpComplex = assembleComplex.rnpComplex;
			out cleavedDNA;
			out cleavageSuccess;
		}

		then decide;
			if cutDNA.cleavageSuccess then proceedToRepair;
			if not cutDNA.cleavageSuccess then retryCleavage;

		action retryCleavage;
		then cutDNA;

		action proceedToRepair;
		then action performRepair : RepairAndEdit {
			in cleavedDNA = cutDNA.cleavedDNA;
			in repairTemplate;
			out editedDNA;
			out editingSuccess;
		}

		then decide;
			if performRepair.editingSuccess then complete;
			if not performRepair.editingSuccess then retryRepair;

		action retryRepair;
		then performRepair;

		action complete;

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import 'CRISPR Gene Editing System'::*;

    action orchestrator {
        item testGuideRNA : GuideRNA {
            attribute sequence = "";
            attribute length : SequenceLength = 0.0;
            attribute complementaryRegion = "";
        }
        item testCas9Protein : Cas9Protein {
            attribute isActive = false;
            attribute nucleaseActivity = 0.0;
        }
        action actionProbe : AssembleRibonucleoprotein {
            in guideRNA = testGuideRNA;
            in cas9Protein = testCas9Protein;
        }
        first actionProbe;
    }
}
