package AllTerrainVehicle {
    import ScalarValues::*;

    // ===== Units =====
    unit deg;
    unit kPa;
    unit cm;
    unit N_per_mm;
    unit Nm;
    unit km_per_h;
    unit s;

    // ===== Value Types =====
    value type SlopeAngle :> Real {
        unit deg;
    }

    value type RoughnessIndex :> Real {
    }

    value type SoilCohesion :> Real {
        unit kPa;
    }

    value type TerrainabilityIndex :> Real {
    }

    value type SuspensionHeight :> Real {
        unit cm;
    }

    value type SuspensionStiffness :> Real {
        unit N_per_mm;
    }

    value type TorqueValue :> Real {
        unit Nm;
    }

    value type SpeedValue :> Real {
        unit km_per_h;
    }

    value type TimeStamp :> Real {
        unit s;
    }

    // ===== Enumerations =====
    enum def TerrainCategory {
        smooth;
        moderate;
        rough;
        extreme;
    }

    enum def TraversalDecision {
        traversable;
        nonTraversable;
    }

    // ===== Item Definitions =====
    item def TerrainProfile {
        attribute slope : SlopeAngle;
        attribute roughness : RoughnessIndex;
        attribute cohesion : SoilCohesion;
    }

    item def TerrainScanData {
        attribute profile : TerrainProfile;
        attribute timestamp : TimeStamp;
        attribute scannerId : Integer;
    }

    item def ConfigurationCommand {
        attribute targetHeight : SuspensionHeight;
        attribute targetStiffness : SuspensionStiffness;
        attribute targetTorque : TorqueValue;
        attribute targetSpeed : SpeedValue;
        attribute category : TerrainCategory;
    }

    item def TraversalStatus {
        attribute decision : TraversalDecision;
        attribute index : TerrainabilityIndex;
        attribute category : TerrainCategory;
    }

    // ===== Port Definitions =====
    port def ScanOutPort {
        out scanData : TerrainScanData;
    }

    port def ScanInPort {
        in scanData : TerrainScanData;
    }

    port def CommandOutPort {
        out command : ConfigurationCommand;
    }

    port def CommandInPort {
        in command : ConfigurationCommand;
    }

    port def StatusOutPort {
        out status : TraversalStatus;
    }

    // ===== Constraint Definitions =====
    constraint def TerrainabilityCalculation {
        in slope : SlopeAngle;
        in roughness : RoughnessIndex;
        in cohesion : SoilCohesion;
        out index : TerrainabilityIndex;

        constraint {
            index == (cohesion / (1.0 + roughness)) * (1.0 - slope / 90.0)
        }
    }

    constraint def TerrainClassificationLogic {
        in index : TerrainabilityIndex;
        out category : TerrainCategory;

        constraint {
            (index > 0.8 implies category == TerrainCategory::smooth) and
            (index > 0.6 and index <= 0.8 implies category == TerrainCategory::moderate) and
            (index > 0.4 and index <= 0.6 implies category == TerrainCategory::rough) and
            (index <= 0.4 implies category == TerrainCategory::extreme)
        }
    }

    constraint def TraversalDecisionLogic {
        in index : TerrainabilityIndex;
        in threshold : TerrainabilityIndex;
        out decision : TraversalDecision;

        constraint {
            (index >= threshold implies decision == TraversalDecision::traversable) and
            (index < threshold implies decision == TraversalDecision::nonTraversable)
        }
    }

    // ===== Action Definitions =====
    action def PerformScan {
        in terrainRef : TerrainProfile;
        out data : TerrainScanData;
    }

    action def CalculateTerrainabilityIndex {
        in profiles : TerrainProfile[4];
        out index : TerrainabilityIndex;
    }

    action def ClassifyTerrain {
        in index : TerrainabilityIndex;
        out category : TerrainCategory;
    }

    action def DecideTraversal {
        in index : TerrainabilityIndex;
        in threshold : TerrainabilityIndex;
        out decision : TraversalDecision;
    }

    action def GenerateConfigurationCommand {
        in category : TerrainCategory;
        out command : ConfigurationCommand;
    }

    action def AdjustSuspensionAction {
        in command : ConfigurationCommand;
    }

    action def AdjustDrivetrainAction {
        in command : ConfigurationCommand;
    }

    // ===== Part Definitions =====
    part def TerrainScanner {
        port scanOut : ScanOutPort;
        attribute scannerId : Integer;
        attribute isActive : Boolean;
        action performScan : PerformScan;
    }

    part def TerrainabilityProcessor {
        port scanIn : ScanInPort[4];
        port commandOut : CommandOutPort;
        port statusOut : StatusOutPort;

        attribute currentIndex : TerrainabilityIndex;
        attribute currentCategory : TerrainCategory;
        attribute currentDecision : TraversalDecision;
        attribute thresholdIndex : TerrainabilityIndex = 0.3;

        action calculateIndex : CalculateTerrainabilityIndex;
        action classifyTerrain : ClassifyTerrain;
        action decideTraversal : DecideTraversal;
        action generateCommand : GenerateConfigurationCommand;
    }

    part def AdaptiveWheel {
        attribute wheelId : Integer;
        attribute height : SuspensionHeight;
        attribute stiffness : SuspensionStiffness;
    }

    part def AdaptiveSuspension {
        port commandIn : CommandInPort;
        part wheels : AdaptiveWheel[6];
        attribute currentHeight : SuspensionHeight;
        attribute currentStiffness : SuspensionStiffness;
        action adjustSuspension : AdjustSuspensionAction;
    }

    part def Drivetrain {
        port commandIn : CommandInPort;
        attribute currentTorque : TorqueValue;
        attribute currentSpeed : SpeedValue;
        action adjustDrive : AdjustDrivetrainAction;
    }

    // ===== Top-Level Vehicle =====
    part def AllTerrainGroundVehicle {
        port statusPort : StatusOutPort;

        part scanners : TerrainScanner[4];
        part processor : TerrainabilityProcessor;
        part drivetrain : Drivetrain;
        part suspension : AdaptiveSuspension;

        connection scanLinks connect scanners.scanOut to processor.scanIn;
        connection driveCommandLink connect processor.commandOut to drivetrain.commandIn;
        connection suspensionCommandLink connect processor.commandOut to suspension.commandIn;
        connection statusLink connect processor.statusOut to statusPort;

        state vehicleBehavior {
            entry; then initializing;

            state initializing {
                entry { /* Power on all subsystems and calibrate sensors */ }
            }

            state scanning {
                entry { /* Activate four forward-facing terrain scanners */ }
                do { /* Continuously gather terrain profile data */ }
            }

            state evaluating {
                entry { /* Process scan data through Terrainability Processor */ }
                do { /* Calculate terrainability index and classify terrain */ }
            }

            state adapting {
                entry { /* Issue configuration commands to drivetrain and suspension */ }
                do { /* Adjust suspension height, stiffness, torque, and speed */ }
            }

            state traversing {
                entry { /* Engage drivetrain to move across terrain */ }
                do { /* Maintain current configuration while moving */ }
            }

            state halted {
                entry { /* Stop all motion and set drivetrain torque to zero */ }
                do { /* Await alternative path or operator instruction */ }
            }

            transition t_init_to_scan
                from initializing
                to scanning;

            transition t_scan_to_eval
                from scanning
                to evaluating;

            transition t_eval_to_adapt
                from evaluating
                to adapting
                when processor.currentDecision == TraversalDecision::traversable;

            transition t_eval_to_halt
                from evaluating
                to halted
                when processor.currentDecision == TraversalDecision::nonTraversable;

            transition t_adapt_to_traverse
                from adapting
                to traversing;

            transition t_traverse_to_scan
                from traversing
                to scanning;

            transition t_halt_to_scan
                from halted
                to scanning
                when true;
        }
    }

    // ===== Requirements =====
    requirement def TerrainSensingRequirement {
        subject vehicle : AllTerrainGroundVehicle;
        require {
            vehicle.scanners->size() == 4
        }
    }

    requirement def TerrainabilityProcessingRequirement {
        subject processor : TerrainabilityProcessor;
        require {
            processor.currentIndex >= 0.0 and processor.currentIndex <= 1.0
        }
    }

    requirement def AdaptiveMobilityRequirement {
        subject vehicle : AllTerrainGroundVehicle;
        require {
            vehicle.suspension.wheels->size() == 6
        }
    }

    requirement def SafetyHaltRequirement {
        subject vehicle : AllTerrainGroundVehicle;
        require {
            vehicle.processor.currentDecision == TraversalDecision::nonTraversable
            implies vehicle.processor.statusOut.status.decision == TraversalDecision::nonTraversable
        }
    }

    requirement def ContinuousAdaptationRequirement {
        subject vehicle : AllTerrainGroundVehicle;
        require {
            vehicle.suspension.currentHeight >= 0.0 and
            vehicle.drivetrain.currentTorque >= 0.0 and
            vehicle.drivetrain.currentSpeed >= 0.0
        }
    }

    requirement def TerrainCategoryConfigurationRequirement {
        subject vehicle : AllTerrainGroundVehicle;
        require {
            (vehicle.processor.currentCategory == TerrainCategory::smooth implies
             vehicle.suspension.currentHeight < 15.0 and vehicle.drivetrain.currentSpeed > 40.0) and
            (vehicle.processor.currentCategory == TerrainCategory::extreme implies
             vehicle.suspension.currentHeight > 30.0 and vehicle.drivetrain.currentSpeed < 10.0 and
             vehicle.drivetrain.currentTorque > 500.0)
        }
    }
}
