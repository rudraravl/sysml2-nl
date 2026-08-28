package SelfMakingBedSystem {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def ActivateSignal;
    attribute def TensionCompleteSignal;
    attribute def FoldCompleteSignal;
    attribute def AlignmentCompleteSignal;

    item def Sheet;
    item def Blanket;
    item def Pillow;

    part def BedFrame;
    part def Mattress;

    part def OccupancySensor {
        out port occupancy : Boolean;
        out port vacantTime : Time;

        action monitorOccupancy {
            out isOccupied : Boolean;
            out duration : Time;
        }
    }

    part def SheetTensioningActuator {
        in port activate : ActivateSignal;
        out port status : TensionCompleteSignal;
        attribute targetTension : Force = 50 [N];

        action tensionSheets {
            in signal : ActivateSignal;
            out completion : TensionCompleteSignal;
        }
    }

    part def BlanketFoldingActuator {
        in port activate : ActivateSignal;
        out port status : FoldCompleteSignal;

        action foldBlanket {
            in signal : ActivateSignal;
            out completion : FoldCompleteSignal;
        }
    }

    part def PillowArrangementActuator {
        in port activate : ActivateSignal;
        out port status : AlignmentCompleteSignal;

        action arrangePillows {
            in signal : ActivateSignal;
            out completion : AlignmentCompleteSignal;
        }
    }

    part def CentralController {
        in port occupancy : Boolean;
        in port vacantTime : Time;

        out port tensionActivate : ActivateSignal;
        in port tensionStatus : TensionCompleteSignal;

        out port foldActivate : ActivateSignal;
        in port foldStatus : FoldCompleteSignal;

        out port pillowActivate : ActivateSignal;
        in port alignmentStatus : AlignmentCompleteSignal;

        attribute vacantThreshold : Time = 60 [s];
        attribute cycleLimit : Time = 120 [s];

        state def ControllerStates {
            in controller : CentralController;
            entry; then idle;
            state idle;
            when controller.occupancy == false and controller.vacantTime >= controller.vacantThreshold
                then makingSheets;
            state makingSheets {
                entry do send new ActivateSignal() to controller.tensionActivate;
                accept TensionCompleteSignal
                    then foldingBlanket;
            }
            state foldingBlanket {
                entry do send new ActivateSignal() to controller.foldActivate;
                accept FoldCompleteSignal
                    then arrangingPillows;
            }
            state arrangingPillows {
                entry do send new ActivateSignal() to controller.pillowActivate;
                accept AlignmentCompleteSignal
                    then idle;
            }
        }

        perform state controllerStates : ControllerStates {
            in controller = self;
        }
    }

    part def SelfMakingBed {
        part frame : BedFrame;
        part mattress : Mattress;

        part topSheet : Sheet;
        part bottomSheet : Sheet;
        part blanket : Blanket;
        part pillows : Pillow[2];

        part occupancySensor : OccupancySensor;
        part sheetActuator : SheetTensioningActuator;
        part blanketActuator : BlanketFoldingActuator;
        part pillowActuator : PillowArrangementActuator;

        part controller : CentralController;

        connect occupancySensor.occupancy to controller.occupancy;
        connect occupancySensor.vacantTime to controller.vacantTime;

        connect controller.tensionActivate to sheetActuator.activate;
        connect sheetActuator.status to controller.tensionStatus;

        connect controller.foldActivate to blanketActuator.activate;
        connect blanketActuator.status to controller.foldStatus;

        connect controller.pillowActivate to pillowActuator.activate;
        connect pillowActuator.status to controller.alignmentStatus;
    }

    requirement def BedMakingQuality {
        subject bed : SelfMakingBed;
        requirement sheetTensionRequirement {
            doc /* The sheets must be sufficiently tight. */
        }
        requirement blanketFoldRequirement {
            doc /* The blanket must be correctly folded. */
        }
        requirement pillowAlignmentRequirement {
            doc /* The pillows must be properly aligned. */
        }
        requirement cycleTimeRequirement {
            doc /* The entire automated cycle must be completed within 2 minutes. */
        }
        requirement vacancySafetyRequirement {
            doc /* The system shall only operate when the bed has been vacant for at least 60 seconds. */
        }
    }

    part selfMakingBed : SelfMakingBed {
        requirement r : BedMakingQuality;
        satisfy r.sheetTensionRequirement by sheetActuator;
        satisfy r.blanketFoldRequirement by blanketActuator;
        satisfy r.pillowAlignmentRequirement by pillowActuator;
        satisfy r.cycleTimeRequirement by controller;
        satisfy r.vacancySafetyRequirement by controller;
    }
}
