package RoboticPaintingSystem {
    import ScalarValues::*;
    import ISQ::*;
    import ISQSpace::*;
    import ISQVolume::*;
    import ISQTime::*;

    // ---- Value Types ----
    attribute def LengthUnit :> Real { :> unit = m; }
    attribute def VolumeUnit :> Real { :> unit = L; }
    attribute def PressureUnit :> Real { :> unit = Pa; }
    attribute def ThicknessUnit :> Real { :> unit = mm; }
    attribute def CoverageUnit :> Real { :> unit = percent; }
    attribute def ThroughputUnit :> Real { :> unit = "1/h"; }
    attribute def AngularPosition :> Real { :> unit = "rad"; }

    // ---- Enumerations ----
    enum def PaintColor { red; white; silver; }
    enum def CoatStage { firstCoat; secondCoat; finalInspection; }
    enum def InspectionResult { pass; fail; }
    enum def WorkpieceStatus { raw; firstCoatApplied; secondCoatApplied; finished; }

    // ---- Item Definitions ----
    item def Paint {
        attribute color : PaintColor;
        attribute viscosity : Real { :> unit = "Pa*s"; }
    }
    item def Workpiece {
        attribute id : String;
        attribute status : WorkpieceStatus := WorkpieceStatus::raw;
        attribute coverage : CoverageUnit := 0.0;
        attribute thickness : ThicknessUnit := 0.0;
    }
    item def QualityReport {
        attribute workpieceId : String;
        attribute coverage : CoverageUnit;
        attribute thickness : ThicknessUnit;
        attribute result : InspectionResult;
        attribute defectsDetected : Boolean;
    }
    item def RobotCommand {
        attribute commandType : String;
        attribute targetColor : PaintColor;
        attribute coatStage : CoatStage;
    }

    // ---- Port Definitions ----
    port def PaintFlowPort {
        out item paint : Paint;
    }
    port def WorkpieceFlowPort {
        out item workpiece : Workpiece;
    }
    port def CommandPort {
        in item command : RobotCommand;
    }
    port def ReportPort {
        out item report : QualityReport;
    }
    port def PowerPort {
        attribute voltage : Real { :> unit = V; }
        attribute current : Real { :> unit = A; }
    }

    // ---- Part Definitions ----
    part def SprayNozzle {
        attribute operatingPressure : PressureUnit := 200000.0;
        attribute flowRate : Real { :> unit = "mL/s"; } := 50.0;
        port paintIn : PaintFlowPort;
        port sprayOut : PaintFlowPort;
        action def Atomize {
            in paint : Paint;
            out atomizedPaint : Paint;
        }
    }

    part def RoboticArm {
        attribute reach : LengthUnit := 1.8;
        attribute axisCount : Integer := 6;
        attribute jointAngles : AngularPosition[6];
        port nozzleMount;
        port commandIn : CommandPort;
        action def PositionArm {
            in targetPose : Any;
            out positioned : Boolean;
        }
        action def ApplyCoat {
            in color : PaintColor;
            in stage : CoatStage;
            out applied : Boolean;
        }
    }

    part def VisionSystem {
        attribute resolution : Real { :> unit = "MP"; } := 12.0;
        port reportOut : ReportPort;
        action def Inspect {
            in workpiece : Workpiece;
            out report : QualityReport;
        }
    }

    part def ConveyorBelt {
        attribute speed : Real { :> unit = "m/s"; } := 0.2;
        attribute length : LengthUnit := 3.0;
        port workpieceOut : WorkpieceFlowPort;
        action def Transport {
            in workpiece : Workpiece;
            out delivered : Workpiece;
        }
    }

    part def PaintReservoir {
        attribute capacity : VolumeUnit := 200.0;
        attribute currentLevel : VolumeUnit := 200.0;
        attribute availableColors : PaintColor[3] := [PaintColor::red, PaintColor::white, PaintColor::silver];
        port paintOut : PaintFlowPort;
        action def SupplyPaint {
            in color : PaintColor;
            out paint : Paint;
        }
    }

    part def SystemController {
        port commandOut : CommandPort;
        port reportIn : ReportPort;
        action def Orchestrate {
            in workpiece : Workpiece;
            out command : RobotCommand;
        }
    }

    // ---- Top-level System ----
    part def AutomatedPaintingSystem {
        part controller : SystemController;
        part robotArm : RoboticArm;
        part nozzle : SprayNozzle;
        part vision : VisionSystem;
        part inputConveyor : ConveyorBelt;
        part outputConveyor : ConveyorBelt;
        part reservoir : PaintReservoir;

        connection paintSupply connect reservoir.paintOut to nozzle.paintIn;
        connection nozzleMount connect nozzle.sprayOut to robotArm.nozzleMount;
        connection commandLink connect controller.commandOut to robotArm.commandIn;
        connection reportLink connect vision.reportOut to controller.reportIn;
        connection inputFlow connect inputConveyor.workpieceOut to robotArm;
        connection outputFlow connect robotArm to outputConveyor.workpieceOut;

        // ---- Operational State Machine ----
        state def PaintingProcess {
            initial standby;
            state awaitingWorkpiece;
            state positioningArm;
            state applyingFirstCoat;
            state inspectingFirstCoat;
            state reapplyingFirstCoat;
            state applyingSecondCoat;
            state inspectingSecondCoat;
            state cleaningSpraySystem;
            state transferringToOutput;
            state resetting;

            transition standby_to_awaiting first standby if workpieceArrived else awaitingWorkpiece;
            transition awaiting_to_positioning await awaitingWorkpiece then positioningArm;
            transition positioning_to_firstCoat done positioningArm then applyingFirstCoat;
            transition firstCoat_to_inspect done applyingFirstCoat then inspectingFirstCoat;
            transition inspect_pass_to_secondCoat if firstInspectionResult == InspectionResult::pass then applyingSecondCoat;
            transition inspect_fail_to_reapply if firstInspectionResult == InspectionResult::fail then reapplyingFirstCoat;
            transition reapply_to_inspect done reapplyingFirstCoat then inspectingFirstCoat;
            transition secondCoat_to_finalInspect done applyingSecondCoat then inspectingSecondCoat;
            transition finalInspect_pass_to_cleaning if finalInspectionResult == InspectionResult::pass then cleaningSpraySystem;
            transition finalInspect_fail_to_secondCoat if finalInspectionResult == InspectionResult::fail then applyingSecondCoat;
            transition cleaning_to_transfer done cleaningSpraySystem then transferringToOutput;
            transition transfer_to_reset done transferringToOutput then resetting;
            transition reset_to_standby done resetting then standby;
        }

        attribute workpieceArrived : Boolean := false;
        attribute firstInspectionResult : InspectionResult;
        attribute finalInspectionResult : InspectionResult;

        exhibit state PaintingProcess;

        // ---- Requirements ----
        requirement def CoverageRequirement {
            doc "The system shall achieve at least 95% paint coverage on each workpiece."
            attribute minCoverage : CoverageUnit := 95.0;
            constraint { coverage >= minCoverage }
        }
        requirement def ThicknessRequirement {
            doc "The final paint thickness shall be between 0.05mm and 0.20mm."
            attribute minThickness : ThicknessUnit := 0.05;
            attribute maxThickness : ThicknessUnit := 0.20;
            constraint { thickness >= minThickness and thickness <= maxThickness }
        }
        requirement def ThroughputRequirement {
            doc "The system shall process at least 15 workpieces per hour."
            attribute minThroughput : ThroughputUnit := 15.0;
            constraint { throughput >= minThroughput }
        }

        requirement coverageReq : CoverageRequirement {
            attribute coverage : CoverageUnit = vision.reportOut.report.coverage;
        }
        requirement thicknessReq : ThicknessRequirement {
            attribute thickness : ThicknessUnit = vision.reportOut.report.thickness;
        }
        requirement throughputReq : ThroughputRequirement {
            attribute throughput : ThroughputUnit := 15.0;
        }

        // ---- Main Action Sequence ----
        action def PaintWorkpiece {
            in workpiece : Workpiece;
            in paintColor : PaintColor;
            out finishedWorkpiece : Workpiece;
            out report : QualityReport;

            // Step 1: Position arm
            action position : RoboticArm::PositionArm {
                in targetPose = workpiece;
            }
            // Step 2: Apply first coat
            action firstCoat : RoboticArm::ApplyCoat {
                in color = paintColor;
                in stage = CoatStage::firstCoat;
            }
            // Step 3: Inspect first coat
            action inspectFirst : VisionSystem::Inspect {
                in workpiece = workpiece;
            }
            // Step 4: Reapply if needed
            flow if inspectFirst.report.result == InspectionResult::fail then
                action reapplyFirst : RoboticArm::ApplyCoat {
                    in color = paintColor;
                    in stage = CoatStage::firstCoat;
                }
            // Step 5: Apply second coat
            action secondCoat : RoboticArm::ApplyCoat {
                in color = paintColor;
                in stage = CoatStage::secondCoat;
            }
            // Step 6: Final inspection
            action finalInspect : VisionSystem::Inspect {
                in workpiece = workpiece;
            }
            // Step 7: Clean spray system
            action clean : SprayNozzle::Atomize {
                in paint = null;
            }
            // Step 8: Transfer to output
            action transfer : ConveyorBelt::Transport {
                in workpiece = workpiece;
            }
        }
    }
}
