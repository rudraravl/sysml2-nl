package ManumationCellSystem {
	private import ScalarValues::*;
	private import SI::*;
	private import ISQ::*;

	enum def WorkpieceStatus {
		raw;
		machined;
		assembled;
		finished;
		defective;
	}

	item def Workpiece {
		attribute id : String;
		attribute mass : ISQ::Mass;
		attribute status : WorkpieceStatus;
	}

	attribute def StartSignal;
	attribute def PauseSignal;
	attribute def ResumeSignal;
	attribute def EmergencyStopSignal;
	attribute def ResetSignal;
	attribute def OperationCompleteSignal;
	attribute def DefectDetectedSignal;
	attribute def SelfTestPassedSignal;
	attribute def WorkpieceArrivedSignal;
	attribute def CycleCompleteSignal;

	port def ControlPort {
		in start : StartSignal;
		in pause : PauseSignal;
		in resume : ResumeSignal;
		in estop : EmergencyStopSignal;
		in reset : ResetSignal;
		out opComplete : OperationCompleteSignal;
		out defect : DefectDetectedSignal;
		out selfTest : SelfTestPassedSignal;
		out arrived : WorkpieceArrivedSignal;
		out cycleComplete : CycleCompleteSignal;
	}

	port def MaterialPort {
		inout workpiece : Workpiece;
	}

	action def InspectWorkpiece {
		in workpiece : Workpiece;
		out isDefective : Boolean;
	}

	action def ProcessWorkpiece {
		in workpiece : Workpiece;
	}

	action def PickAndPlace {
		in workpiece : Workpiece;
		in target : String;
	}

	action def SelfTest;
	action def HaltMotion;
	action def SafeShutdown;

	part def Gripper {
		attribute maxPayload : ISQ::Mass = 30[SI::kg];
	}

	part def SixAxisRobot {
		part gripper : Gripper;
		port controlPort : ControlPort;
		port materialPort : MaterialPort;
	}

	part def Workstation {
		port materialPort : MaterialPort;
		port controlPort : ControlPort;
	}

	part def MachiningStation :> Workstation;
	part def AssemblyStation :> Workstation;
	part def FinishingStation :> Workstation;

	part def ConveyorBelt {
		port inPort : MaterialPort;
		port outPort : MaterialPort;
		port controlPort : ControlPort;
	}

	part def VisionSystem {
		attribute resolution : String = "4K";
		port materialPort : MaterialPort;
		port controlPort : ControlPort;
	}

	state def CellControllerStates;

	state cellControllerStates : CellControllerStates {
		in controller : CentralController;
		entry; then Initializing;

		state Initializing {
			do action selfTest : SelfTest;
		}
		accept SelfTestPassedSignal then Ready;

		state Ready;
		accept StartSignal then Active;

		state Active {
			entry; then WaitForWorkpiece;
			state WaitForWorkpiece;
			accept WorkpieceArrivedSignal then InspectInitial;
			state InspectInitial;
			accept OperationCompleteSignal then PickAndMachine;
			state PickAndMachine;
			accept OperationCompleteSignal then Assemble;
			state Assemble;
			accept OperationCompleteSignal then Finish;
			state Finish;
			accept OperationCompleteSignal then InspectFinal;
			state InspectFinal;
			accept OperationCompleteSignal then WaitForWorkpiece;
		}
		accept CycleCompleteSignal then Ready;
		accept PauseSignal then Paused;

		transition emergencyFromActive
			first Active
			accept EmergencyStopSignal
			then EmergencyStopped;

		state Paused {
			do action haltMotion : HaltMotion;
		}
		accept ResumeSignal then Active;
		accept EmergencyStopSignal then EmergencyStopped;

		state EmergencyStopped {
			do action safeShutdown : SafeShutdown;
		}
		accept ResetSignal then Initializing;
	}

	part def CentralController {
		port controlPort : ~ControlPort;
		exhibit cellControllerStates {
			in controller = this;
		}
	}

	part def ManumationCell {
		part robot1 : SixAxisRobot;
		part robot2 : SixAxisRobot;
		part machiningStation : MachiningStation;
		part assemblyStation : AssemblyStation;
		part finishingStation : FinishingStation;
		part inputConveyor : ConveyorBelt;
		part transportConveyor : ConveyorBelt;
		part outputConveyor : ConveyorBelt;
		part visionSystem : VisionSystem;
		part controller : CentralController;

		connect controller.controlPort to robot1.controlPort;
		connect controller.controlPort to robot2.controlPort;
		connect controller.controlPort to machiningStation.controlPort;
		connect controller.controlPort to assemblyStation.controlPort;
		connect controller.controlPort to finishingStation.controlPort;
		connect controller.controlPort to inputConveyor.controlPort;
		connect controller.controlPort to transportConveyor.controlPort;
		connect controller.controlPort to outputConveyor.controlPort;
		connect controller.controlPort to visionSystem.controlPort;

		connect inputConveyor.outPort to visionSystem.materialPort;
		connect visionSystem.materialPort to robot1.materialPort;
		connect robot1.materialPort to machiningStation.materialPort;
		connect machiningStation.materialPort to transportConveyor.inPort;
		connect transportConveyor.outPort to assemblyStation.materialPort;
		connect assemblyStation.materialPort to transportConveyor.inPort;
		connect transportConveyor.outPort to finishingStation.materialPort;
		connect finishingStation.materialPort to robot2.materialPort;
		connect robot2.materialPort to visionSystem.materialPort;
		connect visionSystem.materialPort to outputConveyor.inPort;

		action productionCycle {
			in workpiece : Workpiece;
			action inspect1 : InspectWorkpiece {
				in workpiece = workpiece;
			}
			then action pick1 : PickAndPlace {
				in workpiece = workpiece;
			}
			then action machine1 : ProcessWorkpiece {
				in workpiece = workpiece;
			}
			then action assemble1 : ProcessWorkpiece {
				in workpiece = workpiece;
			}
			then action finish1 : ProcessWorkpiece {
				in workpiece = workpiece;
			}
			then action inspect2 : InspectWorkpiece {
				in workpiece = workpiece;
			}
			then action output1 : PickAndPlace {
				in workpiece = workpiece;
			}
		}
	}

	part testWorkpiece : Workpiece {
		:>> mass = 5[SI::kg];
		:>> status = WorkpieceStatus::raw;
	}

	part manumationCell : ManumationCell;

	requirement def PayloadRequirement {
		doc /* The robotic grippers must be able to handle workpieces up to 30 kg. */
		subject gripper : Gripper;
		constraint { gripper.maxPayload >= 30[SI::kg] }
	}

	requirement def SafetyShutdownRequirement {
		doc /* The system must halt all operations and guide a safe shutdown upon emergency stop. */
		subject controller : CentralController;
	}

	requirement def VisionRequirement {
		doc /* The vision system must operate at 4K resolution for accurate workpiece identification and defect detection. */
		subject vision : VisionSystem;
		constraint { vision.resolution == "4K" }
	}

	requirement def ProcessSequenceRequirement {
		doc /* Workpieces must follow the sequence: Input -> Inspection -> Machining -> Assembly -> Finishing -> Final Inspection -> Output. */
		subject cell : ManumationCell;
	}

	requirement payloadReq : PayloadRequirement {
		subject gripper = manumationCell.robot1.gripper;
	}

	requirement safetyReq : SafetyShutdownRequirement {
		subject controller = manumationCell.controller;
	}

	requirement visionReq : VisionRequirement {
		subject vision = manumationCell.visionSystem;
	}

	requirement processSeqReq : ProcessSequenceRequirement {
		subject cell = manumationCell;
	}
}
