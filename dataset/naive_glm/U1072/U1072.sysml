package AutonomousHarvester {

    import ScalarValues::*;
    import ISQ::*;
    import ISQSpace::*;
    import ISQForce::*;
    import ISQMass::*;
    import ISQEnergy::*;
    import ISQTime::*;
    import ISQElectricity::*;

    // ---------- Value Types ----------
    value def Confidence :> Real { unit 'percent'; }
    value def RipenessThreshold :> Real { unit 'percent'; }
    value def BatterySOC :> Real { unit 'percent'; }
    value def BinFillLevel :> Real { unit 'percent'; }
    value def TargetWeight :> MassValue;
    value def HarvestedWeight :> MassValue;
    value def ArmReach :> LengthValue;
    value def GripForce :> ForceValue;
    value def BatteryCapacity :> EnergyValue;
    value def Voltage :> ElectricPotentialValue;

    // ---------- Item Types ----------
    item def GPSCoordinate {
        attribute latitude : Real;
        attribute longitude : Real;
        attribute altitude : Real;
    }

    item def Crop {
        attribute id : String;
        attribute location : GPSCoordinate;
        attribute ripeness : Confidence;
        attribute estimatedMass : MassValue;
        attribute harvested : Boolean = false;
    }

    item def RipenessReport {
        attribute cropId : String;
        attribute location : GPSCoordinate;
        attribute ripeness : Confidence;
        attribute isRipe : Boolean;
    }

    item def PathPlan {
        attribute waypoints : GPSCoordinate[0..*];
        attribute estimatedDistance : LengthValue;
        attribute estimatedTime : TimeValue;
    }

    item def ArmCommand {
        attribute targetLocation : GPSCoordinate;
        attribute gripForce : GripForce;
        attribute action : HarvestAction;
    }

    enum def HarvestAction { position, grip, pick, release, retract; }

    item def HarvestedCrop {
        attribute cropId : String;
        attribute mass : MassValue;
    }

    item def MissionStatus {
        attribute harvestedCount : Integer;
        attribute harvestedWeight : HarvestedWeight;
        attribute targetWeight : TargetWeight;
        attribute goalMet : Boolean;
    }

    item def FaultReport {
        attribute faultCode : Integer;
        attribute description : String;
        attribute severity : FaultSeverity;
    }

    enum def FaultSeverity { info, warning, error, critical; }

    // ---------- Ports ----------
    port def CropDetectionPort {
        out item detectedCrops : Crop[0..*];
        out item ripenessReports : RipenessReport[0..*];
    }

    port def NavigationCommandPort {
        in item pathPlan : PathPlan;
        out item currentLocation : GPSCoordinate;
        out item arrivalStatus : ArrivalStatus;
    }

    enum def ArrivalStatus { enroute, arrived, failed; }

    port def ArmCommandPort {
        out item armCommand : ArmCommand;
        in item armStatus : ArmStatus;
    }

    enum def ArmStatus { idle, positioning, gripping, picking, complete, error; }

    port def ConveyorPort {
        in item harvestedCrop : HarvestedCrop;
        out item binUpdate : BinUpdate;
    }

    item def BinUpdate {
        attribute fillLevel : BinFillLevel;
        attribute totalWeight : HarvestedWeight;
        attribute isFull : Boolean;
    }

    port def MissionControlPort {
        out item missionStatus : MissionStatus;
        out item targetCrop : Crop;
        in item systemState : HarvesterState;
    }

    enum def HarvesterState { initializing, standby, activeHarvesting, charging, unloading, fault; }

    port def PowerPort {
        out attribute soc : BatterySOC;
        out attribute voltage : Voltage;
        in attribute chargingEnabled : Boolean;
    }

    // ---------- Parts ----------
    part def VisionSystem {
        port detectionOut : CropDetectionPort;
        attribute detectionRange : LengthValue = 50 [m];
        attribute minConfidence : Confidence = 85 [%];
        attribute scanInterval : TimeValue = 0.5 [s];

        action scanField {
            out item detectedCrops : Crop[0..*];
        }

        action analyzeRipeness {
            in item crop : Crop;
            out item report : RipenessReport;
        }

        action performScan : scanField {
            // Continuously scan field for crops using GPS coordinates
        }

        action performAnalysis : analyzeRipeness {
            // Analyze each detected crop for ripeness with high confidence
        }
    }

    part def NavigationController {
        port navCmd : NavigationCommandPort;
        attribute maxSpeed : SpeedValue = 2.0 [m/s];
        attribute currentLocation : GPSCoordinate;
        attribute currentPath : PathPlan;

        action planPath {
            in item start : GPSCoordinate;
            in item destination : GPSCoordinate;
            out item pathPlan : PathPlan;
        }

        action driveTo {
            in item pathPlan : PathPlan;
            out item arrivalStatus : ArrivalStatus;
        }

        action performPlanning : planPath {
            // Autonomously plan path to crop location
        }

        action performDriving : driveTo {
            // Drive machine to crop location
        }
    }

    part def HarvestingArm {
        port armCmd : ArmCommandPort;
        attribute maxReach : ArmReach = 1.5 [m];
        attribute maxGripForce : GripForce = 20 [N];
        attribute safeGripForce : GripForce = 8 [N];

        state armStateMachine {
            initial -> idle;
            state idle;
            state positioning;
            state gripping;
            state picking;
            state retracting;
            state complete;

            transition idle_to_positioning
                from idle to positioning
                when armCmd.armCommand.action == HarvestAction::position;

            transition positioning_to_gripping
                from positioning to gripping
                when armCmd.armCommand.action == HarvestAction::grip;

            transition gripping_to_picking
                from gripping to picking
                when armCmd.armCommand.action == HarvestAction::pick;

            transition picking_to_retracting
                from picking to retracting
                when armCmd.armCommand.action == HarvestAction::retract;

            transition retracting_to_complete
                from retracting to complete
                when armCmd.armCommand.action == HarvestAction::release;

            transition complete_to_idle
                from complete to idle
                when armCmd.armStatus == ArmStatus::idle;
        }

        action positionArm {
            in item target : GPSCoordinate;
            out item status : ArmStatus;
        }

        action gripCrop {
            in item force : GripForce;
            out item status : ArmStatus;
        }

        action pickCrop {
            out item harvestedCrop : HarvestedCrop;
            out item status : ArmStatus;
        }
    }

    part def ConveyorSystem {
        port conveyorIf : ConveyorPort;
        attribute beltSpeed : SpeedValue = 0.3 [m/s];
        attribute beltLength : LengthValue = 2.0 [m];

        action transportCrop {
            in item harvestedCrop : HarvestedCrop;
            out item binUpdate : BinUpdate;
        }

        action performTransport : transportCrop {
            // Transport harvested crop into storage bin
        }
    }

    part def StorageBin {
        port binIf : ConveyorPort;
        attribute maxCapacity : MassValue = 200 [kg];
        attribute currentWeight : HarvestedWeight = 0 [kg];
        attribute fillLevel : BinFillLevel = 0 [%];
        attribute isFull : Boolean = false;

        action receiveCrop {
            in item harvestedCrop : HarvestedCrop;
            out item binUpdate : BinUpdate;
        }

        action unload {
            out item binUpdate : BinUpdate;
        }

        action performReceive : receiveCrop {
            // Receive crop from conveyor
        }

        action performUnload : unload {
            // Unload bin contents when full
        }
    }

    part def BatteryPack {
        port powerOut : PowerPort;
        attribute capacity : BatteryCapacity = 5000 [Wh];
        attribute currentSOC : BatterySOC = 100 [%];
        attribute nominalVoltage : Voltage = 48 [V];
        attribute lowThreshold : BatterySOC = 20 [%];
        attribute fullThreshold : BatterySOC = 95 [%];

        action discharge {
            out attribute soc : BatterySOC;
        }

        action charge {
            in attribute chargingEnabled : Boolean;
            out attribute soc : BatterySOC;
        }

        action performDischarge : discharge {
            // Discharge during operation
        }

        action performCharge : charge {
            // Recharge when low
        }
    }

    part def MissionController {
        port missionIf : MissionControlPort;
        attribute targetWeight : TargetWeight = 500 [kg];
        attribute harvestedWeight : HarvestedWeight = 0 [kg];
        attribute harvestedCount : Integer = 0;
        attribute goalMet : Boolean = false;
        attribute currentTarget : Crop;

        action selectTargetCrop {
            in item detectedCrops : Crop[0..*];
            in item ripenessReports : RipenessReport[0..*];
            out item targetCrop : Crop;
        }

        action evaluateGoal {
            in item harvestedWeight : HarvestedWeight;
            out item goalMet : Boolean;
        }

        action manageMission {
            // High-level decision making: select next crop, check goal
        }

        action performTargetSelection : selectTargetCrop {
            // Select next ripe crop to target
        }

        action performGoalEvaluation : evaluateGoal {
            // Check if harvesting goal met
        }
    }

    // ---------- Main Harvester System ----------
    part def AutonomousHarvesterSystem {
        port missionPort : MissionControlPort;
        port powerPort : PowerPort;

        part vision : VisionSystem;
        part navigation : NavigationController;
        part arm : HarvestingArm;
        part conveyor : ConveyorSystem;
        part storageBin : StorageBin;
        part battery : BatteryPack;
        part missionController : MissionController;

        // Internal connections
        connection visionToMission connect vision.detectionOut.detectedCrops to missionController.missionIf.targetCrop;
        connection visionToNav connect vision.detectionOut.detectedCrops to navigation.navCmd.pathPlan;
        connection missionToNav connect missionController.missionIf.targetCrop to navigation.navCmd.pathPlan;
        connection navToArm connect navigation.navCmd.arrivalStatus to arm.armCmd.armCommand;
        connection armToConveyor connect arm.armCmd.armStatus to conveyor.conveyorIf.harvestedCrop;
        connection conveyorToBin connect conveyor.conveyorIf.binUpdate to storageBin.binIf.binUpdate;
        connection binToMission connect storageBin.binIf.binUpdate to missionController.missionIf.systemState;
        connection batteryToMission connect battery.powerOut.soc to missionController.missionIf.systemState;
        connection missionToPower connect missionController.missionIf.systemState to battery.powerOut.chargingEnabled;

        // System-level state machine
        state harvesterStateMachine {
            initial -> initializing;
            state initializing {
                entry action initializeSystems;
                // Initialize all subsystems
            }
            state standby {
                entry action enterStandby;
                // Ready but not actively harvesting
            }
            state activeHarvesting {
                entry action startHarvestCycle;
                // Active autonomous mode for harvesting
            }
            state charging {
                entry action startCharging;
                // Battery low, charging mode
            }
            state unloading {
                entry action startUnloading;
                // Storage bin full, unloading mode
            }
            state fault {
                entry action handleFault;
                // Error handling state
            }

            transition init_to_standby
                from initializing to standby
                when battery.powerOut.soc >= 20[%] and storageBin.fillLevel < 100[%];

            transition standby_to_active
                from standby to activeHarvesting
                when missionController.goalMet == false and battery.powerOut.soc >= 20[%] and storageBin.isFull == false;

            transition active_to_charging
                from activeHarvesting to charging
                when battery.powerOut.soc < 20[%];

            transition active_to_unloading
                from activeHarvesting to unloading
                when storageBin.isFull == true;

            transition active_to_fault
                from activeHarvesting to fault
                when arm.armCmd.armStatus == ArmStatus::error;

            transition charging_to_standby
                from charging to standby
                when battery.powerOut.soc >= 95[%];

            transition unloading_to_standby
                from unloading to standby
                when storageBin.fillLevel == 0[%];

            transition fault_to_standby
                from fault to standby
                when faultResolved == true;

            attribute faultResolved : Boolean = false;
        }

        action initializeSystems {
            // Initialize vision, navigation, arm, conveyor, bin, battery, mission controller
        }

        action enterStandby {
            // Enter low-power standby
        }

        action startHarvestCycle {
            // Begin harvesting cycle: scan, navigate, pick, convey, store
        }

        action startCharging {
            // Initiate charging sequence
        }

        action startUnloading {
            // Initiate bin unloading
        }

        action handleFault {
            // Handle fault condition
        }

        // Harvesting cycle composite action
        action harvestCycle {
            in item targetCrop : Crop;
            out item harvestedCrop : HarvestedCrop;

            action scan : vision.performScan;
            action analyze : vision.performAnalysis;
            action plan : navigation.performPlanning;
            action drive : navigation.performDriving;
            action position : arm.positionArm;
            action grip : arm.gripCrop;
            action pick : arm.pickCrop;
            action transport : conveyor.performTransport;
            action store : storageBin.performReceive;

            flow from scan.detectedCrops to analyze.crop;
            flow from analyze.report to plan.start;
            flow from plan.pathPlan to drive.pathPlan;
            flow from drive.arrivalStatus to position.target;
            flow from position.status to grip.force;
            flow from grip.status to pick.harvestedCrop;
            flow from pick.harvestedCrop to transport.harvestedCrop;
            flow from transport.binUpdate to store.harvestedCrop;
        }
    }

    // ---------- Requirements ----------
    requirement def HarvestingGoalRequirement {
        doc "The system shall harvest crops until the target weight is achieved.";
        attribute targetWeight : TargetWeight = 500 [kg];
        satisfy missionController.targetWeight == targetWeight;
    }

    requirement def RipenessDetectionRequirement {
        doc "The vision system shall detect crop ripeness with at least 85% confidence.";
        attribute minConfidence : Confidence = 85 [%];
        satisfy vision.minConfidence >= minConfidence;
    }

    requirement def ArmSafetyRequirement {
        doc "The harvesting arm shall grip crops with force not exceeding safe limit to avoid damage.";
        attribute maxSafeForce : GripForce = 10 [N];
        satisfy arm.safeGripForce <= maxSafeForce;
    }

    requirement def BinCapacityRequirement {
        doc "The storage bin shall hold at least 200 kg of harvested produce.";
        attribute minCapacity : MassValue = 200 [kg];
        satisfy storageBin.maxCapacity >= minCapacity;
    }

    requirement def BatteryEnduranceRequirement {
        doc "The battery shall support at least 8 hours of continuous operation.";
        attribute minRuntime : TimeValue = 8 [h];
        satisfy battery.capacity >= 4000 [Wh];
    }

    requirement def AutonomousOperationRequirement {
        doc "The system shall operate autonomously through initialization, standby, active harvesting, charging, unloading, and fault states.";
        satisfy harvesterStateMachine.states == {HarvesterState::initializing, HarvesterState::standby, HarvesterState::activeHarvesting, HarvesterState::charging, HarvesterState::unloading, HarvesterState::fault};
    }

    requirement HarvestingGoalReq : HarvestingGoalRequirement;
    requirement RipenessDetectionReq : RipenessDetectionRequirement;
    requirement ArmSafetyReq : ArmSafetyRequirement;
    requirement BinCapacityReq : BinCapacityRequirement;
    requirement BatteryEnduranceReq : BatteryEnduranceRequirement;
    requirement AutonomousOperationReq : AutonomousOperationRequirement;

    // ---------- Satisfaction ----------
    satisfaction satisfy HarvestingGoalReq by AutonomousHarvesterSystem::missionController;
    satisfaction satisfy RipenessDetectionReq by AutonomousHarvesterSystem::vision;
    satisfaction satisfy ArmSafetyReq by AutonomousHarvesterSystem::arm;
    satisfaction satisfy BinCapacityReq by AutonomousHarvesterSystem::storageBin;
    satisfaction satisfy BatteryEnduranceReq by AutonomousHarvesterSystem::battery;
    satisfaction satisfy AutonomousOperationReq by AutonomousHarvesterSystem::harvesterStateMachine;

}
