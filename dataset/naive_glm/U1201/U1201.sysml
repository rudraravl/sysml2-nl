package SelfMakingBed {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    // ---- Enumerations ----
    enum def OccupancyState { occupied; vacant; }
    enum def ActuatorState { idle; active; completed; fault; }
    enum def FoldPattern { hospital; hotel; }

    // ---- Data definitions ----
    attribute def OccupancyReading {
        attribute occupancy : OccupancyState;
        attribute vacantDuration : Duration;
    }

    attribute def TensionReading {
        attribute measuredTension : Force;
        attribute targetTension : Force;
        attribute tensionOK : Boolean;
    }

    attribute def BlanketFoldReading {
        attribute foldComplete : Boolean;
        attribute foldPattern : FoldPattern;
    }

    attribute def PillowAlignmentReading {
        attribute aligned : Boolean;
        attribute offset : Length;
    }

    attribute def ActuatorCommand {
        attribute commandId : String;
        attribute activate : Boolean;
        attribute targetValue : Real;
    }

    // ---- Ports ----
    port def OccupancyPort {
        out occupancyReading : OccupancyReading;
    }
    port def TensionFeedbackPort {
        out tensionReading : TensionReading;
    }
    port def BlanketFeedbackPort {
        out blanketReading : BlanketFoldReading;
    }
    port def PillowFeedbackPort {
        out pillowReading : PillowAlignmentReading;
    }
    port def CommandPort {
        in command : ActuatorCommand;
    }

    // ---- Physical parts ----
    part def BedFrame {
        attribute length : Length;
        attribute width : Length;
    }

    part def Mattress {
        attribute length : Length;
        attribute width : Length;
        attribute thickness : Length;
    }

    part def TopSheet {
        attribute tension : Force;
    }

    part def BottomSheet {
        attribute tension : Force;
    }

    part def Blanket {
        attribute foldPattern : FoldPattern;
    }

    part def Pillow {
        attribute position : Length;
    }

    // ---- Sensors ----
    part def OccupancySensor {
        port occupancyOut : OccupancyPort;
        attribute detectionThreshold : Force;
        attribute sampleRate : Duration;
        attribute currentReading : OccupancyReading;

        action def SampleOccupancy {
            in pressureInput : Force;
            out publishedReading : OccupancyReading;
        }

        action def UpdateVacantTimer {
            in previous : OccupancyReading;
            in elapsed : Duration;
            out updated : OccupancyReading;
        }
    }

    // ---- Actuators ----
    part def SheetTensioningActuator {
        port commandIn : CommandPort;
        port feedbackOut : TensionFeedbackPort;
        attribute targetTension : Force;
        attribute maxStroke : Length;
        attribute state : ActuatorState;
        attribute currentReading : TensionReading;

        action def TensionSheet {
            in target : Force;
            out achieved : TensionReading;
        }
    }

    part def BlanketFoldingActuator {
        port commandIn : CommandPort;
        port feedbackOut : BlanketFeedbackPort;
        attribute foldPattern : FoldPattern;
        attribute state : ActuatorState;
        attribute currentReading : BlanketFoldReading;

        action def FoldBlanket {
            in pattern : FoldPattern;
            out result : BlanketFoldReading;
        }
    }

    part def PillowArrangementActuator {
        port commandIn : CommandPort;
        port feedbackOut : PillowFeedbackPort;
        attribute targetPosition : Length;
        attribute state : ActuatorState;
        attribute currentReading : PillowAlignmentReading;

        action def ArrangePillow {
            in target : Length;
            out result : PillowAlignmentReading;
        }
    }

    // ---- Controller state machine ----
    state def ControllerStates {
        entry; then idle;

        state idle;

        transition idle_to_monitoring
            first idle
            if occupancyReading.occupancy == OccupancyState::occupied
            then monitoring;

        state monitoring {
            entry; then checkVacancy;
            action checkVacancy;
        }

        transition monitoring_to_idle
            first monitoring
            if occupancyReading.occupancy == OccupancyState::occupied
            then idle;

        transition monitoring_to_vacantTimer
            first monitoring
            if occupancyReading.occupancy == OccupancyState::vacant
            then vacantTimer;

        state vacantTimer {
            entry; then countDown;
            action countDown;
        }

        transition vacantTimer_to_monitoring
            first vacantTimer
            if occupancyReading.occupancy == OccupancyState::occupied
            then monitoring;

        transition vacantTimer_to_making
            first vacantTimer
            if occupancyReading.vacantDuration >= vacantDelayThreshold
            then makingSequence;

        state makingSequence {
            entry; then sheetTensioning;

            state sheetTensioning {
                entry; then tensionTopSheet;
                action tensionTopSheet;
                then tensionBottomSheet;
                action tensionBottomSheet;
            }

            transition sheet_to_blanket
                first sheetTensioning
                if sheetFeedback.tensionOK == true
                then blanketFolding;

            state blanketFolding {
                entry; then foldBlanketAction;
                action foldBlanketAction;
            }

            transition blanket_to_pillow
                first blanketFolding
                if blanketFeedback.foldComplete == true
                then pillowArranging;

            state pillowArranging {
                entry; then arrangePillowAction;
                action arrangePillowAction;
            }

            transition pillow_to_complete
                first pillowArranging
                if pillowFeedback.aligned == true
                then complete;
        }

        transition making_to_fault
            first makingSequence
            if cycleElapsed >= cycleTimeout
            then fault;

        state complete {
            entry; then reset;
            action reset;
        }

        transition complete_to_idle
            first complete
            then idle;

        state fault {
            entry; then logFault;
            action logFault;
        }

        transition fault_to_idle
            first fault
            if resetRequested == true
            then idle;
    }

    // ---- Central controller ----
    part def CentralController {
        port occupancyIn : OccupancyPort;
        port sheetCommandOut : CommandPort;
        port sheetFeedbackIn : TensionFeedbackPort;
        port blanketCommandOut : CommandPort;
        port blanketFeedbackIn : BlanketFeedbackPort;
        port pillowCommandOut : CommandPort;
        port pillowFeedbackIn : PillowFeedbackPort;

        attribute vacantDelayThreshold : Duration = 60 [s];
        attribute cycleTimeout : Duration = 120 [s];
        attribute targetSheetTension : Force = 25 [N];
        attribute pillowTargetOffset : Length = 0.0 [m];
        attribute cycleElapsed : Duration;
        attribute resetRequested : Boolean;

        attribute occupancyReading : OccupancyReading;
        attribute sheetFeedback : TensionReading;
        attribute blanketFeedback : BlanketFoldReading;
        attribute pillowFeedback : PillowAlignmentReading;

        state machine controllerStates : ControllerStates;

        action def CoordinateMakingCycle {
            in trigger : OccupancyReading;
            out sheetCommand : ActuatorCommand;
            out blanketCommand : ActuatorCommand;
            out pillowCommand : ActuatorCommand;
        }
    }

    // ---- Requirements ----
    requirement def SafetyRequirement {
        doc "The system shall only operate when the bed has been vacant for at least 60 seconds.";
        attribute minVacantDuration : Duration = 60 [s];
        constraint { occupancyReading.vacantDuration >= minVacantDuration }
    }

    requirement def SheetTensionRequirement {
        doc "Sheets shall be tensioned to at least the target tension.";
        attribute targetTension : Force = 25 [N];
        constraint { sheetFeedback.measuredTension >= targetTension }
    }

    requirement def BlanketFoldRequirement {
        doc "Blanket shall be folded according to the selected pattern.";
        constraint { blanketFeedback.foldComplete == true }
    }

    requirement def PillowAlignmentRequirement {
        doc "Pillows shall be aligned within tolerance at the head of the bed.";
        attribute maxOffset : Length = 0.02 [m];
        constraint { pillowFeedback.offset <= maxOffset }
    }

    requirement def CycleTimeRequirement {
        doc "The entire making cycle shall complete within 120 seconds.";
        attribute maxCycleTime : Duration = 120 [s];
        constraint { cycleElapsed <= maxCycleTime }
    }

    // ---- Top-level system ----
    part def SelfMakingBedSystem {
        requirement safetyReq : SafetyRequirement;
        requirement sheetReq : SheetTensionRequirement;
        requirement blanketReq : BlanketFoldRequirement;
        requirement pillowReq : PillowAlignmentRequirement;
        requirement cycleReq : CycleTimeRequirement;

        part frame : BedFrame {
            attribute length = 2.0 [m];
            attribute width = 1.5 [m];
        }

        part mattress : Mattress {
            attribute length = 2.0 [m];
            attribute width = 1.5 [m];
            attribute thickness = 0.25 [m];
        }

        part topSheet : TopSheet;
        part bottomSheet : BottomSheet;

        part blanket : Blanket {
            attribute foldPattern = FoldPattern::hotel;
        }

        part pillows : Pillow[2];

        part occupancySensor : OccupancySensor {
            attribute detectionThreshold = 20 [N];
            attribute sampleRate = 0.5 [s];
        }

        part controller : CentralController;

        part sheetActuator : SheetTensioningActuator {
            attribute targetTension = 25 [N];
            attribute maxStroke = 0.15 [m];
        }

        part blanketActuator : BlanketFoldingActuator {
            attribute foldPattern = FoldPattern::hotel;
        }

        part pillowActuator : PillowArrangementActuator {
            attribute targetPosition = 0.0 [m];
        }

        connection occupancyConn
            connect occupancySensor.occupancyOut to controller.occupancyIn;

        connection sheetCmdConn
            connect controller.sheetCommandOut to sheetActuator.commandIn;

        connection sheetFbConn
            connect sheetActuator.feedbackOut to controller.sheetFeedbackIn;

        connection blanketCmdConn
            connect controller.blanketCommandOut to blanketActuator.commandIn;

        connection blanketFbConn
            connect blanketActuator.feedbackOut to controller.blanketFeedbackIn;

        connection pillowCmdConn
            connect controller.pillowCommandOut to pillowActuator.commandIn;

        connection pillowFbConn
            connect pillowActuator.feedbackOut to controller.pillowFeedbackIn;

        satisfy safetyReq by controller;
        satisfy sheetReq by sheetActuator;
        satisfy blanketReq by blanketActuator;
        satisfy pillowReq by pillowActuator;
        satisfy cycleReq by controller;
    }
}
