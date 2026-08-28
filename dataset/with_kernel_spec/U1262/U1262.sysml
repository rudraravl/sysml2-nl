package 'Wolf Robotics Automated Welding Cell' {
	private import ScalarValues::*;
	private import ISQ::*;

	package Definitions {
		private import ScalarValues::*;
		private import ISQ::*;

		attribute def CurrentValue :> Real;
		attribute def VoltageValue :> Real;
		attribute def TravelSpeedValue :> Real;
		attribute def WireFeedRateValue :> Real;
		attribute def GasFlowRateValue :> Real;
		attribute def LengthValue :> Real;
		attribute def PositionValue :> Real;

		item def WeldingWire;
		item def ShieldingGas;

		item def SeamData {
			attribute seamWidth : LengthValue;
			attribute seamDepth : LengthValue;
			attribute seamLength : LengthValue;
		}

		item def PathData {
			attribute waypoints : LengthValue[*];
		}

		item def WeldParameters {
			attribute current : CurrentValue;
			attribute voltage : VoltageValue;
			attribute travelSpeed : TravelSpeedValue;
			attribute wireFeedRate : WireFeedRateValue;
			attribute gasFlowRate : GasFlowRateValue;
		}

		item def QualityFeedback {
			attribute defectDetected : Boolean;
			attribute defectType : String;
			attribute beadWidth : LengthValue;
			attribute penetration : LengthValue;
		}

		attribute def StartCommand;
		attribute def ScanCommand;
		attribute def QualityCheckCommand;
		attribute def ScanComplete;
		attribute def PathPlanned;
		attribute def WeldComplete;
		attribute def QualityApproved;
		attribute def DefectDetected;
		attribute def ArcStrikeCommand;
		attribute def ArcExtinguishCommand;

		action def ScanWorkpiece { out seam : SeamData; }
		action def PlanPath { in seam : SeamData; out path : PathData; }
		action def ComputeWeldParameters { in seam : SeamData; out params : WeldParameters; }
		action def ExecuteWeld;
		action def MonitorQuality { out feedback : QualityFeedback; }
		action def AdjustParameters { in feedback : QualityFeedback; out newParams : WeldParameters; }

		part def PowerSupply {
			port controlPort {
				in currentSetpoint : CurrentValue;
				in voltageSetpoint : VoltageValue;
			}
			port outputPort {
				out weldingCurrent : CurrentValue;
				out weldingVoltage : VoltageValue;
			}
		}

		part def WireFeedUnit {
			port controlPort { in feedRateSetpoint : WireFeedRateValue; }
			port outputPort { out weldingWire : WireFeedRateValue; }
		}

		part def ShieldingGasSupply {
			port controlPort { in flowRateSetpoint : GasFlowRateValue; }
			port outputPort { out shieldingGas : GasFlowRateValue; }
		}

		part def WeldingTorch {
			port inputPort {
				in weldingCurrent : CurrentValue;
				in weldingVoltage : VoltageValue;
				in weldingWire : WireFeedRateValue;
				in shieldingGas : GasFlowRateValue;
			}
			port arcPort {
				in arcStrikeCmd : ArcStrikeCommand;
				in arcExtinguishCmd : ArcExtinguishCommand;
				out arcStatus : Boolean;
			}
			port mountPort;
		}

		part def RobotArm {
			port controlPort {
				in pathCmd : PathData;
				out positionFeedback : PositionValue;
			}
			port torchMountPort;
		}

		part def VisionSystem {
			port controllerPort {
				in scanCmd : ScanCommand;
				in qualityCheckCmd : QualityCheckCommand;
				out seamData : SeamData;
				out qualityFeedback : QualityFeedback;
			}
		}

		part def SystemController {
			port visionPort {
				in seamData : SeamData;
				in qualityFeedback : QualityFeedback;
				out scanCmd : ScanCommand;
				out qualityCheckCmd : QualityCheckCommand;
			}
			port robotPort {
				out pathCmd : PathData;
				in positionFeedback : PositionValue;
			}
			port powerPort {
				out currentSet : CurrentValue;
				out voltageSet : VoltageValue;
			}
			port wireControlPort { out feedRateSet : WireFeedRateValue; }
			port gasControlPort { out flowRateSet : GasFlowRateValue; }
			port torchPort {
				out arcStrike : ArcStrikeCommand;
				out arcExtinguish : ArcExtinguishCommand;
			}
		}

		part def WeldingCell {
			part robotArm : RobotArm;
			part weldingTorch : WeldingTorch;
			part powerSupply : PowerSupply;
			part wireFeedUnit : WireFeedUnit;
			part shieldingGasSupply : ShieldingGasSupply;
			part visionSystem : VisionSystem;
			part systemController : SystemController;
		}

		state def CellStates;

		requirement def HighQualityWelds {
			doc /* The system shall produce welds with consistent bead width and penetration within specified tolerances. */
		}

		requirement def MinimalHumanOversight {
			doc /* The system shall operate autonomously after initial setup, requiring no manual intervention during normal operation. */
		}

		requirement def AdaptiveControl {
			doc /* The system shall adjust welding parameters in real-time based on quality feedback to compensate for part variations. */
		}

		requirement def SafeWorkflow {
			doc /* The system shall follow a safe sequence of states, ensuring the robot is stationary during scanning and quality checking. */
		}
	}

	package Usages {
		private import Definitions::*;

		part weldingCell : WeldingCell {
			bind weldingTorch.mountPort = robotArm.torchMountPort;

			flow currentFlow of CurrentValue
				from powerSupply.outputPort.weldingCurrent
				to weldingTorch.inputPort.weldingCurrent;
			flow voltageFlow of VoltageValue
				from powerSupply.outputPort.weldingVoltage
				to weldingTorch.inputPort.weldingVoltage;
			flow wireFlow of WireFeedRateValue
				from wireFeedUnit.outputPort.weldingWire
				to weldingTorch.inputPort.weldingWire;
			flow gasFlow of GasFlowRateValue
				from shieldingGasSupply.outputPort.shieldingGas
				to weldingTorch.inputPort.shieldingGas;

			flow scanCmdFlow of ScanCommand
				from systemController.visionPort.scanCmd
				to visionSystem.controllerPort.scanCmd;
			flow qualityCheckCmdFlow of QualityCheckCommand
				from systemController.visionPort.qualityCheckCmd
				to visionSystem.controllerPort.qualityCheckCmd;
			flow seamDataFlow of SeamData
				from visionSystem.controllerPort.seamData
				to systemController.visionPort.seamData;
			flow qualityFeedbackFlow of QualityFeedback
				from visionSystem.controllerPort.qualityFeedback
				to systemController.visionPort.qualityFeedback;

			flow pathCmdFlow of PathData
				from systemController.robotPort.pathCmd
				to robotArm.controlPort.pathCmd;
			flow positionFeedbackFlow of PositionValue
				from robotArm.controlPort.positionFeedback
				to systemController.robotPort.positionFeedback;

			flow currentSetFlow of CurrentValue
				from systemController.powerPort.currentSet
				to powerSupply.controlPort.currentSetpoint;
			flow voltageSetFlow of VoltageValue
				from systemController.powerPort.voltageSet
				to powerSupply.controlPort.voltageSetpoint;
			flow feedRateSetFlow of WireFeedRateValue
				from systemController.wireControlPort.feedRateSet
				to wireFeedUnit.controlPort.feedRateSetpoint;
			flow flowRateSetFlow of GasFlowRateValue
				from systemController.gasControlPort.flowRateSet
				to shieldingGasSupply.controlPort.flowRateSetpoint;

			flow arcStrikeFlow of ArcStrikeCommand
				from systemController.torchPort.arcStrike
				to weldingTorch.arcPort.arcStrikeCmd;
			flow arcExtinguishFlow of ArcExtinguishCommand
				from systemController.torchPort.arcExtinguish
				to weldingTorch.arcPort.arcExtinguishCmd;

			state cellStates : CellStates {
				entry; then idle;

				state idle;
				transition 'idle-to-scanning'
					first idle
					accept StartCommand
					do send new ScanCommand() to visionSystem
					then scanning;

				state scanning {
					do action scanWorkpiece : ScanWorkpiece;
				}
				transition 'scanning-to-pathPlanning'
					first scanning
					accept ScanComplete
					then pathPlanning;

				state pathPlanning {
					do action planPath : PlanPath;
					do action computeWeldParameters : ComputeWeldParameters;
				}
				transition 'pathPlanning-to-welding'
					first pathPlanning
					accept PathPlanned
					then welding;

				state welding {
					entry action strikeArc { send new ArcStrikeCommand() to weldingTorch; }
					do action executeWeld : ExecuteWeld;
					exit action extinguishArc { send new ArcExtinguishCommand() to weldingTorch; }
				}
				transition 'welding-to-qualityChecking'
					first welding
					accept WeldComplete
					do send new QualityCheckCommand() to visionSystem
					then qualityChecking;

				state qualityChecking {
					do action monitorQuality : MonitorQuality;
				}
				transition 'qualityChecking-to-idle'
					first qualityChecking
					accept QualityApproved
					then idle;
				transition 'qualityChecking-to-welding'
					first qualityChecking
					accept DefectDetected
					do action adjustParameters : AdjustParameters
					then welding;
			}
		}

		requirement highQualityReq : HighQualityWelds;
		requirement minimalOversightReq : MinimalHumanOversight;
		requirement adaptiveControlReq : AdaptiveControl;
		requirement safeWorkflowReq : SafeWorkflow;

		satisfy highQualityReq by weldingCell;
		satisfy minimalOversightReq by weldingCell;
		satisfy adaptiveControlReq by weldingCell;
		satisfy safeWorkflowReq by weldingCell;
	}
}
