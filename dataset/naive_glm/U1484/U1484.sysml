package IndustrialRivetingMachine {
    import ISQ::*;
    import ScalarValues::*;

    // ===== Value Types =====
    value type PressureValue :> Real {
        unit 'Pa';
    }
    value type ForceValue :> Real {
        unit 'N';
    }
    value type TimeValue :> Real {
        unit 's';
    }
    value type PercentageValue :> Real {
        unit '%';
    }
    value type CountValue :> Integer;
    value type LengthValue :> Real {
        unit 'mm';
    }
    value type DiameterValue :> Real {
        unit 'mm';
    }

    // ===== Item Types =====
    item def HydraulicFluid;
    item def MetalWorkpiece {
        attribute thickness : LengthValue;
        attribute material : String;
    }
    item def Rivet {
        attribute diameter : DiameterValue;
        attribute length : LengthValue;
        attribute material : String;
    }
    item def FormedRivet :> Rivet {
        attribute formedHeadDiameter : DiameterValue;
        attribute formedHeadHeight : LengthValue;
    }
    item def RivetedAssembly {
        attribute workpieceCount : CountValue;
        attribute rivetCount : CountValue;
    }
    item def InspectionResult {
        attribute qualityScore : PercentageValue;
        attribute pass : Boolean;
    }
    item def CycleStatus {
        attribute cycleId : Integer;
        attribute state : String;
        attribute duration : TimeValue;
        attribute qualityResult : InspectionResult;
    }

    // ===== Port Definitions =====
    port def HydraulicPressurePort {
        out pressure : PressureValue;
        out fluidFlow : HydraulicFluid;
    }
    port def HydraulicReceivePort {
        in pressure : PressureValue;
        in fluidFlow : HydraulicFluid;
    }
    port def ControlPort {
        in command : String;
        out status : String;
    }
    port def RivetSupplyPort {
        out rivet : Rivet;
    }
    port def RivetReceivePort {
        in rivet : Rivet;
    }
    port def WorkpiecePort {
        inout workpiece : MetalWorkpiece;
    }
    port def AssemblyPort {
        out assembly : RivetedAssembly;
    }
    port def InspectionPort {
        in assembly : RivetedAssembly;
        out result : InspectionResult;
    }
    port def OperatorInterfacePort {
        in operatorCommand : String;
        out machineStatus : String;
        out cycleReport : CycleStatus;
    }

    // ===== Requirements =====
    requirement def RivetingForceRequirement {
        doc /* The riveting head must apply up to 50,000 N of force. */
        attribute maxForce : ForceValue = 50000 [N];
        subject rivetingHead : RivetingHeadAssembly;
        require { rivetingHead.appliedForce <= maxForce }
    }

    requirement def CycleTimeRequirement {
        doc /* A full riveting cycle must complete in 12 seconds or less. */
        attribute maxCycleTime : TimeValue = 12 [s];
        subject controller : SystemController;
        require { controller.cycleDuration <= maxCycleTime }
    }

    requirement def QualityThresholdRequirement {
        doc /* Inspection must achieve at least 95% accuracy. */
        attribute minQuality : PercentageValue = 95 [%];
        subject inspectionUnit : QualityInspectionUnit;
        require { inspectionUnit.qualityScore >= minQuality }
    }

    requirement def MagazineCapacityRequirement {
        doc /* The rivet feeder magazine must hold 500 rivets. */
        attribute capacity : CountValue = 500;
        subject feeder : RivetFeederUnit;
        require { feeder.magazineCapacity == capacity }
    }

    requirement def ClampingStabilityRequirement {
        doc /* The clamping assembly must hold workpieces immobile during riveting. */
        subject clampingAssembly : ClampingAssembly;
        require { clampingAssembly.clampingForce >= 20000 [N] }
    }

    requirement def HydraulicPressureRequirement {
        doc /* The hydraulic power unit must generate sufficient pressure for clamping and riveting. */
        attribute minOperatingPressure : PressureValue = 30000000 [Pa];
        subject hpu : HydraulicPowerUnit;
        require { hpu.outputPressure >= minOperatingPressure }
    }

    // ===== Sub-assemblies =====

    part def HydraulicPowerUnit {
        attribute outputPressure : PressureValue;
        attribute reservoirCapacity : VolumeValue;
        attribute pumpPower : Real;
        attribute maxFlowRate : Real;

        port pressureOutClamp : HydraulicPressurePort;
        port pressureOutRivet : HydraulicPressurePort;

        attribute isRunning : Boolean = false;

        exhibit stateMachine HPUStates {
            entry; then Off;
            state Off;
            state Starting;
            state Running;
            state Faulted;
            transition off_to_starting
                first Off
                accept StartSignal
                then Starting;
            transition starting_to_running
                first Starting
                accept PressureReached
                then Running;
            transition running_to_off
                first Running
                accept StopSignal
                then Off;
            transition any_to_faulted
                first Off, Starting, Running
                accept FaultSignal
                then Faulted;
            transition faulted_to_off
                first Faulted
                accept ResetSignal
                then Off;
        }

        action def generatePressure {
            in targetPressure : PressureValue;
            out deliveredPressure : PressureValue;
        }
    }

    part def ClampingAssembly {
        attribute clampingForce : ForceValue;
        attribute jawOpening : LengthValue;
        attribute isClamped : Boolean = false;

        port hydraulicIn : HydraulicReceivePort;
        port workpieceInterface : WorkpiecePort;
        port controlIn : ControlPort;

        exhibit stateMachine ClampStates {
            entry; then Released;
            state Released;
            state Clamping;
            state Clamped;
            state Releasing;
            transition released_to_clamping
                first Released
                accept ClampCommand
                then Clamping;
            transition clamping_to_clamped
                first Clamping
                accept ClampEngaged
                then Clamped;
            transition clamped_to_releasing
                first Clamped
                accept ReleaseCommand
                then Releasing;
            transition releasing_to_released
                first Releasing
                accept ReleaseComplete
                then Released;
        }

        action def clampWorkpiece {
            in workpiece : MetalWorkpiece;
            in hydraulicPressure : PressureValue;
            out clamped : Boolean;
        }
    }

    part def RivetingHeadAssembly {
        attribute appliedForce : ForceValue;
        attribute maxForce : ForceValue = 50000 [N];
        attribute strokeLength : LengthValue;
        attribute isForming : Boolean = false;

        port hydraulicIn : HydraulicReceivePort;
        port rivetIn : RivetReceivePort;
        port workpieceInterface : WorkpiecePort;
        port assemblyOut : AssemblyPort;
        port controlIn : ControlPort;

        exhibit stateMachine RivetHeadStates {
            entry; then Idle;
            state Idle;
            state RivetLoaded;
            state Positioning;
            state Forming;
            state Complete;
            transition idle_to_loaded
                first Idle
                accept RivetReceived
                then RivetLoaded;
            transition loaded_to_positioning
                first RivetLoaded
                accept PositionCommand
                then Positioning;
            transition positioning_to_forming
                first Positioning
                accept PositionConfirmed
                then Forming;
            transition forming_to_complete
                first Forming
                accept ForceTargetReached
                then Complete;
            transition complete_to_idle
                first Complete
                accept ResetHead
                then Idle;
        }

        action def formRivet {
            in rivet : Rivet;
            in workpieces : MetalWorkpiece[0..*];
            in hydraulicPressure : PressureValue;
            out formedRivet : FormedRivet;
            out assembly : RivetedAssembly;
        }
    }

    part def RivetFeederUnit {
        attribute magazineCapacity : CountValue = 500;
        attribute currentCount : CountValue;
        attribute feedRate : Real;

        port rivetOut : RivetSupplyPort;
        port controlIn : ControlPort;

        exhibit stateMachine FeederStates {
            entry; then Ready;
            state Ready;
            state Feeding;
            state Empty;
            state Refilling;
            transition ready_to_feeding
                first Ready
                accept FeedCommand
                then Feeding;
            transition feeding_to_ready
                first Feeding
                accept RivetDispensed
                then Ready;
            transition ready_to_empty
                first Ready
                accept MagazineEmpty
                then Empty;
            transition empty_to_refilling
                first Empty
                accept RefillCommand
                then Refilling;
            transition refilling_to_ready
                first Refilling
                accept RefillComplete
                then Ready;
        }

        action def feedRivet {
            in requestedSize : DiameterValue;
            out dispensedRivet : Rivet;
            out remainingCount : CountValue;
        }
    }

    part def QualityInspectionUnit {
        attribute qualityScore : PercentageValue;
        attribute minThreshold : PercentageValue = 95 [%];
        attribute inspectionMethod : String;

        port inspectionIn : InspectionPort;
        port controlIn : ControlPort;

        exhibit stateMachine InspectionStates {
            entry; then Standby;
            state Standby;
            state Inspecting;
            state ResultReady;
            transition standby_to_inspecting
                first Standby
                accept InspectCommand
                then Inspecting;
            transition inspecting_to_resultready
                first Inspecting
                accept InspectionComplete
                then ResultReady;
            transition resultready_to_standby
                first ResultReady
                accept ResultAcknowledged
                then Standby;
        }

        action def inspectJoint {
            in assembly : RivetedAssembly;
            out result : InspectionResult;
        }
    }

    part def SystemController {
        attribute cycleDuration : TimeValue;
        attribute maxCycleTime : TimeValue = 12 [s];
        attribute cycleCount : CountValue;
        attribute currentState : String;
        attribute emergencyStopActive : Boolean = false;

        port operatorInterface : OperatorInterfacePort;
        port clampControl : ControlPort;
        port rivetHeadControl : ControlPort;
        port feederControl : ControlPort;
        port inspectionControl : ControlPort;
        port hpuControl : ControlPort;

        exhibit stateMachine ControllerStates {
            entry; then Idle;
            state Idle;
            state Initializing;
            state LoadingWorkpiece;
            state FeedingRivet;
            state Clamping;
            state Riveting;
            state Inspecting;
            state Unloading;
            state Complete;
            state EmergencyStop;
            transition idle_to_initializing
                first Idle
                accept StartCycle
                then Initializing;
            transition initializing_to_loading
                first Initializing
                accept SystemReady
                then LoadingWorkpiece;
            transition loading_to_feeding
                first LoadingWorkpiece
                accept WorkpieceLoaded
                then FeedingRivet;
            transition feeding_to_clamping
                first FeedingRivet
                accept RivetFed
                then Clamping;
            transition clamping_to_riveting
                first Clamping
                accept ClampConfirmed
                then Riveting;
            transition riveting_to_inspecting
                first Riveting
                accept RivetFormed
                then Inspecting;
            transition inspecting_to_unloading
                first Inspecting
                accept InspectionDone
                then Unloading;
            transition unloading_to_complete
                first Unloading
                accept WorkpieceUnloaded
                then Complete;
            transition complete_to_idle
                first Complete
                accept CycleReset
                then Idle;
            transition any_to_emergency
                first Idle, Initializing, LoadingWorkpiece, FeedingRivet, Clamping, Riveting, Inspecting, Unloading, Complete
                accept EmergencyStopCommand
                then EmergencyStop;
            transition emergency_to_idle
                first EmergencyStop
                accept EmergencyReset
                then Idle;
        }

        action def executeRivetingCycle {
            in workpiece : MetalWorkpiece;
            out cycleStatus : CycleStatus;
        }

        action def handleOperatorCommand {
            in command : String;
            out response : String;
        }
    }

    // ===== Top-level System =====
    part def AutomatedRivetingMachine {
        attribute machineId : String;
        attribute machineStatus : String;
        attribute totalCycles : CountValue;

        part hydraulicPowerUnit : HydraulicPowerUnit {
            attribute outputPressure = 35000000 [Pa];
            attribute reservoirCapacity = 80 [L];
            attribute pumpPower = 15000;
            attribute maxFlowRate = 50;
        }

        part clampingAssembly : ClampingAssembly {
            attribute clampingForce = 25000 [N];
            attribute jawOpening = 100 [mm];
        }

        part rivetingHeadAssembly : RivetingHeadAssembly {
            attribute appliedForce = 0 [N];
            attribute strokeLength = 50 [mm];
        }

        part rivetFeederUnit : RivetFeederUnit {
            attribute currentCount = 500;
            attribute feedRate = 2;
        }

        part qualityInspectionUnit : QualityInspectionUnit {
            attribute qualityScore = 96 [%];
            attribute inspectionMethod = "OpticalDimensional";
        }

        part systemController : SystemController {
            attribute cycleCount = 0;
            attribute currentState = "Idle";
        }

        // Operator interface binding
        connection controllerOperatorInterface connect systemController.operatorInterface to operatorInterface;

        // Hydraulic pressure distribution
        connection hpuToClamp connect hydraulicPowerUnit.pressureOutClamp to clampingAssembly.hydraulicIn;
        connection hpuToRivetHead connect hydraulicPowerUnit.pressureOutRivet to rivetingHeadAssembly.hydraulicIn;

        // Rivet supply
        connection feederToRivetHead connect rivetFeederUnit.rivetOut to rivetingHeadAssembly.rivetIn;

        // Workpiece flow
        connection clampToRivetHeadWorkpiece connect clampingAssembly.workpieceInterface to rivetingHeadAssembly.workpieceInterface;

        // Assembly to inspection
        connection rivetHeadToInspection connect rivetingHeadAssembly.assemblyOut to qualityInspectionUnit.inspectionIn;

        // Control lines
        connection controllerToHPU connect systemController.hpuControl to hydraulicPowerUnit.controlIn;
        connection controllerToClamp connect systemController.clampControl to clampingAssembly.controlIn;
        connection controllerToRivetHead connect systemController.rivetHeadControl to rivetingHeadAssembly.controlIn;
        connection controllerToFeeder connect systemController.feederControl to rivetFeederUnit.controlIn;
        connection controllerToInspection connect systemController.inspectionControl to qualityInspectionUnit.controlIn;

        // Requirements satisfaction
        satisfy rivetingForceRequirement by rivetingHeadAssembly;
        satisfy cycleTimeRequirement by systemController;
        satisfy qualityThresholdRequirement by qualityInspectionUnit;
        satisfy magazineCapacityRequirement by rivetFeederUnit;
        satisfy clampingStabilityRequirement by clampingAssembly;
        satisfy hydraulicPressureRequirement by hydraulicPowerUnit;
    }

    // External operator interface port
    port def OperatorInterfacePortExternal :> OperatorInterfacePort;

    // Signals for state machines
    item def StartSignal;
    item def StopSignal;
    item def FaultSignal;
    item def ResetSignal;
    item def PressureReached;
    item def ClampCommand;
    item def ClampEngaged;
    item def ReleaseCommand;
    item def ReleaseComplete;
    item def RivetReceived;
    item def PositionCommand;
    item def PositionConfirmed;
    item def ForceTargetReached;
    item def ResetHead;
    item def FeedCommand;
    item def RivetDispensed;
    item def MagazineEmpty;
    item def RefillCommand;
    item def RefillComplete;
    item def InspectCommand;
    item def InspectionComplete;
    item def ResultAcknowledged;
    item def StartCycle;
    item def SystemReady;
    item def WorkpieceLoaded;
    item def RivetFed;
    item def ClampConfirmed;
    item def RivetFormed;
    item def InspectionDone;
    item def WorkpieceUnloaded;
    item def CycleReset;
    item def EmergencyStopCommand;
    item def EmergencyReset;
}
