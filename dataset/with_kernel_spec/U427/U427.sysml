package 'Automated Tube Stripping System' {
	private import ScalarValues::*;

	attribute def Length :> Real;
	attribute def Pressure :> Real;
	attribute def StripLength :> Length;
	attribute def ClampPressure :> Pressure;
	attribute def BladeDepth :> Length;

	item def InsulatedTube {
		attribute coreDiameter : Length;
		attribute insulationThickness : Length;
		attribute totalLength : Length;
	}

	item def StrippedTube :> InsulatedTube {
		attribute exposedCoreLength : Length;
		attribute coreCondition : String;
		attribute stripLengthAccurate : Boolean;
	}

	item def InsulationWaste {
		attribute pieceLength : Length;
	}

	attribute def StartCommand;
	attribute def StopCommand;
	attribute def EmergencyStopCommand;
	attribute def SetStripLengthCommand {
		attribute stripLength : StripLength;
	}
	attribute def ClampCommand {
		attribute pressure : ClampPressure;
	}
	attribute def ReleaseCommand;
	attribute def CutCommand {
		attribute depth : BladeDepth;
	}
	attribute def PullCommand;
	attribute def InspectCommand {
		attribute targetLength : StripLength;
	}
	attribute def ClampedSignal;
	attribute def ReleasedSignal;
	attribute def CutCompleteSignal;
	attribute def PullCompleteSignal;
	attribute def InspectionPassSignal;
	attribute def InspectionFailSignal;
	attribute def InspectionResult {
		attribute passed : Boolean;
		attribute measuredLength : Length;
		attribute coreCondition : String;
	}
	attribute def StatusUpdate {
		attribute currentState : String;
		attribute inspectionPassed : Boolean;
		attribute statusMessage : String;
	}

	part def ClampingAssembly {
		port powerIn { in voltage : Real; }
		port controlPort { in clampCmd : ClampCommand; in releaseCmd : ReleaseCommand; }
		port statusPort { out clamped : ClampedSignal; out released : ReleasedSignal; }
	}

	part def RotaryCuttingHead {
		port powerIn { in voltage : Real; }
		port controlPort { in cutCmd : CutCommand; }
		port statusPort { out cutComplete : CutCompleteSignal; }
	}

	part def PullingMechanism {
		port powerIn { in voltage : Real; }
		port controlPort { in pullCmd : PullCommand; }
		port statusPort { out pullComplete : PullCompleteSignal; }
		port wastePort { out waste : InsulationWaste; }
	}

	part def QualityInspectionUnit {
		port powerIn { in voltage : Real; }
		port controlPort { in inspectCmd : InspectCommand; }
		port statusPort { out pass : InspectionPassSignal; out fail : InspectionFailSignal; out result : InspectionResult; }
	}

	part def WasteCollectionBin {
		port wastePort { in waste : InsulationWaste; }
	}

	part def PowerSupply {
		port powerOut { out voltage : Real; }
	}

	part def Operator {
		port cmdPort {
			out startCmd : StartCommand;
			out stopCmd : StopCommand;
			out emergencyStopCmd : EmergencyStopCommand;
			out setStripLengthCmd : SetStripLengthCommand;
		}
		port statusPort { in status : StatusUpdate; }
	}

	part def ControllerUnit {
		port powerIn { in voltage : Real; }
		port operatorCmdPort {
			in startCmd : StartCommand;
			in stopCmd : StopCommand;
			in emergencyStopCmd : EmergencyStopCommand;
			in setStripLengthCmd : SetStripLengthCommand;
		}
		port operatorStatusPort { out status : StatusUpdate; }

		port clampControl { out clampCmd : ClampCommand; out releaseCmd : ReleaseCommand; }
		port clampStatus { in clamped : ClampedSignal; in released : ReleasedSignal; }

		port cutControl { out cutCmd : CutCommand; }
		port cutStatus { in cutComplete : CutCompleteSignal; }

		port pullControl { out pullCmd : PullCommand; }
		port pullStatus { in pullComplete : PullCompleteSignal; }

		port inspectControl { out inspectCmd : InspectCommand; }
		port inspectStatus { in pass : InspectionPassSignal; in fail : InspectionFailSignal; in result : InspectionResult; }

		attribute stripLength : StripLength;
		attribute insulationThickness : Length;

		state def ControllerStates;
		state controllerStates : ControllerStates {
			entry; then idle;
			state idle;
			accept StartCommand then clamping;
			accept StopCommand then idle;
			accept EmergencyStopCommand then emergency;
			state clamping;
			accept ClampedSignal then cutting;
			accept EmergencyStopCommand then emergency;
			state cutting;
			accept CutCompleteSignal then pulling;
			accept EmergencyStopCommand then emergency;
			state pulling;
			accept PullCompleteSignal then inspecting;
			accept EmergencyStopCommand then emergency;
			state inspecting;
			accept InspectionPassSignal then releasing;
			accept InspectionFailSignal then releasing;
			accept EmergencyStopCommand then emergency;
			state releasing;
			accept ReleasedSignal then idle;
			accept EmergencyStopCommand then emergency;
			state emergency;
			accept StopCommand then idle;
		}
	}

	part def TubeStrippingMachine {
		port operatorCmdPort {
			in startCmd : StartCommand;
			in stopCmd : StopCommand;
			in emergencyStopCmd : EmergencyStopCommand;
			in setStripLengthCmd : SetStripLengthCommand;
		}
		port operatorStatusPort { out status : StatusUpdate; }
		port tubeInPort { in tube : InsulatedTube; }
		port tubeOutPort { out tube : StrippedTube; }

		part controller : ControllerUnit;
		part powerSupply : PowerSupply;
		part clampingAssembly : ClampingAssembly;
		part rotaryCuttingHead : RotaryCuttingHead;
		part pullingMechanism : PullingMechanism;
		part qualityInspectionUnit : QualityInspectionUnit;
		part wasteCollectionBin : WasteCollectionBin;

		bind operatorCmdPort = controller.operatorCmdPort;
		bind operatorStatusPort = controller.operatorStatusPort;

		interface powerToController connect powerSupply.powerOut to controller.powerIn;
		interface powerToClamp connect powerSupply.powerOut to clampingAssembly.powerIn;
		interface powerToCutter connect powerSupply.powerOut to rotaryCuttingHead.powerIn;
		interface powerToPuller connect powerSupply.powerOut to pullingMechanism.powerIn;
		interface powerToInspector connect powerSupply.powerOut to qualityInspectionUnit.powerIn;

		interface clampCmdInterface connect controller.clampControl to clampingAssembly.controlPort;
		interface cutCmdInterface connect controller.cutControl to rotaryCuttingHead.controlPort;
		interface pullCmdInterface connect controller.pullControl to pullingMechanism.controlPort;
		interface inspectCmdInterface connect controller.inspectControl to qualityInspectionUnit.controlPort;

		interface clampStatusInterface connect clampingAssembly.statusPort to controller.clampStatus;
		interface cutStatusInterface connect rotaryCuttingHead.statusPort to controller.cutStatus;
		interface pullStatusInterface connect pullingMechanism.statusPort to controller.pullStatus;
		interface inspectStatusInterface connect qualityInspectionUnit.statusPort to controller.inspectStatus;

		flow wasteFlow of InsulationWaste
			from pullingMechanism.wastePort.waste to wasteCollectionBin.wastePort.waste;

		perform action stripTube {
			in item tube : InsulatedTube;
			out item strippedTube : StrippedTube;
			out item waste : InsulationWaste;

			action clampTube {
				in item tube;
				out item clampedTube : InsulatedTube = tube;
			}
			then action cutInsulation {
				in item clampedTube;
				out item cutTube : InsulatedTube = clampedTube;
			}
			then action pullInsulation {
				in item cutTube;
				out item strippedTube : StrippedTube = cutTube;
				out item waste : InsulationWaste;
			}
			then action inspectTube {
				in item strippedTube;
				out item inspectedTube : StrippedTube = strippedTube;
			}
			then action releaseTube {
				in item inspectedTube;
				out item finishedTube : StrippedTube = inspectedTube;
			}
		}
	}

	requirement def StrippingAccuracy {
		doc /* The system shall strip insulation to the specified strip length within +/- 0.5 mm tolerance. */
		subject machine : TubeStrippingMachine;
		attribute lengthTolerance : Length = 0.5;
	}

	requirement def NoCoreDamage {
		doc /* The stripping process shall not damage the tube core material. */
		subject machine : TubeStrippingMachine;
	}

	requirement def EmergencyStopCapability {
		doc /* The system shall immediately halt all operations upon receiving an emergency stop command. */
		subject machine : TubeStrippingMachine;
	}

	requirement def StatusReporting {
		doc /* The system shall provide real-time status updates and quality inspection results to the operator. */
		subject machine : TubeStrippingMachine;
	}

	requirement def OperatorControl {
		doc /* The system shall support start, stop, emergency stop, and strip length configuration commands. */
		subject machine : TubeStrippingMachine;
	}

	requirement def WasteManagement {
		doc /* The system shall collect removed insulation in a dedicated waste bin. */
		subject machine : TubeStrippingMachine;
	}

	part strippingMachine : TubeStrippingMachine {
		satisfy StrippingAccuracy by qualityInspectionUnit;
		satisfy NoCoreDamage by qualityInspectionUnit;
		satisfy EmergencyStopCapability by controller;
		satisfy StatusReporting by controller;
		satisfy OperatorControl by controller;
		satisfy WasteManagement by wasteCollectionBin;
	}

	part operator : Operator;

	interface operatorCmdInterface connect operator.cmdPort to strippingMachine.operatorCmdPort;
	interface operatorStatusInterface connect strippingMachine.operatorStatusPort to operator.statusPort;
}
