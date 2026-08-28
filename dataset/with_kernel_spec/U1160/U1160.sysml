package 'Automated Robotic Painting System' {
    private import ScalarValues::*;
    private import SI::*;
    
    attribute def Length :> Real;
    attribute def Volume :> Real;
    attribute def Pressure :> Real;
    attribute def Coverage :> Real;
    attribute def Thickness :> Real;
    attribute def Throughput :> Real;
    
    enum def PaintColor { red; white; silver; }
    enum def InspectionResult { pass; fail; }
    
    item def Workpiece;
    item def Paint {
        attribute color : PaintColor;
    }
    item def PaintCommand {
        attribute color : PaintColor;
        attribute pressure : Pressure;
    }
    item def QualityReport {
        attribute coverage : Coverage;
        attribute thickness : Thickness;
        attribute result : InspectionResult;
    }
    
    action positionArm;
    action applyFirstCoat;
    action applySecondCoat;
    action cleanNozzle;
    action moveWorkpiece;
    
    part def SprayNozzle {
        port paintPort { in paint : Paint; }
        port commandPort { in command : PaintCommand; }
    }
    
    part def RoboticArm {
        attribute reach : Length = 1.8 [m];
        attribute axisCount : Integer = 6;
        port commandPort { in command : PaintCommand; }
        part nozzle : SprayNozzle;
    }
    
    part def VisionSystem {
        port reportPort { out report : QualityReport; }
    }
    
    part def Conveyor {
        port workpiecePort { in workpiece : Workpiece; }
    }
    
    part def PaintReservoir {
        attribute capacity : Volume = 200 [L];
        port paintPort { out paint : Paint; }
    }
    
    part def SystemController {
        port robotCommandPort { out command : PaintCommand; }
        port visionReportPort { in report : QualityReport; }
    }
    
    part def PaintingSystem {
        attribute coverage : Coverage;
        attribute thickness : Thickness;
        attribute processingRate : Throughput;
        
        part controller : SystemController;
        part robot : RoboticArm;
        part vision : VisionSystem;
        part inputConveyor : Conveyor;
        part outputConveyor : Conveyor;
        part reservoir : PaintReservoir;
        
        flow paintFlow of Paint from reservoir.paintPort to robot.nozzle.paintPort;
        flow commandFlow of PaintCommand from controller.robotCommandPort to robot.commandPort;
        flow reportFlow of QualityReport from vision.reportPort to controller.visionReportPort;
        
        state def PaintingProcess {
            entry; then standby;
            
            state standby;
            transition t1 first standby accept w : Workpiece via inputConveyor.workpiecePort then positioning;
            
            state positioning;
            transition t2 first positioning do action positionArm then applyingFirstCoat;
            
            state applyingFirstCoat;
            transition t3 first applyingFirstCoat do action applyFirstCoat then firstInspection;
            
            state firstInspection;
            transition t5 first firstInspection accept r1 : QualityReport via vision.reportPort if (r1.result == InspectionResult::fail) then reapplyingFirstCoat;
            transition t6 first firstInspection accept r1 : QualityReport via vision.reportPort if (r1.result == InspectionResult::pass) then applyingSecondCoat;
            
            state reapplyingFirstCoat;
            transition t7 first reapplyingFirstCoat do action applyFirstCoat then firstInspection;
            
            state applyingSecondCoat;
            transition t8 first applyingSecondCoat do action applySecondCoat then finalInspection;
            
            state finalInspection;
            transition t10 first finalInspection accept r2 : QualityReport via vision.reportPort if (r2.result == InspectionResult::fail) then reapplyingSecondCoat;
            transition t11 first finalInspection accept r2 : QualityReport via vision.reportPort if (r2.result == InspectionResult::pass) then cleaning;
            
            state reapplyingSecondCoat;
            transition t12 first reapplyingSecondCoat do action applySecondCoat then finalInspection;
            
            state cleaning;
            transition t13 first cleaning do action cleanNozzle then movingToOutput;
            
            state movingToOutput;
            transition t14 first movingToOutput do action moveWorkpiece then standby;
        }
        
        perform PaintingProcess;
    }
    
    requirement def CoverageRequirement {
        text "The system shall achieve at least 95% paint coverage.";
        attribute minCoverage : Coverage = 95.0;
        subject paintingSystem : PaintingSystem;
    }
    
    requirement def ThicknessRequirement {
        text "The system shall maintain final paint thickness between 0.05mm and 0.20mm.";
        attribute minThickness : Thickness = 0.05;
        attribute maxThickness : Thickness = 0.20;
        subject paintingSystem : PaintingSystem;
    }
    
    requirement def ThroughputRequirement {
        text "The system shall process at least 15 workpieces per hour.";
        attribute minThroughput : Throughput = 15.0;
        subject paintingSystem : PaintingSystem;
    }
    
    requirement coverageReq :> CoverageRequirement {
        satisfy :>> paintingSystem;
    }
    
    requirement thicknessReq :> ThicknessRequirement {
        satisfy :>> paintingSystem;
    }
    
    requirement throughputReq :> ThroughputRequirement {
        satisfy :>> paintingSystem;
    }
}
