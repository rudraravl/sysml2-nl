package CausticPencilModel {
	private import SI::*;
	private import ScalarValues::*;

	attribute def Force :> Real;
	attribute def Duration :> Real;
	attribute def Depth :> Real;
	attribute def Concentration :> Real;

	item def SilverNitrate;
	part def Tissue;
	part def TargetTissue :> Tissue;
	part def CoagulatedTissue :> Tissue;

	port def GripPort;
	port def TipContactPort {
		out item chemicalAgent : SilverNitrate;
	}
	port def TissueContactPort {
		in item receivedAgent : SilverNitrate;
		out item cauterizedTissue : CoagulatedTissue;
	}

	attribute def UnpackageSignal;
	attribute def ApplySignal;
	attribute def ReleaseSignal;
	attribute def DisposeSignal;

	state def CausticPencilOperationalStates {
		entry; then stored;
		state stored;
		transition stored_to_idle
			first stored
			accept UnpackageSignal
			then idle;
		state idle;
		transition idle_to_active
			first idle
			accept ApplySignal
			then active;
		state active;
		transition active_to_idle
			first active
			accept ReleaseSignal
			then idle;
		transition idle_to_disposed
			first idle
			accept DisposeSignal
			then disposed;
		state disposed;
	}

	part def Clinician {
		port hand : GripPort;
	}

	part def PlasticHolder {
		attribute material : String = "MedicalGradePlastic";
		port grip : GripPort;
	}

	part def SilverNitrateTip {
		attribute silverNitrateConcentration : Concentration = 0.95;
		item activeAgent : SilverNitrate;
		port contactPort : TipContactPort;
	}

	part def CausticPencilDevice {
		part holder : PlasticHolder;
		part tip : SilverNitrateTip;
		port applicationPort : TipContactPort;
		port gripPort : GripPort;
		state operationalStates : CausticPencilOperationalStates;
	}

	part def Patient {
		part targetTissueArea : TargetTissue {
			port tissuePort : TissueContactPort;
		}
	}

	action def PrepareProcedure {
		in part targetTissue : TargetTissue;
	}

	action def ApplyTip {
		in part targetTissue : TargetTissue;
		in attribute appliedForce : Force;
		in attribute applicationDuration : Duration;
		out item transferredAgent : SilverNitrate;
	}

	action def Cauterize {
		in item agent : SilverNitrate;
		in part targetTissue : TargetTissue;
		out part coagulatedTissue : CoagulatedTissue;
		out attribute cauteryDepth : Depth;
	}

	action def MonitorEffect {
		in part cauterizedArea : CoagulatedTissue;
		out attribute effectAchieved : Boolean;
	}

	action def DisposePencil;

	action def PerformCauterizationProcedure {
		in part clinician : Clinician;
		in part pencil : CausticPencilDevice;
		in part targetTissue : TargetTissue;

		action prepare : PrepareProcedure {
			in part :>> targetTissue;
		}
		then action apply : ApplyTip {
			in part :>> targetTissue;
			in attribute :>> appliedForce = 0.5;
			in attribute :>> applicationDuration = 5;
			out item :>> transferredAgent;
		}
		then action cauterize : Cauterize {
			in item :>> agent = apply.transferredAgent;
			in part :>> targetTissue;
			out part :>> coagulatedTissue;
			out attribute :>> cauteryDepth;
		}
		then action monitor : MonitorEffect {
			in part :>> cauterizedArea = cauterize.coagulatedTissue;
			out attribute :>> effectAchieved;
		}
		then action dispose : DisposePencil;
	}

	part clinician : Clinician;
	part causticPencil : CausticPencilDevice;
	part patient : Patient;

	connection gripConnection {
		end clinicianHand :> clinician.hand;
		end pencilHandle :> causticPencil.gripPort;
	}

	connection chemicalApplication {
		end pencilTip :> causticPencil.tip.contactPort;
		end tissueSurface :> patient.targetTissueArea.tissuePort;
	}

	requirement def StopMinorBleeding {
		doc "The caustic pencil shall stop minor bleeding through chemical cauterization by coagulating proteins in the target tissue.";
	}

	requirement def RemoveUnwantedTissue {
		doc "The caustic pencil shall remove small amounts of unwanted tissue such as warts or granulation tissue by chemically burning it in a controlled manner.";
	}

	requirement def ControlledCauteryDepth {
		doc "The caustic pencil shall achieve cautery to a shallow depth not exceeding 2 mm and not less than 0.1 mm to avoid excessive tissue damage.";
		attribute maxDepth : Depth = 2;
		attribute minDepth : Depth = 0.1;
	}

	requirement def SingleUseDevice {
		doc "The caustic pencil shall be a single-use medical device that is disposed of after one procedure.";
	}

	requirement def SilverNitrateComposition {
		doc "The active tip shall be composed of 95 percent silver nitrate as the chemical agent responsible for cauterization.";
		attribute concentration : Concentration = 0.95;
	}

	requirement def ControlledApplication {
		doc "The clinician shall apply the silver nitrate tip directly to the tissue with a gentle force not exceeding 0.5 N for a duration not exceeding 5 s.";
		attribute maxForce : Force = 0.5;
		attribute maxDuration : Duration = 5;
	}

	requirement def ReapplicationCapability {
		doc "The clinician shall be able to re-apply the pencil in stages to achieve the desired treatment outcome without causing excessive damage.";
	}

	requirement def OperationalStateModel {
		doc "The caustic pencil shall exist in the following states: stored, idle, active, and disposed, transitioning between them as appropriate for the procedure lifecycle.";
	}

	satisfy StopMinorBleeding by causticPencil;
	satisfy RemoveUnwantedTissue by causticPencil;
	satisfy ControlledCauteryDepth by causticPencil;
	satisfy SingleUseDevice by causticPencil;
	satisfy SilverNitrateComposition by causticPencil.tip;
	satisfy ControlledApplication by clinician;
	satisfy ReapplicationCapability by clinician;
	satisfy OperationalStateModel by causticPencil;

	verification def VerifyCauteryDepth {
		subject testPencil :> causticPencil;
	}

	verification def VerifySilverNitrate {
		subject testPencil :> causticPencil;
	}

	verification def VerifyApplicationControl {
		subject testPencil :> causticPencil;
	}
}
