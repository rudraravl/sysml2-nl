package ManumationCell {
    import ScalarValues::*;
    import ISQ::*;
    import ISQSpace::*;
    import ISQMass::*;

    // ---------- Value Types ----------
    value def PayloadCapacity :> MassValue;
    value def ConveyorSpeed :> SpeedValue;
    value def Resolution :> Real; // megapixels
    value def CycleTime :> DurationValue;
    value def DefectRate :> Real;

    attribute def MassKg :> MassValue {
        :>> unit = 'kg';
    }
    attribute def SpeedMps :> SpeedValue {
        :>> unit = 'm/s';
    }
    attribute def DurationSec :> DurationValue {
        :>> unit = 's';
    }

    // ---------- Item Types ----------
    item def Workpiece {
        attribute mass : MassKg;
        attribute hasDefect : Boolean;
        attribute processed : Boolean;
        attribute finished : Boolean;
    }
    item def RawWorkpiece :> Workpiece {
        redefines hasDefect = false;
        redefines processed = false;
        redefines finished = false;
    }
    item def FinishedProduct :> Workpiece {
        redefines finished = true;
    }
    item def DefectiveWorkpiece :> Workpiece {
        redefines hasDefect = true;
    }

    // ---------- Port Definitions ----------
    port def MaterialPort {
        in item workpiece : Workpiece;
        out item workpieceOut : Workpiece;
    }
    port def ControlPort {
        in attribute command : String;
        out attribute status : String;
    }
    port def VisionPort {
        out attribute workpiecePose : String;
        out attribute inspectionResult : String;
    }
    port def SafetyPort {
        in attribute eStop : Boolean;
        out attribute safeState : String;
    }

    // ---------- Component Definitions ----------
    part def Gripper {
        attribute maxPayload : MassKg = 30 [kg];
        port controlPort : ControlPort;
        attribute gripping : Boolean = false;
        action def Grip {
            in item w : Workpiece;
        }
        action def Release {
            out item w : Workpiece;
        }
    }

    part def RoboticArm {
        attribute axes : Integer = 6;
        attribute maxPayload : MassKg = 30 [kg];
        attribute position : String;
        port controlPort : ControlPort;
        port materialPort : MaterialPort;
        part gripper : Gripper;
        action def Pick {
            in item w : Workpiece;
        }
        action def Place {
            in item w : Workpiece;
            in target : String;
        }
        action def Move {
            in target : String;
        }
    }

    part def Workstation {
        attribute stationName : String;
        attribute operational : Boolean = true;
        port controlPort : ControlPort;
        port materialPort : MaterialPort;
        action def Process {
            in item w : Workpiece;
            out item wProcessed : Workpiece;
        }
    }

    part def MachiningStation :> Workstation {
        redefines stationName = "Machining";
        redefines Process {
            in item w : Workpiece;
            out item wProcessed : Workpiece;
        }
    }
    part def AssemblyStation :> Workstation {
        redefines stationName = "Assembly";
    }
    part def FinishingStation :> Workstation {
        redefines stationName = "Finishing";
    }

    part def ConveyorBelt {
        attribute beltName : String;
        attribute speed : SpeedMps = 0.5 [m/s];
        attribute running : Boolean = false;
        port controlPort : ControlPort;
        port inPort : MaterialPort;
        port outPort : MaterialPort;
        action def Transport {
            in item w : Workpiece;
            out item wOut : Workpiece;
        }
    }

    part def VisionSystem {
        attribute resolution : Resolution = 8.3;
        attribute calibrated : Boolean = true;
        port controlPort : ControlPort;
        port visionPort : VisionPort;
        action def Identify {
            in item w : Workpiece;
            out attribute pose : String;
        }
        action def Inspect {
            in item w : Workpiece;
            out attribute result : String;
        }
    }

    part def CentralController {
        attribute active : Boolean = false;
        port controlPorts : ControlPort[6];
        port safetyPort : SafetyPort;
        attribute productionPlan : String;
        action def PlanSequence {
            out attribute plan : String;
        }
        action def Coordinate {
            in attribute status : String;
        }
        action def Monitor {
            in attribute status : String;
        }
        action def EmergencyShutdown {
        }
    }

    // ---------- State Machine ----------
    state def ControllerStates {
        entry; then Initializing;
        state Initializing {
            entry action selfCheck;
            action selfCheck;
            transition to Ready when selfCheckComplete;
        }
        state Ready {
            transition to Active when startCommandReceived;
        }
        state Active {
            entry action startProduction;
            action startProduction;
            transition to Paused when pauseCommandReceived;
            transition to EmergencyStopped when eStopTriggered;
        }
        state Paused {
            transition to Active when resumeCommandReceived;
            transition to EmergencyStopped when eStopTriggered;
        }
        state EmergencyStopped {
            entry action EmergencyShutdown;
            transition to Ready when resetCommandReceived;
        }
    }

    // ---------- Top-Level Manumation Cell ----------
    part def ManumationCell {
        attribute cellName : String = "ManumationCell-01";
        port safetyPort : SafetyPort;

        part controller : CentralController {
            :>> productionPlan = "Input->Inspect->Machine->Assemble->Finish->Inspect->Output";
        }

        part arm1 : RoboticArm {
            :>> position = "Station1";
        }
        part arm2 : RoboticArm {
            :>> position = "Station3";
        }

        part machiningStation : MachiningStation;
        part assemblyStation : AssemblyStation;
        part finishingStation : FinishingStation;

        part inputConveyor : ConveyorBelt {
            :>> beltName = "Input";
        }
        part transportConveyor : ConveyorBelt {
            :>> beltName = "Transport";
        }
        part outputConveyor : ConveyorBelt {
            :>> beltName = "Output";
        }

        part visionSystem : VisionSystem;

        // Connections
        connection controllerToArm1 : ControlPort connect controller.controlPorts[1] to arm1.controlPort;
        connection controllerToArm2 : ControlPort connect controller.controlPorts[2] to arm2.controlPort;
        connection controllerToMachining : ControlPort connect controller.controlPorts[3] to machiningStation.controlPort;
        connection controllerToAssembly : ControlPort connect controller.controlPorts[4] to assemblyStation.controlPort;
        connection controllerToFinishing : ControlPort connect controller.controlPorts[5] to finishingStation.controlPort;
        connection controllerToVision : ControlPort connect controller.controlPorts[6] to visionSystem.controlPort;

        connection inputToTransport : MaterialPort connect inputConveyor.outPort to transportConveyor.inPort;
        connection transportToMachining : MaterialPort connect transportConveyor.outPort to machiningStation.materialPort;
        connection machiningToAssembly : MaterialPort connect machiningStation.materialPort to assemblyStation.materialPort;
        connection assemblyToFinishing : MaterialPort connect assemblyStation.materialPort to finishingStation.materialPort;
        connection finishingToOutput : MaterialPort connect finishingStation.materialPort to outputConveyor.inPort;

        connection visionToController : VisionPort connect visionSystem.visionPort to controller.safetyPort;

        // Production cycle behavior
        action def ProductionCycle {
            in item raw : RawWorkpiece;
            out item product : FinishedProduct;
            action identify : VisionSystem::Identpect;
            action inspect1 : VisionSystem::Inspect;
            action pick1 : RoboticArm::Pick;
            action machine : MachiningStation::Process;
            action assemble : AssemblyStation::Process;
            action finish : FinishingStation::Process;
            action inspect2 : VisionSystem::Inspect;
            action place : RoboticArm::Place;
            flow from raw to identify.workpiece;
            flow from identify to inspect1;
            flow from inspect1 to pick1;
            flow from pick1 to machine;
            flow from machine to assemble;
            flow from assemble to finish;
            flow from finish to inspect2;
            flow from inspect2 to place;
            flow from place to product;
        }

        // Controller state machine
        part controllerStateMachine :> CentralController {
            exhibit state behavior : ControllerStates;
        }
    }

    // ---------- Requirements ----------
    requirement def AutomatedProduction {
        subject cell : ManumationCell;
        doc /* The cell shall autonomously transform raw workpieces into finished products with minimal human intervention. */
        require cell.controller.active == true;
    }

    requirement def PayloadHandling {
        subject arm : RoboticArm;
        doc /* Robotic arms shall handle workpieces up to 30 kg. */
        require arm.maxPayload <= 30 [kg];
    }

    requirement def WorkstationSequence {
        subject cell : ManumationCell;
        doc /* Workpieces shall be processed through machining, assembly, and finishing stations in sequence. */
        require cell.machiningStation.operational == true;
        require cell.assemblyStation.operational == true;
        require cell.finishingStation.operational == true;
    }

    requirement def VisionInspection {
        subject vision : VisionSystem;
        doc /* The vision system shall identify workpieces and perform quality inspections before and after processing. */
        require vision.resolution >= 8.3;
        require vision.calibrated == true;
    }

    requirement def SafetyShutdown {
        subject cell : ManumationCell;
        doc /* The cell shall halt all operations and perform a safe shutdown when an emergency stop is triggered. */
        require cell.safetyPort.eStop == true implies cell.controller.active == false;
    }

    requirement def StateCoverage {
        subject cell : ManumationCell;
        doc /* The cell shall operate through initialization, ready, active, and paused states. */
        require cell.controllerStateMachine.behavior.initializing == true or
                cell.controllerStateMachine.behavior.ready == true or
                cell.controllerStateMachine.behavior.active == true or
                cell.controllerStateMachine.behavior.paused == true;
    }

    // ---------- Satisfaction ----------
    satisfaction def PayloadSatisfied : PayloadHandling {
        subject :>> arm = ManumationCell::arm1;
    }
    satisfaction def VisionSatisfied : VisionInspection {
        subject :>> vision = ManumationCell::visionSystem;
    }
    satisfaction def SafetySatisfied : SafetyShutdown {
        subject :>> cell = ManumationCell;
    }
}
