package LaundryFoldingSystem {

    import ScalarValues::Real;
    import ScalarValues::Integer;
    import ScalarValues::Boolean;
    import ScalarValues::String;

    // ============ Value Types with Units ============
    value type LengthCm :> Real {
        doc "Length in centimeters.";
    }
    value type WidthCm :> Real {
        doc "Width in centimeters.";
    }
    value type ThicknessMm :> Real {
        doc "Thickness in millimeters.";
    }
    value type TempC :> Real {
        doc "Temperature in degrees Celsius.";
    }
    value type SpeedMps :> Real {
        doc "Linear speed in meters per second.";
    }
    value type ThroughputIph :> Real {
        doc "Throughput in items per hour.";
    }
    value type ItemCount :> Integer {
        doc "Count of discrete items.";
    }
    value type Confidence :> Real {
        doc "Confidence fraction from 0 to 1.";
    }
    value type DurationS :> Real {
        doc "Duration in seconds.";
    }
    value type AngleDeg :> Real {
        doc "Angle in degrees.";
    }

    // ============ Enumerations ============
    enum def GarmentType {
        tShirt;
        pants;
        towel;
        sheet;
        unknown;
    }

    enum def SystemMode {
        off;
        idle;
        running;
        maintenance;
        fault;
    }

    // ============ Item Definitions ============
    item def Garment {
        attribute id : String;
        attribute category : GarmentType := GarmentType::unknown;
        attribute length : LengthCm;
        attribute width : WidthCm;
        attribute thickness : ThicknessMm;
        attribute folded : Boolean := false;
    }

    item def Dimensions {
        attribute length : LengthCm;
        attribute width : WidthCm;
    }

    item def VisionResult {
        attribute detectedType : GarmentType;
        attribute dimensions : Dimensions;
        attribute confidence : Confidence;
    }

    item def FoldStep {
        attribute stepId : Integer;
        attribute actionDescription : String;
    }

    item def FoldingPlan {
        attribute targetGarment : GarmentType;
        attribute steps : FoldStep[1..*];
        attribute surfaceTemp : TempC;
        attribute estimatedDuration : DurationS;
    }

    item def ArmCommand {
        attribute stepRef : Integer;
        attribute gripX : LengthCm;
        attribute gripY : WidthCm;
        attribute liftHeight : LengthCm;
        attribute foldAngle : AngleDeg;
    }

    item def SurfaceControlMsg {
        attribute targetTemp : TempC;
        attribute enableHeater : Boolean;
    }

    // ============ Requirements ============
    requirement def ThroughputRequirement {
        doc "The system shall fold a minimum number of garments per hour during continuous operation.";
        attribute minimumGarmentsPerHour : ThroughputIph = 15.0;
    }

    requirement def FoldingPrecisionRequirement {
        doc "Each folded garment shall meet a minimum folding precision.";
        attribute minimumPrecision : Confidence = 0.95;
    }

    requirement def StackerCapacityRequirement {
        doc "The output stacker shall hold a minimum number of folded garments before emptying.";
        attribute minimumCapacity : ItemCount = 30;
    }

    requirement def GarmentClassificationRequirement {
        doc "The vision system shall classify each garment into a supported category and measure its dimensions.";
    }

    requirement def SequentialProcessingRequirement {
        doc "The system shall process exactly one garment at a time.";
    }

    requirement def SurfaceHeatingRequirement {
        doc "The folding surface shall be capable of controlled heating to assist wrinkle reduction.";
        attribute maximumTemperature : TempC = 80.0;
    }

    requirement def ContinuousOperationRequirement {
        doc "The system shall support continuous operation without manual intervention between garments.";
    }

    // ============ Port Definitions ============
    port def GarmentInPort {
        in garment : Garment;
    }

    port def GarmentOutPort {
        out garment : Garment;
    }

    port def VisionResultOutPort {
        out result : VisionResult;
    }

    port def VisionResultInPort {
        in result : VisionResult;
    }

    port def CommandOutPort {
        out command : ArmCommand;
    }

    port def CommandInPort {
        in command : ArmCommand;
    }

    port def SurfaceControlOutPort {
        out control : SurfaceControlMsg;
    }

    port def SurfaceControlInPort {
        in control : SurfaceControlMsg;
    }

    // ============ Part Definitions ============

    part def InputConveyor {
        doc "Conveyor belt that transports an unfolded garment into the main processing area.";
        attribute beltSpeed : SpeedMps = 0.20;
        attribute active : Boolean := false;
        port out garmentOut : GarmentOutPort;

        action def Transport {
            in incoming : Garment;
            out outgoing : Garment;
        }

        action transportGarment : Transport {
            // Belt moves the garment from the loading zone to the folding surface.
        }

        state conveyorState {
            entry; then Stopped;
            state Stopped;
            state Moving;
            transition from Stopped to Moving when active == true;
            transition from Moving to Stopped when active == false;
        }
    }

    part def VisionSystem {
        doc "Camera and image processing subsystem that identifies the garment category and dimensions.";
        port in garmentIn : GarmentInPort;
        port out resultOut : VisionResultOutPort;

        action def Scan {
            in garment : Garment;
            out result : VisionResult;
        }

        action scanGarment : Scan {
            // Captures image and produces VisionResult with category and dimensions.
        }

        state visionState {
            entry; then Idle;
            state Idle;
            state Capturing;
            state Analyzing;
            state Reporting;
            transition from Idle to Capturing accept garmentIn.garment;
            transition from Capturing to Analyzing;
            transition from Analyzing to Reporting;
            transition from Reporting to Idle;
        }
    }

    part def ProcessController {
        doc "Central controller that plans folding sequences and dispatches commands to arms and surface.";
        port in visionResultIn : VisionResultInPort;
        port out armCommandsA : CommandOutPort;
        port out armCommandsB : CommandOutPort;
        port out surfaceControlOut : SurfaceControlOutPort;

        action def PlanFolding {
            in result : VisionResult;
            out plan : FoldingPlan;
        }

        action planFolding : PlanFolding {
            // Selects fold sequence based on detected garment type and dimensions.
        }

        action def DispatchCommands {
            in plan : FoldingPlan;
            out armCommandA : ArmCommand;
            out armCommandB : ArmCommand;
            out surfaceControl : SurfaceControlMsg;
        }

        action dispatchCommands : DispatchCommands {
            // Generates step-by-step commands for arms and surface heater.
        }

        state controllerState {
            entry; then Idle;
            state Idle;
            state Planning;
            state Dispatching;
            state WaitingCompletion;
            transition from Idle to Planning accept visionResultIn.result;
            transition from Planning to Dispatching;
            transition from Dispatching to WaitingCompletion;
            transition from WaitingCompletion to Idle;
        }
    }

    part def FoldingArm {
        doc "Robotic arm that grips, lifts, and folds the garment on the folding surface.";
        attribute armIdentifier : String;
        port in commandIn : CommandInPort;

        action def ExecuteStep {
            in command : ArmCommand;
        }

        action executeStep : ExecuteStep {
            // Performs grip, lift, fold motions per the received ArmCommand.
        }

        state armState {
            entry; then Ready;
            state Ready;
            state Gripping;
            state Lifting;
            state Folding;
            state Releasing;
            transition from Ready to Gripping accept commandIn.command;
            transition from Gripping to Lifting;
            transition from Lifting to Folding;
            transition from Folding to Releasing;
            transition from Releasing to Ready;
        }
    }

    part def FoldingSurface {
        doc "Surface on which garments are folded; capable of controlled heating for wrinkle reduction.";
        attribute currentTemp : TempC := 25.0;
        attribute targetTemp : TempC := 25.0;
        attribute heaterEnabled : Boolean := false;
        port in controlIn : SurfaceControlInPort;
        port in garmentIn : GarmentInPort;
        port out garmentOut : GarmentOutPort;

        action def AdjustTemperature {
            in target : TempC;
        }

        action adjustTemperature : AdjustTemperature {
            // Modulates heater to reach target temperature.
        }

        action def ReleaseGarment {
            in garment : Garment;
            out releasedGarment : Garment;
        }

        action releaseGarment : ReleaseGarment {
            // Transfers folded garment to the output stacker.
        }

        state surfaceState {
            entry; then Idle;
            state Idle;
            state Heating;
            state Holding;
            state Folding;
            state Cooling;
            state Releasing;
            transition from Idle to Heating when controlIn.control.targetTemp > currentTemp;
            transition from Heating to Idle when currentTemp >= targetTemp;
            transition from Idle to Holding accept garmentIn.garment;
            transition from Holding to Folding;
            transition from Folding to Releasing;
            transition from Releasing to Idle;
            transition from Idle to Cooling when controlIn.control.targetTemp < currentTemp;
            transition from Cooling to Idle when currentTemp <= targetTemp;
        }
    }

    part def OutputStacker {
        doc "Collects and stacks folded garments up to a defined capacity.";
        attribute capacity : ItemCount := 30;
        attribute currentCount : ItemCount := 0;
        port in foldedGarmentIn : GarmentInPort;

        action def Stack {
            in garment : Garment;
        }

        action stackGarment : Stack {
            // Adds folded garment to the top of the stack.
        }

        action def EmptyStacker {
            // Operator-assisted removal of accumulated stack.
        }

        action emptyStacker : EmptyStacker {
            // Resets currentCount to zero.
        }

        state stackerState {
            entry; then Accepting;
            state Accepting;
            state Full;
            transition from Accepting to Full when currentCount >= capacity;
            transition from Full to Accepting when currentCount < capacity;
        }
    }

    // ============ Top-Level System ============
    part def AutomatedLaundryFoldingMachine {
        doc "Self-contained automated laundry folding machine.";
        attribute systemMode : SystemMode := SystemMode::off;
        attribute garmentsProcessed : ItemCount := 0;
        attribute lastCycleDuration : DurationS := 0.0;

        requirement throughputRequirement : ThroughputRequirement;
        requirement foldingPrecisionRequirement : FoldingPrecisionRequirement;
        requirement stackerCapacityRequirement : StackerCapacityRequirement;
        requirement garmentClassificationRequirement : GarmentClassificationRequirement;
        requirement sequentialProcessingRequirement : SequentialProcessingRequirement;
        requirement surfaceHeatingRequirement : SurfaceHeatingRequirement;
        requirement continuousOperationRequirement : ContinuousOperationRequirement;

        part inputConveyor : InputConveyor;
        part visionSystem : VisionSystem;
        part processController : ProcessController;
        part foldingArmA : FoldingArm {
            :armIdentifier = "Arm-A";
        }
        part foldingArmB : FoldingArm {
            :armIdentifier = "Arm-B";
        }
        part foldingSurface : FoldingSurface;
        part outputStacker : OutputStacker;

        connect inputConveyor.garmentOut to foldingSurface.garmentIn;
        connect foldingSurface.garmentOut to outputStacker.foldedGarmentIn;
        connect inputConveyor.garmentOut to visionSystem.garmentIn;
        connect visionSystem.resultOut to processController.visionResultIn;
        connect processController.armCommandsA to foldingArmA.commandIn;
        connect processController.armCommandsB to foldingArmB.commandIn;
        connect processController.surfaceControlOut to foldingSurface.controlIn;

        state systemState {
            entry; then Off;
            state Off;
            state Idle;
            state Processing;
            state Maintenance;
            state Faulted;
            transition from Off to Idle when systemMode == SystemMode::idle;
            transition from Idle to Off when systemMode == SystemMode::off;
            transition from Idle to Processing when systemMode == SystemMode::running;
            transition from Processing to Idle when systemMode == SystemMode::idle;
            transition from Idle to Maintenance when systemMode == SystemMode::maintenance;
            transition from Maintenance to Idle when systemMode == SystemMode::idle;
            transition from Off to Faulted when systemMode == SystemMode::fault;
            transition from Idle to Faulted when systemMode == SystemMode::fault;
            transition from Processing to Faulted when systemMode == SystemMode::fault;
            transition from Maintenance to Faulted when systemMode == SystemMode::fault;
            transition from Faulted to Idle when systemMode == SystemMode::idle;
        }
    }
}
