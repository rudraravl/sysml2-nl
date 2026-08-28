package AutomatedRivetingMachineSystem {
    public import Definitions::*;
    public import Usages::*;

    package Definitions {
        alias Force for ISQ::ForceValue;
        alias Pressure for ISQ::PressureValue;
        alias Time for ISQ::TimeValue;
        alias Volume for ISQ::VolumeValue;

        attribute def Count;
        attribute def AccuracyValue;
        attribute def Signal;
        attribute def StartCmd :> Signal;
        attribute def StopCmd :> Signal;
        attribute def EmergencyStopCmd :> Signal;
        attribute def CycleStatus;

        item def Workpiece;
        item def Rivet;
        item def FormedRivet :> Rivet;
        item def FinishedPart;

        port def HydraulicPressureOutPort {
            out pressure : Pressure;
        }
        port def HydraulicPressureInPort {
            in pressure : Pressure;
        }
        port def ControlSignalInPort {
            in signal : Signal;
        }
        port def ControlSignalOutPort {
            out signal : Signal;
        }
        port def RivetSupplyPort {
            out rivet : Rivet;
        }
        port def RivetReceivePort {
            in rivet : Rivet;
        }
        port def WorkpieceInPort {
            in workpiece : Workpiece;
        }
        port def WorkpieceOutPort {
            out workpiece : Workpiece;
        }
        port def FinishedPartOutPort {
            out finishedPart : FinishedPart;
        }
        port def CycleStatusOutPort {
            out cycleStatus : CycleStatus;
        }
        port def CycleStatusInPort {
            in cycleStatus : CycleStatus;
        }

        action def 'Load Workpiece' {
            in workpiece : Workpiece;
            out loadedWorkpiece : Workpiece;
        }
        action def 'Feed Rivet' {
            out rivet : Rivet;
        }
        action def 'Clamp Workpiece' {
            in workpiece : Workpiece;
            out clampedWorkpiece : Workpiece;
        }
        action def 'Form Rivet' {
            in workpiece : Workpiece;
            in rivet : Rivet;
            out formedAssembly : Workpiece;
        }
        action def 'Inspect Joint' {
            in workpiece : Workpiece;
            out inspectedAssembly : Workpiece;
        }
        action def 'Unload Finished Part' {
            in workpiece : Workpiece;
            out finishedPart : FinishedPart;
        }

        part def HydraulicPowerUnit {
            attribute maxPressure : Pressure = 30000000;
            attribute reservoirCapacity : Volume = 100;
            port pressureOut1 : HydraulicPressureOutPort;
            port pressureOut2 : HydraulicPressureOutPort;
            port controlIn : ControlSignalInPort;
        }

        part def ClampingAssembly {
            attribute clampForce : Force = 30000;
            port pressureIn : HydraulicPressureInPort;
            port controlIn : ControlSignalInPort;
            port workpieceIn : WorkpieceInPort;
            port workpieceOut : WorkpieceOutPort;
            port clampedSignalOut : ControlSignalOutPort;
        }

        part def RivetingHeadAssembly {
            attribute maxRivetingForce : Force = 50000;
            attribute appliedForce : Force;
            port pressureIn : HydraulicPressureInPort;
            port controlIn : ControlSignalInPort;
            port rivetIn : RivetReceivePort;
            port workpieceIn : WorkpieceInPort;
            port workpieceOut : WorkpieceOutPort;
            port formedSignalOut : ControlSignalOutPort;
        }

        part def RivetFeederUnit {
            attribute magazineCapacity : Count = 500;
            attribute rivetsRemaining : Count = 500;
            port controlIn : ControlSignalInPort;
            port rivetOut : RivetSupplyPort;
            port fedSignalOut : ControlSignalOutPort;
        }

        part def QualityInspectionUnit {
            attribute minAccuracyThreshold : AccuracyValue = 95;
            port controlIn : ControlSignalInPort;
            port workpieceIn : WorkpieceInPort;
            port finishedPartOut : FinishedPartOutPort;
            port inspectionResultOut : ControlSignalOutPort;
        }

        part def OperatorPanel {
            port startCmdOut : ControlSignalOutPort;
            port stopCmdOut : ControlSignalOutPort;
            port emergencyStopCmdOut : ControlSignalOutPort;
            port cycleStatusIn : CycleStatusInPort;
            port qualityReportIn : ControlSignalInPort;
        }

        part def SystemController {
            attribute maxCycleTime : Time = 12;
            port operatorCmdIn : ControlSignalInPort;
            port hydraulicControlOut : ControlSignalOutPort;
            port clampControlOut : ControlSignalOutPort;
            port rivetHeadControlOut : ControlSignalOutPort;
            port feederControlOut : ControlSignalOutPort;
            port inspectionControlOut : ControlSignalOutPort;
            port clampedSignalIn : ControlSignalInPort;
            port fedSignalIn : ControlSignalInPort;
            port formedSignalIn : ControlSignalInPort;
            port inspectionResultIn : ControlSignalInPort;
            port cycleStatusOut : CycleStatusOutPort;
        }

        part def AutomatedRivetingMachine {
            port workpieceIn : WorkpieceInPort;
            port finishedPartOut : FinishedPartOutPort;
            port cycleStatusOut : CycleStatusOutPort;
            part operatorPanel : OperatorPanel;
            part systemController : SystemController;
            part hydraulicPowerUnit : HydraulicPowerUnit;
            part clampingAssembly : ClampingAssembly;
            part rivetingHeadAssembly : RivetingHeadAssembly;
            part rivetFeederUnit : RivetFeederUnit;
            part qualityInspectionUnit : QualityInspectionUnit;
        }

        requirement def RivetingForceReq {
            doc /* The riveting head shall apply up to 50000 N of force during riveting. */
            require true;
        }
        requirement def CycleTimeReq {
            doc /* A full riveting cycle shall complete in 12 seconds or less. */
            require true;
        }
        requirement def QualityThresholdReq {
            doc /* Inspected joints shall meet at least 95 percent accuracy. */
            require true;
        }
        requirement def FeederCapacityReq {
            doc /* The rivet feeder magazine shall hold at least 500 rivets. */
            require true;
        }
        requirement def EmergencyShutdownReq {
            doc /* The system shall support emergency shutdown at any time during operation. */
            require true;
        }
    }

    package Usages {
        part rivetingMachine : AutomatedRivetingMachine {
            action 'perform riveting cycle' {
                action load: 'Load Workpiece' {
                    in workpiece: Workpiece;
                    out loadedWorkpiece: Workpiece;
                }
                flow load.loadedWorkpiece to clamp.workpiece;
                action feed: 'Feed Rivet' {
                    out rivet: Rivet;
                }
                flow feed.rivet to rivetAction.rivet;
                action clamp: 'Clamp Workpiece' {
                    in workpiece: Workpiece;
                    out clampedWorkpiece: Workpiece;
                }
                flow clamp.clampedWorkpiece to rivetAction.workpiece;
                action rivetAction: 'Form Rivet' {
                    in workpiece: Workpiece;
                    in rivet: Rivet;
                    out formedAssembly: Workpiece;
                }
                flow rivetAction.formedAssembly to inspect.workpiece;
                action inspect: 'Inspect Joint' {
                    in workpiece: Workpiece;
                    out inspectedAssembly: Workpiece;
                }
                flow inspect.inspectedAssembly to unload.workpiece;
                action unload: 'Unload Finished Part' {
                    in workpiece: Workpiece;
                    out finishedPart: FinishedPart;
                }
            }

            connect hydraulicPowerUnit.pressureOut1 to clampingAssembly.pressureIn;
            connect hydraulicPowerUnit.pressureOut2 to rivetingHeadAssembly.pressureIn;
            connect systemController.hydraulicControlOut to hydraulicPowerUnit.controlIn;
            connect systemController.clampControlOut to clampingAssembly.controlIn;
            connect systemController.rivetHeadControlOut to rivetingHeadAssembly.controlIn;
            connect systemController.feederControlOut to rivetFeederUnit.controlIn;
            connect systemController.inspectionControlOut to qualityInspectionUnit.controlIn;
            connect clampingAssembly.clampedSignalOut to systemController.clampedSignalIn;
            connect rivetFeederUnit.fedSignalOut to systemController.fedSignalIn;
            connect rivetingHeadAssembly.formedSignalOut to systemController.formedSignalIn;
            connect qualityInspectionUnit.inspectionResultOut to systemController.inspectionResultIn;
            connect rivetFeederUnit.rivetOut to rivetingHeadAssembly.rivetIn;
            connect workpieceIn to clampingAssembly.workpieceIn;
            connect clampingAssembly.workpieceOut to rivetingHeadAssembly.workpieceIn;
            connect rivetingHeadAssembly.workpieceOut to qualityInspectionUnit.workpieceIn;
            connect qualityInspectionUnit.finishedPartOut to finishedPartOut;
            connect operatorPanel.startCmdOut to systemController.operatorCmdIn;
            connect operatorPanel.stopCmdOut to systemController.operatorCmdIn;
            connect operatorPanel.emergencyStopCmdOut to systemController.operatorCmdIn;
            connect systemController.cycleStatusOut to operatorPanel.cycleStatusIn;
            connect qualityInspectionUnit.inspectionResultOut to operatorPanel.qualityReportIn;
            connect systemController.cycleStatusOut to cycleStatusOut;

            satisfy rivetingForceReq : RivetingForceReq by rivetingHeadAssembly;
            satisfy cycleTimeReq : CycleTimeReq by systemController;
            satisfy qualityThresholdReq : QualityThresholdReq by qualityInspectionUnit;
            satisfy feederCapacityReq : FeederCapacityReq by rivetFeederUnit;
            satisfy emergencyShutdownReq : EmergencyShutdownReq by systemController;
        }
    }
}
